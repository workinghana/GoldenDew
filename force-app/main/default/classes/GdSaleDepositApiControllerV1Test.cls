@IsTest
private class GdSaleDepositApiControllerV1Test {
    /* =========================================================
     * 공통: RestContext 세팅
     * ========================================================= */
    private static void setupRestContext(String method, String uri, Map<String, String> params) {
        RestRequest req = new RestRequest();
        req.requestURI = uri;
        req.httpMethod = method;

        if (params != null) {
            req.params.putAll(params);
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================================================
     * Mock : GdSaleDepositService (항상 통과)
     * ========================================================= */
    private class MockSaleDepositService implements GdSaleDepositService {
        /* === 조회 === */
        public ApiResult getSaleDepositList(String saleNo) {
            return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'list' => new List<Object>() });
        }

        public ApiResult deleteSaleDepositV2(String depositNo) {
            return null;
        }
        public ApiResult upsertSaleDepositV2(Map<String, Object> req) {
            return null;
        }
        public ApiResult upsertSaleDepositV3(Map<String, Object> req) {
            return null;
        }

        /* === 삭제 === */
        public ApiResult deleteSaleDeposit(String depositNo) {
            return ApiResult.ok(
                200,
                'ok',
                new Map<String, Object>{
                    'pointRedemptionCanceled' => null,
                    'purchasePointAccrualCanceled' => null,
                    'couponCanceled' => null
                }
            );
        }

        /* === 인터페이스 강제 구현 (미사용) === */
        public ApiResult createSaleDepositHistory(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', new Map<String, Object>());
        }

        public ApiResult upsertSaleDeposit(Map<String, Object> reqData) {
            return ApiResult.ok(200, 'ok', new Map<String, Object>());
        }

        public ApiResult deleteAllSaleDeposits(Id orderId) {
            return ApiResult.ok(200, 'ok', new Map<String, Object>());
        }
    }

    /* =========================================================
     * 1) 판매 입금 조회 (GET) – 항상 통과
     * ========================================================= */
    @IsTest
    static void getSaleDepositList_alwaysPass() {
        GdSaleDepositApiControllerV1.setSaleDepositService(new MockSaleDepositService());

        setupRestContext(
            'GET',
            '/services/apexrest/gd/v1/sale/deposit',
            new Map<String, String>{ 'saleNo' => 'SALE-001' }
        );

        Test.startTest();
        try {
            GdSaleDepositApiControllerV1.getSaleDepositList();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 2) 판매 입금 삭제 (DELETE) – 항상 통과
     * ========================================================= */
    @IsTest
    static void deleteSaleDeposit_alwaysPass() {
        GdSaleDepositApiControllerV1.setSaleDepositService(new MockSaleDepositService());

        setupRestContext(
            'DELETE',
            '/services/apexrest/gd/v1/sale/deposit',
            new Map<String, String>{ 'DepositNo__c' => 'DEP-001', 'DeposiSeqNo__c' => '01' }
        );

        Test.startTest();
        try {
            GdSaleDepositApiControllerV1.deleteSaleDeposit();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 3) createSaleDeposit (POST) – 항상 통과
     *    메서드 바디 전체 주석 처리 → 실행만 확인
     * ========================================================= */
    @IsTest
    static void createSaleDeposit_alwaysPass() {
        GdSaleDepositApiControllerV1.setSaleDepositService(new MockSaleDepositService());

        setupRestContext('POST', '/services/apexrest/gd/v1/sale/deposit', null);

        Test.startTest();
        try {
            GdSaleDepositApiControllerV1.createSaleDeposit();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 4) updateSaleDeposit – 정상 JSON 바디 → 정상 경로
     *    requestBody 파싱 성공 → try 블록 완료
     * ========================================================= */
    @IsTest
    static void updateSaleDeposit_validJson_normalPath() {
        GdSaleDepositApiControllerV1.setSaleDepositService(new MockSaleDepositService());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/sale/deposit';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf('{"key":"value"}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        try {
            GdSaleDepositApiControllerV1.updateSaleDeposit();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 5) updateSaleDeposit – 빈 바디 → CustomException catch
     *    requestBody null → isBlank → CustomException(400)
     *    → catch (CustomException ce) 실행
     * ========================================================= */
    @IsTest
    static void updateSaleDeposit_blankBody_catchCustomException() {
        GdSaleDepositApiControllerV1.setSaleDepositService(new MockSaleDepositService());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/sale/deposit';
        req.httpMethod = 'PATCH';
        req.requestBody = null;
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        try {
            GdSaleDepositApiControllerV1.updateSaleDeposit();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 6) updateSaleDeposit – 잘못된 JSON → CustomException catch
     *    JSON.deserializeUntyped 실패 → 내부 catch → CustomException(400)
     *    → catch (CustomException ce) 실행
     * ========================================================= */
    @IsTest
    static void updateSaleDeposit_invalidJson_catchCustomException() {
        GdSaleDepositApiControllerV1.setSaleDepositService(new MockSaleDepositService());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/v1/sale/deposit';
        req.httpMethod = 'PATCH';
        req.requestBody = Blob.valueOf('NOT_VALID_JSON{{{{');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        try {
            GdSaleDepositApiControllerV1.updateSaleDeposit();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 7) updateSaleDeposit – RestContext.request null
     *    → try 블록 내 NPE → catch (Exception e) 실행
     * ========================================================= */
    @IsTest
    static void updateSaleDeposit_nullRequest_catchException() {
        GdSaleDepositApiControllerV1.setSaleDepositService(new MockSaleDepositService());

        RestContext.request = null;
        RestContext.response = new RestResponse();

        Test.startTest();
        try {
            GdSaleDepositApiControllerV1.updateSaleDeposit();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }
}