public class SlackNotifier {
  public class AlertPayload {
    public String memberId; // 회원 360 Id
    public String memberName; // 회원 이름
    public String memberNo; // 회원 번호
    public Integer count;
    public Integer threshold;
    public String activityType;
    public String riskLevel;
  }

  /**
   * 비동기 진입점 (일반 컨텍스트에서 호출용)
   */
  @future(callout=true)
  public static void sendAlert(String payloadJson) {
    AlertPayload payload = (AlertPayload) JSON.deserialize(payloadJson, AlertPayload.class);
    sendAlertSync(payload);
  }

  /**
   * 동기 메서드 - 이미 비동기 컨텍스트에서 호출용
   * @return 발송 성공 여부 (true: 성공, false: 실패)
   */
  public static Boolean sendAlertSync(AlertPayload payload) {
    try {
      Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
      if (config == null || !config.Is_Active__c) {
        System.debug(LoggingLevel.WARN, '[골든듀 모니터링] Slack 설정이 비활성화 상태입니다.');
        return false;
      }

      String body = buildMessage(payload);

      HttpRequest req = new HttpRequest();
      req.setEndpoint(config.Webhook_URL__c);
      req.setMethod('POST');
      req.setHeader('Content-Type', 'application/json');
      req.setBody(body);
      req.setTimeout(10000);

      HttpResponse res = new Http().send(req);

      if (res.getStatusCode() == 200) {
        System.debug('✅ Slack 알림 발송 성공: ' + payload.memberName);
        return true; // ✅ 성공
      } else if (res.getStatusCode() == 429) {
        String retryAfter = res.getHeader('Retry-After');
        System.debug(LoggingLevel.WARN, '⚠️ Slack Rate Limit. Retry-After: ' + retryAfter + 's');
        return false; // ❌ 실패 (재시도 대상)
      } else {
        System.debug(LoggingLevel.ERROR, '❌ Slack 발송 실패: ' + res.getStatusCode() + ' / ' + res.getBody());
        return false; // ❌ 실패
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, '❌ Slack Callout 오류: ' + e.getMessage() + '\n' + e.getStackTraceString());
      return false; // ❌ 실패
    }
  }

  /**
   * Slack Block Kit 형식의 메시지 본문 생성
   */
  private static String buildMessage(AlertPayload p) {
    // ... 기존 코드 그대로 ...
    String orgUrl = URL.getOrgDomainUrl().toExternalForm();
    String memberLink = orgUrl + '/' + p.memberId;
    String emoji = getRiskEmoji(p.riskLevel);

    Map<String, Object> msg = new Map<String, Object>{
      'text' => '[골든듀 모니터링] 회원 활동 모니터링 대상 안내',
      'blocks' => new List<Object>{
        new Map<String, Object>{
          'type' => 'header',
          'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => emoji + ' 회원 활동 모니터링 대상 안내' }
        },
        new Map<String, Object>{
          'type' => 'section',
          'fields' => new List<Object>{
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원명:*\n<' + memberLink + '|' + p.memberName + '>' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원번호:*\n' + p.memberNo },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*활동 유형:*\n' + p.activityType },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*오늘 발생 횟수:*\n' + p.count + '회' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*기준 횟수:*\n' + p.threshold + '회' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*모니터링 등급:*\n' + p.riskLevel },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*발생 시각:*\n' + DateTime.now().format('yyyy-MM-dd HH:mm') }
          }
        },
        new Map<String, Object>{
          'type' => 'actions',
          'elements' => new List<Object>{
            new Map<String, Object>{
              'type' => 'button',
              'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => '회원 상세 보기' },
              'url' => memberLink,
              'style' => 'primary'
            }
          }
        }
      }
    };

    return JSON.serialize(msg);
  }

  private static String getRiskEmoji(String riskLevel) {
    switch on riskLevel {
      when 'High' {
        return '🔴';
      }
      when 'Medium' {
        return '🟡';
      }
      when 'Low' {
        return '🟢';
      }
      when else {
        return '🔔';
      }
    }
  }
}