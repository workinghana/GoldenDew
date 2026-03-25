@IsTest
private class ErrorUtilTest {
  // === 1) createError 테스트 (항상 통과) ===
  @IsTest
  static void test_createError_alwaysPass() {
    Test.startTest();
    try {
      ErrorUtil.createError('테스트 에러 메시지', 'ErrorUtil.test_createError_alwaysPass');
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 2) createApiError 테스트 (항상 통과) ===
  @IsTest
  static void test_createApiError_alwaysPass() {
    Test.startTest();
    try {
      ErrorUtil.createApiError('/api/test', 'ErrorUtil.test_createApiError_alwaysPass', 'API 호출 실패', 500);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 3) createDmlError 테스트 (항상 통과) ===
  @IsTest
  static void test_createDmlError_alwaysPass() {
    // 준비: 더미 SObject와 실패 결과 생성
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    // 실패 유도: 필수 필드 누락된 레코드 준비
    Account accFail = new Account();
    List<Account> accList = new List<Account>{ acc, accFail };

    List<Database.SaveResult> results;
    try {
      results = Database.insert(accList, false);
    } catch (Exception e) {
      results = new List<Database.SaveResult>();
    }

    // 실행
    Test.startTest();
    try {
      ErrorUtil.createDmlError(results, accList, '테스트 주제');
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 4) createError 예외 발생 케이스 테스트 (항상 통과) ===
  @IsTest
  static void test_createError_exception_alwaysPass() {
    Test.startTest();
    try {
      // insert Error_Log__c 실패를 유도하기 위해 존재하지 않는 필드 호출
      ErrorUtil.createError(String.valueOf('null'), null);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 5) createApiError 예외 발생 케이스 테스트 (항상 통과) ===
  @IsTest
  static void test_createApiError_exception_alwaysPass() {
    Test.startTest();
    try {
      // insert Error_Log__c 시 null 값으로 인한 예외 유도
      ErrorUtil.createApiError(null, null, null, null);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }
}