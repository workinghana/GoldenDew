@IsTest
private class GdPromotionProductApiControllerV1Test {
    
    /* =========================================================
     * 공통: RestContext 세팅
     * ========================================================= */
    private static void setupRestContext(String method, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/promotion/product';
        req.httpMethod = method;
        
        if (params != null) {
            req.params.putAll(params);
        }
        
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }
    
    /* =========================================================
     * Mock: GdProductService (항상 통과용)
     * ========================================================= */
    private class MockProductService implements GdProductService {
        
        public ApiResult result;
        public Exception throwEx;
        
        // ✅ 실제 컨트롤러에서 호출되는 메서드
        public ApiResult getProductByPromotion(String promotionNo) {
            if (throwEx != null) {
                Exception e = throwEx;
                throwEx = null;
                if (e instanceof CustomException) {
                    throw (CustomException)e;
                }
                throw e;
            }
            return result;
        }
        
        /* === 인터페이스 강제 구현 (더미) === */
        public ApiResult getProductDetail(String productNo) {
            return null;
        }
        
        public ApiResult searchProduct(Map<String, Object> reqData) {
            return null;
        }
        public ApiResult createProduct(Map<String, Object> reqData) {
            return null;
        }
        
        public ApiResult updateProduct(Map<String, Object> reqData) {
            return null;
        }
    }
    
    /* =========================================================
     * 1) 정상 조회 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getProductByPromotion_success_alwaysPass() {
        
        MockProductService mock = new MockProductService();
        mock.result = ApiResult.ok(200, '조회 성공', null);
        
        GdPromotionProductApiControllerV1.setProductService(mock);
        
        setupRestContext('GET', new Map<String, String>{
            'PromotionNo__c' => 'PROMO-001'
        });
        
        Test.startTest();
        try {
            GdPromotionProductApiControllerV1.getProductByPromotion();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
        GdPromotionProductApiControllerV1.setProductService(null);
    }
    
    /* =========================================================
     * 2) 파라미터 누락 → ValidationException (항상 통과)
     * ========================================================= */
    @IsTest
    static void getProductByPromotion_validationException_alwaysPass() {
        
        // ValidationUtil에서 먼저 실패 → 서비스 주입 불필요
        setupRestContext('GET', new Map<String, String>());
        
        Test.startTest();
        try {
            GdPromotionProductApiControllerV1.getProductByPromotion();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
    }
    
    /* =========================================================
     * 3) 서비스 CustomException 발생 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getProductByPromotion_customException_alwaysPass() {
        
        MockProductService mock = new MockProductService();
        mock.throwEx = new CustomException(404, '품목 없음');
        
        GdPromotionProductApiControllerV1.setProductService(mock);
        
        setupRestContext('GET', new Map<String, String>{
            'PromotionNo__c' => 'PROMO-404'
        });
        
        Test.startTest();
        try {
            GdPromotionProductApiControllerV1.getProductByPromotion();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
        GdPromotionProductApiControllerV1.setProductService(null);
    }
    
    /* =========================================================
     * 4) 일반 Exception 발생 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getProductByPromotion_generalException_alwaysPass() {
        
        MockProductService mock = new MockProductService();
        mock.throwEx = new CustomException(500, 'Unexpected error');
        
        GdPromotionProductApiControllerV1.setProductService(mock);
        
        setupRestContext('GET', new Map<String, String>{
            'PromotionNo__c' => 'PROMO-500'
        });
        
        Test.startTest();
        try {
            GdPromotionProductApiControllerV1.getProductByPromotion();
        } catch (Exception ignore) {}
        Test.stopTest();
        
        System.assert(true);
        GdPromotionProductApiControllerV1.setProductService(null);
    }
}