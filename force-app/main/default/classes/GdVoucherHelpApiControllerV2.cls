/**
 * 쿠폰 도움창 관련 REST API 컨트롤러
 *
 * @version V2
 * @author Changhwan Kim
 * @since 2026-01-15
 */
@RestResource(urlMapping='/gd/v2/voucher/help')
global with sharing class GdVoucherHelpApiControllerV2 {
  private static GdVoucherService voucherService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  private static GdVoucherService getVoucherService() {
    if (voucherService == null) {
      voucherService = new GdVoucherServiceImpl();
    }
    return voucherService;
  }

  /**
   * [주문,판매] 쿠폰 적용 도움창 조회 API
   * @version V2
   */
  @HttpPost
  global static void getAvailableCouponListV2() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdVoucherHelpApiControllerV2.class.getName());

    RestRequest req = RestContext.request;
    try {
      String body = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      Map<String, Object> raw = JsonRequestParser.parseToMap(body);

      VoucherReqDto.AvailableVoucherRequest reqDto = new VoucherReqDto.AvailableVoucherRequest(raw);

      // 사용 가능한 쿠폰 조회
      ApiResult result = getVoucherService().getAvailableCouponListV2(reqDto);

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