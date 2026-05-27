/**
 * LoyaltyValidatorScheduler 테스트.
 */
@IsTest
private class LoyaltyValidatorSchedulerTest {

  @IsTest
  static void schedule_eventMode_runsCleanly() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    String jobId = System.schedule(
      'TEST_LoyaltyValidator_Event',
      '0 0 1 * * ?',
      new LoyaltyValidatorScheduler(LoyaltyValidatorScheduler.Mode.EVENT, 30)
    );
    Test.stopTest();
    System.assertNotEquals(null, jobId);
  }

  @IsTest
  static void schedule_memberMode_runsCleanly() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    String jobId = System.schedule(
      'TEST_LoyaltyValidator_Member',
      '0 0 2 * * ?',
      new LoyaltyValidatorScheduler(LoyaltyValidatorScheduler.Mode.MEMBER, 7)
    );
    Test.stopTest();
    System.assertNotEquals(null, jobId);
  }

  @IsTest
  static void schedule_defaultConstructor_runsCleanly() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    String jobId = System.schedule(
      'TEST_LoyaltyValidator_Default',
      '0 0 3 * * ?',
      new LoyaltyValidatorScheduler()
    );
    Test.stopTest();
    System.assertNotEquals(null, jobId);
  }

  @IsTest
  static void schedule_nullParams_usesDefaults() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    String jobId = System.schedule(
      'TEST_LoyaltyValidator_NullParams',
      '0 0 4 * * ?',
      new LoyaltyValidatorScheduler(null, null)
    );
    Test.stopTest();
    System.assertNotEquals(null, jobId);
  }

  @IsTest
  static void mode_enumValues_areDefined() {
    System.assertEquals(2, LoyaltyValidatorScheduler.Mode.values().size());
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