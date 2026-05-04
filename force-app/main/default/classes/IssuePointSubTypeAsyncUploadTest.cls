@IsTest
private class IssuePointSubTypeAsyncUploadTest {
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

  private static String resolvePointTypeCode() {
    List<Schema.PicklistEntry> entries = LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  @TestSetup
  static void setupData() {
    JournalType jt = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert jt;
    insert new JournalSubType(Name = 'Manual Points Credit', JournalTypeId = jt.Id);

    LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('Prog'), IsPrimary = true);
    insert lp;

    LoyaltyProgramCurrency programCurrency = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = uniq('Currency'),
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

    insert new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = programCurrency.Id,
      Name = uniq('Subtype'),
      PointTypeCode__c = resolvePointTypeCode(),
      UsagePriorityNumber = 1,
      IsActive = true
    );
  }

  private static Contact createContact(String memberNo) {
    Contact contact = new Contact(LastName = uniq('Contact'), MemberNo__c = memberNo);
    insert contact;
    return contact;
  }

  private static LoyaltyProgramMember createProgramMember(Id contactId, String memberNo) {
    LoyaltyProgram program = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ContactId = contactId,
      ProgramId = program.Id,
      MembershipNumber = memberNo,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert member;
    return member;
  }

  private static LoyaltyProgramMember createProgramMemberWithMembershipNumber(Id contactId, String membershipNumber) {
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

  private static String toBase64(String text) {
    return EncodingUtil.base64Encode(Blob.valueOf(text));
  }

  private static Id getSubtypeId() {
    return [SELECT Id FROM LoyaltyPgmCurrencySubtype LIMIT 1].Id;
  }

  @IsTest
  static void test_asyncValidationStatus_completed() {
    System.assertEquals(300, IssuePointSubTypeControllerV1.VALIDATION_BATCH_SCOPE_SIZE);

    String memberNo = uniq('MBR');
    Contact contact = createContact(memberNo);
    createProgramMember(contact.Id, memberNo);

    String csv = 'NO_MBR\n' + memberNo + '\nNOT_FOUND\n' + memberNo + '\n';

    IssuePointSubTypeControllerV1.UploadJobStartResult startResult;
    Test.startTest();
    startResult = IssuePointSubTypeControllerV1.startPointFileValidation(toBase64(csv), 'members.csv', getSubtypeId());
    Test.stopTest();

    IssuePointSubTypeControllerV1.UploadJobStatusResult statusResult = IssuePointSubTypeControllerV1.getPointFileValidationStatus(
      startResult.uploadJobId
    );

    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED, statusResult.status);
    System.assertEquals(1, statusResult.successCount);
    System.assertEquals(2, statusResult.failCount);
    System.assertEquals(true, statusResult.isCompleted);
    System.assertEquals(false, statusResult.errors.isEmpty());
  }

  @IsTest
  static void test_issuePointByUploadJob_returnsRequestedCount() {
    String memberNo = uniq('MBR');
    Contact contact = createContact(memberNo);
    createProgramMember(contact.Id, memberNo);

    String csv = 'NO_MBR\n' + memberNo + '\n';

    IssuePointSubTypeControllerV1.UploadJobStartResult startResult;
    Test.startTest();
    startResult = IssuePointSubTypeControllerV1.startPointFileValidation(toBase64(csv), 'members.csv', getSubtypeId());
    Test.stopTest();

    IssuePointSubTypeControllerV1.IssuePointResult issueResult = IssuePointSubTypeControllerV1.issuePointByUploadJob(
      startResult.uploadJobId,
      getSubtypeId(),
      1000,
      Date.today().addDays(365)
    );

    System.assertEquals(true, issueResult.success);
    System.assertEquals(1, issueResult.requestedMemberCount);
  }

  @IsTest
  static void test_asyncValidationStatus_usesContactMemberNo() {
    String contactMemberNo = uniq('MBR');
    String membershipNumber = uniq('LPM');
    Contact contact = createContact(contactMemberNo);
    createProgramMemberWithMembershipNumber(contact.Id, membershipNumber);

    String csv = 'NO_MBR\n' + contactMemberNo + '\n';

    IssuePointSubTypeControllerV1.UploadJobStartResult startResult;
    Test.startTest();
    startResult = IssuePointSubTypeControllerV1.startPointFileValidation(toBase64(csv), 'members.csv', getSubtypeId());
    Test.stopTest();

    IssuePointSubTypeControllerV1.UploadJobStatusResult statusResult = IssuePointSubTypeControllerV1.getPointFileValidationStatus(
      startResult.uploadJobId
    );

    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED, statusResult.status);
    System.assertEquals(1, statusResult.successCount);
    System.assertEquals(0, statusResult.failCount);
  }

  @IsTest
  static void test_asyncValidationStatus_acceptsMemberNoFieldHeader() {
    String memberNo = uniq('MBRHDR');
    Contact contact = createContact(memberNo);
    createProgramMember(contact.Id, memberNo);

    String csv = 'MemberNo__c\n' + memberNo + '\n';

    IssuePointSubTypeControllerV1.UploadJobStartResult startResult;
    Test.startTest();
    startResult = IssuePointSubTypeControllerV1.startPointFileValidation(toBase64(csv), 'members.csv', getSubtypeId());
    Test.stopTest();

    IssuePointSubTypeControllerV1.UploadJobStatusResult statusResult = IssuePointSubTypeControllerV1.getPointFileValidationStatus(
      startResult.uploadJobId
    );

    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED, statusResult.status);
    System.assertEquals(1, statusResult.successCount);
    System.assertEquals(0, statusResult.failCount);
  }

  @IsTest
  static void test_asyncValidationStatus_acceptsExcelCsvMemberNo() {
    String memberNo = '00098765';
    Contact contact = createContact(memberNo);
    createProgramMemberWithMembershipNumber(contact.Id, uniq('LPM'));

    String csv = '\uFEFF회원번호\n"=""' + memberNo + '"""\n';

    IssuePointSubTypeControllerV1.UploadJobStartResult startResult;
    Test.startTest();
    startResult = IssuePointSubTypeControllerV1.startPointFileValidation(toBase64(csv), 'members.csv', getSubtypeId());
    Test.stopTest();

    IssuePointSubTypeControllerV1.UploadJobStatusResult statusResult = IssuePointSubTypeControllerV1.getPointFileValidationStatus(
      startResult.uploadJobId
    );

    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED, statusResult.status);
    System.assertEquals(1, statusResult.successCount);
    System.assertEquals(0, statusResult.failCount);
  }
}