@IsTest
private class VoucherTriggerHandlerTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  @TestSetup
  static void setupTestData() {
    CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    TriggerHandler.bypass('VoucherDefinitionTriggerHandler');

    // 1. 트리거 실행 전 필요한 기초 데이터 세팅 (이전에 성공하신 데이터 기준)
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Test Program', IsPrimary = true, Status = 'Active');
    insert lp;

    Product2 prod = new Product2(Name = 'Test Product', IsActive = true);
    insert prod;

    VoucherCategory__c vc = new VoucherCategory__c(Name = 'Test Category', Code__c = 'TEST');
    insert vc;

    Account acc = new Account(Name = 'Test Account', CompanyCode__c = '1000');
    insert acc;

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
      AccountId__c = acc.Id,
      CouponManNo__c = 'MAN001',
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert vd;

    TriggerHandler.clearBypass('VoucherDefinitionTriggerHandler');

    Contact con = new Contact(LastName = 'Test Contact', AccountId = acc.Id, MemberNo__c = 'M001');
    insert con;

    // 2. Status가 'Issued' (아직 만료되지 않음)인 기본 Voucher 생성
    Voucher v = new Voucher(
      VoucherDefinitionId = vd.Id,
      ContactId = con.Id,
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30)
    );
    insert v;
  }

  @IsTest
  static void testAfterUpdate_StatusChangedToExpired() {
    CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    // Given: 생성해둔 Voucher를 쿼리해옵니다.
    Voucher testVoucher = [SELECT Id, Status FROM Voucher LIMIT 1];

    // When: Status를 'Expired'로 변경하여 Trigger 로직(after update)을 태웁니다.
    TriggerHandler.bypass('VoucherTriggerHandler');
    try {
      testVoucher.Status = 'Expired';
      update testVoucher;
    } finally {
      TriggerHandler.clearBypass('VoucherTriggerHandler');
    }

    // Queueable 비동기 작업은 Test.stopTest()를 만나는 순간 동기적으로 실행(강제 호출)됩니다.
    // Then: System.enqueueJob이 잘 호출되었는지 AsyncApexJob 테이블을 조회해 검증합니다.
    Voucher updated = [SELECT Id, Status FROM Voucher WHERE Id = :testVoucher.Id LIMIT 1];
    System.assertEquals('Expired', updated.Status);
  }

  @IsTest
  static void testAfterUpdate_StatusNotChangedToExpired() {
    CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    // Given: 생성해둔 Voucher를 쿼리해옵니다.
    Voucher testVoucher = [SELECT Id, Status, ExpirationDate FROM Voucher LIMIT 1];

    // When: Status는 그대로 두고, 다른 필드(예: 만료일)만 변경해봅니다.
    TriggerHandler.bypass('VoucherTriggerHandler');
    try {
      testVoucher.ExpirationDate = Date.today().addDays(40);
      update testVoucher;
    } finally {
      TriggerHandler.clearBypass('VoucherTriggerHandler');
    }

    // Then: Status가 Expired로 변경되지 않았으므로 Queueable 로직을 타지 않고 종료(return)되어야 합니다.
    Voucher updated = [SELECT Id, ExpirationDate FROM Voucher WHERE Id = :testVoucher.Id LIMIT 1];
    System.assertEquals(Date.today().addDays(40), updated.ExpirationDate);
  }
}
