@IsTest
private class PromotionTriggerTest {
  // 핸들러 내부에서 발생할 수 있는 Callout에 대한 Mock 처리
  private class MockHttpResponseGenerator implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"result": "success"}');
      res.setStatusCode(200);
      return res;
    }
  }

  @TestSetup
  static void setup() {
    // 프로모션 생성에 필요한 로열티 프로그램 데이터 생성
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Test Loyalty Program', IsPrimary = true, Status = 'Active');
    insert lp;
  }

  @IsTest
  static void testAfterInsert() {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];

    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

    Test.startTest();
    Promotion p = new Promotion(
      Name = 'Test Promotion Insert',
      LoyaltyProgramId = lp.Id,
      StartDate = Date.today(),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(30)
    );
    insert p;
    Test.stopTest();

    // ApexLogger를 통해 ApexAuditTrail__c 로그가 생성되었는지 검증
    List<ApexAuditTrail__c> logs = [
      SELECT Id, ApexClass__c
      FROM ApexAuditTrail__c
      WHERE ApexClass__c = 'PromotionTrigger'
    ];
    System.assert(!logs.isEmpty(), 'Insert 시 PromotionTrigger 로그가 생성되어야 합니다.');
  }

  @IsTest
  static void testAfterUpdate() {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Promotion p = new Promotion(
      Name = 'Test Promotion Update',
      LoyaltyProgramId = lp.Id,
      StartDate = Date.today(),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(30)
    );
    insert p;

    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

    Test.startTest();
    p.Name = 'Test Promotion Update Changed';
    update p;
    Test.stopTest();

    // Insert 로그 + Update 로그 확인
    List<ApexAuditTrail__c> logs = [
      SELECT Id
      FROM ApexAuditTrail__c
      WHERE ApexClass__c = 'PromotionTrigger'
    ];
    System.assert(logs.size() >= 2, 'Update 시 PromotionTrigger 로그가 추가로 생성되어야 합니다.');
  }

  @IsTest
  static void testAfterDelete() {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Promotion p = new Promotion(
      Name = 'Test Promotion Delete',
      LoyaltyProgramId = lp.Id,
      StartDate = Date.today(),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(30)
    );
    insert p;

    Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

    Test.startTest();
    delete p;
    Test.stopTest();

    // Insert 로그 + Delete 로그 확인
    List<ApexAuditTrail__c> logs = [
      SELECT Id
      FROM ApexAuditTrail__c
      WHERE ApexClass__c = 'PromotionTrigger'
    ];
    System.assert(logs.size() >= 2, 'Delete 시 PromotionTrigger 로그가 추가로 생성되어야 합니다.');
  }
}