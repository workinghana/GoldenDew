@RestResource(urlMapping='/gd/v1/voucher')
global with sharing class GdVoucherApiControllerV1 {
  private static GdVoucherDefinitionService voucherDefinitionService;
  private static GdVoucherService voucherService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherDefinitionService(GdVoucherDefinitionService mock) {
    voucherDefinitionService = mock;
  }

  private static GdVoucherDefinitionService getVoucherDefinitionService() {
    if (voucherDefinitionService == null) {
      voucherDefinitionService = new GdVoucherDefinitionServiceImpl();
    }
    return voucherDefinitionService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  private static GdVoucherService getVoucherService() {
    if (voucherService == null) {
      voucherService = new GdVoucherServiceImpl();
    }
    return voucherService;
  }

  /**
   * ! 사용 X
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

  /**
   * 쿠폰 개별 지급
   */
  @HttpPost
  global static void issueSingleVoucher() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdVoucherApiControllerV1.class.getName());

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

      ApiResult result = getVoucherService().issueCoupon(reqData);

      RestResponseUtil.handleSuccess(result, logger);
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

  /**
   * ! 사용 X
   * 쿠폰 개별 삭제
   */
  @HttpDelete
  global static void deleteSingleVoucher() {
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

      ApiResult result = getVoucherService().deleteCoupon(reqData);
      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }

  /**
   * 쿠폰 개별 수정
   */
  @HttpPatch
  global static void updateSingleVoucher() {
    // 로그 객체 생성 (JobType: API)
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdVoucherApiControllerV1.class.getName());

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

      ApiResult result = getVoucherService().updateCoupon(reqData);

      RestResponseUtil.handleSuccess(result, logger);
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