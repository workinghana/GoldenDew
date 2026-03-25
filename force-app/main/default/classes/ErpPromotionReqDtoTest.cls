@IsTest
private class ErpPromotionReqDtoTest {
    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
    }

    private static Promotion createPromotionRecord() {
        String statusCode = null;
        for (Schema.PicklistEntry e : Promotion.StatusCode__c.getDescribe().getPicklistValues()) {
            statusCode = e.getValue();
            break;
        }

        String typeCode = null;
        for (Schema.PicklistEntry e : Promotion.TypeCode__c.getDescribe().getPicklistValues()) {
            typeCode = e.getValue();
            break;
        }

        String brandCode = null;
        for (Schema.PicklistEntry e : Promotion.BrandCode__c.getDescribe().getPicklistValues()) {
            brandCode = e.getValue();
            break;
        }

        Promotion p = new Promotion(
            Name = uniq('Promo'),
            PromotionCode = uniq('PCODE'),
            BrandCode__c = brandCode,
            TypeCode__c = typeCode,
            StartDate = Date.today(),
            EndDate = Date.today().addDays(7),
            PublishStartDate__c = Date.today(),
            PublishEndDate__c = Date.today().addDays(3),
            StatusCode__c = statusCode,
            IsCouponAllowed__c = true,
            IsFixedAmountCouponAllowed__c = true,
            IsRateCouponAllowed__c = true,
            IsSpecificCouponAllowed__c = false,
            IsPointUsageAllowed__c = true,
            IsAllStore__c = true,
            IsAllItem__c = false,
            DepartmentCode__c = 'D001',
            InsertId__c = 'Inserter',
            ResponId__c = 'Responder'
        );
        insert p;

        return [
            SELECT
                Id,
                Name,
                PromotionNo__c,
                PromotionCode,
                BrandCode__c,
                TypeCode__c,
                StartDate,
                EndDate,
                PublishStartDate__c,
                PublishEndDate__c,
                StatusCode__c,
                IsCouponAllowed__c,
                IsFixedAmountCouponAllowed__c,
                IsRateCouponAllowed__c,
                IsSpecificCouponAllowed__c,
                IsPointUsageAllowed__c,
                IsAllStore__c,
                IsAllItem__c,
                DepartmentCode__c,
                InsertId__c,
                ResponId__c,
                CreatedBy.Name,
                LastModifiedBy.Name
            FROM Promotion
            WHERE Id = :p.Id
            LIMIT 1
        ];
    }

    @IsTest
    static void test_outer_constructor() {
        ErpPromotionReqDto dto = new ErpPromotionReqDto();
        System.assertNotEquals(null, dto);
    }

    @IsTest
    static void test_createRequest_default_assignment() {
        ErpPromotionReqDto.CreateRequest req = new ErpPromotionReqDto.CreateRequest();
        req.no_prom = 'P001';
        req.nm_prom = '프로모션';
        req.id_insert = 'tester';

        System.assertEquals('P001', req.no_prom);
        System.assertEquals('프로모션', req.nm_prom);
        System.assertEquals('tester', req.id_insert);
    }

    @IsTest
    static void test_createRequest_fromPromotion() {
        Promotion p = createPromotionRecord();

        ErpPromotionReqDto.CreateRequest req = new ErpPromotionReqDto.CreateRequest(p);

        System.assertEquals(p.PromotionNo__c, req.no_prom);
        System.assertEquals(p.Name, req.nm_prom);
        System.assertEquals(p.BrandCode__c, req.cd_brand);
        System.assertEquals(p.TypeCode__c, req.cd_type_prom);
        System.assertEquals('Y', req.yn_use_coupon);
        System.assertEquals('Y', req.yn_use_fixed_coupon);
        System.assertEquals('Y', req.yn_use_rate_coupon);
        System.assertEquals('N', req.yn_use_specific_coupon);
        System.assertEquals('Y', req.yn_use_point);
        System.assertEquals('Y', req.yn_all_store);
        System.assertEquals('N', req.yn_all_item);
        System.assertEquals('Y', req.yn_all_coupon);
        System.assertEquals(p.DepartmentCode__c, req.cd_dept);
        System.assertEquals(p.InsertId__c, req.id_insert);
        System.assertEquals(p.LastModifiedBy.Name, req.id_update);
        System.assertEquals(p.ResponId__c, req.id_respon);
    }

    @IsTest
    static void test_deleteRequest_fromPromotion() {
        Promotion p = createPromotionRecord();

        ErpPromotionReqDto.DeleteRequest req = new ErpPromotionReqDto.DeleteRequest(p);

        System.assertEquals(p.PromotionCode, req.no_prom);
        System.assertEquals(UserInfo.getUserId(), req.id_delete);
    }

    @IsTest
    static void test_updateRequest_default_assignment() {
        ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest();
        req.no_prom = 'P002';
        req.id_update = 'updater';

        System.assertEquals('P002', req.no_prom);
        System.assertEquals('updater', req.id_update);
    }

    @IsTest
    static void test_updateRequest_fromPromotion() {
        Promotion p = createPromotionRecord();

        ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest(p);

        System.assertEquals(p.PromotionNo__c, req.no_prom);
        System.assertEquals(p.Name, req.nm_prom);
        System.assertEquals(p.BrandCode__c, req.cd_brand);
        System.assertEquals(p.TypeCode__c, req.cd_type_prom);
        System.assertEquals('Y', req.yn_use_coupon);
        System.assertEquals('Y', req.yn_use_fixed_coupon);
        System.assertEquals('Y', req.yn_use_rate_coupon);
        System.assertEquals('N', req.yn_use_specific_coupon);
        System.assertEquals('Y', req.yn_use_point);
        System.assertEquals('Y', req.yn_all_store);
        System.assertEquals('N', req.yn_all_item);
        System.assertEquals('Y', req.yn_all_coupon);
        System.assertEquals(p.CreatedBy.Name, req.id_insert);
        System.assertEquals(p.LastModifiedBy.Name, req.id_update);
    }

    @IsTest
    static void test_helpers() {
        System.assertEquals('', ErpPromotionReqDto.dateToYmd(null));
        System.assertEquals('20260309', ErpPromotionReqDto.dateToYmd(Date.newInstance(2026, 3, 9)));

        System.assertEquals('', ErpPromotionReqDto.dtToYmd(null));
        Datetime dt = Datetime.newInstance(2026, 3, 9, 10, 20, 30);
        System.assertEquals('20260309', ErpPromotionReqDto.dtToYmd(dt));

        System.assertEquals('Y', ErpPromotionReqDto.boolToYn(true));
        System.assertEquals('N', ErpPromotionReqDto.boolToYn(false));
        System.assertEquals('N', ErpPromotionReqDto.boolToYn(null));

        System.assertEquals('', ErpPromotionReqDto.isStrNull(null));
        System.assertEquals('', ErpPromotionReqDto.isStrNull(''));
        System.assertEquals('', ErpPromotionReqDto.isStrNull('   '));
        System.assertEquals('A', ErpPromotionReqDto.isStrNull('A'));

        System.assertEquals('Y', ErpPromotionReqDto.isAllCoupon('Y', 'Y', 'Y'));
        System.assertEquals('N', ErpPromotionReqDto.isAllCoupon('Y', 'N', 'Y'));
    }
}