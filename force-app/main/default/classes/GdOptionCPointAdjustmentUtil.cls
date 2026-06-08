public with sharing class GdOptionCPointAdjustmentUtil {
  private static final Integer MAX_ADDITIONAL_NOTES_LENGTH = 255;
  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';

  // [Non-Accrual Store Guard 2026-05-20] 적립 불가 매장 코드 set.
  //   기준: GdSaleDepositServiceImpl.createSaleDepositHistory line 541-546 의 활성 정책.
  //   '20'·'25' = 아울렛 (현 운영중), '33' = 추가 적립 불가 매장.
  //   변경 시 양쪽 동기 수정 필요. 향후 별도 PolicyUtil 추출 고려.
  private static final Set<String> NON_ACCRUAL_STORE_TYPES = new Set<String>{ '20', '25', '33' };

  public class AccrualCancelResult {
    public Decimal requestedPoints = 0;
    public Decimal actualPoints = 0;
    public Decimal loss = 0;
    public Boolean success = false;
    public Id reversalTjId;
    public String error;
  }

  public static AccrualCancelResult cancelOldSaleEtcAccrualSafe(
    Id memberId,
    Id loyaltyProgramId,
    Id originalOrderId,
    Id returnOrderId,
    Decimal requestedPoints,
    String reason
  ) {
    AccrualCancelResult result = new AccrualCancelResult();
    result.requestedPoints = requestedPoints == null ? 0 : requestedPoints;
    result.loss = result.requestedPoints;

    if (memberId == null || loyaltyProgramId == null || result.requestedPoints <= 0) {
      result.error = 'invalid input';
      return result;
    }

    // [Non-Accrual Store Guard 2026-05-20] 원판매가 적립 불가 매장이면 강제 차감 skip.
    //   배경: 적립 불가 매장(StoreType 20/25/33)의 라이브 판매는 적립 자체가 일어나지 않음
    //         (GdSaleDepositServiceImpl line 541-546). 그러나 옵션 C 마이그레이션 force-debit 은
    //         "적립이 있었을 것"이라 추정해 회원 기타포인트 lump 에서 강제 차감 → 부당 차감 발생.
    //   해결: 원판매 매장 StoreType 검사 후 차단. 보호 대상 5개 호출처(반품/판매삭제/입금삭제/판매PATCH/미래) 모두.
    //   skip 시맨틱: success=true (정상 종료, 차감할 적립 없음), loss=0 (손실 없음).
    if (isOriginalOrderNonAccrualStore(originalOrderId)) {
      result.error = 'skipped: original sale store is non-accrual (StoreType IN 20/25/33)';
      result.actualPoints = 0;
      result.loss = 0;
      result.success = true;
      return result;
    }

    try {
      Id accrualReversalJtId = SObjectUtil.findIdByName(JournalType.SObjectType, 'Accrual Reversal', true);
      Id cancelPurchaseAccrualJstId = SObjectUtil.findIdByConditions(
        JournalSubType.SObjectType,
        new Map<String, Object>{ 'Name' => 'Cancel Purchase Accrual', 'JournalTypeId' => accrualReversalJtId },
        true
      );
      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      List<LoyaltyLedger> creditLedgers = [
        SELECT
          Id,
          Points,
          LoyaltyPgmCrcySubtypeId,
          ExpiryDate,
          CreatedDate,
          TransactionJournal.OrderId,
          TransactionJournal.SaleId__c,
          TransactionJournal.JournalSubType.Name,
          TransactionJournal.AdditionalNotes__c
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Credit'
          AND Points > 0
          AND ExpiryDate >= TODAY
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c = '04'
        ORDER BY CreatedDate ASC
        LIMIT 1000
      ];
      creditLedgers = filterCancelableOptionCCreditLedgers(creditLedgers, returnOrderId);
      if (creditLedgers.isEmpty()) {
        result.error = 'no active option c etc credit ledger';
        return result;
      }

      Set<Id> creditIds = new Map<Id, LoyaltyLedger>(creditLedgers).keySet();
      Map<Id, Decimal> debitByCreditId = new Map<Id, Decimal>();
      Map<Id, Decimal> debitCancelByCreditId = new Map<Id, Decimal>();
      Map<Id, Decimal> creditCancelByCreditId = new Map<Id, Decimal>();
      // [Fix #2,#5 2026-05-25] TJ.IsDeleted__c 필터 제거 — LASEL trigger net 시맨틱과 통일
      //   배경: 같은 트랜잭션에서 방금 IsDel=true 마킹된 Debit 까지 used 에서 제외시켜
      //         가짜 available 잔액 발생 → OPTC_CREDIT lump 부당 차감 → LASEL 음수.
      //   해결: LLT 자체 IsDeleted 만 신뢰. TJ.IsDeleted__c 무관하게 net 계산.
      //         결과적으로 OPTC_CREDIT (use_sum 표현) 의 available=0 으로 정확 계산되어
      //         후보에서 자동 제외, 회수는 OPTC_RESIDUAL 향으로만 진행됨.
      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
        FROM LoyaltyLedgerTraceability
        WHERE CreditLoyaltyLedgerId IN :creditIds AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation') AND IsDeleted = FALSE
        GROUP BY CreditLoyaltyLedgerId, ActionType
      ]) {
        Id creditId = (Id) ar.get('creditId');
        String actionType = (String) ar.get('actionType');
        Decimal totalPoints = (Decimal) ar.get('totalPoints');
        if (totalPoints == null) {
          totalPoints = 0;
        }
        if ('Debit'.equals(actionType)) {
          debitByCreditId.put(creditId, totalPoints);
        } else if ('DebitCancellation'.equals(actionType)) {
          debitCancelByCreditId.put(creditId, totalPoints);
        } else if ('CreditCancellation'.equals(actionType)) {
          creditCancelByCreditId.put(creditId, totalPoints);
        }
      }

      Decimal remainingRequest = result.requestedPoints;
      List<LoyaltyLedger> debitLedgers = new List<LoyaltyLedger>();
      List<Id> traceCreditLedgerIds = new List<Id>();
      List<Id> traceSubtypeIds = new List<Id>();
      List<Decimal> tracePoints = new List<Decimal>();

      for (Integer pass = 0; pass < 2 && remainingRequest > 0; pass++) {
        for (LoyaltyLedger credit : creditLedgers) {
          if (remainingRequest <= 0) {
            break;
          }
          Boolean sameOriginalOrder =
            originalOrderId != null &&
            credit.TransactionJournal != null &&
            credit.TransactionJournal.OrderId == originalOrderId;
          if ((pass == 0 && !sameOriginalOrder) || (pass == 1 && sameOriginalOrder)) {
            continue;
          }

          Decimal used = debitByCreditId.containsKey(credit.Id) ? debitByCreditId.get(credit.Id) : 0;
          Decimal restored = debitCancelByCreditId.containsKey(credit.Id) ? debitCancelByCreditId.get(credit.Id) : 0;
          Decimal canceled = creditCancelByCreditId.containsKey(credit.Id) ? creditCancelByCreditId.get(credit.Id) : 0;
          Decimal available = credit.Points - used + restored - canceled;
          if (available <= 0) {
            continue;
          }

          Decimal allocated = available < remainingRequest ? available : remainingRequest;
          LoyaltyLedger debitLedger = new LoyaltyLedger();
          debitLedger.LoyaltyProgramMemberId = memberId;
          debitLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
          debitLedger.LoyaltyPgmCrcySubtypeId = credit.LoyaltyPgmCrcySubtypeId;
          debitLedger.Points = allocated;
          debitLedger.EventType = 'Debit';
          debitLedger.ActivityDate = Datetime.now();
          debitLedgers.add(debitLedger);

          traceCreditLedgerIds.add(credit.Id);
          traceSubtypeIds.add(credit.LoyaltyPgmCrcySubtypeId);
          tracePoints.add(allocated);
          remainingRequest -= allocated;
        }
      }

      if (debitLedgers.isEmpty()) {
        result.error = 'no cancelable option c etc balance';
        return result;
      }

      Decimal actual = 0;
      for (Decimal p : tracePoints) {
        actual += p;
      }

      TransactionJournal reversalTj = new TransactionJournal();
      reversalTj.MemberId = memberId;
      reversalTj.LoyaltyProgramId = loyaltyProgramId;
      reversalTj.OrderId = originalOrderId;
      if (returnOrderId != null) {
        reversalTj.SaleId__c = returnOrderId;
      }
      reversalTj.JournalDate = Datetime.now();
      reversalTj.ActivityDate = Datetime.now();
      reversalTj.JournalTypeId = accrualReversalJtId;
      reversalTj.JournalSubTypeId = cancelPurchaseAccrualJstId;
      reversalTj.JournalReason__c = '6';
      reversalTj.TransactionAmount = actual;
      reversalTj.Status = 'Processed';
      reversalTj.AdditionalNotes__c = buildAdditionalNotes('OPTC_OLD_SALE_ETC_ACCRUAL_CANCEL', returnOrderId, actual);
      insert reversalTj;
      result.reversalTjId = reversalTj.Id;

      for (LoyaltyLedger debitLedger : debitLedgers) {
        debitLedger.TransactionJournalId = reversalTj.Id;
      }
      insert debitLedgers;

      List<LoyaltyLedgerTraceability> traces = new List<LoyaltyLedgerTraceability>();
      for (Integer i = 0; i < debitLedgers.size(); i++) {
        LoyaltyLedgerTraceability trace = new LoyaltyLedgerTraceability();
        trace.LoyaltyProgramMemberId = memberId;
        trace.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        trace.LoyaltyPgmCurrencySubtypeId = traceSubtypeIds[i];
        trace.CreditLoyaltyLedgerId = traceCreditLedgerIds[i];
        trace.DebitLoyaltyLedgerId = debitLedgers[i].Id;
        trace.Points = tracePoints[i];
        trace.ActionType = 'CreditCancellation';
        traces.add(trace);
      }
      insert traces;

      List<LoyaltyMemberCurrency> lmcList = [
        SELECT Id, TotalPointsRedeemed
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :memberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      if (!lmcList.isEmpty()) {
        LoyaltyMemberCurrency lmc = lmcList[0];
        lmc.TotalPointsRedeemed = (lmc.TotalPointsRedeemed == null ? 0 : lmc.TotalPointsRedeemed) + actual;
        update lmc;
      }

      GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger(memberId);

      result.actualPoints = actual;
      result.loss = result.requestedPoints - actual;
      result.success = true;
      return result;
    } catch (Exception e) {
      System.debug('GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe exception: ' + e.getMessage());
      result.actualPoints = 0;
      result.loss = result.requestedPoints;
      result.success = false;
      result.error = e.getMessage();
      return result;
    }
  }

  private static List<LoyaltyLedger> filterCancelableOptionCCreditLedgers(List<LoyaltyLedger> creditLedgers, Id currentReturnOrderId) {
    List<LoyaltyLedger> result = new List<LoyaltyLedger>();
    if (creditLedgers == null) {
      return result;
    }

    for (LoyaltyLedger credit : creditLedgers) {
      String journalSubTypeName = credit.TransactionJournal != null &&
        credit.TransactionJournal.JournalSubType != null
        ? credit.TransactionJournal.JournalSubType.Name
        : null;
      Boolean isPointRedeemCancel = journalSubTypeName == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL;
      Boolean isCurrentReturnRestore =
        isPointRedeemCancel &&
        currentReturnOrderId != null &&
        credit.TransactionJournal != null &&
        credit.TransactionJournal.SaleId__c == currentReturnOrderId;
      if (isPointRedeemCancel && !isCurrentReturnRestore) {
        continue;
      }

      // [Fix 결함 ① 2026-06-06]
      //   USE_RESTORE Credit LL 보호 — 입금 단건 삭제로 발행된 사용 환원 LL 이
      //   ACCRUAL_CANCEL 회수 대상에 잡혀 회수 우선순위 결함으로
      //   residual lump 가 부족 회수되는 결함 차단.
      //   TJ.AdditionalNotes__c 가 'OPTC_FORCE_CREDIT:' prefix 면 force-credit 흐름이므로 제외.
      String addNotes = credit.TransactionJournal != null ? credit.TransactionJournal.AdditionalNotes__c : null;
      if (String.isNotBlank(addNotes) && addNotes.startsWith('OPTC_FORCE_CREDIT:')) {
        continue;
      }

      result.add(credit);
    }
    return result;
  }

  @TestVisible
  private static Boolean isOriginalOrderNonAccrualStore(Id originalOrderId) {
    if (originalOrderId == null) {
      return false;
    }
    List<Order> orders = [
      SELECT StoreCode__r.StoreType__c
      FROM Order
      WHERE Id = :originalOrderId
      LIMIT 1
    ];
    if (orders.isEmpty() || orders[0].StoreCode__r == null) {
      return false;
    }
    String storeType = orders[0].StoreCode__r.StoreType__c;
    return String.isNotBlank(storeType) && NON_ACCRUAL_STORE_TYPES.contains(storeType);
  }

  private static String buildAdditionalNotes(String marker, Id returnOrderId, Decimal points) {
    String note = String.isBlank(marker) ? 'OPTC' : marker;
    if (returnOrderId != null) {
      note += ':returnOrderId=' + String.valueOf(returnOrderId);
    }
    if (points != null) {
      note += ';points=' + points.setScale(0, RoundingMode.HALF_UP).toPlainString();
    }
    return note.length() > MAX_ADDITIONAL_NOTES_LENGTH ? note.substring(0, MAX_ADDITIONAL_NOTES_LENGTH) : note;
  }
}