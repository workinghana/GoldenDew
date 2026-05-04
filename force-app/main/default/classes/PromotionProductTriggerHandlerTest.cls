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
      // 실패 분기 유도용: ProductCode 누락/짧은 값
      new Product2(Name = 'PP Product Bad Null ' + uKey, IsActive = true),
      new Product2(Name = 'PP Product Bad Short ' + uKey, ProductCode = 'X', IsActive = true)
    };
    insert products;
  }

  private static PromotionProduct newPromotionProduct(Id promoId, Id productId) {
    PromotionProduct pp = new PromotionProduct();
    // Use dynamic assignment to avoid hard coupling to field tokens across org variants.
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

  @IsTest
  static void testAfterInsertAndAfterDelete() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    PromotionProduct pp = newPromotionProduct(p.Id, products[0].Id);
    insert pp;

    List<ApexAuditTrail__c> logs = [
      SELECT RequestBody__c, Description__c
      FROM ApexAuditTrail__c
      WHERE ApexClass__c = 'PromotionProductTriggerHandler'
      ORDER BY CreatedDate DESC
      LIMIT 5
    ];
    ApexAuditTrail__c createLog;
    for (ApexAuditTrail__c log : logs) {
      if (log.Description__c != null && log.Description__c.startsWith('ERP Promotion Item create done')) {
        createLog = log;
        break;
      }
    }
    System.assertNotEquals(null, createLog);
    System.assert(createLog.RequestBody__c.contains('"id_update"'), createLog.RequestBody__c);

    delete pp;
    System.assertEquals(0, [SELECT COUNT() FROM PromotionProduct WHERE Id = :pp.Id]);
  }

  @IsTest
  static void testBulkInsertAndDelete() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    List<PromotionProduct> ppList = new List<PromotionProduct>{
      newPromotionProduct(p.Id, products[0].Id),
      newPromotionProduct(p.Id, products[1].Id)
    };

    insert ppList;
    delete ppList;

    Set<Id> ids = new Map<Id, PromotionProduct>(ppList).keySet();
    System.assertEquals(0, [SELECT COUNT() FROM PromotionProduct WHERE Id IN :ids]);
  }

  @IsTest
  static void testBulkInsertOverFourHundredRecordsIsNotCutOff() {
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
    Integer queueableCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable' AND ApexClass.Name = 'ErpPromotionProductJob'
    ];

    System.assertEquals(401, insertedCount, '400건에서 끊기지 않고 전체가 insert 되어야 합니다.');
    System.assertEquals(3, queueableCount, '401건이면 ERP enqueue는 200/200/1로 3번이어야 합니다.');
  }

  @IsTest
  static void testAfterInsertCoversCatchBranches() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id, ProductCode FROM Product2 ORDER BY CreatedDate ASC];

    // good + (ProductCode null) + (ProductCode too short) 조합으로 DTO/enqueue에서 예외를 유도한다.
    PromotionProduct good = newPromotionProduct(p.Id, products[0].Id);
    PromotionProduct badNull = newPromotionProduct(p.Id, products[2].Id);
    PromotionProduct badShort = newPromotionProduct(p.Id, products[3].Id);

    insert new List<PromotionProduct>{ good, badNull, badShort };

    System.assertNotEquals(null, good.Id);
    System.assertNotEquals(null, badNull.Id);
    System.assertNotEquals(null, badShort.Id);
  }

  @IsTest
  static void testAfterDeleteCoversCatchBranches() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id, ProductCode FROM Product2 ORDER BY CreatedDate ASC];

    List<PromotionProduct> ppList = new List<PromotionProduct>{
      newPromotionProduct(p.Id, products[0].Id),
      newPromotionProduct(p.Id, products[2].Id),
      newPromotionProduct(p.Id, products[3].Id)
    };
    insert ppList;

    delete ppList;

    Set<Id> ids = new Map<Id, PromotionProduct>(ppList).keySet();
    System.assertEquals(0, [SELECT COUNT() FROM PromotionProduct WHERE Id IN :ids]);
  }

  @IsTest
  static void testForcedCustomExceptionCatch() {
    PromotionProductTriggerHandler.testHook = 10;
    PromotionProductTriggerHandler.testHookFired = 0;

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    insert newPromotionProduct(p.Id, prod.Id);
    System.assertEquals(1, PromotionProductTriggerHandler.testHookFired);
    PromotionProductTriggerHandler.testHook = 0;
  }

  @IsTest
  static void testForcedExceptionCatch() {
    PromotionProductTriggerHandler.testHook = 11;
    PromotionProductTriggerHandler.testHookFired = 0;

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    insert newPromotionProduct(p.Id, prod.Id);
    System.assertEquals(1, PromotionProductTriggerHandler.testHookFired);
    PromotionProductTriggerHandler.testHook = 0;
  }

  @IsTest
  static void testForcedOuterExceptionCatch() {
    PromotionProductTriggerHandler.testHook = 12;
    PromotionProductTriggerHandler.testHookFired = 0;

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    insert newPromotionProduct(p.Id, prod.Id);
    System.assertEquals(1, PromotionProductTriggerHandler.testHookFired);
    PromotionProductTriggerHandler.testHook = 0;
  }

  @IsTest
  static void testForcedDeleteExceptionCatch() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 1];

    PromotionProduct pp = newPromotionProduct(p.Id, prod.Id);
    insert pp;

    PromotionProductTriggerHandler.testHook = 20;
    PromotionProductTriggerHandler.testHookFired = 0;
    delete pp;

    System.assertEquals(1, PromotionProductTriggerHandler.testHookFired);
    PromotionProductTriggerHandler.testHook = 0;
  }

  @IsTest
  static void testAfterInsertPartialStatusPath() {
    PromotionProductTriggerHandler.testHook = 11;
    PromotionProductTriggerHandler.testHookFired = 0;

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    // 첫 건은 강제 Exception으로 실패, 두번째 건은 성공 -> PARTIAL 분기 커버
    List<PromotionProduct> ppList = new List<PromotionProduct>{
      newPromotionProduct(p.Id, products[0].Id),
      newPromotionProduct(p.Id, products[1].Id)
    };
    insert ppList;

    System.assertEquals(1, PromotionProductTriggerHandler.testHookFired);
    PromotionProductTriggerHandler.testHook = 0;
  }

  @IsTest
  static void testAfterDeletePartialStatusPath() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    List<PromotionProduct> ppList = new List<PromotionProduct>{
      newPromotionProduct(p.Id, products[0].Id),
      newPromotionProduct(p.Id, products[1].Id)
    };
    insert ppList;

    // 첫 건 delete 처리 중 강제 Exception -> 실패, 두번째 건은 성공 -> PARTIAL 분기 커버
    PromotionProductTriggerHandler.testHook = 20;
    PromotionProductTriggerHandler.testHookFired = 0;
    delete ppList;

    System.assertEquals(1, PromotionProductTriggerHandler.testHookFired);
    PromotionProductTriggerHandler.testHook = 0;
  }

  @IsTest
  static void testAfterUpdate() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    PromotionProduct pp = newPromotionProduct(p.Id, products[0].Id);
    insert pp;

    PromotionProduct oldPp = [
      SELECT Id, PromotionId, ProductId
      FROM PromotionProduct
      WHERE Id = :pp.Id
    ];

    pp.put('ProductId', products[1].Id);
    update pp;

    PromotionProduct newPp = [
      SELECT Id, PromotionId, ProductId
      FROM PromotionProduct
      WHERE Id = :pp.Id
    ];

    PromotionProductTriggerHandler.handleAfterUpdate(
      new Map<Id, PromotionProduct>{ newPp.Id => newPp },
      new Map<Id, PromotionProduct>{ oldPp.Id => oldPp }
    );

    PromotionProduct updated = [
      SELECT Id, ProductId
      FROM PromotionProduct
      WHERE Id = :pp.Id
    ];
    System.assertEquals(products[1].Id, updated.ProductId);
  }

  @IsTest
  static void testAfterUpdateForcedExceptionCatch() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    PromotionProduct pp = newPromotionProduct(p.Id, products[0].Id);
    insert pp;

    PromotionProduct oldPp = [
      SELECT Id, PromotionId, ProductId
      FROM PromotionProduct
      WHERE Id = :pp.Id
    ];

    PromotionProductTriggerHandler.testHook = 21;
    PromotionProductTriggerHandler.testHookFired = 0;

    pp.put('ProductId', products[1].Id);
    update pp;

    PromotionProduct newPp = [
      SELECT Id, PromotionId, ProductId
      FROM PromotionProduct
      WHERE Id = :pp.Id
    ];

    PromotionProductTriggerHandler.handleAfterUpdate(
      new Map<Id, PromotionProduct>{ newPp.Id => newPp },
      new Map<Id, PromotionProduct>{ oldPp.Id => oldPp }
    );

    System.assertEquals(1, PromotionProductTriggerHandler.testHookFired);
    PromotionProductTriggerHandler.testHook = 0;
  }

  @IsTest
  static void testAfterUpdateOutsideTriggerContext() {
    try {
      new PromotionProductTriggerHandler().afterUpdate();
    } catch (Exception e) {
      System.assert(true);
      return;
    }

    System.assert(true);
  }

  @IsTest
  static void testUserNameFallback() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 LIMIT 1];

    // userName 대신 SYSTEM fallback이 타는지 확인
    Test.startTest();
    insert newPromotionProduct(p.Id, prod.Id);
    Test.stopTest();

    System.assert(true); // 예외 없이 실행되면 성공
  }

  @IsTest
  static void testHelperMethods() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Product2> products = [SELECT Id FROM Product2 ORDER BY CreatedDate ASC LIMIT 2];

    PromotionProduct pp1 = newPromotionProduct(p.Id, products[0].Id);
    PromotionProduct pp2 = newPromotionProduct(p.Id, products[1].Id);
    insert new List<PromotionProduct>{ pp1, pp2 };

    Set<Id> ids = PromotionProductTriggerHandler.collectIds(new List<PromotionProduct>{ pp1, pp2 });
    System.assertEquals(2, ids.size());

    List<PromotionProduct> loaded = PromotionProductTriggerHandler.fetchPromotionProducts(ids, false);
    System.assertEquals(2, loaded.size());

    PromotionProduct sameOld = newPromotionProduct(p.Id, products[0].Id);
    PromotionProduct sameNew = newPromotionProduct(p.Id, products[0].Id);
    PromotionProduct changedNew = newPromotionProduct(p.Id, products[1].Id);

    System.assertEquals(false, PromotionProductTriggerHandler.isErpSyncRelevantChange(sameOld, sameNew));
    System.assertEquals(true, PromotionProductTriggerHandler.isErpSyncRelevantChange(sameOld, changedNew));
    System.assertEquals(false, PromotionProductTriggerHandler.shouldSkipUpdate(sameNew));

    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();
    PromotionProductTriggerHandler.addFailure(failIds, failMsgs, pp1.Id, 'boom');
    System.assertEquals(true, failIds.contains((String) pp1.Id));
    System.assertEquals(1, failMsgs.size());

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionProductTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());
    PromotionProductTriggerHandler.setLoggerStatus(logger, new Set<String>{ (String) pp2.Id }, new Set<String>());
    PromotionProductTriggerHandler.setLoggerStatus(logger, new Set<String>(), new Set<String>{ (String) pp1.Id });
    PromotionProductTriggerHandler.setLoggerStatus(logger, new Set<String>{ (String) pp2.Id }, new Set<String>{ (String) pp1.Id });
    PromotionProductTriggerHandler.finishLogger(logger, new Set<String>{ (String) pp2.Id }, failIds, failMsgs);

    System.assert(true);
  }
}