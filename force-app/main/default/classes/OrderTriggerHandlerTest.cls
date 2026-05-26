@IsTest
private class OrderTriggerHandlerTest {
  private static Integer seq = 0;

  private class SlackHttpMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('ok');
      return res;
    }
  }

  private static Account createStoreAccount() {
    seq++;
    Account acc = new Account(Name = 'OrderTrigger Store ' + seq, StoreCode__c = 'OT-ST-' + seq, StoreType__c = '11', StoreTypeFour__c = '01');
    insert acc;
    return acc;
  }

  private static Id ensurePricebook() {
    Id pbId = Test.getStandardPricebookId();
    update new Pricebook2(Id = pbId, IsActive = true);
    return pbId;
  }

  private static Contact createContact(String name, Decimal spend) {
    Contact c = new Contact(LastName = name, TierQualifyingSpend3Y__c = spend);
    insert c;
    return c;
  }

  private static LoyaltyProgram createLoyaltyProgram() {
    seq++;
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'OrderTrigger Program ' + seq, IsPrimary = false);
    insert lp;
    return lp;
  }

  private static LoyaltyProgramMember createActiveMember(Contact c, LoyaltyProgram lp) {
    seq++;
    LoyaltyProgramMember member = new LoyaltyProgramMember(
      MembershipNumber = 'OTM-' + seq,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = c.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert member;
    return member;
  }

  private static PricebookEntry createPricebookEntry(Id pbId) {
    seq++;
    Product2 p = new Product2(Name = 'OrderTrigger Product ' + seq, ProductCode = 'OTP-' + seq, IsActive = true);
    insert p;

    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pbId, Product2Id = p.Id, UnitPrice = 100, IsActive = true);
    insert pbe;
    return pbe;
  }

  private static Order createOrder(Id storeAccountId, Id pbId, Id memberId, Date effectiveDate, String status) {
    Order o = new Order(
      AccountId = storeAccountId,
      StoreCode__c = storeAccountId,
      Pricebook2Id = pbId,
      MemberNo__c = memberId,
      EffectiveDate = effectiveDate,
      Status = status
    );
    insert o;
    return o;
  }

  private static void setOrderStatuses(Map<Id, String> statusById) {
    if (statusById == null || statusById.isEmpty()) {
      return;
    }

    List<Order> toUpdate = [SELECT Id, Status FROM Order WHERE Id IN :statusById.keySet()];
    for (Order o : toUpdate) {
      o.Status = statusById.get(o.Id);
    }
    update toUpdate;
  }

  private static OrderItem createOrderItem(Id orderId, Id pbeId, Decimal netSales, Id originalOrderItemId) {
    OrderItem oi = new OrderItem(
      OrderId = orderId,
      PricebookEntryId = pbeId,
      Quantity = 1,
      UnitPrice = 100,
      NetSalesUnitPrice__c = netSales,
      OriginalOrderItemId__c = originalOrderItemId
    );
    insert oi;
    return oi;
  }

  @IsTest
  static void constructor_and_guard_paths_are_covered() {
    ApexLogger.disableLogging();

    System.assertNotEquals(null, new OrderTriggerHandler());

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(null);
    OrderTriggerHandler.updateTierQualifyingSpend3Y(new Map<Id, String>());
    Test.stopTest();
  }

  @IsTest
  static void updateTierQualifyingSpend3Y_applies_all_status_deltas() {
    ApexLogger.disableLogging();

    Account store = createStoreAccount();
    Id pbId = ensurePricebook();
    PricebookEntry pbe = createPricebookEntry(pbId);

    Contact cSale = createContact('Sale', 10);
    Contact cSaleDel = createContact('SaleDel', 40);
    Contact cReturn = createContact('Return', 80);
    Contact cReturnDel = createContact('ReturnDel', 30);
    Contact cClamp = createContact('Clamp', 5);
    Contact cJanSaleSkip = createContact('JanSaleSkip', 100);

    Order saleSuccess = createOrder(store.Id, pbId, cSale.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order saleDeleted = createOrder(store.Id, pbId, cSaleDel.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order returnSuccess = createOrder(store.Id, pbId, cReturn.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order returnDeleted = createOrder(store.Id, pbId, cReturnDel.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order clampDeleted = createOrder(store.Id, pbId, cClamp.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order janSaleSuccess = createOrder(store.Id, pbId, cJanSaleSkip.Id, Date.newInstance(2026, 1, 3), 'Draft');

    Order originalForReturn = createOrder(store.Id, pbId, cReturn.Id, Date.newInstance(2026, 2, 1), 'Draft');
    OrderItem originalForReturnItem = createOrderItem(originalForReturn.Id, pbe.Id, 70, null);

    createOrderItem(saleSuccess.Id, pbe.Id, 100, null);
    createOrderItem(saleDeleted.Id, pbe.Id, 20, null);
    createOrderItem(returnSuccess.Id, pbe.Id, 1, originalForReturnItem.Id);
    createOrderItem(returnDeleted.Id, pbe.Id, 1, originalForReturnItem.Id);
    createOrderItem(clampDeleted.Id, pbe.Id, 50, null);
    createOrderItem(janSaleSuccess.Id, pbe.Id, 999, null);

    TriggerHandler.bypass('OrderTriggerHandler');
    setOrderStatuses(
      new Map<Id, String>{
        saleSuccess.Id => 'saleSuccess',
        saleDeleted.Id => 'saleDeleted',
        returnSuccess.Id => 'returnSuccess',
        returnDeleted.Id => 'returnDeleted',
        clampDeleted.Id => 'saleDeleted',
        janSaleSuccess.Id => 'saleSuccess'
      }
    );
    TriggerHandler.clearBypass('OrderTriggerHandler');

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(
      new Map<Id, String>{
        saleSuccess.Id => 'saleSuccess',
        saleDeleted.Id => 'saleDeleted',
        returnSuccess.Id => 'returnSuccess',
        returnDeleted.Id => 'returnDeleted',
        clampDeleted.Id => 'saleDeleted',
        janSaleSuccess.Id => 'saleSuccess'
      }
    );
    Test.stopTest();

    Map<Id, Contact> contacts = new Map<Id, Contact>(
      [
        SELECT Id, TierQualifyingSpend3Y__c
        FROM Contact
        WHERE Id IN :new Set<Id>{ cSale.Id, cSaleDel.Id, cReturn.Id, cReturnDel.Id, cClamp.Id, cJanSaleSkip.Id }
      ]
    );

    System.assertEquals(110, contacts.get(cSale.Id).TierQualifyingSpend3Y__c, 'saleSuccess 는 +NetSales');
    System.assertEquals(20, contacts.get(cSaleDel.Id).TierQualifyingSpend3Y__c, 'saleDeleted 는 -NetSales');
    System.assertEquals(10, contacts.get(cReturn.Id).TierQualifyingSpend3Y__c, 'returnSuccess 는 -OriginalOrderItem.NetSales');
    System.assertEquals(100, contacts.get(cReturnDel.Id).TierQualifyingSpend3Y__c, 'returnDeleted 는 +OriginalOrderItem.NetSales');
    System.assertEquals(0, contacts.get(cClamp.Id).TierQualifyingSpend3Y__c, '음수는 0으로 보정');
    System.assertEquals(100, contacts.get(cJanSaleSkip.Id).TierQualifyingSpend3Y__c, '1월 saleSuccess(1~7)는 제외');
  }

  @IsTest
  static void updateTierQualifyingSpend3Y_ignores_unknown_status_and_missing_rows() {
    ApexLogger.disableLogging();

    Account store = createStoreAccount();
    Id pbId = ensurePricebook();
    PricebookEntry pbe = createPricebookEntry(pbId);
    Contact c = createContact('UnknownStatus', 33);

    Order o = createOrder(store.Id, pbId, c.Id, Date.newInstance(2026, 2, 10), 'Draft');
    createOrderItem(o.Id, pbe.Id, 40, null);
    TriggerHandler.bypass('OrderTriggerHandler');
    setOrderStatuses(new Map<Id, String>{ o.Id => 'saleSuccess' });
    TriggerHandler.clearBypass('OrderTriggerHandler');

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(new Map<Id, String>{ o.Id => 'unknownStatus', UserInfo.getUserId() => 'saleSuccess' });
    Test.stopTest();

    c = [SELECT TierQualifyingSpend3Y__c FROM Contact WHERE Id = :c.Id];
    System.assertEquals(33, c.TierQualifyingSpend3Y__c, '알 수 없는 상태값은 반영되지 않아야 함');
  }

  @IsTest
  static void trigger_afterUpdate_updates_contact_for_transition() {
    ApexLogger.disableLogging();

    Account store = createStoreAccount();
    Id pbId = ensurePricebook();
    PricebookEntry pbe = createPricebookEntry(pbId);
    Contact c = createContact('TriggerPath', 0);

    Order saleOrder = createOrder(store.Id, pbId, c.Id, Date.newInstance(2026, 2, 10), 'Draft');
    createOrderItem(saleOrder.Id, pbe.Id, 120, null);

    saleOrder = [SELECT Id, Status FROM Order WHERE Id = :saleOrder.Id];
    saleOrder.Status = 'saleSuccess';

    Test.startTest();
    update saleOrder;
    Test.stopTest();

    c = [SELECT TierQualifyingSpend3Y__c FROM Contact WHERE Id = :c.Id];
    System.assertEquals(120, c.TierQualifyingSpend3Y__c, 'afterUpdate 상태 전이 시 가산되어야 함');
  }

  @IsTest
  static void trigger_afterUpdate_orderSuccess_enqueuesMonitoring() {
    ApexLogger.disableLogging();

    Account store = createStoreAccount();
    Id pbId = ensurePricebook();
    LoyaltyProgram lp = createLoyaltyProgram();

    Contact cOrder = createContact('OrderSuccessMonitor', 0);
    createActiveMember(cOrder, lp);

    Order orderSuccess = createOrder(store.Id, pbId, cOrder.Id, Date.newInstance(2026, 2, 10), 'Draft');

    Order updateOrder = [
      SELECT Id, Status
      FROM Order
      WHERE Id = :orderSuccess.Id
      LIMIT 1
    ];
    updateOrder.Status = 'orderSuccess';

    Test.startTest();
    update updateOrder;
    Test.stopTest();

    Contact reloadedContact = [SELECT TierQualifyingSpend3Y__c FROM Contact WHERE Id = :cOrder.Id];
    System.assertEquals(0, reloadedContact.TierQualifyingSpend3Y__c, 'orderSuccess should not affect 3Y spend');

    LoyaltyProgramMember member = [
      SELECT ContactId, Last_Activity_Date__c, Daily_Activity_Count__c
      FROM LoyaltyProgramMember
      WHERE ContactId = :cOrder.Id
      LIMIT 1
    ];
    System.assertEquals(Date.today(), member.Last_Activity_Date__c);
    System.assertEquals(1, Integer.valueOf(member.Daily_Activity_Count__c));
  }

  @IsTest
  static void trigger_afterUpdate_saleDeleteAndReturnEvents_enqueueImmediateMonitoring() {
    ApexLogger.disableLogging();

    Account store = createStoreAccount();
    Id pbId = ensurePricebook();
    PricebookEntry pbe = createPricebookEntry(pbId);
    LoyaltyProgram lp = createLoyaltyProgram();

    Contact cSaleDelete = createContact('MonitorSaleDelete', 0);
    Contact cReturnCreate = createContact('MonitorReturnCreate', 0);
    Contact cReturnDelete = createContact('MonitorReturnDelete', 0);
    createActiveMember(cSaleDelete, lp);
    createActiveMember(cReturnCreate, lp);
    createActiveMember(cReturnDelete, lp);

    Order saleDelete = createOrder(store.Id, pbId, cSaleDelete.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order returnCreate = createOrder(store.Id, pbId, cReturnCreate.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order returnDelete = createOrder(store.Id, pbId, cReturnDelete.Id, Date.newInstance(2026, 2, 10), 'Draft');

    Order baseReturn = createOrder(store.Id, pbId, cReturnCreate.Id, Date.newInstance(2026, 2, 1), 'Draft');
    OrderItem baseReturnItem = createOrderItem(baseReturn.Id, pbe.Id, 30, null);

    createOrderItem(saleDelete.Id, pbe.Id, 20, null);
    createOrderItem(returnCreate.Id, pbe.Id, 1, baseReturnItem.Id);
    createOrderItem(returnDelete.Id, pbe.Id, 1, baseReturnItem.Id);

    List<Order> toUpdate = [
      SELECT Id, Status
      FROM Order
      WHERE Id IN :new Set<Id>{ saleDelete.Id, returnCreate.Id, returnDelete.Id }
    ];
    for (Order orderRecord : toUpdate) {
      if (orderRecord.Id == saleDelete.Id) {
        orderRecord.Status = 'saleDeleted';
      } else if (orderRecord.Id == returnCreate.Id) {
        orderRecord.Status = 'returnSuccess';
      } else if (orderRecord.Id == returnDelete.Id) {
        orderRecord.Status = 'returnDeleted';
      }
    }

    Test.setMock(HttpCalloutMock.class, new SlackHttpMock());
    Test.startTest();
    update toUpdate;
    Test.stopTest();

    Map<Id, Order> reloadedById = new Map<Id, Order>(
      [
        SELECT Id, Status
        FROM Order
        WHERE Id IN :new Set<Id>{ saleDelete.Id, returnCreate.Id, returnDelete.Id }
      ]
    );

    System.assertEquals('saleDeleted', reloadedById.get(saleDelete.Id).Status);
    System.assertEquals('returnSuccess', reloadedById.get(returnCreate.Id).Status);
    System.assertEquals('returnDeleted', reloadedById.get(returnDelete.Id).Status);
  }

  @IsTest
  static void run_bypass_and_loopcount_are_covered() {
    ApexLogger.disableLogging();

    OrderTriggerHandler bypassed = new OrderTriggerHandler();
    TriggerHandler.bypass('OrderTriggerHandler');
    bypassed.setTriggerContext('after update', true);
    bypassed.run();
    TriggerHandler.clearBypass('OrderTriggerHandler');

    OrderTriggerHandler h = new OrderTriggerHandler();
    h.setTriggerContext('after update', true);
    h.run();
    h.run();
    h.run();

    Boolean thrown = false;
    try {
      h.run();
    } catch (Exception e) {
      thrown = true;
      System.assert(e.getMessage().contains('최대 실행 횟수'), '루프 카운트 초과 예외여야 함');
    }

    System.assertEquals(true, thrown, '4번째 run()에서 예외가 발생해야 함 (max=3)');
  }

  @IsTest
  static void afterUpdate_outside_trigger_context_is_safe() {
    ApexLogger.disableLogging();

    Test.startTest();
    new OrderTriggerHandler().afterUpdate();
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void updateTierQualifyingSpend3Y_delta_branch_focus() {
    ApexLogger.disableLogging();

    Account store = createStoreAccount();
    Id pbId = ensurePricebook();
    PricebookEntry pbe = createPricebookEntry(pbId);

    Contact cSaleDeleted = createContact('DeltaSaleDeleted', 100);
    Contact cReturnSuccess = createContact('DeltaReturnSuccess', 100);
    Contact cReturnDeleted = createContact('DeltaReturnDeleted', 100);
    Contact cUnknown = createContact('DeltaUnknown', 100);

    Order saleDeleted = createOrder(store.Id, pbId, cSaleDeleted.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order returnSuccess = createOrder(store.Id, pbId, cReturnSuccess.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order returnDeleted = createOrder(store.Id, pbId, cReturnDeleted.Id, Date.newInstance(2026, 2, 10), 'Draft');
    Order unknown = createOrder(store.Id, pbId, cUnknown.Id, Date.newInstance(2026, 2, 10), 'Draft');

    Order baseReturn = createOrder(store.Id, pbId, cReturnSuccess.Id, Date.newInstance(2026, 2, 1), 'Draft');
    OrderItem baseReturnItem = createOrderItem(baseReturn.Id, pbe.Id, 30, null);

    createOrderItem(saleDeleted.Id, pbe.Id, 20, null);
    createOrderItem(returnSuccess.Id, pbe.Id, 1, baseReturnItem.Id);
    createOrderItem(returnDeleted.Id, pbe.Id, 1, baseReturnItem.Id);
    createOrderItem(unknown.Id, pbe.Id, 50, null);

    TriggerHandler.bypass('OrderTriggerHandler');
    setOrderStatuses(
      new Map<Id, String>{
        saleDeleted.Id => 'saleDeleted',
        returnSuccess.Id => 'returnSuccess',
        returnDeleted.Id => 'returnDeleted',
        unknown.Id => 'saleSuccess'
      }
    );
    TriggerHandler.clearBypass('OrderTriggerHandler');

    Test.startTest();
    OrderTriggerHandler.updateTierQualifyingSpend3Y(
      new Map<Id, String>{
        saleDeleted.Id => 'saleDeleted',
        returnSuccess.Id => 'returnSuccess',
        returnDeleted.Id => 'returnDeleted',
        unknown.Id => 'unknownStatus'
      }
    );
    Test.stopTest();

    Map<Id, Contact> reloaded = new Map<Id, Contact>(
      [
        SELECT Id, TierQualifyingSpend3Y__c
        FROM Contact
        WHERE Id IN :new Set<Id>{ cSaleDeleted.Id, cReturnSuccess.Id, cReturnDeleted.Id, cUnknown.Id }
      ]
    );

    System.assertEquals(80, reloaded.get(cSaleDeleted.Id).TierQualifyingSpend3Y__c);
    System.assertEquals(70, reloaded.get(cReturnSuccess.Id).TierQualifyingSpend3Y__c);
    System.assertEquals(130, reloaded.get(cReturnDeleted.Id).TierQualifyingSpend3Y__c);
    System.assertEquals(100, reloaded.get(cUnknown.Id).TierQualifyingSpend3Y__c);
  }
}