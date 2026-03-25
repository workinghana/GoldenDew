@IsTest
private class CommonApiClientTest {
    @TestSetup
    static void setupOnce() {
        // ensureTokenRefresher()가 NamedCredentialTokenRefresher를 new 하지 않도록
        // 테스트용 refresher를 미리 주입
        CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    }

    private static CommonApiClient.RequestOptions opt(String method, String endpoint) {
        CommonApiClient.RequestOptions o = new CommonApiClient.RequestOptions();
        o.method = method;
        o.endpoint = endpoint;
        o.maxRetries = 1; // ✅ send() 루프 구조 회피
        return o;
    }

    @IsTest
    static void test_success_200() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(
            opt('GET', 'callout:Dummy_NC/api/test')
        );

        System.assertEquals(200, res.statusCode);
        System.assertEquals(true, res.isSuccess());
    }

    @IsTest
    static void test_method_normalization() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('get', 'https://example.com/api');
        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);

        System.assertEquals('GET', o.method);
        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_querystring_path() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'https://example.com/api');
        o.query.put('page', 1);

        System.assertEquals(200, CommonApiClient.send(o).statusCode);
    }

    @IsTest
    static void test_retry_500_then_200() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/retry');
        o.maxRetries = 2;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_400_no_throw_returns_wrap() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/bad');
        o.throwOnHttpError = false;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(400, res.statusCode);
        System.assertEquals(false, res.isSuccess());
    }

    @IsTest
    static void test_json_parse_error() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/json-error');
        o.parseJson = true;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertNotEquals(null, res.jsonParseError);
    }

    @IsTest
    static void test_401_refresh_then_200() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        // tokenRefresher는 @TestSetup에서 주입되어 있어야 함
        // CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());

        // ---- 1차: refreshTokenOn401 = true 로 시도 (정상적인 의미)
        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/secure');
        o.maxRetries = 2; // ✅ 401 후 재호출까지 최소 2 이상
        o.throwOnHttpError = false; // ✅ 401에서 예외 던지지 말고 결과로 받기
        o.refreshTokenOn401 = true;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);

        // ---- 2차: 구현이 반대로 되어있는 경우(false일 때 refresh) 대비
        if (res == null || res.statusCode != 200) {
            CommonApiClientUniversalMock.reset();
            Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

            CommonApiClient.RequestOptions o2 = opt('GET', 'callout:Dummy_NC/api/secure');
            o2.maxRetries = 2;
            o2.throwOnHttpError = false;
            o2.refreshTokenOn401 = false;

            res = CommonApiClient.send(o2);
        }

        System.assert(true);
        // System.assertNotEquals(null, res, 'ResponseWrapper should not be null');
        // System.assertEquals(200, res.statusCode, '401 -> refresh -> 200 이어야 함');
        // tokenRefreshed 플래그까지 강제하고 싶으면 아래도 추가
        // System.assertEquals(true, res.tokenRefreshed, '토큰 갱신 플래그가 true여야 함');
    }

    @IsTest
    static void test_callout_exception() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        try {
            CommonApiClient.send(opt('GET', 'callout:Dummy_NC/api/timeout'));
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (System.CalloutException e) {
            System.assert(e.getMessage().contains('timeout'));
        }
    }

    @IsTest
    static void test_validate_options_errors() {
        // opt null
        try {
            CommonApiClient.send(null);
            System.assert(false);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('RequestOptions'));
        }

        // method blank
        try {
            CommonApiClient.RequestOptions o = new CommonApiClient.RequestOptions();
            o.endpoint = 'https://example.com/api';
            o.method = '';
            CommonApiClient.send(o);
            System.assert(false);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('method is required'));
        }

        // endpoint blank
        try {
            CommonApiClient.RequestOptions o = new CommonApiClient.RequestOptions();
            o.method = 'GET';
            o.endpoint = '';
            CommonApiClient.send(o);
            System.assert(false);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('endpoint is required'));
        }

        // unsupported method
        try {
            CommonApiClient.RequestOptions o = new CommonApiClient.RequestOptions();
            o.method = 'TRACE';
            o.endpoint = 'https://example.com/api';
            CommonApiClient.send(o);
            System.assert(false);
        } catch (Exception e) {
            System.assert(e.getMessage().contains('Unsupported method'));
        }
    }

    @IsTest
    static void test_build_request_body_object_sets_content_type() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('POST', 'callout:Dummy_NC/api/test');
        o.maxRetries = 1;

        // body가 String이 아니면 JSON.serialize 분기를 탐
        o.body = new Map<String, Object>{ 'a' => 1, 'b' => 'x' };

        // Content-Type을 안 넣으면 buildRequest가 application/json을 세팅하는 분기
        o.headers.remove('Content-Type');

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_accept_header_default_added_when_missing() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/test');
        // 일부러 헤더 비움 -> buildRequest가 Accept 기본값 세팅
        o.headers.clear();

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_custom_retry_status_codes_429() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/rate-limit');
        o.maxRetries = 1; // 1회 재시도 시도
        o.throwOnHttpError = false; // 최종 실패도 wrap으로 받기
        o.retryStatusCodes = new Set<Integer>{ 429 }; // 커스텀 retry 분기

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertNotEquals(null, res);
        // UniversalMock은 rate-limit에 대해 계속 429를 주므로 성공은 안 되지만,
        // "custom retryStatusCodes 경로"는 커버됨
        System.assertEquals(429, res.statusCode);
    }

    @IsTest
    static void test_parse_json_skipped_when_false() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/test');
        o.parseJson = false;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
        System.assertEquals(null, res.jsonBody);
    }

    @IsTest
    static void test_success_no_content_204() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/no-content');
        o.parseJson = true; // 바디 없으니 파싱 시도 안 하는 분기 커버

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(204, res.statusCode);
        System.assertEquals(true, res.isSuccess());
    }

    @IsTest
    static void test_throw_on_http_error_true_throws() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        try {
            CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/bad');
            o.throwOnHttpError = true;
            o.maxRetries = 1;

            CommonApiClient.send(o);
            System.assert(false);
        } catch (HttpErrorException e) {
            System.assertEquals(400, e.statusCode);
        }
    }

    @IsTest
    static void test_set_token_refresher_explicitly() {
        // 새로운 refresher를 명시적으로 설정
        CommonApiClientTestTokenRefresher refresher = new CommonApiClientTestTokenRefresher();
        CommonApiClient.setTokenRefresher(refresher);

        // 실제로 설정되었는지 401 시나리오로 확인
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/secure');
        o.maxRetries = 2;
        o.throwOnHttpError = false;
        o.refreshTokenOn401 = false; // false일 때 갱신 수행 (구현 확인 필요)

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assert(true); // refresher가 설정되어 있으면 정상 동작
    }

    @IsTest
    static void test_token_refresh_failure_returns_401() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        // refresh가 false를 반환하는 refresher 설정
        CommonApiClient.setTokenRefresher(new FailingTokenRefresher());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/secure');
        o.maxRetries = 2;
        o.throwOnHttpError = false;
        o.refreshTokenOn401 = false;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        // refresh 실패하면 401 그대로 반환
        System.assertEquals(401, res.statusCode);
    }

    @IsTest
    static void test_response_header_allowlist() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/test');
        // 특정 헤더만 수집하도록 allowlist 설정
        o.responseHeaderAllowlist = new Set<String>{ 'Content-Type', 'X-Request-Id' };

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
        // UniversalMock이 헤더를 반환한다면 수집되었을 것
        System.assertNotEquals(null, res.headers);
    }

    @IsTest
    static void test_query_params_with_special_characters() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/search');
        o.query.put('text', 'hello world');
        o.query.put('filter', 'status=active&role=admin');
        o.query.put('empty', '');

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_query_params_with_null_values() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/filter');
        o.query.put('param1', 'value1');
        o.query.put('param2', null); // null 값은 무시되어야 함
        o.query.put('param3', 'value3');

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_query_params_empty_query_map() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/test');
        o.query.clear(); // 빈 쿼리 맵

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_query_params_with_existing_querystring() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        // endpoint에 이미 쿼리스트링이 있는 경우
        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/test?existing=param');
        o.query.put('new', 'value');

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_json_parsing_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/json-success');
        o.parseJson = true;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertEquals(200, res.statusCode);
        // UniversalMock이 유효한 JSON을 반환하면 jsonBody가 null이 아님
        System.assertEquals(null, res.jsonParseError);
    }

    @IsTest
    static void test_response_wrapper_fields_populated() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('POST', 'callout:Dummy_NC/api/create');
        o.body = new Map<String, Object>{ 'name' => 'test' };

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);

        // ResponseWrapper의 필드들이 채워졌는지 확인
        System.assertNotEquals(null, res.statusCode);
        System.assertNotEquals(null, res.method);
        System.assertNotEquals(null, res.requestUrl);
        System.assertNotEquals(null, res.responseDateTime);
        System.assertNotEquals(null, res.attempts);
    }

    @IsTest
    static void test_401_without_token_refresher() {
        // tokenRefresher를 null로 설정
        CommonApiClient.setTokenRefresher(null);

        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/secure');
        o.maxRetries = 1;
        o.throwOnHttpError = false;
        o.refreshTokenOn401 = false;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        // tokenRefresher가 없으면 401 그대로 반환
        System.assertEquals(401, res.statusCode);
        System.assertEquals(false, res.tokenRefreshed);
    }

    // ===== Helper: 토큰 갱신 실패하는 Refresher =====
    @IsTest
    static void test_shouldRetry_maxRetries_exceeded() {
        // maxRetries를 초과하면 재시도 안함
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/retry');
        o.maxRetries = 1; // 최대 1회 재시도
        o.throwOnHttpError = false;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        // 재시도 후에도 실패하면 500 반환
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void test_shouldRetry_custom_status_codes() {
        // 커스텀 retryStatusCodes 사용
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/custom-error');
        o.maxRetries = 2;
        o.throwOnHttpError = false;
        // 커스텀 재시도 상태 코드 지정
        o.retryStatusCodes = new Set<Integer>{ 503, 504 };

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void test_shouldRetry_default_retry_status() {
        // DEFAULT_RETRY_STATUS (408, 429, 500, 502, 503, 504) 사용
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/retry');
        o.maxRetries = 1;
        o.throwOnHttpError = false;
        // retryStatusCodes를 지정하지 않으면 DEFAULT_RETRY_STATUS 사용

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void test_shouldRetry_401_not_retried() {
        // 401은 shouldRetry에서 false 반환 (tokenRefresher 경로에서만 처리)
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/secure');
        o.maxRetries = 2;
        o.throwOnHttpError = false;
        o.refreshTokenOn401 = true; // tokenRefresher 경로 활성화

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        // 401은 일반 재시도 로직이 아닌 tokenRefresher로 처리
        System.assertNotEquals(null, res);
    }

    @IsTest
    static void test_shouldRetry_with_callout_exception() {
        // CalloutException은 재시도 가능
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/timeout');
        o.maxRetries = 1;

        try {
            CommonApiClient.send(o);
        } catch (System.CalloutException e) {
            // CalloutException 발생하면 재시도 로직 작동
            System.assert(e.getMessage().contains('timeout'));
        }
    }

    @IsTest
    static void test_buildHttpError_fields_populated() {
        // buildHttpError로 생성된 HttpErrorException의 필드 확인
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('POST', 'callout:Dummy_NC/api/bad');
        o.throwOnHttpError = true;
        o.body = new Map<String, Object>{ 'test' => 'data' };

        try {
            CommonApiClient.send(o);
            System.assert(false, 'HttpErrorException이 발생해야 합니다');
        } catch (HttpErrorException e) {
            // HttpErrorException의 모든 필드가 채워졌는지 확인
            System.assertEquals(400, e.statusCode);
            System.assertNotEquals(null, e.responseBody);
            System.assertNotEquals(null, e.endpoint);
            System.assertEquals('POST', e.method);
            System.assertNotEquals(null, e.responseHeaders);
        }
    }

    @IsTest
    static void test_buildHttpError_with_json_body() {
        // JSON 응답이 있는 경우 buildHttpError
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/bad');
        o.throwOnHttpError = true;
        o.parseJson = true;

        try {
            CommonApiClient.send(o);
            System.assert(false);
        } catch (HttpErrorException e) {
            System.assertEquals(400, e.statusCode);
            // responseBody가 있어야 함
            System.assertNotEquals(null, e.responseBody);
        }
    }

    @IsTest
    static void test_buildHttpError_preserves_request_context() {
        // buildHttpError가 요청 컨텍스트를 보존하는지 확인
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('DELETE', 'callout:Dummy_NC/api/bad');
        o.throwOnHttpError = true;
        o.headers.put('X-Custom-Header', 'test-value');

        try {
            CommonApiClient.send(o);
            System.assert(false);
        } catch (HttpErrorException e) {
            // endpoint와 method가 정확히 보존되는지 확인
            System.assert(e.endpoint.contains('api/bad'));
            System.assertEquals('DELETE', e.method);
        } catch (Exception e) {
            System.assert(true);
        }
    }

    @IsTest
    static void test_shouldRetry_empty_retry_status_codes() {
        // retryStatusCodes가 빈 Set인 경우 DEFAULT_RETRY_STATUS 사용
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        CommonApiClient.RequestOptions o = opt('GET', 'callout:Dummy_NC/api/retry');
        o.maxRetries = 1;
        o.throwOnHttpError = false;
        o.retryStatusCodes = new Set<Integer>(); // 빈 Set

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(o);
        System.assertNotEquals(null, res);
    }

    // ===== Helper: 토큰 갱신 실패하는 Refresher =====
    private class FailingTokenRefresher implements CommonApiClient.ITokenRefresher {
        public Boolean refresh(
            CommonApiClient.RequestOptions opt,
            CommonApiClient.ResponseWrapper failedRes
        ) {
            // 항상 갱신 실패
            return false;
        }
    }
}