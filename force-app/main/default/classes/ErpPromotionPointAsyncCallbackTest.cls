@IsTest
private class ErpPromotionPointAsyncCallbackTest {
    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
    }

    @TestSetup
    static void setup() {
        // LoyaltyProgram → LoyaltyProgramCurrency → LoyaltyPgmCurrencySubtype
        LoyaltyProgram lp = new LoyaltyProgram(Name = 'TestLP_ErpPromoPoint', IsPrimary = false);
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
            Name = 'TestCurrency_ErpPromoPoint',
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
            Name = 'TestSubtype_ErpPromoPoint',
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

    private static PromotionPointLimit__c createPointLimit(Id promotionId) {
        LoyaltyPgmCurrencySubtype subtype = [SELECT Id FROM LoyaltyPgmCurrencySubtype WHERE Name = 'TestSubtype_ErpPromoPoint' LIMIT 1];
        PromotionPointLimit__c ppl = new PromotionPointLimit__c(
            Name = uniq('PPL'),
            PromotionId__c = promotionId,
            Type__c = 'none',
            Value__c = 100,
            LoyaltyPgmCurrencySubtypeId__c = subtype.Id
        );
        insert ppl;
        return ppl;
    }

    @IsTest
    static void test_onFailure_deletePromotionPoint_restoresDeletedRecord() {
        Promotion p = createPromotionRecord();
        PromotionPointLimit__c ppl = createPointLimit(p.Id);
        delete ppl;

        ErpPromotionPointAsyncCallback cb = new ErpPromotionPointAsyncCallback();
        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_DELETE_PROMOTION_POINT,
            null,
            (HttpErrorException) null,
            ppl.Id
        );

        List<PromotionPointLimit__c> restored = [
            SELECT Id
            FROM PromotionPointLimit__c
            WHERE Id = :ppl.Id
        ];
        System.assertEquals(1, restored.size());
    }

    @IsTest
    static void test_onFailure_deletePromotionPoint_nullRecordId_noThrow() {
        ErpPromotionPointAsyncCallback cb = new ErpPromotionPointAsyncCallback();
        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_DELETE_PROMOTION_POINT,
            null,
            (HttpErrorException) null,
            (Id) null
        );
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_deletePromotionPoint_nonDeletedRecord_noRestorePath() {
        Promotion p = createPromotionRecord();
        PromotionPointLimit__c ppl = createPointLimit(p.Id);

        ErpPromotionPointAsyncCallback cb = new ErpPromotionPointAsyncCallback();
        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_DELETE_PROMOTION_POINT,
            null,
            (HttpErrorException) null,
            ppl.Id
        );

        PromotionPointLimit__c remained = [
            SELECT Id
            FROM PromotionPointLimit__c
            WHERE Id = :ppl.Id
            LIMIT 1
        ];
        System.assertEquals(ppl.Id, remained.Id);
    }

    @IsTest
    static void test_noop_overloads_and_success() {
        ErpPromotionPointAsyncCallback cb = new ErpPromotionPointAsyncCallback();
        ErpApiResponseDto res = new ErpApiResponseDto();

        cb.onSuccess(ErpPromotionPointAsyncCallback.API_CREATE_PROMOTION_POINT, null, res);

        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_CREATE_PROMOTION_POINT,
            null,
            'err',
            'stack'
        );

        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_CREATE_PROMOTION_POINT,
            null,
            'err',
            (Id) null
        );

        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_UPDATE_PROMOTION_POINT,
            null,
            (HttpErrorException) null,
            (Id) null,
            null
        );

        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_CREATE_PROMOTION_POINT,
            null,
            (HttpErrorException) null,
            new Set<Id>()
        );

        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_CREATE_PROMOTION_POINT,
            null,
            (Exception) null,
            new Set<Id>()
        );

        cb.onFailure(
            ErpPromotionPointAsyncCallback.API_CREATE_PROMOTION_POINT,
            null,
            (Exception) null,
            (Id) null
        );

        System.assert(true);
    }

    /* =========================================================
     * extractMessage - 전체 분기 커버
     * ========================================================= */
    @IsTest
    static void test_extractMessage_nullBody() {
        Test.startTest();
        String result = ErpPromotionPointAsyncCallback.extractMessage(null);
        Test.stopTest();
        System.assertEquals(null, result, 'null body → null 반환');
    }

    @IsTest
    static void test_extractMessage_blankBody() {
        Test.startTest();
        String result = ErpPromotionPointAsyncCallback.extractMessage('   ');
        Test.stopTest();
        System.assertEquals(null, result, 'blank body → null 반환');
    }

    @IsTest
    static void test_extractMessage_validJsonWithMessage() {
        String body = '{"success":true,"message":"처리 완료","data":null}';
        Test.startTest();
        String result = ErpPromotionPointAsyncCallback.extractMessage(body);
        Test.stopTest();
        System.assertEquals('처리 완료', result, 'message 필드 추출');
    }

    @IsTest
    static void test_extractMessage_validJsonWithoutMessage() {
        String body = '{"success":true,"data":null}';
        Test.startTest();
        String result = ErpPromotionPointAsyncCallback.extractMessage(body);
        Test.stopTest();
        System.assertEquals(body, result, 'message 키 없으면 body 그대로 반환');
    }

    @IsTest
    static void test_extractMessage_jsonArray_notMap() {
        String body = '[{"message":"item"}]';
        Test.startTest();
        String result = ErpPromotionPointAsyncCallback.extractMessage(body);
        Test.stopTest();
        System.assertEquals(body, result, 'JSON 배열이면 body 그대로 반환');
    }

    @IsTest
    static void test_extractMessage_invalidJson() {
        String body = 'not-json-{{{{';
        Test.startTest();
        String result = ErpPromotionPointAsyncCallback.extractMessage(body);
        Test.stopTest();
        System.assertEquals(body, result, '파싱 실패 시 body 그대로 반환');
    }

    @IsTest
    static void test_extractMessage_messageIsNull() {
        String body = '{"success":true,"message":null}';
        Test.startTest();
        String result = ErpPromotionPointAsyncCallback.extractMessage(body);
        Test.stopTest();
        System.assertEquals(body, result, 'message 값이 null이면 body 그대로 반환');
    }
}