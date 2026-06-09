/**
 * ApiUsageLogRecorder 테스트.
 * OrgLimits 의존성은 usedOverride/limitOverride로 주입하고,
 * 날짜·시간대 중복 방지 로직은 save()에 고정 시각을 넣어 결정적으로 검증한다.
 */
@isTest
private class ApiUsageLogRecorderTest {

  @isTest
  static void shouldInsertLog_WhenRecordExecutes() {
    // Given
    ApiUsageLogRecorder.usedOverride = 1500;
    ApiUsageLogRecorder.limitOverride = 100000;

    // When
    Test.startTest();
    Id logId = ApiUsageLogRecorder.record();
    Test.stopTest();

    // Then
    Assert.isNotNull(logId, '레코드가 저장되어야 합니다');
    API_Usage_Log__c log = [
      SELECT Used_Requests__c, Max_Requests__c, Usage_Percent__c, Log_Date__c, Time_Slot__c, Recorded_At__c
      FROM API_Usage_Log__c
      WHERE Id = :logId
    ];
    Assert.areEqual(1500, log.Used_Requests__c, '사용량이 저장되어야 합니다');
    Assert.areEqual(100000, log.Max_Requests__c, '한도가 저장되어야 합니다');
    Assert.areEqual(1.5, log.Usage_Percent__c, '사용률(1.5%)이 계산되어야 합니다');
    Assert.areEqual(Date.today(), log.Log_Date__c, '오늘 날짜로 기록되어야 합니다');
    Assert.isNotNull(log.Recorded_At__c, '기록 시각이 저장되어야 합니다');
  }

  @isTest
  static void shouldSkipDuplicate_WhenSameDateAndSlot() {
    // Given
    DateTime morning = DateTime.newInstance(2026, 6, 8, 9, 0, 0);

    // When
    Test.startTest();
    Id first = ApiUsageLogRecorder.save(100, 1000, morning);
    Id second = ApiUsageLogRecorder.save(200, 1000, morning);
    Test.stopTest();

    // Then
    Assert.isNotNull(first, '첫 기록은 저장되어야 합니다');
    Assert.isNull(second, '같은 날짜·시간대 중복 기록은 건너뛰어야 합니다');
    Assert.areEqual(1, [SELECT COUNT() FROM API_Usage_Log__c], '레코드는 1건만 존재해야 합니다');
  }

  @isTest
  static void shouldAllowAmAndPm_OnSameDay() {
    // Given
    DateTime morning = DateTime.newInstance(2026, 6, 8, 9, 0, 0);
    DateTime evening = DateTime.newInstance(2026, 6, 8, 21, 0, 0);

    // When
    Test.startTest();
    Id amId = ApiUsageLogRecorder.save(100, 1000, morning);
    Id pmId = ApiUsageLogRecorder.save(500, 1000, evening);
    Test.stopTest();

    // Then
    Assert.isNotNull(amId, '오전 기록이 저장되어야 합니다');
    Assert.isNotNull(pmId, '오후 기록이 저장되어야 합니다');
    Assert.areEqual(2, [SELECT COUNT() FROM API_Usage_Log__c], '하루 2건(오전/오후)이 저장되어야 합니다');
  }

  @isTest
  static void shouldResolveSlotByHour() {
    // Then
    Assert.areEqual('AM', ApiUsageLogRecorder.resolveSlot(DateTime.newInstance(2026, 6, 8, 0, 0, 0)), '0시는 AM');
    Assert.areEqual('AM', ApiUsageLogRecorder.resolveSlot(DateTime.newInstance(2026, 6, 8, 11, 59, 0)), '11:59는 AM');
    Assert.areEqual('PM', ApiUsageLogRecorder.resolveSlot(DateTime.newInstance(2026, 6, 8, 12, 0, 0)), '12시는 PM');
    Assert.areEqual('PM', ApiUsageLogRecorder.resolveSlot(DateTime.newInstance(2026, 6, 8, 23, 0, 0)), '23시는 PM');
  }
}