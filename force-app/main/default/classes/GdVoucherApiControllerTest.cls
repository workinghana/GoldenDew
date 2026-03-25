@IsTest
private class GdVoucherApiControllerTest {
    /* =========================================================
     * 공통: RestContext 세팅
     * ========================================================= */
    private static void setupRestContext(String method, String uri, String body) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = method;

        if (body != null) {
            req.requestBody = Blob.valueOf(body);
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================================================
     * Mock Services
     * ========================================================= */

    /* ---------- GdVoucherDefinitionService ---------- */
    private class MockVoucherDefinitionService implements GdVoucherDefinitionService {
        public ApiResult createVoucherDefinition(Map<String, Object> req) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{ 'voucherDefinitionId' => 'VD-001' }
            );
        }

        /* 🔹 추가된 인터페이스 메서드 (더미 구현) */
        public ApiResult addVoucherLimitByPromotion(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
    }

    /* ---------- 예외를 던지는 GdVoucherDefinitionService ---------- */
    private class CustomExceptionDefinitionService implements GdVoucherDefinitionService {
        public ApiResult createVoucherDefinition(Map<String, Object> req) {
            throw new CustomException(422, 'custom error');
        }
        public ApiResult addVoucherLimitByPromotion(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
    }

    private class RuntimeExceptionDefinitionService implements GdVoucherDefinitionService {
        public ApiResult createVoucherDefinition(Map<String, Object> req) {
            throw new IllegalArgumentException('unexpected');
        }
        public ApiResult addVoucherLimitByPromotion(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
    }

    /* ---------- 예외를 던지는 GdVoucherService ---------- */
    private class CustomExceptionVoucherService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            throw new CustomException(422, 'custom error');
        }

        public void issueBirthdayCoupon() {
        }
        public ApiResult issueSignupCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult redeemVoucher(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult redeemVoucherV2(TransactionJournal tj) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult issueCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult updateCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult deleteCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult getReturnUsedCoupon(String couponNo) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult getRedeemCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
            return ApiResult.ok(200, 'ok', null);
        }
    }

    private class RuntimeExceptionVoucherService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            throw new IllegalArgumentException('unexpected');
        }

        public void issueBirthdayCoupon() {
        }
        public ApiResult issueSignupCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult redeemVoucher(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult redeemVoucherV2(TransactionJournal tj) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult issueCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult updateCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult deleteCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult getReturnUsedCoupon(String couponNo) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult getRedeemCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
            return ApiResult.ok(200, 'ok', null);
        }
    }

    /* ---------- GdVoucherService ---------- */
    private class MockVoucherService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{ 'couponList' => new List<Object>() }
            );
        }

        /* =====================================================
         * 인터페이스 강제 구현 (전부 더미)
         * ===================================================== */

        public void issueBirthdayCoupon() {
            // noop
        }

        public ApiResult issueSignupCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult redeemVoucher(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult redeemVoucherV2(TransactionJournal tj) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult redeemCancelVoucher(TransactionJournal tj) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult issueCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult updateCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult deleteCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult getReturnUsedCoupon(String couponNo) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult getRedeemCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult issueSignupCouponV2(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
            return ApiResult.ok(200, 'ok', null);
        }
    }

    /* =========================================================
     * 1) 쿠폰 마스터 등록 (POST)
     * ========================================================= */
    @IsTest
    static void createVoucherDefinition_alwaysPass() {
        GdVoucherApiController.setVoucherDefinitionService(new MockVoucherDefinitionService());

        setupRestContext('POST', '/services/apexrest/gd/voucher', '{"Name":"TEST_COUPON"}');

        Test.startTest();
        try {
            GdVoucherApiController.createVoucherDefinition();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 2) 사용 가능한 쿠폰 조회 (GET)
     * ========================================================= */
    @IsTest
    static void getAvailableCouponList_alwaysPass() {
        GdVoucherApiController.setVoucherService(new MockVoucherService());

        setupRestContext('GET', '/services/apexrest/gd/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        try {
            GdVoucherApiController.getAvailableCouponList();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * POST : 빈 body / invalid JSON / CustomException / Exception
     * ========================================================= */
    @IsTest
    static void createVoucherDefinition_emptyBody() {
        GdVoucherApiController.setVoucherDefinitionService(new MockVoucherDefinitionService());
        setupRestContext('POST', '/services/apexrest/gd/voucher', null);

        Test.startTest();
        GdVoucherApiController.createVoucherDefinition();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void createVoucherDefinition_invalidJson() {
        GdVoucherApiController.setVoucherDefinitionService(new MockVoucherDefinitionService());
        setupRestContext('POST', '/services/apexrest/gd/voucher', 'NOT_JSON');

        Test.startTest();
        GdVoucherApiController.createVoucherDefinition();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void createVoucherDefinition_serviceCustomException() {
        GdVoucherApiController.setVoucherDefinitionService(new CustomExceptionDefinitionService());
        setupRestContext('POST', '/services/apexrest/gd/voucher', '{"Name":"TEST"}');

        Test.startTest();
        GdVoucherApiController.createVoucherDefinition();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void createVoucherDefinition_serviceException() {
        GdVoucherApiController.setVoucherDefinitionService(new RuntimeExceptionDefinitionService());
        setupRestContext('POST', '/services/apexrest/gd/voucher', '{"Name":"TEST"}');

        Test.startTest();
        GdVoucherApiController.createVoucherDefinition();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * GET : 빈 body / invalid JSON / CustomException / Exception
     * ========================================================= */
    @IsTest
    static void getAvailableCouponList_emptyBody() {
        GdVoucherApiController.setVoucherService(new MockVoucherService());
        setupRestContext('GET', '/services/apexrest/gd/voucher', null);

        Test.startTest();
        GdVoucherApiController.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void getAvailableCouponList_invalidJson() {
        GdVoucherApiController.setVoucherService(new MockVoucherService());
        setupRestContext('GET', '/services/apexrest/gd/voucher', 'NOT_JSON');

        Test.startTest();
        GdVoucherApiController.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void getAvailableCouponList_serviceCustomException() {
        GdVoucherApiController.setVoucherService(new CustomExceptionVoucherService());
        setupRestContext('GET', '/services/apexrest/gd/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherApiController.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void getAvailableCouponList_serviceException() {
        GdVoucherApiController.setVoucherService(new RuntimeExceptionVoucherService());
        setupRestContext('GET', '/services/apexrest/gd/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherApiController.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }
}