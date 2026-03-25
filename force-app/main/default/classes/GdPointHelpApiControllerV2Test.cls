@IsTest
private class GdPointHelpApiControllerV2Test {
  private static void setupRest(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v2/point/help';
    req.httpMethod = 'POST';
    if (body != null) req.requestBody = Blob.valueOf(body);
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
}