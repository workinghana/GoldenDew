public without sharing class GdPointRefreshStageCreateTraceBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';
  private Id runId;
  private Integer traceCount = 0;
  private Boolean autoContinue = false;
  private Boolean cleanupAfterComplete = false;

  public GdPointRefreshStageCreateTraceBatch(Id runId) {
    this.runId = runId;
  }

  public GdPointRefreshStageCreateTraceBatch(Id runId, Boolean autoContinue, Boolean cleanupAfterComplete) {
    this.runId = runId;
    this.autoContinue = autoContinue == true;
    this.cleanupAfterComplete = cleanupAfterComplete == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    return Database.getQueryLocator([
      SELECT Id, EventType__c, EventKey__c, SourceKey__c, OriginKey__c, Points__c
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId AND StageType__c = 'PLAN_TRACE'
      ORDER BY SortKey__c
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    GdPointRefreshRun__c run = [
      SELECT Id, MemberId__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    Id memberId = (Id) run.MemberId__c;
    Id currencyId = [SELECT Id FROM LoyaltyProgramCurrency WHERE Name = :LOYALTY_PROGRAM_CURRENCY_NAME LIMIT 1].Id;

    Set<String> stageKeys = new Set<String>();
    for (SObject row : scope) {
      GdPointRefreshStage__c trace = (GdPointRefreshStage__c) row;
      if (String.isNotBlank(trace.SourceKey__c) && trace.SourceKey__c != '-') {
        stageKeys.add(trace.SourceKey__c);
      }
      if (String.isNotBlank(trace.OriginKey__c) && trace.OriginKey__c != '-') {
        stageKeys.add(trace.OriginKey__c);
      }
    }
    Map<String, GdPointRefreshStage__c> planByEventKey = loadPlanByEventKey(stageKeys);
    Map<String, Id> subtypeIdByPointType = loadSubtypeIdByPointType(planByEventKey.values());

    List<LoyaltyLedgerTraceability> traces = new List<LoyaltyLedgerTraceability>();
    for (SObject row : scope) {
      GdPointRefreshStage__c tracePlan = (GdPointRefreshStage__c) row;
      GdPointRefreshStage__c creditPlan = planByEventKey.get(tracePlan.SourceKey__c);
      GdPointRefreshStage__c debitPlan = planByEventKey.get(tracePlan.OriginKey__c);
      if (creditPlan == null || debitPlan == null || tracePlan.Points__c == null || tracePlan.Points__c <= 0) {
        continue;
      }
      Id creditLedgerId = toIdOrNull(creditPlan.TargetLedgerId__c);
      Id debitLedgerId = toIdOrNull(debitPlan.TargetLedgerId__c);
      if (creditLedgerId == null || debitLedgerId == null) {
        continue;
      }
      LoyaltyLedgerTraceability llt = new LoyaltyLedgerTraceability();
      llt.LoyaltyProgramMemberId = memberId;
      llt.LoyaltyProgramCurrencyId = currencyId;
      llt.LoyaltyPgmCurrencySubtypeId = subtypeIdByPointType.get(creditPlan.PointTypeCode__c);
      llt.CreditLoyaltyLedgerId = creditLedgerId;
      llt.DebitLoyaltyLedgerId = debitLedgerId;
      llt.Points = tracePlan.Points__c;
      llt.ActionType = tracePlan.EventType__c;
      traces.add(llt);
    }
    if (!traces.isEmpty()) {
      insert traces;
      traceCount += traces.size();
    }
  }

  public void finish(Database.BatchableContext context) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'TracesCreated';
    run.CurrentStep__c = 'CREATED_TRACES_' + traceCount;
    update run;
    if (autoContinue) {
      Database.executeBatch(new GdPointRefreshStageFinalizeBatch(runId, cleanupAfterComplete), 1);
    }
  }

  private Map<String, GdPointRefreshStage__c> loadPlanByEventKey(Set<String> stageKeys) {
    Map<String, GdPointRefreshStage__c> result = new Map<String, GdPointRefreshStage__c>();
    if (stageKeys == null || stageKeys.isEmpty()) {
      return result;
    }
    for (GdPointRefreshStage__c row : [
      SELECT EventKey__c, TargetLedgerId__c, PointTypeCode__c
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId AND EventKey__c IN :stageKeys
    ]) {
      result.put(row.EventKey__c, row);
    }
    return result;
  }

  private static Map<String, Id> loadSubtypeIdByPointType(List<GdPointRefreshStage__c> plans) {
    Set<String> pointTypeCodes = new Set<String>();
    if (plans != null) {
      for (GdPointRefreshStage__c plan : plans) {
        if (String.isNotBlank(plan.PointTypeCode__c) && plan.PointTypeCode__c != '-') {
          pointTypeCodes.add(plan.PointTypeCode__c);
        }
      }
    }
    Map<String, Id> result = new Map<String, Id>();
    if (pointTypeCodes.isEmpty()) {
      return result;
    }
    for (LoyaltyPgmCurrencySubtype subtype : [
      SELECT Id, PointTypeCode__c
      FROM LoyaltyPgmCurrencySubtype
      WHERE PointTypeCode__c IN :pointTypeCodes
    ]) {
      if (!result.containsKey(subtype.PointTypeCode__c)) {
        result.put(subtype.PointTypeCode__c, subtype.Id);
      }
    }
    return result;
  }

  private static Id toIdOrNull(String value) {
    if (String.isBlank(value) || (value.length() != 15 && value.length() != 18)) {
      return null;
    }
    try {
      return (Id) value;
    } catch (Exception e) {
      return null;
    }
  }
}