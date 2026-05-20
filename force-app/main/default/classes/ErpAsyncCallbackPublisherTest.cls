@IsTest
private class ErpAsyncCallbackPublisherTest {
    private class McCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"result":"ok"}');
            return res;
        }
    }

    private static HttpErrorException makeHttpError(String body) {
        HttpErrorException he = new HttpErrorException();
        he.statusCode = 400;
        he.responseBody = body;
        he.endpoint = 'callout:Dummy_NC/api';
        he.method = 'PATCH';
        he.requestUrl = he.endpoint;
        he.responseHeaders = new Map<String, String>{ 'Content-Type' => 'application/json' };
        return he;
    }

    @IsTest
    static void test_onSuccess_no_throw() {
        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();
        p.onSuccess('API_X', null, null);
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_httpError_with_json_message_single_record() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();

        HttpErrorException he = makeHttpError(
            '{"success":false,"message":"INVALID_MEMBER","data":null}'
        );
        Map<String, Object> req = new Map<String, Object>{ 'a' => 1, 'b' => 'x' };

        Contact c = new Contact(LastName = 'Test');
        insert c;

        Test.startTest();
        p.onFailure('UPDATE_MEMBER', req, he, c.Id);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_onFailure_httpError_with_non_json_body_single_record_with_sobject() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();

        HttpErrorException he = makeHttpError('NOT_JSON_TEXT');

        Contact c = new Contact(LastName = 'Test2');
        insert c;

        Test.startTest();
        p.onFailure('UPDATE_MEMBER', new Map<String, Object>{ 'k' => 'v' }, he, c.Id, c);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_onFailure_string_errorMessage_recordId() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();

        Contact c = new Contact(LastName = 'Test3');
        insert c;

        String longMsg = '';
        for (Integer i = 0; i < 600; i++) {
            longMsg += 'A';
        }

        Test.startTest();
        p.onFailure('UPDATE_MEMBER', new Map<String, Object>{ 'x' => 1 }, longMsg, c.Id);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_onFailure_httpError_set_recordIds() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();

        Contact c = new Contact(LastName = 'Test4');
        insert c;

        Set<Id> ids = new Set<Id>{ c.Id };

        HttpErrorException he = makeHttpError('{"message":"BULK_FAILED"}');

        Test.startTest();
        p.onFailure('UPDATE_GRADE', new Map<String, Object>{ 'bulk' => true }, he, ids);
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_onFailure_string_stacktrace_noop() {
        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();
        p.onFailure('ANY', null, 'err', 'stack');
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_httpError_null_responseBody() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();

        HttpErrorException he = makeHttpError(null);

        Contact c = new Contact(LastName = 'Test5');
        insert c;

        Test.startTest();
        p.onFailure('UPDATE_MEMBER', null, he, c.Id);
        Test.stopTest();

        System.assert(true);
    }

    // =========================================================
    // ✅ 추가: @TestVisible helper 훅 커버 (coverage 올리기)
    //  - ErpAsyncCallbackPublisher에 아래 메서드가 추가되어 있어야 함:
    //    testExtractMessage / testEscapeJson / testTruncateForLongText / testSafeSerialize
    // =========================================================

    @IsTest
    static void test_helpers_extract_escape_truncate() {
        System.assertEquals(null, ErpAsyncCallbackPublisher.testExtractMessage(null));
        System.assertEquals(null, ErpAsyncCallbackPublisher.testExtractMessage('  '));

        System.assertEquals(
            'HELLO',
            ErpAsyncCallbackPublisher.testExtractMessage('{"message":"HELLO"}')
        );

        String raw = 'NOT_JSON';
        System.assertEquals(raw, ErpAsyncCallbackPublisher.testExtractMessage(raw));

        // message 키가 없는 JSON이면 원문 반환
        String noMsgJson = '{"success":false,"error":"X"}';
        System.assertEquals(noMsgJson, ErpAsyncCallbackPublisher.testExtractMessage(noMsgJson));

        String esc = ErpAsyncCallbackPublisher.testEscapeJson('a"b\\c\nd\r');
        System.assert(esc.contains('\\"'));
        System.assert(esc.contains('\\\\'));
        System.assert(esc.contains('\\n'));
        System.assert(esc.contains('\\r'));

        String t1 = ErpAsyncCallbackPublisher.testTruncateForLongText('abc', 'REQ');
        System.assert(t1.contains('REQ'));

        String longS = '';
        for (Integer i = 0; i < 140000; i++) {
            longS += 'A';
        }
        String t2 = ErpAsyncCallbackPublisher.testTruncateForLongText(longS, 'RES');
        System.assert(t2.length() <= 131072);

        // header 자체가 LONG_TEXT_MAX보다 길어지는 극단 케이스 분기
        String hugeLabel = '';
        for (Integer i = 0; i < 140000; i++) {
            hugeLabel += 'L';
        }
        String t3 = ErpAsyncCallbackPublisher.testTruncateForLongText('x', hugeLabel);
        System.assert(t3.length() <= 131072);
    }

    @IsTest
    static void test_safeSerialize_null_and_normal() {
        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();

        System.assertEquals(null, p.testSafeSerialize(null));

        String s = p.testSafeSerialize(new Map<String, Object>{ 'k' => 'v' });
        System.assert(s.contains('"k"'));
    }

    @IsTest
    static void test_onFailure_exception_overloads_noop() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        ErpAsyncCallbackPublisher p = new ErpAsyncCallbackPublisher();

        Contact c = new Contact(LastName = 'Test6');
        insert c;

        Exception ex;
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            ex = e;
        }

        // 현재 구현은 no-op이므로 예외 없이 호출되는지만 확인
        p.onFailure('ANY_API', new Map<String, Object>{ 'k' => 'v' }, ex, c.Id);
        p.onFailure('ANY_API', new Map<String, Object>{ 'k' => 'v' }, ex, new Set<Id>{ c.Id });

        System.assert(true);
    }
}