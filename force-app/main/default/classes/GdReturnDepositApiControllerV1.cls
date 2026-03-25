/**
 *  반품 입금 관련 API 컨트롤러
 */
@RestResource(urlMapping='/gd/v1/return/deposit')
global with sharing class GdReturnDepositApiControllerV1 {
  private static GdReturnDepositService returnDepositService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setReturnDepositService(GdReturnDepositService mock) {
    returnDepositService = mock;
  }

  private static GdReturnDepositService getReturnDepositService() {
    if (returnDepositService == null) {
      returnDepositService = new GdReturnDepositServiceImpl();
    }
    return returnDepositService;
  }

  /**
   * [판매반품, 교환반품] 입금 삭제
   */
  @HttpDelete
  global static void deleteReturnDeposit() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdReturnDepositApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now()); // 요청 시간

      String depositNo = ValidationUtil.stringValidationEx(req.params.get('DepositNo__c'), 'DepositNo__c', true, false); // 입금 번호
      String deposiSeqNo = ValidationUtil.stringValidationEx(req.params.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true, false); // 입금 일련 번호

      depositNo += '-' + deposiSeqNo;

      ApiResult saleDepositResult = getReturnDepositService().deleteReturnDeposit(depositNo);

      RestResponseUtil.handleSuccess(saleDepositResult, logger);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog(); // 개별 로그 저장
      ApexLogger.insertLogs(); // 실제 DB에 로그 인서트
    }
    return;
  }
}