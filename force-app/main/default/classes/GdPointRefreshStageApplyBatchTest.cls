@IsTest
private class GdPointRefreshStageApplyBatchTest {
  @IsTest
  static void start_throwsWhenRunIdIsMissing() {
    GdPointRefreshStageApplyBatch batch = new GdPointRefreshStageApplyBatch(null, true, false);

    try {
      batch.start(null);
      System.assert(false, 'runId가 없으면 예외가 발생해야 합니다.');
    } catch (CustomException e) {
      System.assertNotEquals(null, e);
    }
  }

  @IsTest
  static void execute_returnsWhenScopeIsEmpty() {
    GdPointRefreshRun__c run = createRun('EMPTY-SCOPE-MEMBER');
    GdPointRefreshStageApplyBatch batch = new GdPointRefreshStageApplyBatch(run.Id, true, false);

    Test.startTest();
    batch.execute(null, new List<SObject>());
    batch.execute(null, null);
    Test.stopTest();

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('Planned', refreshedRun.Status__c);
    System.assertEquals('READY', refreshedRun.CurrentStep__c);
  }

  @IsTest
  static void execute_marksRunAsFailedWhenApplyServiceFails() {
    GdPointRefreshRun__c run = createRun('NO-LOYALTY-MEMBER');
    GdPointRefreshStageApplyBatch batch = new GdPointRefreshStageApplyBatch(run.Id, true, false);

    Test.startTest();
    batch.execute(null, new List<SObject>{ run });
    Test.stopTest();

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('ApplyFailed', refreshedRun.Status__c);
    System.assert(refreshedRun.CurrentStep__c.startsWith('APPLY_FAILED:'));
    System.assert(refreshedRun.CurrentStep__c.length() <= 255);
  }

  @IsTest
  static void batchExecution_updatesRunWhenApplyServiceFails() {
    GdPointRefreshRun__c run = createRun('BATCH-NO-LOYALTY-MEMBER');

    Test.startTest();
    Database.executeBatch(new GdPointRefreshStageApplyBatch(run.Id, false, true), 1);
    Test.stopTest();

    GdPointRefreshRun__c refreshedRun = [
      SELECT Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :run.Id
    ];
    System.assertEquals('ApplyFailed', refreshedRun.Status__c);
    System.assert(refreshedRun.CurrentStep__c.startsWith('APPLY_FAILED:'));
  }

  private static GdPointRefreshRun__c createRun(String memberNo) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = memberNo;
    run.MemberId__c = '0lM000000000001AAA';
    run.OpenDate__c = Date.newInstance(2026, 5, 18);
    run.Status__c = 'Planned';
    run.CurrentStep__c = 'READY';
    insert run;
    return run;
  }
}
