public with sharing class GdTransactionJournalTriggerHandler extends TriggerHandler {
  // =========================
  // Constants (Names)
  // =========================
  private static final String SUBTYPE_POINT_DEBIT = 'Point Debit'; // 포인트 사용
  private static final String SUBTYPE_POINT_REDEEM_CANCEL = 'Point Redeem Cancel'; // 포인트 사용 취소
  private static final String SUBTYPE_PURCHASE_ACCRUAL = 'Purchase Accrual'; // 구매 시 포인트 지급
  private static final String SUBTYPE_MANUAL_POINTS_CREDIT = 'Manual Points Credit';
  private static final String SUBTYPE_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual'; // 구매 시 포인트 적립 취소
  private static final String SUBTYPE_AUTO_EXPIRE = 'Auto Expire';
  private static final String SUBTYPE_API_FORCED_EXPIRE = 'Api Forced Expire';
  private static final String SUBTYPE_API_FORCED_DEBIT = 'Api Forced Debit';
  private static final String SUBTYPE_API_FORCED_CREDIT = 'Api Forced Credit'; // API 요청에 의한 포인트 강제 지급(적립) 처리
  private static final String SUBTYPE_PROMOTION_POINT_ACCRUAL = 'Promotion Point Accrual'; // 프로모션 포인트 지급
  private static final String SUBTYPE_PROMOTION_POINT_ACCRUAL_REVERSAL = 'Promotion Point Accrual Reversal'; // 프로모션 포인트 지급 취소

  private static final String PROGRAM_CURRENCY_POINT_NAME = '포인트';

  // =========================
  // Recursion Guard
  // =========================
  private static Boolean isRunning = false;
  private static Map<String, Id> cachedSubTypeIdByName;
  private static Id cachedPointCurrencyId;
  private static Boolean pointCurrencyLoaded = false;

  // AggrKey util (inner class static method 금지 회피)
  private static final AggrKey KEY_UTIL = new AggrKey();

  public GdTransactionJournalTriggerHandler() {
    this.setMaxLoopCount(10);
  }

  public override void afterUpdate() {
    if (isRunning) {
      return;
    }
    isRunning = true;

    // ---- logger 관련 변수 (조건 충족 시에만 생성) ----
    ApexLogger logger;
    Boolean shouldLogBulkExpire = false;

    try {
      List<TransactionJournal> newList = (List<TransactionJournal>) Trigger.new;
      if (newList == null || newList.isEmpty()) {
        return;
      }

      // 0) 필요한 SubType Id들을 한 번에 조회해서 맵 구성
      Set<String> subTypeNames = getAggregationSubTypeNames();
      Map<String, Id> subTypeIdByName = getSubTypeIdByName(subTypeNames);

      Set<Id> allowedSubTypeIds = new Set<Id>();
      for (String nm : subTypeNames) {
        if (subTypeIdByName.containsKey(nm)) {
          allowedSubTypeIds.add(subTypeIdByName.get(nm));
        }
      }

      if (allowedSubTypeIds.isEmpty()) {
        System.debug('[GdTransactionJournalTriggerHandler] WARN: No JournalSubType IDs resolved. Check names.');
        return;
      }

      // 0-1) LoyaltyProgramCurrency(포인트) Id 조회
      Id pointCurrencyId = getPointCurrencyId();
      if (pointCurrencyId == null) {
        System.debug('[GdTransactionJournalTriggerHandler] WARN: LoyaltyProgramCurrency not found. name=' + PROGRAM_CURRENCY_POINT_NAME);
        return;
      }

      // 1) 이번 트랜잭션에서 처리할 TJ만 수집
      Map<Id, TransactionJournal> targetTjById = new Map<Id, TransactionJournal>();

      // “포인트 소멸” SubType (Auto Expire / Api Forced Expire) 카운트로 "단체 소멸" 여부 판단
      Id autoExpireId = subTypeIdByName.get(SUBTYPE_AUTO_EXPIRE);
      Id apiForcedExpireId = subTypeIdByName.get(SUBTYPE_API_FORCED_EXPIRE);
      Integer expireTjCount = 0;

      for (TransactionJournal tj : newList) {
        TransactionJournal oldTj = (TransactionJournal) Trigger.oldMap.get(tj.Id);
        if (oldTj == null) {
          continue;
        }

        if (oldTj.Status == 'Pending' && tj.Status == 'Processed' && allowedSubTypeIds.contains(tj.JournalSubTypeId)) {
          targetTjById.put(tj.Id, tj);

          if (tj.JournalSubTypeId != null && (tj.JournalSubTypeId == autoExpireId || tj.JournalSubTypeId == apiForcedExpireId)) {
            expireTjCount++;
          }
        }
      }

      if (targetTjById.isEmpty()) {
        return;
      }

      // "포인트 소멸"이면서 "단체(2건 이상)"일 때만 ApexLogger 사용
      if (expireTjCount >= 2) {
        shouldLogBulkExpire = true;

        // ---- ApexLogger 초기화 (너희 조직 ApexLogger 생성자/메서드명에 맞게 필요 시 조정) ----
        // 예: new ApexLogger(ApexLogger.JobType.TRIGGER, null, null) 처럼 사용하는 조직도 있음
        logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, null, null);
        logger.logging(GdTransactionJournalTriggerHandler.class.getName());
        logger.setRequestDatetime(Datetime.now());

        // 처리 대상 TJ id들 스코프 기록(가능할 때만)
        try {
          logger.setScopedIds((List<SObject>) targetTjById.values(), 'Id');
        } catch (Exception e) {
          // logger 유틸이 특정 타입만 허용하는 경우 대비
          System.debug('[GdTransactionJournalTriggerHandler] logger.setScopedIds failed: ' + e.getMessage());
        }

        logger.setDescription('Bulk point expiration detected. expireTjCount=' + String.valueOf(expireTjCount));
        logger.setStatus('START');
      }

      // 2) Bulk 집계 실행
      AggrConfig cfg = new AggrConfig(subTypeIdByName, pointCurrencyId);

      if (shouldLogBulkExpire) {
        // logger에 핵심 파라미터를 남겨두면 운영 시 추적 편함
        System.debug('[GdTransactionJournalTriggerHandler] Bulk expire logging enabled. targetTJ=' + targetTjById.size());
      }

      createLoyaltyAggrSubPointExprLedgerBulk(targetTjById, cfg, logger, shouldLogBulkExpire, true);

      if (shouldLogBulkExpire && logger != null) {
        logger.setStatus('SUCCESS');
        logger.setDescription('Bulk point expiration aggregation completed. targetTJ=' + targetTjById.size());
      }
    } catch (Exception ex) {
      if (shouldLogBulkExpire && logger != null) {
        logger.setStatus('ERROR');
        logger.setErrorCode('EXCEPTION');
        logger.setErrorMessage(ex.getMessage());
        logger.setDescription('Exception in afterUpdate: ' + ex.getTypeName());
      }
      throw ex;
    } finally {
      // 예외가 나도 반드시 원복
      isRunning = false;

      // logger finalize (너희 ApexLogger가 save/flush 개념이 있으면 여기에)
      if (shouldLogBulkExpire && logger != null) {
        try {
          // 예: logger.save(); logger.flush(); 같은 메서드가 있으면 여기서 호출
          // 조직별 구현이 달라서 기본은 System.debug로 둠
          System.debug('[GdTransactionJournalTriggerHandler] ApexLogger finalized.');
        } catch (Exception e) {
          System.debug('[GdTransactionJournalTriggerHandler] ApexLogger finalize failed: ' + e.getMessage());
        }
      }
    }
  }

  private static Set<String> getAggregationSubTypeNames() {
    return new Set<String>{
      SUBTYPE_POINT_DEBIT,
      SUBTYPE_POINT_REDEEM_CANCEL,
      SUBTYPE_PURCHASE_ACCRUAL,
      SUBTYPE_CANCEL_PURCHASE_ACCRUAL,
      SUBTYPE_MANUAL_POINTS_CREDIT,
      SUBTYPE_API_FORCED_EXPIRE,
      SUBTYPE_API_FORCED_DEBIT,
      SUBTYPE_API_FORCED_CREDIT,
      SUBTYPE_AUTO_EXPIRE,
      SUBTYPE_PROMOTION_POINT_ACCRUAL,
      SUBTYPE_PROMOTION_POINT_ACCRUAL_REVERSAL
    };
  }

  private static Map<String, Id> getSubTypeIdByName(Set<String> subTypeNames) {
    if (cachedSubTypeIdByName == null) {
      cachedSubTypeIdByName = new Map<String, Id>();
      for (JournalSubType jst : [
        SELECT Id, Name
        FROM JournalSubType
        WHERE Name IN :subTypeNames
      ]) {
        cachedSubTypeIdByName.put(jst.Name, jst.Id);
      }
    }
    return cachedSubTypeIdByName.clone();
  }

  private static Id getPointCurrencyId() {
    if (!pointCurrencyLoaded) {
      pointCurrencyLoaded = true;
      List<LoyaltyProgramCurrency> lpc = [
        SELECT Id
        FROM LoyaltyProgramCurrency
        WHERE Name = :PROGRAM_CURRENCY_POINT_NAME
        LIMIT 1
      ];
      if (!lpc.isEmpty()) {
        cachedPointCurrencyId = lpc[0].Id;
      }
    }
    return cachedPointCurrencyId;
  }

  @TestVisible
  private static void clearCacheForTest() {
    cachedSubTypeIdByName = null;
    cachedPointCurrencyId = null;
    pointCurrencyLoaded = false;
  }

  public static void aggregateProcessedTransactionJournals(Set<Id> tjIds) {
    if (tjIds == null || tjIds.isEmpty()) {
      return;
    }

    Set<String> subTypeNames = getAggregationSubTypeNames();
    Map<String, Id> subTypeIdByName = getSubTypeIdByName(subTypeNames);
    Id pointCurrencyId = getPointCurrencyId();
    if (pointCurrencyId == null) {
      System.debug('[GdTransactionJournalTriggerHandler] WARN: LoyaltyProgramCurrency not found in retry.');
      return;
    }

    Set<Id> allowedSubTypeIds = new Set<Id>();
    for (String nm : subTypeNames) {
      if (subTypeIdByName.containsKey(nm)) {
        allowedSubTypeIds.add(subTypeIdByName.get(nm));
      }
    }

    Map<Id, TransactionJournal> targetTjById = new Map<Id, TransactionJournal>();
    for (TransactionJournal tj : [
      SELECT Id, JournalSubTypeId, Status
      FROM TransactionJournal
      WHERE Id IN :tjIds AND Status = 'Processed' AND JournalSubTypeId IN :allowedSubTypeIds
    ]) {
      targetTjById.put(tj.Id, tj);
    }

    if (targetTjById.isEmpty()) {
      return;
    }

    createLoyaltyAggrSubPointExprLedgerBulk(targetTjById, new AggrConfig(subTypeIdByName, pointCurrencyId), null, false, false);
  }

  // =========================
  // Bulk 집계 핵심
  // =========================
  private static void createLoyaltyAggrSubPointExprLedgerBulk(
    Map<Id, TransactionJournal> tjById,
    AggrConfig cfg,
    ApexLogger logger,
    Boolean shouldLogBulkExpire,
    Boolean allowRetry
  ) {
    Set<Id> tjIds = tjById.keySet();
    if (tjIds.isEmpty()) {
      return;
    }

    // (A) Ledger를 TJ 전체에 대해 한 번에 조회
    List<LoyaltyLedger> llList = [
      SELECT Id, TransactionJournalId, LoyaltyProgramMemberId, ExpiryDate, EventType, Points, LoyaltyPgmCrcySubtypeId, LoyaltyPgmCrcySubtype.Name
      FROM LoyaltyLedger
      WHERE TransactionJournalId IN :tjIds
      LIMIT 50000
    ];

    if (llList.isEmpty()) {
      if (shouldLogBulkExpire && logger != null) {
        logger.setDescription('No LoyaltyLedger rows found. tjCount=' + tjIds.size());
      }
      enqueueAggregationRetry(tjIds, allowRetry);
      return;
    }

    Set<Id> tjIdsWithLedger = new Set<Id>();
    for (LoyaltyLedger ll : llList) {
      if (ll != null && ll.TransactionJournalId != null) {
        tjIdsWithLedger.add(ll.TransactionJournalId);
      }
    }
    Set<Id> missingLedgerTjIds = new Set<Id>(tjIds);
    missingLedgerTjIds.removeAll(tjIdsWithLedger);
    enqueueAggregationRetry(missingLedgerTjIds, allowRetry);

    if (shouldLogBulkExpire && logger != null) {
      logger.setDescription('Ledger fetched. ledgerRows=' + llList.size());
    }

    // Debit ledger ids 모아서 Traceability도 한 번에 조회
    Set<Id> debitLedgerIds = new Set<Id>();
    for (LoyaltyLedger ll : llList) {
      if (ll != null && 'Debit'.equals(ll.EventType)) {
        debitLedgerIds.add(ll.Id);
      }
    }

    // (B) Traceability를 한 번에 조회
    Map<Id, List<LoyaltyLedgerTraceability>> traceByDebitLedgerId = new Map<Id, List<LoyaltyLedgerTraceability>>();
    if (!debitLedgerIds.isEmpty()) {
      for (LoyaltyLedgerTraceability llt : [
        SELECT
          Id,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtypeId,
          LoyaltyPgmCurrencySubtype.Name,
          CreditLoyaltyLedger.ExpiryDate,
          Points,
          ActionType
        FROM LoyaltyLedgerTraceability
        WHERE DebitLoyaltyLedgerId IN :debitLedgerIds AND ActionType = 'Debit'
        LIMIT 50000
      ]) {
        if (llt.DebitLoyaltyLedgerId == null) {
          continue;
        }

        if (!traceByDebitLedgerId.containsKey(llt.DebitLoyaltyLedgerId)) {
          traceByDebitLedgerId.put(llt.DebitLoyaltyLedgerId, new List<LoyaltyLedgerTraceability>());
        }
        traceByDebitLedgerId.get(llt.DebitLoyaltyLedgerId).add(llt);
      }
    }

    if (shouldLogBulkExpire && logger != null) {
      logger.setDescription('Trace fetched. debitLedger=' + debitLedgerIds.size() + ', traceKeys=' + traceByDebitLedgerId.size());
    }

    // (C) (member, subtype, expiry)별 집계
    Map<String, AggrValue> keyToAggrMap = new Map<String, AggrValue>();
    Set<Id> memberIds = new Set<Id>();
    Set<Id> subtypeIds = new Set<Id>();
    Set<Date> expiryDates = new Set<Date>();

    Set<Id> creditTjIds = new Set<Id>(); // MCE 발송을 위한 객체
    Set<Id> debitTjIds = new Set<Id>(); // MCE 발송을 위한 객체

    for (LoyaltyLedger ll : llList) {
      if (ll == null || ll.TransactionJournalId == null) {
        continue;
      }

      TransactionJournal tj = tjById.get(ll.TransactionJournalId);
      if (tj == null) {
        continue;
      }

      Id memberId = ll.LoyaltyProgramMemberId;
      if (memberId == null) {
        continue;
      }

      memberIds.add(memberId);

      Decimal pts = (ll.Points == null) ? 0 : ll.Points;

      // ===== Credit 처리 =====
      if ('Credit'.equals(ll.EventType)) {
        if (ll.LoyaltyPgmCrcySubtypeId == null || ll.ExpiryDate == null) {
          continue;
        }

        Id subtypeId = ll.LoyaltyPgmCrcySubtypeId;
        Date expDate = ll.ExpiryDate;
        String subtypeName = (ll.LoyaltyPgmCrcySubtype != null) ? ll.LoyaltyPgmCrcySubtype.Name : null;

        String key = KEY_UTIL.toKey(memberId, subtypeId, expDate);
        AggrValue val = keyToAggrMap.containsKey(key) ? keyToAggrMap.get(key) : new AggrValue();
        val.loyaltyPgmCrcySubtypeName = subtypeName;

        if (tj.JournalSubTypeId == cfg.pointRedeemCancelId) {
          // [v3 fix 2026-04-24] Trace 보존 모델 기반 분기:
          //   Flag ON  = v3 Trace 보존 → 원본 Debit Trace 가 그대로 남음.
          //              재적립 Credit 을 Accrued 로 반영. Red 는 추가 차감 불필요.
          //   Flag OFF = v1/v2 경로 (Trace 삭제 전제) → 기존 로직 Red -= pts 유지.
          //
          // 과거 Bug 3 Flag 'Aggr_IncludeCancelInAccrued' 는 v3 Flag 로 통합됨
          // (Trace 삭제 상태에서 Acc += 만 단독으로 걸면 help-info 과다 표시되는 부작용 확인).
          if (GdFeatureFlag.isEnabled('PointCancel_PreserveTrace')) {
            val.totalAccrualPoint += pts;
          } else {
            val.totalRedeemPoint -= pts;
          }
        } else if (
          tj.JournalSubTypeId == cfg.purchaseAccrualId ||
          tj.JournalSubTypeId == cfg.manualPointsCreditId ||
          tj.JournalSubTypeId == cfg.apiForcedCreditId ||
          tj.JournalSubTypeId == cfg.promotionPointAccrualId
        ) {
          val.totalAccrualPoint += pts;
        }

        keyToAggrMap.put(key, val);
        subtypeIds.add(subtypeId);
        expiryDates.add(expDate);

        // if (tj.JournalSubTypeName__c == SUBTYPE_PURCHASE_ACCRUAL || tj.JournalSubTypeName__c == SUBTYPE_POINT_REDEEM_CANCEL) {
        //   System.debug('포함1');
        //   creditTjIds.add(tj.Id);
        // }
      }
      // ===== Debit 처리 =====
      else if ('Debit'.equals(ll.EventType)) {
        List<LoyaltyLedgerTraceability> traces = traceByDebitLedgerId.get(ll.Id);
        if (traces == null || traces.isEmpty()) {
          continue;
        }

        for (LoyaltyLedgerTraceability llt : traces) {
          if (llt.LoyaltyPgmCurrencySubtypeId == null) {
            continue;
          }
          if (llt.CreditLoyaltyLedger == null || llt.CreditLoyaltyLedger.ExpiryDate == null) {
            continue;
          }

          Decimal tPts = (llt.Points == null) ? 0 : llt.Points;

          Id subtypeId = llt.LoyaltyPgmCurrencySubtypeId;
          Date expDate = llt.CreditLoyaltyLedger.ExpiryDate;
          String subtypeName = (llt.LoyaltyPgmCurrencySubtype != null) ? llt.LoyaltyPgmCurrencySubtype.Name : null;

          String key = KEY_UTIL.toKey(memberId, subtypeId, expDate);
          AggrValue val = keyToAggrMap.containsKey(key) ? keyToAggrMap.get(key) : new AggrValue();
          val.loyaltyPgmCrcySubtypeName = subtypeName;

          if (tj.JournalSubTypeId == cfg.pointDebitId) {
            val.totalRedeemPoint += tPts;
          } else if (
            tj.JournalSubTypeId == cfg.cancelPurchaseAccrualId ||
            tj.JournalSubTypeId == cfg.promotionPointAccrualReversalId ||
            tj.JournalSubTypeId == cfg.apiForcedDebitId
          ) {
            val.totalAccrualPoint -= tPts;
          } else if (tj.JournalSubTypeId == cfg.apiForcedExpireId) {
            val.totalExprPoint += tPts;
          }

          keyToAggrMap.put(key, val);
          subtypeIds.add(subtypeId);
          expiryDates.add(expDate);

          // if (tj.JournalSubTypeName__c == SUBTYPE_POINT_DEBIT || tj.JournalSubTypeName__c == SUBTYPE_CANCEL_PURCHASE_ACCRUAL) {
          //   System.debug('포함2');
          //   debitTjIds.add(tj.Id);
          // }
        }
      }
      // ===== Expiry 처리 =====
      else if ('Expiry'.equals(ll.EventType)) {
        if (ll.LoyaltyPgmCrcySubtypeId == null || ll.ExpiryDate == null) {
          continue;
        }

        Id subtypeId = ll.LoyaltyPgmCrcySubtypeId;
        Date expDate = ll.ExpiryDate;
        String subtypeName = (ll.LoyaltyPgmCrcySubtype != null) ? ll.LoyaltyPgmCrcySubtype.Name : null;

        String key = KEY_UTIL.toKey(memberId, subtypeId, expDate);
        AggrValue val = keyToAggrMap.containsKey(key) ? keyToAggrMap.get(key) : new AggrValue();
        val.loyaltyPgmCrcySubtypeName = subtypeName;

        if (
          tj.JournalSubTypeId == cfg.autoExpireId ||
          tj.JournalSubTypeId == cfg.apiForcedExpireId ||
          tj.JournalSubTypeId == cfg.pointRedeemCancelId
        ) {
          val.totalExprPoint += pts;
        }

        keyToAggrMap.put(key, val);
        subtypeIds.add(subtypeId);
        expiryDates.add(expDate);
      }
    }

    if (!debitTjIds.isEmpty()) {
      // enqueueMceJobs(McePointJob.Operation.DEBIT_POINT, debitTjIds, 25);
    }

    if (!creditTjIds.isEmpty()) {
      // enqueueMceJobs(McePointJob.Operation.CREDIT_POINT, creditTjIds, 25);
    }

    if (keyToAggrMap.isEmpty()) {
      if (shouldLogBulkExpire && logger != null) {
        logger.setDescription('Aggregation map is empty. ledgerRows=' + llList.size());
      }
      return;
    }

    // (D) 기존 집계 레코드 조회
    Map<String, LoyaltyAggrSubPointExprLedger__c> existingByKey = new Map<String, LoyaltyAggrSubPointExprLedger__c>();

    if (!memberIds.isEmpty() && !subtypeIds.isEmpty() && !expiryDates.isEmpty()) {
      for (LoyaltyAggrSubPointExprLedger__c ex : [
        SELECT
          Id,
          LoyaltyProgramMemberId__c,
          CurrencySubTypeId__c,
          ExpiryDate__c,
          RedeemedPoints__c,
          AccruedPoints__c,
          ExpiredPoints__c,
          CurrencySubTypeName__c
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE LoyaltyProgramMemberId__c IN :memberIds AND CurrencySubTypeId__c IN :subtypeIds AND ExpiryDate__c IN :expiryDates
        LIMIT 50000
      ]) {
        String key = KEY_UTIL.toKey(ex.LoyaltyProgramMemberId__c, ex.CurrencySubTypeId__c, ex.ExpiryDate__c);
        existingByKey.put(key, ex);
      }
    }

    // (E) Insert/Update 리스트
    List<LoyaltyAggrSubPointExprLedger__c> insertList = new List<LoyaltyAggrSubPointExprLedger__c>();
    List<LoyaltyAggrSubPointExprLedger__c> updateList = new List<LoyaltyAggrSubPointExprLedger__c>();

    for (String key : keyToAggrMap.keySet()) {
      AggrValue val = keyToAggrMap.get(key);
      AggrKeyParts parts = KEY_UTIL.parse(key);
      if (parts == null) {
        continue;
      }

      if (existingByKey.containsKey(key)) {
        LoyaltyAggrSubPointExprLedger__c aggr = existingByKey.get(key);
        aggr.RedeemedPoints__c = (aggr.RedeemedPoints__c == null ? 0 : aggr.RedeemedPoints__c) + val.totalRedeemPoint;
        aggr.AccruedPoints__c = (aggr.AccruedPoints__c == null ? 0 : aggr.AccruedPoints__c) + val.totalAccrualPoint;
        aggr.ExpiredPoints__c = (aggr.ExpiredPoints__c == null ? 0 : aggr.ExpiredPoints__c) + val.totalExprPoint;
        aggr.CurrencySubTypeName__c = val.loyaltyPgmCrcySubtypeName;
        updateList.add(aggr);
      } else {
        insertList.add(
          new LoyaltyAggrSubPointExprLedger__c(
            LoyaltyProgramMemberId__c = parts.memberId,
            CurrencySubTypeId__c = parts.subtypeId,
            ExpiryDate__c = parts.expiryDate,
            CurrencySubTypeName__c = val.loyaltyPgmCrcySubtypeName,
            RedeemedPoints__c = val.totalRedeemPoint,
            AccruedPoints__c = val.totalAccrualPoint,
            ExpiredPoints__c = val.totalExprPoint,
            LoyaltyProgramCurrencyId__c = cfg.pointCurrencyId
          )
        );
      }
    }

    if (shouldLogBulkExpire && logger != null) {
      logger.setDescription('Prepared DML. insert=' + insertList.size() + ', update=' + updateList.size());
    }

    // (F) DML (부분 성공) + 로그
    if (!insertList.isEmpty()) {
      Database.SaveResult[] ins = Database.insert(insertList, false);
      logSaveResults('Aggr INSERT', ins, insertList);

      if (shouldLogBulkExpire && logger != null) {
        Integer insFail = countFailures(ins);
        logger.setDescription('Insert done. success=' + (ins.size() - insFail) + ', fail=' + insFail);
      }
    }

    if (!updateList.isEmpty()) {
      Database.SaveResult[] upd = Database.update(updateList, false);
      logSaveResults('Aggr UPDATE', upd, updateList);

      if (shouldLogBulkExpire && logger != null) {
        Integer updFail = countFailures(upd);
        logger.setDescription('Update done. success=' + (upd.size() - updFail) + ', fail=' + updFail);
      }
    }
  }

  private static Integer countFailures(Database.SaveResult[] srs) {
    if (srs == null) {
      return 0;
    }

    Integer fail = 0;
    for (Integer i = 0; i < srs.size(); i++) {
      if (!srs[i].isSuccess()) {
        fail++;
      }
    }
    return fail;
  }

  private static void enqueueAggregationRetry(Set<Id> tjIds, Boolean allowRetry) {
    if (!allowRetry || tjIds == null || tjIds.isEmpty()) {
      return;
    }

    System.enqueueJob(new GdPointAggrRetryQueueable(new List<Id>(tjIds)));
  }

  // =========================
  // Logging helper
  // =========================
  private static void logSaveResults(String label, Database.SaveResult[] srs, List<SObject> records) {
    if (srs == null) {
      return;
    }

    Integer fail = 0;
    for (Integer i = 0; i < srs.size(); i++) {
      if (!srs[i].isSuccess()) {
        fail++;

        String msg = '[' + label + '] failed idx=' + i;
        for (Database.Error e : srs[i].getErrors()) {
          msg += ' | ' + e.getStatusCode() + ': ' + e.getMessage();
        }
        System.debug(msg);
      }
    }

    if (fail > 0) {
      System.debug('[' + label + '] failures=' + fail + '/' + srs.size());
    }
  }

  // =========================
  // Config holder
  // =========================
  private class AggrConfig {
    public Id pointDebitId;
    public Id pointRedeemCancelId;
    public Id purchaseAccrualId;
    public Id manualPointsCreditId;
    public Id cancelPurchaseAccrualId;
    public Id autoExpireId;
    public Id apiForcedExpireId;
    public Id apiForcedDebitId;
    public Id apiForcedCreditId;
    public Id promotionPointAccrualId;
    public Id promotionPointAccrualReversalId;

    public Id pointCurrencyId;

    public AggrConfig(Map<String, Id> subTypeIdByName, Id pointCurrencyId) {
      this.pointDebitId = subTypeIdByName.get(SUBTYPE_POINT_DEBIT);
      this.pointRedeemCancelId = subTypeIdByName.get(SUBTYPE_POINT_REDEEM_CANCEL);
      this.purchaseAccrualId = subTypeIdByName.get(SUBTYPE_PURCHASE_ACCRUAL);
      this.manualPointsCreditId = subTypeIdByName.get(SUBTYPE_MANUAL_POINTS_CREDIT);
      this.cancelPurchaseAccrualId = subTypeIdByName.get(SUBTYPE_CANCEL_PURCHASE_ACCRUAL);
      this.autoExpireId = subTypeIdByName.get(SUBTYPE_AUTO_EXPIRE);
      this.apiForcedExpireId = subTypeIdByName.get(SUBTYPE_API_FORCED_EXPIRE);
      this.apiForcedDebitId = subTypeIdByName.get(SUBTYPE_API_FORCED_DEBIT);
      this.apiForcedCreditId = subTypeIdByName.get(SUBTYPE_API_FORCED_CREDIT);
      this.promotionPointAccrualId = subTypeIdByName.get(SUBTYPE_PROMOTION_POINT_ACCRUAL);
      this.promotionPointAccrualReversalId = subTypeIdByName.get(SUBTYPE_PROMOTION_POINT_ACCRUAL_REVERSAL);

      this.pointCurrencyId = pointCurrencyId;
    }
  }

  // =========================
  // helper (instance methods)
  // =========================
  private class AggrKey {
    public String toKey(Id memberId, Id subtypeId, Date expDate) {
      return String.valueOf(memberId) + '|' + String.valueOf(subtypeId) + '|' + String.valueOf(expDate);
    }

    public AggrKeyParts parse(String key) {
      if (String.isBlank(key)) {
        return null;
      }

      List<String> p = key.split('\\|');
      if (p.size() != 3) {
        return null;
      }

      AggrKeyParts r = new AggrKeyParts();
      try {
        r.memberId = (Id) p[0];
        r.subtypeId = (Id) p[1];
        r.expiryDate = Date.valueOf(p[2]);
      } catch (Exception e) {
        return null;
      }
      return r;
    }
  }

  private class AggrKeyParts {
    public Id memberId;
    public Id subtypeId;
    public Date expiryDate;
  }

  private class AggrValue {
    public Decimal totalRedeemPoint = 0;
    public Decimal totalAccrualPoint = 0;
    public Decimal totalExprPoint = 0;
    public String loyaltyPgmCrcySubtypeName;
  }

  // private static void enqueueMceJobs(McePointJob.Operation op, Set<Id> tjIds, Integer chunkSize) {
  //   if (tjIds == null || tjIds.isEmpty()) {
  //     return;
  //   }

  //   Integer size = (chunkSize == null || chunkSize <= 0) ? 25 : chunkSize;

  //   List<Id> ids = new List<Id>(tjIds);

  //   Integer enqueued = 0;
  //   for (Integer i = 0; i < ids.size(); i += size) {
  //     List<Id> chunk = new List<Id>();
  //     Integer endIdx = Math.min(i + size, ids.size());

  //     for (Integer j = i; j < endIdx; j++) {
  //       chunk.add(ids[j]);
  //     }

  //     enqueued++;
  //     if (enqueued > 50) {
  //       // 여기서 남은 건 저장 후 재처리 추천.
  //       // 지금은 안전하게 종료(또는 예외) 중 택1
  //       // throw new LimitException('Too many queueables enqueued in one transaction. enqueued=' + enqueued);
  //       break;
  //     }

  //     // System.enqueueJob(new McePointJob(op, chunk));
  //   }
  // }
}