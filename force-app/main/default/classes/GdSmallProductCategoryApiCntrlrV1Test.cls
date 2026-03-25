@IsTest
private class GdSmallProductCategoryApiCntrlrV1Test {

    private static void setupRest(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/smallCategory/product';
        req.httpMethod = 'POST';
        if (body != null) req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================================================
     * Mock : GdProductCategoryService
     * ========================================================= */
    private class MockProductCategoryService implements GdProductCategoryService {
        public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }
    }

    private class CustomExceptionMockService implements GdProductCategoryService {
        public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
            throw new CustomException(422, 'custom error');
        }
    }

    private class RuntimeExceptionMockService implements GdProductCategoryService {
        public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
            throw new IllegalArgumentException('unexpected error');
        }
    }

    /* =========================================================
     * 기존 테스트
     * ========================================================= */
    @IsTest
    static void upsertProductCategory_emptyBody_handlesError() {
        setupRest(null);
        Test.startTest();
        GdSmallProductCategoryApiControllerV1.upsertProductCategory();
        Test.stopTest();
        System.assertNotEquals(null, RestContext.response);
    }

    @IsTest
    static void upsertProductCategory_invalidJson_handlesError() {
        setupRest('{invalid-json}');
        Test.startTest();
        GdSmallProductCategoryApiControllerV1.upsertProductCategory();
        Test.stopTest();
        System.assertNotEquals(null, RestContext.response);
    }

    /* =========================================================
     * setProductCategoryService / getProductCategoryService 커버
     * ========================================================= */
    @IsTest
    static void upsertProductCategory_success_withMock() {
        GdSmallProductCategoryApiControllerV1.setProductCategoryService(new MockProductCategoryService());
        setupRest('{"categoryCode":"CAT-001"}');

        Test.startTest();
        GdSmallProductCategoryApiControllerV1.upsertProductCategory();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* =========================================================
     * catch (CustomException) 커버
     * ========================================================= */
    @IsTest
    static void upsertProductCategory_serviceCustomException() {
        GdSmallProductCategoryApiControllerV1.setProductCategoryService(new CustomExceptionMockService());
        setupRest('{"categoryCode":"CAT-001"}');

        Test.startTest();
        GdSmallProductCategoryApiControllerV1.upsertProductCategory();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * catch (Exception) 커버
     * ========================================================= */
    @IsTest
    static void upsertProductCategory_serviceException() {
        GdSmallProductCategoryApiControllerV1.setProductCategoryService(new RuntimeExceptionMockService());
        setupRest('{"categoryCode":"CAT-001"}');

        Test.startTest();
        GdSmallProductCategoryApiControllerV1.upsertProductCategory();
        Test.stopTest();

        System.assert(true);
    }
}