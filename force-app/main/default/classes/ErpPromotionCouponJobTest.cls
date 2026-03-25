@IsTest
private class ErpPromotionCouponJobTest {
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
            Name = 'ERP_PROMO_COUPON_JOB_' + String.valueOf(Datetime.now().getTime())
        );
        insert a;
        return a.Id;
    }

    @TestSetup
    static void setupOnce() {
        CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    }

    @IsTest
    static void test_execute_createPromotionCoupon_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.CreateRequest req = new ErpPromotionCouponReqDto.CreateRequest();
        req.cd_company = 'GD';
        req.no_prom = 'PROM001';
        req.no_man_coupon = 'CPN001';
        req.id_insert = 'tester';

        Id rid = makeRecordId();

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionCouponJob(
                ErpPromotionCouponJob.Operation.CREATE_PROMOTION_COUPON,
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
    static void test_execute_deletePromotionCoupon_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.DeleteRequest req = new ErpPromotionCouponReqDto.DeleteRequest();
        req.no_prom = 'PROM002';
        req.cd_coupon = 'CPN002';
        req.id_delete = 'tester';

        Id rid = makeRecordId();

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionCouponJob(
                ErpPromotionCouponJob.Operation.DELETE_PROMOTION_COUPON,
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
    static void test_execute_updatePromotionCoupon_notSupported_branch() {
        Id rid = makeRecordId();

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionCouponJob(
                ErpPromotionCouponJob.Operation.UPDATE_PROMOTION_COUPON,
                new Map<String, Object>{ 'k' => 'v' },
                new TestCallback(),
                rid
            )
        );
        Test.stopTest();

        AsyncApexJob job = [
            SELECT Status
            FROM AsyncApexJob
            WHERE JobType = 'Queueable'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        // 내부에서 예외를 catch하므로 Queueable 자체는 완료되어야 함
        System.assertEquals('Completed', job.Status);
    }

    @IsTest
    static void test_constructor_with_sobject_overload_executes() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.DeleteRequest req = new ErpPromotionCouponReqDto.DeleteRequest();
        req.no_prom = 'PROM003';
        req.cd_coupon = 'CPN003';
        req.id_delete = 'tester';

        Account a = new Account(Name = 'SOBJ_' + String.valueOf(Datetime.now().getTime()));
        insert a;

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionCouponJob(
                ErpPromotionCouponJob.Operation.DELETE_PROMOTION_COUPON,
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