/**
 * LoyaltyPointInstantValidator 테스트 — LASEL 정밀 검증 강화 포함.
 */
@IsTest
private class LoyaltyPointInstantValidatorTest {
  private static final String TEST_MEMBER_NO = 'LPIV-TEST-001';

  @TestSetup
  static void setupBaseData() {
    Account acct = new Account(Name = 'LPIV Test Account');
    insert acct;

    Contact c = new Contact(LastName = 'LPIVTester', AccountId = acct.Id, MemberNo__c = TEST_MEMBER_NO);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(
      Name = 'LPIV_TEST_LP_' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
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

  // ============================================================
  // 기존 2개 테스트
  // ============================================================
  @IsTest
  static void validateByMemberNo_whenMemberMissing_returnsInvalidResult() {
    LoyaltyPointInstantValidator.ValidationResult result =
      LoyaltyPointInstantValidator.validateByMemberNo('NO_SUCH_MEMBER');
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateByContactIds_whenEmpty_returnsEmptyList() {
    List<LoyaltyPointInstantValidator.ValidationResult> results =
      LoyaltyPointInstantValidator.validateByContactIds(new Set<Id>());
    System.assertEquals(0, results.size());
  }

  // ============================================================
  // validateByMemberNo — 데이터 있는 회원
  // ============================================================
  @IsTest
  static void validateByMemberNo_withEmptyMember_returnsValid() {
    // LL/LMC/LASEL 없는 회원 — 모든 합계가 0 이므로 정합
    LoyaltyPointInstantValidator.ValidationResult result =
      LoyaltyPointInstantValidator.validateByMemberNo(TEST_MEMBER_NO);
    System.assertNotEquals(null, result);
    System.assertEquals(TEST_MEMBER_NO, result.memberNo);
    // LMC 없으면 lmcBalance=0, LL 없으면 calculated=0 → difference=0, lump 검증도 모두 0 → valid
    System.assertEquals(0, result.lmcBalance);
    System.assertEquals(0, result.calculatedBalance);
    System.assertEquals(0, result.lumpMismatchCount);
  }

  // ============================================================
  // validateByContactIds — 데이터 있는 contact
  // ============================================================
  @IsTest
  static void validateByContactIds_withMember_runs() {
    Id contactId = [SELECT ContactId FROM LoyaltyProgramMember WHERE MembershipNumber = :TEST_MEMBER_NO LIMIT 1].ContactId;
    List<LoyaltyPointInstantValidator.ValidationResult> results =
      LoyaltyPointInstantValidator.validateByContactIds(new Set<Id>{ contactId });
    System.assertEquals(1, results.size());
  }

  // ============================================================
  // validateAndAlert* — Slack mock
  // ============================================================
  @IsTest
  static void validateAndAlertByMemberNo_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyPointInstantValidator.validateAndAlertByMemberNo(TEST_MEMBER_NO);
    Test.stopTest();
    System.assertNotEquals(null, ok);
  }

  @IsTest
  static void validateAndAlertByMemberNo_missing_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyPointInstantValidator.validateAndAlertByMemberNo('NO_SUCH');
    Test.stopTest();
    System.assertNotEquals(null, ok);
  }

  // ============================================================
  // validateNegativeAggrByMemberNo / validateAndAlertNegativeAggrByMemberNo
  // ============================================================
  @IsTest
  static void validateNegativeAggrByMemberNo_runs() {
    LoyaltyPointInstantValidator.ValidationResult result =
      LoyaltyPointInstantValidator.validateNegativeAggrByMemberNo(TEST_MEMBER_NO);
    System.assertNotEquals(null, result);
  }

  @IsTest
  static void validateAndAlertNegativeAggrByMemberNo_noNegative_returnsTrue() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyPointInstantValidator.validateAndAlertNegativeAggrByMemberNo(TEST_MEMBER_NO);
    Test.stopTest();
    // 음수 없으면 true
    System.assertEquals(true, ok);
  }

  // ============================================================
  // validateAndAlertByContactIdsAsync — @future
  // ============================================================
  @IsTest
  static void validateAndAlertByContactIdsAsync_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Id contactId = [SELECT ContactId FROM LoyaltyProgramMember WHERE MembershipNumber = :TEST_MEMBER_NO LIMIT 1].ContactId;
    String json = JSON.serialize(new List<Id>{ contactId });
    Test.startTest();
    LoyaltyPointInstantValidator.validateAndAlertByContactIdsAsync(json);
    Test.stopTest();
  }

  @IsTest
  static void validateAndAlertByContactIdsAsync_blank_returns() {
    Test.startTest();
    LoyaltyPointInstantValidator.validateAndAlertByContactIdsAsync('');
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