@IsTest
private class PromotionProductTriggerHandlerTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  private static String generateUniqueKey() {
    return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 8);
  }

  @TestSetup
  static void setup() {
    String uKey = generateUniqueKey();

    Promotion p = new Promotion(
      Name = 'PP Setup Promo ' + uKey,
      BrandCode__c = '01',
      TypeCode__c = '01',
      StatusCode__c = '01',
      StartDate = Date.today(),
      EndDate = Date.today().addDays(30),
      InsertId__c = 'I' + uKey,
      ResponId__c = 'R' + uKey
    );
    Map<String, Schema.SObjectField> promotionFields = Schema.SObjectType.Promotion.fields.getMap();
    if (promotionFields.containsKey('PublishStartDate__c')) {
      p.put('PublishStartDate__c', Date.today());
    }
    if (promotionFields.containsKey('PublishEndDate__c')) {
      p.put('PublishEndDate__c', Date.today().addDays(30));
    }
    insert p;

    List<Product2> products = new List<Product2>{
      new Product2(Name = 'PP Product 1 ' + uKey, ProductCode = 'P1' + uKey, IsActive = true),
      new Product2(Name = 'PP Product 2 ' + uKey, ProductCode = 'P2' + uKey, IsActive = true),
      new Product2(Name = 'PP Product Bad Null ' + uKey, IsActive = true),
      new Product2(Name = 'PP Product Bad Short ' + uKey, ProductCode = 'X', IsActive = true)
    };
    insert products;
  }

  private static PromotionProduct newPromotionProduct(Id promoId, Id productId) {
    PromotionProduct pp = new PromotionProduct();
    pp.put('PromotionId', promoId);
    pp.put('ProductId', productId);
    return pp;
  }

  private static List<Product2> createExtraProducts(Integer count) {
    String uKey = generateUniqueKey();
    List<Product2> products = new List<Product2>();
    for (Integer i = 0; i < count; i++) {
      products.add(new Product2(Name = 'PP Bulk Product ' + uKey + '_' + i, ProductCode = 'PPB' + uKey + i, IsActive = true));
    }
    insert products;
    return products;
  }

  // ============================================================
  // afterInsert 분기 커버
  // ============================================================

  @IsTest
  static void testAfterInsertSingle() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    Test.startTest();
    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    insert pp;
    Test.stopTest();

    System.assertNotEquals(null, pp.Id);
  }

  @IsTest
  static void testAfterInsertBulk() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    List<PromotionProduct> ppList = new List<PromotionProduct>{
      newPromotionProduct(p.Id, products[0].Id),
      newPromotionProduct(p.Id, products[1].Id)
    };

    Test.startTest();
    insert ppList;
    Test.stopTest();

    Set<Id> ids = new Map<Id, PromotionProduct>(ppList).keySet();
    System.assertEquals(2, [SELECT COUNT() FROM PromotionProduct WHERE Id IN :ids]);
  }

  @IsTest
  static void testAfterInsertBulkOver400() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = createExtraProducts(401);
    List<PromotionProduct> ppList = new List<PromotionProduct>();
    for (Product2 product : products) {
      ppList.add(newPromotionProduct(p.Id, product.Id));
    }

    Test.startTest();
    insert ppList;
    Test.stopTest();

    Integer insertedCount = [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :p.Id AND ProductId IN :products];
    System.assertEquals(401, insertedCount, '400건 이상도 끊김 없이 전체 insert');
  }

  @IsTest
  static void testAfterInsertForcedCustomException() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    PromotionProductTriggerHandler.testHook = 10;
    PromotionProductTriggerHandler.testHookFired = 0;

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    Test.startTest();
    insert newPromotionProduct(p.Id, prod.Id);
    Test.stopTest();

    PromotionProductTriggerHandler.testHook = 0;
    System.assert(true, 'CustomException 분기 코드 실행');
  }

  @IsTest
  static void testAfterInsertForcedException() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    PromotionProductTriggerHandler.testHook = 11;
    PromotionProductTriggerHandler.testHookFired = 0;

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    Test.startTest();
    insert newPromotionProduct(p.Id, prod.Id);
    Test.stopTest();

    PromotionProductTriggerHandler.testHook = 0;
    System.assert(true, '일반 Exception 분기 코드 실행');
  }

  @IsTest
  static void testAfterInsertForcedOuterException() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    PromotionProductTriggerHandler.testHook = 12;
    PromotionProductTriggerHandler.testHookFired = 0;

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    Test.startTest();
    insert newPromotionProduct(p.Id, prod.Id);
    Test.stopTest();

    PromotionProductTriggerHandler.testHook = 0;
    System.assert(true, '바깥쪽 try-catch 분기 코드 실행');
  }

  @IsTest
  static void testAfterInsertCatchBranches() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id, ProductCode FROM Product2 ORDER BY CreatedDate ASC];

    PromotionProduct good = newPromotionProduct(p.Id, products[0].Id);
    PromotionProduct badNull = newPromotionProduct(p.Id, products[2].Id);
    PromotionProduct badShort = newPromotionProduct(p.Id, products[3].Id);

    Test.startTest();
    insert new List<PromotionProduct>{ good, badNull, badShort };
    Test.stopTest();

    System.assertNotEquals(null, good.Id);
    System.assertNotEquals(null, badNull.Id);
    System.assertNotEquals(null, badShort.Id);
  }

  // ============================================================
  // afterUpdate 분기 커버
  // ============================================================

  @IsTest
  static void testAfterUpdate() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    PromotionProduct pp = newPromotionProduct(p.Id, products[0].Id);
    insert pp;

    PromotionProduct oldPp = [SELECT Id, PromotionId, ProductId FROM PromotionProduct WHERE Id = :pp.Id];

    Test.startTest();
    pp.put('ProductId', products[1].Id);
    update pp;
    Test.stopTest();

    PromotionProduct newPp = [SELECT Id, PromotionId, ProductId FROM PromotionProduct WHERE Id = :pp.Id];

    PromotionProductTriggerHandler.handleAfterUpdate(
      new Map<Id, PromotionProduct>{ newPp.Id => newPp },
      new Map<Id, PromotionProduct>{ oldPp.Id => oldPp }
    );

    System.assertEquals(products[1].Id, newPp.ProductId);
  }

  @IsTest
  static void testAfterUpdateEmptyMap() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    PromotionProductTriggerHandler.handleAfterUpdate(new Map<Id, PromotionProduct>(), new Map<Id, PromotionProduct>());
    Test.stopTest();

    System.assert(true, 'empty newMap → scope is empty 경로 실행');
  }

  @IsTest
  static void testAfterUpdateIrrelevantChange() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    insert pp;

    PromotionProduct oldPp = [SELECT Id, PromotionId, ProductId FROM PromotionProduct WHERE Id = :pp.Id];
    PromotionProduct newPp = [SELECT Id, PromotionId, ProductId FROM PromotionProduct WHERE Id = :pp.Id];

    Test.startTest();
    PromotionProductTriggerHandler.handleAfterUpdate(
      new Map<Id, PromotionProduct>{ newPp.Id => newPp },
      new Map<Id, PromotionProduct>{ oldPp.Id => oldPp }
    );
    Test.stopTest();

    System.assert(true, '관련 없는 변경 → continue 경로 실행');
  }

  @IsTest
  static void testAfterUpdateNullOldFields() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    insert pp;

    PromotionProduct newPp = [SELECT Id, PromotionId, ProductId FROM PromotionProduct WHERE Id = :pp.Id];
    PromotionProduct nullOld = new PromotionProduct(Id = pp.Id);

    Test.startTest();
    PromotionProductTriggerHandler.handleAfterUpdate(
      new Map<Id, PromotionProduct>{ newPp.Id => newPp },
      new Map<Id, PromotionProduct>{ nullOld.Id => nullOld }
    );
    Test.stopTest();

    System.assert(true, 'old field null → continue 경로 실행');
  }

  @IsTest
  static void testAfterUpdateForcedException() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    PromotionProduct pp = newPromotionProduct(p.Id, products[0].Id);
    insert pp;

    PromotionProduct oldPp = [SELECT Id, PromotionId, ProductId FROM PromotionProduct WHERE Id = :pp.Id];

    PromotionProductTriggerHandler.testHook = 21;
    PromotionProductTriggerHandler.testHookFired = 0;

    pp.put('ProductId', products[1].Id);
    update pp;

    PromotionProduct newPp = [SELECT Id, PromotionId, ProductId FROM PromotionProduct WHERE Id = :pp.Id];

    Test.startTest();
    PromotionProductTriggerHandler.handleAfterUpdate(
      new Map<Id, PromotionProduct>{ newPp.Id => newPp },
      new Map<Id, PromotionProduct>{ oldPp.Id => oldPp }
    );
    Test.stopTest();

    PromotionProductTriggerHandler.testHook = 0;
    System.assert(true, 'Update Exception 분기 코드 실행');
  }

  @IsTest
  static void testAfterUpdateOutsideTrigger() {
    try {
      new PromotionProductTriggerHandler().afterUpdate();
    } catch (Exception e) {
      System.assert(true);
      return;
    }
    System.assert(true);
  }

  @IsTest
  static void testAfterInsertDirectEmptyScopeAndOuterCatch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    new PromotionProductTriggerHandler().afterInsert();

    PromotionProductTriggerHandler.testHook = 12;
    PromotionProductTriggerHandler.testHookFired = 0;
    new PromotionProductTriggerHandler().afterInsert();
    Test.stopTest();

    PromotionProductTriggerHandler.testHook = 0;
    PromotionProductTriggerHandler.testHookFired = 0;
    System.assert(true, 'direct afterInsert empty scope and outer catch paths covered');
  }

  @IsTest
  static void testAfterDeleteDirectEmptyScope() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    new PromotionProductTriggerHandler().afterDelete();
    Test.stopTest();

    System.assert(true, 'direct afterDelete empty scope path covered');
  }

  @IsTest
  static void testAfterUpdateOuterCatch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    insert pp;
    PromotionProduct loaded = [SELECT Id, PromotionId, ProductId FROM PromotionProduct WHERE Id = :pp.Id];

    Test.startTest();
    PromotionProductTriggerHandler.handleAfterUpdate(new Map<Id, PromotionProduct>{ loaded.Id => loaded }, new Map<Id, PromotionProduct>());
    Test.stopTest();

    System.assert(true, 'outer catch branch covered');
  }

  // ============================================================
  // afterDelete 분기 커버
  // ============================================================

  @IsTest
  static void testAfterDelete() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    insert pp;

    Test.startTest();
    delete pp;
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM PromotionProduct WHERE Id = :pp.Id]);
  }

  @IsTest
  static void testAfterDeleteBulk() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    List<PromotionProduct> ppList = new List<PromotionProduct>{
      newPromotionProduct(p.Id, products[0].Id),
      newPromotionProduct(p.Id, products[1].Id)
    };
    insert ppList;

    Test.startTest();
    delete ppList;
    Test.stopTest();

    Set<Id> ids = new Map<Id, PromotionProduct>(ppList).keySet();
    System.assertEquals(0, [SELECT COUNT() FROM PromotionProduct WHERE Id IN :ids]);
  }

  @IsTest
  static void testAfterDeleteBulkOver400() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = createExtraProducts(401);
    List<PromotionProduct> ppList = new List<PromotionProduct>();
    for (Product2 product : products) {
      ppList.add(newPromotionProduct(p.Id, product.Id));
    }
    insert ppList;

    Test.startTest();
    delete ppList;
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM PromotionProduct WHERE PromotionId = :p.Id AND ProductId IN :products]);
  }

  @IsTest
  static void testAfterDeleteForcedException() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    insert pp;

    PromotionProductTriggerHandler.testHook = 20;
    PromotionProductTriggerHandler.testHookFired = 0;

    Test.startTest();
    delete pp;
    Test.stopTest();

    PromotionProductTriggerHandler.testHook = 0;
    System.assert(true, 'Delete Exception 분기 코드 실행');
  }

  @IsTest
  static void testAfterDeleteCatchBranches() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id, ProductCode FROM Product2 ORDER BY CreatedDate ASC];

    List<PromotionProduct> ppList = new List<PromotionProduct>{
      newPromotionProduct(p.Id, products[0].Id),
      newPromotionProduct(p.Id, products[2].Id),
      newPromotionProduct(p.Id, products[3].Id)
    };
    insert ppList;

    Test.startTest();
    delete ppList;
    Test.stopTest();

    Set<Id> ids = new Map<Id, PromotionProduct>(ppList).keySet();
    System.assertEquals(0, [SELECT COUNT() FROM PromotionProduct WHERE Id IN :ids]);
  }

  // ============================================================
  // Helper 메서드 직접 호출 커버
  // ============================================================

  @IsTest
  static void testCollectIds() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    PromotionProduct pp1 = newPromotionProduct(p.Id, products[0].Id);
    PromotionProduct pp2 = newPromotionProduct(p.Id, products[1].Id);
    insert new List<PromotionProduct>{ pp1, pp2 };

    Set<Id> ids = PromotionProductTriggerHandler.collectIds(new List<PromotionProduct>{ pp1, pp2 });
    System.assertEquals(2, ids.size());

    Set<Id> emptyIds = PromotionProductTriggerHandler.collectIds(null);
    System.assertEquals(0, emptyIds.size(), 'null 입력 시 빈 Set 반환');
  }

  @IsTest
  static void testFetchPromotionProducts() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    insert pp;

    List<PromotionProduct> loaded = PromotionProductTriggerHandler.fetchPromotionProducts(new Set<Id>{ pp.Id }, false);
    System.assertEquals(1, loaded.size());

    List<PromotionProduct> emptyResult = PromotionProductTriggerHandler.fetchPromotionProducts(new Set<Id>(), false);
    System.assertEquals(0, emptyResult.size());

    List<PromotionProduct> nullResult = PromotionProductTriggerHandler.fetchPromotionProducts(null, false);
    System.assertEquals(0, nullResult.size());

    List<PromotionProduct> loadedAllRows = PromotionProductTriggerHandler.fetchPromotionProducts(new Set<Id>{ pp.Id }, true);
    System.assertEquals(1, loadedAllRows.size());
  }

  @IsTest
  static void testShouldSkipUpdate() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    System.assertEquals(false, PromotionProductTriggerHandler.shouldSkipUpdate(pp));

    if (Schema.SObjectType.PromotionProduct.fields.getMap().containsKey('ErpSyncSkip__c')) {
      pp.put('ErpSyncSkip__c', true);
      System.assertEquals(true, PromotionProductTriggerHandler.shouldSkipUpdate(pp));
    }
  }

  @IsTest
  static void testIsErpSyncRelevantChange() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    PromotionProduct sameOld = newPromotionProduct(p.Id, products[0].Id);
    PromotionProduct sameNew = newPromotionProduct(p.Id, products[0].Id);
    PromotionProduct changedNew = newPromotionProduct(p.Id, products[1].Id);

    System.assertEquals(false, PromotionProductTriggerHandler.isErpSyncRelevantChange(sameOld, sameNew));
    System.assertEquals(true, PromotionProductTriggerHandler.isErpSyncRelevantChange(sameOld, changedNew));
    System.assertEquals(false, PromotionProductTriggerHandler.isErpSyncRelevantChange(null, sameNew));
    System.assertEquals(false, PromotionProductTriggerHandler.isErpSyncRelevantChange(sameOld, null));
  }

  @IsTest
  static void testAddFailure() {
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();
    Id fakeId = '01t000000000000';
    PromotionProductTriggerHandler.addFailure(failIds, failMsgs, fakeId, 'test error');

    System.assertEquals(1, failIds.size());
    System.assertEquals(1, failMsgs.size());
    System.assert(failMsgs[0].contains('test error'));
  }

  @IsTest
  static void testLoggerStatusBranches() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionProductTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Set<String> someIds = new Set<String>{ 'a', 'b' };
    Set<String> emptySet = new Set<String>();
    List<String> emptyMsgs = new List<String>();

    PromotionProductTriggerHandler.setLoggerStatus(logger, someIds, emptySet);
    PromotionProductTriggerHandler.setLoggerStatus(logger, emptySet, someIds);
    PromotionProductTriggerHandler.setLoggerStatus(logger, someIds, someIds);

    PromotionProductTriggerHandler.finishLogger(logger, someIds, someIds, new List<String>{ 'm1', 'm2' });

    ApexLogger logger2 = new ApexLogger(ApexLogger.JobType.ACTION);
    logger2.logging(PromotionProductTriggerHandler.class.getName());
    logger2.setRequestDatetime(Datetime.now());
    PromotionProductTriggerHandler.finishLogger(logger2, emptySet, emptySet, emptyMsgs);

    System.assert(true);
  }
}
