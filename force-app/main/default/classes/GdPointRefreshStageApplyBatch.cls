public without sharing class GdPointRefreshStageApplyBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Id runId;
  private Boolean dryRun;
  private Boolean cleanupAfterApply;
  private Boolean applySucceeded = false;
  private String finalStatus;
  private String finalStep;

  public GdPointRefreshStageApplyBatch(Id runId, Boolean dryRun, Boolean cleanupAfterApply) {
    this.runId = runId;
    this.dryRun = dryRun == true;
    this.cleanupAfterApply = cleanupAfterApply == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    return Database.getQueryLocator([
      SELECT Id, MemberNo__c, OpenDate__c, Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    GdPointRefreshRun__c run = (GdPointRefreshRun__c) scope[0];
    try {
      run.Status__c = dryRun ? 'ApplyDryRunning' : 'Applying';
      run.CurrentStep__c = dryRun ? 'APPLY_DRY_RUN_START' : 'APPLY_START';
      update run;

      GdPointRefreshApplyService.Request request = new GdPointRefreshApplyService.Request();
      request.memberNo = run.MemberNo__c;
      request.openDate = run.OpenDate__c;
      request.dryRun = dryRun;

      GdPointRefreshApplyService.ApplyResult result = new GdPointRefreshApplyService().refreshMember(request);

      applySucceeded = true;
      finalStatus = dryRun ? 'ApplyDryRunCompleted' : 'Applied';
      finalStep =
        (dryRun ? 'APPLY_DRY_RUN_DONE' : 'APPLY_DONE') +
        ':DJ=' +
        result.deleteJournalCount +
        ',DL=' +
        result.deleteLedgerCount +
        ',DT=' +
        result.deleteTraceCount +
        ',IJ=' +
        result.insertJournalCount +
        ',IL=' +
        result.insertLedgerCount +
        ',IT=' +
        result.insertTraceCount +
        ',BAL=' +
        result.finalBalance;
    } catch (Exception e) {
      applySucceeded = false;
      finalStatus = 'ApplyFailed';
      finalStep = 'APPLY_FAILED:' + truncate(e.getMessage(), 220);
    }

    GdPointRefreshRun__c updateRun = new GdPointRefreshRun__c(Id = run.Id);
    updateRun.Status__c = finalStatus;
    updateRun.CurrentStep__c = truncate(finalStep, 255);
    update updateRun;
  }

  public void finish(Database.BatchableContext context) {
    if (applySucceeded && !dryRun && cleanupAfterApply) {
      Database.executeBatch(new GdPointRefreshStageCleanupBatch(runId), 2000);
    }
  }

  private static String truncate(String value, Integer maxLength) {
    if (value == null || maxLength == null || value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }
}