@IsTest
private class ErpPromotionPointApiClientTest {
    @TestSetup
    static void setupOnce() {
        CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    }

    @IsTest
    static void test_createPromotionPoint_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionPointReqDto.CreateRequest req = new ErpPromotionPointReqDto.CreateRequest();
        req.cd_company = '1000';
        req.no_prom = 'PROM001';
        req.no_prom_point = 'PPOINT001';
        req.nm_prom_point = '가입 포인트';
        req.cd_type_prom_point = '01';
        req.nm_type_prom_point = '기본';
        req.cd_type_point = 'A';
        req.nm_type_point = '적립';
        req.pt_save = 100;
        req.id_insert = 'tester';

        Test.startTest();
        ErpApiResponseDto result = ErpPromotionPointApiClient.createPromotionPoint(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.info);
        System.assertEquals(200, result.info.statusCode);
    }

    @IsTest
    static void test_updatePromotionPoint_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionPointReqDto.UpdateRequest req = new ErpPromotionPointReqDto.UpdateRequest();
        req.cd_company = '1000';
        req.no_prom = 'PROM001';
        req.no_prom_point = 'PPOINT001';
        req.nm_prom_point = '가입 포인트 수정';
        req.cd_type_prom_point = '01';
        req.nm_type_prom_point = '기본';
        req.cd_type_point = 'A';
        req.nm_type_point = '적립';
        req.pt_save = 150;
        req.id_update = 'updater';

        Test.startTest();
        ErpApiResponseDto result = ErpPromotionPointApiClient.updatePromotionPoint(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.info);
        System.assertEquals(200, result.info.statusCode);
    }

    @IsTest
    static void test_deletePromotionPoint_success() {
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionPointReqDto.DeleteRequest req = new ErpPromotionPointReqDto.DeleteRequest();
        req.no_prom = 'PROM001';
        req.no_prom_point = 'PPOINT001';
        req.id_delete = 'deleter';

        Test.startTest();
        ErpApiResponseDto result = ErpPromotionPointApiClient.deletePromotionPoint(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.info);
        System.assertEquals(200, result.info.statusCode);
    }

    @IsTest
    static void test_createPromotionPoint_nullRequest_throws() {
        Test.startTest();
        try {
            ErpPromotionPointApiClient.createPromotionPoint(null);
            System.assert(false);
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Request body is required.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void test_updatePromotionPoint_nullRequest_throws() {
        Test.startTest();
        try {
            ErpPromotionPointApiClient.updatePromotionPoint(null);
            System.assert(false);
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Request body is required.'));
        }
        Test.stopTest();
    }

    @IsTest
    static void test_deletePromotionPoint_nullRequest_throws() {
        Test.startTest();
        try {
            ErpPromotionPointApiClient.deletePromotionPoint(null);
            System.assert(false);
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Request body is required.'));
        }
        Test.stopTest();
    }
}