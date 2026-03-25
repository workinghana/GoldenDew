@RestResource(urlMapping='/gd/v1/smallCategory/product')
global with sharing class GdSmallProductCategoryApiControllerV1 {

    private static GdProductCategoryService productCategoryService;

    @TestVisible
    private static void setProductCategoryService(GdProductCategoryService mock) {
        productCategoryService = mock;
    }

    private static GdProductCategoryService getProductCategoryService() {
        if (productCategoryService == null) {
            productCategoryService = new GdProductCategoryServiceImpl();
        }
        return productCategoryService;
    }

    /**
     * 제품 소분류 카테고리 등록/수정 (UPSERT)
     */
    @HttpPost
    global static void upsertProductCategory() {

        ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
        logger.logging(GdSmallProductCategoryApiControllerV1.class.getName());

        RestRequest req = RestContext.request;
        Savepoint sp = Database.setSavepoint();

        try {
            String raw =
                (req.requestBody == null) ? null : req.requestBody.toString();

            if (String.isBlank(raw)) {
                throw new CustomException(400, '요청 본문이 비었습니다.');
            }

            Map<String, Object> reqData;
            try {
                reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
            } catch (Exception e) {
                throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
            }

            ApiResult result =
                getProductCategoryService()
                    .upsertSmallProductCategoryProduct(reqData);

            RestResponseUtil.handleSuccess(result);
            return;

        } catch (CustomException ce) {
            RestResponseUtil.handleCustomException(
                ce, sp, ce.code, ce.message
            );
        } catch (Exception e) {
            RestResponseUtil.handleException(e, sp, 500);
        }
    }
}