public without sharing class GdPointRefreshBatch implements Database.Batchable<String>, Database.Stateful {
  private List<String> memberNos;
  private Date openDate;
  private Map<String, Decimal> openingPointByType;
  private Integer successCount = 0;
  private Integer failureCount = 0;
  private List<String> failureMessages = new List<String>();

  public GdPointRefreshBatch(List<String> memberNos, Date openDate) {
    this(memberNos, openDate, null);
  }

  public GdPointRefreshBatch(List<String> memberNos, Date openDate, Map<String, Decimal> openingPointByType) {
    this.memberNos = normalizeMemberNos(memberNos);
    this.openDate = openDate;
    this.openingPointByType = openingPointByType == null ? new Map<String, Decimal>() : new Map<String, Decimal>(openingPointByType);
  }

  public Iterable<String> start(Database.BatchableContext context) {
    if (openDate == null) {
      throw new CustomException(400, 'openDate is required.');
    }
    return memberNos == null ? new List<String>() : memberNos;
  }

  public void execute(Database.BatchableContext context, List<String> scope) {
    if (scope == null || scope.isEmpty()) {
      return;
    }

    for (String memberNo : scope) {
      if (String.isBlank(memberNo)) {
        continue;
      }
      try {
        GdPointRefreshApplyService.Request request = new GdPointRefreshApplyService.Request();
        request.memberNo = memberNo;
        request.openDate = openDate;
        request.openingPointByType = new Map<String, Decimal>(openingPointByType);
        request.dryRun = false;
        new GdPointRefreshApplyService().refreshMember(request);
        successCount++;
      } catch (Exception e) {
        failureCount++;
        failureMessages.add(memberNo + ' => ' + e.getMessage());
        System.debug(LoggingLevel.ERROR, 'GdPointRefreshBatch failed. memberNo=' + memberNo + ', error=' + e.getMessage());
      }
    }
  }

  public void finish(Database.BatchableContext context) {
    System.debug(
      LoggingLevel.INFO,
      'GdPointRefreshBatch finished. success=' +
        successCount +
        ', failure=' +
        failureCount +
        ', failures=' +
        String.join(failureMessages, ' | ')
    );
  }

  public static Id run(List<String> memberNos, Date openDate) {
    return run(memberNos, openDate, null);
  }

  public static Id run(List<String> memberNos, Date openDate, Map<String, Decimal> openingPointByType) {
    return Database.executeBatch(new GdPointRefreshBatch(memberNos, openDate, openingPointByType), 1);
  }

  private static List<String> normalizeMemberNos(List<String> source) {
    List<String> result = new List<String>();
    Set<String> seen = new Set<String>();
    if (source == null) {
      return result;
    }
    for (String memberNo : source) {
      if (String.isBlank(memberNo)) {
        continue;
      }
      String normalized = memberNo.trim();
      if (seen.contains(normalized)) {
        continue;
      }
      seen.add(normalized);
      result.add(normalized);
    }
    return result;
  }
}