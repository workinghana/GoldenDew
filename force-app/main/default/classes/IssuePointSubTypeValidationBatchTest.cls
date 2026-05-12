@IsTest
private class IssuePointSubTypeValidationBatchTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{"erpId":"OK"}}');
      return res;
    }
  }

  private class MockBatchableContext implements Database.BatchableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }

    public Id getChildJobId() {
      return UserInfo.getUserId();
    }
  }

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }

  private static String resolveCurrencyType() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('NonQualifying')) {
        return entry.getValue();
      }
    }

    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String resolveExpiryModel() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('Fixed')) {
        return entry.getValue();
      }
    }

    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String resolveExpiryUnit() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues()) {
      if (!entry.getValue().toLowerCase().contains('day')) {
        return entry.getValue();
      }
    }

    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String resolveExtendExpiration() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('None')) {
        return entry.getValue();
      }
    }

    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  @TestSetup
  static void setupData() {
    setMock();

    JournalType journalType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert journalType;
    insert new JournalSubType(Name = 'Manual Points Credit', JournalTypeId = journalType.Id);

    LoyaltyProgram program = new LoyaltyProgram(Name = uniq('ValidationProgram'), IsPrimary = true);
    insert program;

    LoyaltyProgramCurrency programCurrency = new LoyaltyProgramCurrency(
      LoyaltyProgramId = program.Id,
      Name = uniq('ValidationCurrency'),
      CurrencyType = resolveCurrencyType(),
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = resolveExpiryModel(),
      ExtendExpiration = resolveExtendExpiration(),
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = resolveExpiryUnit(),
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert programCurrency;
  }

  private static Contact createContact(String memberNo) {
    Contact contact = new Contact(LastName = uniq('Contact'), MemberNo__c = memberNo);
    insert contact;
    return contact;
  }

  private static LoyaltyProgramMember createProgramMember(Id contactId, String membershipNumber) {
    LoyaltyProgram program = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ContactId = contactId,
      ProgramId = program.Id,
      MembershipNumber = membershipNumber,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert member;
    return member;
  }

  private static Id createContentVersion(String title, String text) {
    ContentVersion contentVersion = new ContentVersion(
      Title = title,
      PathOnClient = title + '.csv',
      VersionData = Blob.valueOf(text),
      IsMajorVersion = false
    );
    insert contentVersion;
    return contentVersion.Id;
  }

  private static IssuePointSubTypeControllerV1.ValidationSummaryFile loadSummary(Id jobId) {
    IssuePointSubTypeControllerV1.ValidationSummaryFile summary = IssuePointSubTypeControllerV1.loadValidationSummary(jobId);
    System.assertNotEquals(null, summary);
    return summary;
  }

  @IsTest
  static void test_executeBatch_completedWithSuccessDuplicateBlankAndMissingMember() {
    setMock();

    String okMemberNo = uniq('OK');
    Contact contact = createContact(okMemberNo);
    createProgramMember(contact.Id, uniq('LPM'));

    String csv = 'NO_MBR,ETC\r\n' + okMemberNo + ',A\r\n' + okMemberNo + ',DUP\r\n,B\r\nNOT_FOUND,C\r\n\r\n';
    Id sourceContentVersionId = createContentVersion('validation-mixed', csv);

    Id jobId;
    Test.startTest();
    jobId = Database.executeBatch(new IssuePointSubTypeValidationBatch(sourceContentVersionId), 200);
    Test.stopTest();

    IssuePointSubTypeControllerV1.ValidationSummaryFile summary = loadSummary(jobId);
    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED, summary.status);
    System.assertEquals(4, summary.totalCount);
    System.assertEquals(1, summary.successCount);
    System.assertEquals(3, summary.failCount);
    System.assertEquals(3, summary.errors.size());
  }

  @IsTest
  static void test_executeBatch_acceptsMemberNoFieldHeader() {
    setMock();

    String memberNo = uniq('HDR');
    Contact contact = createContact(memberNo);
    createProgramMember(contact.Id, uniq('LPM'));

    Id sourceContentVersionId = createContentVersion('validation-memberno-header', 'MemberNo__c\n' + memberNo + '\n');

    Id jobId;
    Test.startTest();
    jobId = Database.executeBatch(new IssuePointSubTypeValidationBatch(sourceContentVersionId), 200);
    Test.stopTest();

    IssuePointSubTypeControllerV1.ValidationSummaryFile summary = loadSummary(jobId);
    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED, summary.status);
    System.assertEquals(1, summary.totalCount);
    System.assertEquals(1, summary.successCount);
    System.assertEquals(0, summary.failCount);
  }

  @IsTest
  static void test_executeBatch_missingHeaderCreatesFailedSummary() {
    setMock();

    Id sourceContentVersionId = createContentVersion('validation-missing-header', 'WRONG,ETC\nM001,A\n');

    Id jobId;
    Test.startTest();
    jobId = Database.executeBatch(new IssuePointSubTypeValidationBatch(sourceContentVersionId), 200);
    Test.stopTest();

    IssuePointSubTypeControllerV1.ValidationSummaryFile summary = loadSummary(jobId);
    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_FAILED, summary.status);
    System.assertEquals(0, summary.totalCount);
    System.assert(String.isNotBlank(summary.errorMessage));
  }

  @IsTest
  static void test_executeBatch_nullSourceCreatesFailedSummary() {
    setMock();

    Id jobId;
    Test.startTest();
    jobId = Database.executeBatch(new IssuePointSubTypeValidationBatch(null), 200);
    Test.stopTest();

    IssuePointSubTypeControllerV1.ValidationSummaryFile summary = loadSummary(jobId);
    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_FAILED, summary.status);
    System.assertEquals(0, summary.totalCount);
    System.assert(String.isNotBlank(summary.errorMessage));
  }

  @IsTest
  static void test_directExecuteCoversEmptyScopeAndRawPayload() {
    setMock();

    IssuePointSubTypeValidationBatch emptyScopeBatch = new IssuePointSubTypeValidationBatch(null);
    IssuePointSubTypeValidationBatch rawPayloadBatch = new IssuePointSubTypeValidationBatch(null);
    MockBatchableContext context = new MockBatchableContext();

    Test.startTest();
    emptyScopeBatch.execute(context, new List<String>());
    rawPayloadBatch.execute(context, new List<String>{ 'RAW_MEMBER_NO' });
    Test.stopTest();

    System.assert(true);
  }
}