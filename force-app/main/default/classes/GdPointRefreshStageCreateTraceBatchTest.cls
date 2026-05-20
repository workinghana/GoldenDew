@IsTest
private class GdPointRefreshStageCreateTraceBatchTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  @IsTest
  static void start_throwsWhenRunIdIsMissing() {
    GdPointRefreshStageCreateTraceBatch batch = new GdPointRefreshStageCreateTraceBatch(null);

    try {
      batch.start(null);
      System.assert(false, 'runId가 없으면 예외가 발생해야 합니다.');
    } catch (CustomException e) {
      System.assertNotEquals(null, e);
    }
  }

  @IsTest
  static void execute_returnsWhenScopeIsEmpty() {
    TestData data = setupData('EMPTY');
    GdPointRefreshStageCreateTraceBatch batch = new GdPointRefreshStageCreateTraceBatch(data.run.Id);

    Test.startTest();
    batch.execute(null, new List<SObject>());
    batch.execute(null, null);
    batch.finish(null);
    Test.stopTest();

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :data.run.Id
    ];
    System.assertEquals('TracesCreated', refreshedRun.Status__c);
    System.assertEquals('CREATED_TRACES_0', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void execute_createsTraceabilityForValidPlanTrace() {
    TestData data = setupData('CREATE');
    insert new List<GdPointRefreshStage__c>{
      createPlanStage(data.run.Id, 'PLAN_CREDIT', 'CREDIT-1', '-', '04', 100, data.creditLedger.Id, 1),
      createPlanStage(data.run.Id, 'PLAN_DEBIT', 'DEBIT-1', 'CREDIT-1', '-', 40, data.debitLedger.Id, 2)
    };

    GdPointRefreshStage__c validTrace = createTraceStage(data.run.Id, 'TRACE-1', 'CREDIT-1', 'DEBIT-1', 40, 3);
    GdPointRefreshStage__c missingPlanTrace = createTraceStage(data.run.Id, 'TRACE-MISSING', 'NO-CREDIT', 'DEBIT-1', 5, 4);
    GdPointRefreshStage__c zeroPointTrace = createTraceStage(data.run.Id, 'TRACE-ZERO', 'CREDIT-1', 'DEBIT-1', 0, 5);

    GdPointRefreshStageCreateTraceBatch batch = new GdPointRefreshStageCreateTraceBatch(data.run.Id);

    Test.startTest();
    batch.execute(null, new List<SObject>{ validTrace, missingPlanTrace, zeroPointTrace });
    batch.finish(null);
    Test.stopTest();

    List<LoyaltyLedgerTraceability> traces = [
      SELECT
        LoyaltyProgramMemberId,
        LoyaltyProgramCurrencyId,
        LoyaltyPgmCurrencySubtypeId,
        CreditLoyaltyLedgerId,
        DebitLoyaltyLedgerId,
        Points,
        ActionType
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :data.member.Id
    ];
    System.assertEquals(1, traces.size());
    System.assertEquals(data.pointCurrency.Id, traces[0].LoyaltyProgramCurrencyId);
    System.assertEquals(data.subtype.Id, traces[0].LoyaltyPgmCurrencySubtypeId);
    System.assertEquals(data.creditLedger.Id, traces[0].CreditLoyaltyLedgerId);
    System.assertEquals(data.debitLedger.Id, traces[0].DebitLoyaltyLedgerId);
    System.assertEquals(40, traces[0].Points);
    System.assertEquals('Debit', traces[0].ActionType);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :data.run.Id
    ];
    System.assertEquals('TracesCreated', refreshedRun.Status__c);
    System.assertEquals('CREATED_TRACES_1', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void batchExecution_processesPlanTraceRows() {
    TestData data = setupData('BATCH');
    insert new List<GdPointRefreshStage__c>{
      createPlanStage(data.run.Id, 'PLAN_CREDIT', 'CREDIT-BATCH', '-', '04', 70, data.creditLedger.Id, 1),
      createPlanStage(data.run.Id, 'PLAN_DEBIT', 'DEBIT-BATCH', 'CREDIT-BATCH', '-', 30, data.debitLedger.Id, 2),
      createTraceStage(data.run.Id, 'TRACE-BATCH', 'CREDIT-BATCH', 'DEBIT-BATCH', 30, 3)
    };

    Test.startTest();
    Database.executeBatch(new GdPointRefreshStageCreateTraceBatch(data.run.Id), 200);
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM LoyaltyLedgerTraceability WHERE LoyaltyProgramMemberId = :data.member.Id]);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :data.run.Id
    ];
    System.assertEquals('TracesCreated', refreshedRun.Status__c);
    System.assertEquals('CREATED_TRACES_1', refreshedRun.CurrentStep__c);
  }

  private static TestData setupData(String suffix) {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    Contact contactRecord = new Contact(LastName = 'StageCreateTrace ' + suffix, MemberNo__c = 'TRACE-' + suffix);
    insert contactRecord;

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Stage Create Trace Program ' + suffix, IsPrimary = true);
    insert program;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ProgramId = program.Id,
      MembershipNumber = 'TRACE-' + suffix,
      MemberType = 'Individual',
      ContactId = contactRecord.Id,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert member;

    LoyaltyProgramCurrency pointCurrency = new LoyaltyProgramCurrency(
      LoyaltyProgramId = program.Id,
      Name = '\uD3EC\uC778\uD2B8',
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = 'Fixed',
      ExtendExpiration = 'None',
      ExpiryPeriodFrequency = 2,
      ExpiryPeriodUnit = 'Years',
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert pointCurrency;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = 'Stage Create Trace Subtype ' + suffix,
      PointTypeCode__c = '04',
      UsagePriorityNumber = 1
    );
    insert subtype;

    JournalType accrualType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    JournalType redemptionType = new JournalType(Name = 'Redemption', ProcessType = 'Loyalty');
    insert new List<JournalType>{ accrualType, redemptionType };

    JournalSubType accrualSubType = new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualType.Id);
    JournalSubType debitSubType = new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionType.Id);
    insert new List<JournalSubType>{ accrualSubType, debitSubType };

    TransactionJournal creditJournal = createJournal(member.Id, program.Id, accrualType.Id, accrualSubType.Id, 100);
    TransactionJournal debitJournal = createJournal(member.Id, program.Id, redemptionType.Id, debitSubType.Id, 40);
    insert new List<TransactionJournal>{ creditJournal, debitJournal };

    LoyaltyLedger creditLedger = createLedger(member.Id, pointCurrency.Id, subtype.Id, creditJournal.Id, 'Credit', 100);
    LoyaltyLedger debitLedger = createLedger(member.Id, pointCurrency.Id, null, debitJournal.Id, 'Debit', 40);
    insert new List<LoyaltyLedger>{ creditLedger, debitLedger };

    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = 'TRACE-' + suffix;
    run.MemberId__c = member.Id;
    run.OpenDate__c = Date.newInstance(2026, 5, 18);
    run.Status__c = 'LedgersCreated';
    run.CurrentStep__c = 'LEDGER_READY';
    insert run;

    TestData data = new TestData();
    data.member = member;
    data.pointCurrency = pointCurrency;
    data.subtype = subtype;
    data.creditLedger = creditLedger;
    data.debitLedger = debitLedger;
    data.run = run;
    return data;
  }

  private static TransactionJournal createJournal(Id memberId, Id programId, Id journalTypeId, Id journalSubTypeId, Decimal amount) {
    TransactionJournal journal = new TransactionJournal();
    journal.MemberId = memberId;
    journal.LoyaltyProgramId = programId;
    journal.JournalTypeId = journalTypeId;
    journal.JournalSubTypeId = journalSubTypeId;
    journal.Status = 'Processed';
    journal.JournalReason__c = '6';
    journal.TransactionAmount = amount;
    journal.ActivityDate = Datetime.newInstance(2026, 5, 18, 0, 0, 0);
    journal.JournalDate = journal.ActivityDate;
    return journal;
  }

  private static LoyaltyLedger createLedger(Id memberId, Id currencyId, Id subtypeId, Id journalId, String eventType, Decimal points) {
    LoyaltyLedger ledger = new LoyaltyLedger();
    ledger.EventType = eventType;
    ledger.LoyaltyProgramMemberId = memberId;
    ledger.LoyaltyProgramCurrencyId = currencyId;
    ledger.LoyaltyPgmCrcySubtypeId = subtypeId;
    ledger.Points = points;
    ledger.ActivityDate = Datetime.newInstance(2026, 5, 18, 0, 0, 0);
    ledger.ExpiryDate = eventType == 'Credit' ? Date.newInstance(2028, 5, 18) : null;
    ledger.TransactionJournalId = journalId;
    return ledger;
  }

  private static GdPointRefreshStage__c createPlanStage(
    Id runId,
    String stageType,
    String eventKey,
    String originKey,
    String pointTypeCode,
    Decimal points,
    Id ledgerId,
    Integer sequence
  ) {
    GdPointRefreshStage__c stage = baseStage(runId, stageType, eventKey, sequence);
    stage.EventType__c = stageType == 'PLAN_CREDIT' ? GdPointRefreshEngine.EVENT_CREDIT : GdPointRefreshEngine.EVENT_DEBIT;
    stage.SourceKey__c = eventKey;
    stage.OriginKey__c = originKey;
    stage.PointTypeCode__c = pointTypeCode;
    stage.Points__c = points;
    stage.RemainingPoints__c = stageType == 'PLAN_CREDIT' ? points : 0;
    stage.TargetLedgerId__c = String.valueOf(ledgerId);
    return stage;
  }

  private static GdPointRefreshStage__c createTraceStage(
    Id runId,
    String eventKey,
    String sourceKey,
    String originKey,
    Decimal points,
    Integer sequence
  ) {
    GdPointRefreshStage__c stage = baseStage(runId, 'PLAN_TRACE', eventKey, sequence);
    stage.EventType__c = 'Debit';
    stage.SourceKey__c = sourceKey;
    stage.OriginKey__c = originKey;
    stage.PointTypeCode__c = '-';
    stage.Points__c = points;
    stage.RemainingPoints__c = 0;
    return stage;
  }

  private static GdPointRefreshStage__c baseStage(Id runId, String stageType, String eventKey, Integer sequence) {
    Date eventDate = Date.newInstance(2026, 5, 18).addDays(sequence);
    GdPointRefreshStage__c stage = new GdPointRefreshStage__c();
    stage.Run__c = runId;
    stage.StageType__c = stageType;
    stage.EventDate__c = eventDate;
    stage.Sequence__c = sequence;
    stage.EventKey__c = eventKey;
    stage.SaleNo__c = '-';
    stage.ExpiryDate__c = eventDate.addYears(2);
    stage.SortKey__c = GdPointRefreshStagedService.buildSortKey(eventDate, sequence, eventKey);
    stage.TargetJournalId__c = '-';
    stage.TargetLedgerId__c = '-';
    return stage;
  }

  private class TestData {
    LoyaltyProgramMember member;
    LoyaltyProgramCurrency pointCurrency;
    LoyaltyPgmCurrencySubtype subtype;
    LoyaltyLedger creditLedger;
    LoyaltyLedger debitLedger;
    GdPointRefreshRun__c run;
  }
}