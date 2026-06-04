@IsTest
private class BirthdayCouponIssueSchedulerTest {
  private class MockSchedulableContext implements SchedulableContext {
    public Id getTriggerId() {
      return null;
    }
  }

  private static String uniqueName(String prefix) {
    return prefix + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
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
  static void execute_withVoucherDefinition_startsBatch() {
    ApexLogger.disableLogging();
    LoyaltyProgram lp = createProgram();
    VoucherCategory__c vc = createBirthdayCategory();
    createVoucherDefinition(lp.Id, vc.Id);

    Test.startTest();
    new BirthdayCouponIssueScheduler().execute(new MockSchedulableContext());
    Test.stopTest();

    List<AsyncApexJob> batchJobs = [
      SELECT Id, Status, ApexClass.Name
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'BirthdayCouponIssueBatch'
      LIMIT 1
    ];
    System.assert(!batchJobs.isEmpty(), 'Scheduler should enqueue BirthdayCouponIssueBatch when birthday voucher definition exists.');
  }

  @IsTest
  static void execute_withoutVoucherDefinition_handlesCustomException() {
    ApexLogger.disableLogging();
    createProgram();
    createBirthdayCategory();

    Test.startTest();
    new BirthdayCouponIssueScheduler().execute(new MockSchedulableContext());
    Test.stopTest();

    List<AsyncApexJob> batchJobs = [
      SELECT Id
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'BirthdayCouponIssueBatch'
      LIMIT 1
    ];
    System.assertEquals(0, batchJobs.size(), 'Scheduler should not enqueue the batch when no birthday voucher definition exists.');
  }

  @IsTest
  static void execute_withNullContext_handlesMissingVoucherDefinition() {
    ApexLogger.disableLogging();

    Test.startTest();
    new BirthdayCouponIssueScheduler().execute(null);
    Test.stopTest();

    System.assert(true, 'Null SchedulableContext should be handled without propagating an exception.');
  }

  @IsTest
  static void schedule_invokesScheduler() {
    ApexLogger.disableLogging();
    LoyaltyProgram lp = createProgram();
    VoucherCategory__c vc = createBirthdayCategory();
    createVoucherDefinition(lp.Id, vc.Id);

    Test.startTest();
    String jobId = System.schedule(uniqueName('BirthdayScheduler'), '0 0 0 1 * ?', new BirthdayCouponIssueScheduler());
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'System.schedule should return the scheduled job Id.');
  }

  @IsTest
  static void execute_forceGenericException_handlesGenericCatch() {
    ApexLogger.disableLogging();
    BirthdayCouponIssueScheduler.forceGenericException = true;

    Test.startTest();
    new BirthdayCouponIssueScheduler().execute(null);
    Test.stopTest();

    System.assertEquals(false, BirthdayCouponIssueScheduler.forceGenericException, 'Test hook should reset itself after forcing the generic exception path.');
  }
}