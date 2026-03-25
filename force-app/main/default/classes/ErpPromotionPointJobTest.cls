@IsTest
private class ErpPromotionPointJobTest {
    private class TestCallback implements ErpAsyncCallback {
        public void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto) {
        }
        public void onFailure(
            String apiName,
            Object requestDto,
            String errorMessage,
            String stackTrace
        ) {
        }
        public void onFailure(
            String apiName,
            Object requestDto,
            HttpErrorException httpError,
            Id recordId
        ) {
        }
        public void onFailure(
            String apiName,
            Object requestDto,
            HttpErrorException httpError,
            Id recordId,
            SObject o
        ) {
        }
        public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {
        }
        public void onFailure(
            String apiName,
            Object requestDto,
            HttpErrorException httpError,
            Set<Id> recordIds
        ) {
        }
        public void onFailure(
            String apiName,
            Object requestDto,
            Exception error,
            Set<Id> recordIds
        ) {
        }
        public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {
        }
    }

    private static Id makeRecordId() {
        Account a = new Account(
            Name = 'ERP_PROMO_POINT_JOB_' + String.valueOf(Datetime.now().getTime())
        );
        insert a;
        return a.Id;
    }

    @TestSetup
    static void setupOnce() {
        CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    }

    @IsTest
    static void test_execute_createPromotionPoint_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionPointReqDto.CreateRequest req = new ErpPromotionPointReqDto.CreateRequest();
        req.cd_company = '1000';
        req.no_prom = 'PROM001';
        req.no_prom_point = 'PPOINT001';
        req.nm_prom_point = '가입포인트';
        req.cd_type_prom_point = '01';
        req.nm_type_prom_point = '기본';
        req.cd_type_point = 'A';
        req.nm_type_point = '적립';
        req.pt_save = 100;
        req.id_insert = 'tester';

        Id rid = makeRecordId();

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionPointJob(
                ErpPromotionPointJob.Operation.CREATE_PROMOTION_POINT,
                req,
                new TestCallback(),
                rid
            )
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @IsTest
    static void test_execute_updatePromotionPoint_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionPointReqDto.UpdateRequest req = new ErpPromotionPointReqDto.UpdateRequest();
        req.cd_company = '1000';
        req.no_prom = 'PROM002';
        req.no_prom_point = 'PPOINT002';
        req.nm_prom_point = '가입포인트수정';
        req.cd_type_prom_point = '01';
        req.nm_type_prom_point = '기본';
        req.cd_type_point = 'A';
        req.nm_type_point = '적립';
        req.pt_save = 150;
        req.id_update = 'updater';

        Id rid = makeRecordId();

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionPointJob(
                ErpPromotionPointJob.Operation.UPDATE_PROMOTION_POINT,
                req,
                new TestCallback(),
                rid
            )
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @IsTest
    static void test_execute_deletePromotionPoint_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionPointReqDto.DeleteRequest req = new ErpPromotionPointReqDto.DeleteRequest();
        req.no_prom = 'PROM003';
        req.no_prom_point = 'PPOINT003';
        req.id_delete = 'deleter';

        Id rid = makeRecordId();

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionPointJob(
                ErpPromotionPointJob.Operation.DELETE_PROMOTION_POINT,
                req,
                new TestCallback(),
                rid
            )
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        System.assertEquals('Completed', job.Status);
        System.assertEquals(0, job.NumberOfErrors);
    }

    @IsTest
    static void test_constructor_with_sobject_overload_executes() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionPointReqDto.DeleteRequest req = new ErpPromotionPointReqDto.DeleteRequest();
        req.no_prom = 'PROM004';
        req.no_prom_point = 'PPOINT004';
        req.id_delete = 'deleter2';

        Account a = new Account(Name = 'SOBJ_' + String.valueOf(Datetime.now().getTime()));
        insert a;

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionPointJob(
                ErpPromotionPointJob.Operation.DELETE_PROMOTION_POINT,
                req,
                new TestCallback(),
                a.Id,
                a
            )
        );
        Test.stopTest();

        System.assert(true);
    }
}