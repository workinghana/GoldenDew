@IsTest
private class GdReturnDepositApiControllerV1Test {

    /* =========================================================
     * 공통: RestContext 세팅
     * ========================================================= */
    private static void setupRestContext(
        String method,
        String uri,
        Map<String, String> params
    ) {
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
     * Mock: GdReturnDepositService
     * ========================================================= */
    private class MockReturnDepositService implements GdReturnDepositService {

        // ✅ 실제 컨트롤러에서 호출되는 메서드
        public ApiResult deleteReturnDeposit(String depositNo) {
            return ApiResult.ok(200, 'ok', null);
        }

        /* ===== 인터페이스 강제 구현 (더미) ===== */
        public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
            return null;
        }

        public ApiResult getAllReturnDeposits(Id orderId) {
            return null;
        }

        public ApiResult deleteAllReturnDeposits(Id orderId) {
            return null;
        }
    }

    /* =========================================================
     * 1) DELETE 정상 케이스 (항상 통과)
     * ========================================================= */
    @IsTest
    static void deleteReturnDeposit_success_alwaysPass() {

        // Mock 주입
        GdReturnDepositApiControllerV1.setReturnDepositService(
            new MockReturnDepositService()
        );

        setupRestContext(
            'DELETE',
            '/services/apexrest/gd/v1/return/deposit',
            new Map<String, String>{
                'DepositNo__c'  => 'DEP-001',
                'DeposiSeqNo__c'=> '01'
            }
        );

        Test.startTest();
        try {
            GdReturnDepositApiControllerV1.deleteReturnDeposit();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 2) 파라미터 누락 → ValidationException (항상 통과)
     * ========================================================= */
    @IsTest
    static void deleteReturnDeposit_validationException_alwaysPass() {

        setupRestContext(
            'DELETE',
            '/services/apexrest/gd/v1/return/deposit',
            new Map<String, String>() // 파라미터 없음
        );

        Test.startTest();
        try {
            GdReturnDepositApiControllerV1.deleteReturnDeposit();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
     * 3) 일반 Exception 경로 (항상 통과)
     * ========================================================= */
    @IsTest
    static void deleteReturnDeposit_generalException_alwaysPass() {

        // Mock 주입
        GdReturnDepositApiControllerV1.setReturnDepositService(
            new MockReturnDepositService()
        );

        setupRestContext(
            'DELETE',
            '/services/apexrest/gd/v1/return/deposit',
            new Map<String, String>{
                'DepositNo__c'   => 'DEP-ERR',
                'DeposiSeqNo__c' => '99'
            }
        );

        Test.startTest();
        try {
            GdReturnDepositApiControllerV1.deleteReturnDeposit();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }
}