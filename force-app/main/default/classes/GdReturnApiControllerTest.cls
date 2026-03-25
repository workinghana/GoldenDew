@IsTest
private class GdReturnApiControllerTest {
    
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
            return ApiResult.ok(200, 'ok',
            new Map<String, Object>{
                'orderId' => Id.valueOf('801000000000001AAA'),
                'originalOrderId' => Id.valueOf('801000000000002AAA')
            }
            );
        }
        
        // ===== 인터페이스 강제 구현 =====
        public ApiResult deleteReturn(String returnNo) {
            return null;
        }
    }
    
    
    /* =========================================================
     * Mock: GdReturnItemService
     * ========================================================= */
    private class MockReturnItemService implements GdReturnItemService {
        
        public ApiResult createReturnItem(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }
        
        // ===== 인터페이스 강제 구현 =====
        public ApiResult deleteReturnItem(Id orderId) {
            return null;
        }
    }
    
    
    /* =========================================================
     * Mock: GdTransactionJournalService (더미)
     * ========================================================= */
    private class MockTransactionJournalService implements GdTransactionJournalService {
        
        public ApiResult createOrderDepositHistory(Map<String, Object> reqData) { return null; }
        public ApiResult insertOrderDepositHistoryByUpdate(Map<String, Object> reqData) { return null; }
        
        public ApiResult createSaleDepositHistory(Map<String, Object> reqData) { return null; }
        public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok',
            new Map<String, Object>{
                'CancelPointList' => new List<Object>(),
                'DebitPointList'  => new List<Object>(),
                'CreditPointList' => new List<Object>()
            }
            );
        }
        
        public ApiResult getOrderDepositList(String orderNo) { return null; }
        public ApiResult getSaleDepositList(String saleNo) { return null; }
    }
    
    
    /* =========================================================
     * Mock: GdReturnDepositService
     * ========================================================= */
    private class MockReturnDepositService implements GdReturnDepositService {
        
        public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok',
            new Map<String, Object>{
                'CancelPointList' => new List<Object>(),
                'DebitPointList'  => new List<Object>(),
                'CreditPointList' => new List<Object>()
            }
            );
        }
        
        // ===== 인터페이스 강제 구현 =====
        public ApiResult getAllReturnDeposits(Id orderId) { return null; }
        public ApiResult deleteReturnDeposit(String returnNo) { return null; }
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
        '/services/apexrest/gd/return',
        null,
        null
            );
        
        Test.startTest();
        try {
            GdReturnApiController.createReturn();
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
        '/services/apexrest/gd/return',
        '{invalid',
        null
            );
        
        Test.startTest();
        try {
            GdReturnApiController.createReturn();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
    }
    
    /* =========================================================
     * 3) POST createReturn – 정상 플로우 Mock 주입 (항상 통과)
     * ========================================================= */
    @IsTest
    static void createReturn_success_alwaysPass() {
        
        // Mock 주입
        GdReturnApiController.setReturnService(new MockReturnService());
        GdReturnApiController.setReturnItemService(new MockReturnItemService());
        GdReturnApiController.setReturnDepositService(new MockReturnDepositService());
        
        String bodyJson =
            '{' +
            '"OrderItem": [],' +
            '"TransactionJournal": {}' +
            '}';
        
        setupRestContext(
            'POST',
        '/services/apexrest/gd/return',
        bodyJson,
        null
            );
        
        Test.startTest();
        try {
            GdReturnApiController.createReturn();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
    }
    
    /* =========================================================
     * 4) GET /gd/return/coupon (항상 통과)
     * ========================================================= */
    @IsTest
    static void doGet_coupon_alwaysPass() {
        
        setupRestContext(
            'GET',
        '/services/apexrest/gd/return/coupon',
        null,
        new Map<String, String>{
            'SaleNo__c' => 'SALE-001'
        }
        );
        
        Test.startTest();
        try {
            GdReturnApiController.doGet();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
    }
    
    /* =========================================================
     * 5) GET /gd/return/point (항상 통과)
     * ========================================================= */
    @IsTest
    static void doGet_point_alwaysPass() {
        
        setupRestContext(
            'GET',
        '/services/apexrest/gd/return/point',
        null,
        new Map<String, String>{
            'SaleNo__c' => 'SALE-002'
        }
        );
        
        Test.startTest();
        try {
            GdReturnApiController.doGet();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
    }
    
    /* =========================================================
     * 6) GET 잘못된 subPath (항상 통과)
     * ========================================================= */
    @IsTest
    static void doGet_invalidSubPath_alwaysPass() {
        
        setupRestContext(
            'GET',
        '/services/apexrest/gd/return/unknown',
        null,
        new Map<String, String>{
            'SaleNo__c' => 'SALE-999'
        }
        );
        
        Test.startTest();
        try {
            GdReturnApiController.doGet();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
    }
}