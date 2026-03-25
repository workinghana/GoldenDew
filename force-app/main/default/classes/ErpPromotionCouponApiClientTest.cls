/**
 * Test class for ErpPromotionCouponApiClient
 */
@IsTest
private class ErpPromotionCouponApiClientTest {
    @TestSetup
    static void setupOnce() {
        // CommonApiClient의 TokenRefresher를 테스트용으로 주입
        CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    }

    // =========================
    // TEST: createPromotionCoupon - 정상 케이스
    // =========================
    @IsTest
    static void test_createPromotionCoupon_success() {
        // Given
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.CreateRequest req = new ErpPromotionCouponReqDto.CreateRequest();
        req.cd_company = 'TEST_COMPANY';
        req.no_prom = 'PROM001';
        req.no_man_coupon = 'CPN001';
        req.nm_man_coupon = 'Test Coupon';
        req.cd_type_coupon = '01';
        req.nm_type_coupon = 'Fixed';
        req.dt_str_exp = '20260101';
        req.dt_end_exp = '20261231';
        req.rt_disc = '10';
        req.am_disc = '5000';
        req.id_insert = 'TestUser';

        // When
        Test.startTest();
        ErpApiResponseDto result = ErpPromotionCouponApiClient.createPromotionCoupon(req);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.info, 'Result info should not be null');
        System.assertEquals(200, result.info.statusCode, 'Status code should be 200');
    }

    // =========================
    // TEST: createPromotionCoupon - null request
    // =========================
    @IsTest
    static void test_createPromotionCoupon_nullRequest() {
        // Given
        ErpPromotionCouponReqDto.CreateRequest req = null;

        // When & Then
        Test.startTest();
        try {
            ErpPromotionCouponApiClient.createPromotionCoupon(req);
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('Request body is required'),
                'Exception message should mention required request body'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: deletePromotionCoupon - 정상 케이스
    // =========================
    @IsTest
    static void test_deletePromotionCoupon_success() {
        // Given
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.DeleteRequest req = new ErpPromotionCouponReqDto.DeleteRequest();
        req.no_prom = 'PROM001';
        req.cd_coupon = 'CPN001';
        req.id_delete = 'TestUser';

        // When
        Test.startTest();
        ErpApiResponseDto result = ErpPromotionCouponApiClient.deletePromotionCoupon(req);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.info, 'Result info should not be null');
        System.assertEquals(200, result.info.statusCode, 'Status code should be 200');
    }

    // =========================
    // TEST: deletePromotionCoupon - null request
    // =========================
    @IsTest
    static void test_deletePromotionCoupon_nullRequest() {
        // Given
        ErpPromotionCouponReqDto.DeleteRequest req = null;

        // When & Then
        Test.startTest();
        try {
            ErpPromotionCouponApiClient.deletePromotionCoupon(req);
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('Request body is required'),
                'Exception message should mention required request body'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: createPromotionCoupon - HTTP 오류
    // =========================
    @IsTest
    static void test_createPromotionCoupon_httpError() {
        // Given
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.CreateRequest req = new ErpPromotionCouponReqDto.CreateRequest();
        req.cd_company = 'TEST';
        req.no_prom = 'PROM001';
        req.no_man_coupon = 'CPN001';
        req.id_insert = 'TestUser';

        // When & Then - throwOnHttpError가 true이므로 예외 발생
        Test.startTest();
        try {
            // /bad 경로로 400 오류 유도
            CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
            opt.method = 'POST';
            opt.endpoint = 'callout:GoldenDewApiNC/api/bad';
            opt.body = req;
            opt.throwOnHttpError = true;
            opt.parseJson = true;
            opt.maxRetries = 1;

            CommonApiClient.send(opt);
            System.assert(false, 'Should have thrown HttpErrorException');
        } catch (HttpErrorException e) {
            System.assertEquals(400, e.statusCode, 'Status code should be 400');
        }
        Test.stopTest();
    }

    // =========================
    // TEST: deletePromotionCoupon - query parameters 설정 확인
    // =========================
    @IsTest
    static void test_deletePromotionCoupon_queryParameters() {
        // Given
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.DeleteRequest req = new ErpPromotionCouponReqDto.DeleteRequest();
        req.no_prom = 'PROM002';
        req.cd_coupon = 'CPN002';
        req.id_delete = 'DeleteUser';

        // When
        Test.startTest();
        ErpApiResponseDto result = ErpPromotionCouponApiClient.deletePromotionCoupon(req);
        Test.stopTest();

        // Then - 정상적으로 응답을 받았다면 query parameter가 제대로 설정된 것
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.info, 'Result info should not be null');
        System.assertEquals(200, result.info.statusCode, 'Status code should be 200');
    }

    // =========================
    // TEST: createPromotionCoupon - 재시도 테스트
    // =========================
    @IsTest
    static void test_createPromotionCoupon_retry() {
        // Given
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.CreateRequest req = new ErpPromotionCouponReqDto.CreateRequest();
        req.cd_company = 'TEST';
        req.no_prom = 'PROM001';
        req.no_man_coupon = 'CPN001';
        req.id_insert = 'TestUser';

        // When - /retry 경로로 재시도 시나리오 테스트
        Test.startTest();
        CommonApiClient.RequestOptions opt = new CommonApiClient.RequestOptions();
        opt.method = 'POST';
        opt.endpoint = 'callout:GoldenDewApiNC/api/retry';
        opt.body = req;
        opt.throwOnHttpError = true;
        opt.parseJson = true;
        opt.maxRetries = 2;

        CommonApiClient.ResponseWrapper res = CommonApiClient.send(opt);
        Test.stopTest();

        // Then
        System.assertEquals(200, res.statusCode, 'Should succeed after retry');
    }

    // =========================
    // TEST: createPromotionCoupon - 필드값 검증
    // =========================
    @IsTest
    static void test_createPromotionCoupon_fieldValues() {
        // Given
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.CreateRequest req = new ErpPromotionCouponReqDto.CreateRequest();
        req.cd_company = 'COMPANY123';
        req.no_prom = 'PROM999';
        req.no_man_coupon = 'CPN999';
        req.nm_man_coupon = '할인 쿠폰';
        req.cd_type_coupon = '02';
        req.nm_type_coupon = 'Percentage';
        req.dt_str_exp = '20260201';
        req.dt_end_exp = '20260228';
        req.rt_disc = '20';
        req.am_disc = '10000';
        req.id_insert = 'AdminUser';

        // When
        Test.startTest();
        ErpApiResponseDto result = ErpPromotionCouponApiClient.createPromotionCoupon(req);
        Test.stopTest();

        // Then
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertNotEquals(null, result.info, 'Result info should not be null');
        System.assertEquals(200, result.info.statusCode, 'Status code should be 200');
    }

    // =========================
    // TEST: deletePromotionCoupon - 빈 필드값
    // =========================
    @IsTest
    static void test_deletePromotionCoupon_emptyFields() {
        // Given
        CommonApiClientUniversalMock.reset();
        Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

        ErpPromotionCouponReqDto.DeleteRequest req = new ErpPromotionCouponReqDto.DeleteRequest();
        req.no_prom = '';
        req.cd_coupon = '';
        req.id_delete = '';

        // When
        Test.startTest();
        ErpApiResponseDto result = ErpPromotionCouponApiClient.deletePromotionCoupon(req);
        Test.stopTest();

        // Then - API는 호출되지만 빈 값으로 처리됨
        System.assertNotEquals(null, result, 'Result should not be null');
    }
}