/**
 * 매시간 API 사용량 Slack 알림을 트리거하는 Schedulable.
 *
 * 콜아웃은 Schedulable에서 직접 수행할 수 없으므로
 * ApiUsageMonitorQueueable을 enqueue하여 위임한다.
 *
 * 등록 예시 (Anonymous Apex):
 *   ApiUsageMonitorScheduler.scheduleHourly();
 */
public with sharing class ApiUsageMonitorScheduler implements Schedulable {
  public static final String JOB_NAME = 'API_Usage_Monitor_Hourly';
  public static final String CRON_HOURLY = '0 0 * * * ?';

  /**
   * 매시 정각 실행되도록 스케줄 잡을 등록한다.
   *
   * @return 등록된 스케줄 잡 Id
   * @example
   * ApiUsageMonitorScheduler.scheduleHourly();
   */
  public static Id scheduleHourly() {
    return System.schedule(JOB_NAME, CRON_HOURLY, new ApiUsageMonitorScheduler());
  }

  /**
   * 스케줄 실행 시 API 사용량 알림 Queueable을 enqueue한다.
   *
   * @param context 스케줄 실행 컨텍스트
   */
  public void execute(SchedulableContext context) {
    try {
      System.enqueueJob(new ApiUsageMonitorQueueable());
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] API 사용량 Queueable enqueue 실패: ' + e.getMessage());
    }
  }
}