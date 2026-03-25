public with sharing class McePointService implements Queueable, Database.AllowsCallouts {
  // =========================================================
  // CMDT DeveloperNames
  // =========================================================
  private static final String CMDT_KEY_CREDIT = 'MceCreditPointEventDefinitionKey';
  private static final String CMDT_KEY_DEBIT = 'MceDebitPointEventDefinitionKey';
  private static final String CMDT_KEY_BOTH = 'MceCreditAndDebitPointEventDefinitionKey';

  // Lazy cache (per-transaction)
  @TestVisible public static String creditEventDefinitionKey;
  @TestVisible public static String debitEventDefinitionKey;
  @TestVisible public static String creditAndDebitEventDefinitionKey;

  private static final String POINT_CURRENCY_NAME = '포인트';

  public enum SendMode {
    DEBIT,
    CREDIT,
    BOTH
  }

  private List<Id> orderIds;

  public McePointService(List<Id> orderIds) {
    this.orderIds = (orderIds == null) ? new List<Id>() : orderIds;
  }

  // =========================================================
  // Lazy getters (CMDT)
  // =========================================================
  public static String getCreditEventDefinitionKey() {
    if (creditEventDefinitionKey == null) {
      creditEventDefinitionKey = loadApiKeyFromCmdt(CMDT_KEY_CREDIT);
    }
    return creditEventDefinitionKey;
  }

  public static String getDebitEventDefinitionKey() {
    if (debitEventDefinitionKey == null) {
      debitEventDefinitionKey = loadApiKeyFromCmdt(CMDT_KEY_DEBIT);
    }
    return debitEventDefinitionKey;
  }

  public static String getCreditAndDebitEventDefinitionKey() {
    if (creditAndDebitEventDefinitionKey == null) {
      creditAndDebitEventDefinitionKey = loadApiKeyFromCmdt(CMDT_KEY_BOTH);
    }
    return creditAndDebitEventDefinitionKey;
  }

  public static String loadApiKeyFromCmdt(String developerName) {
    MceApiCredential__mdt m = MceApiCredential__mdt.getInstance(developerName);
    if (m == null) {
      throw new CalloutException('MCE CMDT record not found: ' + developerName);
    }
    if (String.isBlank(m.ApiKey__c)) {
      throw new CalloutException('MCE ApiKey__c is blank: ' + developerName);
    }
    return m.ApiKey__c;
  }

  // =========================================================
  // Execute
  // =========================================================
  public void execute(QueueableContext ctx) {
    ApexLogger jobLogger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, ctx.getJobId(), null);
    jobLogger.logging(McePointService.class.getName());
    jobLogger.setRequestDatetime(Datetime.now());

    List<String> failMsgs = new List<String>();
    Set<String> okMembers = new Set<String>();
    Set<String> ngMembers = new Set<String>();

    Integer debitOk = 0, debitNg = 0, creditOk = 0, creditNg = 0;
    Integer bothOk = 0, bothNg = 0;

    try {
      if (orderIds == null || orderIds.isEmpty()) {
        jobLogger.setStatus('SUCCESS');
        jobLogger.setDescription('orderIds is empty.');
        return;
      }

      // 1) Order -> TransactionJournal 조회 (Processed + 대상 subtype만)
      List<TransactionJournal> tjList = [
        SELECT Id, OrderId, JournalSubTypeName__c
        FROM TransactionJournal
        WHERE
          OrderId IN :orderIds
          AND Status = 'Processed'
          AND JournalSubTypeName__c IN ('Purchase Accrual', 'Point Redeem Cancel', 'Point Debit', 'Cancel Purchase Accrual')
        LIMIT 50000
      ];

      if (tjList.isEmpty()) {
        jobLogger.setStatus('SUCCESS');
        jobLogger.setDescription('No TransactionJournal found. orderCnt=' + orderIds.size());
        return;
      }

      // 주문별 debit/credit TJ ID 수집
      Map<Id, List<Id>> debitTjIdsByOrder = new Map<Id, List<Id>>();
      Map<Id, List<Id>> creditTjIdsByOrder = new Map<Id, List<Id>>();
      Set<Id> debitOrderIds = new Set<Id>();
      Set<Id> creditOrderIds = new Set<Id>();

      for (TransactionJournal tj : tjList) {
        if (tj == null || tj.OrderId == null) {
          continue;
        }

        Boolean isDebitTj = tj.JournalSubTypeName__c == 'Point Debit' || tj.JournalSubTypeName__c == 'Cancel Purchase Accrual';
        Boolean isCreditTj = tj.JournalSubTypeName__c == 'Purchase Accrual' || tj.JournalSubTypeName__c == 'Point Redeem Cancel';

        if (isDebitTj) {
          debitOrderIds.add(tj.OrderId);
          if (!debitTjIdsByOrder.containsKey(tj.OrderId)) {
            debitTjIdsByOrder.put(tj.OrderId, new List<Id>());
          }
          debitTjIdsByOrder.get(tj.OrderId).add(tj.Id);
        } else if (isCreditTj) {
          creditOrderIds.add(tj.OrderId);
          if (!creditTjIdsByOrder.containsKey(tj.OrderId)) {
            creditTjIdsByOrder.put(tj.OrderId, new List<Id>());
          }
          creditTjIdsByOrder.get(tj.OrderId).add(tj.Id);
        }
      }

      // 주문 단위로 3그룹
      Set<Id> bothOrderIds = new Set<Id>(debitOrderIds);
      bothOrderIds.retainAll(creditOrderIds); // 교집합

      Set<Id> debitOnlyOrderIds = new Set<Id>(debitOrderIds);
      debitOnlyOrderIds.removeAll(bothOrderIds); // 차집합

      Set<Id> creditOnlyOrderIds = new Set<Id>(creditOrderIds);
      creditOnlyOrderIds.removeAll(bothOrderIds);

      // 3그룹에 해당하는 TJ ID 리스트
      List<Id> debitOnlyTjIds = new List<Id>();
      List<Id> creditOnlyTjIds = new List<Id>();
      List<Id> bothTjIds = new List<Id>();

      for (Id oid : debitOnlyOrderIds) {
        if (debitTjIdsByOrder.containsKey(oid)) {
          debitOnlyTjIds.addAll(debitTjIdsByOrder.get(oid));
        }
      }
      for (Id oid : creditOnlyOrderIds) {
        if (creditTjIdsByOrder.containsKey(oid)) {
          creditOnlyTjIds.addAll(creditTjIdsByOrder.get(oid));
        }
      }
      for (Id oid : bothOrderIds) {
        if (debitTjIdsByOrder.containsKey(oid)) {
          bothTjIds.addAll(debitTjIdsByOrder.get(oid));
        }
        if (creditTjIdsByOrder.containsKey(oid)) {
          bothTjIds.addAll(creditTjIdsByOrder.get(oid));
        }
      }

      if (debitOnlyTjIds.isEmpty() && creditOnlyTjIds.isEmpty() && bothTjIds.isEmpty()) {
        jobLogger.setStatus('SUCCESS');
        jobLogger.setDescription('TJ exists but no debit/credit matched. tjCnt=' + tjList.size());
        return;
      }

      // 전송 (주문 그룹 기준)
      SendSummary sDebit = new SendSummary();
      SendSummary sCredit = new SendSummary();
      SendSummary sBoth = new SendSummary();

      if (!debitOnlyTjIds.isEmpty()) {
        sDebit = sendByTjIds(debitOnlyTjIds, getDebitEventDefinitionKey(), SendMode.DEBIT);
      }
      if (!creditOnlyTjIds.isEmpty()) {
        sCredit = sendByTjIds(creditOnlyTjIds, getCreditEventDefinitionKey(), SendMode.CREDIT);
      }
      if (!bothTjIds.isEmpty()) {
        sBoth = sendByTjIds(bothTjIds, getCreditAndDebitEventDefinitionKey(), SendMode.BOTH);
      }

      // 집계
      debitOk += sDebit.ok;
      debitNg += sDebit.ng;
      creditOk += sCredit.ok;
      creditNg += sCredit.ng;
      bothOk += sBoth.ok;
      bothNg += sBoth.ng;

      okMembers.addAll(sDebit.okMembers);
      ngMembers.addAll(sDebit.ngMembers);
      failMsgs.addAll(sDebit.failMsgs);
      okMembers.addAll(sCredit.okMembers);
      ngMembers.addAll(sCredit.ngMembers);
      failMsgs.addAll(sCredit.failMsgs);
      okMembers.addAll(sBoth.okMembers);
      ngMembers.addAll(sBoth.ngMembers);
      failMsgs.addAll(sBoth.failMsgs);

      ngMembers.removeAll(okMembers);

      if (!ngMembers.isEmpty() && !okMembers.isEmpty()) {
        jobLogger.setStatus('PARTIAL');
      } else if (!ngMembers.isEmpty()) {
        jobLogger.setStatus('ERROR');
      } else {
        jobLogger.setStatus('SUCCESS');
      }

      jobLogger.setDescription(
        'Order-based send done. orderCnt=' +
          orderIds.size() +
          ', tjCnt=' +
          tjList.size() +
          ', debitOnlyOrders=' +
          debitOnlyOrderIds.size() +
          ', creditOnlyOrders=' +
          creditOnlyOrderIds.size() +
          ', bothOrders=' +
          bothOrderIds.size() +
          ', debitOnlyTj=' +
          debitOnlyTjIds.size() +
          ', creditOnlyTj=' +
          creditOnlyTjIds.size() +
          ', bothTj=' +
          bothTjIds.size() +
          ', debitOk=' +
          debitOk +
          ', debitNg=' +
          debitNg +
          ', creditOk=' +
          creditOk +
          ', creditNg=' +
          creditNg +
          ', bothOk=' +
          bothOk +
          ', bothNg=' +
          bothNg +
          ', okMembers=' +
          okMembers.size() +
          ', ngMembers=' +
          ngMembers.size()
      );
    } catch (Exception e) {
      try {
        jobLogger.createExceptionLog(e);
      } catch (Exception ignore) {
        // 무시
      }
      jobLogger.setStatus('ERROR');
      failMsgs.add('Unhandled exception: ' + e.getMessage());
    } finally {
      try {
        if (!okMembers.isEmpty()) {
          jobLogger.setSuccessRecordIds(okMembers);
        }
        if (!ngMembers.isEmpty()) {
          jobLogger.setFailedRecordIds(ngMembers);
        }
        if (!failMsgs.isEmpty()) {
          jobLogger.setErrorMessage(String.join(failMsgs, ' | '));
        }
      } catch (Exception ignore) {
        // 무시
      }

      jobLogger.setResponseDatetime(Datetime.now());
      jobLogger.addLog();

      try {
        ApexLogger.insertLogs();
      } catch (Exception ignore) {
        // 무시
      }
    }
  }

  // ----------------------------------------------------------------
  // TJ ID 리스트 기준 실제 전송 (DEBIT/CREDIT/BOTH 별로 따로 호출됨)
  // - AvailablePoints는 "현재 잔여 포인트"를 조회해서 세팅
  // ----------------------------------------------------------------
  public static SendSummary sendByTjIds(List<Id> tjIds, String eventDefinitionKey, SendMode mode) {
    SendSummary sum = new SendSummary();
    if (tjIds == null || tjIds.isEmpty()) {
      return sum;
    }

    // 0) TJ 조회(1회)
    List<TransactionJournal> tjList = [
      SELECT Id, ActivityDate, JournalDate, PostPointBalance__c, Order.EffectiveDate, Order.StoreCode__r.Name, Order.StoreCode__r.StoreCode__c
      FROM TransactionJournal
      WHERE Id IN :tjIds
    ];
    if (tjList.isEmpty()) {
      sum.failMsgs.add('No TJ found. tjCnt=' + tjIds.size());
      return sum;
    }
    Map<Id, TransactionJournal> tjById = new Map<Id, TransactionJournal>(tjList);

    // 1) Ledger 조회(1회)
    List<LoyaltyLedger> llList = [
      SELECT
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
      WHERE TransactionJournalId IN :tjById.keySet() AND LoyaltyProgramCurrency.Name = :POINT_CURRENCY_NAME
    ];
    if (llList.isEmpty()) {
      return sum;
    }

    // 2) 멤버 집계 (credit/debit 합산)
    Map<Id, MemberAgg> aggByMemberId = new Map<Id, MemberAgg>();

    for (LoyaltyLedger ll : llList) {
      if (ll == null) {
        continue;
      }

      Id mid = ll.LoyaltyProgramMemberId;
      if (mid == null) {
        continue;
      }

      String dir = deriveDirection(ll);

      if (mode == SendMode.DEBIT && dir != 'DEBIT') {
        continue;
      }
      if (mode == SendMode.CREDIT && dir != 'CREDIT') {
        continue;
      }
      // BOTH면 둘 다 허용

      if (!aggByMemberId.containsKey(mid))
        aggByMemberId.put(mid, new MemberAgg(mid));
      MemberAgg agg = aggByMemberId.get(mid);

      agg.add(dir, ll.Points);

      // 샘플 ledger 1개 확보 (연락처 정보용)
      if (agg.sampleLedger == null) {
        agg.sampleLedger = ll;
      }

      // 기존 availableAfter는 더 이상 핵심이 아니지만 fallback 용도로만 유지
      TransactionJournal tj = tjById.get(ll.TransactionJournalId);
      if (tj != null) {
        Decimal bal = (tj.PostPointBalance__c == null) ? 0 : tj.PostPointBalance__c;
        if (agg.sampleTjId == null) {
          agg.sampleTjId = tj.Id;
          agg.availableAfter = bal;
        }
      }
    }

    if (aggByMemberId.isEmpty()) {
      return sum;
    }

    // =========================================================
    // 2.5) "현재 잔여 포인트" 조회 (멤버별 1회)
    // =========================================================
    Map<Id, Decimal> balanceByMemberId = new Map<Id, Decimal>();
    for (LoyaltyMemberCurrency lmc : [
      SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId IN :aggByMemberId.keySet() AND LoyaltyProgramCurrency.Name = :POINT_CURRENCY_NAME
    ]) {
      balanceByMemberId.put(lmc.LoyaltyMemberId, lmc.PointsBalance);
    }

    // 3) callout (멤버 단위)
    for (Id memberId : aggByMemberId.keySet()) {
      if (Limits.getCallouts() >= Limits.getLimitCallouts()) {
        sum.ngMembers.add((String) memberId);
        sum.failMsgs.add('Callout limit reached. memberId=' + memberId);
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
        sum.ngMembers.add((String) memberId);
        sum.failMsgs.add('MemberNo blank. memberId=' + memberId);
        continue;
      }

      // 현재 잔여 포인트
      Decimal currentBal = balanceByMemberId.get(memberId);
      System.debug('currentBal: ' + currentBal);

      Map<String, Object> data = new Map<String, Object>{
        'ContactKey' => memberNo,
        'PK' => MceEventReqDto.buildPk(memberNo),
        'SubscriberKey' => memberNo,
        'Phone' => base.LoyaltyProgramMember.Contact.MobilePhone,
        'EmailAddress' => base.LoyaltyProgramMember.Contact.Email,
        'LastName' => base.LoyaltyProgramMember.Contact.LastName,
        'Grade__c' => base.LoyaltyProgramMember.Contact.Grade__c,
        // 조회 잔액이 null이면 fallback(기존 로직) 사용
        'AvailablePoints' => (currentBal == null ? agg.availableAfter : currentBal)
      };

      if (mode == SendMode.DEBIT) {
        data.put('UsedPoints', agg.debitTotal);
        System.debug('SendMode.DEBIT 진입');
        System.debug('agg.debitTotal: ' + agg.debitTotal);
      } else if (mode == SendMode.CREDIT) {
        data.put('EarnedPoints', agg.creditTotal);
        System.debug('SendMode.CREDIT 진입');
        System.debug('agg.creditTotal: ' + agg.creditTotal);
      } else {
        // BOTH
        data.put('UsedPoints', agg.debitTotal);
        data.put('EarnedPoints', agg.creditTotal);
        System.debug('SendMode.BOTH 진입');
        System.debug('agg.debitTotal: ' + agg.debitTotal);
        System.debug('agg.creditTotal: ' + agg.creditTotal);
      }

      MceEventReqDto reqDto = new MceEventReqDto(data);
      try {
        reqDto.setEventDefinitionKey(eventDefinitionKey);
      } catch (Exception ignore) {
        // 무시
      }
      try {
        reqDto.setContactKey((String) data.get('ContactKey'));
      } catch (Exception ignore) {
        // 무시
      }

      ApexLogger apiLogger = new ApexLogger(ApexLogger.JobType.API);
      apiLogger.logging('MceApiClient');
      apiLogger.setRequestDatetime(Datetime.now());
      apiLogger.setMethod('POST');
      apiLogger.setRequestUrl('callout:MarketingCloudApiNC/interaction/v1/events');
      apiLogger.setRequestBody(JSON.serialize(reqDto.toMap()));
      apiLogger.setDescription('MCE ' + String.valueOf(mode) + ' memberNo=' + memberNo);

      try {
        // MceApiClient.sendInteractionEvent(reqDto);    // todo : 실제 운영에서 주석 해제

        apiLogger.setStatus('SUCCESS');
        sum.ok++;
        sum.okMembers.add((String) memberId);
      } catch (Exception ex) {
        apiLogger.setStatus('ERROR');
        apiLogger.setErrorCode('MCE_FAIL');
        apiLogger.setErrorMessage(ex.getMessage());

        sum.ng++;
        sum.ngMembers.add((String) memberId);
        sum.failMsgs.add('MCE fail memberNo=' + memberNo + ' msg=' + ex.getMessage());
      } finally {
        apiLogger.setResponseDatetime(Datetime.now());
        apiLogger.addLog();
      }
    }

    return sum;
  }

  public static String deriveDirection(LoyaltyLedger ll) {
    if (ll == null) {
      return 'CREDIT';
    }
    if (ll.EventType == 'Debit') {
      return 'DEBIT';
    }
    if (ll.EventType == 'Credit') {
      return 'CREDIT';
    }
    Decimal p = ll.Points;
    return (p != null && p < 0) ? 'DEBIT' : 'CREDIT';
  }

  public class MemberAgg {
    public Id memberId;
    public Decimal creditTotal = 0;
    public Decimal debitTotal = 0;
    public LoyaltyLedger sampleLedger;
    public Id sampleTjId;
    public Datetime latestDt;
    public Decimal availableAfter = 0; // fallback

    public MemberAgg(Id mid) {
      memberId = mid;
    }

    public void add(String dir, Decimal points) {
      Decimal v = (points == null) ? 0 : points.abs();
      if (dir == 'DEBIT') {
        debitTotal += v;
      } else {
        creditTotal += v;
      }
    }
  }

  public class SendSummary {
    public Integer ok = 0;
    public Integer ng = 0;
    public Set<String> okMembers = new Set<String>();
    public Set<String> ngMembers = new Set<String>();
    public List<String> failMsgs = new List<String>();
  }
}