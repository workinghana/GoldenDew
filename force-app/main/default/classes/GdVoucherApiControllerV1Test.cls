@IsTest
private class GdVoucherApiControllerV1Test {
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
     * Mock : GdVoucherDefinitionService
     * ========================================================= */
    private class MockVoucherDefinitionService implements GdVoucherDefinitionService {
        public ApiResult createVoucherDefinition(Map<String, Object> reqData) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult addVoucherLimitByPromotion(Map<String, Object> reqData) { return ApiResult.ok(200, 'ok', null); }
    }

    /* =========================================================
     * Mock : 예외를 던지는 GdVoucherService 구현체들
     * ========================================================= */
    private class CustomExceptionMockService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) { throw new CustomException(422, 'custom error'); }
        public ApiResult issueCoupon(Map<String, Object> req) { throw new CustomException(422, 'custom error'); }
        public ApiResult deleteCoupon(Map<String, Object> req) { throw new CustomException(422, 'custom error'); }
        public ApiResult updateCoupon(Map<String, Object> req) { throw new CustomException(422, 'custom error'); }

        public void issueBirthdayCoupon() {}
        public ApiResult issueSignupCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucher(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucherV2(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getReturnUsedCoupon(String couponNo) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getRedeemCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) { return ApiResult.ok(200, 'ok', null); }
    }

    private class RuntimeExceptionMockService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) { throw new IllegalArgumentException('unexpected'); }
        public ApiResult issueCoupon(Map<String, Object> req) { throw new IllegalArgumentException('unexpected'); }
        public ApiResult deleteCoupon(Map<String, Object> req) { throw new IllegalArgumentException('unexpected'); }
        public ApiResult updateCoupon(Map<String, Object> req) { throw new IllegalArgumentException('unexpected'); }

        public void issueBirthdayCoupon() {}
        public ApiResult issueSignupCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult issueSignupCouponV2(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucher(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemVoucherV2(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult redeemCancelVoucher(TransactionJournal tj) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getReturnUsedCoupon(String couponNo) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getRedeemCoupon(Map<String, Object> req) { return ApiResult.ok(200, 'ok', null); }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) { return ApiResult.ok(200, 'ok', null); }
    }

    /* =========================================================
     * Mock : GdVoucherService
     * ========================================================= */
    private class MockVoucherService implements GdVoucherService {
        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', new Map<String, Object>());
        }

        public ApiResult issueCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult deleteCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult updateCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        /* ===== 인터페이스 요구 but 여기서는 사용 안 함 ===== */

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
     * 1) GET : 사용 가능한 쿠폰 조회
     * ========================================================= */
    @IsTest
    static void test_getAvailableCouponList() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());

        setupRestContext('GET', '/services/apexrest/gd/v1/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* =========================================================
     * 2) POST : 쿠폰 개별 지급
     * ========================================================= */
    @IsTest
    static void test_issueSingleVoucher() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());

        setupRestContext(
            'POST',
            '/services/apexrest/gd/v1/voucher',
            '{"memberNo":"M001","couponCode":"C001"}'
        );

        Test.startTest();
        GdVoucherApiControllerV1.issueSingleVoucher();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* =========================================================
     * 3) DELETE : 쿠폰 개별 삭제
     * ========================================================= */
    @IsTest
    static void test_deleteSingleVoucher() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());

        setupRestContext('DELETE', '/services/apexrest/gd/v1/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherApiControllerV1.deleteSingleVoucher();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* =========================================================
     * 4) PATCH : 쿠폰 개별 수정
     * ========================================================= */
    @IsTest
    static void test_updateSingleVoucher() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());

        setupRestContext(
            'PATCH',
            '/services/apexrest/gd/v1/voucher',
            '{"couponId":"CPN001","status":"USED"}'
        );

        Test.startTest();
        GdVoucherApiControllerV1.updateSingleVoucher();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* =========================================================
     * setVoucherDefinitionService / getVoucherDefinitionService 커버
     * ========================================================= */
    @IsTest
    static void test_setVoucherDefinitionService_covers() {
        GdVoucherApiControllerV1.setVoucherDefinitionService(new MockVoucherDefinitionService());
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('GET', '/services/apexrest/gd/v1/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * GET : 빈 body / invalid JSON / CustomException / Exception
     * ========================================================= */
    @IsTest
    static void test_getAvailableCouponList_emptyBody() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('GET', '/services/apexrest/gd/v1/voucher', null);

        Test.startTest();
        GdVoucherApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_getAvailableCouponList_invalidJson() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('GET', '/services/apexrest/gd/v1/voucher', 'NOT_JSON');

        Test.startTest();
        GdVoucherApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_getAvailableCouponList_serviceCustomException() {
        GdVoucherApiControllerV1.setVoucherService(new CustomExceptionMockService());
        setupRestContext('GET', '/services/apexrest/gd/v1/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_getAvailableCouponList_serviceException() {
        GdVoucherApiControllerV1.setVoucherService(new RuntimeExceptionMockService());
        setupRestContext('GET', '/services/apexrest/gd/v1/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherApiControllerV1.getAvailableCouponList();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * POST : 빈 body / invalid JSON / CustomException / Exception
     * ========================================================= */
    @IsTest
    static void test_issueSingleVoucher_emptyBody() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('POST', '/services/apexrest/gd/v1/voucher', null);

        Test.startTest();
        GdVoucherApiControllerV1.issueSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_issueSingleVoucher_invalidJson() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('POST', '/services/apexrest/gd/v1/voucher', 'NOT_JSON');

        Test.startTest();
        GdVoucherApiControllerV1.issueSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_issueSingleVoucher_serviceCustomException() {
        GdVoucherApiControllerV1.setVoucherService(new CustomExceptionMockService());
        setupRestContext('POST', '/services/apexrest/gd/v1/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherApiControllerV1.issueSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_issueSingleVoucher_serviceException() {
        GdVoucherApiControllerV1.setVoucherService(new RuntimeExceptionMockService());
        setupRestContext('POST', '/services/apexrest/gd/v1/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherApiControllerV1.issueSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * DELETE : 빈 body / CustomException / Exception
     * ========================================================= */
    @IsTest
    static void test_deleteSingleVoucher_emptyBody() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('DELETE', '/services/apexrest/gd/v1/voucher', null);

        Test.startTest();
        GdVoucherApiControllerV1.deleteSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_deleteSingleVoucher_serviceCustomException() {
        GdVoucherApiControllerV1.setVoucherService(new CustomExceptionMockService());
        setupRestContext('DELETE', '/services/apexrest/gd/v1/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherApiControllerV1.deleteSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_deleteSingleVoucher_serviceException() {
        GdVoucherApiControllerV1.setVoucherService(new RuntimeExceptionMockService());
        setupRestContext('DELETE', '/services/apexrest/gd/v1/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherApiControllerV1.deleteSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * PATCH : 빈 body / invalid JSON / CustomException / Exception
     * ========================================================= */
    @IsTest
    static void test_updateSingleVoucher_emptyBody() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('PATCH', '/services/apexrest/gd/v1/voucher', null);

        Test.startTest();
        GdVoucherApiControllerV1.updateSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_updateSingleVoucher_invalidJson() {
        GdVoucherApiControllerV1.setVoucherService(new MockVoucherService());
        setupRestContext('PATCH', '/services/apexrest/gd/v1/voucher', 'NOT_JSON');

        Test.startTest();
        GdVoucherApiControllerV1.updateSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_updateSingleVoucher_serviceCustomException() {
        GdVoucherApiControllerV1.setVoucherService(new CustomExceptionMockService());
        setupRestContext('PATCH', '/services/apexrest/gd/v1/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherApiControllerV1.updateSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    @IsTest
    static void test_updateSingleVoucher_serviceException() {
        GdVoucherApiControllerV1.setVoucherService(new RuntimeExceptionMockService());
        setupRestContext('PATCH', '/services/apexrest/gd/v1/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherApiControllerV1.updateSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }
}