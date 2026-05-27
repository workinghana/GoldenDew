/**
 * LoyaltyHelpInfoValidator 테스트.
 */
@IsTest
private class LoyaltyHelpInfoValidatorTest {
  private static final String TEST_MEMBER_NO = 'LHIV-TEST-001';

  @TestSetup
  static void setupBaseData() {
    Account acct = new Account(Name = 'LHIV Test Account');
    insert acct;

    Contact c = new Contact(LastName = 'LHIVTester', AccountId = acct.Id, MemberNo__c = TEST_MEMBER_NO);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(
      Name = 'LHIV_TEST_LP_' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      IsPrimary = false
    );
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = TEST_MEMBER_NO,
      EnrollmentDate = Date.today()
    );
    insert lpm;
  }

  private static Id testMemberId() {
    return [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = :TEST_MEMBER_NO LIMIT 1].Id;
  }

  // ============================================================
  // validateMember
  // ============================================================
  @IsTest
  static void validateMember_withNull_returnsInvalid() {
    LoyaltyHelpInfoValidator.ValidationResult result =
      LoyaltyHelpInfoValidator.validateMember(null);
    System.assertEquals(false, result.isValid);
    System.assertEquals('회원 ID가 필요합니다.', result.summary);
  }

  @IsTest
  static void validateMember_withEmptyMember_returnsValid() {
    LoyaltyHelpInfoValidator.ValidationResult result =
      LoyaltyHelpInfoValidator.validateMember(testMemberId());
    System.assertEquals(true, result.isValid);
    System.assertEquals(0, result.llWithoutTjCount);
    System.assertEquals(0, result.llReferencingDeletedTjCount);
    System.assertEquals(0, result.debitLLWithoutLLTCount);
    System.assertEquals(0, result.orphanLLTCount);
    System.assertEquals(0, result.cancelTjWithoutCreditLLCount);
  }

  // ============================================================
  // validateMemberByNo
  // ============================================================
  @IsTest
  static void validateMemberByNo_withBlank_returnsInvalid() {
    LoyaltyHelpInfoValidator.ValidationResult result =
      LoyaltyHelpInfoValidator.validateMemberByNo('');
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateMemberByNo_withMissing_returnsInvalid() {
    LoyaltyHelpInfoValidator.ValidationResult result =
      LoyaltyHelpInfoValidator.validateMemberByNo('NO_SUCH');
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateMemberByNo_withMember_returnsResult() {
    LoyaltyHelpInfoValidator.ValidationResult result =
      LoyaltyHelpInfoValidator.validateMemberByNo(TEST_MEMBER_NO);
    System.assertNotEquals(null, result);
    System.assertEquals(true, result.isValid);
  }

  // ============================================================
  // validateAndAlert / validateAndAlertByNo
  // ============================================================
  @IsTest
  static void validateAndAlert_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyHelpInfoValidator.validateAndAlert(testMemberId());
    Test.stopTest();
    System.assertEquals(true, ok); // empty member 는 valid → alert 없음 → true
  }

  @IsTest
  static void validateAndAlert_withNull_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyHelpInfoValidator.validateAndAlert(null);
    Test.stopTest();
    System.assertNotEquals(null, ok);
  }

  @IsTest
  static void validateAndAlertByNo_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyHelpInfoValidator.validateAndAlertByNo(TEST_MEMBER_NO);
    Test.stopTest();
    System.assertEquals(true, ok);
  }

  @IsTest
  static void validateAndAlertByNo_missing_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyHelpInfoValidator.validateAndAlertByNo('NO_SUCH');
    Test.stopTest();
    System.assertNotEquals(null, ok);
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