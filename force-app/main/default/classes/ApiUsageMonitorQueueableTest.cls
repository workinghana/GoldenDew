/**
 * ApiUsageMonitorQueueable 테스트.
 * Slack Webhook 콜아웃은 HttpCalloutMock으로 격리하고,
 * 조직 메타데이터 의존성은 configOverride로 주입하여 결정적으로 검증한다.
 */
@isTest
private class ApiUsageMonitorQueueableTest {
  private static final String TEST_WEBHOOK_URL = 'https://hooks.slack.com/services/TEST/TEST/test';

  private class SlackWebhookMock implements HttpCalloutMock {
    Integer statusCode;
    Integer callCount = 0;
    String lastRequestBody;

    SlackWebhookMock(Integer statusCode) {
      this.statusCode = statusCode;
    }

    public HttpResponse respond(HttpRequest req) {
      callCount++;
      lastRequestBody = req.getBody();
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setBody(statusCode == 200 ? 'ok' : 'error');
      return res;
    }
  }

  private static Slack_Config__mdt activeConfig() {
    return new Slack_Config__mdt(
      DeveloperName = 'API_Usage_Alert',
      Is_Active__c = true,
      Webhook_URL__c = TEST_WEBHOOK_URL
    );
  }

  @isTest
  static void shouldSendSlackMessage_WhenQueueableExecutes() {
    // Given
    ApiUsageMonitorQueueable.configOverride = activeConfig();
    SlackWebhookMock mock = new SlackWebhookMock(200);
    Test.setMock(HttpCalloutMock.class, mock);

    // When
    Test.startTest();
    System.enqueueJob(new ApiUsageMonitorQueueable());
    Test.stopTest();

    // Then
    Assert.areEqual(1, mock.callCount, 'Slack Webhook이 정확히 1회 호출되어야 합니다');
    Assert.isTrue(mock.lastRequestBody.contains('API 사용량'), '메시지에 API 사용량 문구가 포함되어야 합니다');
  }

  @isTest
  static void shouldReturnTrue_WhenSlackReturns200() {
    // Given
    ApiUsageMonitorQueueable.configOverride = activeConfig();
    SlackWebhookMock mock = new SlackWebhookMock(200);
    Test.setMock(HttpCalloutMock.class, mock);

    // When
    Test.startTest();
    Boolean result = ApiUsageMonitorQueueable.notify(100, 1000);
    Test.stopTest();

    // Then
    Assert.isTrue(result, 'Slack 200 응답 시 true를 반환해야 합니다');
    Assert.areEqual(1, mock.callCount, 'Slack Webhook이 정확히 1회 호출되어야 합니다');
  }

  @isTest
  static void shouldReturnFalse_WhenSlackReturnsServerError() {
    // Given
    ApiUsageMonitorQueueable.configOverride = activeConfig();
    SlackWebhookMock mock = new SlackWebhookMock(500);
    Test.setMock(HttpCalloutMock.class, mock);

    // When
    Test.startTest();
    Boolean result = ApiUsageMonitorQueueable.notify(100, 1000);
    Test.stopTest();

    // Then
    Assert.isFalse(result, 'Slack 오류 응답 시 false를 반환해야 합니다');
  }

  @isTest
  static void shouldReturnFalse_WhenConfigInactive() {
    // Given
    Slack_Config__mdt inactiveConfig = activeConfig();
    inactiveConfig.Is_Active__c = false;
    ApiUsageMonitorQueueable.configOverride = inactiveConfig;
    SlackWebhookMock mock = new SlackWebhookMock(200);
    Test.setMock(HttpCalloutMock.class, mock);

    // When
    Test.startTest();
    Boolean result = ApiUsageMonitorQueueable.notify(100, 1000);
    Test.stopTest();

    // Then
    Assert.isFalse(result, '설정 비활성화 시 false를 반환해야 합니다');
    Assert.areEqual(0, mock.callCount, '설정 비활성화 시 콜아웃이 발생하지 않아야 합니다');
  }

  @isTest
  static void shouldUseNormalLevel_WhenUsageBelowWarning() {
    // When
    String message = ApiUsageMonitorQueueable.buildMessage(123, 1000);

    // Then
    Assert.isTrue(message.contains(':bar_chart:'), '70% 미만은 정상 레벨이어야 합니다');
    Assert.isTrue(message.contains('12.3%'), '사용률 12.3%가 표기되어야 합니다');
    Assert.isFalse(message.contains('<!channel>'), '정상 레벨은 채널 멘션이 없어야 합니다');
  }

  @isTest
  static void shouldUseWarningLevel_WhenUsageAtOrOver70() {
    // When
    String message = ApiUsageMonitorQueueable.buildMessage(750, 1000);

    // Then
    Assert.isTrue(message.contains(':warning:'), '70% 이상은 주의 레벨이어야 합니다');
    Assert.isFalse(message.contains('<!channel>'), '주의 레벨은 채널 멘션이 없어야 합니다');
  }

  @isTest
  static void shouldUseCriticalLevelWithChannelMention_WhenUsageAtOrOver90() {
    // When
    String message = ApiUsageMonitorQueueable.buildMessage(950, 1000);

    // Then
    Assert.isTrue(message.contains(':rotating_light:'), '90% 이상은 위험 레벨이어야 합니다');
    Assert.isTrue(message.contains('<!channel>'), '위험 레벨은 채널 멘션이 있어야 합니다');
  }

  @isTest
  static void shouldShowZeroPercent_WhenLimitIsZero() {
    // When
    String message = ApiUsageMonitorQueueable.buildMessage(100, 0);

    // Then
    Assert.isTrue(message.contains('(0%)'), '한도가 0이면 0%로 표기하고 0으로 나누기 오류가 없어야 합니다');
  }
}