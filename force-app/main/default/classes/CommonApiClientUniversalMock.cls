public with sharing class CommonApiClientUniversalMock implements HttpCalloutMock {
  private static Integer hitRetry = 0;
  private static Integer hit401 = 0;

  public static void reset() {
    hitRetry = 0;
    hit401 = 0;
  }

  public HttpResponse respond(HttpRequest req) {
    String ep = req.getEndpoint();
    HttpResponse res = new HttpResponse();

    // timeout 유도
    if (ep != null && ep.contains('/timeout')) {
      throw new System.CalloutException('timeout');
    }

    // 500 -> 200 (재시도)
    if (ep != null && ep.contains('/retry')) {
      hitRetry++;
      if (hitRetry == 1) {
        res.setStatusCode(500);
        res.setStatus('Internal Server Error');
        res.setBody('error');
        return res;
      }
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"ok":true}');
      return res;
    }

    // 401 -> 200 (토큰 갱신 분기)
    if (ep != null && ep.contains('/secure')) {
      hit401++;
      if (hit401 == 1) {
        res.setStatusCode(401);
        res.setStatus('Unauthorized');
        res.setBody('unauthorized');
        return res;
      }
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"ok":true}');
      return res;
    }

    // 400
    if (ep != null && ep.contains('/bad')) {
      res.setStatusCode(400);
      res.setStatus('Bad Request');
      res.setBody('bad');
      return res;
    }

    // invalid json
    if (ep != null && ep.contains('/json-error')) {
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{invalid json}');
      return res;
    }

    // 429 (재시도 대상)
    if (ep != null && ep.contains('/rate-limit')) {
      res.setStatusCode(429);
      res.setStatus('Too Many Requests');
      res.setBody('rate limit');
      return res;
    }

    // 204 No Content (바디 없음 성공)
    if (ep != null && ep.contains('/no-content')) {
      res.setStatusCode(204);
      res.setStatus('No Content');
      res.setBody('');
      return res;
    }

    // default 200
    res.setStatusCode(200);
    res.setStatus('OK');
    res.setHeader('Content-Type', 'application/json');
    res.setBody('{"ok":true}');
    return res;
  }
}