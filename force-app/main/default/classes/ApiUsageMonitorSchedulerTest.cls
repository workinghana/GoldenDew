/**
 * ApiUsageMonitorScheduler 테스트.
 * CRON 등록과 Queueable enqueue 위임을 검증한다.
 */
@isTest
private class ApiUsageMonitorSchedulerTest {
  private class NoopMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      return res;
    }
  }

  @isTest
  static void shouldRegisterCronJob_WhenScheduleHourly() {
    // When
    Test.startTest();
    Id jobId = ApiUsageMonitorScheduler.scheduleHourly();
    Test.stopTest();

    // Then
    CronTrigger registered = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
    Assert.areEqual(ApiUsageMonitorScheduler.CRON_HOURLY, registered.CronExpression, '매시 정각 CRON으로 등록되어야 합니다');
  }

  @isTest
  static void shouldEnqueueQueueable_WhenExecute() {
    // Given
    Test.setMock(HttpCalloutMock.class, new NoopMock());

    // When
    Test.startTest();
    new ApiUsageMonitorScheduler().execute(null);

    // Then
    Assert.areEqual(1, Limits.getQueueableJobs(), 'Queueable이 정확히 1건 enqueue되어야 합니다');
    Test.stopTest();
  }
}