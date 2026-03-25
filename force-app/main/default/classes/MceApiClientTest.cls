/**
 * MceApiClient 테스트 클래스
 * 커버리지 75% 이상(목표 90%+) 확보를 위한 전체 시나리오 포함
 */
@isTest
private class MceApiClientTest {

    /**
     * 내부 Mock 클래스: 다양한 응답 상황(성공, 에러, 예외)을 시뮬레이션
     */
    private class MceMock implements HttpCalloutMock {
        private Integer statusCode;
        private String status;
        private String body;
        private Boolean failWithException = false;

        public MceMock(Integer statusCode, String status, String body) {
            this.statusCode = statusCode;
            this.status = status;
            this.body = body;
        }

        public void setFailWithException(Boolean fail) {
            this.failWithException = fail;
        }

        public HttpResponse respond(HttpRequest req) {
            if (failWithException) {
                throw new CalloutException('Network connection error');
            }
            HttpResponse res = new HttpResponse();
            res.setStatusCode(this.statusCode);
            res.setStatus(this.status);
            res.setBody(this.body);
            return res;
        }
    }

    /**
     * 1. 성공 케이스 (POST, JSON Body, Query Params 포함)
     */
    @isTest
    static void testSendJson_Success() {
        // Mock 설정: 201 Created 응답
        MceMock mock = new MceMock(201, 'Created', '{"id":"event123"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Map<String, String> queryParams = new Map<String, String>{
            'version' => 'v1',
            'test' => 'true'
        };
        Map<String, Object> body = new Map<String, Object>{'name' => 'test event'};

        Test.startTest();
        MceApiClient.CalloutResult result = MceApiClient.sendJson('POST', '/test-path', body, queryParams);
        Test.stopTest();

        // 검증
        System.assertEquals(true, result.isSuccess, '성공 상태여야 합니다.');
        System.assertEquals(201, result.statusCode);
        System.assertEquals('{"id":"event123"}', result.responseBody);
    }

    /**
     * 2. HTTP 에러 케이스 (400 Bad Request)
     */
    @isTest
    static void testSendJson_HttpError() {
        MceMock mock = new MceMock(400, 'Bad Request', '{"message":"Invalid data"}');
        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        // Path가 /로 시작하지 않을 때의 로직(path = '/' + path) 커버를 위해 'test'로 전달
        MceApiClient.CalloutResult result = MceApiClient.sendJson('PUT', 'test', null, null);
        Test.stopTest();

        // 검증
        System.assertEquals(false, result.isSuccess);
        System.assertEquals('HTTP_ERROR', result.errorType);
        System.assertEquals(400, result.statusCode);
    }

    /**
     * 3. 유효성 검사 예외 (Method/Path가 비어있는 경우)
     */
    @isTest
    static void testInputValidation() {
        // reqDto가 null인 경우
        try {
            MceApiClient.sendInteractionEvent(null);
            System.assert(false, 'Exception should have been thrown');
        } catch (MceApiClient.MceApiException e) {
            System.assertEquals('Request DTO is null.', e.getMessage());
        }

        // Method가 blank인 경우
        try {
            MceApiClient.sendJson('', '/path', null, null);
            System.assert(false, 'Exception should have been thrown');
        } catch (MceApiClient.MceApiException e) {
            System.assertEquals('HTTP method is blank.', e.getMessage());
        }

        // Path가 blank인 경우
        try {
            MceApiClient.sendJson('POST', '  ', null, null);
            System.assert(false, 'Exception should have been thrown');
        } catch (MceApiClient.MceApiException e) {
            System.assertEquals('Path is blank.', e.getMessage());
        }
    }

    /**
     * 4. 쿼리 파라미터 빌더의 경계값 테스트 (Null 키/값 처리)
     */
    @isTest
    static void testBuildEndpointSpecialCases() {
        MceMock mock = new MceMock(200, 'OK', '{}');
        Test.setMock(HttpCalloutMock.class, mock);

        // 빈 키값이나 Null 밸류가 포함된 맵
        Map<String, String> queryParams = new Map<String, String>{
            'key1' => 'value1',
            '' => 'emptyKey', // skip 처리됨
            'key2' => null    // ''로 변환됨
        };

        Test.startTest();
        MceApiClient.CalloutResult result = MceApiClient.sendJson('GET', '/path', null, queryParams);
        Test.stopTest();

        System.assertEquals(200, result.statusCode);
    }
}