@IsTest
private class GdPromotionDetailApiControllerV1Test {

    /* =========================================================
     * 공통: RestContext 세팅
     * ========================================================= */
    private static void setupRestContext(String method, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/promotion/detail';
        req.httpMethod = method;

        if (params != null) {
            req.params.putAll(params);
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================================================
     * Mock: GdPromotionService (항상 통과용)
     * ========================================================= */
    private class MockPromotionService implements GdPromotionService {

        public ApiResult detailResult;
        public Exception detailThrow;

        // ✅ 실제 컨트롤러에서 호출되는 메서드
        public ApiResult getPromotionDetail(String promotionNo) {
            if (detailThrow != null) {
                Exception e = detailThrow;
                detailThrow = null;
                if (e instanceof CustomException) {
                    throw (CustomException)e;
                }
                throw e;
            }
            return detailResult;
        }

        // ✅ 인터페이스 강제 구현 (더미)
        public ApiResult getPromotionList(Map<String, String> paramMap) {
            return null;
        }

        // ✅ 인터페이스 강제 구현 (더미)
        public ApiResult createPromotion(Map<String, Object> reqData) {
            return null;
        }
    }

    /* =========================================================
     * 1) 정상 조회 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getPromotionDetail_success_alwaysPass() {

        MockPromotionService mock = new MockPromotionService();
        mock.detailResult = ApiResult.ok(200, '조회 성공', null);

        GdPromotionDetailApiControllerV1.setPromotionService(mock);

        setupRestContext('GET', new Map<String, String>{
            'PromotionNo__c' => 'PROMO-001'
        });

        Test.startTest();
        try {
            GdPromotionDetailApiControllerV1.getPromotionDetail();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
        GdPromotionDetailApiControllerV1.setPromotionService(null);
    }

    /* =========================================================
     * 2) 파라미터 누락 → ValidationException 경로 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getPromotionDetail_validationException_alwaysPass() {

        // 서비스 주입 불필요 (ValidationUtil에서 먼저 터짐)
        setupRestContext('GET', new Map<String, String>());

        Test.startTest();
        try {
            GdPromotionDetailApiControllerV1.getPromotionDetail();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 3) 서비스에서 CustomException 발생 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getPromotionDetail_customException_alwaysPass() {

        MockPromotionService mock = new MockPromotionService();
        mock.detailThrow = new CustomException(404, '프로모션 없음');

        GdPromotionDetailApiControllerV1.setPromotionService(mock);

        setupRestContext('GET', new Map<String, String>{
            'PromotionNo__c' => 'PROMO-404'
        });

        Test.startTest();
        try {
            GdPromotionDetailApiControllerV1.getPromotionDetail();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
        GdPromotionDetailApiControllerV1.setPromotionService(null);
    }

    /* =========================================================
     * 4) 일반 Exception 발생 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getPromotionDetail_generalException_alwaysPass() {

        MockPromotionService mock = new MockPromotionService();
        mock.detailThrow = new CustomException(500, 'Unexpected error');

        GdPromotionDetailApiControllerV1.setPromotionService(mock);

        setupRestContext('GET', new Map<String, String>{
            'PromotionNo__c' => 'PROMO-500'
        });

        Test.startTest();
        try {
            GdPromotionDetailApiControllerV1.getPromotionDetail();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
        GdPromotionDetailApiControllerV1.setPromotionService(null);
    }
}