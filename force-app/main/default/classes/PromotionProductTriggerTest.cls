@IsTest
private class PromotionProductTriggerTest {
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

  private static Product2 createProduct() {
    Product2 prod = new Product2(Name = uniq('Prod'), ProductCode = uniq('Code'), IsActive = true);
    insert prod;
    return prod;
  }

  @IsTest
  static void trigger_afterInsert_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Promotion p = createPromotion();
    Product2 prod = createProduct();

    PromotionProduct pp = new PromotionProduct(PromotionId = p.Id, ProductId = prod.Id);

    Test.startTest();
    insert pp;
    Test.stopTest();

    System.assertNotEquals(null, pp.Id);
  }

  @IsTest
  static void trigger_afterDelete_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Promotion p = createPromotion();
    Product2 prod = createProduct();
    PromotionProduct pp = new PromotionProduct(PromotionId = p.Id, ProductId = prod.Id);
    insert pp;

    Test.startTest();
    delete pp;
    Test.stopTest();

    Integer cnt = [SELECT COUNT() FROM PromotionProduct WHERE Id = :pp.Id];
    System.assertEquals(0, cnt);
  }
}
