public with sharing class RestResponseUtil {
  /**
   * 정상 RestResponse
   * + Logger 추가
   */
  public static void handleSuccess(ApiResult result, ApexLogger logger) {
    RestResponse res = RestContext.response;
    res.statusCode = result.code ?? 200;
    res.responseBody = Blob.valueOf(JSON.serializePretty(result));
    res.addHeader('Content-Type', 'application/json');

    // 정상 처리시 로그
    logger.setResponseDatetime(Datetime.now());
    logger.setStatus('SUCCESS');
    logger.setHttpStatusCode(String.valueOf(res.statusCode));
    if (res.responseBody != null) {
      logger.setResponseBody(res.responseBody.toString());
    }
  }

  /**
   * 정상 RestResponse
   */
  public static void handleSuccess(ApiResult result) {
    RestResponse res = RestContext.response;
    res.statusCode = result.code ?? 200;
    res.responseBody = Blob.valueOf(JSON.serializePretty(result, true));
    res.addHeader('Content-Type', 'application/json');
  }

  /**
   * catch => Exception 일 때 RestResponse 처리
   */
  public static void handleException(Exception e, Savepoint sp, Integer statusCode) {
    if (sp != null) {
      Database.rollback(sp);
    }

    // 1. 로그 저장
    String endpoint = RestContext.request.httpMethod + ' ' + RestContext.request.requestURI;
    ErrorUtil.createApiError(endpoint, e.getStackTraceString().split('\n')[0], e.getMessage(), statusCode);

    // 2. 응답 구성
    RestResponse res = RestContext.response;
    res.statusCode = statusCode;

    ApiResult result = ApiResult.fail(statusCode, e.getMessage().replace('"', '\\"'));
    res.responseBody = Blob.valueOf(JSON.serializePretty(result, true));
    res.addHeader('Content-Type', 'application/json');
  }

  /**
   * catch => Exception 일 때 RestResponse 처리
   * + Logger 추가
   */
  public static void handleException(Exception e, Savepoint sp, Integer statusCode, ApexLogger logger) {
    if (sp != null) {
      Database.rollback(sp);
    }

    // 응답 구성
    RestResponse res = RestContext.response;
    res.statusCode = statusCode;

    ApiResult result = ApiResult.fail(statusCode, e.getMessage().replace('"', '\\"'));
    res.responseBody = Blob.valueOf(JSON.serializePretty(result, true));
    res.addHeader('Content-Type', 'application/json');

    // 로그 저장
    logger.setResponseDatetime(Datetime.now());
    logger.setStatus('ERROR');
    logger.setErrorCode('EXCEPTION');
    logger.setErrorMessage(e.getMessage());
    logger.setStackTrace(e.getStackTraceString().split('\n')[0]);
    logger.setResponseDatetime(Datetime.now());
    logger.setHttpStatusCode(String.valueOf(res.statusCode));
    if (res.responseBody != null) {
      logger.setResponseBody(res.responseBody.toString());
    }
  }

  /**
   * catch => CustomException 일 때 RestResponse 처리
   */
  public static void handleCustomException(Exception e, Savepoint sp, Integer statusCode, String message) {
    if (sp != null) {
      Database.rollback(sp);
    }

    // 1. 로그 저장
    String endpoint = RestContext.request.httpMethod + ' ' + RestContext.request.requestURI;
    ErrorUtil.createApiError(endpoint, e.getStackTraceString().split('\n')[0], message, statusCode);

    // 2. 응답 구성
    RestResponse res = RestContext.response;
    res.statusCode = statusCode;

    ApiResult result = ApiResult.fail(statusCode, message.replace('"', '\\"'));
    res.responseBody = Blob.valueOf(JSON.serializePretty(result, true));
    res.addHeader('Content-Type', 'application/json');
  }

  /**
   * catch => CustomException 일 때 RestResponse 처리
   * + Logger 추가
   */
  public static void handleCustomException(Exception e, Savepoint sp, Integer statusCode, String message, ApexLogger logger) {
    if (sp != null) {
      Database.rollback(sp);
    }

    // 2. 응답 구성
    RestResponse res = RestContext.response;
    res.statusCode = statusCode;

    ApiResult result = ApiResult.fail(statusCode, message.replace('"', '\\"'));
    res.responseBody = Blob.valueOf(JSON.serializePretty(result, true));
    res.addHeader('Content-Type', 'application/json');

    // 로그 저장
    logger.setResponseDatetime(Datetime.now());
    logger.setStatus('ERROR');
    logger.setErrorCode('CUSTOM_EXCEPTION');
    logger.setErrorMessage(message);
    logger.setStackTrace(e.getStackTraceString().split('\n')[0]);
    logger.setResponseDatetime(Datetime.now());
    logger.setHttpStatusCode(String.valueOf(res.statusCode));
    if (res.responseBody != null) {
      logger.setResponseBody(res.responseBody.toString());
    }
  }
}