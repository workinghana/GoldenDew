/**
 * 생일 쿠폰 지급 스케줄러
 * 실행 시기 : 매월 1일
 * Cron : 0 0 0 1 * ?
 */
public with sharing class BirthdayCouponIssueScheduler implements Schedulable {
  @TestVisible
  private class TestHookException extends Exception {
  }

  @TestVisible
  private static Boolean forceGenericException = false;

  private final String VOUCHER_CATEGORY_NAME_BIRTHDAY_COUPON = 'BirthdayCoupon';

  public void execute(SchedulableContext sc) {
    String triggerId = sc == null ? null : sc.getTriggerId();

    ApexLogger startLogger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, triggerId, null);
    startLogger.logging(BirthdayCouponIssueScheduler.class.getName());
    startLogger.setRequestDatetime(Datetime.now());
    startLogger.setStatus('SUCCESS');
    startLogger.setDescription('Scheduler started. triggerId=' + triggerId);
    startLogger.setResponseDatetime(Datetime.now());
    startLogger.addLog();
    ApexLogger.insertLogs();

    // (선택) 시작 알림
    SchedulerNotificationPublisher.publishStarted('BirthdayCouponIssueScheduler', 'TriggerId=' + triggerId, null);

    try {
      if (Test.isRunningTest() && forceGenericException) {
        forceGenericException = false;
        throw new TestHookException('forced generic exception for test');
      }

      if (!([SELECT COUNT() FROM VoucherDefinition WHERE VoucherCategoryId__r.Code__c = :VOUCHER_CATEGORY_NAME_BIRTHDAY_COUPON LIMIT 1] > 0)) {
        throw new CustomException(404, '지급 가능한 쿠폰이 없습니다.');
      }

      Database.executeBatch(new BirthdayCouponIssueBatch(), 200);
    } catch (CustomException ce) {
      ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, triggerId, null);
      logger.logging(BirthdayCouponIssueScheduler.class.getName());
      logger.setRequestDatetime(Datetime.now());
      logger.createCustomExceptionLog(ce);
      logger.setStatus('ERROR');
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();

      // (선택) 스케줄러 레벨 실패도 알림
      SchedulerNotificationPublisher.publishResult(
        'BirthdayCouponIssueScheduler',
        SchedulerNotificationPublisher.ResultStatus.ERROR,
        'Scheduler failed: ' + ce.getMessage(),
        null,
        null
      );
    } catch (Exception e) {
      ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, triggerId, null);
      logger.logging(BirthdayCouponIssueScheduler.class.getName());
      logger.setRequestDatetime(Datetime.now());
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();

      SchedulerNotificationPublisher.publishResult(
        'BirthdayCouponIssueScheduler',
        SchedulerNotificationPublisher.ResultStatus.ERROR,
        'Scheduler failed: ' + e.getMessage(),
        null,
        null
      );
    }
  }
}