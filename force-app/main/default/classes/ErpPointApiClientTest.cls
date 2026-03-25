@IsTest
private class ErpPointApiClientTest {
    // =========================================================
    // Mock
    // =========================================================
    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success":true,"message":"OK","data":null}');
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"success":false,"message":"Internal Server Error","data":null}');
            return res;
        }
    }

    // =========================================================
    // 1) expiryPoint - null 요청 -> IllegalArgumentException
    // =========================================================
    @IsTest
    static void test_expiryPoint_null_throws() {
        Boolean threw = false;
        try {
            ErpPointApiClient.expiryPoint(null);
        } catch (IllegalArgumentException e) {
            threw = true;
            System.assertEquals('Request body is required.', e.getMessage());
        }
        System.assert(threw, 'null 요청 시 IllegalArgumentException이 발생해야 함');
    }

    // =========================================================
    // 2) expiryPoint - 정상 요청 -> 200 OK
    // =========================================================
    @IsTest
    static void test_expiryPoint_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();
        ErpPointReqDto.MbrPointUseModels model = new ErpPointReqDto.MbrPointUseModels();
        model.cd_save_ledger = 'LEDGER-001';
        model.pt_destory = '1000';
        model.cd_use_ledger = 'USE-001';
        model.id_insert = 'TEST_USER';
        req.mbrPointUseModels.add(model);

        Test.startTest();
        ErpApiResponseDto result = ErpPointApiClient.expiryPoint(req);
        Test.stopTest();

        System.assertNotEquals(null, result, '결과가 null이면 안됨');
        System.assertEquals(true, result.success, '성공 응답이어야 함');
    }

    // =========================================================
    // 3) expiryPoint - 빈 목록으로 호출
    // =========================================================
    @IsTest
    static void test_expiryPoint_empty_list() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        ErpPointReqDto.ExpiryRequest req = new ErpPointReqDto.ExpiryRequest();
        // mbrPointUseModels 기본값은 빈 리스트

        Test.startTest();
        ErpApiResponseDto result = ErpPointApiClient.expiryPoint(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================
    // 4) creditPoint - null 요청 -> IllegalArgumentException
    // =========================================================
    @IsTest
    static void test_creditPoint_null_throws() {
        Boolean threw = false;
        try {
            ErpPointApiClient.creditPoint(null);
        } catch (IllegalArgumentException e) {
            threw = true;
            System.assertEquals('Request body is required.', e.getMessage());
        }
        System.assert(threw, 'null 요청 시 IllegalArgumentException이 발생해야 함');
    }

    // =========================================================
    // 5) creditPoint - 정상 요청 -> 200 OK
    // =========================================================
    @IsTest
    static void test_creditPoint_success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();
        req.cd_company = 'GD';
        req.no_mbr = '00001';
        req.pt_save = 1000;
        req.id_insert = 'TEST_USER';

        Test.startTest();
        ErpApiResponseDto result = ErpPointApiClient.creditPoint(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(true, result.success);
    }

    // =========================================================
    // 6) creditPoint - null 필드 포함 -> pruneNulls 경유
    // =========================================================
    @IsTest
    static void test_creditPoint_with_null_fields_pruned() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        ErpPointReqDto.CreditRequest req = new ErpPointReqDto.CreditRequest();
        // 대부분 필드 null, 일부만 세팅
        req.no_mbr = '00002';
        req.pt_save = 500;
        // 나머지는 null -> pruneNulls로 제거되어야 함

        Test.startTest();
        ErpApiResponseDto result = ErpPointApiClient.creditPoint(req);
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // =========================================================
    // 7) pruneNulls - null 입력 -> null 반환
    // =========================================================
    @IsTest
    static void test_pruneNulls_null_input() {
        Object result = ErpPointApiClient.pruneNulls(null);
        System.assertEquals(null, result, 'null 입력 시 null 반환');
    }

    // =========================================================
    // 8) pruneNulls - Map에서 null 값 제거
    // =========================================================
    @IsTest
    static void test_pruneNulls_map_removes_null_values() {
        Map<String, Object> input = new Map<String, Object>{
            'key1' => 'value1',
            'key2' => null,
            'key3' => 42
        };

        Object result = ErpPointApiClient.pruneNulls(input);
        Map<String, Object> resultMap = (Map<String, Object>) result;

        System.assert(resultMap.containsKey('key1'), 'key1 유지');
        System.assert(!resultMap.containsKey('key2'), 'key2(null) 제거');
        System.assert(resultMap.containsKey('key3'), 'key3 유지');
        System.assertEquals('value1', resultMap.get('key1'));
        System.assertEquals(42, resultMap.get('key3'));
    }

    // =========================================================
    // 9) pruneNulls - 중첩 Map에서 null 재귀 제거
    // =========================================================
    @IsTest
    static void test_pruneNulls_nested_map_removes_null() {
        Map<String, Object> innerMap = new Map<String, Object>{
            'innerKey' => null,
            'innerValid' => 'present'
        };
        Map<String, Object> input = new Map<String, Object>{
            'outer' => innerMap,
            'outerNull' => null
        };

        Object result = ErpPointApiClient.pruneNulls(input);
        Map<String, Object> resultMap = (Map<String, Object>) result;

        System.assert(!resultMap.containsKey('outerNull'), 'outerNull 제거');
        System.assert(resultMap.containsKey('outer'), 'outer 유지');

        Map<String, Object> innerResult = (Map<String, Object>) resultMap.get('outer');
        System.assert(!innerResult.containsKey('innerKey'), 'innerKey(null) 제거');
        System.assert(innerResult.containsKey('innerValid'), 'innerValid 유지');
    }

    // =========================================================
    // 10) pruneNulls - List에서 null 요소 제거
    // =========================================================
    @IsTest
    static void test_pruneNulls_list_removes_null_elements() {
        List<Object> input = new List<Object>{ 'a', null, 'b', null, 'c' };

        Object result = ErpPointApiClient.pruneNulls(input);
        List<Object> resultList = (List<Object>) result;

        System.assertEquals(3, resultList.size(), 'null 제거 후 3개 남아야 함');
        System.assert(resultList.contains('a'));
        System.assert(resultList.contains('b'));
        System.assert(resultList.contains('c'));
    }

    // =========================================================
    // 11) pruneNulls - 빈 Map -> 그대로 반환
    // =========================================================
    @IsTest
    static void test_pruneNulls_empty_map() {
        Map<String, Object> input = new Map<String, Object>();
        Object result = ErpPointApiClient.pruneNulls(input);
        Map<String, Object> resultMap = (Map<String, Object>) result;
        System.assertEquals(0, resultMap.size(), '빈 Map은 그대로');
    }

    // =========================================================
    // 12) pruneNulls - 빈 List -> 그대로 반환
    // =========================================================
    @IsTest
    static void test_pruneNulls_empty_list() {
        List<Object> input = new List<Object>();
        Object result = ErpPointApiClient.pruneNulls(input);
        List<Object> resultList = (List<Object>) result;
        System.assertEquals(0, resultList.size(), '빈 List는 그대로');
    }

    // =========================================================
    // 13) pruneNulls - 스칼라 값 (String) -> 그대로 반환
    // =========================================================
    @IsTest
    static void test_pruneNulls_scalar_value_returned_as_is() {
        Object result = ErpPointApiClient.pruneNulls('hello');
        System.assertEquals('hello', result, '스칼라 String은 그대로 반환');
    }

    // =========================================================
    // 14) pruneNulls - List 내 Map의 null 재귀 제거
    // =========================================================
    @IsTest
    static void test_pruneNulls_list_containing_map_with_nulls() {
        Map<String, Object> innerMap = new Map<String, Object>{ 'a' => 'val', 'b' => null };
        List<Object> input = new List<Object>{ innerMap, null };

        Object result = ErpPointApiClient.pruneNulls(input);
        List<Object> resultList = (List<Object>) result;

        System.assertEquals(1, resultList.size(), 'null 요소 제거 후 1개');
        Map<String, Object> m = (Map<String, Object>) resultList[0];
        System.assert(!m.containsKey('b'), 'b(null) 제거');
        System.assert(m.containsKey('a'), 'a 유지');
    }
}