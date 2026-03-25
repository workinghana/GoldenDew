@IsTest
private class ExpiredVoucherApiServiceTest {

    /* ================= 성공 케이스 (Status 200) ================= */
    @IsTest
    static void test_callERP_success() {

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        ExpiredVoucherApiService.Request req = new ExpiredVoucherApiService.Request();
        req.CouponId   = null; // Id 타입 필드: 유효한 값 없으므로 null
        req.AccountId  = null;
        req.ExpiredDt  = System.now();
        req.ActionType = 'expired';

        List<ExpiredVoucherApiService.Request> reqList =
            new List<ExpiredVoucherApiService.Request>{ req };

        Test.startTest();
        List<ExpiredVoucherApiService.Response> results =
            ExpiredVoucherApiService.callERP(reqList);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assert(true);
    }

    /* ================= 실패 케이스 (Status 500) ================= */
    @IsTest
    static void test_callERP_failure() {

        Test.setMock(HttpCalloutMock.class, new MockHttpFailure());

        ExpiredVoucherApiService.Request req = new ExpiredVoucherApiService.Request();
        req.CouponId   = null;
        req.AccountId  = null;
        req.ExpiredDt  = System.now();
        req.ActionType = 'expired';

        List<ExpiredVoucherApiService.Request> reqList =
            new List<ExpiredVoucherApiService.Request>{ req };

        Test.startTest();
        List<ExpiredVoucherApiService.Response> results =
            ExpiredVoucherApiService.callERP(reqList);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].isSuccess);
        System.assert(true);
    }

    /* ================= 빈 요청 리스트 ================= */
    @IsTest
    static void test_callERP_emptyList() {

        Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

        Test.startTest();
        List<ExpiredVoucherApiService.Response> results =
            ExpiredVoucherApiService.callERP(new List<ExpiredVoucherApiService.Request>());
        Test.stopTest();

        System.assertEquals(0, results.size());
        System.assert(true);
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