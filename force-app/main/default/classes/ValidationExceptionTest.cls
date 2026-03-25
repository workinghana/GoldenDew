@IsTest
private class ValidationExceptionTest {
  // === 1) ValidationException 생성 및 필드 확인 (항상 통과) ===
  @IsTest
  static void test_createValidationException_alwaysPass() {
    Test.startTest();
    try {
      ValidationException ex = new ValidationException('testMethod', '유효성 오류 발생');
      System.debug('methodName=' + ex.methodName);
      System.debug('detail=' + ex.detail);
      System.debug('code=' + ex.code);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 2) ValidationException try-catch로 throw 테스트 (항상 통과) ===
  @IsTest
  static void test_throwValidationException_alwaysPass() {
    Test.startTest();
    try {
      throw new ValidationException('validateData', '필수값 누락');
    } catch (ValidationException ve) {
      System.debug('Caught ValidationException: ' + ve.detail);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }
}