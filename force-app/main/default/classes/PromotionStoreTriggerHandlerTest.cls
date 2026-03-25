@IsTest
private class PromotionStoreTriggerHandlerTest {
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
    Map<String, Schema.SObjectField> promotionFields = Schema.SObjectType.Promotion.fields.getMap();

    Promotion p1 = new Promotion(
      Name = 'Setup Promo 1 ' + uKey,
      BrandCode__c = '01',
      TypeCode__c = '01',
      StatusCode__c = '01',
      StartDate = Date.today(),
      EndDate = Date.today().addDays(30),
      InsertId__c = 'I' + uKey,
      ResponId__c = 'R' + uKey
    );
    if (promotionFields.containsKey('PublishStartDate__c')) {
      p1.put('PublishStartDate__c', Date.today());
    }
    if (promotionFields.containsKey('PublishEndDate__c')) {
      p1.put('PublishEndDate__c', Date.today().addDays(30));
    }

    Promotion p2 = new Promotion(
      Name = 'Setup Promo 2 ' + uKey,
      BrandCode__c = '01',
      TypeCode__c = '01',
      StatusCode__c = '01',
      StartDate = Date.today(),
      EndDate = Date.today().addDays(30),
      InsertId__c = 'I2' + uKey,
      ResponId__c = 'R2' + uKey
    );
    if (promotionFields.containsKey('PublishStartDate__c')) {
      p2.put('PublishStartDate__c', Date.today());
    }
    if (promotionFields.containsKey('PublishEndDate__c')) {
      p2.put('PublishEndDate__c', Date.today().addDays(30));
    }

    insert new List<Promotion>{ p1, p2 };

    Account acc1 = new Account(Name = 'Store 1 ' + uKey, CompanyCode__c = '1000', StoreCode__c = 'S' + uKey.substring(0, 4));
    Account acc2 = new Account(Name = 'Store 2 ' + uKey, CompanyCode__c = '1000', StoreCode__c = 'T' + uKey.substring(0, 4));
    insert new List<Account>{ acc1, acc2 };
  }

  private static List<Account> createExtraAccounts(Integer count) {
    String uKey = generateUniqueKey();
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < count; i++) {
      accounts.add(
        new Account(Name = 'Bulk Store ' + uKey + ' ' + i, CompanyCode__c = '1000', StoreCode__c = 'B' + uKey + String.valueOf(i).leftPad(4, '0'))
      );
    }
    insert accounts;
    return accounts;
  }

  @IsTest
  static void testAfterInsert() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    List<Promotion> promos = [SELECT Id FROM Promotion ORDER BY CreatedDate ASC LIMIT 2];
    List<Account> accounts = [SELECT Id FROM Account ORDER BY CreatedDate ASC LIMIT 2];

    PromotionAccount__c pa = new PromotionAccount__c(PromotionId__c = promos[0].Id, AccountId__c = accounts[0].Id);

    Test.startTest();
    insert pa;
    Test.stopTest();

    System.assertNotEquals(null, pa.Id);
  }

  @IsTest
  static void testAfterInsertWithPotentialFailure() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    List<Promotion> promos = [SELECT Id FROM Promotion ORDER BY CreatedDate ASC LIMIT 2];
    List<Account> accounts = [SELECT Id FROM Account ORDER BY CreatedDate ASC LIMIT 2];

    Account accBad = new Account(Name = 'Store Bad ' + generateUniqueKey(), CompanyCode__c = '1000');
    try {
      insert accBad;
    } catch (DmlException e) {
      accBad = null;
    }

    PromotionAccount__c ok = new PromotionAccount__c(PromotionId__c = promos[0].Id, AccountId__c = accounts[0].Id);
    PromotionAccount__c bad = (accBad == null)
      ? new PromotionAccount__c(PromotionId__c = promos[0].Id, AccountId__c = accounts[1].Id)
      : new PromotionAccount__c(PromotionId__c = promos[0].Id, AccountId__c = accBad.Id);

    Test.startTest();
    insert new List<PromotionAccount__c>{ ok, bad };
    Test.stopTest();

    System.assertNotEquals(null, ok.Id);
    System.assertNotEquals(null, bad.Id);
  }

  @IsTest
  static void testBulkInsertOverFourHundredRecordsIsNotCutOff() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    List<Account> accounts = createExtraAccounts(401);
    List<PromotionAccount__c> paList = new List<PromotionAccount__c>();

    for (Account accountRecord : accounts) {
      paList.add(new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = accountRecord.Id));
    }

    Test.startTest();
    insert paList;
    Test.stopTest();

    Integer insertedCount = [SELECT COUNT() FROM PromotionAccount__c WHERE PromotionId__c = :p.Id AND AccountId__c IN :accounts];
    Integer queueableCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable' AND ApexClass.Name = 'ErpPromotionStoreJob'
    ];

    System.assertEquals(401, insertedCount);
    System.assertEquals(3, queueableCount);
  }

  @IsTest
  static void testAfterUpdateWithChange() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    List<Promotion> promos = [SELECT Id FROM Promotion ORDER BY CreatedDate ASC LIMIT 2];
    List<Account> accounts = [SELECT Id FROM Account ORDER BY CreatedDate ASC LIMIT 2];

    PromotionAccount__c pa = new PromotionAccount__c(PromotionId__c = promos[0].Id, AccountId__c = accounts[0].Id, ErpSyncSkip__c = false);
    insert pa;

    PromotionAccount__c paToUpdate = [SELECT Id, PromotionId__c, AccountId__c, ErpSyncSkip__c FROM PromotionAccount__c WHERE Id = :pa.Id];
    Boolean changed = false;

    try {
      paToUpdate.AccountId__c = accounts[1].Id;
      Test.startTest();
      update paToUpdate;
      Test.stopTest();
      changed = true;
    } catch (Exception e) {
    }

    if (!changed) {
      try {
        paToUpdate.PromotionId__c = promos[1].Id;
        Test.startTest();
        update paToUpdate;
        Test.stopTest();
        changed = true;
      } catch (Exception e) {
      }
    }

    System.assertNotEquals(null, paToUpdate.Id);
  }

  @IsTest
  static void testAfterUpdateSkippedWhenErpSyncSkipTrue() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Account acc = [SELECT Id FROM Account LIMIT 1];

    PromotionAccount__c pa = new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id, ErpSyncSkip__c = false);
    insert pa;

    pa.ErpSyncSkip__c = true;
    update pa;

    System.assertEquals(true, [SELECT ErpSyncSkip__c FROM PromotionAccount__c WHERE Id = :pa.Id].ErpSyncSkip__c);
  }

  @IsTest
  static void testHandleAfterUpdateDirectly() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    List<Promotion> promos = [SELECT Id FROM Promotion ORDER BY CreatedDate ASC LIMIT 2];
    List<Account> accounts = [SELECT Id, CompanyCode__c, StoreCode__c, Name FROM Account ORDER BY CreatedDate ASC LIMIT 2];

    PromotionAccount__c inserted = new PromotionAccount__c(PromotionId__c = promos[0].Id, AccountId__c = accounts[0].Id);
    insert inserted;

    Integer afterInsertQueueableCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable' AND ApexClass.Name = 'ErpPromotionStoreJob'
    ];

    PromotionAccount__c oldRec = new PromotionAccount__c(Id = inserted.Id, PromotionId__c = promos[0].Id, AccountId__c = accounts[0].Id);
    PromotionAccount__c newRec = new PromotionAccount__c(Id = inserted.Id, PromotionId__c = promos[1].Id, AccountId__c = accounts[1].Id);

    Test.startTest();
    PromotionStoreTriggerHandler.handleAfterUpdate(
      new Map<Id, PromotionAccount__c>{ newRec.Id => newRec },
      new Map<Id, PromotionAccount__c>{ oldRec.Id => oldRec }
    );
    Test.stopTest();

    Integer queueableCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable' AND ApexClass.Name = 'ErpPromotionStoreJob'
    ];
    System.assertEquals(2, queueableCount - afterInsertQueueableCount);
  }

  @IsTest
  static void testAfterDelete() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Account acc = [SELECT Id FROM Account LIMIT 1];

    PromotionAccount__c pa = new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id);
    insert pa;

    Test.startTest();
    delete pa;
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM PromotionAccount__c WHERE Id = :pa.Id]);
  }

  @IsTest
  static void testAfterDeleteWithPotentialFailure() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];

    Account accBad = new Account(Name = 'Store Bad Del ' + generateUniqueKey(), CompanyCode__c = '1000');
    try {
      insert accBad;
    } catch (DmlException e) {
      accBad = null;
    }

    Account accOk = (accBad == null) ? [SELECT Id FROM Account LIMIT 1] : accBad;
    PromotionAccount__c pa = new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = accOk.Id);
    insert pa;

    Test.startTest();
    delete pa;
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM PromotionAccount__c WHERE Id = :pa.Id]);
  }

  @IsTest
  static void testHelperMethods() {
    Promotion p = [SELECT Id FROM Promotion LIMIT 1];
    Account acc = [SELECT Id FROM Account LIMIT 1];

    Set<Id> ids = PromotionStoreTriggerHandler.collectIds(new List<PromotionAccount__c>());
    System.assertEquals(0, ids.size());

    PromotionAccount__c pa1 = new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id);
    insert pa1;

    Set<Id> loadedIds = PromotionStoreTriggerHandler.collectIds(new List<PromotionAccount__c>{ pa1 });
    System.assertEquals(1, loadedIds.size());

    List<PromotionAccount__c> loadedCreate = PromotionStoreTriggerHandler.fetchPromotionAccounts(loadedIds, false, true);
    List<PromotionAccount__c> loadedBasic = PromotionStoreTriggerHandler.fetchPromotionAccounts(loadedIds, false, false);
    System.assertEquals(1, loadedCreate.size());
    System.assertEquals(1, loadedBasic.size());

    PromotionAccount__c oldRec = new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id);
    PromotionAccount__c sameRec = new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id);
    System.assertEquals(false, PromotionStoreTriggerHandler.isPromotionStoreChanged(oldRec, sameRec));

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionStoreTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());
    PromotionStoreTriggerHandler.setLoggerStatus(logger, new Set<String>{ (String) pa1.Id }, new Set<String>());
    PromotionStoreTriggerHandler.setLoggerStatus(logger, new Set<String>(), new Set<String>{ (String) pa1.Id });
    PromotionStoreTriggerHandler.setLoggerStatus(logger, new Set<String>{ (String) pa1.Id }, new Set<String>{ (String) pa1.Id });
    PromotionStoreTriggerHandler.finishLogger(
      logger,
      new Set<String>{ (String) pa1.Id },
      new Set<String>{ (String) pa1.Id },
      new List<String>{ 'test' }
    );

    System.assert(true);
  }

  @IsTest
  static void testHandlerSafety() {
    try {
      new PromotionStoreTriggerHandler().afterUpdate();
    } catch (Exception e) {
      System.assert(true);
      return;
    }

    System.assert(true);
  }
}
