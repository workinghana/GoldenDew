public without sharing class GdPointRefreshStageCleanupByRunBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Set<Id> runIds = new Set<Id>();
  private Integer deletedCount = 0;

  public GdPointRefreshStageCleanupByRunBatch(Set<Id> runIds) {
    if (runIds != null) {
      this.runIds.addAll(runIds);
    }
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    if (runIds.isEmpty()) {
      throw new CustomException(400, 'runIds is required.');
    }
    return Database.getQueryLocator([
      SELECT Id
      FROM GdPointRefreshStage__c
      WHERE Run__c IN :runIds
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
      SELECT Id, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id IN :runIds
    ];
    for (GdPointRefreshRun__c run : runs) {
      run.Status__c = 'SupersededCleaned';
      run.CurrentStep__c = 'SUPERSEDED_CLEANED_STAGE_ROWS_' + deletedCount;
    }
    if (!runs.isEmpty()) {
      update runs;
    }
  }
}