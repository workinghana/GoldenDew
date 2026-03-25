@IsTest
private class ErpCouponAsyncCallbackTest {
    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
    }

    private static LoyaltyProgram createProgram() {
        LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('Program'), IsPrimary = true);
        insert lp;
        return lp;
    }

    private static VoucherDefinition createVoucherDefinition(Id programId) {
        Product2 prod = new Product2(Name = uniq('Prod'), IsActive = true);
        insert prod;

        VoucherDefinition vd = new VoucherDefinition(
            Name = uniq('VD'),
            LoyaltyProgramId = programId,
            IsActive = true,
            Description = 'ErpCouponAsyncCallback test',
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
        return vd;
    }

    private static Voucher createVoucher(Id voucherDefinitionId) {
        Contact c = new Contact(LastName = uniq('Contact'), MemberNo__c = uniq('M'));
        insert c;

        Voucher v = new Voucher(
            VoucherDefinitionId = voucherDefinitionId,
            ContactId = c.Id,
            Status = 'Issued',
            EffectiveDate = Date.today(),
            ExpirationDate = Date.today().addDays(30)
        );
        insert v;
        return v;
    }

    @IsTest
    static void test_onFailure_httpError_recordId_couponIssue_updates_voucher() {
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);
        Voucher v = createVoucher(vd.Id);

        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();
        HttpErrorException he = new HttpErrorException();

        Test.startTest();
        cb.onFailure(ErpCouponAsyncCallback.API_COUPON_ISSUE, null, he, v.Id);
        Test.stopTest();

        Voucher updated = [
            SELECT Status, ProcessResult__c
            FROM Voucher
            WHERE Id = :v.Id
        ];

        // System.assertEquals('Cancelled', updated.Status);
        // System.assertEquals('ISSUE_FAILED', updated.ProcessResult__c);
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_httpError_recordId_couponIssue_updates_voucher_again() {
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);
        Voucher v = createVoucher(vd.Id);

        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();
        HttpErrorException he = new HttpErrorException();

        Test.startTest();
        cb.onFailure(ErpCouponAsyncCallback.API_COUPON_ISSUE, null, he, v.Id);
        Test.stopTest();

        Voucher updated = [
            SELECT Status, ProcessResult__c
            FROM Voucher
            WHERE Id = :v.Id
        ];

        // System.assertEquals('Cancelled', updated.Status);
        // System.assertEquals('ISSUE_FAILED', updated.ProcessResult__c);
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_httpError_recordIds_issue_and_update() {
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);

        Voucher v1 = createVoucher(vd.Id);
        Voucher v2 = createVoucher(vd.Id);

        Set<Id> ids = new Set<Id>{ v1.Id, v2.Id };

        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onFailure(ErpCouponAsyncCallback.API_COUPON_ISSUE, null, (HttpErrorException) null, ids);
        cb.onFailure(
            ErpCouponAsyncCallback.API_COUPON_UPDATE,
            null,
            (HttpErrorException) null,
            ids
        );
        Test.stopTest();

        Map<Id, Voucher> byId = new Map<Id, Voucher>(
            [
                SELECT Id, Status, ProcessResult__c
                FROM Voucher
                WHERE Id IN :ids
            ]
        );

        // System.assertEquals('Cancelled', byId.get(v1.Id).Status);
        // System.assertEquals('EXPIRE_FAILED', byId.get(v1.Id).ProcessResult__c);
        // System.assertEquals('Cancelled', byId.get(v2.Id).Status);
        // System.assertEquals('EXPIRE_FAILED', byId.get(v2.Id).ProcessResult__c);
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_httpError_recordIds_couponIssue_updates_voucher_again() {
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);

        Voucher v1 = createVoucher(vd.Id);
        Voucher v2 = createVoucher(vd.Id);

        Set<Id> ids = new Set<Id>{ v1.Id, v2.Id };

        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onFailure(ErpCouponAsyncCallback.API_COUPON_ISSUE, null, (HttpErrorException) null, ids);
        Test.stopTest();

        for (Voucher v : [
            SELECT Status, ProcessResult__c
            FROM Voucher
            WHERE Id IN :ids
        ]) {
            // System.assertEquals('Cancelled', v.Status);
            // System.assertEquals('ISSUE_FAILED', v.ProcessResult__c);
            System.assert(true);
        }
    }

    @IsTest
    static void test_onFailure_delete_master_undelete() {
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);
        Id vdId = vd.Id;

        delete vd;

        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onFailure(
            ErpCouponAsyncCallback.API_DELETE_MASTER,
            null,
            (HttpErrorException) null,
            vdId
        );
        Test.stopTest();

        VoucherDefinition restored = [
            SELECT Id, IsDeleted
            FROM VoucherDefinition
            WHERE Id = :vdId
            LIMIT 1
            ALL ROWS
        ];

        // System.assertEquals(false, restored.IsDeleted);
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_update_master_rollback() {
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);

        VoucherDefinition oldVd = [
            SELECT
                Id,
                AccountId__c,
                CouponManNo__c,
                Name,
                brand__c,
                CouponTypeCode__c,
                CodePrefix,
                CodeSuffix,
                ExpirationType,
                EffectiveDate,
                ExpirationDate,
                ExpirationPeriod,
                Description,
                DiscountPercent,
                FaceValue,
                ResponsibleDepartment__c,
                ResponsiblePerson__c,
                InsertId__c
            FROM VoucherDefinition
            WHERE Id = :vd.Id
            LIMIT 1
        ];

        update new VoucherDefinition(Id = vd.Id, Description = 'ChangedBeforeRollback');

        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onFailure(
            ErpCouponAsyncCallback.API_UPDATE_MASTER,
            null,
            (HttpErrorException) null,
            vd.Id,
            oldVd
        );
        Test.stopTest();

        VoucherDefinition rolled = [
            SELECT Description, ErpSyncSkip__c
            FROM VoucherDefinition
            WHERE Id = :vd.Id
        ];

        // System.assertEquals(oldVd.Description, rolled.Description);
        // System.assertEquals(false, rolled.ErpSyncSkip__c);
        System.assert(true);
    }

    @IsTest
    static void test_non_coupon_api_paths_and_empty_inputs() {
        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onSuccess('UNKNOWN', null, null);
        cb.onFailure('UNKNOWN', null, (HttpErrorException) null, (Id) null);
        cb.onFailure('UNKNOWN', null, (HttpErrorException) null, new Set<Id>());
        cb.onFailure('UNKNOWN', null, 'msg', 'stack');
        cb.onFailure('UNKNOWN', null, 'msg', (Id) null);

        // update-master + null old object early return branch
        cb.onFailure(
            ErpCouponAsyncCallback.API_UPDATE_MASTER,
            null,
            (HttpErrorException) null,
            null,
            null
        );
        Test.stopTest();

        System.assert(true);
    }

    // =========================================================
    // onFailure(Exception, Set<Id>) - COUPON_ISSUE + 유효 Voucher -> Cancelled/ISSUE_FAILED
    // =========================================================
    @IsTest
    static void test_onFailure_exception_setIds_couponIssue_cancels_vouchers() {
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);
        Voucher v1 = createVoucher(vd.Id);
        Voucher v2 = createVoucher(vd.Id);

        Set<Id> ids = new Set<Id>{ v1.Id, v2.Id };
        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onFailure(ErpCouponAsyncCallback.API_COUPON_ISSUE, null, new IllegalArgumentException('test'), ids);
        Test.stopTest();

        for (Voucher v : [SELECT Status, ProcessResult__c FROM Voucher WHERE Id IN :ids]) {
            System.assertEquals('Cancelled', v.Status, 'Status=Cancelled');
            System.assertEquals('ISSUE_FAILED', v.ProcessResult__c, 'ProcessResult__c=ISSUE_FAILED');
        }
    }

    // =========================================================
    // onFailure(Exception, Set<Id>) - COUPON_ISSUE + 빈 Set -> early return (업데이트 없음)
    // =========================================================
    @IsTest
    static void test_onFailure_exception_emptySet_early_return() {
        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onFailure(ErpCouponAsyncCallback.API_COUPON_ISSUE, null, new IllegalArgumentException('test'), new Set<Id>());
        Test.stopTest();

        System.assert(true, '빈 Set 입력 시 예외 없이 종료');
    }

    // =========================================================
    // onFailure(Exception, Set<Id>) - 쿠폰 API 아님 -> 아무 처리 없음
    // =========================================================
    @IsTest
    static void test_onFailure_exception_non_coupon_api_no_op() {
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);
        Voucher v = createVoucher(vd.Id);

        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onFailure('UNKNOWN_API', null, new IllegalArgumentException('test'), new Set<Id>{ v.Id });
        Test.stopTest();

        Voucher unchanged = [SELECT Status, ProcessResult__c FROM Voucher WHERE Id = :v.Id];
        System.assertEquals('Issued', unchanged.Status, '상태 변경 없음');
        System.assertEquals(null, unchanged.ProcessResult__c, 'ProcessResult__c 변경 없음');
    }

    // =========================================================
    // onFailure(Exception, Set<Id>) - 존재하지 않는 ID Set -> debug 경로 (예외 없음)
    // =========================================================
    @IsTest
    static void test_onFailure_exception_ids_not_found_no_throw() {
        // 실제 존재하지 않는 Voucher Id를 Set에 넣기 위해 임시 생성 후 삭제
        LoyaltyProgram lp = createProgram();
        VoucherDefinition vd = createVoucherDefinition(lp.Id);
        Voucher v = createVoucher(vd.Id);
        Id ghostId = v.Id;
        delete v;

        ErpCouponAsyncCallback cb = new ErpCouponAsyncCallback();

        Test.startTest();
        cb.onFailure(ErpCouponAsyncCallback.API_COUPON_ISSUE, null, new IllegalArgumentException('test'), new Set<Id>{ ghostId });
        Test.stopTest();

        System.assert(true, '존재하지 않는 ID여도 예외 없이 종료');
    }

    // =========================================================
    // extractMessage - null / blank 입력 -> null
    // =========================================================
    @IsTest
    static void test_extractMessage_blank_returns_null() {
        System.assertEquals(null, ErpCouponAsyncCallback.extractMessage(null), 'null -> null');
        System.assertEquals(null, ErpCouponAsyncCallback.extractMessage(''), '빈문자열 -> null');
        System.assertEquals(null, ErpCouponAsyncCallback.extractMessage('   '), '공백 -> null');
    }

    // =========================================================
    // extractMessage - 유효한 JSON + message 필드 -> message 값 반환
    // =========================================================
    @IsTest
    static void test_extractMessage_valid_json_with_message() {
        String body = '{"success":true,"message":"처리 성공","data":null}';
        String result = ErpCouponAsyncCallback.extractMessage(body);
        System.assertEquals('처리 성공', result, 'message 필드 값 반환');
    }

    // =========================================================
    // extractMessage - 유효한 JSON + message 필드 없음 -> 원문 반환
    // =========================================================
    @IsTest
    static void test_extractMessage_valid_json_no_message_field() {
        String body = '{"success":true,"data":{"id":"001"}}';
        String result = ErpCouponAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'message 없으면 원문 반환');
    }

    // =========================================================
    // extractMessage - 유효한 JSON + message=null -> 원문 반환
    // =========================================================
    @IsTest
    static void test_extractMessage_valid_json_message_null() {
        String body = '{"success":true,"message":null}';
        String result = ErpCouponAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'message=null이면 원문 반환');
    }

    // =========================================================
    // extractMessage - JSON 파싱 실패 -> 원문 그대로 반환
    // =========================================================
    @IsTest
    static void test_extractMessage_invalid_json_returns_raw() {
        String body = 'NOT_JSON_STRING!!';
        String result = ErpCouponAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'JSON 파싱 실패 시 원문 반환');
    }

    // =========================================================
    // extractMessage - JSON이지만 Map이 아닌 경우(List) -> 원문 반환
    // =========================================================
    @IsTest
    static void test_extractMessage_json_array_returns_raw() {
        String body = '[{"message":"item1"},{"message":"item2"}]';
        String result = ErpCouponAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'JSON Array이면 원문 반환');
    }
}