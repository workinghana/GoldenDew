public without sharing class LoyaltyPointEventValidator {
  private static final String PAYMENT_METHOD_POINT = '81';
  private static final String DEPOSIT_TYPE_RETURN = '03';
  private static final String ACTION_CREDIT_CANCELLATION = 'CreditCancellation';
  private static final String JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final Set<String> ACCRUAL_EXCLUDED_PAYMENT_METHODS = new Set<String>{ '20', '81', '90', '93' };
  private static final String UNKNOWN_POINT_TYPE = 'UNKNOWN';

  public class ValidationResult {
    public Boolean isValid;
    public String eventType;
    public Id memberId;
    public String memberNo;
    public String memberName;
    public Id orderId;
    public Id originalOrderId;
    public String saleNo;
    public String originalSaleNo;
    public Decimal expectedCreditCancelPoints = 0;
    public Decimal actualCreditCancelPoints = 0;
    public Decimal expectedRedeemCancelPoints = 0;
    public Decimal actualRedeemCancelPoints = 0;
    public Decimal creditCancelDifference = 0;
    public Decimal redeemCancelDifference = 0;
    public Map<String, Decimal> expectedCreditCancelByType = new Map<String, Decimal>();
    public Map<String, Decimal> actualCreditCancelByType = new Map<String, Decimal>();
    public Map<String, Decimal> expectedRedeemCancelByType = new Map<String, Decimal>();
    public Map<String, Decimal> actualRedeemCancelByType = new Map<String, Decimal>();
    public String summary;
  }

  public static ValidationResult validateSaleDelete(String saleNo) {
    return validateSaleDelete(findOrderBySaleNo(saleNo));
  }

  public static ValidationResult validateSaleDelete(Id orderId) {
    return validateSaleDelete(findOrderById(orderId));
  }

  public static ValidationResult validateReturnCreate(String returnSaleNo) {
    return validateReturnCreate(findOrderBySaleNo(returnSaleNo));
  }

  public static ValidationResult validateReturnCreate(Id returnOrderId) {
    return validateReturnCreate(findOrderById(returnOrderId));
  }

  public static ValidationResult validateSaleDepositDelete(String depositNo) {
    return validateDepositDelete('SALE_DEPOSIT_DELETE', findDeletedDeposit(depositNo));
  }

  public static ValidationResult validateReturnDepositDelete(String depositNo) {
    return validateDepositDelete('RETURN_DEPOSIT_DELETE', findDeletedDeposit(depositNo));
  }

  public static Boolean validateAndAlertSaleDelete(String saleNo) {
    return alertIfInvalid(validateSaleDelete(saleNo));
  }

  public static Boolean validateAndAlertReturnCreate(String returnSaleNo) {
    return alertIfInvalid(validateReturnCreate(returnSaleNo));
  }

  public static Boolean validateAndAlertSaleDepositDelete(String depositNo) {
    return alertIfInvalid(validateSaleDepositDelete(depositNo));
  }

  public static Boolean validateAndAlertReturnDepositDelete(String depositNo) {
    return alertIfInvalid(validateReturnDepositDelete(depositNo));
  }

  private static ValidationResult validateSaleDelete(Order saleOrder) {
    if (saleOrder == null) {
      return invalidMissing('SALE_DELETE', '삭제 판매를 찾을 수 없습니다.');
    }

    ValidationResult result = baseResult('SALE_DELETE', saleOrder);
    result.expectedCreditCancelByType = sumEffectiveAccrualPointsByType(saleOrder.Id);
    result.actualCreditCancelByType = sumCreditCancellationByOriginOrderByType(saleOrder.Id);
    finalizeResult(result);
    return result;
  }

  private static ValidationResult validateReturnCreate(Order returnOrder) {
    if (returnOrder == null) {
      return invalidMissing('RETURN_CREATE', '반품 판매를 찾을 수 없습니다.');
    }

    ValidationResult result = baseResult('RETURN_CREATE', returnOrder);
    result.originalOrderId = returnOrder.OriginalOrderId__c;
    if (returnOrder.OriginalOrderId__c != null) {
      Order originalOrder = findOrderById(returnOrder.OriginalOrderId__c);
      result.originalSaleNo = originalOrder == null ? null : originalOrder.SaleNo__c;
      result.expectedCreditCancelByType = estimateReturnCreditCancelPointsByType(returnOrder);
      result.actualCreditCancelByType = sumCreditCancellationByDebitOrderByType(returnOrder.Id);
    }

    result.expectedRedeemCancelPoints = sumPointReturnDeposits(returnOrder.Id);
    result.actualRedeemCancelByType = sumPointRedeemCancelCreditsByType(returnOrder.Id);
    finalizeResult(result);
    return result;
  }

  private static ValidationResult validateDepositDelete(String eventType, TransactionJournal deletedDeposit) {
    if (deletedDeposit == null) {
      return invalidMissing(eventType, '삭제 입금 TransactionJournal을 찾을 수 없습니다.');
    }

    Id eventOrderId = resolveEventOrderId(deletedDeposit);
    Order eventOrder = eventOrderId == null ? deletedDeposit.Order : findOrderById(eventOrderId);
    ValidationResult result = baseResult(eventType, eventOrder);
    result.orderId = eventOrderId == null ? deletedDeposit.OrderId : eventOrderId;
    result.memberId = deletedDeposit.MemberId;
    if (deletedDeposit.MemberId != null) {
      populateMemberById(result, deletedDeposit.MemberId);
    }
    result.saleNo = eventOrder == null ? null : eventOrder.SaleNo__c;

    if (deletedDeposit.PaymentMethod == PAYMENT_METHOD_POINT) {
      result.expectedRedeemCancelPoints = absDecimal(deletedDeposit.TransactionAmount);
      result.actualRedeemCancelByType = sumPointRedeemCancelCreditsByType(result.orderId);
    } else if (deletedDeposit.DepositType__c == DEPOSIT_TYPE_RETURN && eventOrder != null) {
      result.expectedCreditCancelByType = estimateReturnCreditCancelPointsByType(eventOrder);
      result.actualCreditCancelByType = sumCreditCancellationByDebitOrderByType(result.orderId);
    }

    finalizeResult(result);
    return result;
  }

  private static Order findOrderBySaleNo(String saleNo) {
    if (String.isBlank(saleNo)) {
      return null;
    }
    List<Order> rows = [
      SELECT Id, SaleNo__c, OriginalOrderId__c, IsReductionOrder__c, MemberNo__c, AccountId, TotalAmount, ActualPaymentAmount__c
      FROM Order
      WHERE SaleNo__c = :saleNo
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static Order findOrderById(Id orderId) {
    if (orderId == null) {
      return null;
    }
    List<Order> rows = [
      SELECT Id, SaleNo__c, OriginalOrderId__c, IsReductionOrder__c, MemberNo__c, AccountId, TotalAmount, ActualPaymentAmount__c
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static TransactionJournal findDeletedDeposit(String depositNo) {
    if (String.isBlank(depositNo)) {
      return null;
    }
    List<TransactionJournal> rows = [
      SELECT
        Id,
        OrderId,
        SaleId__c,
        MemberId,
        PaymentMethod,
        DepositType__c,
        TransactionAmount,
        DepositNo__c,
        IsDeleted__c,
        Order.Id,
        Order.SaleNo__c,
        Order.OriginalOrderId__c,
        Order.IsReductionOrder__c,
        Order.MemberNo__c,
        Order.AccountId,
        Order.TotalAmount,
        Order.ActualPaymentAmount__c
      FROM TransactionJournal
      WHERE DepositNo__c = :depositNo AND IsDeleted__c = TRUE
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static ValidationResult baseResult(String eventType, Order orderRecord) {
    ValidationResult result = new ValidationResult();
    result.eventType = eventType;
    if (orderRecord != null) {
      result.orderId = orderRecord.Id;
      result.originalOrderId = orderRecord.OriginalOrderId__c;
      result.saleNo = orderRecord.SaleNo__c;
      result.memberNo = orderRecord.MemberNo__c;
      populateMember(result, orderRecord);
    }
    return result;
  }

  private static ValidationResult invalidMissing(String eventType, String message) {
    ValidationResult result = new ValidationResult();
    result.eventType = eventType;
    result.isValid = false;
    result.summary = message;
    return result;
  }

  private static void populateMember(ValidationResult result, Order orderRecord) {
    if (orderRecord == null || String.isBlank(orderRecord.MemberNo__c)) {
      return;
    }
    String memberRef = orderRecord.MemberNo__c;
    List<LoyaltyProgramMember> members;
    if (isSalesforceId(memberRef) && memberRef.startsWith('003')) {
      Id contactId = (Id) memberRef;
      members = [
        SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
        FROM LoyaltyProgramMember
        WHERE ContactId = :contactId AND MemberStatus = 'Active'
        LIMIT 1
      ];
    } else {
      members = [
        SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberRef AND MemberStatus = 'Active'
        LIMIT 1
      ];
    }
    applyMember(result, members);
  }

  private static void populateMemberById(ValidationResult result, Id memberId) {
    if (memberId == null) {
      return;
    }
    List<LoyaltyProgramMember> members = [
      SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
      FROM LoyaltyProgramMember
      WHERE Id = :memberId
      LIMIT 1
    ];
    applyMember(result, members);
  }

  private static void applyMember(ValidationResult result, List<LoyaltyProgramMember> members) {
    if (!members.isEmpty()) {
      result.memberId = members[0].Id;
      result.memberNo = members[0].Contact == null ? members[0].MembershipNumber : members[0].Contact.MemberNo__c;
      result.memberName = getMemberName(members[0]);
    }
  }

  private static Map<String, Decimal> estimateReturnCreditCancelPointsByType(Order returnOrder) {
    Map<String, Decimal> emptyResult = new Map<String, Decimal>();
    if (returnOrder == null || returnOrder.OriginalOrderId__c == null) {
      return emptyResult;
    }

    Map<String, Decimal> originalCreditsByType = sumEffectiveAccrualPointsByType(returnOrder.OriginalOrderId__c);
    Decimal originalEligibleAmount = calculateOriginalSaleEligibleAmount(returnOrder.OriginalOrderId__c);
    Decimal returnEligibleAmount = calculateReturnEligibleAmount(returnOrder.Id);
    if (originalCreditsByType.isEmpty() || originalEligibleAmount <= 0 || returnEligibleAmount <= 0) {
      return emptyResult;
    }
    return prorateByType(originalCreditsByType, returnEligibleAmount, originalEligibleAmount);
  }

  private static Map<String, Decimal> sumOriginalAccrualPointsByType(Id orderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (orderId == null) {
      return result;
    }
    String orderIdText = String.valueOf(orderId);
    for (AggregateResult row : [
      SELECT LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedger
      WHERE (TransactionJournal.OrderId = :orderId OR TransactionJournal.SaleId__c = :orderIdText)
        AND EventType = 'Credit'
        AND (TransactionJournal.JournalSubType.Name = NULL OR TransactionJournal.JournalSubType.Name != :JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL)
      GROUP BY LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Map<String, Decimal> sumEffectiveAccrualPointsByType(Id orderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (orderId == null) {
      return result;
    }

    String orderIdText = String.valueOf(orderId);
    List<LoyaltyLedger> creditLedgers = [
      SELECT Id, Points, LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE (TransactionJournal.OrderId = :orderId OR TransactionJournal.SaleId__c = :orderIdText)
        AND EventType = 'Credit'
        AND TransactionJournal.IsDeleted__c = FALSE
        AND (TransactionJournal.JournalSubType.Name = NULL OR TransactionJournal.JournalSubType.Name != :JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL)
    ];
    if (creditLedgers.isEmpty()) {
      return result;
    }

    Map<Id, LoyaltyLedger> creditById = new Map<Id, LoyaltyLedger>(creditLedgers);
    Map<Id, Decimal> canceledByCreditId = new Map<Id, Decimal>();
    for (AggregateResult row : [
      SELECT CreditLoyaltyLedgerId creditId, SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId IN :creditById.keySet()
        AND ActionType = :ACTION_CREDIT_CANCELLATION
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      GROUP BY CreditLoyaltyLedgerId
    ]) {
      canceledByCreditId.put((Id) row.get('creditId'), absDecimal((Decimal) row.get('total')));
    }

    for (LoyaltyLedger creditLedger : creditLedgers) {
      Decimal creditPoints = absDecimal(creditLedger.Points);
      Decimal canceledPoints = canceledByCreditId.containsKey(creditLedger.Id) ? canceledByCreditId.get(creditLedger.Id) : 0;
      Decimal effectivePoints = creditPoints - canceledPoints;
      if (effectivePoints > 0) {
        addToMap(result, normalizePointType(creditLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c), effectivePoints);
      }
    }
    return result;
  }

  private static Map<String, Decimal> sumCreditCancellationByOriginOrderByType(Id originalOrderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (originalOrderId == null) {
      return result;
    }
    String originalOrderIdText = String.valueOf(originalOrderId);
    for (AggregateResult row : [
      SELECT CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE ActionType = :ACTION_CREDIT_CANCELLATION
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (CreditLoyaltyLedger.TransactionJournal.OrderId = :originalOrderId
        OR CreditLoyaltyLedger.TransactionJournal.SaleId__c = :originalOrderIdText)
      GROUP BY CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Map<String, Decimal> sumCreditCancellationByDebitOrderByType(Id debitOrderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (debitOrderId == null) {
      return result;
    }
    String debitOrderIdText = String.valueOf(debitOrderId);
    for (AggregateResult row : [
      SELECT CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE ActionType = :ACTION_CREDIT_CANCELLATION
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (DebitLoyaltyLedger.TransactionJournal.OrderId = :debitOrderId
        OR DebitLoyaltyLedger.TransactionJournal.SaleId__c = :debitOrderIdText)
      GROUP BY CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Decimal sumPointReturnDeposits(Id orderId) {
    if (orderId == null) {
      return 0;
    }
    String orderIdText = String.valueOf(orderId);
    List<AggregateResult> rows = [
      SELECT SUM(TransactionAmount) total
      FROM TransactionJournal
      WHERE (OrderId = :orderId OR SaleId__c = :orderIdText)
        AND PaymentMethod = :PAYMENT_METHOD_POINT
        AND DepositType__c = :DEPOSIT_TYPE_RETURN
        AND IsDeleted__c = FALSE
    ];
    return aggregateDecimal(rows, 'total').abs();
  }

  private static Map<String, Decimal> sumPointRedeemCancelCreditsByType(Id orderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (orderId == null) {
      return result;
    }
    String orderIdText = String.valueOf(orderId);
    for (AggregateResult row : [
      SELECT LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedger
      WHERE (TransactionJournal.OrderId = :orderId OR TransactionJournal.SaleId__c = :orderIdText)
        AND EventType = 'Credit'
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL
      GROUP BY LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Decimal calculateOriginalSaleEligibleAmount(Id originalOrderId) {
    if (originalOrderId == null) {
      return 0;
    }
    Decimal eligibleDepositAmount = calculateAccrualEligibleDepositAmount(originalOrderId, false);
    Decimal excludedAmount = calculateSaleExcludedAmount(originalOrderId);
    Decimal result = eligibleDepositAmount - excludedAmount;
    return result <= 0 ? 0 : result;
  }

  private static Decimal calculateReturnEligibleAmount(Id returnOrderId) {
    if (returnOrderId == null) {
      return 0;
    }
    Decimal eligibleDepositAmount = calculateAccrualEligibleDepositAmount(returnOrderId, true);
    Decimal excludedAmount = calculateReturnExcludedAmount(returnOrderId);
    Decimal result = eligibleDepositAmount - excludedAmount;
    return result <= 0 ? 0 : result;
  }

  private static Decimal calculateAccrualEligibleDepositAmount(Id orderId, Boolean includeReturnDepositTypes) {
    Decimal total = 0;
    if (orderId == null) {
      return total;
    }
    String orderIdText = String.valueOf(orderId);
    for (TransactionJournal tj : [
      SELECT PaymentMethod, DepositType__c, TransactionAmount
      FROM TransactionJournal
      WHERE (OrderId = :orderId OR SaleId__c = :orderIdText)
        AND IsDeleted__c = FALSE
    ]) {
      if (!isAccrualEligiblePayment(tj)) {
        continue;
      }
      Boolean depositTypeEligible = includeReturnDepositTypes
        ? (tj.DepositType__c == '03' || tj.DepositType__c == '05')
        : (tj.DepositType__c == '01' || tj.DepositType__c == '02');
      if (!depositTypeEligible) {
        continue;
      }
      total += absDecimal(tj.TransactionAmount);
    }
    return total;
  }

  private static Boolean isAccrualEligiblePayment(TransactionJournal tj) {
    if (tj == null || tj.TransactionAmount == null || tj.TransactionAmount == 0) {
      return false;
    }
    if (String.isBlank(tj.PaymentMethod) || ACCRUAL_EXCLUDED_PAYMENT_METHODS.contains(tj.PaymentMethod)) {
      return false;
    }
    return true;
  }

  private static Decimal calculateSaleExcludedAmount(Id orderId) {
    Decimal excludedAmount = 0;
    if (orderId == null) {
      return excludedAmount;
    }
    for (OrderItem oi : [
      SELECT NetSalesUnitPrice__c, Quantity, IsExclude__c
      FROM OrderItem
      WHERE OrderId = :orderId
    ]) {
      if (oi.IsExclude__c == true) {
        excludedAmount += absDecimal(oi.NetSalesUnitPrice__c) * absDecimal(oi.Quantity == null ? 1 : oi.Quantity);
      }
    }
    return excludedAmount;
  }

  private static Decimal calculateReturnExcludedAmount(Id returnOrderId) {
    Decimal excludedAmount = 0;
    if (returnOrderId == null) {
      return excludedAmount;
    }
    for (OrderItem oi : [
      SELECT
        IsExclude__c,
        NetSalesUnitPrice__c,
        Quantity,
        OriginalOrderItemId__c,
        OriginalOrderItem.IsExclude__c,
        OriginalOrderItem.NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :returnOrderId
    ]) {
      Boolean isExcluded = oi.OriginalOrderItemId__c != null ? oi.OriginalOrderItem.IsExclude__c : oi.IsExclude__c;
      Decimal unitPrice = oi.OriginalOrderItemId__c != null ? oi.OriginalOrderItem.NetSalesUnitPrice__c : oi.NetSalesUnitPrice__c;
      if (isExcluded == true) {
        excludedAmount += absDecimal(unitPrice) * absDecimal(oi.Quantity == null ? 1 : oi.Quantity);
      }
    }
    return excludedAmount;
  }

  private static Map<String, Decimal> prorateByType(Map<String, Decimal> sourceByType, Decimal numerator, Decimal denominator) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (sourceByType == null || sourceByType.isEmpty() || numerator == null || denominator == null || denominator <= 0) {
      return result;
    }
    for (String pointType : sourceByType.keySet()) {
      Decimal sourcePoints = sourceByType.get(pointType) == null ? 0 : sourceByType.get(pointType);
      Decimal points = (sourcePoints * numerator / denominator).setScale(0, RoundingMode.HALF_UP);
      if (points > 0) {
        result.put(pointType, points);
      }
    }
    return result;
  }

  private static void finalizeResult(ValidationResult result) {
    result.expectedCreditCancelPoints = sumMap(result.expectedCreditCancelByType);
    result.actualCreditCancelPoints = sumMap(result.actualCreditCancelByType);
    if (result.expectedRedeemCancelPoints == null || result.expectedRedeemCancelPoints == 0) {
      result.expectedRedeemCancelPoints = sumMap(result.expectedRedeemCancelByType);
    }
    result.actualRedeemCancelPoints = sumMap(result.actualRedeemCancelByType);

    result.creditCancelDifference = result.actualCreditCancelPoints - result.expectedCreditCancelPoints;
    result.redeemCancelDifference = result.actualRedeemCancelPoints - result.expectedRedeemCancelPoints;
    result.isValid = result.creditCancelDifference == 0 && result.redeemCancelDifference == 0;
    result.summary = result.isValid
      ? '포인트 이벤트 검증 정상'
      : '포인트 이벤트 검증 불일치. 적립취소 기대=' + formatPoint(result.expectedCreditCancelPoints) +
        'P/실제=' + formatPoint(result.actualCreditCancelPoints) +
        'P, 사용취소 기대=' + formatPoint(result.expectedRedeemCancelPoints) +
        'P/실제=' + formatPoint(result.actualRedeemCancelPoints) +
        'P, 기대 적립취소 타입별=' + JSON.serialize(result.expectedCreditCancelByType) +
        ', 실제 적립취소 타입별=' + JSON.serialize(result.actualCreditCancelByType);
  }

  private static Boolean alertIfInvalid(ValidationResult result) {
    if (result == null || result.isValid == true) {
      return true;
    }
    return sendValidationAlert(result);
  }

  private static Boolean sendValidationAlert(ValidationResult result) {
    Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
    if (config == null || !config.Is_Active__c || String.isBlank(config.Webhook_URL__c)) {
      System.debug(LoggingLevel.WARN, '[포인트 이벤트 검증] Slack 설정이 비활성화되어 알림을 보내지 않습니다. ' + result.summary);
      return false;
    }

    HttpRequest req = new HttpRequest();
    req.setEndpoint(config.Webhook_URL__c);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(buildSlackBody(result));
    req.setTimeout(10000);

    HttpResponse res = new Http().send(req);
    return res.getStatusCode() >= 200 && res.getStatusCode() < 300;
  }

  private static String buildSlackBody(ValidationResult result) {
    String orgUrl = URL.getOrgDomainUrl().toExternalForm();
    String memberLink = result.memberId == null ? '' : orgUrl + '/' + result.memberId;
    String memberTitle = String.isBlank(memberLink)
      ? String.valueOf(result.memberName)
      : '<' + memberLink + '|' + result.memberName + '>';

    Map<String, Object> msg = new Map<String, Object>{
      'text' => '[골든듀 모니터링] 포인트 이벤트 검증 불일치',
      'blocks' => new List<Object>{
        new Map<String, Object>{
          'type' => 'header',
          'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => '포인트 이벤트 검증 불일치' }
        },
        new Map<String, Object>{
          'type' => 'section',
          'fields' => new List<Object>{
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*이벤트*\n' + result.eventType },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원*\n' + memberTitle },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원번호*\n' + String.valueOf(result.memberNo) },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*판매번호*\n' + String.valueOf(result.saleNo) },
            new Map<String, Object>{
              'type' => 'mrkdwn',
              'text' => '*적립취소 기대/실제*\n' + formatPoint(result.expectedCreditCancelPoints) + 'P / ' + formatPoint(result.actualCreditCancelPoints) + 'P'
            },
            new Map<String, Object>{
              'type' => 'mrkdwn',
              'text' => '*사용취소 기대/실제*\n' + formatPoint(result.expectedRedeemCancelPoints) + 'P / ' + formatPoint(result.actualRedeemCancelPoints) + 'P'
            }
          }
        },
        new Map<String, Object>{
          'type' => 'section',
          'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*요약*\n' + result.summary }
        }
      }
    };
    return JSON.serialize(msg);
  }

  private static Decimal aggregateDecimal(List<AggregateResult> rows, String fieldName) {
    if (rows == null || rows.isEmpty() || rows[0].get(fieldName) == null) {
      return 0;
    }
    return (Decimal) rows[0].get(fieldName);
  }

  private static Decimal absDecimal(Decimal value) {
    return value == null ? 0 : value.abs();
  }

  private static Decimal sumMap(Map<String, Decimal> valuesByKey) {
    Decimal total = 0;
    if (valuesByKey == null) {
      return total;
    }
    for (Decimal value : valuesByKey.values()) {
      total += value == null ? 0 : value;
    }
    return total;
  }

  private static void addToMap(Map<String, Decimal> valuesByKey, String key, Decimal value) {
    if (valuesByKey == null || value == null || value == 0) {
      return;
    }
    String normalizedKey = normalizePointType(key);
    valuesByKey.put(normalizedKey, (valuesByKey.containsKey(normalizedKey) ? valuesByKey.get(normalizedKey) : 0) + value);
  }

  private static String normalizePointType(String pointType) {
    return String.isBlank(pointType) ? UNKNOWN_POINT_TYPE : pointType.trim();
  }

  private static Id resolveEventOrderId(TransactionJournal tj) {
    if (tj == null) {
      return null;
    }
    if (String.isNotBlank(tj.SaleId__c) && isSalesforceId(tj.SaleId__c)) {
      return (Id) tj.SaleId__c;
    }
    return tj.OrderId;
  }

  private static Boolean isSalesforceId(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    try {
      Id parsedId = (Id) value;
      return parsedId != null;
    } catch (Exception e) {
      return false;
    }
  }

  private static String getMemberName(LoyaltyProgramMember member) {
    if (member.Contact != null && String.isNotBlank(member.Contact.Name)) {
      return member.Contact.Name;
    }
    if (member.Account != null && String.isNotBlank(member.Account.Name)) {
      return member.Account.Name;
    }
    return member.MembershipNumber != null ? member.MembershipNumber : '(이름 없음)';
  }

  private static String formatPoint(Decimal value) {
    return String.valueOf(value == null ? 0 : value.setScale(0));
  }
}