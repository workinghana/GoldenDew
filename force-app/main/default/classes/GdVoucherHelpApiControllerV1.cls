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
    try {
      RestRequest req = RestContext.request;

      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // 사용 가능한 쿠폰 조회
      ApiResult result = getVoucherService().getAvailableCouponList(reqData);

      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500);
    }
  }
}