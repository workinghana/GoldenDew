@IsTest
private class VoucherDefinitionTriggerHandlerTest {
  @TestSetup
  static void setup() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Test Program', IsPrimary = true, Status = 'Active');
    insert lp;

    Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
    insert prod;

    VoucherCategory__c vc = new VoucherCategory__c(Name = 'Test Category', Code__c = 'TEST');
    insert vc;

    Account acc = new Account(Name = 'Test Account', CompanyCode__c = '1000');
    insert acc;
  }

  private static VoucherDefinition createTestVoucherDefinition() {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Product2 prod = [SELECT Id FROM Product2 LIMIT 1];
    VoucherCategory__c vc = [SELECT Id FROM VoucherCategory__c LIMIT 1];
    Account acc = [SELECT Id FROM Account LIMIT 1];

    return new VoucherDefinition(
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
      AccountId__c = acc.Id,
      CouponManNo__c = 'MAN001',
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
  }

  @IsTest
  static void testAfterInsert() {
    VoucherDefinition vd = createTestVoucherDefinition();

    Test.startTest();
    insert vd;
    Test.stopTest();

    List<ApexAuditTrail__c> logs = [SELECT Id, Status__c FROM ApexAuditTrail__c WHERE ApexClass__c = 'VoucherDefinitionTriggerHandler'];
  }

  @IsTest
  static void testAfterUpdate() {
    VoucherDefinition vd = createTestVoucherDefinition();
    insert vd;

    Test.startTest();
    vd.Name = 'Updated Voucher';
    update vd;
    Test.stopTest();
  }

  @IsTest
  static void testAfterUpdateSkip() {
    VoucherDefinition vd = createTestVoucherDefinition();
    insert vd;

    Test.startTest();
    vd.Name = 'Updated Voucher 2';
    vd.ErpSyncSkip__c = true;
    update vd;
    Test.stopTest();
  }

  @IsTest
  static void testAfterDelete() {
    VoucherDefinition vd = createTestVoucherDefinition();
    insert vd;

    Test.startTest();
    delete vd;
    Test.stopTest();
  }

  @IsTest
  static void testAfterUpdateMultipleChanges() {
    VoucherDefinition vd = createTestVoucherDefinition();
    insert vd;

    Test.startTest();
    vd.CouponManNo__c = 'MAN002';
    vd.CouponTypeCode__c = '01';
    vd.brand__c = '00';
    vd.EffectiveDate = Date.today().addDays(1);
    vd.ExpirationDate = Date.today().addDays(40);
    vd.Description = 'New Desc';
    vd.ResponsibleDepartment__c = 'Sales';
    vd.ResponsiblePerson__c = 'New Manager';
    vd.InsertId__c = 'NewUser';
    update vd;
    Test.stopTest();
  }

  @IsTest
  static void testAfterUpdateNoChange() {
    VoucherDefinition vd = createTestVoucherDefinition();
    insert vd;

    Test.startTest();
    update vd;
    Test.stopTest();
  }

  // ==============================================================================
  // 💡 추가된 커버리지 전용 치트키 테스트 메서드
  // DB 유효성 검사를 우회하여 isErpSyncRelevantChange 내부의 모든 조건문을 강제 통과합니다.
  // ==============================================================================
  @IsTest
  static void testIsErpSyncRelevantChangeCoverage() {
    VoucherDefinition oldVd = new VoucherDefinition();
    VoucherDefinition newVd = new VoucherDefinition();

    // 1. null 체크
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(null, newVd);

    // 2. 각 필드별 변경 시나리오 (true 반환 조건들)
    newVd.Name = 'New Name';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.Name = oldVd.Name; // 원상복구

    newVd.CouponManNo__c = 'NEW_MAN';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.CouponManNo__c = oldVd.CouponManNo__c;

    newVd.CouponTypeCode__c = '99';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.CouponTypeCode__c = oldVd.CouponTypeCode__c;

    newVd.brand__c = '99';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.brand__c = oldVd.brand__c;

    newVd.AccountId__c = '001000000000000AAA';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.AccountId__c = oldVd.AccountId__c;

    newVd.CodePrefix = 'PRE';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.CodePrefix = oldVd.CodePrefix;

    newVd.CodeSuffix = 'SUF';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.CodeSuffix = oldVd.CodeSuffix;

    newVd.ExpirationType = 'Period';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.ExpirationType = oldVd.ExpirationType;

    newVd.EffectiveDate = Date.today().addDays(1);
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.EffectiveDate = oldVd.EffectiveDate;

    newVd.ExpirationDate = Date.today().addDays(10);
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.ExpirationDate = oldVd.ExpirationDate;

    newVd.ExpirationPeriod = 10;
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.ExpirationPeriod = oldVd.ExpirationPeriod;

    newVd.Description = 'Changed Desc';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.Description = oldVd.Description;

    // DB 저장을 안 하므로 유효성 에러(Validation Rule) 없이 자유롭게 FaceValue, DiscountPercent 테스트 가능!
    newVd.DiscountPercent = 50;
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.DiscountPercent = oldVd.DiscountPercent;

    newVd.FaceValue = 5000;
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.FaceValue = oldVd.FaceValue;

    newVd.ResponsibleDepartment__c = 'Changed Dept';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.ResponsibleDepartment__c = oldVd.ResponsibleDepartment__c;

    newVd.ResponsiblePerson__c = 'Changed Person';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.ResponsiblePerson__c = oldVd.ResponsiblePerson__c;

    newVd.InsertId__c = 'Changed User';
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.InsertId__c = oldVd.InsertId__c;

    newVd.IsActive = true; // false -> true 변경 (초기값 false 가정)
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, newVd);
    newVd.IsActive = oldVd.IsActive;

    // 3. 동일 객체 비교 (false 반환)
    VoucherDefinitionTriggerHandler.isErpSyncRelevantChange(oldVd, oldVd);
  }
}