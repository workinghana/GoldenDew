public with sharing class PointLedgerUIControllerV1 {
  private static final Set<String> COUPON_PAYMENT_METHODS = new Set<String>{ '90' };
  private static final Set<String> POINT_PAYMENT_METHODS = new Set<String>{ '81' };
  private static final String HQ_EXCHANGE_PAYMENT_METHOD = '93';
  private static final String JOURNAL_SUBTYPE_PURCHASE_ACCRUAL = 'Purchase Accrual';
  private static final String JOURNAL_SUBTYPE_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual';
  private static final String JOURNAL_SUBTYPE_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static Map<String, Id> journalSubTypeIdsByName;

  @AuraEnabled(cacheable=true)
  public static Id resolveLoyaltyProgramMemberId(Id recordId) {
    if (recordId == null) {
      return null;
    }

    String objectName = recordId.getSObjectType().getDescribe().getName();

    if (objectName == 'LoyaltyProgramMember') {
      return recordId;
    }

    if (objectName == 'Order') {
      List<Order> orders = [
        SELECT MemberNo__c
        FROM Order
        WHERE Id = :recordId
        LIMIT 1
      ];

      if (orders.isEmpty() || orders[0].MemberNo__c == null) {
        return null;
      }

      List<LoyaltyProgramMember> members = [
        SELECT Id
        FROM LoyaltyProgramMember
        WHERE ContactId = :orders[0].MemberNo__c
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];

      return members.isEmpty() ? null : members[0].Id;
    }

    return null;
  }

  @AuraEnabled(cacheable=true)
  public static Id resolveOrderId(Id recordId) {
    if (recordId == null) {
      return null;
    }

    String objectName = recordId.getSObjectType().getDescribe().getName();
    return objectName == 'Order' ? recordId : null;
  }

  @AuraEnabled(cacheable=true)
  public static List<PointLedgerRowDTO> getPointLedgerRows(Id loyaltyProgramMemberId, Id orderId) {
    if (loyaltyProgramMemberId == null) {
      return new List<PointLedgerRowDTO>();
    }

    Id pointRedeemCancelSubTypeId = getJournalSubTypeIdByName(JOURNAL_SUBTYPE_POINT_REDEEM_CANCEL);
    List<LoyaltyLedger> creditLedgers;
    if (orderId == null) {
      creditLedgers = [
        SELECT
          Id,
          ActivityDate,
          Points,
          ExpiryDate,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          TransactionJournalId,
          TransactionJournal.OrderId,
          TransactionJournal.Order.EffectiveDate,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.ActualPaymentAmount__c
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :loyaltyProgramMemberId
          AND EventType = 'Credit'
          AND (TransactionJournal.JournalSubTypeId = NULL
          OR TransactionJournal.JournalSubTypeId != :pointRedeemCancelSubTypeId)
        ORDER BY ActivityDate DESC, ExpiryDate ASC
      ];
    } else {
      creditLedgers = [
        SELECT
          Id,
          ActivityDate,
          Points,
          ExpiryDate,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          TransactionJournalId,
          TransactionJournal.OrderId,
          TransactionJournal.Order.EffectiveDate,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.ActualPaymentAmount__c
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :loyaltyProgramMemberId
          AND EventType = 'Credit'
          AND TransactionJournal.OrderId = :orderId
          AND (TransactionJournal.JournalSubTypeId = NULL
          OR TransactionJournal.JournalSubTypeId != :pointRedeemCancelSubTypeId)
        ORDER BY ActivityDate DESC, ExpiryDate ASC
      ];
    }

    if (creditLedgers.isEmpty()) {
      return new List<PointLedgerRowDTO>();
    }

    Set<Id> orderIds = new Set<Id>();
    Set<Id> subtypeIds = new Set<Id>();

    for (LoyaltyLedger ledger : creditLedgers) {
      subtypeIds.add(ledger.LoyaltyPgmCrcySubtypeId);
      if (ledger.TransactionJournal != null && ledger.TransactionJournal.OrderId != null) {
        orderIds.add(ledger.TransactionJournal.OrderId);
      }
    }

    Map<String, UsageSummary> usageByOrderSubtype = buildUsageSummaryMap(loyaltyProgramMemberId, orderIds, subtypeIds);
    Map<Id, PaymentSummary> paymentByOrderId = buildPaymentSummaryMap(orderIds);

    List<PointLedgerRowDTO> results = new List<PointLedgerRowDTO>();

    for (LoyaltyLedger ledger : creditLedgers) {
      PointLedgerRowDTO row = new PointLedgerRowDTO();
      String usageKey = buildOrderSubtypeKey(
        ledger.TransactionJournal != null ? ledger.TransactionJournal.OrderId : null,
        ledger.LoyaltyPgmCrcySubtypeId
      );
      UsageSummary usage = usageByOrderSubtype.get(usageKey);

      row.ledgerId = ledger.Id;
      row.pointTypeName = ledger.LoyaltyPgmCrcySubtype != null ? ledger.LoyaltyPgmCrcySubtype.Name : '';
      row.transactionDate = ledger.ActivityDate != null ? ledger.ActivityDate.date() : null;
      row.accruedPoints = toInteger(ledger.Points);
      row.usedPoints = usage == null ? 0 : usage.usedPoints;
      row.expiredPoints = usage == null ? 0 : usage.expiredPoints;
      row.startDate = ledger.ActivityDate != null ? ledger.ActivityDate.date() : null;
      row.endDate = ledger.ExpiryDate;

      row.saleDate = (ledger.TransactionJournal != null &&
        ledger.TransactionJournal.OrderId != null &&
        ledger.TransactionJournal.Order != null)
        ? ledger.TransactionJournal.Order.EffectiveDate
        : null;
      row.saleNo = (ledger.TransactionJournal != null &&
        ledger.TransactionJournal.OrderId != null &&
        ledger.TransactionJournal.Order != null)
        ? ledger.TransactionJournal.Order.SaleNo__c
        : null;
      row.saleOrderId = ledger.TransactionJournal != null ? ledger.TransactionJournal.OrderId : null;
      row.saleAmount = (ledger.TransactionJournal != null &&
        ledger.TransactionJournal.OrderId != null &&
        ledger.TransactionJournal.Order != null)
        ? toInteger(ledger.TransactionJournal.Order.ActualPaymentAmount__c)
        : 0;

      if (ledger.TransactionJournal != null && ledger.TransactionJournal.OrderId != null) {
        PaymentSummary payment = paymentByOrderId.get(ledger.TransactionJournal.OrderId);
        row.depositCouponAmount = payment == null ? 0 : payment.depositCouponAmount;
        row.depositPointAmount = payment == null ? 0 : payment.depositPointAmount;
        row.depositHqExchangeAmount = payment == null ? 0 : payment.depositHqExchangeAmount;
      } else {
        row.depositCouponAmount = 0;
        row.depositPointAmount = 0;
        row.depositHqExchangeAmount = 0;
      }

      results.add(row);
    }

    return results;
  }

  @AuraEnabled(cacheable=true)
  public static List<PointRedemptionRowDTO> getPointRedemptionRows(Id loyaltyProgramMemberId, Id orderId) {
    if (loyaltyProgramMemberId == null) {
      return new List<PointRedemptionRowDTO>();
    }

    Id pointRedeemCancelSubTypeId = getJournalSubTypeIdByName(JOURNAL_SUBTYPE_POINT_REDEEM_CANCEL);
    List<LoyaltyLedgerTraceability> traceRows;
    List<LoyaltyLedger> expiryRows;
    List<LoyaltyLedger> redeemCancelCreditRows;
    if (orderId == null) {
      traceRows = [
        SELECT
          Id,
          ActionType,
          Points,
          CreatedDate,
          LoyaltyPgmCurrencySubtypeId,
          LoyaltyPgmCurrencySubtype.Name,
          CreditLoyaltyLedgerId,
          CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.Name,
          CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
          CreditLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
          CreditLoyaltyLedger.TransactionJournal.OrderId,
          DebitLoyaltyLedgerId,
          DebitLoyaltyLedger.LoyaltyPgmCrcySubtype.Name,
          DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
          DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
          DebitLoyaltyLedger.TransactionJournal.OrderId,
          DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c,
          DebitLoyaltyLedger.TransactionJournal.JournalDate
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
        ORDER BY CreatedDate DESC
      ];
      expiryRows = [
        SELECT
          Id,
          EventType,
          Points,
          ActivityDate,
          ExpiryDate,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          TransactionJournal.OrderId,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.OrderNo__c,
          TransactionJournal.Order.ActualPaymentAmount__c,
          TransactionJournal.JournalDate
        FROM LoyaltyLedger
        WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId AND EventType = 'Expiry'
        ORDER BY ExpiryDate DESC, ActivityDate DESC
      ];
      redeemCancelCreditRows = [
        SELECT
          Id,
          Points,
          ActivityDate,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          TransactionJournal.OrderId,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.OrderNo__c,
          TransactionJournal.Order.ActualPaymentAmount__c,
          TransactionJournal.JournalDate
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :loyaltyProgramMemberId
          AND EventType = 'Credit'
          AND TransactionJournal.JournalSubTypeId = :pointRedeemCancelSubTypeId
        ORDER BY ActivityDate DESC, CreatedDate DESC
      ];
    } else {
      traceRows = [
        SELECT
          Id,
          ActionType,
          Points,
          CreatedDate,
          LoyaltyPgmCurrencySubtypeId,
          LoyaltyPgmCurrencySubtype.Name,
          CreditLoyaltyLedgerId,
          CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.Name,
          CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
          CreditLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
          CreditLoyaltyLedger.TransactionJournal.OrderId,
          DebitLoyaltyLedgerId,
          DebitLoyaltyLedger.LoyaltyPgmCrcySubtype.Name,
          DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
          DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
          DebitLoyaltyLedger.TransactionJournal.OrderId,
          DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c,
          DebitLoyaltyLedger.TransactionJournal.JournalDate
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :loyaltyProgramMemberId
          AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
          AND (DebitLoyaltyLedger.TransactionJournal.OrderId = :orderId
          OR CreditLoyaltyLedger.TransactionJournal.OrderId = :orderId)
        ORDER BY CreatedDate DESC
      ];
      expiryRows = [
        SELECT
          Id,
          EventType,
          Points,
          ActivityDate,
          ExpiryDate,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          TransactionJournal.OrderId,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.OrderNo__c,
          TransactionJournal.Order.ActualPaymentAmount__c,
          TransactionJournal.JournalDate
        FROM LoyaltyLedger
        WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId AND EventType = 'Expiry' AND TransactionJournal.OrderId = :orderId
        ORDER BY ExpiryDate DESC, ActivityDate DESC
      ];
      redeemCancelCreditRows = [
        SELECT
          Id,
          Points,
          ActivityDate,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          TransactionJournal.OrderId,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.OrderNo__c,
          TransactionJournal.Order.ActualPaymentAmount__c,
          TransactionJournal.JournalDate
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :loyaltyProgramMemberId
          AND EventType = 'Credit'
          AND TransactionJournal.OrderId = :orderId
          AND TransactionJournal.JournalSubTypeId = :pointRedeemCancelSubTypeId
        ORDER BY ActivityDate DESC, CreatedDate DESC
      ];
    }

    List<PointRedemptionRowDTO> results = new List<PointRedemptionRowDTO>();
    Map<Id, String> expirySubtypeNameById = buildSubtypeNameMap(expiryRows);

    for (LoyaltyLedgerTraceability traceRow : traceRows) {
      PointRedemptionRowDTO row = new PointRedemptionRowDTO();
      row.ledgerId = traceRow.Id;
      row.redemptionDate = getDebitJournalDate(traceRow);
      row.pointTypeName = getTraceabilityPointTypeName(traceRow);
      row.redemptionType = getTraceabilityActionLabel(traceRow.ActionType);
      row.redemptionPoints = traceRow.Points == null ? 0 : Integer.valueOf(traceRow.Points.abs());
      row.saleNo = traceRow.DebitLoyaltyLedger != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal.Order != null
        ? traceRow.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c
        : null;
      row.orderNo = traceRow.DebitLoyaltyLedger != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal.Order != null
        ? traceRow.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c
        : null;
      row.recordId = traceRow.DebitLoyaltyLedger != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal != null
        ? traceRow.DebitLoyaltyLedger.TransactionJournal.OrderId
        : null;
      row.saleAmount = traceRow.DebitLoyaltyLedger != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal.Order != null
        ? toInteger(traceRow.DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c)
        : 0;
      row.accrualSaleNo = traceRow.CreditLoyaltyLedger != null &&
        traceRow.CreditLoyaltyLedger.TransactionJournal != null &&
        traceRow.CreditLoyaltyLedger.TransactionJournal.Order != null
        ? traceRow.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c
        : null;
      row.accrualRecordId = traceRow.CreditLoyaltyLedger != null &&
        traceRow.CreditLoyaltyLedger.TransactionJournal != null
        ? traceRow.CreditLoyaltyLedger.TransactionJournal.OrderId
        : null;
      row.returnSaleNo = traceRow.ActionType == 'DebitCancellation' &&
        traceRow.DebitLoyaltyLedger != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal != null &&
        traceRow.DebitLoyaltyLedger.TransactionJournal.Order != null
        ? traceRow.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c
        : null;
      row.isCancel = traceRow.ActionType == 'DebitCancellation';

      results.add(row);
    }

    for (LoyaltyLedger expiryRow : expiryRows) {
      PointRedemptionRowDTO row = new PointRedemptionRowDTO();
      row.ledgerId = expiryRow.Id;
      row.redemptionDate = expiryRow.ExpiryDate != null
        ? expiryRow.ExpiryDate
        : (expiryRow.ActivityDate != null ? expiryRow.ActivityDate.date() : null);
      row.pointTypeName = getExpiryPointTypeName(expiryRow, expirySubtypeNameById);
      row.redemptionType = getTraceabilityActionLabel(expiryRow.EventType);
      row.redemptionPoints = expiryRow.Points == null ? 0 : Integer.valueOf(expiryRow.Points.abs());
      row.saleNo = expiryRow.TransactionJournal != null &&
        expiryRow.TransactionJournal.Order != null
        ? expiryRow.TransactionJournal.Order.SaleNo__c
        : null;
      row.orderNo = expiryRow.TransactionJournal != null &&
        expiryRow.TransactionJournal.Order != null
        ? expiryRow.TransactionJournal.Order.OrderNo__c
        : null;
      row.recordId = expiryRow.TransactionJournal != null ? expiryRow.TransactionJournal.OrderId : null;
      row.saleAmount = expiryRow.TransactionJournal != null &&
        expiryRow.TransactionJournal.Order != null
        ? toInteger(expiryRow.TransactionJournal.Order.ActualPaymentAmount__c)
        : 0;
      row.accrualSaleNo = null;
      row.returnSaleNo = null;
      row.isCancel = false;

      results.add(row);
    }

    for (LoyaltyLedger redeemCancelCreditRow : redeemCancelCreditRows) {
      PointRedemptionRowDTO row = new PointRedemptionRowDTO();
      row.ledgerId = redeemCancelCreditRow.Id;
      row.redemptionDate = getJournalDate(redeemCancelCreditRow.TransactionJournal);
      row.pointTypeName = getExpiryPointTypeName(redeemCancelCreditRow, null);
      row.redemptionType = getTraceabilityActionLabel('DebitCancellation');
      row.redemptionPoints = redeemCancelCreditRow.Points == null ? 0 : Integer.valueOf(redeemCancelCreditRow.Points.abs());
      row.saleNo = redeemCancelCreditRow.TransactionJournal != null &&
        redeemCancelCreditRow.TransactionJournal.Order != null
        ? redeemCancelCreditRow.TransactionJournal.Order.SaleNo__c
        : null;
      row.orderNo = redeemCancelCreditRow.TransactionJournal != null &&
        redeemCancelCreditRow.TransactionJournal.Order != null
        ? redeemCancelCreditRow.TransactionJournal.Order.OrderNo__c
        : null;
      row.recordId = redeemCancelCreditRow.TransactionJournal != null ? redeemCancelCreditRow.TransactionJournal.OrderId : null;
      row.saleAmount = redeemCancelCreditRow.TransactionJournal != null &&
        redeemCancelCreditRow.TransactionJournal.Order != null
        ? toInteger(redeemCancelCreditRow.TransactionJournal.Order.ActualPaymentAmount__c)
        : 0;
      row.accrualSaleNo = null;
      row.returnSaleNo = row.saleNo;
      row.isCancel = true;

      results.add(row);
    }

    results.sort();

    return results;
  }

  private static String getExpiryPointTypeName(LoyaltyLedger expiryRow, Map<Id, String> subtypeNameById) {
    if (expiryRow == null) {
      return '';
    }

    if (expiryRow.LoyaltyPgmCrcySubtype != null && !String.isBlank(expiryRow.LoyaltyPgmCrcySubtype.Name)) {
      return expiryRow.LoyaltyPgmCrcySubtype.Name;
    }

    if (expiryRow.LoyaltyPgmCrcySubtypeId != null && subtypeNameById != null && subtypeNameById.containsKey(expiryRow.LoyaltyPgmCrcySubtypeId)) {
      return subtypeNameById.get(expiryRow.LoyaltyPgmCrcySubtypeId);
    }

    return '';
  }

  private static Map<Id, String> buildSubtypeNameMap(List<LoyaltyLedger> expiryRows) {
    Map<Id, String> result = new Map<Id, String>();
    Set<Id> subtypeIds = new Set<Id>();

    if (expiryRows == null || expiryRows.isEmpty()) {
      return result;
    }

    for (LoyaltyLedger expiryRow : expiryRows) {
      if (expiryRow != null && expiryRow.LoyaltyPgmCrcySubtypeId != null) {
        subtypeIds.add(expiryRow.LoyaltyPgmCrcySubtypeId);
      }
    }

    if (subtypeIds.isEmpty()) {
      return result;
    }

    for (LoyaltyPgmCurrencySubtype subtype : [
      SELECT Id, Name
      FROM LoyaltyPgmCurrencySubtype
      WHERE Id IN :subtypeIds
    ]) {
      result.put(subtype.Id, subtype.Name);
    }

    return result;
  }

  private static String getTraceabilityPointTypeName(LoyaltyLedgerTraceability traceRow) {
    if (traceRow == null) {
      return '';
    }

    if (traceRow.LoyaltyPgmCurrencySubtype != null && !String.isBlank(traceRow.LoyaltyPgmCurrencySubtype.Name)) {
      return traceRow.LoyaltyPgmCurrencySubtype.Name;
    }

    return '';
  }

  private static String getTraceabilityActionLabel(String actionType) {
    if (actionType == 'CreditCancellation') {
      return '\uC801\uB9BD\uCDE8\uC18C';
    }

    if (actionType == 'Debit') {
      return '\uC0AC\uC6A9';
    }
    if (actionType == 'DebitCancellation') {
      return '\uC0AC\uC6A9\uCDE8\uC18C';
    }
    if (actionType == 'Expiry') {
      return '\uC18C\uBA78';
    }

    return String.isBlank(actionType) ? '' : actionType;
  }

  private static Date getDebitJournalDate(LoyaltyLedgerTraceability traceRow) {
    if (traceRow == null || traceRow.DebitLoyaltyLedger == null || traceRow.DebitLoyaltyLedger.TransactionJournal == null) {
      return null;
    }

    return getJournalDate(traceRow.DebitLoyaltyLedger.TransactionJournal);
  }

  private static Date getJournalDate(TransactionJournal journal) {
    return journal != null && journal.JournalDate != null ? journal.JournalDate.date() : null;
  }

  private static Map<String, UsageSummary> buildUsageSummaryMap(Id loyaltyProgramMemberId, Set<Id> orderIds, Set<Id> subtypeIds) {
    Map<String, UsageSummary> result = new Map<String, UsageSummary>();

    if (orderIds.isEmpty() || subtypeIds.isEmpty()) {
      return result;
    }

    Id cancelPurchaseAccrualSubTypeId = getJournalSubTypeIdByName(JOURNAL_SUBTYPE_CANCEL_PURCHASE_ACCRUAL);
    for (AggregateResult ar : [
      SELECT TransactionJournal.OrderId orderId, LoyaltyPgmCrcySubtypeId subtypeId, EventType eventType, SUM(Points) totalPoints
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :loyaltyProgramMemberId
        AND EventType IN ('Debit', 'Expiry')
        AND TransactionJournal.OrderId IN :orderIds
        AND LoyaltyPgmCrcySubtypeId IN :subtypeIds
        AND (TransactionJournal.JournalSubTypeId = NULL
        OR TransactionJournal.JournalSubTypeId != :cancelPurchaseAccrualSubTypeId)
      GROUP BY TransactionJournal.OrderId, LoyaltyPgmCrcySubtypeId, EventType
    ]) {
      Id orderId = (Id) ar.get('orderId');
      Id subtypeId = (Id) ar.get('subtypeId');
      String eventType = (String) ar.get('eventType');
      Decimal totalPoints = (Decimal) ar.get('totalPoints');
      String key = buildOrderSubtypeKey(orderId, subtypeId);

      if (!result.containsKey(key)) {
        result.put(key, new UsageSummary());
      }

      Integer amount = totalPoints == null ? 0 : Integer.valueOf(totalPoints.abs());
      UsageSummary usage = result.get(key);

      if (eventType == 'Debit') {
        usage.usedPoints += amount;
      } else if (eventType == 'Expiry') {
        usage.expiredPoints += amount;
      }
    }

    return result;
  }

  private static Map<Id, PaymentSummary> buildPaymentSummaryMap(Set<Id> orderIds) {
    Map<Id, PaymentSummary> result = new Map<Id, PaymentSummary>();

    if (orderIds.isEmpty()) {
      return result;
    }

    Set<Id> excludedPaymentJournalSubTypeIds = getJournalSubTypeIdsByNames(
      new Set<String>{ 'Coupon Redeem Cancel', 'Point Redeem Cancel', 'Order Deposit Reversal', 'Sale Deposit Reversal', 'Cancel Purchase Accrual' }
    );
    for (AggregateResult ar : [
      SELECT OrderId orderId, PaymentMethod paymentMethod, SUM(TransactionAmount) totalAmount
      FROM TransactionJournal
      WHERE
        OrderId IN :orderIds
        AND TransactionAmount != NULL
        AND PaymentMethod != NULL
        AND IsDeleted__c = FALSE
        AND (JournalSubTypeId = NULL
        OR JournalSubTypeId NOT IN :excludedPaymentJournalSubTypeIds)
      GROUP BY OrderId, PaymentMethod
    ]) {
      Id orderId = (Id) ar.get('orderId');
      String paymentMethod = (String) ar.get('paymentMethod');
      Decimal totalAmount = (Decimal) ar.get('totalAmount');

      if (!result.containsKey(orderId)) {
        result.put(orderId, new PaymentSummary());
      }

      Integer amount = totalAmount == null ? 0 : Integer.valueOf(totalAmount);
      PaymentSummary summary = result.get(orderId);

      if (COUPON_PAYMENT_METHODS.contains(paymentMethod)) {
        summary.depositCouponAmount += amount;
      } else if (POINT_PAYMENT_METHODS.contains(paymentMethod)) {
        summary.depositPointAmount += amount;
      } else if (paymentMethod == HQ_EXCHANGE_PAYMENT_METHOD) {
        summary.depositHqExchangeAmount += amount;
      }
    }

    return result;
  }

  private static Map<Id, RelatedOrderInfo> buildRelatedOrderInfoMap(Set<Id> orderIds) {
    Map<Id, RelatedOrderInfo> result = new Map<Id, RelatedOrderInfo>();

    if (orderIds.isEmpty()) {
      return result;
    }

    Id purchaseAccrualSubTypeId = getJournalSubTypeIdByName(JOURNAL_SUBTYPE_PURCHASE_ACCRUAL);
    Id cancelPurchaseAccrualSubTypeId = getJournalSubTypeIdByName(JOURNAL_SUBTYPE_CANCEL_PURCHASE_ACCRUAL);
    for (TransactionJournal journal : [
      SELECT OrderId, Order.SaleNo__c, JournalSubTypeId
      FROM TransactionJournal
      WHERE OrderId IN :orderIds AND JournalSubTypeId IN :new Set<Id>{ purchaseAccrualSubTypeId, cancelPurchaseAccrualSubTypeId }
    ]) {
      if (!result.containsKey(journal.OrderId)) {
        result.put(journal.OrderId, new RelatedOrderInfo());
      }

      RelatedOrderInfo info = result.get(journal.OrderId);

      if (journal.JournalSubTypeId == purchaseAccrualSubTypeId) {
        info.accrualSaleNo = journal.Order != null ? journal.Order.SaleNo__c : null;
      } else if (journal.JournalSubTypeId == cancelPurchaseAccrualSubTypeId) {
        info.returnSaleNo = journal.Order != null ? journal.Order.SaleNo__c : null;
      }
    }

    return result;
  }

  private static Id getJournalSubTypeIdByName(String name) {
    if (String.isBlank(name)) {
      return null;
    }
    if (journalSubTypeIdsByName == null) {
      journalSubTypeIdsByName = new Map<String, Id>();
    }
    if (!journalSubTypeIdsByName.containsKey(name)) {
      List<JournalSubType> rows = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :name
        LIMIT 1
      ];
      journalSubTypeIdsByName.put(name, rows.isEmpty() ? null : rows[0].Id);
    }
    return journalSubTypeIdsByName.get(name);
  }

  private static Set<Id> getJournalSubTypeIdsByNames(Set<String> names) {
    Set<Id> result = new Set<Id>();
    if (names == null || names.isEmpty()) {
      return result;
    }
    for (String name : names) {
      Id subTypeId = getJournalSubTypeIdByName(name);
      if (subTypeId != null) {
        result.add(subTypeId);
      }
    }
    return result;
  }

  private static String buildOrderSubtypeKey(Id orderId, Id subtypeId) {
    return String.valueOf(orderId) + ':' + String.valueOf(subtypeId);
  }

  private static Integer toInteger(Decimal value) {
    return value == null ? 0 : Integer.valueOf(value);
  }

  private class UsageSummary {
    public Integer usedPoints = 0;
    public Integer expiredPoints = 0;
  }

  private class PaymentSummary {
    public Integer depositCouponAmount = 0;
    public Integer depositPointAmount = 0;
    public Integer depositHqExchangeAmount = 0;
  }

  private class RelatedOrderInfo {
    public String accrualSaleNo;
    public String returnSaleNo;
  }

  public class PointLedgerRowDTO {
    @AuraEnabled
    public Id ledgerId;
    @AuraEnabled
    public String pointTypeName;
    @AuraEnabled
    public Date transactionDate;
    @AuraEnabled
    public Integer accruedPoints;
    @AuraEnabled
    public Integer usedPoints;
    @AuraEnabled
    public Integer expiredPoints;
    @AuraEnabled
    public Date startDate;
    @AuraEnabled
    public Date endDate;
    @AuraEnabled
    public Date saleDate;
    @AuraEnabled
    public String saleNo;
    @AuraEnabled
    public Id saleOrderId;
    @AuraEnabled
    public Integer saleAmount;
    @AuraEnabled
    public Integer depositCouponAmount;
    @AuraEnabled
    public Integer depositPointAmount;
    @AuraEnabled
    public Integer depositHqExchangeAmount;
  }

  public class PointRedemptionRowDTO implements Comparable {
    @AuraEnabled
    public Id ledgerId;
    @AuraEnabled
    public Date redemptionDate;
    @AuraEnabled
    public String pointTypeName;
    @AuraEnabled
    public String redemptionType;
    @AuraEnabled
    public Integer redemptionPoints;
    @AuraEnabled
    public String orderNo;
    @AuraEnabled
    public String saleNo;
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public Integer saleAmount;
    @AuraEnabled
    public String accrualSaleNo;
    @AuraEnabled
    public Id accrualRecordId;
    @AuraEnabled
    public String returnSaleNo;
    @AuraEnabled
    public Boolean isCancel;

    public Integer compareTo(Object other) {
      PointRedemptionRowDTO target = (PointRedemptionRowDTO) other;
      Date thisDate = redemptionDate;
      Date otherDate = target == null ? null : target.redemptionDate;

      if (thisDate == otherDate) {
        return 0;
      }
      if (thisDate == null) {
        return 1;
      }
      if (otherDate == null) {
        return -1;
      }
      if (thisDate > otherDate) {
        return -1;
      }
      return 1;
    }
  }
}