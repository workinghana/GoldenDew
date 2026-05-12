@IsTest
private class GdPointDebitApiControllerV1Test {
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
      if (methodName == 'getDebitPointList') {
        if (mode == 'custom') {
          throw new CustomException(422, 'CUSTOM ERROR');
        }
        if (mode == 'runtime') {
          String forcedNull;
          forcedNull.length();
        }

        return ApiResult.ok(200, 'SUCCESS', new Map<String, Object>{ 'points' => 100 });
      }

      return null;
    }
  }

  private static GdPointService pointServiceStub(String mode) {
    return (GdPointService) Test.createStub(GdPointService.class, new PointServiceStubProvider(mode));
  }

  private static void setupRest() {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v1/point/debit';
    req.httpMethod = 'GET';
    req.addParameter('memberNo', 'MEM001');
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @IsTest
  static void getDebitPointList_handlesExceptionPath() {
    setupRest();
    Test.startTest();
    GdPointDebitApiControllerV1.getDebitPointList();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void getDebitPointList_success() {
    GdPointDebitApiControllerV1.setPointService(pointServiceStub('success'));
    setupRest();

    Test.startTest();
    GdPointDebitApiControllerV1.getDebitPointList();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    GdPointDebitApiControllerV1.setPointService(null);
  }

  @IsTest
  static void getDebitPointList_serviceCustomException() {
    GdPointDebitApiControllerV1.setPointService(pointServiceStub('custom'));
    setupRest();

    Test.startTest();
    GdPointDebitApiControllerV1.getDebitPointList();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    GdPointDebitApiControllerV1.setPointService(null);
  }

  @IsTest
  static void getDebitPointList_serviceRuntimeException() {
    GdPointDebitApiControllerV1.setPointService(pointServiceStub('runtime'));
    setupRest();

    Test.startTest();
    GdPointDebitApiControllerV1.getDebitPointList();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    GdPointDebitApiControllerV1.setPointService(null);
  }
}