// ! 사용 X
@RestResource(urlMapping='/gd/point/award')
global with sharing class GdPointAwardApiController {
  private static GdPointService pointService;

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

  @HttpPost
  global static void rewardPoints() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();

    try {
      // JSON Raw
      String raw = req.requestBody == null ? null : req.requestBody.toString();
      System.debug(raw);

      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      // JSON → List<Object>
      // List<Object> jsonList;
      // try {
      //     jsonList = (List<Object>) JSON.deserializeUntyped(raw);
      // } catch (Exception e) {
      //     throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      // }

      // List<Object> → List<Map<String,Object>>
      // List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      // for (Object o : jsonList) {
      //     reqList.add((Map<String, Object>) o);
      // }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      System.debug('reqData = ' + reqData);

      // 서비스 호출
      // List<LoyaltyManagement.CreditPointsOutput> results =
      //     LoyaltyPointService.creditPoints(reqList);

      // 성공 응답
      // ApiResult result = ApiResult.ok(200, '포인트 지급 성공', null);
      // RestResponseUtil.handleSuccess(result);
      // return;

      //Impl 호출
      ApiResult result = getPointService().creditPoint(reqData);
      RestResponseUtil.handleSuccess(result);
      return;
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
      return;
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
      return;
    }
  }
}