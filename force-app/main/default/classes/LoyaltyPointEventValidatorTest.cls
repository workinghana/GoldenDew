/**
 * LoyaltyPointEventValidator 테스트 — 신규 메서드 포함.
 *
 * 전략:
 *   - null / 누락 입력 경로 (가드 클로즈 커버)
 *   - 최소 데이터 (Active LPM + LMC) 로 회원 단위 검증 메서드 실행 — 빈 결과 'valid' 확인
 *   - Slack callout 은 Test.setMock 으로 차단
 */
@IsTest
private class LoyaltyPointEventValidatorTest {
  private static final String TEST_MEMBER_NO = 'LPEV-TEST-001';

  @TestSetup
  static void setupBaseData() {
    Account acct = new Account(Name = 'LPEV Test Account');
    insert acct;

    Contact c = new Contact(
      LastName = 'LPEVTester',
      AccountId = acct.Id,
      MemberNo__c = TEST_MEMBER_NO
    );
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(
      Name = 'LPEV_TEST_LP_' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
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
  // 기존 4개 테스트 — 변경 없이 유지
  // ============================================================
  @IsTest
  static void validateSaleDelete_whenSaleMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSaleDelete('NO_SUCH_SALE');
    System.assertEquals(false, result.isValid);
    System.assertEquals('SALE_DELETE', result.eventType);
  }

  @IsTest
  static void validateReturnCreate_whenReturnMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateReturnCreate('NO_SUCH_RETURN');
    System.assertEquals(false, result.isValid);
    System.assertEquals('RETURN_CREATE', result.eventType);
  }

  @IsTest
  static void validateSaleDepositDelete_whenDepositMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSaleDepositDelete('NO_SUCH_DEPOSIT');
    System.assertEquals(false, result.isValid);
    System.assertEquals('SALE_DEPOSIT_DELETE', result.eventType);
  }

  @IsTest
  static void validateReturnDepositDelete_whenDepositMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateReturnDepositDelete('NO_SUCH_DEPOSIT');
    System.assertEquals(false, result.isValid);
    System.assertEquals('RETURN_DEPOSIT_DELETE', result.eventType);
  }

  // ============================================================
  // 보강 #1 — validateReturnDelete
  // ============================================================
  @IsTest
  static void validateReturnDelete_whenSaleMissing_returnsInvalidResult() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateReturnDelete('NO_SUCH_RETURN');
    System.assertEquals(false, result.isValid);
    System.assertEquals('RETURN_DELETE', result.eventType);
  }

  @IsTest
  static void validateReturnDelete_withNullId_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateReturnDelete((Id) null);
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateAndAlertReturnDelete_withMissing_returnsFalseOrTrueButNoException() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyPointEventValidator.validateAndAlertReturnDelete('NO_SUCH_RETURN');
    Test.stopTest();
    System.assertNotEquals(null, ok);
  }

  // ============================================================
  // 보강 #2 — validateOptionCLumpMatching
  // ============================================================
  @IsTest
  static void validateOptionCLumpMatching_withNullMember_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateOptionCLumpMatching(null);
    System.assertEquals(false, result.isValid);
    System.assertEquals('OPTC_LUMP_MATCHING', result.eventType);
  }

  @IsTest
  static void validateOptionCLumpMatching_withEmptyMember_returnsValid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateOptionCLumpMatching(testMemberId());
    System.assertEquals(true, result.isValid);
    System.assertEquals(0, result.mismatchCount);
  }

  @IsTest
  static void validateAndAlertOptionCLumpMatching_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyPointEventValidator.validateAndAlertOptionCLumpMatching(testMemberId());
    Test.stopTest();
    System.assertEquals(true, ok);
  }

  // ============================================================
  // 보강 #3 — validateOriginCreditLLTrace
  // ============================================================
  @IsTest
  static void validateOriginCreditLLTrace_withNullMember_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateOriginCreditLLTrace(null);
    System.assertEquals(false, result.isValid);
    System.assertEquals('ORIGIN_CREDIT_LL_TRACE', result.eventType);
  }

  @IsTest
  static void validateOriginCreditLLTrace_withEmptyMember_returnsValid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateOriginCreditLLTrace(testMemberId());
    System.assertEquals(true, result.isValid);
  }

  @IsTest
  static void validateAndAlertOriginCreditLLTrace_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyPointEventValidator.validateAndAlertOriginCreditLLTrace(testMemberId());
    Test.stopTest();
    System.assertEquals(true, ok);
  }

  // ============================================================
  // 보강 #4 — DeposiSeqNo 오버로드 + ByTjId
  // ============================================================
  @IsTest
  static void validateSaleDepositDeleteWithSeqNo_whenMissing_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSaleDepositDelete('NO_DEPOSIT', '01');
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateReturnDepositDeleteWithSeqNo_whenMissing_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateReturnDepositDelete('NO_DEPOSIT', '02');
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateSaleDepositDeleteByTjId_withNull_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSaleDepositDeleteByTjId(null);
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateReturnDepositDeleteByTjId_withNull_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateReturnDepositDeleteByTjId(null);
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateAndAlertDepositDeleteOverloads_run() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    LoyaltyPointEventValidator.validateAndAlertSaleDepositDelete('NO_DEPOSIT', '01');
    LoyaltyPointEventValidator.validateAndAlertReturnDepositDelete('NO_DEPOSIT', '02');
    Test.stopTest();
  }

  // ============================================================
  // 보강 #5 — validateSaleCreate
  // ============================================================
  @IsTest
  static void validateSaleCreate_whenSaleMissing_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSaleCreate('NO_SUCH_SALE');
    System.assertEquals(false, result.isValid);
    System.assertEquals('SALE_CREATE', result.eventType);
  }

  @IsTest
  static void validateSaleCreate_withNullId_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSaleCreate((Id) null);
    System.assertEquals(false, result.isValid);
  }

  @IsTest
  static void validateAndAlertSaleCreate_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok1 = LoyaltyPointEventValidator.validateAndAlertSaleCreate('NO_SALE');
    Boolean ok2 = LoyaltyPointEventValidator.validateAndAlertSaleCreate((Id) null);
    Test.stopTest();
    System.assertNotEquals(null, ok1);
    System.assertNotEquals(null, ok2);
  }

  // ============================================================
  // 보강 #6 — validateSalePatchAccrualLump
  // ============================================================
  @IsTest
  static void validateSalePatchAccrualLump_withNullMember_returnsInvalid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSalePatchAccrualLump(null);
    System.assertEquals(false, result.isValid);
    System.assertEquals('OPTC_SALE_PATCH_LUMP', result.eventType);
  }

  @IsTest
  static void validateSalePatchAccrualLump_withEmptyMember_returnsValid() {
    LoyaltyPointEventValidator.ValidationResult result =
      LoyaltyPointEventValidator.validateSalePatchAccrualLump(testMemberId());
    System.assertEquals(true, result.isValid);
  }

  @IsTest
  static void validateAndAlertSalePatchAccrualLump_runs() {
    Test.setMock(HttpCalloutMock.class, new MockSlackOk());
    Test.startTest();
    Boolean ok = LoyaltyPointEventValidator.validateAndAlertSalePatchAccrualLump(testMemberId());
    Test.stopTest();
    System.assertEquals(true, ok);
  }

  // ============================================================
  // Slack mock
  // ============================================================
  public class MockSlackOk implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{"ok":true}');
      return res;
    }
  }
}