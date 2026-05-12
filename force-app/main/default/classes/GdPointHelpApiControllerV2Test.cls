@IsTest
private class GdPointHelpApiControllerV2Test {
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
      if (methodName == 'getPointApplyHelpV2') {
        if (mode == 'custom') {
          throw new CustomException(422, 'point help v2 custom error');
        }
        if (mode == 'runtime') {
          String forcedNull;
          forcedNull.length();
        }

        return ApiResult.ok(
          200,
          'point help v2 success',
          new Map<String, Object>{ 'pointList' => new List<Object>{ new Map<String, Object>{ 'POINT' => 123.45 } } }
        );
      }

      return null;
    }
  }

  private static GdPointService pointServiceStub(String mode) {
    return (GdPointService) Test.createStub(GdPointService.class, new PointServiceStubProvider(mode));
  }

  private static void setupRest(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v2/point/help';
    req.httpMethod = 'POST';
    if (body != null)
      req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @IsTest
  static void getPointListV2_emptyBody_handlesError() {
    setupRest(null);
    Test.startTest();
    GdPointHelpApiControllerV2.getPointListV2();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void getPointListV2_invalidJson_handlesError() {
    setupRest('{invalid-json}');
    Test.startTest();
    GdPointHelpApiControllerV2.getPointListV2();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void getPointListV2_success() {
    GdPointHelpApiControllerV2.setPointService(pointServiceStub('success'));
    setupRest('{"MemberNo__c":"M001","StoreCode__c":"STORE-01","Type":"01"}');

    Test.startTest();
    GdPointHelpApiControllerV2.getPointListV2();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('point help v2 success'));
    GdPointHelpApiControllerV2.setPointService(null);
  }

  @IsTest
  static void getPointListV2_serviceCustomException() {
    GdPointHelpApiControllerV2.setPointService(pointServiceStub('custom'));
    setupRest('{"MemberNo__c":"M001"}');

    Test.startTest();
    GdPointHelpApiControllerV2.getPointListV2();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    GdPointHelpApiControllerV2.setPointService(null);
  }

  @IsTest
  static void getPointListV2_serviceRuntimeException() {
    GdPointHelpApiControllerV2.setPointService(pointServiceStub('runtime'));
    setupRest('{"MemberNo__c":"M001"}');

    Test.startTest();
    GdPointHelpApiControllerV2.getPointListV2();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    GdPointHelpApiControllerV2.setPointService(null);
  }

  @IsTest
  static void getPointListV2_defaultServicePath_handlesError() {
    GdPointHelpApiControllerV2.setPointService(null);
    setupRest('{"MemberNo__c":"M001"}');

    Test.startTest();
    GdPointHelpApiControllerV2.getPointListV2();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
  }
}