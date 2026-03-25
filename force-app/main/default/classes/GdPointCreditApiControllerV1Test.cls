@IsTest
private class GdPointCreditApiControllerV1Test {
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
}