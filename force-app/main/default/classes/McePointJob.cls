/**
 * ! 사용 X
 * MCE 포인트(적립/차감) 이벤트 전송 Queueable
 * - Trigger에서 TJ Id들을 25개씩 chunk enqueue
 * - TransactionJournal 1회 조회 (Order/Store 포함)
 * - LoyaltyLedger 1회 조회
 * - (✅) LoyaltyMemberCurrency 조회 제거: TJ.PostPointBalance__c(처리 후 잔액) 사용
 * - 멤버별 1회 callout
 *
 * 전제:
 * - TransactionJournal에 처리 후 포인트 잔액 필드(PostPointBalance__c)가 존재하며,
 *   해당 TJ 처리 완료 시점에 값이 채워져있다.
 * - 멤버가 여러 TJ를 가질 수 있으므로, 멤버 대표 잔액은 "가장 최신 TJ(ActivityDate)" 기준으로 선택한다.
 */
public with sharing class McePointJob {
  /* implements Queueable, Database.AllowsCallouts {
  private static final String MCE_CREDIT_EVENT_DEFINITION_KEY = System.Label.MceCreditPointEventDefinitionKey;
  private static final String MCE_DEBIT_EVENT_DEFINITION_KEY = System.Label.MceDebitPointEventDefinitionKey;

  private static final String POINT_CURRENCY_NAME = '포인트';

  // ✅ TJ "처리 후 잔액" 필드 API Name (필드명 변경 시 여기만 수정)
  //   private static final String TJ_POST_POINT_BALANCE_FIELD = 'PostPointBalance__c';

  public enum Operation {
    CREDIT_POINT,
    DEBIT_POINT
  }

  private Operation op;
  private List<Id> tjIds;

  public McePointJob(Operation op, List<Id> tjIds) {
    this.op = op;
    this.tjIds = (tjIds == null) ? new List<Id>() : tjIds;
  }

  public void execute(QueueableContext ctx) {
    Id jobId = ctx.getJobId();
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, jobId, null);
    logger.logging(McePointJob.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Set<String> successIds = new Set<String>(); // memberId(String)
    Set<String> failIds = new Set<String>(); // memberId(String)
    List<String> failMsgs = new List<String>();

    Integer apiSuccessCnt = 0;
    Integer apiFailCnt = 0;

    try {
      // -------------------------
      // Guard
      // -------------------------
      if (op == null) {
        logger.setStatus('ERROR');
        logger.setDescription('Operation is null');
        return;
      }
      if (tjIds == null || tjIds.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('tjIds is empty');
        return;
      }

      // eventDefinitionKey 결정
      String eventDefinitionKey = (op == Operation.CREDIT_POINT) ? MCE_CREDIT_EVENT_DEFINITION_KEY : MCE_DEBIT_EVENT_DEFINITION_KEY;

      // -------------------------
      // 0) TransactionJournal 조회 (1회)
      // - Store/Order 정보 + 처리 후 잔액(PostPointBalance__c)
      // -------------------------
      List<TransactionJournal> tjList = [
        SELECT
          Id,
          ActivityDate,
          JournalDate,
          PostPointBalance__c,
          OrderId,
          Order.EffectiveDate,
          Order.StoreCode__c,
          Order.StoreCode__r.Name,
          Order.StoreCode__r.StoreCode__c
        FROM TransactionJournal
        WHERE Id IN :tjIds
      ];

      if (tjList == null || tjList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('No TransactionJournal found. tjCnt=' + tjIds.size());
        return;
      }

      // logger scoped ids
      try {
        logger.setScopedIds((List<SObject>) tjList, 'Id');
      } catch (Exception ignore) {
      }

      // TJ Map + StoreInfo + PostBalance Map
      Map<Id, TransactionJournal> tjById = new Map<Id, TransactionJournal>();
      Set<Id> tjIdSet = new Set<Id>();
      Map<Id, StoreInfo> storeInfoByTjId = new Map<Id, StoreInfo>();
      Map<Id, Decimal> postBalanceByTjId = new Map<Id, Decimal>();

      for (TransactionJournal tj : tjList) {
        tjById.put(tj.Id, tj);
        tjIdSet.add(tj.Id);

        // StoreInfo
        StoreInfo si = new StoreInfo();
        if (tj.OrderId != null && tj.Order != null && tj.Order.StoreCode__c != null && tj.Order.StoreCode__r != null) {
          si.storeCode = tj.Order.StoreCode__r.StoreCode__c;
          si.storeName = tj.Order.StoreCode__r.Name;
        }
        // 구매일자: Order.EffectiveDate 우선, 없으면 TJ.ActivityDate fallback
        if (tj.OrderId != null && tj.Order != null && tj.Order.EffectiveDate != null) {
          si.purchaseDate = String.valueOf(tj.Order.EffectiveDate);
        } else if (tj.ActivityDate != null) {
          si.purchaseDate = String.valueOf(tj.ActivityDate.date());
        }

        storeInfoByTjId.put(tj.Id, si);

        // 처리 후 잔액
        postBalanceByTjId.put(tj.Id, tj.PostPointBalance__c);
      }

      // -------------------------
      // 1) LoyaltyLedger 조회 (1회)
      // - payload에 필요한 Contact 관계 포함
      // -------------------------
      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyProgramMemberId,
          EventType,
          Points,
          LoyaltyProgramCurrency.Name,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LoyaltyProgramMember.Contact.MobilePhone,
          LoyaltyProgramMember.Contact.Email,
          LoyaltyProgramMember.Contact.LastName,
          LoyaltyProgramMember.Contact.Grade__c
        FROM LoyaltyLedger
        WHERE TransactionJournalId IN :tjIdSet AND LoyaltyProgramCurrency.Name = :POINT_CURRENCY_NAME
      ];

      if (llList == null || llList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('No LoyaltyLedger found. tjCnt=' + tjIdSet.size());
        return;
      }

      // -------------------------
      // 2) 멤버별 집계 + 멤버 대표 TJ(최신) 선택
      // - 대표 TJ 기준으로 StoreInfo, AvailablePoints(처리 후 잔액) 결정
      // -------------------------
      Map<Id, MemberAgg> aggByMemberId = new Map<Id, MemberAgg>();
      Set<Id> memberIdSet = new Set<Id>();

      for (LoyaltyLedger ll : llList) {
        if (ll == null) {
          continue;
        }

        Id memberId = ll.LoyaltyProgramMemberId;
        if (memberId == null) {
          continue;
        }

        memberIdSet.add(memberId);

        if (!aggByMemberId.containsKey(memberId)) {
          aggByMemberId.put(memberId, new MemberAgg(memberId));
        }

        MemberAgg agg = aggByMemberId.get(memberId);

        // 집계(적립/차감 합계)
        String direction = deriveDirection(ll);
        agg.add(direction, ll.Points, ll.TransactionJournalId);

        // 샘플 ledger (연락처 공통값)
        if (agg.sampleLedger == null) {
          agg.sampleLedger = ll;
        }

        // 대표 TJ 선택: "가장 최신 ActivityDate" 우선
        Id tjId = ll.TransactionJournalId;
        TransactionJournal tj = (tjId != null) ? tjById.get(tjId) : null;
        if (tj != null) {
          Datetime candidateDt = tj.ActivityDate;

          // ActivityDate가 비어있으면 JournalDate로 fallback (Date -> Datetime)
          if (candidateDt == null && tj.JournalDate != null) {
            candidateDt = tj.JournalDate; // JournalDate가 Datetime일 때
          }

          if (candidateDt != null) {
            if (agg.latestTxnDt == null || candidateDt.getTime() > agg.latestTxnDt.getTime()) {
              agg.latestTxnDt = candidateDt;
              agg.sampleTjId = tjId;

              // 대표 TJ의 처리 후 잔액 사용 (없으면 0)
              Decimal bal = postBalanceByTjId.containsKey(tjId) ? postBalanceByTjId.get(tjId) : null;
              agg.availablePointsAfter = (bal == null) ? 0 : bal;
            }
          } else {
            // 날짜 판단이 불가하면 최초 1회만 채움(최후 fallback)
            if (agg.sampleTjId == null && tjId != null) {
              agg.sampleTjId = tjId;
              Decimal bal2 = postBalanceByTjId.containsKey(tjId) ? postBalanceByTjId.get(tjId) : null;
              agg.availablePointsAfter = (bal2 == null) ? 0 : bal2;
            }
          }
        }
      }

      if (memberIdSet.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('No member target. ledgerCnt=' + llList.size());
        return;
      }

      // -------------------------
      // 3) 멤버별 callout (멤버당 1회)
      // -------------------------
      for (Id memberId : aggByMemberId.keySet()) {
        // 트랜잭션당 callout 100 제한 방어
        if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
          failIds.add((String) memberId);
          failMsgs.add('Callout limit reached. memberId=' + memberId);
          continue;
        }

        MemberAgg agg = aggByMemberId.get(memberId);
        LoyaltyLedger base = agg.sampleLedger;

        String memberNo = (base != null &&
          base.LoyaltyProgramMember != null &&
          base.LoyaltyProgramMember.Contact != null)
          ? base.LoyaltyProgramMember.Contact.MemberNo__c
          : null;

        if (String.isBlank(memberNo)) {
          failIds.add((String) memberId);
          failMsgs.add('MemberNo__c is blank. memberId=' + memberId);
          continue;
        }

        // ✅ 처리 후 잔액(TJ) 기반 AvailablePoints
        Decimal available = (agg.availablePointsAfter == null) ? 0 : agg.availablePointsAfter;

        // 대표 TJ 기반 StoreInfo
        StoreInfo si = (agg.sampleTjId != null) ? storeInfoByTjId.get(agg.sampleTjId) : null;

        try {
          String pk = MceEventReqDto.buildPk(memberNo);

          Map<String, Object> data = new Map<String, Object>{
            'ContactKey' => memberNo,
            'PK' => pk,
            'SubscriberKey' => memberNo,
            'Phone' => (base != null &&
              base.LoyaltyProgramMember != null &&
              base.LoyaltyProgramMember.Contact != null)
              ? base.LoyaltyProgramMember.Contact.MobilePhone
              : null,
            'EmailAddress' => (base != null &&
              base.LoyaltyProgramMember != null &&
              base.LoyaltyProgramMember.Contact != null)
              ? base.LoyaltyProgramMember.Contact.Email
              : null,
            'LastName' => (base != null &&
              base.LoyaltyProgramMember != null &&
              base.LoyaltyProgramMember.Contact != null)
              ? base.LoyaltyProgramMember.Contact.LastName
              : null,
            'AvailablePoints' => available,
            'Grade__c' => (base != null &&
              base.LoyaltyProgramMember != null &&
              base.LoyaltyProgramMember.Contact != null)
              ? base.LoyaltyProgramMember.Contact.Grade__c
              : null,
            'StoreCode__c' => (si == null ? null : si.storeCode),
            'Purchase_Store' => (si == null ? null : si.storeName),
            'PurchaseDate' => (si == null ? null : si.purchaseDate)
          };

          // op에 따라 body 값 key 분기
          if (op == Operation.CREDIT_POINT) {
            data.put('EarnedPoints', agg.creditTotal);
          } else {
            data.put('UsedPoints', agg.debitTotal);
          }

          // 요청 DTO 구성
          // ※ MceEventReqDto에 setEventDefinitionKey/setContactKey 등이 실제로 존재하는지 확인 필요
          //    존재하지 않으면 생성자/필드에 맞게 수정.
          MceEventReqDto reqDto = new MceEventReqDto(data);
          // ContactKey 세팅(너희 DTO 규격에 맞게)
          try {
            reqDto.setContactKey(pk);
          } catch (Exception ignore) {
          }
          try {
            reqDto.setEventDefinitionKey(eventDefinitionKey);
          } catch (Exception ignore) {
          }

          // ✅ 실제 callout
          //   MceApiClient.sendInteractionEvent(reqDto);

          DebugUtil.pretty('reqDto', reqDto);

          // 실제 callout
          if ('01039422265'.equals(data.get('Phone'))) {
            System.debug('번호가 동일합니다. 01039422265');
            MceApiClient.sendInteractionEvent(reqDto);
          } else {
            System.debug('번호가 다릅니다. ' + data.get('Phone'));
          }

          apiSuccessCnt++;
          successIds.add((String) memberId);
        } catch (Exception ex) {
          apiFailCnt++;
          failIds.add((String) memberId);
          failMsgs.add('MCE callout failed. memberId=' + memberId + ', msg=' + ex.getMessage());
        }
      }

      // 성공한 건은 실패 목록에서 제거
      failIds.removeAll(successIds);

      Boolean hasAnyFail = !failIds.isEmpty();
      Boolean hasAnySuccess = !successIds.isEmpty();

      if (hasAnyFail && hasAnySuccess) {
        logger.setStatus('PARTIAL');
      } else if (hasAnyFail) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription(
        'op=' +
          String.valueOf(op) +
          ', chunkTjCnt=' +
          tjList.size() +
          ', tjCnt=' +
          tjIdSet.size() +
          ', ledgerCnt=' +
          llList.size() +
          ', memberCnt=' +
          memberIdSet.size() +
          ', apiSuccess=' +
          apiSuccessCnt +
          ', apiFail=' +
          apiFailCnt
      );
    } catch (Exception e) {
      try {
        logger.createExceptionLog(e);
      } catch (Exception ignore) {
      }
      logger.setStatus('ERROR');
      failMsgs.add('Unhandled exception: ' + e.getMessage());
    } finally {
      // 로거 부가정보
      if (!successIds.isEmpty()) {
        try {
          logger.setSuccessRecordIds(successIds);
        } catch (Exception ignore) {
        }
      }
      if (!failIds.isEmpty()) {
        try {
          logger.setFailedRecordIds(failIds);
        } catch (Exception ignore) {
        }
      }
      if (!failMsgs.isEmpty()) {
        try {
          logger.setErrorMessage(String.join(failMsgs, ' | '));
        } catch (Exception ignore) {
        }
      }

      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  // -------------------------
  // CREDIT/DEBIT 판별
  // - EventType('Credit'/'Debit') 우선
  // - fallback: Points 부호
  // -------------------------
  private static String deriveDirection(LoyaltyLedger ll) {
    if (ll == null)
      return 'CREDIT';

    if (!String.isBlank(ll.EventType)) {
      if (ll.EventType == 'Credit')
        return 'CREDIT';
      if (ll.EventType == 'Debit')
        return 'DEBIT';
    }

    Decimal p = ll.Points;
    return (p != null && p < 0) ? 'DEBIT' : 'CREDIT';
  }

  // =========================
  // 멤버 단위 집계
  // =========================
  public class MemberAgg {
    public Id memberId;
    public Decimal creditTotal = 0;
    public Decimal debitTotal = 0;

    public LoyaltyLedger sampleLedger; // 연락처/등급 등 공통값
    public Id sampleTjId; // StoreInfo + AvailablePoints 대표 TJ
    public Datetime latestTxnDt; // 대표 TJ 선택 기준
    public Decimal availablePointsAfter = 0; // ✅ 처리 후 잔액(대표)

    public MemberAgg(Id memberId) {
      this.memberId = memberId;
    }

    public void add(String direction, Decimal points, Id tjId) {
      if (points == null) {
        points = 0;
      }

      Decimal v = points.abs();
      if (direction == 'DEBIT') {
        debitTotal += v;
      } else {
        creditTotal += v;
      }
    }
  }

  // =========================
  // TJ 기준 Store/Purchase 정보
  // =========================
  public class StoreInfo {
    public String storeCode; // 구매 매장 코드
    public String storeName; // 구매 매장명
    public String purchaseDate; // 구매일자
  }
    */
}