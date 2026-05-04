@isTest
private class MCUserSyncServiceTest {
    
    private class MockMCSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
            } else {
                res.setStatusCode(202);
                res.setBody('{"requestId":"test-request-id","resultMessages":[]}');
            }
            return res;
        }
    }
    
    @isTest
    static void testSyncAllUsers() {
        Test.setMock(HttpCalloutMock.class, new MockMCSuccess());
        
        Test.startTest();
        MCUserSyncService.syncAllUsers();
        Test.stopTest();
    }
    
    @isTest
    static void testSendToMC() {
        Test.setMock(HttpCalloutMock.class, new MockMCSuccess());
        
        String testPayload = JSON.serialize(new Map<String, Object>{
            'items' => new List<Map<String, String>>{
                new Map<String, String>{
                    'ContactKey' => '005000000000001',
                    'Id'         => '005000000000001',
                    'Name'       => 'Test User',
                    'Email'      => 'test@test.com'
                }
            }
        });
        
        Test.startTest();
        MCUserSyncService.sendToMC(testPayload);
        Test.stopTest();
    }
    
    @isTest
    static void testScheduler() {
        Test.setMock(HttpCalloutMock.class, new MockMCSuccess());
        
        Test.startTest();
        String jobId = System.schedule(
            'MC User Sync Test', 
            '0 0 2 * * ?', 
            new MCUserSyncScheduler()
        );
        Test.stopTest();
        
        System.assertNotEquals(null, jobId);
    }
}