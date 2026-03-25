@IsTest
private class PromotionStoreTriggerTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  private static Promotion createPromotion() {
    Promotion p = new Promotion(
      Name = uniq('Promo'),
      StartDate = Date.today(),
      EndDate = Date.today().addDays(7),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(3),
      IsCouponAllowed__c = true,
      IsFixedAmountCouponAllowed__c = false,
      IsRateCouponAllowed__c = true,
      IsSpecificCouponAllowed__c = false,
      IsPointUsageAllowed__c = false,
      IsAllStore__c = false,
      IsAllItem__c = false
    );
    insert p;
    return p;
  }

  private static Account createStore(String storeCode) {
    Account a = new Account(
      Name = uniq('Store'),
      CompanyCode__c = '1000',
      StoreCode__c = storeCode
    );
    insert a;
    return a;
  }

  @IsTest
  static void trigger_afterInsert_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = createPromotion();
    Account a = createStore('S001');
    PromotionAccount__c pa = new PromotionAccount__c(
      PromotionId__c = p.Id,
      AccountId__c = a.Id
    );

    Test.startTest();
    insert pa;
    Test.stopTest();

    System.assertNotEquals(null, pa.Id);
  }

  @IsTest
  static void trigger_afterUpdate_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = createPromotion();
    Account a1 = createStore('S002');
    PromotionAccount__c pa = new PromotionAccount__c(
      PromotionId__c = p.Id,
      AccountId__c = a1.Id
    );
    insert pa;

    Test.startTest();
    update pa;
    Test.stopTest();

    PromotionAccount__c updated = [SELECT Id FROM PromotionAccount__c WHERE Id = :pa.Id LIMIT 1];
    System.assertEquals(pa.Id, updated.Id);
  }

  @IsTest
  static void trigger_afterDelete_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = createPromotion();
    Account a = createStore('S004');
    PromotionAccount__c pa = new PromotionAccount__c(
      PromotionId__c = p.Id,
      AccountId__c = a.Id
    );
    insert pa;

    Test.startTest();
    delete pa;
    Test.stopTest();

    Integer cnt = [SELECT COUNT() FROM PromotionAccount__c WHERE Id = :pa.Id];
    System.assertEquals(0, cnt);
  }
}