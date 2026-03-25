@RestResource(urlMapping='/gd/point')
global with sharing class GdPointApiController {
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
   * [주문,판매] 포인트 적용 도움창 조회 API
   */
  @HttpGet
  global static void getPointList() {
    RestRequest req = RestContext.request;
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData = new Map<String, Object>();
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      Decimal points = getPointService().getPointApplyHelp(reqData);
      resData.put('points', points);

      RestResponseUtil.handleSuccess(ApiResult.ok(200, '포인트 조회 성공', resData));
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500);
    }
  }
}