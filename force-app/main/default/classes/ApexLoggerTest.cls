@IsTest
public with sharing class ApexLoggerTest {
    /* ==============================
     * 1. 기본 로깅 커버
     * ============================== */
    @IsTest
    static void cover_basic_logging() {
        ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
        logger.logging('TestClass');

        logger.setStatus('SUCCESS');
        logger.setDescription('basic logging');
        logger.setMethod('POST');
        logger.setRecordId('001000000000001');

        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM ApexAuditTrail__c]);
    }

    /* ==============================
     * 2. 일반 Exception 로그
     * ============================== */
    @IsTest
    static void cover_exception_logging() {
        ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
        logger.logging('TestClass');

        try {
            Integer i = 1 / 0;
        } catch (Exception e) {
            logger.createExceptionLog(e);
        }

        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();
    }

    /* ==============================
     * 3. CustomException 로그
     * ============================== */
    @IsTest
    static void cover_custom_exception_logging() {
        ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
        logger.logging('TestClass');

        try {
            throw new CustomException(400, 'custom error');
        } catch (CustomException ce) {
            logger.createCustomExceptionLog(ce);
        }

        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();
    }

    /* ==============================
     * 4. HttpErrorException 로그 + setter 전부 커버
     * ============================== */
    @IsTest
    static void cover_http_error_exception_logging() {
        ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
        logger.logging('TestClass');

        // 기본 생성자만 사용
        HttpErrorException he = new HttpErrorException('HTTP ERROR');

        // ApexLogger에서 사용하는 필드만 직접 세팅
        he.statusCode = 500;
        he.method = 'POST';
        he.endpoint = '/services/apexrest/test';
        he.responseBody = '{"error":"server error"}';

        logger.createHttpErrorExceptionLog(he);
        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();

        // 선택 검증
        ApexAuditTrail__c log = [
            SELECT Status__c, HttpStatusCode__c, Method__c
            FROM ApexAuditTrail__c
            LIMIT 1
        ];
        System.assertEquals('ERROR', log.Status__c);
        System.assertEquals('500', log.HttpStatusCode__c);
    }

    /* ==============================
     * 5. disableLogging 분기 커버
     * ============================== */
    @IsTest
    static void cover_disable_logging() {
        ApexLogger.disableLogging();

        ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
        logger.logging('TestClass');
        logger.setStatus('SUCCESS');
        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();

        // disableLogging=true 이므로 insert 안 됨
        System.assertEquals(0, [SELECT COUNT() FROM ApexAuditTrail__c]);
    }

    /* ==============================
     * 6. scopedIds / getScopedIds 커버
     * ============================== */
    @IsTest
    static void cover_scoped_ids() {
        Account a1 = new Account(Name = 'A1');
        Account a2 = new Account(Name = 'A2');
        insert new List<Account>{ a1, a2 };

        ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
        logger.logging('TestClass');

        logger.setScopedIds(new List<SObject>{ a1, a2 }, 'Id');

        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();
    }

    /* ==============================
     * 7. Interface 생성자 커버
     * ============================== */
    @IsTest
    static void cover_interface_constructor() {
        // InterfaceMaster__c 레코드 생성 (필요 시)
        Id dummyInterfaceId = '001000000000001';

        ApexLogger logger = new ApexLogger(ApexLogger.JobType.API, dummyInterfaceId);
        logger.logging('TestInterfaceClass');
        logger.setStatus('SUCCESS');
        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM ApexAuditTrail__c]);
    }

    /* ==============================
     * 8. setScopedIds(Set<String>) 커버
     * ============================== */
    @IsTest
    static void cover_set_scoped_ids_string_set() {
        ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
        logger.logging('TestClass');

        Set<String> scopedIds = new Set<String>{ 'ID001', 'ID002', 'ID003' };
        logger.setScopedIds(scopedIds);
        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();

        ApexAuditTrail__c log = [SELECT ScopedIds__c FROM ApexAuditTrail__c LIMIT 1];
        System.assert(log.ScopedIds__c.contains('ID001'));
    }

    /* ==============================
     * 9. 모든 setter 메서드 커버
     * ============================== */
    @IsTest
    static void cover_all_setter_methods() {
        ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
        logger.logging('TestClass');

        // 모든 setter 메서드 호출
        logger.setMethod('POST');
        logger.setErrorCode('ERR_001');
        logger.setErrorMessage('Test error message');
        logger.setStackTrace('Line 1: error\nLine 2: trace');
        logger.setHttpStatusCode('404');
        logger.setRequestUrl('https://api.example.com/test');
        logger.setResponseBody('{"status":"error"}');

        Set<String> failedIds = new Set<String>{ 'Failed001', 'Failed002' };
        logger.setFailedRecordIds(failedIds);

        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();

        ApexAuditTrail__c log = [
            SELECT
                Method__c,
                ErrorCode__c,
                ErrorMessage__c,
                StackTrace__c,
                HttpStatusCode__c,
                RequestUrl__c,
                ResponseBody__c,
                FailedRecordIds__c
            FROM ApexAuditTrail__c
            LIMIT 1
        ];

        System.assertEquals('POST', log.Method__c);
        System.assertEquals('ERR_001', log.ErrorCode__c);
        System.assertEquals('Test error message', log.ErrorMessage__c);
        System.assertEquals('404', log.HttpStatusCode__c);
        System.assertEquals('https://api.example.com/test', log.RequestUrl__c);
        System.assertEquals('{"status":"error"}', log.ResponseBody__c);
        System.assert(log.FailedRecordIds__c.contains('Failed001'));
    }

    /* ==============================
     * 10. createHttpErrorExceptionLog 전체 필드 커버
     * ============================== */
    @IsTest
    static void cover_create_http_error_exception_full() {
        ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
        logger.logging('TestHttpErrorClass');

        HttpErrorException he = new HttpErrorException('HTTP Request Failed');
        he.statusCode = 401;
        he.method = 'GET';
        he.endpoint = 'https://api.example.com/resource';
        he.responseBody = '{"error":"Unauthorized","message":"Invalid token"}';

        logger.createHttpErrorExceptionLog(he);
        logger.addLog();

        Test.startTest();
        ApexLogger.insertLogs();
        Test.stopTest();

        ApexAuditTrail__c log = [
            SELECT
                Status__c,
                Method__c,
                HttpStatusCode__c,
                RequestUrl__c,
                ResponseBody__c,
                ErrorCode__c,
                ErrorMessage__c
            FROM ApexAuditTrail__c
            LIMIT 1
        ];

        System.assertEquals('ERROR', log.Status__c);
        System.assertEquals('GET', log.Method__c);
        System.assertEquals('401', log.HttpStatusCode__c);
        System.assertEquals('https://api.example.com/resource', log.RequestUrl__c);
        System.assertEquals('HTTP_ERROR_EXCEPTION', log.ErrorCode__c);
        System.assert(log.ResponseBody__c.contains('Unauthorized'));
    }
}