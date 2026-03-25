@IsTest(SeeAllData=true)
private class MceCampaignTargetSendHistoryFetchJobTest {
  private class RowsetMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;

    RowsetMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setHeader('Content-Type', 'application/json');
      res.setBody(body);
      return res;
    }
  }

  private static void assertQueueableCompleted(Id jobId) {
    System.assertNotEquals(null, jobId);

    AsyncApexJob job = [
      SELECT Id, Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
      LIMIT 1
    ];

    System.assertEquals('Completed', job.Status);
    System.assertEquals(0, job.NumberOfErrors);
  }

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  private static LoyaltyProgram getLabelProgram() {
    return [
      SELECT Id, Name
      FROM LoyaltyProgram
      WHERE Name = :System.Label.LoyaltyProgramName
      LIMIT 1
    ];
  }

  private static LoyaltyProgramMember createLpmBackedByIdMemberNo() {
    Contact c = new Contact(LastName = uniq('MCContact'));
    insert c;

    c.MemberNo__c = String.valueOf(c.Id);
    update c;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = getLabelProgram().Id,
      MembershipNumber = uniq('MCLPM'),
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert lpm;
    return lpm;
  }

  private static Contact createContactOnlyBackedByIdMemberNo() {
    Contact c = new Contact(LastName = uniq('NoLpmContact'));
    insert c;

    c.MemberNo__c = String.valueOf(c.Id);
    update c;
    return c;
  }

  private static String makeItem(String contactKey, String pk, String campName, String sentDate, String channel1, String channel2) {
    String valuesJson = '"values":{';
    if (pk != null) {
      valuesJson += '"pk":"' + pk + '"';
      if (channel1 != null || channel2 != null) {
        valuesJson += ',';
      }
    }
    if (channel1 != null) {
      valuesJson += '"channel1_f_code":"' + channel1 + '"';
      if (channel2 != null) {
        valuesJson += ',';
      }
    }
    if (channel2 != null) {
      valuesJson += '"channel2_f_code":"' + channel2 + '"';
    }
    valuesJson += '}';

    return '{' +
      '"keys":{' +
      '"contactkey":"' +
      contactKey +
      '",' +
      '"camp_name":"' +
      campName +
      '",' +
      '"camp_dtl_name":"Dtl ' +
      campName +
      '",' +
      '"journey_id":"JRN-' +
      campName +
      '",' +
      '"activity_id":"ACT-' +
      campName +
      '"' +
      (sentDate == null ? '' : ',"sentdate":"' + sentDate + '"') +
      '},' +
      valuesJson +
      '}';
  }

  @IsTest
  static void execute_whenRowsetEmpty_succeeds() {
    ApexLogger.disableLogging();
    Test.setMock(HttpCalloutMock.class, new RowsetMock(200, '{"items":[]}'));

    Test.startTest();
    Id jobId = System.enqueueJob(new MceCampaignTargetSendHistoryFetchJob(Date.newInstance(2026, 3, 1), 1));
    Test.stopTest();

    assertQueueableCompleted(jobId);
  }

  @IsTest
  static void execute_whenApiReturnsError_handlesGracefully() {
    ApexLogger.disableLogging();
    Test.setMock(HttpCalloutMock.class, new RowsetMock(500, '{"message":"internal error"}'));

    Test.startTest();
    Id jobId = System.enqueueJob(new MceCampaignTargetSendHistoryFetchJob(null, 0));
    Test.stopTest();

    assertQueueableCompleted(jobId);
  }

  @IsTest
  static void execute_whenItemsMixed_insertsAndHandlesFailures() {
    ApexLogger.disableLogging();

    LoyaltyProgramMember lpm = createLpmBackedByIdMemberNo();
    Contact noLpmContact = createContactOnlyBackedByIdMemberNo();

    String body =
      '{' +
      '"items":[' +
      makeItem(String.valueOf(lpm.ContactId), 'PK-VALID-1', 'CampA', '1/14/2026 9:52:40 AM', 'F1', 'F2') +
      ',' +
      makeItem(String.valueOf(noLpmContact.Id), 'PK-NO-LPM', 'CampB', null, 'F3', null) +
      ',' +
      makeItem(String.valueOf(lpm.ContactId), null, 'CampC', null, 'F4', null) +
      ']' +
      '}';

    Test.setMock(HttpCalloutMock.class, new RowsetMock(200, body));

    Test.startTest();
    Id jobId = System.enqueueJob(new MceCampaignTargetSendHistoryFetchJob(Date.newInstance(2026, 3, 1), 1));
    Test.stopTest();

    assertQueueableCompleted(jobId);

    Integer inserted = [
      SELECT COUNT()
      FROM TransactionJournal
      WHERE MemberId = :lpm.Id AND UsageType__c = 'Campaign' AND CS_CAMP_NAME__c = 'CampA'
    ];
    System.assert(inserted >= 0);
  }

  @IsTest
  static void execute_whenJsonIsInvalid_hitsOuterCatch() {
    ApexLogger.disableLogging();
    Test.setMock(HttpCalloutMock.class, new RowsetMock(200, '{"items":['));

    Test.startTest();
    Id jobId = System.enqueueJob(new MceCampaignTargetSendHistoryFetchJob(Date.newInstance(2026, 3, 2), 2));
    Test.stopTest();

    assertQueueableCompleted(jobId);
  }

  @IsTest
  static void execute_whenPageIsFull_enqueuesNextPage() {
    ApexLogger.disableLogging();

    LoyaltyProgramMember lpm = createLpmBackedByIdMemberNo();
    List<String> items = new List<String>();
    for (Integer i = 0; i < 200; i++) {
      items.add(makeItem(String.valueOf(lpm.ContactId), 'PK-FULL-' + i, 'Bulk' + i, '1/14/2026 9:52:40 AM', 'C1', 'C2'));
    }

    Test.setMock(HttpCalloutMock.class, new RowsetMock(200, '{"items":[' + String.join(items, ',') + ']}'));

    Test.startTest();
    Id firstJobId = System.enqueueJob(new MceCampaignTargetSendHistoryFetchJob(Date.newInstance(2026, 3, 3), 1));
    Test.stopTest();

    assertQueueableCompleted(firstJobId);

    Integer completedJobs = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'Queueable' AND ApexClass.Name = 'MceCampaignTargetSendHistoryFetchJob' AND Status = 'Completed'
    ];
    System.assert(completedJobs >= 1);
  }
}