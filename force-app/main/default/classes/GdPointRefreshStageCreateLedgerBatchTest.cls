@IsTest
private class GdPointRefreshStageCreateLedgerBatchTest {
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
    GdPointRefreshStageCreateLedgerBatch batch = new GdPointRefreshStageCreateLedgerBatch(null);

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
    GdPointRefreshStageCreateLedgerBatch batch = new GdPointRefreshStageCreateLedgerBatch(data.run.Id);

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
    System.assertEquals('LedgersCreated', refreshedRun.Status__c);
    System.assertEquals('CREATED_JOURNALS_0_LEDGERS_0', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void execute_createsJournalsLedgersAndUpdatesStages() {
    TestData data = setupData('CREATE');
    List<GdPointRefreshStage__c> stages = new List<GdPointRefreshStage__c>{
      createStage(data.run.Id, 'PLAN_CREDIT', 'OPENING:MEM-CREATE:04', 'OPENING:MEM-CREATE:04', '04', 100, 100, 1),
      createStage(data.run.Id, 'PLAN_DEBIT', 'DEBIT:TJ:001', 'OPENING:MEM-CREATE:04', '-', 40, 0, 2),
      createStage(data.run.Id, 'PLAN_CREDIT_CANCEL_DEBIT', 'CREDIT_CANCEL:TJ:002', 'OPENING:MEM-CREATE:04', '04', 20, 0, 3)
    };
    insert stages;

    GdPointRefreshStageCreateLedgerBatch batch = new GdPointRefreshStageCreateLedgerBatch(data.run.Id);

    Test.startTest();
    batch.execute(null, new List<SObject>{ stages[0], stages[1], stages[2] });
    batch.finish(null);
    Test.stopTest();

    List<TransactionJournal> journals = [
      SELECT Id, MemberId, LoyaltyProgramId, Status, TransactionAmount, JournalType.Name, JournalSubType.Name, AdditionalNotes__c
      FROM TransactionJournal
      WHERE MemberId = :data.member.Id
      ORDER BY TransactionAmount DESC
    ];
    System.assertEquals(3, journals.size());

    List<LoyaltyLedger> ledgers = [
      SELECT
        Id,
        EventType,
        LoyaltyProgramMemberId,
        LoyaltyProgramCurrencyId,
        LoyaltyPgmCrcySubtypeId,
        Points,
        ExpiryDate,
        TransactionJournalId,
        AdditionalNotes
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :data.member.Id
      ORDER BY Points DESC
    ];
    System.assertEquals(3, ledgers.size());
    System.assertEquals('Credit', ledgers[0].EventType);
    System.assertEquals(data.pointCurrency.Id, ledgers[0].LoyaltyProgramCurrencyId);
    System.assertEquals(data.subtype.Id, ledgers[0].LoyaltyPgmCrcySubtypeId);
    System.assertNotEquals(null, ledgers[0].TransactionJournalId);

    List<GdPointRefreshStage__c> updatedStages = [
      SELECT TargetJournalId__c, TargetLedgerId__c
      FROM GdPointRefreshStage__c
      WHERE Run__c = :data.run.Id
    ];
    for (GdPointRefreshStage__c stage : updatedStages) {
      System.assertNotEquals('-', stage.TargetJournalId__c);
      System.assertNotEquals('-', stage.TargetLedgerId__c);
    }

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :data.run.Id
    ];
    System.assertEquals('LedgersCreated', refreshedRun.Status__c);
    System.assertEquals('CREATED_JOURNALS_3_LEDGERS_3', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void batchExecution_processesPlanRows() {
    TestData data = setupData('BATCH');
    insert createStage(data.run.Id, 'PLAN_CREDIT', 'OPENING:MEM-BATCH:04', 'OPENING:MEM-BATCH:04', '04', 70, 70, 1);

    Test.startTest();
    Database.executeBatch(new GdPointRefreshStageCreateLedgerBatch(data.run.Id), 200);
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM TransactionJournal WHERE MemberId = :data.member.Id]);
    System.assertEquals(1, [SELECT COUNT() FROM LoyaltyLedger WHERE LoyaltyProgramMemberId = :data.member.Id]);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :data.run.Id
    ];
    System.assertEquals('LedgersCreated', refreshedRun.Status__c);
    System.assertEquals('CREATED_JOURNALS_1_LEDGERS_1', refreshedRun.CurrentStep__c);
  }

  private static TestData setupData(String suffix) {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    Contact contactRecord = new Contact(LastName = 'StageCreateLedger ' + suffix, MemberNo__c = 'MEM-' + suffix);
    insert contactRecord;

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Stage Create Ledger Program ' + suffix, IsPrimary = true);
    insert program;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ProgramId = program.Id,
      MembershipNumber = 'MEM-' + suffix,
      MemberType = 'Individual',
      ContactId = contactRecord.Id,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert member;

    LoyaltyProgramCurrency currencyRecord = new LoyaltyProgramCurrency(
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
    insert currencyRecord;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = currencyRecord.Id,
      Name = 'Stage Create Ledger Subtype ' + suffix,
      PointTypeCode__c = '04',
      UsagePriorityNumber = 1
    );
    insert subtype;

    ensureJournalConfig();

    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = 'MEM-' + suffix;
    run.MemberId__c = member.Id;
    run.OpenDate__c = Date.newInstance(2026, 5, 18);
    run.Status__c = 'Planned';
    run.CurrentStep__c = 'PLAN_READY';
    insert run;

    TestData data = new TestData();
    data.member = member;
    data.pointCurrency = currencyRecord;
    data.subtype = subtype;
    data.run = run;
    return data;
  }

  private static void ensureJournalConfig() {
    JournalType accrualType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    JournalType redemptionType = new JournalType(Name = 'Redemption', ProcessType = 'Loyalty');
    JournalType accrualReversalType = new JournalType(Name = 'Accrual Reversal', ProcessType = 'Loyalty');
    insert new List<JournalType>{ accrualType, redemptionType, accrualReversalType };

    insert new List<JournalSubType>{
      new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = accrualReversalType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual Reversal', JournalTypeId = accrualReversalType.Id)
    };
  }

  private static GdPointRefreshStage__c createStage(
    Id runId,
    String stageType,
    String eventKey,
    String originKey,
    String pointTypeCode,
    Decimal points,
    Decimal remainingPoints,
    Integer sequence
  ) {
    GdPointRefreshStage__c stage = new GdPointRefreshStage__c();
    stage.Run__c = runId;
    stage.StageType__c = stageType;
    stage.EventType__c = stageType == 'PLAN_CREDIT' ? GdPointRefreshEngine.EVENT_CREDIT : GdPointRefreshEngine.EVENT_DEBIT;
    stage.EventDate__c = Date.newInstance(2026, 5, 18).addDays(sequence);
    stage.Sequence__c = sequence;
    stage.EventKey__c = eventKey;
    stage.SourceKey__c = eventKey;
    stage.SaleNo__c = '-';
    stage.OriginKey__c = originKey;
    stage.PointTypeCode__c = pointTypeCode;
    stage.Points__c = points;
    stage.RemainingPoints__c = remainingPoints;
    stage.ExpiryDate__c = stage.EventDate__c.addYears(2);
    stage.SortKey__c = GdPointRefreshStagedService.buildSortKey(stage.EventDate__c, sequence, eventKey);
    stage.TargetJournalId__c = '-';
    stage.TargetLedgerId__c = '-';
    return stage;
  }

  private class TestData {
    LoyaltyProgramMember member;
    LoyaltyProgramCurrency pointCurrency;
    LoyaltyPgmCurrencySubtype subtype;
    GdPointRefreshRun__c run;
  }
}