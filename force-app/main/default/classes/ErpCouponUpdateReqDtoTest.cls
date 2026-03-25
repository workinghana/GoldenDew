/**
 * Test class for ErpCouponUpdateReqDto
 */
@IsTest
private class ErpCouponUpdateReqDtoTest {
    // =========================
    // TEST: 기본 생성자
    // =========================
    @IsTest
    static void test_defaultConstructor() {
        // Given & When
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();

        // Then
        System.assertNotEquals(null, dto, 'DTO should be instantiated');
        System.assertEquals(null, dto.no_man_coupon, 'no_man_coupon should be null by default');
        System.assertEquals(null, dto.no_mbr, 'no_mbr should be null by default');
        System.assertEquals(null, dto.no_coupon, 'no_coupon should be null by default');
        System.assertEquals(null, dto.id_update, 'id_update should be null by default');
        System.assertEquals(null, dto.dt_end_exp_mbr, 'dt_end_exp_mbr should be null by default');
    }

    // =========================
    // TEST: 파라미터 생성자
    // =========================
    @IsTest
    static void test_parameterizedConstructor() {
        // Given & When
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto(
            'COP2025OC0011',
            '213006800125',
            'COP2025OC0011',
            '쿠폰 지급 테스트',
            '20250101'
        );

        // Then
        System.assertEquals('COP2025OC0011', dto.no_man_coupon, 'no_man_coupon should match');
        System.assertEquals('213006800125', dto.no_mbr, 'no_mbr should match');
        System.assertEquals('COP2025OC0011', dto.no_coupon, 'no_coupon should match');
        System.assertEquals('쿠폰 지급 테스트', dto.id_update, 'id_update should match');
        System.assertEquals('20250101', dto.dt_end_exp_mbr, 'dt_end_exp_mbr should match');
    }

    // =========================
    // TEST: validate() - 정상 케이스
    // =========================
    @IsTest
    static void test_validate_success() {
        // Given
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto(
            'CPN001',
            'MBR001',
            'CPN_CODE001',
            'TestUser',
            '20260101'
        );

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
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();
        dto.no_man_coupon = null;
        dto.no_mbr = 'MBR001';
        dto.no_coupon = 'CPN001';
        dto.id_update = 'TestUser';
        dto.dt_end_exp_mbr = '20260101';

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
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();
        dto.no_man_coupon = '';
        dto.no_mbr = 'MBR001';
        dto.no_coupon = 'CPN001';
        dto.id_update = 'TestUser';
        dto.dt_end_exp_mbr = '20260101';

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
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = null;
        dto.no_coupon = 'CPN001';
        dto.id_update = 'TestUser';
        dto.dt_end_exp_mbr = '20260101';

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
    // TEST: validate() - no_coupon null
    // =========================
    @IsTest
    static void test_validate_noCouponNull() {
        // Given
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = 'MBR001';
        dto.no_coupon = null;
        dto.id_update = 'TestUser';
        dto.dt_end_exp_mbr = '20260101';

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('no_coupon is required'),
                'Exception message should mention no_coupon'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - id_update null
    // =========================
    @IsTest
    static void test_validate_idUpdateNull() {
        // Given
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = 'MBR001';
        dto.no_coupon = 'CPN001';
        dto.id_update = null;
        dto.dt_end_exp_mbr = '20260101';

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('id_update is required'),
                'Exception message should mention id_update'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - dt_end_exp_mbr null
    // =========================
    @IsTest
    static void test_validate_dtEndExpMbrNull() {
        // Given
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = 'MBR001';
        dto.no_coupon = 'CPN001';
        dto.id_update = 'TestUser';
        dto.dt_end_exp_mbr = null;

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('dt_end_exp_mbr is required'),
                'Exception message should mention dt_end_exp_mbr'
            );
        }
        Test.stopTest();
    }

    // =========================
    // TEST: validate() - dt_end_exp_mbr empty
    // =========================
    @IsTest
    static void test_validate_dtEndExpMbrEmpty() {
        // Given
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();
        dto.no_man_coupon = 'CPN001';
        dto.no_mbr = 'MBR001';
        dto.no_coupon = 'CPN001';
        dto.id_update = 'TestUser';
        dto.dt_end_exp_mbr = '';

        // When & Then
        Test.startTest();
        try {
            dto.validate();
            System.assert(false, 'Should have thrown IllegalArgumentException');
        } catch (IllegalArgumentException e) {
            System.assert(
                e.getMessage().contains('dt_end_exp_mbr is required'),
                'Exception message should mention dt_end_exp_mbr'
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
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();
        dto.no_man_coupon = '   ';
        dto.no_mbr = '   ';
        dto.no_coupon = '   ';
        dto.id_update = '   ';
        dto.dt_end_exp_mbr = '   ';

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
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto();

        // When
        dto.no_man_coupon = 'TEST_MAN_CPN';
        dto.no_mbr = 'TEST_MBR';
        dto.no_coupon = 'TEST_CPN';
        dto.id_update = 'TEST_USER';
        dto.dt_end_exp_mbr = '20261231';

        // Then
        System.assertEquals('TEST_MAN_CPN', dto.no_man_coupon, 'no_man_coupon should be set');
        System.assertEquals('TEST_MBR', dto.no_mbr, 'no_mbr should be set');
        System.assertEquals('TEST_CPN', dto.no_coupon, 'no_coupon should be set');
        System.assertEquals('TEST_USER', dto.id_update, 'id_update should be set');
        System.assertEquals('20261231', dto.dt_end_exp_mbr, 'dt_end_exp_mbr should be set');

        // Validate 통과 확인
        dto.validate();
    }

    // =========================
    // TEST: 날짜 포맷 검증 (YYYYMMDD)
    // =========================
    @IsTest
    static void test_dateFormatYYYYMMDD() {
        // Given
        ErpCouponUpdateReqDto dto = new ErpCouponUpdateReqDto(
            'CPN001',
            'MBR001',
            'CPN_CODE001',
            'TestUser',
            '20260315'
        );

        // When & Then
        dto.validate();
        System.assertEquals('20260315', dto.dt_end_exp_mbr, 'Date should be in YYYYMMDD format');
    }
}