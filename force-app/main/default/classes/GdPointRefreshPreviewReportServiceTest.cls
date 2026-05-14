@IsTest
private class GdPointRefreshPreviewReportServiceTest {
  @IsTest
  static void getReport_buildsAccrualUsageAndSummaryFromPlanRows() {
    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = 'REPORT-TEST';
    run.MemberId__c = '0lM000000000001AAA';
    run.OpenDate__c = Date.newInstance(2026, 5, 18);
    run.Status__c = 'Planned';
    run.CurrentStep__c = 'PLAN_ROWS_3';
    insert run;

    insert new List<GdPointRefreshStage__c>{
      buildStage(run.Id, 'PLAN_CREDIT', 'CREDIT', Date.newInstance(2026, 5, 18), 1, 'C1', 'C1', 'SAL-1', 'C1', '04', 100, 70),
      buildStage(run.Id, 'PLAN_DEBIT', 'DEBIT', Date.newInstance(2026, 5, 19), 2, 'D1', 'D1', 'SAL-2', '-', '-', 30, 0),
      buildStage(run.Id, 'PLAN_TRACE', 'Debit', Date.newInstance(2026, 5, 19), 3, 'T1', 'C1', 'SAL-2', 'D1', '-', 30, 0),
      buildStage(run.Id, 'PLAN_CREDIT_CANCEL_DEBIT', 'CreditCancellationDebit', Date.newInstance(2026, 5, 20), 4, 'CC1', 'CC1', 'SAL-1', 'C1', '-', 10, 0)
    };

    GdPointRefreshPreviewReportService.Report report = new GdPointRefreshPreviewReportService().getReport(run.Id);

    System.assertEquals(run.Id, report.runId);
    System.assertEquals('REPORT-TEST', report.memberNo);
    System.assertEquals(1, report.accrualCount);
    System.assertEquals(2, report.usageCount);
    System.assertEquals(1, report.traceCount);
    System.assertEquals(1, report.creditCancelCount);
    System.assertEquals(70, report.totalRemaining);
    System.assertEquals(70, report.remainingByPointType.get('04'));
    System.assertEquals('SAL-1', report.accrualRows[0].saleNo);
    System.assertEquals('CreditCancellation', report.usageRows[1].actionType);

    GdPointRefreshPreviewReportService.Summary summary = new GdPointRefreshPreviewReportService().getSummary(run.Id);
    System.assertEquals(report.totalRemaining, summary.totalRemaining);
    System.assertEquals(report.accrualCount, summary.accrualCount);
  }

  private static GdPointRefreshStage__c buildStage(
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
    Decimal remainingPoints
  ) {
    GdPointRefreshStage__c stage = new GdPointRefreshStage__c();
    stage.Run__c = runId;
    stage.StageType__c = stageType;
    stage.EventType__c = eventType;
    stage.EventDate__c = eventDate;
    stage.Sequence__c = sequence;
    stage.EventKey__c = eventKey;
    stage.SourceKey__c = sourceKey;
    stage.SaleNo__c = saleNo;
    stage.OriginKey__c = originKey;
    stage.PointTypeCode__c = pointTypeCode;
    stage.Points__c = points;
    stage.RemainingPoints__c = remainingPoints;
    stage.ExpiryDate__c = eventDate.addYears(2);
    stage.SortKey__c = GdPointRefreshStagedService.buildSortKey(eventDate, sequence, eventKey);
    stage.TargetJournalId__c = '-';
    stage.TargetLedgerId__c = '-';
    return stage;
  }
}