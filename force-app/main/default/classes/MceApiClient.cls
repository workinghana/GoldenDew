public with sharing class MceApiClient {
  @TestVisible
  private static String namedCredential = 'MarketingCloudApiNC';
  @TestVisible
  private static Integer timeoutMs = 60000;

  public class MceApiException extends Exception {
  }

  public class CalloutResult {
    public Integer statusCode;
    public String status;
    public String responseBody;
    public String errorType; // CALLOUT_EXCEPTION | EXCEPTION | HTTP_ERROR
    public String errorMessage;
    public Boolean isSuccess;

    public CalloutResult() {
    }
  }

  public static CalloutResult sendInteractionEvent(MceEventReqDto reqDto) {
    if (reqDto == null) {
      throw new MceApiException('Request DTO is null.');
    }
    return sendJson('POST', '/interaction/v1/events', reqDto.toMap(), null);
  }

  public static CalloutResult sendJson(String method, String path, Object bodyObj, Map<String, String> queryParams) {
    if (String.isBlank(method)) {
      throw new MceApiException('HTTP method is blank.');
    }
    if (String.isBlank(path)) {
      throw new MceApiException('Path is blank.');
    }
    if (!path.startsWith('/')) {
      path = '/' + path;
    }

    String httpMethod = method.toUpperCase();
    String endpoint = buildEndpoint(path, queryParams);

    HttpRequest req = new HttpRequest();
    req.setEndpoint(endpoint);
    req.setMethod(httpMethod);
    req.setHeader('Content-Type', 'application/json');
    req.setTimeout(timeoutMs);

    if (bodyObj != null && httpMethod != 'GET') {
      req.setBody(JSON.serialize(bodyObj));
    }

    CalloutResult out = new CalloutResult();

    try {
      HttpResponse res = new Http().send(req);

      out.statusCode = res.getStatusCode();
      out.status = res.getStatus();
      out.responseBody = res.getBody();

      if (out.statusCode != null && out.statusCode >= 200 && out.statusCode < 300) {
        out.isSuccess = true;
      } else {
        out.isSuccess = false;
        out.errorType = 'HTTP_ERROR';
        out.errorMessage = out.status;
      }

      return out;
    } catch (System.CalloutException ce) {
      out.isSuccess = false;
      out.errorType = 'CALLOUT_EXCEPTION';
      out.errorMessage = ce.getMessage();
      return out;
    } catch (Exception e) {
      out.isSuccess = false;
      out.errorType = 'EXCEPTION';
      out.errorMessage = e.getMessage();
      return out;
    }
  }

  private static String buildEndpoint(String path, Map<String, String> queryParams) {
    String endpoint = 'callout:' + namedCredential + path;
    if (queryParams == null || queryParams.isEmpty()) {
      return endpoint;
    }

    List<String> pairs = new List<String>();
    for (String k : queryParams.keySet()) {
      if (String.isBlank(k)) {
        continue;
      }
      String v = queryParams.get(k);
      pairs.add(EncodingUtil.urlEncode(k, 'UTF-8') + '=' + EncodingUtil.urlEncode(v == null ? '' : v, 'UTF-8'));
    }
    return endpoint + '?' + String.join(pairs, '&');
  }
}