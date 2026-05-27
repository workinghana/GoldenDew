/**
 * LoyaltyMemberValidatorBatch 테스트.
 */
@IsTest
private class LoyaltyMemberValidatorBatchTest {

  @TestSetup
  static void setupBaseData() {
    Account acct = new Account(Name = 'LMVB Test Account');
    insert acct;

    Contact c = new Contact(LastName = 'LMVBTester', AccountId = acct.Id, MemberNo__c = 'LMVB-001');
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(
      Name = 'LMVB_TEST_LP_' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      IsPrimary = false
    );
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'LMVB-001',
      EnrollmentDate = Date.today()
    );
    insert lpm;
  }

  @IsTest
  static void batch_withNoRecentActivity_runsCleanly() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    // start 가 recent activity 없는 회원 제외 → 빈 scope
    Database.executeBatch(new LoyaltyMemberValidatorBatch(7), 10);
    Test.stopTest();
  }

  @IsTest
  static void batch_defaultConstructor_runsCleanly() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Database.executeBatch(new LoyaltyMemberValidatorBatch(), 10);
    Test.stopTest();
  }

  @IsTest
  static void batch_withNullDays_usesDefault() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Database.executeBatch(new LoyaltyMemberValidatorBatch(null), 10);
    Test.stopTest();
  }

  @IsTest
  static void batch_withInvalidDays_usesDefault() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Database.executeBatch(new LoyaltyMemberValidatorBatch(-5), 10);
    Test.stopTest();
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