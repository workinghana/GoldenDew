@IsTest
private class TritonFlowTest {

    /* =====================================================
     * 공통 FlowLog 생성 헬퍼
     * ===================================================== */
    private static TritonFlow.FlowLog baseFlowLog() {
        TritonFlow.FlowLog log = new TritonFlow.FlowLog();
        log.area = 'Flow';
        log.summary = 'Test Summary';
        log.interviewGUID = 'FLOW-INT-001';
        log.flowApiName = 'Test_Flow';
        log.operation = 'TestOperation';
        log.details = 'Detail message';
        log.type = 'Backend';
        return log;
    }

    /* =====================================================
     * 1️⃣ 정상 INFO 로그
     * ===================================================== */
    @IsTest
    static void test_log_success_info() {

        TritonFlow.FlowLog log = baseFlowLog();
        log.level = 'INFO';

        Test.startTest();
        List<TritonFlow.FlowLogOutput> result =
            TritonFlow.log(new List<TritonFlow.FlowLog>{ log });
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals(null, result[0].stacktrace);
    }

    /* =====================================================
     * 2️⃣ 잘못된 Level → INFO fallback
     * ===================================================== */
    @IsTest
    static void test_invalid_level_fallback() {

        TritonFlow.FlowLog log = baseFlowLog();
        log.level = 'NOT_A_LEVEL';

        Test.startTest();
        List<TritonFlow.FlowLogOutput> result =
            TritonFlow.log(new List<TritonFlow.FlowLog>{ log });
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* =====================================================
     * 3️⃣ 잘못된 Category → Flow fallback
     * ===================================================== */
    @IsTest
    static void test_invalid_category_fallback() {

        TritonFlow.FlowLog log = baseFlowLog();
        log.category = 'INVALID_CATEGORY';

        Test.startTest();
        List<TritonFlow.FlowLogOutput> result =
            TritonFlow.log(new List<TritonFlow.FlowLog>{ log });
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* =====================================================
     * 4️⃣ ERROR 레벨 → createIssue 분기
     * ===================================================== */
    @IsTest
    static void test_error_level_creates_issue() {

        TritonFlow.FlowLog log = baseFlowLog();
        log.level = 'ERROR';

        Test.startTest();
        List<TritonFlow.FlowLogOutput> result =
            TritonFlow.log(new List<TritonFlow.FlowLog>{ log });
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* =====================================================
     * 5️⃣ additionalFields JSON 성공
     * ===================================================== */
    @IsTest
    static void test_additional_fields_json_success() {

        TritonFlow.FlowLog log = baseFlowLog();
        log.additionalFields =
            '{"Custom_Field__c":"VALUE","Another_Field__c":123}';

        Test.startTest();
        List<TritonFlow.FlowLogOutput> result =
            TritonFlow.log(new List<TritonFlow.FlowLog>{ log });
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* =====================================================
     * 6️⃣ additionalFields JSON 실패
     * ===================================================== */
    @IsTest
    static void test_additional_fields_json_fail() {

        TritonFlow.FlowLog log = baseFlowLog();
        log.additionalFields = '{INVALID_JSON';

        Test.startTest();
        List<TritonFlow.FlowLogOutput> result =
            TritonFlow.log(new List<TritonFlow.FlowLog>{ log });
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* =====================================================
     * 7️⃣ transactionId 존재 → resumeTransaction
     * ===================================================== */
    @IsTest
    static void test_resume_transaction() {

        TritonFlow.FlowLog log = baseFlowLog();
        log.transactionId = 'TX-001';

        Test.startTest();
        List<TritonFlow.FlowLogOutput> result =
            TritonFlow.log(new List<TritonFlow.FlowLog>{ log });
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    /* =====================================================
     * 8️⃣ stacktrace + fullStacktrace 병합
     * ===================================================== */
    @IsTest
    static void test_stacktrace_merge() {

        TritonFlow.FlowLog log = baseFlowLog();
        log.stacktrace = 'STACK';
        log.fullStacktrace = 'FULL';

        Test.startTest();
        List<TritonFlow.FlowLogOutput> result =
            TritonFlow.log(new List<TritonFlow.FlowLog>{ log });
        Test.stopTest();

        System.assertEquals(
            'FULLSTACK',
            result[0].fullStacktrace.replace(' ', '')
        );
    }
}