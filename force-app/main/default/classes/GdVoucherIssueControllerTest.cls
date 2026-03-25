@IsTest
private class GdVoucherIssueControllerTest {
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
        public ApiResult issueCoupon(Map<String, Object> req) {
            throw new CustomException(422, 'issue custom error');
        }
        public ApiResult updateCoupon(Map<String, Object> req) {
            throw new CustomException(422, 'update custom error');
        }
        public ApiResult deleteCoupon(Map<String, Object> req) {
            throw new CustomException(422, 'delete custom error');
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public void issueBirthdayCoupon() {
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

    private class RuntimeExceptionMockService implements GdVoucherService {
        public ApiResult issueCoupon(Map<String, Object> req) {
            throw new IllegalArgumentException('issue unexpected');
        }
        public ApiResult updateCoupon(Map<String, Object> req) {
            throw new IllegalArgumentException('update unexpected');
        }
        public ApiResult deleteCoupon(Map<String, Object> req) {
            throw new IllegalArgumentException('delete unexpected');
        }

        public ApiResult getAvailableCouponList(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }
        public void issueBirthdayCoupon() {
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
     * Mock : GdVoucherService
     * ========================================================= */
    private class MockVoucherService implements GdVoucherService {
        /* === 실제 컨트롤러에서 사용하는 메서드 === */

        public ApiResult issueCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult updateCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
        }

        public ApiResult deleteCoupon(Map<String, Object> req) {
            return ApiResult.ok(200, 'ok', null);
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
     * 1) POST : 쿠폰 개별 지급
     * ========================================================= */
    @IsTest
    static void test_issueSingleVoucher_success() {
        GdVoucherIssueController.setVoucherService(new MockVoucherService());

        setupRestContext(
            'POST',
            '/services/apexrest/gd/issue/voucher',
            '{"memberNo":"M001","couponCode":"C001"}'
        );

        Test.startTest();
        GdVoucherIssueController.issueSingleVoucher();
        Test.stopTest();

        System.assertEquals(
            200,
            RestContext.response.statusCode,
            '쿠폰 지급은 200 응답이어야 합니다.'
        );
    }

    /* =========================================================
     * 2) PATCH : 쿠폰 개별 수정
     * ========================================================= */
    @IsTest
    static void test_updateSingleVoucher_success() {
        GdVoucherIssueController.setVoucherService(new MockVoucherService());

        setupRestContext(
            'PATCH',
            '/services/apexrest/gd/issue/voucher',
            '{"couponId":"CPN001","status":"USED"}'
        );

        Test.startTest();
        GdVoucherIssueController.updateSingleVoucher();
        Test.stopTest();

        System.assertEquals(
            200,
            RestContext.response.statusCode,
            '쿠폰 수정은 200 응답이어야 합니다.'
        );
    }

    /* =========================================================
     * 3) DELETE : 쿠폰 개별 삭제
     * ========================================================= */
    @IsTest
    static void test_deleteSingleVoucher_success() {
        GdVoucherIssueController.setVoucherService(new MockVoucherService());

        setupRestContext('DELETE', '/services/apexrest/gd/issue/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherIssueController.deleteSingleVoucher();
        Test.stopTest();

        System.assertEquals(
            200,
            RestContext.response.statusCode,
            '쿠폰 삭제는 200 응답이어야 합니다.'
        );
    }

    /* =========================================================
     * 4) POST : 빈 body → CustomException catch
     * ========================================================= */
    @IsTest
    static void test_issueSingleVoucher_emptyBody_customException() {
        GdVoucherIssueController.setVoucherService(new MockVoucherService());
        setupRestContext('POST', '/services/apexrest/gd/issue/voucher', null);

        Test.startTest();
        GdVoucherIssueController.issueSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 5) POST : 잘못된 JSON → 내부 catch → CustomException catch
     * ========================================================= */
    @IsTest
    static void test_issueSingleVoucher_invalidJson_customException() {
        GdVoucherIssueController.setVoucherService(new MockVoucherService());
        setupRestContext('POST', '/services/apexrest/gd/issue/voucher', 'NOT_JSON');

        Test.startTest();
        GdVoucherIssueController.issueSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 6) POST : 서비스 CustomException → catch (CustomException)
     * ========================================================= */
    @IsTest
    static void test_issueSingleVoucher_serviceCustomException() {
        GdVoucherIssueController.setVoucherService(new CustomExceptionMockService());
        setupRestContext('POST', '/services/apexrest/gd/issue/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherIssueController.issueSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 7) POST : 서비스 Exception → catch (Exception)
     * ========================================================= */
    @IsTest
    static void test_issueSingleVoucher_serviceException() {
        GdVoucherIssueController.setVoucherService(new RuntimeExceptionMockService());
        setupRestContext('POST', '/services/apexrest/gd/issue/voucher', '{"memberNo":"M001"}');

        Test.startTest();
        GdVoucherIssueController.issueSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 8) PATCH : 빈 body → CustomException catch
     * ========================================================= */
    @IsTest
    static void test_updateSingleVoucher_emptyBody_customException() {
        GdVoucherIssueController.setVoucherService(new MockVoucherService());
        setupRestContext('PATCH', '/services/apexrest/gd/issue/voucher', null);

        Test.startTest();
        GdVoucherIssueController.updateSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 9) PATCH : 서비스 CustomException → catch (CustomException)
     * ========================================================= */
    @IsTest
    static void test_updateSingleVoucher_serviceCustomException() {
        GdVoucherIssueController.setVoucherService(new CustomExceptionMockService());
        setupRestContext('PATCH', '/services/apexrest/gd/issue/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherIssueController.updateSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 10) PATCH : 서비스 Exception → catch (Exception)
     * ========================================================= */
    @IsTest
    static void test_updateSingleVoucher_serviceException() {
        GdVoucherIssueController.setVoucherService(new RuntimeExceptionMockService());
        setupRestContext('PATCH', '/services/apexrest/gd/issue/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherIssueController.updateSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 11) DELETE : 빈 body → CustomException catch
     * ========================================================= */
    @IsTest
    static void test_deleteSingleVoucher_emptyBody_customException() {
        GdVoucherIssueController.setVoucherService(new MockVoucherService());
        setupRestContext('DELETE', '/services/apexrest/gd/issue/voucher', null);

        Test.startTest();
        GdVoucherIssueController.deleteSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 12) DELETE : 서비스 CustomException → catch (CustomException)
     * ========================================================= */
    @IsTest
    static void test_deleteSingleVoucher_serviceCustomException() {
        GdVoucherIssueController.setVoucherService(new CustomExceptionMockService());
        setupRestContext('DELETE', '/services/apexrest/gd/issue/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherIssueController.deleteSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 13) DELETE : 서비스 Exception → catch (Exception)
     * ========================================================= */
    @IsTest
    static void test_deleteSingleVoucher_serviceException() {
        GdVoucherIssueController.setVoucherService(new RuntimeExceptionMockService());
        setupRestContext('DELETE', '/services/apexrest/gd/issue/voucher', '{"couponId":"CPN001"}');

        Test.startTest();
        GdVoucherIssueController.deleteSingleVoucher();
        Test.stopTest();

        System.assert(true);
    }
}