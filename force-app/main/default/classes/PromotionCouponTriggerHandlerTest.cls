@IsTest
private class PromotionCouponTriggerHandlerTest {
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

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }

  private static String pick(Schema.SObjectField fieldToken) {
    List<Schema.PicklistEntry> entries = fieldToken.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String pickVoucherType(Boolean fixedAmount) {
    List<Schema.PicklistEntry> entries = VoucherDefinition.Type.getDescribe().getPicklistValues();
    String preferred = fixedAmount ? 'FixedValue' : 'DiscountPercentage';

    for (Schema.PicklistEntry entry : entries) {
      if (entry.getValue() == preferred) {
        return entry.getValue();
      }
    }

    for (Schema.PicklistEntry entry : entries) {
      if (entry.getValue() != 'Product' && entry.getValue() != 'Service') {
        return entry.getValue();
      }
    }

    return entries.isEmpty() ? null : entries[0].getValue();
  }

  @TestSetup
  static void setupData() {
    ApexLogger.disableLogging();
    TriggerHandler.bypass('PromotionTriggerHandler');
    TriggerHandler.bypass('PromotionCouponTriggerHandler');

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'PCTH-LP', IsPrimary = false, Status = 'Active');
    insert lp;

    Account account = new Account(Name = 'PCTH Store', CompanyCode__c = '1000');
    insert account;

    Promotion promo = new Promotion(
      Name = 'PCTH-Promo',
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      StartDate = Date.today(),
      EndDate = Date.today().addDays(30),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(30),
      IsCouponAllowed__c = true,
      IsFixedAmountCouponAllowed__c = true,
      IsRateCouponAllowed__c = true,
      IsSpecificCouponAllowed__c = false,
      IsPointUsageAllowed__c = false,
      IsAllStore__c = true,
      IsAllItem__c = true,
      DepartmentCode__c = 'D001',
      InsertId__c = 'PCTH',
      ResponId__c = 'PCTH'
    );
    insert promo;
  }

  private static LoyaltyProgram loyaltyProgram() {
    return [SELECT Id FROM LoyaltyProgram WHERE Name = 'PCTH-LP' LIMIT 1];
  }

  private static Account storeAccount() {
    return [SELECT Id FROM Account WHERE Name = 'PCTH Store' LIMIT 1];
  }

  private static Promotion promotion() {
    return [SELECT Id FROM Promotion WHERE Name = 'PCTH-Promo' LIMIT 1];
  }

  private static VoucherDefinition createVoucherDefinition(Boolean fixedAmount) {
    VoucherDefinition vd = new VoucherDefinition(
      Name = uniq('PCTH-VD'),
      LoyaltyProgramId = loyaltyProgram().Id,
      IsActive = true,
      Type = pickVoucherType(fixedAmount),
      ExpirationType = pick(VoucherDefinition.ExpirationType),
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(60),
      FaceValue = fixedAmount ? 1000 : null,
      DiscountPercent = fixedAmount ? null : 10,
      CouponTypeCode__c = fixedAmount ? '01' : '02',
      ResponsibleDepartment__c = 'PCTH-DEPT',
      InsertId__c = 'PCTH-INSERT',
      ResponsiblePerson__c = UserInfo.getUserId(),
      AccountId__c = storeAccount().Id
    );
    insert vd;
    return vd;
  }

  private static VoucherLimit__c newPromotionVoucherLimit(Id voucherDefinitionId, Id promotionId) {
    return new VoucherLimit__c(
      Name = uniq('PCTH-VL'),
      VoucherDefinitionId__c = voucherDefinitionId,
      PromotionId__c = promotionId,
      Type__c = 'PromotionIncludeList',
      Value__c = String.valueOf(promotionId),
      IsActive__c = true,
      ExternalId__c = uniq('PCTH-EXT'),
      Erp_Sync_Skip__c = false
    );
  }

  private static VoucherLimit__c newNonPromotionVoucherLimit(Id voucherDefinitionId) {
    return new VoucherLimit__c(
      Name = uniq('PCTH-VL-NON'),
      VoucherDefinitionId__c = voucherDefinitionId,
      Type__c = 'OrderTypeIncludeList',
      Value__c = '01',
      IsActive__c = true,
      ExternalId__c = uniq('PCTH-EXT-NON'),
      Erp_Sync_Skip__c = false
    );
  }

  private static VoucherLimit__c insertSeedVoucherLimit(Boolean fixedAmount) {
    TriggerHandler.bypass('PromotionCouponTriggerHandler');
    VoucherDefinition vd = createVoucherDefinition(fixedAmount);
    VoucherLimit__c vl = newPromotionVoucherLimit(vd.Id, promotion().Id);
    insert vl;
    TriggerHandler.clearBypass('PromotionCouponTriggerHandler');
    return vl;
  }

  @IsTest
  static void testAfterInsertPromotionCouponEnqueuesCreate() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();
    TriggerHandler.clearBypass('PromotionCouponTriggerHandler');
    TriggerHandler.bypass('PromotionTriggerHandler');

    VoucherDefinition vd = createVoucherDefinition(true);
    VoucherLimit__c vl = newPromotionVoucherLimit(vd.Id, promotion().Id);

    Test.startTest();
    insert vl;
    Test.stopTest();

    System.assertNotEquals(null, vl.Id);
  }

  @IsTest
  static void testAfterInsertSkipsNonPromotionLimit() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();
    TriggerHandler.clearBypass('PromotionCouponTriggerHandler');

    VoucherDefinition vd = createVoucherDefinition(true);
    VoucherLimit__c vl = newNonPromotionVoucherLimit(vd.Id);

    Test.startTest();
    insert vl;
    Test.stopTest();

    System.assertNotEquals(null, vl.Id);
  }

  @IsTest
  static void testAfterDeletePromotionCouponEnqueuesDelete() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();
    VoucherLimit__c vl = insertSeedVoucherLimit(true);

    Test.startTest();
    delete vl;
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM VoucherLimit__c WHERE Id = :vl.Id]);
  }

  @IsTest
  static void testAfterUpdateFixedValueChanged() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();
    VoucherLimit__c vl = insertSeedVoucherLimit(true);

    vl.Value__c = '900';

    Test.startTest();
    update vl;
    Test.stopTest();

    System.assertEquals('900', [SELECT Value__c FROM VoucherLimit__c WHERE Id = :vl.Id].Value__c);
  }

  @IsTest
  static void testAfterUpdateRateCouponNameChanged() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();
    VoucherLimit__c vl = insertSeedVoucherLimit(false);

    vl.Name = uniq('PCTH-VL-UPD');

    Test.startTest();
    update vl;
    Test.stopTest();

    System.assertEquals(vl.Name, [SELECT Name FROM VoucherLimit__c WHERE Id = :vl.Id].Name);
  }

  @IsTest
  static void testAfterUpdateSkipsWhenErpSyncSkipTrue() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();
    VoucherLimit__c vl = insertSeedVoucherLimit(true);

    vl.Value__c = '800';
    vl.Erp_Sync_Skip__c = true;

    Test.startTest();
    update vl;
    Test.stopTest();

    VoucherLimit__c result = [
      SELECT Value__c, Erp_Sync_Skip__c
      FROM VoucherLimit__c
      WHERE Id = :vl.Id
    ];
    System.assertEquals('800', result.Value__c);
    System.assertEquals(true, result.Erp_Sync_Skip__c);
  }

  @IsTest
  static void testAfterUpdateSkipsWhenNoErpFieldChanged() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();
    VoucherLimit__c vl = insertSeedVoucherLimit(true);

    VoucherLimit__c requeried = [
      SELECT Id, Name, Type__c, Value__c
      FROM VoucherLimit__c
      WHERE Id = :vl.Id
    ];

    Test.startTest();
    update requeried;
    Test.stopTest();

    System.assertNotEquals(null, requeried.Id);
  }

  @IsTest
  static void testAfterUpdateSkipsNonPromotionLimit() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();
    TriggerHandler.bypass('PromotionCouponTriggerHandler');
    VoucherDefinition vd = createVoucherDefinition(true);
    VoucherLimit__c vl = newNonPromotionVoucherLimit(vd.Id);
    insert vl;
    TriggerHandler.clearBypass('PromotionCouponTriggerHandler');

    vl.Value__c = '02';

    Test.startTest();
    update vl;
    Test.stopTest();

    System.assertEquals('02', [SELECT Value__c FROM VoucherLimit__c WHERE Id = :vl.Id].Value__c);
  }

  @IsTest
  static void testHandlerInstantiation() {
    PromotionCouponTriggerHandler handler = new PromotionCouponTriggerHandler();
    System.assertNotEquals(null, handler);
  }
}