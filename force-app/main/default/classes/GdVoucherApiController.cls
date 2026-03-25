@RestResource(urlMapping='/gd/voucher')
global with sharing class GdVoucherApiController {
  private static GdVoucherDefinitionService voucherDefinitionService;
  private static GdVoucherService voucherService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherDefinitionService(GdVoucherDefinitionService mock) {
    voucherDefinitionService = mock;
  }

  private static GdVoucherDefinitionService getVoucherDefinitionService() {
    if (voucherDefinitionService == null)
      voucherDefinitionService = new GdVoucherDefinitionServiceImpl();
    return voucherDefinitionService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  private static GdVoucherService getVoucherService() {
    if (voucherService == null)
      voucherService = new GdVoucherServiceImpl();
    return voucherService;
  }

  /**
   * ! 보류
   * 쿠폰 마스터 등록
   * VoucherDefinition 생성
   */
  @HttpPost
  global static void createVoucherDefinition() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
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

      // VoucherDefinition 생성
      ApiResult result = getVoucherDefinitionService().createVoucherDefinition(reqData);

      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }

  /**
   * ! 개발중
   * 사용 가능한 쿠폰 조회
   */
  @HttpGet
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