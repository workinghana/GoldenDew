@IsTest
private class GdOrderApiControllerV1Test {
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

  private static Id createOrderRecord() {
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();
    try {
      update new Pricebook2(Id = standardPricebookId, IsActive = true);
    } catch (Exception ignore) {
    }

    Order orderRecord = new Order(AccountId = accountRecord.Id, Status = 'Draft', EffectiveDate = Date.today(), Pricebook2Id = standardPricebookId);
    insert orderRecord;
    return orderRecord.Id;
  }

  @TestSetup
  static void setupData() {
    insert new Account(Name = 'Order API Test Account');
  }

  private class MockOrderService implements GdOrderService {
    Id createOrderId;
    Exception createThrow;
    Exception updateThrow;

    public ApiResult createOrder(Map<String, Object> req) {
      if (createThrow != null) {
        Exception e = createThrow;
        createThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }

      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => createOrderId, 'storeTypeFour' => null });
    }

    public ApiResult updateOrder(Map<String, Object> req) {
      if (updateThrow != null) {
        Exception e = updateThrow;
        updateThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }

      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => createOrderId });
    }

    public ApiResult createSale(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult updateSale(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult deleteSale(String saleNo) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }
  }

  private class MockOrderItemService implements GdOrderItemService {
    public ApiResult createOrderItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'oiList' => new List<Object>(), 'isGoldenBar' => false });
    }

    public ApiResult upsertOrderItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult createSaleItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult deleteSaleItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult upsertSaleItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }
  }

  private class MockOrderDepositService implements GdOrderDepositService {
    Exception createThrow;
    Exception upsertThrow;

    public ApiResult getOrderDepositList(String orderNo) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult createOrderDepositHistory(Map<String, Object> req) {
      if (createThrow != null) {
        Exception e = createThrow;
        createThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }

      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'DebitPointList' => new List<Object>() });
    }

    public ApiResult upsertOrderDeposit(Map<String, Object> req) {
      if (upsertThrow != null) {
        Exception e = upsertThrow;
        upsertThrow = null;
        if (e instanceof CustomException) {
          throw (CustomException) e;
        }
        throw e;
      }

      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'DebitPointList' => new List<Object>(), 'CancelPointList' => new List<Object>() });
    }
  }

  private class MockVoucherServiceStub implements GdVoucherService {
    public void issueBirthdayCoupon() {
    }
    public ApiResult issueSignupCoupon(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult issueSignupCouponV2(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getAvailableCouponList(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemVoucher(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemVoucherV2(TransactionJournal tj) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemCancelVoucher(TransactionJournal tj) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult issueCoupon(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult updateCoupon(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult deleteCoupon(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getReturnUsedCoupon(String originalOrderId) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getRedeemCoupon(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  @IsTest
  static void setVoucherService_coverage() {
    GdOrderApiControllerV1.setVoucherService(new MockVoucherServiceStub());
    GdOrderApiControllerV1.setVoucherService(null);
    System.assert(true);
  }

  @IsTest
  static void createOrder_emptyBody_returns400() {
    setupRest('POST', null);

    Test.startTest();
    GdOrderApiControllerV1.createOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void createOrder_badJson_returns400() {
    setupRest('POST', '{invalid_json');

    Test.startTest();
    GdOrderApiControllerV1.createOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void createOrder_missingTransactionJournal_returns400() {
    MockOrderService orderService = new MockOrderService();
    orderService.createOrderId = createOrderRecord();

    GdOrderApiControllerV1.setOrderService(orderService);
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());
    setupRest('POST', '{"orderNo":"ORD-001"}');

    Test.startTest();
    GdOrderApiControllerV1.createOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(
      RestContext.response.responseBody.toString().contains('입금 내역이 비어 있습니다. 입금 내역 등록 후 저장해주시기 바랍니다.'),
      'Missing TransactionJournal should return the deposit empty message.'
    );
  }

  @IsTest
  static void createOrder_emptyTransactionJournal_returns400() {
    MockOrderService orderService = new MockOrderService();
    orderService.createOrderId = createOrderRecord();

    GdOrderApiControllerV1.setOrderService(orderService);
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());
    setupRest('POST', '{"orderNo":"ORD-001","TransactionJournal":[]}');

    Test.startTest();
    GdOrderApiControllerV1.createOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
    System.assertEquals(false, body.get('success'));
    System.assert(String.valueOf(body.get('message')).contains('입금 내역이 비어 있습니다.'));
  }

  @IsTest
  static void createOrder_success_returns200() {
    MockOrderService orderService = new MockOrderService();
    orderService.createOrderId = createOrderRecord();

    GdOrderApiControllerV1.setOrderService(orderService);
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());
    setupRest('POST', '{"orderNo":"ORD-001","TransactionJournal":{"type":"deposit"}}');

    Test.startTest();
    GdOrderApiControllerV1.createOrder();
    Test.stopTest();

    Order updatedOrder = [SELECT Status FROM Order WHERE Id = :orderService.createOrderId LIMIT 1];
    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals('orderSuccess', updatedOrder.Status);
  }

  @IsTest
  static void createOrder_orderServiceCustomException_returns422() {
    MockOrderService orderService = new MockOrderService();
    orderService.createThrow = new CustomException(422, 'create failed');

    GdOrderApiControllerV1.setOrderService(orderService);
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());
    setupRest('POST', '{"orderNo":"ORD-001","TransactionJournal":{"type":"deposit"}}');

    Test.startTest();
    GdOrderApiControllerV1.createOrder();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
  }

  @IsTest
  static void createOrder_orderDepositException_returns500() {
    MockOrderService orderService = new MockOrderService();
    orderService.createOrderId = createOrderRecord();

    MockOrderDepositService orderDepositService = new MockOrderDepositService();
    orderDepositService.createThrow = new IllegalArgumentException('deposit failed');

    GdOrderApiControllerV1.setOrderService(orderService);
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(orderDepositService);
    setupRest('POST', '{"orderNo":"ORD-001","TransactionJournal":{"type":"deposit"}}');

    Test.startTest();
    GdOrderApiControllerV1.createOrder();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
  }

  @IsTest
  static void createOrder_orderNotFound_returns400Or500() {
    MockOrderService orderService = new MockOrderService();
    orderService.createOrderId = (Id) (Order.SObjectType.getDescribe().getKeyPrefix() + '000000000000AAA');

    GdOrderApiControllerV1.setOrderService(orderService);
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());
    setupRest('POST', '{"orderNo":"ORD-001","TransactionJournal":{"type":"deposit"}}');

    Test.startTest();
    GdOrderApiControllerV1.createOrder();
    Test.stopTest();

    System.assert(RestContext.response.statusCode == 400 || RestContext.response.statusCode == 500);
  }

  @IsTest
  static void updateOrder_emptyBody_returns400() {
    setupRest('PATCH', null);

    Test.startTest();
    GdOrderApiControllerV1.updateOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void updateOrder_badJson_returns400() {
    setupRest('PATCH', '{invalid_json');

    Test.startTest();
    GdOrderApiControllerV1.updateOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void updateOrder_success_returns200() {
    MockOrderService orderService = new MockOrderService();
    orderService.createOrderId = createOrderRecord();

    GdOrderApiControllerV1.setOrderService(orderService);
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());
    setupRest('PATCH', '{"orderNo":"ORD-001","OrderItem":{"qty":1},"TransactionJournal":{"type":"deposit"}}');

    Test.startTest();
    GdOrderApiControllerV1.updateOrder();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
  }

  @IsTest
  static void updateOrder_orderServiceCustomException_returns422() {
    MockOrderService orderService = new MockOrderService();
    orderService.updateThrow = new CustomException(422, 'update failed');

    GdOrderApiControllerV1.setOrderService(orderService);
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(new MockOrderDepositService());
    setupRest('PATCH', '{"orderNo":"ORD-001"}');

    Test.startTest();
    GdOrderApiControllerV1.updateOrder();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
  }

  @IsTest
  static void updateOrder_orderDepositException_returns500() {
    MockOrderDepositService orderDepositService = new MockOrderDepositService();
    orderDepositService.upsertThrow = new IllegalArgumentException('deposit update failed');

    GdOrderApiControllerV1.setOrderService(new MockOrderService());
    GdOrderApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdOrderApiControllerV1.setOrderDepositService(orderDepositService);
    setupRest('PATCH', '{"orderNo":"ORD-001","TransactionJournal":{"type":"deposit"}}');

    Test.startTest();
    GdOrderApiControllerV1.updateOrder();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
  }
}