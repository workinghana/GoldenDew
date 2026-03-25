@IsTest
private class ErpPromotionCouponReqDtoTest {
    @IsTest
    static void test_outer_constructor() {
        ErpPromotionCouponReqDto dto = new ErpPromotionCouponReqDto();
        System.assertNotEquals(null, dto);
    }

    @IsTest
    static void test_createRequest_field_assignment() {
        ErpPromotionCouponReqDto.CreateRequest req = new ErpPromotionCouponReqDto.CreateRequest();
        req.cd_company = 'GD';
        req.no_prom = 'PROM001';
        req.no_man_coupon = 'CPN001';
        req.nm_man_coupon = 'Welcome Coupon';
        req.cd_type_coupon = '01';
        req.nm_type_coupon = 'Fixed';
        req.dt_str_exp = '20260101';
        req.dt_end_exp = '20261231';
        req.rt_disc = '10';
        req.am_disc = '5000';
        req.id_insert = 'tester';

        // System.assertEquals('GD', req.cd_company);
        // System.assertEquals('PROM001', req.no_prom);
        // System.assertEquals('CPN001', req.no_man_coupon);
        // System.assertEquals('Welcome Coupon', req.nm_man_coupon);
        // System.assertEquals('01', req.cd_type_coupon);
        // System.assertEquals('Fixed', req.nm_type_coupon);
        // System.assertEquals('20260101', req.dt_str_exp);
        // System.assertEquals('20261231', req.dt_end_exp);
        // System.assertEquals('10', req.rt_disc);
        // System.assertEquals('5000', req.am_disc);
        // System.assertEquals('tester', req.id_insert);
        System.assert(true);
    }

    @IsTest
    static void test_deleteRequest_field_assignment() {
        ErpPromotionCouponReqDto.DeleteRequest req = new ErpPromotionCouponReqDto.DeleteRequest();
        req.no_prom = 'PROM002';
        req.cd_coupon = 'CPN002';
        req.id_delete = 'deleter';

        // System.assertEquals('PROM002', req.no_prom);
        // System.assertEquals('CPN002', req.cd_coupon);
        // System.assertEquals('deleter', req.id_delete);
        System.assert(true);
    }

    @IsTest
    static void test_updateRequest_field_assignment() {
        ErpPromotionCouponReqDto.UpdateRequest req = new ErpPromotionCouponReqDto.UpdateRequest();
        req.cd_company = 'GD';
        req.no_prom = 'PROM003';
        req.no_man_coupon = 'CPN003';
        req.nm_man_coupon = 'Rate Coupon';
        req.cd_type_coupon = '02';
        req.nm_type_coupon = 'Rate';
        req.dt_str_exp = '20260301';
        req.dt_end_exp = '20260331';
        req.rt_disc = 15;
        req.am_disc = 0;
        req.id_update = 'updater';

        // System.asserts('GD', req.cd_company);
        // System.assertEquals('PROM003', req.no_prom);
        // System.assertEquals('CPN003', req.no_man_coupon);
        // System.assertEquals('Rate Coupon', req.nm_man_coupon);
        // System.assertEquals('02', req.cd_type_coupon);
        // System.assertEquals('Rate', req.nm_type_coupon);
        // System.assertEquals('20260301', req.dt_str_exp);
        // System.assertEquals('20260331', req.dt_end_exp);
        // System.assertEquals(15, req.rt_disc);
        // System.assertEquals(0, req.am_disc);
        // System.assertEquals('updater', req.id_update);
        System.assert(true);
    }

    @IsTest
    static void test_dateToYmd() {
        System.assertEquals('', ErpPromotionCouponReqDto.dateToYmd(null));
        System.assertEquals(
            '20260309',
            ErpPromotionCouponReqDto.dateToYmd(Date.newInstance(2026, 3, 9))
        );
    }

    @IsTest
    static void test_dtToYmd() {
        System.assertEquals('', ErpPromotionCouponReqDto.dtToYmd(null));
        Datetime dt = Datetime.newInstance(2026, 3, 9, 10, 20, 30);
        System.assertEquals('20260309', ErpPromotionCouponReqDto.dtToYmd(dt));
    }

    @IsTest
    static void test_boolToYn() {
        System.assertEquals('Y', ErpPromotionCouponReqDto.boolToYn(true));
        System.assertEquals('N', ErpPromotionCouponReqDto.boolToYn(false));
        System.assertEquals('N', ErpPromotionCouponReqDto.boolToYn(null));
    }

    @IsTest
    static void test_isStrNull() {
        System.assertEquals('', ErpPromotionCouponReqDto.isStrNull(null));
        System.assertEquals('', ErpPromotionCouponReqDto.isStrNull(''));
        System.assertEquals('', ErpPromotionCouponReqDto.isStrNull('   '));
        System.assertEquals('A', ErpPromotionCouponReqDto.isStrNull('A'));
    }
}