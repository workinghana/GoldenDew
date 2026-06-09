/**
 * 조직의 일일 API 요청 사용량(DailyApiRequests)을 조회하여
 * API_Usage_Log__c 커스텀 오브젝트에 1건 기록하는 클래스.
 *
 * 하루 2회(오전/오후) 스케줄로 실행되며, 같은 날짜·시간대(Log_Date__c + Time_Slot__c)에
 * 이미 기록이 있으면 중복 저장하지 않는다. 나중에 SOQL로 시계열 사용량을 조회할 수 있다.
 *
 * Slack 알림(ApiUsageMonitorQueueable)과는 독립적으로 동작한다.
 * OrgLimits 조회와 DML만 수행하며 콜아웃이 없으므로 Schedulable에서 직접 호출한다.
 */
public with sharing class ApiUsageLogRecorder {
  @TestVisible
  private static final String LIMIT_NAME = 'DailyApiRequests';

  /** AM(오전)/PM(오후) 경계 시각. 12시 미만이면 AM. */
  @TestVisible
  private static final Integer NOON_HOUR = 12;

  /** 테스트에서 OrgLimits 대신 주입하는 값 (운영 코드에서는 항상 null) */
  @TestVisible
  private static Integer usedOverride;
  @TestVisible
  private static Integer limitOverride;

  /**
   * 현재 API 사용량을 조회하여 로그 레코드를 1건 저장한다.
   * 같은 날짜·시간대에 이미 기록이 있으면 저장을 건너뛴다.
   *
   * @return 저장된 레코드 Id (중복으로 건너뛰거나 조회 실패 시 null)
   */
  public static Id record() {
    Integer used;
    Integer maxAllowed;

    if (usedOverride != null) {
      used = usedOverride;
      maxAllowed = limitOverride;
    } else {
      System.OrgLimit apiLimit = OrgLimits.getMap().get(LIMIT_NAME);
      if (apiLimit == null) {
        System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] OrgLimit을 찾을 수 없습니다: ' + LIMIT_NAME);
        return null;
      }
      used = apiLimit.getValue();
      maxAllowed = apiLimit.getLimit();
    }

    return save(used, maxAllowed, DateTime.now());
  }

  /**
   * 사용량/한도/시각을 받아 로그 레코드를 저장한다.
   * 같은 날짜·시간대 레코드가 이미 있으면 건너뛴다.
   *
   * @param used API 호출 횟수
   * @param maxAllowed 일일 한도
   * @param occurredAt 기록 시각
   * @return 저장된 레코드 Id (중복 시 null)
   */
  @TestVisible
  private static Id save(Integer used, Integer maxAllowed, DateTime occurredAt) {
    Date logDate = occurredAt.date();
    String slot = resolveSlot(occurredAt);

    List<API_Usage_Log__c> existing = [
      SELECT Id
      FROM API_Usage_Log__c
      WHERE Log_Date__c = :logDate AND Time_Slot__c = :slot
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      System.debug(LoggingLevel.INFO, '[골든듀 모니터링] 이미 기록된 시간대입니다: ' + logDate + ' ' + slot);
      return null;
    }

    API_Usage_Log__c logRecord = new API_Usage_Log__c(
      Used_Requests__c = used,
      Max_Requests__c = maxAllowed,
      Log_Date__c = logDate,
      Time_Slot__c = slot,
      Recorded_At__c = occurredAt
    );
    insert logRecord;
    return logRecord.Id;
  }

  /**
   * 시각을 기준으로 오전(AM)/오후(PM) 시간대를 구분한다.
   *
   * @param occurredAt 판별 대상 시각
   * @return 'AM' 또는 'PM'
   */
  @TestVisible
  private static String resolveSlot(DateTime occurredAt) {
    return occurredAt.hour() < NOON_HOUR ? 'AM' : 'PM';
  }
}