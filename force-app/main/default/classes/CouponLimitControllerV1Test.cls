@IsTest
private class CouponLimitControllerV1Test {
    /* =====================================================
     * 공통 Test Data
     * ===================================================== */
    private static VoucherDefinition createVoucherDefinition() {
        // Type, ExpirationType: org 실제 피클리스트 첫 번째 값 동적 조회
        String typeValue = VoucherDefinition.Type.getDescribe().getPicklistValues()[0].getValue();
        String expirationTypeValue = VoucherDefinition.ExpirationType.getDescribe()
                .getPicklistValues()[0]
            .getValue();

        VoucherDefinition vd = new VoucherDefinition(
            Name = 'Test Voucher Definition',
            IsActive = true,
            Type = typeValue,
            ExpirationType = expirationTypeValue,
            EffectiveDate = Date.today(),
            ExpirationDate = Date.today().addDays(365),
            FaceValue = 1000,
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