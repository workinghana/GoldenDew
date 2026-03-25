@IsTest
private class GdPointApiControllerV1Test {
  private static void setupRest(String method, String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v1/point';
    req.httpMethod = method;
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

      if (methodName == 'getPointApplyHelp') {
        if (reqData != null && reqData.containsKey('throwCustom')) {
          throw new CustomException(400, '포인트 조회 커스텀 예외');
        }
        if (reqData != null && reqData.containsKey('throwException')) {
          Integer x = 1 / 0;
        }
        return 12345;
      }

      if (methodName == 'deletePoint') {
        if (reqData != null && reqData.containsKey('throwCustom')) {
          throw new CustomException(400, '포인트 삭제 커스텀 예외');
        }
        if (reqData != null && reqData.containsKey('throwException')) {
          Integer x = 1 / 0;
        }
        return ApiResult.ok(200, '포인트 삭제 성공', new Map<String, Object>{
          'result' => 'deleted'
        });
      }

      if (methodName == 'updatePoint') {
        if (reqData != null && reqData.containsKey('throwCustom')) {
          throw new CustomException(400, '포인트 수정 커스텀 예외');
        }
        if (reqData != null && reqData.containsKey('throwException')) {
          Integer x = 1 / 0;
        }
        return ApiResult.ok(200, '포인트 수정 성공', new Map<String, Object>{
          'result' => 'updated'
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
    GdPointApiControllerV1.setPointService(pointStub);
  }

  @IsTest
  static void getPointList_emptyBody_handlesError() {
    setupRest('GET', null);

    Test.startTest();
    GdPointApiControllerV1.getPointList();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('요청 본문이 비었습니다.'));
  }

  @IsTest
  static void getPointList_invalidJson_handlesError() {
    setupRest('GET', '{invalid-json}');

    Test.startTest();
    GdPointApiControllerV1.getPointList();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('JSON 역직렬화 실패'));
  }

  @IsTest
  static void getPointList_success() {
    setMockPointService();
    setupRest('GET', '{"MemberNo__c":"MT-001","orderId":"ORD-001"}');

    Test.startTest();
    GdPointApiControllerV1.getPointList();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('포인트 조회 성공'));
    System.assert(RestContext.response.responseBody.toString().contains('12345'));
  }

  @IsTest
  static void getPointList_customException_handlesError() {
    setMockPointService();
    setupRest('GET', '{"throwCustom":true}');

    Test.startTest();
    GdPointApiControllerV1.getPointList();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('포인트 조회 커스텀 예외'));
  }

  @IsTest
  static void getPointList_generalException_handlesError() {
    setMockPointService();
    setupRest('GET', '{"throwException":true}');

    Test.startTest();
    GdPointApiControllerV1.getPointList();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(500, RestContext.response.statusCode);
  }

  @IsTest
  static void deletePoint_emptyBody_handlesError() {
    setupRest('DELETE', null);

    Test.startTest();
    GdPointApiControllerV1.deletePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('요청 본문이 비었습니다.'));
  }

  @IsTest
  static void deletePoint_invalidJson_handlesError() {
    setupRest('DELETE', '{invalid-json}');

    Test.startTest();
    GdPointApiControllerV1.deletePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('JSON 역직렬화 실패'));
  }

  @IsTest
  static void deletePoint_success() {
    setMockPointService();
    setupRest('DELETE', '{"pointId":"P-001"}');

    Test.startTest();
    GdPointApiControllerV1.deletePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('포인트 삭제 성공'));
  }

  @IsTest
  static void deletePoint_customException_handlesError() {
    setMockPointService();
    setupRest('DELETE', '{"throwCustom":true}');

    Test.startTest();
    GdPointApiControllerV1.deletePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('포인트 삭제 커스텀 예외'));
  }

  @IsTest
  static void deletePoint_generalException_handlesError() {
    setMockPointService();
    setupRest('DELETE', '{"throwException":true}');

    Test.startTest();
    GdPointApiControllerV1.deletePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(500, RestContext.response.statusCode);
  }

  @IsTest
  static void updatePoint_emptyBody_handlesError() {
    setupRest('PATCH', null);

    Test.startTest();
    GdPointApiControllerV1.updatePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('요청 본문이 비었습니다.'));
  }

  @IsTest
  static void updatePoint_invalidJson_handlesError() {
    setupRest('PATCH', '{invalid-json}');

    Test.startTest();
    GdPointApiControllerV1.updatePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('JSON 역직렬화 실패'));
  }

  @IsTest
  static void updatePoint_success() {
    setMockPointService();
    setupRest('PATCH', '{"pointId":"P-001","amount":1000}');

    Test.startTest();
    GdPointApiControllerV1.updatePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('포인트 수정 성공'));
  }

  @IsTest
  static void updatePoint_customException_handlesError() {
    setMockPointService();
    setupRest('PATCH', '{"throwCustom":true}');

    Test.startTest();
    GdPointApiControllerV1.updatePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('포인트 수정 커스텀 예외'));
  }

  @IsTest
  static void updatePoint_generalException_handlesError() {
    setMockPointService();
    setupRest('PATCH', '{"throwException":true}');

    Test.startTest();
    GdPointApiControllerV1.updatePoint();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(500, RestContext.response.statusCode);
  }
}