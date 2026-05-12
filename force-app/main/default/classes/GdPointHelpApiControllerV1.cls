/**
 * 사용
 * 포인트 도움창 관련 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-01-12
 */
@RestResource(urlMapping='/gd/v1/point/help')
global with sharing class GdPointHelpApiControllerV1 {
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
   * * 사용 중
   * [주문,판매] 포인트 적용 도움창 조회 API
   */
  @HttpPost
  global static void getPointList() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdPointHelpApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    logger.setMethod(String.isBlank(req.httpMethod) ? 'POST' : req.httpMethod);
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용

      if (String.isBlank(raw)) {
        // 에러 로그 설정
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      Map<String, Object> resData = new Map<String, Object>();
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        // 에러 로그 설정
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Decimal points = getPointService().getPointApplyHelp(reqData);
      // resData.put('points', points);
      ApiResult result = getPointService().getPointApplyHelp(reqData);

      // ApiResult result = new ApiResult(true, 200, '포인트 도움창 조회 성공', resData);

      RestResponseUtil.handleSuccess(result, logger);
      // RestResponseUtil.handleSuccess(ApiResult.ok(200, '포인트 조회 성공', resData));
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }

  /**
   * * 사용 중
   * 회원 포인트 총 금액 조회
   */
  @HttpGet
  global static void getTotalMemberPoints() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdMemberHelpInfoApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    logger.setMethod(String.isBlank(req.httpMethod) ? 'GET' : req.httpMethod);
    res.addHeader('Content-Type', 'application/json');

    // Savepoint sp = Database.setSavepoint();

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

      Map<String, Object> data = new Map<String, Object>();

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      List<AggregateResult> totalPointResult = [
        SELECT SUM(AvailablePoints__c) totalPointsBalance
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE AvailablePoints__c > 0 AND ExpiryDate__c >= :Date.today() AND LoyaltyProgramMemberId__c = :lpmList[0].Id
      ];

      Decimal totalPointsBalance = 0;
      if (!totalPointResult.isEmpty() && totalPointResult[0].get('totalPointsBalance') != null) {
        totalPointsBalance = (Decimal) totalPointResult[0].get('totalPointsBalance');
      }
      data.put('TotalPointsBalance', totalPointsBalance);

      ApiResult result = ApiResult.ok(200, '회원 포인트 총합 조회 성공', data);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, null, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, null, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
  }
}