@IsTest
private class GdLargeProductCategoryApiCntrlrV1Test {

    private class SuccessMockService implements GdProductCategoryService {
        public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
            System.assertNotEquals(null, reqData);
            System.assertEquals('CAT001', (String) reqData.get('categoryCode'));

            return (ApiResult) JSON.deserialize(
                '{"success": true, "message": "SUCCESS"}',
                ApiResult.class
            );
        }

        public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
            return (ApiResult) JSON.deserialize(
                '{"success": true, "message": "MEDIUM SUCCESS"}',
                ApiResult.class
            );
        }

        public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
            return (ApiResult) JSON.deserialize(
                '{"success": true, "message": "SMALL SUCCESS"}',
                ApiResult.class
            );
        }
    }

    private class ExceptionMockService implements GdProductCategoryService {
        public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
            throw new IllegalArgumentException('강제 예외 발생');
        }

        public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
            throw new IllegalArgumentException('강제 예외 발생');
        }

        public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
            throw new IllegalArgumentException('강제 예외 발생');
        }
    }

    private static void setRestContext(String requestBody) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/largeCategory/product';
        req.httpMethod = 'POST';

        if (requestBody != null) {
            req.requestBody = Blob.valueOf(requestBody);
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void upsertLargeProductCategory_success() {
        setRestContext('{"categoryCode":"CAT001","categoryName":"반지"}');
        GdLargeProductCategoryApiControllerV1.setProductCategoryService(new SuccessMockService());

        Test.startTest();
        GdLargeProductCategoryApiControllerV1.upsertLargeProductCategory();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response);
        System.assertNotEquals(null, RestContext.response.responseBody);

        String responseBody = RestContext.response.responseBody.toString();
        System.assert(responseBody.contains('SUCCESS'));
    }

    @IsTest
    static void upsertLargeProductCategory_emptyBody() {
        setRestContext('');
        GdLargeProductCategoryApiControllerV1.setProductCategoryService(new SuccessMockService());

        Test.startTest();
        GdLargeProductCategoryApiControllerV1.upsertLargeProductCategory();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);

        String responseBody = RestContext.response.responseBody == null
            ? ''
            : RestContext.response.responseBody.toString();

        System.assert(responseBody.contains('요청 본문이 비었습니다.'));
    }

    @IsTest
    static void upsertLargeProductCategory_nullBody() {
        setRestContext(null);
        GdLargeProductCategoryApiControllerV1.setProductCategoryService(new SuccessMockService());

        Test.startTest();
        GdLargeProductCategoryApiControllerV1.upsertLargeProductCategory();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);

        String responseBody = RestContext.response.responseBody == null
            ? ''
            : RestContext.response.responseBody.toString();

        System.assert(responseBody.contains('요청 본문이 비었습니다.'));
    }

    @IsTest
    static void upsertLargeProductCategory_invalidJson() {
        setRestContext('invalid json');
        GdLargeProductCategoryApiControllerV1.setProductCategoryService(new SuccessMockService());

        Test.startTest();
        GdLargeProductCategoryApiControllerV1.upsertLargeProductCategory();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
    }

    @IsTest
    static void upsertLargeProductCategory_serviceException() {
        setRestContext('{"categoryCode":"CAT001","categoryName":"반지"}');
        GdLargeProductCategoryApiControllerV1.setProductCategoryService(new ExceptionMockService());

        Test.startTest();
        GdLargeProductCategoryApiControllerV1.upsertLargeProductCategory();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
    }
}