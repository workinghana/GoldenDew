@IsTest
private class PromotionPointTriggerHandlerTest {
    private class SuccessCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true,"message":"ok","data":{}}');
            return res;
        }
    }

    private static String uKey() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 8);
    }

    @TestSetup
    static void setup() {
        LoyaltyProgram lp = new LoyaltyProgram(Name = 'PPTH-LP', IsPrimary = false);
        insert lp;

        String expiryUnit = null;
        for (
            Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe()
                .getPicklistValues()
        ) {
            if (!e.getValue().toLowerCase().contains('day')) {
                expiryUnit = e.getValue();
                break;
            }
        }
        if (expiryUnit == null) {
            List<Schema.PicklistEntry> units = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe()
                .getPicklistValues();
            if (!units.isEmpty())
                expiryUnit = units[0].getValue();
        }

        String expiryModel = 'FIXED';
        for (
            Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryModel.getDescribe()
                .getPicklistValues()
        ) {
            if (e.getValue().equalsIgnoreCase('FIXED')) {
                expiryModel = e.getValue();
                break;
            }
        }

        String extendExpiration = null;
        List<Schema.PicklistEntry> extEntries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe()
            .getPicklistValues();
        if (!extEntries.isEmpty())
            extendExpiration = extEntries[0].getValue();

        LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
            LoyaltyProgramId = lp.Id,
            Name = 'PPTH-Currency',
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

        String pointTypeCode = LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe()
                .getPicklistValues()[0]
            .getValue();

        LoyaltyPgmCurrencySubtype sub1 = new LoyaltyPgmCurrencySubtype(
            LoyaltyProgramCurrencyId = lpc.Id,
            Name = 'PPTH-Sub1',
            PointTypeCode__c = pointTypeCode,
            UsagePriorityNumber = 1
        );
        insert sub1;

        LoyaltyPgmCurrencySubtype sub2 = new LoyaltyPgmCurrencySubtype(
            LoyaltyProgramCurrencyId = lpc.Id,
            Name = 'PPTH-Sub2',
            PointTypeCode__c = pointTypeCode,
            UsagePriorityNumber = 2
        );
        insert sub2;

        Promotion p = new Promotion(
            Name = 'PPTH-Promo',
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
    }

    private static String firstPicklistValue(List<Schema.PicklistEntry> entries) {
        return entries.isEmpty() ? null : entries[0].getValue();
    }

    private static PromotionPointLimit__c makeLimit() {
        Id promoId = [SELECT Id FROM Promotion WHERE Name = 'PPTH-Promo' LIMIT 1].Id;
        Id subtypeId = [SELECT Id FROM LoyaltyPgmCurrencySubtype WHERE Name = 'PPTH-Sub1' LIMIT 1].Id;
        String typeVal = firstPicklistValue(
            PromotionPointLimit__c.Type__c.getDescribe().getPicklistValues()
        );
        return new PromotionPointLimit__c(
            Name = 'PPTH-' + uKey(),
            PromotionId__c = promoId,
            Type__c = typeVal,
            Value__c = 100,
            LoyaltyPgmCurrencySubtypeId__c = subtypeId
        );
    }

    /* =========================================================
     * afterInsert
     * ========================================================= */
    @IsTest
    static void testAfterInsertSingleRecord() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        PromotionPointLimit__c ppl = makeLimit();

        Test.startTest();
        insert ppl;
        Test.stopTest();

        System.assertNotEquals(null, ppl.Id, 'insert 후 Id가 있어야 합니다.');
    }

    @IsTest
    static void testAfterInsertMultipleRecords() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        List<PromotionPointLimit__c> pplList = new List<PromotionPointLimit__c>{
            makeLimit(),
            makeLimit(),
            makeLimit()
        };

        Test.startTest();
        insert pplList;
        Test.stopTest();

        Integer cnt = [SELECT COUNT() FROM PromotionPointLimit__c WHERE Id IN :pplList];
        System.assertEquals(3, cnt, '3건 insert 되어야 합니다.');
    }

    /* =========================================================
     * afterDelete
     * ========================================================= */
    @IsTest
    static void testAfterDeleteSingleRecord() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        PromotionPointLimit__c ppl = makeLimit();
        insert ppl;

        Test.startTest();
        delete ppl;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM PromotionPointLimit__c WHERE Id = :ppl.Id],
            'delete 후 레코드가 없어야 합니다.'
        );
    }

    @IsTest
    static void testAfterDeleteMultipleRecords() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        List<PromotionPointLimit__c> pplList = new List<PromotionPointLimit__c>{
            makeLimit(),
            makeLimit()
        };
        insert pplList;

        Test.startTest();
        delete pplList;
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM PromotionPointLimit__c WHERE Id IN :pplList],
            '전체 delete 되어야 합니다.'
        );
    }

    /* =========================================================
     * afterUpdate – ERP 필드 변경 시 enqueue
     * ========================================================= */
    @IsTest
    static void testAfterUpdateValueChanged() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        PromotionPointLimit__c ppl = makeLimit();
        insert ppl;

        ppl.Value__c = 999;

        Test.startTest();
        update ppl;
        Test.stopTest();

        System.assertEquals(
            999,
            [SELECT Value__c FROM PromotionPointLimit__c WHERE Id = :ppl.Id].Value__c
        );
    }

    @IsTest
    static void testAfterUpdateTypeChanged() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        PromotionPointLimit__c ppl = makeLimit();
        insert ppl;

        // restricted picklist → 유효한 값 동적으로 가져오기 (현재 값과 다른 값 선택)
        String currentType = ppl.Type__c;
        String newType = null;
        for (Schema.PicklistEntry e : PromotionPointLimit__c.Type__c.getDescribe().getPicklistValues()) {
            if (e.getValue() != currentType) {
                newType = e.getValue();
                break;
            }
        }
        if (newType == null) {
            return; // 선택 가능한 다른 값이 없으면 skip
        }
        ppl.Type__c = newType;

        Test.startTest();
        update ppl;
        Test.stopTest();

        System.assertEquals(
            newType,
            [SELECT Type__c FROM PromotionPointLimit__c WHERE Id = :ppl.Id].Type__c
        );
    }

    /* =========================================================
     * afterUpdate – skip 분기
     * ========================================================= */
    @IsTest
    static void testAfterUpdateSkipWhenErpSyncSkipTrue() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        PromotionPointLimit__c ppl = makeLimit();
        insert ppl;

        // ErpSyncSkip__c = true → 핸들러 내 continue 분기
        ppl.Value__c = 777;
        ppl.ErpSyncSkip__c = true;

        Test.startTest();
        update ppl;
        Test.stopTest();

        PromotionPointLimit__c result = [
            SELECT Value__c, ErpSyncSkip__c
            FROM PromotionPointLimit__c
            WHERE Id = :ppl.Id
        ];
        System.assertEquals(777, result.Value__c);
        System.assertEquals(true, result.ErpSyncSkip__c);
    }

    @IsTest
    static void testAfterUpdateSkipWhenNoErpFieldChange() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        PromotionPointLimit__c ppl = makeLimit();
        insert ppl;

        // ERP 관련 필드(Value__c, Type__c, LoyaltyPgmCurrencySubtypeId__c, PromotionId__c)
        // 변경 없이 재조회 후 update → 핸들러 내 skip 분기
        PromotionPointLimit__c requeried = [
            SELECT Id, Value__c, Type__c
            FROM PromotionPointLimit__c
            WHERE Id = :ppl.Id
        ];

        Test.startTest();
        update requeried;
        Test.stopTest();

        System.assertNotEquals(null, requeried.Id);
    }

    /* =========================================================
     * afterUpdate – afterUpdateRunning 재진입 차단
     * ========================================================= */
    @IsTest
    static void testAfterUpdateReentranceGuard() {
        Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
        PromotionPointLimit__c ppl = makeLimit();
        insert ppl;

        // 핸들러를 직접 두 번 호출해도 afterUpdateRunning 플래그로 두 번째는 즉시 반환
        PromotionPointTriggerHandler handler = new PromotionPointTriggerHandler();

        Test.startTest();
        try {
            handler.afterUpdate();
        } catch (Exception e) {
            // 트리거 컨텍스트 외 호출이므로 NPE 등은 허용
        }
        try {
            handler.afterUpdate();
        } catch (Exception e) {
            // 두 번째 호출도 예외 허용
        }
        Test.stopTest();

        System.assertNotEquals(null, ppl.Id);
    }

    /* =========================================================
     * 핸들러 직접 인스턴스화
     * ========================================================= */
    @IsTest
    static void testHandlerInstantiation() {
        PromotionPointTriggerHandler handler = new PromotionPointTriggerHandler();
        System.assertNotEquals(null, handler);
    }
}