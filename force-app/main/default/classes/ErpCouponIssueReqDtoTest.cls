/**
 * Test class for ErpCouponIssueReqDto
 */
@IsTest
private class ErpCouponIssueReqDtoTest {
    // =========================
    // TEST: 기본 생성자
    // =========================
    @IsTest
    static void test_defaultConstructor() {
        // Given & When
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();

        // Then
        System.assertNotEquals(null, dto, 'DTO should be instantiated');
        System.assertEquals(null, dto.no_man_coupon, 'no_man_coupon should be null by default');
        System.assertEquals(null, dto.no_mbr, 'no_mbr should be null by default');
        System.assertEquals(null, dto.id_insert, 'id_insert should be null by default');
    }

    // =========================
    // TEST: 파라미터 생성자
    // =========================
    @IsTest
    static void test_parameterizedConstructor() {
        // Given & When
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto(
            'COP2025DC0002',
            '259999800019',
            '쿠폰 지급 테스트'
        );

        // Then
        System.assertEquals('COP2025DC0002', dto.no_man_coupon, 'no_man_coupon should match');
        System.assertEquals('259999800019', dto.no_mbr, 'no_mbr should match');
        System.assertEquals('쿠폰 지급 테스트', dto.id_insert, 'id_insert should match');
    }

    // =========================
    // TEST: validate() - 정상 케이스
    // =========================
    @IsTest
    static void test_validate_success() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto('CPN001', 'MBR001', 'TestUser');

        // When & Then - 예외 없이 성공
        Test.startTest();
        dto.validate();
        Test.stopTest();

        // Assert - 검증 통과
        System.assertEquals('CPN001', dto.no_man_coupon, 'no_man_coupon should be set');
    }

    // =========================
    // TEST: validate() - no_man_coupon null
    // =========================
    @IsTest
    static void test_validate_noManCouponNull() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();
        dto.no_man_coupon = null; // null
        dto.no_mbr = 'MBR001';
        dto.id_insert = 'TestUser';

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('no_man_coupon is required'),
                'Exception message should mention no_man_coupon'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - no_man_coupon empty
    // =========================
    @IsTest
    static void test_validate_noManCouponEmpty() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();
        dto.no_man_coupon = ''; // empty
        dto.no_mbr = 'MBR001';
        dto.id_insert = 'TestUser';

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('no_man_coupon is required'),
                'Exception message should mention no_man_coupon'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - no_mbr null
    // =========================
    @IsTest
    static void test_validate_noMbrNull() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = null; // null
        dto.id_insert = 'TestUser';

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('no_mbr is required'),
                'Exception message should mention no_mbr'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - no_mbr empty
    // =========================
    @IsTest
    static void test_validate_noMbrEmpty() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = ''; // empty
        dto.id_insert = 'TestUser';

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('no_mbr is required'),
                'Exception message should mention no_mbr'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - id_insert null
    // =========================
    @IsTest
    static void test_validate_idInsertNull() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = 'MBR001';
        dto.id_insert = null; // null

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('id_insert is required'),
                'Exception message should mention id_insert'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - id_insert empty
    // =========================
    @IsTest
    static void test_validate_idInsertEmpty() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = 'MBR001';
        dto.id_insert = ''; // empty

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('id_insert is required'),
                'Exception message should mention id_insert'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - 모든 필드 blank
    // =========================
    @IsTest
    static void test_validate_allFieldsBlank() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();
        dto.no_man_coupon = '   '; // whitespace
        dto.no_mbr = '   '; // whitespace
        dto.id_insert = '   '; // whitespace

        // When & Then - no_man_coupon이 첫 번째로 검증되므로 해당 예외 발생
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('no_man_coupon is required'),
                'Exception message should mention no_man_coupon (first validated field)'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: 필드 직접 할당
    // =========================
    @IsTest
    static void test_fieldAssignment() {
        // Given
        ErpCouponIssueReqDto dto = new ErpCouponIssueReqDto();

        // When
        dto.no_man_coupon = 'TEST_CPN';
        dto.no_mbr = 'TEST_MBR';
        dto.id_insert = 'TEST_USER';

        // Then
        System.assertEquals('TEST_CPN', dto.no_man_coupon, 'no_man_coupon should be set');
        System.assertEquals('TEST_MBR', dto.no_mbr, 'no_mbr should be set');
        System.assertEquals('TEST_USER', dto.id_insert, 'id_insert should be set');

        // Validate 통과 확인
        dto.validate();
    }
}