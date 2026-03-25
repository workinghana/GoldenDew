/**
 * 쿠폰 지급 스케줄러
 * 실행 시기 : 반기
 *
 * @author Changhwan Kim
 * @since 2026-01-26
 */
public with sharing class HalfYearCouponIssueScheduler implements Schedulable {
  private final String VOUCHER_CATEGORY_NAME_HALF_YEAR_COUPON = 'HalfYearCoupon'; // 반기 지급 쿠폰 카테고리 이름

  public void execute(SchedulableContext sc) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, sc.getTriggerId(), null);
    logger.logging(HalfYearCouponIssueScheduler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    // (선택) 시작 알림
    SchedulerNotificationPublisher.publishStarted('HalfYearCouponIssueScheduler', 'TriggerId=' + sc.getTriggerId(), null);

    try {
      if (!([SELECT COUNT() FROM VoucherDefinition WHERE VoucherCategoryId__r.Code__c = :VOUCHER_CATEGORY_NAME_HALF_YEAR_COUPON LIMIT 1] > 0)) {
        throw new CustomException(404, '지급 가능한 반기 쿠폰이 없습니다.');
      }

      // 월 지급 배치 실행 (배치 사이즈는 정책에 맞게)
      Database.executeBatch(new MonthlyCouponIssueBatch(), 50);

      logger.setStatus('SUCCESS');
      logger.setDescription('Batch enqueued. triggerId=' + sc.getTriggerId());
    } catch (CustomException ce) {
      logger.createCustomExceptionLog(ce);
      logger.setStatus('ERROR');

      SchedulerNotificationPublisher.publishResult(
        'HalfYearCouponIssueScheduler',
        SchedulerNotificationPublisher.ResultStatus.ERROR,
        'Scheduler failed: ' + ce.getMessage(),
        null,
        null
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');

      SchedulerNotificationPublisher.publishResult(
        'HalfYearCouponIssueScheduler',
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