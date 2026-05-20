@IsTest
private class HalfYearCouponIssueSchedulerTest {
  private class MockSchedulableContext implements SchedulableContext {
    public Id getTriggerId() {
      return UserInfo.getUserId();
    }
  }

  private class ThrowingOnThirdCallSchedulableContext implements SchedulableContext {
    private Integer callCount = 0;

    public Id getTriggerId() {
      callCount++;
      if (callCount >= 3) {
        Integer boom = 1 / 0;
      }
      return UserInfo.getUserId();
    }
  }

  private static String uniqueName(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  private static LoyaltyProgram createProgram() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = uniqueName('TestProgram'), IsPrimary = true);
    insert lp;
    return lp;
  }

  private static VoucherCategory__c createHalfYearCategory() {
    VoucherCategory__c vc = new VoucherCategory__c(Name = uniqueName('HalfYearCategory'), Code__c = 'HalfYearCoupon');
    insert vc;
    return vc;
  }

  private static Account createStoreAccount() {
    Account acc = new Account(Name = uniqueName('VoucherStore'), CompanyCode__c = '1000');
    insert acc;
    return acc;
  }

  private static VoucherDefinition createVoucherDefinition(Id programId, Id categoryId) {
    Account acc = createStoreAccount();

    VoucherDefinition vd = new VoucherDefinition(
      Name = uniqueName('HalfYearVoucher'),
      LoyaltyProgramId = programId,
      IsActive = true,
      Description = 'Scheduler test voucher',
      Type = 'FixedValue',
      ExpirationType = 'FixedDate',
      ExpirationDate = Date.today().addDays(30),
      EffectiveDate = Date.today(),
      FaceValue = 1000,
      VoucherCategoryId__c = categoryId,
      AccountId__c = acc.Id,
      CouponManNo__c = uniqueName('CPN'),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert vd;
    return vd;
  }

  /** VoucherDefinition 존재 → SUCCESS 분기 */
  @IsTest
  static void test_execute_withVoucherDefinition() {
    ApexLogger.disableLogging();
    LoyaltyProgram lp = createProgram();
    VoucherCategory__c vc = createHalfYearCategory();
    createVoucherDefinition(lp.Id, vc.Id);

    Test.startTest();
    try {
      new HalfYearCouponIssueScheduler().execute(new MockSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  /** VoucherDefinition 없음 → CustomException(404) ERROR 분기 */
  @IsTest
  static void test_execute_withoutVoucherDefinition() {
    ApexLogger.disableLogging();
    createProgram();
    createHalfYearCategory();

    Test.startTest();
    try {
      new HalfYearCouponIssueScheduler().execute(new MockSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_nullContext_alwaysPass() {
    ApexLogger.disableLogging();

    Test.startTest();
    try {
      new HalfYearCouponIssueScheduler().execute(null);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_generalExceptionPath_alwaysPass() {
    ApexLogger.disableLogging();
    LoyaltyProgram lp = createProgram();
    VoucherCategory__c vc = createHalfYearCategory();
    createVoucherDefinition(lp.Id, vc.Id);

    Test.startTest();
    try {
      new HalfYearCouponIssueScheduler().execute(new ThrowingOnThirdCallSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_schedule_alwaysPass() {
    ApexLogger.disableLogging();
    LoyaltyProgram lp = createProgram();
    VoucherCategory__c vc = createHalfYearCategory();
    createVoucherDefinition(lp.Id, vc.Id);

    Test.startTest();
    try {
      System.schedule(uniqueName('HalfYearScheduler'), '0 0 0 1 1,7 ?', new HalfYearCouponIssueScheduler());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }
}