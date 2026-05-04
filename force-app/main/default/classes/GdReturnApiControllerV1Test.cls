@IsTest
private class GdReturnApiControllerV1Test {
  @TestSetup
  static void setupData() {
    Account acc = new Account(Name = 'Return API Test Account');
    insert acc;

    Id standardPricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = standardPricebookId, IsActive = true);

    Product2 product = new Product2(Name = 'Return API Product', ProductCode = 'RET-API-001', IsActive = true);
    insert product;

    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = product.Id, UnitPrice = 1000, IsActive = true);
    insert pbe;

    Order originalOrder = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = standardPricebookId,
      OrderNo__c = 'RET-API-ORIGINAL',
      SaleNo__c = 'RET-API-ORIGINAL-SALE'
    );
    insert originalOrder;

    OrderItem originalOrderItem = new OrderItem(
      OrderId = originalOrder.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 1000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = 'RET-API-ORIGINAL-1'
    );
    insert originalOrderItem;

    originalOrder.Status = 'saleSuccess';
    update originalOrder;

    Order returnOrder = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = standardPricebookId,
      OrderNo__c = 'RET-API-RETURN',
      SaleNo__c = 'RET-API-RETURN-SALE',
      OriginalOrderId__c = originalOrder.Id,
      IsReductionOrder__c = true
    );
    insert returnOrder;

    insert new OrderItem(
      OrderId = returnOrder.Id,
      PricebookEntryId = pbe.Id,
      Quantity = -1,
      UnitPrice = 1000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = 'RET-API-RETURN-1',
      OriginalOrderItemId__c = originalOrderItem.Id
    );
  }

  private static void setupRestContext(String method, String uri, String bodyJson, Map<String, String> params) {
    RestRequest req = new RestRequest();
    req.requestURI = uri;
    req.httpMethod = method;

    if (bodyJson != null) {
      req.addHeader('Content-Type', 'application/json');
      req.requestBody = Blob.valueOf(bodyJson);
    }

    if (params != null) {
      req.params.putAll(params);
    }

    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  private static Map<String, Object> parseResponseBody() {
    return RestContext.response.responseBody == null
      ? null
      : (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
  }

  private static Id getOriginalOrderId() {
    return [SELECT Id FROM Order WHERE OrderNo__c = 'RET-API-ORIGINAL' LIMIT 1].Id;
  }

  private static Id getReturnOrderId() {
    return [SELECT Id FROM Order WHERE OrderNo__c = 'RET-API-RETURN' LIMIT 1].Id;
  }

  private class MockReturnService implements GdReturnService {
    public ApiResult createReturn(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => getReturnOrderId(), 'originalOrderId' => getOriginalOrderId() });
    }

    public ApiResult deleteReturn(String saleNo) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => getReturnOrderId() });
    }
  }

  private class MockReturnItemService implements GdReturnItemService {
    public ApiResult createReturnItem(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteReturnItem(Id orderId) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockReturnDepositService implements GdReturnDepositService {
    public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
      return ApiResult.ok(
        200,
        'ok',
        new Map<String, Object>{
          'CancelPointList' => new List<Object>(),
          'DebitPointList' => new List<Object>(),
          'CreditPointList' => new List<Object>(),
          'CancelPointsCreditedList' => new List<Object>()
        }
      );
    }

    public ApiResult getAllReturnDeposits(Id orderId) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteReturnDeposit(String returnNo) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteAllReturnDeposits(Id orderId) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockPointService implements GdPointService {
    public ApiResult creditPoint(Map<String, Object> reqData) {
      return null;
    }

    public ApiResult creditEcopoint(Map<String, Object> reqData) {
      return null;
    }

    public Double getPointList(Map<String, Object> reqData) {
      return 0;
    }

    public ApiResult getPointApplyHelp(Map<String, Object> reqData) {
      return null;
    }

    public ApiResult getPointApplyHelpV2(Map<String, Object> reqData) {
      return null;
    }

    public ApiResult getDebitPointList(Map<String, Object> reqData) {
      return null;
    }

    public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj) {
      return new List<GdSaleApiController.PointDebitDTO>();
    }

    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return new List<GdSaleApiController.PointDebitDTO>();
    }

    public List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList) {
      return new List<PointDebitDTO>();
    }

    public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return new List<PointCreditDTO>();
    }

    public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return new List<PointDebitDTO>();
    }

    public List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList) {
      return new List<PointCreditDTO>();
    }

    public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
      return new List<PointCreditDTO>();
    }

    public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
      return new List<PointCreditDTO>();
    }

    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }

    public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }

    public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
      return new Map<String, Object>();
    }

    public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
      return new List<GdSaleApiController.PointDebitDTO>();
    }

    public ApiResult deletePoint(Map<String, Object> reqData) {
      return null;
    }

    public Boolean isAccrualEligible(TransactionJournal tj) {
      return true;
    }

    public ApiResult updatePoint(Map<String, Object> reqData) {
      return null;
    }
  }

  private static void setMockServices() {
    GdReturnApiControllerV1.setReturnService(new MockReturnService());
    GdReturnApiControllerV1.setReturnItemService(new MockReturnItemService());
    GdReturnApiControllerV1.setReturnDepositService(new MockReturnDepositService());
    GdReturnApiControllerV1.setPointService(new MockPointService());
  }

  @IsTest
  static void createReturn_emptyBody_returns400() {
    setupRestContext('POST', '/services/apexrest/gd/v1/return', null, null);

    Test.startTest();
    GdReturnApiControllerV1.createReturn();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void createReturn_badJson_returns400() {
    setupRestContext('POST', '/services/apexrest/gd/v1/return', '{invalid', null);

    Test.startTest();
    GdReturnApiControllerV1.createReturn();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void createReturn_success_updatesOrderStatus() {
    setMockServices();
    setupRestContext('POST', '/services/apexrest/gd/v1/return', '{"OrderItem":[],"TransactionJournal":[]}', null);

    Test.startTest();
    GdReturnApiControllerV1.createReturn();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Id returnOrderId = getReturnOrderId();
    System.assertEquals('returnSuccess', [SELECT Status FROM Order WHERE Id = :returnOrderId LIMIT 1].Status);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void deleteReturn_success_updatesOrderStatus() {
    setMockServices();
    setupRestContext('DELETE', '/services/apexrest/gd/v1/return', null, new Map<String, String>{ 'SaleNo__c' => 'RET-API-RETURN-SALE' });

    Test.startTest();
    GdReturnApiControllerV1.deleteReturn();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Id returnOrderId = getReturnOrderId();
    System.assertEquals('returnDeleted', [SELECT Status FROM Order WHERE Id = :returnOrderId LIMIT 1].Status);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void doGet_coupon_returns200() {
    setupRestContext('GET', '/services/apexrest/gd/v1/return/coupon', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-002' });

    Test.startTest();
    GdReturnApiControllerV1.doGet();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void doGet_point_returns200() {
    setupRestContext('GET', '/services/apexrest/gd/v1/return/point', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-003' });

    Test.startTest();
    GdReturnApiControllerV1.doGet();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void doGet_invalidSubPath_returns500() {
    setupRestContext('GET', '/services/apexrest/gd/v1/return/unknown', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-999' });

    Test.startTest();
    GdReturnApiControllerV1.doGet();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }
}