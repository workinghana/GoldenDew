@IsTest
private class LoyaltyAggrSubUIControllerTest {
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

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  private static String pickFirst(List<Schema.PicklistEntry> entries, String defaultValue) {
    return entries != null && !entries.isEmpty() ? entries[0].getValue() : defaultValue;
  }

  private static String resolveCurrencyType() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('NonQualifying')) {
        return entry.getValue();
      }
    }
    return pickFirst(LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues(), null);
  }

  private static String resolveExpiryModel() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('Fixed')) {
        return entry.getValue();
      }
    }
    return pickFirst(LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues(), null);
  }

  private static String resolveExpiryUnit() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues()) {
      String value = entry.getValue().toLowerCase();
      if (value.contains('month') || value.contains('year')) {
        return entry.getValue();
      }
    }
    return pickFirst(LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues(), null);
  }

  private static String resolveExtendExpiration() {
    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[entries.size() - 1].getValue();
  }

  @TestSetup
  static void setupData() {
    setMock();

    Contact contact = new Contact(LastName = 'PointTester', MemberNo__c = 'M1001');
    insert contact;

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Point Test Program', IsPrimary = true);
    insert program;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ContactId = contact.Id,
      ProgramId = program.Id,
      MembershipNumber = 'LPM-M1001',
      EnrollmentDate = Date.today(),
      MemberStatus = 'Active'
    );
    insert member;

    LoyaltyProgramCurrency currencyRecord = new LoyaltyProgramCurrency(
      LoyaltyProgramId = program.Id,
      Name = 'Point Currency',
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
    insert currencyRecord;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = currencyRecord.Id,
      Name = 'Base Point',
      PointTypeCode__c = pickFirst(LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues(), 'NORMAL'),
      UsagePriorityNumber = 1
    );
    insert subtype;

    JournalType journalType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert journalType;

    JournalSubType journalSubType = new JournalSubType(Name = 'Manual Points Credit', JournalTypeId = journalType.Id);
    insert journalSubType;

    TransactionJournal journal = new TransactionJournal(
      MemberId = member.Id,
      LoyaltyProgramId = program.Id,
      ActivityDate = Date.today(),
      JournalDate = Date.today(),
      JournalTypeId = journalType.Id,
      JournalSubTypeId = journalSubType.Id,
      Status = 'Processed'
    );
    insert journal;

    Date expiryDate = Date.today().addDays(10);
    insert new List<LoyaltyLedger>{
      new LoyaltyLedger(
        LoyaltyProgramMemberId = member.Id,
        LoyaltyProgramCurrencyId = currencyRecord.Id,
        LoyaltyPgmCrcySubtypeId = subtype.Id,
        TransactionJournalId = journal.Id,
        EventType = 'Credit',
        Points = 100,
        ActivityDate = Date.today(),
        ExpiryDate = expiryDate
      ),
      new LoyaltyLedger(
        LoyaltyProgramMemberId = member.Id,
        LoyaltyProgramCurrencyId = currencyRecord.Id,
        LoyaltyPgmCrcySubtypeId = subtype.Id,
        TransactionJournalId = journal.Id,
        EventType = 'Debit',
        Points = 40,
        ActivityDate = Date.today(),
        ExpiryDate = expiryDate
      )
    };
  }

  @IsTest
  static void test_getPointDetails_success() {
    setMock();
    Id memberId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;

    Test.startTest();
    LoyaltyAggrSubUIController.PointDetailResult result = LoyaltyAggrSubUIController.getPointDetails(memberId);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(1, result.details.size());
    System.assertEquals(100, result.totalAccrued);
    System.assertEquals(40, result.totalUsed);
    System.assertEquals(60, result.totalRemaining);

    LoyaltyAggrSubUIController.PointDetailDTO first = result.details[0];
    System.assertEquals('Base Point', first.pointTypeName);
    System.assertEquals(100, first.accruedPoints);
    System.assertEquals(40, first.usedPoints);
    System.assertEquals(0, first.expiredPoints);
    System.assertEquals(60, first.remainingPoints);
  }

  @IsTest
  static void test_getPointDetails_empty() {
    setMock();

    Test.startTest();
    LoyaltyAggrSubUIController.PointDetailResult result = LoyaltyAggrSubUIController.getPointDetails(UserInfo.getUserId());
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(0, result.details.size());
    System.assertEquals(0, result.totalAccrued);
    System.assertEquals(0, result.totalUsed);
    System.assertEquals(0, result.totalRemaining);
  }
}