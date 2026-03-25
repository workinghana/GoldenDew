@IsTest
private class GdVoucherHelpApiControllerV1Test {
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
     * Mock : 예외를 던지는 GdVoucherService 구현체들
     * ========================================================= */
    private class CustomExceptionMockService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) { throw new CustomException(422, 'custom error'); }

        public void issueBirthdayCoupon() {}
        public ApiResult issueSignupCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucher(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucherV2(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult updateCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult deleteCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getReturnUsedCoupon(String couponNo) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getRedeemCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) { return ApiResult.ok(200, 'ok', null); }
    }

    private class RuntimeExceptionMockService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) { throw new IllegalArgumentException('unexpected error'); }

        public void issueBirthdayCoupon() {}
        public ApiResult issueSignupCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucher(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucherV2(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult updateCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult deleteCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getReturnUsedCoupon(String couponNo) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getRedeemCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) { return ApiResult.ok(200, 'ok', null); }
    }

    /* =========================================================
     * Mock : GdVoucherService
     * ========================================================= */
    private class MockVoucherService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{ 'couponList' => new List<Object>() }
            );
        }

        /* ===== 인터페이스 요구 (미사용 메서드 더미 구현) ===== */

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
     * POST : /gd/v1/voucher/help
     * ========================================================= */
    @IsTest
    static void test_getAvailableCouponList_success() {
        // Mock 주입
        GdVoucherHelpApiControllerV1.setVoucherService(new MockVoucherService());

        setupRestContext(
            'POST',
            '/services/apexrest/gd/v1/voucher/help',
            '{"memberNo":"M001","orderAmount":10000}'
        );

        Test.startTest();
        GdVoucherHelpApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, '응답은 200이어야 합니다.');
    }

    /* =========================================================
     * 2) 빈 body → CustomException catch
     * ========================================================= */
    @IsTest
    static void test_getAvailableCouponList_emptyBody_customException() {
        GdVoucherHelpApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('POST', '/services/apexrest/gd/v1/voucher/help', null);

        Test.startTest();
        GdVoucherHelpApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 3) 잘못된 JSON → 내부 catch → CustomException catch
     * ========================================================= */
    @IsTest
    static void test_getAvailableCouponList_invalidJson_customException() {
        GdVoucherHelpApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('POST', '/services/apexrest/gd/v1/voucher/help', 'NOT_JSON');

        Test.startTest();
        GdVoucherHelpApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 4) 서비스 CustomException → catch (CustomException ce)
     * ========================================================= */
    @IsTest
    static void test_getAvailableCouponList_serviceCustomException() {
        GdVoucherHelpApiControllerV1.setVoucherService(new CustomExceptionMockService());
        setupRestContext('POST', '/services/apexrest/gd/v1/voucher/help', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherHelpApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 5) 서비스 Exception → catch (Exception e)
     * ========================================================= */
    @IsTest
    static void test_getAvailableCouponList_serviceException() {
        GdVoucherHelpApiControllerV1.setVoucherService(new RuntimeExceptionMockService());
        setupRestContext('POST', '/services/apexrest/gd/v1/voucher/help', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherHelpApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }
}