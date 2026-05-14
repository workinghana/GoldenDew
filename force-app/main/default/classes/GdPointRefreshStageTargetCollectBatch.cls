public without sharing class GdPointRefreshStageTargetCollectBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Id runId;
  private Id memberId;
  private Integer targetCount = 0;
  private Boolean autoContinue = false;
  private Boolean cleanupAfterComplete = false;
  private Boolean clearedExistingTargets = false;

  public GdPointRefreshStageTargetCollectBatch(Id runId) {
    this.runId = runId;
  }

  public GdPointRefreshStageTargetCollectBatch(Id runId, Boolean autoContinue, Boolean cleanupAfterComplete) {
    this.runId = runId;
    this.autoContinue = autoContinue == true;
    this.cleanupAfterComplete = cleanupAfterComplete == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    GdPointRefreshRun__c run = [
      SELECT Id, MemberId__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    memberId = (Id) run.MemberId__c;
    return Database.getQueryLocator([
      SELECT
        Id,
        Points,
        ActivityDate,
        ExpiryDate,
        EventType,
        AdditionalNotes,
        TransactionJournalId,
        TransactionJournal.JournalSubType.Name,
        TransactionJournal.AdditionalNotes__c,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.SaleId__r.SaleNo__c,
        LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (!clearedExistingTargets) {
      deleteExistingTargetRows();
      clearedExistingTargets = true;
    }
    List<GdPointRefreshStage__c> targets = new List<GdPointRefreshStage__c>();
    Integer seq = targetCount;
    for (SObject row : scope) {
      LoyaltyLedger ll = (LoyaltyLedger) row;
      if (isPreservedManualCredit(ll)) {
        continue;
      }
      Date eventDate = ll.ActivityDate == null ? Date.today() : ll.ActivityDate.date();
      GdPointRefreshStage__c stage = new GdPointRefreshStage__c();
      stage.Run__c = runId;
      stage.StageType__c = 'TARGET_LEDGER';
      stage.EventType__c = String.isBlank(ll.EventType) ? '-' : ll.EventType;
      stage.EventDate__c = eventDate;
      stage.Sequence__c = seq++;
      stage.EventKey__c = String.valueOf(ll.Id);
      stage.SourceKey__c = String.valueOf(ll.Id);
      stage.SaleNo__c = resolveSaleNo(ll);
      if (String.isBlank(stage.SaleNo__c)) stage.SaleNo__c = '-';
      stage.OriginKey__c = ll.TransactionJournalId == null ? '-' : String.valueOf(ll.TransactionJournalId);
      stage.PointTypeCode__c = ll.LoyaltyPgmCrcySubtype == null ? '-' : String.valueOf(ll.LoyaltyPgmCrcySubtype.PointTypeCode__c);
      stage.Points__c = ll.Points == null ? 0 : ll.Points;
      stage.RemainingPoints__c = 0;
      stage.ExpiryDate__c = ll.ExpiryDate == null ? eventDate.addYears(2) : ll.ExpiryDate;
      stage.SortKey__c = GdPointRefreshStagedService.buildSortKey(eventDate, stage.Sequence__c.intValue(), stage.EventKey__c);
      stage.TargetLedgerId__c = String.valueOf(ll.Id);
      stage.TargetJournalId__c = ll.TransactionJournalId == null ? '-' : String.valueOf(ll.TransactionJournalId);
      targets.add(stage);
    }
    if (!targets.isEmpty()) {
      insert targets;
      targetCount += targets.size();
    }
  }

  public void finish(Database.BatchableContext context) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'TargetCollected';
    run.CurrentStep__c = 'TARGET_LEDGER_ROWS_' + targetCount;
    update run;
    if (autoContinue) {
      Database.executeBatch(new GdPointRefreshStageDeleteTraceBatch(runId, true, cleanupAfterComplete), 2000);
    }
  }

  private static Boolean isPreservedManualCredit(LoyaltyLedger ll) {
    if (ll == null || ll.EventType != 'Credit') {
      return false;
    }
    String subTypeName = ll.TransactionJournal != null && ll.TransactionJournal.JournalSubType != null ? ll.TransactionJournal.JournalSubType.Name : null;
    String notes = ((ll.TransactionJournal == null ? '' : String.valueOf(ll.TransactionJournal.AdditionalNotes__c)) + ';' + String.valueOf(ll.AdditionalNotes)).toUpperCase();
    if (notes.contains('OPTC') || notes.contains('RETURN_DEPOSIT_DELETE') || notes.contains('RESTORE') || notes.contains('ORIGIN_CREDIT_LL')) {
      return false;
    }
    if (String.isNotBlank(resolveSaleNo(ll))) {
      return false;
    }
    return subTypeName == 'Api Forced Credit' || subTypeName == 'Manual Points Credit';
  }

  private void deleteExistingTargetRows() {
    List<GdPointRefreshStage__c> rows = [
      SELECT Id
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId AND StageType__c = 'TARGET_LEDGER'
      LIMIT 10000
    ];
    while (!rows.isEmpty()) {
      delete rows;
      rows = [
        SELECT Id
        FROM GdPointRefreshStage__c
        WHERE Run__c = :runId AND StageType__c = 'TARGET_LEDGER'
        LIMIT 10000
      ];
    }
  }

  private static String resolveSaleNo(LoyaltyLedger ll) {
    if (ll == null || ll.TransactionJournal == null) {
      return null;
    }
    if (ll.TransactionJournal.SaleId__r != null && String.isNotBlank(ll.TransactionJournal.SaleId__r.SaleNo__c)) {
      return ll.TransactionJournal.SaleId__r.SaleNo__c;
    }
    if (ll.TransactionJournal.Order != null && String.isNotBlank(ll.TransactionJournal.Order.SaleNo__c)) {
      return ll.TransactionJournal.Order.SaleNo__c;
    }
    return null;
  }
}