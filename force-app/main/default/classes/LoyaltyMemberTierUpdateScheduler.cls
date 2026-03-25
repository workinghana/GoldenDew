/**
 * 회원 등급 변경 스케줄러
 * 실행 시기 : 매년 2월 1일
 * - 실제 회원 등급 변경
 *
 * @author Changhwan Kim
 * @since 2026-01-30
 */
public with sharing class LoyaltyMemberTierUpdateScheduler implements Schedulable {
  public void execute(SchedulableContext sc) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, sc.getTriggerId(), null);
    logger.logging(LoyaltyMemberTierUpdateScheduler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    // (선택) 시작 알림
    SchedulerNotificationPublisher.publishStarted('LoyaltyMemberTierUpdateScheduler', 'TriggerId=' + sc.getTriggerId(), null);

    try {
      Database.executeBatch(new LoyaltyMemberTierUpdateBatch(), 100); // 회원 100명 씩 실행

      logger.setStatus('SUCCESS');
      logger.setDescription('Batch enqueued. triggerId=' + sc.getTriggerId());
    } catch (CustomException ce) {
      logger.createCustomExceptionLog(ce);
      logger.setStatus('ERROR');

      // (선택) 스케줄러 레벨 실패도 알림
      SchedulerNotificationPublisher.publishResult(
        'LoyaltyMemberTierUpdateScheduler',
        SchedulerNotificationPublisher.ResultStatus.ERROR,
        'Scheduler failed: ' + ce.getMessage(),
        null,
        null
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');

      SchedulerNotificationPublisher.publishResult(
        'LoyaltyMemberTierUpdateScheduler',
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