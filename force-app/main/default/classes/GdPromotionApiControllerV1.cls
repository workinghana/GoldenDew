/**
 * 프로모션 관련 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-01-07
 */
@RestResource(urlMapping='/gd/v1/promotion')
global with sharing class GdPromotionApiControllerV1 {
  private static GdPromotionService promotionService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setPromotionService(GdPromotionService mock) {
    promotionService = mock;
  }

  private static GdPromotionService getPromotionService() {
    if (promotionService == null) {
      promotionService = new GdPromotionServiceImpl();
    }
    return promotionService;
  }

  /**
   * 프로모션 조회
   */
  @HttpGet
  global static void getPromotionList() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdPromotionApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    try {
      Map<String, String> paramMap = req.params;
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      ApiResult result = getPromotionService().getPromotionList(paramMap);

      RestResponseUtil.handleSuccess(result, logger);
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