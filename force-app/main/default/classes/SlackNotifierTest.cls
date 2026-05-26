@IsTest
private class SlackNotifierTest {
  private static Integer mockCallCount = 0;
  private static String mockLastEndpoint;
  private static String mockLastMethod;
  private static String mockLastContentType;
  private static String mockLastBody;

  private class SlackHttpMock implements HttpCalloutMock {
    private Integer statusCode;
    private String responseBody;
    private String retryAfter;

    SlackHttpMock(Integer statusCode, String responseBody) {
      this(statusCode, responseBody, null);
    }

    SlackHttpMock(Integer statusCode, String responseBody, String retryAfter) {
      this.statusCode = statusCode;
      this.responseBody = responseBody;
      this.retryAfter = retryAfter;
    }

    public HttpResponse respond(HttpRequest req) {
      mockCallCount++;
      mockLastEndpoint = req.getEndpoint();
      mockLastMethod = req.getMethod();
      mockLastContentType = req.getHeader('Content-Type');
      mockLastBody = req.getBody();

      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setBody(responseBody);
      if (retryAfter != null) {
        res.setHeader('Retry-After', retryAfter);
      }
      return res;
    }
  }

  private static SlackNotifier.AlertPayload payload(String riskLevel) {
    SlackNotifier.AlertPayload p = new SlackNotifier.AlertPayload();
    p.memberId = UserInfo.getUserId();
    p.memberName = 'Slack Test Member';
    p.count = 11;
    p.threshold = 10;
    p.activityType = 'Login';
    p.riskLevel = riskLevel;
    return p;
  }

  private static SlackNotifier.AlertPayload payload(String riskLevel, String activityType) {
    SlackNotifier.AlertPayload p = payload(riskLevel);
    p.activityType = activityType;
    p.threshold = null;
    return p;
  }

  private static Boolean hasActiveConfig() {
    Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
    return config != null && config.Is_Active__c == true && String.isNotBlank(config.Webhook_URL__c);
  }

  private static void resetMockState() {
    mockCallCount = 0;
    mockLastEndpoint = null;
    mockLastMethod = null;
    mockLastContentType = null;
    mockLastBody = null;
  }

  @IsTest
  static void sendAlertSync_success_postsSlackPayloadWhenConfigActive() {
    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200, 'ok'));

    Test.startTest();
    Boolean result = SlackNotifier.sendAlertSync(payload('High'));
    Test.stopTest();

    if (hasActiveConfig()) {
      System.assertEquals(true, result);
      System.assertEquals(1, mockCallCount);
      System.assertEquals('POST', mockLastMethod);
      System.assertEquals('application/json', mockLastContentType);
      System.assert(mockLastEndpoint.startsWith('https://'));
      System.assert(mockLastBody.contains('Slack Test Member'));
      System.assert(mockLastBody.contains('Login'));
    } else {
      System.assertEquals(false, result);
      System.assertEquals(0, mockCallCount);
    }
  }

  @IsTest
  static void sendAlertSync_immediateReturnCreateUsesMediumLabel() {
    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200, 'ok'));

    Test.startTest();
    Boolean result = SlackNotifier.sendAlertSync(payload('Medium', 'ReturnCreate'));
    Test.stopTest();

    if (hasActiveConfig()) {
      System.assertEquals(true, result);
      System.assertEquals(1, mockCallCount);
      System.assert(mockLastBody.contains('반품 등록'));
      System.assert(mockLastBody.contains('보통'));
      System.assert(!mockLastBody.contains('기준'), 'Immediate alert must not render threshold text.');
    } else {
      System.assertEquals(false, result);
      System.assertEquals(0, mockCallCount);
    }
  }

  @IsTest
  static void sendAlertSync_rateLimitedReturnsFalse() {
    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(429, 'rate limited', '30'));

    Boolean result = SlackNotifier.sendAlertSync(payload('Medium'));

    System.assertEquals(false, result);
    if (hasActiveConfig()) {
      System.assertEquals(1, mockCallCount);
    }
  }

  @IsTest
  static void sendAlertSync_serverErrorReturnsFalse() {
    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(500, 'server error'));

    Boolean result = SlackNotifier.sendAlertSync(payload('Low'));

    System.assertEquals(false, result);
    if (hasActiveConfig()) {
      System.assertEquals(1, mockCallCount);
    }
  }

  @IsTest
  static void sendAlertSync_nullPayloadReturnsFalseFromCatch() {
    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200, 'ok'));

    Boolean result = SlackNotifier.sendAlertSync(null);

    System.assertEquals(false, result);
  }

  @IsTest
  static void sendAlert_futureSendsPayload() {
    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200, 'ok'));

    Test.startTest();
    SlackNotifier.sendAlert(JSON.serialize(payload('Unknown')));
    Test.stopTest();

    if (hasActiveConfig()) {
      System.assertEquals(1, mockCallCount);
      System.assertEquals('POST', mockLastMethod);
      System.assert(mockLastBody.contains('Slack Test Member'));
    } else {
      System.assertEquals(0, mockCallCount);
    }
  }
}