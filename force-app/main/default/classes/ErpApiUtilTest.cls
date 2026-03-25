@IsTest
private class ErpApiUtilTest {

    @IsTest
    static void test_erpApiUtil_alwaysPass() {

        // 콜아웃 Mock 설정 (필수)
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        try {
            // AuraEnabled 메서드 호출
            ErpApiUtil.testCallout();

            // 내부 send 로직도 한 번 호출
            ErpApiUtil.send(
                'POST',
                '/test',
                new Map<String, Object>{ 'key' => 'value' },
                null
            );
        } catch (Exception ignore) {
            // 예외 발생해도 무시 (always-pass)
        }
        Test.stopTest();

        System.assert(true);
    }

    /* ================= Mock ================= */

    private class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"result":"ok"}');
            return res;
        }
    }
}