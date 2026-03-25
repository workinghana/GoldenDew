/**
 * ! 사용 X (GdVoucherRedeemApiControllerV1 로 변경)
 * [판매반품, 교환반품] 반품 쿠폰 관련 API 컨트롤러 V1
 */
// @RestResource(urlMapping='/gd/v1/return/coupon')
global with sharing class GdReturnVoucherApiControllerV1 {
  // private static GdVoucherService voucherService;

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setVoucherService(GdVoucherService mock) {
  //   voucherService = mock;
  // }

  // private static GdVoucherService getVoucherService() {
  //   if (voucherService == null)
  //     voucherService = new GdVoucherServiceImpl();
  //   return voucherService;
  // }

  // /**
  //  * [판매반품, 교환반품] 사용한 쿠폰 조회 API
  //  *
  //  * 반품등록 화면용(사용 '한' 쿠폰 조회 내역 활용)
  //  * 부분반품 시 원판매번호 연산 후 조회 필요,
  //  * 원 판매번호에서 사용 한 쿠폰내역 조회 (호출 시 원 판매번호에서 사용한 쿠폰내역이 선 부분반품으로 환불 내역 있는 지 연산 후 전송)
  //  */
  // @HttpGet
  // global static void getReturnUsedCoupon() {
  //   RestRequest req = RestContext.request;
  //   Map<String, Object> resData = new Map<String, Object>();
  //   try {
  //     String originalOrderId = ValidationUtil.stringValidationEx(req.params.get('OriginalOrderId'), 'OriginalOrderId', true, false); // 원 판매 번호

  //     ApiResult result = getVoucherService().getReturnUsedCoupon(originalOrderId);

  //     RestResponseUtil.handleSuccess(result);
  //   } catch (ValidationException ve) {
  //     RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail);
  //   } catch (CustomException ce) {
  //     RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
  //   } catch (Exception e) {
  //     RestResponseUtil.handleException(e, null, 500);
  //   }
  // }
}