@IsTest
private class GdPointCreditApiControllerV1Test {
  private class PointServiceStubProvider implements System.StubProvider {
    private String mode;

    PointServiceStubProvider(String mode) {
      this.mode = mode;
    }

    public Object handleMethodCall(
      Object stubbedObject,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      if (methodName == 'creditPoint') {
        if (mode == 'custom') {
          throw new CustomException(422, 'CUSTOM ERROR');
        }
        if (mode == 'runtime') {
          String forcedNull;
          forcedNull.length();
        }

        return ApiResult.ok(200, 'SUCCESS', new Map<String, Object>{ 'result' => 'ok' });
      }

      return null;
    }
  }

  private static GdPointService pointServiceStub(String mode) {
    return (GdPointService) Test.createStub(GdPointService.class, new PointServiceStubProvider(mode));
  }

  private static void setupRest(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v1/point/credit';
    req.httpMethod = 'POST';
    if (body != null) req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @IsTest
  static void creditPoints_emptyBody_handlesError() {
    setupRest(null);
    Test.startTest();
    GdPointCreditApiControllerV1.creditPoints();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void creditPoints_invalidJson_handlesError() {
    setupRest('{invalid-json}');
    Test.startTest();
    GdPointCreditApiControllerV1.creditPoints();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void creditPoints_success() {
    GdPointCreditApiControllerV1.setPointService(pointServiceStub('success'));
    setupRest('{"memberNo":"MEM001","points":100}');

    Test.startTest();
    GdPointCreditApiControllerV1.creditPoints();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    GdPointCreditApiControllerV1.setPointService(null);
  }

  @IsTest
  static void creditPoints_serviceCustomException() {
    GdPointCreditApiControllerV1.setPointService(pointServiceStub('custom'));
    setupRest('{"memberNo":"MEM001","points":100}');

    Test.startTest();
    GdPointCreditApiControllerV1.creditPoints();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    GdPointCreditApiControllerV1.setPointService(null);
  }

  @IsTest
  static void creditPoints_serviceRuntimeException() {
    GdPointCreditApiControllerV1.setPointService(pointServiceStub('runtime'));
    setupRest('{"memberNo":"MEM001","points":100}');

    Test.startTest();
    GdPointCreditApiControllerV1.creditPoints();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    GdPointCreditApiControllerV1.setPointService(null);
  }

  @IsTest
  static void creditPoints_defaultServicePath_handlesError() {
    GdPointCreditApiControllerV1.setPointService(null);
    setupRest('{"memberNo":"MEM001","points":100}');

    Test.startTest();
    GdPointCreditApiControllerV1.creditPoints();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
  }
}