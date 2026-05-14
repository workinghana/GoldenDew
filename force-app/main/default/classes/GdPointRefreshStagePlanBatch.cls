public without sharing class GdPointRefreshStagePlanBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Id runId;
  private Integer plannedCount = 0;
  private Boolean autoContinue = false;
  private Boolean cleanupAfterComplete = false;

  public GdPointRefreshStagePlanBatch(Id runId) {
    this.runId = runId;
  }

  public GdPointRefreshStagePlanBatch(Id runId, Boolean autoContinue, Boolean cleanupAfterComplete) {
    this.runId = runId;
    this.autoContinue = autoContinue == true;
    this.cleanupAfterComplete = cleanupAfterComplete == true;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    return Database.getQueryLocator([
      SELECT Id, MemberNo__c, OpenDate__c, UseCreatedDateCutoff__c, MigrationCutoffDateTime__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
    ]);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    GdPointRefreshRun__c run = (GdPointRefreshRun__c) scope[0];
    deleteExistingPlanRows(run.Id);

    GdPointRefreshPreviewService.PreviewResult preview = new GdPointRefreshPreviewService()
      .simulateMember(
        run.MemberNo__c,
        run.OpenDate__c,
        new Map<String, Decimal>(),
        run.UseCreatedDateCutoff__c,
        run.MigrationCutoffDateTime__c
      );
    Map<String, GdPointRefreshPreviewService.EventRow> eventByKey = buildEventByKey(preview);

    List<GdPointRefreshStage__c> rows = new List<GdPointRefreshStage__c>();
    Integer seq = 100000;
    for (GdPointRefreshPreviewService.BucketRow bucket : preview.buckets) {
      if (bucket == null || bucket.originalPoints == null || bucket.originalPoints <= 0) {
        continue;
      }
      rows.add(buildPlanRow(run.Id, 'PLAN_CREDIT', GdPointRefreshEngine.EVENT_CREDIT, bucket.accrualDate, seq++, bucket.bucketKey, bucket.bucketKey, bucket.originSaleNo, bucket.rootOriginKey, bucket.pointTypeCode, bucket.originalPoints, bucket.remainingPoints, bucket.expiryDate));
      flush(rows);
    }

    Map<String, Decimal> debitTotalByEventKey = new Map<String, Decimal>();
    for (GdPointRefreshPreviewService.AllocationRow allocation : preview.allocations) {
      if (allocation == null || allocation.points == null || allocation.points <= 0 || String.isBlank(allocation.debitEventKey)) {
        continue;
      }
      Decimal current = debitTotalByEventKey.containsKey(allocation.debitEventKey) ? debitTotalByEventKey.get(allocation.debitEventKey) : 0;
      debitTotalByEventKey.put(allocation.debitEventKey, current + allocation.points);
    }
    for (String debitEventKey : debitTotalByEventKey.keySet()) {
      GdPointRefreshPreviewService.EventRow debitEvent = eventByKey.get(debitEventKey);
      Date eventDate = debitEvent == null ? run.OpenDate__c : debitEvent.eventDate;
      rows.add(buildPlanRow(run.Id, 'PLAN_DEBIT', GdPointRefreshEngine.EVENT_DEBIT, eventDate, seq++, debitEventKey, debitEventKey, debitEvent == null ? null : debitEvent.saleNo, '-', '-', debitTotalByEventKey.get(debitEventKey), 0, eventDate.addYears(2)));
      flush(rows);
    }

    for (GdPointRefreshPreviewService.AllocationRow allocation : preview.allocations) {
      if (allocation == null || allocation.points == null || allocation.points <= 0) {
        continue;
      }
      GdPointRefreshPreviewService.EventRow debitEvent = eventByKey.get(allocation.debitEventKey);
      Date eventDate = debitEvent == null ? run.OpenDate__c : debitEvent.eventDate;
      String eventKey = 'TRACE:DEBIT:' + allocation.debitEventKey + ':' + allocation.creditBucketKey;
      rows.add(buildPlanRow(run.Id, 'PLAN_TRACE', 'Debit', eventDate, seq++, eventKey, allocation.creditBucketKey, debitEvent == null ? null : debitEvent.saleNo, allocation.debitEventKey, '-', allocation.points, 0, eventDate.addYears(2)));
      flush(rows);
    }

    for (GdPointRefreshPreviewService.DebitCancellationRow cancellation : preview.debitCancellations) {
      if (cancellation == null || cancellation.points == null || cancellation.points <= 0) {
        continue;
      }
      GdPointRefreshPreviewService.EventRow cancelEvent = eventByKey.get(cancellation.cancelEventKey);
      Date eventDate = cancelEvent == null ? run.OpenDate__c : cancelEvent.eventDate;
      String eventKey = 'TRACE:DEBIT_CANCEL:' + cancellation.cancelEventKey + ':' + cancellation.sourceCreditBucketKey + ':' + cancellation.restoredCreditBucketKey;
      rows.add(buildPlanRow(run.Id, 'PLAN_TRACE', 'DebitCancellation', eventDate, seq++, eventKey, cancellation.sourceCreditBucketKey, cancelEvent == null ? null : cancelEvent.saleNo, cancellation.restoredCreditBucketKey, '-', cancellation.points, 0, eventDate.addYears(2)));
      flush(rows);
    }

    for (GdPointRefreshPreviewService.CreditCancellationRow cancellation : preview.creditCancellations) {
      if (cancellation == null || cancellation.points == null || cancellation.points <= 0) {
        continue;
      }
      GdPointRefreshPreviewService.EventRow cancelEvent = eventByKey.get(cancellation.cancelEventKey);
      Date eventDate = cancelEvent == null ? run.OpenDate__c : cancelEvent.eventDate;
      String debitStageKey = 'CREDIT_CANCEL_DEBIT:' + cancellation.cancelEventKey + ':' + cancellation.creditBucketKey;
      rows.add(buildPlanRow(run.Id, 'PLAN_CREDIT_CANCEL_DEBIT', 'CreditCancellationDebit', eventDate, seq++, debitStageKey, cancellation.cancelEventKey, cancelEvent == null ? null : cancelEvent.saleNo, cancellation.creditBucketKey, '-', cancellation.points, 0, eventDate.addYears(2)));
      flush(rows);
      String eventKey = 'TRACE:CREDIT_CANCEL:' + cancellation.cancelEventKey + ':' + cancellation.creditBucketKey;
      rows.add(buildPlanRow(run.Id, 'PLAN_TRACE', 'CreditCancellation', eventDate, seq++, eventKey, cancellation.creditBucketKey, cancelEvent == null ? null : cancelEvent.saleNo, debitStageKey, '-', cancellation.points, 0, eventDate.addYears(2)));
      flush(rows);
    }

    flushAll(rows);
  }

  public void finish(Database.BatchableContext context) {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'Planned';
    run.CurrentStep__c = 'PLAN_ROWS_' + String.valueOf(plannedCount);
    update run;
    if (autoContinue) {
      Database.executeBatch(new GdPointRefreshStageTargetCollectBatch(runId, true, cleanupAfterComplete), 500);
    }
  }

  private void deleteExistingPlanRows(Id targetRunId) {
    List<GdPointRefreshStage__c> rows = [
      SELECT Id
      FROM GdPointRefreshStage__c
      WHERE Run__c = :targetRunId AND StageType__c LIKE 'PLAN_%'
      LIMIT 10000
    ];
    while (!rows.isEmpty()) {
      delete rows;
      rows = [
        SELECT Id
        FROM GdPointRefreshStage__c
        WHERE Run__c = :targetRunId AND StageType__c LIKE 'PLAN_%'
        LIMIT 10000
      ];
    }
  }

  private void flush(List<GdPointRefreshStage__c> rows) {
    if (rows.size() < 1000) {
      return;
    }
    flushAll(rows);
  }

  private void flushAll(List<GdPointRefreshStage__c> rows) {
    if (rows.isEmpty()) {
      return;
    }
    insert rows;
    plannedCount += rows.size();
    rows.clear();
  }

  private static GdPointRefreshStage__c buildPlanRow(
    Id runId,
    String stageType,
    String eventType,
    Date eventDate,
    Integer sequence,
    String eventKey,
    String sourceKey,
    String saleNo,
    String originKey,
    String pointTypeCode,
    Decimal points,
    Decimal remainingPoints,
    Date expiryDate
  ) {
    Date safeDate = eventDate == null ? Date.today() : eventDate;
    String safeEventKey = String.isBlank(eventKey) ? '-' : eventKey;
    GdPointRefreshStage__c row = new GdPointRefreshStage__c();
    row.Run__c = runId;
    row.StageType__c = stageType;
    row.EventType__c = String.isBlank(eventType) ? '-' : eventType;
    row.EventDate__c = safeDate;
    row.Sequence__c = sequence == null ? 0 : sequence;
    row.EventKey__c = truncate(safeEventKey, 255);
    row.SourceKey__c = truncate(String.isBlank(sourceKey) ? '-' : sourceKey, 255);
    row.SaleNo__c = truncate(String.isBlank(saleNo) ? '-' : saleNo, 255);
    row.OriginKey__c = truncate(String.isBlank(originKey) ? '-' : originKey, 255);
    row.PointTypeCode__c = truncate(String.isBlank(pointTypeCode) ? '-' : pointTypeCode, 40);
    row.Points__c = points == null ? 0 : points;
    row.RemainingPoints__c = remainingPoints == null ? 0 : remainingPoints;
    row.ExpiryDate__c = expiryDate == null ? safeDate.addYears(2) : expiryDate;
    row.SortKey__c = GdPointRefreshStagedService.buildSortKey(safeDate, row.Sequence__c.intValue(), safeEventKey);
    row.TargetJournalId__c = '-';
    row.TargetLedgerId__c = '-';
    return row;
  }

  private static Map<String, GdPointRefreshPreviewService.EventRow> buildEventByKey(GdPointRefreshPreviewService.PreviewResult preview) {
    Map<String, GdPointRefreshPreviewService.EventRow> result = new Map<String, GdPointRefreshPreviewService.EventRow>();
    if (preview == null || preview.events == null) {
      return result;
    }
    for (GdPointRefreshPreviewService.EventRow event : preview.events) {
      result.put(event.eventKey, event);
    }
    return result;
  }

  private static String truncate(String value, Integer maxLength) {
    if (value == null || maxLength == null || value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }
}