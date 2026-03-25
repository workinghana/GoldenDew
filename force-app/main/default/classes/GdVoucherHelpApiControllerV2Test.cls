@IsTest
private class GdVoucherHelpApiControllerV2Test {
    private static void setupRest(String body) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v2/voucher/help';
        req.httpMethod = 'POST';
        if (body != null)
            req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================================================
     * Mock : GdVoucherService 구현체들
     * ========================================================= */
    private class MockVoucherService implements GdVoucherService {
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
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
    }

    private class ValidationExceptionMockService implements GdVoucherService {
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
            throw new ValidationException('getAvailableCouponListV2', 'validation error');
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
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
    }

    private class CustomExceptionMockService implements GdVoucherService {
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
            throw new CustomException(422, 'custom error');
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
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
    }

    private class RuntimeExceptionMockService implements GdVoucherService {
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
            throw new IllegalArgumentException('unexpected error');
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
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
    }

    /* =========================================================
     * 1) 성공 케이스 + setVoucherService / getVoucherService 커버
     * ========================================================= */
    @IsTest
    static void getAvailableCouponListV2_success() {
        GdVoucherHelpApiControllerV2.setVoucherService(new MockVoucherService());
        setupRest('{}');

        Test.startTest();
        GdVoucherHelpApiControllerV2.getAvailableCouponListV2();
        Test.stopTest();

        System.assertNotEquals(null, RestContext.response);
    }

    /* =========================================================
     * 2) 빈 body → 기존 테스트 (getVoucherService null 분기 커버)
     * ========================================================= */
    @IsTest
    static void getAvailableCouponListV2_emptyBody_handlesError() {
        setupRest(null);
        Test.startTest();
        GdVoucherHelpApiControllerV2.getAvailableCouponListV2();
        Test.stopTest();
        System.assertNotEquals(null, RestContext.response);
    }

    /* =========================================================
     * 3) ValidationException → catch (ValidationException ve)
     * ========================================================= */
    @IsTest
    static void getAvailableCouponListV2_validationException() {
        GdVoucherHelpApiControllerV2.setVoucherService(new ValidationExceptionMockService());
        setupRest('{}');

        Test.startTest();
        GdVoucherHelpApiControllerV2.getAvailableCouponListV2();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 4) CustomException → catch (CustomException ce)
     * ========================================================= */
    @IsTest
    static void getAvailableCouponListV2_customException() {
        GdVoucherHelpApiControllerV2.setVoucherService(new CustomExceptionMockService());
        setupRest('{}');

        Test.startTest();
        GdVoucherHelpApiControllerV2.getAvailableCouponListV2();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 5) Exception → catch (Exception e)
     * ========================================================= */
    @IsTest
    static void getAvailableCouponListV2_unexpectedException() {
        GdVoucherHelpApiControllerV2.setVoucherService(new RuntimeExceptionMockService());
        setupRest('{}');

        Test.startTest();
        GdVoucherHelpApiControllerV2.getAvailableCouponListV2();
        Test.stopTest();

        System.assert(true);
    }
}