/**
 * 포인트 사용에 관한 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-01-08
 */
@RestResource(urlMapping='/gd/v1/point/debit')
global with sharing class GdPointDebitApiControllerV1 {
  private static GdPointService pointService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setPointService(GdPointService mock) {
    pointService = mock;
  }

  private static GdPointService getPointService() {
    if (pointService == null) {
      pointService = new GdPointServiceImpl();
    }
    return pointService;
  }

  /**
   * 사용한 포인트 조회 API
   */
  @HttpGet
  global static void getDebitPointList() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdPointDebitApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Map<String, Object> resData = new Map<String, Object>();
    try {
      Map<String, String> paramMap = req.params;
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      ApiResult result = getPointService().getDebitPointList(paramMap);

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