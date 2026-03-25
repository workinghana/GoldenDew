/**
 * ! 사용 X
 * @author hana
 */
public with sharing class ErpApiUtil {
  @AuraEnabled
  public static void testCallout() {
    HttpRequest req = new HttpRequest();
    req.setMethod('POST');
    req.setEndpoint('https://goldendew.com/services/apexrest/api/utility');

    Http http = new Http();
    HttpResponse res = http.send(req);

    System.debug('Response: ' + res.getBody());
  }

  //Http Method 설정
  public static Map<String, Object> send(String method, String path, Object bodyObj, Map<String, String> extraHeaders) {
    HttpRequest req = buildRequest(method, path, bodyObj, extraHeaders);
    HttpResponse res = sendRequest(req);
    return parseResponse(res);
  }

  //request 생성
  private static HttpRequest buildRequest(String method, String path, Object bodyObj, Map<String, String> extraHeaders) {
    HttpRequest req = new HttpRequest();
    req.setMethod(method);
    req.setEndpoint('https://goldendew.com/services/apexrest/api/utility');
    req.setHeader('Content-Type', 'application/json');

    if (extraHeaders != null) {
      for (String key : extraHeaders.keySet()) {
        req.setHeader(key, extraHeaders.get(key));
      }
    }

    if (bodyObj != null) {
      req.setBody(JSON.serialize(bodyObj));
    }

    return req;
  }

  //예외 처리
  private static HttpResponse sendRequest(HttpRequest req) {
    try {
      Http http = new Http();
      return http.send(req);
    } catch (Exception e) {
      throw new AuraHandledException('ERP 서버 통신 오류: ' + e.getMessage());
    }
  }

  //response 파싱
  private static Map<String, Object> parseResponse(HttpResponse res) {
    Integer code = res.getStatusCode();
    String body = res.getBody();

    try {
      if (code >= 200 && code < 300) {
        Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(body);

        return data;
      }

      System.debug('[ERP ERROR CODE] ' + code);
      System.debug('[ERP ERROR BODY] ' + body);

      throw new AuraHandledException('ERP 응답 오류: ' + code);
    } catch (Exception e) {
      // JSON 형식 오류, NULL pointer 등 모든 예외 처리
      System.debug('[ERP PARSE ERROR] ' + e.getMessage());
      System.debug('[ERP RAW BODY] ' + body);

      throw new AuraHandledException('ERP 응답 파싱 중 오류 발생: ' + e.getMessage());
    }
  }
}