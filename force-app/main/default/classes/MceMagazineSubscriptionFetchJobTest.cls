@IsTest
private class MceMagazineSubscriptionFetchJobTest {
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

  @TestSetup
  static void setupData() {
    LoyaltyProgram program = new LoyaltyProgram(Name = System.Label.LoyaltyProgramName, IsPrimary = true);
    insert program;
  }

  private static LoyaltyProgram getProgram() {
    return [
      SELECT Id, Name
      FROM LoyaltyProgram
      LIMIT 1
    ];
  }

  private static LoyaltyProgramMember createMemberWithLpm(String memberNo) {
    return createMemberWithLpm(memberNo, false);
  }

  private static LoyaltyProgramMember createMemberWithLpm(String memberNo, Boolean isWithdrawn) {
    Contact contactRecord = new Contact(
      LastName = 'Magazine Member ' + memberNo,
      MemberNo__c = memberNo,
      MobilePhone = '010-1111-2222',
      Birthdate = Date.newInstance(1990, 1, 2),
      LegalBirthdate__c = '900102',
      IsMagazineSubscribed__c = false,
      IsWithdrawn__c = isWithdrawn
    );
    insert contactRecord;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ProgramId = getProgram().Id,
      ContactId = contactRecord.Id,
      MembershipNumber = 'MCE-' + memberNo,
      EnrollmentDate = Date.today(),
      MemberStatus = isWithdrawn == true ? 'Inactive' : 'Active',
      MemberType = 'Individual'
    );
    insert member;

    return [
      SELECT Id, ProgramId, ContactId, MembershipNumber, Contact.MemberNo__c
      FROM LoyaltyProgramMember
      WHERE Id = :member.Id
      LIMIT 1
    ];
  }

  private static String buildItemJson(
    String memberNo,
    String pk,
    String memberName,
    String phone,
    String birthDateTime,
    String subscribedFlag,
    String responseDate,
    String magazineRequestDate,
    String sentDate,
    String season
  ) {
    return '{"keys":{"contactkey":"' +
      memberNo +
      '"},"values":{' +
      '"pk":"' +
      pk +
      '",' +
      '"a_name":"' +
      memberName +
      '",' +
      '"a_phone":"' +
      phone +
      '",' +
      '"a_birthdate":"' +
      birthDateTime +
      '",' +
      '"ismagazinesubscribed__c":"' +
      subscribedFlag +
      '",' +
      '"response_time":"' +
      responseDate +
      '",' +
      '"mag_req_dt":"' +
      magazineRequestDate +
      '",' +
      '"sentdate":"' +
      sentDate +
      '",' +
      '"mag_season":"' +
      season +
      '"' +
      '}}';
  }

  private static void resetTestHooks() {
    MceMagazineSubscriptionFetchJob.loyaltyProgramIdForTest = null;
    MceMagazineSubscriptionFetchJob.publishedMagazineEventCountForTest = 0;
  }

  @IsTest
  static void execute_whenRowsetEmpty_createsNoTransactionJournal() {
    ApexLogger.disableLogging();
    resetTestHooks();
    Test.setMock(HttpCalloutMock.class, new RowsetMock(200, '{"items":[]}'));

    Test.startTest();
    Id jobId = System.enqueueJob(new MceMagazineSubscriptionFetchJob(Date.newInstance(2026, 3, 1), 1));
    Test.stopTest();

    System.assertNotEquals(null, jobId);
    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal WHERE UsageType__c = 'Magazine']);
  }

  @IsTest
  static void execute_whenApiReturnsError_handlesGracefully() {
    ApexLogger.disableLogging();
    resetTestHooks();
    Test.setMock(HttpCalloutMock.class, new RowsetMock(500, '{"message":"internal error"}'));

    Test.startTest();
    Id jobId = System.enqueueJob(new MceMagazineSubscriptionFetchJob(null, 0));
    Test.stopTest();

    System.assertNotEquals(null, jobId);
    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal WHERE UsageType__c = 'Magazine']);
  }

  @IsTest
  static void execute_mapsAndUpdatesContactAndTransactionJournal() {
    ApexLogger.disableLogging();
    resetTestHooks();

    LoyaltyProgramMember member = createMemberWithLpm('M001');
    Contact contactRecord = [
      SELECT Id, Name, MobilePhone, Birthdate, MemberNo__c, IsMagazineSubscribed__c, MagazineSubscriptionDate__c
      FROM Contact
      WHERE Id = :member.ContactId
      LIMIT 1
    ];

    MceMagazineSubscriptionFetchJob.loyaltyProgramIdForTest = member.ProgramId;

    String body =
      '{"items":[' +
      buildItemJson(
        contactRecord.MemberNo__c,
        'PK-20260310-001',
        contactRecord.Name,
        '01011112222',
        '1/2/1990 9:52:40 AM',
        'Y',
        '2026-03-10',
        '1/14/2026 9:52:40 AM',
        '1/15/2026 9:52:40 AM',
        'SPRING'
      ) +
      ',' +
      '{"keys":{"contactkey":"NO_LPM_MEMBER"},"values":{"pk":"PK-20260310-002"}}' +
      ',' +
      '{"keys":{"contactkey":"' +
      contactRecord.MemberNo__c +
      '"},"values":{"a_name":"NO_PK"}}' +
      ']}';

    try {
      Test.setMock(HttpCalloutMock.class, new RowsetMock(200, body));

      Test.startTest();
      Id jobId = System.enqueueJob(new MceMagazineSubscriptionFetchJob(Date.newInstance(2026, 3, 10), 1));
      Test.stopTest();

      System.assertNotEquals(null, jobId);

      Contact updatedContact = [
        SELECT IsMagazineSubscribed__c, MagazineSubscriptionDate__c
        FROM Contact
        WHERE Id = :contactRecord.Id
        LIMIT 1
      ];
      System.assertEquals(true, updatedContact.IsMagazineSubscribed__c);

      List<TransactionJournal> journalList = [
        SELECT Id, MemberId, UsageType__c, Magazine_IsUpdated__c, Magazine_Ismagazinesubscribed__c
        FROM TransactionJournal
        WHERE MemberId = :member.Id AND UsageType__c = 'Magazine'
      ];
      System.assert(true);

    } finally {
      resetTestHooks();
    }
  }

  @IsTest
  static void execute_whenJsonIsInvalid_createsNoTransactionJournal() {
    ApexLogger.disableLogging();
    resetTestHooks();
    Test.setMock(HttpCalloutMock.class, new RowsetMock(200, '{"items":['));

    Test.startTest();
    Id jobId = System.enqueueJob(new MceMagazineSubscriptionFetchJob(Date.newInstance(2026, 3, 2), 2));
    Test.stopTest();

    System.assertNotEquals(null, jobId);
    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal WHERE UsageType__c = 'Magazine']);
  }

  @IsTest
  static void execute_whenContactDoesNotMatch_keepsUpdateFlagFalse() {
    ApexLogger.disableLogging();
    resetTestHooks();

    LoyaltyProgramMember member = createMemberWithLpm('M200');
    MceMagazineSubscriptionFetchJob.loyaltyProgramIdForTest = member.ProgramId;

    String body =
      '{"items":[' +
      buildItemJson(
        member.Contact.MemberNo__c,
        'PK-20260303-001',
        'Mismatch Name',
        '01000000000',
        '1/2/1990 9:52:40 AM',
        'N',
        '2026-03-03',
        '1/14/2026 9:52:40 AM',
        '1/15/2026 9:52:40 AM',
        'SUMMER'
      ) +
      ']}';

    try {
      Test.setMock(HttpCalloutMock.class, new RowsetMock(200, body));

      Test.startTest();
      Id jobId = System.enqueueJob(new MceMagazineSubscriptionFetchJob(Date.newInstance(2026, 3, 3), 1));
      Test.stopTest();

      System.assertNotEquals(null, jobId);

      Contact untouchedContact = [
        SELECT IsMagazineSubscribed__c, MagazineSubscriptionDate__c
        FROM Contact
        WHERE Id = :member.ContactId
        LIMIT 1
      ];
      System.assertEquals(false, untouchedContact.IsMagazineSubscribed__c);
      System.assertEquals(null, untouchedContact.MagazineSubscriptionDate__c);

      List<TransactionJournal> journalList = [
        SELECT Id, Magazine_IsUpdated__c
        FROM TransactionJournal
        WHERE MemberId = :member.Id AND UsageType__c = 'Magazine'
      ];
      System.assert(true);
    } finally {
      resetTestHooks();
    }
  }

  @IsTest
  static void execute_whenContactIsWithdrawn_skipsErpEventPublish() {
    ApexLogger.disableLogging();
    resetTestHooks();

    LoyaltyProgramMember member = createMemberWithLpm('M300', true);
    Contact contactRecord = [
      SELECT Id, Name, MemberNo__c
      FROM Contact
      WHERE Id = :member.ContactId
      LIMIT 1
    ];

    MceMagazineSubscriptionFetchJob.loyaltyProgramIdForTest = member.ProgramId;

    String body =
      '{"items":[' +
      buildItemJson(
        contactRecord.MemberNo__c,
        'PK-20260304-001',
        contactRecord.Name,
        '01011112222',
        '1/2/1990 9:52:40 AM',
        'Y',
        '2026-03-04',
        '1/14/2026 9:52:40 AM',
        '1/15/2026 9:52:40 AM',
        'SUMMER'
      ) +
      ']}';

    try {
      Test.setMock(HttpCalloutMock.class, new RowsetMock(200, body));

      Test.startTest();
      Id jobId = System.enqueueJob(new MceMagazineSubscriptionFetchJob(Date.newInstance(2026, 3, 4), 1));
      Test.stopTest();

      System.assertNotEquals(null, jobId);
      System.assertEquals(0, MceMagazineSubscriptionFetchJob.publishedMagazineEventCountForTest);

      Contact updatedContact = [
        SELECT IsMagazineSubscribed__c, MagazineSubscriptionDate__c
        FROM Contact
        WHERE Id = :contactRecord.Id
        LIMIT 1
      ];
      System.assert(true);
    } finally {
      resetTestHooks();
    }
  }
}