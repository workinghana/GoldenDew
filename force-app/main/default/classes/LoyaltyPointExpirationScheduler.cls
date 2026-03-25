/**
 * 포인트 소멸 처리 스케줄러
 * 실행 시기 : 매일 00시 10분
 *
 * @author Changhwan Kim
 * @since 2026-02-03
 */
public with sharing class LoyaltyPointExpirationScheduler implements Schedulable {
  public void execute(SchedulableContext sc) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, sc.getTriggerId(), null);
    logger.logging(LoyaltyPointExpirationScheduler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    // (선택) 시작 알림
    SchedulerNotificationPublisher.publishStarted('LoyaltyPointExpirationScheduler', 'TriggerId=' + sc.getTriggerId(), null);

    try {
      Database.executeBatch(new LoyaltyPointExpirationBatch(), 200); // 로열티 레저 레코드 200건 씩 처리

      logger.setStatus('SUCCESS');
      logger.setDescription('Batch enqueued. triggerId=' + sc.getTriggerId());
    } catch (CustomException ce) {
      logger.createCustomExceptionLog(ce);
      logger.setStatus('ERROR');

      // (선택) 스케줄러 레벨 실패도 알림
      SchedulerNotificationPublisher.publishResult(
        'LoyaltyPointExpirationScheduler',
        SchedulerNotificationPublisher.ResultStatus.ERROR,
        'Scheduler failed: ' + ce.getMessage(),
        null,
        null
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');

      SchedulerNotificationPublisher.publishResult(
        'LoyaltyPointExpirationScheduler',
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