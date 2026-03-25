/**
 * @author Changhwan Kim
 * @since 2026-01-15
 */
public class ErpAsyncCallbackPublisher implements ErpAsyncCallback {
  private static final Integer LONG_TEXT_MAX = 131072;
  private static final Integer TEXT_MAX = 255;

  public void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto) {
    // TODO: Platform Event로 발행
    System.debug('[ERP ASYNC SUCCESS] ' + apiName + ' res=' + JSON.serialize(responseDto));
  }

  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId) {
    ErpAsyncFailure__e evt = new ErpAsyncFailure__e();
    evt.ApiName__c = apiName;
    String req = safeSerialize(requestDto);
    evt.RequestData__c = (req == null) ? null : req.left(Math.min(req.length(), LONG_TEXT_MAX));
    evt.ResponseData__c = (httpError.responseBody == null)
      ? null
      : httpError.responseBody.left(Math.min(httpError.responseBody.length(), LONG_TEXT_MAX));
    evt.TargetRecordId__c = recordId;
    evt.ErrorMessage__c = (httpError.responseBody == null)
      ? null
      : extractMessage(httpError.responseBody).left(Math.min(httpError.responseBody.length(), TEXT_MAX));

    Database.SaveResult sr = EventBus.publish(evt);
    if (sr == null || !sr.isSuccess()) {
      // 이벤트 발행 실패는 별도 로깅 정도만 (무한 루프 방지)
      System.debug('[ERP FAILURE EVENT PUBLISH FAILED] ' + getFirstError(sr));
    }
    System.debug('플랫폼 이벤트 발행 성공');
  }

  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId, SObject o) {
    System.debug('onFailure 진입 1');
    ErpAsyncFailure__e evt = new ErpAsyncFailure__e();
    evt.ApiName__c = apiName;
    String req = safeSerialize(requestDto);
    evt.RequestData__c = (req == null) ? null : req.left(Math.min(req.length(), LONG_TEXT_MAX));
    evt.ResponseData__c = (httpError.responseBody == null)
      ? null
      : httpError.responseBody.left(Math.min(httpError.responseBody.length(), LONG_TEXT_MAX));
    evt.TargetRecordId__c = recordId;
    evt.ErrorMessage__c = (httpError.responseBody == null)
      ? null
      : extractMessage(httpError.responseBody).left(Math.min(httpError.responseBody.length(), TEXT_MAX));

    System.debug('apiName : ' + apiName);
    System.debug('safeSerialize(requestDto) : ' + safeSerialize(requestDto));
    System.debug('req : ' + req);
    System.debug('recordId : ' + recordId);
    System.debug('extractMessage(httpError.responseBody) : ' + extractMessage(httpError.responseBody));

    Database.SaveResult sr = EventBus.publish(evt);
    if (sr == null || !sr.isSuccess()) {
      // 이벤트 발행 실패는 별도 로깅 정도만 (무한 루프 방지)
      System.debug('[ERP FAILURE EVENT PUBLISH FAILED] ' + getFirstError(sr));
    }
    System.debug('플랫폼 이벤트 발행 성공');
  }

  public void onFailure(String apiName, Object requestDto, String errorMessage, String stackTrace) {
    // System.debug('onFailure 진입 2');
    // ErpAsyncFailure__e evt = new ErpAsyncFailure__e();
    // evt.ApiName__c = apiName;
    // // evt.RequestData__c = safeSerialize(requestDto);
    // // evt.ResponseData__c = httpError.responseBody;
    // evt.TargetRecordId__c = recordId;
    // evt.ErrorMessage__c = errorMessage;
    // // evt.ErrorMessage__c = extractMessage(httpError.responseBody);

    // Database.SaveResult sr = EventBus.publish(evt);
    // if (sr == null || !sr.isSuccess()) {
    //   // 이벤트 발행 실패는 별도 로깅 정도만 (무한 루프 방지)
    //   System.debug('[ERP FAILURE EVENT PUBLISH FAILED] ' + getFirstError(sr));
    // }
    // System.debug('플랫폼 이벤트 발행 성공');
  }

  public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {
    System.debug('onFailure 진입 3');
    ErpAsyncFailure__e evt = new ErpAsyncFailure__e();
    evt.ApiName__c = apiName;
    String req = safeSerialize(requestDto);
    evt.RequestData__c = (req == null) ? null : req.left(Math.min(req.length(), LONG_TEXT_MAX));
    // evt.ResponseData__c = httpError.responseBody;
    evt.TargetRecordId__c = recordId;
    // evt.ErrorMessage__c = errorMessage;
    evt.ErrorMessage__c = (errorMessage == null) ? null : errorMessage.left(Math.min(errorMessage.length(), LONG_TEXT_MAX));

    Database.SaveResult sr = EventBus.publish(evt);
    if (sr == null || !sr.isSuccess()) {
      // 이벤트 발행 실패는 별도 로깅 정도만 (무한 루프 방지)
      System.debug('[ERP FAILURE EVENT PUBLISH FAILED] ' + getFirstError(sr));
    }
    System.debug('플랫폼 이벤트 발행 성공');
  }

  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) {
    ErpAsyncFailure__e evt = new ErpAsyncFailure__e();
    evt.ApiName__c = apiName;
    String req = safeSerialize(requestDto);
    evt.RequestData__c = (req == null) ? null : req.left(Math.min(req.length(), LONG_TEXT_MAX));
    evt.ResponseData__c = (httpError.responseBody == null)
      ? null
      : httpError.responseBody.left(Math.min(httpError.responseBody.length(), LONG_TEXT_MAX));
    evt.TargetRecordId__c = new List<Id>(recordIds)[0];
    evt.ErrorMessage__c = (httpError.responseBody == null)
      ? null
      : extractMessage(httpError.responseBody).left(Math.min(httpError.responseBody.length(), TEXT_MAX));

    Database.SaveResult sr = EventBus.publish(evt);
    if (sr == null || !sr.isSuccess()) {
      // 이벤트 발행 실패는 별도 로깅 정도만 (무한 루프 방지)
      System.debug('[ERP FAILURE EVENT PUBLISH FAILED] ' + getFirstError(sr));
    }
    System.debug('플랫폼 이벤트 발행 성공');
  }
  public void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds) {
    // List<LoyaltyMemberCurrency> lmc
  }
  public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {
  }

  // ---------- helpers ----------
  private String safeSerialize(Object obj) {
    if (obj == null) {
      return null;
    }
    try {
      return JSON.serialize(obj);
    } catch (Exception e) {
      return '{"serializeError":"' + escapeJson(e.getMessage()) + '"}';
    }
  }

  private static String getFirstError(Database.SaveResult sr) {
    if (sr == null) {
      return 'SaveResult is null';
    }
    if (sr.getErrors() == null || sr.getErrors().isEmpty()) {
      return 'Unknown publish error';
    }
    Database.Error e = sr.getErrors()[0];
    return String.valueOf(e.getStatusCode()) + ': ' + e.getMessage();
  }

  private static String escapeJson(String s) {
    if (s == null) {
      return '';
    }
    // 최소 escape (필요 시 확장)
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r');
  }

  private static String extractMessage(String responseBody) {
    if (String.isBlank(responseBody)) {
      return null;
    }

    try {
      Object obj = JSON.deserializeUntyped(responseBody);

      if (obj instanceof Map<String, Object>) {
        Map<String, Object> m = (Map<String, Object>) obj;
        Object msg = m.get('message');
        if (msg != null) {
          return String.valueOf(msg);
        }
      }
    } catch (Exception e) {
      // JSON 파싱 실패 시 원문 그대로 사용
      return responseBody;
    }

    return responseBody; // 최후의 안전망
  }

  private static String truncateForLongText(String s, String label) {
    if (s == null) {
      return null;
    }

    // prefix로 "잘림 여부/원본 길이"를 남김 (운영 시 유용)
    String prefix = '[' + label + '] len=' + s.length();
    // prefix + 구분자까지 고려
    String header = prefix + ' | ';

    Integer maxBody = LONG_TEXT_MAX - header.length();
    if (maxBody < 0) {
      // 극단 케이스(거의 없음): header 자체가 길면 그냥 강제 cut
      return prefix.left(LONG_TEXT_MAX);
    }

    if (s.length() <= maxBody) {
      return header + s;
    }

    // 잘라서 저장
    return header + s.left(maxBody);
  }

  @TestVisible
  static String testExtractMessage(String body) {
    return extractMessage(body);
  }

  @TestVisible
  static String testEscapeJson(String s) {
    return escapeJson(s);
  }

  @TestVisible
  static String testTruncateForLongText(String s, String label) {
    return truncateForLongText(s, label);
  }

  @TestVisible
  String testSafeSerialize(Object o) {
    return safeSerialize(o);
  }
}