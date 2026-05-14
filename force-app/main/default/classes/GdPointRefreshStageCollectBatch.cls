public without sharing class GdPointRefreshStageCollectBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Id runId;
  private Id memberId;
  private Date openDate;
  private Boolean useCreatedDateCutoff = true;
  private Datetime migrationCutoffDateTime;
  private Integer collectedCount = 0;
  private Boolean autoContinue = false;
  private Boolean cleanupAfterComplete = false;
  private Boolean stopAfterPlan = false;

  public GdPointRefreshStageCollectBatch(Id runId) {
    this.runId = runId;
  }

  public GdPointRefreshStageCollectBatch(Id runId, Boolean autoContinue, Boolean cleanupAfterComplete) {
    this.runId = runId;
    this.autoContinue = autoContinue == true;
    this.cleanupAfterComplete = cleanupAfterComplete == true;
  }

  public GdPointRefreshStageCollectBatch(Id runId, Boolean autoContinue, Boolean cleanupAfterComplete, Boolean stopAfterPlan) {
    this.runId = runId;
    this.autoContinue = autoContinue == true;
    this.cleanupAfterComplete = cleanupAfterComplete == true;
    this.stopAfterPlan = stopAfterPlan == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    GdPointRefreshRun__c run = [
      SELECT Id, MemberId__c, OpenDate__c, UseCreatedDateCutoff__c, MigrationCutoffDateTime__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    memberId = (Id) run.MemberId__c;
    openDate = run.OpenDate__c;
    useCreatedDateCutoff = run.UseCreatedDateCutoff__c == true;
    migrationCutoffDateTime = run.MigrationCutoffDateTime__c == null ? TimeUtil.dateToUtcStartOfDay(openDate) : run.MigrationCutoffDateTime__c;

    Datetime openDateTime = TimeUtil.dateToUtcStartOfDay(openDate);
    if (useCreatedDateCutoff == true && migrationCutoffDateTime != null) {
      return Database.getQueryLocator([
        SELECT
          Id,
          CreatedDate,
          OrderId,
          SaleId__c,
          ActivityDate,
          PaymentMethod,
          DepositType__c,
          TransactionAmount,
          IsDeleted__c,
          DeleteDateTime__c,
          PromotionId,
          Promotion.PointTypeCode__c,
          Order.SaleNo__c,
          Order.EndDate,
          Order.EffectiveDate,
          Order.IsReductionOrder__c,
          Order.IsDeleted__c,
          Order.OriginalOrderId__c,
          SaleId__r.SaleNo__c,
          SaleId__r.EndDate,
          SaleId__r.EffectiveDate,
          SaleId__r.IsReductionOrder__c,
          SaleId__r.IsDeleted__c,
          SaleId__r.OriginalOrderId__c
        FROM TransactionJournal
        WHERE
          MemberId = :memberId
          AND PaymentMethod != NULL
          AND DepositType__c != NULL
          AND (ActivityDate >= :openDateTime OR CreatedDate > :migrationCutoffDateTime)
        ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
      ]);
    }
    return Database.getQueryLocator([
      SELECT
        Id,
        CreatedDate,
        OrderId,
        SaleId__c,
        ActivityDate,
        PaymentMethod,
        DepositType__c,
        TransactionAmount,
        IsDeleted__c,
        DeleteDateTime__c,
        PromotionId,
        Promotion.PointTypeCode__c,
        Order.SaleNo__c,
        Order.EndDate,
        Order.EffectiveDate,
        Order.IsReductionOrder__c,
        Order.IsDeleted__c,
        Order.OriginalOrderId__c,
        SaleId__r.SaleNo__c,
        SaleId__r.EndDate,
        SaleId__r.EffectiveDate,
        SaleId__r.IsReductionOrder__c,
        SaleId__r.IsDeleted__c,
        SaleId__r.OriginalOrderId__c
      FROM TransactionJournal
      WHERE
        MemberId = :memberId
        AND PaymentMethod != NULL
        AND DepositType__c != NULL
        AND ActivityDate >= :openDateTime
      ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    List<GdPointRefreshStage__c> stages = new List<GdPointRefreshStage__c>();
    Integer localSeq = 0;
    for (SObject row : scope) {
      TransactionJournal tj = (TransactionJournal) row;
      if (tj.TransactionAmount == null || tj.TransactionAmount <= 0) {
        continue;
      }
      Date eventDate = resolveBusinessDate(tj);
      if (!isCollectTargetEvent(eventDate, tj.CreatedDate)) {
        continue;
      }
      GdPointRefreshStage__c stage = new GdPointRefreshStage__c();
      stage.Run__c = runId;
      stage.StageType__c = 'SOURCE_TJ';
      stage.EventDate__c = eventDate;
      stage.Sequence__c = collectedCount + localSeq + 1000;
      stage.SourceKey__c = String.valueOf(tj.Id);
      stage.SaleNo__c = resolveSaleNo(tj);
      if (String.isBlank(stage.SaleNo__c)) {
        stage.SaleNo__c = '-';
      }
      stage.Points__c = tj.TransactionAmount;
      stage.RemainingPoints__c = 0;
      stage.OriginKey__c = '-';
      stage.PointTypeCode__c = '-';
      stage.ExpiryDate__c = eventDate.addYears(2);
      stage.EventType__c = classifyEventType(tj);
      stage.EventKey__c = stage.EventType__c + ':TJ:' + String.valueOf(tj.Id);
      stage.SortKey__c = GdPointRefreshStagedService.buildSortKey(eventDate, collectedCount + localSeq + 1000, stage.EventKey__c);
      stage.TargetJournalId__c = '-';
      stage.TargetLedgerId__c = '-';
      stages.add(stage);
      localSeq++;
    }
    if (!stages.isEmpty()) {
      insert stages;
      collectedCount += stages.size();
    }
  }

  public void finish(Database.BatchableContext context) {
    GdPointRefreshRun__c run = [
      SELECT Id
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    Integer openingCount = [
      SELECT COUNT()
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId AND StageType__c = 'EVENT'
    ];
    run.Status__c = 'Staged';
    run.CurrentStep__c = 'SOURCE_COLLECTED_' + String.valueOf(collectedCount + openingCount);
    update run;
    if (autoContinue) {
      Database.executeBatch(new GdPointRefreshStagePlanBatch(runId, stopAfterPlan != true, cleanupAfterComplete), 1);
    }
  }

  private static String classifyEventType(TransactionJournal tj) {
    Boolean isReturn = resolveIsReturn(tj);
    Boolean deleted = tj.IsDeleted__c == true || resolveOrderDeleted(tj);
    if ('81'.equals(tj.PaymentMethod)) {
      if (isReturn && !deleted) return GdPointRefreshEngine.EVENT_DEBIT_CANCEL;
      if (isReturn && deleted) return GdPointRefreshEngine.EVENT_DEBIT;
      if (!isReturn && !deleted) return GdPointRefreshEngine.EVENT_DEBIT;
      return GdPointRefreshEngine.EVENT_DEBIT_CANCEL;
    }
    if (isReturn && !deleted) return GdPointRefreshEngine.EVENT_CREDIT_CANCEL;
    if (isReturn && deleted) return GdPointRefreshEngine.EVENT_CREDIT;
    if (!isReturn && !deleted) return GdPointRefreshEngine.EVENT_CREDIT;
    return GdPointRefreshEngine.EVENT_CREDIT_CANCEL;
  }

  private static Date resolveBusinessDate(TransactionJournal tj) {
    if (tj.SaleId__r != null) {
      if (tj.SaleId__r.EndDate != null) return tj.SaleId__r.EndDate;
      if (tj.SaleId__r.EffectiveDate != null) return tj.SaleId__r.EffectiveDate;
    }
    if (tj.Order != null) {
      if (tj.Order.EndDate != null) return tj.Order.EndDate;
      if (tj.Order.EffectiveDate != null) return tj.Order.EffectiveDate;
    }
    return tj.ActivityDate == null ? null : tj.ActivityDate.date();
  }

  private static String resolveSaleNo(TransactionJournal tj) {
    if (tj.SaleId__r != null && String.isNotBlank(tj.SaleId__r.SaleNo__c)) return tj.SaleId__r.SaleNo__c;
    if (tj.Order != null && String.isNotBlank(tj.Order.SaleNo__c)) return tj.Order.SaleNo__c;
    return null;
  }

  private static Boolean resolveIsReturn(TransactionJournal tj) {
    if (tj.SaleId__r != null) return tj.SaleId__r.IsReductionOrder__c == true;
    if (tj.Order != null) return tj.Order.IsReductionOrder__c == true;
    return false;
  }

  private static Boolean resolveOrderDeleted(TransactionJournal tj) {
    if (tj.SaleId__r != null) return tj.SaleId__r.IsDeleted__c == true;
    if (tj.Order != null) return tj.Order.IsDeleted__c == true;
    return false;
  }

  private Boolean isCollectTargetEvent(Date businessDate, Datetime createdDate) {
    if (businessDate == null || openDate == null) {
      return false;
    }
    if (businessDate >= openDate) {
      return true;
    }
    return useCreatedDateCutoff == true &&
      migrationCutoffDateTime != null &&
      createdDate != null &&
      createdDate > migrationCutoffDateTime;
  }
}