public without sharing class LoyaltyPointInstantValidator {
  public class ValidationResult {
    public Id memberId;
    public String memberNo;
    public String memberName;
    public Decimal lmcBalance;
    public Decimal calculatedBalance;
    public Decimal difference;
    public Integer negativeAggrLedgerCount = 0;
    public Decimal negativeAggrAvailablePoints = 0;
    public List<Id> negativeAggrLedgerIds = new List<Id>();
    public Boolean isValid;
    public String summary;
  }

  public static ValidationResult validateByMemberNo(String memberNo) {
    if (String.isBlank(memberNo)) {
      throw new IllegalArgumentException('memberNo is required.');
    }

    List<LoyaltyProgramMember> members = [
      SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
      FROM LoyaltyProgramMember
      WHERE Contact.MemberNo__c = :memberNo AND MemberStatus = 'Active'
      LIMIT 1
    ];

    if (members.isEmpty()) {
      ValidationResult result = new ValidationResult();
      result.memberNo = memberNo;
      result.lmcBalance = 0;
      result.calculatedBalance = 0;
      result.difference = 0;
      result.isValid = false;
      result.summary = 'Active LoyaltyProgramMember not found.';
      return result;
    }

    return validateMember(members[0]);
  }

  public static List<ValidationResult> validateByContactIds(Set<Id> contactIds) {
    List<ValidationResult> results = new List<ValidationResult>();
    if (contactIds == null || contactIds.isEmpty()) {
      return results;
    }

    for (LoyaltyProgramMember member : [
      SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
      FROM LoyaltyProgramMember
      WHERE ContactId IN :contactIds AND MemberStatus = 'Active'
    ]) {
      results.add(validateMember(member));
    }

    return results;
  }

  public static Boolean validateAndAlertByMemberNo(String memberNo) {
    ValidationResult result = validateByMemberNo(memberNo);
    if (result.isValid == true) {
      return true;
    }
    return sendValidationAlert(result);
  }

  public static ValidationResult validateNegativeAggrByMemberNo(String memberNo) {
    return validateByMemberNo(memberNo);
  }

  public static Boolean validateAndAlertNegativeAggrByMemberNo(String memberNo) {
    ValidationResult result = validateByMemberNo(memberNo);
    if (result.negativeAggrLedgerCount == null || result.negativeAggrLedgerCount == 0) {
      return true;
    }
    return sendValidationAlert(result);
  }

  @future(callout=true)
  public static void validateAndAlertByContactIdsAsync(String contactIdsJson) {
    if (String.isBlank(contactIdsJson)) {
      return;
    }

    List<Object> rawIds = (List<Object>) JSON.deserializeUntyped(contactIdsJson);
    Set<Id> contactIds = new Set<Id>();
    for (Object rawId : rawIds) {
      if (rawId != null) {
        contactIds.add((Id) String.valueOf(rawId));
      }
    }

    for (ValidationResult result : validateByContactIds(contactIds)) {
      if (result.isValid != true) {
        sendValidationAlert(result);
      }
    }
  }

  private static ValidationResult validateMember(LoyaltyProgramMember member) {
    ValidationResult result = new ValidationResult();
    result.memberId = member.Id;
    result.memberNo = member.Contact == null ? member.MembershipNumber : member.Contact.MemberNo__c;
    result.memberName = getMemberName(member);

    result.lmcBalance = queryLmcBalance(member.Id);
    result.calculatedBalance = queryAvailableLedgerBalance(member.Id);
    result.difference = result.calculatedBalance - result.lmcBalance;
    applyNegativeAggrValidation(result);
    finalizeResult(result);
    return result;
  }

  private static Decimal queryLmcBalance(Id memberId) {
    List<LoyaltyMemberCurrency> rows = [
      SELECT PointsBalance
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :memberId
      LIMIT 1
    ];
    if (rows.isEmpty() || rows[0].PointsBalance == null) {
      return 0;
    }
    return rows[0].PointsBalance;
  }

  private static Decimal queryAvailableLedgerBalance(Id memberId) {
    Decimal balance = 0;
    for (AggregateResult row : [
      SELECT EventType eventType, SUM(Points) total
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
      GROUP BY EventType
    ]) {
      String eventType = (String) row.get('eventType');
      Decimal points = (Decimal) row.get('total');
      if (points == null) {
        continue;
      }

      Decimal amount = points.abs();
      if (eventType == 'Credit' || eventType == 'DebitCancellation') {
        balance += amount;
      } else if (eventType == 'Debit' || eventType == 'CreditCancellation' || eventType == 'Expiry') {
        balance -= amount;
      }
    }
    return balance;
  }

  private static void applyNegativeAggrValidation(ValidationResult result) {
    if (result == null || result.memberId == null) {
      return;
    }

    for (AggregateResult row : [
      SELECT COUNT(Id) cnt, SUM(AvailablePoints__c) total
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :result.memberId AND AvailablePoints__c < 0
    ]) {
      result.negativeAggrLedgerCount = (Integer) row.get('cnt');
      result.negativeAggrAvailablePoints = row.get('total') == null ? 0 : (Decimal) row.get('total');
    }

    if (result.negativeAggrLedgerCount == null || result.negativeAggrLedgerCount == 0) {
      return;
    }

    for (LoyaltyAggrSubPointExprLedger__c aggr : [
      SELECT Id
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :result.memberId AND AvailablePoints__c < 0
      ORDER BY AvailablePoints__c ASC
      LIMIT 20
    ]) {
      result.negativeAggrLedgerIds.add(aggr.Id);
    }
  }

  private static void finalizeResult(ValidationResult result) {
    Boolean balanceValid = result.difference == 0;
    Boolean aggrValid = result.negativeAggrLedgerCount == null || result.negativeAggrLedgerCount == 0;
    result.isValid = balanceValid && aggrValid;

    if (result.isValid) {
      result.summary = '포인트 즉시 검증 정상';
      return;
    }

    List<String> messages = new List<String>();
    if (!balanceValid) {
      messages.add(
        'LMC/LL 불일치: LMC=' +
          formatPoint(result.lmcBalance) +
          'P, 계산=' +
          formatPoint(result.calculatedBalance) +
          'P, 차이=' +
          formatPoint(result.difference) +
          'P'
      );
    }
    if (!aggrValid) {
      messages.add(
        '집계 음수 원장 발견: 건수=' +
          String.valueOf(result.negativeAggrLedgerCount) +
          ', 음수 합계=' +
          formatPoint(result.negativeAggrAvailablePoints) +
          'P, 샘플=' +
          JSON.serialize(result.negativeAggrLedgerIds)
      );
    }
    result.summary = String.join(messages, ' / ');
  }

  private static Boolean sendValidationAlert(ValidationResult result) {
    Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
    if (config == null || !config.Is_Active__c || String.isBlank(config.Webhook_URL__c)) {
      System.debug(LoggingLevel.WARN, '[포인트 즉시 검증] Slack 설정이 비활성화되어 알림을 보내지 않습니다. ' + result.summary);
      return false;
    }

    HttpRequest req = new HttpRequest();
    req.setEndpoint(config.Webhook_URL__c);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(buildSlackBody(result));
    req.setTimeout(10000);

    HttpResponse res = new Http().send(req);
    Boolean success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
    if (!success) {
      System.debug(LoggingLevel.ERROR, '[포인트 즉시 검증] Slack 발송 실패: ' + res.getStatusCode() + ' / ' + res.getBody());
    }
    return success;
  }

  private static String buildSlackBody(ValidationResult result) {
    String orgUrl = URL.getOrgDomainUrl().toExternalForm();
    String memberLink = result.memberId == null ? '' : orgUrl + '/' + result.memberId;
    String memberTitle = String.isBlank(memberLink)
      ? String.valueOf(result.memberName)
      : '<' + memberLink + '|' + result.memberName + '>';

    Map<String, Object> msg = new Map<String, Object>{
      'text' => '[골든듀 모니터링] 포인트 즉시 검증 불일치',
      'blocks' => new List<Object>{
        new Map<String, Object>{
          'type' => 'header',
          'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => '포인트 즉시 검증 불일치' }
        },
        new Map<String, Object>{
          'type' => 'section',
          'fields' => new List<Object>{
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원:*\n' + memberTitle },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원번호:*\n' + String.valueOf(result.memberNo) },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*LMC 잔액:*\n' + formatPoint(result.lmcBalance) + 'P' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*LL 계산 잔액:*\n' + formatPoint(result.calculatedBalance) + 'P' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*차이:*\n' + formatPoint(result.difference) + 'P' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*음수 집계 건수:*\n' + String.valueOf(result.negativeAggrLedgerCount) },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*음수 집계 합계:*\n' + formatPoint(result.negativeAggrAvailablePoints) + 'P' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*검증 시각:*\n' + Datetime.now().format('yyyy-MM-dd HH:mm') }
          }
        },
        new Map<String, Object>{
          'type' => 'section',
          'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*요약:*\n' + result.summary }
        }
      }
    };

    return JSON.serialize(msg);
  }

  private static String getMemberName(LoyaltyProgramMember member) {
    if (member.Contact != null && String.isNotBlank(member.Contact.Name)) {
      return member.Contact.Name;
    }
    if (member.Account != null && String.isNotBlank(member.Account.Name)) {
      return member.Account.Name;
    }
    return member.MembershipNumber != null ? member.MembershipNumber : '(이름 없음)';
  }

  private static String formatPoint(Decimal value) {
    return String.valueOf(value == null ? 0 : value.setScale(0));
  }
}