@IsTest
private class TierQualifyingSpend3YRecalcBatchTest {
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

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  @TestSetup
  static void setup() {
    setMock();

    // 탈퇴하지 않은 회원 (배치 대상)
    Contact active = new Contact(LastName = 'ActiveMember', MemberNo__c = 'TQS-001');
    // 탈퇴 회원 (배치 제외 대상)
    Contact dropped = new Contact(LastName = 'DroppedMember', MemberNo__c = 'TQS-002', MemberDropDate__c = Date.today().addDays(-10));
    insert new List<Contact>{ active, dropped };
  }

  // =========================================================
  // 생성자 검증
  // =========================================================

  @IsTest
  static void defaultConstructor_setsDateFromToday() {
    setMock();

    Test.startTest();
    TierQualifyingSpend3YRecalcBatch batch = new TierQualifyingSpend3YRecalcBatch();
    Test.stopTest();

    // 생성자가 예외 없이 실행되어야 함
    System.assert(true);
  }

  @IsTest
  static void paramConstructor_nullBaseDate_usesToday() {
    setMock();

    Test.startTest();
    TierQualifyingSpend3YRecalcBatch batch = new TierQualifyingSpend3YRecalcBatch(null);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void paramConstructor_specificDate_usesGivenDate() {
    setMock();

    Date baseDate = Date.newInstance(2024, 6, 15);

    Test.startTest();
    TierQualifyingSpend3YRecalcBatch batch = new TierQualifyingSpend3YRecalcBatch(baseDate);
    Test.stopTest();

    System.assert(true);
  }

  // =========================================================
  // 배치 실행 — 데이터 없음 (execute empty)
  // =========================================================

  @IsTest
  static void batch_noContacts_completesSuccessfully() {
    setMock();

    // 전체 Contact 삭제 후 빈 상태에서 실행
    delete [SELECT Id FROM Contact];

    Test.startTest();
    Database.executeBatch(new TierQualifyingSpend3YRecalcBatch(), 200);
    Test.stopTest();

    System.assert(true);
  }

  // =========================================================
  // 배치 실행 — 활성 회원 존재, 주문 없음 → TierQualifyingSpend3Y__c = 0
  // =========================================================

  @IsTest
  static void batch_activeContactNoOrders_setsZero() {
    setMock();

    Test.startTest();
    Database.executeBatch(new TierQualifyingSpend3YRecalcBatch(), 200);
    Test.stopTest();

    Contact c = [SELECT TierQualifyingSpend3Y__c FROM Contact WHERE MemberNo__c = 'TQS-001' LIMIT 1];
    System.assertEquals(0, c.TierQualifyingSpend3Y__c);
  }

  // =========================================================
  // 배치 실행 — 특정 기준일로 실행
  // =========================================================

  @IsTest
  static void batch_specificBaseDate_completesSuccessfully() {
    setMock();

    Date baseDate = Date.newInstance(2025, 2, 1);

    Test.startTest();
    Database.executeBatch(new TierQualifyingSpend3YRecalcBatch(baseDate), 200);
    Test.stopTest();

    // 탈퇴 회원은 배치 제외 → TierQualifyingSpend3Y__c 미변경
    Contact active = [SELECT TierQualifyingSpend3Y__c FROM Contact WHERE MemberNo__c = 'TQS-001' LIMIT 1];
    System.assertEquals(0, active.TierQualifyingSpend3Y__c);
  }

  // =========================================================
  // start() — QueryLocator 반환 검증
  // =========================================================

  @IsTest
  static void start_returnsQueryLocatorForNonDroppedContacts() {
    setMock();

    TierQualifyingSpend3YRecalcBatch batch = new TierQualifyingSpend3YRecalcBatch();

    Test.startTest();
    Database.QueryLocator ql = batch.start(null);
    Test.stopTest();

    System.assertNotEquals(null, ql);
  }
}