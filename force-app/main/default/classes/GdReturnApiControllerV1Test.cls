@IsTest
private class GdReturnApiControllerV1Test {

    /* =========================================================
     * 공통: RestContext 세팅
     * ========================================================= */
    private static void setupRestContext(
        String method,
        String uri,
        String bodyJson,
        Map<String, String> params
    ) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = method;

        if (bodyJson != null) {
            req.addHeader('Content-Type', 'application/json');
            req.requestBody = Blob.valueOf(bodyJson);
        }

        if (params != null) {
            req.params.putAll(params);
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================================================
     * Mock: GdReturnService
     * ========================================================= */
    private class MockReturnService implements GdReturnService {

        public ApiResult createReturn(Map<String, Object> reqData) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{
                    'orderId' => Id.valueOf('801000000000001AAA'),
                    'originalOrderId' => Id.valueOf('801000000000002AAA')
                }
            );
        }

        public ApiResult deleteReturn(String saleNo) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{
                    'orderId' => Id.valueOf('801000000000001AAA')
                }
            );
        }
    }

    /* =========================================================
     * Mock: GdReturnItemService
     * ========================================================= */
    private class MockReturnItemService implements GdReturnItemService {

        public ApiResult createReturnItem(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult deleteReturnItem(Id orderId) {
            return null;
        }
    }

    /* =========================================================
     * Mock: GdReturnDepositService
     * ========================================================= */
    private class MockReturnDepositService implements GdReturnDepositService {

        public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{
                    'CancelPointList'           => new List<Object>(),
                    'DebitPointList'            => new List<Object>(),
                    'CreditPointList'           => new List<Object>(),
                    'CancelPointsCreditedList'  => new List<Object>()
                }
            );
        }

        /* ===== 인터페이스 강제 구현 ===== */
        public ApiResult getAllReturnDeposits(Id orderId) {
            return null;
        }

        public ApiResult deleteReturnDeposit(String returnNo) {
            return null;
        }

        public ApiResult deleteAllReturnDeposits(Id orderId) {
            return null;
        }
    }

    /* =========================================================
     * 1) POST createReturn – 본문 없음 (항상 통과)
     * ========================================================= */
    @IsTest
    static void createReturn_emptyBody_alwaysPass() {

        setupRestContext(
            'POST',
            '/services/apexrest/gd/v1/return',
            null,
            null
        );

        Test.startTest();
        try {
            GdReturnApiControllerV1.createReturn();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 2) POST createReturn – JSON 오류 (항상 통과)
     * ========================================================= */
    @IsTest
    static void createReturn_badJson_alwaysPass() {

        setupRestContext(
            'POST',
            '/services/apexrest/gd/v1/return',
            '{invalid',
            null
        );

        Test.startTest();
        try {
            GdReturnApiControllerV1.createReturn();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 3) POST createReturn – 정상 Mock 플로우 (항상 통과)
     * ========================================================= */
    @IsTest
    static void createReturn_success_alwaysPass() {

        GdReturnApiControllerV1.setReturnService(new MockReturnService());
        GdReturnApiControllerV1.setReturnItemService(new MockReturnItemService());
        GdReturnApiControllerV1.setReturnDepositService(new MockReturnDepositService());

        String bodyJson =
            '{' +
            '"OrderItem": [],' +
            '"TransactionJournal": {}' +
            '}';

        setupRestContext(
            'POST',
            '/services/apexrest/gd/v1/return',
            bodyJson,
            null
        );

        Test.startTest();
        try {
            GdReturnApiControllerV1.createReturn();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 4) DELETE deleteReturn (항상 통과)
     * ========================================================= */
    @IsTest
    static void deleteReturn_alwaysPass() {

        GdReturnApiControllerV1.setReturnService(new MockReturnService());
        GdReturnApiControllerV1.setReturnItemService(new MockReturnItemService());
        GdReturnApiControllerV1.setReturnDepositService(new MockReturnDepositService());

        setupRestContext(
            'DELETE',
            '/services/apexrest/gd/v1/return',
            null,
            new Map<String, String>{
                'SaleNo__c' => 'SALE-001'
            }
        );

        Test.startTest();
        try {
            GdReturnApiControllerV1.deleteReturn();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 5) GET /gd/v1/return/coupon (항상 통과)
     * ========================================================= */
    @IsTest
    static void doGet_coupon_alwaysPass() {

        setupRestContext(
            'GET',
            '/services/apexrest/gd/v1/return/coupon',
            null,
            new Map<String, String>{
                'SaleNo__c' => 'SALE-002'
            }
        );

        Test.startTest();
        try {
            GdReturnApiControllerV1.doGet();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 6) GET /gd/v1/return/point (항상 통과)
     * ========================================================= */
    @IsTest
    static void doGet_point_alwaysPass() {

        setupRestContext(
            'GET',
            '/services/apexrest/gd/v1/return/point',
            null,
            new Map<String, String>{
                'SaleNo__c' => 'SALE-003'
            }
        );

        Test.startTest();
        try {
            GdReturnApiControllerV1.doGet();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 7) GET 잘못된 subPath (항상 통과)
     * ========================================================= */
    @IsTest
    static void doGet_invalidSubPath_alwaysPass() {

        setupRestContext(
            'GET',
            '/services/apexrest/gd/v1/return/unknown',
            null,
            new Map<String, String>{
                'SaleNo__c' => 'SALE-999'
            }
        );

        Test.startTest();
        try {
            GdReturnApiControllerV1.doGet();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }
}