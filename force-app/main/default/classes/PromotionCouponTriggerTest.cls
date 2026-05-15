@IsTest
private class PromotionCouponTriggerTest {
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

  private static LoyaltyProgram createLoyaltyProgram() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('CouponProgram'), IsPrimary = true, Status = 'Active');
    insert lp;
    return lp;
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

  private static VoucherDefinition createVoucherDefinition() {
    LoyaltyProgram lp = createLoyaltyProgram();
    String typeValue = VoucherDefinition.Type.getDescribe().getPicklistValues()[0].getValue();
    String expirationTypeValue = VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue();
    VoucherDefinition vd = new VoucherDefinition(
      Name = uniq('VD'),
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      Type = typeValue,
      ExpirationType = expirationTypeValue,
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(365),
      FaceValue = 1000,
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'TEST-DEPT',
      InsertId__c = 'TEST-INSERT-001',
      ResponsiblePerson__c = UserInfo.getUserId()
    );
    insert vd;
    return vd;
  }

  private static VoucherLimit__c buildVoucherLimit(Id voucherDefinitionId, Id promotionId) {
    return new VoucherLimit__c(
      Name = uniq('VL'),
      VoucherDefinitionId__c = voucherDefinitionId,
      Type__c = 'PromotionIncludeList',
      Value__c = String.valueOf(promotionId),
      PromotionId__c = String.valueOf(promotionId),
      IsActive__c = true,
      ExternalId__c = uniq('COUPON'),
      Erp_Sync_Skip__c = false
    );
  }

  @IsTest
  static void trigger_afterInsert_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = createPromotion();
    VoucherDefinition vd = createVoucherDefinition();
    VoucherLimit__c vl = buildVoucherLimit(vd.Id, p.Id);

    Test.startTest();
    insert vl;
    Test.stopTest();

    System.assertNotEquals(null, vl.Id);
  }

  @IsTest
  static void trigger_afterUpdate_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = createPromotion();
    VoucherDefinition vd = createVoucherDefinition();
    VoucherLimit__c vl = buildVoucherLimit(vd.Id, p.Id);
    insert vl;

    vl.Value__c = String.valueOf(p.Id) + '-UPDATED';

    Test.startTest();
    update vl;
    Test.stopTest();

    VoucherLimit__c updated = [SELECT Id, Value__c FROM VoucherLimit__c WHERE Id = :vl.Id LIMIT 1];
    System.assertEquals(String.valueOf(p.Id) + '-UPDATED', updated.Value__c);
  }

  @IsTest
  static void trigger_afterUpdate_runs_otherCoupon() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = createPromotion();
    LoyaltyProgram lp = createLoyaltyProgram();
    VoucherDefinition vd = new VoucherDefinition(
      Name = uniq('VD'),
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      Type = 'FixedValue',
      ExpirationType = VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue(),
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(365),
      FaceValue = 1000,
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'TEST-DEPT',
      InsertId__c = 'TEST-INSERT-001',
      ResponsiblePerson__c = UserInfo.getUserId()
    );
    insert vd;
    VoucherLimit__c vl = buildVoucherLimit(vd.Id, p.Id);
    insert vl;

    vl.Value__c = String.valueOf(p.Id) + '-UPDATED';

    Test.startTest();
    update vl;
    Test.stopTest();

    VoucherLimit__c updated = [SELECT Id, Value__c FROM VoucherLimit__c WHERE Id = :vl.Id LIMIT 1];
    System.assertEquals(String.valueOf(p.Id) + '-UPDATED', updated.Value__c);
  }

  @IsTest
  static void trigger_afterDelete_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Promotion p = createPromotion();
    VoucherDefinition vd = createVoucherDefinition();
    VoucherLimit__c vl = buildVoucherLimit(vd.Id, p.Id);
    insert vl;

    Test.startTest();
    delete vl;
    Test.stopTest();

    Integer cnt = [SELECT COUNT() FROM VoucherLimit__c WHERE Id = :vl.Id];
    System.assertEquals(0, cnt);
  }
}
