/**
 * 에코포인트 API 컨트롤러
 */
//@RestResource(urlMapping='/gd/ecopoint')
global with sharing class GdEcopointApiController {
  private static GdPointService pointService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setPointService(GdPointService mock) {
    pointService = mock;
  }

  private static GdPointService getPointService() {
    if (pointService == null)
      pointService = new GdPointServiceImpl();
    return pointService;
  }

  /**
   * 에코 포인트 지급
   */
  //@HttpPost
  global static void creditEcopoint() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();

    try {
      String raw = req.requestBody == null ? null : req.requestBody.toString();

      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
        resData = reqData;
      } catch (Exception e) {
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      ApiResult result = getPointService().creditEcopoint(reqData);

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

  /**
   * 에코 포인트 수정
   */
  //   @HttpPatch
  //   global static void updateEcopoint() {
  //     RestRequest req = RestContext.request;
  //     Savepoint sp = Database.setSavepoint();

  //     try {
  //       String raw = req.requestBody == null ? null : req.requestBody.toString();

  //       if (String.isBlank(raw)) {
  //         throw new CustomException(400, '요청 본문이 비었습니다.');
  //       }

  //       Map<String, Object> reqData;
  //       Map<String, Object> resData;
  //       try {
  //         reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
  //         resData = reqData;
  //       } catch (Exception e) {
  //         throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
  //       }

  //       ApiResult result = getPointService().creditPoint(reqData);

  //       RestResponseUtil.handleSuccess(result);
  //       return;
  //     } catch (CustomException ce) {
  //       RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
  //       return;
  //     } catch (Exception e) {
  //       RestResponseUtil.handleException(e, sp, 500);
  //       return;
  //     }
  //   }
}