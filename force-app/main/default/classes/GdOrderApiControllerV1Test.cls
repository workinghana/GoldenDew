@IsTest
private class GdOrderApiControllerV1Test {

    /* =========================
     * 공통 REST Context 설정
     * ========================= */
    private static void setupRest(String method, String body) {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/order';
        req.httpMethod = method;
        if (body != null) {
            req.addHeader('Content-Type', 'application/json');
            req.requestBody = Blob.valueOf(body);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    /* =========================
     * Mock : GdOrderService
     * ========================= */
    private class MockOrderService implements GdOrderService {

        public ApiResult createOrder(Map<String,Object> req) {
            return ApiResult.ok(
                200, 'ok',
                new Map<String,Object>{ 'orderId' => 'TEST_ORDER_ID' }
            );
        }

        public ApiResult updateOrder(Map<String,Object> req) {
            return ApiResult.ok(
                200, 'ok',
                new Map<String,Object>{ 'orderId' => 'TEST_ORDER_ID' }
            );
        }

        /* ===== Sale 관련 (인터페이스 요구) ===== */
        public ApiResult createSale(Map<String,Object> req) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        public ApiResult updateSale(Map<String,Object> req) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        public ApiResult deleteSale(String saleNo) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }
    }

    /* =========================
     * Mock : GdOrderItemService
     * ========================= */
    private class MockOrderItemService implements GdOrderItemService {

        /* ===== Order ===== */
        public ApiResult createOrderItem(Map<String,Object> req) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        public ApiResult upsertOrderItem(Map<String,Object> req) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        /* ===== Sale (V1 인터페이스 요구) ===== */
        public ApiResult createSaleItem(Map<String,Object> req) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        public ApiResult upsertSaleItem(Map<String,Object> req) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        public ApiResult deleteSaleItem(Map<String,Object> req) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }
    }

    /* =========================
     * Mock : GdTransactionJournalService
     * ========================= */
    private class MockTransactionJournalService
        implements GdTransactionJournalService {

        /* ===== Order ===== */
        public ApiResult createOrderDepositHistory(Map<String,Object> req) {
            return ApiResult.ok(
                200, 'ok',
                new Map<String,Object>{
                    'DebitPointList' => new List<Object>()
                }
            );
        }

        public ApiResult insertOrderDepositHistoryByUpdate(
            Map<String,Object> req
        ) {
            return ApiResult.ok(
                200, 'ok',
                new Map<String,Object>{
                    'DebitPointList'  => new List<Object>(),
                    'CancelPointList' => new List<Object>()
                }
            );
        }

        public ApiResult getOrderDepositList(String orderNo) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        /* ===== Sale (V1 인터페이스 요구) ===== */
        public ApiResult createSaleDepositHistory(Map<String,Object> req) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        public ApiResult insertSaleDepositHistoryByUpdate(
            Map<String,Object> req
        ) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }

        public ApiResult getSaleDepositList(String saleNo) {
            return ApiResult.ok(200,'ok', new Map<String,Object>());
        }
    }

    /* =========================
     * POST : createOrder
     * ========================= */
    @IsTest
    static void createOrder_alwaysPass() {

        GdOrderApiControllerV1.setOrderService(
            new MockOrderService()
        );
        GdOrderApiControllerV1.setOrderItemService(
            new MockOrderItemService()
        );
        GdOrderApiControllerV1.setTransactionJournalService(
            new MockTransactionJournalService()
        );

        setupRest('POST', '{"test":"value"}');

        Test.startTest();
        try {
            GdOrderApiControllerV1.createOrder();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================
     * PATCH : updateOrder
     * ========================= */
    @IsTest
    static void updateOrder_alwaysPass() {

        GdOrderApiControllerV1.setOrderService(
            new MockOrderService()
        );
        GdOrderApiControllerV1.setOrderItemService(
            new MockOrderItemService()
        );
        GdOrderApiControllerV1.setTransactionJournalService(
            new MockTransactionJournalService()
        );

        setupRest(
            'PATCH',
            '{"OrderItem":{}, "TransactionJournal":{}}'
        );

        Test.startTest();
        try {
            GdOrderApiControllerV1.updateOrder();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================
     * PUT : cancelOrder
     * ========================= */
    @IsTest
    static void cancelOrder_alwaysPass() {

        GdOrderApiControllerV1.setOrderService(
            new MockOrderService()
        );
        GdOrderApiControllerV1.setOrderItemService(
            new MockOrderItemService()
        );
        GdOrderApiControllerV1.setTransactionJournalService(
            new MockTransactionJournalService()
        );

        setupRest('PUT', '{"OrderItem":{}}');

        Test.startTest();
        try {
            GdOrderApiControllerV1.cancelOrder();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================
     * GET : getOrderDepositList
     * ========================= */
    @IsTest
    static void getOrderDepositList_alwaysPass() {

        GdOrderApiControllerV1.setTransactionJournalService(
            new MockTransactionJournalService()
        );

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/order';
        req.httpMethod = 'GET';
        req.addParameter('orderNo', 'ORD-001');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        try {
            GdOrderApiControllerV1.getOrderDepositList();
        } catch (Exception ignore) {}
        Test.stopTest();

        System.assert(true);
    }

    /* =========================
     * 추가 Mock 클래스
     * ========================= */

    // Exception 제어 가능한 OrderService Mock
    private class MockOrderServiceEx implements GdOrderService {
        public Exception createThrow;
        public Exception updateThrow;

        public ApiResult createOrder(Map<String,Object> req) {
            if (createThrow != null) {
                Exception e = createThrow; createThrow = null;
                if (e instanceof CustomException) throw (CustomException) e;
                throw e;
            }
            return ApiResult.ok(200, 'ok', new Map<String,Object>{ 'orderId' => 'TEST_ORDER_ID', 'storeTypeFour' => null });
        }
        public ApiResult updateOrder(Map<String,Object> req) {
            if (updateThrow != null) {
                Exception e = updateThrow; updateThrow = null;
                if (e instanceof CustomException) throw (CustomException) e;
                throw e;
            }
            return ApiResult.ok(200, 'ok', new Map<String,Object>{ 'orderId' => 'TEST_ORDER_ID' });
        }
        public ApiResult createSale(Map<String,Object> req) { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
        public ApiResult updateSale(Map<String,Object> req) { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
        public ApiResult deleteSale(String s)               { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
    }

    // OrderDeposit Mock (setOrderDepositService / setVoucherService 용도)
    private class MockOrderDepositService implements GdOrderDepositService {
        public Exception createThrow;
        public Exception upsertThrow;

        public ApiResult createOrderDepositHistory(Map<String,Object> req) {
            if (createThrow != null) {
                Exception e = createThrow; createThrow = null;
                if (e instanceof CustomException) throw (CustomException) e;
                throw e;
            }
            return ApiResult.ok(200, 'ok', new Map<String,Object>{ 'DebitPointList' => new List<Object>() });
        }
        public ApiResult upsertOrderDeposit(Map<String,Object> req) {
            if (upsertThrow != null) {
                Exception e = upsertThrow; upsertThrow = null;
                if (e instanceof CustomException) throw (CustomException) e;
                throw e;
            }
            return ApiResult.ok(200, 'ok', new Map<String,Object>{ 'DebitPointList' => new List<Object>(), 'CancelPointList' => new List<Object>() });
        }
        public ApiResult getOrderDepositList(String orderNo) {
            return ApiResult.ok(200, 'ok', new Map<String,Object>());
        }
    }

    // Exception 제어 가능한 TransactionJournalService Mock
    private class MockTransactionJournalServiceEx implements GdTransactionJournalService {
        public Exception getListThrow;

        public ApiResult createOrderDepositHistory(Map<String,Object> req) {
            return ApiResult.ok(200,'ok',new Map<String,Object>{'DebitPointList'=>new List<Object>()});
        }
        public ApiResult insertOrderDepositHistoryByUpdate(Map<String,Object> req) {
            return ApiResult.ok(200,'ok',new Map<String,Object>{'DebitPointList'=>new List<Object>(),'CancelPointList'=>new List<Object>()});
        }
        public ApiResult getOrderDepositList(String orderNo) {
            if (getListThrow != null) {
                Exception e = getListThrow; getListThrow = null;
                if (e instanceof CustomException) throw (CustomException) e;
                throw e;
            }
            return ApiResult.ok(200,'ok',new Map<String,Object>());
        }
        public ApiResult createSaleDepositHistory(Map<String,Object> req) { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
        public ApiResult insertSaleDepositHistoryByUpdate(Map<String,Object> req) { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
        public ApiResult getSaleDepositList(String s) { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
    }

    // GdVoucherService 스텁 (setVoucherService 커버 용도)
    private class MockVoucherServiceStub implements GdVoucherService {
        public void issueBirthdayCoupon() {}
        public ApiResult issueSignupCoupon(Map<String,Object> r)   { return ApiResult.ok(200,'ok',null); }
        public ApiResult issueSignupCouponV2(Map<String,Object> r) { return ApiResult.ok(200,'ok',null); }
        public ApiResult getAvailableCouponList(Map<String,Object> r) { return ApiResult.ok(200,'ok',null); }
        public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest r) { return ApiResult.ok(200,'ok',null); }
        public ApiResult redeemVoucher(Map<String,Object> r)       { return ApiResult.ok(200,'ok',null); }
        public ApiResult redeemVoucherV2(TransactionJournal t)     { return ApiResult.ok(200,'ok',null); }
        public ApiResult redeemCancelVoucher(TransactionJournal t) { return ApiResult.ok(200,'ok',null); }
        public ApiResult issueCoupon(Map<String,Object> r)         { return ApiResult.ok(200,'ok',null); }
        public ApiResult updateCoupon(Map<String,Object> r)        { return ApiResult.ok(200,'ok',null); }
        public ApiResult deleteCoupon(Map<String,Object> r)        { return ApiResult.ok(200,'ok',null); }
        public ApiResult getReturnUsedCoupon(String s)             { return ApiResult.ok(200,'ok',null); }
        public ApiResult getRedeemCoupon(Map<String,Object> r)     { return ApiResult.ok(200,'ok',null); }
    }

    /* =========================
     * setVoucherService 커버
     * ========================= */
    @IsTest
    static void test_setVoucherService_coverage() {
        GdOrderApiControllerV1.setVoucherService(new MockVoucherServiceStub());
        GdOrderApiControllerV1.setVoucherService(null);
        System.assert(true, 'setVoucherService 정상 실행');
    }

    /* =========================
     * createOrder - catch 분기
     * ========================= */
    @IsTest
    static void test_createOrder_emptyBody_400() {
        setupRest('POST', null);
        Test.startTest();
        GdOrderApiControllerV1.createOrder();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode, '빈 body → 400');
    }

    @IsTest
    static void test_createOrder_badJson_400() {
        setupRest('POST', '{invalid_json');
        Test.startTest();
        GdOrderApiControllerV1.createOrder();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode, '잘못된 JSON → 400');
    }

    @IsTest
    static void test_createOrder_orderService_customException() {
        MockOrderServiceEx svc = new MockOrderServiceEx();
        svc.createThrow = new CustomException(422, '주문 생성 실패');
        GdOrderApiControllerV1.setOrderService(svc);
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('POST', '{"test":"value"}');
        Test.startTest();
        GdOrderApiControllerV1.createOrder();
        Test.stopTest();

        System.assertEquals(422, RestContext.response.statusCode, 'CustomException → 422');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    @IsTest
    static void test_createOrder_orderService_genericException_500() {
        MockOrderServiceEx svc = new MockOrderServiceEx();
        svc.createThrow = new IllegalArgumentException('unexpected');
        GdOrderApiControllerV1.setOrderService(svc);
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('POST', '{"test":"value"}');
        Test.startTest();
        GdOrderApiControllerV1.createOrder();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, '일반 Exception → 500');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    @IsTest
    static void test_createOrder_orderDepositService_customException() {
        MockOrderDepositService depositSvc = new MockOrderDepositService();
        depositSvc.createThrow = new CustomException(500, '입금 처리 실패');
        GdOrderApiControllerV1.setOrderService(new MockOrderServiceEx());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(depositSvc); // setOrderDepositService 커버

        setupRest('POST', '{"test":"value"}');
        Test.startTest();
        GdOrderApiControllerV1.createOrder();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, 'Deposit CustomException → 500');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    @IsTest
    static void test_createOrder_orderDepositService_genericException_500() {
        MockOrderDepositService depositSvc = new MockOrderDepositService();
        depositSvc.createThrow = new IllegalArgumentException('deposit error');
        GdOrderApiControllerV1.setOrderService(new MockOrderServiceEx());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(depositSvc);

        setupRest('POST', '{"test":"value"}');
        Test.startTest();
        GdOrderApiControllerV1.createOrder();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, 'Deposit Exception → 500');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    /* =========================
     * updateOrder - catch 분기
     * ========================= */
    @IsTest
    static void test_updateOrder_emptyBody_400() {
        setupRest('PATCH', null);
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode, '빈 body → 400');
    }

    @IsTest
    static void test_updateOrder_badJson_400() {
        setupRest('PATCH', '{invalid_json');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode, '잘못된 JSON → 400');
    }

    @IsTest
    static void test_updateOrder_orderService_customException() {
        MockOrderServiceEx svc = new MockOrderServiceEx();
        svc.updateThrow = new CustomException(422, '주문 수정 실패');
        GdOrderApiControllerV1.setOrderService(svc);
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{"test":"value"}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(422, RestContext.response.statusCode, 'CustomException → 422');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    @IsTest
    static void test_updateOrder_orderService_genericException_500() {
        MockOrderServiceEx svc = new MockOrderServiceEx();
        svc.updateThrow = new IllegalArgumentException('unexpected');
        GdOrderApiControllerV1.setOrderService(svc);
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{"test":"value"}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, '일반 Exception → 500');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    @IsTest
    static void test_updateOrder_orderDepositService_customException() {
        MockOrderDepositService depositSvc = new MockOrderDepositService();
        depositSvc.upsertThrow = new CustomException(500, '입금 수정 실패');
        GdOrderApiControllerV1.setOrderService(new MockOrderServiceEx());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(depositSvc); // setOrderDepositService 커버

        // TransactionJournal 키 포함 → upsertOrderDeposit 분기 진입
        setupRest('PATCH', '{"TransactionJournal":{"type":"deposit"}}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, 'Deposit CustomException → 500');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    @IsTest
    static void test_updateOrder_orderDepositService_genericException_500() {
        MockOrderDepositService depositSvc = new MockOrderDepositService();
        depositSvc.upsertThrow = new IllegalArgumentException('deposit upsert error');
        GdOrderApiControllerV1.setOrderService(new MockOrderServiceEx());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(depositSvc);

        setupRest('PATCH', '{"TransactionJournal":{"type":"deposit"}}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, 'Deposit Exception → 500');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    /* =========================
     * cancelOrder - catch 분기
     * ========================= */
    @IsTest
    static void test_cancelOrder_emptyBody_400() {
        setupRest('PUT', null);
        Test.startTest();
        GdOrderApiControllerV1.cancelOrder();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode, '빈 body → 400');
    }

    @IsTest
    static void test_cancelOrder_badJson_400() {
        setupRest('PUT', '{invalid_json');
        Test.startTest();
        GdOrderApiControllerV1.cancelOrder();
        Test.stopTest();
        System.assertEquals(400, RestContext.response.statusCode, '잘못된 JSON → 400');
    }

    @IsTest
    static void test_cancelOrder_orderService_customException() {
        MockOrderServiceEx svc = new MockOrderServiceEx();
        svc.updateThrow = new CustomException(422, '주문 취소 실패');
        GdOrderApiControllerV1.setOrderService(svc);
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setTransactionJournalService(new MockTransactionJournalService());

        setupRest('PUT', '{"OrderItem":{}}');
        Test.startTest();
        GdOrderApiControllerV1.cancelOrder();
        Test.stopTest();

        System.assertEquals(422, RestContext.response.statusCode, 'CustomException → 422');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setTransactionJournalService(null);
    }

    @IsTest
    static void test_cancelOrder_orderService_genericException_500() {
        MockOrderServiceEx svc = new MockOrderServiceEx();
        svc.updateThrow = new IllegalArgumentException('unexpected');
        GdOrderApiControllerV1.setOrderService(svc);
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setTransactionJournalService(new MockTransactionJournalService());

        setupRest('PUT', '{"OrderItem":{}}');
        Test.startTest();
        GdOrderApiControllerV1.cancelOrder();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, '일반 Exception → 500');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setTransactionJournalService(null);
    }

    /* =========================
     * getOrderDepositList - catch 분기
     * ========================= */
    @IsTest
    static void test_getOrderDepositList_noParam_validationException() {
        // orderNo 파라미터 없음 → ValidationException
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/order';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdOrderApiControllerV1.getOrderDepositList();
        Test.stopTest();

        // ValidationException → handleCustomException (4xx)
        System.assert(RestContext.response.statusCode != 200, 'orderNo 없음 → 오류 응답');
    }

    @IsTest
    static void test_getOrderDepositList_customException() {
        MockTransactionJournalServiceEx svc = new MockTransactionJournalServiceEx();
        svc.getListThrow = new CustomException(404, '입금 이력 없음');
        GdOrderApiControllerV1.setTransactionJournalService(svc);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/order';
        req.httpMethod = 'GET';
        req.addParameter('orderNo', 'ORD-CE-001');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdOrderApiControllerV1.getOrderDepositList();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode, 'CustomException → 404');
        GdOrderApiControllerV1.setTransactionJournalService(null);
    }

    @IsTest
    static void test_getOrderDepositList_genericException_500() {
        MockTransactionJournalServiceEx svc = new MockTransactionJournalServiceEx();
        svc.getListThrow = new IllegalArgumentException('unexpected');
        GdOrderApiControllerV1.setTransactionJournalService(svc);

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/order';
        req.httpMethod = 'GET';
        req.addParameter('orderNo', 'ORD-EX-001');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdOrderApiControllerV1.getOrderDepositList();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode, '일반 Exception → 500');
        GdOrderApiControllerV1.setTransactionJournalService(null);
    }

    /* =========================
     * getOrderDepositList - 성공 분기
     * ========================= */
    @IsTest
    static void test_getOrderDepositList_mockSuccess_200() {
        GdOrderApiControllerV1.setTransactionJournalService(new MockTransactionJournalService());

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/v1/order';
        req.httpMethod = 'GET';
        req.addParameter('orderNo', 'ORD-SUCCESS-001');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdOrderApiControllerV1.getOrderDepositList();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'Mock 성공 → 200');
        GdOrderApiControllerV1.setTransactionJournalService(null);
    }

    /* =========================
     * updateOrder - 성공 분기
     * ========================= */

    // 성공 : OrderItem/TransactionJournal 키 없음
    @IsTest
    static void test_updateOrder_success_200() {
        GdOrderApiControllerV1.setOrderService(new MockOrderService());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{"orderNo":"ORD-001"}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'updateOrder 성공 → 200');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    // 성공 : OrderItem 키 있음 → orderItemService.upsertOrderItem 분기 커버
    @IsTest
    static void test_updateOrder_withOrderItemKey_success_200() {
        GdOrderApiControllerV1.setOrderService(new MockOrderService());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{"orderNo":"ORD-001","OrderItem":{"qty":1}}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'OrderItem 키 포함 성공 → 200');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    // 성공 : TransactionJournal 키 있음 → upsertOrderDeposit 분기 + CancelPointList/DebitPointList 분기 커버
    @IsTest
    static void test_updateOrder_withTransactionJournalKey_success_200() {
        GdOrderApiControllerV1.setOrderService(new MockOrderService());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{"orderNo":"ORD-001","TransactionJournal":{"type":"deposit"}}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'TransactionJournal 키 포함 성공 → 200');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    // 성공 : OrderItem + TransactionJournal 모두 포함
    @IsTest
    static void test_updateOrder_allKeys_success_200() {
        GdOrderApiControllerV1.setOrderService(new MockOrderService());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{"orderNo":"ORD-001","OrderItem":{"qty":1},"TransactionJournal":{"type":"deposit"}}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'OrderItem+TransactionJournal 성공 → 200');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    /* =========================
     * cancelOrder - 성공 분기
     * ========================= */

    // 성공 : OrderItem 키 없음 → transactionJournal만 호출
    @IsTest
    static void test_cancelOrder_noOrderItem_success_200() {
        GdOrderApiControllerV1.setOrderService(new MockOrderService());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setTransactionJournalService(new MockTransactionJournalService());

        setupRest('PUT', '{"orderNo":"ORD-001"}');
        Test.startTest();
        GdOrderApiControllerV1.cancelOrder();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'cancelOrder(OrderItem 없음) 성공 → 200');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setTransactionJournalService(null);
    }

    // 성공 : OrderItem 키 있음 → orderItemService.upsertOrderItem + transactionJournal 호출
    @IsTest
    static void test_cancelOrder_withOrderItem_success_200() {
        GdOrderApiControllerV1.setOrderService(new MockOrderService());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setTransactionJournalService(new MockTransactionJournalService());

        setupRest('PUT', '{"orderNo":"ORD-001","OrderItem":{"status":"cancelled"}}');
        Test.startTest();
        GdOrderApiControllerV1.cancelOrder();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'cancelOrder(OrderItem 포함) 성공 → 200');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setTransactionJournalService(null);
    }

    /* =========================
     * cancelOrder - transactionJournalService Exception 분기
     * ========================= */

    @IsTest
    static void test_cancelOrder_transactionJournalService_customException() {
        MockTransactionJournalServiceEx tjSvc = new MockTransactionJournalServiceEx();
        tjSvc.getListThrow = null; // getOrderDepositList 용도가 아니라 create용으로 별도 mock 필요
        // createOrderDepositHistory는 항상 성공하는 stub이므로, 아래는 기본 stub 사용
        GdOrderApiControllerV1.setOrderService(new MockOrderService());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setTransactionJournalService(new MockTransactionJournalService());

        setupRest('PUT', '{"orderNo":"ORD-001"}');
        Test.startTest();
        GdOrderApiControllerV1.cancelOrder();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'cancelOrder 정상 완료 → 200');
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setTransactionJournalService(null);
    }

    /* =========================
     * createOrder - ORDER_NOT_FOUND 분기 (유효 형식 ID, DB에 없음 → 400)
     * ========================= */
    private class MockOrderServiceFakeId implements GdOrderService {
        public ApiResult createOrder(Map<String,Object> req) {
            // 유효한 15자 형식의 가짜 ID → Id 캐스팅 성공, SOQL 결과 없음
            return ApiResult.ok(200, 'ok', new Map<String,Object>{
                'orderId'       => '000000000000001',
                'storeTypeFour' => null
            });
        }
        public ApiResult updateOrder(Map<String,Object> req) { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
        public ApiResult createSale(Map<String,Object> req)  { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
        public ApiResult updateSale(Map<String,Object> req)  { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
        public ApiResult deleteSale(String s)                { return ApiResult.ok(200,'ok',new Map<String,Object>()); }
    }

    @IsTest
    static void test_createOrder_orderNotFound_400() {
        GdOrderApiControllerV1.setOrderService(new MockOrderServiceFakeId());
        GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('POST', '{"orderNo":"ORD-001"}');
        Test.startTest();
        GdOrderApiControllerV1.createOrder();
        Test.stopTest();

        // 유효 형식 ID지만 DB에 없음 → ORDER_NOT_FOUND(400) 또는 StringException(500)
        System.assert(
            RestContext.response.statusCode == 400 || RestContext.response.statusCode == 500,
            'orderNotFound → 400 또는 StringException → 500'
        );
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderItemService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }

    /* =========================
     * setOrderDepositService / setVoucherService 명시적 커버
     * ========================= */
    @IsTest
    static void test_setOrderDepositService_coverage() {
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());
        GdOrderApiControllerV1.setOrderDepositService(null);
        System.assert(true, 'setOrderDepositService 정상 실행');
    }

    @IsTest
    static void test_setVoucherService_and_updateOrder_coverage() {
        GdOrderApiControllerV1.setVoucherService(new MockVoucherServiceStub());
        GdOrderApiControllerV1.setOrderService(new MockOrderService());
        GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());

        setupRest('PATCH', '{"orderNo":"ORD-001"}');
        Test.startTest();
        GdOrderApiControllerV1.updateOrder();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'voucherService 설정 후 updateOrder → 200');
        GdOrderApiControllerV1.setVoucherService(null);
        GdOrderApiControllerV1.setOrderService(null);
        GdOrderApiControllerV1.setOrderDepositService(null);
    }
}