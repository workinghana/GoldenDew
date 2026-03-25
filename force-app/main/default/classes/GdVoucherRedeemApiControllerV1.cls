/**
 * 쿠폰 사용에 관한 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-01-08
 */
@RestResource(urlMapping='/gd/v1/voucher/redeem')
global with sharing class GdVoucherRedeemApiControllerV1 {
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
   * 사용한 쿠폰 조회 API
   */
  @HttpGet
  global static void getRedeemCoupon() {
    RestRequest req = RestContext.request;
    Map<String, Object> resData = new Map<String, Object>();
    try {
      Map<String, String> paramMap = req.params;

      ApiResult result = getVoucherService().getRedeemCoupon(paramMap);

      RestResponseUtil.handleSuccess(result);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500);
    }
  }
}