@IsTest
private class ErrorLogControllerV1Test {
    private static ApexAuditTrail__c makeLog(String suffix, String status, Datetime reqDt) {
        ApexAuditTrail__c log = new ApexAuditTrail__c();
        log.Status__c = status;
        log.HttpStatusCode__c = '200';
        log.RequestDateTime__c = reqDt;
        log.ApexClass__c = 'ErrorLogControllerV1Test_' + suffix;
        log.Method__c = 'POST';
        log.RequestUrl__c = '/services/apexrest/test/' + suffix;
        insert log;
        return log;
    }

    @IsTest
    static void test_getErrorLogs_withStatusFilter() {
        Datetime nowDt = System.now();

        ApexAuditTrail__c successLog = makeLog('success', 'SUCCESS', nowDt.addMinutes(-10));
        ApexAuditTrail__c errorLog = makeLog('error', 'ERROR', nowDt.addMinutes(-5));

        Test.startTest();
        List<ApexAuditTrail__c> results = ErrorLogControllerV1.getErrorLogs(
            nowDt.addDays(-1),
            nowDt.addDays(1),
            'ERROR',
            50
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return only ERROR status logs');
        System.assertEquals(errorLog.Id, results[0].Id);
        System.assertEquals('ERROR', results[0].Status__c);
        System.assertNotEquals(successLog.Id, results[0].Id);
    }

    @IsTest
    static void test_getErrorLogs_withoutStatusFilter_and_limit() {
        Datetime nowDt = System.now();

        makeLog('l1', 'SUCCESS', nowDt.addMinutes(-30));
        makeLog('l2', 'ERROR', nowDt.addMinutes(-20));
        makeLog('l3', 'ERROR', nowDt.addMinutes(-10));

        Test.startTest();
        List<ApexAuditTrail__c> results = ErrorLogControllerV1.getErrorLogs(
            nowDt.addDays(-1),
            nowDt.addDays(1),
            null,
            2
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'LIMIT should be applied');
        System.assert(
            results[0].RequestDateTime__c >= results[1].RequestDateTime__c,
            'Should be ordered by RequestDateTime__c DESC'
        );
    }

    @IsTest
    static void test_getErrorLogs_invalidPeriod_throws() {
        Test.startTest();
        try {
            ErrorLogControllerV1.getErrorLogs(null, System.now(), 'ERROR', 10);
            System.assert(false, 'Expected AuraHandledException when fromDt is null');
        } catch (AuraHandledException e) {
            // AuraHandledException.getMessage()는 테스트 컨텍스트에서 'Script-thrown exception' 반환
            System.assert(true);
        }

        try {
            ErrorLogControllerV1.getErrorLogs(System.now(), null, 'ERROR', 10);
            System.assert(false, 'Expected AuraHandledException when toDt is null');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}