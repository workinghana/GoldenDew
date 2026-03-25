/**
 * MCE 매거진 구독 데이터 동기화 스케줄러
 * 실행 시기 : 매일 06:00
 *
 * @author Changhwan Kim
 * @since 2026-02-25
 */
public with sharing class MceDailyMagazineSyncScheduler implements Schedulable {
  public void execute(SchedulableContext sc) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, sc.getTriggerId(), null);
    logger.logging(MceDailyMagazineSyncScheduler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    // (선택) 시작 알림
    SchedulerNotificationPublisher.publishStarted('MceDailyMagazineSyncScheduler', 'TriggerId=' + sc.getTriggerId(), null);

    try {
      System.enqueueJob(new MceMagazineSubscriptionFetchJob(null, 1));

      logger.setStatus('SUCCESS');
      logger.setDescription('Batch enqueued. triggerId=' + sc.getTriggerId());
    } catch (CustomException ce) {
      logger.createCustomExceptionLog(ce); logger.setStatus('ERROR'); SchedulerNotificationPublisher.publishResult('MceDailyMagazineSyncScheduler', SchedulerNotificationPublisher.ResultStatus.ERROR, 'Scheduler failed: ' + ce.getMessage(), null, null);
    } catch (Exception e) {
      logger.createExceptionLog(e); logger.setStatus('ERROR'); SchedulerNotificationPublisher.publishResult('MceDailyMagazineSyncScheduler', SchedulerNotificationPublisher.ResultStatus.ERROR, 'Scheduler failed: ' + e.getMessage(), null, null);
    } finally {
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }
}