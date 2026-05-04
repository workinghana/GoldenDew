@IsTest
private class IssuePointSubTypeControllerV1Test {
  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  private static String toBase64(String text) {
    return EncodingUtil.base64Encode(Blob.valueOf(text));
  }

  private static String resolveCurrencyType() {
    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.getValue().equalsIgnoreCase('NonQualifying')) {
        return entry.getValue();
      }
    }

    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String resolveExpiryUnit() {
    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (!entry.getValue().toLowerCase().contains('day')) {
        return entry.getValue();
      }
    }

    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String resolveExpiryModel() {
    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.getValue().equalsIgnoreCase('Fixed')) {
        return entry.getValue();
      }
    }

    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String resolveExtendExpiration() {
    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.getValue().equalsIgnoreCase('None')) {
        return entry.getValue();
      }
    }

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
    Contact c = new Contact(LastName = uniq('Contact'), MemberNo__c = memberNo);
    insert c;
    return c;
  }

  private static LoyaltyProgramMember createProgramMember(Id contactId, String memberNo) {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];

    LoyaltyProgramMember pm = new LoyaltyProgramMember(
      ContactId = contactId,
      ProgramId = lp.Id,
      MembershipNumber = memberNo,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );

    insert pm;
    return pm;
  }

  private static LoyaltyProgramMember createProgramMemberWithMembershipNumber(Id contactId, String membershipNumber) {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];

    LoyaltyProgramMember pm = new LoyaltyProgramMember(
      ContactId = contactId,
      ProgramId = lp.Id,
      MembershipNumber = membershipNumber,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );

    insert pm;
    return pm;
  }

  private static Id getSubtypeId() {
    return [SELECT Id FROM LoyaltyPgmCurrencySubtype LIMIT 1].Id;
  }

  private static AsyncApexJob findJobById(Id jobId) {
    return [
      SELECT Id, Status, ExtendedStatus
      FROM AsyncApexJob
      WHERE Id = :jobId
      LIMIT 1
    ];
  }

  @IsTest
  static void test_parsePointFile_blankData() {
    try {
      IssuePointSubTypeControllerV1.parsePointFile(null);
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void test_parsePointFile_missingHeader() {
    try {
      IssuePointSubTypeControllerV1.parsePointFile(toBase64('WRONG,ETC\nM001,A'));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void test_parsePointFile_headerOnly() {
    IssuePointSubTypeControllerV1.UploadPreviewResult result = IssuePointSubTypeControllerV1.parsePointFile(toBase64('NO_MBR,ETC\n'));

    System.assertEquals(0, result.successCount);
    System.assertEquals(0, result.failCount);
  }

  @IsTest
  static void test_parsePointFile_success() {
    String m1 = uniq('M1');
    String m2 = uniq('M2');

    Contact c1 = createContact(m1);
    Contact c2 = createContact(m2);

    createProgramMember(c1.Id, m1);
    createProgramMember(c2.Id, m2);

    String csv = 'NO_MBR,ETC\n' + m1 + ',A\n' + m2 + ',B\n';

    IssuePointSubTypeControllerV1.UploadPreviewResult result = IssuePointSubTypeControllerV1.parsePointFile(toBase64(csv));

    System.assertEquals(2, result.successCount);
    System.assertEquals(0, result.failCount);
  }

  @IsTest
  static void test_parsePointFile_success_byContactMemberNo() {
    String contactMemberNo = uniq('CM');
    String membershipNumber = uniq('LPM');

    Contact contact = createContact(contactMemberNo);
    createProgramMemberWithMembershipNumber(contact.Id, membershipNumber);

    String csv = 'NO_MBR\n' + contactMemberNo + '\n';

    IssuePointSubTypeControllerV1.UploadPreviewResult result = IssuePointSubTypeControllerV1.parsePointFile(toBase64(csv));

    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.failCount);
  }

  @IsTest
  static void test_parsePointFile_success_withMemberNoFieldHeader() {
    String contactMemberNo = uniq('CMHDR');
    Contact contact = createContact(contactMemberNo);
    createProgramMember(contact.Id, contactMemberNo);

    String csv = 'MemberNo__c\n' + contactMemberNo + '\n';

    IssuePointSubTypeControllerV1.UploadPreviewResult result = IssuePointSubTypeControllerV1.parsePointFile(toBase64(csv));

    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.failCount);
  }

  @IsTest
  static void test_parsePointFile_success_withKoreanHeaderAndExcelTextValue() {
    String memberNo = '00012345';
    Contact contact = createContact(memberNo);
    createProgramMember(contact.Id, uniq('LPM'));

    String csv = '\uFEFF회원번호,비고\n"=""' + memberNo + '""",테스트\n';

    IssuePointSubTypeControllerV1.UploadPreviewResult result = IssuePointSubTypeControllerV1.parsePointFile(toBase64(csv));

    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.failCount);
  }

  @IsTest
  static void test_parsePointFile_largeRowCountWithinLimit() {
    String memberNo = uniq('LARGE');
    Contact contact = createContact(memberNo);
    createProgramMember(contact.Id, memberNo);

    String csv = 'NO_MBR\n';
    for (Integer i = 0; i < 2000; i++) {
      csv += memberNo + '\n';
    }

    IssuePointSubTypeControllerV1.UploadPreviewResult result = IssuePointSubTypeControllerV1.parsePointFile(toBase64(csv));

    System.assertEquals(1, result.successCount);
    System.assertEquals(1999, result.failCount);
  }

  @IsTest
  static void test_issuePoint_nullMembers() {
    try {
      IssuePointSubTypeControllerV1.issuePoint(null, getSubtypeId(), 100, Date.today().addDays(1));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void test_issuePoint_invalidPoint() {
    String memberNo = uniq('P0');
    Contact c = createContact(memberNo);
    LoyaltyProgramMember pm = createProgramMember(c.Id, memberNo);

    try {
      IssuePointSubTypeControllerV1.issuePoint(new List<Id>{ pm.Id }, getSubtypeId(), 0, Date.today().addDays(1));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void test_issuePoint_invalidSubtypeAndExpireAndMaxPoint() {
    String memberNo = uniq('P1');
    Contact c = createContact(memberNo);
    LoyaltyProgramMember pm = createProgramMember(c.Id, memberNo);

    try {
      IssuePointSubTypeControllerV1.issuePoint(new List<Id>{ pm.Id }, null, 100, Date.today().addDays(1));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }

    try {
      IssuePointSubTypeControllerV1.issuePoint(new List<Id>{ pm.Id }, getSubtypeId(), 100000001, Date.today().addDays(1));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }

    try {
      IssuePointSubTypeControllerV1.issuePoint(new List<Id>{ pm.Id }, getSubtypeId(), 100, null);
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }

    try {
      IssuePointSubTypeControllerV1.issuePoint(new List<Id>{ pm.Id }, getSubtypeId(), 100, Date.today().addDays(-1));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }

    try {
      IssuePointSubTypeControllerV1.issuePoint(new List<Id>{ pm.Id }, getSubtypeId(), 100, Date.today());
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void test_issuePoint_success() {
    String memberNo = uniq('OK');
    Contact c = createContact(memberNo);
    LoyaltyProgramMember pm = createProgramMember(c.Id, memberNo);

    Test.startTest();

    IssuePointSubTypeControllerV1.IssuePointResult result = IssuePointSubTypeControllerV1.issuePoint(
      new List<Id>{ pm.Id },
      getSubtypeId(),
      1000,
      Date.today().addDays(365)
    );

    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(1, result.requestedMemberCount);
  }

  @IsTest
  static void test_startValidation_and_getStatus_completed() {
    String okMemberNo = uniq('UPL');
    Contact c = createContact(okMemberNo);
    createProgramMember(c.Id, okMemberNo);
    String missingMemberNo = uniq('MISS');

    String csv = 'NO_MBR,ETC\n' + okMemberNo + ',A\n' + missingMemberNo + ',B\n';

    Test.startTest();
    IssuePointSubTypeControllerV1.UploadJobStartResult startResult = IssuePointSubTypeControllerV1.startPointFileValidation(
      toBase64(csv),
      'point-upload.csv',
      getSubtypeId()
    );
    Test.stopTest();

    System.assertNotEquals(null, startResult.uploadJobId);
    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_PROCESSING, startResult.status);

    IssuePointSubTypeControllerV1.UploadJobStatusResult statusResult = IssuePointSubTypeControllerV1.getPointFileValidationStatus(
      startResult.uploadJobId
    );

    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED, statusResult.status);
    System.assertEquals(2, statusResult.totalCount);
    System.assertEquals(1, statusResult.successCount);
    System.assertEquals(1, statusResult.failCount);
    System.assertEquals(false, statusResult.isFailed);
    System.assertEquals(true, statusResult.isCompleted);
    System.assertEquals(1, statusResult.errors.size());
  }

  @IsTest
  static void test_startValidation_blankData_throws() {
    try {
      IssuePointSubTypeControllerV1.startPointFileValidation(null, 'point-upload.csv', getSubtypeId());
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void test_getStatus_invalidArgs_and_missingSource() {
    try {
      IssuePointSubTypeControllerV1.getPointFileValidationStatus(null);
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }

    try {
      IssuePointSubTypeControllerV1.issuePointByUploadJob(null, getSubtypeId(), 100, Date.today().addDays(1));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }

    Id fakeJobId = ((Id) '707000000000001AAA');
    try {
      IssuePointSubTypeControllerV1.issuePointByUploadJob(fakeJobId, getSubtypeId(), 100, Date.today().addDays(1));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertEquals('Script-thrown exception', e.getMessage());
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void test_loadSummary_and_displayHelpers() {
    Id fakeJobId = ((Id) '707000000000002AAA');
    IssuePointSubTypeControllerV1.ValidationSummaryFile summary = new IssuePointSubTypeControllerV1.ValidationSummaryFile();
    summary.status = IssuePointSubTypeControllerV1.JOB_STATUS_FAILED;
    summary.totalCount = 3;
    summary.successCount = 1;
    summary.failCount = 2;
    summary.errorMessage = 'Contact MemberNo__c';
    summary.errors = new List<IssuePointSubTypeControllerV1.MemberErrorDTO>{
      new IssuePointSubTypeControllerV1.MemberErrorDTO('M1', 'LoyaltyProgramMember')
    };

    insert new ContentVersion(
      Title = 'summary',
      PathOnClient = 'summary.json',
      Description = IssuePointSubTypeControllerV1.buildSummaryDescription(fakeJobId),
      VersionData = Blob.valueOf(JSON.serialize(summary)),
      IsMajorVersion = false
    );

    IssuePointSubTypeControllerV1.ValidationSummaryFile loaded = IssuePointSubTypeControllerV1.loadValidationSummary(fakeJobId);
    System.assertNotEquals(null, loaded);
    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_FAILED, loaded.status);
    System.assertEquals(3, loaded.totalCount);
    System.assertEquals(null, IssuePointSubTypeControllerV1.loadValidationSummary((Id) '707000000000003AAA'));

    String displayMessage = IssuePointSubTypeControllerV1.toDisplayLabelMessage('Contact MemberNo__c X_UNKNOWN');
    System.assert(String.isNotBlank(displayMessage));
    System.assert(displayMessage.contains('X_UNKNOWN'));

    System.assertEquals('POINT_UPLOAD_SOURCE:' + String.valueOf(fakeJobId), IssuePointSubTypeControllerV1.buildSourceDescription(fakeJobId));
    System.assertEquals('POINT_UPLOAD_SUMMARY:' + String.valueOf(fakeJobId), IssuePointSubTypeControllerV1.buildSummaryDescription(fakeJobId));
  }

  @IsTest
  static void test_csvUtilityMethods() {
    List<String> cols = IssuePointSubTypeControllerV1.parseCsvColumns('A,"B,C","D""E"');
    System.assertEquals(3, cols.size());
    System.assertEquals('A', cols[0]);
    System.assertEquals('B,C', IssuePointSubTypeControllerV1.normalizeCsvCell('"' + cols[1] + '"'));
    System.assertEquals('D"E', IssuePointSubTypeControllerV1.normalizeCsvCell('"D""E"'));
    System.assertEquals('', IssuePointSubTypeControllerV1.normalizeCsvCell(null));
    System.assertEquals('000123', IssuePointSubTypeControllerV1.normalizeCsvCell('="000123"'));
    System.assertEquals('ABC', IssuePointSubTypeControllerV1.normalizeCsvCell('\'ABC'));
    System.assertEquals('001', IssuePointSubTypeControllerV1.normalizeMemberNo('\u00A0001\u00A0'));
    System.assertEquals(0, IssuePointSubTypeControllerV1.parseCsvColumns(null).size());
  }

  @IsTest
  static void test_getStatus_failedSummaryAndMapAsyncStatus() {
    String csv = 'WRONG,ETC\nA,B\n';

    Test.startTest();
    IssuePointSubTypeControllerV1.UploadJobStartResult startResult = IssuePointSubTypeControllerV1.startPointFileValidation(
      toBase64(csv),
      'wrong-header.csv',
      getSubtypeId()
    );
    Test.stopTest();

    AsyncApexJob job = findJobById(startResult.uploadJobId);
    System.assertEquals('Completed', job.Status);

    IssuePointSubTypeControllerV1.UploadJobStatusResult statusResult = IssuePointSubTypeControllerV1.getPointFileValidationStatus(
      startResult.uploadJobId
    );
    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_FAILED, statusResult.status);
    System.assertEquals(true, statusResult.isFailed);
    System.assert(String.isNotBlank(statusResult.errorMessage));
  }

  @IsTest
  static void test_getPointIssueProgress_completedJob() {
    String okMemberNo = uniq('PG');
    Contact contact = createContact(okMemberNo);
    createProgramMember(contact.Id, okMemberNo);

    String csv = 'NO_MBR,ETC\n' + okMemberNo + ',A\n';

    Test.startTest();
    IssuePointSubTypeControllerV1.UploadJobStartResult startResult = IssuePointSubTypeControllerV1.startPointFileValidation(
      toBase64(csv),
      'point-progress.csv',
      getSubtypeId()
    );
    Test.stopTest();

    IssuePointSubTypeControllerV1.IssuePointProgressResult progressResult = IssuePointSubTypeControllerV1.getPointIssueProgress(
      startResult.uploadJobId,
      1
    );

    System.assertEquals(startResult.uploadJobId, progressResult.issueJobId);
    System.assertEquals(IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED, progressResult.status);
    System.assertEquals(true, progressResult.isCompleted);
    System.assertEquals(false, progressResult.isFailed);
    System.assertEquals(1, progressResult.totalCount);
    System.assertEquals(1, progressResult.processedCount);
  }
}