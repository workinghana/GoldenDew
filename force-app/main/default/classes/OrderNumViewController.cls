public with sharing class OrderNumViewController {
  private static final Set<String> CASH_PAYMENT_METHODS = new Set<String>{ '01' };
  private static final Set<String> CARD_PAYMENT_METHODS = new Set<String>{ '03' };
  private static final Set<String> COUPON_PAYMENT_METHODS = new Set<String>{ '90' };
  private static final Set<String> POINT_PAYMENT_METHODS = new Set<String>{ '81' };
  private static final Set<String> DEPT_VOUCHER_PAYMENT_METHODS = new Set<String>{ '92' };
  private static final Set<String> HQ_VOUCHER_PAYMENT_METHODS = new Set<String>{ '93' };
  private static final Set<String> UPGRADE_PAYMENT_METHODS = new Set<String>{ '20' };
  private static final Set<String> PROVISIONAL_PAYMENT_METHODS = new Set<String>{ '06' };
  private static final Set<String> DEPOSIT_JOURNAL_TYPE_NAMES = new Set<String>{ 'Deposit' };
  private static final Set<String> ORDER_PAYMENT_JOURNAL_TYPE_NAMES = new Set<String>{ 'Deposit', 'Deposit Reversal' };
  private static final String ACCRUAL_JOURNAL_TYPE_NAME = 'Accrual';
  private static final String ACCRUAL_REVERSAL_JOURNAL_TYPE_NAME = 'Accrual Reversal';
  private static final Set<String> SALE_POINT_JOURNAL_TYPE_NAMES = new Set<String>{ 'Accrual', 'Accrual Reversal' };
  private static final String REDEMPTION_JOURNAL_TYPE_NAME = 'Redemption';
  private static final String REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME = 'Redemption Reversal';
  private static final String SALE_DEPOSIT_JOURNAL_SUBTYPE_NAME = 'Sale Deposit';
  private static final String SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME = 'Sale Deposit Reversal';
  private static final String ORDER_DEPOSIT_JOURNAL_SUBTYPE_NAME = 'Order Deposit';
  private static final String ORDER_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME = 'Order Deposit Reversal';
  private static final String PURCHASE_ACCRUAL_JOURNAL_SUBTYPE_NAME = 'Purchase Accrual';
  private static final String CANCEL_PURCHASE_ACCRUAL_JOURNAL_SUBTYPE_NAME = 'Cancel Purchase Accrual';
  private static final String PROMOTION_POINT_ACCRUAL_JOURNAL_SUBTYPE_NAME = 'Promotion Point Accrual';
  private static final String PROMOTION_POINT_ACCRUAL_REVERSAL_JOURNAL_SUBTYPE_NAME = 'Promotion Point Accrual Reversal';
  private static final String API_FORCED_CREDIT_JOURNAL_SUBTYPE_NAME = 'Api Forced Credit';
  private static final String API_FORCED_DEBIT_JOURNAL_SUBTYPE_NAME = 'Api Forced Debit';
  private static final String RESTORE_PURCHASE_ACCRUAL_ADDITIONAL_NOTES = 'Restore purchase accrual due to return deletion';
  private static final String RESTORE_PROMOTION_POINT_ACCRUAL_ADDITIONAL_NOTES = 'Restore promotion point accrual due to return deletion';
  private static final String RESTORE_POINT_USAGE_ADDITIONAL_NOTES = 'Restore point usage due to return deletion';
  private static final String COUPON_REDEEM_JOURNAL_SUBTYPE_NAME = 'Coupon Redeem';
  private static final String COUPON_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME = 'Coupon Redeem Cancel';
  private static final String POINT_DEBIT_JOURNAL_SUBTYPE_NAME = 'Point Debit';
  private static final String POINT_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME = 'Point Redeem Cancel';
  private static final Set<String> INCLUDED_PAYMENT_STATUSES = new Set<String>{ 'Approved', 'Processed' };
  private static final Set<String> COUPON_REDEMPTION_JOURNAL_TYPE_NAMES = new Set<String>{ 'Redemption', 'Redemption Reversal' };
  private static final Set<String> COUPON_REDEMPTION_JOURNAL_SUBTYPE_NAMES = new Set<String>{ 'Coupon Redeem', 'Coupon Redeem Cancel' };
  private static final Set<String> POINT_REDEMPTION_JOURNAL_TYPE_NAMES = new Set<String>{ 'Redemption', 'Redemption Reversal' };
  private static final Set<String> POINT_REDEMPTION_JOURNAL_SUBTYPE_NAMES = new Set<String>{ 'Point Debit', 'Point Redeem Cancel' };
  private static final Set<String> RETURN_POINT_RESTORE_JOURNAL_SUBTYPE_NAMES = new Set<String>{
    PURCHASE_ACCRUAL_JOURNAL_SUBTYPE_NAME,
    PROMOTION_POINT_ACCRUAL_JOURNAL_SUBTYPE_NAME,
    API_FORCED_CREDIT_JOURNAL_SUBTYPE_NAME
  };
  private static final Set<String> RETURN_POINT_CANCEL_JOURNAL_SUBTYPE_NAMES = new Set<String>{
    CANCEL_PURCHASE_ACCRUAL_JOURNAL_SUBTYPE_NAME,
    PROMOTION_POINT_ACCRUAL_REVERSAL_JOURNAL_SUBTYPE_NAME,
    API_FORCED_DEBIT_JOURNAL_SUBTYPE_NAME
  };
  private static final Set<String> RETURN_POINT_RESTORE_ADDITIONAL_NOTES = new Set<String>{
    RESTORE_PURCHASE_ACCRUAL_ADDITIONAL_NOTES,
    RESTORE_PROMOTION_POINT_ACCRUAL_ADDITIONAL_NOTES
  };
  private static final String ACTIVATED_STATUS_VALUE = 'activated';
  private static final String SALE_SUCCESS_STATUS_VALUE = 'salesuccess';
  private static final String SALE_SUCCESS_ACTIVE_STATUS_VALUE = 'salesuccess2';
  private static final String SALE_DELETED_STATUS_VALUE = 'saledeleted';
  private static final String SALE_DELETED_ACTIVE_STATUS_VALUE = 'saledeleted2';
  private static final String RETURN_SUCCESS_STATUS_VALUE = 'returnsuccess';
  private static final String RETURN_SUCCESS_ACTIVE_STATUS_VALUE = 'returnsuccess2';
  private static final String RETURN_DELETED_STATUS_VALUE = 'returndeleted';
  private static final String RETURN_DELETED_ACTIVE_STATUS_VALUE = 'returndeleted2';
  private static final String PROGRESS_STATE_NOT_STARTED = 'not_started';
  private static final String PROGRESS_STATE_IN_PROGRESS = 'in_progress';
  private static final String PROGRESS_STATE_COMPLETED = 'completed';
  private static final String PROGRESS_STATE_CANCELLED = 'cancelled';
  private static final Set<String> DEFINED_STATUS_VALUES = new Set<String>{
    RETURN_DELETED_STATUS_VALUE,
    RETURN_SUCCESS_STATUS_VALUE,
    RETURN_SUCCESS_ACTIVE_STATUS_VALUE,
    SALE_DELETED_STATUS_VALUE,
    SALE_SUCCESS_STATUS_VALUE,
    SALE_SUCCESS_ACTIVE_STATUS_VALUE,
    ACTIVATED_STATUS_VALUE
  };
  private static final Set<String> DEFINED_DELETED_STATUS_VALUES = new Set<String>{
    SALE_DELETED_STATUS_VALUE,
    SALE_DELETED_ACTIVE_STATUS_VALUE,
    RETURN_DELETED_STATUS_VALUE,
    RETURN_DELETED_ACTIVE_STATUS_VALUE
  };
  private static final String DEFAULT_POINT_CODE = '00';
  private static Id cancelPurchaseAccrualJournalSubTypeId;
  private static Map<String, Id> journalSubTypeIdsByName;
  private static Map<String, Set<Id>> journalSubTypeIdSetsByName;
  private static Map<String, Id> journalTypeIdsByName;
  private static final String DEFAULT_POINT_LABEL = 'Point';
  private static final String DEFAULT_PRODUCT_LABEL = '?怨밸? ?類ｋ궖 ??곸벉';

  @AuraEnabled(cacheable=true)
  public static OrderDetailDto getOrderNumView(Id orderId) {
    Order orderRecord = fetchOrder(orderId);
    Order saleOrder = orderRecord;
    Order displayOrder = orderRecord;
    Order returnOrder;
    List<Order> returnOrders = new List<Order>();
    Boolean isCurrentOrderReturnPage = orderRecord.IsReductionOrder__c == true;

    if (isCurrentOrderReturnPage) {
      returnOrder = orderRecord;

      if (orderRecord.OriginalOrderId__c != null) {
        saleOrder = fetchOrder(orderRecord.OriginalOrderId__c);
      }
    }

    List<Order> relatedSaleOrders = getRelatedSaleOrders(saleOrder);
    saleOrder = getRepresentativeSaleOrder(saleOrder, relatedSaleOrders, isCurrentOrderReturnPage);
    relatedSaleOrders = prioritizeRepresentativeSaleOrder(relatedSaleOrders, saleOrder);
    List<Order> relatedOrderOrders = getRelatedOrderOrders(orderRecord, saleOrder, relatedSaleOrders);

    List<Order> relatedReturnOrders = getRelatedReturnOrders(saleOrder);
    Order returnProgressOrder = getReturnProgressOrder(returnOrder, relatedReturnOrders, isCurrentOrderReturnPage);
    returnOrder = getRepresentativeReturnOrder(returnOrder, relatedReturnOrders, isCurrentOrderReturnPage);

    if (isCurrentOrderReturnPage) {
      returnOrders = returnOrder == null || returnOrder.Id == null ? new List<Order>() : new List<Order>{ returnOrder };
    } else {
      returnOrders = returnOrder == null || returnOrder.Id == null ? new List<Order>() : new List<Order>{ returnOrder };
    }

    if (relatedOrderOrders != null && !relatedOrderOrders.isEmpty()) {
      displayOrder = relatedOrderOrders[0];
    } else {
      Id originalOrderId = resolveOriginalOrderIdFromSale(saleOrder);
      if (originalOrderId != null) {
        displayOrder = fetchOrder(originalOrderId);
      } else if (saleOrder != null && saleOrder.OriginalOrderId__c != null) {
        displayOrder = fetchOrder(saleOrder.OriginalOrderId__c);
      } else {
        displayOrder = saleOrder;
      }
      relatedOrderOrders = displayOrder == null ? new List<Order>() : new List<Order>{ displayOrder };
    }

    Set<Id> saleOrderIds = getActiveSaleOrderIds(saleOrder, relatedSaleOrders);

    List<OrderItem> orderItems = new List<OrderItem>();
    Set<Id> relatedOrderIds = getOrderIds(relatedOrderOrders);
    if (!relatedOrderIds.isEmpty()) {
      orderItems = [
        SELECT Id, OrderId, Quantity, TotalPrice, Product2.Name, Order.OrderNo__c, Order.SaleNo__c
        FROM OrderItem
        WHERE OrderId IN :relatedOrderIds
        ORDER BY Order.EffectiveDate DESC, Order.CreatedDate DESC, CreatedDate DESC, Id DESC
      ];
    }

    List<OrderItem> saleItems = new List<OrderItem>();
    if (!saleOrderIds.isEmpty()) {
      saleItems = [
        SELECT Id, OrderId, Quantity, TotalPrice, Product2.Name, Order.OrderNo__c, Order.SaleNo__c
        FROM OrderItem
        WHERE OrderId IN :saleOrderIds
      ];
    }

    Set<Id> returnOrderIds = getOrderIds(returnOrders);

    List<OrderItem> returnOrderItems = new List<OrderItem>();
    if (!returnOrderIds.isEmpty()) {
      returnOrderItems = [
        SELECT Id, OrderId, Quantity, TotalPrice, Product2.Name, Order.OrderNo__c, Order.SaleNo__c
        FROM OrderItem
        WHERE OrderId IN :returnOrderIds
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

    return new OrderDetailDto(
      displayOrder,
      saleOrder,
      returnOrder,
      relatedOrderOrders,
      returnOrders,
      relatedSaleOrders,
      orderItems,
      saleItems,
      returnOrderItems,
      transactionJournals,
      isCurrentOrderReturnPage,
      returnProgressOrder
    );
  }

  private static Order fetchOrder(Id orderId) {
    return [
      SELECT
        Id,
        OrderNo__c,
        Type,
        OrderReferenceNumber,
        StoreCode__c,
        StoreCode__r.Name,
        StoreCode__r.StoreCode__c,
        Account.Name,
        Account.StoreCode__c,
        Status,
        EffectiveDate,
        PoDate,
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
        IsReductionOrder__c,
        OriginalOrderId__c,
        IsDeleted__c,
        DeleteDateTime__c
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];
  }

  private static Id resolveOriginalOrderIdFromSale(Order saleOrder) {
    if (saleOrder == null || saleOrder.Id == null) {
      return null;
    }

    List<TransactionJournal> journals = [
      SELECT OrderId__c
      FROM TransactionJournal
      WHERE SaleId__c = :saleOrder.Id AND OrderId__c != NULL AND OrderId__c != :saleOrder.Id
      ORDER BY CreatedDate DESC, LastModifiedDate DESC, Id DESC
      LIMIT 1
    ];

    return journals.isEmpty() ? null : journals[0].OrderId__c;
  }

  private static List<Order> getRelatedOrderOrders(Order currentOrderRecord, Order saleOrder, List<Order> relatedSaleOrders) {
    Set<Id> orderIds = new Set<Id>();
    Set<Id> saleContextIds = new Set<Id>();

    if (
      currentOrderRecord != null &&
      currentOrderRecord.Id != null &&
      currentOrderRecord.IsReductionOrder__c != true &&
      !String.isBlank(currentOrderRecord.OrderNo__c) &&
      String.isBlank(currentOrderRecord.SaleNo__c)
    ) {
      orderIds.add(currentOrderRecord.Id);
    }

    if (relatedSaleOrders != null) {
      for (Order relatedSaleOrder : relatedSaleOrders) {
        if (relatedSaleOrder != null && relatedSaleOrder.Id != null) {
          saleContextIds.add(relatedSaleOrder.Id);
        }
      }
    }

    if (saleOrder != null && saleOrder.Id != null) {
      saleContextIds.add(saleOrder.Id);
    }

    if (!saleContextIds.isEmpty()) {
      for (TransactionJournal linkedSaleJournal : [
        SELECT OrderId__c
        FROM TransactionJournal
        WHERE SaleId__c IN :saleContextIds AND OrderId__c != NULL
      ]) {
        if (linkedSaleJournal.OrderId__c != null && !saleContextIds.contains(linkedSaleJournal.OrderId__c)) {
          orderIds.add(linkedSaleJournal.OrderId__c);
        }
      }
    }

    if (orderIds.isEmpty() && !saleContextIds.isEmpty()) {
      for (OrderItem linkedSaleItem : [
        SELECT OrderId__c
        FROM OrderItem
        WHERE OrderId IN :saleContextIds AND OrderId__c != NULL
      ]) {
        if (linkedSaleItem.OrderId__c != null && !saleContextIds.contains(linkedSaleItem.OrderId__c)) {
          orderIds.add(linkedSaleItem.OrderId__c);
        }
      }
    }

    if (orderIds.isEmpty()) {
      if (
        currentOrderRecord != null &&
        currentOrderRecord.Id != null &&
        currentOrderRecord.IsReductionOrder__c != true &&
        !String.isBlank(currentOrderRecord.OrderNo__c) &&
        String.isBlank(currentOrderRecord.SaleNo__c)
      ) {
        orderIds.add(currentOrderRecord.Id);
      }
    }

    if (orderIds.isEmpty()) {
      return new List<Order>();
    }

    return [
      SELECT
        Id,
        OrderNo__c,
        Type,
        OrderReferenceNumber,
        StoreCode__c,
        StoreCode__r.Name,
        StoreCode__r.StoreCode__c,
        Account.Name,
        Account.StoreCode__c,
        Status,
        EffectiveDate,
        PoDate,
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
        IsReductionOrder__c,
        OriginalOrderId__c,
        IsDeleted__c,
        DeleteDateTime__c
      FROM Order
      WHERE Id IN :orderIds AND IsReductionOrder__c = FALSE AND OrderNo__c != NULL
      ORDER BY EffectiveDate DESC, ActivatedDate DESC, CreatedDate DESC, Id DESC
    ];
  }

  private static List<Order> getRelatedReturnOrders(Order saleOrder) {
    if (saleOrder == null || saleOrder.Id == null) {
      return new List<Order>();
    }

    return [
      SELECT
        Id,
        SaleNo__c,
        Status,
        EndDate,
        EffectiveDate,
        PoDate,
        IsReductionOrder__c,
        TotalAmount,
        IsDeleted__c,
        DeleteDateTime__c,
        StoreCode__c,
        StoreCode__r.Name,
        StoreCode__r.StoreCode__c,
        Account.Name,
        Account.StoreCode__c,
        MemberNo__r.Id,
        MemberNo__r.Name,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c
      FROM Order
      WHERE OriginalOrderId__c = :saleOrder.Id AND IsReductionOrder__c = TRUE
      ORDER BY CreatedDate DESC, LastModifiedDate DESC, Id DESC
    ];
  }

  private static Order getRepresentativeReturnOrder(Order currentReturnOrder, List<Order> relatedReturnOrders, Boolean isCurrentOrderReturnPage) {
    if (isCurrentOrderReturnPage == true && currentReturnOrder != null && !isSaleDeletedOrderStatus(currentReturnOrder)) {
      return currentReturnOrder;
    }

    if (relatedReturnOrders == null || relatedReturnOrders.isEmpty()) {
      return currentReturnOrder != null && !isSaleDeletedOrderStatus(currentReturnOrder) ? currentReturnOrder : null;
    }

    Order latestReturnOrder = relatedReturnOrders[0];
    if (isSaleDeletedOrderStatus(latestReturnOrder)) {
      return null;
    }

    for (Order relatedReturnOrder : relatedReturnOrders) {
      if (isCompletedReturnOrderStatus(relatedReturnOrder)) {
        return relatedReturnOrder;
      }
    }

    for (Order relatedReturnOrder : relatedReturnOrders) {
      if (relatedReturnOrder != null && !isSaleDeletedOrderStatus(relatedReturnOrder)) {
        return relatedReturnOrder;
      }
    }

    return null;
  }

  private static Order getReturnProgressOrder(Order currentReturnOrder, List<Order> relatedReturnOrders, Boolean isCurrentOrderReturnPage) {
    if (isCurrentOrderReturnPage == true && currentReturnOrder != null) {
      return currentReturnOrder;
    }

    if (relatedReturnOrders != null && !relatedReturnOrders.isEmpty()) {
      return relatedReturnOrders[0];
    }

    return currentReturnOrder;
  }

  private static List<Order> getActiveReturnOrders(List<Order> returnOrders) {
    List<Order> activeReturnOrders = new List<Order>();
    if (returnOrders == null) {
      return activeReturnOrders;
    }

    for (Order returnOrder : returnOrders) {
      if (returnOrder == null || isCancelledOrDeletedOrder(returnOrder)) {
        continue;
      }
      activeReturnOrders.add(returnOrder);
    }

    return activeReturnOrders;
  }

  @TestVisible
  private static Integer testVisibleGetActiveReturnOrderCount(List<Order> returnOrders) {
    return getActiveReturnOrders(returnOrders).size();
  }

  private static Set<Id> getOrderIds(List<Order> orders) {
    Set<Id> orderIds = new Set<Id>();
    if (orders == null) {
      return orderIds;
    }

    for (Order orderRecord : orders) {
      if (orderRecord != null && orderRecord.Id != null) {
        orderIds.add(orderRecord.Id);
      }
    }

    return orderIds;
  }

  private static Set<Id> getActiveSaleOrderIds(Order saleOrder, List<Order> relatedSaleOrders) {
    Set<Id> saleOrderIds = new Set<Id>();

    if (saleOrder != null && saleOrder.Id != null && !isSaleDeletedOrderStatus(saleOrder)) {
      saleOrderIds.add(saleOrder.Id);
    }

    if (relatedSaleOrders != null) {
      for (Order relatedSaleOrder : relatedSaleOrders) {
        if (relatedSaleOrder != null && relatedSaleOrder.Id != null && !isSaleDeletedOrderStatus(relatedSaleOrder)) {
          saleOrderIds.add(relatedSaleOrder.Id);
        }
      }
    }

    return saleOrderIds;
  }

  private static SaleStatusSummary resolveSaleStatusSummary(Order saleOrder, List<Order> relatedSaleOrders, Boolean isSaleStarted) {
    SaleStatusSummary summary = new SaleStatusSummary();
    if (!isSaleStarted) {
      summary.progressState = PROGRESS_STATE_NOT_STARTED;
      return summary;
    }

    List<Order> saleOrdersForStatus = new List<Order>();
    if (relatedSaleOrders != null) {
      for (Order relatedSaleOrder : relatedSaleOrders) {
        if (relatedSaleOrder != null && !String.isBlank(relatedSaleOrder.SaleNo__c)) {
          saleOrdersForStatus.add(relatedSaleOrder);
        }
      }
    }

    if (saleOrdersForStatus.isEmpty() && saleOrder != null && !String.isBlank(saleOrder.SaleNo__c)) {
      saleOrdersForStatus.add(saleOrder);
    }

    if (saleOrdersForStatus.isEmpty()) {
      summary.progressState = PROGRESS_STATE_NOT_STARTED;
      return summary;
    }

    Set<String> normalizedStatusValues = new Set<String>();
    Integer saleSuccessCount = 0;

    for (Order statusOrder : saleOrdersForStatus) {
      String normalizedStatusValue = normalizeStatusValue(statusOrder.Status);
      normalizedStatusValues.add(normalizedStatusValue);
      if (isSaleSuccessStatusValue(normalizedStatusValue)) {
        saleSuccessCount++;
      }
    }

    if (normalizedStatusValues.size() == 1) {
      Order firstSaleOrder = saleOrdersForStatus[0];
      summary.label = getPicklistLabel(Order.Status, firstSaleOrder.Status);
      summary.progressState = resolveStageProgressStateByStatusValue(firstSaleOrder.Status, true);
      return summary;
    }

    if (saleSuccessCount > 0 && saleSuccessCount < saleOrdersForStatus.size()) {
      summary.label = '부분 판매';
      summary.progressState = PROGRESS_STATE_IN_PROGRESS;
      return summary;
    }

    summary.label = '부분 판매';
    summary.progressState = PROGRESS_STATE_IN_PROGRESS;
    return summary;
  }

  private static List<Order> getRelatedSaleOrders(Order saleOrder) {
    if (saleOrder == null || saleOrder.Id == null) {
      return new List<Order>();
    }

    if (String.isBlank(saleOrder.SaleNo__c) && saleOrder.IsReductionOrder__c != true) {
      return getSaleOrdersLinkedToOrder(saleOrder.Id);
    }

    Id originalOrderId = resolveOriginalOrderIdFromSale(saleOrder);
    if (originalOrderId != null) {
      List<Order> linkedSaleOrders = getSaleOrdersLinkedToOrder(originalOrderId);
      if (!linkedSaleOrders.isEmpty()) {
        return linkedSaleOrders;
      }
    }

    return new List<Order>{ saleOrder };
  }

  private static List<Order> getSaleOrdersLinkedToOrder(Id originalOrderId) {
    if (originalOrderId == null) {
      return new List<Order>();
    }

    Set<Id> saleOrderIds = new Set<Id>();

    for (TransactionJournal journal : [
      SELECT SaleId__c
      FROM TransactionJournal
      WHERE OrderId__c = :originalOrderId AND SaleId__c != NULL
    ]) {
      if (journal.SaleId__c != null && journal.SaleId__c != originalOrderId) {
        saleOrderIds.add(journal.SaleId__c);
      }
    }

    for (OrderItem linkedSaleItem : [
      SELECT OrderId
      FROM OrderItem
      WHERE OrderId__c = :originalOrderId AND OrderId != NULL
    ]) {
      if (linkedSaleItem.OrderId != null && linkedSaleItem.OrderId != originalOrderId) {
        saleOrderIds.add(linkedSaleItem.OrderId);
      }
    }

    if (saleOrderIds.isEmpty()) {
      return new List<Order>();
    }

    return [
      SELECT
        Id,
        OrderNo__c,
        SaleNo__c,
        Status,
        EndDate,
        EffectiveDate,
        PoDate,
        ActualPaymentAmount__c,
        OriginalOrderId__c,
        StoreCode__c,
        StoreCode__r.Name,
        StoreCode__r.StoreCode__c,
        Account.Name,
        Account.StoreCode__c,
        MemberNo__r.Id,
        MemberNo__r.Name,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c
      FROM Order
      WHERE Id IN :saleOrderIds AND IsReductionOrder__c = FALSE AND SaleNo__c != NULL
      ORDER BY EndDate DESC, EffectiveDate DESC, CreatedDate DESC
    ];
  }

  private static Order getRepresentativeSaleOrder(Order currentSaleOrder, List<Order> relatedSaleOrders, Boolean isCurrentOrderReturnPage) {
    if (currentSaleOrder == null) {
      return null;
    }

    if (isCurrentOrderReturnPage == true) {
      return currentSaleOrder;
    }

    if (relatedSaleOrders == null || relatedSaleOrders.isEmpty()) {
      return currentSaleOrder;
    }

    for (Order relatedSaleOrder : relatedSaleOrders) {
      if (relatedSaleOrder != null && !isSaleDeletedOrderStatus(relatedSaleOrder)) {
        return relatedSaleOrder;
      }
    }

    return currentSaleOrder;
  }

  private static List<Order> prioritizeRepresentativeSaleOrder(List<Order> relatedSaleOrders, Order representativeSaleOrder) {
    if (relatedSaleOrders == null || relatedSaleOrders.isEmpty()) {
      return relatedSaleOrders == null ? new List<Order>() : relatedSaleOrders;
    }

    if (representativeSaleOrder == null || representativeSaleOrder.Id == null) {
      return relatedSaleOrders;
    }

    List<Order> prioritizedSaleOrders = new List<Order>();

    for (Order relatedSaleOrder : relatedSaleOrders) {
      if (relatedSaleOrder != null && relatedSaleOrder.Id == representativeSaleOrder.Id) {
        prioritizedSaleOrders.add(relatedSaleOrder);
        break;
      }
    }

    for (Order relatedSaleOrder : relatedSaleOrders) {
      if (relatedSaleOrder == null || relatedSaleOrder.Id == representativeSaleOrder.Id) {
        continue;
      }
      prioritizedSaleOrders.add(relatedSaleOrder);
    }

    return prioritizedSaleOrders;
  }

  private static Order getLatestCompletedSaleOrder(Order currentSaleOrder) {
    if (currentSaleOrder == null) {
      return null;
    }

    if (currentSaleOrder.OriginalOrderId__c != null) {
      List<Order> completedSiblingSaleOrders = [
        SELECT
          Id,
          SaleNo__c,
          Status,
          EndDate,
          EffectiveDate,
          PoDate,
          ActualPaymentAmount__c,
          OriginalOrderId__c,
          StoreCode__c,
          StoreCode__r.Name,
          StoreCode__r.StoreCode__c,
          Account.Name,
          Account.StoreCode__c
        FROM Order
        WHERE
          OriginalOrderId__c = :currentSaleOrder.OriginalOrderId__c
          AND IsReductionOrder__c = FALSE
          AND SaleNo__c != NULL
          AND Status = :SALE_SUCCESS_STATUS_VALUE
        ORDER BY EndDate DESC, EffectiveDate DESC, CreatedDate DESC
        LIMIT 1
      ];

      if (!completedSiblingSaleOrders.isEmpty()) {
        return completedSiblingSaleOrders[0];
      }
    }

    if (currentSaleOrder.Id != null) {
      List<Order> completedChildSaleOrders = [
        SELECT
          Id,
          SaleNo__c,
          Status,
          EndDate,
          EffectiveDate,
          PoDate,
          ActualPaymentAmount__c,
          OriginalOrderId__c,
          StoreCode__c,
          StoreCode__r.Name,
          StoreCode__r.StoreCode__c,
          Account.Name,
          Account.StoreCode__c
        FROM Order
        WHERE OriginalOrderId__c = :currentSaleOrder.Id AND IsReductionOrder__c = FALSE AND SaleNo__c != NULL AND Status = :SALE_SUCCESS_STATUS_VALUE
        ORDER BY EndDate DESC, EffectiveDate DESC, CreatedDate DESC
        LIMIT 1
      ];

      if (!completedChildSaleOrders.isEmpty()) {
        return completedChildSaleOrders[0];
      }
    }

    return isCompletedSaleOrderStatus(currentSaleOrder) ? currentSaleOrder : null;
  }

  @TestVisible
  private static Integer testVisibleGetRelatedSaleOrderCount(Order saleOrder) {
    return getRelatedSaleOrders(saleOrder).size();
  }

  @TestVisible
  private static String testVisibleGetRepresentativeSaleNo(Order saleOrder) {
    Order representativeSaleOrder = getRepresentativeSaleOrder(saleOrder, getRelatedSaleOrders(saleOrder), false);
    return representativeSaleOrder == null ? null : representativeSaleOrder.SaleNo__c;
  }

  private class SaleStatusSummary {
    String label;
    String progressState;
  }

  public class OrderDetailDto {
    @AuraEnabled
    public Id orderRecordId;
    @AuraEnabled
    public Id saleOrderId;
    @AuraEnabled
    public Id returnOrderId;
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
    public Decimal orderDeptVoucherAmount;
    @AuraEnabled
    public Decimal orderHqVoucherAmount;
    @AuraEnabled
    public Decimal orderUpgradeAmount;
    @AuraEnabled
    public Decimal orderProvisionalAmount;
    @AuraEnabled
    public Decimal orderDepositTotalAmount;
    @AuraEnabled
    public List<OrderRecordDto> orderRecords;

    @AuraEnabled
    public String saleNo;
    @AuraEnabled
    public Datetime saleDate;
    @AuraEnabled
    public String saleStatus;
    @AuraEnabled
    public String saleProgressState;
    @AuraEnabled
    public Boolean saleDetailAvailable;
    @AuraEnabled
    public String saleStoreName;
    @AuraEnabled
    public List<OrderItemDto> orderItems;
    @AuraEnabled
    public List<OrderItemDto> saleItems;
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
    public Decimal saleDeptVoucherAmount;
    @AuraEnabled
    public Decimal saleHqVoucherAmount;
    @AuraEnabled
    public Decimal saleUpgradeAmount;
    @AuraEnabled
    public Decimal saleProvisionalAmount;
    @AuraEnabled
    public Decimal saleDepositTotalAmount;
    @AuraEnabled
    public Boolean saleHasDepositCancellation;
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
    public String returnProgressState;
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
    public Decimal refundDeptVoucherAmount;
    @AuraEnabled
    public Decimal refundHqVoucherAmount;
    @AuraEnabled
    public Decimal refundUpgradeAmount;
    @AuraEnabled
    public Decimal refundProvisionalAmount;
    @AuraEnabled
    public Decimal returnDepositTotalAmount;
    @AuraEnabled
    public Boolean returnHasDepositCancellation;
    @AuraEnabled
    public Decimal restoredPointAmount;
    @AuraEnabled
    public List<EarnedPointItemDto> restoredPointItems;
    @AuraEnabled
    public List<OrderItemDto> returnItems;

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
      List<Order> returnOrders,
      List<Order> relatedSaleOrders,
      List<OrderItem> orderItemList,
      List<OrderItem> returnOrderItemList,
      List<TransactionJournal> tjList
    ) {
      this(
        displayOrder,
        saleOrder,
        returnOrder,
        displayOrder == null ? new List<Order>() : new List<Order>{ displayOrder },
        returnOrders,
        relatedSaleOrders,
        orderItemList,
        orderItemList,
        returnOrderItemList,
        tjList,
        false,
        returnOrder
      );
    }

    public OrderDetailDto(
      Order displayOrder,
      Order saleOrder,
      Order returnOrder,
      List<Order> relatedOrderOrders,
      List<Order> returnOrders,
      List<Order> relatedSaleOrders,
      List<OrderItem> orderItemList,
      List<OrderItem> returnOrderItemList,
      List<TransactionJournal> tjList
    ) {
      this(
        displayOrder,
        saleOrder,
        returnOrder,
        relatedOrderOrders,
        returnOrders,
        relatedSaleOrders,
        orderItemList,
        orderItemList,
        returnOrderItemList,
        tjList,
        false,
        returnOrder
      );
    }

    public OrderDetailDto(
      Order displayOrder,
      Order saleOrder,
      Order returnOrder,
      List<Order> returnOrders,
      List<Order> relatedSaleOrders,
      List<OrderItem> orderItemList,
      List<OrderItem> saleOrderItemList,
      List<OrderItem> returnOrderItemList,
      List<TransactionJournal> tjList
    ) {
      this(
        displayOrder,
        saleOrder,
        returnOrder,
        displayOrder == null ? new List<Order>() : new List<Order>{ displayOrder },
        returnOrders,
        relatedSaleOrders,
        orderItemList,
        saleOrderItemList,
        returnOrderItemList,
        tjList,
        false,
        returnOrder
      );
    }

    public OrderDetailDto(
      Order displayOrder,
      Order saleOrder,
      Order returnOrder,
      List<Order> returnOrders,
      List<Order> relatedSaleOrders,
      List<OrderItem> orderItemList,
      List<OrderItem> saleOrderItemList,
      List<OrderItem> returnOrderItemList,
      List<TransactionJournal> tjList,
      Boolean isCurrentOrderReturnPage,
      Order returnProgressOrder
    ) {
      this(
        displayOrder,
        saleOrder,
        returnOrder,
        displayOrder == null ? new List<Order>() : new List<Order>{ displayOrder },
        returnOrders,
        relatedSaleOrders,
        orderItemList,
        saleOrderItemList,
        returnOrderItemList,
        tjList,
        isCurrentOrderReturnPage,
        returnProgressOrder
      );
    }

    public OrderDetailDto(
      Order displayOrder,
      Order saleOrder,
      Order returnOrder,
      List<Order> returnOrders,
      List<Order> relatedSaleOrders,
      List<OrderItem> orderItemList,
      List<OrderItem> saleOrderItemList,
      List<OrderItem> returnOrderItemList,
      List<TransactionJournal> tjList,
      Boolean isCurrentOrderReturnPage
    ) {
      this(
        displayOrder,
        saleOrder,
        returnOrder,
        displayOrder == null ? new List<Order>() : new List<Order>{ displayOrder },
        returnOrders,
        relatedSaleOrders,
        orderItemList,
        saleOrderItemList,
        returnOrderItemList,
        tjList,
        isCurrentOrderReturnPage,
        returnOrder
      );
    }

    public OrderDetailDto(
      Order displayOrder,
      Order saleOrder,
      Order returnOrder,
      List<Order> relatedOrderOrders,
      List<Order> returnOrders,
      List<Order> relatedSaleOrders,
      List<OrderItem> orderItemList,
      List<OrderItem> saleOrderItemList,
      List<OrderItem> returnOrderItemList,
      List<TransactionJournal> tjList,
      Boolean isCurrentOrderReturnPage,
      Order returnProgressOrder
    ) {
      Boolean isSaleStarted = saleOrder != null && !String.isBlank(saleOrder.SaleNo__c);
      Boolean isSaleDetailVisible = isSaleStarted && !isSaleDeletedOrderStatus(saleOrder);
      Boolean isOrderStarted = !String.isBlank(getDisplayOrderNumber(displayOrder, saleOrder));
      Order customerSourceOrder = pickCustomerSourceOrder(displayOrder, saleOrder, returnOrder);
      String orderFallbackStore = resolveStoreCode(displayOrder, saleOrder);
      List<Order> effectiveOrderRecords = relatedOrderOrders == null ? new List<Order>() : relatedOrderOrders;
      Boolean showNegativeReturnAmounts = isCurrentOrderReturnPage == true && isSaleDeletedOrderStatus(returnOrder);
      Boolean showNegativeSaleAmounts = isSaleDeletedOrderStatus(saleOrder);
      SaleStatusSummary saleStatusSummary = resolveSaleStatusSummary(saleOrder, relatedSaleOrders, isSaleStarted);

      orderNo = getDisplayOrderNumber(displayOrder, saleOrder);
      orderRecordId = resolveDisplayOrderId(displayOrder, saleOrder);
      saleOrderId = isSaleStarted ? saleOrder.Id : null;
      orderDate = isOrderStarted ? getDisplayOrderDate(displayOrder, saleOrder) : null;
      orderStatus = isOrderStarted && displayOrder != null ? getPicklistLabel(Order.OrderStatus__c, displayOrder.OrderStatus__c) : null;
      orderType = isOrderStarted && displayOrder != null ? getPicklistLabel(Order.Type, getQueriedStringValue(displayOrder, 'Type')) : null;
      orderStoreName = isOrderStarted ? getOrderStoreCode(orderNo, orderFallbackStore) : null;

      saleNo = isSaleStarted ? saleOrder.SaleNo__c : null;
      saleDate = isSaleStarted ? (saleOrder.EndDate != null ? saleOrder.EndDate : saleOrder.EffectiveDate) : null;
      saleStatus = saleStatusSummary.label;
      saleProgressState = saleStatusSummary.progressState;
      saleDetailAvailable = isSaleDetailVisible;
      saleStoreName = isSaleStarted ? getSaleStoreCode(saleOrder.SaleNo__c, orderStoreName) : null;

      orderItems = new List<OrderItemDto>();
      saleItems = new List<OrderItemDto>();
      returnItems = new List<OrderItemDto>();
      earnedPointItems = new List<EarnedPointItemDto>();
      restoredPointItems = new List<EarnedPointItemDto>();
      orderRecords = new List<OrderRecordDto>();
      saleRecords = new List<SaleRecordDto>();
      pointTypeOptions = getPointTypeOptions();
      Set<Id> saleOrderIds = new Set<Id>();
      if (saleOrder != null && saleOrder.Id != null && !isSaleDeletedOrderStatus(saleOrder)) {
        saleOrderIds.add(saleOrder.Id);
      }
      if (relatedSaleOrders != null) {
        for (Order relatedSale : relatedSaleOrders) {
          if (relatedSale != null && relatedSale.Id != null && !isSaleDeletedOrderStatus(relatedSale)) {
            saleOrderIds.add(relatedSale.Id);
          }
        }
      }
      Set<Id> returnOrderIds = getReturnSummaryOrderIds(returnOrders);
      Boolean isReturnStarted = returnOrder != null && !String.isBlank(returnOrder.SaleNo__c);
      Order effectiveReturnProgressOrder = returnProgressOrder;
      if (effectiveReturnProgressOrder == null && returnOrders != null && !returnOrders.isEmpty()) {
        effectiveReturnProgressOrder = returnOrders[0];
      }
      Boolean hasReturnProgressData = effectiveReturnProgressOrder != null && !String.isBlank(effectiveReturnProgressOrder.SaleNo__c);
      String returnStatusValue = effectiveReturnProgressOrder != null ? effectiveReturnProgressOrder.Status : null;
      Boolean showNegativeRestoredPoints = isCurrentOrderReturnPage == true && isSaleDeletedOrderStatus(returnOrder);
      returnNo = isReturnStarted ? returnOrder.SaleNo__c : null;
      returnOrderId = isReturnStarted ? returnOrder.Id : null;
      returnDate = isReturnStarted ? (returnOrder.EndDate != null ? returnOrder.EndDate : returnOrder.EffectiveDate) : null;
      returnStatus = isReturnStarted ? getPicklistLabel(Order.Status, returnOrder.Status) : null;
      returnProgressState = resolveStageProgressStateByStatusValue(returnStatusValue, hasReturnProgressData);
      returnStoreName = isReturnStarted ? getReturnStoreCode(returnNo, saleStoreName) : null;

      totalAmount = 0;
      orderQuantity = 0;
      saleQuantity = 0;
      returnQuantity = 0;
      earnedPointAmount = 0;
      restoredPointAmount = 0;

      if (orderItemList != null) {
        for (OrderItem orderItem : orderItemList) {
          Decimal quantity = orderItem.Quantity == null ? 0 : orderItem.Quantity;
          if (isOrderStarted) {
            orderQuantity += quantity;
            orderItems.add(new OrderItemDto(orderItem));
          }
        }
      }

      if (saleOrderItemList != null) {
        for (OrderItem saleOrderItem : saleOrderItemList) {
          Decimal quantity = saleOrderItem.Quantity == null ? 0 : saleOrderItem.Quantity;
          if (isSaleDetailVisible) {
            saleItems.add(new OrderItemDto(saleOrderItem));
            saleQuantity += quantity;
          }
        }
      }

      if (returnOrderItemList != null) {
        for (OrderItem returnOrderItem : returnOrderItemList) {
          Decimal quantity = returnOrderItem.Quantity == null ? 0 : returnOrderItem.Quantity;
          returnQuantity += quantity < 0 ? quantity.abs() : quantity;
          returnItems.add(new OrderItemDto(returnOrderItem));
        }
      }

      if (hasQueriedMember(customerSourceOrder)) {
        customerName = customerSourceOrder.MemberNo__r.Name;
        customerMemberNo = customerSourceOrder.MemberNo__r.MemberNo__c;
        customerPhone = customerSourceOrder.MemberNo__r.MobilePhone;
        customerGrade = getPicklistLabel(Contact.Grade__c, customerSourceOrder.MemberNo__r.Grade__c);
        managedStoreName = resolveStoreCode(customerSourceOrder, saleOrder);

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

      Boolean subtractOrderDepositReversal = !isProvisionalOrderCancellation(effectiveOrderRecords, displayOrder);
      PaymentSummary orderPaymentSummary = isOrderStarted
        ? getOrderPaymentSummary(effectiveOrderRecords, orderNo, subtractOrderDepositReversal)
        : new PaymentSummary();
      PaymentSummary salePaymentSummary = isSaleDetailVisible ? getOriginalSalePaymentSummaryForOrderIds(saleOrderIds) : new PaymentSummary();
      PaymentSummary returnPaymentSummary = isCurrentOrderReturnPage == true &&
        returnOrder != null
        ? buildReturnEventPaymentSummary(saleOrder, returnOrder)
        : (!returnOrderIds.isEmpty() ? getCumulativeReturnPaymentSummary(saleOrder, returnOrders) : new PaymentSummary());
      Boolean hasDepositCancellation = isSaleDetailVisible ? hasDepositCancellation(saleOrder, returnOrders) : false;

      Set<Id> journalIds = getSaleJournalIds(saleOrder, relatedSaleOrders, tjList);
      Map<String, PointAmountSummary> earnedPointAmountByType = new Map<String, PointAmountSummary>();
      Map<String, PointAmountSummary> restoredPointAmountByType = new Map<String, PointAmountSummary>();

      if (isSaleDetailVisible) {
        accumulateSalePointAmounts(saleOrderIds, earnedPointAmountByType);
      }
      if (isReturnStarted) {
        if (isCurrentOrderReturnPage == true && returnOrder != null) {
          accumulateReturnOrderPointAmounts(saleOrder, returnOrder, restoredPointAmountByType);
        } else {
          accumulateCumulativeReturnPointAmounts(saleOrder, returnOrders, restoredPointAmountByType);
        }
      }

      for (PointAmountSummary pointSummary : earnedPointAmountByType.values()) {
        Decimal displayEarnedAmount = normalizeReturnDisplayAmount(pointSummary.amount, showNegativeSaleAmounts);
        earnedPointItems.add(new EarnedPointItemDto(pointSummary.type, pointSummary.label, displayEarnedAmount));
        earnedPointAmount += displayEarnedAmount;
      }

      for (PointAmountSummary pointSummary : restoredPointAmountByType.values()) {
        Decimal displayRestoredAmount = normalizeReturnDisplayAmount(pointSummary.amount, showNegativeRestoredPoints);
        restoredPointItems.add(new EarnedPointItemDto(pointSummary.type, pointSummary.label, displayRestoredAmount));
        restoredPointAmount += displayRestoredAmount;
      }

      orderCashAmount = orderPaymentSummary.cashAmount;
      orderCardAmount = orderPaymentSummary.cardAmount;
      orderCouponAmount = orderPaymentSummary.couponAmount;
      orderPointAmount = orderPaymentSummary.pointAmount;
      orderDeptVoucherAmount = orderPaymentSummary.deptVoucherAmount;
      orderHqVoucherAmount = orderPaymentSummary.hqVoucherAmount;
      orderUpgradeAmount = orderPaymentSummary.upgradeAmount;
      orderProvisionalAmount = orderPaymentSummary.provisionalAmount;
      orderDepositTotalAmount = orderPaymentSummary.totalAmount;
      totalAmount = isOrderStarted ? resolveOrderTotalAmount(effectiveOrderRecords, displayOrder, saleOrder) : 0;

      if (isOrderStarted && effectiveOrderRecords != null) {
        for (Order relatedOrder : effectiveOrderRecords) {
          if (relatedOrder == null || String.isBlank(relatedOrder.OrderNo__c)) {
            continue;
          }

          orderRecords.add(
            new OrderRecordDto(
              relatedOrder.Id,
              relatedOrder.OrderNo__c,
              getPicklistLabel(Order.OrderStatus__c, relatedOrder.OrderStatus__c),
              getOrderPoDateTime(relatedOrder),
              resolveStoreCode(relatedOrder, displayOrder),
              getDisplayOrderTotalAmount(relatedOrder, null, getQueriedDecimalValue(relatedOrder, 'ActualPaymentAmount__c'))
            )
          );
        }
      }

      saleCashAmount = normalizeReturnDisplayAmount(salePaymentSummary.cashAmount, showNegativeSaleAmounts);
      saleCardAmount = normalizeReturnDisplayAmount(salePaymentSummary.cardAmount, showNegativeSaleAmounts);
      saleCouponAmount = normalizeReturnDisplayAmount(salePaymentSummary.couponAmount, showNegativeSaleAmounts);
      salePointAmount = normalizeReturnDisplayAmount(salePaymentSummary.pointAmount, showNegativeSaleAmounts);
      saleDeptVoucherAmount = normalizeReturnDisplayAmount(salePaymentSummary.deptVoucherAmount, showNegativeSaleAmounts);
      saleHqVoucherAmount = normalizeReturnDisplayAmount(salePaymentSummary.hqVoucherAmount, showNegativeSaleAmounts);
      saleUpgradeAmount = normalizeReturnDisplayAmount(salePaymentSummary.upgradeAmount, showNegativeSaleAmounts);
      saleProvisionalAmount = normalizeReturnDisplayAmount(salePaymentSummary.provisionalAmount, showNegativeSaleAmounts);
      Decimal aggregatedSaleTotal = 0;
      Boolean hasAggregatedSaleTotal = false;
      if (isSaleDetailVisible && relatedSaleOrders != null) {
        for (Order relatedSale : relatedSaleOrders) {
          Decimal relatedSaleActualPaymentAmount = getQueriedDecimalValue(relatedSale, 'ActualPaymentAmount__c');
          if (relatedSale != null && relatedSaleActualPaymentAmount != null && !isSaleDeletedOrderStatus(relatedSale)) {
            aggregatedSaleTotal += relatedSaleActualPaymentAmount;
            hasAggregatedSaleTotal = true;
          }
        }
      }
      saleTotalAmount = isSaleDetailVisible ? (hasAggregatedSaleTotal ? aggregatedSaleTotal : resolveSaleTotalAmount(saleOrder)) : 0;
      saleDepositTotalAmount = normalizeReturnDisplayAmount(salePaymentSummary.totalAmount, showNegativeSaleAmounts);
      saleHasDepositCancellation = isSaleDetailVisible ? hasDepositCancellation : false;

      if (isSaleStarted && relatedSaleOrders != null) {
        for (Order relatedSaleOrder : relatedSaleOrders) {
          if (String.isBlank(relatedSaleOrder.SaleNo__c)) {
            continue;
          }

          saleRecords.add(
            new SaleRecordDto(
              relatedSaleOrder.Id,
              relatedSaleOrder.SaleNo__c,
              getPicklistLabel(Order.Status, relatedSaleOrder.Status),
              relatedSaleOrder.EndDate != null ? relatedSaleOrder.EndDate : relatedSaleOrder.EffectiveDate,
              getSaleStoreCode(relatedSaleOrder.SaleNo__c, resolveStoreCode(relatedSaleOrder, saleOrder)),
              getQueriedDecimalValue(relatedSaleOrder, 'ActualPaymentAmount__c')
            )
          );
        }
      }

      refundCashAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.cashAmount, showNegativeReturnAmounts) : 0;
      refundCardAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.cardAmount, showNegativeReturnAmounts) : 0;
      refundCouponAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.couponAmount, showNegativeReturnAmounts) : 0;
      refundPointAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.pointAmount, showNegativeReturnAmounts) : 0;
      refundDeptVoucherAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.deptVoucherAmount, showNegativeReturnAmounts) : 0;
      refundHqVoucherAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.hqVoucherAmount, showNegativeReturnAmounts) : 0;
      refundUpgradeAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.upgradeAmount, showNegativeReturnAmounts) : 0;
      refundProvisionalAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.provisionalAmount, showNegativeReturnAmounts) : 0;
      returnDepositTotalAmount = isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.totalAmount, showNegativeReturnAmounts) : 0;
      returnHasDepositCancellation = isReturnStarted ? hasDepositCancellation : false;
      Decimal aggregatedReturnTotalAmount = 0;
      if (returnOrders != null) {
        for (Order relatedReturnOrder : returnOrders) {
          if (relatedReturnOrder != null && relatedReturnOrder.TotalAmount != null) {
            aggregatedReturnTotalAmount += relatedReturnOrder.TotalAmount;
          }
        }
      }
      returnTotalAmount = isReturnStarted && aggregatedReturnTotalAmount != 0
        ? normalizeReturnDisplayAmount(aggregatedReturnTotalAmount, showNegativeReturnAmounts)
        : (isReturnStarted ? normalizeReturnDisplayAmount(returnPaymentSummary.totalAmount, showNegativeReturnAmounts) : 0);
    }
  }

  @TestVisible
  private static String resolveStoreCode(Order primaryOrder, Order fallbackOrder) {
    String primaryStoreName = getStoreDisplayName(primaryOrder);
    if (!String.isBlank(primaryStoreName)) {
      return primaryStoreName;
    }

    String fallbackStoreName = getStoreDisplayName(fallbackOrder);
    if (!String.isBlank(fallbackStoreName)) {
      return fallbackStoreName;
    }

    return null;
  }

  private static String getStoreDisplayName(Order orderRecord) {
    if (orderRecord == null) {
      return null;
    }

    Map<String, Object> populatedFieldMap = orderRecord.getPopulatedFieldsAsMap();

    if (populatedFieldMap.containsKey('StoreCode__r') && populatedFieldMap.get('StoreCode__r') instanceof SObject) {
      SObject storeRecord = (SObject) populatedFieldMap.get('StoreCode__r');
      String storeName = getQueriedStringValue(storeRecord, 'Name');
      if (!String.isBlank(storeName)) {
        return storeName;
      }

      String relatedStoreCode = getQueriedStringValue(storeRecord, 'StoreCode__c');
      if (!String.isBlank(relatedStoreCode)) {
        return getStoreNameByCode(relatedStoreCode);
      }
    }

    String storeCodeValue = getQueriedStringValue(orderRecord, 'StoreCode__c');
    if (!String.isBlank(storeCodeValue)) {
      return getStoreNameByCode(storeCodeValue);
    }

    if (populatedFieldMap.containsKey('Account') && populatedFieldMap.get('Account') instanceof SObject) {
      SObject accountRecord = (SObject) populatedFieldMap.get('Account');
      String accountName = getQueriedStringValue(accountRecord, 'Name');
      if (!String.isBlank(accountName)) {
        return accountName;
      }

      String accountStoreCode = getQueriedStringValue(accountRecord, 'StoreCode__c');
      if (!String.isBlank(accountStoreCode)) {
        return getStoreNameByCode(accountStoreCode);
      }
    }

    return null;
  }

  private static String getDisplayOrderNumber(Order displayOrder, Order saleOrder) {
    String displayOrderNo = getQueriedStringValue(displayOrder, 'OrderNo__c');
    if (!String.isBlank(displayOrderNo)) {
      return displayOrderNo;
    }

    String saleOrderNo = getQueriedStringValue(saleOrder, 'OrderNo__c');
    if (!String.isBlank(saleOrderNo)) {
      return saleOrderNo;
    }

    return null;
  }

  private static Order pickCustomerSourceOrder(Order displayOrder, Order saleOrder, Order returnOrder) {
    if (hasQueriedMember(displayOrder)) {
      return displayOrder;
    }
    if (hasQueriedMember(saleOrder)) {
      return saleOrder;
    }
    if (hasQueriedMember(returnOrder)) {
      return returnOrder;
    }
    return displayOrder != null ? displayOrder : (saleOrder != null ? saleOrder : returnOrder);
  }

  private static Boolean hasQueriedMember(Order orderRecord) {
    if (orderRecord == null) {
      return false;
    }
    try {
      return orderRecord.MemberNo__r != null;
    } catch (System.SObjectException ex) {
      return false;
    }
  }

  private static Id resolveDisplayOrderId(Order displayOrder, Order saleOrder) {
    String displayOrderNo = getQueriedStringValue(displayOrder, 'OrderNo__c');
    if (!String.isBlank(displayOrderNo)) {
      return displayOrder.Id;
    }

    String saleOrderNo = getQueriedStringValue(saleOrder, 'OrderNo__c');
    if (!String.isBlank(saleOrderNo) && saleOrder != null) {
      return saleOrder.Id;
    }

    return null;
  }

  @TestVisible
  private static String testVisibleGetDisplayOrderNumber(Order displayOrder, Order saleOrder) {
    return getDisplayOrderNumber(displayOrder, saleOrder);
  }

  @TestVisible
  private static Datetime getDisplayOrderDate(Order displayOrder, Order saleOrder) {
    Datetime displayOrderDate = getOrderPoDateTime(displayOrder);
    if (displayOrderDate != null) {
      return displayOrderDate;
    }

    Datetime saleOrderDate = getOrderPoDateTime(saleOrder);
    if (saleOrderDate != null) {
      return saleOrderDate;
    }

    return null;
  }

  private static Datetime getOrderPoDateTime(Order orderRecord) {
    Object orderDate = getQueriedValue(orderRecord, 'PoDate');
    return orderDate instanceof Date ? toOrderDateTime((Date) orderDate) : null;
  }

  private static Datetime toOrderDateTime(Date orderDate) {
    return orderDate == null ? null : Datetime.newInstance(orderDate, Time.newInstance(0, 0, 0, 0));
  }

  @TestVisible
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

  private static Decimal resolveOrderTotalAmount(List<Order> relatedOrderOrders, Order displayOrder, Order saleOrder) {
    Decimal aggregatedOrderTotalAmount = 0;
    Boolean hasAggregatedOrderAmount = false;

    if (relatedOrderOrders != null) {
      for (Order relatedOrder : relatedOrderOrders) {
        Decimal orderTotalAmount = getQueriedDecimalValue(relatedOrder, 'TotalAmount');
        if (orderTotalAmount == null) {
          continue;
        }
        aggregatedOrderTotalAmount += orderTotalAmount;
        hasAggregatedOrderAmount = true;
      }
    }

    if (hasAggregatedOrderAmount) {
      return aggregatedOrderTotalAmount;
    }

    Decimal displayOrderTotalAmount = getDisplayOrderTotalAmount(displayOrder, saleOrder, 0);
    if (displayOrderTotalAmount != null && displayOrderTotalAmount > 0) {
      return displayOrderTotalAmount;
    }

    Decimal saleOrderTotalAmount = getQueriedDecimalValue(saleOrder, 'ActualPaymentAmount__c');
    return saleOrderTotalAmount != null ? saleOrderTotalAmount : 0;
  }

  @TestVisible
  private static Decimal testVisibleResolveOrderTotalAmount(Order displayOrder, Order saleOrder) {
    return resolveOrderTotalAmount(displayOrder == null ? new List<Order>() : new List<Order>{ displayOrder }, displayOrder, saleOrder);
  }

  private static Boolean isProvisionalOrderCancellation(List<Order> relatedOrderOrders, Order displayOrder) {
    List<Order> ordersToCheck = new List<Order>();
    if (relatedOrderOrders != null) {
      ordersToCheck.addAll(relatedOrderOrders);
    }
    if (displayOrder != null) {
      ordersToCheck.add(displayOrder);
    }

    for (Order orderRecord : ordersToCheck) {
      if (orderRecord == null) {
        continue;
      }

      String statusValue = getQueriedStringValue(orderRecord, 'OrderStatus__c');
      String statusLabel = getPicklistLabel(Order.OrderStatus__c, statusValue);
      String normalizedValue = normalizeStatusValue(statusValue);
      String normalizedLabel = normalizeStatusValue(statusLabel);

      Boolean isProvisional =
        normalizedValue.contains('가주문') ||
        normalizedLabel.contains('가주문') ||
        normalizedValue.contains('provisional') ||
        normalizedLabel.contains('provisional');
      Boolean isCancelled =
        normalizedValue.contains('취소') ||
        normalizedLabel.contains('취소') ||
        normalizedValue.contains('cancel') ||
        normalizedLabel.contains('cancel');

      if (isProvisional && isCancelled) {
        return true;
      }
    }

    return false;
  }

  private static PaymentSummary getOrderPaymentSummary(List<Order> relatedOrderOrders, String fallbackOrderNo, Boolean subtractOrderDepositReversal) {
    Set<Id> orderIds = getOrderIds(relatedOrderOrders);
    if (!orderIds.isEmpty()) {
      PaymentSummary summary;
      if (subtractOrderDepositReversal == true) {
        summary = getOrderPaymentSummaryByOrderIds(orderIds);
        applyCouponRedemptionByOrderIds(summary, orderIds, 'OrderId__c');
      } else {
        summary = getPaymentSummaryByOrderIds(orderIds, DEPOSIT_JOURNAL_TYPE_NAMES);
      }
      applyPointRedemptionByOrderIds(summary, orderIds, 'OrderId__c');
      return summary;
    }

    return getPaymentSummaryByOrderNumber('OrderNo__c', fallbackOrderNo, null, subtractOrderDepositReversal);
  }

  private static Decimal resolveSaleTotalAmount(Order saleOrder) {
    if (saleOrder == null || String.isBlank(saleOrder.SaleNo__c)) {
      return 0;
    }

    List<Order> matchedSales = [
      SELECT ActualPaymentAmount__c
      FROM Order
      WHERE SaleNo__c = :saleOrder.SaleNo__c
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    if (!matchedSales.isEmpty() && matchedSales[0].ActualPaymentAmount__c != null) {
      return matchedSales[0].ActualPaymentAmount__c;
    }

    return saleOrder.ActualPaymentAmount__c != null ? saleOrder.ActualPaymentAmount__c : 0;
  }

  @TestVisible
  private static Decimal testVisibleResolveSaleTotalAmount(Order saleOrder) {
    return resolveSaleTotalAmount(saleOrder);
  }

  private static Set<Id> getReturnPointJournalIds(Order saleOrder, List<Order> returnOrders) {
    Set<Id> returnJournalIds = new Set<Id>();
    Set<Id> returnOrderIds = getReturnSummaryOrderIds(returnOrders);
    Set<Id> linkedReturnPointSubTypeIds = getReturnPointLinkedSubTypeIds();

    if (!returnOrderIds.isEmpty()) {
      for (TransactionJournal returnJournal : [
        SELECT Id
        FROM TransactionJournal
        WHERE OrderId IN :returnOrderIds
      ]) {
        returnJournalIds.add(returnJournal.Id);
      }
    }

    returnJournalIds.addAll(getLinkedSaleJournalIdsBySubtypeIds(saleOrder, returnOrderIds, linkedReturnPointSubTypeIds));

    return returnJournalIds;
  }

  private static Set<Id> getReturnPointRestoreSubTypeIds() {
    return getJournalSubTypeIdsByNames(RETURN_POINT_RESTORE_JOURNAL_SUBTYPE_NAMES);
  }

  private static Set<Id> getReturnPointCancelSubTypeIds() {
    return getJournalSubTypeIdsByNames(RETURN_POINT_CANCEL_JOURNAL_SUBTYPE_NAMES);
  }

  private static Set<Id> getReturnPointLinkedSubTypeIds() {
    Set<Id> linkedSubTypeIds = getReturnPointRestoreSubTypeIds();
    linkedSubTypeIds.addAll(getReturnPointCancelSubTypeIds());
    return linkedSubTypeIds;
  }

  private static Set<Id> getReturnSummaryOrderIds(List<Order> returnOrders) {
    Set<Id> returnOrderIds = new Set<Id>();
    if (returnOrders == null) {
      return returnOrderIds;
    }

    for (Order returnOrder : returnOrders) {
      if (isReturnOrderForSummary(returnOrder)) {
        returnOrderIds.add(returnOrder.Id);
      }
    }

    return returnOrderIds;
  }

  private static Boolean hasDepositCancellation(Order saleOrder, List<Order> returnOrders) {
    Set<Id> returnOrderIds = getReturnSummaryOrderIds(returnOrders);
    if (saleOrder == null || saleOrder.Id == null || returnOrderIds.isEmpty()) {
      return false;
    }

    Id depositReversalTypeId = getJournalTypeIdByName('Deposit Reversal');
    if (depositReversalTypeId == null) {
      return false;
    }

    Set<Id> reversalSubTypeIds = new Set<Id>();
    reversalSubTypeIds.addAll(getJournalSubTypeIdsByName(SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME));
    reversalSubTypeIds.addAll(getJournalSubTypeIdsByName(ORDER_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME));
    if (reversalSubTypeIds.isEmpty()) {
      return false;
    }

    Integer directReturnReversalCount = [
      SELECT COUNT()
      FROM TransactionJournal
      WHERE OrderId IN :returnOrderIds AND JournalTypeId = :depositReversalTypeId AND JournalSubTypeId IN :reversalSubTypeIds
    ];
    if (directReturnReversalCount > 0) {
      return true;
    }

    Set<Id> linkedSaleDepositReversalJournalIds = getLinkedSaleJournalIdsBySubtypeIds(
      saleOrder,
      returnOrderIds,
      reversalSubTypeIds,
      new Set<Id>{ depositReversalTypeId }
    );
    return !linkedSaleDepositReversalJournalIds.isEmpty();
  }

  @TestVisible
  private static Boolean testVisibleHasDepositCancellation(Order saleOrder, List<Order> returnOrders) {
    return hasDepositCancellation(saleOrder, returnOrders);
  }

  private static Set<Id> getLinkedSaleJournalIdsBySubtypeIds(Order saleOrder, Set<Id> returnOrderIds, Set<Id> journalSubTypeIds) {
    return getLinkedSaleJournalIdsBySubtypeIds(saleOrder, returnOrderIds, journalSubTypeIds, null);
  }

  private static Set<Id> getLinkedSaleJournalIdsBySubtypeIds(
    Order saleOrder,
    Set<Id> returnOrderIds,
    Set<Id> journalSubTypeIds,
    Set<Id> journalTypeIds
  ) {
    Set<Id> journalIds = new Set<Id>();
    if (
      saleOrder == null ||
      saleOrder.Id == null ||
      returnOrderIds == null ||
      returnOrderIds.isEmpty() ||
      journalSubTypeIds == null ||
      journalSubTypeIds.isEmpty()
    ) {
      return journalIds;
    }

    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    Boolean hasSaleIdField = journalFieldMap.containsKey('SaleId__c');
    Boolean hasOrderLinkField = journalFieldMap.containsKey('OrderId__c');
    if (!hasSaleIdField && !hasOrderLinkField) {
      return journalIds;
    }

    Id saleOrderId = saleOrder.Id;
    String linkedQuery = 'SELECT Id ' + 'FROM TransactionJournal ' + 'WHERE OrderId = :saleOrderId ' + 'AND JournalSubTypeId IN :journalSubTypeIds ';

    if (hasSaleIdField && hasOrderLinkField) {
      linkedQuery += 'AND (SaleId__c IN :returnOrderIds OR OrderId__c IN :returnOrderIds)';
    } else if (hasSaleIdField) {
      linkedQuery += 'AND SaleId__c IN :returnOrderIds';
    } else {
      linkedQuery += 'AND OrderId__c IN :returnOrderIds';
    }

    if (journalTypeIds != null && !journalTypeIds.isEmpty()) {
      linkedQuery += ' AND JournalTypeId IN :journalTypeIds';
    }

    for (TransactionJournal linkedJournal : Database.query(linkedQuery)) {
      journalIds.add(linkedJournal.Id);
    }

    Set<Id> fallbackSubtypeIds = new Set<Id>(journalSubTypeIds);
    for (Id restoreSubTypeId : getReturnPointRestoreSubTypeIds()) {
      fallbackSubtypeIds.remove(restoreSubTypeId);
    }

    if (!fallbackSubtypeIds.isEmpty()) {
      String fallbackQuery =
        'SELECT Id ' +
        'FROM TransactionJournal ' +
        'WHERE OrderId = :saleOrderId ' +
        'AND JournalSubTypeId IN :fallbackSubtypeIds ';

      if (hasSaleIdField && hasOrderLinkField) {
        fallbackQuery += 'AND (SaleId__c = NULL OR SaleId__c = :saleOrderId) AND OrderId__c = NULL ';
      } else if (hasSaleIdField) {
        fallbackQuery += 'AND (SaleId__c = NULL OR SaleId__c = :saleOrderId) ';
      } else if (hasOrderLinkField) {
        fallbackQuery += 'AND OrderId__c = NULL ';
      }

      if (journalTypeIds != null && !journalTypeIds.isEmpty()) {
        fallbackQuery += 'AND JournalTypeId IN :journalTypeIds';
      }

      for (TransactionJournal fallbackJournal : Database.query(fallbackQuery)) {
        journalIds.add(fallbackJournal.Id);
      }
    }

    return journalIds;
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

    if (saleOrder != null && saleOrder.Id != null) {
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

  private static PaymentSummary getOriginalSalePaymentSummary(Order saleOrder) {
    if (saleOrder == null || saleOrder.Id == null) {
      return new PaymentSummary();
    }
    return getOriginalSalePaymentSummaryForOrderIds(new Set<Id>{ saleOrder.Id });
  }

  private static PaymentSummary getOriginalSalePaymentSummaryForOrderIds(Set<Id> saleOrderIds) {
    PaymentSummary summary = new PaymentSummary();
    if (saleOrderIds == null || saleOrderIds.isEmpty()) {
      return summary;
    }

    for (TransactionJournal journal : [
      SELECT
        OrderId,
        SaleId__c,
        OrderId__c,
        JournalType.Name,
        JournalSubType.Name,
        TransactionAmount,
        PaymentMethod,
        Status,
        AdditionalNotes__c,
        DepositType__c
      FROM TransactionJournal
      WHERE OrderId IN :saleOrderIds AND TransactionAmount != NULL AND (IsDeleted__c = FALSE OR IsDeleted__c = NULL)
    ]) {
      if (!isOriginalSaleJournalForSet(journal, saleOrderIds)) {
        continue;
      }

      Decimal amount = journal.TransactionAmount == null ? 0 : journal.TransactionAmount.abs();
      if (amount == 0) {
        continue;
      }

      // DepositType__c == '03' (환불) → 결제 종류 무관 차감 (PaymentMethod 별 버킷 + totalAmount 동시 차감)
      if (journal.DepositType__c == '03') {
        applySignedPaymentAmount(summary, journal.PaymentMethod, -amount);
        continue;
      }

      if (
        journal.JournalType != null &&
        journal.JournalType.Name == 'Deposit' &&
        journal.JournalSubType != null &&
        journal.JournalSubType.Name == SALE_DEPOSIT_JOURNAL_SUBTYPE_NAME
      ) {
        applySignedPaymentAmount(summary, journal.PaymentMethod, amount);
        continue;
      }

      if (
        journal.JournalType != null &&
        journal.JournalType.Name == 'Deposit Reversal' &&
        journal.JournalSubType != null &&
        journal.JournalSubType.Name == SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME
      ) {
        applySignedPaymentAmount(summary, journal.PaymentMethod, -amount);
        continue;
      }

      if (
        journal.JournalType != null &&
        journal.JournalType.Name == REDEMPTION_JOURNAL_TYPE_NAME &&
        journal.JournalSubType != null &&
        journal.JournalSubType.Name == COUPON_REDEEM_JOURNAL_SUBTYPE_NAME &&
        isIncludedPaymentStatus(journal.Status) &&
        journal.DepositType__c == '02'
      ) {
        summary.totalAmount += amount;
        summary.couponAmount += amount;
        continue;
      }

      if (
        journal.JournalType != null &&
        journal.JournalType.Name == REDEMPTION_JOURNAL_TYPE_NAME &&
        journal.JournalSubType != null &&
        journal.JournalSubType.Name == POINT_DEBIT_JOURNAL_SUBTYPE_NAME &&
        isIncludedPaymentStatus(journal.Status) &&
        journal.AdditionalNotes__c != RESTORE_POINT_USAGE_ADDITIONAL_NOTES &&
        journal.DepositType__c == '02'
      ) {
        summary.totalAmount += amount;
        summary.pointAmount += amount;
        continue;
      }
    }

    return summary;
  }

  @TestVisible
  private static Decimal testVisibleGetOriginalSalePaymentSummaryAmount(Order saleOrder, String category) {
    PaymentSummary summary = getOriginalSalePaymentSummary(saleOrder);
    if (summary == null) {
      return 0;
    }
    if (category == 'cash') {
      return summary.cashAmount;
    }
    if (category == 'card') {
      return summary.cardAmount;
    }
    if (category == 'coupon') {
      return summary.couponAmount;
    }
    if (category == 'point') {
      return summary.pointAmount;
    }
    return summary.totalAmount;
  }

  private static Boolean isOriginalSaleJournalForSet(TransactionJournal journal, Set<Id> saleOrderIds) {
    if (journal == null || saleOrderIds == null || saleOrderIds.isEmpty()) {
      return false;
    }

    if (journal.OrderId == null || !saleOrderIds.contains(journal.OrderId)) {
      return false;
    }

    // SaleId__c 가 우리 sale 집합 외 다른 sale 을 가리키면 cross-sale 누설 방지로 제외
    if (journal.SaleId__c != null && !saleOrderIds.contains(journal.SaleId__c)) {
      return false;
    }

    return true;
  }

  private static Boolean isOriginalSaleJournal(TransactionJournal journal, Id saleOrderId) {
    if (journal == null || saleOrderId == null || journal.OrderId != saleOrderId) {
      return false;
    }

    Id saleLinkId = journal.SaleId__c;
    Id orderLinkId = journal.OrderId__c;
    Boolean matchesSaleLink = saleLinkId == null || saleLinkId == saleOrderId;
    // 신규 데이터에서는 OrderId__c 가 부모 주문 Id (Sale 과 다름) 를 가리킬 수 있어 별개 케이스로 허용
    Boolean matchesOrderLink = orderLinkId == null || orderLinkId == saleOrderId || orderLinkId != journal.OrderId;
    return matchesSaleLink && matchesOrderLink;
  }

  private static Boolean isIncludedPaymentStatus(String status) {
    return String.isBlank(status) || INCLUDED_PAYMENT_STATUSES.contains(status);
  }

  private static PaymentSummary getCumulativeReturnPaymentSummary(Order saleOrder, List<Order> returnOrders) {
    PaymentSummary summary = new PaymentSummary();
    if (saleOrder == null || saleOrder.Id == null || returnOrders == null || returnOrders.isEmpty()) {
      return summary;
    }

    for (Order returnOrder : returnOrders) {
      if (returnOrder == null || returnOrder.Id == null || returnOrder.IsReductionOrder__c != true) {
        continue;
      }
      PaymentSummary eventSummary = buildReturnEventPaymentSummary(saleOrder, returnOrder);
      accumulateSignedPaymentSummary(summary, eventSummary, 1);
    }

    return summary;
  }

  private static PaymentSummary buildReturnEventPaymentSummary(Order saleOrder, Order returnOrder) {
    PaymentSummary summary = new PaymentSummary();
    if (saleOrder == null || saleOrder.Id == null || returnOrder == null || returnOrder.Id == null) {
      return summary;
    }

    for (TransactionJournal journal : [
      SELECT JournalType.Name, JournalSubType.Name, TransactionAmount, PaymentMethod, Status
      FROM TransactionJournal
      WHERE TransactionAmount != NULL AND (OrderId = :returnOrder.Id OR (OrderId = :saleOrder.Id AND SaleId__c = :returnOrder.Id))
    ]) {
      if (journal.TransactionAmount == null) {
        continue;
      }
      Decimal amount = journal.TransactionAmount.abs();
      if (amount == 0) {
        continue;
      }

      if (
        journal.JournalType != null &&
        journal.JournalType.Name == 'Deposit Reversal' &&
        journal.JournalSubType != null &&
        (journal.JournalSubType.Name == SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME ||
        journal.JournalSubType.Name == ORDER_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME)
      ) {
        applySignedPaymentAmount(summary, journal.PaymentMethod, amount);
        continue;
      }

      if (
        journal.JournalType != null &&
        journal.JournalType.Name == REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME &&
        journal.JournalSubType != null &&
        journal.JournalSubType.Name == COUPON_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME &&
        isIncludedPaymentStatus(journal.Status)
      ) {
        summary.totalAmount += amount;
        summary.couponAmount += amount;
        continue;
      }

      if (
        journal.JournalType != null &&
        journal.JournalType.Name == REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME &&
        journal.JournalSubType != null &&
        journal.JournalSubType.Name == POINT_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME &&
        isIncludedPaymentStatus(journal.Status)
      ) {
        summary.totalAmount += amount;
        summary.pointAmount += amount;
      }
    }

    return summary;
  }

  @TestVisible
  private static Decimal testVisibleGetReturnEventPaymentSummaryAmount(Order saleOrder, Order returnOrder, String category) {
    PaymentSummary summary = buildReturnEventPaymentSummary(saleOrder, returnOrder);
    if (summary == null) {
      return 0;
    }
    if (category == 'cash') {
      return summary.cashAmount;
    }
    if (category == 'card') {
      return summary.cardAmount;
    }
    if (category == 'coupon') {
      return summary.couponAmount;
    }
    if (category == 'point') {
      return summary.pointAmount;
    }
    return summary.totalAmount;
  }

  private static void accumulateSignedPaymentSummary(PaymentSummary target, PaymentSummary source, Decimal sign) {
    if (target == null || source == null || sign == null || sign == 0) {
      return;
    }
    target.totalAmount += source.totalAmount * sign;
    target.cashAmount += source.cashAmount * sign;
    target.cardAmount += source.cardAmount * sign;
    target.couponAmount += source.couponAmount * sign;
    target.pointAmount += source.pointAmount * sign;
    target.deptVoucherAmount += source.deptVoucherAmount * sign;
    target.hqVoucherAmount += source.hqVoucherAmount * sign;
    target.upgradeAmount += source.upgradeAmount * sign;
    target.provisionalAmount += source.provisionalAmount * sign;
  }

  private static void accumulateSalePointAmounts(Set<Id> saleOrderIds, Map<String, PointAmountSummary> amountByType) {
    if (saleOrderIds == null || saleOrderIds.isEmpty()) {
      return;
    }

    Set<Id> saleAccrualSubTypeIds = getJournalSubTypeIdsByName(PURCHASE_ACCRUAL_JOURNAL_SUBTYPE_NAME);
    saleAccrualSubTypeIds.addAll(getJournalSubTypeIdsByName(PROMOTION_POINT_ACCRUAL_JOURNAL_SUBTYPE_NAME));
    saleAccrualSubTypeIds.addAll(getJournalSubTypeIdsByName(API_FORCED_CREDIT_JOURNAL_SUBTYPE_NAME));
    if (saleAccrualSubTypeIds.isEmpty()) {
      return;
    }

    for (LoyaltyLedger ledger : [
      SELECT
        Id,
        Points,
        EventType,
        LoyaltyPgmCrcySubtype.Name,
        LoyaltyPgmCrcySubtype.PointTypeCode__c,
        TransactionJournal.JournalType.Name,
        TransactionJournal.JournalSubTypeId,
        TransactionJournal.AdditionalNotes__c,
        TransactionJournal.Order.IsReductionOrder__c,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.Order.Status
      FROM LoyaltyLedger
      WHERE TransactionJournal.OrderId IN :saleOrderIds AND EventType IN ('Credit', 'Debit')
    ]) {
      Decimal pointAmount = ledger.Points == null ? 0 : ledger.Points;
      if (pointAmount == 0) {
        continue;
      }

      Boolean isAccrualCredit =
        ledger.EventType == 'Credit' &&
        ledger.TransactionJournal != null &&
        ledger.TransactionJournal.JournalType != null &&
        ledger.TransactionJournal.JournalType.Name == ACCRUAL_JOURNAL_TYPE_NAME &&
        saleAccrualSubTypeIds.contains(ledger.TransactionJournal.JournalSubTypeId) &&
        !isReturnRestoredAccrualAdditionalNote(ledger.TransactionJournal.AdditionalNotes__c);

      if (!isAccrualCredit) {
        continue;
      }

      Decimal signedPointAmount = pointAmount.abs();
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

  private static void accumulateReturnPointAmounts(Set<Id> journalIds, Map<String, PointAmountSummary> amountByType) {
    if (journalIds == null || journalIds.isEmpty()) {
      return;
    }
    Set<Id> cancelPurchaseAccrualSubTypeIds = getReturnPointCancelSubTypeIds();
    Set<Id> purchaseAccrualSubTypeIds = getReturnPointRestoreSubTypeIds();

    Set<Id> unresolvedCancelDebitLedgerIds = new Set<Id>();
    for (LoyaltyLedger ledger : [
      SELECT
        Id,
        Points,
        EventType,
        LoyaltyPgmCrcySubtype.Name,
        LoyaltyPgmCrcySubtype.PointTypeCode__c,
        TransactionJournal.JournalSubTypeId,
        TransactionJournal.AdditionalNotes__c
      FROM LoyaltyLedger
      WHERE TransactionJournalId IN :journalIds AND EventType IN ('Credit', 'Debit')
    ]) {
      Decimal rawPointAmount = ledger.Points == null ? 0 : ledger.Points;
      if (rawPointAmount == 0) {
        continue;
      }

      Boolean isRestoredCredit =
        ledger.EventType == 'Credit' &&
        ledger.TransactionJournal != null &&
        !purchaseAccrualSubTypeIds.isEmpty() &&
        purchaseAccrualSubTypeIds.contains(ledger.TransactionJournal.JournalSubTypeId) &&
        isReturnRestoredAccrualAdditionalNote(ledger.TransactionJournal.AdditionalNotes__c);
      Boolean isCancelledAccrualDebit =
        ledger.EventType == 'Debit' &&
        ledger.TransactionJournal != null &&
        !cancelPurchaseAccrualSubTypeIds.isEmpty() &&
        cancelPurchaseAccrualSubTypeIds.contains(ledger.TransactionJournal.JournalSubTypeId);

      if (!isRestoredCredit && !isCancelledAccrualDebit) {
        continue;
      }

      Decimal pointAmount = rawPointAmount.abs();
      Boolean hasPointSubtype =
        ledger.LoyaltyPgmCrcySubtype != null &&
        !String.isBlank(ledger.LoyaltyPgmCrcySubtype.PointTypeCode__c) &&
        !String.isBlank(ledger.LoyaltyPgmCrcySubtype.Name);

      if (isCancelledAccrualDebit && !hasPointSubtype) {
        unresolvedCancelDebitLedgerIds.add(ledger.Id);
        continue;
      }

      addPointAmount(
        amountByType,
        ledger.LoyaltyPgmCrcySubtype != null ? ledger.LoyaltyPgmCrcySubtype.PointTypeCode__c : null,
        ledger.LoyaltyPgmCrcySubtype != null ? ledger.LoyaltyPgmCrcySubtype.Name : null,
        pointAmount
      );
    }

    if (!unresolvedCancelDebitLedgerIds.isEmpty()) {
      for (LoyaltyLedgerTraceability traceability : [
        SELECT
          DebitLoyaltyLedgerId,
          Points,
          CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.Name,
          CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c
        FROM LoyaltyLedgerTraceability
        WHERE DebitLoyaltyLedgerId IN :unresolvedCancelDebitLedgerIds
      ]) {
        Decimal tracedAmount = traceability.Points == null ? 0 : traceability.Points.abs();
        if (tracedAmount <= 0) {
          continue;
        }

        addPointAmount(
          amountByType,
          traceability.CreditLoyaltyLedger != null &&
            traceability.CreditLoyaltyLedger.LoyaltyPgmCrcySubtype != null
            ? traceability.CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c
            : null,
          traceability.CreditLoyaltyLedger != null &&
            traceability.CreditLoyaltyLedger.LoyaltyPgmCrcySubtype != null
            ? traceability.CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.Name
            : null,
          tracedAmount
        );
      }
    }
  }

  private static void accumulateCumulativeReturnPointAmounts(
    Order saleOrder,
    List<Order> returnOrders,
    Map<String, PointAmountSummary> amountByType
  ) {
    if (saleOrder == null || saleOrder.Id == null || returnOrders == null || returnOrders.isEmpty() || amountByType == null) {
      return;
    }

    Set<Id> journalIds = getReturnPointJournalIds(saleOrder, returnOrders);
    if (journalIds.isEmpty()) {
      return;
    }

    accumulateReturnPointAmounts(journalIds, amountByType);
  }

  private static void accumulateReturnOrderPointAmounts(Order saleOrder, Order returnOrder, Map<String, PointAmountSummary> amountByType) {
    if (saleOrder == null || saleOrder.Id == null || returnOrder == null || returnOrder.Id == null || amountByType == null) {
      return;
    }

    Set<Id> journalIds = getReturnPointJournalIds(saleOrder, new List<Order>{ returnOrder });
    if (journalIds.isEmpty()) {
      return;
    }

    accumulateReturnPointAmounts(journalIds, amountByType);
  }

  @TestVisible
  private static Decimal testVisibleAccumulateReturnPointAmounts(Set<Id> journalIds) {
    Map<String, PointAmountSummary> amountByType = new Map<String, PointAmountSummary>();
    accumulateReturnPointAmounts(journalIds, amountByType);
    Decimal totalAmount = 0;
    for (PointAmountSummary pointSummary : amountByType.values()) {
      totalAmount += pointSummary.amount;
    }
    return totalAmount;
  }

  @TestVisible
  private static Decimal testVisibleGetReturnOrderRestoredPointAmount(Order saleOrder, Order returnOrder) {
    Map<String, PointAmountSummary> amountByType = new Map<String, PointAmountSummary>();
    accumulateReturnOrderPointAmounts(saleOrder, returnOrder, amountByType);
    Decimal totalAmount = 0;
    for (PointAmountSummary pointSummary : amountByType.values()) {
      totalAmount += pointSummary.amount;
    }
    return totalAmount;
  }

  private static Boolean isReturnRestoredAccrualAdditionalNote(String additionalNotes) {
    return !String.isBlank(additionalNotes) && RETURN_POINT_RESTORE_ADDITIONAL_NOTES.contains(additionalNotes);
  }

  private static String getPointTypeLabel(String typeCode) {
    for (PointTypeOptionDto option : getPointTypeOptions()) {
      if (option != null && option.type == typeCode) {
        return option.label;
      }
    }
    return typeCode;
  }

  private static void addPointAmount(
    Map<String, PointAmountSummary> amountByType,
    String rawPointTypeCode,
    String rawPointTypeLabel,
    Decimal amount
  ) {
    if (amountByType == null || amount == null || amount == 0) {
      return;
    }

    String pointTypeCode = !String.isBlank(rawPointTypeCode) ? rawPointTypeCode : DEFAULT_POINT_CODE;
    String pointTypeLabel = !String.isBlank(rawPointTypeLabel) ? rawPointTypeLabel : DEFAULT_POINT_LABEL;

    if (!amountByType.containsKey(pointTypeCode)) {
      amountByType.put(pointTypeCode, new PointAmountSummary(pointTypeCode, pointTypeLabel, 0));
    }

    amountByType.get(pointTypeCode).amount += amount;
  }

  private static Id getCancelPurchaseAccrualJournalSubTypeId() {
    if (cancelPurchaseAccrualJournalSubTypeId != null) {
      return cancelPurchaseAccrualJournalSubTypeId;
    }

    List<JournalSubType> subTypes = [
      SELECT Id
      FROM JournalSubType
      WHERE Name = :CANCEL_PURCHASE_ACCRUAL_JOURNAL_SUBTYPE_NAME
      LIMIT 1
    ];

    cancelPurchaseAccrualJournalSubTypeId = subTypes.isEmpty() ? null : subTypes[0].Id;
    return cancelPurchaseAccrualJournalSubTypeId;
  }

  private static Id getJournalSubTypeIdByName(String subTypeName) {
    if (String.isBlank(subTypeName)) {
      return null;
    }

    if (journalSubTypeIdsByName == null) {
      journalSubTypeIdsByName = new Map<String, Id>();
    }

    if (!journalSubTypeIdsByName.containsKey(subTypeName)) {
      List<JournalSubType> subTypes = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :subTypeName
        LIMIT 1
      ];
      journalSubTypeIdsByName.put(subTypeName, subTypes.isEmpty() ? null : subTypes[0].Id);
    }

    return journalSubTypeIdsByName.get(subTypeName);
  }

  private static Set<Id> getJournalSubTypeIdsByName(String subTypeName) {
    if (String.isBlank(subTypeName)) {
      return new Set<Id>();
    }

    if (journalSubTypeIdSetsByName == null) {
      journalSubTypeIdSetsByName = new Map<String, Set<Id>>();
    }

    if (!journalSubTypeIdSetsByName.containsKey(subTypeName)) {
      Set<Id> subTypeIds = new Set<Id>();
      for (JournalSubType subType : [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :subTypeName
      ]) {
        subTypeIds.add(subType.Id);
      }
      journalSubTypeIdSetsByName.put(subTypeName, subTypeIds);
    }

    return journalSubTypeIdSetsByName.get(subTypeName);
  }

  private static Set<Id> getJournalSubTypeIdsByNames(Set<String> subTypeNames) {
    Set<Id> subTypeIds = new Set<Id>();
    if (subTypeNames == null || subTypeNames.isEmpty()) {
      return subTypeIds;
    }

    for (String subTypeName : subTypeNames) {
      subTypeIds.addAll(getJournalSubTypeIdsByName(subTypeName));
    }

    return subTypeIds;
  }

  private static Id getJournalTypeIdByName(String typeName) {
    if (String.isBlank(typeName)) {
      return null;
    }

    if (journalTypeIdsByName == null) {
      journalTypeIdsByName = new Map<String, Id>();
    }

    if (!journalTypeIdsByName.containsKey(typeName)) {
      List<JournalType> types = [
        SELECT Id
        FROM JournalType
        WHERE Name = :typeName
        LIMIT 1
      ];
      journalTypeIdsByName.put(typeName, types.isEmpty() ? null : types[0].Id);
    }

    return journalTypeIdsByName.get(typeName);
  }

  private static Decimal normalizeNegativeAmount(Decimal amount) {
    if (amount == null || amount == 0) {
      return 0;
    }

    return -amount.abs();
  }

  private static Decimal normalizeReturnDisplayAmount(Decimal amount, Boolean showNegative) {
    if (showNegative == true) {
      return normalizeNegativeAmount(amount);
    }
    if (amount == null) {
      return 0;
    }
    // 결제수단별 버킷 / 합계의 실제 부호 보존 — 환불이 입금보다 크면 음수 그대로 표시
    return amount;
  }

  private static void applySignedPaymentAmount(PaymentSummary summary, String paymentMethod, Decimal signedAmount) {
    if (summary == null || signedAmount == null || signedAmount == 0) {
      return;
    }

    String paymentCategory = resolvePaymentCategory(paymentMethod);
    if (paymentCategory == 'OTHER') {
      return;
    }
    summary.totalAmount += signedAmount;
    if (paymentCategory == 'CASH') {
      summary.cashAmount += signedAmount;
    } else if (paymentCategory == 'CARD') {
      summary.cardAmount += signedAmount;
    } else if (paymentCategory == 'COUPON') {
      summary.couponAmount += signedAmount;
    } else if (paymentCategory == 'POINT') {
      summary.pointAmount += signedAmount;
    } else if (paymentCategory == 'DEPT_VOUCHER') {
      summary.deptVoucherAmount += signedAmount;
    } else if (paymentCategory == 'HQ_VOUCHER') {
      summary.hqVoucherAmount += signedAmount;
    } else if (paymentCategory == 'UPGRADE') {
      summary.upgradeAmount += signedAmount;
    } else if (paymentCategory == 'PROVISIONAL') {
      summary.provisionalAmount += signedAmount;
    }
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

  private static PaymentSummary getPaymentSummaryByOrderNumber(
    String fieldName,
    String fieldValue,
    Boolean isReductionOrder,
    Boolean subtractOrderDepositReversal
  ) {
    PaymentSummary summary = new PaymentSummary();

    if (String.isBlank(fieldValue)) {
      return summary;
    }

    Set<Id> linkedOrderIds = new Map<Id, Order>((List<Order>) Database.query('SELECT Id FROM Order WHERE ' + fieldName + ' = :fieldValue')).keySet();

    String query =
      'SELECT PaymentMethod paymentMethod, JournalType.Name journalTypeName, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE (Order.' +
      fieldName +
      ' = :fieldValue ';

    if (!linkedOrderIds.isEmpty()) {
      query += 'OR OrderId__c IN :linkedOrderIds ';
    }

    query +=
      ') ' +
      'AND TransactionAmount != NULL ' +
      'AND PaymentMethod != NULL ' +
      'AND JournalType.Name IN :ORDER_PAYMENT_JOURNAL_TYPE_NAMES ' +
      'AND (JournalSubType.Name = NULL ' +
      'OR JournalSubType.Name = :ORDER_DEPOSIT_JOURNAL_SUBTYPE_NAME ';
    query += 'OR JournalSubType.Name = :SALE_DEPOSIT_JOURNAL_SUBTYPE_NAME ';

    if (subtractOrderDepositReversal == true) {
      query += 'OR JournalSubType.Name = :ORDER_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME ';
      query += 'OR JournalSubType.Name = :SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME ';
    }

    query += ') ';

    if (isReductionOrder != null) {
      query += 'AND Order.IsReductionOrder__c = ' + String.valueOf(isReductionOrder) + ' ';
    }

    query += 'GROUP BY PaymentMethod, JournalType.Name';

    for (AggregateResult ar : Database.query(query)) {
      String paymentMethod = (String) ar.get('paymentMethod');
      Decimal totalAmountValue = (Decimal) ar.get('totalAmount');
      Decimal amount = totalAmountValue == null ? 0 : totalAmountValue;
      Boolean isReversal = (String) ar.get('journalTypeName') == 'Deposit Reversal';
      applySignedPaymentAmount(summary, paymentMethod, isReversal ? -amount.abs() : amount.abs());
    }

    applyCouponRedemptionByOrderNumber(summary, fieldName, fieldValue, isReductionOrder);
    applyPointRedemptionByOrderNumber(summary, fieldName, fieldValue, isReductionOrder);

    return summary;
  }

  private static PaymentSummary getOrderPaymentSummaryByOrderIds(Set<Id> orderIds) {
    PaymentSummary summary = new PaymentSummary();
    if (orderIds == null || orderIds.isEmpty()) {
      return summary;
    }

    for (AggregateResult ar : [
      SELECT PaymentMethod paymentMethod, JournalType.Name journalTypeName, SUM(TransactionAmount) totalAmount
      FROM TransactionJournal
      WHERE
        (OrderId__c IN :orderIds
        OR OrderId IN :orderIds)
        AND TransactionAmount != NULL
        AND PaymentMethod != NULL
        AND JournalType.Name IN :ORDER_PAYMENT_JOURNAL_TYPE_NAMES
        AND (JournalSubType.Name = :ORDER_DEPOSIT_JOURNAL_SUBTYPE_NAME
        OR JournalSubType.Name = :ORDER_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME
        OR JournalSubType.Name = :SALE_DEPOSIT_JOURNAL_SUBTYPE_NAME
        OR JournalSubType.Name = :SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME)
      GROUP BY PaymentMethod, JournalType.Name
    ]) {
      Decimal amount = (Decimal) ar.get('totalAmount');
      Boolean isReversal = (String) ar.get('journalTypeName') == 'Deposit Reversal';
      applySignedPaymentAmount(summary, (String) ar.get('paymentMethod'), isReversal ? -amount.abs() : amount.abs());
    }

    return summary;
  }

  private static PaymentSummary getPaymentSummaryByOrderIds(Set<Id> orderIds, Set<String> journalTypeNames) {
    PaymentSummary summary = new PaymentSummary();
    if (orderIds == null || orderIds.isEmpty() || journalTypeNames == null || journalTypeNames.isEmpty()) {
      return summary;
    }

    for (AggregateResult ar : [
      SELECT PaymentMethod paymentMethod, SUM(TransactionAmount) totalAmount
      FROM TransactionJournal
      WHERE
        (OrderId__c IN :orderIds
        OR OrderId IN :orderIds)
        AND TransactionAmount != NULL
        AND PaymentMethod != NULL
        AND JournalType.Name IN :journalTypeNames
      GROUP BY PaymentMethod
    ]) {
      String paymentMethod = (String) ar.get('paymentMethod');
      Decimal totalAmountValue = (Decimal) ar.get('totalAmount');
      Decimal amount = totalAmountValue == null ? 0 : totalAmountValue;
      applySignedPaymentAmount(summary, paymentMethod, amount);
    }

    applyCouponRedemptionByOrderIds(summary, orderIds, 'OrderId__c');

    return summary;
  }

  private static PaymentSummary getSalePaymentSummaryByOrderIds(Set<Id> orderIds) {
    PaymentSummary summary = new PaymentSummary();
    if (orderIds == null || orderIds.isEmpty()) {
      return summary;
    }

    Id saleDepositSubTypeId = getJournalSubTypeIdByName(SALE_DEPOSIT_JOURNAL_SUBTYPE_NAME);
    Id saleDepositReversalSubTypeId = getJournalSubTypeIdByName(SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME);
    if (saleDepositSubTypeId == null && saleDepositReversalSubTypeId == null) {
      applyCouponRedemptionByOrderIds(summary, orderIds, 'SaleId__c');
      return summary;
    }

    for (AggregateResult ar : [
      SELECT PaymentMethod paymentMethod, JournalType.Name journalTypeName, SUM(TransactionAmount) totalAmount
      FROM TransactionJournal
      WHERE
        (SaleId__c IN :orderIds
        OR OrderId IN :orderIds)
        AND Order.IsReductionOrder__c = FALSE
        AND TransactionAmount != NULL
        AND (IsDeleted__c = FALSE
        OR IsDeleted__c = NULL)
        AND PaymentMethod != NULL
        AND ((JournalType.Name = 'Deposit'
        AND JournalSubTypeId = :saleDepositSubTypeId)
        OR (JournalType.Name = 'Deposit Reversal'
        AND JournalSubTypeId = :saleDepositReversalSubTypeId))
      GROUP BY PaymentMethod, JournalType.Name
    ]) {
      Decimal amount = (Decimal) ar.get('totalAmount');
      Boolean isReversal = (String) ar.get('journalTypeName') == 'Deposit Reversal';
      applySignedPaymentAmount(summary, (String) ar.get('paymentMethod'), isReversal ? -amount.abs() : amount.abs());
    }

    applyCouponRedemptionByOrderIds(summary, orderIds, 'SaleId__c');
    applyPointRedemptionByOrderIds(summary, orderIds, 'SaleId__c');
    return summary;
  }

  @TestVisible
  private static Decimal testVisibleGetSalePaymentSummaryByOrderIdsAmount(Set<Id> orderIds, String category) {
    PaymentSummary summary = getSalePaymentSummaryByOrderIds(orderIds);
    if (summary == null) {
      return 0;
    }
    if (category == 'cash') {
      return summary.cashAmount;
    }
    if (category == 'card') {
      return summary.cardAmount;
    }
    if (category == 'coupon') {
      return summary.couponAmount;
    }
    if (category == 'point') {
      return summary.pointAmount;
    }
    return summary.totalAmount;
  }

  private static PaymentSummary getReturnPaymentSummaryByOrderIds(Order saleOrder, Set<Id> orderIds) {
    PaymentSummary summary = new PaymentSummary();
    if (orderIds == null || orderIds.isEmpty()) {
      return summary;
    }

    Id saleDepositReversalSubTypeId = getJournalSubTypeIdByName(SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME);
    Id depositReversalTypeId = getJournalTypeIdByName('Deposit Reversal');
    if (saleDepositReversalSubTypeId != null && depositReversalTypeId != null) {
      for (AggregateResult ar : [
        SELECT PaymentMethod paymentMethod, SUM(TransactionAmount) totalAmount
        FROM TransactionJournal
        WHERE
          OrderId IN :orderIds
          AND Order.IsReductionOrder__c = TRUE
          AND Order.SaleNo__c != NULL
          AND TransactionAmount != NULL
          AND PaymentMethod != NULL
          AND JournalTypeId = :depositReversalTypeId
          AND JournalSubTypeId = :saleDepositReversalSubTypeId
        GROUP BY PaymentMethod
      ]) {
        Decimal amount = (Decimal) ar.get('totalAmount');
        applySignedPaymentAmount(summary, (String) ar.get('paymentMethod'), amount == null ? 0 : amount.abs());
      }

      Set<Id> linkedSaleDepositReversalJournalIds = getLinkedSaleJournalIdsBySubtypeIds(
        saleOrder,
        orderIds,
        new Set<Id>{ saleDepositReversalSubTypeId },
        new Set<Id>{ depositReversalTypeId }
      );
      if (!linkedSaleDepositReversalJournalIds.isEmpty()) {
        for (AggregateResult ar : [
          SELECT PaymentMethod paymentMethod, SUM(TransactionAmount) totalAmount
          FROM TransactionJournal
          WHERE Id IN :linkedSaleDepositReversalJournalIds AND TransactionAmount != NULL AND PaymentMethod != NULL
          GROUP BY PaymentMethod
        ]) {
          Decimal amount = (Decimal) ar.get('totalAmount');
          applySignedPaymentAmount(summary, (String) ar.get('paymentMethod'), amount == null ? 0 : amount.abs());
        }
      }
    }

    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);
    Id couponRedeemCancelSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Id pointRedeemCancelSubTypeId = getJournalSubTypeIdByName(POINT_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);

    if (redemptionReversalTypeId != null && couponRedeemCancelSubTypeId != null) {
      for (AggregateResult ar : [
        SELECT JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount
        FROM TransactionJournal
        WHERE
          OrderId IN :orderIds
          AND TransactionAmount != NULL
          AND JournalTypeId = :redemptionReversalTypeId
          AND JournalSubTypeId = :couponRedeemCancelSubTypeId
          AND (Status = NULL
          OR Status IN :INCLUDED_PAYMENT_STATUSES)
        GROUP BY JournalTypeId, JournalSubTypeId
      ]) {
        applyReturnCouponOrPointCancelAmount(summary, (Id) ar.get('journalTypeId'), (Id) ar.get('journalSubTypeId'), (Decimal) ar.get('totalAmount'));
      }
    }

    if (redemptionReversalTypeId != null && pointRedeemCancelSubTypeId != null) {
      for (AggregateResult ar : [
        SELECT JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount
        FROM TransactionJournal
        WHERE
          OrderId IN :orderIds
          AND TransactionAmount != NULL
          AND JournalTypeId = :redemptionReversalTypeId
          AND JournalSubTypeId = :pointRedeemCancelSubTypeId
          AND (Status = NULL
          OR Status IN :INCLUDED_PAYMENT_STATUSES)
        GROUP BY JournalTypeId, JournalSubTypeId
      ]) {
        applyReturnCouponOrPointCancelAmount(summary, (Id) ar.get('journalTypeId'), (Id) ar.get('journalSubTypeId'), (Decimal) ar.get('totalAmount'));
      }
    }

    if (redemptionReversalTypeId != null && couponRedeemCancelSubTypeId != null) {
      Set<Id> linkedCouponCancelJournalIds = getLinkedSaleJournalIdsBySubtypeIds(
        saleOrder,
        orderIds,
        new Set<Id>{ couponRedeemCancelSubTypeId },
        new Set<Id>{ redemptionReversalTypeId }
      );
      if (!linkedCouponCancelJournalIds.isEmpty()) {
        for (AggregateResult ar : [
          SELECT JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount
          FROM TransactionJournal
          WHERE Id IN :linkedCouponCancelJournalIds AND TransactionAmount != NULL
          GROUP BY JournalTypeId, JournalSubTypeId
        ]) {
          applyReturnCouponOrPointCancelAmount(
            summary,
            (Id) ar.get('journalTypeId'),
            (Id) ar.get('journalSubTypeId'),
            (Decimal) ar.get('totalAmount')
          );
        }
      }
    }

    if (redemptionReversalTypeId != null && pointRedeemCancelSubTypeId != null) {
      Set<Id> linkedPointCancelJournalIds = getLinkedSaleJournalIdsBySubtypeIds(
        saleOrder,
        orderIds,
        new Set<Id>{ pointRedeemCancelSubTypeId },
        new Set<Id>{ redemptionReversalTypeId }
      );
      if (!linkedPointCancelJournalIds.isEmpty()) {
        for (AggregateResult ar : [
          SELECT JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount
          FROM TransactionJournal
          WHERE Id IN :linkedPointCancelJournalIds AND TransactionAmount != NULL
          GROUP BY JournalTypeId, JournalSubTypeId
        ]) {
          applyReturnCouponOrPointCancelAmount(
            summary,
            (Id) ar.get('journalTypeId'),
            (Id) ar.get('journalSubTypeId'),
            (Decimal) ar.get('totalAmount')
          );
        }
      }
    }

    return summary;
  }

  @TestVisible
  private static Decimal testVisibleGetReturnPaymentSummaryByOrderIdsAmount(Order saleOrder, Set<Id> orderIds, String category) {
    PaymentSummary summary = getReturnPaymentSummaryByOrderIds(saleOrder, orderIds);
    if (summary == null) {
      return 0;
    }
    if (category == 'cash') {
      return summary.cashAmount;
    }
    if (category == 'card') {
      return summary.cardAmount;
    }
    if (category == 'coupon') {
      return summary.couponAmount;
    }
    if (category == 'point') {
      return summary.pointAmount;
    }
    return summary.totalAmount;
  }

  private static Map<String, PaymentSummary> getSalePaymentSummariesBySaleNumbers(List<Order> saleOrders) {
    Map<String, PaymentSummary> summaryBySaleNo = new Map<String, PaymentSummary>();
    Set<String> saleNumbers = new Set<String>();
    Set<Id> saleOrderIds = new Set<Id>();

    if (saleOrders != null) {
      for (Order saleOrder : saleOrders) {
        if (!String.isBlank(saleOrder.SaleNo__c)) {
          saleNumbers.add(saleOrder.SaleNo__c);
          summaryBySaleNo.put(saleOrder.SaleNo__c, new PaymentSummary());
        }
        if (saleOrder != null && saleOrder.Id != null) {
          saleOrderIds.add(saleOrder.Id);
        }
      }
    }

    if (saleNumbers.isEmpty()) {
      return summaryBySaleNo;
    }

    Id saleDepositSubTypeId = getJournalSubTypeIdByName(SALE_DEPOSIT_JOURNAL_SUBTYPE_NAME);
    Id saleDepositReversalSubTypeId = getJournalSubTypeIdByName(SALE_DEPOSIT_REVERSAL_JOURNAL_SUBTYPE_NAME);
    if (saleDepositSubTypeId == null && saleDepositReversalSubTypeId == null) {
      applyCouponRedemptionBySaleNumbers(summaryBySaleNo, saleNumbers, saleOrderIds);
      return summaryBySaleNo;
    }

    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    Boolean hasSaleIdField = journalFieldMap.containsKey('SaleId__c');
    String salePaymentBySaleNoQuery =
      'SELECT Order.SaleNo__c saleNo, PaymentMethod paymentMethod, JournalType.Name journalTypeName, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE Order.SaleNo__c IN :saleNumbers ' +
      'AND Order.IsReductionOrder__c = FALSE ' +
      'AND TransactionAmount != NULL ' +
      'AND (IsDeleted__c = FALSE OR IsDeleted__c = NULL) ' +
      'AND PaymentMethod != NULL ' +
      'AND ((JournalType.Name = \'Deposit\' AND JournalSubTypeId = :saleDepositSubTypeId) ' +
      'OR (JournalType.Name = \'Deposit Reversal\' AND JournalSubTypeId = :saleDepositReversalSubTypeId)) ';

    if (hasSaleIdField) {
      salePaymentBySaleNoQuery += 'AND (SaleId__c = NULL OR SaleId__c IN :saleOrderIds) ';
    }

    salePaymentBySaleNoQuery += 'GROUP BY Order.SaleNo__c, PaymentMethod, JournalType.Name';

    for (AggregateResult ar : Database.query(salePaymentBySaleNoQuery)) {
      String saleNo = (String) ar.get('saleNo');
      if (!summaryBySaleNo.containsKey(saleNo)) {
        summaryBySaleNo.put(saleNo, new PaymentSummary());
      }

      Decimal amount = (Decimal) ar.get('totalAmount');
      Boolean isReversal = (String) ar.get('journalTypeName') == 'Deposit Reversal';
      applySignedPaymentAmount(summaryBySaleNo.get(saleNo), (String) ar.get('paymentMethod'), isReversal ? -amount.abs() : amount.abs());
    }

    applyCouponRedemptionBySaleNumbers(summaryBySaleNo, saleNumbers, saleOrderIds);
    applyPointRedemptionBySaleNumbers(summaryBySaleNo, saleNumbers, saleOrderIds);
    return summaryBySaleNo;
  }

  private static void applyCouponRedemptionByOrderNumber(PaymentSummary summary, String fieldName, String fieldValue, Boolean isReductionOrder) {
    if (summary == null || String.isBlank(fieldValue)) {
      return;
    }

    Id redemptionTypeId = getJournalTypeIdByName(REDEMPTION_JOURNAL_TYPE_NAME);
    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);
    Id couponRedeemSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_JOURNAL_SUBTYPE_NAME);
    Id couponRedeemCancelSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    if ((redemptionTypeId == null && redemptionReversalTypeId == null) || (couponRedeemSubTypeId == null && couponRedeemCancelSubTypeId == null)) {
      return;
    }

    String query =
      'SELECT JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE Order.' +
      fieldName +
      ' = :fieldValue ' +
      'AND TransactionAmount != NULL ' +
      'AND JournalTypeId IN :couponJournalTypeIds ' +
      'AND JournalSubTypeId IN :couponJournalSubTypeIds ' +
      'AND (Status = NULL OR Status IN :INCLUDED_PAYMENT_STATUSES) ';

    Set<Id> couponJournalTypeIds = new Set<Id>();
    if (redemptionTypeId != null) {
      couponJournalTypeIds.add(redemptionTypeId);
    }
    if (redemptionReversalTypeId != null) {
      couponJournalTypeIds.add(redemptionReversalTypeId);
    }

    Set<Id> couponJournalSubTypeIds = new Set<Id>();
    if (couponRedeemSubTypeId != null) {
      couponJournalSubTypeIds.add(couponRedeemSubTypeId);
    }
    if (couponRedeemCancelSubTypeId != null) {
      couponJournalSubTypeIds.add(couponRedeemCancelSubTypeId);
    }

    if (isReductionOrder != null) {
      query += 'AND Order.IsReductionOrder__c = ' + String.valueOf(isReductionOrder) + ' ';
    }

    query += 'GROUP BY JournalTypeId, JournalSubTypeId';

    for (AggregateResult ar : Database.query(query)) {
      applyCouponRedemptionAmount(summary, (Id) ar.get('journalTypeId'), (Id) ar.get('journalSubTypeId'), (Decimal) ar.get('totalAmount'));
    }
  }

  private static Set<Id> getOrdersWithSaleConnection(Set<Id> orderIds) {
    Set<Id> result = new Set<Id>();
    if (orderIds == null || orderIds.isEmpty()) {
      return result;
    }
    for (AggregateResult ar : [
      SELECT OrderId__c oid
      FROM TransactionJournal
      WHERE OrderId__c IN :orderIds AND SaleId__c != NULL
      GROUP BY OrderId__c
    ]) {
      Object oidVal = ar.get('oid');
      if (oidVal == null) {
        continue;
      }
      String oidStr = String.valueOf(oidVal);
      if (String.isBlank(oidStr)) {
        continue;
      }
      result.add((Id) oidStr);
    }
    return result;
  }

  private static void applyCouponRedemptionByOrderIds(PaymentSummary summary, Set<Id> orderIds, String idField) {
    if (summary == null || orderIds == null || orderIds.isEmpty() || String.isBlank(idField)) {
      return;
    }

    Id redemptionTypeId = getJournalTypeIdByName(REDEMPTION_JOURNAL_TYPE_NAME);
    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);
    Id couponRedeemSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_JOURNAL_SUBTYPE_NAME);
    Id couponRedeemCancelSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Set<Id> couponJournalTypeIds = new Set<Id>();
    Set<Id> couponJournalSubTypeIds = new Set<Id>();
    if (redemptionTypeId != null)
      couponJournalTypeIds.add(redemptionTypeId);
    if (redemptionReversalTypeId != null)
      couponJournalTypeIds.add(redemptionReversalTypeId);
    if (couponRedeemSubTypeId != null)
      couponJournalSubTypeIds.add(couponRedeemSubTypeId);
    if (couponRedeemCancelSubTypeId != null)
      couponJournalSubTypeIds.add(couponRedeemCancelSubTypeId);
    if (couponJournalTypeIds.isEmpty() || couponJournalSubTypeIds.isEmpty()) {
      return;
    }

    Set<Id> ordersWithSaleConnection = idField == 'OrderId__c' ? getOrdersWithSaleConnection(orderIds) : new Set<Id>();

    String query =
      'SELECT JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE (' +
      idField +
      ' IN :orderIds OR OrderId IN :orderIds) ' +
      'AND TransactionAmount != NULL ' +
      'AND JournalTypeId IN :couponJournalTypeIds ' +
      'AND JournalSubTypeId IN :couponJournalSubTypeIds ' +
      'AND (Status = NULL OR Status IN :INCLUDED_PAYMENT_STATUSES) ';

    if (idField == 'SaleId__c' && Schema.sObjectType.TransactionJournal.fields.getMap().containsKey('SaleId__c')) {
      query += 'AND (SaleId__c = NULL OR SaleId__c IN :orderIds) ';
    }

    if (idField == 'OrderId__c' && !ordersWithSaleConnection.isEmpty()) {
      query += 'AND (OrderId__c NOT IN :ordersWithSaleConnection OR SaleId__c != NULL) ';
    }

    query += 'GROUP BY JournalTypeId, JournalSubTypeId';

    for (AggregateResult ar : Database.query(query)) {
      applyCouponRedemptionAmount(summary, (Id) ar.get('journalTypeId'), (Id) ar.get('journalSubTypeId'), (Decimal) ar.get('totalAmount'));
    }
  }

  private static void applyCouponRedemptionBySaleNumbers(Map<String, PaymentSummary> summaryBySaleNo, Set<String> saleNumbers, Set<Id> saleOrderIds) {
    if (summaryBySaleNo == null || summaryBySaleNo.isEmpty() || saleNumbers == null || saleNumbers.isEmpty()) {
      return;
    }

    Id redemptionTypeId = getJournalTypeIdByName(REDEMPTION_JOURNAL_TYPE_NAME);
    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);
    Id couponRedeemSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_JOURNAL_SUBTYPE_NAME);
    Id couponRedeemCancelSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Set<Id> couponJournalTypeIds = new Set<Id>();
    Set<Id> couponJournalSubTypeIds = new Set<Id>();
    if (redemptionTypeId != null)
      couponJournalTypeIds.add(redemptionTypeId);
    if (redemptionReversalTypeId != null)
      couponJournalTypeIds.add(redemptionReversalTypeId);
    if (couponRedeemSubTypeId != null)
      couponJournalSubTypeIds.add(couponRedeemSubTypeId);
    if (couponRedeemCancelSubTypeId != null)
      couponJournalSubTypeIds.add(couponRedeemCancelSubTypeId);
    if (couponJournalTypeIds.isEmpty() || couponJournalSubTypeIds.isEmpty()) {
      return;
    }

    String query =
      'SELECT Order.SaleNo__c saleNo, JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE Order.SaleNo__c IN :saleNumbers ' +
      'AND Order.IsReductionOrder__c = FALSE ' +
      'AND TransactionAmount != NULL ' +
      'AND JournalTypeId IN :couponJournalTypeIds ' +
      'AND JournalSubTypeId IN :couponJournalSubTypeIds ' +
      'AND (Status = NULL OR Status IN :INCLUDED_PAYMENT_STATUSES) ';

    if (saleOrderIds != null && !saleOrderIds.isEmpty() && Schema.sObjectType.TransactionJournal.fields.getMap().containsKey('SaleId__c')) {
      query += 'AND (SaleId__c = NULL OR SaleId__c IN :saleOrderIds) ';
    }

    query += 'GROUP BY Order.SaleNo__c, JournalTypeId, JournalSubTypeId';

    for (AggregateResult ar : Database.query(query)) {
      String saleNo = (String) ar.get('saleNo');
      if (!summaryBySaleNo.containsKey(saleNo)) {
        summaryBySaleNo.put(saleNo, new PaymentSummary());
      }
      applyCouponRedemptionAmount(
        summaryBySaleNo.get(saleNo),
        (Id) ar.get('journalTypeId'),
        (Id) ar.get('journalSubTypeId'),
        (Decimal) ar.get('totalAmount')
      );
    }
  }

  private static void applyPointRedemptionByOrderNumber(PaymentSummary summary, String fieldName, String fieldValue, Boolean isReductionOrder) {
    if (summary == null || String.isBlank(fieldValue)) {
      return;
    }

    Id pointDebitSubTypeId = getJournalSubTypeIdByName(POINT_DEBIT_JOURNAL_SUBTYPE_NAME);
    Id pointRedeemCancelSubTypeId = getJournalSubTypeIdByName(POINT_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Id redemptionTypeId = getJournalTypeIdByName(REDEMPTION_JOURNAL_TYPE_NAME);
    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);

    Set<Id> pointJournalTypeIds = new Set<Id>();
    if (redemptionTypeId != null) {
      pointJournalTypeIds.add(redemptionTypeId);
    }
    if (redemptionReversalTypeId != null) {
      pointJournalTypeIds.add(redemptionReversalTypeId);
    }

    Set<Id> pointJournalSubTypeIds = new Set<Id>();
    if (pointDebitSubTypeId != null) {
      pointJournalSubTypeIds.add(pointDebitSubTypeId);
    }
    if (pointRedeemCancelSubTypeId != null) {
      pointJournalSubTypeIds.add(pointRedeemCancelSubTypeId);
    }

    if (pointJournalTypeIds.isEmpty() || pointJournalSubTypeIds.isEmpty()) {
      return;
    }

    String query =
      'SELECT JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE Order.' +
      fieldName +
      ' = :fieldValue ' +
      'AND TransactionAmount != NULL ' +
      'AND JournalTypeId IN :pointJournalTypeIds ' +
      'AND JournalSubTypeId IN :pointJournalSubTypeIds ' +
      'AND (AdditionalNotes__c = NULL OR AdditionalNotes__c != :RESTORE_POINT_USAGE_ADDITIONAL_NOTES) ' +
      'AND (Status = NULL OR Status IN :INCLUDED_PAYMENT_STATUSES) ';

    if (isReductionOrder != null) {
      query += 'AND Order.IsReductionOrder__c = ' + String.valueOf(isReductionOrder) + ' ';
    }

    query += 'GROUP BY JournalTypeId, JournalSubTypeId';

    for (AggregateResult ar : Database.query(query)) {
      applyPointRedemptionAmount(summary, (Id) ar.get('journalTypeId'), (Id) ar.get('journalSubTypeId'), (Decimal) ar.get('totalAmount'));
    }
  }

  private static void applyPointRedemptionByOrderIds(PaymentSummary summary, Set<Id> orderIds, String idField) {
    if (summary == null || orderIds == null || orderIds.isEmpty() || String.isBlank(idField)) {
      return;
    }

    Id pointDebitSubTypeId = getJournalSubTypeIdByName(POINT_DEBIT_JOURNAL_SUBTYPE_NAME);
    Id pointRedeemCancelSubTypeId = getJournalSubTypeIdByName(POINT_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Id redemptionTypeId = getJournalTypeIdByName(REDEMPTION_JOURNAL_TYPE_NAME);
    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);

    Set<Id> pointJournalTypeIds = new Set<Id>();
    if (redemptionTypeId != null) {
      pointJournalTypeIds.add(redemptionTypeId);
    }
    if (redemptionReversalTypeId != null) {
      pointJournalTypeIds.add(redemptionReversalTypeId);
    }

    Set<Id> pointJournalSubTypeIds = new Set<Id>();
    if (pointDebitSubTypeId != null) {
      pointJournalSubTypeIds.add(pointDebitSubTypeId);
    }
    if (pointRedeemCancelSubTypeId != null) {
      pointJournalSubTypeIds.add(pointRedeemCancelSubTypeId);
    }

    if (pointJournalTypeIds.isEmpty() || pointJournalSubTypeIds.isEmpty()) {
      return;
    }

    Set<Id> ordersWithSaleConnection = idField == 'OrderId__c' ? getOrdersWithSaleConnection(orderIds) : new Set<Id>();

    String restoreNote = RESTORE_POINT_USAGE_ADDITIONAL_NOTES;
    String query =
      'SELECT JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE (' +
      idField +
      ' IN :orderIds OR OrderId IN :orderIds) ' +
      'AND TransactionAmount != NULL ' +
      'AND JournalTypeId IN :pointJournalTypeIds ' +
      'AND JournalSubTypeId IN :pointJournalSubTypeIds ' +
      'AND (AdditionalNotes__c = NULL OR AdditionalNotes__c != :restoreNote) ' +
      'AND (Status = NULL OR Status IN :INCLUDED_PAYMENT_STATUSES) ';

    if (idField == 'SaleId__c' && Schema.sObjectType.TransactionJournal.fields.getMap().containsKey('SaleId__c')) {
      query += 'AND (SaleId__c = NULL OR SaleId__c IN :orderIds) ';
    }

    if (idField == 'OrderId__c' && !ordersWithSaleConnection.isEmpty()) {
      query += 'AND (OrderId__c NOT IN :ordersWithSaleConnection OR SaleId__c != NULL) ';
    }

    query += 'GROUP BY JournalTypeId, JournalSubTypeId';

    for (AggregateResult ar : Database.query(query)) {
      applyPointRedemptionAmount(summary, (Id) ar.get('journalTypeId'), (Id) ar.get('journalSubTypeId'), (Decimal) ar.get('totalAmount'));
    }
  }

  private static void applyPointRedemptionBySaleNumbers(Map<String, PaymentSummary> summaryBySaleNo, Set<String> saleNumbers, Set<Id> saleOrderIds) {
    if (summaryBySaleNo == null || summaryBySaleNo.isEmpty() || saleNumbers == null || saleNumbers.isEmpty()) {
      return;
    }

    Id pointDebitSubTypeId = getJournalSubTypeIdByName(POINT_DEBIT_JOURNAL_SUBTYPE_NAME);
    Id pointRedeemCancelSubTypeId = getJournalSubTypeIdByName(POINT_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Id redemptionTypeId = getJournalTypeIdByName(REDEMPTION_JOURNAL_TYPE_NAME);
    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);

    Set<Id> pointJournalTypeIds = new Set<Id>();
    if (redemptionTypeId != null) {
      pointJournalTypeIds.add(redemptionTypeId);
    }
    if (redemptionReversalTypeId != null) {
      pointJournalTypeIds.add(redemptionReversalTypeId);
    }

    Set<Id> pointJournalSubTypeIds = new Set<Id>();
    if (pointDebitSubTypeId != null) {
      pointJournalSubTypeIds.add(pointDebitSubTypeId);
    }
    if (pointRedeemCancelSubTypeId != null) {
      pointJournalSubTypeIds.add(pointRedeemCancelSubTypeId);
    }

    if (pointJournalTypeIds.isEmpty() || pointJournalSubTypeIds.isEmpty()) {
      return;
    }

    String restoreNote = RESTORE_POINT_USAGE_ADDITIONAL_NOTES;
    String query =
      'SELECT Order.SaleNo__c saleNo, JournalTypeId journalTypeId, JournalSubTypeId journalSubTypeId, SUM(TransactionAmount) totalAmount ' +
      'FROM TransactionJournal ' +
      'WHERE Order.SaleNo__c IN :saleNumbers ' +
      'AND Order.IsReductionOrder__c = FALSE ' +
      'AND TransactionAmount != NULL ' +
      'AND JournalTypeId IN :pointJournalTypeIds ' +
      'AND JournalSubTypeId IN :pointJournalSubTypeIds ' +
      'AND (AdditionalNotes__c = NULL OR AdditionalNotes__c != :restoreNote) ' +
      'AND (Status = NULL OR Status IN :INCLUDED_PAYMENT_STATUSES) ';

    if (saleOrderIds != null && !saleOrderIds.isEmpty() && Schema.sObjectType.TransactionJournal.fields.getMap().containsKey('SaleId__c')) {
      query += 'AND (SaleId__c = NULL OR SaleId__c IN :saleOrderIds) ';
    }

    query += 'GROUP BY Order.SaleNo__c, JournalTypeId, JournalSubTypeId';

    for (AggregateResult ar : Database.query(query)) {
      String saleNo = (String) ar.get('saleNo');
      if (!summaryBySaleNo.containsKey(saleNo)) {
        summaryBySaleNo.put(saleNo, new PaymentSummary());
      }
      applyPointRedemptionAmount(
        summaryBySaleNo.get(saleNo),
        (Id) ar.get('journalTypeId'),
        (Id) ar.get('journalSubTypeId'),
        (Decimal) ar.get('totalAmount')
      );
    }
  }

  private static void applyCouponRedemptionAmount(PaymentSummary summary, Id journalTypeId, Id journalSubTypeId, Decimal amount) {
    if (summary == null || amount == null || amount == 0) {
      return;
    }

    Id redemptionTypeId = getJournalTypeIdByName(REDEMPTION_JOURNAL_TYPE_NAME);
    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);
    Id couponRedeemSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_JOURNAL_SUBTYPE_NAME);
    Id couponRedeemCancelSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Boolean isCouponRedeem = journalTypeId == redemptionTypeId && journalSubTypeId == couponRedeemSubTypeId;
    Boolean isCouponRedeemCancel = journalTypeId == redemptionReversalTypeId && journalSubTypeId == couponRedeemCancelSubTypeId;

    if (!isCouponRedeem && !isCouponRedeemCancel) {
      return;
    }

    Decimal signedAmount = isCouponRedeemCancel ? -amount.abs() : amount.abs();
    summary.totalAmount += signedAmount;
    summary.couponAmount += signedAmount;
  }

  private static void applyPointRedemptionAmount(PaymentSummary summary, Id journalTypeId, Id journalSubTypeId, Decimal amount) {
    if (summary == null || amount == null || amount == 0) {
      return;
    }

    Id redemptionTypeId = getJournalTypeIdByName(REDEMPTION_JOURNAL_TYPE_NAME);
    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);
    Id pointDebitSubTypeId = getJournalSubTypeIdByName(POINT_DEBIT_JOURNAL_SUBTYPE_NAME);
    Id pointRedeemCancelSubTypeId = getJournalSubTypeIdByName(POINT_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Boolean isPointDebit = journalTypeId == redemptionTypeId && journalSubTypeId == pointDebitSubTypeId;
    Boolean isPointRedeemCancel = journalTypeId == redemptionReversalTypeId && journalSubTypeId == pointRedeemCancelSubTypeId;

    if (!isPointDebit && !isPointRedeemCancel) {
      return;
    }

    Decimal signedAmount = isPointRedeemCancel ? -amount.abs() : amount.abs();
    summary.totalAmount += signedAmount;
    summary.pointAmount += signedAmount;
  }

  private static void applyReturnCouponOrPointCancelAmount(PaymentSummary summary, Id journalTypeId, Id journalSubTypeId, Decimal amount) {
    if (summary == null || amount == null || amount == 0) {
      return;
    }

    Id redemptionReversalTypeId = getJournalTypeIdByName(REDEMPTION_REVERSAL_JOURNAL_TYPE_NAME);
    Id couponRedeemCancelSubTypeId = getJournalSubTypeIdByName(COUPON_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Id pointRedeemCancelSubTypeId = getJournalSubTypeIdByName(POINT_REDEEM_CANCEL_JOURNAL_SUBTYPE_NAME);
    Decimal normalizedAmount = amount.abs();

    if (journalTypeId == redemptionReversalTypeId && journalSubTypeId == couponRedeemCancelSubTypeId) {
      summary.totalAmount += normalizedAmount;
      summary.couponAmount += normalizedAmount;
      return;
    }

    if (journalTypeId == redemptionReversalTypeId && journalSubTypeId == pointRedeemCancelSubTypeId) {
      summary.totalAmount += normalizedAmount;
      summary.pointAmount += normalizedAmount;
    }
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

  private static Boolean isCancelledOrDeletedOrder(Order orderRecord) {
    if (orderRecord == null) {
      return false;
    }

    if (getQueriedBooleanValue(orderRecord, 'IsDeleted__c') == true) {
      return true;
    }

    Object deleteDateTimeValue = getQueriedValue(orderRecord, 'DeleteDateTime__c');
    if (deleteDateTimeValue != null) {
      return true;
    }

    return false;
  }

  private static Boolean isReturnOrderForSummary(Order orderRecord) {
    return orderRecord != null &&
      orderRecord.IsReductionOrder__c == true &&
      !String.isBlank(orderRecord.SaleNo__c) &&
      !isSaleDeletedOrderStatus(orderRecord);
  }

  private static Boolean isCompletedSaleOrderStatus(Order orderRecord) {
    if (orderRecord == null || String.isBlank(orderRecord.SaleNo__c) || isSaleDeletedOrderStatus(orderRecord)) {
      return false;
    }

    return isSaleSuccessStatusValue(normalizeStatusValue(orderRecord.Status));
  }

  private static Boolean isCompletedReturnOrderStatus(Order orderRecord) {
    if (orderRecord == null || String.isBlank(orderRecord.SaleNo__c) || isSaleDeletedOrderStatus(orderRecord)) {
      return false;
    }

    return normalizeStatusValue(orderRecord.Status) == RETURN_SUCCESS_STATUS_VALUE;
  }

  private static Boolean isSaleDeletedOrderStatus(Order orderRecord) {
    if (orderRecord == null) {
      return false;
    }

    if (isCancelledOrDeletedOrder(orderRecord)) {
      return true;
    }

    return DEFINED_DELETED_STATUS_VALUES.contains(normalizeStatusValue(orderRecord.Status));
  }

  private static String normalizeStatusValue(String statusValue) {
    return String.isBlank(statusValue) ? '' : statusValue.trim().toLowerCase();
  }

  private static String resolveStageProgressStateByStatusValue(String statusValue, Boolean hasData) {
    String normalizedStatusValue = normalizeStatusValue(statusValue);
    if (String.isBlank(normalizedStatusValue)) {
      return hasData ? PROGRESS_STATE_COMPLETED : PROGRESS_STATE_NOT_STARTED;
    }

    if (isSaleSuccessStatusValue(normalizedStatusValue) || isReturnSuccessStatusValue(normalizedStatusValue)) {
      return PROGRESS_STATE_COMPLETED;
    }

    if (DEFINED_DELETED_STATUS_VALUES.contains(normalizedStatusValue)) {
      return PROGRESS_STATE_CANCELLED;
    }

    if (normalizedStatusValue == ACTIVATED_STATUS_VALUE) {
      return hasData ? PROGRESS_STATE_IN_PROGRESS : PROGRESS_STATE_NOT_STARTED;
    }

    return hasData ? PROGRESS_STATE_IN_PROGRESS : PROGRESS_STATE_NOT_STARTED;
  }

  private static Boolean isSaleSuccessStatusValue(String normalizedStatusValue) {
    return normalizedStatusValue == SALE_SUCCESS_STATUS_VALUE || normalizedStatusValue == SALE_SUCCESS_ACTIVE_STATUS_VALUE;
  }

  private static Boolean isReturnSuccessStatusValue(String normalizedStatusValue) {
    return normalizedStatusValue == RETURN_SUCCESS_STATUS_VALUE || normalizedStatusValue == RETURN_SUCCESS_ACTIVE_STATUS_VALUE;
  }

  @TestVisible
  private static Boolean testVisibleIsCancelledOrDeletedOrder(Order orderRecord) {
    return isCancelledOrDeletedOrder(orderRecord);
  }

  private static Object getQueriedValue(SObject record, String fieldName) {
    if (record == null || String.isBlank(fieldName)) {
      return null;
    }

    try {
      return record.get(fieldName);
    } catch (SObjectException e) {
      return null;
    }
  }

  private static Boolean getQueriedBooleanValue(SObject record, String fieldName) {
    Object value = getQueriedValue(record, fieldName);
    return value instanceof Boolean ? (Boolean) value : false;
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
    if (DEPT_VOUCHER_PAYMENT_METHODS.contains(paymentMethod)) {
      return 'DEPT_VOUCHER';
    }
    if (HQ_VOUCHER_PAYMENT_METHODS.contains(paymentMethod)) {
      return 'HQ_VOUCHER';
    }
    if (UPGRADE_PAYMENT_METHODS.contains(paymentMethod)) {
      return 'UPGRADE';
    }
    if (PROVISIONAL_PAYMENT_METHODS.contains(paymentMethod)) {
      return 'PROVISIONAL';
    }

    return 'OTHER';
  }

  public class OrderItemDto {
    @AuraEnabled
    public Id orderItemId;
    @AuraEnabled
    public Id orderId;
    @AuraEnabled
    public String productName;
    @AuraEnabled
    public Decimal quantity;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public String orderNo;
    @AuraEnabled
    public String saleNo;

    public OrderItemDto(OrderItem orderItem) {
      orderItemId = orderItem.Id;
      orderId = orderItem.OrderId;
      productName = orderItem.Product2 != null ? orderItem.Product2.Name : DEFAULT_PRODUCT_LABEL;
      quantity = orderItem.Quantity;
      amount = orderItem.TotalPrice == null ? 0 : orderItem.TotalPrice;
      orderNo = orderItem.Order != null ? orderItem.Order.OrderNo__c : null;
      saleNo = orderItem.Order != null ? orderItem.Order.SaleNo__c : null;
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
    public Id saleOrderId;
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

    public SaleRecordDto(Id orderId, String saleNumber, String statusLabel, Datetime saleDatetime, String storeCode, Decimal saleAmount) {
      saleOrderId = orderId;
      saleNo = saleNumber;
      status = statusLabel;
      saleDate = saleDatetime;
      storeName = storeCode;
      amount = saleAmount == null ? 0 : saleAmount;
    }
  }

  public class OrderRecordDto {
    @AuraEnabled
    public Id orderRecordId;
    @AuraEnabled
    public String orderNo;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Datetime orderDate;
    @AuraEnabled
    public String storeName;
    @AuraEnabled
    public Decimal amount;

    public OrderRecordDto(Id orderId, String orderNumber, String statusLabel, Datetime orderDatetime, String orderStoreName, Decimal orderAmount) {
      orderRecordId = orderId;
      orderNo = orderNumber;
      status = statusLabel;
      orderDate = orderDatetime;
      storeName = orderStoreName;
      amount = orderAmount == null ? 0 : orderAmount;
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
    public Decimal deptVoucherAmount = 0;
    public Decimal hqVoucherAmount = 0;
    public Decimal upgradeAmount = 0;
    public Decimal provisionalAmount = 0;
  }
}
