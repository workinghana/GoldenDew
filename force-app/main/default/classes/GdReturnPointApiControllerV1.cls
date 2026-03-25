/**
 * ! 사용 X (GdPointDebitApiControllerV1 로 변경)
 * [판매반품, 교환반품] 반품 포인트 관련 API 컨트롤러 V1
 */
// @RestResource(urlMapping='/gd/v1/return/point')
global with sharing class GdReturnPointApiControllerV1 {
  // private static GdPointService pointService;

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setPointService(GdPointService mock) {
  //   pointService = mock;
  // }

  // private static GdPointService getPointService() {
  //   if (pointService == null)
  //     pointService = new GdPointServiceImpl();
  //   return pointService;
  // }

  /**
   * ! 사용 X
   * [판매반품, 교환반품] 사용한 포인트 조회 API
   *
   * 반품등록 화면용(사용 '한' 포인트 조회 내역 활용)
   * 부분반품 시 원판매번호 연산 후 조회 필요,
   * 원 판매번호에서 사용 한 쿠폰내역 조회
   * (호출 시 원 판매번호에서 사용한 포인트내역이 선 부분반품으로 환불 내역 있는 지 연산 후 전송)
   */
  // @HttpGet
  // global static void getReturnUsedPoint() {
  //   RestRequest req = RestContext.request;
  //   Map<String, Object> resData = new Map<String, Object>();
  //   try {
  //     String originalOrderId = ValidationUtil.stringValidationEx(req.params.get('OriginalOrderId'), 'OriginalOrderId', true, false); // 원 판매 번호
  //     System.debug('originalOrderId : ' + originalOrderId);

  //     ApiResult result = getPointService().getReturnUsedPoint(originalOrderId);

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