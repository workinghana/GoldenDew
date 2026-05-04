//@RestResource(urlMapping='/gd/v1/promotion/product')
global with sharing class GdPromotionProductApiControllerV1 {
  private static GdProductService productService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setProductService(GdProductService mock) {
    productService = mock;
  }

  private static GdProductService getProductService() {
    if (productService == null)
      productService = new GdProductServiceImpl();
    return productService;
  }

  /**
   * 품목 도움창 조회 (프로모션 연동) API
   */
  //@HttpGet
  global static void getProductByPromotion() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdPromotionProductApiControllerV1.class.getName());

    try {
      RestRequest req = RestContext.request;
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      String promotionNo = ValidationUtil.stringValidationEx(req.params.get('PromotionNo__c'), 'PromotionNo__c', true, false);

      ApiResult result = getProductService().getProductByPromotion(promotionNo);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }
}