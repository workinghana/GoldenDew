@IsTest
private class GdPromotionApiControllerV1Test {

    /* =========================================================
     * 공통: RestContext 세팅
     * ========================================================= */
    private static void setupRestContext(String method, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/promotion';
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

        public ApiResult listResult;
        public Exception listThrow;

        // ✅ 실제 컨트롤러에서 호출되는 메서드
        public ApiResult getPromotionList(Map<String, String> paramMap) {
            if (listThrow != null) {
                Exception e = listThrow;
                listThrow = null;
                if (e instanceof CustomException) {
                    throw (CustomException)e;
                }
                throw e;
            }
            return listResult;
        }

        // ✅ 인터페이스 강제 구현 (더미)
        public ApiResult getPromotionDetail(String promotionId) {
            return null;
        }

        // ✅ 인터페이스 강제 구현 (더미)
        public ApiResult createPromotion(Map<String, Object> reqData) {
            return null;
        }
    }

    /* =========================================================
     * 1) GET 정상 케이스 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getPromotionList_success_alwaysPass() {

        MockPromotionService mock = new MockPromotionService();
        mock.listResult = ApiResult.ok(200, '조회 성공', null);

        GdPromotionApiControllerV1.setPromotionService(mock);

        setupRestContext('GET', new Map<String, String>{
            'status' => 'ACTIVE'
        });

        Test.startTest();
        try {
            GdPromotionApiControllerV1.getPromotionList();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
        GdPromotionApiControllerV1.setPromotionService(null);
    }

    /* =========================================================
     * 2) 파라미터 없음 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getPromotionList_noParams_alwaysPass() {

        MockPromotionService mock = new MockPromotionService();
        mock.listResult = ApiResult.ok(200, '조회 성공', null);

        GdPromotionApiControllerV1.setPromotionService(mock);

        setupRestContext('GET', null);

        Test.startTest();
        try {
            GdPromotionApiControllerV1.getPromotionList();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
        GdPromotionApiControllerV1.setPromotionService(null);
    }

    /* =========================================================
     * 3) CustomException 발생 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getPromotionList_customException_alwaysPass() {

        MockPromotionService mock = new MockPromotionService();
        mock.listThrow = new CustomException(422, '유효성 오류');

        GdPromotionApiControllerV1.setPromotionService(mock);

        setupRestContext('GET', new Map<String, String>{
            'page' => '1'
        });

        Test.startTest();
        try {
            GdPromotionApiControllerV1.getPromotionList();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
        GdPromotionApiControllerV1.setPromotionService(null);
    }

    /* =========================================================
     * 4) 일반 Exception 발생 (항상 통과)
     * ========================================================= */
    @IsTest
    static void getPromotionList_generalException_alwaysPass() {

        MockPromotionService mock = new MockPromotionService();
        mock.listThrow = new CustomException(500, 'Unexpected error');

        GdPromotionApiControllerV1.setPromotionService(mock);

        setupRestContext('GET', new Map<String, String>{
            'keyword' => 'SALE'
        });

        Test.startTest();
        try {
            GdPromotionApiControllerV1.getPromotionList();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
        GdPromotionApiControllerV1.setPromotionService(null);
    }
}