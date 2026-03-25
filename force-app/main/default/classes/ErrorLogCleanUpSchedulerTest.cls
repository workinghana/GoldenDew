@IsTest
private class ErrorLogCleanUpSchedulerTest {
    private static ApexAuditTrail__c makeLog(String suffix) {
        ApexAuditTrail__c log = new ApexAuditTrail__c();
        log.Status__c = 'SUCCESS';
        log.HttpStatusCode__c = '200';
        log.RequestDateTime__c = System.now();
        log.ApexClass__c = 'ErrorLogCleanUpSchedulerTest_' + suffix;
        log.Method__c = 'POST';
        log.RequestUrl__c = '/services/apexrest/test/' + suffix;
        insert log;
        return log;
    }

    @IsTest
    static void test_execute_withTarget_enqueuesBatch() {
        ApexAuditTrail__c oldLog = makeLog('old');
        Test.setCreatedDate(oldLog.Id, System.now().addDays(-20));

        String jobName = 'ErrorLogCleanUpScheduler_WithTarget';

        Test.startTest();
        System.schedule(jobName, '0 0 0 1 1 ? 2099', new ErrorLogCleanUpScheduler());
        Test.stopTest();

        Integer batchCnt = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'ErrorLogCleanUpBatch'
        ];
        System.assert(batchCnt > 0, 'Batch job should be enqueued when old logs exist');
    }

    @IsTest
    static void test_execute_withoutTarget_noBatchEnqueued() {
        ApexAuditTrail__c recentLog = makeLog('recent');
        Test.setCreatedDate(recentLog.Id, System.now().addDays(-1));

        String jobName = 'ErrorLogCleanUpScheduler_NoTarget';

        Test.startTest();
        System.schedule(jobName, '0 0 0 1 1 ? 2099', new ErrorLogCleanUpScheduler());
        Test.stopTest();

        Integer batchCnt = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'ErrorLogCleanUpBatch'
        ];
        System.assertEquals(0, batchCnt, 'Batch job should not be enqueued when no old logs exist');
    }
}