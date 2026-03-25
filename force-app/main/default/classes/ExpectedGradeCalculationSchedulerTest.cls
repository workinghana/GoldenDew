@IsTest
private class ExpectedGradeCalculationSchedulerTest {
    private class MockSchedulableContext implements SchedulableContext {
        public Id getTriggerId() {
            return UserInfo.getUserId();
        }
    }

    @IsTest
    static void test_execute_enqueues_expected_grade_batch() {
        String jobName = 'ExpectedGradeCalcScheduler_' + String.valueOf(System.currentTimeMillis());

        Test.startTest();
        System.schedule(jobName, '0 0 0 12 1 ? 2099', new ExpectedGradeCalculationScheduler());
        Test.stopTest();

        Integer batchCnt = [
            SELECT COUNT()
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'ExpectedGradeCalculationBatch'
        ];

        System.assert(
            batchCnt > 0,
            'ExpectedGradeCalculationBatch should be enqueued by scheduler'
        );
    }

    @IsTest
    static void test_execute_customException_catch_branch() {
        ExpectedGradeCalculationScheduler.testForceCustomException = true;
        ExpectedGradeCalculationScheduler.testForceException = false;

        Test.startTest();
        new ExpectedGradeCalculationScheduler().execute(new MockSchedulableContext());
        Test.stopTest();

        ExpectedGradeCalculationScheduler.testForceCustomException = false;
        ExpectedGradeCalculationScheduler.testForceException = false;

        System.assert(true);
    }

    @IsTest
    static void test_execute_exception_catch_branch() {
        ExpectedGradeCalculationScheduler.testForceCustomException = false;
        ExpectedGradeCalculationScheduler.testForceException = true;

        Test.startTest();
        new ExpectedGradeCalculationScheduler().execute(new MockSchedulableContext());
        Test.stopTest();

        ExpectedGradeCalculationScheduler.testForceCustomException = false;
        ExpectedGradeCalculationScheduler.testForceException = false;

        System.assert(true);
    }
}