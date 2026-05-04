/**
 * 포인트 만료 처리 Batch Class (NO debitPoints)
 * - 만료(Expiry) 레저 생성 성공한 건들만 ERP 포인트 소멸 API로 전송
 *
 * @author Changhwan Kim
 * @since 2026-01-30
 */
public with sharing class LoyaltyPointExpirationBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String LOYALTY_PROGRAM_NAME = System.Label.LoyaltyProgramName;
  private static final Id LOYALTY_PROGRAM_ID = SObjectUtil.findIdByName(LoyaltyProgram.SObjectType, LOYALTY_PROGRAM_NAME, true);

  private static final String JOURNAL_TYPE_NAME_POINTS_EXPIRATION = 'Points Expiration';
  private static final String JOURNAL_SUB_TYPE_NAME_AUTO_EXPIRE = 'Auto Expire';

  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';
  private static final String LEDGER_EVENTTYPE_EXPIRE = 'Expiry';

  // ERP 요청의 id_insert(수정자) 값: 운영에서 구분 가능한 값으로
  private static final String ERP_ID_INSERT = UserInfo.getUserId();

  // ======= Stateful totals (credit ledger id 기준) =======
  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  // private Date expiryDate = Date.valueOf('2028-01-04');
  // private Date expiryDate = Date.today(); // todo: 실제 운영 시 주석 해제 // 기존 코드
  private Date expiryDate = Date.today().addDays(-1); // 신규 코드 [2026-04-24 Carson]


  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT Id, LoyaltyProgramMemberId, LoyaltyPgmCrcySubtypeId, ExpiryDate, EventType, Points, LoyaltyProgramCurrencyId
        FROM LoyaltyLedger
        WHERE EventType = 'Credit' AND LoyaltyPgmCrcySubtypeId != NULL AND ExpiryDate = :expiryDate AND Points > 0
        ORDER BY CreatedDate DESC
      ]
    );
  }

  public void execute(Database.BatchableContext bc, List<LoyaltyLedger> ledgerList) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(LoyaltyPointExpirationBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    if (ledgerList != null && !ledgerList.isEmpty()) {
      logger.setScopedIds((List<SObject>) ledgerList, 'Id');
    }

    Set<String> successIds = new Set<String>(); // creditLedgerId
    Set<String> failIds = new Set<String>(); // creditLedgerId
    List<String> failMsgs = new List<String>();

    Integer chunkSize = (ledgerList == null) ? 0 : ledgerList.size();
    Integer journalInsertFailMembers = 0;
    Integer expireLedgerInsertFailCnt = 0;
    Integer memberCurrencyUpdateFailCnt = 0;
    Integer journalUpdateFailCnt = 0;

    // ERP 전송용 payload (만료 레저 insert 성공한 건들만 담음)
    ErpPointReqDto.ExpiryRequest erpExpiryReq = new ErpPointReqDto.ExpiryRequest();
    Set<Id> expireJournalIdSetForCallback = new Set<Id>(); // ErpPointJob 추적용 저널 ID

    try {
      if (ledgerList == null || ledgerList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      // ProgramCurrencyId
      Id programCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      // Journal Type/SubType Id
      Id journalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_POINTS_EXPIRATION, true);
      Id journalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_AUTO_EXPIRE, true);

      // ============================================================
      // 0) credit ledger 캐시 + member 그룹
      // ============================================================
      Set<Id> creditLedgerIds = new Set<Id>();
      Map<Id, LoyaltyLedger> creditById = new Map<Id, LoyaltyLedger>();
      Map<Id, List<Id>> creditIdsByMemberId = new Map<Id, List<Id>>();

      for (LoyaltyLedger ll : ledgerList) {
        if (ll == null || ll.Id == null) {
          continue;
        }

        creditLedgerIds.add(ll.Id);
        creditById.put(ll.Id, ll);

        if (ll.LoyaltyProgramMemberId == null) {
          failIds.add((String) ll.Id);
          failMsgs.add('Missing LoyaltyProgramMemberId. creditLedgerId=' + ll.Id);
          continue;
        }

        if (!creditIdsByMemberId.containsKey(ll.LoyaltyProgramMemberId)) {
          creditIdsByMemberId.put(ll.LoyaltyProgramMemberId, new List<Id>());
        }
        creditIdsByMemberId.get(ll.LoyaltyProgramMemberId).add(ll.Id);
      }

      if (creditLedgerIds.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('no valid credit ledgers in scope');
        return;
      }

      // ============================================================
      // 1) Traceability 집계: creditLedgerId -> minusSum
      // ============================================================
      Map<Id, Decimal> minusSumByCreditLedgerId = new Map<Id, Decimal>();

      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId creditId, SUM(Points) minusSum
        FROM LoyaltyLedgerTraceability
        WHERE CreditLoyaltyLedgerId IN :creditLedgerIds AND ActionType IN ('CreditCancellation', 'Debit') AND Points > 0
        GROUP BY CreditLoyaltyLedgerId
      ]) {
        Id creditId = (Id) ar.get('creditId');
        Decimal minusSum = (Decimal) ar.get('minusSum');
        minusSumByCreditLedgerId.put(creditId, (minusSum == null) ? 0 : minusSum);
      }

      // ============================================================
      // 2) memberId별 ExpireItem 구성 (remaining 계산)
      // ============================================================
      Map<Id, List<ExpireItem>> itemsByMemberId = new Map<Id, List<ExpireItem>>();
      Integer targetCreditCnt = 0;
      Decimal targetPointsSum = 0;

      for (Id memberId : creditIdsByMemberId.keySet()) {
        for (Id creditId : creditIdsByMemberId.get(memberId)) {
          LoyaltyLedger credit = creditById.get(creditId);
          if (credit == null) {
            continue;
          }

          if (credit.LoyaltyPgmCrcySubtypeId == null) {
            failIds.add((String) creditId);
            failMsgs.add('Missing LoyaltyPgmCrcySubtypeId. creditLedgerId=' + creditId);
            continue;
          }

          Decimal credited = (credit.Points == null) ? 0 : credit.Points;
          Decimal minus = minusSumByCreditLedgerId.containsKey(creditId) ? minusSumByCreditLedgerId.get(creditId) : 0;
          Decimal remaining = credited - minus;

          if (remaining <= 0) {
            // 만료 불필요(전액 사용/취소)
            successIds.add((String) creditId);
            continue;
          }

          if (!itemsByMemberId.containsKey(memberId)) {
            itemsByMemberId.put(memberId, new List<ExpireItem>());
          }
          itemsByMemberId.get(memberId).add(new ExpireItem(creditId, credit.LoyaltyPgmCrcySubtypeId, remaining));

          targetCreditCnt++;
          targetPointsSum += remaining;
        }
      }

      if (itemsByMemberId.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('nothing to expire (all remaining <= 0 or invalid)');
        return;
      }

      // ============================================================
      // 3) memberId별 TransactionJournal 1개 생성
      // ============================================================
      List<TransactionJournal> tjToInsert = new List<TransactionJournal>();
      List<Id> memberIdByTjIndex = new List<Id>();

      for (Id memberId : itemsByMemberId.keySet()) {
        TransactionJournal tj = new TransactionJournal();
        tj.ActivityDate = Datetime.now();
        tj.JournalDate = Datetime.now();
        tj.LoyaltyProgramId = LOYALTY_PROGRAM_ID;
        tj.MemberId = memberId;
        tj.JournalTypeId = journalTypeId;
        tj.JournalSubTypeId = journalSubTypeId;
        tj.Status = 'Pending';

        tjToInsert.add(tj);
        memberIdByTjIndex.add(memberId);
      }

      Database.SaveResult[] tjInsertResults = Database.insert(tjToInsert, false);

      Map<Id, Id> journalIdByMemberId = new Map<Id, Id>();

      for (Integer i = 0; i < tjInsertResults.size(); i++) {
        Id memberId = memberIdByTjIndex[i];
        Database.SaveResult sr = tjInsertResults[i];

        if (sr.isSuccess()) {
          journalIdByMemberId.put(memberId, sr.getId());
        } else {
          journalInsertFailMembers++;
          String msg = 'Journal insert failed. memberId=' + memberId;
          for (Database.Error err : sr.getErrors()) {
            msg += ', ' + err.getMessage();
          }
          failMsgs.add(msg);

          for (ExpireItem it : itemsByMemberId.get(memberId)) {
            failIds.add((String) it.creditLedgerId);
          }
        }
      }

      // ============================================================
      // 4) 만료 LoyaltyLedger 직접 Insert
      //    + insert 성공한 Expiry 레저만 ERP 요청 모델로 구성
      // ============================================================
      List<LoyaltyLedger> expireLedgersToInsert = new List<LoyaltyLedger>();
      List<Id> creditIdByExpireLedgerIndex = new List<Id>();
      List<Id> memberIdByExpireLedgerIndex = new List<Id>();

      for (Id memberId : itemsByMemberId.keySet()) {
        if (!journalIdByMemberId.containsKey(memberId)) {
          continue;
        }

        Id journalId = journalIdByMemberId.get(memberId);

        for (ExpireItem it : itemsByMemberId.get(memberId)) {
          if (it.remainingPoints == null || it.remainingPoints <= 0 || it.currencySubtypeId == null) {
            failIds.add((String) it.creditLedgerId);
            failMsgs.add('Invalid expire item. creditLedgerId=' + it.creditLedgerId);
            continue;
          }

          LoyaltyLedger exp = new LoyaltyLedger();
          exp.LoyaltyProgramMemberId = memberId;
          exp.LoyaltyProgramCurrencyId = programCurrencyId;
          exp.LoyaltyPgmCrcySubtypeId = it.currencySubtypeId;
          exp.TransactionJournalId = journalId;
          exp.ActivityDate = Date.today();
          exp.ExpiryDate = expiryDate;
          exp.EventType = LEDGER_EVENTTYPE_EXPIRE;
          exp.Points = it.remainingPoints;

          expireLedgersToInsert.add(exp);
          creditIdByExpireLedgerIndex.add(it.creditLedgerId);
          memberIdByExpireLedgerIndex.add(memberId);
        }
      }

      Database.SaveResult[] expSrs = expireLedgersToInsert.isEmpty()
        ? new List<Database.SaveResult>()
        : Database.insert(expireLedgersToInsert, false);

      Map<Id, Integer> okCntByMember = new Map<Id, Integer>();
      Map<Id, Integer> ngCntByMember = new Map<Id, Integer>();

      for (Integer i = 0; i < expSrs.size(); i++) {
        Database.SaveResult sr = expSrs[i];
        Id creditId = creditIdByExpireLedgerIndex[i];
        Id memberId = memberIdByExpireLedgerIndex[i];
        LoyaltyLedger exp = expireLedgersToInsert[i];

        if (sr.isSuccess()) {
          successIds.add((String) creditId);
          okCntByMember.put(memberId, (okCntByMember.containsKey(memberId) ? okCntByMember.get(memberId) : 0) + 1);

          // ==========================================
          // ERP 요청값 구성 (요청 JSON 스펙과 동일)
          // ==========================================
          ErpPointReqDto.MbrPointUseModels item = new ErpPointReqDto.MbrPointUseModels();

          // cd_save_ledger : "지급된(원본) 레저 key"
          item.cd_save_ledger = ledgerKeyOfCredit(creditById.get(creditId));

          // pt_destory : 소멸 포인트(문자열)
          item.pt_destory = String.valueOf((exp.Points == null) ? 0 : exp.Points);

          // cd_use_ledger : "생성된 소멸 레저 key"
          item.cd_use_ledger = (String) sr.getId();

          // id_insert : 수정자(배치명/시스템)
          item.id_insert = ERP_ID_INSERT;

          erpExpiryReq.mbrPointUseModels.add(item);

          if (exp.TransactionJournalId != null) {
            expireJournalIdSetForCallback.add(exp.TransactionJournalId);
          }
        } else {
          expireLedgerInsertFailCnt++;
          failIds.add((String) creditId);
          ngCntByMember.put(memberId, (ngCntByMember.containsKey(memberId) ? ngCntByMember.get(memberId) : 0) + 1);

          String msg = 'Expire ledger insert failed. creditLedgerId=' + creditId;
          for (Database.Error err : sr.getErrors()) {
            msg += ', ' + err.getMessage();
          }
          failMsgs.add(msg);
        }
      }

      // ============================================================
      // 4.5) ERP 소멸 API 호출은 ErpPointJob 으로 비동기 처리
      // - execute 트랜잭션에는 DML이 있으므로 callout 직접 수행하면 위험
      // - "ErpCouponJob(...)" 패턴과 동일하게 enqueueJob
      // ============================================================
      if (erpExpiryReq.mbrPointUseModels != null && !erpExpiryReq.mbrPointUseModels.isEmpty()) {
        // NOTE: 한 execute당 queueable은 1개만 enqueue하여
        // "Too many queueable jobs added to queue: 2" 같은 이슈를 줄이는 방향

        DebugUtil.pretty('erpExpiryReq', erpExpiryReq);

        System.enqueueJob(
          new ErpPointJob(
            ErpPointJob.Operation.POINT_EXPIRY, // ← org 컨벤션에 맞게 Operation명 조정
            erpExpiryReq, // ← 요청 DTO
            new ErpPointAsyncCallback(), // ← 콜백
            expireJournalIdSetForCallback // ← ErpCouponJob(voucherIds)처럼 추적용
          )
        );
      }

      // ============================================================
      // 5) 멤버 커런시 업데이트 (기존 로직 유지)
      // ============================================================
      Map<Id, Decimal> successExpireSumByMember = new Map<Id, Decimal>();
      for (Integer i = 0; i < expSrs.size(); i++) {
        if (!expSrs[i].isSuccess()) {
          continue;
        }
        LoyaltyLedger exp = expireLedgersToInsert[i];
        Id mId = exp.LoyaltyProgramMemberId;
        Decimal cur = successExpireSumByMember.containsKey(mId) ? successExpireSumByMember.get(mId) : 0;
        successExpireSumByMember.put(mId, cur + ((exp.Points == null) ? 0 : exp.Points));
      }

      if (!successExpireSumByMember.isEmpty()) {
        Set<Id> memberIds = successExpireSumByMember.keySet();

        List<LoyaltyMemberCurrency> lmcList = [
          SELECT Id, LoyaltyMemberId, LoyaltyProgramCurrencyId, TotalPointsExpired
          FROM LoyaltyMemberCurrency
          WHERE LoyaltyMemberId IN :memberIds AND LoyaltyProgramCurrencyId = :programCurrencyId
        ];

        Map<Id, LoyaltyMemberCurrency> lmcByMemberId = new Map<Id, LoyaltyMemberCurrency>();
        for (LoyaltyMemberCurrency lmc : lmcList) {
          if (lmc.LoyaltyMemberId != null)
            lmcByMemberId.put(lmc.LoyaltyMemberId, lmc);
        }

        List<LoyaltyMemberCurrency> toUpdate = new List<LoyaltyMemberCurrency>();
        for (Id memberId : memberIds) {
          if (!lmcByMemberId.containsKey(memberId)) {
            memberCurrencyUpdateFailCnt++;
            failMsgs.add('LoyaltyMemberCurrency not found. memberId=' + memberId + ', currencyId=' + programCurrencyId);
            continue;
          }

          LoyaltyMemberCurrency lmc = lmcByMemberId.get(memberId);
          Decimal inc = successExpireSumByMember.get(memberId);

          // 누적/덮어쓰기 정책은 org 컨벤션에 맞게 선택
          // lmc.TotalPointsExpired = ((lmc.TotalPointsExpired == null) ? 0 : lmc.TotalPointsExpired) + inc;
          lmc.TotalPointsExpired = inc;

          toUpdate.add(lmc);
        }

        if (!toUpdate.isEmpty()) {
          Database.SaveResult[] mcsrs = Database.update(toUpdate, false);
          for (Integer i = 0; i < mcsrs.size(); i++) {
            if (!mcsrs[i].isSuccess()) {
              memberCurrencyUpdateFailCnt++;
              String msg = 'LoyaltyMemberCurrency update failed. id=' + toUpdate[i].Id;
              for (Database.Error err : mcsrs[i].getErrors()) {
                msg += ', ' + err.getMessage();
              }
              failMsgs.add(msg);
            }
          }
        }
      }

      // 성공한 건은 실패 목록에서 제거
      failIds.removeAll(successIds);

      // ============================================================
      // 6) TransactionJournal 상태 업데이트
      // ============================================================
      List<TransactionJournal> tjToUpdate = new List<TransactionJournal>();

      for (Id memberId : itemsByMemberId.keySet()) {
        if (!journalIdByMemberId.containsKey(memberId)) {
          continue;
        }

        Integer ok = okCntByMember.containsKey(memberId) ? okCntByMember.get(memberId) : 0;
        Integer ng = ngCntByMember.containsKey(memberId) ? ngCntByMember.get(memberId) : 0;

        String status;
        if (ng > 0 && ok > 0) {
          status = 'Error';
        } else if (ng > 0) {
          status = 'Error';
        } else {
          status = 'Processed';
        }

        TransactionJournal tj = new TransactionJournal();
        tj.Id = journalIdByMemberId.get(memberId);
        tj.Status = status;
        tjToUpdate.add(tj);
      }

      if (!tjToUpdate.isEmpty()) {
        Database.SaveResult[] tjUpdateResults = Database.update(tjToUpdate, false);
        for (Integer i = 0; i < tjUpdateResults.size(); i++) {
          if (!tjUpdateResults[i].isSuccess()) {
            journalUpdateFailCnt++;
            String msg = 'TransactionJournal update failed. id=' + tjToUpdate[i].Id;
            for (Database.Error err : tjUpdateResults[i].getErrors()) {
              msg += ', ' + err.getMessage();
            }
            failMsgs.add(msg);
          }
        }
      }

      // ============================================================
      // 7) logger 상태/설명
      // ============================================================
      Boolean hasAnyFail =
        !failIds.isEmpty() ||
        journalInsertFailMembers > 0 ||
        expireLedgerInsertFailCnt > 0 ||
        memberCurrencyUpdateFailCnt > 0 ||
        journalUpdateFailCnt > 0;

      Boolean hasAnySuccess = !successIds.isEmpty() || !expireLedgersToInsert.isEmpty();

      if (hasAnyFail && hasAnySuccess) {
        logger.setStatus('PARTIAL');
      } else if (hasAnyFail) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription(
        'chunkSize=' +
          chunkSize +
          ', creditLedgers=' +
          creditLedgerIds.size() +
          ', erpItems=' +
          (erpExpiryReq.mbrPointUseModels == null ? 0 : erpExpiryReq.mbrPointUseModels.size()) +
          ', journalInsertFailMembers=' +
          journalInsertFailMembers +
          ', expireLedgerInsertFailCnt=' +
          expireLedgerInsertFailCnt +
          ', memberCurrencyUpdateFailCnt=' +
          memberCurrencyUpdateFailCnt +
          ', journalUpdateFailCnt=' +
          journalUpdateFailCnt +
          ', successCredits=' +
          successIds.size() +
          ', failCredits=' +
          failIds.size()
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
    } finally {
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      if (!successIds.isEmpty()) {
        logger.setSuccessRecordIds(successIds);
      }
      if (!failIds.isEmpty()) {
        logger.setFailedRecordIds(failIds);
      }
      if (!failMsgs.isEmpty()) {
        logger.setErrorMessage(String.join(failMsgs, ' | '));
      }

      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  public void finish(Database.BatchableContext bc) {
    totalFail.removeAll(totalSuccess);

    Integer successCnt = totalSuccess.size();
    Integer failCnt = totalFail.size();

    String status;
    SchedulerNotificationPublisher.ResultStatus notifStatus;

    if (failCnt > 0 && successCnt > 0) {
      status = 'PARTIAL';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.PARTIAL;
    } else if (failCnt > 0) {
      status = 'ERROR';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.ERROR;
    } else {
      status = 'SUCCESS';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.SUCCESS;
    }

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(LoyaltyPointExpirationBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL successCredits=' + successCnt + ', failCredits=' + failCnt);
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();

    String msg = 'Status=' + status + ', success=' + successCnt + ', fail=' + failCnt + ', jobId=' + bc.getJobId();
    SchedulerNotificationPublisher.publishResult('LoyaltyPointExpirationBatch', notifStatus, msg, bc.getJobId(), null);
  }

  // ===== helper dto =====
  public class ExpireItem {
    public Id creditLedgerId;
    public Id currencySubtypeId;
    public Decimal remainingPoints;

    public ExpireItem(Id creditLedgerId, Id currencySubtypeId, Decimal remainingPoints) {
      this.creditLedgerId = creditLedgerId;
      this.currencySubtypeId = currencySubtypeId;
      this.remainingPoints = remainingPoints;
    }
  }

  /**
   * cd_save_ledger(원 지급 레저 key) 매핑 지점
   * - 현재는 Salesforce LoyaltyLedger.Id를 key로 사용
   * - ERP key를 써야 한다면 여기에서 치환(예: credit에 저장된 외부키 값을 리턴)
   */
  private static String ledgerKeyOfCredit(LoyaltyLedger credit) {
    if (credit == null || credit.Id == null) {
      return null;
    }
    return (String) credit.Id;
  }
}