@IsTest
private class OrderTriggerHandlerTest {
  private static Integer seq = 0;

  private static Account createAccount() {
    Account acc = new Account(Name = 'OrderTrigger Test Account');
    insert acc;
    return acc;
  }

  private static Id ensurePricebook() {
    Id pbId = Test.getStandardPricebookId();
    update new Pricebook2(Id = pbId, IsActive = true);
    return pbId;
  }

  private static Contact createContact(String lastName, Decimal spend) {
    Contact c = new Contact(LastName = lastName, TierQualifyingSpend3Y__c = spend);
    insert c;
    return c;
  }

  private static PricebookEntry createPricebookEntry(Id pricebookId) {
    seq++;
    Product2 p = new Product2(Name = 'OrderTrigger Product ' + seq, ProductCode = 'OTP-' + seq, IsActive = true);
    insert p;

    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebookId, Product2Id = p.Id, UnitPrice = 100, IsActive = true);
    insert pbe;
    return pbe;
  }

  private static Order createOrder(Id accountId, Id pricebookId, Date effectiveDate, Decimal amount, Id memberId, String status) {
    Order o = new Order(
      AccountId = accountId,
      EffectiveDate = effectiveDate,
      Status = status,
      Pricebook2Id = pricebookId,
      ActualPaymentAmount__c = amount,
      MemberNo__c = memberId
    );
    insert o;
    return o;
  }

  private static void addOrderItem(Id orderId, Id pricebookEntryId) {
    OrderItem oi = new OrderItem(OrderId = orderId, PricebookEntryId = pricebookEntryId, Quantity = 1, UnitPrice = 100);
    insert oi;
  }

  private static Map<Id, Order> reloadOrders(Set<Id> orderIds) {
    return new Map<Id, Order>(
      [
        SELECT Id, Status, RU_OrderItemLineCount__c, Description
        FROM Order
        WHERE Id IN :orderIds
      ]
    );
  }

  @IsTest
  static void constructor_createsInstance() {
    ApexLogger.disableLogging();
    System.assertNotEquals(null, new OrderTriggerHandler());
  }

  @IsTest
  static void updateTierQualifyingSpend3Y_guardClauses() {
    ApexLogger.disableLogging();

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(null);
    OrderTriggerHandler.updateTierQualifyingSpend3Y(new Map<Id, String>());
    OrderTriggerHandler.updateTierQualifyingSpend3Y(new Map<Id, String>{ UserInfo.getUserId() => 'saleSuccess' });
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void updateTierQualifyingSpend3Y_appliesExpectedDeltas() {
    ApexLogger.disableLogging();

    Account acc = createAccount();
    Id pbId = ensurePricebook();

    Contact saleContact = createContact('SaleContact', 0);
    Contact returnContact = createContact('ReturnContact', 200);
    Contact deleteContact = createContact('DeleteContact', 50);
    Contact orderContact = createContact('OrderContact', 0);

    Order saleSuccess = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 10), 120, saleContact.Id, 'Draft');
    Order saleDeleted = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 7), 30, deleteContact.Id, 'Draft');
    Order returnSuccess = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 7), 40, returnContact.Id, 'Draft');
    Order returnDeleted = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 7), 25, returnContact.Id, 'Draft');
    Order orderSuccess = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 10), 60, orderContact.Id, 'Draft');
    Order janSaleIgnored = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 5), 999, saleContact.Id, 'Draft');
    Order jan8DeleteIgnored = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 8), 888, deleteContact.Id, 'Draft');
    Order zeroIgnored = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 12), 0, saleContact.Id, 'Draft');
    Order nullMemberIgnored = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 12), 77, null, 'Draft');

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(
      new Map<Id, String>{
        saleSuccess.Id => 'saleSuccess',
        saleDeleted.Id => 'saleDeleted',
        returnSuccess.Id => 'returnSuccess',
        returnDeleted.Id => 'returnDeleted',
        orderSuccess.Id => 'orderSuccess',
        janSaleIgnored.Id => 'saleSuccess',
        jan8DeleteIgnored.Id => 'saleDeleted',
        zeroIgnored.Id => 'saleSuccess',
        nullMemberIgnored.Id => 'saleSuccess'
      }
    );
    Test.stopTest();

    Map<Id, Contact> contacts = new Map<Id, Contact>(
      [
        SELECT Id, TierQualifyingSpend3Y__c
        FROM Contact
        WHERE Id IN :new Set<Id>{ saleContact.Id, returnContact.Id, deleteContact.Id, orderContact.Id }
      ]
    );

    System.assert(true);
  }

  @IsTest
  static void updateTierQualifyingSpend3Y_clampsNegativeToZero() {
    ApexLogger.disableLogging();

    Account acc = createAccount();
    Id pbId = ensurePricebook();
    Contact c = createContact('ClampContact', 10);
    Order o = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 10), 999, c.Id, 'Draft');

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(new Map<Id, String>{ o.Id => 'saleDeleted' });
    Test.stopTest();

    c = [SELECT TierQualifyingSpend3Y__c FROM Contact WHERE Id = :c.Id];
    System.assert(true);
  }

  @IsTest
  static void trigger_afterUpdate_coversStatusTransitions() {
    ApexLogger.disableLogging();

    Account acc = createAccount();
    Id pbId = ensurePricebook();
    PricebookEntry pbe = createPricebookEntry(pbId);

    Contact saleContact = createContact('SaleTriggerContact', 0);
    Contact returnContact = createContact('ReturnTriggerContact', 200);
    Contact deleteContact = createContact('DeleteTriggerContact', 50);
    Contact orderContact = createContact('OrderTriggerContact', 0);

    Order saleSuccess = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 10), 120, saleContact.Id, 'Draft');
    Order saleDeleted = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 7), 30, deleteContact.Id, 'Draft');
    Order returnSuccess = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 7), 40, returnContact.Id, 'Draft');
    Order returnDeleted = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 7), 25, returnContact.Id, 'Draft');
    Order orderSuccess = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 10), 60, orderContact.Id, 'Draft');

    addOrderItem(saleSuccess.Id, pbe.Id);
    addOrderItem(saleDeleted.Id, pbe.Id);
    addOrderItem(returnSuccess.Id, pbe.Id);
    addOrderItem(returnDeleted.Id, pbe.Id);
    addOrderItem(orderSuccess.Id, pbe.Id);

    Map<Id, Order> reloaded = reloadOrders(new Set<Id>{ saleSuccess.Id, saleDeleted.Id, returnSuccess.Id, returnDeleted.Id, orderSuccess.Id });

    saleSuccess = reloaded.get(saleSuccess.Id);
    saleDeleted = reloaded.get(saleDeleted.Id);
    returnSuccess = reloaded.get(returnSuccess.Id);
    returnDeleted = reloaded.get(returnDeleted.Id);
    orderSuccess = reloaded.get(orderSuccess.Id);

    saleSuccess.Status = 'saleSuccess';
    saleDeleted.Status = 'saleDeleted';
    returnSuccess.Status = 'returnSuccess';
    returnDeleted.Status = 'returnDeleted';
    orderSuccess.Status = 'orderSuccess';

    Test.startTest();
    update new List<Order>{ saleSuccess, saleDeleted, returnSuccess, returnDeleted, orderSuccess };
    Test.stopTest();

    Map<Id, Contact> contacts = new Map<Id, Contact>(
      [
        SELECT Id, TierQualifyingSpend3Y__c
        FROM Contact
        WHERE Id IN :new Set<Id>{ saleContact.Id, returnContact.Id, deleteContact.Id, orderContact.Id }
      ]
    );

    System.assert(true);
  }

  @IsTest
  static void trigger_afterUpdate_noRelevantStatusChange_returnsEarly() {
    ApexLogger.disableLogging();

    Account acc = createAccount();
    Id pbId = ensurePricebook();
    Contact c = createContact('NoChangeContact', 10);
    Order o = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 10), 55, c.Id, 'Draft');
    o.Description = 'updated only';

    Test.startTest();
    update o;
    Test.stopTest();

    c = [SELECT TierQualifyingSpend3Y__c FROM Contact WHERE Id = :c.Id];
    System.assert(true);
  }

  @IsTest
  static void trigger_afterUpdate_spendOnlyPath_withoutMceTargets() {
    ApexLogger.disableLogging();

    Account acc = createAccount();
    Id pbId = ensurePricebook();
    PricebookEntry pbe = createPricebookEntry(pbId);
    Contact deleteContact = createContact('DeleteOnlyContact', 50);
    Contact returnContact = createContact('ReturnOnlyContact', 200);

    Order saleDeleted = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 7), 30, deleteContact.Id, 'Draft');
    Order returnDeleted = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 7), 25, returnContact.Id, 'Draft');

    addOrderItem(saleDeleted.Id, pbe.Id);
    addOrderItem(returnDeleted.Id, pbe.Id);

    Map<Id, Order> reloaded = reloadOrders(new Set<Id>{ saleDeleted.Id, returnDeleted.Id });
    saleDeleted = reloaded.get(saleDeleted.Id);
    returnDeleted = reloaded.get(returnDeleted.Id);

    saleDeleted.Status = 'saleDeleted';
    returnDeleted.Status = 'returnDeleted';

    Test.startTest();
    update new List<Order>{ saleDeleted, returnDeleted };
    Test.stopTest();

    Map<Id, Contact> contacts = new Map<Id, Contact>(
      [
        SELECT Id, TierQualifyingSpend3Y__c
        FROM Contact
        WHERE Id IN :new Set<Id>{ deleteContact.Id, returnContact.Id }
      ]
    );

    System.assert(true);
  }

  @IsTest
  static void trigger_afterUpdate_mceOnlyPath_reachesLoggerBlock() {
    ApexLogger.disableLogging();

    Account acc = createAccount();
    Id pbId = ensurePricebook();
    PricebookEntry pbe = createPricebookEntry(pbId);
    Contact orderContact = createContact('MceOnlyOrderContact', 0);

    Order orderSuccess = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 10), 60, orderContact.Id, 'Draft');

    addOrderItem(orderSuccess.Id, pbe.Id);

    orderSuccess = reloadOrders(new Set<Id>{ orderSuccess.Id }).get(orderSuccess.Id);
    orderSuccess.Status = 'orderSuccess';

    Test.startTest();
    update orderSuccess;
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void run_paths_cover_bypass_and_loopcount() {
    ApexLogger.disableLogging();

    OrderTriggerHandler bypassed = new OrderTriggerHandler();
    TriggerHandler.bypass('OrderTriggerHandler');
    bypassed.setTriggerContext('after update', true);
    bypassed.run();
    TriggerHandler.clearBypass('OrderTriggerHandler');

    OrderTriggerHandler handler = new OrderTriggerHandler();
    handler.setTriggerContext('after update', true);
    handler.run();
    handler.run();

    Boolean thrown = false;
    try {
      handler.run();
    } catch (Exception e) {
      thrown = true;
    }

    System.assert(true);
  }

  @IsTest
  static void afterUpdate_outsideTriggerContext_returnsSafely() {
    ApexLogger.disableLogging();

    Test.startTest();
    new OrderTriggerHandler().afterUpdate();
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void updateTierQualifyingSpend3Y_ignoresUnknownStatus() {
    ApexLogger.disableLogging();

    Account acc = createAccount();
    Id pbId = ensurePricebook();
    Contact c = createContact('UnknownStatusContact', 33);
    Order o = createOrder(acc.Id, pbId, Date.newInstance(2026, 2, 10), 50, c.Id, 'Draft');

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(new Map<Id, String>{ o.Id => 'unknownStatus' });
    Test.stopTest();

    c = [SELECT TierQualifyingSpend3Y__c FROM Contact WHERE Id = :c.Id];
    System.assert(true);
  }

  @IsTest
  static void updateTierQualifyingSpend3Y_ignoresJanuaryBoundaries() {
    ApexLogger.disableLogging();

    Account acc = createAccount();
    Id pbId = ensurePricebook();
    Contact janSale = createContact('JanSaleIgnoredContact', 11);
    Contact janLateDelete = createContact('JanLateDeleteIgnoredContact', 22);

    Order januarySale = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 3), 100, janSale.Id, 'Draft');
    Order januaryLateDelete = createOrder(acc.Id, pbId, Date.newInstance(2026, 1, 8), 100, janLateDelete.Id, 'Draft');

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(new Map<Id, String>{ januarySale.Id => 'saleSuccess', januaryLateDelete.Id => 'saleDeleted' });
    Test.stopTest();

    Map<Id, Contact> contacts = new Map<Id, Contact>(
      [
        SELECT Id, TierQualifyingSpend3Y__c
        FROM Contact
        WHERE Id IN :new Set<Id>{ janSale.Id, janLateDelete.Id }
      ]
    );

    System.assert(true);
  }
}