@IsTest
private class ErpPromotionStoreAsyncCallbackTest {
    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
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

    private static Account createAccount() {
        Account a = new Account(Name = uniq('Store'));
        insert a;
        return a;
    }

    private static PromotionAccount__c createPromotionAccount(Id promotionId, Id accountId) {
        PromotionAccount__c pa = new PromotionAccount__c(
            PromotionId__c = promotionId,
            AccountId__c = accountId
        );
        insert pa;
        return pa;
    }

    @IsTest
    static void test_onFailure_deletePromotionStore_restoresDeletedRecord() {
        Promotion p = createPromotionRecord();
        Account a = createAccount();
        PromotionAccount__c pa = createPromotionAccount(p.Id, a.Id);
        delete pa;

        ErpPromotionStoreAsyncCallback cb = new ErpPromotionStoreAsyncCallback();
        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_DELETE_PROMOTION_STORE,
            null,
            (HttpErrorException) null,
            pa.Id
        );

        List<PromotionAccount__c> restored = [
            SELECT Id
            FROM PromotionAccount__c
            WHERE Id = :pa.Id
        ];
        System.assertEquals(1, restored.size());
    }

    @IsTest
    static void test_onFailure_deletePromotionStore_nullRecordId_noThrow() {
        ErpPromotionStoreAsyncCallback cb = new ErpPromotionStoreAsyncCallback();
        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_DELETE_PROMOTION_STORE,
            null,
            (HttpErrorException) null,
            (Id) null
        );
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_deletePromotionStore_nonDeletedRecord_noRestorePath() {
        Promotion p = createPromotionRecord();
        Account a = createAccount();
        PromotionAccount__c pa = createPromotionAccount(p.Id, a.Id);

        ErpPromotionStoreAsyncCallback cb = new ErpPromotionStoreAsyncCallback();
        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_DELETE_PROMOTION_STORE,
            null,
            (HttpErrorException) null,
            pa.Id
        );

        PromotionAccount__c remained = [
            SELECT Id
            FROM PromotionAccount__c
            WHERE Id = :pa.Id
            LIMIT 1
        ];
        System.assertEquals(pa.Id, remained.Id);
    }

    @IsTest
    static void test_noop_overloads_and_success() {
        ErpPromotionStoreAsyncCallback cb = new ErpPromotionStoreAsyncCallback();
        ErpApiResponseDto res = new ErpApiResponseDto();

        cb.onSuccess(ErpPromotionStoreAsyncCallback.API_CREATE_PROMOTION_STORE, null, res);

        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_CREATE_PROMOTION_STORE,
            null,
            'err',
            'stack'
        );

        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_CREATE_PROMOTION_STORE,
            null,
            'err',
            (Id) null
        );

        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_UPDATE_PROMOTION_STORE,
            null,
            (HttpErrorException) null,
            (Id) null,
            null
        );

        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_CREATE_PROMOTION_STORE,
            null,
            (HttpErrorException) null,
            new Set<Id>()
        );

        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_CREATE_PROMOTION_STORE,
            null,
            (Exception) null,
            new Set<Id>()
        );

        cb.onFailure(
            ErpPromotionStoreAsyncCallback.API_CREATE_PROMOTION_STORE,
            null,
            (Exception) null,
            (Id) null
        );

        System.assert(true);
    }

    // =========================================================
    // extractMessage 테스트
    // =========================================================

    // 1) blank/null 입력 -> null
    @IsTest
    static void test_extractMessage_blank_returns_null() {
        System.assertEquals(null, ErpPromotionStoreAsyncCallback.extractMessage(null), 'null -> null');
        System.assertEquals(null, ErpPromotionStoreAsyncCallback.extractMessage(''), '빈문자열 -> null');
        System.assertEquals(null, ErpPromotionStoreAsyncCallback.extractMessage('   '), '공백 -> null');
    }

    // 2) 유효한 JSON + message 필드 있음 -> message 값 반환
    @IsTest
    static void test_extractMessage_valid_json_with_message() {
        String body = '{"success":true,"message":"처리 성공","data":null}';
        String result = ErpPromotionStoreAsyncCallback.extractMessage(body);
        System.assertEquals('처리 성공', result, 'message 필드 값 반환');
    }

    // 3) 유효한 JSON + message 필드 없음 -> 원문 반환
    @IsTest
    static void test_extractMessage_valid_json_without_message_field() {
        String body = '{"success":true,"data":null}';
        String result = ErpPromotionStoreAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'message 필드 없으면 원문 반환');
    }

    // 4) 유효한 JSON + message = null -> 원문 반환
    @IsTest
    static void test_extractMessage_valid_json_message_is_null() {
        String body = '{"success":false,"message":null}';
        String result = ErpPromotionStoreAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'message=null이면 원문 반환');
    }

    // 5) 유효하지 않은 JSON -> 원문 반환 (catch 분기)
    @IsTest
    static void test_extractMessage_invalid_json_returns_raw() {
        String body = 'NOT_JSON_STRING';
        String result = ErpPromotionStoreAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, '파싱 실패 시 원문 반환');
    }

    // 6) JSON 배열 -> 원문 반환 (Map 아님 분기)
    @IsTest
    static void test_extractMessage_json_array_returns_raw() {
        String body = '[{"message":"item"}]';
        String result = ErpPromotionStoreAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'JSON 배열이면 원문 반환');
    }
}