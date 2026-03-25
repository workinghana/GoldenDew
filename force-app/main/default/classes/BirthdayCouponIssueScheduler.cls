/**
 * 생일 쿠폰 지급 스케줄러
 * 실행 시기 : 매월 1일
 */
public with sharing class BirthdayCouponIssueScheduler implements Schedulable {
  private final String VOUCHER_CATEGORY_NAME_BIRTHDAY_COUPON = 'BirthdayCoupon';

  public void execute(SchedulableContext sc) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, sc.getTriggerId(), null);
    logger.logging(BirthdayCouponIssueScheduler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    // (선택) 시작 알림
    SchedulerNotificationPublisher.publishStarted('BirthdayCouponIssueScheduler', 'TriggerId=' + sc.getTriggerId(), null);

    try {
      if (!([SELECT COUNT() FROM VoucherDefinition WHERE VoucherCategoryId__r.Code__c = :VOUCHER_CATEGORY_NAME_BIRTHDAY_COUPON LIMIT 1] > 0)) {
        throw new CustomException(404, '지급 가능한 쿠폰이 없습니다.');
      }

      Database.executeBatch(new BirthdayCouponIssueBatch(), 50);

      logger.setStatus('SUCCESS');
      logger.setDescription('Batch enqueued. triggerId=' + sc.getTriggerId());
    } catch (CustomException ce) {
      logger.createCustomExceptionLog(ce);
      logger.setStatus('ERROR');

      // (선택) 스케줄러 레벨 실패도 알림
      SchedulerNotificationPublisher.publishResult(
        'BirthdayCouponIssueScheduler',
        SchedulerNotificationPublisher.ResultStatus.ERROR,
        'Scheduler failed: ' + ce.getMessage(),
        null,
        null
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');

      SchedulerNotificationPublisher.publishResult(
        'BirthdayCouponIssueScheduler',
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