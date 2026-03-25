@IsTest
private class VoucherApiServiceTest {

    /* ================= 성공 케이스 (Status 200) ================= */
    @IsTest
    static void test_callERP_success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        VoucherApiService.Request req = new VoucherApiService.Request();
        req.CouponId   = null; 
        req.AccountId  = null;
        req.ExpiredDt  = System.now();
        req.ActionType = 'expired';

        List<VoucherApiService.Request> reqList = new List<VoucherApiService.Request>{ req };

        Test.startTest();
        List<VoucherApiService.Response> results = VoucherApiService.callERP(reqList);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Results size should be 1');
        System.assertEquals(true, results[0].isSuccess, 'Should be successful');
        System.assert(results[0].message.contains('200'), 'Message should contain 200');
    }

    /* ================= 실패 케이스 (Status 500) ================= */
    @IsTest
    static void test_callERP_failure() {
        Test.setMock(HttpCalloutMock.class, new MockHttpFailure());

        VoucherApiService.Request req = new VoucherApiService.Request();
        req.CouponId   = null;
        req.AccountId  = null;
        req.ExpiredDt  = System.now();
        req.ActionType = 'expired';

        List<VoucherApiService.Request> reqList = new List<VoucherApiService.Request>{ req };

        Test.startTest();
        List<VoucherApiService.Response> results = VoucherApiService.callERP(reqList);
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Results size should be 1');
        System.assertEquals(false, results[0].isSuccess, 'Should be unsuccessful');
        System.assert(results[0].message.contains('500'), 'Message should contain 500');
    }

    /* ================= 빈 요청 리스트 ================= */
    @IsTest
    static void test_callERP_emptyList() {
        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        List<VoucherApiService.Response> results = VoucherApiService.callERP(new List<VoucherApiService.Request>());
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Results size should be 0');
    }

    /* ================= Callout Mock - 성공 ================= */
    private class MockHttpSuccess implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"result":"ok"}');
            return res;
        }
    }

    /* ================= Callout Mock - 실패 ================= */
    private class MockHttpFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"internal server error"}');
            return res;
        }
    }
}