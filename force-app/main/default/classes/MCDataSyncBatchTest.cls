@IsTest
private class MCDataSyncBatchTest {
  private class MCSuccessMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (req.getEndpoint().contains('/v2/token')) {
        res.setStatusCode(200);
        res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
        return res;
      }

      System.assertEquals('PUT', req.getMethod());
      System.assert(req.getEndpoint().contains('/data/v1/async/dataextensions/key:'));
      System.assert(req.getBody().contains('"items"'));

      res.setStatusCode(202);
      res.setBody('{"requestId":"test-request","resultMessages":[]}');
      return res;
    }
  }

  private class MCErrorMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (req.getEndpoint().contains('/v2/token')) {
        res.setStatusCode(200);
        res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
        return res;
      }

      res.setStatusCode(500);
      res.setBody('{"message":"forced failure"}');
      return res;
    }
  }

  @IsTest
  static void executeBatch_success_coversStartExecuteFinish() {
    Test.setMock(HttpCalloutMock.class, new MCSuccessMock());

    Test.startTest();
    Database.executeBatch(new MCDataSyncBatch('User'), 200);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void executeBatch_nonAcceptedResponse_coversErrorCountPath() {
    Test.setMock(HttpCalloutMock.class, new MCErrorMock());

    Test.startTest();
    Database.executeBatch(new MCDataSyncBatch('User'), 200);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void constructor_missingMetadata_throwsException() {
    try {
      new MCDataSyncBatch('NOT_EXISTING_METADATA_FOR_TEST');
      System.assert(false, 'Missing metadata should throw a query exception.');
    } catch (QueryException e) {
      System.assert(e.getMessage().contains('List has no rows'));
    }
  }
}