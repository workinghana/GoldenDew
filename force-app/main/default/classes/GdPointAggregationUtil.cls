public with sharing class GdPointAggregationUtil {
  private static final String JST_POINT_DEBIT = 'Point Debit';
  private static final String JST_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String JST_PURCHASE_ACCRUAL = 'Purchase Accrual';
  private static final String JST_MANUAL_POINTS_CREDIT = 'Manual Points Credit';
  private static final String JST_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual';
  private static final String JST_AUTO_EXPIRE = 'Auto Expire';
  private static final String JST_API_FORCED_EXPIRE = 'Api Forced Expire';
  private static final String JST_API_FORCED_DEBIT = 'Api Forced Debit';
  private static final String JST_API_FORCED_CREDIT = 'Api Forced Credit';
  private static final String JST_PROMOTION_POINT_ACCRUAL = 'Promotion Point Accrual';
  private static final String JST_PROMOTION_POINT_ACCRUAL_REVERSAL = 'Promotion Point Accrual Reversal';

  public static void rebuildLoyaltyAggrSubPointExprLedger(Id loyaltyProgramMemberId) {
    if (loyaltyProgramMemberId == null) {
      return;
    }

    Id pointCurrencyId = resolvePointCurrencyId(loyaltyProgramMemberId);
    Boolean preservePointCancelTrace = GdFeatureFlag.isEnabled('PointCancel_PreserveTrace');
    Map<String, AggrRebuildValue> targetByKey = new Map<String, AggrRebuildValue>();
    Set<Id> debitLedgerIds = new Set<Id>();
    Map<Id, LoyaltyLedger> debitLedgerById = new Map<Id, LoyaltyLedger>();
    Map<String, List<CreditLedgerBucket>> creditBucketsBySourceAndSubtype = new Map<String, List<CreditLedgerBucket>>();
    Set<Id> debitLedgerIdsWithTrace = new Set<Id>();

    List<LoyaltyLedger> activeLedgers = [
      SELECT
        Id,
        EventType,
        Points,
        ExpiryDate,
        LoyaltyPgmCrcySubtypeId,
        LoyaltyPgmCrcySubtype.Name,
        TransactionJournal.OrderId,
        TransactionJournal.SaleId__c,
        TransactionJournal.OrderId__c,
        TransactionJournal.JournalSubType.Name
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId AND IsDeleted = FALSE
      ORDER BY CreatedDate ASC
      LIMIT 50000
    ];

    for (LoyaltyLedger ledger : activeLedgers) {
      if (ledger == null) {
        continue;
      }
      if ('Debit'.equals(ledger.EventType)) {
        debitLedgerIds.add(ledger.Id);
        debitLedgerById.put(ledger.Id, ledger);
        continue;
      }
      if (ledger.LoyaltyPgmCrcySubtypeId == null || ledger.ExpiryDate == null) {
        continue;
      }

      String subtypeName = ledger.LoyaltyPgmCrcySubtype == null ? null : ledger.LoyaltyPgmCrcySubtype.Name;
      String journalSubTypeName = ledger.TransactionJournal == null ||
        ledger.TransactionJournal.JournalSubType == null
        ? null
        : ledger.TransactionJournal.JournalSubType.Name;
      Decimal points = ledger.Points == null ? 0 : ledger.Points;

      AggrRebuildValue value = getOrCreateAggrValue(
        targetByKey,
        loyaltyProgramMemberId,
        ledger.LoyaltyPgmCrcySubtypeId,
        ledger.ExpiryDate,
        subtypeName
      );

      if ('Credit'.equals(ledger.EventType)) {
        if (JST_POINT_REDEEM_CANCEL.equals(journalSubTypeName)) {
          if (preservePointCancelTrace) {
            value.accruedPoints += points;
          } else {
            value.redeemedPoints -= points;
          }
        } else if (
          JST_PURCHASE_ACCRUAL.equals(journalSubTypeName) ||
          JST_MANUAL_POINTS_CREDIT.equals(journalSubTypeName) ||
          JST_API_FORCED_CREDIT.equals(journalSubTypeName) ||
          JST_PROMOTION_POINT_ACCRUAL.equals(journalSubTypeName)
        ) {
          value.accruedPoints += points;
          addCreditBucket(creditBucketsBySourceAndSubtype, ledger, points, subtypeName);
        }
      } else if ('Expiry'.equals(ledger.EventType)) {
        if (
          JST_AUTO_EXPIRE.equals(journalSubTypeName) ||
          JST_API_FORCED_EXPIRE.equals(journalSubTypeName) ||
          JST_POINT_REDEEM_CANCEL.equals(journalSubTypeName)
        ) {
          value.expiredPoints += points;
        }
      }
    }

    if (!debitLedgerIds.isEmpty()) {
      for (LoyaltyLedgerTraceability trace : [
        SELECT
          CreditLoyaltyLedger.ExpiryDate,
          DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name,
          LoyaltyPgmCurrencySubtypeId,
          LoyaltyPgmCurrencySubtype.Name,
          DebitLoyaltyLedgerId,
          Points,
          ActionType
        FROM LoyaltyLedgerTraceability
        WHERE DebitLoyaltyLedgerId IN :debitLedgerIds AND ActionType IN ('Debit', 'CreditCancellation') AND IsDeleted = FALSE
        LIMIT 50000
      ]) {
        if (trace == null || trace.LoyaltyPgmCurrencySubtypeId == null) {
          continue;
        }
        debitLedgerIdsWithTrace.add(trace.DebitLoyaltyLedgerId);
        if (trace.CreditLoyaltyLedger == null || trace.CreditLoyaltyLedger.ExpiryDate == null) {
          continue;
        }

        String journalSubTypeName = trace.DebitLoyaltyLedger == null ||
          trace.DebitLoyaltyLedger.TransactionJournal == null ||
          trace.DebitLoyaltyLedger.TransactionJournal.JournalSubType == null
          ? null
          : trace.DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name;
        String subtypeName = trace.LoyaltyPgmCurrencySubtype == null ? null : trace.LoyaltyPgmCurrencySubtype.Name;
        Decimal points = trace.Points == null ? 0 : trace.Points;

        AggrRebuildValue value = getOrCreateAggrValue(
          targetByKey,
          loyaltyProgramMemberId,
          trace.LoyaltyPgmCurrencySubtypeId,
          trace.CreditLoyaltyLedger.ExpiryDate,
          subtypeName
        );

        if (JST_POINT_DEBIT.equals(journalSubTypeName)) {
          value.redeemedPoints += points;
        } else if (
          JST_CANCEL_PURCHASE_ACCRUAL.equals(journalSubTypeName) ||
          JST_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(journalSubTypeName) ||
          JST_API_FORCED_DEBIT.equals(journalSubTypeName)
        ) {
          value.accruedPoints -= points;
        } else if (JST_API_FORCED_EXPIRE.equals(journalSubTypeName)) {
          value.expiredPoints += points;
        }
      }

      applyMissingCreditCancellationFallback(
        targetByKey,
        loyaltyProgramMemberId,
        debitLedgerById,
        debitLedgerIdsWithTrace,
        creditBucketsBySourceAndSubtype
      );
    }

    Map<String, LoyaltyAggrSubPointExprLedger__c> existingByKey = new Map<String, LoyaltyAggrSubPointExprLedger__c>();
    for (LoyaltyAggrSubPointExprLedger__c existing : [
      SELECT
        Id,
        LoyaltyProgramMemberId__c,
        CurrencySubTypeId__c,
        ExpiryDate__c,
        CurrencySubTypeName__c,
        AccruedPoints__c,
        RedeemedPoints__c,
        ExpiredPoints__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :loyaltyProgramMemberId
      LIMIT 50000
    ]) {
      existingByKey.put(buildAggrRebuildKey(existing.LoyaltyProgramMemberId__c, existing.CurrencySubTypeId__c, existing.ExpiryDate__c), existing);
    }

    List<LoyaltyAggrSubPointExprLedger__c> inserts = new List<LoyaltyAggrSubPointExprLedger__c>();
    List<LoyaltyAggrSubPointExprLedger__c> updates = new List<LoyaltyAggrSubPointExprLedger__c>();
    for (String key : targetByKey.keySet()) {
      AggrRebuildValue value = targetByKey.get(key);
      LoyaltyAggrSubPointExprLedger__c row = existingByKey.get(key);
      if (row == null) {
        inserts.add(
          new LoyaltyAggrSubPointExprLedger__c(
            LoyaltyProgramMemberId__c = value.memberId,
            CurrencySubTypeId__c = value.subtypeId,
            ExpiryDate__c = value.expiryDate,
            CurrencySubTypeName__c = value.subtypeName,
            AccruedPoints__c = value.accruedPoints,
            RedeemedPoints__c = value.redeemedPoints,
            ExpiredPoints__c = value.expiredPoints,
            LoyaltyProgramCurrencyId__c = pointCurrencyId
          )
        );
      } else {
        row.CurrencySubTypeName__c = value.subtypeName;
        row.AccruedPoints__c = value.accruedPoints;
        row.RedeemedPoints__c = value.redeemedPoints;
        row.ExpiredPoints__c = value.expiredPoints;
        updates.add(row);
      }
    }

    for (String key : existingByKey.keySet()) {
      if (targetByKey.containsKey(key)) {
        continue;
      }
      LoyaltyAggrSubPointExprLedger__c stale = existingByKey.get(key);
      stale.AccruedPoints__c = 0;
      stale.RedeemedPoints__c = 0;
      stale.ExpiredPoints__c = 0;
      updates.add(stale);
    }

    if (!inserts.isEmpty()) {
      insert inserts;
    }
    if (!updates.isEmpty()) {
      update updates;
    }
  }

  private static AggrRebuildValue getOrCreateAggrValue(
    Map<String, AggrRebuildValue> targetByKey,
    Id memberId,
    Id subtypeId,
    Date expiryDate,
    String subtypeName
  ) {
    String key = buildAggrRebuildKey(memberId, subtypeId, expiryDate);
    if (!targetByKey.containsKey(key)) {
      targetByKey.put(key, new AggrRebuildValue(memberId, subtypeId, expiryDate, subtypeName));
    }
    AggrRebuildValue value = targetByKey.get(key);
    if (String.isNotBlank(subtypeName)) {
      value.subtypeName = subtypeName;
    }
    return value;
  }

  private static String buildAggrRebuildKey(Id memberId, Id subtypeId, Date expiryDate) {
    return String.valueOf(memberId) + '|' + String.valueOf(subtypeId) + '|' + String.valueOf(expiryDate);
  }

  private static void addCreditBucket(
    Map<String, List<CreditLedgerBucket>> creditBucketsBySourceAndSubtype,
    LoyaltyLedger ledger,
    Decimal points,
    String subtypeName
  ) {
    String sourceKey = buildSourceSubtypeKey(ledger);
    if (String.isBlank(sourceKey) || ledger.ExpiryDate == null || ledger.LoyaltyPgmCrcySubtypeId == null) {
      return;
    }
    if (!creditBucketsBySourceAndSubtype.containsKey(sourceKey)) {
      creditBucketsBySourceAndSubtype.put(sourceKey, new List<CreditLedgerBucket>());
    }
    creditBucketsBySourceAndSubtype.get(sourceKey)
      .add(new CreditLedgerBucket(ledger.LoyaltyPgmCrcySubtypeId, ledger.ExpiryDate, subtypeName, points == null ? 0 : points));
  }

  private static void applyMissingCreditCancellationFallback(
    Map<String, AggrRebuildValue> targetByKey,
    Id memberId,
    Map<Id, LoyaltyLedger> debitLedgerById,
    Set<Id> debitLedgerIdsWithTrace,
    Map<String, List<CreditLedgerBucket>> creditBucketsBySourceAndSubtype
  ) {
    for (Id debitLedgerId : debitLedgerById.keySet()) {
      if (debitLedgerIdsWithTrace.contains(debitLedgerId)) {
        continue;
      }
      LoyaltyLedger debitLedger = debitLedgerById.get(debitLedgerId);
      if (debitLedger == null || debitLedger.LoyaltyPgmCrcySubtypeId == null) {
        continue;
      }

      String journalSubTypeName = debitLedger.TransactionJournal == null ||
        debitLedger.TransactionJournal.JournalSubType == null
        ? null
        : debitLedger.TransactionJournal.JournalSubType.Name;
      if (!isAccrualReversalSubType(journalSubTypeName)) {
        continue;
      }

      String sourceKey = buildSourceSubtypeKey(debitLedger);
      if (String.isBlank(sourceKey) || !creditBucketsBySourceAndSubtype.containsKey(sourceKey)) {
        continue;
      }

      Decimal remaining = debitLedger.Points == null ? 0 : debitLedger.Points;
      for (CreditLedgerBucket bucket : creditBucketsBySourceAndSubtype.get(sourceKey)) {
        if (remaining <= 0) {
          break;
        }
        if (bucket.remainingPoints <= 0) {
          continue;
        }

        Decimal allocated = remaining > bucket.remainingPoints ? bucket.remainingPoints : remaining;
        if (allocated <= 0) {
          continue;
        }

        AggrRebuildValue value = getOrCreateAggrValue(targetByKey, memberId, bucket.subtypeId, bucket.expiryDate, bucket.subtypeName);
        value.accruedPoints -= allocated;
        bucket.remainingPoints -= allocated;
        remaining -= allocated;
      }
    }
  }

  private static Boolean isAccrualReversalSubType(String journalSubTypeName) {
    return JST_CANCEL_PURCHASE_ACCRUAL.equals(journalSubTypeName) ||
      JST_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(journalSubTypeName) ||
      JST_API_FORCED_DEBIT.equals(journalSubTypeName);
  }

  private static String buildSourceSubtypeKey(LoyaltyLedger ledger) {
    if (ledger == null || ledger.TransactionJournal == null || ledger.LoyaltyPgmCrcySubtypeId == null) {
      return null;
    }
    String sourceId = ledger.TransactionJournal.OrderId == null ? null : String.valueOf(ledger.TransactionJournal.OrderId);
    if (String.isBlank(sourceId) && String.isNotBlank(ledger.TransactionJournal.SaleId__c)) {
      sourceId = String.valueOf(ledger.TransactionJournal.SaleId__c);
    }
    if (String.isBlank(sourceId) && String.isNotBlank(ledger.TransactionJournal.OrderId__c)) {
      sourceId = String.valueOf(ledger.TransactionJournal.OrderId__c);
    }
    if (String.isBlank(sourceId)) {
      return null;
    }
    return sourceId + '|' + String.valueOf(ledger.LoyaltyPgmCrcySubtypeId);
  }

  private static Id resolvePointCurrencyId(Id loyaltyProgramMemberId) {
    List<LoyaltyMemberCurrency> memberCurrencyList = [
      SELECT LoyaltyProgramCurrencyId
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :loyaltyProgramMemberId
      LIMIT 1
    ];
    if (memberCurrencyList.isEmpty() || memberCurrencyList[0].LoyaltyProgramCurrencyId == null) {
      throw new CustomException(400, 'LoyaltyMemberCurrency not found for member ' + loyaltyProgramMemberId);
    }
    return memberCurrencyList[0].LoyaltyProgramCurrencyId;
  }

  private class AggrRebuildValue {
    Id memberId;
    Id subtypeId;
    Date expiryDate;
    String subtypeName;
    Decimal accruedPoints = 0;
    Decimal redeemedPoints = 0;
    Decimal expiredPoints = 0;

    AggrRebuildValue(Id memberId, Id subtypeId, Date expiryDate, String subtypeName) {
      this.memberId = memberId;
      this.subtypeId = subtypeId;
      this.expiryDate = expiryDate;
      this.subtypeName = subtypeName;
    }
  }

  private class CreditLedgerBucket {
    Id subtypeId;
    Date expiryDate;
    String subtypeName;
    Decimal remainingPoints;

    CreditLedgerBucket(Id subtypeId, Date expiryDate, String subtypeName, Decimal points) {
      this.subtypeId = subtypeId;
      this.expiryDate = expiryDate;
      this.subtypeName = subtypeName;
      this.remainingPoints = points == null ? 0 : points;
    }
  }
}