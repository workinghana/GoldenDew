@IsTest
private class ErpPointFlowActionTest {
    @IsTest
    static void test_enqueuePointCredit_null_inputs() {
        Test.startTest();
        List<ErpPointFlowAction.Output> outputs = ErpPointFlowAction.enqueuePointCredit(null);
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals(false, outputs[0].enqueued);
        System.assertEquals(0, outputs[0].requestCount);
        System.assertEquals('No inputs.', outputs[0].message);
    }

    @IsTest
    static void test_enqueuePointCredit_empty_inputs() {
        Test.startTest();
        List<ErpPointFlowAction.Output> outputs = ErpPointFlowAction.enqueuePointCredit(
            new List<ErpPointFlowAction.CreditInput>()
        );
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals(false, outputs[0].enqueued);
        System.assertEquals(0, outputs[0].requestCount);
        System.assertEquals('No inputs.', outputs[0].message);
    }

    @IsTest
    static void test_enqueuePointCredit_missing_cd_company() {
        ErpPointFlowAction.CreditInput input = new ErpPointFlowAction.CreditInput();
        input.no_mbr = 'MBR001';
        input.pt_target = 1000;

        Test.startTest();
        try {
            ErpPointFlowAction.enqueuePointCredit(
                new List<ErpPointFlowAction.CreditInput>{ input }
            );
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            // AuraHandledException.getMessage()는 테스트 컨텍스트에서 'Script-thrown exception' 반환
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void test_enqueuePointCredit_missing_no_mbr() {
        ErpPointFlowAction.CreditInput input = new ErpPointFlowAction.CreditInput();
        input.cd_company = 'GD';
        input.pt_target = 1000;

        Test.startTest();
        try {
            ErpPointFlowAction.enqueuePointCredit(
                new List<ErpPointFlowAction.CreditInput>{ input }
            );
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void test_enqueuePointCredit_missing_pt_target() {
        ErpPointFlowAction.CreditInput input = new ErpPointFlowAction.CreditInput();
        input.cd_company = 'GD';
        input.no_mbr = 'MBR001';

        Test.startTest();
        try {
            ErpPointFlowAction.enqueuePointCredit(
                new List<ErpPointFlowAction.CreditInput>{ input }
            );
            System.assert(false, 'Expected exception');
        } catch (AuraHandledException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void test_enqueuePointCredit_success_minimal_fields() {
        ErpPointFlowAction.CreditInput input = new ErpPointFlowAction.CreditInput();
        input.cd_company = 'GD';
        input.no_mbr = 'MBR001';
        input.pt_target = 1000;

        Test.startTest();
        List<ErpPointFlowAction.Output> outputs = ErpPointFlowAction.enqueuePointCredit(
            new List<ErpPointFlowAction.CreditInput>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals(true, outputs[0].enqueued);
        System.assertEquals(1, outputs[0].requestCount);
        System.assert(outputs[0].message.contains('Enqueued POINT_CREDIT jobs=1'));

        // Verify job enqueued
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'ErpPointJob'
        ];
        System.assertEquals(1, jobs.size());
    }

    @IsTest
    static void test_enqueuePointCredit_success_all_fields() {
        // Create test record for recordId
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ErpPointFlowAction.CreditInput input = new ErpPointFlowAction.CreditInput();
        input.cd_company = 'GD';
        input.no_mbr = 'MBR002';
        input.pt_target = 2000;
        input.id_insert = 'TESTUSER';
        input.cd_save_ledger = 'LEDGER001';
        input.cd_type_save = '01';
        input.cd_type_point = 'P001';
        input.ym_create = '202603';
        input.dt_create = '20260309';
        input.dt_save_plan = '20260310';
        input.dt_save = '20260309';
        input.dt_limit_start = '20260309';
        input.dt_limit_end = '20271231';
        input.dt_destroy_plan = '20280101';
        input.dt_destroy_del_sale = '20280201';
        input.no_sal = 'SAL001';
        input.am_sal = 50000;
        input.pt_use_sale = 500;
        input.pt_save_plan = 2000;
        input.pt_save = 2000;
        input.tx_remark = 'Test remark';
        input.recordId = acc.Id;

        Test.startTest();
        List<ErpPointFlowAction.Output> outputs = ErpPointFlowAction.enqueuePointCredit(
            new List<ErpPointFlowAction.CreditInput>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, outputs.size());
        System.assertEquals(true, outputs[0].enqueued);
        System.assertEquals(1, outputs[0].requestCount);
        System.assert(outputs[0].message.contains('Enqueued POINT_CREDIT jobs=1'));

        // Verify job enqueued
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'ErpPointJob'
        ];
        System.assertEquals(1, jobs.size());
    }

    @IsTest
    static void test_enqueuePointCredit_multiple_inputs() {
        ErpPointFlowAction.CreditInput input1 = new ErpPointFlowAction.CreditInput();
        input1.cd_company = 'GD';
        input1.no_mbr = 'MBR003';
        input1.pt_target = 1000;

        ErpPointFlowAction.CreditInput input2 = new ErpPointFlowAction.CreditInput();
        input2.cd_company = 'GD';
        input2.no_mbr = 'MBR004';
        input2.pt_target = 2000;

        Test.startTest();
        List<ErpPointFlowAction.Output> outputs = ErpPointFlowAction.enqueuePointCredit(
            new List<ErpPointFlowAction.CreditInput>{ input1, input2 }
        );
        Test.stopTest();

        System.assertEquals(2, outputs.size());
        System.assertEquals(true, outputs[0].enqueued);
        System.assertEquals(2, outputs[0].requestCount);
        System.assert(outputs[0].message.contains('Enqueued POINT_CREDIT jobs=2'));

        // Verify jobs enqueued
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'ErpPointJob'
        ];
        System.assertEquals(2, jobs.size());
    }

    @IsTest
    static void test_enqueuePointCredit_skip_null_input() {
        ErpPointFlowAction.CreditInput input1 = new ErpPointFlowAction.CreditInput();
        input1.cd_company = 'GD';
        input1.no_mbr = 'MBR005';
        input1.pt_target = 1500;

        List<ErpPointFlowAction.CreditInput> inputs = new List<ErpPointFlowAction.CreditInput>{
            input1,
            null
        };

        Test.startTest();
        List<ErpPointFlowAction.Output> outputs = ErpPointFlowAction.enqueuePointCredit(inputs);
        Test.stopTest();

        System.assertEquals(2, outputs.size());
        System.assertEquals(true, outputs[0].enqueued);
        System.assertEquals(1, outputs[0].requestCount); // Only 1 because null is skipped
        System.assert(outputs[0].message.contains('Enqueued POINT_CREDIT jobs=1'));

        // Verify only 1 job enqueued
        List<AsyncApexJob> jobs = [
            SELECT Id, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'ErpPointJob'
        ];
        System.assertEquals(1, jobs.size());
    }

    @IsTest
    static void test_output_class_instantiation() {
        ErpPointFlowAction.Output out = new ErpPointFlowAction.Output();

        System.assertNotEquals(null, out);
    }

    @IsTest
    static void test_creditInput_class_instantiation() {
        ErpPointFlowAction.CreditInput input = new ErpPointFlowAction.CreditInput();

        System.assertNotEquals(null, input);
    }
}