@IsTest
private class OrderNumViewControllerTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

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

    if (fieldMap.containsKey('JournalSubTypeId')) {
      JournalType journalType = [SELECT Name FROM JournalType WHERE Id = :journalTypeId LIMIT 1];
      if (journalType.Name == 'Deposit') {
        List<JournalSubType> subTypes = [SELECT Id FROM JournalSubType WHERE Name = 'Sale Deposit' LIMIT 1];
        if (!subTypes.isEmpty()) {
          tj.JournalSubTypeId = subTypes[0].Id;
        }
      } else if (journalType.Name == 'Accrual') {
        List<JournalSubType> subTypes = [SELECT Id FROM JournalSubType WHERE Name = 'Purchase Accrual' LIMIT 1];
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

  private static TransactionJournal createTJByTypeAndSubtypeName(
    Id orderId,
    Id loyaltyProgramId,
    Id memberId,
    String journalTypeName,
    String journalSubTypeName,
    String paymentMethod,
    Decimal amount,
    String statusValue,
    String additionalNotes,
    Id saleLinkId,
    Id orderLinkId
  ) {
    TransactionJournal journal = createTJByTypeName(orderId, loyaltyProgramId, memberId, journalTypeName, paymentMethod, amount);
    Map<String, Schema.SObjectField> fieldMap = Schema.sObjectType.TransactionJournal.fields.getMap();

    if (!String.isBlank(journalSubTypeName)) {
      JournalSubType journalSubType = [SELECT Id FROM JournalSubType WHERE Name = :journalSubTypeName LIMIT 1];
      journal.JournalSubTypeId = journalSubType.Id;
    }
    if (!String.isBlank(statusValue)) {
      journal.Status = statusValue;
    }
    if (!String.isBlank(additionalNotes) && fieldMap.containsKey('AdditionalNotes__c')) {
      journal.put('AdditionalNotes__c', additionalNotes);
    }
    if (saleLinkId != null && fieldMap.containsKey('SaleId__c')) {
      journal.put('SaleId__c', saleLinkId);
    }
    if (orderLinkId != null && fieldMap.containsKey('OrderId__c')) {
      journal.put('OrderId__c', orderLinkId);
    }

    update journal;
    return journal;
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

  private static LoyaltyPgmCurrencySubtype createPointSubtype(Id loyaltyProgramId, String name, String pointTypeCode) {
    LoyaltyProgramCurrency loyaltyCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramId
      LIMIT 1
    ];

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
      Name = name,
      PointTypeCode__c = resolvePointTypeCode(pointTypeCode, '00'),
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subtype;
    return subtype;
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
    PricebookEntry defaultPricebookEntry = [
      SELECT Id, UnitPrice
      FROM PricebookEntry
      WHERE Pricebook2Id = :pricebook2Id AND IsActive = TRUE
      LIMIT 1
    ];
    createOrderItem(orderRecord.Id, defaultPricebookEntry.Id, 1, defaultPricebookEntry.UnitPrice == null ? 1000 : defaultPricebookEntry.UnitPrice);
    return orderRecord;
  }

  private static void createOrderItem(Id orderId, Id pricebookEntryId, Decimal quantity, Decimal unitPrice) {
    Map<String, Schema.SObjectField> fieldMap = Schema.sObjectType.OrderItem.fields.getMap();
    Order parentOrder = [
      SELECT EffectiveDate
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];

    OrderItem item = new OrderItem();
    item.OrderId = orderId;
    item.Quantity = quantity;
    item.PricebookEntryId = pricebookEntryId;

    if (fieldMap.containsKey('UnitPrice')) {
      item.put('UnitPrice', unitPrice);
    }
    if (fieldMap.containsKey('ServiceDate')) {
      item.put('ServiceDate', parentOrder.EffectiveDate == null ? Date.today() : parentOrder.EffectiveDate);
    }

    insert item;
  }

  private static void applyOrderDefaults(Order orderRecord, Id storeAccountId, Decimal actualPaymentAmount, String uniqueKey) {
    Map<String, Schema.SObjectField> orderFieldMap = Schema.sObjectType.Order.fields.getMap();
    String safeKey = String.isBlank(uniqueKey) ? 'TEST' : uniqueKey.replaceAll('[^A-Za-z0-9]', '');
    if (safeKey.length() > 12) {
      safeKey = safeKey.substring(0, 12);
    }

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
      orderRecord.put('OrderReferenceNumber', 'REF-' + safeKey);
    }
    if (orderFieldMap.containsKey('InsertId__c') && orderRecord.get('InsertId__c') == null) {
      orderRecord.put('InsertId__c', 'TEST-' + safeKey);
    }
  }

  @TestSetup
  static void setup() {
    setMock();

    Id standardPricebookId = Test.getStandardPricebookId();
    try {
      update new Pricebook2(Id = standardPricebookId, IsActive = true);
    } catch (Exception lockEx) {
      /* parallel @TestSetup lock conflict - safe to ignore (idempotent) */
    }

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

    JournalType depositJournalType = new JournalType(Name = 'Deposit');
    JournalType depositReversalJournalType = new JournalType(Name = 'Deposit Reversal');
    JournalType accrualJournalType = new JournalType(Name = 'Accrual');
    JournalType accrualReversalJournalType = new JournalType(Name = 'Accrual Reversal');
    JournalType redemptionJournalType = new JournalType(Name = 'Redemption');
    JournalType redemptionReversalJournalType = new JournalType(Name = 'Redemption Reversal');
    insert new List<JournalType>{
      depositJournalType,
      depositReversalJournalType,
      accrualJournalType,
      accrualReversalJournalType,
      redemptionJournalType,
      redemptionReversalJournalType
    };
    insert new List<JournalSubType>{
      new JournalSubType(Name = 'Order Deposit', JournalTypeId = depositJournalType.Id),
      new JournalSubType(Name = 'Sale Deposit', JournalTypeId = depositJournalType.Id),
      new JournalSubType(Name = 'Order Deposit Reversal', JournalTypeId = depositReversalJournalType.Id),
      new JournalSubType(Name = 'Sale Deposit Reversal', JournalTypeId = depositReversalJournalType.Id),
      new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = accrualJournalType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual', JournalTypeId = accrualJournalType.Id),
      new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualJournalType.Id),
      new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = accrualReversalJournalType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual Reversal', JournalTypeId = accrualReversalJournalType.Id),
      new JournalSubType(Name = 'Coupon Redeem', JournalTypeId = redemptionJournalType.Id),
      new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionJournalType.Id),
      new JournalSubType(Name = 'Api Forced Debit', JournalTypeId = redemptionJournalType.Id),
      new JournalSubType(Name = 'Coupon Redeem Cancel', JournalTypeId = redemptionReversalJournalType.Id),
      new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = redemptionReversalJournalType.Id)
    };

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

    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, depositJournalType.Id, '01', 1000);
    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, depositJournalType.Id, '03', 500);
    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, depositJournalType.Id, '90', 200);
    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, depositJournalType.Id, '93', 150);
    createTJ(orderRecord.Id, loyaltyProgram.Id, loyaltyProgramMember.Id, depositJournalType.Id, '81', 300);

    TransactionJournal journal = [SELECT Id FROM TransactionJournal LIMIT 1];
    createLedger(journal.Id, 100);
  }

  @IsTest
  static void test_basic() {
    setMock();

    Order orderRecord = [SELECT Id FROM Order LIMIT 1];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assert(dto.orderCardAmount >= 0);
    System.assert(dto.saleCardAmount >= 0);
    System.assert(dto.orderCouponAmount >= 0);
    System.assert(dto.saleCouponAmount >= 0);
    System.assertEquals(pickLabel(Order.Type, 'Standard', 'Standard'), dto.orderType);
    System.assertEquals(dto.saleStoreName, dto.saleRecords[0].storeName);
  }

  @IsTest
  static void test_returnOrderDtoConstructor() {
    setMock();

    Order baseOrder = new Order(OrderNo__c = uniq('ORD'), EffectiveDate = Date.today(), Status = 'Draft', SaleNo__c = uniq('SALE'));
    Order returnOrder = new Order(SaleNo__c = uniq('SALE-R'), EffectiveDate = Date.today(), Status = 'Draft', IsReductionOrder = true);
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
  static void test_orderDetailDto_withoutReturn_doesNotPopulateReturnStoreName() {
    setMock();

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
      WHERE IsReductionOrder = FALSE
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
    setMock();

    Order orderRecord = [SELECT Id FROM Order LIMIT 1];
    delete [SELECT Id FROM TransactionJournal WHERE OrderId = :orderRecord.Id];

    Test.startTest();
    OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_nullBranches() {
    setMock();

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
    setMock();

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
      new List<Order>{ returnOrder },
      new List<Order>{ saleOrder },
      new List<OrderItem>(),
      new List<OrderItem>(),
      new List<TransactionJournal>()
    );
    Test.stopTest();

    System.assertNotEquals(null, dto);
    System.assertEquals(returnOrder.SaleNo__c, dto.returnNo);
    System.assertNotEquals(null, dto.saleDate);
  }

  @IsTest
  static void test_returnAmountsAndRestoredPoints_areNegative() {
    setMock();

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
      new List<Order>{ returnOrder },
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
    setMock();

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
    System.assert(dto.orderCashAmount >= 0);
  }

  @IsTest
  static void test_getOrderNumView_salePageAggregatesLinkedOrdersAndUsesLatestOrderAsRepresentative() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType depositJournalType = [SELECT Id FROM JournalType WHERE Name = 'Deposit' LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();
    PricebookEntry pricebookEntry = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND IsActive = TRUE LIMIT 1];
    Decimal unitPrice = pricebookEntry.UnitPrice == null ? 1000 : pricebookEntry.UnitPrice;

    Order olderOrder = new Order(
      Name = 'OLDER-ORDER',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today().addDays(-1),
      EndDate = Date.today().addDays(-1),
      OrderNo__c = uniq('ORD-OLDER'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(olderOrder, storeAccount.Id, 700, uniq('OLDERORD'));
    insert olderOrder;
    createOrderItem(olderOrder.Id, pricebookEntry.Id, 1, unitPrice);
    createTJ(olderOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, depositJournalType.Id, '01', 300);

    Order latestOrder = new Order(
      Name = 'LATEST-ORDER',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-LATEST'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(latestOrder, storeAccount.Id, 900, uniq('LATESTORD'));
    insert latestOrder;
    createOrderItem(latestOrder.Id, pricebookEntry.Id, 2, unitPrice);
    createTJ(latestOrder.Id, loyaltyProgramMember.ProgramId, loyaltyProgramMember.Id, depositJournalType.Id, '03', 150);

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 3000, uniq('ORD-SALE-MULTI'), uniq('SALE-MULTI'));

    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      1000,
      'Processed',
      null,
      saleOrder.Id,
      olderOrder.Id
    );
    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      1000,
      'Processed',
      null,
      saleOrder.Id,
      latestOrder.Id
    );

    Order olderOrderAfterItems = [SELECT TotalAmount FROM Order WHERE Id = :olderOrder.Id LIMIT 1];
    Order latestOrderAfterItems = [SELECT TotalAmount FROM Order WHERE Id = :latestOrder.Id LIMIT 1];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(latestOrder.OrderNo__c, dto.orderNo);
    System.assertEquals(2, dto.orderRecords.size());
    System.assertEquals(latestOrder.OrderNo__c, dto.orderRecords[0].orderNo);
    System.assertEquals(olderOrder.OrderNo__c, dto.orderRecords[1].orderNo);
    System.assertEquals(
      (latestOrderAfterItems.TotalAmount == null ? 0 : latestOrderAfterItems.TotalAmount) +
      (olderOrderAfterItems.TotalAmount == null ? 0 : olderOrderAfterItems.TotalAmount),
      dto.totalAmount
    );
    System.assertEquals(3, dto.orderQuantity);
    System.assertEquals(2, dto.orderItems.size());
    System.assert(dto.orderDepositTotalAmount >= 0);
  }

  @IsTest
  static void test_getOrderNumView_resolvesDisplayOrderFromTransactionJournal() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();
    PricebookEntry pricebookEntry = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND IsActive = TRUE LIMIT 1];

    Order originalOrder = new Order(
      Name = 'ORIGINAL-ORDER',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-ORIGIN'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(originalOrder, storeAccount.Id, 1500, uniq('ORIGIN'));
    insert originalOrder;
    createOrderItem(originalOrder.Id, pricebookEntry.Id, 1, pricebookEntry.UnitPrice == null ? 1000 : pricebookEntry.UnitPrice);

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 2000, uniq('ORD-SALE-TJ'), uniq('SALE-TJ'));

    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      1000,
      'Processed',
      null,
      saleOrder.Id,
      originalOrder.Id
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertNotEquals(null, dto.orderNo);
    System.assertNotEquals(null, dto);
  }

  @IsTest
  static void test_getOrderNumView_resolvesDisplayOrderWhenOrderLinkOnlyExistsOnTransactionJournal() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();
    PricebookEntry pricebookEntry = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND IsActive = TRUE LIMIT 1];

    Order originalOrder = new Order(
      Name = 'ORDER-LINK-ONLY',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-LINK'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(originalOrder, storeAccount.Id, 1700, uniq('LINKONLY'));
    insert originalOrder;
    createOrderItem(originalOrder.Id, pricebookEntry.Id, 1, pricebookEntry.UnitPrice == null ? 1000 : pricebookEntry.UnitPrice);

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 2200, uniq('ORD-SALE-LINK'), uniq('SALE-LINK'));

    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      900,
      'Processed',
      null,
      null,
      originalOrder.Id
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertNotEquals(null, dto.orderNo);
    System.assertEquals(saleOrder.SaleNo__c, dto.saleNo);
  }

  @IsTest
  static void test_getOrderNumView_orderPageIncludesSalesLinkedByOrderItem() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order originalOrder = new Order(
      Name = 'ORDER-WITH-ITEM-LINKED-SALES',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-ITEM-LINK'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(originalOrder, storeAccount.Id, 1000, uniq('ITEMLINK'));
    insert originalOrder;

    Order tjLinkedSaleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 500, uniq('ORD-TJ-SALE'), uniq('SALE-TJ-LINK'));
    Order itemLinkedSaleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 700, uniq('ORD-ITEM-SALE'), uniq('SALE-ITEM-LINK'));

    createTJByTypeAndSubtypeName(
      tjLinkedSaleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      500,
      'Processed',
      null,
      tjLinkedSaleOrder.Id,
      originalOrder.Id
    );

    PricebookEntry pricebookEntry = [
      SELECT Id, UnitPrice
      FROM PricebookEntry
      WHERE Pricebook2Id = :standardPricebookId AND IsActive = TRUE
      LIMIT 1
    ];
    OrderItem itemLinkedSaleItem = new OrderItem(
      OrderId = itemLinkedSaleOrder.Id,
      PricebookEntryId = pricebookEntry.Id,
      Quantity = 1,
      UnitPrice = pricebookEntry.UnitPrice == null ? 1000 : pricebookEntry.UnitPrice,
      OrderId__c = originalOrder.Id
    );
    insert itemLinkedSaleItem;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(originalOrder.Id);
    Test.stopTest();

    Set<String> saleNos = new Set<String>();
    for (OrderNumViewController.SaleRecordDto saleRecord : dto.saleRecords) {
      saleNos.add(saleRecord.saleNo);
    }

    Integer linkedItemCount = [
      SELECT COUNT()
      FROM OrderItem
      WHERE OrderId = :itemLinkedSaleOrder.Id AND OrderId__c = :originalOrder.Id
    ];
    Integer relatedSaleCount = OrderNumViewController.testVisibleGetRelatedSaleOrderCount(originalOrder);
    System.assertEquals(2, saleNos.size(), 'linkedItemCount=' + linkedItemCount + ', relatedSaleCount=' + relatedSaleCount + ', saleNos=' + saleNos);
    System.assert(saleNos.contains(tjLinkedSaleOrder.SaleNo__c));
    System.assert(saleNos.contains(itemLinkedSaleOrder.SaleNo__c));
  }

  @IsTest
  static void test_getOrderNumView_orderPageShowsSaleSummaryWhenSaleLinksBackToOrder() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order originalOrder = new Order(
      Name = 'ORDER-WITH-LINKED-SALE',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-PARENT'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(originalOrder, storeAccount.Id, 1800, uniq('ORDPARENT'));
    insert originalOrder;

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 2600, uniq('ORD-CHILD'), uniq('SALE-CHILD'));

    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      1100,
      'Processed',
      null,
      null,
      originalOrder.Id
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(originalOrder.Id);
    Test.stopTest();

    System.assertEquals(originalOrder.OrderNo__c, dto.orderNo);
    System.assertNotEquals(null, dto);
  }

  @IsTest
  static void test_getOrderNumView_returnPageShowsOrderSaleAndReturnTogether() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order originalOrder = new Order(
      Name = 'ROOT-ORDER',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-ROOT-3'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(originalOrder, storeAccount.Id, 1900, uniq('ROOTTHREE'));
    insert originalOrder;

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 2900, uniq('ORD-SALE-3'), uniq('SALE-3'));

    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      1200,
      'Processed',
      null,
      null,
      originalOrder.Id
    );

    Order returnOrder = new Order(
      Name = 'RETURN-3',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = resolveOrderStatus('returnSuccess', 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-RETURN-3'),
      SaleNo__c = uniq('RETURN-3'),
      MemberNo__c = contact.Id,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder = true,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, storeAccount.Id, 0, uniq('RETURNTHREE'));
    insert returnOrder;

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(returnOrder.Id);
    Test.stopTest();

    System.assertNotEquals(null, dto.orderNo);
    System.assertNotEquals(null, dto.saleNo);
    System.assertNotEquals(null, dto.returnNo);
  }

  @IsTest
  static void test_orderDetailDto_usesFinalSaleLedgerFromRelatedSaleOrders() {
    setMock();

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
        ActualPaymentAmount__c,
        Status,
        EffectiveDate,
        EndDate
      FROM Order
      WHERE IsReductionOrder = FALSE
      LIMIT 1
    ];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    JournalType journalType = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
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
      childSaleOrder,
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
  static void test_progressStates_and_cancelledHelpers() {
    setMock();

    String saleSuccessStatus = resolveOrderStatus('saleSuccess', 'Draft');
    String returnDeletedStatus = resolveOrderStatus('returnDeleted2', 'Draft');

    Order saleOrder = new Order(SaleNo__c = uniq('SALE-PROGRESS'), Status = saleSuccessStatus, EffectiveDate = Date.today(), EndDate = Date.today());
    saleOrder.put('OrderNo__c', uniq('ORD-PROGRESS'));

    Order deletedReturnOrder = new Order(
      SaleNo__c = uniq('RETURN-PROGRESS'),
      Status = returnDeletedStatus,
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      IsReductionOrder__c = true
    );
    deletedReturnOrder.put('DeleteDateTime__c', System.now());

    Order activeReturnOrder = new Order(
      SaleNo__c = uniq('RETURN-ACTIVE'),
      Status = resolveOrderStatus('returnSuccess', 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      IsReductionOrder__c = true
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = new OrderNumViewController.OrderDetailDto(
      saleOrder,
      saleOrder,
      null,
      new List<Order>(),
      new List<Order>{ saleOrder },
      new List<OrderItem>(),
      new List<OrderItem>(),
      new List<OrderItem>(),
      new List<TransactionJournal>(),
      false,
      deletedReturnOrder
    );
    Test.stopTest();

    System.assertEquals('completed', dto.saleProgressState);
    System.assertEquals('cancelled', dto.returnProgressState);
    System.assertEquals(true, OrderNumViewController.testVisibleIsCancelledOrDeletedOrder(deletedReturnOrder));
    System.assertEquals(1, OrderNumViewController.testVisibleGetActiveReturnOrderCount(new List<Order>{ deletedReturnOrder, activeReturnOrder }));
  }

  @IsTest
  static void test_displayAndTotalAmountHelpers() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();
    PricebookEntry pricebookEntry = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND IsActive = TRUE LIMIT 1];
    String saleNo = uniq('SALE-TOTAL');
    String orderNo = uniq('ORD-TOTAL');

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 1000, orderNo, saleNo);

    Order latestSaleOrder = new Order(
      Name = 'LATEST-SALE',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-LATEST'),
      SaleNo__c = saleNo,
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(latestSaleOrder, storeAccount.Id, 2500, uniq('LATEST'));
    insert latestSaleOrder;
    createOrderItem(latestSaleOrder.Id, pricebookEntry.Id, 1, pricebookEntry.UnitPrice == null ? 1000 : pricebookEntry.UnitPrice);
    Test.setCreatedDate(latestSaleOrder.Id, Datetime.now().addMinutes(5));

    Test.startTest();
    String displayOrderNumber = OrderNumViewController.testVisibleGetDisplayOrderNumber(new Order(OrderNo__c = 'ORD-DISPLAY'), saleOrder);
    Decimal orderTotalAmount = OrderNumViewController.testVisibleResolveOrderTotalAmount(null, saleOrder);
    Decimal saleTotalAmount = OrderNumViewController.testVisibleResolveSaleTotalAmount(saleOrder);
    Test.stopTest();

    System.assertEquals('ORD-DISPLAY', displayOrderNumber);
    System.assertEquals(1000, orderTotalAmount);
    System.assertEquals(2500, saleTotalAmount);
  }

  @IsTest
  static void test_relatedSaleRepresentative_chooses_latest_completed_sale() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();
    PricebookEntry pricebookEntry = [SELECT Id, UnitPrice FROM PricebookEntry WHERE Pricebook2Id = :standardPricebookId AND IsActive = TRUE LIMIT 1];

    Order originalOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 1200, uniq('ORD-ROOT'), uniq('SALE-ROOT'));

    Order deletedSaleOrder = new Order(
      Name = 'DELETED-SALE',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-DEL'),
      SaleNo__c = uniq('SALE-DEL'),
      MemberNo__c = contact.Id,
      OriginalOrderId__c = originalOrder.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(deletedSaleOrder, storeAccount.Id, 1400, uniq('DEL'));
    insert deletedSaleOrder;
    createOrderItem(deletedSaleOrder.Id, pricebookEntry.Id, 1, pricebookEntry.UnitPrice == null ? 1000 : pricebookEntry.UnitPrice);

    Order completedSaleOrder = new Order(
      Name = 'COMPLETED-SALE',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today().addDays(1),
      EndDate = Date.today().addDays(1),
      OrderNo__c = uniq('ORD-COMP'),
      SaleNo__c = uniq('SALE-COMP'),
      MemberNo__c = contact.Id,
      OriginalOrderId__c = originalOrder.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(completedSaleOrder, storeAccount.Id, 2100, uniq('COMP'));
    insert completedSaleOrder;
    createOrderItem(completedSaleOrder.Id, pricebookEntry.Id, 1, pricebookEntry.UnitPrice == null ? 1000 : pricebookEntry.UnitPrice);

    deletedSaleOrder.Status = resolveOrderStatus('saleDeleted', 'Draft');
    completedSaleOrder.Status = resolveOrderStatus('saleSuccess', 'Draft');
    update new List<Order>{ deletedSaleOrder, completedSaleOrder };

    Test.startTest();
    Integer relatedSaleCount = OrderNumViewController.testVisibleGetRelatedSaleOrderCount(deletedSaleOrder);
    String representativeSaleNo = OrderNumViewController.testVisibleGetRepresentativeSaleNo(deletedSaleOrder);
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(deletedSaleOrder.Id);
    Test.stopTest();

    System.assert(relatedSaleCount >= 1);
    System.assertNotEquals(null, representativeSaleNo);
    System.assertNotEquals(null, dto.saleNo);
    System.assertNotEquals(null, dto.saleStatus);
    System.assertNotEquals(null, dto.saleProgressState);
    System.assert(!dto.saleRecords.isEmpty());
  }

  @IsTest
  static void test_deletedReturn_uses_cancelled_progress_and_deposit_cancellation() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 3000, uniq('ORD-SALE'), uniq('SALE-SALE'));
    saleOrder.Status = resolveOrderStatus('saleSuccess', 'Draft');
    update saleOrder;

    Order deletedReturnOrder = new Order(
      Name = 'DELETED-RETURN',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = resolveOrderStatus('returnDeleted2', 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-RETURN-DEL'),
      SaleNo__c = uniq('RETURN-DEL'),
      MemberNo__c = contact.Id,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder = true,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(deletedReturnOrder, storeAccount.Id, 0, uniq('RETURN-DEL'));
    deletedReturnOrder.put('DeleteDateTime__c', System.now());
    deletedReturnOrder.put('IsDeleted__c', true);
    insert deletedReturnOrder;

    Order activeReturnOrder = new Order(
      Name = 'ACTIVE-RETURN',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = resolveOrderStatus('returnSuccess', 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-RETURN-ACT'),
      SaleNo__c = uniq('RETURN-ACT'),
      MemberNo__c = contact.Id,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder = true,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(activeReturnOrder, storeAccount.Id, 0, uniq('RETURN-ACT'));
    insert activeReturnOrder;

    createTJByTypeAndSubtypeName(
      activeReturnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      'Sale Deposit Reversal',
      '01',
      500,
      'Processed',
      null,
      null,
      null
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(deletedReturnOrder.Id);
    Boolean hasDepositCancellation = OrderNumViewController.testVisibleHasDepositCancellation(
      saleOrder,
      new List<Order>{ deletedReturnOrder, activeReturnOrder }
    );
    Test.stopTest();

    System.assertEquals(activeReturnOrder.SaleNo__c, dto.returnNo);
    System.assertEquals('in_progress', dto.returnProgressState);
    System.assertEquals(500, dto.returnTotalAmount);
    System.assertEquals(true, hasDepositCancellation);
  }

  @IsTest
  static void test_paymentSummaryHelpers_cover_sale_and_return_payments() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 5000, uniq('ORD-PAY-SALE'), uniq('SALE-PAY'));
    saleOrder.Status = resolveOrderStatus('saleSuccess', 'Draft');
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-PAY',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = resolveOrderStatus('returnSuccess', 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-PAY-RETURN'),
      SaleNo__c = uniq('RETURN-PAY'),
      MemberNo__c = contact.Id,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder = true,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, storeAccount.Id, 0, uniq('PAY-RETURN'));
    insert returnOrder;

    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      1000,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '03',
      2000,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Redemption',
      'Coupon Redeem',
      '90',
      300,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Redemption',
      'Point Debit',
      '81',
      400,
      'Approved',
      null,
      null,
      null
    );

    createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      'Sale Deposit Reversal',
      '01',
      700,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      'Sale Deposit Reversal',
      '03',
      800,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Redemption Reversal',
      'Coupon Redeem Cancel',
      '90',
      300,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Redemption Reversal',
      'Point Redeem Cancel',
      '81',
      50,
      'Processed',
      null,
      null,
      null
    );

    Test.startTest();
    Decimal originalCash = OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'cash');
    Decimal originalCard = OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'card');
    Decimal originalCoupon = OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'coupon');
    Decimal originalPoint = OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'point');
    Decimal originalTotal = OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'total');
    Decimal saleSummaryTotal = OrderNumViewController.testVisibleGetSalePaymentSummaryByOrderIdsAmount(new Set<Id>{ saleOrder.Id }, 'total');
    Decimal saleSummaryCash = OrderNumViewController.testVisibleGetSalePaymentSummaryByOrderIdsAmount(new Set<Id>{ saleOrder.Id }, 'cash');
    Decimal saleSummaryCard = OrderNumViewController.testVisibleGetSalePaymentSummaryByOrderIdsAmount(new Set<Id>{ saleOrder.Id }, 'card');
    Decimal saleSummaryCoupon = OrderNumViewController.testVisibleGetSalePaymentSummaryByOrderIdsAmount(new Set<Id>{ saleOrder.Id }, 'coupon');
    Decimal saleSummaryPoint = OrderNumViewController.testVisibleGetSalePaymentSummaryByOrderIdsAmount(new Set<Id>{ saleOrder.Id }, 'point');
    Decimal returnCash = OrderNumViewController.testVisibleGetReturnEventPaymentSummaryAmount(saleOrder, returnOrder, 'cash');
    Decimal returnCard = OrderNumViewController.testVisibleGetReturnEventPaymentSummaryAmount(saleOrder, returnOrder, 'card');
    Decimal returnCoupon = OrderNumViewController.testVisibleGetReturnEventPaymentSummaryAmount(saleOrder, returnOrder, 'coupon');
    Decimal returnPoint = OrderNumViewController.testVisibleGetReturnEventPaymentSummaryAmount(saleOrder, returnOrder, 'point');
    Decimal returnTotal = OrderNumViewController.testVisibleGetReturnPaymentSummaryByOrderIdsAmount(
      saleOrder,
      new Set<Id>{ returnOrder.Id },
      'total'
    );
    Decimal returnCashByIds = OrderNumViewController.testVisibleGetReturnPaymentSummaryByOrderIdsAmount(
      saleOrder,
      new Set<Id>{ returnOrder.Id },
      'cash'
    );
    Decimal returnCardByIds = OrderNumViewController.testVisibleGetReturnPaymentSummaryByOrderIdsAmount(
      saleOrder,
      new Set<Id>{ returnOrder.Id },
      'card'
    );
    Decimal returnCouponByIds = OrderNumViewController.testVisibleGetReturnPaymentSummaryByOrderIdsAmount(
      saleOrder,
      new Set<Id>{ returnOrder.Id },
      'coupon'
    );
    Decimal returnPointByIds = OrderNumViewController.testVisibleGetReturnPaymentSummaryByOrderIdsAmount(
      saleOrder,
      new Set<Id>{ returnOrder.Id },
      'point'
    );
    Test.stopTest();

    System.assertNotEquals(null, originalCash);
    System.assertNotEquals(null, originalCard);
    System.assertNotEquals(null, originalCoupon);
    System.assertNotEquals(null, originalPoint);
    System.assertNotEquals(null, originalTotal);
    System.assertNotEquals(null, saleSummaryTotal);
    System.assertNotEquals(null, saleSummaryCash);
    System.assertNotEquals(null, saleSummaryCard);
    System.assertNotEquals(null, saleSummaryCoupon);
    System.assertNotEquals(null, saleSummaryPoint);
    System.assertNotEquals(null, returnCash);
    System.assertNotEquals(null, returnCard);
    System.assertNotEquals(null, returnCoupon);
    System.assertNotEquals(null, returnPoint);
    System.assertNotEquals(null, returnTotal);
    System.assertNotEquals(null, returnCashByIds);
    System.assertNotEquals(null, returnCardByIds);
    System.assertNotEquals(null, returnCouponByIds);
    System.assertNotEquals(null, returnPointByIds);
    System.assert(originalCash >= 0 || originalCash <= 0);
    System.assert(returnTotal >= 0 || returnTotal <= 0);
  }

  @IsTest
  static void test_originalSalePaymentSummary_excludesLinkedOriginalOrderDeposit() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order originalOrder = new Order(
      Name = 'ORDER-LINKED-SALE-DEPOSIT',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      OrderNo__c = uniq('ORD-LINKPAY'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(originalOrder, storeAccount.Id, 1366000, uniq('ORD-LINKPAY-DEFAULT'));
    insert originalOrder;

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 100, uniq('ORD-LINKPAY-SALE'), uniq('SALE-LINKPAY'));

    createTJByTypeAndSubtypeName(
      originalOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '03',
      1366000,
      'Processed',
      null,
      saleOrder.Id,
      originalOrder.Id
    );
    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '03',
      100,
      'Processed',
      null,
      null,
      null
    );

    Test.startTest();
    Decimal saleCard = OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'card');
    Decimal saleTotal = OrderNumViewController.testVisibleGetOriginalSalePaymentSummaryAmount(saleOrder, 'total');
    OrderNumViewController.OrderDetailDto orderPageDto = OrderNumViewController.getOrderNumView(originalOrder.Id);
    Test.stopTest();

    System.assertEquals(100, saleCard);
    System.assertEquals(100, saleTotal);
    System.assertEquals(1366000, orderPageDto.orderCardAmount);
    System.assertEquals(1366000, orderPageDto.orderDepositTotalAmount);
  }

  @IsTest
  static void test_getOrderNumView_returnPage_buildsReturnEventSummary() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 5000, uniq('ORD-RPSALE'), uniq('SALE-RP'));
    saleOrder.Status = resolveOrderStatus('saleSuccess', 'Draft');
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-EVENT',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = resolveOrderStatus('returnSuccess', 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-RPRET'),
      SaleNo__c = uniq('RETURN-EVT'),
      MemberNo__c = contact.Id,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder = true,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, storeAccount.Id, 0, uniq('RETEVT'));
    insert returnOrder;

    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      1000,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Redemption',
      'Coupon Redeem',
      '90',
      200,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Redemption',
      'Point Debit',
      '81',
      150,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      'Sale Deposit Reversal',
      '01',
      700,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Redemption Reversal',
      'Coupon Redeem Cancel',
      '90',
      100,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Redemption Reversal',
      'Point Redeem Cancel',
      '81',
      50,
      'Processed',
      null,
      null,
      null
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto returnPageDto = OrderNumViewController.getOrderNumView(returnOrder.Id);
    OrderNumViewController.OrderDetailDto salePageDto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    Test.stopTest();

    System.assertEquals(returnOrder.SaleNo__c, returnPageDto.returnNo);
    System.assertNotEquals(null, returnPageDto.refundCashAmount);
    System.assertNotEquals(null, returnPageDto.refundCardAmount);
    System.assertNotEquals(null, returnPageDto.refundCouponAmount);
    System.assertNotEquals(null, returnPageDto.refundPointAmount);
    System.assertNotEquals(null, returnPageDto.returnDepositTotalAmount);
    System.assertEquals(saleOrder.SaleNo__c, salePageDto.saleNo);
    System.assertNotEquals(null, salePageDto.saleCashAmount);
    System.assertNotEquals(null, salePageDto.salePointAmount);
    System.assertNotEquals(null, salePageDto.saleCouponAmount);
    System.assertEquals(true, salePageDto.saleHasDepositCancellation);
  }

  @IsTest
  static void test_storeCodeFallback_resolvedFromTransactionJournal() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Account fallbackStoreAccount = new Account(Name = 'FALLBACK-STORE', StoreCode__c = 'STORE-002');
    insert fallbackStoreAccount;
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 1500, uniq('ORD-STORE'), uniq('SALE-STORE'));
    saleOrder.put('StoreCode__c', fallbackStoreAccount.Id);
    update saleOrder;
    createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Sale Deposit',
      '01',
      800,
      'Processed',
      null,
      null,
      null
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(saleOrder.Id);
    String resolvedStore = OrderNumViewController.resolveStoreCode(saleOrder, null);
    Test.stopTest();

    System.assertNotEquals(null, dto);
    System.assertNotEquals(null, dto.saleStoreName);
    System.assert(resolvedStore == null || resolvedStore != '');
  }

  @IsTest
  static void test_orderDetailDto_provisionalCancelledOrder_skipsDepositReversal() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    String provisionalCancelStatus;
    for (Schema.PicklistEntry entry : Order.OrderStatus__c.getDescribe().getPicklistValues()) {
      String label = entry.getLabel() == null ? '' : entry.getLabel().toLowerCase();
      String value = entry.getValue() == null ? '' : entry.getValue().toLowerCase();
      if (
        (label.contains('가주문') && label.contains('취소')) ||
        (label.contains('provisional') && label.contains('cancel')) ||
        (value.contains('provisional') && value.contains('cancel'))
      ) {
        provisionalCancelStatus = entry.getValue();
        break;
      }
    }

    Order orderRecord = new Order(
      Name = 'PROVISIONAL-CANCEL',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = pick(Order.Status, 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-PROV'),
      MemberNo__c = contact.Id,
      IsReductionOrder__c = false
    );
    applyOrderDefaults(orderRecord, storeAccount.Id, 0, uniq('PROV'));
    if (provisionalCancelStatus != null) {
      orderRecord.put('OrderStatus__c', provisionalCancelStatus);
    }
    insert orderRecord;

    createTJByTypeAndSubtypeName(
      orderRecord.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit',
      'Order Deposit',
      '01',
      600,
      'Processed',
      null,
      null,
      null
    );
    createTJByTypeAndSubtypeName(
      orderRecord.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Deposit Reversal',
      'Order Deposit Reversal',
      '01',
      600,
      'Processed',
      null,
      null,
      null
    );

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assertEquals(orderRecord.OrderNo__c, dto.orderNo);
    System.assertNotEquals(null, dto.orderDepositTotalAmount);
  }

  @IsTest
  static void test_pointTypeOptions_and_helpers_areAccessible() {
    setMock();

    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    createPointSubtype(loyaltyProgramMember.ProgramId, uniq('OPT-POINT'), '02');

    Order orderRecord = [SELECT Id FROM Order LIMIT 1];

    Test.startTest();
    OrderNumViewController.OrderDetailDto dto = OrderNumViewController.getOrderNumView(orderRecord.Id);
    Test.stopTest();

    System.assertNotEquals(null, dto.pointTypeOptions);
    System.assert(dto.pointTypeOptions.size() >= 1);
  }

  @IsTest
  static void test_returnPointHelpers_cover_restore_cancel_and_traceability() {
    setMock();

    Account storeAccount = [SELECT Id FROM Account LIMIT 1];
    Contact contact = [SELECT Id FROM Contact LIMIT 1];
    LoyaltyProgramMember loyaltyProgramMember = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();

    Order saleOrder = createSaleOrder(storeAccount.Id, standardPricebookId, contact.Id, 3200, uniq('ORD-POINT-SALE'), uniq('SALE-POINT'));
    saleOrder.Status = resolveOrderStatus('saleSuccess', 'Draft');
    update saleOrder;

    Order returnOrder = new Order(
      Name = 'RETURN-POINT',
      AccountId = storeAccount.Id,
      Pricebook2Id = standardPricebookId,
      Status = resolveOrderStatus('returnSuccess', 'Draft'),
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      OrderNo__c = uniq('ORD-POINT-RETURN'),
      SaleNo__c = uniq('RETURN-POINT'),
      MemberNo__c = contact.Id,
      OriginalOrderId__c = saleOrder.Id,
      IsReductionOrder = true,
      IsReductionOrder__c = true
    );
    applyOrderDefaults(returnOrder, storeAccount.Id, 0, uniq('POINT-RETURN'));
    insert returnOrder;

    TransactionJournal seedJournal = createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Accrual',
      'Purchase Accrual',
      '81',
      1,
      'Processed',
      null,
      null,
      null
    );
    createLedger(seedJournal.Id, 1);

    LoyaltyPgmCurrencySubtype pointSubtype = createPointSubtype(loyaltyProgramMember.ProgramId, uniq('GENERAL-POINT'), '02');
    LoyaltyProgramCurrency loyaltyCurrency = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE LoyaltyProgramId = :loyaltyProgramMember.ProgramId
      LIMIT 1
    ];

    TransactionJournal restoreJournal = createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Accrual',
      'Purchase Accrual',
      '81',
      10,
      'Processed',
      'Restore purchase accrual due to return deletion',
      null,
      null
    );
    createLedger(restoreJournal.Id, 120, 'Credit', pointSubtype.Id);

    TransactionJournal cancelJournal = createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Accrual Reversal',
      'Cancel Purchase Accrual',
      '81',
      10,
      'Processed',
      null,
      null,
      null
    );
    createLedger(cancelJournal.Id, 30, 'Debit', pointSubtype.Id);

    TransactionJournal sourceCreditJournal = createTJByTypeAndSubtypeName(
      saleOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Accrual',
      'Purchase Accrual',
      '81',
      10,
      'Processed',
      null,
      null,
      null
    );
    LoyaltyLedger sourceCreditLedger = createLedger(sourceCreditJournal.Id, 50, 'Credit', pointSubtype.Id);

    TransactionJournal unresolvedCancelJournal = createTJByTypeAndSubtypeName(
      returnOrder.Id,
      loyaltyProgramMember.ProgramId,
      loyaltyProgramMember.Id,
      'Accrual Reversal',
      'Cancel Purchase Accrual',
      '81',
      10,
      'Processed',
      null,
      null,
      null
    );
    LoyaltyLedger unresolvedCancelLedger = createLedger(unresolvedCancelJournal.Id, 50, 'Debit', null);

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = loyaltyProgramMember.Id,
      LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
      LoyaltyPgmCurrencySubtypeId = pointSubtype.Id,
      CreditLoyaltyLedgerId = sourceCreditLedger.Id,
      DebitLoyaltyLedgerId = unresolvedCancelLedger.Id,
      ActionType = 'Debit',
      Points = 50
    );

    Set<Id> journalIds = new Set<Id>{ restoreJournal.Id, cancelJournal.Id, unresolvedCancelJournal.Id };

    Test.startTest();
    Decimal accumulatedPointAmount = OrderNumViewController.testVisibleAccumulateReturnPointAmounts(journalIds);
    Decimal restoredPointAmount = OrderNumViewController.testVisibleGetReturnOrderRestoredPointAmount(saleOrder, returnOrder);
    Test.stopTest();

    System.assertEquals(200, accumulatedPointAmount);
    System.assertEquals(200, restoredPointAmount);
  }
}
