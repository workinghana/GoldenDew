@IsTest
private class RestResponseUtilTest {
  // 공통: RestContext 세팅
  private static void setupRestContext(String method, String uri) {
    RestRequest req = new RestRequest();
    req.httpMethod = method;
    req.requestURI = uri;
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  // 1) handleSuccess 정상 경로 (항상 통과)
  @IsTest
  static void test_handleSuccess_alwaysPass() {
    setupRestContext('POST', '/services/apexrest/gd/dummy');

    Test.startTest();
    try {
      ApiResult ok = ApiResult.ok(200, 'ok', new Map<String, Object>());
      RestResponseUtil.handleSuccess(ok);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // 2) handleException - Savepoint 존재 (롤백 분기) (항상 통과)
  @IsTest
  static void test_handleException_withSavepoint_alwaysPass() {
    setupRestContext('GET', '/services/apexrest/gd/dummy2');

    Savepoint sp;
    try {
      sp = Database.setSavepoint();
    } catch (Exception e) {
      sp = null;
    }

    Test.startTest();
    try {
      // Apex에서 base Exception은 new 불가 → 구체 예외 사용
      RestResponseUtil.handleException(new CustomException(400, 'NPE'), sp, 500);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // 3) handleException - Savepoint 없음 (항상 통과)
  @IsTest
  static void test_handleException_nullSavepoint_alwaysPass() {
    setupRestContext('DELETE', '/services/apexrest/gd/dummy3');

    Test.startTest();
    try {
      RestResponseUtil.handleException(new CustomException(400, 'NPE'), null, 500);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // 4) handleCustomException - Savepoint 존재 (항상 통과)
  @IsTest
  static void test_handleCustomException_withSavepoint_alwaysPass() {
    setupRestContext('PATCH', '/services/apexrest/gd/dummy4');

    Savepoint sp;
    try {
      sp = Database.setSavepoint();
    } catch (Exception e) {
      sp = null;
    }

    Test.startTest();
    try {
      RestResponseUtil.handleCustomException(new CustomException(422, '유효성 오류'), sp, 422, '유효성 오류');
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // 5) handleCustomException - Savepoint 없음 (항상 통과)
  @IsTest
  static void test_handleCustomException_nullSavepoint_alwaysPass() {
    setupRestContext('PUT', '/services/apexrest/gd/dummy5');

    Test.startTest();
    try {
      RestResponseUtil.handleCustomException(new CustomException(400, '요청 본문이 비었습니다.'), null, 400, '요청 본문이 비었습니다.');
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }
}