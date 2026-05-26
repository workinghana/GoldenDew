@IsTest
private class LoyaltyActivityCounterTest {
  private static Integer mockCallCount = 0;
  private static String mockLastMethod;
  private static String mockLastBody;

  private class SlackHttpMock implements HttpCalloutMock {
    private Integer statusCode;

    SlackHttpMock(Integer statusCode) {
      this.statusCode = statusCode;
    }

    public HttpResponse respond(HttpRequest req) {
      mockCallCount++;
      mockLastMethod = req.getMethod();
      mockLastBody = req.getBody();

      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setBody(statusCode == 200 ? 'ok' : 'failed');
      return res;
    }
  }

  private class MemberFixture {
    Id contactId;
    Id memberId;
  }

  private static void resetMockState() {
    mockCallCount = 0;
    mockLastMethod = null;
    mockLastBody = null;
  }

  private static Activity_Threshold__mdt activeThreshold(String activityType) {
    List<Activity_Threshold__mdt> rows = [
      SELECT Activity_Type__c, Daily_Threshold__c, Risk_Level__c
      FROM Activity_Threshold__mdt
      WHERE Is_Active__c = TRUE AND Activity_Type__c = :activityType
      LIMIT 1
    ];
    System.assert(!rows.isEmpty(), 'Active Activity_Threshold__mdt is required for ' + activityType);
    return rows[0];
  }

  private static MemberFixture createActiveMember(String suffix) {
    Contact con = new Contact(LastName = 'Activity Counter ' + suffix, MemberNo__c = 'LAC-' + suffix);
    insert con;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Loyalty Activity Counter ' + suffix, IsPrimary = false);
    insert lp;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      MembershipNumber = 'LAC-' + suffix,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = con.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert member;

    MemberFixture f = new MemberFixture();
    f.contactId = con.Id;
    f.memberId = member.Id;
    return f;
  }

  private static String payload(String activityType, Id contactId) {
    return JSON.serialize(new Map<String, List<String>>{ activityType => new List<String>{ String.valueOf(contactId) } });
  }

  private static Boolean hasActiveSlackConfig() {
    Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
    return config != null && config.Is_Active__c == true && String.isNotBlank(config.Webhook_URL__c);
  }

  @IsTest
  static void processMonitoringAsync_blankPayload_doesNothing() {
    Test.startTest();
    LoyaltyActivityCounter.processMonitoringAsync(null);
    LoyaltyActivityCounter.processMonitoringAsync('');
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM LoyaltyProgramMember WHERE MembershipNumber LIKE 'LAC-BLANK%']);
  }

  @IsTest
  static void processMonitoringAsync_unknownThreshold_leavesMemberUnchanged() {
    MemberFixture f = createActiveMember('NO-THRESHOLD');

    Test.startTest();
    LoyaltyActivityCounter.processMonitoringAsync(payload('NoSuchActivityType', f.contactId));
    Test.stopTest();

    LoyaltyProgramMember member = [
      SELECT Last_Activity_Date__c, Daily_Activity_Count__c, Last_Alert_Date__c
      FROM LoyaltyProgramMember
      WHERE Id = :f.memberId
    ];
    System.assertEquals(null, member.Last_Activity_Date__c);
    System.assertEquals(0, Integer.valueOf(member.Daily_Activity_Count__c));
    System.assertEquals(null, member.Last_Alert_Date__c);
  }

  @IsTest
  static void processMonitoringAsync_belowThreshold_updatesDailyCountOnly() {
    Activity_Threshold__mdt threshold = activeThreshold('Order');
    MemberFixture f = createActiveMember('BELOW');

    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200));

    Test.startTest();
    LoyaltyActivityCounter.processMonitoringAsync(payload(threshold.Activity_Type__c, f.contactId));
    Test.stopTest();

    LoyaltyProgramMember member = [
      SELECT Last_Activity_Date__c, Daily_Activity_Count__c, Last_Alert_Date__c
      FROM LoyaltyProgramMember
      WHERE Id = :f.memberId
    ];
    System.assertEquals(Date.today(), member.Last_Activity_Date__c);
    System.assertEquals(1, Integer.valueOf(member.Daily_Activity_Count__c));
    System.assertEquals(null, member.Last_Alert_Date__c);
    System.assertEquals(0, mockCallCount);
  }

  @IsTest
  static void processMonitoringAsync_thresholdReached_sendsSlackAndStoresAlertDate() {
    Activity_Threshold__mdt threshold = activeThreshold('Return');
    MemberFixture f = createActiveMember('ALERT-SUCCESS');
    Integer startingCount = Integer.valueOf(threshold.Daily_Threshold__c) - 1;

    update new LoyaltyProgramMember(
      Id = f.memberId,
      Last_Activity_Date__c = Date.today(),
      Daily_Activity_Count__c = startingCount
    );

    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200));

    Test.startTest();
    LoyaltyActivityCounter.processMonitoringAsync(payload(threshold.Activity_Type__c, f.contactId));
    Test.stopTest();

    LoyaltyProgramMember member = [
      SELECT Last_Activity_Date__c, Daily_Activity_Count__c, Last_Alert_Date__c
      FROM LoyaltyProgramMember
      WHERE Id = :f.memberId
    ];
    System.assertEquals(Date.today(), member.Last_Activity_Date__c);
    System.assertEquals(Integer.valueOf(threshold.Daily_Threshold__c), Integer.valueOf(member.Daily_Activity_Count__c));

    if (hasActiveSlackConfig()) {
      System.assertEquals(Date.today(), member.Last_Alert_Date__c);
      System.assertEquals(1, mockCallCount);
      System.assertEquals('POST', mockLastMethod);
      System.assert(mockLastBody.contains('Activity Counter ALERT-SUCCESS'));
    } else {
      System.assertEquals(null, member.Last_Alert_Date__c);
      System.assertEquals(0, mockCallCount);
    }
  }

  @IsTest
  static void processMonitoringAsync_immediateSaleDelete_sendsSlackWithoutThresholdMetadata() {
    MemberFixture f = createActiveMember('SALE-DELETE-IMMEDIATE');

    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200));

    Test.startTest();
    LoyaltyActivityCounter.processMonitoringAsync(payload('SaleDelete', f.contactId));
    Test.stopTest();

    LoyaltyProgramMember member = [
      SELECT Last_Activity_Date__c, Daily_Activity_Count__c, Last_Alert_Date__c
      FROM LoyaltyProgramMember
      WHERE Id = :f.memberId
    ];
    System.assertEquals(Date.today(), member.Last_Activity_Date__c);
    System.assertEquals(1, Integer.valueOf(member.Daily_Activity_Count__c));
    System.assertEquals(null, member.Last_Alert_Date__c, 'Immediate alerts must not suppress later threshold alerts.');

    if (hasActiveSlackConfig()) {
      System.assertEquals(1, mockCallCount);
      System.assert(mockLastBody.contains('판매 삭제'));
      System.assert(mockLastBody.contains('보통'));
    } else {
      System.assertEquals(0, mockCallCount);
    }
  }

  @IsTest
  static void processMonitoringAsync_allImmediateTypes_sendSlackAndCountActivities() {
    MemberFixture f = createActiveMember('ALL-IMMEDIATE');

    String payloadJson = JSON.serialize(
      new Map<String, List<String>>{
        'SaleDelete' => new List<String>{ String.valueOf(f.contactId) },
        'ReturnCreate' => new List<String>{ String.valueOf(f.contactId) },
        'ReturnDelete' => new List<String>{ String.valueOf(f.contactId) }
      }
    );

    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200));

    Test.startTest();
    LoyaltyActivityCounter.processMonitoringAsync(payloadJson);
    Test.stopTest();

    LoyaltyProgramMember member = [
      SELECT Last_Activity_Date__c, Daily_Activity_Count__c, Last_Alert_Date__c
      FROM LoyaltyProgramMember
      WHERE Id = :f.memberId
    ];
    System.assertEquals(Date.today(), member.Last_Activity_Date__c);
    System.assertEquals(3, Integer.valueOf(member.Daily_Activity_Count__c));
    System.assertEquals(null, member.Last_Alert_Date__c);

    if (hasActiveSlackConfig()) {
      System.assertEquals(3, mockCallCount);
    } else {
      System.assertEquals(0, mockCallCount);
    }
  }

  @IsTest
  static void processMonitoringAsync_slackFailure_rollsBackOnlyAlertDate() {
    Activity_Threshold__mdt threshold = activeThreshold('Sale');
    MemberFixture f = createActiveMember('ALERT-FAILURE');
    Integer startingCount = Integer.valueOf(threshold.Daily_Threshold__c) - 1;

    update new LoyaltyProgramMember(
      Id = f.memberId,
      Last_Activity_Date__c = Date.today(),
      Daily_Activity_Count__c = startingCount
    );

    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(500));

    Test.startTest();
    LoyaltyActivityCounter.processMonitoringAsync(payload(threshold.Activity_Type__c, f.contactId));
    Test.stopTest();

    LoyaltyProgramMember member = [
      SELECT Last_Activity_Date__c, Daily_Activity_Count__c, Last_Alert_Date__c
      FROM LoyaltyProgramMember
      WHERE Id = :f.memberId
    ];
    System.assertEquals(Date.today(), member.Last_Activity_Date__c);
    System.assertEquals(Integer.valueOf(threshold.Daily_Threshold__c), Integer.valueOf(member.Daily_Activity_Count__c));
    System.assertEquals(null, member.Last_Alert_Date__c);

    if (hasActiveSlackConfig()) {
      System.assertEquals(1, mockCallCount);
    } else {
      System.assertEquals(0, mockCallCount);
    }
  }

  @IsTest
  static void processMonitoringAsync_alreadyAlertedToday_doesNotSendSlackAgain() {
    Activity_Threshold__mdt threshold = activeThreshold('Order');
    MemberFixture f = createActiveMember('ALREADY-ALERTED');

    update new LoyaltyProgramMember(
      Id = f.memberId,
      Last_Activity_Date__c = Date.today(),
      Daily_Activity_Count__c = Integer.valueOf(threshold.Daily_Threshold__c),
      Last_Alert_Date__c = Date.today()
    );

    resetMockState();
    Test.setMock(HttpCalloutMock.class, new SlackHttpMock(200));

    Test.startTest();
    LoyaltyActivityCounter.processMonitoringAsync(payload(threshold.Activity_Type__c, f.contactId));
    Test.stopTest();

    LoyaltyProgramMember member = [
      SELECT Daily_Activity_Count__c, Last_Alert_Date__c
      FROM LoyaltyProgramMember
      WHERE Id = :f.memberId
    ];
    System.assertEquals(Integer.valueOf(threshold.Daily_Threshold__c) + 1, Integer.valueOf(member.Daily_Activity_Count__c));
    System.assertEquals(Date.today(), member.Last_Alert_Date__c);
    System.assertEquals(0, mockCallCount);
  }

  private static String activityLabel(String activityType) {
    if (activityType == 'Order') {
      return '주문';
    }
    if (activityType == 'Sale') {
      return '판매';
    }
    if (activityType == 'Return') {
      return '반품';
    }
    return activityType;
  }
}