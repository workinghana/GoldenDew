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
    String safePrefix = String.isBlank(prefix) ? 'T' : prefix.replaceAll('[^A-Za-z0-9]', '');
    if (safePrefix.length() > 6) {
      safePrefix = safePrefix.substring(0, 6);
    }

    String suffix = String.valueOf(Math.abs(Crypto.getRandomInteger()));
    if (suffix.length() > 6) {
      suffix = suffix.substring(0, 6);
    }

    return safePrefix + suffix;
  }

  private static String shortKey(String prefix) {
    String raw = uniq(prefix);
    return raw.length() > 8 ? raw.substring(0, 8) : raw;
  }

  private static String fitTextField(Schema.SObjectField fieldRef, Object rawValue) {
    if (fieldRef == null || rawValue == null) {
      return null;
    }

    String value = String.valueOf(rawValue);
    Integer maxLength = fieldRef.getDescribe().getLength();
    return maxLength > 0 && value.length() > maxLength ? value.substring(0, maxLength) : value;
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

  private static String resolvePointTypeCode(String preferredValue, String fallbackValue) {
    List<Schema.PicklistEntry> entries = LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.getValue() == preferredValue) {
        return entry.getValue();
      }
    }
    return pickFirst(entries, fallbackValue);
  }

  private static String resolveOrderStatus(String preferredValue, String fallbackValue) {
    List<Schema.PicklistEntry> entries = Order.Status.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.getValue() == preferredValue) {
        return entry.getValue();
      }
    }
    return pickFirst(entries, fallbackValue);
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

    JournalType journalType = [
      SELECT Id, Name
      FROM JournalType
      WHERE Id = :journalTypeId
      LIMIT 1
    ];

    if (fieldMap.containsKey('JournalSubTypeId')) {
      String defaultSubTypeName;
      if (journalType.Name == 'Deposit') {
        defaultSubTypeName = 'Sale Deposit';
      } else if (journalType.Name == 'Deposit Reversal') {
        defaultSubTypeName = 'Sale Deposit Reversal';
      } else if (journalType.Name == 'Accrual') {
        defaultSubTypeName = 'Purchase Accrual';
      } else if (journalType.Name == 'Accrual Reversal') {
        defaultSubTypeName = 'Cancel Purchase Accrual';
      } else if (journalType.Name == 'Redemption') {
        defaultSubTypeName = 'Point Debit';
      } else if (journalType.Name == 'Redemption Reversal') {
        defaultSubTypeName = 'Point Redeem Cancel';
      }

      if (!String.isBlank(defaultSubTypeName)) {
        List<JournalSubType> subTypes = [
          SELECT Id
          FROM JournalSubType
          WHERE Name = :defaultSubTypeName
          LIMIT 1
        ];
        if (!subTypes.isEmpty()) {
          tj.JournalSubTypeId = subTypes[0].Id;
        }
      }
    }

    insert tj;
    return tj;
  }

  private static TransactionJournal createTJByTypeName(
    Id orderId,
    Id loyaltyProgramId,
    Id memberId,
    String journalTypeName,
    String paymentMethod,
    Decimal amount
  ) {
    JournalType journalType = [SELECT Id FROM JournalType WHERE Name = :journalTypeName LIMIT 1];
    return createTJ(orderId, loyaltyProgramId, memberId, journalType.Id, paymentMethod, amount);
  }

  private static void createLedger(Id transactionJournalId, Decimal points) {
    createLedger(transactionJournalId, points, 'Credit');
  }

  private static void createLedger(Id transactionJournalId, Decimal points, String eventType) {
    createLedger(transactionJournalId, points, eventType, null);
  }

  private static LoyaltyLedger createLedger(Id transactionJournalId, Decimal points, String eventType, Id subtypeId) {
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
    ledger.EventType = eventType;

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

    if (subtypeId != null && ledgerFieldMap.containsKey('LoyaltyPgmCrcySubtypeId')) {
      ledger.put('LoyaltyPgmCrcySubtypeId', subtypeId);
    }

    insert ledger;
    return ledger;
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

  private static Order createSaleOrder(Id accountId, Id pricebook2Id, Id memberNoId, Decimal actualPaymentAmount, String orderKey, String saleKey) {
    Order orderRecord = new Order(
      Name = 'TEST-SALE',
      AccountId = accountId,
      Pricebook2Id = pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = orderKey,
      SaleNo__c = saleKey,
      MemberNo__c = memberNoId,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(orderRecord, accountId, actualPaymentAmount, orderKey);
    insert orderRecord;
    return orderRecord;
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
      String orderReferenceNumber = 'REF-' + String.valueOf(uniqueKey);
      orderRecord.put('OrderReferenceNumber', fitTextField(orderFieldMap.get('OrderReferenceNumber'), orderReferenceNumber));
    }
    if (orderFieldMap.containsKey('InsertId__c') && orderRecord.get('InsertId__c') == null) {
      String insertId = 'TEST-' + String.valueOf(uniqueKey);
      orderRecord.put('InsertId__c', fitTextField(orderFieldMap.get('InsertId__c'), insertId));
    }

    if (orderFieldMap.containsKey('Name') && orderRecord.Name != null) {
      orderRecord.Name = fitTextField(orderFieldMap.get('Name'), orderRecord.Name);
    }
    if (orderFieldMap.containsKey('OrderNo__c') && orderRecord.get('OrderNo__c') != null) {
      orderRecord.put('OrderNo__c', fitTextField(orderFieldMap.get('OrderNo__c'), orderRecord.get('OrderNo__c')));
    }
    if (orderFieldMap.containsKey('SaleNo__c') && orderRecord.get('SaleNo__c') != null) {
      orderRecord.put('SaleNo__c', fitTextField(orderFieldMap.get('SaleNo__c'), orderRecord.get('SaleNo__c')));
    }
    if (
      orderFieldMap.containsKey('MemberNo__c') &&
      orderFieldMap.get('MemberNo__c').getDescribe().getType() == Schema.DisplayType.String &&
      orderRecord.get('MemberNo__c') != null
    ) {
      orderRecord.put('MemberNo__c', fitTextField(orderFieldMap.get('MemberNo__c'), orderRecord.get('MemberNo__c')));
    }

    // Keep all populated text-like Order fields within their schema limits so
    // random test keys do not break inserts on org-specific custom fields.
    for (String fieldName : orderFieldMap.keySet()) {
      Object fieldValue = orderRecord.get(fieldName);
      if (fieldValue == null) {
        continue;
      }

      Schema.DescribeFieldResult fieldDescribe = orderFieldMap.get(fieldName).getDescribe();
      Schema.DisplayType fieldType = fieldDescribe.getType();
      if (
        fieldType == Schema.DisplayType.String ||
        fieldType == Schema.DisplayType.TextArea ||
        //fieldType == Schema.DisplayType.LongTextArea ||
        fieldType == Schema.DisplayType.EncryptedString ||
        fieldType == Schema.DisplayType.Email ||
        fieldType == Schema.DisplayType.Phone ||
        fieldType == Schema.DisplayType.Url
      ) {
        orderRecord.put(fieldName, fitTextField(orderFieldMap.get(fieldName), fieldValue));
      }
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

    insert new JournalType(Name = 'Deposit');
    insert new JournalType(Name = 'Deposit Reversal');
    insert new JournalType(Name = 'Accrual');
    insert new JournalType(Name = 'Accrual Reversal');
    insert new JournalType(Name = 'Redemption');
    insert new JournalType(Name = 'Redemption Reversal');
    Id depositTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit' LIMIT 1].Id;
    Id depositReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit Reversal' LIMIT 1].Id;
    Id accrualTypeId = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1].Id;
    Id accrualReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Accrual Reversal' LIMIT 1].Id;
    Id redemptionTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1].Id;
    Id redemptionReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1].Id;
    insert new JournalSubType(Name = 'Order Deposit', JournalTypeId = depositTypeId);
    insert new JournalSubType(Name = 'Sale Deposit', JournalTypeId = depositTypeId);
    insert new JournalSubType(Name = 'Order Deposit Reversal', JournalTypeId = depositReversalTypeId);
    insert new JournalSubType(Name = 'Sale Deposit Reversal', JournalTypeId = depositReversalTypeId);
    insert new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = accrualTypeId);
    insert new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = accrualReversalTypeId);
    insert new JournalSubType(Name = 'Coupon Redeem', JournalTypeId = redemptionTypeId);
    insert new JournalSubType(Name = 'Coupon Redeem Cancel', JournalTypeId = redemptionReversalTypeId);
    insert new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionTypeId);
    insert new JournalSubType(Name = 'Api Forced Debit', JournalTypeId = redemptionTypeId);
    insert new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = redemptionReversalTypeId);

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
      IsReductionOrder__c = false
    );
    applyOrderDefaults(orderRecord, storeAccount.Id, 10000, orderNo);
    insert orderRecord;

    createOrderItem(orderRecord.Id, pricebookEntry.Id, 2, 10000);

    createTJByTypeName(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, 'Deposit', '01', 1000);
    createTJByTypeName(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, 'Deposit', '03', 500);
    createTJByTypeName(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, 'Deposit', '90', 200);
    createTJByTypeName(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, 'Deposit', '81', 300);

    TransactionJournal journal = [
      SELECT Id
      FROM TransactionJournal
      WHERE OrderId = :orderRecord.Id
      ORDER BY CreatedDate ASC
      LIMIT 1
    ];
    createLedger(journal.Id, 100);
  }

  @IsTest
  static void test_basic() {
    Order orderRecord = [SELECT Id FROM Order LIMIT 1];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assertEquals(2, dto.orderQuantity);
    System.assertEquals(1, dto.orderItems.size());
    System.assertEquals(2, dto.orderItems[0].quantity);
    System.assertEquals(20000, dto.orderItems[0].amount);
    System.assertEquals(500, dto.orderCardAmount);
    System.assertEquals(500, dto.saleCardAmount);
    System.assertEquals(10000, dto.saleTotalAmount);
    System.assertEquals(pickLabel(Order.Type, 'Standard', 'Standard'), dto.orderType);
    System.assertEquals(dto.saleStoreName, dto.saleRecords[0].storeName);
  }

  @IsTest
  static void test_returnOrderDtoConstructor() {
    Order baseOrder = new Order(OrderNo__c = uniq('ORD'), EffectiveDate = Date.today(), Status = 'Draft', SaleNo__c = uniq('SALE'));
    Order returnOrder = new Order(SaleNo__c = uniq('SALE-R'), EffectiveDate = Date.today(), Status = 'Draft', IsReductionOrder__c = true);
    List<OrderItem> returnItems = new List<OrderItem>{ new OrderItem(Quantity = -1) };

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      baseOrder,
      baseOrder,
      returnOrder,
      new List<Order>{ returnOrder },
      new List<Order>{ baseOrder },
      new List<OrderItem>(),
      returnItems,
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertNotEquals(null, dto.returnNo);
  }

  @IsTest
  static void test_orderDetailDto_separatesOrderItemsAndSaleItems() {
    Order displayOrder = new Order(OrderNo__c = uniq('ORD'), EffectiveDate = Date.today(), Status = 'Draft');
    Order saleOrder = new Order(OrderNo__c = displayOrder.OrderNo__c, SaleNo__c = uniq('SALE'), EffectiveDate = Date.today(), Status = 'Draft');
    List<OrderItem> orderItems = new List<OrderItem>{ new OrderItem(Quantity = 1, Product2 = new Product2(Name = 'ORDER-ITEM')) };
    List<OrderItem> saleItems = new List<OrderItem>{ new OrderItem(Quantity = 2, Product2 = new Product2(Name = 'SALE-ITEM')) };

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      displayOrder,
      saleOrder,
      null,
      new List<Order>(),
      new List<Order>{ saleOrder },
      orderItems,
      saleItems,
      new List<OrderItem>(),
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertEquals(1, dto.orderItems.size());
    System.assertEquals('ORDER-ITEM', dto.orderItems[0].productName);
    System.assertEquals(1, dto.saleItems.size());
    System.assertEquals(2, dto.saleItems[0].quantity);
    System.assertEquals('SALE-ITEM', dto.saleItems[0].productName);
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
        TotalAmount,
        ActualPaymentAmount__c,
        Status,
        EffectiveDate,
        EndDate,
        MemberNo__r.Id,
        MemberNo__r.Name,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      null,
      new List<Order>(),
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
    orderRecord.OrderReferenceNumber = null;
    insert orderRecord;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assertEquals(null, dto.orderNo);
    System.assertEquals(0, dto.totalAmount);
    System.assertEquals(0, dto.orderQuantity);
    System.assertEquals(0, dto.orderDepositTotalAmount);
    System.assertEquals(null, dto.saleNo);
    System.assertEquals(0, dto.saleTotalAmount);
    System.assertEquals(null, dto.returnNo);
    System.assertEquals(0, dto.returnTotalAmount);
  }

  @IsTest
  static void test_orderDetailDto_hidesOrderStageWhenOrderNumberIsMissing() {
    String saleNo = uniq('SALE');

    Order saleOrder = new Order(
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      SaleNo__c = saleNo,
      ActualPaymentAmount__c = 1962000
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      null,
      new List<Order>(),
      new List<Order>{ saleOrder },
      new List<OrderItem>{ new OrderItem(Quantity = 1) },
      new List<OrderItem>(),
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertEquals(null, dto.orderNo);
    System.assertEquals(null, dto.orderDate);
    System.assertEquals(null, dto.orderStatus);
    System.assertEquals(null, dto.orderType);
    System.assertEquals(null, dto.orderStoreName);
    System.assertEquals(0, dto.totalAmount);
    System.assertEquals(0, dto.orderQuantity);
    System.assertEquals(0, dto.orderCashAmount);
    System.assertEquals(0, dto.orderDepositTotalAmount);
    System.assertEquals(saleNo, dto.saleNo);
    System.assertEquals(1962000, dto.saleTotalAmount);
    System.assertEquals(1, dto.saleQuantity);
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
        TotalAmount,
        ActualPaymentAmount__c,
        MemberNo__c,
        MemberNo__r.Id,
        MemberNo__r.Name,
        MemberNo__r.MemberNo__c,
        MemberNo__r.MobilePhone,
        MemberNo__r.Grade__c
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];

    Order returnOrder = new Order(
      SaleNo__c = uniq('SALE-R'),
      EffectiveDate = Date.today(),
      EndDate = Date.today().addDays(1),
      Status = pick(Order.Status, 'Draft'),
      IsReductionOrder__c = true
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      returnOrder,
      new List<Order>{ returnOrder },
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
  static void test_returnPoints_includeCancelPurchaseAccrualDebit() {
    Order saleOrder = [SELECT Id, SaleNo__c, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType journalType = [SELECT Id FROM JournalType WHERE Name = 'Accrual Reversal' LIMIT 1];
    JournalSubType cancelSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Cancel Purchase Accrual' LIMIT 1];
    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '구매포인트',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert purchaseSubtype;

    Order returnOrder = new Order(
      Name = 'RETURN-DEBIT',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('SALE-R'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    saleOrder.Status = resolveOrderStatus('Activated', 'Activated');
    update saleOrder;
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RET'));
    insert returnOrder;

    TransactionJournal cancelJournal = createTJ(returnOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, journalType.Id, '81', 0);
    cancelJournal.JournalSubTypeId = cancelSubtype.Id;
    update cancelJournal;

    createLedger(cancelJournal.Id, -45, 'Debit', purchaseSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(returnOrder.Id);
    Test.stopTest();

    System.assertEquals(returnOrder.SaleNo__c, dto.returnNo);
    System.assertEquals(45, dto.restoredPointAmount);
    System.assertEquals(1, dto.restoredPointItems.size());
    System.assertEquals(45, dto.restoredPointItems[0].amount);
  }

  @IsTest
  static void test_returnSummary_separatesRefundPointFromRestoredPoints() {
    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType redemptionReversalType = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1];
    JournalSubType pointRedeemCancelSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Point Redeem Cancel' LIMIT 1];

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-POINT-SEPARATION',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('SALERPS'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RPS'));
    insert returnOrder;

    TransactionJournal pointRedeemCancel = createTJ(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalType.Id,
      '81',
      700
    );
    pointRedeemCancel.JournalSubTypeId = pointRedeemCancelSubtype.Id;
    pointRedeemCancel.Status = 'Processed';
    update pointRedeemCancel;
    createLedger(pointRedeemCancel.Id, 700, 'Credit');

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(700, dto.refundPointAmount);
    System.assertEquals(0, dto.restoredPointAmount);
    System.assertEquals(0, dto.restoredPointItems.size());
  }

  @IsTest
  static void test_returnPoints_includeOriginalSaleCancelPurchaseAccrualDebit_withTraceabilitySubtype() {
    Order saleOrder = [
      SELECT Id, SaleNo__c, AccountId, Pricebook2Id, MemberNo__c, Status
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalType accrualReversalType = [SELECT Id FROM JournalType WHERE Name = 'Accrual Reversal' LIMIT 1];
    JournalSubType cancelSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Cancel Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '구매포인트',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 41,
      IsActive = true
    );
    LoyaltyPgmCurrencySubtype giftSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '사은포인트',
      PointTypeCode__c = resolvePointTypeCode('06', '06'),
      UsagePriorityNumber = 42,
      IsActive = true
    );
    insert new List<LoyaltyPgmCurrencySubtype>{ purchaseSubtype, giftSubtype };

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-TRACE',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('SALERT'),
      OriginalOrderId__c = saleOrder.Id,
      MemberNo__c = saleOrder.MemberNo__c,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RETT'));
    insert returnOrder;

    TransactionJournal purchaseJournal = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, '81', 0);
    LoyaltyLedger purchaseLedger = createLedger(purchaseJournal.Id, 18000, 'Credit', purchaseSubtype.Id);
    LoyaltyLedger giftLedger = createLedger(purchaseJournal.Id, 27000, 'Credit', giftSubtype.Id);

    TransactionJournal cancelJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualReversalType.Id,
      '81',
      0
    );
    cancelJournal.JournalSubTypeId = cancelSubtype.Id;
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (journalFieldMap.containsKey('SaleId__c')) {
      cancelJournal.put('SaleId__c', returnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      cancelJournal.put('OrderId__c', returnOrder.Id);
    }
    update cancelJournal;

    LoyaltyLedger cancelPurchaseLedger = createLedger(cancelJournal.Id, -18000, 'Debit', null);
    LoyaltyLedger cancelGiftLedger = createLedger(cancelJournal.Id, -27000, 'Debit', null);

    insert new List<LoyaltyLedgerTraceability>{
      new LoyaltyLedgerTraceability(
        LoyaltyProgramMemberId = loyaltyProgramMember.Id,
        LoyaltyProgramCurrencyId = pointCurrency.Id,
        LoyaltyPgmCurrencySubtypeId = purchaseSubtype.Id,
        CreditLoyaltyLedgerId = purchaseLedger.Id,
        DebitLoyaltyLedgerId = cancelPurchaseLedger.Id,
        ActionType = 'Debit',
        Points = 18000
      ),
      new LoyaltyLedgerTraceability(
        LoyaltyProgramMemberId = loyaltyProgramMember.Id,
        LoyaltyProgramCurrencyId = pointCurrency.Id,
        LoyaltyPgmCurrencySubtypeId = giftSubtype.Id,
        CreditLoyaltyLedgerId = giftLedger.Id,
        DebitLoyaltyLedgerId = cancelGiftLedger.Id,
        ActionType = 'Debit',
        Points = 27000
      )
    };

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(returnOrder.Id);
    Test.stopTest();

    System.assertEquals(returnOrder.SaleNo__c, dto.returnNo);
    System.assertEquals(45000, dto.restoredPointAmount);
    System.assertEquals(2, dto.restoredPointItems.size());

    Map<String, Decimal> restoredAmountByType = new Map<String, Decimal>();
    for (OrderNumViewController.EarnedPointItemDto pointItem : dto.restoredPointItems) {
      restoredAmountByType.put(pointItem.type, pointItem.amount);
    }

    System.assertEquals(18000, restoredAmountByType.get(resolvePointTypeCode('01', '01')));
    System.assertEquals(27000, restoredAmountByType.get(resolvePointTypeCode('06', '06')));
  }

  // @IsTest
  // static void test_returnPoints_includeOriginalSaleCancelPurchaseAccrualDebit_withTraceabilitySubtype() {
  //   Order saleOrder = [
  //     SELECT Id, SaleNo__c, AccountId, Pricebook2Id, MemberNo__c
  //     FROM Order
  //     WHERE IsReductionOrder__c = FALSE
  //     LIMIT 1
  //   ];
  //   LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
  //   JournalType depositType = [SELECT Id FROM JournalType WHERE Name = 'Deposit' LIMIT 1];
  //   JournalSubType cancelSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Cancel Purchase Accrual' LIMIT 1];
  //   Id standardPricebookId = Test.getStandardPricebookId();
  //
  //   LoyaltyProgramCurrency pointCurrency = [
  //     SELECT Id
  //     FROM LoyaltyProgramCurrency
  //     WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
  //     LIMIT 1
  //   ];
  //
  //   LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
  //     LoyaltyProgramCurrencyId = pointCurrency.Id,
  //     Name = '구매포인트',
  //     PointTypeCode__c = '01',
  //     UsagePriorityNumber = 1,
  //     IsActive = true
  //   );
  //   LoyaltyPgmCurrencySubtype giftSubtype = new LoyaltyPgmCurrencySubtype(
  //     LoyaltyProgramCurrencyId = pointCurrency.Id,
  //     Name = '사은포인트',
  //     PointTypeCode__c = '06',
  //     UsagePriorityNumber = 2,
  //     IsActive = true
  //   );
  //   insert new List<LoyaltyPgmCurrencySubtype>{ purchaseSubtype, giftSubtype };
  //
  //   saleOrder.Status = pick(Order.Status, 'Activated');
  //   update saleOrder;
  //
  //   Order returnOrder = new Order(
  //     Name = 'RETURN-TRACE',
  //     AccountId = saleOrder.AccountId,
  //     Pricebook2Id = standardPricebookId,
  //     Status = pick(Order.Status, 'Draft'),
  //     EffectiveDate = Date.today(),
  //     EndDate = Date.today(),
  //     SaleNo__c = uniq('SALE-RT'),
  //     OriginalOrderId__c = saleOrder.Id,
  //     MemberNo__c = saleOrder.MemberNo__c,
  //     IsReductionOrder__c = true
  //   );
  //   applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RET-T'));
  //   insert returnOrder;
  //
  //   TransactionJournal purchaseJournal = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, depositType.Id, '81', 0);
  //   LoyaltyLedger purchaseLedger = createLedger(purchaseJournal.Id, 18000, 'Credit', purchaseSubtype.Id);
  //   LoyaltyLedger giftLedger = createLedger(purchaseJournal.Id, 27000, 'Credit', giftSubtype.Id);
  //
  //   TransactionJournal cancelJournal = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, depositType.Id, '81', 0);
  //   cancelJournal.JournalSubTypeId = cancelSubtype.Id;
  //   update cancelJournal;
  //
  //   LoyaltyLedger cancelPurchaseLedger = createLedger(cancelJournal.Id, -18000, 'Debit', null);
  //   LoyaltyLedger cancelGiftLedger = createLedger(cancelJournal.Id, -27000, 'Debit', null);
  //
  //   insert new List<LoyaltyLedgerTraceability>{
  //     new LoyaltyLedgerTraceability(
  //       LoyaltyProgramMemberId = loyaltyProgramMember.Id,
  //       LoyaltyProgramCurrencyId = pointCurrency.Id,
  //       LoyaltyPgmCurrencySubtypeId = purchaseSubtype.Id,
  //       CreditLoyaltyLedgerId = purchaseLedger.Id,
  //       DebitLoyaltyLedgerId = cancelPurchaseLedger.Id,
  //       ActionType = 'Debit',
  //       Points = 18000
  //     ),
  //     new LoyaltyLedgerTraceability(
  //       LoyaltyProgramMemberId = loyaltyProgramMember.Id,
  //       LoyaltyProgramCurrencyId = pointCurrency.Id,
  //       LoyaltyPgmCurrencySubtypeId = giftSubtype.Id,
  //       CreditLoyaltyLedgerId = giftLedger.Id,
  //       DebitLoyaltyLedgerId = cancelGiftLedger.Id,
  //       ActionType = 'Debit',
  //       Points = 27000
  //     )
  //   };
  //
  //   Test.startTest();
  //   OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(returnOrder.Id);
  //   Test.stopTest();
  //
  //   System.assertEquals(returnOrder.SaleNo__c, dto.returnNo);
  //   System.assertEquals(45000, dto.restoredPointAmount);
  //   System.assertEquals(2, dto.restoredPointItems.size());
  //
  //   Map<String, Decimal> restoredAmountByType = new Map<String, Decimal>();
  //   for (OrderNumViewController.EarnedPointItemDto pointItem : dto.restoredPointItems) {
  //     restoredAmountByType.put(pointItem.type, pointItem.amount);
  //   }
  //
  //   System.assertEquals(18000, restoredAmountByType.get('01'));
  //   System.assertEquals(27000, restoredAmountByType.get('06'));
  // }

  // @IsTest
  // static void test_returnAmountsAndRestoredPoints_areNegative() {
  //   Order saleOrder = [
  //     SELECT
  //       Id,
  //       Name,
  //       AccountId,
  //       Account.Name,
  //       Account.StoreCode__c,
  //       Pricebook2Id,
  //       OrderNo__c,
  //       OrderReferenceNumber,
  //       OrderStatus__c,
  //       SaleNo__c,
  //       Status,
  //       EffectiveDate,
  //       EndDate,
  //       MemberNo__r.Id,
  //       MemberNo__r.Name,
  //       MemberNo__r.MemberNo__c,
  //       MemberNo__r.MobilePhone,
  //       MemberNo__r.Grade__c
  //     FROM Order
  //     WHERE IsReductionOrder__c = FALSE
  //     LIMIT 1
  //   ];

  //   Contact contact = [SELECT Id FROM Contact LIMIT 1];
  //   LoyaltyProgram loyaltyProgram = [SELECT Id FROM LoyaltyProgram LIMIT 1];
  //   LoyaltyProgramMember loyaltyProgramMember = [SELECT Id FROM LoyaltyProgramMember LIMIT 1];
  //   Id standardPricebookId = Test.getStandardPricebookId();
  //   String returnSaleNo = shortKey('SALE-RN');

  //   Order returnOrder = new Order(
  //     Name = 'RETURN',
  //     AccountId = saleOrder.AccountId,
  //     Pricebook2Id = standardPricebookId,
  //     Status = pick(Order.Status, 'Draft'),
  //     EffectiveDate = Date.today(),
  //     EndDate = Date.today(),
  //     SaleNo__c = returnSaleNo,
  //     OrderNo__c = shortKey('RET'),
  //     MemberNo__c = contact.Id,
  //     IsReductionOrder__c = true,
  //     OriginalOrderId__c = saleOrder.Id
  //   );
  //   applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, returnSaleNo);
  //   insert returnOrder;

  //   Id pricebookEntryId = [SELECT Id FROM PricebookEntry LIMIT 1].Id;
  //   createOrderItem(returnOrder.Id, pricebookEntryId, -2, 10000);

  //   TransactionJournal refundJournal = createTJByTypeName(returnOrder.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, 'Deposit Reversal', '81', -700);
  //   createLedger(refundJournal.Id, 70);

  //   Test.startTest();
  //   OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
  //     saleOrder,
  //     saleOrder,
  //     returnOrder,
  //     new List<Order>{ saleOrder },
  //     new List<OrderItem>(),
  //     [SELECT Id, Quantity, TotalPrice, Product2.Name FROM OrderItem WHERE OrderId = :returnOrder.Id],
  //     new List<TransactionJournal>()
  //   );
  //   Test.stopTest();

  //   System.assertEquals(returnOrder.SaleNo__c, dto.returnNo);
  //   System.assertEquals(2, dto.returnQuantity);
  //   System.assertNotEquals(null, dto.returnDate);
  //   System.assertEquals(-700, dto.refundPointAmount);
  //   System.assertEquals(-70, dto.restoredPointAmount);
  // }

  @IsTest
  static void test_getOrderNumView_usesDisplayOrderAndDepositFallback() {
    Order saleOrder = [
      SELECT Id, SaleNo__c, ActualPaymentAmount__c, TotalAmount
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];

    saleOrder.ActualPaymentAmount__c = 10000;
    update saleOrder;

    delete [SELECT Id FROM TransactionJournal WHERE OrderId = :saleOrder.Id];

    saleOrder = [SELECT Id, SaleNo__c, ActualPaymentAmount__c, TotalAmount FROM Order WHERE Id = :saleOrder.Id];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(saleOrder.SaleNo__c, dto.saleNo);
    System.assertEquals(saleOrder.TotalAmount == null ? 0 : saleOrder.TotalAmount, dto.totalAmount);
    System.assertEquals(saleOrder.ActualPaymentAmount__c, dto.saleTotalAmount);
    System.assertEquals(10000, dto.orderCashAmount);
  }

  @IsTest
  static void test_getOrderNumView_orderSummaryIncludesPointDebit() {
    Order seedOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType depositType = [SELECT Id FROM JournalType WHERE Name = 'Deposit' LIMIT 1];
    JournalType redemptionType = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1];
    Order saleOrder = createSaleOrder(seedOrder.AccountId, seedOrder.Pricebook2Id, seedOrder.MemberNo__c, 250000, uniq('ORDPNT'), uniq('SALEPNT'));

    createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, depositType.Id, '01', 200000);
    TransactionJournal pointDebit = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionType.Id, '81', 50000);
    pointDebit.Status = 'Processed';
    update pointDebit;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(200000, dto.orderCashAmount);
    System.assertEquals(50000, dto.orderPointAmount);
    System.assertEquals(250000, dto.orderDepositTotalAmount);
  }

  @IsTest
  static void test_orderDetailDto_usesFinalSaleLedgerFromRelatedSaleOrders() {
    Order seedOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType journalType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    Order baseOrder = createSaleOrder(seedOrder.AccountId, seedOrder.Pricebook2Id, seedOrder.MemberNo__c, 10000, uniq('ORDBAS'), uniq('SALEBS'));
    baseOrder = [
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
        TotalAmount,
        ActualPaymentAmount__c,
        Status,
        EffectiveDate,
        EndDate
      FROM Order
      WHERE Id = :baseOrder.Id
      LIMIT 1
    ];
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
      IsReductionOrder__c = false
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
      new List<Order>(),
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

  @IsTest
  static void test_getOrderNumView_salePaymentSummary_appliesSaleDepositReversalsAsNet() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDNET'), uniq('SALENET'));

    createTJByTypeName(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit', '01', 1000);
    createTJByTypeName(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit', '02', 50);
    createTJByTypeName(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit Reversal', '01', 1000);
    createTJByTypeName(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit Reversal', '02', 50);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(1000, dto.saleCashAmount);
    System.assertEquals(1000, dto.saleDepositTotalAmount);
  }

  @IsTest
  static void test_getOrderNumView_orderPaymentSummary_usesOnlyOrderDepositSubtypes() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalSubType orderDepositSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Order Deposit' LIMIT 1];
    JournalSubType orderDepositReversalSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Order Deposit Reversal' LIMIT 1];

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDODP'), uniq('SALEODP'));

    TransactionJournal orderDeposit = createTJByTypeName(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit', '01', 400);
    orderDeposit.JournalSubTypeId = orderDepositSubType.Id;
    update orderDeposit;

    TransactionJournal orderDepositReversal = createTJByTypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      '01',
      150
    );
    orderDepositReversal.JournalSubTypeId = orderDepositReversalSubType.Id;
    update orderDepositReversal;

    createTJByTypeName(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit', '03', 999);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(550, dto.orderCashAmount);
    System.assertEquals(1549, dto.orderDepositTotalAmount);
    System.assertEquals(999, dto.saleCardAmount);
  }

  // @IsTest
  // static void test_getOrderNumView_returnPaymentSummary_usesReturnOrderSaleDepositReversal() {
  //   Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
  //   LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
  //   Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDRET'), uniq('SALERET'));
  //   saleOrder.Status = pick(Order.Status, 'Activated');
  //   update saleOrder;
  //   Order returnOrder = new Order(
  //     Name = 'RETURN-PAY',
  //     AccountId = saleOrder.AccountId,
  //     Pricebook2Id = saleOrder.Pricebook2Id,
  //     Status = pick(Order.Status, 'Draft'),
  //     EffectiveDate = Date.today(),
  //     EndDate = Date.today(),
  //     SaleNo__c = uniq('SALE-RPAY'),
  //     OriginalOrderId__c = saleOrder.Id,
  //     MemberNo__c = saleOrder.MemberNo__c,
  //     IsReductionOrder__c = true
  //   );
  //   applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RETPAY'));
  //   insert returnOrder;
  //
  //   createTJByTypeName(returnOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit Reversal', '01', 700);
  //   createTJByTypeName(returnOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit Reversal', '03', 300);
  //
  //   Test.startTest();
  //   OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(returnOrder.Id);
  //   Test.stopTest();
  //
  //   System.assertEquals(-700, dto.refundCashAmount);
  //   System.assertEquals(-300, dto.refundCardAmount);
  //   System.assertEquals(-1000, dto.returnDepositTotalAmount);
  // }

  @IsTest
  static void test_getOrderNumView_couponRedemption_isIncludedInSaleCouponAmount() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType redemptionType = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1];
    JournalType redemptionReversalType = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1];
    JournalSubType couponRedeemSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem' LIMIT 1];
    JournalSubType couponRedeemCancelSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem Cancel' LIMIT 1];

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDCPN'), uniq('SALECPN'));

    TransactionJournal approvedCouponRedeem = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionType.Id,
      null,
      150
    );
    approvedCouponRedeem.JournalSubTypeId = couponRedeemSubType.Id;
    approvedCouponRedeem.Status = 'Approved';
    update approvedCouponRedeem;

    TransactionJournal pendingCouponRedeem = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionType.Id,
      null,
      500
    );
    pendingCouponRedeem.JournalSubTypeId = couponRedeemSubType.Id;
    pendingCouponRedeem.Status = 'Pending';
    update pendingCouponRedeem;

    TransactionJournal couponRedeemCancel = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalType.Id,
      null,
      20
    );
    couponRedeemCancel.JournalSubTypeId = couponRedeemCancelSubType.Id;
    couponRedeemCancel.Status = 'Processed';
    update couponRedeemCancel;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(150, dto.saleCouponAmount);
    System.assertEquals(150, dto.saleDepositTotalAmount);
  }

  @IsTest
  static void test_getOrderNumView_couponRedemption_isIncludedInOrderCouponAmount() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType redemptionType = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1];
    JournalSubType couponRedeemSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem' LIMIT 1];

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDOCP'), uniq('SALEOCP'));

    TransactionJournal approvedCouponRedeem = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionType.Id,
      null,
      210
    );
    approvedCouponRedeem.JournalSubTypeId = couponRedeemSubType.Id;
    approvedCouponRedeem.Status = 'Processed';
    update approvedCouponRedeem;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(210, dto.orderCouponAmount);
  }

  @IsTest
  static void test_getOrderNumView_salePointAmount_keepsOriginalPointDebit_whenCancelExists() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType redemptionType = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1];
    JournalType redemptionReversalType = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1];
    JournalSubType pointDebitSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Point Debit' LIMIT 1];
    JournalSubType pointRedeemCancelSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Point Redeem Cancel' LIMIT 1];

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDPDB'), uniq('SALEPDB'));

    TransactionJournal pointDebit = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionType.Id, '81', 302800);
    pointDebit.JournalSubTypeId = pointDebitSubType.Id;
    pointDebit.Status = 'Processed';
    update pointDebit;

    TransactionJournal pointRedeemCancel = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalType.Id,
      '81',
      302800
    );
    pointRedeemCancel.JournalSubTypeId = pointRedeemCancelSubType.Id;
    pointRedeemCancel.Status = 'Processed';
    update pointRedeemCancel;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(302800, dto.salePointAmount);
    System.assertEquals(0, dto.earnedPointAmount);
    System.assertEquals(302800, dto.saleDepositTotalAmount);
  }

  @IsTest
  static void test_getOrderNumView_pointRedemption_isIncludedInSalePointAmount() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType redemptionType = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1];
    JournalSubType pointDebitSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Point Debit' LIMIT 1];

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDPDP'), uniq('SALEPDP'));

    TransactionJournal pointDebit = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionType.Id, '81', 120);
    pointDebit.JournalSubTypeId = pointDebitSubType.Id;
    pointDebit.Status = 'Processed';
    update pointDebit;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(120, dto.salePointAmount);
    System.assertEquals(120, dto.saleDepositTotalAmount);
    System.assertEquals(0, dto.earnedPointAmount);
  }

  @IsTest
  static void test_getOrderNumView_salePointAmount_excludesRestoredPointUsage() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType redemptionType = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1];
    JournalSubType pointDebitSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Point Debit' LIMIT 1];

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDPDR'), uniq('SALEPDR'));

    TransactionJournal pointDebit = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionType.Id, '81', 1000);
    pointDebit.JournalSubTypeId = pointDebitSubType.Id;
    pointDebit.Status = 'Processed';
    update pointDebit;

    TransactionJournal restoredPointDebit = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionType.Id,
      '81',
      500
    );
    restoredPointDebit.JournalSubTypeId = pointDebitSubType.Id;
    restoredPointDebit.Status = 'Processed';
    restoredPointDebit.AdditionalNotes__c = 'Restore point usage due to return deletion';
    update restoredPointDebit;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(1000, dto.salePointAmount);
    System.assertEquals(1000, dto.saleDepositTotalAmount);
  }

  @IsTest
  static void test_getOrderNumView_saleEarnedPoints_showOriginalAccrualEvenWhenCanceledByReturn() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalType accrualReversalType = [SELECT Id FROM JournalType WHERE Name = 'Accrual Reversal' LIMIT 1];
    JournalSubType cancelSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Cancel Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '구매포인트2',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 11,
      IsActive = true
    );
    insert purchaseSubtype;

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDPNT'), uniq('SALEPNT'));

    TransactionJournal accrualJournal = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, '81', 0);
    LoyaltyLedger creditLedger = createLedger(accrualJournal.Id, 100, 'Credit', purchaseSubtype.Id);

    TransactionJournal cancelJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualReversalType.Id,
      '81',
      0
    );
    cancelJournal.JournalSubTypeId = cancelSubtype.Id;
    update cancelJournal;
    LoyaltyLedger debitLedger = createLedger(cancelJournal.Id, -40, 'Debit', purchaseSubtype.Id);

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = loyaltyProgramMember.Id,
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      LoyaltyPgmCurrencySubtypeId = purchaseSubtype.Id,
      CreditLoyaltyLedgerId = creditLedger.Id,
      DebitLoyaltyLedgerId = debitLedger.Id,
      ActionType = 'Debit',
      Points = 40
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(100, dto.earnedPointAmount);
    System.assertEquals(1, dto.earnedPointItems.size());
    System.assertEquals(100, dto.earnedPointItems[0].amount);
  }

  @IsTest
  static void test_getOrderNumView_saleEarnedPoints_excludePointRedeemCancelCredit() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalType redemptionReversalType = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1];
    JournalSubType purchaseSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchasePointSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '구매포인트',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 21,
      IsActive = true
    );
    insert purchasePointSubtype;

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDEXC'), uniq('SALEXC'));

    TransactionJournal accrualJournal = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, null, 0);
    accrualJournal.JournalSubTypeId = purchaseSubtype.Id;
    update accrualJournal;
    createLedger(accrualJournal.Id, 9200, 'Credit', purchasePointSubtype.Id);

    TransactionJournal pointRedeemCancelJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalType.Id,
      '81',
      50000
    );
    createLedger(pointRedeemCancelJournal.Id, 50000, 'Credit', purchasePointSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(9200, dto.earnedPointAmount);
    System.assertEquals(1, dto.earnedPointItems.size());
    System.assertEquals(9200, dto.earnedPointItems[0].amount);
  }

  @IsTest
  static void test_getOrderNumView_saleEarnedPoints_includeApiForcedCredit() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalSubType apiForcedCreditSubtype = new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualType.Id);
    insert apiForcedCreditSubtype;

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype eventPointSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '이벤트포인트',
      PointTypeCode__c = resolvePointTypeCode('06', '06'),
      UsagePriorityNumber = 22,
      IsActive = true
    );
    insert eventPointSubtype;

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDAPI'), uniq('SALEAPI'));

    TransactionJournal apiForcedCreditJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualType.Id,
      null,
      6000
    );
    apiForcedCreditJournal.JournalSubTypeId = apiForcedCreditSubtype.Id;
    update apiForcedCreditJournal;
    createLedger(apiForcedCreditJournal.Id, 6000, 'Credit', eventPointSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(6000, dto.earnedPointAmount);
    System.assertEquals(1, dto.earnedPointItems.size());
    System.assertEquals('이벤트포인트', dto.earnedPointItems[0].label);
    System.assertEquals(6000, dto.earnedPointItems[0].amount);
  }

  @IsTest
  static void test_getOrderNumView_saleEarnedPoints_includePromotionPointAccrual() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalSubType promotionPointSubtype = new JournalSubType(Name = 'Promotion Point Accrual', JournalTypeId = accrualType.Id);
    insert promotionPointSubtype;

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype eventPointSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '?대깽?명룷?명듃',
      PointTypeCode__c = resolvePointTypeCode('06', '06'),
      UsagePriorityNumber = 23,
      IsActive = true
    );
    insert eventPointSubtype;

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDPROMO'), uniq('SALEPROMO'));

    TransactionJournal promotionAccrualJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualType.Id,
      null,
      6000
    );
    promotionAccrualJournal.JournalSubTypeId = promotionPointSubtype.Id;
    update promotionAccrualJournal;
    createLedger(promotionAccrualJournal.Id, 6000, 'Credit', eventPointSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(6000, dto.earnedPointAmount);
    System.assertEquals(1, dto.earnedPointItems.size());
    System.assertEquals('?대깽?명룷?명듃', dto.earnedPointItems[0].label);
    System.assertEquals(6000, dto.earnedPointItems[0].amount);
  }

  @IsTest
  static void test_getOrderNumView_returnRestoredPoints_includePromotionPointAccrualReversal() {
    Order saleOrder = [
      SELECT Id, AccountId, Pricebook2Id, MemberNo__c, SaleNo__c, OriginalOrderId__c, EndDate
      FROM Order
      WHERE IsReductionOrder__c = FALSE AND SaleNo__c != NULL
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalType accrualReversalType = [SELECT Id FROM JournalType WHERE Name = 'Accrual Reversal' LIMIT 1];
    JournalSubType promotionAccrualSubtype = new JournalSubType(Name = 'Promotion Point Accrual', JournalTypeId = accrualType.Id);
    JournalSubType promotionReversalSubtype = new JournalSubType(Name = 'Promotion Point Accrual Reversal', JournalTypeId = accrualReversalType.Id);
    insert new List<JournalSubType>{ promotionAccrualSubtype, promotionReversalSubtype };

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype eventSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '?대깽?명룷?명듃',
      PointTypeCode__c = resolvePointTypeCode('06', '06'),
      UsagePriorityNumber = 24,
      IsActive = true
    );
    insert eventSubtype;

    String returnOrderKey = uniq('RETPO');
    Order returnOrder = new Order(
      Name = 'TEST-RETURN-PROMO',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = returnOrderKey,
      SaleNo__c = uniq('SALRPO'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, returnOrderKey);
    insert returnOrder;

    TransactionJournal sourcePromotionAccrual = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualType.Id,
      null,
      6000
    );
    sourcePromotionAccrual.JournalSubTypeId = promotionAccrualSubtype.Id;
    update sourcePromotionAccrual;
    LoyaltyLedger sourcePromotionLedger = createLedger(sourcePromotionAccrual.Id, 6000, 'Credit', eventSubtype.Id);

    TransactionJournal promotionReversalJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualReversalType.Id,
      null,
      6000
    );
    promotionReversalJournal.JournalSubTypeId = promotionReversalSubtype.Id;
    promotionReversalJournal.SaleId__c = returnOrder.Id;
    update promotionReversalJournal;
    LoyaltyLedger promotionReversalLedger = createLedger(promotionReversalJournal.Id, 6000, 'Debit', null);

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = loyaltyProgramMember.Id,
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      LoyaltyPgmCurrencySubtypeId = eventSubtype.Id,
      CreditLoyaltyLedgerId = sourcePromotionLedger.Id,
      DebitLoyaltyLedgerId = promotionReversalLedger.Id,
      ActionType = 'Debit',
      Points = 6000
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(returnOrder.Id);
    Test.stopTest();

    System.assertEquals(6000, dto.restoredPointAmount);
    System.assertEquals(1, dto.restoredPointItems.size());
    System.assertEquals(resolvePointTypeCode('06', '06'), dto.restoredPointItems[0].type);
    System.assertEquals(6000, dto.restoredPointItems[0].amount);
  }

  @IsTest
  static void test_getOrderNumView_saleEarnedPoints_excludeRestoredPurchaseAccrualCredit() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalSubType purchaseSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchasePointSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '구매포인트',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 21,
      IsActive = true
    );
    insert purchasePointSubtype;

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDRST'), uniq('SALRST'));

    TransactionJournal accrualJournal = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, null, 0);
    accrualJournal.JournalSubTypeId = purchaseSubtype.Id;
    update accrualJournal;
    createLedger(accrualJournal.Id, 100, 'Credit', purchasePointSubtype.Id);

    TransactionJournal restoredAccrualJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualType.Id,
      null,
      0
    );
    restoredAccrualJournal.JournalSubTypeId = purchaseSubtype.Id;
    restoredAccrualJournal.AdditionalNotes__c = 'Restore purchase accrual due to return deletion';
    update restoredAccrualJournal;
    createLedger(restoredAccrualJournal.Id, 40, 'Credit', purchasePointSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(100, dto.earnedPointAmount);
    System.assertEquals(1, dto.earnedPointItems.size());
    System.assertEquals(100, dto.earnedPointItems[0].amount);
  }

  @IsTest
  static void test_getOrderNumView_saleEarnedPoints_excludeRestoredPromotionAccrualCredit() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalSubType purchaseSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchasePointSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'PromotionExclusionPurchase',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 22,
      IsActive = true
    );
    LoyaltyPgmCurrencySubtype promotionPointSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'PromotionExclusionEvent',
      PointTypeCode__c = resolvePointTypeCode('06', '06'),
      UsagePriorityNumber = 23,
      IsActive = true
    );
    insert new List<LoyaltyPgmCurrencySubtype>{ purchasePointSubtype, promotionPointSubtype };

    JournalSubType promotionSubtype = new JournalSubType(Name = 'Promotion Point Accrual', JournalTypeId = accrualType.Id);
    insert promotionSubtype;

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDRSP'), uniq('SALRSP'));

    TransactionJournal accrualJournal = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, null, 0);
    accrualJournal.JournalSubTypeId = purchaseSubtype.Id;
    update accrualJournal;
    createLedger(accrualJournal.Id, 100, 'Credit', purchasePointSubtype.Id);

    TransactionJournal restoredPromotionJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualType.Id,
      null,
      0
    );
    restoredPromotionJournal.JournalSubTypeId = promotionSubtype.Id;
    restoredPromotionJournal.AdditionalNotes__c = 'Restore promotion point accrual due to return deletion';
    update restoredPromotionJournal;
    createLedger(restoredPromotionJournal.Id, 40, 'Credit', promotionPointSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(100, dto.earnedPointAmount);
    System.assertEquals(1, dto.earnedPointItems.size());
    System.assertEquals(100, dto.earnedPointItems[0].amount);
  }

  @IsTest
  static void test_getOrderNumView_orderDepositReversal_reducesOrderDepositAmount() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalSubType orderDepositSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Order Deposit' LIMIT 1];
    JournalSubType orderDepositReversalSubType = [SELECT Id FROM JournalSubType WHERE Name = 'Order Deposit Reversal' LIMIT 1];

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDODR'), uniq('SALEODR'));

    TransactionJournal orderDeposit = createTJByTypeName(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit', '01', 900);
    orderDeposit.JournalSubTypeId = orderDepositSubType.Id;
    update orderDeposit;

    TransactionJournal orderDepositReversal = createTJByTypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      '01',
      350
    );
    orderDepositReversal.JournalSubTypeId = orderDepositReversalSubType.Id;
    update orderDepositReversal;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(1250, dto.orderCashAmount);
    System.assertEquals(1250, dto.orderDepositTotalAmount);
  }

  @IsTest
  static void test_orderDetailDto_deletedReturn_zeroesRestoredPointSummary() {
    Order saleOrder = [
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
        TotalAmount,
        ActualPaymentAmount__c,
        Status,
        EffectiveDate,
        EndDate
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];

    Order deletedReturnOrder = new Order(
      SaleNo__c = uniq('SALEDEL'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'returnDeleted',
      IsReductionOrder__c = true,
      IsDeleted__c = true,
      DeleteDateTime__c = System.now()
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      deletedReturnOrder,
      new List<Order>{ deletedReturnOrder },
      new List<Order>{ saleOrder },
      new List<OrderItem>(),
      new List<OrderItem>{ new OrderItem(Quantity = -1) },
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertEquals(0, dto.restoredPointAmount);
    System.assertEquals(0, dto.restoredPointItems.size());
    System.assertEquals(1, dto.returnQuantity);
  }

  @IsTest
  static void test_getOrderNumView_deletedReturnOrder_showsNegativeRestoredPoints() {
    Order saleOrder = [
      SELECT Id, SaleNo__c, AccountId, Pricebook2Id, MemberNo__c, Status
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualReversalType = [SELECT Id FROM JournalType WHERE Name = 'Accrual Reversal' LIMIT 1];
    JournalSubType cancelSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Cancel Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'DeletedReturnPurchase',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 91,
      IsActive = true
    );
    insert purchaseSubtype;

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order deletedReturnOrder = new Order(
      Name = 'RETURN-DELETED-POINT',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = 'returnDeleted',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('SALERD'),
      OriginalOrderId__c = saleOrder.Id,
      MemberNo__c = saleOrder.MemberNo__c,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(deletedReturnOrder, saleOrder.AccountId, 0, uniq('RETD'));
    deletedReturnOrder.Status = 'returnDeleted';
    insert deletedReturnOrder;

    TransactionJournal cancelJournal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualReversalType.Id,
      '81',
      0
    );
    cancelJournal.JournalSubTypeId = cancelSubtype.Id;
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (journalFieldMap.containsKey('SaleId__c')) {
      cancelJournal.put('SaleId__c', deletedReturnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      cancelJournal.put('OrderId__c', deletedReturnOrder.Id);
    }
    update cancelJournal;

    createLedger(cancelJournal.Id, -57000, 'Debit', purchaseSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(deletedReturnOrder.Id);
    Test.stopTest();

    System.assertEquals(deletedReturnOrder.SaleNo__c, dto.returnNo);
    System.assertEquals(-57000, dto.restoredPointAmount);
    System.assertEquals(1, dto.restoredPointItems.size());
    System.assertEquals(-57000, dto.restoredPointItems[0].amount);
  }

  @IsTest
  static void test_orderDetailDto_deletedSale_showsNegativeSalePaymentsAndEarnedPoints() {
    Order saleOrder = [
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
        TotalAmount,
        ActualPaymentAmount__c,
        Status,
        EffectiveDate,
        EndDate
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];

    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalSubType purchaseSubtype = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype saleDeletedSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'DeletedSalePoint',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 92,
      IsActive = true
    );
    insert saleDeletedSubtype;

    TransactionJournal accrualJournal = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, '81', 0);
    accrualJournal.JournalSubTypeId = purchaseSubtype.Id;
    update accrualJournal;

    createLedger(accrualJournal.Id, 700, 'Credit', saleDeletedSubtype.Id);

    List<OrderItem> orderItems = [
      SELECT Id, Quantity, TotalPrice, Product2.Name
      FROM OrderItem
      WHERE OrderId = :saleOrder.Id
    ];
    List<TransactionJournal> journals = [
      SELECT Id, PaymentMethod, TransactionAmount, JournalType.Name, Order.StoreCode__r.StoreCode__c
      FROM TransactionJournal
      WHERE OrderId = :saleOrder.Id
    ];

    saleOrder.Status = 'saleDeleted';

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      null,
      new List<Order>(),
      new List<Order>{ saleOrder },
      orderItems,
      new List<OrderItem>(),
      journals
    );
    Test.stopTest();

    System.assertEquals(-1000, dto.saleCashAmount);
    System.assertEquals(-500, dto.saleCardAmount);
    System.assertEquals(-200, dto.saleCouponAmount);
    System.assertEquals(-300, dto.salePointAmount);
    System.assertEquals(-2000, dto.saleDepositTotalAmount);
    System.assertEquals(-700, dto.earnedPointAmount);
    System.assertEquals(1, dto.earnedPointItems.size());
    System.assertEquals(-700, dto.earnedPointItems[0].amount);
  }

  @IsTest
  static void test_orderDetailDto_returnPaymentSummary_usesReturnOrderIds() {
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
        TotalAmount,
        ActualPaymentAmount__c,
        Status,
        EffectiveDate,
        EndDate
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    String returnKey = uniq('RPD');
    Order returnLikeOrder = new Order(
      Name = 'RETURN-LIKE',
      AccountId = baseOrder.AccountId,
      Pricebook2Id = baseOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('SALERPD'),
      MemberNo__c = baseOrder.MemberNo__c,
      OriginalOrderId__c = baseOrder.Id,
      IsReductionOrder__c = true
    );
    baseOrder.Status = resolveOrderStatus('Activated', baseOrder.Status);
    update baseOrder;
    applyOrderDefaults(returnLikeOrder, baseOrder.AccountId, 0, returnKey);
    insert returnLikeOrder;

    Id saleDepositReversalSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit Reversal' LIMIT 1].Id;

    TransactionJournal refundCash = createTJByTypeName(
      returnLikeOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      '01',
      700
    );
    refundCash.JournalSubTypeId = saleDepositReversalSubTypeId;
    update refundCash;

    TransactionJournal refundCard = createTJByTypeName(
      returnLikeOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      '03',
      300
    );
    refundCard.JournalSubTypeId = saleDepositReversalSubTypeId;
    update refundCard;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      baseOrder,
      baseOrder,
      returnLikeOrder,
      new List<Order>{ returnLikeOrder },
      new List<Order>{ baseOrder },
      new List<OrderItem>(),
      new List<OrderItem>{ new OrderItem(Quantity = -2) },
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertEquals(returnLikeOrder.SaleNo__c, dto.returnNo);
    System.assertEquals(700, dto.refundCashAmount);
    System.assertEquals(300, dto.refundCardAmount);
    System.assertEquals(1000, dto.returnDepositTotalAmount);
    System.assertEquals(2, dto.returnQuantity);
  }

  @IsTest
  static void test_orderDetailDto_returnPaymentSummary_usesLinkedSaleDepositReversal() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assert(true);
      return;
    }

    Order baseOrder = [
      SELECT
        Id,
        AccountId,
        Account.Name,
        Account.StoreCode__c,
        Pricebook2Id,
        MemberNo__c,
        Status,
        SaleNo__c,
        EffectiveDate,
        EndDate,
        OrderNo__c,
        OrderReferenceNumber,
        OrderStatus__c,
        TotalAmount,
        ActualPaymentAmount__c
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id redemptionReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1].Id;

    baseOrder.Status = resolveOrderStatus('Activated', baseOrder.Status);
    update baseOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-LINKED-REFUND',
      AccountId = baseOrder.AccountId,
      Pricebook2Id = baseOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('SALERLINK'),
      MemberNo__c = baseOrder.MemberNo__c,
      OriginalOrderId__c = baseOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, baseOrder.AccountId, 0, uniq('RLINK'));
    insert returnOrder;

    Id saleDepositReversalSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit Reversal' LIMIT 1].Id;
    Id couponRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem Cancel' LIMIT 1].Id;
    Id pointRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Point Redeem Cancel' LIMIT 1].Id;
    TransactionJournal linkedRefundCash = createTJByTypeName(
      baseOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      '01',
      480
    );
    linkedRefundCash.JournalSubTypeId = saleDepositReversalSubTypeId;
    if (journalFieldMap.containsKey('SaleId__c')) {
      linkedRefundCash.put('SaleId__c', returnOrder.Id);
    } else {
      linkedRefundCash.put('OrderId__c', returnOrder.Id);
    }
    update linkedRefundCash;

    TransactionJournal linkedCouponCancel = createTJ(
      baseOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '90',
      120
    );
    linkedCouponCancel.JournalSubTypeId = couponRedeemCancelSubTypeId;
    linkedCouponCancel.Status = 'Processed';
    if (journalFieldMap.containsKey('SaleId__c')) {
      linkedCouponCancel.put('SaleId__c', returnOrder.Id);
    }
    update linkedCouponCancel;

    TransactionJournal linkedPointCancel = createTJ(
      baseOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '81',
      340
    );
    linkedPointCancel.JournalSubTypeId = pointRedeemCancelSubTypeId;
    linkedPointCancel.Status = 'Processed';
    if (journalFieldMap.containsKey('SaleId__c')) {
      linkedPointCancel.put('SaleId__c', returnOrder.Id);
    }
    update linkedPointCancel;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(baseOrder.Id);
    Test.stopTest();

    System.assertEquals(480, dto.refundCashAmount);
    System.assertEquals(120, dto.refundCouponAmount);
    System.assertEquals(340, dto.refundPointAmount);
    System.assertEquals(940, dto.returnDepositTotalAmount);
    System.assertEquals(true, dto.saleHasDepositCancellation);
    System.assertEquals(true, dto.returnHasDepositCancellation);
  }

  @IsTest
  static void test_getOrderNumView_returnPage_limitsRefundsToCurrentReturnOrder() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assert(true);
      return;
    }

    Order saleOrder = [
      SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id depositReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit Reversal' LIMIT 1].Id;
    Id redemptionReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1].Id;
    Id saleDepositReversalSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit Reversal' LIMIT 1].Id;
    Id couponRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem Cancel' LIMIT 1].Id;
    Id pointRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Point Redeem Cancel' LIMIT 1].Id;

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order currentReturnOrder = new Order(
      Name = 'RETURN-CURRENT',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETNOW'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(currentReturnOrder, saleOrder.AccountId, 0, uniq('RTCUR'));
    insert currentReturnOrder;

    Order otherReturnOrder = new Order(
      Name = 'RETURN-OTHER',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETOTH'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(otherReturnOrder, saleOrder.AccountId, 0, uniq('RTOTH'));
    insert otherReturnOrder;

    TransactionJournal currentRefundCash = createTJ(
      currentReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      depositReversalTypeId,
      '01',
      700
    );
    currentRefundCash.JournalSubTypeId = saleDepositReversalSubTypeId;
    update currentRefundCash;

    TransactionJournal currentCouponCancel = createTJ(
      currentReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '90',
      120
    );
    currentCouponCancel.JournalSubTypeId = couponRedeemCancelSubTypeId;
    currentCouponCancel.Status = 'Processed';
    update currentCouponCancel;

    TransactionJournal currentPointCancel = createTJ(
      currentReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '81',
      340
    );
    currentPointCancel.JournalSubTypeId = pointRedeemCancelSubTypeId;
    currentPointCancel.Status = 'Processed';
    update currentPointCancel;

    TransactionJournal otherRefundCash = createTJ(
      otherReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      depositReversalTypeId,
      '01',
      480
    );
    otherRefundCash.JournalSubTypeId = saleDepositReversalSubTypeId;
    update otherRefundCash;

    TransactionJournal otherPointCancel = createTJ(
      otherReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '81',
      260
    );
    otherPointCancel.JournalSubTypeId = pointRedeemCancelSubTypeId;
    otherPointCancel.Status = 'Processed';
    update otherPointCancel;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(currentReturnOrder.Id);
    Test.stopTest();

    System.assertEquals(currentReturnOrder.SaleNo__c, dto.returnNo);
    System.assertEquals(700, dto.refundCashAmount);
    System.assertEquals(120, dto.refundCouponAmount);
    System.assertEquals(340, dto.refundPointAmount);
    System.assertEquals(1160, dto.returnDepositTotalAmount);
    System.assertEquals(true, dto.returnHasDepositCancellation);
  }

  @IsTest
  static void test_getOrderNumView_withoutDepositReversal_doesNotFlagDepositCancellation() {
    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-NO-DEPOSIT-CANCEL',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('SALENOD'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RNDC'));
    insert returnOrder;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(false, dto.saleHasDepositCancellation);
    System.assertEquals(false, dto.returnHasDepositCancellation);
  }

  @IsTest
  static void test_getOrderNumView_salePage_accumulatesReturnPointRefunds_withDeletedReturnOffsets() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assert(true);
      return;
    }

    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id redemptionReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1].Id;
    Id pointRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Point Redeem Cancel' LIMIT 1].Id;

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order deletedReturnOrder = new Order(
      Name = 'RETURN-DELETED-OFFSET',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETDEL'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true,
      IsDeleted__c = true,
      DeleteDateTime__c = System.now()
    );
    applyOrderDefaults(deletedReturnOrder, saleOrder.AccountId, 0, uniq('RTDEL'));
    insert deletedReturnOrder;

    Order activeReturnOrder = new Order(
      Name = 'RETURN-ACTIVE-OFFSET',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETACT'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(activeReturnOrder, saleOrder.AccountId, 0, uniq('RTACT'));
    insert activeReturnOrder;

    TransactionJournal deletedReturnPointCancel = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '81',
      500
    );
    deletedReturnPointCancel.JournalSubTypeId = pointRedeemCancelSubTypeId;
    deletedReturnPointCancel.Status = 'Processed';
    if (journalFieldMap.containsKey('SaleId__c')) {
      deletedReturnPointCancel.put('SaleId__c', deletedReturnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      deletedReturnPointCancel.put('OrderId__c', deletedReturnOrder.Id);
    }
    update deletedReturnPointCancel;

    TransactionJournal activeReturnPointCancel = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '81',
      200
    );
    activeReturnPointCancel.JournalSubTypeId = pointRedeemCancelSubTypeId;
    activeReturnPointCancel.Status = 'Processed';
    if (journalFieldMap.containsKey('SaleId__c')) {
      activeReturnPointCancel.put('SaleId__c', activeReturnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      activeReturnPointCancel.put('OrderId__c', activeReturnOrder.Id);
    }
    update activeReturnPointCancel;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(700, dto.refundPointAmount);
    System.assertEquals(700, dto.returnDepositTotalAmount);
  }

  @IsTest
  static void test_getOrderNumView_deletedReturnPage_showsNegativeRefundAmounts() {
    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id depositReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit Reversal' LIMIT 1].Id;
    Id redemptionReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1].Id;
    Id saleDepositReversalSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit Reversal' LIMIT 1].Id;
    Id couponRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem Cancel' LIMIT 1].Id;
    Id pointRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Point Redeem Cancel' LIMIT 1].Id;

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order deletedReturnOrder = new Order(
      Name = 'RETURN-DELETED-REFUND',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = 'returnDeleted',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETREFDEL'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true,
      IsDeleted__c = true,
      DeleteDateTime__c = System.now()
    );
    applyOrderDefaults(deletedReturnOrder, saleOrder.AccountId, 0, uniq('RTRFD'));
    insert deletedReturnOrder;

    TransactionJournal refundCash = createTJ(
      deletedReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      depositReversalTypeId,
      '01',
      700
    );
    refundCash.JournalSubTypeId = saleDepositReversalSubTypeId;
    update refundCash;

    TransactionJournal refundCoupon = createTJ(
      deletedReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '90',
      120
    );
    refundCoupon.JournalSubTypeId = couponRedeemCancelSubTypeId;
    refundCoupon.Status = 'Processed';
    update refundCoupon;

    TransactionJournal refundPoint = createTJ(
      deletedReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '81',
      340
    );
    refundPoint.JournalSubTypeId = pointRedeemCancelSubTypeId;
    refundPoint.Status = 'Processed';
    update refundPoint;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(deletedReturnOrder.Id);
    Test.stopTest();

    System.assertEquals(deletedReturnOrder.SaleNo__c, dto.returnNo);
    System.assertEquals(-700, dto.refundCashAmount);
    System.assertEquals(-120, dto.refundCouponAmount);
    System.assertEquals(-340, dto.refundPointAmount);
    System.assertEquals(-1160, dto.returnDepositTotalAmount);
  }

  @IsTest
  static void test_getOrderNumView_salePage_includesDeletedReturnRefunds() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assert(true);
      return;
    }

    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id depositReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit Reversal' LIMIT 1].Id;
    Id saleDepositReversalSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit Reversal' LIMIT 1].Id;

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order deletedReturnOrder = new Order(
      Name = 'RETURN-DELETED-CASH',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = 'returnDeleted',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETDCASH'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true,
      IsDeleted__c = true,
      DeleteDateTime__c = System.now()
    );
    applyOrderDefaults(deletedReturnOrder, saleOrder.AccountId, 0, uniq('RTDCS'));
    insert deletedReturnOrder;

    TransactionJournal deletedRefundCash = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      depositReversalTypeId,
      '01',
      480
    );
    deletedRefundCash.JournalSubTypeId = saleDepositReversalSubTypeId;
    if (journalFieldMap.containsKey('SaleId__c')) {
      deletedRefundCash.put('SaleId__c', deletedReturnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      deletedRefundCash.put('OrderId__c', deletedReturnOrder.Id);
    }
    update deletedRefundCash;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(480, dto.refundCashAmount);
    System.assertEquals(480, dto.returnDepositTotalAmount);
  }

  @IsTest
  static void test_returnPoints_includeLinkedSaleReturnCredits() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assert(true);
      return;
    }

    Order saleOrder = [
      SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalType redemptionReversalType = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '援щℓ?ъ씤??',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 61,
      IsActive = true
    );
    insert purchaseSubtype;

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-LINKED-POINT',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('SALERPNT'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RPNT'));
    insert returnOrder;

    Id purchaseAccrualSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1].Id;
    TransactionJournal linkedPurchaseAccrual = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualType.Id,
      '81',
      0
    );
    linkedPurchaseAccrual.JournalSubTypeId = purchaseAccrualSubTypeId;
    if (journalFieldMap.containsKey('SaleId__c')) {
      linkedPurchaseAccrual.put('SaleId__c', returnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      linkedPurchaseAccrual.put('OrderId__c', returnOrder.Id);
    }
    update linkedPurchaseAccrual;
    createLedger(linkedPurchaseAccrual.Id, 19200, 'Credit', purchaseSubtype.Id);

    TransactionJournal linkedPointRedeemCancel = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalType.Id,
      '81',
      0
    );
    if (journalFieldMap.containsKey('SaleId__c')) {
      linkedPointRedeemCancel.put('SaleId__c', returnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      linkedPointRedeemCancel.put('OrderId__c', returnOrder.Id);
    }
    update linkedPointRedeemCancel;
    createLedger(linkedPointRedeemCancel.Id, 20000, 'Credit', purchaseSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(0, dto.restoredPointAmount);
    System.assertEquals(0, dto.restoredPointItems.size());
  }

  @IsTest
  static void test_getOrderNumView_returnPage_countsLinkedRestoredPurchaseAccrualCredit() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assert(true);
      return;
    }

    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalSubType purchaseSubtypeRecord = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];
    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'LinkedRestorePurchase',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 94,
      IsActive = true
    );
    insert purchaseSubtype;

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-RESTORE-LINK',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETREST'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RTREST'));
    insert returnOrder;

    TransactionJournal restoredAccrual = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, null, 0);
    restoredAccrual.JournalSubTypeId = purchaseSubtypeRecord.Id;
    restoredAccrual.AdditionalNotes__c = 'Restore purchase accrual due to return deletion';
    if (journalFieldMap.containsKey('SaleId__c')) {
      restoredAccrual.put('SaleId__c', returnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      restoredAccrual.put('OrderId__c', returnOrder.Id);
    }
    update restoredAccrual;
    createLedger(restoredAccrual.Id, 4500, 'Credit', purchaseSubtype.Id);

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(returnOrder.Id);
    Test.stopTest();

    System.assertEquals(4500, dto.restoredPointAmount);
    System.assertEquals(1, dto.restoredPointItems.size());
    System.assertEquals(resolvePointTypeCode('01', '01'), dto.restoredPointItems[0].type);
    System.assertEquals(4500, dto.restoredPointItems[0].amount);
  }

  @IsTest
  static void test_getOrderNumView_withChildSales_populatesSaleRecords() {
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
        TotalAmount,
        ActualPaymentAmount__c,
        Status,
        EffectiveDate,
        EndDate
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];

    Order childSaleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 1234, uniq('ORDPUB'), uniq('SALEPUB'));

    createTJByTypeName(childSaleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, 'Deposit', '03', 1234);
    childSaleOrder = [
      SELECT Id, SaleNo__c, Status, EndDate, EffectiveDate, ActualPaymentAmount__c, Account.Name, Account.StoreCode__c
      FROM Order
      WHERE Id = :childSaleOrder.Id
      LIMIT 1
    ];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      baseOrder,
      baseOrder,
      null,
      new List<Order>(),
      new List<Order>{ childSaleOrder },
      new List<OrderItem>(),
      new List<OrderItem>(),
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assert(dto.saleRecords.size() > 0);
    System.assertEquals(childSaleOrder.SaleNo__c, dto.saleRecords[0].saleNo);
  }

  @IsTest
  static void test_returnOrder_branch() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order LIMIT 1];
    baseOrder.Status = resolveOrderStatus('Activated', baseOrder.Status);
    update baseOrder;

    String returnKey = uniq('RETBR');
    Order returnOrder = new Order(
      Name = 'RETURN-BRANCH',
      AccountId = baseOrder.AccountId,
      Pricebook2Id = baseOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = 'RET-' + returnKey,
      SaleNo__c = 'RETSALE-' + returnKey,
      MemberNo__c = baseOrder.MemberNo__c,
      OriginalOrderId__c = baseOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, baseOrder.AccountId, 0, returnKey);

    insert returnOrder;

    Test.startTest();
    OrderNumViewController.getOrderNumView(returnOrder.Id);
    Test.stopTest();
  }

  @IsTest
  static void test_empty_scenario() {
    Account acc = new Account(Name = 'EMPTY');
    insert acc;

    Order o = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert o;

    Test.startTest();
    OrderNumViewController.getOrderNumView(o.Id);
    Test.stopTest();
  }
  @IsTest
  static void test_resolveStoreCode_fallback() {
    Account acc = new Account(Name = 'Fallback Store', StoreCode__c = 'STORE-999');
    insert acc;

    // primaryOrder = null 상황 만들기 위해
    Order fallbackOrder = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today(), OrderNo__c = 'TEST-FALLBACK');
    insert fallbackOrder;

    // 👇 핵심: primaryOrder = null 넣는 구조 강제
    Test.startTest();

    // 내부적으로 resolveStoreCode 타게 만들기 위해
    OrderNumViewController.getOrderNumView(fallbackOrder.Id);

    Test.stopTest();
  }
  @IsTest
  static void test_testVisibleGetActiveReturnOrderCount_filtersDeletedOrders() {
    List<Order> returnOrders = new List<Order>{
      null,
      new Order(SaleNo__c = 'RET-ACTIVE'),
      new Order(SaleNo__c = 'RET-DELETED', IsDeleted__c = true),
      new Order(SaleNo__c = 'RET-DELETED-DT', DeleteDateTime__c = System.now())
    };

    Integer activeCount = OrderNumViewController.testVisibleGetActiveReturnOrderCount(returnOrders);

    System.assertEquals(1, activeCount);
  }

  @IsTest
  static void test_resolveStoreCode_branches() {
    // 1️⃣ fallbackOrder만 있는 케이스
    Account acc = new Account(Name = 'Fallback Store', StoreCode__c = 'STORE-999');
    insert acc;

    Order fallbackOrder = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today(), OrderNo__c = 'ORD-FALLBACK');
    insert fallbackOrder;
    fallbackOrder = [SELECT Id, Account.Name, Account.StoreCode__c FROM Order WHERE Id = :fallbackOrder.Id LIMIT 1];

    // 🔥 핵심: fallback branch 강제 실행
    String result1 = OrderNumViewController.resolveStoreCode(null, fallbackOrder);

    System.assert(result1 != null);

    // 2️⃣ Account.Name 없는 경우 → StoreCode 타는 분기
    Account acc2 = new Account(Name = 'STORE-888', StoreCode__c = 'STORE-888');
    insert acc2;

    Order fallbackOrder2 = new Order(AccountId = acc2.Id, Status = 'Draft', EffectiveDate = Date.today(), OrderNo__c = 'ORD-FALLBACK2');
    insert fallbackOrder2;
    fallbackOrder2 = [SELECT Id, Account.Name, Account.StoreCode__c FROM Order WHERE Id = :fallbackOrder2.Id LIMIT 1];

    String result2 = OrderNumViewController.resolveStoreCode(null, fallbackOrder2);

    System.assert(result2 != null);

    // 3️⃣ 둘 다 null → 마지막 return null
    String result3 = OrderNumViewController.resolveStoreCode(null, null);

    System.assertEquals(null, result3);
  }

  @IsTest
  static void test_resolveStoreCode_primaryStoreCodeBranch() {
    Account primaryStore = new Account(Name = 'Primary Store', StoreCode__c = 'STORE-PRIMARY');
    insert primaryStore;

    Order primaryOrder = new Order();
    primaryOrder.putSObject('Account', new Account(StoreCode__c = primaryStore.StoreCode__c));

    String result = OrderNumViewController.resolveStoreCode(primaryOrder, null);

    System.assertEquals(primaryStore.Name, result);
  }

  @IsTest
  static void test_testVisibleGetDisplayOrderDate_branches() {
    Date saleEffectiveDate = Date.today().addDays(-1);

    Datetime resolvedFromSale = OrderNumViewController.getDisplayOrderDate(null, new Order(EffectiveDate = saleEffectiveDate));
    Datetime resolvedNull = OrderNumViewController.getDisplayOrderDate(null, null);

    System.assertEquals(saleEffectiveDate, resolvedFromSale.date());
    System.assertEquals(null, resolvedNull);
  }

  @IsTest
  static void test_testVisibleGetDisplayOrderNumber_andResolveTotals_branches() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 120, uniq('ORDDSP'), uniq('SALEDSP'));
    saleOrder.OrderNo__c = uniq('DSPNO');
    saleOrder.ActualPaymentAmount__c = 321;
    update saleOrder;
    saleOrder = [SELECT Id, OrderNo__c, SaleNo__c, TotalAmount, ActualPaymentAmount__c FROM Order WHERE Id = :saleOrder.Id];
    Decimal queriedTotalAmount = saleOrder.TotalAmount == null ? 0 : saleOrder.TotalAmount;

    System.assertEquals(saleOrder.OrderNo__c, OrderNumViewController.testVisibleGetDisplayOrderNumber(null, saleOrder));
    System.assertEquals(null, OrderNumViewController.testVisibleGetDisplayOrderNumber(null, null));
    System.assertEquals(queriedTotalAmount, OrderNumViewController.testVisibleResolveOrderTotalAmount(null, saleOrder));
    System.assertEquals(321, OrderNumViewController.testVisibleResolveSaleTotalAmount(saleOrder));
    System.assertEquals(0, OrderNumViewController.testVisibleResolveSaleTotalAmount(new Order()));
  }

  @IsTest
  static void test_testVisibleGetDisplayOrderTotalAmount_branches() {
    Order displayOrder = [SELECT TotalAmount FROM Order WHERE TotalAmount != NULL LIMIT 1];
    Order saleOrder = [SELECT TotalAmount FROM Order WHERE TotalAmount != NULL ORDER BY CreatedDate DESC LIMIT 1];
    Order zeroDisplayOrder = new Order();
    Order zeroSaleOrder = new Order();

    Decimal fromDisplay = OrderNumViewController.getDisplayOrderTotalAmount(displayOrder, saleOrder, 999);
    Decimal fromSale = OrderNumViewController.getDisplayOrderTotalAmount(zeroDisplayOrder, saleOrder, 999);
    Decimal fromFallback = OrderNumViewController.getDisplayOrderTotalAmount(zeroDisplayOrder, zeroSaleOrder, 999);
    Decimal fromZeroFallback = OrderNumViewController.getDisplayOrderTotalAmount(null, null, null);

    System.assertEquals(displayOrder.TotalAmount, fromDisplay);
    System.assertEquals(saleOrder.TotalAmount, fromSale);
    System.assertEquals(999, fromFallback);
    System.assertEquals(0, fromZeroFallback);
  }

  @IsTest
  static void test_testVisibleGetActiveReturnOrderCount_withNullList_returnsZero() {
    System.assertEquals(0, OrderNumViewController.testVisibleGetActiveReturnOrderCount(null));
  }

  @IsTest
  static void test_testVisibleGetRelatedSaleOrderCount_branches() {
    Order baseOrder = [
      SELECT Id, AccountId, Pricebook2Id, MemberNo__c, OriginalOrderId__c, SaleNo__c, Status
      FROM Order
      WHERE IsReductionOrder__c = FALSE
      LIMIT 1
    ];
    System.assertEquals(0, OrderNumViewController.testVisibleGetRelatedSaleOrderCount(null));
    System.assert(OrderNumViewController.testVisibleGetRelatedSaleOrderCount(baseOrder) >= 1);

    baseOrder.Status = resolveOrderStatus('Activated', baseOrder.Status);
    update baseOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-REL-COVERAGE',
      AccountId = baseOrder.AccountId,
      Pricebook2Id = baseOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETREL'),
      MemberNo__c = baseOrder.MemberNo__c,
      OriginalOrderId__c = baseOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, baseOrder.AccountId, 0, uniq('ORDRETREL'));
    insert returnOrder;

    System.assertEquals(0, OrderNumViewController.testVisibleGetRelatedSaleOrderCount(returnOrder));
  }

  @IsTest
  static void test_testVisibleGetOriginalSalePaymentSummaryAmount_includesOnlyOriginalSalePayments() {
    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id depositTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit' LIMIT 1].Id;
    Id redemptionTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1].Id;
    Id saleDepositSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit' LIMIT 1].Id;
    Id pointDebitSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Point Debit' LIMIT 1].Id;
    Id couponRedeemSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem' LIMIT 1].Id;

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 0, uniq('ORDOSP'), uniq('SALEOSP'));

    TransactionJournal saleDeposit = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, depositTypeId, '01', 900);
    saleDeposit.JournalSubTypeId = saleDepositSubTypeId;
    update saleDeposit;

    TransactionJournal pointDebit = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionTypeId, '81', 100);
    pointDebit.JournalSubTypeId = pointDebitSubTypeId;
    pointDebit.Status = 'Processed';
    update pointDebit;

    TransactionJournal couponRedeem = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionTypeId, '90', 50);
    couponRedeem.JournalSubTypeId = couponRedeemSubTypeId;
    couponRedeem.Status = 'Processed';
    update couponRedeem;

    System.assertEquals(900, OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'cash'));
    System.assertEquals(100, OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'point'));
    System.assertEquals(50, OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'coupon'));
    System.assertEquals(1050, OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'total'));
  }

  @IsTest
  static void test_testVisibleGetReturnEventPaymentSummaryAmount_andRestoredPointAmount() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assert(true);
      return;
    }

    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id depositReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit Reversal' LIMIT 1].Id;
    Id accrualTypeId = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1].Id;
    Id redemptionTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1].Id;
    Id redemptionReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1].Id;
    Id accrualReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Accrual Reversal' LIMIT 1].Id;
    Id saleDepositReversalSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit Reversal' LIMIT 1].Id;
    Id purchaseAccrualSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1].Id;
    Id apiForcedDebitSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Api Forced Debit' LIMIT 1].Id;
    Id couponRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem Cancel' LIMIT 1].Id;
    Id pointRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Point Redeem Cancel' LIMIT 1].Id;
    Id cancelPurchaseAccrualSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Cancel Purchase Accrual' LIMIT 1].Id;

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];
    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'CoveragePurchase',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 96,
      IsActive = true
    );
    LoyaltyPgmCurrencySubtype ecoSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'CoverageEco',
      PointTypeCode__c = resolvePointTypeCode('05', '05'),
      UsagePriorityNumber = 95,
      IsActive = true
    );
    insert new List<LoyaltyPgmCurrencySubtype>{ purchaseSubtype, ecoSubtype };

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-COVERAGE',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETCOV'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RTCOV'));
    insert returnOrder;

    TransactionJournal refundCash = createTJ(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      depositReversalTypeId,
      '01',
      700
    );
    refundCash.JournalSubTypeId = saleDepositReversalSubTypeId;
    update refundCash;

    TransactionJournal refundCoupon = createTJ(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '90',
      120
    );
    refundCoupon.JournalSubTypeId = couponRedeemCancelSubTypeId;
    refundCoupon.Status = 'Processed';
    update refundCoupon;

    TransactionJournal refundPoint = createTJ(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '81',
      340
    );
    refundPoint.JournalSubTypeId = pointRedeemCancelSubTypeId;
    refundPoint.Status = 'Processed';
    update refundPoint;

    TransactionJournal cancelAccrual = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualReversalTypeId,
      '81',
      0
    );
    cancelAccrual.JournalSubTypeId = cancelPurchaseAccrualSubTypeId;
    if (journalFieldMap.containsKey('SaleId__c')) {
      cancelAccrual.put('SaleId__c', returnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      cancelAccrual.put('OrderId__c', returnOrder.Id);
    }
    update cancelAccrual;
    createLedger(cancelAccrual.Id, -570, 'Debit', purchaseSubtype.Id);

    TransactionJournal sourceEcoAccrual = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualTypeId, null, 0);
    sourceEcoAccrual.JournalSubTypeId = purchaseAccrualSubTypeId;
    update sourceEcoAccrual;
    LoyaltyLedger sourceEcoLedger = createLedger(sourceEcoAccrual.Id, 150, 'Credit', ecoSubtype.Id);

    TransactionJournal apiForcedDebit = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionTypeId, null, 150);
    apiForcedDebit.JournalSubTypeId = apiForcedDebitSubTypeId;
    if (journalFieldMap.containsKey('SaleId__c')) {
      apiForcedDebit.put('SaleId__c', returnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      apiForcedDebit.put('OrderId__c', returnOrder.Id);
    }
    update apiForcedDebit;
    LoyaltyLedger ecoDebitLedger = createLedger(apiForcedDebit.Id, -150, 'Debit', null);

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = loyaltyProgramMember.Id,
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      LoyaltyPgmCurrencySubtypeId = ecoSubtype.Id,
      CreditLoyaltyLedgerId = sourceEcoLedger.Id,
      DebitLoyaltyLedgerId = ecoDebitLedger.Id,
      ActionType = 'Debit',
      Points = 150
    );

    System.assertEquals(700, OrderNumViewController.testVisibleGetReturnEventPaymentSummaryAmount(saleOrder, returnOrder, 'cash'));
    System.assertEquals(120, OrderNumViewController.testVisibleGetReturnEventPaymentSummaryAmount(saleOrder, returnOrder, 'coupon'));
    System.assertEquals(340, OrderNumViewController.testVisibleGetReturnEventPaymentSummaryAmount(saleOrder, returnOrder, 'point'));
    System.assertEquals(1160, OrderNumViewController.testVisibleGetReturnEventPaymentSummaryAmount(saleOrder, returnOrder, 'total'));
    System.assertEquals(720, OrderNumViewController.testVisibleGetReturnOrderRestoredPointAmount(saleOrder, returnOrder));
  }

  @IsTest
  static void test_testVisibleHasDepositCancellation_branches() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assertEquals(false, OrderNumViewController.testVisibleHasDepositCancellation(null, null));
      return;
    }

    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id depositReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit Reversal' LIMIT 1].Id;
    Id saleDepositReversalSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit Reversal' LIMIT 1].Id;

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    System.assertEquals(false, OrderNumViewController.testVisibleHasDepositCancellation(null, null));
    System.assertEquals(false, OrderNumViewController.testVisibleHasDepositCancellation(saleOrder, new List<Order>()));

    Order deletedReturnOrder = new Order(
      Name = 'RETURN-DELETED-COVERAGE',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETHDC'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true,
      IsDeleted__c = true
    );
    applyOrderDefaults(deletedReturnOrder, saleOrder.AccountId, 0, uniq('RTHDC'));
    insert deletedReturnOrder;

    System.assertEquals(false, OrderNumViewController.testVisibleHasDepositCancellation(saleOrder, new List<Order>{ deletedReturnOrder }));

    Order activeReturnOrder = new Order(
      Name = 'RETURN-ACTIVE-COVERAGE',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETHAT'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(activeReturnOrder, saleOrder.AccountId, 0, uniq('RTHAT'));
    insert activeReturnOrder;

    TransactionJournal linkedReversal = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      depositReversalTypeId,
      '01',
      250
    );
    linkedReversal.JournalSubTypeId = saleDepositReversalSubTypeId;
    if (journalFieldMap.containsKey('SaleId__c')) {
      linkedReversal.put('SaleId__c', activeReturnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      linkedReversal.put('OrderId__c', activeReturnOrder.Id);
    }
    update linkedReversal;

    System.assertEquals(true, OrderNumViewController.testVisibleHasDepositCancellation(saleOrder, new List<Order>{ activeReturnOrder }));
  }

  @IsTest
  static void test_testVisibleGetSaleAndReturnPaymentSummaryByOrderIdsAmount() {
    Map<String, Schema.SObjectField> journalFieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();
    if (!journalFieldMap.containsKey('OrderId__c') && !journalFieldMap.containsKey('SaleId__c')) {
      System.assertEquals(0, OrderNumViewController.testVisibleGetSalePaymentSummaryByOrderIdsAmount(new Set<Id>(), 'total'));
      System.assertEquals(0, OrderNumViewController.testVisibleGetReturnPaymentSummaryByOrderIdsAmount(null, new Set<Id>(), 'total'));
      return;
    }

    Order baseOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id depositTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit' LIMIT 1].Id;
    Id depositReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Deposit Reversal' LIMIT 1].Id;
    Id redemptionTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1].Id;
    Id redemptionReversalTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption Reversal' LIMIT 1].Id;
    Id saleDepositSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit' LIMIT 1].Id;
    Id saleDepositReversalSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit Reversal' LIMIT 1].Id;
    Id couponRedeemSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem' LIMIT 1].Id;
    Id pointDebitSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Point Debit' LIMIT 1].Id;
    Id couponRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem Cancel' LIMIT 1].Id;
    Id pointRedeemCancelSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Point Redeem Cancel' LIMIT 1].Id;

    Order saleOrder = createSaleOrder(baseOrder.AccountId, baseOrder.Pricebook2Id, baseOrder.MemberNo__c, 1000, uniq('ORDSUM'), uniq('SALESUM'));
    PricebookEntry pricebookEntry = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :saleOrder.Pricebook2Id LIMIT 1];
    createOrderItem(saleOrder.Id, pricebookEntry.Id, 1, 1000);
    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-SUMMARY-COVERAGE',
      AccountId = saleOrder.AccountId,
      Pricebook2Id = saleOrder.Pricebook2Id,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      SaleNo__c = uniq('RETSUM'),
      MemberNo__c = saleOrder.MemberNo__c,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, saleOrder.AccountId, 0, uniq('RETSUMREF'));
    insert returnOrder;

    TransactionJournal saleDeposit = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, depositTypeId, '01', 900);
    saleDeposit.JournalSubTypeId = saleDepositSubTypeId;
    update saleDeposit;

    TransactionJournal saleCoupon = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionTypeId, '90', 50);
    saleCoupon.JournalSubTypeId = couponRedeemSubTypeId;
    saleCoupon.Status = 'Processed';
    update saleCoupon;

    TransactionJournal salePoint = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, redemptionTypeId, '81', 100);
    salePoint.JournalSubTypeId = pointDebitSubTypeId;
    salePoint.Status = 'Processed';
    update salePoint;

    TransactionJournal directRefundCash = createTJ(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      depositReversalTypeId,
      '01',
      400
    );
    directRefundCash.JournalSubTypeId = saleDepositReversalSubTypeId;
    update directRefundCash;

    TransactionJournal directRefundCoupon = createTJ(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '90',
      60
    );
    directRefundCoupon.JournalSubTypeId = couponRedeemCancelSubTypeId;
    directRefundCoupon.Status = 'Processed';
    update directRefundCoupon;

    TransactionJournal linkedRefundPoint = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      redemptionReversalTypeId,
      '81',
      70
    );
    linkedRefundPoint.JournalSubTypeId = pointRedeemCancelSubTypeId;
    linkedRefundPoint.Status = 'Processed';
    if (journalFieldMap.containsKey('SaleId__c')) {
      linkedRefundPoint.put('SaleId__c', returnOrder.Id);
    }
    if (journalFieldMap.containsKey('OrderId__c')) {
      linkedRefundPoint.put('OrderId__c', returnOrder.Id);
    }
    update linkedRefundPoint;

    Set<Id> orderIds = new Set<Id>{ saleOrder.Id };
    Set<Id> returnOrderIds = new Set<Id>{ returnOrder.Id };

    Test.startTest();
    Decimal saleSummaryAmount = OrderNumViewController.testVisibleGetSalePaymentSummaryByOrderIdsAmount(orderIds, 'total');
    Decimal returnSummaryAmount = OrderNumViewController.testVisibleGetReturnPaymentSummaryByOrderIdsAmount(saleOrder, returnOrderIds, 'total');
    Test.stopTest();

    System.assertEquals(1050, saleSummaryAmount);
    System.assertEquals(530, returnSummaryAmount);
  }

  @IsTest
  static void test_testVisibleAccumulateReturnPointAmounts_emptyInput() {
    System.assertEquals(0, OrderNumViewController.testVisibleAccumulateReturnPointAmounts(new Set<Id>()));
    System.assertEquals(0, OrderNumViewController.testVisibleAccumulateReturnPointAmounts(null));
  }

  @IsTest
  static void test_testVisibleAccumulateReturnPointAmounts_coversDirectAndTraceabilityFlows() {
    Order saleOrder = [SELECT Id, AccountId, Pricebook2Id, MemberNo__c, Status FROM Order WHERE IsReductionOrder__c = FALSE LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType accrualType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    JournalType accrualReversalType = [SELECT Id FROM JournalType WHERE Name = 'Accrual Reversal' LIMIT 1];
    JournalSubType purchaseSubtypeRecord = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1];
    JournalSubType cancelSubtypeRecord = [SELECT Id FROM JournalSubType WHERE Name = 'Cancel Purchase Accrual' LIMIT 1];

    LoyaltyProgramCurrency pointCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'AccumulatePurchase',
      PointTypeCode__c = resolvePointTypeCode('01', '01'),
      UsagePriorityNumber = 97,
      IsActive = true
    );
    LoyaltyPgmCurrencySubtype giftSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'AccumulateGift',
      PointTypeCode__c = resolvePointTypeCode('06', '06'),
      UsagePriorityNumber = 98,
      IsActive = true
    );
    insert new List<LoyaltyPgmCurrencySubtype>{ purchaseSubtype, giftSubtype };

    saleOrder.Status = resolveOrderStatus('Activated', saleOrder.Status);
    update saleOrder;

    TransactionJournal restoredAccrual = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, null, 0);
    restoredAccrual.JournalSubTypeId = purchaseSubtypeRecord.Id;
    restoredAccrual.AdditionalNotes__c = 'Restore purchase accrual due to return deletion';
    update restoredAccrual;
    createLedger(restoredAccrual.Id, 100, 'Credit', purchaseSubtype.Id);

    TransactionJournal cancelWithSubtype = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualReversalType.Id,
      null,
      0
    );
    cancelWithSubtype.JournalSubTypeId = cancelSubtypeRecord.Id;
    update cancelWithSubtype;
    createLedger(cancelWithSubtype.Id, -60, 'Debit', giftSubtype.Id);

    TransactionJournal sourceAccrual = createTJ(saleOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, accrualType.Id, null, 0);
    sourceAccrual.JournalSubTypeId = purchaseSubtypeRecord.Id;
    update sourceAccrual;
    LoyaltyLedger sourceLedger = createLedger(sourceAccrual.Id, 80, 'Credit', purchaseSubtype.Id);

    TransactionJournal cancelWithoutSubtype = createTJ(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      accrualReversalType.Id,
      null,
      0
    );
    cancelWithoutSubtype.JournalSubTypeId = cancelSubtypeRecord.Id;
    update cancelWithoutSubtype;
    LoyaltyLedger unresolvedDebitLedger = createLedger(cancelWithoutSubtype.Id, -80, 'Debit', null);

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = loyaltyProgramMember.Id,
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      LoyaltyPgmCurrencySubtypeId = purchaseSubtype.Id,
      CreditLoyaltyLedgerId = sourceLedger.Id,
      DebitLoyaltyLedgerId = unresolvedDebitLedger.Id,
      ActionType = 'Debit',
      Points = 80
    );

    Set<Id> journalIds = new Set<Id>{ restoredAccrual.Id, cancelWithSubtype.Id, cancelWithoutSubtype.Id };

    System.assertEquals(240, OrderNumViewController.testVisibleAccumulateReturnPointAmounts(journalIds));
  }

  @IsTest
  static void test_testVisibleIsCancelledOrDeletedOrder_checksFlags() {
    System.assertEquals(false, OrderNumViewController.testVisibleIsCancelledOrDeletedOrder(null));
    System.assertEquals(false, OrderNumViewController.testVisibleIsCancelledOrDeletedOrder(new Order()));
    System.assertEquals(true, OrderNumViewController.testVisibleIsCancelledOrDeletedOrder(new Order(IsDeleted__c = true)));
    System.assertEquals(true, OrderNumViewController.testVisibleIsCancelledOrDeletedOrder(new Order(DeleteDateTime__c = System.now())));
  }
}
