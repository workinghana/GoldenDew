@IsTest
private class ScheduleJobResultTriggerTest {
    
    @IsTest
    static void testTriggerExecution() {
        // Given: 테스트용 플랫폼 이벤트 생성
        SchedulerJobResult__e testEvent = new SchedulerJobResult__e(
            JobName__c = 'Trigger Test Job',
            Status__c = 'SUCCESS',
            Summary__c = 'Trigger test summary'
        );

        Test.startTest();
        
        // When: 플랫폼 이벤트를 발행 (이 순간 SchedulerJobResultTrigger가 자동으로 실행됩니다)
        Database.SaveResult sr = EventBus.publish(testEvent);
        
        Test.stopTest();

        // Then: 에러 없이 정상적으로 이벤트가 발행(트리거 실행)되었는지 검증
        System.assertEquals(true, sr.isSuccess(), '플랫폼 이벤트가 에러 없이 발행되고 트리거가 실행되어야 합니다.');
    }
}