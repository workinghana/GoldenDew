public class SlackNotifier {
  public class AlertPayload {
    public String memberId;
    public String memberName;
    public String memberNo;
    public Integer count;
    public Integer threshold;
    public String activityType;
    public String riskLevel;
    public String detailMessage;
  }

  @future(callout=true)
  public static void sendAlert(String payloadJson) {
    AlertPayload payload = (AlertPayload) JSON.deserialize(payloadJson, AlertPayload.class);
    sendAlertSync(payload);
  }

  public static Boolean sendAlertSync(AlertPayload payload) {
    try {
      Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
      if (config == null || !config.Is_Active__c) {
        System.debug(LoggingLevel.WARN, '[골든듀 모니터링] Slack 설정이 비활성화 상태입니다.');
        return false;
      }

      HttpRequest req = new HttpRequest();
      req.setEndpoint(config.Webhook_URL__c);
      req.setMethod('POST');
      req.setHeader('Content-Type', 'application/json');
      req.setBody(buildMessage(payload));
      req.setTimeout(10000);

      HttpResponse res = new Http().send(req);
      if (res.getStatusCode() == 200) {
        System.debug('Slack 알림 발송 성공: ' + payload.memberName);
        return true;
      }
      if (res.getStatusCode() == 429) {
        System.debug(LoggingLevel.WARN, 'Slack Rate Limit. Retry-After: ' + res.getHeader('Retry-After') + 's');
        return false;
      }

      System.debug(LoggingLevel.ERROR, 'Slack 발송 실패: ' + res.getStatusCode() + ' / ' + res.getBody());
      return false;
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Slack Callout 오류: ' + e.getMessage() + '\n' + e.getStackTraceString());
      return false;
    }
  }

  private static String buildMessage(AlertPayload payload) {
    if (payload == null) {
      throw new IllegalArgumentException('payload is required.');
    }

    String memberLink = URL.getOrgDomainUrl().toExternalForm() + '/' + payload.memberId;
    String memberText = '<' + memberLink + '|' + String.valueOf(payload.memberName) + '> (`' + String.valueOf(payload.memberNo) + '`)';
    String countText = String.valueOf(payload.count == null ? 0 : payload.count) + '건';
    if (payload.threshold != null && payload.threshold > 0) {
      countText += ' / 기준 ' + String.valueOf(payload.threshold) + '건';
    }

    List<String> lines = new List<String>{
      getRiskEmoji(payload.riskLevel) + ' *회원 활동 모니터링* | *' + getRiskLabel(payload.riskLevel) + '*',
      '*회원* ' + memberText,
      '*유형* ' + getActivityLabel(payload.activityType) + '  |  *발생* ' + countText
    };
    if (String.isNotBlank(payload.detailMessage)) {
      lines.add('*상세* ' + payload.detailMessage);
    }
    lines.add('*시각* ' + DateTime.now().format('yyyy-MM-dd HH:mm'));

    Map<String, Object> message = new Map<String, Object>{
      'text' => '[골든듀 모니터링] 회원 활동 모니터링 대상 안내',
      'blocks' => new List<Object>{
        new Map<String, Object>{
          'type' => 'section',
          'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => String.join(lines, '\n') }
        }
      }
    };
    return JSON.serialize(message);
  }

  private static String getRiskEmoji(String riskLevel) {
    switch on riskLevel {
      when 'High' {
        return ':rotating_light:';
      }
      when 'Medium' {
        return ':warning:';
      }
      when 'Low' {
        return ':information_source:';
      }
      when else {
        return ':grey_question:';
      }
    }
  }

  private static String getRiskLabel(String riskLevel) {
    switch on riskLevel {
      when 'High' {
        return '긴급';
      }
      when 'Medium' {
        return '보통';
      }
      when 'Low' {
        return '낮음';
      }
      when else {
        return '낮음';
      }
    }
  }

  private static String getActivityLabel(String activityType) {
    switch on activityType {
      when 'Order' {
        return '주문';
      }
      when 'Sale' {
        return '판매';
      }
      when 'SaleDelete' {
        return '판매 삭제';
      }
      when 'ReturnCreate' {
        return '반품 등록';
      }
      when 'ReturnDelete' {
        return '반품 삭제';
      }
      when 'Return' {
        return '반품';
      }
      when else {
        return String.valueOf(activityType);
      }
    }
  }
}