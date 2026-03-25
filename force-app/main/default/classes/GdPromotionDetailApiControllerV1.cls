/**
 * 프로모션 상세 관련 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-01-08
 */
@RestResource(urlMapping='/gd/v1/promotion/detail')
global with sharing class GdPromotionDetailApiControllerV1 {
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
   * 프로모션 상세 조회
   */
  @HttpGet
  global static void getPromotionDetail() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdPromotionDetailApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      String promotionNo = ValidationUtil.stringValidationEx(req.params.get('PromotionNo__c'), 'PromotionNo__c', true, false);

      ApiResult result = getPromotionService().getPromotionDetail(promotionNo);

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