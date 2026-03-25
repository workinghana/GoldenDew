@IsTest
private class ErpPromotionJobTest {
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

    private static Promotion makePromotion() {
        String statusCode = null;
        for (Schema.PicklistEntry e : Promotion.StatusCode__c.getDescribe().getPicklistValues()) {
            statusCode = e.getValue();
            break;
        }

        String typeCode = null;
        for (Schema.PicklistEntry e : Promotion.TypeCode__c.getDescribe().getPicklistValues()) {
            typeCode = e.getValue();
            break;
        }

        String brandCode = null;
        for (Schema.PicklistEntry e : Promotion.BrandCode__c.getDescribe().getPicklistValues()) {
            brandCode = e.getValue();
            break;
        }

        Promotion p = new Promotion(
            Name = 'PROM_' + String.valueOf(Datetime.now().getTime()),
            PromotionCode = 'PCODE_' + String.valueOf(Datetime.now().getTime()),
            BrandCode__c = brandCode,
            TypeCode__c = typeCode,
            StartDate = Date.today(),
            EndDate = Date.today().addDays(7),
            PublishStartDate__c = Date.today(),
            PublishEndDate__c = Date.today().addDays(3),
            StatusCode__c = statusCode,
            IsCouponAllowed__c = true,
            IsFixedAmountCouponAllowed__c = true,
            IsRateCouponAllowed__c = true,
            IsSpecificCouponAllowed__c = false,
            IsPointUsageAllowed__c = true,
            IsAllStore__c = true,
            IsAllItem__c = false,
            DepartmentCode__c = 'D001',
            InsertId__c = 'Inserter',
            ResponId__c = 'Responder'
        );
        insert p;

        return [
            SELECT
                Id,
                PromotionNo__c,
                PromotionCode,
                Name,
                BrandCode__c,
                TypeCode__c,
                StartDate,
                EndDate,
                PublishStartDate__c,
                PublishEndDate__c,
                StatusCode__c,
                IsCouponAllowed__c,
                IsFixedAmountCouponAllowed__c,
                IsRateCouponAllowed__c,
                IsSpecificCouponAllowed__c,
                IsPointUsageAllowed__c,
                IsAllStore__c,
                IsAllItem__c,
                LastModifiedBy.Name,
                CreatedBy.Name
            FROM Promotion
            WHERE Id = :p.Id
            LIMIT 1
        ];
    }

    @TestSetup
    static void setupOnce() {
        CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    }

    @IsTest
    static void test_execute_deleteMaster_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        Promotion p = makePromotion();
        ErpPromotionReqDto.DeleteRequest req = new ErpPromotionReqDto.DeleteRequest(p);

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionJob(
                ErpPromotionJob.Operation.DELETE_MASTER,
                req,
                new TestCallback(),
                p.Id
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
    static void test_execute_updateMaster_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        Promotion p = makePromotion();
        ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest(p);

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionJob(
                ErpPromotionJob.Operation.UPDATE_MASTER,
                req,
                new TestCallback(),
                p.Id
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

        Promotion p = makePromotion();
        ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest(p);

        Test.startTest();
        System.enqueueJob(
            new ErpPromotionJob(
                ErpPromotionJob.Operation.UPDATE_MASTER,
                req,
                new TestCallback(),
                p.Id,
                p
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
        System.assertEquals('Completed', job.Status);
    }
}