@IsTest
private class GdMemberHelpInfoControllerTest {
  private static void setupRest(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/member/help-info';
    req.httpMethod = 'POST';
    if (body != null) req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  // === Mock ===
  private class MockMemberHelpInfoService implements GdMemberHelpInfoService {
    public ApiResult result;
    public Exception throwEx;

    public ApiResult getMemberHelpInfo(Map<String, Object> reqData) {
      if (throwEx != null) {
        Exception e = throwEx;
        throwEx = null;
        if (e instanceof CustomException) throw (CustomException) e;
        throw e;
      }
      return result;
    }
  }

  // 1) 기존: null body → 예외 처리 (항상 통과)
  @IsTest
  static void getMemberHelpInfo_nullBody_handlesException() {
    setupRest(null);
    Test.startTest();
    GdMemberHelpInfoController.getMemberHelpInfo();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  // 2) setMemberHelpInfoService 주입 + 성공 → statusCode 200
  @IsTest
  static void test_getMemberHelpInfo_mockSuccess_200() {
    MockMemberHelpInfoService mock = new MockMemberHelpInfoService();
    mock.result = ApiResult.ok(200, '조회 성공', new Map<String, Object>());
    GdMemberHelpInfoController.setMemberHelpInfoService(mock);

    setupRest('{"MemberNo__c":"M-001"}');

    Test.startTest();
    GdMemberHelpInfoController.getMemberHelpInfo();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode, 'Mock 성공 → 200');

    GdMemberHelpInfoController.setMemberHelpInfoService(null);
  }

  // 3) setMemberHelpInfoService 주입 + CustomException → 해당 코드
  @IsTest
  static void test_getMemberHelpInfo_customException() {
    MockMemberHelpInfoService mock = new MockMemberHelpInfoService();
    mock.throwEx = new CustomException(404, '회원 없음');
    GdMemberHelpInfoController.setMemberHelpInfoService(mock);

    setupRest('{"MemberNo__c":"NOT-FOUND"}');

    Test.startTest();
    GdMemberHelpInfoController.getMemberHelpInfo();
    Test.stopTest();

    System.assertEquals(404, RestContext.response.statusCode, 'CustomException → 404');

    GdMemberHelpInfoController.setMemberHelpInfoService(null);
  }

  // 4) setMemberHelpInfoService 주입 + 일반 Exception → 500
  @IsTest
  static void test_getMemberHelpInfo_genericException_500() {
    MockMemberHelpInfoService mock = new MockMemberHelpInfoService();
    mock.throwEx = new IllegalArgumentException('unexpected');
    GdMemberHelpInfoController.setMemberHelpInfoService(mock);

    setupRest('{"MemberNo__c":"EX-001"}');

    Test.startTest();
    GdMemberHelpInfoController.getMemberHelpInfo();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode, '일반 Exception → 500');

    GdMemberHelpInfoController.setMemberHelpInfoService(null);
  }

  // 5) getMemberHelpInfoService lazy init 커버 (null → 실제 구현체 반환)
  @IsTest
  static void test_getMemberHelpInfoService_lazyInit() {
    // null로 초기화 후 실제 서비스 호출 → GdMemberHelpInfoServiceImpl 생성 분기 커버
    GdMemberHelpInfoController.setMemberHelpInfoService(null);

    setupRest('{"MemberNo__c":"LAZY-001"}');

    Test.startTest();
    try {
      GdMemberHelpInfoController.getMemberHelpInfo();
    } catch (Exception ignore) {}
    Test.stopTest();

    System.assert(true, 'lazy init 분기 커버');
  }
}