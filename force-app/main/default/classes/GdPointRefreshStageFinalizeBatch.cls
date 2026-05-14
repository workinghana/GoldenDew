public without sharing class GdPointRefreshStageFinalizeBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';
  private Id runId;
  private Boolean cleanupAfterFinalize;

  public GdPointRefreshStageFinalizeBatch(Id runId, Boolean cleanupAfterFinalize) {
    this.runId = runId;
    this.cleanupAfterFinalize = cleanupAfterFinalize == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    return Database.getQueryLocator([
      SELECT Id, MemberId__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    GdPointRefreshRun__c run = (GdPointRefreshRun__c) scope[0];
    Id memberId = (Id) run.MemberId__c;

    Decimal totalAccrued = sumStagePoints('PLAN_CREDIT');
    Decimal totalRedeemed = sumStagePoints('PLAN_DEBIT') + sumStagePoints('PLAN_CREDIT_CANCEL_DEBIT');

    List<LoyaltyMemberCurrency> lmcs = [
      SELECT Id, TotalPointsAccrued, TotalPointsRedeemed
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :memberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
      LIMIT 1
    ];
    if (!lmcs.isEmpty()) {
      lmcs[0].TotalPointsAccrued = totalAccrued;
      lmcs[0].TotalPointsRedeemed = totalRedeemed;
      update lmcs[0];
    }

    GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger(memberId);
  }

  public void finish(Database.BatchableContext context) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'Completed';
    run.CurrentStep__c = cleanupAfterFinalize ? 'COMPLETED_CLEANUP_QUEUE' : 'COMPLETED';
    update run;

    if (cleanupAfterFinalize) {
      Database.executeBatch(new GdPointRefreshStageCleanupBatch(runId), 2000);
    }
  }

  private Decimal sumStagePoints(String stageType) {
    AggregateResult[] rows = [
      SELECT SUM(Points__c) total
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId AND StageType__c = :stageType
    ];
    if (rows.isEmpty() || rows[0].get('total') == null) {
      return 0;
    }
    return (Decimal) rows[0].get('total');
  }
}