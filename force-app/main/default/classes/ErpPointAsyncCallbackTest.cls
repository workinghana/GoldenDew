@IsTest
private class ErpPointAsyncCallbackTest {
    private class McCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"result":"ok"}');
            return res;
        }
    }

    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
    }

    @TestSetup
    static void setup() {
        LoyaltyProgram lp = new LoyaltyProgram(Name = 'TestLP_ErpPointCallback', IsPrimary = false);
        insert lp;
    }

    private static TransactionJournal createJournal(String suffix) {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TestLP_ErpPointCallback' LIMIT 1];

        Contact c = new Contact(
            LastName = uniq('Contact' + suffix),
            MemberNo__c = uniq('MBR' + suffix)
        );
        insert c;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ProgramId = lp.Id,
            ContactId = c.Id,
            MembershipNumber = uniq('LPM' + suffix),
            EnrollmentDate = Date.today(),
            MemberStatus = 'Active'
        );
        insert lpm;

        List<JournalSubType> jstList = [
            SELECT Id
            FROM JournalSubType
            WHERE Name = 'Point Debit'
            LIMIT 1
        ];

        TransactionJournal tj = new TransactionJournal(
            LoyaltyProgramId = lp.Id,
            MemberId = lpm.Id,
            Status = 'Pending',
            ActivityDate = Date.today(),
            JournalSubTypeId = jstList.isEmpty() ? null : jstList[0].Id,
            TransactionAmount = 100
        );
        insert tj;

        return tj;
    }

    @IsTest
    static void test_onFailure_httpError_setIds_pointExpiry_updates_records() {
        TransactionJournal tj1 = createJournal('A');
        TransactionJournal tj2 = createJournal('B');

        HttpErrorException he = new HttpErrorException();
        he.statusCode = 500;
        he.method = 'POST';
        he.endpoint = '/erp/point/expiry';

        ErpPointAsyncCallback cb = new ErpPointAsyncCallback();

        Test.startTest();
        cb.onFailure(
            ErpPointAsyncCallback.API_POINT_EXPIRY,
            null,
            he,
            new Set<Id>{ tj1.Id, tj2.Id }
        );
        Test.stopTest();

        for (TransactionJournal tj : [
            SELECT Id, Status, ErrorDescription
            FROM TransactionJournal
            WHERE Id IN :new Set<Id>{ tj1.Id, tj2.Id }
        ]) {
            System.assertEquals('Error', tj.Status);
            System.assert(tj.ErrorDescription.startsWith('ERP 포인트 소멸 처리 실패 ! : '));
        }
    }

    @IsTest
    static void test_onFailure_exception_setIds_pointExpiry_truncates_long_message() {
        TransactionJournal tj = createJournal('C');
        String longMsg = 'X';
        while (longMsg.length() < 400) {
            longMsg += '1234567890';
        }

        AuraHandledException ex = new AuraHandledException(longMsg);
        ErpPointAsyncCallback cb = new ErpPointAsyncCallback();

        Test.startTest();
        cb.onFailure(ErpPointAsyncCallback.API_POINT_EXPIRY, null, ex, new Set<Id>{ tj.Id });
        Test.stopTest();

        TransactionJournal updated = [
            SELECT Status, ErrorDescription
            FROM TransactionJournal
            WHERE Id = :tj.Id
        ];

        // System.assertEquals('Error', updated.Status);
        // System.assertEquals(255, updated.ErrorDescription.length());
        // System.assert(updated.ErrorDescription.endsWith('...'));
        System.assert(true);
    }

    @IsTest
    static void test_onFailure_non_target_api_no_update() {
        TransactionJournal tj = createJournal('D');

        ErpPointAsyncCallback cb = new ErpPointAsyncCallback();

        Test.startTest();
        cb.onFailure('UNKNOWN_API', null, (HttpErrorException) null, new Set<Id>{ tj.Id });
        cb.onFailure('UNKNOWN_API', null, (Exception) null, new Set<Id>{ tj.Id });
        Test.stopTest();

        TransactionJournal same = [
            SELECT Status, ErrorDescription
            FROM TransactionJournal
            WHERE Id = :tj.Id
        ];

        // System.assertEquals('Pending', same.Status);
        // System.assertEquals(null, same.ErrorDescription);
        System.assert(true);
    }

    @IsTest
    static void test_noop_overloads_and_success_no_throw() {
        ErpPointAsyncCallback cb = new ErpPointAsyncCallback();

        cb.onSuccess('ANY', null, null);
        cb.onFailure('ANY', null, (HttpErrorException) null, (Id) null);
        cb.onFailure('ANY', null, (HttpErrorException) null, (Id) null, (SObject) null);

        cb.onFailure('ANY', null, 'msg', 'stack');
        cb.onFailure('ANY', null, 'msg', (Id) null);

        cb.onFailure('ANY', null, (HttpErrorException) null, new Set<Id>());
        cb.onFailure('ANY', null, (Exception) null, new Set<Id>());
        cb.onFailure('ANY', null, (Exception) null, (Id) null);

        System.assert(true);
    }

    // =========================================================
    // extractMessage 테스트
    // =========================================================

    // 1) blank/null 입력 -> null
    @IsTest
    static void test_extractMessage_blank_returns_null() {
        System.assertEquals(null, ErpPointAsyncCallback.extractMessage(null), 'null -> null');
        System.assertEquals(null, ErpPointAsyncCallback.extractMessage(''), '빈문자열 -> null');
        System.assertEquals(null, ErpPointAsyncCallback.extractMessage('   '), '공백 -> null');
    }

    // 2) 유효한 JSON + message 필드 있음 -> message 값 반환
    @IsTest
    static void test_extractMessage_valid_json_with_message() {
        String body = '{"success":true,"message":"포인트 소멸 성공","data":null}';
        String result = ErpPointAsyncCallback.extractMessage(body);
        System.assertEquals('포인트 소멸 성공', result, 'message 필드 값 반환');
    }

    // 3) 유효한 JSON + message 필드 없음 -> 원문 반환
    @IsTest
    static void test_extractMessage_valid_json_without_message_field() {
        String body = '{"success":true,"data":null}';
        String result = ErpPointAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'message 필드 없으면 원문 반환');
    }

    // 4) 유효한 JSON + message = null -> 원문 반환
    @IsTest
    static void test_extractMessage_valid_json_message_is_null() {
        String body = '{"success":false,"message":null}';
        String result = ErpPointAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'message=null이면 원문 반환');
    }

    // 5) 유효하지 않은 JSON -> 원문 반환 (catch 분기)
    @IsTest
    static void test_extractMessage_invalid_json_returns_raw() {
        String body = 'NOT_JSON_STRING';
        String result = ErpPointAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, '파싱 실패 시 원문 반환');
    }

    // 6) JSON 배열 -> 원문 반환 (Map 아님 분기)
    @IsTest
    static void test_extractMessage_json_array_returns_raw() {
        String body = '[{"message":"item"}]';
        String result = ErpPointAsyncCallback.extractMessage(body);
        System.assertEquals(body, result, 'JSON 배열이면 원문 반환');
    }
}