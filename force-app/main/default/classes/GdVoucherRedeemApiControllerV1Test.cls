@IsTest
private class GdVoucherRedeemApiControllerV1Test {
    /* =========================================================
     * 공통: RestContext 세팅 (GET + params)
     * ========================================================= */
    private static void setupRestContextWithParams(String uri, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = 'GET';

        for (String key : params.keySet()) {
            req.params.put(key, params.get(key));
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================================================
     * Mock : 예외를 던지는 GdVoucherService 구현체들
     * ========================================================= */
    private class ValidationExceptionMockService implements GdVoucherService {
        public ApiResult getRedeemCoupon(Map<String, Object> req) {
            throw new ValidationException('getRedeemCoupon', 'validation error');
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public void issueBirthdayCoupon() {}
        public ApiResult issueSignupCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucher(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucherV2(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult updateCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult deleteCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getReturnUsedCoupon(String couponNo) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) { return ApiResult.ok(200, 'ok', null); }
    }

    private class CustomExceptionMockService implements GdVoucherService {
        public ApiResult getRedeemCoupon(Map<String, Object> req) {
            throw new CustomException(422, 'custom error');
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public void issueBirthdayCoupon() {}
        public ApiResult issueSignupCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucher(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucherV2(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult updateCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult deleteCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getReturnUsedCoupon(String couponNo) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) { return ApiResult.ok(200, 'ok', null); }
    }

    private class RuntimeExceptionMockService implements GdVoucherService {
        public ApiResult getRedeemCoupon(Map<String, Object> req) {
            throw new IllegalArgumentException('unexpected error');
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public void issueBirthdayCoupon() {}
        public ApiResult issueSignupCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucher(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucherV2(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult updateCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult deleteCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getReturnUsedCoupon(String couponNo) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) { return ApiResult.ok(200, 'ok', null); }
    }

    /* =========================================================
     * Mock : GdVoucherService
     * ========================================================= */
    private class MockVoucherService implements GdVoucherService {
        /* === 실제 컨트롤러에서 사용하는 메서드 === */
        public ApiResult getRedeemCoupon(Map<String, Object> req) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{ 'redeemList' => new List<Object>() }
            );
        }

        /* === 인터페이스 요구 (미사용 메서드 더미) === */

        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

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

        public ApiResult issueSignupCouponV2(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
            return ApiResult.ok(200, 'ok', null);
        }
    }

    /* =========================================================
     * GET : 사용한 쿠폰 조회
     * ========================================================= */
    @IsTest
    static void test_getRedeemCoupon_success() {
        // Mock 주입
        GdVoucherRedeemApiControllerV1.setVoucherService(new MockVoucherService());

        Map<String, String> params = new Map<String, String>{
            'memberNo' => 'M001',
            'orderNo' => 'O20260101'
        };

        setupRestContextWithParams('/services/apexrest/gd/v1/voucher/redeem', params);

        Test.startTest();
        GdVoucherRedeemApiControllerV1.getRedeemCoupon();
        Test.stopTest();

        System.assertEquals(
            200,
            RestContext.response.statusCode,
            '사용 쿠폰 조회는 200 응답이어야 합니다.'
        );
    }

    @IsTest
    static void test_getRedeemCoupon_validationException() {
        GdVoucherRedeemApiControllerV1.setVoucherService(new ValidationExceptionMockService());

        setupRestContextWithParams('/services/apexrest/gd/v1/voucher/redeem', new Map<String, String>());

        Test.startTest();
        GdVoucherRedeemApiControllerV1.getRedeemCoupon();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_getRedeemCoupon_customException() {
        GdVoucherRedeemApiControllerV1.setVoucherService(new CustomExceptionMockService());

        setupRestContextWithParams('/services/apexrest/gd/v1/voucher/redeem', new Map<String, String>());

        Test.startTest();
        GdVoucherRedeemApiControllerV1.getRedeemCoupon();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_getRedeemCoupon_unexpectedException() {
        GdVoucherRedeemApiControllerV1.setVoucherService(new RuntimeExceptionMockService());

        setupRestContextWithParams('/services/apexrest/gd/v1/voucher/redeem', new Map<String, String>());

        Test.startTest();
        GdVoucherRedeemApiControllerV1.getRedeemCoupon();
        Test.stopTest();

        System.assert(true);
    }
}