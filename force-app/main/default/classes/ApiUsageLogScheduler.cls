/**
 * 하루 2회(오전/오후) API 사용량을 API_Usage_Log__c에 기록하는 Schedulable.
 *
 * 기본 스케줄은 매일 오전 11시 / 오후 5시이며, 각각 별도의 CronTrigger로 등록된다.
 * OrgLimits 조회와 DML만 수행하므로 Queueable 위임 없이 직접 기록한다.
 *
 * 등록 예시 (Anonymous Apex):
 *   ApiUsageLogScheduler.scheduleTwiceDaily();
 */
public with sharing class ApiUsageLogScheduler implements Schedulable {
  public static final String JOB_NAME_AM = 'API_Usage_Log_AM';
  public static final String JOB_NAME_PM = 'API_Usage_Log_PM';
  /** 매일 오전 11시 정각 */
  public static final String CRON_AM = '0 0 11 * * ?';
  /** 매일 오후 5시(17시) 정각 */
  public static final String CRON_PM = '0 0 17 * * ?';

  /**
   * 잡 이름 접두사. 테스트에서 실제 org에 예약된 잡과의 이름 충돌을 피하기 위해
   * 고유 값을 주입한다. 운영 경로에서는 빈 문자열이다.
   */
  @TestVisible
  private static String jobNamePrefix = '';

  /**
   * 오전/오후 2개의 기록 스케줄 잡을 등록한다.
   *
   * @return 등록된 CronTrigger Id 목록 [AM, PM]
   * @example
   * ApiUsageLogScheduler.scheduleTwiceDaily();
   */
  public static List<Id> scheduleTwiceDaily() {
    return new List<Id>{
      System.schedule(jobNamePrefix + JOB_NAME_AM, CRON_AM, new ApiUsageLogScheduler()),
      System.schedule(jobNamePrefix + JOB_NAME_PM, CRON_PM, new ApiUsageLogScheduler())
    };
  }

  /**
   * 스케줄 실행 시 현재 API 사용량을 기록한다.
   *
   * @param context 스케줄 실행 컨텍스트
   */
  public void execute(SchedulableContext context) {
    try {
      ApiUsageLogRecorder.record();
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] API 사용량 기록 실패: ' + e.getMessage() + '\n' + e.getStackTraceString());
    }
  }
}