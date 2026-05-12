public with sharing class GdOptionCPointAdjustmentUtil {
  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';

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

    try {
      Id accrualReversalJtId = SObjectUtil.findIdByName(JournalType.SObjectType, 'Accrual Reversal', true);
      Id cancelPurchaseAccrualJstId = SObjectUtil.findIdByConditions(
        JournalSubType.SObjectType,
        new Map<String, Object>{ 'Name' => 'Cancel Purchase Accrual', 'JournalTypeId' => accrualReversalJtId },
        true
      );
      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(
        LoyaltyProgramCurrency.SObjectType,
        LOYALTY_PROGRAM_CURRENCY_NAME,
        true
      );

      List<LoyaltyLedger> creditLedgers = [
        SELECT Id, Points, LoyaltyPgmCrcySubtypeId, ExpiryDate, CreatedDate, TransactionJournal.OrderId
        FROM LoyaltyLedger
        WHERE LoyaltyProgramMemberId = :memberId
          AND EventType = 'Credit'
          AND Points > 0
          AND ExpiryDate >= TODAY
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c = '04'
        ORDER BY CreatedDate ASC
        LIMIT 1000
      ];
      if (creditLedgers.isEmpty()) {
        result.error = 'no active option c etc credit ledger';
        return result;
      }

      Set<Id> creditIds = new Map<Id, LoyaltyLedger>(creditLedgers).keySet();
      Map<Id, Decimal> debitByCreditId = new Map<Id, Decimal>();
      Map<Id, Decimal> debitCancelByCreditId = new Map<Id, Decimal>();
      Map<Id, Decimal> creditCancelByCreditId = new Map<Id, Decimal>();
      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
        FROM LoyaltyLedgerTraceability
        WHERE CreditLoyaltyLedgerId IN :creditIds
          AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
          AND (DebitLoyaltyLedgerId = NULL OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
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
          Boolean sameOriginalOrder = originalOrderId != null &&
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
      String safeReason = String.isBlank(reason) ? '' : reason;
      if (safeReason.length() > 30000) {
        safeReason = safeReason.substring(0, 30000);
      }
      reversalTj.AdditionalNotes__c = 'OPTC_OLD_SALE_ETC_ACCRUAL_CANCEL: ' + safeReason;
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
        WHERE LoyaltyMemberId = :memberId
          AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
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
}