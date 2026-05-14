public without sharing class GdPointRefreshPreviewReportService {
  public class Report {
    public Id runId;
    public String memberNo;
    public Id memberId;
    public Date openDate;
    public String status;
    public String currentStep;
    public Decimal totalRemaining = 0;
    public Integer accrualCount = 0;
    public Integer usageCount = 0;
    public Integer traceCount = 0;
    public Integer creditCancelCount = 0;
    public Map<String, Decimal> remainingByPointType = new Map<String, Decimal>();
    public List<AccrualRow> accrualRows = new List<AccrualRow>();
    public List<UsageRow> usageRows = new List<UsageRow>();
  }

  public class AccrualRow {
    public Date accrualDate;
    public String saleNo;
    public String pointTypeCode;
    public Decimal accruedPoints;
    public Decimal remainingPoints;
    public Date expiryDate;
    public String eventKey;
    public String originKey;
    public String stageType;
  }

  public class UsageRow {
    public Date eventDate;
    public String saleNo;
    public String actionType;
    public Decimal points;
    public String sourceKey;
    public String debitOrCancelKey;
    public String eventKey;
    public String stageType;
  }

  public Report getReport(Id runId) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }

    GdPointRefreshRun__c run = [
      SELECT Id, MemberNo__c, MemberId__c, OpenDate__c, Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];

    Report report = new Report();
    report.runId = run.Id;
    report.memberNo = run.MemberNo__c;
    report.memberId = (Id) run.MemberId__c;
    report.openDate = run.OpenDate__c;
    report.status = run.Status__c;
    report.currentStep = run.CurrentStep__c;

    List<GdPointRefreshStage__c> planRows = [
      SELECT
        StageType__c,
        EventType__c,
        EventDate__c,
        EventKey__c,
        SourceKey__c,
        SaleNo__c,
        OriginKey__c,
        PointTypeCode__c,
        Points__c,
        RemainingPoints__c,
        ExpiryDate__c,
        SortKey__c
      FROM GdPointRefreshStage__c
      WHERE Run__c = :runId AND StageType__c LIKE 'PLAN_%'
      ORDER BY SortKey__c
      LIMIT 50000
    ];

    for (GdPointRefreshStage__c row : planRows) {
      if (row.StageType__c == 'PLAN_CREDIT') {
        addAccrual(report, row);
      } else if (row.StageType__c == 'PLAN_DEBIT' || row.StageType__c == 'PLAN_CREDIT_CANCEL_DEBIT') {
        addUsage(report, row);
      } else if (row.StageType__c == 'PLAN_TRACE') {
        report.traceCount++;
      }
    }

    return report;
  }

  public Summary getSummary(Id runId) {
    Report report = getReport(runId);
    Summary summary = new Summary();
    summary.runId = report.runId;
    summary.memberNo = report.memberNo;
    summary.status = report.status;
    summary.currentStep = report.currentStep;
    summary.totalRemaining = report.totalRemaining;
    summary.remainingByPointType = report.remainingByPointType;
    summary.accrualCount = report.accrualCount;
    summary.usageCount = report.usageCount;
    summary.traceCount = report.traceCount;
    summary.creditCancelCount = report.creditCancelCount;
    return summary;
  }

  public class Summary {
    public Id runId;
    public String memberNo;
    public String status;
    public String currentStep;
    public Decimal totalRemaining = 0;
    public Integer accrualCount = 0;
    public Integer usageCount = 0;
    public Integer traceCount = 0;
    public Integer creditCancelCount = 0;
    public Map<String, Decimal> remainingByPointType = new Map<String, Decimal>();
  }

  private static void addAccrual(Report report, GdPointRefreshStage__c row) {
    AccrualRow dto = new AccrualRow();
    dto.accrualDate = row.EventDate__c;
    dto.saleNo = normalizeBlank(row.SaleNo__c);
    dto.pointTypeCode = normalizeBlank(row.PointTypeCode__c);
    dto.accruedPoints = nvl(row.Points__c);
    dto.remainingPoints = nvl(row.RemainingPoints__c);
    dto.expiryDate = row.ExpiryDate__c;
    dto.eventKey = row.EventKey__c;
    dto.originKey = normalizeBlank(row.OriginKey__c);
    dto.stageType = row.StageType__c;
    report.accrualRows.add(dto);
    report.accrualCount++;

    report.totalRemaining += dto.remainingPoints;
    String pointType = String.isBlank(dto.pointTypeCode) ? 'UNKNOWN' : dto.pointTypeCode;
    Decimal current = report.remainingByPointType.containsKey(pointType) ? report.remainingByPointType.get(pointType) : 0;
    report.remainingByPointType.put(pointType, current + dto.remainingPoints);
  }

  private static void addUsage(Report report, GdPointRefreshStage__c row) {
    UsageRow dto = new UsageRow();
    dto.eventDate = row.EventDate__c;
    dto.saleNo = normalizeBlank(row.SaleNo__c);
    dto.actionType = row.StageType__c == 'PLAN_CREDIT_CANCEL_DEBIT' ? 'CreditCancellation' : 'Debit';
    dto.points = nvl(row.Points__c);
    dto.sourceKey = normalizeBlank(row.SourceKey__c);
    dto.debitOrCancelKey = normalizeBlank(row.OriginKey__c);
    dto.eventKey = row.EventKey__c;
    dto.stageType = row.StageType__c;
    report.usageRows.add(dto);
    report.usageCount++;
    if (dto.actionType == 'CreditCancellation') {
      report.creditCancelCount++;
    }
  }

  private static Decimal nvl(Decimal value) {
    return value == null ? 0 : value;
  }

  private static String normalizeBlank(String value) {
    return String.isBlank(value) || value == '-' ? null : value;
  }
}