@IsTest
private class GdAccountApiControllerV1Test {
    /* =====================================================
     * Mock Service (반드시 Test 클래스 내부)
     * ===================================================== */
    private class MockAccountService implements GdAccountService {
        public ApiResult createAccount(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'created', null);
        }

        public ApiResult updateAccount(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'updated', null);
        }

        public ApiResult deleteAccount(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'deleted', null);
        }
    }

    /* ================= 정상 CREATE ================= */
    @IsTest
    static void test_createAccount_success() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{"Name":"매장A"}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.createAccount();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* ================= 정상 UPDATE ================= */
    @IsTest
    static void test_updateAccount_success() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf('{"Id":"001000000000001AAA","Name":"매장B"}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.updateAccount();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* ================= 빈 Body (CustomException) ================= */
    @IsTest
    static void test_createAccount_emptyBody() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.createAccount();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    /* ================= JSON 파싱 오류 ================= */
    @IsTest
    static void test_updateAccount_invalidJson() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf('{invalid json');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.updateAccount();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    /* ================= 정상 DELETE (Company) ================= */
    @IsTest
    static void test_deleteAccount_company_success() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'DELETE';
        req.addParameter('isCompany', 'true');
        req.addParameter('CompanyCode__c', 'C001');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.deleteAccount();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* ================= 정상 DELETE (Store) ================= */
    @IsTest
    static void test_deleteAccount_store_success() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'DELETE';
        req.addParameter('isCompany', 'false');
        req.addParameter('CompanyCode__c', 'C001');
        req.addParameter('StoreCode__c', 'S001');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.deleteAccount();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* ================= DELETE - isCompany 파라미터 없음 ================= */
    @IsTest
    static void test_deleteAccount_noIsCompany() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'DELETE';
        req.addParameter('CompanyCode__c', 'C001');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.deleteAccount();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
    }

    /* ================= DELETE - 유효하지 않은 isCompany 값 ================= */
    @IsTest
    static void test_deleteAccount_invalidIsCompany() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'DELETE';
        req.addParameter('isCompany', 'invalid');
        req.addParameter('CompanyCode__c', 'C001');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.deleteAccount();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }

    /* ================= DELETE - CompanyCode__c 누락 ================= */
    @IsTest
    static void test_deleteAccount_missingCompanyCode() {
        GdAccountApiControllerV1.setAccountService(new MockAccountService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/account';
        req.httpMethod = 'DELETE';
        req.addParameter('isCompany', 'true');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdAccountApiControllerV1.deleteAccount();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
    }
}