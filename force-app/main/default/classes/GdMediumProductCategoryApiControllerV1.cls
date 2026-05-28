@RestResource(urlMapping='/gd/v1/mediumCategory/product')
global with sharing class GdMediumProductCategoryApiControllerV1 {
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
   * 제품 중분류 카테고리 등록/수정 (UPSERT)
   */
  @HttpPost
  global static void upsertProductCategory() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdMediumProductCategoryApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();

    try {
      String raw = (req.requestBody == null) ? null : req.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용

      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      ApiResult result = getProductCategoryService().upsertMediumProductCategoryProduct(reqData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
  }
}