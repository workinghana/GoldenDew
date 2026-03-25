@IsTest
private class MemberDeleteSchedulerTest {

    /* =========================================================
     * MemberDeleteScheduler.execute()
     * – System.schedule() → Test.stopTest() 시점에 execute() 실행
     * – Database.executeBatch(MemberDeleteBatch, 200) 호출 확인
     * ========================================================= */
    @IsTest
    static void testExecute_runsBatch() {
        Test.startTest();
        System.schedule(
            'MemberDeleteSchedulerTest_Job',
            '0 0 0 * * ?',
            new MemberDeleteScheduler()
        );
        Test.stopTest();

        // stopTest() 시점에 execute()가 실행되어 MemberDeleteBatch가 enqueue됨
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'MemberDeleteBatch'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(1, jobs.size(), 'MemberDeleteBatch가 실행되어야 합니다.');
    }
}