// ! 이관 대상
@RestResource(urlMapping='/gd/member/help-info')
global with sharing class GdMemberHelpInfoController {
  private static GdMemberHelpInfoService memberHelpInfoService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setMemberHelpInfoService(GdMemberHelpInfoService service) {
    memberHelpInfoService = service;
  }

  private static GdMemberHelpInfoService getMemberHelpInfoService() {
    if (memberHelpInfoService == null) {
      memberHelpInfoService = new GdMemberHelpInfoServiceImpl();
    }
    return memberHelpInfoService;
  }

  //회원도움창조회
  @HttpPost
  global static void getMemberHelpInfo() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    res.addHeader('Content-Type', 'application/json');

    Savepoint sp = Database.setSavepoint();

    try {
      Map<String, Object> reqData = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

      ApiResult result = getMemberHelpInfoService().getMemberHelpInfo(reqData);

      res.statusCode = 200;
      res.responseBody = Blob.valueOf(JSON.serialize(result));
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }
}