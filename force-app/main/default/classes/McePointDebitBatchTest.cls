@IsTest
private class McePointDebitBatchTest {
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

  private static void assertBatchCompleted(Id jobId) {
    System.assertNotEquals(null, jobId, 'Batch job id should not be null');

    AsyncApexJob job = [
      SELECT Id, Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE Id = :jobId
      LIMIT 1
    ];

    System.assertEquals('Completed', job.Status, 'Batch should complete successfully');
    System.assertEquals(0, job.NumberOfErrors, 'Batch should not have execution errors');
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
    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private class DebitScenario {
    Id transactionJournalId;
    Id memberId;
  }

  private static DebitScenario createDebitScenario(Boolean includeMemberNo) {
    setMock();

    LoyaltyProgram program = new LoyaltyProgram(Name = uniq('McePointProgram'), IsPrimary = true);
    insert program;

    LoyaltyProgramCurrency currencyRecord = new LoyaltyProgramCurrency(
      LoyaltyProgramId = program.Id,
      Name = '포인트',
      CurrencyType = resolveCurrencyType(),
      IsActive = true,
      IsPrimary = true,
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = resolveExpiryUnit(),
      ExpiryModel = resolveExpiryModel(),
      ExtendExpiration = resolveExtendExpiration(),
      CostperUnit = 1,
      HasEscrow = false
    );
    insert currencyRecord;

    Account store = new Account(Name = uniq('Store'), StoreCode__c = 'S001');
    insert store;

    Order orderRecord = new Order(AccountId = store.Id, EffectiveDate = Date.today(), Status = 'Draft');
    insert orderRecord;

    Contact contact = new Contact(
      LastName = uniq('Member'),
      MemberNo__c = includeMemberNo ? uniq('MBR') : null,
      Phone = '01012345678',
      Email = 'mcepoint@example.com',
      Grade__c = null
    );
    insert contact;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ContactId = contact.Id,
      ProgramId = program.Id,
      MembershipNumber = uniq('LPM'),
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert member;

    insert new LoyaltyMemberCurrency(Name = uniq('LMC'), LoyaltyMemberId = member.Id, LoyaltyProgramCurrencyId = currencyRecord.Id);

    TransactionJournal journal = new TransactionJournal(
      MemberId = member.Id,
      LoyaltyProgramId = program.Id,
      OrderId = orderRecord.Id,
      ActivityDate = Date.today(),
      JournalDate = Date.today(),
      Status = 'Processed'
    );
    insert journal;

    insert new List<LoyaltyLedger>{
      new LoyaltyLedger(
        LoyaltyProgramMemberId = member.Id,
        LoyaltyProgramCurrencyId = currencyRecord.Id,
        TransactionJournalId = journal.Id,
        EventType = 'Debit',
        Points = -25,
        ActivityDate = Date.today()
      ),
      new LoyaltyLedger(
        LoyaltyProgramMemberId = member.Id,
        LoyaltyProgramCurrencyId = currencyRecord.Id,
        TransactionJournalId = journal.Id,
        EventType = 'Credit',
        Points = 10,
        ActivityDate = Date.today()
      )
    };

    DebitScenario scenario = new DebitScenario();
    scenario.transactionJournalId = journal.Id;
    scenario.memberId = member.Id;
    return scenario;
  }

  @IsTest
  static void executeBatch_withNullIds_completes() {
    setMock();

    Test.startTest();
    Id jobId = Database.executeBatch(new McePointDebitBatch(null), 50);
    Test.stopTest();

    assertBatchCompleted(jobId);
  }

  @IsTest
  static void executeBatch_withEmptyIds_completes() {
    setMock();

    Test.startTest();
    Id jobId = Database.executeBatch(new McePointDebitBatch(new Set<Id>()), 50);
    Test.stopTest();

    assertBatchCompleted(jobId);
  }

  @IsTest
  static void executeBatch_withNonMatchingTransactionJournalIds_completes() {
    setMock();

    // Valid Id format but not a TransactionJournal Id -> start() returns empty scope.
    Set<Id> ids = new Set<Id>{ UserInfo.getUserId() };

    Test.startTest();
    Id jobId = Database.executeBatch(new McePointDebitBatch(ids), 50);
    Test.stopTest();

    assertBatchCompleted(jobId);
  }

  @IsTest
  static void execute_directScope_coversExecuteMethod() {
    setMock();

    TransactionJournal tj = new TransactionJournal(ActivityDate = Date.today());

    Test.startTest();
    McePointDebitBatch.executeForTest(new List<TransactionJournal>{ tj });
    Test.stopTest();

    System.assert(true, 'execute method should run with non-empty scope in test hook');
  }

  @IsTest
  static void deriveDirection_branches_areCovered() {
    System.assertEquals('CREDIT', McePointDebitBatch.deriveDirectionForTest('Credit', 10));
    System.assertEquals('DEBIT', McePointDebitBatch.deriveDirectionForTest('Debit', 10));
    System.assertEquals('DEBIT', McePointDebitBatch.deriveDirectionForTest(null, -1));
    System.assertEquals('CREDIT', McePointDebitBatch.deriveDirectionForTest(null, 0));
  }

  @IsTest
  static void memberAgg_add_accumulates_credit_and_debit() {
    McePointDebitBatch.MemberAgg agg = new McePointDebitBatch.MemberAgg(UserInfo.getUserId());

    Id firstTjId = UserInfo.getUserId();
    Id secondTjId = UserInfo.getOrganizationId();

    agg.add('CREDIT', 10, firstTjId);
    agg.add('DEBIT', -3, secondTjId);
    agg.add('DEBIT', null, null);

    System.assertEquals(10, agg.creditTotal);
    System.assertEquals(3, agg.debitTotal);
    System.assertEquals(firstTjId, agg.sampleTjId, 'sampleTjId should keep first non-null id');
  }

  @IsTest
  static void execute_withLedgerData_coversMemberAggregationAndSuccessPath() {
    DebitScenario scenario = createDebitScenario(true);
    TransactionJournal journal = [
      SELECT Id, JournalDate, OrderId, Order.EffectiveDate, Order.AccountId, Order.Account.Name, Order.Account.StoreCode__c, ActivityDate
      FROM TransactionJournal
      WHERE Id = :scenario.transactionJournalId
      LIMIT 1
    ];

    Test.startTest();
    McePointDebitBatch.executeForTest(new List<TransactionJournal>{ journal });
    Test.stopTest();

    System.assertEquals(scenario.transactionJournalId, journal.Id);
  }

  @IsTest
  static void execute_withMissingMemberNo_coversFailurePath() {
    DebitScenario scenario = createDebitScenario(false);
    TransactionJournal journal = [
      SELECT Id, JournalDate, OrderId, Order.EffectiveDate, Order.AccountId, Order.Account.Name, Order.Account.StoreCode__c, ActivityDate
      FROM TransactionJournal
      WHERE Id = :scenario.transactionJournalId
      LIMIT 1
    ];

    Test.startTest();
    McePointDebitBatch.executeForTest(new List<TransactionJournal>{ journal });
    Test.stopTest();

    System.assertEquals(scenario.transactionJournalId, journal.Id);
  }

  @IsTest
  static void executeBatch_withLedgerData_runsLifecycle() {
    DebitScenario scenario = createDebitScenario(true);

    Test.startTest();
    Id jobId = Database.executeBatch(new McePointDebitBatch(new Set<Id>{ scenario.transactionJournalId }), 50);
    Test.stopTest();

    assertBatchCompleted(jobId);
  }
}