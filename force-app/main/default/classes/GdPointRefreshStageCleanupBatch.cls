public without sharing class GdPointRefreshStageCleanupBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Id runId;
  private Integer deletedCount = 0;

  public GdPointRefreshStageCleanupBatch(Id runId) {
    this.runId = runId;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    return Database.getQueryLocator([
      SELECT Id
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    List<GdPointRefreshStage__c> rows = new List<GdPointRefreshStage__c>();
    for (SObject row : scope) {
      rows.add((GdPointRefreshStage__c) row);
    }
    if (!rows.isEmpty()) {
      deletedCount += rows.size();
      delete rows;
    }
  }

  public void finish(Database.BatchableContext context) {
    List<GdPointRefreshRun__c> runs = [
      SELECT Id, Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    if (!runs.isEmpty()) {
      Boolean keepAppliedStatus = runs[0].Status__c == 'Applied' || runs[0].Status__c == 'Completed';
      if (!keepAppliedStatus) {
        runs[0].Status__c = 'Cleaned';
      }
      runs[0].CurrentStep__c = keepAppliedStatus ? 'APPLIED_AND_CLEANED_STAGE_ROWS_' + deletedCount : 'CLEANED_STAGE_ROWS_' + deletedCount;
      update runs[0];
    }
  }
}