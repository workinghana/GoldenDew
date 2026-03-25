/**
 * Apex Audit Trail 로그 삭제 스케줄러
 * 실행 시기 : 매일 (예: 새벽 3시)
 * 보관 기간 : 14일
 */
public with sharing class ErrorLogCleanUpScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {

        ApexLogger logger =
            new ApexLogger(
                ApexLogger.JobType.ASYNCHRONOUS,
                sc.getTriggerId(),
                null
            );

        logger.logging(ErrorLogCleanUpScheduler.class.getName());
        logger.setRequestDatetime(Datetime.now());

        // (선택) 시작 알림
        SchedulerNotificationPublisher.publishStarted(
            'ErrorLogCleanUpScheduler',
            'TriggerId=' + sc.getTriggerId(),
            null
        );

        try {
            // 삭제 대상 존재 여부 체크
            DateTime cutoffDate = System.now().addDays(-14);

            Integer targetCount = [
                SELECT COUNT()
                FROM ApexAuditTrail__c
                WHERE CreatedDate < :cutoffDate
            ];

            if (targetCount == 0) {
                throw new CustomException(204, '삭제 대상 로그가 없습니다.');
            }

            // Batch 실행
            Database.executeBatch(
                new ErrorLogCleanUpBatch(),
                200
            );

            logger.setStatus('SUCCESS');
            logger.setDescription(
                'Log cleanup batch enqueued. triggerId=' + sc.getTriggerId()
            );

        } catch (CustomException ce) {

            logger.createCustomExceptionLog(ce);
            logger.setStatus('ERROR');

            SchedulerNotificationPublisher.publishResult(
                'ErrorLogCleanUpScheduler',
                SchedulerNotificationPublisher.ResultStatus.ERROR,
                'Scheduler failed: ' + ce.getMessage(),
                null,
                null
            );

        } catch (Exception e) {

            logger.createExceptionLog(e);
            logger.setStatus('ERROR');

            SchedulerNotificationPublisher.publishResult(
                'ErrorLogCleanUpScheduler',
                SchedulerNotificationPublisher.ResultStatus.ERROR,
                'Scheduler failed: ' + e.getMessage(),
                null,
                null
            );

        } finally {

            logger.setResponseDatetime(Datetime.now());
            logger.addLog();
            ApexLogger.insertLogs();
        }
    }
}