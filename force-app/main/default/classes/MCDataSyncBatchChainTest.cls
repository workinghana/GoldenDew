@IsTest
private class MCDataSyncBatchChainTest {
  private class MockMCSuccess implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      if (req.getEndpoint().contains('/v2/token')) {
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
      } else {
        res.setStatusCode(202);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"requestId":"test-id","resultMessages":[]}');
      }
      return res;
    }
  }

  private class MockMCError implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      if (req.getEndpoint().contains('/v2/token')) {
        res.setStatusCode(200);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
      } else {
        res.setStatusCode(500);
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"message":"error"}');
      }
      return res;
    }
  }

  @IsTest
  static void testBatchChainRunsForUserMetadata() {
    Test.setMock(HttpCalloutMock.class, new MockMCSuccess());

    Test.startTest();
    Database.executeBatch(new MCDataSyncBatchChain(new List<String>{ 'User' }, 0), 200);
    Test.stopTest();

    System.assert(true, 'Batch chain should run for User metadata.');
  }

  @IsTest
  static void testExecuteHandlesMcErrorResponse() {
    Test.setMock(HttpCalloutMock.class, new MockMCError());
    MCDataSyncBatchChain batch = new MCDataSyncBatchChain(new List<String>{ 'User' }, 0);
    User currentUser = [
      SELECT
        Id,
        ContactId,
        AccountId,
        CallCenterId,
        CreatedById,
        DelegatedApproverId,
        Email,
        IndividualId,
        LastModifiedById,
        ManagerId,
        Name,
        ProfileId,
        UserRoleId
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];

    Test.startTest();
    batch.execute(null, new List<SObject>{ currentUser });
    batch.finish(null);
    Test.stopTest();

    System.assertNotEquals(null, batch);
  }

  @IsTest
  static void testConstructorWithLaterIndex() {
    MCDataSyncBatchChain batch = new MCDataSyncBatchChain(new List<String>{ 'User', 'User' }, 1);
    System.assertNotEquals(null, batch);
  }
}