@IsTest
private class GdPointRefreshStageCollectBatchTest {
  private static Integer nextJournalId = 1;

  @IsTest
  static void execute_collectsCreditAndDebitSourceRows() {
    GdPointRefreshRun__c run = createRun('COLLECT-DIRECT', true);
    GdPointRefreshStageCollectBatch batch = new GdPointRefreshStageCollectBatch(run.Id);
    batch.start(null);

    TransactionJournal credit = createJournal(Date.newInstance(2026, 5, 18), '01', '01', 100, false);
    TransactionJournal debit = createJournal(Date.newInstance(2026, 5, 19), '81', '01', 40, false);
    TransactionJournal skippedZero = createJournal(Date.newInstance(2026, 5, 20), '01', '01', 0, false);
    TransactionJournal skippedOld = createJournal(Date.newInstance(2026, 5, 17), '01', '01', 80, false);

    Test.startTest();
    batch.execute(null, new List<SObject>{ credit, debit, skippedZero, skippedOld });
    batch.finish(null);
    Test.stopTest();

    List<GdPointRefreshStage__c> stages = [
      SELECT
        StageType__c,
        EventType__c,
        EventDate__c,
        Sequence__c,
        SaleNo__c,
        Points__c,
        RemainingPoints__c,
        OriginKey__c,
        PointTypeCode__c,
        TargetJournalId__c,
        TargetLedgerId__c
      FROM GdPointRefreshStage__c
      WHERE Run__c = :run.Id
      ORDER BY Sequence__c
    ];
    System.assertEquals(2, stages.size());
    System.assertEquals('SOURCE_TJ', stages[0].StageType__c);
    System.assertEquals(GdPointRefreshEngine.EVENT_CREDIT, stages[0].EventType__c);
    System.assertEquals(GdPointRefreshEngine.EVENT_DEBIT, stages[1].EventType__c);
    System.assertEquals(1000, Integer.valueOf(stages[0].Sequence__c));
    System.assertEquals('-', stages[0].SaleNo__c);
    System.assertEquals(100, stages[0].Points__c);
    System.assertEquals(0, stages[0].RemainingPoints__c);
    System.assertEquals('-', stages[0].OriginKey__c);
    System.assertEquals('-', stages[0].PointTypeCode__c);
    System.assertEquals('-', stages[0].TargetJournalId__c);
    System.assertEquals('-', stages[0].TargetLedgerId__c);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Staged', refreshedRun.Status__c);
    System.assertEquals('SOURCE_COLLECTED_2', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void finish_includesExistingOpeningEventsInCount() {
    GdPointRefreshRun__c run = createRun('COLLECT-OPENING', false);
    insert createOpeningStage(run.Id, 'OPENING-1', 1);

    GdPointRefreshStageCollectBatch batch = new GdPointRefreshStageCollectBatch(run.Id, false, false);
    batch.start(null);

    Test.startTest();
    batch.finish(null);
    Test.stopTest();

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Staged', refreshedRun.Status__c);
    System.assertEquals('SOURCE_COLLECTED_1', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void batchExecution_withNoTransactionJournalsMarksRunStaged() {
    GdPointRefreshRun__c run = createRun('COLLECT-BATCH', true);

    Test.startTest();
    Database.executeBatch(new GdPointRefreshStageCollectBatch(run.Id), 200);
    Test.stopTest();

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Staged', refreshedRun.Status__c);
    System.assertEquals('SOURCE_COLLECTED_0', refreshedRun.CurrentStep__c);
  }

  private static GdPointRefreshRun__c createRun(String memberNo, Boolean useCreatedDateCutoff) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = memberNo;
    run.MemberId__c = '0lM000000000001AAA';
    run.OpenDate__c = Date.newInstance(2026, 5, 18);
    run.UseCreatedDateCutoff__c = useCreatedDateCutoff;
    run.MigrationCutoffDateTime__c = Datetime.newInstance(2026, 5, 18, 0, 0, 0);
    run.Status__c = 'Created';
    run.CurrentStep__c = 'READY';
    insert run;
    return run;
  }

  private static TransactionJournal createJournal(Date activityDate, String paymentMethod, String depositType, Decimal amount, Boolean deleted) {
    TransactionJournal tj = new TransactionJournal();
    tj.Id = fakeTransactionJournalId(nextJournalId++);
    tj.ActivityDate = Datetime.newInstance(activityDate, Time.newInstance(0, 0, 0, 0));
    tj.PaymentMethod = paymentMethod;
    tj.DepositType__c = depositType;
    tj.TransactionAmount = amount;
    tj.IsDeleted__c = deleted;
    return tj;
  }

  private static Id fakeTransactionJournalId(Integer sequence) {
    String suffix = String.valueOf(sequence).leftPad(12, '0');
    return (Id) ('0lV' + suffix + 'AAA');
  }

  private static GdPointRefreshStage__c createOpeningStage(Id runId, String eventKey, Integer sequence) {
    GdPointRefreshStage__c stage = new GdPointRefreshStage__c();
    stage.Run__c = runId;
    stage.StageType__c = 'EVENT';
    stage.EventDate__c = Date.newInstance(2026, 5, 18);
    stage.Sequence__c = sequence;
    stage.EventType__c = GdPointRefreshEngine.EVENT_CREDIT;
    stage.EventKey__c = eventKey;
    stage.SourceKey__c = eventKey;
    stage.SaleNo__c = '-';
    stage.OriginKey__c = eventKey;
    stage.PointTypeCode__c = '04';
    stage.Points__c = 100;
    stage.RemainingPoints__c = 100;
    stage.ExpiryDate__c = Date.newInstance(2028, 5, 18);
    stage.SortKey__c = GdPointRefreshStagedService.buildSortKey(stage.EventDate__c, sequence, eventKey);
    stage.TargetJournalId__c = '-';
    stage.TargetLedgerId__c = '-';
    return stage;
  }
}