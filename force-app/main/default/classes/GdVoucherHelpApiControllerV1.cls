@RestResource(urlMapping='/gd/v1/voucher/help')
global with sharing class GdVoucherHelpApiControllerV1 {
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
   * [주문,판매] 쿠폰 도움창 조회 API
   */
  @HttpPost
  global static void getAvailableCouponList() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdVoucherHelpApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    try {
      String body = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(body); // 요청 본문 내용

      // String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      // if (String.isBlank(raw)) {
      //   throw new CustomException(400, '요청 본문이 비었습니다.');
      // }
      if (String.isBlank(body)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;

      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(body);
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Map<String, Object> raw = JsonRequestParser.parseToMap(body);

      // try {
      //   reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      // } catch (Exception e) {
      //   throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      // }

      // 사용 가능한 쿠폰 조회
      ApiResult result = getVoucherService().getAvailableCouponList(reqData);

      RestResponseUtil.handleSuccess(result, logger);
      // RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message, logger);
      // RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500, logger);
      // RestResponseUtil.handleException(e, null, 500);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }
}