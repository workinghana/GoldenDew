@isTest
private class MCDataSyncServiceTest {
    
    private class MockMCSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
            } else {
                res.setStatusCode(202);
                res.setBody('{"requestId":"test-id","resultMessages":[]}');
            }
            return res;
        }
    }
    
    @isTest
    static void testSyncObject() {
        Test.setMock(HttpCalloutMock.class, new MockMCSuccess());
        
        Test.startTest();
        MCDataSyncService.syncObject('User');
        Test.stopTest();
    }
    
    @isTest
    static void testBatchDirect() {
        Test.setMock(HttpCalloutMock.class, new MockMCSuccess());
        
        Test.startTest();
        Database.executeBatch(new MCDataSyncBatch('User'), 200);
        Test.stopTest();
    }
    
    @isTest
    static void testSchedulerClass() {
        MCDataSyncScheduler scheduler = new MCDataSyncScheduler();
        System.assertNotEquals(null, scheduler);
    }
}