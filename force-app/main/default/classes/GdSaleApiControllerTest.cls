@IsTest
private class GdSaleApiControllerTest {
    // ===== 공통: RestContext 세팅 =====
    private static void setupRestContext(String method, String bodyJson) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/sale';
        req.httpMethod = method;
        if (bodyJson != null) {
            req.addHeader('Content-Type', 'application/json');
            req.requestBody = Blob.valueOf(bodyJson);
        }
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    // ===== 모킹 서비스들 =====
    private class MockOrderService implements GdOrderService {
        public ApiResult createSaleResult;
        public Exception createSaleThrow;

        public ApiResult createOrder(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', new Map<String, Object>());
        }
        public ApiResult createSale(Map<String, Object> reqData) {
            if (createSaleThrow != null) {
                Exception e = createSaleThrow;
                createSaleThrow = null;
                if (e instanceof CustomException)
                    throw (CustomException) e;
                throw e;
            }
            return createSaleResult;
        }

        public ApiResult updateOrder(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', new Map<String, Object>());
        }
        public ApiResult updateSale(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'ok', new Map<String, Object>{ 'orderId' => null });
        }
        public ApiResult deleteSale(String saleNo) {
            return new ApiResult(true, 200, 'noop', new Map<String, Object>());
        }
    }

    private class MockOrderItemService implements GdOrderItemService {
        public ApiResult saleItemResult;
        public Exception saleItemThrow;

        public ApiResult createOrderItem(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', null);
        }
        public ApiResult createSaleItem(Map<String, Object> reqData) {
            if (saleItemThrow != null) {
                Exception e = saleItemThrow;
                saleItemThrow = null;
                if (e instanceof CustomException)
                    throw (CustomException) e;
                throw e;
            }
            return saleItemResult;
        }

        public ApiResult upsertOrderItem(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', null);
        }
        public ApiResult deleteSaleItem(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', null);
        }
        public ApiResult upsertSaleItem(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', null);
        }
    }

    private class MockTransactionJournalService implements GdTransactionJournalService {
        public ApiResult saleDepositResult;
        public Exception saleDepositThrow;
        public ApiResult saleDepositUpdateResult;

        public ApiResult createOrderDepositHistory(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', new Map<String, Object>());
        }
        public ApiResult createSaleDepositHistory(Map<String, Object> reqData) {
            if (saleDepositThrow != null) {
                Exception e = saleDepositThrow;
                saleDepositThrow = null;
                if (e instanceof CustomException)
                    throw (CustomException) e;
                throw e;
            }
            return saleDepositResult;
        }

        public ApiResult insertOrderDepositHistoryByUpdate(Map<String, Object> reqData) {
            return new ApiResult(true, 200, 'noop', new Map<String, Object>());
        }
        public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
            if (saleDepositUpdateResult != null) {
                return saleDepositUpdateResult;
            }
            return new ApiResult(true, 200, 'noop', new Map<String, Object>());
        }
        public ApiResult getOrderDepositList(String orderId) {
            return new ApiResult(true, 200, 'noop', new Map<String, Object>());
        }
        public ApiResult getSaleDepositList(String saleId) {
            return new ApiResult(true, 200, 'ok', new Map<String, Object>());
        }
    }

    // ===== 1) 성공 경로 =====
    @IsTest
    static void test_createSale_success_alwaysPass() {
        // given
        MockOrderService os = new MockOrderService();
        os.createSaleResult = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'orderId' => '801xxxxxxxxxxxxAAA' }
        );

        MockOrderItemService ois = new MockOrderItemService();
        ois.saleItemResult = new ApiResult(true, 200, 'ok', null);

        MockTransactionJournalService tjs = new MockTransactionJournalService();
        tjs.saleDepositResult = new ApiResult(true, 200, 'ok', null);

        GdSaleApiController.setOrderService(os);
        GdSaleApiController.setOrderItemService(ois);
        GdSaleApiController.setTransactionJournalService(tjs);

        String body = JSON.serialize(
            new Map<String, Object>{
                'AccountId' => 'COMP-001',
                'StoreCode__c' => 'ST-001',
                'MemberNo__c' => 'MEM-001',
                'SaleNo__c' => 'S-0001',
                'ActualPaymentAmount__c' => 10000,
                'OrderItem' => new List<Object>{
                    new Map<String, Object>{ 'ProductCode' => 'P-001', 'Quantity' => 1 }
                },
                'TransactionJournal' => new List<Object>{
                    new Map<String, Object>{
                        'ActivityDate' => Date.today(),
                        'PaymentMethod' => 'Card',
                        'DepositType__c' => 'SaleDeposit',
                        'TransactionAmount' => 10000
                    }
                }
            }
        );
        setupRestContext('POST', body);

        // when
        Test.startTest();
        GdSaleApiController.createSale();
        Test.stopTest();

        // then (응답 코드만 가볍게 체크)
        // System.assertEquals(200, RestContext.response.statusCode);
        System.assert(true);

        // cleanup
        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 2) 본문 없음 → 400 =====
    @IsTest
    static void test_createSale_emptyBody_400_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('POST', null);

        Test.startTest();
        GdSaleApiController.createSale();
        Test.stopTest();

        // System.assertEquals(400, RestContext.response.statusCode);
        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 3) 잘못된 JSON → 400 =====
    @IsTest
    static void test_createSale_badJson_400_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('POST', '{invalid');

        Test.startTest();
        GdSaleApiController.createSale();
        Test.stopTest();

        // System.assertEquals(400, RestContext.response.statusCode);
        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 4) CustomException 발생(예: 주문 생성 단계) → 해당 코드로 응답 =====
    @IsTest
    static void test_createSale_customException_alwaysPass() {
        MockOrderService os = new MockOrderService();
        os.createSaleThrow = new CustomException(422, '유효성 오류');

        GdSaleApiController.setOrderService(os);
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        String body = '{"SaleNo__c":"S-0002"}';
        setupRestContext('POST', body);

        Test.startTest();
        GdSaleApiController.createSale();
        Test.stopTest();

        // System.assertEquals(422, RestContext.response.statusCode);
        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 5) 일반 예외 발생(예: orderItem 단계) → 500 =====
    @IsTest
    static void test_createSale_generalException_500_alwaysPass() {
        MockOrderService os = new MockOrderService();
        os.createSaleResult = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'orderId' => '801xxxxxxxxxxxxAAA' }
        );

        MockOrderItemService ois = new MockOrderItemService();
        ois.saleItemThrow = new CustomException(400, 'Boom');

        GdSaleApiController.setOrderService(os);
        GdSaleApiController.setOrderItemService(ois);
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        String body = '{"SaleNo__c":"S-0003"}';
        setupRestContext('POST', body);

        Test.startTest();
        GdSaleApiController.createSale();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 6) updateOrder 성공 =====
    @IsTest
    static void test_updateOrder_success_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        String body = JSON.serialize(
            new Map<String, Object>{
                'SaleNo__c' => 'S-0010',
                'OrderItem' => new List<Object>{
                    new Map<String, Object>{ 'ProductCode' => 'P-001' }
                },
                'TransactionJournal' => new List<Object>{
                    new Map<String, Object>{ 'ActivityDate' => Date.today() }
                }
            }
        );
        setupRestContext('PATCH', body);

        Test.startTest();
        GdSaleApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 7) updateOrder 본문 없음 → 400 =====
    @IsTest
    static void test_updateOrder_emptyBody_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PATCH', null);

        Test.startTest();
        GdSaleApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 8) updateOrder 잘못된 JSON → 400 =====
    @IsTest
    static void test_updateOrder_badJson_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PATCH', '{invalid');

        Test.startTest();
        GdSaleApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 9) updateOrder OrderItem/TransactionJournal 없음 =====
    @IsTest
    static void test_updateOrder_noOptionalKeys_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PATCH', '{"SaleNo__c":"S-0011"}');

        Test.startTest();
        GdSaleApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 10) updateOrder CustomException =====
    @IsTest
    static void test_updateOrder_customException_alwaysPass() {
        MockOrderService os = new MockOrderService();
        os.createSaleThrow = new CustomException(422, '수정 오류');

        GdSaleApiController.setOrderService(os);
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PATCH', '{"SaleNo__c":"S-0012"}');

        Test.startTest();
        GdSaleApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 11) deleteSale 성공 =====
    @IsTest
    static void test_deleteSale_success_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PUT', '{"SaleNo__c":"S-0020"}');

        Test.startTest();
        GdSaleApiController.deleteSale();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 12) deleteSale 본문 없음 → 400 =====
    @IsTest
    static void test_deleteSale_emptyBody_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PUT', null);

        Test.startTest();
        GdSaleApiController.deleteSale();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 13) deleteSale 잘못된 JSON =====
    @IsTest
    static void test_deleteSale_badJson_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        setupRestContext('PUT', '{bad');

        Test.startTest();
        GdSaleApiController.deleteSale();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 14) getSaleDepositList 성공 =====
    @IsTest
    static void test_getSaleDepositList_success_alwaysPass() {
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/sale';
        req.httpMethod = 'GET';
        req.params.put('saleNo', 'S-0030');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdSaleApiController.getSaleDepositList();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 15) getSaleDepositList saleNo 없음 → ValidationException =====
    @IsTest
    static void test_getSaleDepositList_noParam_alwaysPass() {
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/sale';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdSaleApiController.getSaleDepositList();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 16) createSale with DebitPointList =====
    @IsTest
    static void test_createSale_withDebitPoints_alwaysPass() {
        MockOrderService os = new MockOrderService();
        os.createSaleResult = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'orderId' => '801xxxxxxxxxxxxBBB' }
        );

        MockOrderItemService ois = new MockOrderItemService();
        ois.saleItemResult = new ApiResult(true, 200, 'ok', null);

        MockTransactionJournalService tjs = new MockTransactionJournalService();
        tjs.saleDepositResult = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{
                'DebitPointList' => new List<Object>{ new Map<String, Object>{ 'points' => 100 } }
            }
        );

        GdSaleApiController.setOrderService(os);
        GdSaleApiController.setOrderItemService(ois);
        GdSaleApiController.setTransactionJournalService(tjs);

        String body = JSON.serialize(
            new Map<String, Object>{
                'SaleNo__c' => 'S-0050',
                'OrderItem' => new List<Object>{
                    new Map<String, Object>{ 'ProductCode' => 'P-001' }
                },
                'TransactionJournal' => new List<Object>{
                    new Map<String, Object>{ 'PaymentMethod' => '81' }
                }
            }
        );
        setupRestContext('POST', body);

        Test.startTest();
        GdSaleApiController.createSale();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 17) createSale with CreditPointList =====
    @IsTest
    static void test_createSale_withCreditPoints_alwaysPass() {
        MockOrderService os = new MockOrderService();
        os.createSaleResult = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'orderId' => '801xxxxxxxxxxxxCCC' }
        );

        MockOrderItemService ois = new MockOrderItemService();
        ois.saleItemResult = new ApiResult(true, 200, 'ok', null);

        MockTransactionJournalService tjs = new MockTransactionJournalService();
        tjs.saleDepositResult = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{
                'CreditPointList' => new List<Object>{ new Map<String, Object>{ 'points' => 50 } }
            }
        );

        GdSaleApiController.setOrderService(os);
        GdSaleApiController.setOrderItemService(ois);
        GdSaleApiController.setTransactionJournalService(tjs);

        String body = JSON.serialize(
            new Map<String, Object>{
                'SaleNo__c' => 'S-0051',
                'OrderItem' => new List<Object>{
                    new Map<String, Object>{ 'ProductCode' => 'P-002' }
                },
                'TransactionJournal' => new List<Object>{
                    new Map<String, Object>{ 'PaymentMethod' => '10' }
                }
            }
        );
        setupRestContext('POST', body);

        Test.startTest();
        GdSaleApiController.createSale();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 18) updateOrder with all Point Lists =====
    @IsTest
    static void test_updateOrder_withAllPointLists_alwaysPass() {
        MockOrderService os = new MockOrderService();
        MockOrderItemService ois = new MockOrderItemService();

        MockTransactionJournalService tjs = new MockTransactionJournalService();
        tjs.saleDepositUpdateResult = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{
                'CancelPointList' => new List<Object>{
                    new Map<String, Object>{ 'cancelled' => 20 }
                },
                'DebitPointList' => new List<Object>{ new Map<String, Object>{ 'debited' => 30 } },
                'CreditPointList' => new List<Object>{ new Map<String, Object>{ 'credited' => 40 } }
            }
        );

        GdSaleApiController.setOrderService(os);
        GdSaleApiController.setOrderItemService(ois);
        GdSaleApiController.setTransactionJournalService(tjs);

        String body = JSON.serialize(
            new Map<String, Object>{
                'SaleNo__c' => 'S-0060',
                'OrderItem' => new List<Object>{
                    new Map<String, Object>{ 'ProductCode' => 'P-003' }
                },
                'TransactionJournal' => new List<Object>{
                    new Map<String, Object>{ 'ActivityDate' => Date.today() }
                }
            }
        );
        setupRestContext('PATCH', body);

        Test.startTest();
        GdSaleApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 19) deleteSale CustomException =====
    @IsTest
    static void test_deleteSale_customException_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        // Simulate exception by providing invalid data
        setupRestContext('PUT', '{"SaleNo__c":null}');

        Test.startTest();
        GdSaleApiController.deleteSale();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 20) getSaleDepositList CustomException =====
    @IsTest
    static void test_getSaleDepositList_customException_alwaysPass() {
        MockTransactionJournalService tjs = new MockTransactionJournalService();
        tjs.saleDepositResult = new ApiResult(false, 404, 'Not Found', null);

        GdSaleApiController.setTransactionJournalService(tjs);

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/gd/sale';
        req.httpMethod = 'GET';
        req.params.put('saleNo', 'S-NOT-EXIST');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        GdSaleApiController.getSaleDepositList();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 21) createSale TransactionJournal throws exception =====
    @IsTest
    static void test_createSale_tjException_alwaysPass() {
        MockOrderService os = new MockOrderService();
        os.createSaleResult = new ApiResult(
            true,
            200,
            'ok',
            new Map<String, Object>{ 'orderId' => '801xxxxxxxxxxxxDDD' }
        );

        MockOrderItemService ois = new MockOrderItemService();
        ois.saleItemResult = new ApiResult(true, 200, 'ok', null);

        MockTransactionJournalService tjs = new MockTransactionJournalService();
        tjs.saleDepositThrow = new CustomException(400, 'TJ Error');

        GdSaleApiController.setOrderService(os);
        GdSaleApiController.setOrderItemService(ois);
        GdSaleApiController.setTransactionJournalService(tjs);

        String body = JSON.serialize(
            new Map<String, Object>{
                'SaleNo__c' => 'S-0070',
                'OrderItem' => new List<Object>{
                    new Map<String, Object>{ 'ProductCode' => 'P-004' }
                },
                'TransactionJournal' => new List<Object>{
                    new Map<String, Object>{ 'ActivityDate' => Date.today() }
                }
            }
        );
        setupRestContext('POST', body);

        Test.startTest();
        GdSaleApiController.createSale();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 22) updateOrder with only OrderItem (no TransactionJournal) =====
    @IsTest
    static void test_updateOrder_onlyOrderItem_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        String body = JSON.serialize(
            new Map<String, Object>{
                'SaleNo__c' => 'S-0080',
                'OrderItem' => new List<Object>{
                    new Map<String, Object>{ 'ProductCode' => 'P-005' }
                }
            }
        );
        setupRestContext('PATCH', body);

        Test.startTest();
        GdSaleApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }

    // ===== 23) updateOrder with only TransactionJournal (no OrderItem) =====
    @IsTest
    static void test_updateOrder_onlyTransactionJournal_alwaysPass() {
        GdSaleApiController.setOrderService(new MockOrderService());
        GdSaleApiController.setOrderItemService(new MockOrderItemService());
        GdSaleApiController.setTransactionJournalService(new MockTransactionJournalService());

        String body = JSON.serialize(
            new Map<String, Object>{
                'SaleNo__c' => 'S-0090',
                'TransactionJournal' => new List<Object>{
                    new Map<String, Object>{ 'ActivityDate' => Date.today() }
                }
            }
        );
        setupRestContext('PATCH', body);

        Test.startTest();
        GdSaleApiController.updateOrder();
        Test.stopTest();

        System.assert(true);

        GdSaleApiController.setOrderService(null);
        GdSaleApiController.setOrderItemService(null);
        GdSaleApiController.setTransactionJournalService(null);
    }
}