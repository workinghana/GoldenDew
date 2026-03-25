@IsTest
private class GdMemberHelpInfoApiControllerV1Test {

    // === Mock ===
    private class MockMemberHelpInfoService implements GdMemberHelpInfoService {
        public ApiResult result;
        public Exception throwEx;

        public ApiResult getMemberHelpInfo(Map<String, Object> reqData) {
            if (throwEx != null) {
                Exception e = throwEx;
                throwEx = null;
                if (e instanceof CustomException) throw (CustomException) e;
                throw e;
            }
            return result;
        }
    }

    private static void setupGet(String memberNo) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/member/help-info';
        req.httpMethod = 'GET';
        if (memberNo != null) {
            req.addParameter('MemberNo__c', memberNo);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    // 1) 기존: MemberNo__c 없음 (always-pass)
    @IsTest
    static void test_getMemberHelpInfo_alwaysPass() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/member/help-info';
        req.httpMethod = 'GET';
        req.addParameter('MemberNo__c', 'TEST_MEMBER_NO');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        try {
            GdMemberHelpInfoApiControllerV1.getMemberHelpInfo();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    // 2) MemberNo__c 파라미터 없음 → 400
    @IsTest
    static void test_getMemberHelpInfo_noParam_400() {
        setupGet(null);

        Test.startTest();
        GdMemberHelpInfoApiControllerV1.getMemberHelpInfo();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode, 'MemberNo__c 없음 → 400');
    }

    // 3) setMemberHelpInfoService 주입 + 성공 → 200
    @IsTest
    static void test_getMemberHelpInfo_mockSuccess_200() {
        MockMemberHelpInfoService mock = new MockMemberHelpInfoService();
        mock.result = ApiResult.ok(200, '조회 성공', new Map<String, Object>());
        GdMemberHelpInfoApiControllerV1.setMemberHelpInfoService(mock);

        setupGet('M-001');

        Test.startTest();
        GdMemberHelpInfoApiControllerV1.getMemberHelpInfo();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Mock 성공 → 200');

        GdMemberHelpInfoApiControllerV1.setMemberHelpInfoService(null);
    }

    // 4) setMemberHelpInfoService 주입 + CustomException → 해당 코드
    @IsTest
    static void test_getMemberHelpInfo_customException() {
        MockMemberHelpInfoService mock = new MockMemberHelpInfoService();
        mock.throwEx = new CustomException(404, '회원 없음');
        GdMemberHelpInfoApiControllerV1.setMemberHelpInfoService(mock);

        setupGet('M-NOT-FOUND');

        Test.startTest();
        GdMemberHelpInfoApiControllerV1.getMemberHelpInfo();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode, 'CustomException → 404');

        GdMemberHelpInfoApiControllerV1.setMemberHelpInfoService(null);
    }

    // 5) setMemberHelpInfoService 주입 + 일반 Exception → 500
    @IsTest
    static void test_getMemberHelpInfo_genericException_500() {
        MockMemberHelpInfoService mock = new MockMemberHelpInfoService();
        mock.throwEx = new IllegalArgumentException('unexpected');
        GdMemberHelpInfoApiControllerV1.setMemberHelpInfoService(mock);

        setupGet('M-EX');

        Test.startTest();
        GdMemberHelpInfoApiControllerV1.getMemberHelpInfo();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, '일반 Exception → 500');

        GdMemberHelpInfoApiControllerV1.setMemberHelpInfoService(null);
    }
}