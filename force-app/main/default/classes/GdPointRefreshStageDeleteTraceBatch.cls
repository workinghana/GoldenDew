public without sharing class GdPointRefreshStageDeleteTraceBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Id runId;
  private Integer deletedCount = 0;
  private Boolean autoContinue = false;
  private Boolean cleanupAfterComplete = false;

  public GdPointRefreshStageDeleteTraceBatch(Id runId) {
    this.runId = runId;
  }

  public GdPointRefreshStageDeleteTraceBatch(Id runId, Boolean autoContinue, Boolean cleanupAfterComplete) {
    this.runId = runId;
    this.autoContinue = autoContinue == true;
    this.cleanupAfterComplete = cleanupAfterComplete == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    return Database.getQueryLocator([
      SELECT TargetLedgerId__c
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId AND StageType__c = 'TARGET_LEDGER'
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    Set<Id> ledgerIds = new Set<Id>();
    for (SObject row : scope) {
      Id ledgerId = toIdOrNull(((GdPointRefreshStage__c) row).TargetLedgerId__c);
      if (ledgerId != null) ledgerIds.add(ledgerId);
    }
    if (ledgerIds.isEmpty()) return;
    List<LoyaltyLedgerTraceability> traces = [
      SELECT Id
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId IN :ledgerIds OR DebitLoyaltyLedgerId IN :ledgerIds
      LIMIT 10000
    ];
    if (!traces.isEmpty()) {
      deletedCount += traces.size();
      delete traces;
    }
  }

  public void finish(Database.BatchableContext context) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'TargetTracesDeleted';
    run.CurrentStep__c = 'DELETED_TRACES_' + deletedCount;
    update run;
    if (autoContinue) {
      Database.executeBatch(new GdPointRefreshStageDeleteLedgerBatch(runId, true, cleanupAfterComplete), 2000);
    }
  }

  private static Id toIdOrNull(String value) {
    if (String.isBlank(value) || (value.length() != 15 && value.length() != 18)) return null;
    try { return (Id) value; } catch (Exception e) { return null; }
  }
}