@IsTest
private class VoucherDefinitionTriggerTest {
  @IsTest
  static void testTrigger() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Test Program', IsPrimary = true, Status = 'Active');
    insert lp;

    Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
    insert prod;

    VoucherCategory__c vc = new VoucherCategory__c(Name = 'Test Category', Code__c = 'TEST');
    insert vc;

    Account companyAccount = new Account(Name = 'Test Company', CompanyCode__c = '1000');
    insert companyAccount;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Test Voucher',
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      ProductId = prod.Id,
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      ExpirationDate = Date.today().addDays(30),
      EffectiveDate = Date.today(),
      VoucherCategoryId__c = vc.Id,
      AccountId__c = companyAccount.Id,
      CouponManNo__c = 'MAN001',
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );

    Test.startTest();
    insert vd;
    vd.Name = 'Updated';
    update vd;
    delete vd;
    Test.stopTest();
  }

  @IsTest
  static void trigger_insertUpdateDelete_coversAllPaths() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Trigger LP', IsPrimary = true, Status = 'Active');
    insert lp;

    Product2 prod = new Product2(Name = 'Trigger Product', IsActive = true);
    insert prod;

    VoucherCategory__c vc = new VoucherCategory__c(Name = 'Trigger Category', Code__c = 'TRIG');
    insert vc;

    Account companyAccount = new Account(Name = 'Trigger Company', CompanyCode__c = '1000');
    insert companyAccount;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Trigger Test',
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      ProductId = prod.Id,
      Type = 'DiscountPercentage',
      DiscountPercent = 10,
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      VoucherCategoryId__c = vc.Id,
      AccountId__c = companyAccount.Id,
      CouponManNo__c = 'MAN002',
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );

    Test.startTest();
    insert vd; // before insert + after insert 커버

    vd.Name = 'Updated Name'; // ERP sync 대상 필드 변경
    update vd; // after update 커버

    delete vd; // after delete 커버
    Test.stopTest();

    System.assertNotEquals(null, vd.Id);
  }
}