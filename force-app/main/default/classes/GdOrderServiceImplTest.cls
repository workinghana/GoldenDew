@IsTest
private class GdOrderServiceImplTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"ok":true}');
      return res;
    }
  }

  private static Id ensureStdPricebookActive() {
    Id pricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = pricebookId, IsActive = true);
    return pricebookId;
  }

  @testSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Id pbId = ensureStdPricebookActive();

    Account company = new Account(Name = 'GoldenDew-Company', CompanyCode__c = 'COMP-001');
    insert company;

    Account store = new Account(Name = 'GoldenDew-Store', StoreCode__c = 'STORE-001', StoreTypeFour__c = '01', ParentId = company.Id);
    insert store;

    Contact contact = new Contact(LastName = 'Member1', MemberNo__c = 'MEM-001');
    insert contact;

    insert new Order(
      AccountId = company.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = pbId,
      OrderNo__c = 'ORD-EXIST',
      MemberNo__c = contact.Id
    );

    insert new Order(
      AccountId = company.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = pbId,
      SaleNo__c = 'SALE-EXIST',
      MemberNo__c = contact.Id
    );

    insert new Order(AccountId = company.Id, EffectiveDate = Date.today(), Status = 'Draft', Pricebook2Id = pbId, OrderNo__c = 'ORD-DUP');

    insert new Order(AccountId = company.Id, EffectiveDate = Date.today(), Status = 'Draft', Pricebook2Id = pbId, SaleNo__c = 'SALE-DUP');
  }

  private static GdOrderService svc() {
    return new GdOrderServiceImpl();
  }

  @IsTest
  static void test_createOrder_success() {
    Map<String, Object> req = new Map<String, Object>{
      'AccountId' => 'COMP-001',
      'StoreCode__c' => 'STORE-001',
      'MemberNo__c' => 'MEM-001',
      'OrderNo__c' => 'ORD-NEW-001',
      'ActualPaymentAmount__c' => 1000,
      'OrderStatus__c' => '011',
      'InsertId__c' => 'TESTER'
    };

    Test.startTest();
    ApiResult res = svc().createOrder(req);
    Test.stopTest();

    Assert.areEqual(200, res.code);
  }

  @IsTest
  static void test_createOrder_errorPaths() {
    Test.startTest();
    try {
      svc().createOrder(null);
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc()
        .createOrder(
          new Map<String, Object>{ 'AccountId' => 'COMP-001', 'StoreCode__c' => 'STORE-001', 'MemberNo__c' => 'MEM-001', 'OrderNo__c' => 'ORD-DUP' }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc()
        .createOrder(
          new Map<String, Object>{
            'AccountId' => 'NO-COMP',
            'StoreCode__c' => 'STORE-001',
            'MemberNo__c' => 'MEM-001',
            'OrderNo__c' => 'ORD-ERR-001'
          }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc()
        .createOrder(
          new Map<String, Object>{
            'AccountId' => 'COMP-001',
            'StoreCode__c' => 'NO-STORE',
            'MemberNo__c' => 'MEM-001',
            'OrderNo__c' => 'ORD-ERR-002'
          }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc()
        .createOrder(
          new Map<String, Object>{
            'AccountId' => 'COMP-001',
            'StoreCode__c' => 'STORE-001',
            'MemberNo__c' => 'NO-MEMBER',
            'OrderNo__c' => 'ORD-ERR-003'
          }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_createOrder_validationExceptionPath() {
    Test.startTest();
    try {
      svc()
        .createOrder(
          new Map<String, Object>{
            'AccountId' => 'COMP-001',
            'StoreCode__c' => 'STORE-001',
            'MemberNo__c' => 'MEM-001',
            'ActualPaymentAmount__c' => 1000
          }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_updateOrder_success() {
    Map<String, Object> req = new Map<String, Object>{ 'OrderNo__c' => 'ORD-EXIST', 'ActualPaymentAmount__c' => 500000, 'OrderStatus__c' => '011' };

    Test.startTest();
    ApiResult res = svc().updateOrder(req);
    Test.stopTest();

    Assert.areEqual(200, res.code);
    Order updated = [SELECT ActualPaymentAmount__c, OrderStatus__c FROM Order WHERE OrderNo__c = 'ORD-EXIST' LIMIT 1];
    Assert.areEqual(500000, updated.ActualPaymentAmount__c);
  }

  @IsTest
  static void test_updateOrder_errorPaths() {
    Test.startTest();
    try {
      svc().updateOrder(null);
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc().updateOrder(new Map<String, Object>{ 'OrderNo__c' => 'ORD-NOT-FOUND', 'ActualPaymentAmount__c' => 100 });
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_updateOrder_validationExceptionPath() {
    Test.startTest();
    try {
      svc().updateOrder(new Map<String, Object>{ 'ActualPaymentAmount__c' => 100 });
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_createSale_success() {
    Map<String, Object> req = new Map<String, Object>{
      'AccountId' => 'COMP-001',
      'StoreCode__c' => 'STORE-001',
      'MemberNo__c' => 'MEM-001',
      'SaleNo__c' => 'SALE-NEW-001',
      'ActualPaymentAmount__c' => 2000,
      'SaleStatus__c' => '01',
      'InsertId__c' => 'TESTER'
    };

    Test.startTest();
    ApiResult res = svc().createSale(req);
    Test.stopTest();

    Assert.areEqual(200, res.code);
  }

  @IsTest
  static void test_createSale_errorPaths() {
    Test.startTest();
    try {
      svc().createSale(null);
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc()
        .createSale(
          new Map<String, Object>{ 'AccountId' => 'COMP-001', 'StoreCode__c' => 'STORE-001', 'MemberNo__c' => 'MEM-001', 'SaleNo__c' => 'SALE-DUP' }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc()
        .createSale(
          new Map<String, Object>{
            'AccountId' => 'NO-COMP',
            'StoreCode__c' => 'STORE-001',
            'MemberNo__c' => 'MEM-001',
            'SaleNo__c' => 'SALE-ERR-001'
          }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc()
        .createSale(
          new Map<String, Object>{
            'AccountId' => 'COMP-001',
            'StoreCode__c' => 'NO-STORE',
            'MemberNo__c' => 'MEM-001',
            'SaleNo__c' => 'SALE-ERR-002'
          }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc()
        .createSale(
          new Map<String, Object>{
            'AccountId' => 'COMP-001',
            'StoreCode__c' => 'STORE-001',
            'MemberNo__c' => 'NO-MEMBER',
            'SaleNo__c' => 'SALE-ERR-003'
          }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_createSale_validationExceptionPath() {
    Test.startTest();
    try {
      svc()
        .createSale(
          new Map<String, Object>{
            'AccountId' => 'COMP-001',
            'StoreCode__c' => 'STORE-001',
            'MemberNo__c' => 'MEM-001',
            'ActualPaymentAmount__c' => 2000
          }
        );
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_updateSale_success() {
    Map<String, Object> req = new Map<String, Object>{ 'SaleNo__c' => 'SALE-EXIST', 'ActualPaymentAmount__c' => 300000, 'SaleStatus__c' => '01' };

    Test.startTest();
    ApiResult res = svc().updateSale(req);
    Test.stopTest();

    Assert.areEqual(200, res.code);
    Order updated = [SELECT ActualPaymentAmount__c, SaleStatus__c FROM Order WHERE SaleNo__c = 'SALE-EXIST' LIMIT 1];
    Assert.areEqual(300000, updated.ActualPaymentAmount__c);
  }

  @IsTest
  static void test_updateSale_errorPaths() {
    Test.startTest();
    try {
      svc().updateSale(null);
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }

    try {
      svc().updateSale(new Map<String, Object>{ 'SaleNo__c' => 'SALE-NOT-FOUND', 'ActualPaymentAmount__c' => 100 });
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_updateSale_validationExceptionPath() {
    Test.startTest();
    try {
      svc().updateSale(new Map<String, Object>{ 'ActualPaymentAmount__c' => 100 });
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_updateSale_returnOrderBlocksUpdate() {
    Order original = [SELECT Id, AccountId, Pricebook2Id FROM Order WHERE SaleNo__c = 'SALE-EXIST' LIMIT 1];

    insert new Order(
      AccountId = original.AccountId,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = original.Pricebook2Id,
      OriginalOrderId__c = original.Id,
      IsDeleted__c = false
    );

    Test.startTest();
    try {
      svc().updateSale(new Map<String, Object>{ 'SaleNo__c' => 'SALE-EXIST', 'ActualPaymentAmount__c' => 100 });
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_deleteSale_success() {
    Test.startTest();
    ApiResult res = svc().deleteSale('SALE-EXIST');
    Test.stopTest();

    Assert.areEqual(200, res.code);
    Order deleted = [SELECT IsDeleted__c, DeleteDateTime__c FROM Order WHERE SaleNo__c = 'SALE-EXIST' LIMIT 1];
    Assert.isTrue(deleted.IsDeleted__c);
    Assert.isNotNull(deleted.DeleteDateTime__c);
  }

  @IsTest
  static void test_deleteSale_notFound() {
    Test.startTest();
    try {
      svc().deleteSale('SALE-NOT-FOUND');
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }
}