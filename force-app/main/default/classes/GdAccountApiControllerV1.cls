/**
 * 매장 및 회사 관련 API 컨트롤러
 */
@RestResource(urlMapping='/gd/v1/account')
global with sharing class GdAccountApiControllerV1 {
  private static GdAccountService accountService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setAccountService(GdAccountService mock) {
    accountService = mock;
  }

  private static GdAccountService getAccountService() {
    if (accountService == null) {
      accountService = new GdAccountServiceImpl();
    }
    return accountService;
  }

  /**
   * 매장 및 회사 등록
   * Account create
   */
  @HttpPost
  global static void createAccount() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdAccountApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용
      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Account 생성
      ApiResult result = getAccountService().createAccount(reqData);

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

  /**
   * 매장 및 회사 수정
   * Account update
   */
  @HttpPatch
  global static void updateAccount() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdAccountApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      logger.setRequestUrl(req.requestURI); // 요청 URL
      logger.setRequestDatetime(Datetime.now()); // 요청 시간
      logger.setRequestBody(raw); // 요청 본문 내용
      if (String.isBlank(raw)) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('Empty body');
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        logger.setErrorCode('BAD_REQUEST');
        logger.setErrorMessage('JSON 역직렬화 실패: ' + e.getMessage());
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Account update
      ApiResult result = getAccountService().updateAccount(reqData);

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

  /**
   * 매장 및 회사 삭제
   * Account delete
   */
  @HttpDelete
  global static void deleteAccount() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdAccountApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();

    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now());

      String isCompanyRaw = req.params.get('isCompany');
      Boolean isCompany = null;

      if (isCompanyRaw != null) {
        String lower = isCompanyRaw.trim().toLowerCase();

        if (lower == 'true') {
          isCompany = true;
        } else if (lower == 'false') {
          isCompany = false;
        } else {
          throw new ValidationException('deleteAccount()', 'isCompany 값은 true 또는 false 여야 합니다.');
        }
      }

      String companyCode = ValidationUtil.stringValidationEx(req.params.get('CompanyCode__c'), 'CompanyCode__c', true, false);

      String storeCode = ValidationUtil.stringValidationEx(req.params.get('StoreCode__c'), 'StoreCode__c', false, false);

      Map<String, Object> reqData = new Map<String, Object>{ 'isCompany' => isCompany, 'CompanyCode__c' => companyCode, 'StoreCode__c' => storeCode };

      ApiResult result = getAccountService().deleteAccount(reqData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }
}