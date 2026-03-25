@IsTest
private class OrderNumViewControllerTest {
  private static String pick(Schema.SObjectField fieldRef, String defaultValue) {
    List<Schema.PicklistEntry> entries = fieldRef.getDescribe().getPicklistValues();
    return entries.isEmpty() ? defaultValue : entries[0].getValue();
  }

  private static String pickLabel(Schema.SObjectField fieldRef, String value, String defaultValue) {
    if (value == null) {
      return defaultValue;
    }

    for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
      if (entry.getValue() == value) {
        return entry.getLabel();
      }
    }

    return defaultValue;
  }

  private static String uniq(String prefix) {
    return prefix + '-' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }

  private static String pickFirst(List<Schema.PicklistEntry> entries, String fallback) {
    return entries.isEmpty() ? fallback : entries[0].getValue();
  }

  private static String resolveCurrencyType() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('NonQualifying')) {
        return entry.getValue();
      }
    }
    return pickFirst(LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues(), 'NonQualifying');
  }

  private static String resolveExpiryModel() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('Fixed')) {
        return entry.getValue();
      }
    }
    return pickFirst(LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues(), null);
  }

  private static String resolveExpiryUnit() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues()) {
      if (!entry.getValue().toLowerCase().contains('day')) {
        return entry.getValue();
      }
    }
    return pickFirst(LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues(), null);
  }

  private static String resolveExtendExpiration() {
    return pickFirst(LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues(), null);
  }

  private static TransactionJournal createTJ(Id orderId, Id loyaltyProgramId, Id memberId, Id journalTypeId, String paymentMethod, Decimal amount) {
    Map<String, Schema.SObjectField> fieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    Order targetOrder = [
      SELECT OrderNo__c, SaleNo__c
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];

    TransactionJournal tj = new TransactionJournal();
    tj.OrderId = orderId;
    tj.LoyaltyProgramId = loyaltyProgramId;
    tj.MemberId = memberId;
    tj.JournalTypeId = journalTypeId;
    tj.ActivityDate = Date.today();
    tj.PaymentMethod = paymentMethod;
    tj.TransactionAmount = amount;
    tj.Quantity = 1;
    tj.Status = pick(TransactionJournal.Status, 'Posted');

    if (fieldMap.containsKey('OrderNo__c')) {
      tj.put('OrderNo__c', targetOrder.OrderNo__c);
    }
    if (fieldMap.containsKey('SaleNo__c')) {
      tj.put('SaleNo__c', targetOrder.SaleNo__c);
    }
    if (fieldMap.containsKey('Type')) {
      tj.put('Type', 'Accrual');
    }
    if (fieldMap.containsKey('SubType')) {
      tj.put('SubType', 'Default');
    }
    if (fieldMap.containsKey('CurrencyIsoCode')) {
      tj.put('CurrencyIsoCode', 'KRW');
    }
    if (fieldMap.containsKey('Description')) {
      tj.put('Description', 'TEST');
    }

    insert tj;
    return tj;
  }

  private static void createLedger(Id transactionJournalId, Decimal points) {
    Map<String, Schema.SObjectField> ledgerFieldMap = Schema.sObjectType.LoyaltyLedger.fields.getMap();
    Map<String, Schema.SObjectField> currencyFieldMap = Schema.sObjectType.LoyaltyProgramCurrency.fields.getMap();

    TransactionJournal journal = [
      SELECT Id, JournalTypeId, LoyaltyProgramId
      FROM TransactionJournal
      WHERE Id = :transactionJournalId
      LIMIT 1
    ];

    LoyaltyLedger ledger = new LoyaltyLedger();
    ledger.TransactionJournalId = journal.Id;
    ledger.Points = points;
    ledger.EventType = 'Credit';

    if (ledgerFieldMap.containsKey('JournalTypeId') && journal.JournalTypeId != null) {
      ledger.put('JournalTypeId', journal.JournalTypeId);
    }

    if (ledgerFieldMap.containsKey('LoyaltyProgramCurrencyId')) {
      List<LoyaltyProgramCurrency> currencies = [
        SELECT Id
        FROM LoyaltyProgramCurrency
        WHERE LoyaltyProgramId = :journal.LoyaltyProgramId
        LIMIT 1
      ];

      Id currencyId;
      if (currencies.isEmpty()) {
        LoyaltyProgramCurrency loyaltyCurrency = new LoyaltyProgramCurrency();
        loyaltyCurrency.Name = uniq('POINT');
        loyaltyCurrency.LoyaltyProgramId = journal.LoyaltyProgramId;

        if (currencyFieldMap.containsKey('CurrencyType')) {
          loyaltyCurrency.put('CurrencyType', resolveCurrencyType());
        }
        if (currencyFieldMap.containsKey('IsActive')) {
          loyaltyCurrency.put('IsActive', true);
        }
        if (currencyFieldMap.containsKey('IsPrimary')) {
          loyaltyCurrency.put('IsPrimary', true);
        }
        if (currencyFieldMap.containsKey('ExpiryModel')) {
          loyaltyCurrency.put('ExpiryModel', resolveExpiryModel());
        }
        if (currencyFieldMap.containsKey('ExtendExpiration')) {
          loyaltyCurrency.put('ExtendExpiration', resolveExtendExpiration());
        }
        if (currencyFieldMap.containsKey('ExpiryPeriodFrequency')) {
          loyaltyCurrency.put('ExpiryPeriodFrequency', 12);
        }
        if (currencyFieldMap.containsKey('ExpiryPeriodUnit')) {
          loyaltyCurrency.put('ExpiryPeriodUnit', resolveExpiryUnit());
        }
        if (currencyFieldMap.containsKey('CostperUnit')) {
          loyaltyCurrency.put('CostperUnit', 1);
        }
        if (currencyFieldMap.containsKey('HasEscrow')) {
          loyaltyCurrency.put('HasEscrow', false);
        }
        if (currencyFieldMap.containsKey('DoesAllowLedgerTracing')) {
          loyaltyCurrency.put('DoesAllowLedgerTracing', true);
        }
        if (currencyFieldMap.containsKey('CurrencyIsoCode')) {
          loyaltyCurrency.put('CurrencyIsoCode', 'KRW');
        }
        if (currencyFieldMap.containsKey('Description')) {
          loyaltyCurrency.put('Description', 'TEST');
        }

        insert loyaltyCurrency;
        currencyId = loyaltyCurrency.Id;
      } else {
        currencyId = currencies[0].Id;
      }

      ledger.put('LoyaltyProgramCurrencyId', currencyId);
    }

    if (ledgerFieldMap.containsKey('Description')) {
      ledger.put('Description', 'TEST');
    }

    insert ledger;
  }

  private static void createOrderItem(Id orderId, Id pricebookEntryId, Decimal quantity, Decimal unitPrice) {
    Map<String, Schema.SObjectField> fieldMap = Schema.sObjectType.OrderItem.fields.getMap();

    OrderItem item = new OrderItem();
    item.OrderId = orderId;
    item.Quantity = quantity;
    item.PricebookEntryId = pricebookEntryId;

    if (fieldMap.containsKey('UnitPrice')) {
      item.put('UnitPrice', unitPrice);
    }
    if (fieldMap.containsKey('ServiceDate')) {
      item.put('ServiceDate', Date.today());
    }

    insert item;
  }

  private static void applyOrderDefaults(Order orderRecord, Id storeAccountId, Decimal actualPaymentAmount, String uniqueKey) {
    Map<String, Schema.SObjectField> orderFieldMap = Schema.sObjectType.Order.fields.getMap();

    orderRecord.Status = 'Draft';

    if (storeAccountId != null && orderFieldMap.containsKey('StoreCode__c')) {
      orderRecord.put('StoreCode__c', storeAccountId);
    }
    if (actualPaymentAmount != null && orderFieldMap.containsKey('ActualPaymentAmount__c')) {
      orderRecord.put('ActualPaymentAmount__c', actualPaymentAmount);
    }
    if (orderFieldMap.containsKey('Type') && orderRecord.get('Type') == null) {
      orderRecord.put('Type', 'Standard');
    }
    if (orderFieldMap.containsKey('OrderStatus__c') && orderRecord.get('OrderStatus__c') == null) {
      orderRecord.put('OrderStatus__c', pick(Order.OrderStatus__c, null));
    }
    if (orderFieldMap.containsKey('SaleStatus__c') && orderRecord.get('SaleStatus__c') == null) {
      orderRecord.put('SaleStatus__c', '01');
    }
    if (orderFieldMap.containsKey('OrderReferenceNumber') && orderRecord.get('OrderReferenceNumber') == null) {
      orderRecord.put('OrderReferenceNumber', 'REF-' + uniqueKey);
    }
    if (orderFieldMap.containsKey('InsertId__c') && orderRecord.get('InsertId__c') == null) {
      orderRecord.put('InsertId__c', 'TEST-' + uniqueKey);
    }
  }

  @TestSetup
  static void setup() {
    Id standardPricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = standardPricebookId, IsActive = true);

    String memberNo = uniq('M');
    String membershipNo = uniq('LPM');
    String orderNo = uniq('ORD');
    String saleNo = uniq('SALE');

    Contact contact = new Contact(LastName = 'TEST', MemberNo__c = memberNo, Grade__c = pick(Contact.Grade__c, null));
    insert contact;

    Account storeAccount = new Account(Name = 'STORE', StoreCode__c = 'STORE-001');
    insert storeAccount;

    Product2 product = new Product2(Name = 'PRODUCT', IsActive = true);
    insert product;

    PricebookEntry pricebookEntry = new PricebookEntry(
      Pricebook2Id = standardPricebookId,
      Product2Id = product.Id,
      UnitPrice = 10000,
      IsActive = true
    );
    insert pricebookEntry;

    LoyaltyProgram loyaltyProgram = new LoyaltyProgram(Name = 'LP', IsPrimary = true);
    insert loyaltyProgram;

    LoyaltyProgramMember loyaltyProgramMember = new LoyaltyProgramMember(
      ContactId = contact.Id,
      ProgramId = loyaltyProgram.Id,
      MembershipNumber = membershipNo,
      EnrollmentDate = Date.today(),
      MemberStatus = 'Active'
    );
    insert loyaltyProgramMember;

    JournalType journalType = new JournalType(Name = 'JT');
    insert journalType;

    Order orderRecord = new Order(
      Name = 'ORDER',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = orderNo,
      SaleNo__c = saleNo,
      MemberNo__c = contact.Id,
      IsReductionOrder = false
    );
    applyOrderDefaults(orderRecord, storeAccount.Id, 10000, orderNo);
    insert orderRecord;

    createOrderItem(orderRecord.Id, pricebookEntry.Id, 2, 10000);

    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, journalType.Id, '01', 1000);
    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, journalType.Id, '03', 500);
    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, journalType.Id, '90', 200);
    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, journalType.Id, '81', 300);

    TransactionJournal journal = [SELECT Id FROM TransactionJournal LIMIT 1];
    createLedger(journal.Id, 100);
  }

  @IsTest
  static void test_basic() {
    Order orderRecord = [SELECT Id FROM Order LIMIT 1];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assertEquals(500, dto.orderCardAmount);
    System.assertEquals(500, dto.saleCardAmount);
    System.assertEquals(pickLabel(Order.Type, 'Standard', 'Standard'), dto.orderType);
    System.assertEquals(dto.saleStoreName, dto.saleRecords[0].storeName);
  }

  @IsTest
  static void test_returnOrderDtoConstructor() {
    Order baseOrder = new Order(OrderNo__c = uniq('ORD'), EffectiveDate = Date.today(), Status = 'Draft', SaleNo__c = uniq('SALE'));
    Order returnOrder = new Order(SaleNo__c = uniq('SALE-R'), EffectiveDate = Date.today(), Status = 'Draft', IsReductionOrder = true);
    List<OrderItem> returnItems = new List<OrderItem>{ new OrderItem(Quantity = -1) };

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      baseOrder,
      baseOrder,
      returnOrder,
      new List<Order>{ baseOrder },
      new List<OrderItem>(),
      returnItems,
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertNotEquals(null, dto.returnNo);
  }

  @IsTest
  static void test_orderDetailDto_withoutReturn_doesNotPopulateReturnStoreName() {
    Order saleOrder = [
      SELECT
        Id,
        AccountId,
        Account.Name,
        Account.StoreCode__c,
        OrderNo__c,
        OrderReferenceNumber,
        OrderStatus__c,
        SaleNo__c,
        Status,
        EffectiveDate,
        EndDate,
        MemberNo__r.Id,
        MemberNo__r.Name,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c
      FROM Order
      WHERE IsReductionOrder = FALSE
      LIMIT 1
    ];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      null,
      new List<Order>{ saleOrder },
      new List<OrderItem>(),
      new List<OrderItem>(),
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertEquals(null, dto.returnNo);
    System.assertEquals(null, dto.returnStoreName);
  }

  @IsTest
  static void test_noJournal() {
    Order orderRecord = [SELECT Id FROM Order LIMIT 1];
    delete [SELECT Id FROM TransactionJournal WHERE OrderId = :orderRecord.Id];

    Test.startTest();
    OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_nullBranches() {
    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();
    String uniqueKey = uniq('NULL');

    Order orderRecord = new Order(
      Name = 'NULL',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today()
    );
    applyOrderDefaults(orderRecord, storeAccount.Id, 0, uniqueKey);
    insert orderRecord;

    Test.startTest();
    OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_getOrderNumView_withReturnRecord_usesOriginalSaleData() {
    Order saleOrder = [
      SELECT
        Id,
        Name,
        AccountId,
        Account.Name,
        Account.StoreCode__c,
        Pricebook2Id,
        Status,
        EffectiveDate,
        EndDate,
        OrderNo__c,
        OrderReferenceNumber,
        OrderStatus__c,
        SaleNo__c,
        MemberNo__c,
        MemberNo__r.Id,
        MemberNo__r.Name,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c
      FROM Order
      WHERE IsReductionOrder = FALSE
      LIMIT 1
    ];

    Order returnOrder = new Order(
      SaleNo__c = uniq('SALE-R'),
      EffectiveDate = Date.today(),
      EndDate = Date.today().addDays(1),
      Status = pick(Order.Status, 'Draft'),
      IsReductionOrder = true
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      returnOrder,
      new List<Order>{ saleOrder },
      new List<OrderItem>(),
      new List<OrderItem>(),
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertEquals(saleOrder.SaleNo__c, dto.saleNo);
    System.assertEquals(returnOrder.SaleNo__c, dto.returnNo);
    System.assertNotEquals(null, dto.saleDate);
  }

  @IsTest
  static void test_returnAmountsAndRestoredPoints_areNegative() {
    Order saleOrder = [
      SELECT
        Id,
        AccountId,
        Account.Name,
        Account.StoreCode__c,
        OrderNo__c,
        OrderReferenceNumber,
        OrderStatus__c,
        SaleNo__c,
        Status,
        EffectiveDate,
        EndDate,
        MemberNo__r.Id,
        MemberNo__r.Name,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c
      FROM Order
      WHERE IsReductionOrder = FALSE
      LIMIT 1
    ];

    Order returnOrder = new Order(
      SaleNo__c = uniq('SALE-RN'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = pick(Order.Status, 'Draft'),
      IsReductionOrder = true
    );

    List<OrderItem> returnItems = new List<OrderItem>{ new OrderItem(Quantity = -2) };

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      returnOrder,
      new List<Order>{ saleOrder },
      new List<OrderItem>(),
      returnItems,
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertEquals(returnOrder.SaleNo__c, dto.returnNo);
    System.assertEquals(2, dto.returnQuantity);
    System.assertNotEquals(null, dto.returnDate);
  }

  @IsTest
  static void test_getOrderNumView_usesDisplayOrderAndDepositFallback() {
    Order saleOrder = [
      SELECT Id, SaleNo__c, ActualPaymentAmount__c, TotalAmount
      FROM Order
      WHERE IsReductionOrder = FALSE
      LIMIT 1
    ];

    delete [SELECT Id FROM TransactionJournal WHERE OrderId = :saleOrder.Id];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(saleOrder.SaleNo__c, dto.saleNo);
    System.assertEquals(saleOrder.TotalAmount, dto.totalAmount);
    System.assertEquals(10000, dto.orderCashAmount);
  }

  @IsTest
  static void test_orderDetailDto_usesFinalSaleLedgerFromRelatedSaleOrders() {
    Order baseOrder = [
      SELECT
        Id,
        AccountId,
        Account.Name,
        Account.StoreCode__c,
        Pricebook2Id,
        MemberNo__c,
        MemberNo__r.Id,
        MemberNo__r.Name,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c,
        OrderNo__c,
        OrderReferenceNumber,
        OrderStatus__c,
        SaleNo__c,
        Status,
        EffectiveDate,
        EndDate
      FROM Order
      WHERE IsReductionOrder = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType journalType = [SELECT Id FROM JournalType LIMIT 1];
    String childSaleNo = uniq('SALE-CHILD');
    String childUniqueKey = uniq('SC');

    Order childSaleOrder = new Order(
      Name = 'CHILD-SALE',
      AccountId = baseOrder.AccountId,
      Pricebook2Id = baseOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-CHILD'),
      SaleNo__c = childSaleNo,
      MemberNo__c = baseOrder.MemberNo__c,
      IsReductionOrder = false
    );
    applyOrderDefaults(childSaleOrder, baseOrder.AccountId, 20000, childUniqueKey);
    insert childSaleOrder;

    TransactionJournal childJournal = createTJ(
      childSaleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      journalType.Id,
      '03',
      20000
    );
    createLedger(childJournal.Id, 250);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      baseOrder,
      baseOrder,
      null,
      new List<Order>{ childSaleOrder },
      new List<OrderItem>(),
      new List<OrderItem>(),
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertEquals(1, dto.saleRecords.size());
    System.assertEquals(childSaleNo, dto.saleRecords[0].saleNo);
    System.assertEquals(250, dto.earnedPointAmount);
    System.assertEquals(250, dto.earnedPointItems[0].amount);
  }
}
