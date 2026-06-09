/**
 * ApiUsageLogScheduler 테스트.
 * 스케줄 등록 시 오전/오후 2개의 CronTrigger가 생성되는지,
 * 잡 실행 시 로그가 1건 기록되는지 검증한다.
 */
@isTest
private class ApiUsageLogSchedulerTest {

  /** 실제 org/테스트 간 잡 이름 충돌을 막는 고유 접두사 (프로젝트 공통 관례) */
  private static String uniquePrefix(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime()) + '_';
  }

  @isTest
  static void shouldScheduleTwoJobs() {
    // Given: 실제 org에 예약된 동일 이름 잡과의 충돌을 피하기 위해 고유 접두사 주입
    ApiUsageLogScheduler.jobNamePrefix = uniquePrefix('Test');

    // When
    Test.startTest();
    List<Id> jobIds = ApiUsageLogScheduler.scheduleTwiceDaily();
    Test.stopTest();

    // Then
    Assert.areEqual(2, jobIds.size(), '오전/오후 2개 잡이 등록되어야 합니다');
    List<CronTrigger> triggers = [SELECT CronExpression FROM CronTrigger WHERE Id IN :jobIds];
    Assert.areEqual(2, triggers.size(), '등록된 CronTrigger가 2개여야 합니다');
  }

  @isTest
  static void shouldInsertLog_WhenJobFires() {
    // Given
    ApiUsageLogRecorder.usedOverride = 2000;
    ApiUsageLogRecorder.limitOverride = 100000;

    // When
    Test.startTest();
    new ApiUsageLogScheduler().execute(null);
    Test.stopTest();

    // Then
    Assert.areEqual(1, [SELECT COUNT() FROM API_Usage_Log__c], '잡 실행 시 로그가 1건 저장되어야 합니다');
  }
}