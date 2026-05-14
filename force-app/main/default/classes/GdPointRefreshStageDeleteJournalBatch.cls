public without sharing class GdPointRefreshStageDeleteJournalBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Id runId;
  private Integer deletedCount = 0;
  private Boolean autoContinue = false;
  private Boolean cleanupAfterComplete = false;

  public GdPointRefreshStageDeleteJournalBatch(Id runId) {
    this.runId = runId;
  }

  public GdPointRefreshStageDeleteJournalBatch(Id runId, Boolean autoContinue, Boolean cleanupAfterComplete) {
    this.runId = runId;
    this.autoContinue = autoContinue == true;
    this.cleanupAfterComplete = cleanupAfterComplete == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator([
      SELECT TargetJournalId__c
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId AND StageType__c = 'TARGET_LEDGER' AND TargetJournalId__c != '-'
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    Set<Id> journalIds = new Set<Id>();
    for (SObject row : scope) {
      Id journalId = toIdOrNull(((GdPointRefreshStage__c) row).TargetJournalId__c);
      if (journalId != null) journalIds.add(journalId);
    }
    if (journalIds.isEmpty()) return;
    List<TransactionJournal> journals = [SELECT Id FROM TransactionJournal WHERE Id IN :journalIds];
    if (!journals.isEmpty()) {
      deletedCount += journals.size();
      delete journals;
    }
  }

  public void finish(Database.BatchableContext context) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'TargetDeleted';
    run.CurrentStep__c = 'DELETED_JOURNALS_' + deletedCount;
    update run;
    if (autoContinue) {
      Database.executeBatch(new GdPointRefreshStageCreateLedgerBatch(runId, true, cleanupAfterComplete), 200);
    }
  }

  private static Id toIdOrNull(String value) {
    if (String.isBlank(value) || (value.length() != 15 && value.length() != 18)) return null;
    try { return (Id) value; } catch (Exception e) { return null; }
  }
}