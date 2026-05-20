@IsTest
private class CouponLimitControllerV1Test {
    /* =====================================================
     * 공통 Test Data
     * ===================================================== */
    private static String pickNonProductServiceType() {
        for (Schema.PicklistEntry entry : VoucherDefinition.Type.getDescribe().getPicklistValues()) {
            if (entry.getValue() == 'FixedValue') {
                return entry.getValue();
            }
        }
        for (Schema.PicklistEntry entry : VoucherDefinition.Type.getDescribe().getPicklistValues()) {
            if (entry.getValue() != 'ProductOrService' && entry.getValue() != '제품 또는 서비스') {
                return entry.getValue();
            }
        }
        return VoucherDefinition.Type.getDescribe().getPicklistValues()[0].getValue();
    }

    private static VoucherDefinition createVoucherDefinition() {
        LoyaltyProgram lp = new LoyaltyProgram(
            Name = 'Test Voucher Program ' + String.valueOf(Datetime.now().getTime()),
            IsPrimary = true,
            Status = 'Active'
        );
        insert lp;

        Account acc = new Account(
            Name = 'Test Voucher Store ' + String.valueOf(Datetime.now().getTime()),
            CompanyCode__c = '1000'
        );
        insert acc;

        String typeValue = pickNonProductServiceType();
        String expirationTypeValue = VoucherDefinition.ExpirationType.getDescribe()
                .getPicklistValues()[0]
            .getValue();

        VoucherDefinition vd = new VoucherDefinition(
            Name = 'Test Voucher Definition',
            LoyaltyProgramId = lp.Id,
            IsActive = true,
            Type = typeValue,
            ExpirationType = expirationTypeValue,
            EffectiveDate = Date.today(),
            ExpirationDate = Date.today().addDays(365),
            FaceValue = 1000,
            AccountId__c = acc.Id,
            CouponTypeCode__c = '01',
            ResponsibleDepartment__c = 'TEST-DEPT',
            InsertId__c = 'TEST-INSERT-001',
            ResponsiblePerson__c = UserInfo.getUserId()
        );
        insert vd;
        return vd;
    }

    /* ================= 정상 케이스 ================= */
    @IsTest
    static void test_getCouponLimit_success() {
        VoucherDefinition vd = createVoucherDefinition();

        VoucherLimit__c vl = new VoucherLimit__c(
            VoucherDefinitionId__c = vd.Id,
            Type__c = 'OrderTypeIncludeList',
            IsActive__c = true
        );
        insert vl;

        Test.startTest();
        CouponLimitControllerV1.CouponLimitDTO dto = CouponLimitControllerV1.getCouponLimit(vl.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals('OrderTypeIncludeList', dto.type);
        System.assert(true);
    }

    /* ================= Inactive 케이스 ================= */
    @IsTest
    static void test_getCouponLimit_inactive() {
        VoucherDefinition vd = createVoucherDefinition();

        VoucherLimit__c vl = new VoucherLimit__c(
            VoucherDefinitionId__c = vd.Id,
            Type__c = 'OrderTypeIncludeList',
            IsActive__c = false
        );
        insert vl;

        Test.startTest();
        CouponLimitControllerV1.CouponLimitDTO dto = CouponLimitControllerV1.getCouponLimit(vl.Id);
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals('NONE', dto.type);
        System.assert(true);
    }

    /* ================= Not Found 케이스 ================= */
    @IsTest
    static void test_getCouponLimit_notFound() {
        Test.startTest();
        CouponLimitControllerV1.CouponLimitDTO dto = CouponLimitControllerV1.getCouponLimit(
            Id.valueOf('a00000000000000AAA')
        );
        Test.stopTest();

        System.assertNotEquals(null, dto);
        System.assertEquals('NONE', dto.type);
        System.assert(true);
    }

    /* ================= null Id 케이스 ================= */
    @IsTest
    static void test_getCouponLimit_nullId() {
        Test.startTest();
        CouponLimitControllerV1.CouponLimitDTO dto = CouponLimitControllerV1.getCouponLimit(null);
        Test.stopTest();

        System.assertEquals(null, dto);
        System.assert(true);
    }
}