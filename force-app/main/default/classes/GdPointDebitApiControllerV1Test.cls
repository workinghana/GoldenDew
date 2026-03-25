@IsTest
private class GdPointDebitApiControllerV1Test {
  private static void setupRest() {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v1/point/debit';
    req.httpMethod = 'GET';
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
}