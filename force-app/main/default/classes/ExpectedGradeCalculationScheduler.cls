/**
 * 예상 등급 산정 스케줄러
 * 실행 시기 : 매년 1월 12일
 *
 * @author Changhwan Kim
 * @since 2026-01-30
 */
public with sharing class ExpectedGradeCalculationScheduler implements Schedulable {
    @TestVisible
    static Boolean testForceCustomException = false;

    @TestVisible
    static Boolean testForceException = false;

    public void execute(SchedulableContext sc) {
        ApexLogger logger = new ApexLogger(
            ApexLogger.JobType.ASYNCHRONOUS,
            sc.getTriggerId(),
            null
        );
        logger.logging(ExpectedGradeCalculationScheduler.class.getName());
        logger.setRequestDatetime(Datetime.now());

        // (선택) 시작 알림
        SchedulerNotificationPublisher.publishStarted(
            'ExpectedGradeCalculationScheduler',
            'TriggerId=' + sc.getTriggerId(),
            null
        );

        try {
            // 테스트에서 catch 분기 강제 커버를 위한 훅
            if (Test.isRunningTest() && testForceCustomException) {
                throw new CustomException(500, 'Forced custom exception for test');
            }
            if (Test.isRunningTest() && testForceException) {
                Integer x = 1 / 0;
            }

            Database.executeBatch(new ExpectedGradeCalculationBatch(), 1000); // 회원 1000명 씩 실행

            logger.setStatus('SUCCESS');
            logger.setDescription('Batch enqueued. triggerId=' + sc.getTriggerId());
        } catch (CustomException ce) {
            logger.createCustomExceptionLog(ce);
            logger.setStatus('ERROR');

            // (선택) 스케줄러 레벨 실패도 알림
            SchedulerNotificationPublisher.publishResult(
                'ExpectedGradeCalculationScheduler',
                SchedulerNotificationPublisher.ResultStatus.ERROR,
                'Scheduler failed: ' + ce.getMessage(),
                null,
                null
            );
        } catch (Exception e) {
            logger.createExceptionLog(e);
            logger.setStatus('ERROR');

            SchedulerNotificationPublisher.publishResult(
                'ExpectedGradeCalculationScheduler',
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