public with sharing class MceEventResDto {
  public Boolean success;
  public Integer statusCode;
  public String status;
  public String body;
  public String errorCode;
  public String errorMessage;

  public static MceEventResDto fromResponse(HttpResponse res) {
    MceEventResDto r = new MceEventResDto();
    r.statusCode = res.getStatusCode();
    r.status = res.getStatus();
    r.body = res.getBody();
    r.success = (r.statusCode >= 200 && r.statusCode < 300);

    if (!r.success && r.body != null && r.body.trim().startsWith('{')) {
      try {
        Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(r.body);
        if (m.containsKey('errorcode')) {
          r.errorCode = String.valueOf(m.get('errorcode'));
        }
        if (m.containsKey('message')) {
          r.errorMessage = String.valueOf(m.get('message'));
        }
      } catch (Exception ignore) {
      }
    }
    return r;
  }

  public static MceEventResDto fail(Integer statusCode, String errorCode, String errorMessage, String body) {
    MceEventResDto r = new MceEventResDto();
    r.success = false;
    r.statusCode = statusCode;
    r.errorCode = errorCode;
    r.errorMessage = errorMessage;
    r.body = body;
    return r;
  }
}