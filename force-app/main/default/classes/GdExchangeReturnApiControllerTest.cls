@IsTest
private class GdExchangeReturnApiControllerTest {
  /* ===============================
   * OrderService Stub
   * =============================== */
  private class OrderServiceStub implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbed,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      if (methodName == 'createOrder' || methodName == 'updateOrder') {
        return ApiResult.ok(200, 'OK', new Map<String, Object>{ 'orderId' => 'ORD-001' });
      }
      return null;
    }
  }

  /* ===============================
   * OrderItemService Stub
   * =============================== */
  private class OrderItemServiceStub implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbed,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      return ApiResult.ok(200, 'OK', null);
    }
  }

  /* ===============================
   * TransactionJournalService Stub
   * =============================== */
  private class TransactionJournalServiceStub implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbed,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      if (methodName == 'createOrderDepositHistory' || methodName == 'insertOrderDepositHistoryByUpdate') {
        return ApiResult.ok(200, 'OK', new Map<String, Object>{ 'DebitPointList' => new List<Object>(), 'CancelPointList' => new List<Object>() });
      }

      if (methodName == 'getOrderDepositList') {
        return ApiResult.ok(200, 'OK', new Map<String, Object>{ 'list' => new List<Object>() });
      }
      return null;
    }
  }

  /* ===============================
   * createOrder - success
   * =============================== */
  @IsTest
  static void test_createOrder_success() {
    injectStubs();

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{ "orderNo":"ORD001" }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.createOrder();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
  }

  /* ===============================
   * createOrder - invalid JSON
   * =============================== */
  @IsTest
  static void test_createOrder_invalidJson() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{ invalid json }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.createOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  /* ===============================
   * updateOrder - success
   * =============================== */
  @IsTest
  static void test_updateOrder_success() {
    injectStubs();

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'PATCH';
    req.requestBody = Blob.valueOf('{ "orderNo":"ORD001", "OrderItem":{}, "TransactionJournal":{} }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.updateOrder();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
  }

  /* ===============================
   * cancelOrder - success
   * =============================== */
  @IsTest
  static void test_cancelOrder_success() {
    injectStubs();

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'PUT';
    req.requestBody = Blob.valueOf('{ "orderNo":"ORD001" }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.cancelOrder();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
  }

  /* ===============================
   * getOrderDepositList - success
   * =============================== */
  @IsTest
  static void test_getOrderDepositList_success() {
    GdExchangeReturnApiController.setTransactionJournalService(
      (GdTransactionJournalService) Test.createStub(GdTransactionJournalService.class, new TransactionJournalServiceStub())
    );

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'GET';
    req.addParameter('orderNo', 'ORD001');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.getOrderDepositList();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
  }

  /* ===============================
   * getOrderDepositList - validation fail
   * =============================== */
  @IsTest
  static void test_getOrderDepositList_validationFail() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'GET';

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.getOrderDepositList();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void test_createOrder_emptyBody() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(''); // 빈 바디

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.createOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void test_updateOrder_emptyBody() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'PATCH';
    req.requestBody = Blob.valueOf(''); // 빈 바디

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.updateOrder();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }
  @IsTest
  static void test_updateOrder_withoutOptionalBlocks() {
    injectStubs();

    // OrderItem / TransactionJournal 키 일부러 제거
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/exchangeReturn';
    req.httpMethod = 'PATCH';
    req.requestBody = Blob.valueOf('{ "orderNo":"ORD001" }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdExchangeReturnApiController.updateOrder();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
  }

  /* ===============================
   * 공통 Stub 주입
   * =============================== */
  private static void injectStubs() {
    GdExchangeReturnApiController.setOrderService((GdOrderService) Test.createStub(GdOrderService.class, new OrderServiceStub()));
    GdExchangeReturnApiController.setOrderItemService((GdOrderItemService) Test.createStub(GdOrderItemService.class, new OrderItemServiceStub()));
    GdExchangeReturnApiController.setTransactionJournalService(
      (GdTransactionJournalService) Test.createStub(GdTransactionJournalService.class, new TransactionJournalServiceStub())
    );
  }
}
