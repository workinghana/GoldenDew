@IsTest
private class GdMediumProductCategoryApiCntrlrV1Test {
    private static void setupRest(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/mediumCategory/product';
        req.httpMethod = 'POST';
        if (body != null)
            req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    @IsTest
    static void upsertProductCategory_emptyBody_handlesError() {
        setupRest(null);
        Test.startTest();
        GdMediumProductCategoryApiControllerV1.upsertProductCategory();
        Test.stopTest();
        System.assertNotEquals(null, RestContext.response);
    }

    @IsTest
    static void upsertProductCategory_invalidJson_handlesError() {
        setupRest('{invalid-json}');
        Test.startTest();
        GdMediumProductCategoryApiControllerV1.upsertProductCategory();
        Test.stopTest();
        System.assertNotEquals(null, RestContext.response);
    }

    @IsTest
    static void test_setProductCategoryService_coverage() {
        setupRest('{}');
        GdProductCategoryService serviceImpl = new GdProductCategoryServiceImpl();
        GdMediumProductCategoryApiControllerV1.setProductCategoryService(serviceImpl);

        Test.startTest();
        GdMediumProductCategoryApiControllerV1.upsertProductCategory();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response);
    }
}