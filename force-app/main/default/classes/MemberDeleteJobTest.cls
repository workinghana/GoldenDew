@IsTest
private class MemberDeleteJobTest {
    /* =========================================================
     * MemberDeleteJob.register()
     * – System.schedule() 호출 → CronTrigger 등록 확인
     * ========================================================= */
    @IsTest
    static void testRegister_schedulesJob() {
        Test.startTest();
        MemberDeleteJob.register();
        Test.stopTest();

        // 스케줄러가 정상 등록되었는지 CronTrigger 조회로 확인
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name
            FROM CronTrigger
            WHERE CronJobDetail.Name = 'MemberDeleteSchedulerJob'
        ];
        System.assertEquals(1, jobs.size(), 'MemberDeleteSchedulerJob 이 등록되어야 합니다.');
    }

    /* =========================================================
     * MemberDeleteScheduler.execute()
     * – Database.executeBatch 호출 커버
     * ========================================================= */
    @IsTest
    static void testSchedulerExecute_runsBatch() {
        Test.startTest();
        System.schedule(
            'MemberDeleteSchedulerJob_Test',
            '0 0 0 * * ?',
            new MemberDeleteScheduler()
        );
        Test.stopTest();

        // stopTest() 시점에 execute()가 실행되어 MemberDeleteBatch 가 enqueue됨
        // 배치 Job 등록 확인
        List<AsyncApexJob> jobs = [
            SELECT Id, Status, ApexClass.Name
            FROM AsyncApexJob
            WHERE ApexClass.Name = 'MemberDeleteBatch'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals(1, jobs.size(), 'MemberDeleteBatch 가 실행되어야 합니다.');
    }
}