@RestResource(urlMapping='/gd/v1/largeCategory/product')
global with sharing class GdLargeProductCategoryApiControllerV1 {
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
   * 제품 대분류 카테고리 등록/수정 (UPSERT)
   */
  @HttpPost
  global static void upsertLargeProductCategory() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdLargeProductCategoryApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();

    try {
      String raw = (req.requestBody == null) ? null : req.requestBody.toString();

      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);

      ApiResult result = getProductCategoryService().upsertLargeProductCategoryProduct(reqData);

      RestContext.response.responseBody = Blob.valueOf(JSON.serialize(result));
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }
}