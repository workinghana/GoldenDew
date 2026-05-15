@IsTest
private class GdPointRefreshStageDeleteJournalTest {
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
  static void execute_returnsWhenScopeHasNoValidJournalIds() {
    TestData data = setupData('EMPTY');
    GdPointRefreshStageDeleteJournalBatch batch = new GdPointRefreshStageDeleteJournalBatch(data.run.Id);

    Test.startTest();
    batch.execute(null, new List<SObject>{ createTargetStage(data.run.Id, '-', 1), createTargetStage(data.run.Id, 'NOT_AN_ID', 2) });
    batch.finish(null);
    Test.stopTest();

    System.assertEquals(1, [SELECT COUNT() FROM TransactionJournal WHERE Id = :data.journal.Id]);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :data.run.Id
    ];
    System.assertEquals('TargetDeleted', refreshedRun.Status__c);
    System.assertEquals('DELETED_JOURNALS_0', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void execute_deletesValidTargetJournalsAndMarksRun() {
    TestData data = setupData('DIRECT');
    GdPointRefreshStage__c validStage = createTargetStage(data.run.Id, String.valueOf(data.journal.Id), 1);
    GdPointRefreshStage__c invalidStage = createTargetStage(data.run.Id, '-', 2);

    GdPointRefreshStageDeleteJournalBatch batch = new GdPointRefreshStageDeleteJournalBatch(data.run.Id);

    Test.startTest();
    batch.execute(null, new List<SObject>{ validStage, invalidStage });
    batch.finish(null);
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal WHERE Id = :data.journal.Id]);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :data.run.Id
    ];
    System.assertEquals('TargetDeleted', refreshedRun.Status__c);
    System.assertEquals('DELETED_JOURNALS_1', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void batchExecution_deletesOnlyTargetLedgerStageJournals() {
    TestData data = setupData('BATCH');
    TransactionJournal untouchedJournal = createJournal(data.member.Id, data.program.Id, data.journalType.Id, data.journalSubType.Id, 20);
    insert untouchedJournal;

    insert new List<GdPointRefreshStage__c>{
      createTargetStage(data.run.Id, String.valueOf(data.journal.Id), 1),
      createNonTargetStage(data.run.Id, String.valueOf(untouchedJournal.Id), 2),
      createTargetStage(data.run.Id, '-', 3)
    };

    Test.startTest();
    Database.executeBatch(new GdPointRefreshStageDeleteJournalBatch(data.run.Id), 200);
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal WHERE Id = :data.journal.Id]);
    System.assertEquals(1, [SELECT COUNT() FROM TransactionJournal WHERE Id = :untouchedJournal.Id]);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :data.run.Id
    ];
    System.assertEquals('TargetDeleted', refreshedRun.Status__c);
    System.assertEquals('DELETED_JOURNALS_1', refreshedRun.CurrentStep__c);
  }

  private static TestData setupData(String suffix) {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    Contact contactRecord = new Contact(LastName = 'DeleteJournal ' + suffix, MemberNo__c = 'DEL-J-' + suffix);
    insert contactRecord;

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Delete Journal Program ' + suffix, IsPrimary = true);
    insert program;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ProgramId = program.Id,
      MembershipNumber = 'DEL-J-' + suffix,
      MemberType = 'Individual',
      ContactId = contactRecord.Id,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert member;

    JournalType journalType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert journalType;

    JournalSubType journalSubType = new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = journalType.Id);
    insert journalSubType;

    TransactionJournal journal = createJournal(member.Id, program.Id, journalType.Id, journalSubType.Id, 100);
    insert journal;

    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = 'DEL-J-' + suffix;
    run.MemberId__c = member.Id;
    run.OpenDate__c = Date.newInstance(2026, 5, 18);
    run.Status__c = 'TargetCollected';
    run.CurrentStep__c = 'TARGET_READY';
    insert run;

    TestData data = new TestData();
    data.program = program;
    data.member = member;
    data.journalType = journalType;
    data.journalSubType = journalSubType;
    data.journal = journal;
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
    journal.AdditionalNotes__c = 'DELETE_JOURNAL_TEST';
    return journal;
  }

  private static GdPointRefreshStage__c createTargetStage(Id runId, String targetJournalId, Integer sequence) {
    GdPointRefreshStage__c stage = baseStage(runId, 'TARGET_LEDGER', 'TARGET-' + String.valueOf(sequence), sequence);
    stage.TargetJournalId__c = targetJournalId;
    return stage;
  }

  private static GdPointRefreshStage__c createNonTargetStage(Id runId, String targetJournalId, Integer sequence) {
    GdPointRefreshStage__c stage = baseStage(runId, 'PLAN_CREDIT', 'NON-TARGET-' + String.valueOf(sequence), sequence);
    stage.TargetJournalId__c = targetJournalId;
    return stage;
  }

  private static GdPointRefreshStage__c baseStage(Id runId, String stageType, String eventKey, Integer sequence) {
    Date eventDate = Date.newInstance(2026, 5, 18).addDays(sequence);
    GdPointRefreshStage__c stage = new GdPointRefreshStage__c();
    stage.Run__c = runId;
    stage.StageType__c = stageType;
    stage.EventType__c = GdPointRefreshEngine.EVENT_CREDIT;
    stage.EventDate__c = eventDate;
    stage.Sequence__c = sequence;
    stage.EventKey__c = eventKey;
    stage.SourceKey__c = eventKey;
    stage.SaleNo__c = '-';
    stage.OriginKey__c = eventKey;
    stage.PointTypeCode__c = '04';
    stage.Points__c = 100;
    stage.RemainingPoints__c = 100;
    stage.ExpiryDate__c = eventDate.addYears(2);
    stage.SortKey__c = GdPointRefreshStagedService.buildSortKey(eventDate, sequence, eventKey);
    stage.TargetJournalId__c = '-';
    stage.TargetLedgerId__c = '-';
    return stage;
  }

  private class TestData {
    LoyaltyProgram program;
    LoyaltyProgramMember member;
    JournalType journalType;
    JournalSubType journalSubType;
    TransactionJournal journal;
    GdPointRefreshRun__c run;
  }
}
