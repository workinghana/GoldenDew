/**
 * Apex Audit Trail 로그 정리 Batch
 * 보관 기간 : 14일
 */
public with sharing class ErrorLogCleanUpBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private static final Integer RETENTION_DAYS = 14;

    // 전체 누적
    private Set<Id> totalSuccess = new Set<Id>();
    private Set<Id> totalFail = new Set<Id>();

    /* =========================
       Batch start
    ========================= */
    public Database.QueryLocator start(Database.BatchableContext bc) {

        DateTime cutoffDate = System.now().addDays(-RETENTION_DAYS);

        return Database.getQueryLocator([
            SELECT Id
            FROM ApexAuditTrail__c
            WHERE CreatedDate < :cutoffDate
        ]);
    }

    /* =========================
       Batch execute (chunk)
    ========================= */
    public void execute(
        Database.BatchableContext bc,
        List<ApexAuditTrail__c> scope
    ) {

        ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS,bc.getJobId(),null);

        logger.logging(ErrorLogCleanUpBatch.class.getName());
        logger.setRequestDatetime(Datetime.now());

        if (scope != null && !scope.isEmpty()) {
            logger.setScopedIds((List<SObject>) scope, 'Id');
        }

        Set<Id> successIds = new Set<Id>();
        Set<Id> failIds = new Set<Id>();
        List<String> failMsgs = new List<String>();

        try {

            if (scope == null || scope.isEmpty()) {
                logger.setStatus('SUCCESS');
                logger.setDescription('scope is empty');
                return;
            }

            Database.DeleteResult[] results =
                Database.delete(scope, false);

            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    successIds.add(scope[i].Id);
                } else {
                    failIds.add(scope[i].Id);
                    for (Database.Error err : results[i].getErrors()) {
                        failMsgs.add(
                            'Id=' + scope[i].Id + ' | ' + err.getMessage()
                        );
                    }
                }
            }

            if (!failIds.isEmpty() && !successIds.isEmpty()) {
                logger.setStatus('PARTIAL');
            } else if (!failIds.isEmpty()) {
                logger.setStatus('ERROR');
            } else {
                logger.setStatus('SUCCESS');
            }

            logger.setDescription(
                'chunkSize=' + scope.size()
                + ', success=' + successIds.size()
                + ', fail=' + failIds.size()
            );

        } catch (Exception e) {

            logger.createExceptionLog(e);
            logger.setStatus('ERROR');

        } finally {

    totalSuccess.addAll(successIds);
    totalFail.addAll(failIds);

    // 🔹 Id → String 변환 (ApexLogger 시그니처에 맞춤)
    Set<String> successIdStrings = new Set<String>();
    for (Id sid : successIds) {
        successIdStrings.add((String) sid);
    }

    Set<String> failIdStrings = new Set<String>();
    for (Id fid : failIds) {
        failIdStrings.add((String) fid);
    }

    if (!successIdStrings.isEmpty()) {
        logger.setSuccessRecordIds(successIdStrings);
    }
    if (!failIdStrings.isEmpty()) {
        logger.setFailedRecordIds(failIdStrings);
    }
    if (!failMsgs.isEmpty()) {
        logger.setErrorMessage(String.join(failMsgs, ' | '));
    }

    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();
}

    }

    /* =========================
       Batch finish
    ========================= */
    public void finish(Database.BatchableContext bc) {

        totalFail.removeAll(totalSuccess);

        Integer successCnt = totalSuccess.size();
        Integer failCnt = totalFail.size();

        String status;
        SchedulerNotificationPublisher.ResultStatus notifStatus;

        if (failCnt > 0 && successCnt > 0) {
            status = 'PARTIAL';
            notifStatus = SchedulerNotificationPublisher.ResultStatus.PARTIAL;
        } else if (failCnt > 0) {
            status = 'ERROR';
            notifStatus = SchedulerNotificationPublisher.ResultStatus.ERROR;
        } else {
            status = 'SUCCESS';
            notifStatus = SchedulerNotificationPublisher.ResultStatus.SUCCESS;
        }

        // 요약 로그
        ApexLogger logger =
            new ApexLogger(
                ApexLogger.JobType.ASYNCHRONOUS,
                bc.getJobId(),
                null
            );

        logger.logging(ErrorLogCleanUpBatch.class.getName());
        logger.setStatus(status);
        logger.setDescription(
            'TOTAL success=' + successCnt
            + ', fail=' + failCnt
        );
        logger.setResponseDatetime(Datetime.now());
        logger.addLog();
        ApexLogger.insertLogs();

        // 결과 알림
        String msg =
            'Status=' + status
            + ', success=' + successCnt
            + ', fail=' + failCnt
            + ', jobId=' + bc.getJobId();

        SchedulerNotificationPublisher.publishResult(
            'ErrorLogCleanUpBatch',
            notifStatus,
            msg,
            bc.getJobId(),
            null
        );
    }
}