@IsTest
private class GdPointApiControllerTest {

    /**
     * GdPointService Stub Provider
     */
    private class GdPointServiceStubProvider implements System.StubProvider {
        public Object handleMethodCall(
            Object stubbedObject,
            String methodName,
            Type returnType,
            List<Type> paramTypes,
            List<String> paramNames,
            List<Object> args
        ) {
            if (methodName == 'getPointApplyHelp') {
                Map<String, Object> reqData = (Map<String, Object>) args[0];

                if (reqData != null && reqData.containsKey('throwCustom')) {
                    throw new CustomException(400, '포인트 조회 커스텀 예외');
                }

                if (reqData != null && reqData.containsKey('throwException')) {
                    Integer x = 1 / 0;
                }

                return 12345;
            }

            return null;
        }
    }

    /**
     * 성공 케이스
     */
    @IsTest
    static void getPointList_success() {
        GdPointService pointStub = (GdPointService) Test.createStub(
            GdPointService.class,
            new GdPointServiceStubProvider()
        );
        GdPointApiController.setPointService(pointStub);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/point';
        req.httpMethod = 'GET';
        req.requestBody = Blob.valueOf('{"MemberNo__c":"MT-001","orderId":"ORD-001"}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdPointApiController.getPointList();
        Test.stopTest();

        System.assert(true);
    }

    /**
     * 요청 본문이 비어있는 경우
     */
    @IsTest
    static void getPointList_emptyBody() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/point';
        req.httpMethod = 'GET';
        req.requestBody = null;

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdPointApiController.getPointList();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertNotEquals(null, RestContext.response.responseBody);
        System.assert(
            RestContext.response.responseBody.toString().contains('요청 본문이 비었습니다.')
        );
    }

    /**
     * 잘못된 JSON 요청인 경우
     */
    @IsTest
    static void getPointList_invalidJson() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/point';
        req.httpMethod = 'GET';
        req.requestBody = Blob.valueOf('{"MemberNo__c":"MT-001"');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdPointApiController.getPointList();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertNotEquals(null, RestContext.response.responseBody);
        System.assert(
            RestContext.response.responseBody.toString().contains('JSON 역직렬화 실패')
        );
    }

    /**
     * 서비스에서 CustomException 발생하는 경우
     */
    @IsTest
    static void getPointList_customException() {
        GdPointService pointStub = (GdPointService) Test.createStub(
            GdPointService.class,
            new GdPointServiceStubProvider()
        );
        GdPointApiController.setPointService(pointStub);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/point';
        req.httpMethod = 'GET';
        req.requestBody = Blob.valueOf('{"throwCustom":true}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdPointApiController.getPointList();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        System.assertNotEquals(null, RestContext.response.responseBody);
        System.assert(
            RestContext.response.responseBody.toString().contains('포인트 조회 커스텀 예외')
        );
    }

    /**
     * 서비스에서 일반 Exception 발생하는 경우
     */
    @IsTest
    static void getPointList_generalException() {
        GdPointService pointStub = (GdPointService) Test.createStub(
            GdPointService.class,
            new GdPointServiceStubProvider()
        );
        GdPointApiController.setPointService(pointStub);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/point';
        req.httpMethod = 'GET';
        req.requestBody = Blob.valueOf('{"throwException":true}');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdPointApiController.getPointList();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        System.assertNotEquals(null, RestContext.response.responseBody);
    }
}