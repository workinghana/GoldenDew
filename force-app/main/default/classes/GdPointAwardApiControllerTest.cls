@IsTest
private class GdPointAwardApiControllerTest {
  private static void setupRest(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/point/award';
    req.httpMethod = 'POST';
    if (body != null) {
      req.requestBody = Blob.valueOf(body);
    }
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  /**
   * GdPointService Stub Provider
   */
  private class GdPointServiceStubProvider implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbedObject,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      Map<String, Object> reqData = (args != null && !args.isEmpty())
        ? (Map<String, Object>) args[0]
        : null;

      if (methodName == 'creditPoint') {
        if (reqData != null && reqData.containsKey('throwCustom')) {
          throw new CustomException(400, '포인트 지급 커스텀 예외');
        }

        if (reqData != null && reqData.containsKey('throwException')) {
          Integer x = 1 / 0;
        }

        return ApiResult.ok(200, '포인트 지급 성공', new Map<String, Object>{
          'result' => 'credited'
        });
      }

      return null;
    }
  }

  private static void setMockPointService() {
    GdPointService pointStub = (GdPointService) Test.createStub(
      GdPointService.class,
      new GdPointServiceStubProvider()
    );
    GdPointAwardApiController.setPointService(pointStub);
  }

  @IsTest
  static void rewardPoints_emptyBody_handlesError() {
    setupRest(null);

    Test.startTest();
    GdPointAwardApiController.rewardPoints();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('요청 본문이 비었습니다.'));
  }

  @IsTest
  static void rewardPoints_invalidJson_handlesError() {
    setupRest('{invalid-json}');

    Test.startTest();
    GdPointAwardApiController.rewardPoints();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('JSON 역직렬화 실패'));
  }

  @IsTest
  static void rewardPoints_success() {
    setMockPointService();
    setupRest('{"MemberNo__c":"MT-001","points":1000}');

    Test.startTest();
    GdPointAwardApiController.rewardPoints();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('포인트 지급 성공'));
  }

  @IsTest
  static void rewardPoints_customException_handlesError() {
    setMockPointService();
    setupRest('{"throwCustom":true}');

    Test.startTest();
    GdPointAwardApiController.rewardPoints();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('포인트 지급 커스텀 예외'));
  }

  @IsTest
  static void rewardPoints_generalException_handlesError() {
    setMockPointService();
    setupRest('{"throwException":true}');

    Test.startTest();
    GdPointAwardApiController.rewardPoints();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(500, RestContext.response.statusCode);
  }
}