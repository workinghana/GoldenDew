@IsTest
private class VoucherTriggerTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  @TestSetup
  static void setupTestData() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Voucher Trigger Test Program');
    insert lp;

    Product2 prod = new Product2(Name = 'Voucher Trigger Test Product', IsActive = true);
    insert prod;

    VoucherCategory__c vc = new VoucherCategory__c(Name = 'Voucher Trigger Test Category', Code__c = 'VTT');
    insert vc;

    Account acc = new Account(Name = 'Voucher Trigger Test Account', CompanyCode__c = '1000');
    insert acc;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Voucher Trigger Test Voucher',
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
    insert vd;

    Contact con = new Contact(LastName = 'Voucher Trigger Contact', AccountId = acc.Id, MemberNo__c = 'M001');
    insert con;

    insert new Voucher(
      VoucherDefinitionId = vd.Id,
      ContactId = con.Id,
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30)
    );
  }

  private static Voucher getVoucher() {
    return [
      SELECT Id, Status, EffectiveDate, ExpirationDate
      FROM Voucher
      LIMIT 1
    ];
  }

  @IsTest
  static void afterUpdate_statusChangedToExpired_enqueuesCouponUpdateJob() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Voucher testVoucher = getVoucher();

    Test.startTest();
    testVoucher.Status = 'Expired';
    update testVoucher;
    Test.stopTest();

    System.assertEquals('Expired', [SELECT Status FROM Voucher WHERE Id = :testVoucher.Id].Status);
  }

  @IsTest
  static void afterUpdate_expirationDateChanged_enqueuesCouponUpdateJob() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Voucher testVoucher = getVoucher();

    Test.startTest();
    testVoucher.ExpirationDate = Date.today().addDays(45);
    update testVoucher;
    Test.stopTest();

    System.assertEquals(Date.today().addDays(45), [SELECT ExpirationDate FROM Voucher WHERE Id = :testVoucher.Id].ExpirationDate);
  }

  @IsTest
  static void afterUpdate_withoutRelevantChange_doesNotEnqueueJob() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Voucher testVoucher = getVoucher();

    Test.startTest();
    testVoucher.Status = 'Issued';
    update testVoucher;
    System.assertEquals(0, Limits.getQueueableJobs(), 'Unchanged status and expiration date should not enqueue a job.');
    Test.stopTest();
  }
}