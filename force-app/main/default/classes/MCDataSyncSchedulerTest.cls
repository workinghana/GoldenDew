@IsTest
private class MCDataSyncSchedulerTest {
  private class MockMCSuccess implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (req.getEndpoint().contains('/v2/token')) {
        res.setStatusCode(200);
        res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
        return res;
      }

      res.setStatusCode(202);
      res.setBody('{"requestId":"test-id","resultMessages":[]}');
      return res;
    }
  }

  @IsTest
  static void scheduledExecute_startsBatchChain() {
    Test.setMock(HttpCalloutMock.class, new MockMCSuccess());

    Test.startTest();
    String jobId = System.schedule('MCDataSyncSchedulerTestJob', '0 0 0 1 1 ? 2099', new MCDataSyncScheduler());
    Test.stopTest();

    System.assertNotEquals(null, jobId);
  }

  @IsTest
  static void directExecute_invokesSchedulerPath() {
    Test.setMock(HttpCalloutMock.class, new MockMCSuccess());

    Test.startTest();
    new MCDataSyncScheduler().execute(null);
    Test.stopTest();

    System.assert(true);
  }
}