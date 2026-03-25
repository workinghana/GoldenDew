@IsTest
private class ErrorLogCleanUpBatchTest {
    private static ApexAuditTrail__c makeLog(String suffix) {
        ApexAuditTrail__c log = new ApexAuditTrail__c();
        log.Status__c = 'SUCCESS';
        log.HttpStatusCode__c = '200';
        log.RequestDateTime__c = System.now();
        log.ApexClass__c = 'ErrorLogCleanUpBatchTest_' + suffix;
        log.Method__c = 'POST';
        log.RequestUrl__c = '/services/apexrest/test/' + suffix;
        insert log;
        return log;
    }

    @IsTest
    static void test_execute_deletes_only_old_logs() {
        ApexAuditTrail__c oldLog1 = makeLog('old1');
        ApexAuditTrail__c oldLog2 = makeLog('old2');
        ApexAuditTrail__c recentLog = makeLog('recent');

        Test.setCreatedDate(oldLog1.Id, System.now().addDays(-20));
        Test.setCreatedDate(oldLog2.Id, System.now().addDays(-30));
        Test.setCreatedDate(recentLog.Id, System.now().addDays(-2));

        Test.startTest();
        Database.executeBatch(new ErrorLogCleanUpBatch(), 200);
        Test.stopTest();

        Map<Id, ApexAuditTrail__c> byId = new Map<Id, ApexAuditTrail__c>(
            [
                SELECT Id, IsDeleted
                FROM ApexAuditTrail__c
                WHERE Id IN :new Set<Id>{ oldLog1.Id, oldLog2.Id, recentLog.Id }
                ALL ROWS
            ]
        );

        System.assertEquals(true, byId.get(oldLog1.Id).IsDeleted, 'Old log 1 should be deleted');
        System.assertEquals(true, byId.get(oldLog2.Id).IsDeleted, 'Old log 2 should be deleted');
        System.assertEquals(false, byId.get(recentLog.Id).IsDeleted, 'Recent log should remain');
    }

    @IsTest
    static void test_execute_with_no_old_logs() {
        ApexAuditTrail__c recentLog = makeLog('recent_only');
        Test.setCreatedDate(recentLog.Id, System.now().addDays(-1));

        Test.startTest();
        Database.executeBatch(new ErrorLogCleanUpBatch(), 50);
        Test.stopTest();

        ApexAuditTrail__c remained = [
            SELECT Id
            FROM ApexAuditTrail__c
            WHERE Id = :recentLog.Id
            LIMIT 1
        ];
        System.assertEquals(recentLog.Id, remained.Id, 'Recent log should not be deleted');
    }
}