@IsTest
private class MonthlyCouponissueJobTest {
    /* =====================================================
     * Mock GdVoucherService (FULL IMPLEMENTATION)
     * ===================================================== */
    private class MockVoucherService implements GdVoucherService {
        public Boolean called = false;
        public Boolean throwCustom = false;
        public Boolean throwException = false;

        // execute()에서 호출되는 메서드
        public void issueBirthdayCoupon() {
            called = true;

            if (throwCustom) {
                throw new CustomException(400, '테스트 커스텀 예외');
            }

            if (throwException) {
                Integer x = 1 / 0; // MathException 발생
            }
        }

        /* ===== 인터페이스 강제 구현 메서드들 (더미) ===== */

        public ApiResult issueSignupCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) {
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

    private static void setupRestContext() {
        RestContext.request = new RestRequest();
        RestContext.response = new RestResponse();
        RestContext.request.httpMethod = 'POST';
        RestContext.request.requestURI = '/services/apexrest/v1/monthly-coupon';
    }

    /* =====================================================
     * 테스트는 그대로
     * ===================================================== */

    @IsTest
    static void test_execute_success() {
        setupRestContext();
        MockVoucherService mock = new MockVoucherService();
        MonthlyCouponissueJob.setVoucherService(mock);

        Test.startTest();
        new MonthlyCouponissueJob().execute(null);
        Test.stopTest();

        System.assertEquals(true, mock.called);
    }

    @IsTest
    static void test_execute_customException_branch() {
        setupRestContext();
        MockVoucherService mock = new MockVoucherService();
        mock.throwCustom = true;
        MonthlyCouponissueJob.setVoucherService(mock);

        Test.startTest();
        new MonthlyCouponissueJob().execute(null);
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    @IsTest
    static void test_execute_exception_branch() {
        setupRestContext();
        MockVoucherService mock = new MockVoucherService();
        mock.throwException = true;
        MonthlyCouponissueJob.setVoucherService(mock);

        Test.startTest();
        new MonthlyCouponissueJob().execute(null);
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
    }
}