/**
 * 조직의 지난 24시간 API 요청 사용량(DailyApiRequests)을 조회하여
 * Slack Webhook으로 발송하는 Queueable.
 *
 * 매시간 ApiUsageMonitorScheduler가 enqueue하며, 사용률에 따라
 * 정상(📊)/주의(⚠️ 70%)/위험(🚨 90% + 채널 멘션) 레벨로 메시지를 구성한다.
 * Webhook URL과 활성화 여부는 Slack_Config__mdt 'API_Usage_Alert' 레코드로 제어한다.
 */
public with sharing class ApiUsageMonitorQueueable implements Queueable, Database.AllowsCallouts {
  @TestVisible
  private static final String LIMIT_NAME = 'DailyApiRequests';
  @TestVisible
  private static final String CONFIG_DEV_NAME = 'API_Usage_Alert';
  @TestVisible
  private static final Decimal WARNING_THRESHOLD_PERCENT = 70;
  @TestVisible
  private static final Decimal CRITICAL_THRESHOLD_PERCENT = 90;
  private static final Integer CALLOUT_TIMEOUT_MS = 10000;

  /** 테스트에서 조직 메타데이터 대신 주입하는 설정 (운영 코드에서는 항상 null) */
  @TestVisible
  private static Slack_Config__mdt configOverride;

  /**
   * API 사용량을 조회하고 Slack 알림을 발송한다.
   *
   * @param context Queueable 실행 컨텍스트
   */
  public void execute(QueueableContext context) {
    try {
      System.OrgLimit apiLimit = OrgLimits.getMap().get(LIMIT_NAME);
      if (apiLimit == null) {
        System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] OrgLimit을 찾을 수 없습니다: ' + LIMIT_NAME);
        return;
      }
      notify(apiLimit.getValue(), apiLimit.getLimit());
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] API 사용량 알림 실패: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
  }

  /**
   * 사용량/한도를 받아 Slack 메시지를 구성하고 발송한다.
   *
   * @param used 지난 24시간 API 요청 수
   * @param maxAllowed 24시간 API 요청 한도
   * @return 발송 성공 여부
   */
  @TestVisible
  private static Boolean notify(Integer used, Integer maxAllowed) {
    Slack_Config__mdt config = configOverride != null ? configOverride : Slack_Config__mdt.getInstance(CONFIG_DEV_NAME);
    if (config == null || !config.Is_Active__c) {
      System.debug(LoggingLevel.WARN, '[골든듀 모니터링] API_Usage_Alert Slack 설정이 비활성화 상태입니다.');
      return false;
    }

    HttpRequest req = new HttpRequest();
    req.setEndpoint(config.Webhook_URL__c);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(buildMessage(used, maxAllowed));
    req.setTimeout(CALLOUT_TIMEOUT_MS);

    HttpResponse res = new Http().send(req);
    if (res.getStatusCode() == 200) {
      return true;
    }
    System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] Slack 발송 실패: ' + res.getStatusCode() + ' / ' + res.getBody());
    return false;
  }

  /**
   * 사용률 레벨에 따른 Slack Block Kit 메시지 JSON을 생성한다.
   *
   * @param used 지난 24시간 API 요청 수
   * @param maxAllowed 24시간 API 요청 한도
   * @return Slack Webhook 요청 본문 JSON
   */
  @TestVisible
  private static String buildMessage(Integer used, Integer maxAllowed) {
    Decimal percent = maxAllowed == null || maxAllowed == 0
      ? 0
      : ((Decimal) used / maxAllowed * 100).setScale(1);

    String headline;
    if (percent >= CRITICAL_THRESHOLD_PERCENT) {
      headline = '<!channel> :rotating_light: *API 사용량 모니터링* | *위험*';
    } else if (percent >= WARNING_THRESHOLD_PERCENT) {
      headline = ':warning: *API 사용량 모니터링* | *주의*';
    } else {
      headline = ':bar_chart: *API 사용량 모니터링* | *정상*';
    }

    List<String> lines = new List<String>{
      headline,
      '*지난 24시간* ' + used.format() + ' / ' + maxAllowed.format() + '건 (' + String.valueOf(percent) + '%)',
      '*시각* ' + DateTime.now().format('yyyy-MM-dd HH:mm')
    };

    Map<String, Object> message = new Map<String, Object>{
      'text' => '[골든듀 모니터링] API 사용량 (' + String.valueOf(percent) + '%)',
      'blocks' => new List<Object>{
        new Map<String, Object>{
          'type' => 'section',
          'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => String.join(lines, '\n') }
        }
      }
    };
    return JSON.serialize(message);
  }
}