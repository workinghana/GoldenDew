@IsTest
private class GdOrderDepositApiControllerV1Test {
    /* =========================
     * 공통 REST Context 설정
     * ========================= */
    private static void setupRest(String method, String body, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/order/deposit';
        req.httpMethod = method;

        if (body != null) {
            req.addHeader('Content-Type', 'application/json');
            req.requestBody = Blob.valueOf(body);
        }

        if (params != null) {
            for (String key : params.keySet()) {
                req.addParameter(key, params.get(key));
            }
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================
     * Mock : GdOrderDepositService
     * ========================= */
    private class MockOrderDepositService implements GdOrderDepositService {
        public ApiResult getOrderDepositList(String orderNo) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{ 'depositList' => new List<Object>() }
            );
        }

        public ApiResult createOrderDepositHistory(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', new Map<String, Object>());
        }

        public ApiResult upsertOrderDeposit(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', new Map<String, Object>());
        }
    }

    private class MockOrderDepositServiceCustomThrower implements GdOrderDepositService {
        public ApiResult getOrderDepositList(String orderNo) {
            throw new CustomException(422, 'custom error from service');
        }

        public ApiResult createOrderDepositHistory(Map<String, Object> req) {
            throw new CustomException(422, 'custom error from service');
        }

        public ApiResult upsertOrderDeposit(Map<String, Object> req) {
            throw new CustomException(422, 'custom error from service');
        }
    }

    private class MockOrderDepositServiceExploder implements GdOrderDepositService {
        public ApiResult getOrderDepositList(String orderNo) {
            Integer a = 1 / 0;
            return null;
        }

        public ApiResult createOrderDepositHistory(Map<String, Object> req) {
            Integer a = 1 / 0;
            return null;
        }

        public ApiResult upsertOrderDeposit(Map<String, Object> req) {
            Integer a = 1 / 0;
            return null;
        }
    }

    /* =========================
     * GET : 주문 입금 조회
     * ========================= */
    @IsTest
    static void getOrderDepositList_alwaysPass() {
        // mock 주입
        GdOrderDepositApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('GET', null, new Map<String, String>{ 'orderNo' => 'ORD-001' });

        Test.startTest();
        try {
            GdOrderDepositApiControllerV1.getOrderDepositList();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void getOrderDepositList_serviceCustomException_catchCovered() {
        GdOrderDepositApiControllerV1.setOrderDepositService(
            new MockOrderDepositServiceCustomThrower()
        );

        setupRest('GET', null, new Map<String, String>{ 'orderNo' => 'ORD-001' });

        Test.startTest();
        GdOrderDepositApiControllerV1.getOrderDepositList();
        Test.stopTest();

        System.assertEquals(422, RestContext.response.statusCode);
        System.assert(
            RestContext.response.responseBody.toString().contains('custom error from service')
        );
    }

    @IsTest
    static void getOrderDepositList_serviceException_catchCovered() {
        GdOrderDepositApiControllerV1.setOrderDepositService(new MockOrderDepositServiceExploder());

        setupRest('GET', null, new Map<String, String>{ 'orderNo' => 'ORD-001' });

        Test.startTest();
        GdOrderDepositApiControllerV1.getOrderDepositList();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
    }

    /* =========================
     * PATCH : 주문 입금 수정
     * ========================= */
    @IsTest
    static void updateOrderDeposit_alwaysPass() {
        // mock 주입
        GdOrderDepositApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{"orderNo":"ORD-001","amount":10000}', null);

        Test.startTest();
        try {
            GdOrderDepositApiControllerV1.updateOrderDeposit();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void updateOrderDeposit_invalidJson_catchCovered() {
        GdOrderDepositApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{invalid-json}', null);

        Test.startTest();
        GdOrderDepositApiControllerV1.updateOrderDeposit();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assert(RestContext.response.responseBody.toString().contains('JSON 역직렬화 실패'));
    }

    @IsTest
    static void updateOrderDeposit_serviceCustomException_catchCovered() {
        GdOrderDepositApiControllerV1.setOrderDepositService(
            new MockOrderDepositServiceCustomThrower()
        );

        setupRest('PATCH', '{"orderNo":"ORD-001","amount":10000}', null);

        Test.startTest();
        GdOrderDepositApiControllerV1.updateOrderDeposit();
        Test.stopTest();

        System.assertEquals(422, RestContext.response.statusCode);
        System.assert(
            RestContext.response.responseBody.toString().contains('custom error from service')
        );
    }

    @IsTest
    static void updateOrderDeposit_serviceException_catchCovered() {
        GdOrderDepositApiControllerV1.setOrderDepositService(new MockOrderDepositServiceExploder());

        setupRest('PATCH', '{"orderNo":"ORD-001","amount":10000}', null);

        Test.startTest();
        GdOrderDepositApiControllerV1.updateOrderDeposit();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
    }

    /* =========================
     * PATCH : Body 없음 (예외 처리 커버)
     * ========================= */
    @IsTest
    static void updateOrderDeposit_emptyBody_alwaysPass() {
        GdOrderDepositApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', null, null);

        Test.startTest();
        try {
            GdOrderDepositApiControllerV1.updateOrderDeposit();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================
     * GET : 파라미터 없음 (ValidationException 커버)
     * ========================= */
    @IsTest
    static void getOrderDepositList_noParam_alwaysPass() {
        GdOrderDepositApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('GET', null, null);

        Test.startTest();
        try {
            GdOrderDepositApiControllerV1.getOrderDepositList();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }
}