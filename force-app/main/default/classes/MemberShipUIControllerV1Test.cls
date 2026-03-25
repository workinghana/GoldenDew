@IsTest
private class MemberShipUIControllerV1Test {
  private static String pickFirst(Schema.SObjectField fieldRef, String fallback) {
    List<Schema.PicklistEntry> entries = fieldRef.getDescribe().getPicklistValues();
    return entries.isEmpty() ? fallback : entries[0].getValue();
  }

  @TestSetup
  static void setup() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP', IsPrimary = true);
    insert lp;

    LoyaltyTierGroup tg = new LoyaltyTierGroup(
      Name = 'TG',
      LoyaltyProgramId = lp.Id,
      TierModel = 'Fixed',
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tg;

    insert new LoyaltyTier(Name = 'Gold', LoyaltyTierGroupId = tg.Id, Grade__c = '01');
    insert new Contact(LastName = 'Tester', Grade__c = '01');

    BenefitType benefitType = new BenefitType(
      Name = 'MembershipBenefitType',
      ProcessType = pickFirst(BenefitType.ProcessType, 'Loyalty'),
      LoyaltyProgramId = lp.Id
    );
    insert benefitType;

    Benefit benefit = new Benefit(Name = '보상_구매 금액의 1% 지급', IsActive = true, BenefitTypeId = benefitType.Id, PurchasePointRate__c = 1);
    insert benefit;

    LoyaltyTier tier = [SELECT Id FROM LoyaltyTier LIMIT 1];
    insert new LoyaltyTierBenefit(Name = 'Gold-Benefit', LoyaltyTierId = tier.Id, BenefitId = benefit.Id);

    Product2 p = new Product2(Name = 'Test Product', IsActive = true);
    insert p;

    VoucherCategory__c cat = new VoucherCategory__c(Name = 'CAT', Code__c = 'C01');
    insert cat;

    Account acc = new Account(Name = 'Voucher Company', CompanyCode__c = '1000');
    insert acc;

    insert new VoucherDefinition(
      Name = 'VD',
      LoyaltyProgramId = lp.Id,
      ProductId = p.Id,
      VoucherCategoryId__c = cat.Id,
      AccountId__c = acc.Id,
      IsActive = true,
      Type = 'ProductOrService',
      ExpirationType = pickFirst(VoucherDefinition.ExpirationType, 'FixedDate'),
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(10),
      CouponManNo__c = 'CPN-MEMBERSHIP-001',
      CouponTypeCode__c = pickFirst(VoucherDefinition.CouponTypeCode__c, '01'),
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
  }

  @IsTest
  static void test_all_flow() {
    Id tierId = [SELECT Id FROM LoyaltyTier LIMIT 1].Id;
    Id vdId = [SELECT Id FROM VoucherDefinition LIMIT 1].Id;

    insert new VoucherLimit__c(VoucherDefinitionId__c = vdId, Type__c = 'GradeIncludeList', Value__c = '01', IsActive__c = true);

    Test.startTest();
    MemberShipUIControllerV1.MemberShipDetailDto detail = MemberShipUIControllerV1.getMemberTierView(tierId);
    MemberShipUIControllerV1.getMemberTierView(null);
    MemberShipUIControllerV1.getTierCouponOptions(tierId);
    MemberShipUIControllerV1.issueTierCoupon(tierId, vdId);

    try {
      MemberShipUIControllerV1.issueTierCoupon(null, null);
      System.assert(false);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assertNotEquals(null, detail);
    System.assertEquals(1, detail.benefits.size());
    System.assertEquals('보상_구매 금액의 1% 지급', detail.benefits[0].benefitName);
    System.assertEquals(1, detail.benefits[0].rate);
  }

  @IsTest
  static void test_isVoucherAllowedForTier_cases() {
    Id vdId = [SELECT Id FROM VoucherDefinition LIMIT 1].Id;

    MemberShipUIControllerV1.isVoucherAllowedForTier(vdId, '01');

    insert new VoucherLimit__c(VoucherDefinitionId__c = vdId, Type__c = 'GradeIncludeList', Value__c = '01', IsActive__c = true);
    MemberShipUIControllerV1.isVoucherAllowedForTier(vdId, '01');

    insert new VoucherLimit__c(VoucherDefinitionId__c = vdId, Type__c = 'GradeIncludeList', Value__c = '02', IsActive__c = true);
    MemberShipUIControllerV1.isVoucherAllowedForTier(vdId, '01');
  }
}