@RestResource(urlMapping='/gd/v1/member/help-info')
global with sharing class GdMemberHelpInfoApiControllerV1 {
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

  /**
   * 회원 도움창 조회
   */
  @HttpGet
  global static void getMemberHelpInfo() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdMemberHelpInfoApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    res.addHeader('Content-Type', 'application/json');

    Savepoint sp = Database.setSavepoint();

    try {
      Map<String, Object> reqData = new Map<String, Object>();
      String memberNo = req.params.get('MemberNo__c');

      if (String.isBlank(memberNo)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('MemberNo__c parameter is required.');
        throw new CustomException(400, 'MemberNo__c parameter is required.');
      }

      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      reqData.put('MemberNo__c', memberNo);

      ApiResult result = getMemberHelpInfoService().getMemberHelpInfo(reqData);

      // res.statusCode = 200;
      // res.responseBody = Blob.valueOf(JSON.serialize(result));
      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
  }
}