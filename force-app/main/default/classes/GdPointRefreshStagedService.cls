public without sharing class GdPointRefreshStagedService {
  private static final Set<String> VALIDATION_RUN_STATUSES = new Set<String>{
    'Collecting',
    'Staged',
    'Planning',
    'Planned',
    'ApplyDryRunQueued',
    'ApplyDryRunning',
    'ApplyDryRunCompleted',
    'ApplyFailed'
  };
  private static final Set<String> DESTRUCTIVE_RUN_STATUSES = new Set<String>{
    'ApplyQueued',
    'Applying',
    'CollectingTargets',
    'TargetCollected',
    'DeletingTargetTraces',
    'TargetTracesDeleted',
    'DeletingTargetLedgers',
    'TargetLedgersDeleted',
    'DeletingTargetJournals',
    'TargetDeleted',
    'CreatingLedgers',
    'LedgersCreated',
    'CreatingTraces',
    'TracesCreated',
    'Finalizing'
  };

  private class RefreshConfig {
    Date openDate;
    Boolean useCreatedDateCutoff = true;
    Datetime migrationCutoffDateTime;
  }

  public static Id startCollect(String memberNo, Date openDate) {
    return startCollect(memberNo, openDate, false, false);
  }

  public static Id startValidation(String memberNo) {
    RefreshConfig config = resolveRefreshConfig(null, null);
    return startValidation(memberNo, config.openDate, config.useCreatedDateCutoff, config.migrationCutoffDateTime);
  }

  public static Id startValidation(String memberNo, Date openDate) {
    RefreshConfig config = resolveRefreshConfig(openDate, null);
    return startValidation(memberNo, config.openDate, config.useCreatedDateCutoff, config.migrationCutoffDateTime);
  }

  public static Id startValidation(String memberNo, Date openDate, Datetime migrationCutoffDateTime) {
    RefreshConfig config = resolveRefreshConfig(openDate, migrationCutoffDateTime);
    return startValidation(memberNo, config.openDate, config.useCreatedDateCutoff, config.migrationCutoffDateTime);
  }

  private static Id startValidation(
    String memberNo,
    Date openDate,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    validateMemberNoAndDate(memberNo, openDate);
    String normalizedMemberNo = memberNo.trim();
    guardNoDestructiveRun(normalizedMemberNo);
    supersedeExistingValidationRuns(normalizedMemberNo);
    return startCollect(normalizedMemberNo, openDate, true, false, true, useCreatedDateCutoff, migrationCutoffDateTime);
  }

  public static Id applyValidation(Id runId) {
    GdPointRefreshRun__c run = validateLatestPlannedRun(runId);
    run.Status__c = 'ApplyApproved';
    run.CurrentStep__c = 'APPLY_VALIDATION_APPROVED';
    update run;
    return Database.executeBatch(new GdPointRefreshStageTargetCollectBatch(runId, true, true), 500);
  }

  public static Id startFullRefresh(String memberNo, Date openDate) {
    return startCollect(memberNo, openDate, true, true);
  }

  public static Id startFullRefresh(String memberNo, Date openDate, Boolean cleanupAfterComplete) {
    RefreshConfig config = resolveRefreshConfig(openDate, null);
    return startCollect(memberNo, config.openDate, true, cleanupAfterComplete == true, false, config.useCreatedDateCutoff, config.migrationCutoffDateTime);
  }

  public static Id startFullRefresh(String memberNo, Date openDate, Boolean cleanupAfterComplete, Datetime migrationCutoffDateTime) {
    RefreshConfig config = resolveRefreshConfig(openDate, migrationCutoffDateTime);
    return startCollect(memberNo, config.openDate, true, cleanupAfterComplete == true, false, config.useCreatedDateCutoff, config.migrationCutoffDateTime);
  }

  public static Id startCollect(String memberNo, Date openDate, Boolean autoContinue, Boolean cleanupAfterComplete) {
    RefreshConfig config = resolveRefreshConfig(openDate, null);
    return startCollect(memberNo, config.openDate, autoContinue, cleanupAfterComplete, false, config.useCreatedDateCutoff, config.migrationCutoffDateTime);
  }

  public static Id startCollect(String memberNo, Date openDate, Boolean autoContinue, Boolean cleanupAfterComplete, Datetime migrationCutoffDateTime) {
    RefreshConfig config = resolveRefreshConfig(openDate, migrationCutoffDateTime);
    return startCollect(memberNo, config.openDate, autoContinue, cleanupAfterComplete, false, config.useCreatedDateCutoff, config.migrationCutoffDateTime);
  }

  private static Id startCollect(String memberNo, Date openDate, Boolean autoContinue, Boolean cleanupAfterComplete, Boolean stopAfterPlan) {
    RefreshConfig config = resolveRefreshConfig(openDate, null);
    return startCollect(memberNo, config.openDate, autoContinue, cleanupAfterComplete, stopAfterPlan, config.useCreatedDateCutoff, config.migrationCutoffDateTime);
  }

  private static Id startCollect(
    String memberNo,
    Date openDate,
    Boolean autoContinue,
    Boolean cleanupAfterComplete,
    Boolean stopAfterPlan,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    validateMemberNoAndDate(memberNo, openDate);
    Datetime effectiveMigrationCutoff = migrationCutoffDateTime == null ? defaultMigrationCutoff(openDate) : migrationCutoffDateTime;

    LoyaltyProgramMember member = [
      SELECT Id, Contact.MemberNo__c, OpeningPointBalance__c
      FROM LoyaltyProgramMember
      WHERE Contact.MemberNo__c = :memberNo
      LIMIT 1
    ];

    GdPointRefreshRun__c run = new GdPointRefreshRun__c();
    run.MemberNo__c = memberNo.trim();
    run.MemberId__c = String.valueOf(member.Id);
    run.OpenDate__c = openDate;
    run.UseCreatedDateCutoff__c = useCreatedDateCutoff == true;
    run.MigrationCutoffDateTime__c = effectiveMigrationCutoff;
    run.Status__c = 'Collecting';
    run.CurrentStep__c = 'SOURCE_COLLECT';
    insert run;

    if (member.OpeningPointBalance__c != null && member.OpeningPointBalance__c > 0) {
      GdPointRefreshStage__c opening = new GdPointRefreshStage__c();
      opening.Run__c = run.Id;
      opening.StageType__c = 'EVENT';
      opening.EventType__c = GdPointRefreshEngine.EVENT_CREDIT;
      opening.EventDate__c = openDate;
      opening.Sequence__c = 0;
      opening.EventKey__c = 'OPENING:' + memberNo + ':04';
      opening.SourceKey__c = opening.EventKey__c;
      opening.OriginKey__c = opening.EventKey__c;
      opening.PointTypeCode__c = '04';
      opening.Points__c = member.OpeningPointBalance__c;
      opening.RemainingPoints__c = member.OpeningPointBalance__c;
      opening.ExpiryDate__c = openDate.addYears(2);
      opening.SortKey__c = buildSortKey(openDate, 0, opening.EventKey__c);
      opening.SourceKey__c = opening.EventKey__c;
      opening.SaleNo__c = '-';
      opening.TargetJournalId__c = '-';
      opening.TargetLedgerId__c = '-';
      insert opening;
    }

    Id jobId = Database.executeBatch(new GdPointRefreshStageCollectBatch(run.Id, autoContinue == true, cleanupAfterComplete == true, stopAfterPlan == true), 500);
    run.CurrentStep__c = 'SOURCE_COLLECT_JOB_' + String.valueOf(jobId);
    update run;
    return run.Id;
  }

  public static Id cleanup(Id runId) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    return Database.executeBatch(new GdPointRefreshStageCleanupBatch(runId), 2000);
  }

  public static Id startFinalize(Id runId, Boolean cleanupAfterFinalize) {
    validateStatus(runId, new Set<String>{ 'TracesCreated' }, 'TracesCreated');
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'Finalizing';
    run.CurrentStep__c = 'FINALIZE_QUEUE';
    update run;
    return Database.executeBatch(new GdPointRefreshStageFinalizeBatch(runId, cleanupAfterFinalize == true), 1);
  }

  public static Id startApply(Id runId) {
    return startApply(runId, false, true);
  }

  public static Id startPlan(Id runId) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }

    GdPointRefreshRun__c run = [
      SELECT Id, Status__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    if (run.Status__c != 'Staged' && run.Status__c != 'Planned' && run.Status__c != 'ApplyDryRunCompleted') {
      throw new CustomException(400, 'Point refresh run must be Staged before plan. current=' + run.Status__c);
    }

    run.Status__c = 'Planning';
    run.CurrentStep__c = 'PLAN_QUEUE';
    update run;

    Id jobId = Database.executeBatch(new GdPointRefreshStagePlanBatch(runId), 1);
    run.CurrentStep__c = 'PLAN_JOB_' + String.valueOf(jobId);
    update run;
    return jobId;
  }

  public static Id startApply(Id runId, Boolean dryRun, Boolean cleanupAfterApply) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }

    GdPointRefreshRun__c run = [
      SELECT Id, Status__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    if (run.Status__c != 'Staged' && run.Status__c != 'ApplyDryRunCompleted' && run.Status__c != 'ApplyFailed') {
      throw new CustomException(400, 'Point refresh run must be Staged before apply. current=' + run.Status__c);
    }

    run.Status__c = dryRun == true ? 'ApplyDryRunQueued' : 'ApplyQueued';
    run.CurrentStep__c = 'APPLY_QUEUE';
    update run;

    Id jobId = Database.executeBatch(new GdPointRefreshStageApplyBatch(runId, dryRun == true, cleanupAfterApply == true), 1);
    run.CurrentStep__c = 'APPLY_JOB_' + String.valueOf(jobId);
    update run;
    return jobId;
  }

  public static Id startCreatePlannedLedgers(Id runId) {
    validatePlannedRun(runId);
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'CreatingLedgers';
    run.CurrentStep__c = 'CREATE_LEDGER_QUEUE';
    update run;
    return Database.executeBatch(new GdPointRefreshStageCreateLedgerBatch(runId), 200);
  }

  public static Id startCollectTargets(Id runId) {
    validateStatus(runId, new Set<String>{ 'Planned', 'TargetCollected' }, 'Planned');
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'CollectingTargets';
    run.CurrentStep__c = 'TARGET_COLLECT_QUEUE';
    update run;
    return Database.executeBatch(new GdPointRefreshStageTargetCollectBatch(runId), 500);
  }

  public static Id startDeleteTargetTraces(Id runId) {
    validateStatus(runId, new Set<String>{ 'TargetCollected' }, 'TargetCollected');
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'DeletingTargetTraces';
    run.CurrentStep__c = 'DELETE_TRACE_QUEUE';
    update run;
    return Database.executeBatch(new GdPointRefreshStageDeleteTraceBatch(runId), 2000);
  }

  public static Id startDeleteTargetLedgers(Id runId) {
    validateStatus(runId, new Set<String>{ 'TargetTracesDeleted' }, 'TargetTracesDeleted');
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'DeletingTargetLedgers';
    run.CurrentStep__c = 'DELETE_LEDGER_QUEUE';
    update run;
    return Database.executeBatch(new GdPointRefreshStageDeleteLedgerBatch(runId), 2000);
  }

  public static Id startDeleteTargetJournals(Id runId) {
    validateStatus(runId, new Set<String>{ 'TargetLedgersDeleted' }, 'TargetLedgersDeleted');
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'DeletingTargetJournals';
    run.CurrentStep__c = 'DELETE_JOURNAL_QUEUE';
    update run;
    return Database.executeBatch(new GdPointRefreshStageDeleteJournalBatch(runId), 2000);
  }

  public static Id startCreatePlannedTraces(Id runId) {
    List<GdPointRefreshRun__c> runs = [
      SELECT Id, Status__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    if (runs.isEmpty()) {
      throw new CustomException(400, 'Point refresh run not found. ' + runId);
    }
    if (runs[0].Status__c != 'LedgersCreated') {
      throw new CustomException(400, 'Point refresh run must be LedgersCreated before trace creation. current=' + runs[0].Status__c);
    }
    GdPointRefreshRun__c run = new GdPointRefreshRun__c(Id = runId);
    run.Status__c = 'CreatingTraces';
    run.CurrentStep__c = 'CREATE_TRACE_QUEUE';
    update run;
    return Database.executeBatch(new GdPointRefreshStageCreateTraceBatch(runId), 200);
  }

  private static void validatePlannedRun(Id runId) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    List<GdPointRefreshRun__c> runs = [
      SELECT Id, Status__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    if (runs.isEmpty()) {
      throw new CustomException(400, 'Point refresh run not found. ' + runId);
    }
    if (runs[0].Status__c != 'TargetDeleted') {
      throw new CustomException(400, 'Point refresh run must be TargetDeleted before ledger creation. current=' + runs[0].Status__c);
    }
  }

  private static void validateStatus(Id runId, Set<String> allowedStatuses, String expectedLabel) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    List<GdPointRefreshRun__c> runs = [
      SELECT Id, Status__c
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    if (runs.isEmpty()) {
      throw new CustomException(400, 'Point refresh run not found. ' + runId);
    }
    if (allowedStatuses == null || !allowedStatuses.contains(runs[0].Status__c)) {
      throw new CustomException(400, 'Point refresh run must be ' + expectedLabel + '. current=' + runs[0].Status__c);
    }
  }

  private static void validateMemberNoAndDate(String memberNo, Date openDate) {
    if (String.isBlank(memberNo)) {
      throw new CustomException(400, 'memberNo is required.');
    }
    if (openDate == null) {
      throw new CustomException(400, 'openDate is required.');
    }
  }

  private static void guardNoDestructiveRun(String memberNo) {
    List<GdPointRefreshRun__c> runs = [
      SELECT Id, Status__c, CurrentStep__c
      FROM GdPointRefreshRun__c
      WHERE MemberNo__c = :memberNo AND Status__c IN :DESTRUCTIVE_RUN_STATUSES
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    if (!runs.isEmpty()) {
      throw new CustomException(400, 'Point refresh apply is already in progress for member. runId=' + runs[0].Id + ', status=' + runs[0].Status__c);
    }
  }

  private static void supersedeExistingValidationRuns(String memberNo) {
    List<GdPointRefreshRun__c> runs = [
      SELECT Id, Status__c
      FROM GdPointRefreshRun__c
      WHERE MemberNo__c = :memberNo AND Status__c IN :VALIDATION_RUN_STATUSES
      ORDER BY CreatedDate DESC
      LIMIT 50
    ];
    if (runs.isEmpty()) {
      return;
    }
    Set<Id> runIds = new Set<Id>();
    for (GdPointRefreshRun__c run : runs) {
      run.Status__c = 'Superseded';
      run.CurrentStep__c = 'SUPERSEDED_BY_NEW_VALIDATION';
      runIds.add(run.Id);
    }
    update runs;
    Database.executeBatch(new GdPointRefreshStageCleanupByRunBatch(runIds), 2000);
  }

  private static GdPointRefreshRun__c validateLatestPlannedRun(Id runId) {
    if (runId == null) {
      throw new CustomException(400, 'runId is required.');
    }
    GdPointRefreshRun__c run = [
      SELECT Id, MemberNo__c, Status__c, CreatedDate
      FROM GdPointRefreshRun__c
      WHERE Id = :runId
      LIMIT 1
    ];
    if (run.Status__c != 'Planned') {
      throw new CustomException(400, 'Only Planned validation run can be applied. current=' + run.Status__c);
    }
    List<GdPointRefreshRun__c> newerRuns = [
      SELECT Id, Status__c, CreatedDate
      FROM GdPointRefreshRun__c
      WHERE MemberNo__c = :run.MemberNo__c
      AND CreatedDate > :run.CreatedDate
      AND Status__c IN :VALIDATION_RUN_STATUSES
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    if (!newerRuns.isEmpty()) {
      throw new CustomException(400, 'A newer validation run exists. latestRunId=' + newerRuns[0].Id + ', status=' + newerRuns[0].Status__c);
    }
    guardNoDestructiveRun(run.MemberNo__c);
    return run;
  }

  public static String buildSortKey(Date eventDate, Integer sequence, String key) {
    String datePart = eventDate == null ? '99999999' : String.valueOf(eventDate).replace('-', '');
    String seqPart = String.valueOf(sequence == null ? 0 : sequence).leftPad(10, '0');
    return datePart + ':' + seqPart + ':' + String.valueOf(key);
  }

  private static Datetime defaultMigrationCutoff(Date openDate) {
    return openDate == null ? null : TimeUtil.dateToUtcStartOfDay(openDate);
  }

  private static RefreshConfig resolveRefreshConfig(Date requestedOpenDate, Datetime requestedMigrationCutoff) {
    GdPointRefreshSetting__c setting = GdPointRefreshSetting__c.getOrgDefaults();
    RefreshConfig config = new RefreshConfig();
    config.openDate = requestedOpenDate;
    config.useCreatedDateCutoff = true;
    config.migrationCutoffDateTime = requestedMigrationCutoff;

    if (setting != null) {
      if (config.openDate == null) {
        config.openDate = setting.OpenDate__c;
      }
      config.useCreatedDateCutoff = setting.UseCreatedDateCutoff__c == null ? true : setting.UseCreatedDateCutoff__c;
      if (config.migrationCutoffDateTime == null) {
        config.migrationCutoffDateTime = setting.MigrationCreatedDateCutoff__c;
      }
    }

    if (config.migrationCutoffDateTime == null) {
      config.migrationCutoffDateTime = defaultMigrationCutoff(config.openDate);
    }
    return config;
  }
}