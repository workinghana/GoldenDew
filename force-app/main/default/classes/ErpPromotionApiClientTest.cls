@IsTest
private class ErpPromotionApiClientTest {
    @TestSetup
    static void setupOnce() {
        CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    }

    @IsTest
    static void test_createMaster_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionReqDto.CreateRequest req = new ErpPromotionReqDto.CreateRequest();
        req.no_prom = 'PROM001';
        req.nm_prom = 'Promotion A';
        req.id_insert = 'TestUser';

        Test.startTest();
        ErpApiResponseDto result = ErpPromotionApiClient.createMaster(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_createMaster_nullRequest_throws() {
        Test.startTest();
        try {
            ErpPromotionApiClient.createMaster(null);
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Request body is required'));
        }
        Test.stopTest();
    }

    @IsTest
    static void test_updateMaster_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest();
        req.no_prom = 'PROM002';
        req.nm_prom = 'Promotion B';
        req.id_update = 'Updater';

        Test.startTest();
        ErpApiResponseDto result = ErpPromotionApiClient.updateMaster(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_updateMaster_nullRequest_throws() {
        Test.startTest();
        try {
            ErpPromotionApiClient.updateMaster(null);
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Request body is required'));
        }
        Test.stopTest();
    }

    @IsTest
    static void test_deleteMaster_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionReqDto.DeleteRequest req = (ErpPromotionReqDto.DeleteRequest) JSON.deserialize(
            '{"no_prom":"PROM003","id_delete":"Deleter"}',
            ErpPromotionReqDto.DeleteRequest.class
        );

        Test.startTest();
        ErpApiResponseDto result = ErpPromotionApiClient.deleteMaster(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_deleteMaster_nullRequest_throws() {
        Test.startTest();
        try {
            ErpPromotionApiClient.deleteMaster(null);
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Request body is required'));
        }
        Test.stopTest();
    }
}