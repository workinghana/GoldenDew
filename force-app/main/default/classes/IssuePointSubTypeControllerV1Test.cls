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

  private static Id getSubtypeId() {
    return [SELECT Id FROM LoyaltyPgmCurrencySubtype LIMIT 1].Id;
  }

  @IsTest
  static void test_parsePointFile_blankData() {
    try {
      IssuePointSubTypeControllerV1.parsePointFile(null);
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  @IsTest
  static void test_parsePointFile_missingHeader() {
    try {
      IssuePointSubTypeControllerV1.parsePointFile(toBase64('WRONG,ETC\nM001,A'));
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assert(true);
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
      System.assert(true);
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
      System.assert(true);
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
}
