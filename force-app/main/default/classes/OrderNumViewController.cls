public with sharing class OrderNumViewController {
  private static final Set<String> CASH_PAYMENT_METHODS = new Set<String>{ '01' };
  private static final Set<String> CARD_PAYMENT_METHODS = new Set<String>{ '03' };
  private static final Set<String> COUPON_PAYMENT_METHODS = new Set<String>{ '90', '91', '92', '93' };
  private static final Set<String> POINT_PAYMENT_METHODS = new Set<String>{ '81' };
  private static final String DEFAULT_POINT_CODE = '00';
  private static final String DEFAULT_POINT_LABEL = '포인트';
  private static final String DEFAULT_PRODUCT_LABEL = '상품 정보 없음';

  @AuraEnabled(cacheable=true)
  public static OrderDetailDto getOrderNumView(Id orderId) {
    Order orderRecord = fetchOrder(orderId);
    Order saleOrder = orderRecord;
    Order displayOrder = orderRecord;
    Order returnOrder;

    if (orderRecord.IsReductionOrder == true) {
      returnOrder = orderRecord;

      if (orderRecord.OriginalOrderId != null) {
        saleOrder = fetchOrder(orderRecord.OriginalOrderId);
      }
    } else {
      List<Order> returnOrders = [
        SELECT Id, SaleNo__c, Status, EndDate, EffectiveDate, IsReductionOrder
        FROM Order
        WHERE OriginalOrderId = :saleOrder.Id AND IsReductionOrder = TRUE
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];

      if (!returnOrders.isEmpty()) {
        returnOrder = returnOrders[0];
      }
    }

    if (saleOrder != null && saleOrder.OriginalOrderId != null) {
      displayOrder = fetchOrder(saleOrder.OriginalOrderId);
    } else {
      displayOrder = saleOrder;
    }

    List<OrderItem> orderItems = new List<OrderItem>();
    if (saleOrder != null) {
      orderItems = [
        SELECT Id, Quantity, Product2.Name
        FROM OrderItem
        WHERE OrderId = :saleOrder.Id
      ];
    }

    List<OrderItem> returnOrderItems = new List<OrderItem>();
    if (returnOrder != null) {
      returnOrderItems = [
        SELECT Id, Quantity, Product2.Name
        FROM OrderItem
        WHERE OrderId = :returnOrder.Id
      ];
    }

    List<TransactionJournal> transactionJournals = new List<TransactionJournal>();
    if (saleOrder != null) {
      transactionJournals = [
        SELECT Id, PaymentMethod, TransactionAmount, JournalType.Name, Order.StoreCode__r.StoreCode__c
        FROM TransactionJournal
        WHERE OrderId = :saleOrder.Id
      ];
    }

    List<Order> relatedSaleOrders = getRelatedSaleOrders(saleOrder);

    return new OrderDetailDto(displayOrder, saleOrder, returnOrder, relatedSaleOrders, orderItems, returnOrderItems, transactionJournals);
  }

  private static Order fetchOrder(Id orderId) {
    return [
      SELECT
        Id,
        OrderNo__c,
        Type,
        OrderReferenceNumber,
        Account.Name,
        Account.StoreCode__c,
        Status,
        EffectiveDate,
        ActivatedDate,
        TotalAmount,
        ActualPaymentAmount__c,
        MemberNo__r.Name,
        MemberNo__r.Id,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c,
        OrderStatus__c,
        SaleNo__c,
        EndDate,
        IsReductionOrder,
        OriginalOrderId
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];
  }

  private static List<Order> getRelatedSaleOrders(Order saleOrder) {
    if (saleOrder == null) {
      return new List<Order>();
    }

    if (saleOrder.OriginalOrderId != null) {
      return [
        SELECT Id, SaleNo__c, Status, EndDate, EffectiveDate, ActualPaymentAmount__c, Account.Name, Account.StoreCode__c
        FROM Order
        WHERE OriginalOrderId = :saleOrder.OriginalOrderId AND IsReductionOrder = FALSE AND SaleNo__c != NULL
        ORDER BY EndDate DESC, EffectiveDate DESC, CreatedDate DESC
      ];
    }

    List<Order> childSaleOrders = [
      SELECT Id, SaleNo__c, Status, EndDate, EffectiveDate, ActualPaymentAmount__c, Account.Name, Account.StoreCode__c
      FROM Order
      WHERE OriginalOrderId = :saleOrder.Id AND IsReductionOrder = FALSE AND SaleNo__c != NULL
      ORDER BY EndDate DESC, EffectiveDate DESC, CreatedDate DESC
    ];

    if (!childSaleOrders.isEmpty()) {
      return childSaleOrders;
    }

    return String.isBlank(saleOrder.SaleNo__c) ? new List<Order>() : new List<Order>{ saleOrder };
  }

  public class OrderDetailDto {
    @AuraEnabled
    public String orderNo;
    @AuraEnabled
    public Datetime orderDate;
    @AuraEnabled
    public String orderStatus;
    @AuraEnabled
    public String orderType;
    @AuraEnabled
    public String orderStoreName;
    @AuraEnabled
    public Decimal orderQuantity;
    @AuraEnabled
    public Decimal totalAmount;
    @AuraEnabled
    public Decimal orderCashAmount;
    @AuraEnabled
    public Decimal orderCardAmount;
    @AuraEnabled
    public Decimal orderCouponAmount;
    @AuraEnabled
    public Decimal orderPointAmount;

    @AuraEnabled
    public String saleNo;
    @AuraEnabled
    public Datetime saleDate;
    @AuraEnabled
    public String saleStatus;
    @AuraEnabled
    public String saleStoreName;
    @AuraEnabled
    public List<OrderItemDto> orderItems;
    @AuraEnabled
    public Decimal saleQuantity;
    @AuraEnabled
    public Decimal saleTotalAmount;
    @AuraEnabled
    public Decimal saleCashAmount;
    @AuraEnabled
    public Decimal saleCardAmount;
    @AuraEnabled
    public Decimal saleCouponAmount;
    @AuraEnabled
    public Decimal salePointAmount;
    @AuraEnabled
    public Decimal earnedPointAmount;
    @AuraEnabled
    public List<EarnedPointItemDto> earnedPointItems;
    @AuraEnabled
    public List<SaleRecordDto> saleRecords;

    @AuraEnabled
    public String returnNo;
    @AuraEnabled
    public Datetime returnDate;
    @AuraEnabled
    public String returnStatus;
    @AuraEnabled
    public String returnStoreName;
    @AuraEnabled
    public Decimal returnQuantity;
    @AuraEnabled
    public Decimal returnTotalAmount;
    @AuraEnabled
    public Decimal refundCashAmount;
    @AuraEnabled
    public Decimal refundCardAmount;
    @AuraEnabled
    public Decimal refundCouponAmount;
    @AuraEnabled
    public Decimal refundPointAmount;
    @AuraEnabled
    public Decimal restoredPointAmount;
    @AuraEnabled
    public List<EarnedPointItemDto> restoredPointItems;

    @AuraEnabled
    public List<PointTypeOptionDto> pointTypeOptions;

    @AuraEnabled
    public Id loyaltyProgramMemberId;
    @AuraEnabled
    public String customerName;
    @AuraEnabled
    public String customerMemberNo;
    @AuraEnabled
    public String customerPhone;
    @AuraEnabled
    public String customerGrade;
    @AuraEnabled
    public String managedStoreName;

    public OrderDetailDto(
      Order displayOrder,
      Order saleOrder,
      Order returnOrder,
      List<Order> relatedSaleOrders,
      List<OrderItem> orderItemList,
      List<OrderItem> returnOrderItemList,
      List<TransactionJournal> tjList
    ) {
      Boolean isSaleStarted = saleOrder != null && !String.isBlank(saleOrder.SaleNo__c);
      Order customerSourceOrder = displayOrder != null ? displayOrder : saleOrder;
      String orderFallbackStore = resolveStoreCode(displayOrder, saleOrder);

      orderNo = getDisplayOrderNumber(displayOrder, saleOrder);
      orderDate = getDisplayOrderDate(displayOrder, saleOrder);
      orderStatus = displayOrder != null ? getPicklistLabel(Order.OrderStatus__c, displayOrder.OrderStatus__c) : null;
      orderType = displayOrder != null ? getPicklistLabel(Order.Type, getQueriedStringValue(displayOrder, 'Type')) : null;
      orderStoreName = getOrderStoreCode(orderNo, orderFallbackStore);

      saleNo = isSaleStarted ? saleOrder.SaleNo__c : null;
      saleDate = isSaleStarted ? (saleOrder.EndDate != null ? saleOrder.EndDate : saleOrder.EffectiveDate) : null;
      saleStatus = isSaleStarted ? getPicklistLabel(Order.Status, saleOrder.Status) : null;
      saleStoreName = isSaleStarted ? getSaleStoreCode(saleOrder.SaleNo__c, orderStoreName) : null;

      orderItems = new List<OrderItemDto>();
      earnedPointItems = new List<EarnedPointItemDto>();
      restoredPointItems = new List<EarnedPointItemDto>();
      saleRecords = new List<SaleRecordDto>();
      pointTypeOptions = getPointTypeOptions();

      returnNo = returnOrder != null ? returnOrder.SaleNo__c : null;
      returnDate = returnOrder != null ? (returnOrder.EndDate != null ? returnOrder.EndDate : returnOrder.EffectiveDate) : null;
      returnStatus = returnOrder != null ? getPicklistLabel(Order.Status, returnOrder.Status) : null;
      returnStoreName = returnOrder != null ? getReturnStoreCode(returnNo, saleStoreName) : null;

      totalAmount = 0;
      orderQuantity = 0;
      saleQuantity = 0;
      returnQuantity = 0;
      earnedPointAmount = 0;
      restoredPointAmount = 0;

      if (orderItemList != null) {
        for (OrderItem orderItem : orderItemList) {
          Decimal quantity = orderItem.Quantity == null ? 0 : orderItem.Quantity;
          orderQuantity += quantity;

          if (isSaleStarted) {
            orderItems.add(new OrderItemDto(orderItem));
            saleQuantity += quantity;
          }
        }
      }

      if (returnOrderItemList != null) {
        for (OrderItem returnOrderItem : returnOrderItemList) {
          Decimal quantity = returnOrderItem.Quantity == null ? 0 : returnOrderItem.Quantity;
          returnQuantity += quantity < 0 ? quantity.abs() : quantity;
        }
      }

      if (customerSourceOrder != null && customerSourceOrder.MemberNo__r != null) {
        customerName = customerSourceOrder.MemberNo__r.Name;
        customerMemberNo = customerSourceOrder.MemberNo__r.MemberNo__c;
        customerPhone = customerSourceOrder.MemberNo__r.MobilePhone;
        customerGrade = getPicklistLabel(Contact.Grade__c, customerSourceOrder.MemberNo__r.Grade__c);
        managedStoreName = customerSourceOrder.Account != null ? customerSourceOrder.Account.Name : null;

        List<LoyaltyProgramMember> lpmList = [
          SELECT Id
          FROM LoyaltyProgramMember
          WHERE ContactId = :customerSourceOrder.MemberNo__r.Id
          LIMIT 1
        ];

        if (!lpmList.isEmpty()) {
          loyaltyProgramMemberId = lpmList[0].Id;
        }
      }

      PaymentSummary orderPaymentSummary = getPaymentSummaryByOrderNumber('OrderNo__c', orderNo, null);
      PaymentSummary salePaymentSummary = isSaleStarted ? getPaymentSummaryByOrderNumber('SaleNo__c', saleNo, false) : new PaymentSummary();
      PaymentSummary returnPaymentSummary = getPaymentSummaryByOrderNumber('SaleNo__c', returnNo, true);
      Map<String, PaymentSummary> saleSummaryBySaleNo = getPaymentSummariesBySaleNumbers(relatedSaleOrders);

      Set<Id> journalIds = getSaleJournalIds(saleOrder, relatedSaleOrders, tjList);
      Map<String, PointAmountSummary> earnedPointAmountByType = new Map<String, PointAmountSummary>();
      Map<String, PointAmountSummary> restoredPointAmountByType = new Map<String, PointAmountSummary>();

      if (isSaleStarted) {
        accumulatePointAmounts(journalIds, earnedPointAmountByType, 1);
      }
      accumulatePointAmounts(getReturnJournalIds(returnOrder), restoredPointAmountByType, -1);

      for (PointAmountSummary pointSummary : earnedPointAmountByType.values()) {
        earnedPointItems.add(new EarnedPointItemDto(pointSummary.type, pointSummary.label, pointSummary.amount));
        earnedPointAmount += pointSummary.amount;
      }

      for (PointAmountSummary pointSummary : restoredPointAmountByType.values()) {
        restoredPointItems.add(new EarnedPointItemDto(pointSummary.type, pointSummary.label, pointSummary.amount));
        restoredPointAmount += pointSummary.amount;
      }

      orderCashAmount = orderPaymentSummary.cashAmount;
      orderCardAmount = orderPaymentSummary.cardAmount;
      orderCouponAmount = orderPaymentSummary.couponAmount;
      orderPointAmount = orderPaymentSummary.pointAmount;
      totalAmount = getDisplayOrderTotalAmount(displayOrder, saleOrder, orderPaymentSummary.totalAmount);

      if (orderPaymentSummary.totalAmount == 0) {
        Decimal derivedDepositAmount = 0;

        if (displayOrder != null && displayOrder.ActualPaymentAmount__c != null && displayOrder.ActualPaymentAmount__c > 0) {
          derivedDepositAmount = displayOrder.ActualPaymentAmount__c;
        } else if (salePaymentSummary.totalAmount != null && salePaymentSummary.totalAmount > 0) {
          derivedDepositAmount = (salePaymentSummary.totalAmount * 0.1).setScale(0);
        }

        if (derivedDepositAmount > 0) {
          orderCashAmount = derivedDepositAmount;
          orderCardAmount = 0;
          orderCouponAmount = 0;
          orderPointAmount = 0;
        }
      }

      saleCashAmount = salePaymentSummary.cashAmount;
      saleCardAmount = salePaymentSummary.cardAmount;
      saleCouponAmount = salePaymentSummary.couponAmount;
      salePointAmount = salePaymentSummary.pointAmount;
      saleTotalAmount = salePaymentSummary.totalAmount;

      if (relatedSaleOrders != null) {
        for (Order relatedSaleOrder : relatedSaleOrders) {
          if (String.isBlank(relatedSaleOrder.SaleNo__c)) {
            continue;
          }

          PaymentSummary relatedSaleSummary = saleSummaryBySaleNo.containsKey(relatedSaleOrder.SaleNo__c)
            ? saleSummaryBySaleNo.get(relatedSaleOrder.SaleNo__c)
            : new PaymentSummary();

          saleRecords.add(
            new SaleRecordDto(
              relatedSaleOrder.SaleNo__c,
              getPicklistLabel(Order.Status, relatedSaleOrder.Status),
              relatedSaleOrder.EndDate != null ? relatedSaleOrder.EndDate : relatedSaleOrder.EffectiveDate,
              getSaleStoreCode(relatedSaleOrder.SaleNo__c, resolveStoreCode(relatedSaleOrder, saleOrder)),
              relatedSaleSummary.totalAmount > 0 ? relatedSaleSummary.totalAmount : relatedSaleOrder.ActualPaymentAmount__c
            )
          );
        }
      }

      refundCashAmount = normalizeNegativeAmount(returnPaymentSummary.cashAmount);
      refundCardAmount = normalizeNegativeAmount(returnPaymentSummary.cardAmount);
      refundCouponAmount = normalizeNegativeAmount(returnPaymentSummary.couponAmount);
      refundPointAmount = normalizeNegativeAmount(returnPaymentSummary.pointAmount);
      returnTotalAmount = returnOrder != null &&
        returnOrder.TotalAmount != null
        ? normalizeNegativeAmount(returnOrder.TotalAmount)
        : normalizeNegativeAmount(returnPaymentSummary.totalAmount);
    }
  }

  private static String resolveStoreCode(Order primaryOrder, Order fallbackOrder) {
    if (primaryOrder != null && primaryOrder.Account != null) {
      if (!String.isBlank(primaryOrder.Account.Name)) {
        return primaryOrder.Account.Name;
      }
      if (!String.isBlank(primaryOrder.Account.StoreCode__c)) {
        return getStoreNameByCode(primaryOrder.Account.StoreCode__c);
      }
    }

    if (fallbackOrder != null && fallbackOrder.Account != null) {
      if (!String.isBlank(fallbackOrder.Account.Name)) {
        return fallbackOrder.Account.Name;
      }
      if (!String.isBlank(fallbackOrder.Account.StoreCode__c)) {
        return getStoreNameByCode(fallbackOrder.Account.StoreCode__c);
      }
    }

    return null;
  }

  private static String getDisplayOrderNumber(Order displayOrder, Order saleOrder) {
    if (displayOrder != null) {
      if (!String.isBlank(displayOrder.OrderNo__c)) {
        return displayOrder.OrderNo__c;
      }
      if (!String.isBlank((String) displayOrder.get('OrderReferenceNumber'))) {
        return (String) displayOrder.get('OrderReferenceNumber');
      }
    }

    if (saleOrder != null) {
      if (!String.isBlank(saleOrder.OrderNo__c)) {
        return saleOrder.OrderNo__c;
      }
      if (!String.isBlank((String) saleOrder.get('OrderReferenceNumber'))) {
        return (String) saleOrder.get('OrderReferenceNumber');
      }
    }

    return null;
  }

  private static Datetime getDisplayOrderDate(Order displayOrder, Order saleOrder) {
    if (displayOrder != null && displayOrder.EffectiveDate != null) {
      return displayOrder.EffectiveDate;
    }

    if (saleOrder != null && saleOrder.EffectiveDate != null) {
      return saleOrder.EffectiveDate;
    }

    return null;
  }

  private static Decimal getDisplayOrderTotalAmount(Order displayOrder, Order saleOrder, Decimal fallbackAmount) {
    Decimal displayOrderTotalAmount = getQueriedDecimalValue(displayOrder, 'TotalAmount');
    if (displayOrderTotalAmount != null && displayOrderTotalAmount > 0) {
      return displayOrderTotalAmount;
    }

    Decimal saleOrderTotalAmount = getQueriedDecimalValue(saleOrder, 'TotalAmount');
    if (saleOrderTotalAmount != null && saleOrderTotalAmount > 0) {
      return saleOrderTotalAmount;
    }

    return fallbackAmount == null ? 0 : fallbackAmount;
  }

  private static Set<Id> getReturnJournalIds(Order returnOrder) {
    Set<Id> returnJournalIds = new Set<Id>();

    if (returnOrder == null) {
      return returnJournalIds;
    }

    for (TransactionJournal returnJournal : [
      SELECT Id
      FROM TransactionJournal
      WHERE OrderId = :returnOrder.Id
    ]) {
      returnJournalIds.add(returnJournal.Id);
    }

    return returnJournalIds;
  }

  private static Set<Id> getSaleJournalIds(Order saleOrder, List<Order> relatedSaleOrders, List<TransactionJournal> tjList) {
    Set<Id> journalIds = new Set<Id>();
    Set<Id> saleOrderIds = new Set<Id>();

    if (relatedSaleOrders != null) {
      for (Order relatedSaleOrder : relatedSaleOrders) {
        if (relatedSaleOrder != null && relatedSaleOrder.Id != null) {
          saleOrderIds.add(relatedSaleOrder.Id);
        }
      }
    }

    if (saleOrderIds.isEmpty() && saleOrder != null && saleOrder.Id != null) {
      saleOrderIds.add(saleOrder.Id);
    }

    if (!saleOrderIds.isEmpty()) {
      for (TransactionJournal saleJournal : [
        SELECT Id
        FROM TransactionJournal
        WHERE OrderId IN :saleOrderIds
      ]) {
        journalIds.add(saleJournal.Id);
      }

      return journalIds;
    }

    if (tjList != null) {
      for (TransactionJournal tj : tjList) {
        if (tj != null && tj.Id != null) {
          journalIds.add(tj.Id);
        }
      }
    }

    return journalIds;
  }

  private static void accumulatePointAmounts(Set<Id> journalIds, Map<String, PointAmountSummary> amountByType, Integer multiplier) {
    if (journalIds == null || journalIds.isEmpty()) {
      return;
    }

    for (LoyaltyLedger ledger : [
      SELECT Points, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE TransactionJournalId IN :journalIds AND EventType = 'Credit'
    ]) {
      Decimal pointAmount = ledger.Points == null ? 0 : ledger.Points;
      if (pointAmount <= 0) {
        continue;
      }

      Decimal signedPointAmount = pointAmount * (multiplier == null ? 1 : multiplier);
      String pointTypeCode = ledger.LoyaltyPgmCrcySubtype != null && !String.isBlank(ledger.LoyaltyPgmCrcySubtype.PointTypeCode__c)
        ? ledger.LoyaltyPgmCrcySubtype.PointTypeCode__c
        : DEFAULT_POINT_CODE;
      String pointTypeLabel = ledger.LoyaltyPgmCrcySubtype != null && !String.isBlank(ledger.LoyaltyPgmCrcySubtype.Name)
        ? ledger.LoyaltyPgmCrcySubtype.Name
        : DEFAULT_POINT_LABEL;

      if (!amountByType.containsKey(pointTypeCode)) {
        amountByType.put(pointTypeCode, new PointAmountSummary(pointTypeCode, pointTypeLabel, 0));
      }

      amountByType.get(pointTypeCode).amount += signedPointAmount;
    }
  }

  private static Decimal normalizeNegativeAmount(Decimal amount) {
    if (amount == null || amount == 0) {
      return 0;
    }

    return -amount.abs();
  }

  private static List<PointTypeOptionDto> getPointTypeOptions() {
    List<PointTypeOptionDto> options = new List<PointTypeOptionDto>();

    for (LoyaltyPgmCurrencySubtype subtype : [
      SELECT PointTypeCode__c, Name, UsagePriorityNumber
      FROM LoyaltyPgmCurrencySubtype
      WHERE PointTypeCode__c != NULL AND IsActive = TRUE
      ORDER BY UsagePriorityNumber ASC, Name ASC
    ]) {
      options.add(new PointTypeOptionDto(subtype.PointTypeCode__c, subtype.Name));
    }

    return options;
  }

  private static String getOrderStoreCode(String orderNo, String fallbackStoreCode) {
    return getStoreCodeByOrderNumber('OrderNo__c', orderNo, fallbackStoreCode);
  }

  private static String getSaleStoreCode(String saleNo, String fallbackStoreCode) {
    return getStoreCodeByOrderNumber('SaleNo__c', saleNo, fallbackStoreCode);
  }

  private static String getReturnStoreCode(String returnNo, String fallbackStoreCode) {
    if (String.isBlank(returnNo)) {
      return fallbackStoreCode;
    }

    return getStoreCodeByOrderNumber('SaleNo__c', returnNo, fallbackStoreCode);
  }

  private static String getStoreCodeByOrderNumber(String fieldName, String fieldValue, String fallbackStoreCode) {
    if (String.isBlank(fieldValue)) {
      return fallbackStoreCode;
    }

    List<TransactionJournal> journals = Database.query(
      'SELECT Order.StoreCode__r.Name, Order.StoreCode__r.StoreCode__c ' +
        'FROM TransactionJournal ' +
        'WHERE Order.' +
        fieldName +
        ' = :fieldValue ' +
        'AND Order.StoreCode__r.StoreCode__c != NULL ' +
        'LIMIT 1'
    );

    if (!journals.isEmpty() && journals[0].Order != null && journals[0].Order.StoreCode__r != null) {
      if (!String.isBlank(journals[0].Order.StoreCode__r.Name)) {
        return journals[0].Order.StoreCode__r.Name;
      }
      if (!String.isBlank(journals[0].Order.StoreCode__r.StoreCode__c)) {
        return getStoreNameByCode(journals[0].Order.StoreCode__r.StoreCode__c);
      }
    }

    return fallbackStoreCode;
  }

  private static String getStoreNameByCode(String storeCode) {
    if (String.isBlank(storeCode)) {
      return null;
    }

    List<Account> stores = [
      SELECT Name
      FROM Account
      WHERE StoreCode__c = :storeCode
      LIMIT 1
    ];

    return stores.isEmpty() ? storeCode : stores[0].Name;
  }

  private static PaymentSummary getPaymentSummaryByOrderNumber(String fieldName, String fieldValue, Boolean isReductionOrder) {
    PaymentSummary summary = new PaymentSummary();

    if (String.isBlank(fieldValue)) {
      return summary;
    }

    String query =
      'SELECT PaymentMethod paymentMethod, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE Order.' +
      fieldName +
      ' = :fieldValue ' +
      'AND TransactionAmount != NULL ' +
      'AND PaymentMethod != NULL ';

    if (isReductionOrder != null) {
      query += 'AND Order.IsReductionOrder = ' + String.valueOf(isReductionOrder) + ' ';
    }

    query += 'GROUP BY PaymentMethod';

    for (AggregateResult ar : Database.query(query)) {
      String paymentMethod = (String) ar.get('paymentMethod');
      Decimal totalAmountValue = (Decimal) ar.get('totalAmount');
      Decimal amount = totalAmountValue == null ? 0 : totalAmountValue;
      String paymentCategory = resolvePaymentCategory(paymentMethod);
      if (paymentCategory == 'OTHER') {
        continue;
      }

      summary.totalAmount += amount;
      if (paymentCategory == 'CASH') {
        summary.cashAmount += amount;
      } else if (paymentCategory == 'CARD') {
        summary.cardAmount += amount;
      } else if (paymentCategory == 'COUPON') {
        summary.couponAmount += amount;
      } else if (paymentCategory == 'POINT') {
        summary.pointAmount += amount;
      }
    }

    return summary;
  }

  private static Map<String, PaymentSummary> getPaymentSummariesBySaleNumbers(List<Order> saleOrders) {
    Map<String, PaymentSummary> summaryBySaleNo = new Map<String, PaymentSummary>();
    Set<String> saleNumbers = new Set<String>();

    if (saleOrders != null) {
      for (Order saleOrder : saleOrders) {
        if (!String.isBlank(saleOrder.SaleNo__c)) {
          saleNumbers.add(saleOrder.SaleNo__c);
          summaryBySaleNo.put(saleOrder.SaleNo__c, new PaymentSummary());
        }
      }
    }

    if (saleNumbers.isEmpty()) {
      return summaryBySaleNo;
    }

    for (AggregateResult ar : [
      SELECT Order.SaleNo__c saleNo, PaymentMethod paymentMethod, SUM(TransactionAmount) totalAmount
      FROM TransactionJournal
      WHERE Order.SaleNo__c IN :saleNumbers AND Order.IsReductionOrder = FALSE AND TransactionAmount != NULL AND PaymentMethod != NULL
      GROUP BY Order.SaleNo__c, PaymentMethod
    ]) {
      String saleNo = (String) ar.get('saleNo');
      String paymentMethod = (String) ar.get('paymentMethod');
      Decimal amount = (Decimal) ar.get('totalAmount');

      if (!summaryBySaleNo.containsKey(saleNo)) {
        summaryBySaleNo.put(saleNo, new PaymentSummary());
      }

      PaymentSummary summary = summaryBySaleNo.get(saleNo);
      Decimal safeAmount = amount == null ? 0 : amount;
      String paymentCategory = resolvePaymentCategory(paymentMethod);
      if (paymentCategory == 'OTHER') {
        continue;
      }

      summary.totalAmount += safeAmount;
      if (paymentCategory == 'CASH') {
        summary.cashAmount += safeAmount;
      } else if (paymentCategory == 'CARD') {
        summary.cardAmount += safeAmount;
      } else if (paymentCategory == 'COUPON') {
        summary.couponAmount += safeAmount;
      } else if (paymentCategory == 'POINT') {
        summary.pointAmount += safeAmount;
      }
    }

    return summaryBySaleNo;
  }

  private static String getPicklistLabel(Schema.SObjectField fieldRef, String value) {
    if (String.isBlank(value)) {
      return null;
    }

    for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
      if (entry.getValue() == value) {
        return entry.getLabel();
      }
    }

    return value;
  }

  private static String getQueriedStringValue(SObject record, String fieldApiName) {
    if (record == null || String.isBlank(fieldApiName)) {
      return null;
    }

    Map<String, Object> populatedFieldMap = record.getPopulatedFieldsAsMap();
    if (!populatedFieldMap.containsKey(fieldApiName)) {
      return null;
    }

    Object fieldValue = populatedFieldMap.get(fieldApiName);
    return fieldValue == null ? null : String.valueOf(fieldValue);
  }

  private static Decimal getQueriedDecimalValue(SObject record, String fieldApiName) {
    if (record == null || String.isBlank(fieldApiName)) {
      return null;
    }

    Map<String, Object> populatedFieldMap = record.getPopulatedFieldsAsMap();
    if (!populatedFieldMap.containsKey(fieldApiName)) {
      return null;
    }

    Object fieldValue = populatedFieldMap.get(fieldApiName);
    if (fieldValue == null) {
      return null;
    }

    if (fieldValue instanceof Decimal) {
      return (Decimal) fieldValue;
    }

    return Decimal.valueOf(String.valueOf(fieldValue));
  }

  private static String resolvePaymentCategory(String paymentMethod) {
    if (String.isBlank(paymentMethod)) {
      return 'OTHER';
    }
    if (CASH_PAYMENT_METHODS.contains(paymentMethod)) {
      return 'CASH';
    }
    if (CARD_PAYMENT_METHODS.contains(paymentMethod)) {
      return 'CARD';
    }
    if (COUPON_PAYMENT_METHODS.contains(paymentMethod)) {
      return 'COUPON';
    }
    if (POINT_PAYMENT_METHODS.contains(paymentMethod)) {
      return 'POINT';
    }

    return 'OTHER';
  }

  public class OrderItemDto {
    @AuraEnabled
    public Id orderItemId;
    @AuraEnabled
    public String productName;
    @AuraEnabled
    public Decimal quantity;

    public OrderItemDto(OrderItem orderItem) {
      orderItemId = orderItem.Id;
      productName = orderItem.Product2 != null ? orderItem.Product2.Name : DEFAULT_PRODUCT_LABEL;
      quantity = orderItem.Quantity;
    }
  }

  public class EarnedPointItemDto {
    @AuraEnabled
    public String type;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Decimal amount;

    public EarnedPointItemDto(String typeCode, String typeLabel, Decimal pointAmount) {
      type = typeCode;
      label = String.isBlank(typeLabel) ? typeCode : typeLabel;
      amount = pointAmount;
    }
  }

  public class PointTypeOptionDto {
    @AuraEnabled
    public String type;
    @AuraEnabled
    public String label;

    public PointTypeOptionDto(String typeCode, String typeLabel) {
      type = typeCode;
      label = String.isBlank(typeLabel) ? typeCode : typeLabel;
    }
  }

  public class SaleRecordDto {
    @AuraEnabled
    public String saleNo;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Datetime saleDate;
    @AuraEnabled
    public String storeName;
    @AuraEnabled
    public Decimal amount;

    public SaleRecordDto(String saleNumber, String statusLabel, Datetime saleDatetime, String storeCode, Decimal saleAmount) {
      saleNo = saleNumber;
      status = statusLabel;
      saleDate = saleDatetime;
      storeName = storeCode;
      amount = saleAmount == null ? 0 : saleAmount;
    }
  }

  private class PointAmountSummary {
    public String type;
    public String label;
    public Decimal amount;

    public PointAmountSummary(String typeCode, String typeLabel, Decimal pointAmount) {
      type = typeCode;
      label = String.isBlank(typeLabel) ? typeCode : typeLabel;
      amount = pointAmount;
    }
  }

  private class PaymentSummary {
    public Decimal totalAmount = 0;
    public Decimal cashAmount = 0;
    public Decimal cardAmount = 0;
    public Decimal couponAmount = 0;
    public Decimal pointAmount = 0;
  }
}
