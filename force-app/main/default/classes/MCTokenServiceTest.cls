@isTest
private class MCTokenServiceTest {
    
    private class MockTokenSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"access_token":"test_token_123","token_type":"Bearer","expires_in":1080}');
            return res;
        }
    }
    
    private class MockTokenFail implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error":"unauthorized"}');
            return res;
        }
    }
    
    @isTest
    static void testGetAccessTokenSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockTokenSuccess());
        
        Test.startTest();
        String token = MCTokenService.getAccessToken();
        Test.stopTest();
        
        System.assertEquals('test_token_123', token);
    }
    
    @isTest
    static void testGetAccessTokenFail() {
        Test.setMock(HttpCalloutMock.class, new MockTokenFail());
        
        Test.startTest();
        try {
            MCTokenService.getAccessToken();
            System.assert(false, 'Exception expected');
        } catch (CalloutException e) {
            System.assert(e.getMessage().contains('MC Token Error'));
        }
        Test.stopTest();
    }
}