@IsTest
private class VoucherResDTOTest {
    // =========================================================
    // Helpers
    // =========================================================
    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Crypto.getRandomInteger()).substring(0, 6);
    }

    private static Voucher makeVoucher(String status) {
        LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('Prog'), IsPrimary = true);
        insert lp;

        Product2 prod = new Product2(Name = uniq('Prod'), IsActive = true);
        insert prod;

        VoucherDefinition vd = new VoucherDefinition(
            Name = uniq('VD'),
            LoyaltyProgramId = lp.Id,
            IsActive = true,
            Description = 'VoucherResDTOTest',
            ProductId = prod.Id,
            Type = 'ProductOrService',
            ExpirationType = 'FixedDate',
            EffectiveDate = Date.today(),
            ExpirationDate = Date.today().addDays(30),
            CouponManNo__c = uniq('CPN'),
            CouponTypeCode__c = '01',
            ResponsibleDepartment__c = 'Marketing',
            InsertId__c = 'TestUser',
            ResponsiblePerson__c = 'Manager'
        );
        insert vd;

        Contact c = new Contact(LastName = uniq('Member'));
        insert c;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ProgramId = lp.Id,
            ContactId = c.Id,
            MembershipNumber = uniq('MBR'),
            MemberStatus = 'Active',
            EnrollmentDate = Date.today()
        );
        insert lpm;

        Voucher v = new Voucher(
            VoucherDefinitionId = vd.Id,
            ContactId = c.Id,
            LoyaltyProgramMemberId = lpm.Id,
            Status = status,
            EffectiveDate = Date.today(),
            ExpirationDate = Date.today().addDays(30)
        );
        insert v;

        return [
            SELECT
                Id,
                Status,
                FaceValue,
                Reason,
                EffectiveDate,
                UseDate,
                ExpirationDate,
                CreatedDate,
                VoucherCode,
                DiscountPercent,
                VoucherDefinition.Name,
                VoucherDefinition.brand__c,
                VoucherDefinition.CouponManNo__c,
                VoucherDefinition.CouponTypeCode__c,
                VoucherDefinition.ExpirationType,
                VoucherDefinition.ExpirationPeriod,
                VoucherDefinition.ResponsibleDepartment__c,
                VoucherDefinition.InsertId__c,
                CreatedBy.Name
            FROM Voucher
            WHERE Id = :v.Id
        ];
    }

    // =========================================================
    // 1) 생성자 - Issued 상태 Voucher → DTO 필드 정상 매핑
    // =========================================================
    @IsTest
    static void test_constructor_issued_voucher_maps_fields() {
        Voucher v = makeVoucher('Issued');

        Test.startTest();
        VoucherResDTO dto = new VoucherResDTO(v);
        Test.stopTest();

        System.assertNotEquals(null, dto, 'DTO가 생성되어야 함');
        System.assertEquals('02', dto.CD_STAT_COUPON, 'Issued -> 02');
        System.assertEquals('02', dto.CD_TYPE_DAY_EXP, 'FixedDate -> 02');
        System.assertEquals('01', dto.CD_TYPE_COUPON, '쿠폰 유형 코드');
        System.assertEquals('Marketing', dto.NM_DEPT, '담당부서');
        System.assertEquals('TestUser', dto.ID_INSERT, '등록자');
        System.assertNotEquals(null, dto.DT_STR_EXP, '시작일자 세팅');
        System.assertNotEquals(null, dto.DT_END_EXP, '종료일자 세팅');
        System.assertNotEquals(null, dto.DT_ISSUE, '발급일자 세팅');
        System.assertNotEquals(null, dto.DTS_INSERT, '등록일자 세팅');
    }

    // =========================================================
    // 2) 생성자 - null 필드 → 기본값 처리
    // =========================================================
    @IsTest
    static void test_constructor_null_fields_use_defaults() {
        Voucher v = makeVoucher('Issued');

        Test.startTest();
        VoucherResDTO dto = new VoucherResDTO(v);
        Test.stopTest();

        // FaceValue, DiscountPercent, ExpirationPeriod null → 0
        System.assertEquals(0, dto.AM_DISC, 'FaceValue null -> 0');
        System.assertEquals(0, dto.RT_DISC, 'DiscountPercent null -> 0');
        System.assertEquals(0, dto.DS_MON_EXP, 'ExpirationPeriod null -> 0');

        // UseDate null → ''
        System.assertEquals('', dto.DT_USE, 'UseDate null -> 빈문자열');
        // Reason null → ''
        System.assertEquals('', dto.TX_COUPON, 'Reason null -> 빈문자열');
    }

    // =========================================================
    // 3) mapVoucherStatusToCode - 모든 분기
    // =========================================================
    @IsTest
    static void test_mapVoucherStatusToCode_all_branches() {
        System.assertEquals('01', VoucherResDTO.mapVoucherStatusToCode('Redeemed'), 'Redeemed -> 01');
        System.assertEquals('02', VoucherResDTO.mapVoucherStatusToCode('Issued'), 'Issued -> 02');
        System.assertEquals('03', VoucherResDTO.mapVoucherStatusToCode('Canceled'), 'Canceled -> 03');
        System.assertEquals('04', VoucherResDTO.mapVoucherStatusToCode('Expired'), 'Expired -> 04');
        System.assertEquals(null, VoucherResDTO.mapVoucherStatusToCode('Unknown'), '미정의 -> null');
    }

    // =========================================================
    // 4) mapVoucherStatusToCode - blank/null → null
    // =========================================================
    @IsTest
    static void test_mapVoucherStatusToCode_blank_returns_null() {
        System.assertEquals(null, VoucherResDTO.mapVoucherStatusToCode(null), 'null -> null');
        System.assertEquals(null, VoucherResDTO.mapVoucherStatusToCode(''), '빈문자열 -> null');
        System.assertEquals(null, VoucherResDTO.mapVoucherStatusToCode('   '), '공백 -> null');
    }

    // =========================================================
    // 5) mapVoucherDefinitionExpirationTypeToCode - 모든 분기
    // =========================================================
    @IsTest
    static void test_mapExpirationTypeToCode_all_branches() {
        System.assertEquals('01', VoucherResDTO.mapVoucherDefinitionExpirationTypeToCode('Period'), 'Period -> 01');
        System.assertEquals('02', VoucherResDTO.mapVoucherDefinitionExpirationTypeToCode('FixedDate'), 'FixedDate -> 02');
        System.assertEquals(null, VoucherResDTO.mapVoucherDefinitionExpirationTypeToCode('Other'), '미정의 -> null');
    }

    // =========================================================
    // 6) mapVoucherDefinitionExpirationTypeToCode - blank/null → null
    // =========================================================
    @IsTest
    static void test_mapExpirationTypeToCode_blank_returns_null() {
        System.assertEquals(null, VoucherResDTO.mapVoucherDefinitionExpirationTypeToCode(null), 'null -> null');
        System.assertEquals(null, VoucherResDTO.mapVoucherDefinitionExpirationTypeToCode(''), '빈문자열 -> null');
        System.assertEquals(null, VoucherResDTO.mapVoucherDefinitionExpirationTypeToCode('   '), '공백 -> null');
    }

    // =========================================================
    // 7) 날짜 포맷 검증 - 하이픈 제거 (yyyyMMdd)
    // =========================================================
    @IsTest
    static void test_date_fields_formatted_without_hyphen() {
        Voucher v = makeVoucher('Issued');

        VoucherResDTO dto = new VoucherResDTO(v);

        // DT_STR_EXP, DT_END_EXP 는 하이픈이 없어야 함
        System.assert(!dto.DT_STR_EXP.contains('-'), 'DT_STR_EXP 하이픈 없음');
        System.assert(!dto.DT_END_EXP.contains('-'), 'DT_END_EXP 하이픈 없음');
        System.assertEquals(8, dto.DT_STR_EXP.length(), 'DT_STR_EXP 8자리');
        System.assertEquals(8, dto.DT_END_EXP.length(), 'DT_END_EXP 8자리');

        // DT_ISSUE 는 yyyyMMdd (8자리)
        System.assertEquals(8, dto.DT_ISSUE.length(), 'DT_ISSUE 8자리');
        // DTS_INSERT 는 yyyyMMddHHmmss (14자리)
        System.assertEquals(14, dto.DTS_INSERT.length(), 'DTS_INSERT 14자리');
    }
}