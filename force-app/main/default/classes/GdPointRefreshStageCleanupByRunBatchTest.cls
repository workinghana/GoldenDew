@IsTest
private class GdPointRefreshStageCleanupByRunBatchTest {
  @IsTest
  static void start_throwsWhenRunIdsAreMissing() {
    assertStartThrows(new GdPointRefreshStageCleanupByRunBatch(null));
    assertStartThrows(new GdPointRefreshStageCleanupByRunBatch(new Set<Id>()));
  }

  @IsTest
  static void execute_deletesStageRowsInScope() {
    GdPointRefreshRun__c run = createRun('DIRECT-EXECUTE-RUN');
    List<GdPointRefreshStage__c> stages = new List<GdPointRefreshStage__c>{ createStage(run.Id, 'DIRECT-1', 1), createStage(run.Id, 'DIRECT-2', 2) };
    insert stages;

    GdPointRefreshStageCleanupByRunBatch batch = new GdPointRefreshStageCleanupByRunBatch(new Set<Id>{ run.Id });

    Test.startTest();
    batch.execute(null, new List<SObject>{ stages[0], stages[1] });
    batch.finish(null);
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM GdPointRefreshStage__c WHERE Run__c = :run.Id]);

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('SupersededCleaned', refreshedRun.Status__c);
    System.assertEquals('SUPERSEDED_CLEANED_STAGE_ROWS_2', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void batchExecution_deletesStagesForAllRunsAndMarksRuns() {
    GdPointRefreshRun__c firstRun = createRun('BATCH-RUN-1');
    GdPointRefreshRun__c secondRun = createRun('BATCH-RUN-2');
    GdPointRefreshRun__c untouchedRun = createRun('BATCH-RUN-3');

    insert new List<GdPointRefreshStage__c>{
      createStage(firstRun.Id, 'BATCH-1A', 1),
      createStage(firstRun.Id, 'BATCH-1B', 2),
      createStage(secondRun.Id, 'BATCH-2A', 1),
      createStage(untouchedRun.Id, 'BATCH-3A', 1)
    };

    Test.startTest();
    Database.executeBatch(new GdPointRefreshStageCleanupByRunBatch(new Set<Id>{ firstRun.Id, secondRun.Id }), 200);
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM GdPointRefreshStage__c WHERE Run__c IN :new Set<Id>{ firstRun.Id, secondRun.Id }]);
    System.assertEquals(1, [SELECT COUNT() FROM GdPointRefreshStage__c WHERE Run__c = :untouchedRun.Id]);

    Map<Id, GdPointRefreshRun__c> runById = new Map<Id, GdPointRefreshRun__c>(
      [
        SELECT Status__c, CurrentStep__c
        FROM GdPointRefreshRun__c
        WHERE Id IN :new Set<Id>{ firstRun.Id, secondRun.Id, untouchedRun.Id }
      ]
    );
    System.assertEquals('SupersededCleaned', runById.get(firstRun.Id).Status__c);
    System.assertEquals('SupersededCleaned', runById.get(secondRun.Id).Status__c);
    System.assertEquals('Staged', runById.get(untouchedRun.Id).Status__c);
    System.assertEquals('SUPERSEDED_CLEANED_STAGE_ROWS_3', runById.get(firstRun.Id).CurrentStep__c);
    System.assertEquals('SUPERSEDED_CLEANED_STAGE_ROWS_3', runById.get(secondRun.Id).CurrentStep__c);
  }

  private static void assertStartThrows(GdPointRefreshStageCleanupByRunBatch batch) {
    try {
      batch.start(null);
      System.assert(false, 'runIds가 없으면 예외가 발생해야 합니다.');
    } catch (CustomException e) {
      System.assertNotEquals(null, e);
    }
  }

  private static GdPointRefreshRun__c createRun(String memberNo) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = memberNo;
    run.MemberId__c = '0lM000000000001AAA';
    run.OpenDate__c = Date.newInstance(2026, 5, 18);
    run.Status__c = 'Staged';
    run.CurrentStep__c = 'SOURCE_COLLECTED';
    insert run;
    return run;
  }

  private static GdPointRefreshStage__c createStage(Id runId, String eventKey, Integer sequence) {
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
