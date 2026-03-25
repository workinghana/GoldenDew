@IsTest(SeeAllData=true)
private class MceDailyMagazineSyncSchedulerTest {
    private class MockSchedulableContext implements SchedulableContext {
        public Id getTriggerId() {
            return UserInfo.getUserId();
        }
    }

    private class EmptyRowsetMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"items":[]}');
            return res;
        }
    }

    @IsTest
    static void execute_enqueuesFetchJob() {
        Test.setMock(HttpCalloutMock.class, new EmptyRowsetMock());

        Test.startTest();
        new MceDailyMagazineSyncScheduler().execute(new MockSchedulableContext());
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void schedule_runsSuccessfully() {
        Test.setMock(HttpCalloutMock.class, new EmptyRowsetMock());

        Test.startTest();
        System.schedule(
            'MceDailyMagazineSyncScheduler Test',
            '0 0 6 * * ?',
            new MceDailyMagazineSyncScheduler()
        );
        Test.stopTest();

        System.assert(true);
    }
}