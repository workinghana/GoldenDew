@IsTest
private class CommonApiClientUniversalMockTest {
    private static HttpRequest req(String endpoint) {
        HttpRequest r = new HttpRequest();
        r.setEndpoint(endpoint);
        r.setMethod('GET');
        return r;
    }

    @IsTest
    static void test_reset_and_retry_branch() {
        CommonApiClientUniversalMock.reset();
        CommonApiClientUniversalMock mock = new CommonApiClientUniversalMock();

        HttpResponse first = mock.respond(req('https://example.com/retry'));
        System.assertEquals(500, first.getStatusCode());
        System.assertEquals('error', first.getBody());

        HttpResponse second = mock.respond(req('https://example.com/retry'));
        System.assertEquals(200, second.getStatusCode());
        System.assertEquals('{"ok":true}', second.getBody());
    }

    @IsTest
    static void test_reset_and_secure_branch() {
        CommonApiClientUniversalMock.reset();
        CommonApiClientUniversalMock mock = new CommonApiClientUniversalMock();

        HttpResponse first = mock.respond(req('https://example.com/secure'));
        System.assertEquals(401, first.getStatusCode());
        System.assertEquals('unauthorized', first.getBody());

        HttpResponse second = mock.respond(req('https://example.com/secure'));
        System.assertEquals(200, second.getStatusCode());
        System.assertEquals('{"ok":true}', second.getBody());
    }

    @IsTest
    static void test_timeout_branch_throws() {
        CommonApiClientUniversalMock.reset();
        CommonApiClientUniversalMock mock = new CommonApiClientUniversalMock();

        Boolean thrown = false;
        try {
            mock.respond(req('https://example.com/timeout'));
        } catch (System.CalloutException e) {
            thrown = true;
            System.assert(e.getMessage().contains('timeout'));
        }

        System.assertEquals(true, thrown);
    }

    @IsTest
    static void test_bad_branch() {
        CommonApiClientUniversalMock.reset();
        CommonApiClientUniversalMock mock = new CommonApiClientUniversalMock();

        HttpResponse res = mock.respond(req('https://example.com/bad'));
        System.assertEquals(400, res.getStatusCode());
        System.assertEquals('bad', res.getBody());
    }

    @IsTest
    static void test_json_error_branch() {
        CommonApiClientUniversalMock.reset();
        CommonApiClientUniversalMock mock = new CommonApiClientUniversalMock();

        HttpResponse res = mock.respond(req('https://example.com/json-error'));
        System.assertEquals(200, res.getStatusCode());
        System.assertEquals('{invalid json}', res.getBody());
        System.assertEquals('application/json', res.getHeader('Content-Type'));
    }

    @IsTest
    static void test_rate_limit_branch() {
        CommonApiClientUniversalMock.reset();
        CommonApiClientUniversalMock mock = new CommonApiClientUniversalMock();

        HttpResponse res = mock.respond(req('https://example.com/rate-limit'));
        System.assertEquals(429, res.getStatusCode());
        System.assertEquals('rate limit', res.getBody());
    }

    @IsTest
    static void test_no_content_branch() {
        CommonApiClientUniversalMock.reset();
        CommonApiClientUniversalMock mock = new CommonApiClientUniversalMock();

        HttpResponse res = mock.respond(req('https://example.com/no-content'));
        System.assertEquals(204, res.getStatusCode());
        System.assertEquals('', res.getBody());
    }

    @IsTest
    static void test_default_branch_and_null_endpoint() {
        CommonApiClientUniversalMock.reset();
        CommonApiClientUniversalMock mock = new CommonApiClientUniversalMock();

        HttpResponse defaultRes = mock.respond(req('https://example.com/other'));
        System.assertEquals(200, defaultRes.getStatusCode());
        System.assertEquals('{"ok":true}', defaultRes.getBody());
        System.assertEquals('application/json', defaultRes.getHeader('Content-Type'));

        HttpRequest nullReq = new HttpRequest();
        nullReq.setMethod('GET');
        HttpResponse nullEpRes = mock.respond(nullReq);
        System.assertEquals(200, nullEpRes.getStatusCode());
        System.assertEquals('{"ok":true}', nullEpRes.getBody());
    }
}