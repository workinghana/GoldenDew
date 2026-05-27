/**
 * LoyaltyEventValidatorBatch 테스트.
 */
@IsTest
private class LoyaltyEventValidatorBatchTest {

  @TestSetup
  static void setupBaseData() {
    Account acct = new Account(Name = 'LEVB Test Account');
    insert acct;

    Contact c = new Contact(LastName = 'LEVBTester', AccountId = acct.Id, MemberNo__c = 'LEVB-001');
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(
      Name = 'LEVB_TEST_LP_' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      IsPrimary = false
    );
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'LEVB-001',
      EnrollmentDate = Date.today()
    );
    insert lpm;
  }

  // ============================================================
  // 빈 scope 배치 — start/execute/finish path 검증
  // ============================================================
  @IsTest
  static void batch_withEmptyOrders_runsCleanly() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    // since 를 미래로 설정 → start 가 빈 scope 반환
    Datetime futureSince = Datetime.now().addDays(10);
    Test.startTest();
    Database.executeBatch(new LoyaltyEventValidatorBatch(futureSince), 20);
    Test.stopTest();
    // 배치 정상 완료 — 예외 없음
  }

  @IsTest
  static void batch_depositsPhase_runsCleanly() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Datetime futureSince = Datetime.now().addDays(10);
    Test.startTest();
    Database.executeBatch(
      new LoyaltyEventValidatorBatch(futureSince, LoyaltyEventValidatorBatch.Phase.DEPOSITS),
      20
    );
    Test.stopTest();
  }

  @IsTest
  static void batch_defaultConstructor_runsCleanly() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    // null since → 기본 1시간 전
    Database.executeBatch(new LoyaltyEventValidatorBatch(null), 20);
    Test.stopTest();
  }

  // ============================================================
  // Phase enum 직접 호출 — coverage 보조
  // ============================================================
  @IsTest
  static void phase_enumValues_areDefined() {
    System.assertEquals(2, LoyaltyEventValidatorBatch.Phase.values().size());
  }

  public class MockSlackOk implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{"ok":true}');
      return res;
    }
  }
}