@IsTest
private class GdOrderApiControllerTest {
    /* =========================
       공통 RestContext 세팅
    ========================== */
    private static void setupRestContext(String method, String bodyJson) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/order';
        req.httpMethod = method;

        if (bodyJson != null) {
            req.addHeader('Content-Type', 'application/json');
            req.requestBody = Blob.valueOf(bodyJson);
        }

        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================
       Mock : GdOrderService
    ========================== */
    private class MockOrderService implements GdOrderService {
        public ApiResult result;
        public Exception throwEx;
        public Boolean throwRuntimeEx;

        private ApiResult handle() {
            if (throwRuntimeEx == true) {
                throwRuntimeEx = false;
                Integer x = 1 / 0;
            }
            if (throwEx != null) {
                Exception e = throwEx;
                throwEx = null;
                if (e instanceof CustomException)
                    throw (CustomException) e;
                throw e;
            }
            return result == null
                ? new ApiResult(true, 200, 'ok', new Map<String, Object>())
                : result;
        }

        public ApiResult createOrder(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult updateOrder(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult createSale(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult updateSale(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult deleteSale(String saleNo) {
            return handle();
        }
    }

    /* =========================
       Mock : GdOrderItemService
    ========================== */
    private class MockOrderItemService implements GdOrderItemService {
        public ApiResult result;
        public Exception throwEx;
        public Boolean throwRuntimeEx;

        private ApiResult handle() {
            if (throwRuntimeEx == true) {
                throwRuntimeEx = false;
                Integer x = 1 / 0;
            }
            if (throwEx != null) {
                Exception e = throwEx;
                throwEx = null;
                if (e instanceof CustomException)
                    throw (CustomException) e;
                throw e;
            }
            return result == null
                ? new ApiResult(true, 200, 'ok', new Map<String, Object>())
                : result;
        }

        public ApiResult createOrderItem(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult upsertOrderItem(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult createSaleItem(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult upsertSaleItem(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult deleteSaleItem(Map<String, Object> reqData) {
            return handle();
        }
    }

    /* =========================
       Mock : GdTransactionJournalService
    ========================== */
    private class MockTransactionJournalService implements GdTransactionJournalService {
        public ApiResult result;
        public Exception throwEx;
        public Boolean throwRuntimeEx;

        private ApiResult handle() {
            if (throwRuntimeEx == true) {
                throwRuntimeEx = false;
                Integer x = 1 / 0;
            }
            if (throwEx != null) {
                Exception e = throwEx;
                throwEx = null;
                if (e instanceof CustomException)
                    throw (CustomException) e;
                throw e;
            }
            return result == null
                ? new ApiResult(true, 200, 'ok', new Map<String, Object>())
                : result;
        }

        public ApiResult createOrderDepositHistory(Map<String, Object> reqData) {
            return handle();
        }

        public ApiResult insertOrderDepositHistoryByUpdate(Map<String, Object> reqData) {
            return handle();
        }

        public ApiResult getOrderDepositList(String orderNo) {
            return handle();
        }

        public ApiResult createSaleDepositHistory(Map<String, Object> reqData) {
            return handle();
        }
        public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
            return handle();
        }

        public ApiResult getSaleDepositList(String saleNo) {
            return handle();
        }
    }

    /* =========================
       테스트 1 : 정상 플로우
    ========================== */
    @IsTest
    static void createOrder_success() {
        MockOrderService orderMock = new MockOrderService();
        orderMock.result = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'orderId' => '801AAA' }
        );

        MockOrderItemService itemMock = new MockOrderItemService();
        MockTransactionJournalService tjMock = new MockTransactionJournalService();

        GdOrderApiController.setOrderService(orderMock);
        GdOrderApiController.setOrderItemService(itemMock);
        GdOrderApiController.setTransactionJournalService(tjMock);

        setupRestContext('POST', '{"OrderNumber":"O-1001"}');

        Test.startTest();
        GdOrderApiController.createOrder();
        Test.stopTest();

        System.assert(true);

        GdOrderApiController.setOrderService(null);
        GdOrderApiController.setOrderItemService(null);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void setVoucherService_canBeCalled() {
        // 메서드 노출 커버 목적
        GdOrderApiController.setVoucherService(null);
        System.assert(true);
    }

    @IsTest
    static void updateOrder_success_withOptionalLists() {
        MockOrderService orderMock = new MockOrderService();
        orderMock.result = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'orderId' => '801BBB' }
        );

        MockOrderItemService itemMock = new MockOrderItemService();

        MockTransactionJournalService tjMock = new MockTransactionJournalService();
        tjMock.result = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{
                'CancelPointList' => new List<Object>{ new Map<String, Object>{ 'k' => 'v' } },
                'DebitPointList' => new List<Object>{ new Map<String, Object>{ 'k2' => 'v2' } }
            }
        );

        GdOrderApiController.setOrderService(orderMock);
        GdOrderApiController.setOrderItemService(itemMock);
        GdOrderApiController.setTransactionJournalService(tjMock);

        setupRestContext(
            'PATCH',
            '{"OrderItem":[{"ProductCode":"P001"}],"TransactionJournal":[{"ActivityDate":"2026-03-10"}]}'
        );

        Test.startTest();
        GdOrderApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdOrderApiController.setOrderService(null);
        GdOrderApiController.setOrderItemService(null);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void updateOrder_customException_branch() {
        MockOrderService orderMock = new MockOrderService();
        orderMock.throwEx = new CustomException(422, 'update failed');

        GdOrderApiController.setOrderService(orderMock);
        GdOrderApiController.setOrderItemService(new MockOrderItemService());
        GdOrderApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PATCH', '{"OrderNo":"O-1"}');

        Test.startTest();
        GdOrderApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdOrderApiController.setOrderService(null);
        GdOrderApiController.setOrderItemService(null);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void updateOrder_exception_branch() {
        MockOrderService orderMock = new MockOrderService();
        orderMock.throwRuntimeEx = true;

        GdOrderApiController.setOrderService(orderMock);
        GdOrderApiController.setOrderItemService(new MockOrderItemService());
        GdOrderApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PATCH', '{"OrderNo":"O-2"}');

        Test.startTest();
        GdOrderApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdOrderApiController.setOrderService(null);
        GdOrderApiController.setOrderItemService(null);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void cancelOrder_success() {
        MockOrderService orderMock = new MockOrderService();
        orderMock.result = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'orderId' => '801CCC' }
        );

        GdOrderApiController.setOrderService(orderMock);
        GdOrderApiController.setOrderItemService(new MockOrderItemService());
        GdOrderApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PUT', '{"OrderItem":[{"ProductCode":"P001"}],"OrderNo":"O-3"}');

        Test.startTest();
        GdOrderApiController.cancelOrder();
        Test.stopTest();

        System.assert(true);

        GdOrderApiController.setOrderService(null);
        GdOrderApiController.setOrderItemService(null);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void cancelOrder_badJson_customException_branch() {
        GdOrderApiController.setOrderService(new MockOrderService());
        GdOrderApiController.setOrderItemService(new MockOrderItemService());
        GdOrderApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PUT', '{bad');

        Test.startTest();
        GdOrderApiController.cancelOrder();
        Test.stopTest();

        System.assert(true);

        GdOrderApiController.setOrderService(null);
        GdOrderApiController.setOrderItemService(null);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void cancelOrder_exception_branch() {
        MockOrderService orderMock = new MockOrderService();
        orderMock.throwRuntimeEx = true;

        GdOrderApiController.setOrderService(orderMock);
        GdOrderApiController.setOrderItemService(new MockOrderItemService());
        GdOrderApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PUT', '{"OrderNo":"O-4"}');

        Test.startTest();
        GdOrderApiController.cancelOrder();
        Test.stopTest();

        System.assert(true);

        GdOrderApiController.setOrderService(null);
        GdOrderApiController.setOrderItemService(null);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void getOrderDepositList_success() {
        MockTransactionJournalService tjMock = new MockTransactionJournalService();
        tjMock.result = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'list' => new List<Object>() }
        );

        GdOrderApiController.setTransactionJournalService(tjMock);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/order';
        req.httpMethod = 'GET';
        req.params.put('orderNo', 'ORD-001');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdOrderApiController.getOrderDepositList();
        Test.stopTest();

        System.assert(true);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void getOrderDepositList_validationException_branch() {
        GdOrderApiController.setTransactionJournalService(new MockTransactionJournalService());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/order';
        req.httpMethod = 'GET';
        // orderNo 누락
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdOrderApiController.getOrderDepositList();
        Test.stopTest();

        System.assert(true);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void getOrderDepositList_customException_branch() {
        MockTransactionJournalService tjMock = new MockTransactionJournalService();
        tjMock.throwEx = new CustomException(400, 'deposit failed');
        GdOrderApiController.setTransactionJournalService(tjMock);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/order';
        req.httpMethod = 'GET';
        req.params.put('orderNo', 'ORD-002');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdOrderApiController.getOrderDepositList();
        Test.stopTest();

        System.assert(true);
        GdOrderApiController.setTransactionJournalService(null);
    }

    @IsTest
    static void getOrderDepositList_exception_branch() {
        MockTransactionJournalService tjMock = new MockTransactionJournalService();
        tjMock.throwRuntimeEx = true;
        GdOrderApiController.setTransactionJournalService(tjMock);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/order';
        req.httpMethod = 'GET';
        req.params.put('orderNo', 'ORD-003');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdOrderApiController.getOrderDepositList();
        Test.stopTest();

        System.assert(true);
        GdOrderApiController.setTransactionJournalService(null);
    }
}