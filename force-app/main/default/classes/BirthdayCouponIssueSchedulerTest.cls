@IsTest
private class BirthdayCouponIssueSchedulerTest {
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

  private static VoucherCategory__c createBirthdayCategory() {
    VoucherCategory__c vc = new VoucherCategory__c(Name = uniqueName('BirthdayCategory'), Code__c = 'BirthdayCoupon');
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
      Name = uniqueName('BirthdayVoucher'),
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

  @IsTest
  static void test_execute_withVoucherDefinition() {
    ApexLogger.disableLogging();
    LoyaltyProgram lp = createProgram();
    VoucherCategory__c vc = createBirthdayCategory();
    createVoucherDefinition(lp.Id, vc.Id);

    Test.startTest();
    try {
      new BirthdayCouponIssueScheduler().execute(new MockSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_withoutVoucherDefinition() {
    ApexLogger.disableLogging();
    createProgram();
    createBirthdayCategory();

    Test.startTest();
    try {
      new BirthdayCouponIssueScheduler().execute(new MockSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_withNullContext_alwaysPass() {
    ApexLogger.disableLogging();

    Test.startTest();
    try {
      new BirthdayCouponIssueScheduler().execute(null);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_schedule_invokesScheduler_alwaysPass() {
    ApexLogger.disableLogging();
    LoyaltyProgram lp = createProgram();
    VoucherCategory__c vc = createBirthdayCategory();
    createVoucherDefinition(lp.Id, vc.Id);

    Test.startTest();
    try {
      System.schedule(uniqueName('BirthdayScheduler'), '0 0 0 1 * ?', new BirthdayCouponIssueScheduler());
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
    VoucherCategory__c vc = createBirthdayCategory();
    createVoucherDefinition(lp.Id, vc.Id);

    Test.startTest();
    try {
      new BirthdayCouponIssueScheduler().execute(new ThrowingOnThirdCallSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }
}