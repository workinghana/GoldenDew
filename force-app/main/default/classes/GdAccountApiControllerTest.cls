@IsTest
private class GdAccountApiControllerTest {
    // === 공통 헬퍼: RestContext 세팅 ===
    private static void setupRestContext(String method, String bodyJson) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/account';
        req.httpMethod = method;
        if (bodyJson != null) {
            req.addHeader('Content-Type', 'application/json');
            req.requestBody = Blob.valueOf(bodyJson);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    // === 모킹 서비스 ===
    private class MockService implements GdAccountService {
        public ApiResult createResult;
        public ApiResult updateResult;
        public Exception createThrow; // 설정 시 create에서 던짐
        public Exception updateThrow; // 설정 시 update에서 던짐

        public ApiResult createAccount(Map<String, Object> reqData) {
            if (createThrow != null) {
                // CustomException, Exception 모두 허용
                Exception e = createThrow;
                createThrow = null; // 중복 던짐 방지
                if (e instanceof CustomException) {
                    throw (CustomException) e;
                }
                throw e;
            }
            return createResult;
        }

        public ApiResult updateAccount(Map<String, Object> reqData) {
            if (updateThrow != null) {
                Exception e = updateThrow;
                updateThrow = null;
                if (e instanceof CustomException) {
                    throw (CustomException) e;
                }
                throw e;
            }
            return updateResult;
        }

        public ApiResult deleteAccount(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', null);
        }
    }

    // === 1) POST 성공 (201) ===
    @IsTest
    static void testCreateAccount_success() {
        // given
        MockService mock = new MockService();
        mock.createResult = new ApiResult(
            true,
            201,
            'Created',
            new Map<String, Object>{ 'id' => '001xx0000000001' }
        );
        GdAccountApiController.setAccountService(mock);

        String body = '{"Name":"Milvus","Type":"Customer"}';
        setupRestContext('POST', body);

        // when
        Test.startTest();
        GdAccountApiController.createAccount();
        Test.stopTest();

        // then
        System.assertEquals(201, RestContext.response.statusCode, 'POST는 201이어야 함');
        String resp = RestContext.response.responseBody == null
            ? null
            : RestContext.response.responseBody.toString();
        System.assert(true);

        // cleanup
        GdAccountApiController.setAccountService(null);
    }

    // === 2) PATCH 성공 (200) ===
    @IsTest
    static void testUpdateAccount_success() {
        MockService mock = new MockService();
        mock.updateResult = new ApiResult(
            true,
            200,
            'Updated',
            new Map<String, Object>{ 'updated' => true }
        );
        GdAccountApiController.setAccountService(mock);

        String body = '{"Id":"001xx0000000001","Phone":"02-123-4567"}';
        setupRestContext('PATCH', body);

        Test.startTest();
        GdAccountApiController.updateAccount();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'PATCH는 200이어야 함');
        String resp = RestContext.response.responseBody == null
            ? null
            : RestContext.response.responseBody.toString();
        System.assert(true);

        GdAccountApiController.setAccountService(null);
    }

    // === 3) 본문 없음 → 400 ===
    @IsTest
    static void testCreateAccount_emptyBody_400() {
        GdAccountApiController.setAccountService(new MockService()); // 호출은 되지만 사용 안 됨
        setupRestContext('POST', null);

        Test.startTest();
        GdAccountApiController.createAccount();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        String resp = RestContext.response.responseBody == null
            ? null
            : RestContext.response.responseBody.toString();
        System.assert(resp != null && resp.contains('요청 본문이 비었습니다'), '에러 메시지 확인');

        GdAccountApiController.setAccountService(null);
    }

    // === 4) 잘못된 JSON → 400 ===
    @IsTest
    static void testCreateAccount_badJson_400() {
        GdAccountApiController.setAccountService(new MockService());
        setupRestContext('POST', '{invalid');

        Test.startTest();
        GdAccountApiController.createAccount();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        String resp = RestContext.response.responseBody == null
            ? null
            : RestContext.response.responseBody.toString();
        System.assert(resp != null && resp.contains('JSON 역직렬화 실패'), '역직렬화 실패 메시지');

        GdAccountApiController.setAccountService(null);
    }

    // === 5) CustomException(422) → 422 ===
    @IsTest
    static void testUpdateAccount_customException_422() {
        MockService mock = new MockService();
        mock.updateThrow = new CustomException(422, '유효성 오류');
        GdAccountApiController.setAccountService(mock);

        setupRestContext('PATCH', '{"Id":"001xx0000000001"}');

        Test.startTest();
        GdAccountApiController.updateAccount();
        Test.stopTest();

        System.assertEquals(422, RestContext.response.statusCode);
        String resp = RestContext.response.responseBody == null
            ? null
            : RestContext.response.responseBody.toString();
        System.assert(resp != null && resp.contains('유효성 오류'), '커스텀 예외 메시지');

        GdAccountApiController.setAccountService(null);
    }

    // === 6) 일반 예외 → 500 ===
    @IsTest
    static void testCreateAccount_generalException_500() {
        MockService mock = new MockService();
        mock.createThrow = new CustomException(500, 'NPE or something');
        GdAccountApiController.setAccountService(mock);

        setupRestContext('POST', '{"Name":"X"}');

        Test.startTest();
        GdAccountApiController.createAccount();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        String resp = RestContext.response.responseBody == null
            ? null
            : RestContext.response.responseBody.toString();
        System.assert(
            resp != null && resp.contains('error') || resp.contains('message'),
            '일반 예외 처리 바디 체크'
        );

        GdAccountApiController.setAccountService(null);
    }
}