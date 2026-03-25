@IsTest
private class ErpPromotionPointReqDtoTest {
    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
    }

    @TestSetup
    static void setup() {
        LoyaltyProgram lp = new LoyaltyProgram(Name = 'TestLP_ErpPromoPointReqDto', IsPrimary = false);
        insert lp;

        String expiryUnit = null;
        for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues()) {
            if (!e.getValue().toLowerCase().contains('day')) { expiryUnit = e.getValue(); break; }
        }
        if (expiryUnit == null) {
            List<Schema.PicklistEntry> units = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();
            if (!units.isEmpty()) expiryUnit = units[0].getValue();
        }

        String expiryModel = 'FIXED';
        for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
            if (e.getValue().equalsIgnoreCase('FIXED')) { expiryModel = e.getValue(); break; }
        }

        String extendExpiration = null;
        List<Schema.PicklistEntry> extEntries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
        if (!extEntries.isEmpty()) extendExpiration = extEntries[0].getValue();

        LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
            LoyaltyProgramId = lp.Id,
            Name = 'TestCurrency_ErpPromoPointReqDto',
            CurrencyType = 'NonQualifying',
            IsActive = true,
            IsPrimary = true,
            ExpiryPeriodFrequency = 12,
            ExpiryPeriodUnit = expiryUnit,
            ExpiryModel = expiryModel,
            ExtendExpiration = extendExpiration,
            CostperUnit = 1,
            HasEscrow = false,
            DoesAllowLedgerTracing = true
        );
        insert lpc;

        String pointTypeCode = 'NORMAL';
        List<Schema.PicklistEntry> ptEntries = LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues();
        if (!ptEntries.isEmpty()) pointTypeCode = ptEntries[0].getValue();

        LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
            LoyaltyProgramCurrencyId = lpc.Id,
            Name = 'TestSubtype_ErpPromoPointReqDto',
            PointTypeCode__c = pointTypeCode,
            UsagePriorityNumber = 1
        );
        insert subtype;
    }

    private static Promotion createPromotionRecord() {
        Promotion p = new Promotion(
            Name = uniq('Promo'),
            StartDate = Date.today(),
            EndDate = Date.today().addDays(7),
            PublishStartDate__c = Date.today(),
            PublishEndDate__c = Date.today().addDays(3),
            IsCouponAllowed__c = true,
            IsFixedAmountCouponAllowed__c = false,
            IsRateCouponAllowed__c = true,
            IsSpecificCouponAllowed__c = false,
            IsPointUsageAllowed__c = false,
            IsAllStore__c = false,
            IsAllItem__c = false
        );
        insert p;
        return p;
    }

    private static PromotionPointLimit__c createPointLimit(Id promotionId, Decimal value) {
        LoyaltyPgmCurrencySubtype subtype = [SELECT Id FROM LoyaltyPgmCurrencySubtype WHERE Name = 'TestSubtype_ErpPromoPointReqDto' LIMIT 1];
        PromotionPointLimit__c ppl = new PromotionPointLimit__c(
            Name = uniq('PPL'),
            PromotionId__c = promotionId,
            Type__c = 'none',
            Value__c = value,
            LoyaltyPgmCurrencySubtypeId__c = subtype.Id
        );
        insert ppl;
        return ppl;
    }

    @IsTest
    static void test_outer_constructor() {
        ErpPromotionPointReqDto dto = new ErpPromotionPointReqDto();
        System.assertNotEquals(null, dto);
    }

    @IsTest
    static void test_createRequest_default_field_assignment() {
        ErpPromotionPointReqDto.CreateRequest req = new ErpPromotionPointReqDto.CreateRequest();
        req.cd_company = '1000';
        req.no_prom = 'PROM001';
        req.no_prom_point = 'PPOINT001';
        req.nm_prom_point = '가입 포인트';
        req.cd_type_prom_point = '01';
        req.nm_type_prom_point = '기본';
        req.cd_type_point = 'A';
        req.nm_type_point = '적립';
        req.pt_save = 100;
        req.id_insert = 'tester';

        System.assertEquals('1000', req.cd_company);
        System.assertEquals('PROM001', req.no_prom);
        System.assertEquals('PPOINT001', req.no_prom_point);
        System.assertEquals('가입 포인트', req.nm_prom_point);
        System.assertEquals('01', req.cd_type_prom_point);
        System.assertEquals('기본', req.nm_type_prom_point);
        System.assertEquals('A', req.cd_type_point);
        System.assertEquals('적립', req.nm_type_point);
        System.assertEquals(100, req.pt_save);
        System.assertEquals('tester', req.id_insert);
    }

    @IsTest
    static void test_createRequest_fromPpl_withValue() {
        Promotion p = createPromotionRecord();
        PromotionPointLimit__c inserted = createPointLimit(p.Id, 250);

        PromotionPointLimit__c src = [
            SELECT Id, Name, Value__c, PromotionId__r.PromotionNo__c
            FROM PromotionPointLimit__c
            WHERE Id = :inserted.Id
            LIMIT 1
        ];

        ErpPromotionPointReqDto.CreateRequest req = new ErpPromotionPointReqDto.CreateRequest(src);

        System.assertEquals('1000', req.cd_company);
        System.assertEquals(src.PromotionId__r.PromotionNo__c, req.no_prom);
        System.assertEquals(src.Name, req.nm_prom_point);
        System.assertEquals(250, req.pt_save);
        System.assertEquals(UserInfo.getUserName(), req.id_insert);
    }

    @IsTest
    static void test_createRequest_fromPpl_nullValue() {
        Promotion p = createPromotionRecord();
        PromotionPointLimit__c inserted = createPointLimit(p.Id, null);

        PromotionPointLimit__c src = [
            SELECT Id, Name, Value__c, PromotionId__r.PromotionNo__c
            FROM PromotionPointLimit__c
            WHERE Id = :inserted.Id
            LIMIT 1
        ];

        ErpPromotionPointReqDto.CreateRequest req = new ErpPromotionPointReqDto.CreateRequest(src);

        System.assertEquals(null, req.pt_save);
        System.assertEquals(src.Name, req.nm_prom_point);
    }

    @IsTest
    static void test_updateRequest_field_assignment() {
        ErpPromotionPointReqDto.UpdateRequest req = new ErpPromotionPointReqDto.UpdateRequest();
        req.cd_company = '1000';
        req.no_prom = 'PROM002';
        req.no_prom_point = 'PPOINT002';
        req.nm_prom_point = '수정 포인트';
        req.cd_type_prom_point = '01';
        req.nm_type_prom_point = '기본';
        req.cd_type_point = 'A';
        req.nm_type_point = '적립';
        req.pt_save = 300;
        req.id_update = 'updater';

        System.assertEquals('1000', req.cd_company);
        System.assertEquals('PROM002', req.no_prom);
        System.assertEquals('PPOINT002', req.no_prom_point);
        System.assertEquals('수정 포인트', req.nm_prom_point);
        System.assertEquals('01', req.cd_type_prom_point);
        System.assertEquals('기본', req.nm_type_prom_point);
        System.assertEquals('A', req.cd_type_point);
        System.assertEquals('적립', req.nm_type_point);
        System.assertEquals(300, req.pt_save);
        System.assertEquals('updater', req.id_update);
    }

    @IsTest
    static void test_deleteRequest_default_field_assignment() {
        ErpPromotionPointReqDto.DeleteRequest req = new ErpPromotionPointReqDto.DeleteRequest();
        req.no_prom = 'PROM003';
        req.no_prom_point = 'PPOINT003';
        req.id_delete = 'deleter';

        System.assertEquals('PROM003', req.no_prom);
        System.assertEquals('PPOINT003', req.no_prom_point);
        System.assertEquals('deleter', req.id_delete);
    }

    @IsTest
    static void test_deleteRequest_fromPpl() {
        Promotion p = createPromotionRecord();
        PromotionPointLimit__c inserted = createPointLimit(p.Id, 123);

        PromotionPointLimit__c src = [
            SELECT Id, Name, PromotionId__r.PromotionNo__c
            FROM PromotionPointLimit__c
            WHERE Id = :inserted.Id
            LIMIT 1
        ];

        ErpPromotionPointReqDto.DeleteRequest req = new ErpPromotionPointReqDto.DeleteRequest(src);

        System.assertEquals(src.PromotionId__r.PromotionNo__c, req.no_prom);
        System.assertEquals(src.Name, req.no_prom_point);
        System.assertEquals(UserInfo.getUserName(), req.id_delete);
    }
}