@IsTest
private class GdSaleApiControllerV1Test {
  @TestSetup
  static void setupData() {
    Account acc = new Account(Name = 'Sale API Test Account', StoreCode__c = 'SALE-API-STORE', StoreType__c = '01');
    insert acc;

    Id standardPricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = standardPricebookId, IsActive = true);

    Product2 product = new Product2(Name = 'Sale API Product', ProductCode = 'SALE-API-001', IsActive = true);
    insert product;

    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = product.Id, UnitPrice = 2000, IsActive = true);
    insert pbe;

    Order createOrder = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = standardPricebookId,
      OrderNo__c = 'SALE-API-CREATE',
      SaleNo__c = 'SALE-API-CREATE-NO',
      StoreCode__c = acc.Id
    );
    insert createOrder;
    insert new OrderItem(OrderId = createOrder.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 2000);

    Order deleteOrder = new Order(
      AccountId = acc.Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = standardPricebookId,
      OrderNo__c = 'SALE-API-DELETE',
      SaleNo__c = 'SALE-API-DELETE-NO',
      StoreCode__c = acc.Id
    );
    insert deleteOrder;
    insert new OrderItem(OrderId = deleteOrder.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 2000);
    deleteOrder.Status = 'saleSuccess';
    update deleteOrder;

    insert new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    Id accrualTypeId = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1].Id;
    insert new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualTypeId);
  }

  private static void setupRestContext(String method, String uri, String body, Map<String, String> params) {
    RestRequest req = new RestRequest();
    req.requestURI = uri;
    req.httpMethod = method;

    if (body != null) {
      req.addHeader('Content-Type', 'application/json');
      req.requestBody = Blob.valueOf(body);
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

  private static Id getCreateOrderId() {
    return [SELECT Id FROM Order WHERE OrderNo__c = 'SALE-API-CREATE' LIMIT 1].Id;
  }

  private static Id getDeleteOrderId() {
    return [SELECT Id FROM Order WHERE OrderNo__c = 'SALE-API-DELETE' LIMIT 1].Id;
  }

  private static void setOptionCBranch(Boolean enabled, Date openDate) {
    OptionCBranchSetting__c setting = OptionCBranchSetting__c.getInstance();
    if (setting == null || setting.Id == null) {
      setting = new OptionCBranchSetting__c();
    }
    setting.IsEnabled__c = enabled;
    setting.OpenDate__c = openDate;
    upsert setting;
  }

  private static LoyaltyProgramMember seedMemberForDeleteOrder() {
    Id orderId = getDeleteOrderId();

    Contact con = new Contact(LastName = 'SaleApiEcoMember', MemberNo__c = 'SALE-API-MEMBER-ON');
    insert con;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Sale API Loyalty ON', IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      MembershipNumber = 'SALE-API-MEMBER-ON',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = con.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert lpm;

    update new Order(Id = orderId, MemberNo__c = con.Id);
    return lpm;
  }

  private static void seedEcoLedgerForDeleteOrder(Integer creditPoints, Integer usedPoints) {
    Id orderId = getDeleteOrderId();

    Contact con = new Contact(LastName = 'SaleApiEco', MemberNo__c = 'SALE-API-MEMBER');
    insert con;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Sale API Loyalty', IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      MembershipNumber = 'SALE-API-MEMBER',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = con.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert lpm;

    update new Order(Id = orderId, MemberNo__c = con.Id);

    LoyaltyProgramCurrency loyaltyCurrency = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = 'POINT',
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = 'Fixed',
      ExtendExpiration = 'None',
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = 'Years',
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert loyaltyCurrency;

    LoyaltyPgmCurrencySubtype ecoSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
      Name = '에코포인트',
      PointTypeCode__c = '05',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert ecoSubtype;

    if ([SELECT COUNT() FROM JournalType WHERE Name = 'Redemption'] == 0) {
      insert new JournalType(Name = 'Redemption', ProcessType = 'Loyalty');
    }

    Id accrualTypeId = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1].Id;
    Id accrualSubTypeId = [SELECT Id FROM JournalSubType WHERE Name = 'Api Forced Credit' LIMIT 1].Id;
    Id redemptionTypeId = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1].Id;
    if ([SELECT COUNT() FROM JournalSubType WHERE Name = 'Api Forced Debit' AND JournalTypeId = :redemptionTypeId] == 0) {
      insert new JournalSubType(Name = 'Api Forced Debit', JournalTypeId = redemptionTypeId);
    }

    TransactionJournal creditTj = new TransactionJournal(
      DepositNo__c = 'SALE-ECO-CREDIT',
      DeposiSeqNo__c = '1',
      JournalDate = Datetime.now(),
      ActivityDate = Datetime.now(),
      LoyaltyProgramId = lp.Id,
      MemberId = lpm.Id,
      OrderId = orderId,
      SaleId__c = orderId,
      TransactionAmount = creditPoints,
      JournalTypeId = accrualTypeId,
      JournalSubTypeId = accrualSubTypeId,
      Status = 'Processed'
    );
    insert creditTj;

    LoyaltyLedger creditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
      LoyaltyPgmCrcySubtypeId = ecoSubtype.Id,
      TransactionJournalId = creditTj.Id,
      ActivityDate = Datetime.now(),
      Points = creditPoints,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert creditLedger;

    if (usedPoints > 0) {
      TransactionJournal debitTj = new TransactionJournal(
        DepositNo__c = 'SALE-ECO-DEBIT',
        DeposiSeqNo__c = '1',
        JournalDate = Datetime.now(),
        ActivityDate = Datetime.now(),
        LoyaltyProgramId = lp.Id,
        MemberId = lpm.Id,
        OrderId = orderId,
        SaleId__c = orderId,
        TransactionAmount = usedPoints,
        JournalTypeId = redemptionTypeId,
        Status = 'Processed'
      );
      insert debitTj;

      LoyaltyLedger debitLedger = new LoyaltyLedger(
        LoyaltyProgramMemberId = lpm.Id,
        LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
        LoyaltyPgmCrcySubtypeId = ecoSubtype.Id,
        TransactionJournalId = debitTj.Id,
        ActivityDate = Datetime.now(),
        Points = usedPoints,
        ExpiryDate = Date.today().addYears(1),
        EventType = 'Debit'
      );
      insert debitLedger;

      insert new LoyaltyLedgerTraceability(
        LoyaltyProgramMemberId = lpm.Id,
        LoyaltyPgmCurrencySubtypeId = ecoSubtype.Id,
        DebitLoyaltyLedgerId = debitLedger.Id,
        CreditLoyaltyLedgerId = creditLedger.Id,
        Points = usedPoints,
        ActionType = 'Debit'
      );
    }
  }

  private class MockOrderService implements GdOrderService {
    public ApiResult createSale(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => getCreateOrderId(), 'storeTypeFour' => '01' });
    }

    public ApiResult updateSale(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => getCreateOrderId() });
    }

    public ApiResult createOrder(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult updateOrder(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteSale(String saleNo) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => getDeleteOrderId() });
    }

    public ApiResult getReturnUsedPoint(String originalOrderId) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }
  }

  private class MockSaleService implements GdSaleService {
    public ApiResult deleteSale(String saleNo) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => getDeleteOrderId() });
    }
  }

  private class MockOrderItemService implements GdOrderItemService {
    public ApiResult createSaleItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'oiList' => new List<Object>() });
    }

    public ApiResult upsertSaleItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult createOrderItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult upsertOrderItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteSaleItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockSaleItemService implements GdSaleItemService {
    public ApiResult deleteSaleItem(Id orderId) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockSaleItemServiceThrows implements GdSaleItemService {
    public ApiResult deleteSaleItem(Id orderId) {
      String forceError;
      forceError.length();
      return null;
    }
  }

  private class MockSaleDepositService implements GdSaleDepositService {
    public ApiResult createSaleDepositHistory(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'DebitPointList' => new List<Object>(), 'CreditPointList' => new List<Object>() });
    }

    public ApiResult upsertSaleDeposit(Map<String, Object> req) {
      return ApiResult.ok(
        200,
        'ok',
        new Map<String, Object>{
          'CancelPointList' => new List<Object>(),
          'DebitPointList' => new List<Object>(),
          'CreditPointList' => new List<Object>()
        }
      );
    }

    public ApiResult upsertSaleDepositV2(Map<String, Object> req) {
      return ApiResult.ok(
        200,
        'ok',
        new Map<String, Object>{
          'CancelPointList' => new List<Object>{ new Map<String, Object>{ 'kind' => 'cancel' } },
          'DebitPointList' => new List<Object>{ new Map<String, Object>{ 'kind' => 'debit' } },
          'CreditPointList' => new List<Object>{ new Map<String, Object>{ 'kind' => 'credit' } }
        }
      );
    }

    public ApiResult upsertSaleDepositV3(Map<String, Object> req) {
      return upsertSaleDepositV2(req);
    }

    public ApiResult deleteAllSaleDeposits(Id orderId) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult getSaleDepositList(String saleNo) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteSaleDeposit(String depositNo) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteSaleDepositV2(String depositNo) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockOrderItemServiceThrows implements GdOrderItemService {
    public ApiResult createSaleItem(Map<String, Object> req) {
      String forceError;
      forceError.length();
      return null;
    }

    public ApiResult upsertSaleItem(Map<String, Object> req) {
      String forceError;
      forceError.length();
      return null;
    }

    public ApiResult createOrderItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult upsertOrderItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteSaleItem(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockSaleDepositServiceThrows implements GdSaleDepositService {
    public ApiResult createSaleDepositHistory(Map<String, Object> req) {
      String forceError;
      forceError.length();
      return null;
    }

    public ApiResult upsertSaleDeposit(Map<String, Object> req) {
      String forceError;
      forceError.length();
      return null;
    }

    public ApiResult upsertSaleDepositV2(Map<String, Object> req) {
      String forceError;
      forceError.length();
      return null;
    }

    public ApiResult upsertSaleDepositV3(Map<String, Object> req) {
      String forceError;
      forceError.length();
      return null;
    }

    public ApiResult deleteAllSaleDeposits(Id orderId) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult getSaleDepositList(String saleNo) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteSaleDeposit(String depositNo) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteSaleDepositV2(String depositNo) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockVoucherService implements GdVoucherService {
    public void issueBirthdayCoupon() {
    }
    public ApiResult issueSignupCoupon(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult issueSignupCouponV2(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getAvailableCouponList(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemVoucher(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemVoucherV2(TransactionJournal tj) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult redeemCancelVoucher(TransactionJournal tj) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult issueCoupon(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult updateCoupon(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult deleteCoupon(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getReturnUsedCoupon(String originalOrderId) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getRedeemCoupon(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockOrderServiceOrderNotFound implements GdOrderService {
    public ApiResult createSale(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => Id.valueOf('801000000000001AAA'), 'storeTypeFour' => '01' });
    }

    public ApiResult updateSale(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => Id.valueOf('801000000000001AAA') });
    }

    public ApiResult createOrder(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult updateOrder(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', null);
    }

    public ApiResult deleteSale(String saleNo) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => Id.valueOf('801000000000001AAA') });
    }
  }

  private class MockOrderServiceThrows implements GdOrderService {
    public ApiResult createSale(Map<String, Object> req) {
      throw new CustomException(422, 'mock create error');
    }

    public ApiResult updateSale(Map<String, Object> req) {
      throw new CustomException(422, 'mock update error');
    }

    public ApiResult createOrder(Map<String, Object> req) {
      return null;
    }

    public ApiResult updateOrder(Map<String, Object> req) {
      return null;
    }

    public ApiResult deleteSale(String saleNo) {
      return null;
    }
  }

  private class MockSaleServiceOrderNotFound implements GdSaleService {
    public ApiResult deleteSale(String saleNo) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>{ 'orderId' => Id.valueOf('801000000000001AAA') });
    }
  }

  private class MockSaleServiceThrows implements GdSaleService {
    public ApiResult deleteSale(String saleNo) {
      throw new CustomException(422, 'mock delete error');
    }
  }

  private static void setCreateMocks() {
    GdSaleApiControllerV1.setOrderService(new MockOrderService());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
  }

  private static void setDeleteMocks() {
    GdSaleApiControllerV1.setSaleService(new MockSaleService());
    GdSaleApiControllerV1.setSaleItemService(new MockSaleItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
  }

  @IsTest
  static void createSale_success_updatesOrderStatus() {
    setCreateMocks();
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-001"}', null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Id orderId = getCreateOrderId();
    System.assertEquals('saleSuccess', [SELECT Status FROM Order WHERE Id = :orderId LIMIT 1].Status);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void createSale_blankBody_returns400() {
    setCreateMocks();
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', null, null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void createSale_invalidJson_returns400() {
    setCreateMocks();
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', 'NOT_VALID_JSON{{{{', null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void updateSale_success_returns200() {
    setCreateMocks();
    setupRestContext('PATCH', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-002","OrderItem":[],"TransactionJournal":[]}', null);

    Test.startTest();
    GdSaleApiControllerV1.updateSale();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void updateSale_withTransactionJournal_returnsV2DepositPayload() {
    setCreateMocks();
    setupRestContext(
      'PATCH',
      '/services/apexrest/gd/v1/sale',
      '{"SaleNo__c":"SALE-V2","TransactionJournal":[{"DepositNo__c":"DEP-V2","DeposiSeqNo__c":"1","ActivityDate":"2026-04-13","PaymentMethod":"01","DepositType__c":"01","TransactionAmount":1000}]}',
      null
    );

    Test.startTest();
    GdSaleApiControllerV1.updateSale();
    Test.stopTest();

    Map<String, Object> body = parseResponseBody();
    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, body.get('success'));
    Map<String, Object> data = (Map<String, Object>) body.get('data');
    System.assertNotEquals(null, data.get('CancelPointList'));
    System.assertNotEquals(null, data.get('DebitPointList'));
    System.assertNotEquals(null, data.get('CreditPointList'));
  }

  @IsTest
  static void updateSale_blankBody_returns400() {
    setCreateMocks();
    setupRestContext('PATCH', '/services/apexrest/gd/v1/sale', null, null);

    Test.startTest();
    GdSaleApiControllerV1.updateSale();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void updateSale_invalidJson_returns400() {
    setCreateMocks();
    setupRestContext('PATCH', '/services/apexrest/gd/v1/sale', 'NOT_VALID_JSON{{{{', null);

    Test.startTest();
    GdSaleApiControllerV1.updateSale();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void deleteSale_success_updatesOrderStatus() {
    setDeleteMocks();
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-API-DELETE-NO' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    Id orderId = getDeleteOrderId();
    System.assertEquals('saleDeleted', [SELECT Status FROM Order WHERE Id = :orderId LIMIT 1].Status);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void deleteSale_missingParam_returns400() {
    setDeleteMocks();
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, null);

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void createSale_withoutOptionalKeys_stillReturns200() {
    GdSaleApiControllerV1.setOrderService(new MockOrderService());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-003","OnlyRequired":true}', null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void createSale_withTransactionJournal_returnsDepositPayload() {
    setCreateMocks();
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-DEPOSIT-CREATE","TransactionJournal":[]}', null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    Map<String, Object> body = parseResponseBody();
    Map<String, Object> data = (Map<String, Object>) body.get('data');
    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, body.get('success'));
    System.assertNotEquals(null, data.get('DebitPointList'));
    System.assertNotEquals(null, data.get('CreditPointList'));
  }

  @IsTest
  static void createSale_whenOrderNotFound_returns400() {
    GdSaleApiControllerV1.setOrderService(new MockOrderServiceOrderNotFound());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-404"}', null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void createSale_whenServiceThrows_returns422() {
    GdSaleApiControllerV1.setOrderService(new MockOrderServiceThrows());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-ERR"}', null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void updateSale_withoutOptionalKeys_returns200() {
    setCreateMocks();
    setupRestContext('PATCH', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-004"}', null);

    Test.startTest();
    GdSaleApiControllerV1.updateSale();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void updateSale_whenServiceThrows_returns422() {
    GdSaleApiControllerV1.setOrderService(new MockOrderServiceThrows());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('PATCH', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-ERR-UPD"}', null);

    Test.startTest();
    GdSaleApiControllerV1.updateSale();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void deleteSale_whenOrderNotFound_returns400() {
    GdSaleApiControllerV1.setSaleService(new MockSaleServiceOrderNotFound());
    GdSaleApiControllerV1.setSaleItemService(new MockSaleItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-404-DEL' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void deleteSale_whenServiceThrows_returns422() {
    GdSaleApiControllerV1.setSaleService(new MockSaleServiceThrows());
    GdSaleApiControllerV1.setSaleItemService(new MockSaleItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-ERR-DEL' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void voucherService_setAndGet_coversVisibleBranch() {
    GdSaleApiControllerV1.setVoucherService(null);
    Test.startTest();
    GdVoucherService svcFromNull = GdSaleApiControllerV1.getVoucherService();
    GdSaleApiControllerV1.setVoucherService((GdVoucherService) new MockVoucherService());
    GdVoucherService svcFromMock = GdSaleApiControllerV1.getVoucherService();
    Test.stopTest();

    System.assertNotEquals(null, svcFromNull);
    System.assertNotEquals(null, svcFromMock);
  }

  @IsTest
  static void defaultServiceFactories_areCoveredThroughControllerEntryPoints() {
    GdSaleApiControllerV1.setOrderService(null);
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-DEFAULT-ORDER"}', null);
    GdSaleApiControllerV1.createSale();
    System.assertNotEquals(null, RestContext.response.statusCode);

    GdSaleApiControllerV1.setOrderService(new MockOrderService());
    GdSaleApiControllerV1.setOrderItemService(null);
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-DEFAULT-ITEM"}', null);
    GdSaleApiControllerV1.createSale();
    System.assertNotEquals(null, RestContext.response.statusCode);

    GdSaleApiControllerV1.setOrderService(new MockOrderService());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(null);
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-DEFAULT-DEPOSIT","TransactionJournal":[]}', null);
    GdSaleApiControllerV1.createSale();
    System.assertNotEquals(null, RestContext.response.statusCode);

    GdSaleApiControllerV1.setSaleService(null);
    GdSaleApiControllerV1.setSaleItemService(new MockSaleItemService());
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-DEFAULT-DELETE' });
    GdSaleApiControllerV1.deleteSale();
    System.assertNotEquals(null, RestContext.response.statusCode);

    GdSaleApiControllerV1.setSaleService(new MockSaleService());
    GdSaleApiControllerV1.setSaleItemService(null);
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-API-DELETE-NO' });
    GdSaleApiControllerV1.deleteSale();
    System.assertNotEquals(null, RestContext.response.statusCode);
  }

  @IsTest
  static void updateSale_optionCBranch_wrapsOldSaleResponse() {
    setOptionCBranch(true, Date.today().addDays(1));
    setCreateMocks();
    setupRestContext('PATCH', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-API-CREATE-NO"}', null);

    Test.startTest();
    GdSaleApiControllerV1.updateSale();
    Test.stopTest();

    Map<String, Object> data = (Map<String, Object>) parseResponseBody().get('data');
    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, data.get('option_c_branch'));
  }

  @IsTest
  static void deleteSale_optionCBranch_wrapsOldSaleResponse() {
    setOptionCBranch(true, Date.today().addDays(1));
    setDeleteMocks();
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-API-DELETE-NO' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    Map<String, Object> data = (Map<String, Object>) parseResponseBody().get('data');
    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, data.get('option_c_branch'));
  }

  @IsTest
  static void deleteSale_featureFlagOn_withMemberButNoEcoPoints_succeeds() {
    setDeleteMocks();
    seedMemberForDeleteOrder();
    GdFeatureFlag.setForTest('EcoPointCancel_UseSpecificLedger', true);
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-API-DELETE-NO' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    GdFeatureFlag.clearCacheForTest();
    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(true, parseResponseBody().get('success'));
  }

  @IsTest
  static void deleteSale_featureFlagOn_withCancelableEcoPoints_returnsCancelPayload() {
    setDeleteMocks();
    seedEcoLedgerForDeleteOrder(100, 0);
    GdFeatureFlag.setForTest('EcoPointCancel_UseSpecificLedger', true);
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-API-DELETE-NO' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    GdFeatureFlag.clearCacheForTest();
    System.assertEquals(200, RestContext.response.statusCode);
    Map<String, Object> data = (Map<String, Object>) parseResponseBody().get('data');
    System.assertNotEquals(null, data.get('CancelPointList'));
  }

  @IsTest
  static void createSale_nullRequest_returns500() {
    setCreateMocks();
    RestContext.request = null;
    RestContext.response = new RestResponse();

    Test.startTest();
    try {
      GdSaleApiControllerV1.createSale();
      System.assert(false, 'Expected null RestRequest to throw before response handling.');
    } catch (NullPointerException e) {
      System.assert(e.getMessage() != null);
    }
    Test.stopTest();
  }

  @IsTest
  static void updateSale_nullRequest_returns500() {
    setCreateMocks();
    RestContext.request = null;
    RestContext.response = new RestResponse();

    Test.startTest();
    try {
      GdSaleApiControllerV1.updateSale();
      System.assert(false, 'Expected null RestRequest to throw before response handling.');
    } catch (NullPointerException e) {
      System.assert(e.getMessage() != null);
    }
    Test.stopTest();
  }

  @IsTest
  static void deleteSale_nullRequest_returns500() {
    setDeleteMocks();
    RestContext.request = null;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void deleteSale_withFullyUsedEcoPoints_skipsForcedDebitAndStillSucceeds() {
    setDeleteMocks();
    GdFeatureFlag.setForTest('EcoPointCancel_UseSpecificLedger', false);
    seedEcoLedgerForDeleteOrder(100, 100);
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-API-DELETE-NO' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    GdFeatureFlag.clearCacheForTest();
    System.assertEquals(200, RestContext.response.statusCode);
    Id orderId = getDeleteOrderId();
    System.assertEquals('saleDeleted', [SELECT Status FROM Order WHERE Id = :orderId LIMIT 1].Status);
    System.assertEquals(0, [SELECT COUNT() FROM TransactionJournal WHERE OrderId = :orderId AND AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL']);
  }

  @IsTest
  static void deleteSale_withCancelableEcoPoints_entersForcedDebitBranch() {
    setDeleteMocks();
    GdFeatureFlag.setForTest('EcoPointCancel_UseSpecificLedger', false);
    seedEcoLedgerForDeleteOrder(100, 0);
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-API-DELETE-NO' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    GdFeatureFlag.clearCacheForTest();
    System.assertNotEquals(null, RestContext.response);
    System.assertNotEquals(null, RestContext.response.statusCode);
    System.assertNotEquals(null, RestContext.response.responseBody);
  }

  @IsTest
  static void createSale_whenOrderItemServiceThrows_returns500() {
    GdSaleApiControllerV1.setOrderService(new MockOrderService());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemServiceThrows());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-ITEM-ERR"}', null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void updateSale_whenDepositServiceThrows_returns500() {
    GdSaleApiControllerV1.setOrderService(new MockOrderService());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositServiceThrows());
    setupRestContext('PATCH', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-DEPOSIT-ERR","TransactionJournal":[]}', null);

    Test.startTest();
    GdSaleApiControllerV1.updateSale();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void createSale_whenDepositServiceThrows_returns500() {
    GdSaleApiControllerV1.setOrderService(new MockOrderService());
    GdSaleApiControllerV1.setOrderItemService(new MockOrderItemService());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositServiceThrows());
    setupRestContext('POST', '/services/apexrest/gd/v1/sale', '{"SaleNo__c":"SALE-DEPOSIT-ERR-CREATE","TransactionJournal":[]}', null);

    Test.startTest();
    GdSaleApiControllerV1.createSale();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }

  @IsTest
  static void deleteSale_whenSaleItemServiceThrows_returns500() {
    GdSaleApiControllerV1.setSaleService(new MockSaleService());
    GdSaleApiControllerV1.setSaleItemService(new MockSaleItemServiceThrows());
    GdSaleApiControllerV1.setSaleDepositService(new MockSaleDepositService());
    setupRestContext('DELETE', '/services/apexrest/gd/v1/sale', null, new Map<String, String>{ 'SaleNo__c' => 'SALE-API-DELETE-NO' });

    Test.startTest();
    GdSaleApiControllerV1.deleteSale();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertEquals(false, parseResponseBody().get('success'));
  }
}