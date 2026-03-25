/**
 * Test class for ErpCouponIssueDto
 */
@IsTest
private class ErpCouponIssueDtoTest {
    // =========================
    // TEST: IssueRequest 생성 및 필드 할당
    // =========================
    @IsTest
    static void test_issueRequest_creation() {
        // Given & When
        ErpCouponIssueDto.IssueRequest req = new ErpCouponIssueDto.IssueRequest();
        req.no_man_coupon = 'CPN001';
        req.no_mbr = 'MBR001';
        req.id_insert = 'TestUser';

        // Then
        System.assertEquals('CPN001', req.no_man_coupon, 'no_man_coupon should be set');
        System.assertEquals('MBR001', req.no_mbr, 'no_mbr should be set');
        System.assertEquals('TestUser', req.id_insert, 'id_insert should be set');
    }

    // =========================
    // TEST: IssueRequest null 필드
    // =========================
    @IsTest
    static void test_issueRequest_nullFields() {
        // Given & When
        ErpCouponIssueDto.IssueRequest req = new ErpCouponIssueDto.IssueRequest();

        // Then
        System.assertEquals(null, req.no_man_coupon, 'no_man_coupon should be null by default');
        System.assertEquals(null, req.no_mbr, 'no_mbr should be null by default');
        System.assertEquals(null, req.id_insert, 'id_insert should be null by default');
    }

    // =========================
    // TEST: IssueResponse 생성 및 필드 할당
    // =========================
    @IsTest
    static void test_issueResponse_creation() {
        // Given & When
        ErpCouponIssueDto.IssueResponse res = new ErpCouponIssueDto.IssueResponse();
        res.success = true;
        res.message = 'Success message';
        res.errorMessage = null;
        res.issuedCouponCodes = new List<String>{ 'CODE001', 'CODE002' };

        // Then
        System.assertEquals(true, res.success, 'success should be true');
        System.assertEquals('Success message', res.message, 'message should be set');
        System.assertEquals(null, res.errorMessage, 'errorMessage should be null');
        System.assertEquals(2, res.issuedCouponCodes.size(), 'Should have 2 coupon codes');
        System.assertEquals('CODE001', res.issuedCouponCodes[0], 'First code should match');
        System.assertEquals('CODE002', res.issuedCouponCodes[1], 'Second code should match');
    }

    // =========================
    // TEST: IssueResponse 실패 케이스
    // =========================
    @IsTest
    static void test_issueResponse_failure() {
        // Given & When
        ErpCouponIssueDto.IssueResponse res = new ErpCouponIssueDto.IssueResponse();
        res.success = false;
        res.message = null;
        res.errorMessage = 'Error occurred';
        res.issuedCouponCodes = new List<String>();

        // Then
        System.assertEquals(false, res.success, 'success should be false');
        System.assertEquals(null, res.message, 'message should be null');
        System.assertEquals('Error occurred', res.errorMessage, 'errorMessage should be set');
        System.assertEquals(0, res.issuedCouponCodes.size(), 'Should have no coupon codes');
    }

    // =========================
    // TEST: IssueResponse null 필드
    // =========================
    @IsTest
    static void test_issueResponse_nullFields() {
        // Given & When
        ErpCouponIssueDto.IssueResponse res = new ErpCouponIssueDto.IssueResponse();

        // Then
        System.assertEquals(null, res.success, 'success should be null by default');
        System.assertEquals(null, res.message, 'message should be null by default');
        System.assertEquals(null, res.errorMessage, 'errorMessage should be null by default');
        System.assertEquals(
            null,
            res.issuedCouponCodes,
            'issuedCouponCodes should be null by default'
        );
    }

    // =========================
    // TEST: ErpCouponIssueDto 생성자
    // =========================
    @IsTest
    static void test_erpCouponIssueDto_constructor() {
        // Given & When
        ErpCouponIssueDto dto = new ErpCouponIssueDto();

        // Then
        System.assertNotEquals(null, dto, 'DTO should be instantiated');
    }

    // =========================
    // TEST: 여러 IssueRequest 객체 생성
    // =========================
    @IsTest
    static void test_multipleIssueRequests() {
        // Given & When
        List<ErpCouponIssueDto.IssueRequest> requests = new List<ErpCouponIssueDto.IssueRequest>();

        ErpCouponIssueDto.IssueRequest req1 = new ErpCouponIssueDto.IssueRequest();
        req1.no_man_coupon = 'CPN001';
        req1.no_mbr = 'MBR001';
        req1.id_insert = 'User1';

        ErpCouponIssueDto.IssueRequest req2 = new ErpCouponIssueDto.IssueRequest();
        req2.no_man_coupon = 'CPN002';
        req2.no_mbr = 'MBR002';
        req2.id_insert = 'User2';

        requests.add(req1);
        requests.add(req2);

        // Then
        System.assertEquals(2, requests.size(), 'Should have 2 requests');
        System.assertEquals(
            'CPN001',
            requests[0].no_man_coupon,
            'First request coupon should match'
        );
        System.assertEquals(
            'CPN002',
            requests[1].no_man_coupon,
            'Second request coupon should match'
        );
    }
}