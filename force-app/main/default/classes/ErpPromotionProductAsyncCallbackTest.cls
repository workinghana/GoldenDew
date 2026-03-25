@IsTest
private class ErpPromotionProductAsyncCallbackTest {
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

    private static Product2 createProduct() {
        Product2 prod = new Product2(Name = uniq('Prod'), IsActive = true);
        insert prod;
        return prod;
    }

    private static PromotionProduct createPromotionProduct(Id promotionId, Id productId) {
        PromotionProduct pp = new PromotionProduct(
            PromotionId = promotionId,
            ProductId = productId
        );
        insert pp;
        return pp;
    }

    @IsTest
    static void test_onFailure_deletePromotionProduct_restoresDeletedRecord() {
        Promotion p = createPromotionRecord();
        Product2 prod = createProduct();
        PromotionProduct pp = createPromotionProduct(p.Id, prod.Id);
        delete pp;

        ErpPromotionProductAsyncCallback cb = new ErpPromotionProductAsyncCallback();
        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_DELETE_PROMOTION_PRODUCT,
            null,
            (HttpErrorException) null,
            pp.Id
        );

        List<PromotionProduct> restored = [
            SELECT Id
            FROM PromotionProduct
            WHERE Id = :pp.Id
        ];
        System.assertEquals(1, restored.size());
    }

    @IsTest
    static void test_onFailure_deletePromotionProduct_nullRecordId_noThrow() {
        ErpPromotionProductAsyncCallback cb = new ErpPromotionProductAsyncCallback();
        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_DELETE_PROMOTION_PRODUCT,
            null,
            (HttpErrorException) null,
            (Id) null
        );
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_deletePromotionProduct_nonDeletedRecord_noRestorePath() {
        Promotion p = createPromotionRecord();
        Product2 prod = createProduct();
        PromotionProduct pp = createPromotionProduct(p.Id, prod.Id);

        ErpPromotionProductAsyncCallback cb = new ErpPromotionProductAsyncCallback();
        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_DELETE_PROMOTION_PRODUCT,
            null,
            (HttpErrorException) null,
            pp.Id
        );

        PromotionProduct remained = [
            SELECT Id
            FROM PromotionProduct
            WHERE Id = :pp.Id
            LIMIT 1
        ];
        System.assertEquals(pp.Id, remained.Id);
    }

    @IsTest
    static void test_onFailure_createPromotionProduct_noAction() {
        Promotion p = createPromotionRecord();
        Product2 prod = createProduct();
        PromotionProduct pp = createPromotionProduct(p.Id, prod.Id);
        delete pp;

        ErpPromotionProductAsyncCallback cb = new ErpPromotionProductAsyncCallback();
        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_CREATE_PROMOTION_PRODUCT,
            null,
            (HttpErrorException) null,
            pp.Id
        );

        List<PromotionProduct> remainedDeleted = [
            SELECT Id
            FROM PromotionProduct
            WHERE Id = :pp.Id
        ];
        System.assertEquals(0, remainedDeleted.size());
    }

    @IsTest
    static void test_noop_overloads_and_success() {
        ErpPromotionProductAsyncCallback cb = new ErpPromotionProductAsyncCallback();
        ErpApiResponseDto res = new ErpApiResponseDto();

        cb.onSuccess(ErpPromotionProductAsyncCallback.API_CREATE_PROMOTION_PRODUCT, null, res);

        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_CREATE_PROMOTION_PRODUCT,
            null,
            'err',
            'stack'
        );

        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_CREATE_PROMOTION_PRODUCT,
            null,
            'err',
            (Id) null
        );

        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_UPDATE_PROMOTION_PRODUCT,
            null,
            (HttpErrorException) null,
            (Id) null,
            null
        );

        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_CREATE_PROMOTION_PRODUCT,
            null,
            (HttpErrorException) null,
            new Set<Id>()
        );

        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_CREATE_PROMOTION_PRODUCT,
            null,
            (Exception) null,
            new Set<Id>()
        );

        cb.onFailure(
            ErpPromotionProductAsyncCallback.API_CREATE_PROMOTION_PRODUCT,
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
        System.assertEquals(null, ErpPromotionProductAsyncCallback.extractMessage(null), 'null -> null');
        System.assertEquals(null, ErpPromotionProductAsyncCallback.extractMessage(''), '빈문자열 -> null');
        System.assertEquals(null, ErpPromotionProductAsyncCallback.extractMessage('   '), '공백 -> null');
    }

    // 2) 유효한 JSON + message 필드 있음 -> message 값 반환
    @IsTest
    static void test_extractMessage_valid_json_with_message() {
        String body = '{"success":true,"message":"처리 성공","data":null}';
        String result = ErpPromotionProductAsyncCallback.extractMessage(body);
        System.assertEquals('처리 성공', result, 'message 필드 값 반환');
    }

    // 3) 유효한 JSON + message 필드 없음 -> 원문 반환
    @IsTest
    static void test_extractMessage_valid_json_without_message_field() {
        String body = '{"success":true,"data":null}';
        String result = ErpPromotionProductAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'message 필드 없으면 원문 반환');
    }

    // 4) 유효한 JSON + message = null -> 원문 반환
    @IsTest
    static void test_extractMessage_valid_json_message_is_null() {
        String body = '{"success":false,"message":null}';
        String result = ErpPromotionProductAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'message=null이면 원문 반환');
    }

    // 5) 유효하지 않은 JSON -> 원문 반환 (catch 분기)
    @IsTest
    static void test_extractMessage_invalid_json_returns_raw() {
        String body = 'NOT_JSON_STRING';
        String result = ErpPromotionProductAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, '파싱 실패 시 원문 반환');
    }

    // 6) JSON 배열 -> 원문 반환 (Map 아님 분기)
    @IsTest
    static void test_extractMessage_json_array_returns_raw() {
        String body = '[{"message":"item"}]';
        String result = ErpPromotionProductAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'JSON 배열이면 원문 반환');
    }
}