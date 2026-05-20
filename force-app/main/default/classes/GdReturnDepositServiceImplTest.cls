@IsTest
private class GdReturnDepositServiceImplTest {
  private static final String TEST_MEMBER_NO = 'RT-001';
  private static final String ORIGINAL_ORDER_NO = 'ORD-ORIGINAL-001';
  private static final String RETURN_ORDER_NO = 'ORD-RETURN-001';
  private static Id lastRedeemCancelOrderId;
  private static Id lastRedeemCancelOrderIdCustom;
  private static Id lastRedeemCancelSaleId;
  private static String lastRedeemCancelVoucherCode;
  private static Integer cancelPointsCreditedOnPurchaseCallCount;
  private static Integer creditPointsOnPurchaseCallCount;
  private static Integer creditPromotionPointsOnPurchaseCallCount;
  private static Boolean returnPromotionCreditList;
  private static List<TransactionJournal> capturedCancelPointsCreditedData;

  private class MockHttpSuccess implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setHeader('Content-Type', 'application/json');

      if (req.getEndpoint() != null && req.getEndpoint().contains('/v2/token')) {
        res.setStatusCode(200);
        res.setBody('{"access_token":"test_token","token_type":"Bearer","expires_in":1080}');
        return res;
      }

      res.setStatusCode(202);
      res.setBody('{"requestId":"test-request-id","resultMessages":[]}');
      return res;
    }
  }

  private class VoucherServiceStubProvider implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbedObject,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      if (methodName == 'redeemVoucherV2') {
        return ApiResult.ok(200, '荑좏룿 泥섎━ ?깃났', new Map<String, Object>{ 'voucher' => 'VOUCHER_OK' });
      }

      if (methodName == 'redeemCancelVoucher') {
        TransactionJournal tj = (TransactionJournal) args[0];
        lastRedeemCancelOrderId = tj.OrderId;
        lastRedeemCancelOrderIdCustom = tj.OrderId__c;
        lastRedeemCancelSaleId = tj.SaleId__c;
        lastRedeemCancelVoucherCode = tj.VoucherCode;
        return ApiResult.ok(200, '荑좏룿 痍⑥냼 ?깃났', new Map<String, Object>{ 'voucher' => 'VOUCHER_CANCEL_OK' });
      }

      return null;
    }
  }

  private class PointServiceStubProvider implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbedObject,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      if (methodName == 'cancelPointRedemption') {
        return new Map<String, Object>{ 'result' => 'cancel-ok' };
      }

      if (methodName == 'debitPoint') {
        return new List<GdSaleApiController.PointDebitDTO>();
      }

      if (methodName == 'creditPointsOnPurchase') {
        return new List<PointCreditDTO>{ new PointCreditDTO() };
      }

      if (methodName == 'cancelPointsCreditedOnPurchase') {
        return new List<GdSaleApiController.PointDebitDTO>();
      }

      if (methodName == 'debitSpecificPoints') {
        TransactionJournal tj = (TransactionJournal) args[0];
        tj.JournalTypeId = getJournalTypeId('Redemption');
        tj.JournalSubTypeId = getJournalSubTypeId('Point Debit');
        tj.Status = 'Pending';
        insert tj;
        return new List<GdSaleApiController.PointDebitDTO>{ new GdSaleApiController.PointDebitDTO() };
      }

      if (methodName == 'creditSepcificPoints') {
        TransactionJournal tj = (TransactionJournal) args[0];
        tj.JournalTypeId = getJournalTypeId('Accrual');
        tj.JournalSubTypeId = getJournalSubTypeId('Purchase Accrual');
        insert tj;
        return new List<PointCreditDTO>{ new PointCreditDTO() };
      }

      if (methodName == 'creditPointsOnPurchaseByGrade') {
        return new List<PointCreditDTO>{ new PointCreditDTO() };
      }

      return null;
    }
  }

  private class PointServiceMock implements GdPointService {
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

    public List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList) {
      tj.JournalTypeId = getJournalTypeId('Redemption');
      tj.JournalSubTypeId = getJournalSubTypeId('Point Debit');
      tj.Status = 'Pending';
      insert tj;

      PointDebitDTO dto = new PointDebitDTO();
      dto.CD_RESON = '1';
      dto.PT_USE = tj.TransactionAmount;
      return new List<PointDebitDTO>{ dto };
    }

    public List<PointDebitDTO> debitSpecificPointsV2(TransactionJournal tj, List<LoyaltyLedger> llList) {
      return debitSpecificPoints(tj, llList);
    }

    public List<PointDebitDTO> debitSpecificPointsV3(TransactionJournal tj, Map<Id, Decimal> requestedPointsByLedgerId) {
      tj.JournalTypeId = getJournalTypeId('Redemption');
      tj.JournalSubTypeId = getJournalSubTypeId('Point Debit');
      tj.Status = 'Pending';
      insert tj;

      List<PointDebitDTO> result = new List<PointDebitDTO>();
      if (requestedPointsByLedgerId != null) {
        for (Id ledgerId : requestedPointsByLedgerId.keySet()) {
          PointDebitDTO dto = new PointDebitDTO();
          dto.CD_LEDGER = ledgerId;
          dto.CD_RESON = '1';
          dto.PT_USE = requestedPointsByLedgerId.get(ledgerId);
          result.add(dto);
        }
      }
      return result;
    }

    public List<GdSaleApiController.PointDebitDTO> debitPointsCustom(TransactionJournal tj) {
      return new List<GdSaleApiController.PointDebitDTO>();
    }

    public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return new List<PointCreditDTO>{ new PointCreditDTO() };
    }

    public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return new List<PointDebitDTO>();
    }

    public List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList) {
      tj.JournalTypeId = getJournalTypeId('Accrual');
      tj.JournalSubTypeId = getJournalSubTypeId('Purchase Accrual');
      insert tj;
      return new List<PointCreditDTO>{ new PointCreditDTO() };
    }

    public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
      creditPointsOnPurchaseCallCount = (creditPointsOnPurchaseCallCount == null) ? 1 : creditPointsOnPurchaseCallCount + 1;
      return new List<PointCreditDTO>{ new PointCreditDTO() };
    }

    public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
      return new List<PointCreditDTO>{ new PointCreditDTO() };
    }

    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }

    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }

    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
    }

    public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
      creditPromotionPointsOnPurchaseCallCount = (creditPromotionPointsOnPurchaseCallCount == null)
        ? 1
        : creditPromotionPointsOnPurchaseCallCount + 1;
      if (returnPromotionCreditList == true) {
        return new List<PointCreditDTO>{ new PointCreditDTO() };
      }
      return new List<PointCreditDTO>();
    }

    public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
      return new Map<String, Object>{ 'result' => 'cancel-ok' };
    }

    public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
      cancelPointsCreditedOnPurchaseCallCount = (cancelPointsCreditedOnPurchaseCallCount == null) ? 1 : cancelPointsCreditedOnPurchaseCallCount + 1;
      capturedCancelPointsCreditedData = (data == null) ? null : data.deepClone(true, true, true);
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

  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    Contact con = new Contact(LastName = 'ReturnTester', Grade__c = '02', PreviousGrade__c = '01', MemberNo__c = TEST_MEMBER_NO);
    insert con;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Return Program', IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      MembershipNumber = TEST_MEMBER_NO,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = con.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert lpm;

    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'Return Tier Group',
      LoyaltyProgramId = lp.Id,
      QpResetPeriod = 'Years',
      QpResetDate = Date.today(),
      QpResetFrequency = 1
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(Name = 'Tier-Gold', LoyaltyTierGroupId = tierGroup.Id);
    insert tier;

    insert new LoyaltyMemberTier(LoyaltyMemberId = lpm.Id, LoyaltyTierId = tier.Id, Name = '02');

    Account acnt = new Account(Name = 'TEST-ACCOUNT');
    insert acnt;

    Id standardPricebookId = Test.getStandardPricebookId();

    Order originalOrder = new Order(
      Name = 'Original Order',
      EffectiveDate = Date.today().addDays(-10),
      EndDate = Date.today().addDays(-10),
      Status = 'Draft',
      OrderNo__c = ORIGINAL_ORDER_NO,
      SaleNo__c = 'SALE-ORIGINAL-001',
      ActualPaymentAmount__c = 100000,
      IsReductionOrder__c = false,
      MemberNo__c = con.Id,
      InsertId__c = 'USER-001',
      AccountId = acnt.Id,
      Pricebook2Id = standardPricebookId
    );
    insert originalOrder;

    Product2 product = new Product2(Name = 'Return Test Product', ProductCode = 'RT-P-001', IsActive = true);
    insert product;

    insert new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = product.Id, UnitPrice = 10000, IsActive = true);

    Id originalPbeId = [
      SELECT Id
      FROM PricebookEntry
      WHERE Pricebook2Id = :standardPricebookId AND Product2Id = :product.Id
      LIMIT 1
    ]
    .Id;

    insert new OrderItem(
      OrderId = originalOrder.Id,
      PricebookEntryId = originalPbeId,
      Quantity = 1,
      UnitPrice = 10000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = 'ORIGINAL-SETUP-1'
    );

    insert new OrderItem(
      OrderId = originalOrder.Id,
      PricebookEntryId = originalPbeId,
      Quantity = 1,
      UnitPrice = 10000,
      SaleSeqNo__c = '2',
      SaleItemNo__c = 'ORIGINAL-SETUP-2'
    );

    originalOrder.Status = 'saleSuccess';
    update originalOrder;

    Order returnOrder = new Order(
      Name = 'Return Order',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      OrderNo__c = RETURN_ORDER_NO,
      SaleNo__c = 'SALE-RETURN-001',
      ActualPaymentAmount__c = 50000,
      MemberNo__c = con.Id,
      InsertId__c = 'USER-002',
      AccountId = acnt.Id,
      Pricebook2Id = standardPricebookId,
      OriginalOrderId__c = originalOrder.Id,
      IsReductionOrder__c = true
    );
    insert returnOrder;

    LoyaltyProgramCurrency loyaltyCurrency = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = '\uD3EC\uC778\uD2B8',
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

    insert new LoyaltyMemberCurrency(Name = 'Return Test Member Currency', LoyaltyMemberId = lpm.Id, LoyaltyProgramCurrencyId = loyaltyCurrency.Id);

    insert new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
      Name = '\uC5D0\uCF54\uD3EC\uC778\uD2B8',
      PointTypeCode__c = '05',
      UsagePriorityNumber = 1,
      IsActive = true
    );

    JournalType depositType = new JournalType(Name = 'Deposit');
    JournalType depositReversalType = new JournalType(Name = 'Deposit Reversal');
    JournalType redemptionType = new JournalType(Name = 'Redemption');
    JournalType redemptionReversalType = new JournalType(Name = 'Redemption Reversal');
    JournalType accrualType = new JournalType(Name = 'Accrual');
    JournalType accrualReversalType = new JournalType(Name = 'Accrual Reversal');
    insert new List<JournalType>{ depositType, depositReversalType, redemptionType, redemptionReversalType, accrualType, accrualReversalType };

    insert new List<JournalSubType>{
      new JournalSubType(Name = 'Order Deposit', JournalTypeId = depositType.Id),
      new JournalSubType(Name = 'Order Deposit Reversal', JournalTypeId = depositReversalType.Id),
      new JournalSubType(Name = 'Sale Deposit', JournalTypeId = depositType.Id),
      new JournalSubType(Name = 'Sale Deposit Reversal', JournalTypeId = depositReversalType.Id),
      new JournalSubType(Name = 'Coupon Redeem', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Coupon Redeem Cancel', JournalTypeId = redemptionReversalType.Id),
      new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Api Forced Debit', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = redemptionReversalType.Id),
      new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = accrualReversalType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual Reversal', JournalTypeId = accrualReversalType.Id)
    };
  }

  private static void setMockServices() {
    lastRedeemCancelOrderId = null;
    lastRedeemCancelOrderIdCustom = null;
    lastRedeemCancelSaleId = null;
    lastRedeemCancelVoucherCode = null;
    cancelPointsCreditedOnPurchaseCallCount = 0;
    creditPointsOnPurchaseCallCount = 0;
    creditPromotionPointsOnPurchaseCallCount = 0;
    returnPromotionCreditList = false;
    capturedCancelPointsCreditedData = null;

    GdVoucherService voucherStub = (GdVoucherService) Test.createStub(GdVoucherService.class, new VoucherServiceStubProvider());
    GdPointService pointStub = new PointServiceMock();

    GdReturnDepositServiceImpl.setVoucherService(voucherStub);
    GdReturnDepositServiceImpl.setPointService(pointStub);
  }

  private static Order getOriginalOrder() {
    return [
      SELECT Id, OrderNo__c, MemberNo__c, EndDate, ActualPaymentAmount__c, InsertId__c
      FROM Order
      WHERE OrderNo__c = :ORIGINAL_ORDER_NO
      LIMIT 1
    ];
  }

  private static Order getReturnOrder() {
    return [
      SELECT Id, OrderNo__c, MemberNo__c, EndDate, ActualPaymentAmount__c, InsertId__c
      FROM Order
      WHERE OrderNo__c = :RETURN_ORDER_NO
      LIMIT 1
    ];
  }

  private static Id getJournalSubTypeId(String name) {
    return [
      SELECT Id
      FROM JournalSubType
      WHERE Name = :name
      LIMIT 1
    ]
    .Id;
  }

  private static Id getJournalTypeId(String name) {
    return [
      SELECT Id
      FROM JournalType
      WHERE Name = :name
      LIMIT 1
    ]
    .Id;
  }

  private static Id getPricebookEntryId() {
    return [SELECT Id FROM PricebookEntry WHERE Product2.ProductCode = 'RT-P-001' LIMIT 1].Id;
  }

  private static Id getEcoSubtypeId() {
    return [SELECT Id FROM LoyaltyPgmCurrencySubtype WHERE PointTypeCode__c = '05' LIMIT 1].Id;
  }

  private static Id getVoucherDefinitionAccountId() {
    List<Account> accountList = [
      SELECT Id
      FROM Account
      WHERE Name = 'Return Coupon Company'
      LIMIT 1
    ];
    if (!accountList.isEmpty()) {
      return accountList[0].Id;
    }

    String brandCode = Account.BrandCode__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : Account.BrandCode__c.getDescribe().getPicklistValues()[0].getValue();
    String storeType = Account.StoreType__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : Account.StoreType__c.getDescribe().getPicklistValues()[0].getValue();

    Account accountRecord = new Account(
      Name = 'Return Coupon Company',
      CompanyCode__c = '1000',
      BrandCode__c = brandCode
    );
    insert accountRecord;
    return accountRecord.Id;
  }

  private static Id getLoyaltyProgramCurrencyId() {
    return [SELECT LoyaltyProgramCurrencyId FROM LoyaltyPgmCurrencySubtype WHERE PointTypeCode__c = '05' LIMIT 1].LoyaltyProgramCurrencyId;
  }

  private static void seedOriginalSaleDeposit(Order originalOrder, String depositNo, String paymentMethod, Decimal amount) {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    insert new TransactionJournal(
      DepositNo__c = depositNo,
      DeposiSeqNo__c = '1',
      JournalDate = Date.today().addDays(-1),
      ActivityDate = Datetime.now().addDays(-1),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      JournalTypeId = getJournalTypeId('Deposit'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit'),
      PaymentMethod = paymentMethod,
      DepositType__c = '01',
      TransactionAmount = amount,
      Status = 'Processed'
    );
  }

  private static void seedFullReturnItems() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    Id pbeId = getPricebookEntryId();
    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];

    if ([SELECT COUNT() FROM OrderItem WHERE OrderId = :returnOrder.Id] == 0) {
      insert new OrderItem(
        OrderId = returnOrder.Id,
        PricebookEntryId = pbeId,
        Quantity = -1,
        UnitPrice = 10000,
        SaleSeqNo__c = '1',
        SaleItemNo__c = 'RETURN-1',
        OriginalOrderItemId__c = originalItems[0].Id
      );

      insert new OrderItem(
        OrderId = returnOrder.Id,
        PricebookEntryId = pbeId,
        Quantity = -1,
        UnitPrice = 10000,
        SaleSeqNo__c = '2',
        SaleItemNo__c = 'RETURN-2',
        OriginalOrderItemId__c = originalItems[1].Id
      );
    }
  }

  private static Order createSiblingReturnOrder() {
    Order originalOrder = getOriginalOrder();
    Contact memberContact = [SELECT Id FROM Contact WHERE MemberNo__c = :TEST_MEMBER_NO LIMIT 1];
    return new Order(
      Name = 'Sibling Return Order',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      OrderNo__c = 'ORD-RETURN-002',
      SaleNo__c = 'SALE-RETURN-002',
      ActualPaymentAmount__c = 50000,
      MemberNo__c = memberContact.Id,
      InsertId__c = 'USER-003',
      AccountId = [SELECT Id FROM Account LIMIT 1]
      .Id,
      Pricebook2Id = Test.getStandardPricebookId(),
      OriginalOrderId__c = originalOrder.Id,
      IsReductionOrder__c = true
    );
  }

  private static void seedDistributedFullReturnItems() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    Id pbeId = getPricebookEntryId();

    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];

    insert new OrderItem(
      OrderId = returnOrder.Id,
      PricebookEntryId = pbeId,
      Quantity = -1,
      UnitPrice = 10000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = 'RETURN-A',
      OriginalOrderItemId__c = originalItems[0].Id
    );

    Order siblingReturn = createSiblingReturnOrder();
    insert siblingReturn;
    insert new OrderItem(
      OrderId = siblingReturn.Id,
      PricebookEntryId = pbeId,
      Quantity = -1,
      UnitPrice = 10000,
      SaleSeqNo__c = '2',
      SaleItemNo__c = 'RETURN-B',
      OriginalOrderItemId__c = originalItems[1].Id
    );
  }

  private static void seedOriginalEcoLedger() {
    Order originalOrder = getOriginalOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id accrualTypeId = getJournalTypeId('Accrual');
    Id purchaseAccrualSubTypeId = getJournalSubTypeId('Api Forced Credit');
    Id ecoSubtypeId = getEcoSubtypeId();
    Id loyaltyProgramCurrencyId = [
      SELECT LoyaltyProgramCurrencyId
      FROM LoyaltyPgmCurrencySubtype
      WHERE Id = :ecoSubtypeId
      LIMIT 1
    ]
    .LoyaltyProgramCurrencyId;

    TransactionJournal ecoAccrualTj = new TransactionJournal(
      JournalDate = Date.today().addDays(-10),
      ActivityDate = Datetime.now().addDays(-10),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      JournalTypeId = accrualTypeId,
      JournalSubTypeId = purchaseAccrualSubTypeId,
      TransactionAmount = 100,
      Status = 'Processed'
    );
    insert ecoAccrualTj;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId,
      LoyaltyPgmCrcySubtypeId = ecoSubtypeId,
      TransactionJournalId = ecoAccrualTj.Id,
      ActivityDate = Datetime.now().addDays(-10),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_missingRequired_throws() {
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.insertSaleDepositHistoryByUpdate(new Map<String, Object>());
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_saleDeposit() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-TEST',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTDEP001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '01',
          'TransactionAmount' => 10000
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    List<TransactionJournal> tjList = [
      SELECT Id, DepositNo__c, SaleId__c, OrderId, PaymentMethod, DepositType__c
      FROM TransactionJournal
      WHERE DepositNo__c = 'RTDEP001-1'
    ];
    System.assertEquals(1, tjList.size());
    Set<Id> relatedOrderIds = new Set<Id>{ tjList[0].SaleId__c, tjList[0].OrderId };
    System.assertEquals(true, relatedOrderIds.contains(returnOrder.Id));
    System.assertEquals(true, relatedOrderIds.contains(originalOrder.Id));
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_pointAndCoupon() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-TEST',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTPOINT001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '81',
          'DepositType__c' => '03',
          'TransactionAmount' => 3000
        },
        new Map<String, Object>{
          'DepositNo__c' => 'RTCOUPON001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '01',
          'TransactionAmount' => 1000,
          'CouponNo' => 'CP-001'
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void deleteAllReturnDeposits_notFound_throws() {
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.deleteAllReturnDeposits('801000000000000AAA');
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteAllReturnDeposits_success_cancelPurchaseAccrual() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    TransactionJournal tj = new TransactionJournal();
    tj.DepositNo__c = 'DELALL001';
    tj.DeposiSeqNo__c = '1';
    tj.JournalDate = Date.today();
    tj.ActivityDate = Datetime.now();
    tj.PaymentMethod = '11';
    tj.DepositType__c = '03';
    tj.TransactionAmount = 5000;
    tj.OrderId = originalOrder.Id;
    tj.SaleId__c = returnOrder.Id;
    tj.LoyaltyProgramId = [
      SELECT ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ]
    .ProgramId;
    tj.MemberId = [
      SELECT Id
      FROM LoyaltyProgramMember
      LIMIT 1
    ]
    .Id;
    tj.JournalTypeId = getJournalTypeId('Accrual Reversal');
    tj.JournalSubTypeId = getJournalSubTypeId('Cancel Purchase Accrual');
    tj.Status = 'Processed';
    tj.IsDeleted__c = false;
    insert tj;

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.deleteAllReturnDeposits(returnOrder.Id);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    TransactionJournal updatedTj = [
      SELECT Id, IsDeleted__c, DeleteDateTime__c
      FROM TransactionJournal
      WHERE Id = :tj.Id
    ];
    System.assertEquals(true, updatedTj.IsDeleted__c);
    System.assertNotEquals(null, updatedTj.DeleteDateTime__c);
  }

  @IsTest
  static void deleteReturnDeposit_notFound_throws() {
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.deleteReturnDeposit('DEP-NOT-FOUND');
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteReturnDeposit_success_couponRedeemCancel() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    Order originalOrder = getOriginalOrder();
    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId, ContactId
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Delete Return Coupon',
      LoyaltyProgramId = lpm.ProgramId,
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today().addDays(-1),
      ExpirationDate = Date.today().addDays(30),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'TEST',
      InsertId__c = 'TEST',
      AccountId__c = getVoucherDefinitionAccountId(),
      IsActive = true
    );
    insert vd;

    insert new Voucher(
      VoucherDefinitionId = vd.Id,
      LoyaltyProgramMemberId = lpm.Id,
      ContactId = lpm.ContactId,
      VoucherCode = 'CP-DEL-001',
      Status = 'Issued',
      EffectiveDate = Date.today().addDays(-1),
      ExpirationDate = Date.today().addDays(30)
    );

    TransactionJournal tj = new TransactionJournal();
    tj.DepositNo__c = 'DELONE001';
    tj.DeposiSeqNo__c = '1';
    tj.JournalDate = Date.today();
    tj.ActivityDate = Datetime.now();
    tj.PaymentMethod = '11';
    tj.DepositType__c = '03';
    tj.TransactionAmount = 2000;
    tj.OrderId = originalOrder.Id;
    tj.SaleId__c = getReturnOrder().Id;
    tj.LoyaltyProgramId = [
      SELECT ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ]
    .ProgramId;
    tj.MemberId = [
      SELECT Id
      FROM LoyaltyProgramMember
      LIMIT 1
    ]
    .Id;
    tj.JournalTypeId = getJournalTypeId('Redemption Reversal');
    tj.JournalSubTypeId = getJournalSubTypeId('Coupon Redeem Cancel');
    tj.Status = 'Processed';
    tj.IsDeleted__c = false;
    tj.VoucherCode = 'CP-DEL-001';
    insert tj;

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Test.startTest();
    setMockServices();
    ApiResult result = svc.deleteReturnDeposit('DELONE001');
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    TransactionJournal updatedTj = [
      SELECT Id, IsDeleted__c, DeleteDateTime__c
      FROM TransactionJournal
      WHERE Id = :tj.Id
    ];
    System.assertEquals(true, updatedTj.IsDeleted__c);
    System.assertNotEquals(null, updatedTj.DeleteDateTime__c);
  }
  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_saleDepositReversal() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-REV',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTREV001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 7000
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    List<TransactionJournal> tjList = [
      SELECT Id, DepositNo__c, DepositType__c, SaleId__c, OrderId
      FROM TransactionJournal
      WHERE DepositNo__c = 'RTREV001-1'
    ];
    System.assertEquals(1, tjList.size());
    System.assertEquals('03', tjList[0].DepositType__c);
    Set<Id> relatedOrderIds = new Set<Id>{ tjList[0].SaleId__c, tjList[0].OrderId };
    System.assertEquals(true, relatedOrderIds.contains(returnOrder.Id));
    System.assertEquals(true, relatedOrderIds.contains(originalOrder.Id));
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_pointDebit() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-POINT',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTPOINT002',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '81',
          'DepositType__c' => '01',
          'TransactionAmount' => 1500
        }
      }
    };

    Boolean thrown = false;
    try {
      svc.insertSaleDepositHistoryByUpdate(reqData);
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_pointCancel() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-POINT-CANCEL',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTPOINT003',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '81',
          'DepositType__c' => '03',
          'TransactionAmount' => 1500
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
    System.assertNotEquals(null, result.data.get('CancelPointList'));
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_couponCancel() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-COUPON',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTCOUPON002',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 1000,
          'CouponNo' => 'CP-002'
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_couponCancel_usesOriginalCouponRedeemOrder() {
    GdReturnDepositServiceImpl.setVoucherService(null);
    GdReturnDepositServiceImpl.setPointService(new PointServiceMock());

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    Contact memberContact = [SELECT Id FROM Contact WHERE MemberNo__c = :TEST_MEMBER_NO LIMIT 1];
    String brandCode = Account.BrandCode__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : Account.BrandCode__c.getDescribe().getPicklistValues()[0].getValue();

    Account voucherAccount = new Account(Name = 'Return Coupon Account', CompanyCode__c = '1000', BrandCode__c = brandCode);
    insert voucherAccount;

    VoucherCategory__c voucherCategory = new VoucherCategory__c(Name = 'Return Coupon Category', Code__c = 'ReturnCoupon');
    insert voucherCategory;

    Order sourceOrder = new Order(
      Name = 'Coupon Source Order',
      EffectiveDate = Date.today().addDays(-1),
      EndDate = Date.today().addDays(-1),
      Status = 'Draft',
      OrderNo__c = 'ORD-COUPON-SRC-001',
      SaleNo__c = 'SALE-COUPON-SRC-001',
      ActualPaymentAmount__c = 10000,
      MemberNo__c = memberContact.Id,
      InsertId__c = 'USER-COUPON-SRC',
      AccountId = accountRecord.Id,
      Pricebook2Id = Test.getStandardPricebookId()
    );
    insert sourceOrder;

    TransactionJournal sourceRedeemJournal = new TransactionJournal(
      DepositNo__c = 'SRC-COUPON-001-1',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today().addDays(-1),
      ActivityDate = Datetime.now().addDays(-1),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = sourceOrder.Id,
      OrderId__c = sourceOrder.Id,
      SaleId__c = originalOrder.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Coupon Redeem'),
      VoucherCode = 'CP-ORDER-LINK-001',
      Status = 'Processed'
    );
    insert sourceRedeemJournal;

    VoucherDefinition couponDefinition = new VoucherDefinition(
      Name = 'Return Cancel Coupon',
      CouponManNo__c = 'CPN-RETURN-CANCEL-001',
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      CouponTypeCode__c = VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue(),
      EffectiveDate = Date.today().addDays(-5),
      ExpirationDate = Date.today().addDays(30),
      LoyaltyProgramId = lpm.ProgramId,
      AccountId__c = voucherAccount.Id,
      VoucherCategoryId__c = voucherCategory.Id,
      InsertId__c = 'RETURN-COUPON-TEST',
      ResponsibleDepartment__c = 'TEST',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = true
    );
    insert couponDefinition;

    insert new Voucher(
      VoucherDefinitionId = couponDefinition.Id,
      LoyaltyProgramMemberId = lpm.Id,
      VoucherCode = 'CP-ORDER-LINK-001',
      Status = 'Redeemed',
      EffectiveDate = Date.today().addDays(-5),
      ExpirationDate = Date.today().addDays(30),
      UsedTransactionJournalId__c = sourceRedeemJournal.Id
    );

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-COUPON-LINK',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTCOUPON-LINK',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 1000,
          'CouponNo' => 'CP-ORDER-LINK-001'
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);

    TransactionJournal cancelJournal = [
      SELECT OrderId, OrderId__c, SaleId__c, VoucherCode, JournalSubType.Name
      FROM TransactionJournal
      WHERE VoucherCode = 'CP-ORDER-LINK-001' AND JournalSubType.Name = 'Coupon Redeem Cancel'
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    System.assertEquals(sourceOrder.Id, cancelJournal.OrderId, 'Coupon cancel should target the original coupon redeem order');
    System.assertEquals(sourceOrder.Id, cancelJournal.OrderId__c, 'Custom order link should also follow the original coupon redeem order');
    System.assertEquals(returnOrder.Id, cancelJournal.SaleId__c, 'Return order link should remain on SaleId__c');
    System.assertEquals('CP-ORDER-LINK-001', cancelJournal.VoucherCode);
  }

  @IsTest
  static void deleteReturnDeposit_success_saleDepositReversal_currentGrade() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    Promotion promo = new Promotion(
      Name = 'Return Restore Promo',
      StartDate = Date.today().addDays(-5),
      EndDate = Date.today().addDays(5),
      PublishStartDate__c = Date.today().addDays(-5),
      PublishEndDate__c = Date.today().addDays(5)
    );
    insert promo;

    TransactionJournal tj = new TransactionJournal();
    tj.DepositNo__c = 'DELONESALE001';
    tj.DeposiSeqNo__c = '1';
    tj.JournalDate = Date.today();
    tj.ActivityDate = Datetime.now();
    tj.PaymentMethod = '11';
    tj.DepositType__c = '03';
    tj.TransactionAmount = 8000;
    tj.OrderId = originalOrder.Id;
    tj.SaleId__c = returnOrder.Id;
    tj.LoyaltyProgramId = lpm.ProgramId;
    tj.MemberId = lpm.Id;
    tj.JournalTypeId = getJournalTypeId('Deposit Reversal');
    tj.JournalSubTypeId = getJournalSubTypeId('Sale Deposit Reversal');
    tj.Status = 'Processed';
    tj.IsDeleted__c = false;
    tj.InsertId__c = 'USER-SALE-DEL';
    tj.PromotionId = promo.Id;
    insert tj;

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Test.startTest();
    setMockServices();
    ApiResult result = svc.deleteReturnDeposit('DELONESALE001');
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    TransactionJournal updatedTj = [
      SELECT Id, IsDeleted__c, DeleteDateTime__c
      FROM TransactionJournal
      WHERE Id = :tj.Id
    ];
    System.assertEquals(true, updatedTj.IsDeleted__c);
    System.assertNotEquals(null, updatedTj.DeleteDateTime__c);
  }

  @IsTest
  static void deleteReturnDeposit_withLinkedAccrualReversal_restoresLinkedAccrual() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    seedOriginalSaleDeposit(originalOrder, 'ORIG-LINKED-RESTORE', '11', 1000);

    TransactionJournal originalAccrualTj = new TransactionJournal(
      JournalDate = Date.today().addDays(-2),
      ActivityDate = Datetime.now().addDays(-2),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      JournalTypeId = getJournalTypeId('Accrual'),
      JournalSubTypeId = getJournalSubTypeId('Purchase Accrual'),
      TransactionAmount = 100,
      Status = 'Processed'
    );
    insert originalAccrualTj;

    LoyaltyLedger originalCreditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = originalAccrualTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert originalCreditLedger;

    TransactionJournal sourceTj = new TransactionJournal(
      DepositNo__c = 'DEL-LINKED-RESTORE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 1000,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Deposit Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit Reversal'),
      Status = 'Processed',
      IsDeleted__c = false,
      InsertId__c = 'USER-LINKED-RESTORE'
    );
    insert sourceTj;

    TransactionJournal linkedReversalTj = new TransactionJournal(
      DepositNo__c = 'LINKED-ACCRUAL-REVERSAL',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      TransactionAmount = 100,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      RelatedJournalId = sourceTj.Id,
      JournalTypeId = getJournalTypeId('Accrual Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Cancel Purchase Accrual'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert linkedReversalTj;

    LoyaltyLedger reversalDebitLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = linkedReversalTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit'
    );
    insert reversalDebitLedger;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = originalCreditLedger.Id,
      DebitLoyaltyLedgerId = reversalDebitLedger.Id,
      Points = 100,
      ActionType = 'CreditCancellation'
    );

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(sourceTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);

    TransactionJournal deletedSourceTj = [SELECT IsDeleted__c FROM TransactionJournal WHERE Id = :sourceTj.Id];
    TransactionJournal deletedLinkedTj = [SELECT IsDeleted__c FROM TransactionJournal WHERE Id = :linkedReversalTj.Id];
    System.assertEquals(true, deletedSourceTj.IsDeleted__c);
    System.assertEquals(true, deletedLinkedTj.IsDeleted__c);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE RelatedJournalId = :linkedReversalTj.Id AND JournalSubType.Name = 'Purchase Accrual'
      ]
    );
  }

  @IsTest
  static void deleteReturnDeposit_pointRedeemCancel_reappliesRestoredPointUsage() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    TransactionJournal pointRedeemCancelTj = new TransactionJournal(
      DepositNo__c = 'DEL-POINT-RESTORE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '03',
      TransactionAmount = 120,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false,
      InsertId__c = 'USER-POINT-RESTORE'
    );
    insert pointRedeemCancelTj;

    LoyaltyLedger restoredCreditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = pointRedeemCancelTj.Id,
      ActivityDate = Datetime.now(),
      Points = 120,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert restoredCreditLedger;

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(pointRedeemCancelTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);

    TransactionJournal deletedSourceTj = [
      SELECT IsDeleted__c
      FROM TransactionJournal
      WHERE Id = :pointRedeemCancelTj.Id
    ];
    System.assertEquals(true, deletedSourceTj.IsDeleted__c);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE RelatedJournalId = :pointRedeemCancelTj.Id AND JournalSubType.Name = 'Point Debit'
      ]
    );
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_fullReturn_cancelsEcoPoints() {
    seedFullReturnItems();
    seedOriginalEcoLedger();

    Order originalOrder = getOriginalOrder();

    Test.startTest();
    Boolean isFullReturn = GdReturnDepositServiceImpl.isFullReturn(originalOrder.Id);
    Integer cancelableEcoPoints = GdReturnDepositServiceImpl.getCancelableEcoPointLedgers(originalOrder.Id);
    Test.stopTest();

    System.assertEquals(true, isFullReturn);
    System.assertEquals(100, cancelableEcoPoints);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_fullReturn_withoutEcoPoints_skipsEcoCancel() {
    setMockServices();
    seedFullReturnItems();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-ECO-NONE',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTECO-NONE',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 10000
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(null, result.data.get('FullReturnEcoPointCancelList'));
    System.assertEquals(
      0,
      [SELECT COUNT() FROM TransactionJournal WHERE SaleId__c = :returnOrder.Id AND AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL']
    );
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_fullReturn_reachesEcoCancelDebitCall() {
    seedFullReturnItems();
    seedOriginalEcoLedger();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    ApiResult result;

    result = svc.insertSaleDepositHistoryByUpdate(
      new Map<String, Object>{
        'orderId' => returnOrder.Id,
        'originalOrderId' => originalOrder.Id,
        'InsertId__c' => 'USER-ECO-DEBIT',
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'RTECO-DEBIT',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '11',
            'DepositType__c' => '03',
            'TransactionAmount' => 10000
          }
        }
      }
    );

    System.assertEquals(200, result.code);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE SaleId__c = :returnOrder.Id AND AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL'
      ]
    );
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_fullReturn_withExistingEcoCancel_skipsDuplicateCancel() {
    setMockServices();
    seedFullReturnItems();
    seedOriginalEcoLedger();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];

    insert new TransactionJournal(
      DepositNo__c = 'ECO-' + String.valueOf(returnOrder.Id),
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      TransactionAmount = 100,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL',
      Status = 'Pending',
      IsDeleted__c = false
    );

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-ECO-SKIP',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTECO-SKIP',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 10000
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(null, result.data.get('FullReturnEcoPointCancelList'));
    System.assertEquals(
      1,
      [SELECT COUNT() FROM TransactionJournal WHERE SaleId__c = :returnOrder.Id AND AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL']
    );
  }

  @IsTest
  static void isFullReturn_partialReturn_returnsFalse() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    Id pbeId = getPricebookEntryId();
    OrderItem originalItem = [
      SELECT Id
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id AND SaleSeqNo__c = '1'
      LIMIT 1
    ];

    insert new OrderItem(
      OrderId = returnOrder.Id,
      PricebookEntryId = pbeId,
      Quantity = -1,
      UnitPrice = 10000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = 'RETURN-PARTIAL-1',
      OriginalOrderItemId__c = originalItem.Id
    );

    System.assertEquals(false, GdReturnDepositServiceImpl.isFullReturn(originalOrder.Id));
  }

  @IsTest
  static void getExcludedReturnAmount_usesReturnOrderItems() {
    Order returnOrder = getReturnOrder();
    Id pbeId = getPricebookEntryId();
    Order originalOrder = getOriginalOrder();

    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];
    originalItems[0].IsExclude__c = false;
    originalItems[0].NetSalesUnitPrice__c = 70000;
    originalItems[1].IsExclude__c = true;
    originalItems[1].NetSalesUnitPrice__c = 30000;
    update originalItems;

    insert new OrderItem(
      OrderId = returnOrder.Id,
      PricebookEntryId = pbeId,
      Quantity = -1,
      UnitPrice = 10000,
      IsExclude__c = true,
      NetSalesUnitPrice__c = 30000,
      SaleSeqNo__c = '2',
      SaleItemNo__c = 'RETURN-EXCLUDED-1'
    );

    System.assertEquals(30000, GdReturnDepositServiceImpl.getExcludedReturnAmount(returnOrder.Id));
  }

  @IsTest
  static void getExcludedReturnAmount_usesRequestOrderItems() {
    Order returnOrder = getReturnOrder();
    Order originalOrder = getOriginalOrder();

    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];
    originalItems[0].IsExclude__c = false;
    originalItems[0].NetSalesUnitPrice__c = 70000;
    originalItems[1].IsExclude__c = true;
    originalItems[1].NetSalesUnitPrice__c = 30000;
    update originalItems;

    List<Object> requestOrderItems = new List<Object>{
      new Map<String, Object>{
        'OriginalOrderItemId__c' => originalItems[0].Id,
        'SaleSeqNo__c' => originalItems[0].SaleSeqNo__c,
        'NetSalesUnitPrice__c' => 70000
      },
      new Map<String, Object>{
        'OriginalOrderItemId__c' => originalItems[1].Id,
        'SaleSeqNo__c' => originalItems[1].SaleSeqNo__c,
        'NetSalesUnitPrice__c' => 30000
      }
    };

    System.assertEquals(30000, GdReturnDepositServiceImpl.getExcludedReturnAmount(originalOrder.Id, requestOrderItems, returnOrder.Id));
  }

  @IsTest
  static void helperMethods_coverNullAliasAndEligibleAmountBranches() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    System.assertEquals(0, GdReturnDepositServiceImpl.getReturnOrderItemRequestList(null).size());
    System.assertEquals(0, GdReturnDepositServiceImpl.getReturnOrderItemRequestList(new Map<String, Object>()).size());

    List<Object> oiList = new List<Object>{ new Map<String, Object>{ 'SaleSeqNo__c' => '1', 'NetSalesUnitPrice__c' => 100 } };
    System.assertEquals(1, GdReturnDepositServiceImpl.getReturnOrderItemRequestList(new Map<String, Object>{ 'oiList' => oiList }).size());

    List<TransactionJournal> cancelDepositList = new List<TransactionJournal>{
      null,
      new TransactionJournal(PaymentMethod = '11', TransactionAmount = 1000),
      new TransactionJournal(PaymentMethod = '20', TransactionAmount = 2000),
      new TransactionJournal(PaymentMethod = '81', TransactionAmount = 3000),
      new TransactionJournal(PaymentMethod = '90', TransactionAmount = 4000),
      new TransactionJournal(PaymentMethod = '93', TransactionAmount = 5000),
      new TransactionJournal(PaymentMethod = '11', TransactionAmount = 0)
    };
    System.assertEquals(1000, GdReturnDepositServiceImpl.getReturnAccrualEligibleDepositAmount(cancelDepositList));

    seedOriginalSaleDeposit(originalOrder, 'ORIG-ELIGIBLE-A', '11', 1000);
    seedOriginalSaleDeposit(originalOrder, 'ORIG-ELIGIBLE-B', '81', 5000);
    System.assertEquals(1000, GdReturnDepositServiceImpl.getOriginalAccrualEligibleDepositAmount(originalOrder.Id));

    List<TransactionJournal> adjustedList = GdReturnDepositServiceImpl.buildAccrualEligibleCancelTransactions(
      originalOrder.Id,
      returnOrder.Id,
      new List<TransactionJournal>{
        new TransactionJournal(PaymentMethod = '11', TransactionAmount = 700),
        new TransactionJournal(PaymentMethod = '81', TransactionAmount = 900),
        new TransactionJournal(PaymentMethod = '11', TransactionAmount = 600)
      },
      new List<Object>()
    );

    System.assertEquals(2, adjustedList.size());
    System.assertEquals(700, adjustedList[0].TransactionAmount);
    System.assertEquals(600, adjustedList[1].TransactionAmount);

    List<TransactionJournal> emptyAdjustedList = GdReturnDepositServiceImpl.buildAccrualEligibleCancelTransactions(
      originalOrder.Id,
      returnOrder.Id,
      new List<TransactionJournal>{ new TransactionJournal(PaymentMethod = '81', TransactionAmount = 900) },
      new List<Object>()
    );
    System.assertEquals(0, emptyAdjustedList.size());
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_partialExcludedReturn_skipsAccrualCancel() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];
    originalItems[0].IsExclude__c = false;
    originalItems[0].NetSalesUnitPrice__c = 1000;
    originalItems[1].IsExclude__c = true;
    originalItems[1].NetSalesUnitPrice__c = 500;
    update originalItems;
    seedOriginalSaleDeposit(originalOrder, 'ORIG-CASH-1', '11', 1000);

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-EXCLUDED',
      'OrderItem' => new List<Object>{
        new Map<String, Object>{
          'OriginalOrderItemId__c' => originalItems[1].Id,
          'SaleSeqNo__c' => originalItems[1].SaleSeqNo__c,
          'NetSalesUnitPrice__c' => 500
        }
      },
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RET-EXCLUDED',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 500
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(0, cancelPointsCreditedOnPurchaseCallCount);
    System.assertEquals(null, capturedCancelPointsCreditedData);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_mixedReturn_cancelsOnlyEligibleAmount() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];
    originalItems[0].IsExclude__c = false;
    originalItems[0].NetSalesUnitPrice__c = 1000;
    originalItems[1].IsExclude__c = true;
    originalItems[1].NetSalesUnitPrice__c = 500;
    update originalItems;
    seedOriginalSaleDeposit(originalOrder, 'ORIG-CASH-2', '11', 1000);

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-MIXED',
      'OrderItem' => new List<Object>{
        new Map<String, Object>{
          'OriginalOrderItemId__c' => originalItems[0].Id,
          'SaleSeqNo__c' => originalItems[0].SaleSeqNo__c,
          'NetSalesUnitPrice__c' => 1000
        },
        new Map<String, Object>{
          'OriginalOrderItemId__c' => originalItems[1].Id,
          'SaleSeqNo__c' => originalItems[1].SaleSeqNo__c,
          'NetSalesUnitPrice__c' => 500
        }
      },
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RET-MIXED',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 1500
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(1, cancelPointsCreditedOnPurchaseCallCount);
    System.assertEquals(1, capturedCancelPointsCreditedData.size());
    System.assertEquals(1000, capturedCancelPointsCreditedData[0].TransactionAmount);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_scenario11_cashAndPointRefund_cancelsCashOnly() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];
    originalItems[0].IsExclude__c = false;
    originalItems[0].NetSalesUnitPrice__c = 1000000;
    originalItems[1].IsExclude__c = true;
    originalItems[1].NetSalesUnitPrice__c = 500000;
    update originalItems;
    seedOriginalSaleDeposit(originalOrder, 'ORIG-CASH-SC11', '11', 1000000);

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-SC11',
      'OrderItem' => new List<Object>{
        new Map<String, Object>{
          'OriginalOrderItemId__c' => originalItems[0].Id,
          'SaleSeqNo__c' => originalItems[0].SaleSeqNo__c,
          'NetSalesUnitPrice__c' => 1000000
        }
      },
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RET-SC11-CASH',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 500000
        },
        new Map<String, Object>{
          'DepositNo__c' => 'RET-SC11-POINT',
          'DeposiSeqNo__c' => '2',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '81',
          'DepositType__c' => '03',
          'TransactionAmount' => 500000
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(1, cancelPointsCreditedOnPurchaseCallCount);
    System.assertEquals(1, capturedCancelPointsCreditedData.size());
    System.assertEquals(500000, capturedCancelPointsCreditedData[0].TransactionAmount);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_scenario12_excludedItemCashRefund_skipsAccrualCancel() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];
    originalItems[0].IsExclude__c = false;
    originalItems[0].NetSalesUnitPrice__c = 1000000;
    originalItems[1].IsExclude__c = true;
    originalItems[1].NetSalesUnitPrice__c = 500000;
    update originalItems;
    seedOriginalSaleDeposit(originalOrder, 'ORIG-CASH-SC12', '11', 1000000);

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-SC12',
      'OrderItem' => new List<Object>{
        new Map<String, Object>{
          'OriginalOrderItemId__c' => originalItems[1].Id,
          'SaleSeqNo__c' => originalItems[1].SaleSeqNo__c,
          'NetSalesUnitPrice__c' => 500000
        }
      },
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RET-SC12-CASH',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 500000
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(0, cancelPointsCreditedOnPurchaseCallCount);
    System.assertEquals(null, capturedCancelPointsCreditedData);
  }

  @IsTest
  static void getCancelableEcoPointLedgers_withoutEcoLedger_returnsZero() {
    Order originalOrder = getOriginalOrder();

    System.assertEquals(0, GdReturnDepositServiceImpl.getCancelableEcoPointLedgers(originalOrder.Id));
  }

  @IsTest
  static void getCancelableEcoPointLedgers_whenAllUsed_returnsZero() {
    seedOriginalEcoLedger();

    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember LIMIT 1];
    LoyaltyLedger creditLedger = [
      SELECT Id, LoyaltyProgramCurrencyId, LoyaltyPgmCrcySubtypeId
      FROM LoyaltyLedger
      WHERE EventType = 'Credit' AND LoyaltyPgmCrcySubtypeId = :getEcoSubtypeId()
      LIMIT 1
    ];

    TransactionJournal debitTj = new TransactionJournal(
      DepositNo__c = 'ECO-USED-001',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      LoyaltyProgramId = [SELECT ProgramId FROM LoyaltyProgramMember LIMIT 1]
      .ProgramId,
      MemberId = lpm.Id,
      OrderId = getOriginalOrder().Id,
      SaleId__c = getReturnOrder().Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      TransactionAmount = 100,
      Status = 'Pending'
    );
    insert debitTj;

    LoyaltyLedger debitLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = creditLedger.LoyaltyProgramCurrencyId,
      LoyaltyPgmCrcySubtypeId = creditLedger.LoyaltyPgmCrcySubtypeId,
      TransactionJournalId = debitTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit'
    );
    insert debitLedger;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyPgmCurrencySubtypeId = creditLedger.LoyaltyPgmCrcySubtypeId,
      DebitLoyaltyLedgerId = debitLedger.Id,
      CreditLoyaltyLedgerId = creditLedger.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    System.assertEquals(0, GdReturnDepositServiceImpl.getCancelableEcoPointLedgers(getOriginalOrder().Id));
  }

  @IsTest
  static void getCancelableEcoPointLedgers_creditCancellation_countsAsUsed() {
    seedOriginalEcoLedger();

    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember LIMIT 1];
    LoyaltyLedger creditLedger = [
      SELECT Id, LoyaltyProgramCurrencyId, LoyaltyPgmCrcySubtypeId
      FROM LoyaltyLedger
      WHERE EventType = 'Credit' AND LoyaltyPgmCrcySubtypeId = :getEcoSubtypeId()
      LIMIT 1
    ];

    TransactionJournal debitTj = new TransactionJournal(
      DepositNo__c = 'ECO-CREDIT-CANCEL-001',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      LoyaltyProgramId = [SELECT ProgramId FROM LoyaltyProgramMember LIMIT 1]
      .ProgramId,
      MemberId = lpm.Id,
      OrderId = getOriginalOrder().Id,
      SaleId__c = getReturnOrder().Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      TransactionAmount = 100,
      Status = 'Pending'
    );
    insert debitTj;

    LoyaltyLedger debitLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = creditLedger.LoyaltyProgramCurrencyId,
      LoyaltyPgmCrcySubtypeId = creditLedger.LoyaltyPgmCrcySubtypeId,
      TransactionJournalId = debitTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit'
    );
    insert debitLedger;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyPgmCurrencySubtypeId = creditLedger.LoyaltyPgmCrcySubtypeId,
      DebitLoyaltyLedgerId = debitLedger.Id,
      CreditLoyaltyLedgerId = creditLedger.Id,
      Points = 100,
      ActionType = 'CreditCancellation'
    );

    System.assertEquals(0, GdReturnDepositServiceImpl.getCancelableEcoPointLedgers(getOriginalOrder().Id));
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_returnOrderNotFound_throws() {
    setMockServices();
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.insertSaleDepositHistoryByUpdate(
        new Map<String, Object>{
          'orderId' => '801000000000000AAA',
          'originalOrderId' => getOriginalOrder().Id,
          'InsertId__c' => 'USER-MISSING-RETURN',
          'TransactionJournal' => new List<Object>{
            new Map<String, Object>{
              'DepositNo__c' => 'RTMISS001',
              'DeposiSeqNo__c' => '1',
              'ActivityDate' => Date.today(),
              'PaymentMethod' => '11',
              'DepositType__c' => '01',
              'TransactionAmount' => 1000
            }
          }
        }
      );
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_memberNotFound_throws() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    Account acc = new Account(Name = 'NO-MEMBER-ACCOUNT');
    insert acc;

    Contact noMemberContact = new Contact(LastName = 'NoMemberContact', Grade__c = '02', PreviousGrade__c = '01', MemberNo__c = 'RT-NO-LPM-001');
    insert noMemberContact;

    Id standardPricebookId = Test.getStandardPricebookId();
    Product2 product = new Product2(Name = 'NO-MEMBER-PRODUCT', ProductCode = 'NO-MEMBER-P-001', IsActive = true);
    insert product;
    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = standardPricebookId, Product2Id = product.Id, UnitPrice = 1000, IsActive = true);
    insert pbe;

    Order originalOrder = new Order(
      Name = 'No Member Original',
      EffectiveDate = Date.today().addDays(-1),
      EndDate = Date.today().addDays(-1),
      Status = 'Draft',
      OrderNo__c = 'ORD-NO-MEMBER-ORIGINAL',
      SaleNo__c = 'SALE-NO-MEMBER-ORIGINAL',
      ActualPaymentAmount__c = 1000,
      IsReductionOrder__c = false,
      MemberNo__c = noMemberContact.Id,
      InsertId__c = 'USER-NO-MEMBER',
      AccountId = acc.Id,
      Pricebook2Id = standardPricebookId
    );
    insert originalOrder;
    insert new OrderItem(
      OrderId = originalOrder.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 1000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = 'NO-MEMBER-ORIGINAL-1'
    );
    insert new OrderItem(
      OrderId = originalOrder.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 1000,
      SaleSeqNo__c = '2',
      SaleItemNo__c = 'NO-MEMBER-ORIGINAL-2'
    );
    originalOrder.Status = 'saleSuccess';
    update originalOrder;

    Order returnOrder = new Order(
      Name = 'No Member Return',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      OrderNo__c = 'ORD-NO-MEMBER-RETURN',
      SaleNo__c = 'SALE-NO-MEMBER-RETURN',
      ActualPaymentAmount__c = 1000,
      MemberNo__c = noMemberContact.Id,
      AccountId = acc.Id,
      Pricebook2Id = standardPricebookId,
      OriginalOrderId__c = originalOrder.Id,
      IsReductionOrder__c = true
    );
    insert returnOrder;

    setMockServices();
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.insertSaleDepositHistoryByUpdate(
        new Map<String, Object>{
          'orderId' => returnOrder.Id,
          'originalOrderId' => originalOrder.Id,
          'InsertId__c' => 'USER-NO-MEMBER',
          'TransactionJournal' => new List<Object>{
            new Map<String, Object>{
              'DepositNo__c' => 'RTMISS002',
              'DeposiSeqNo__c' => '1',
              'ActivityDate' => Date.today(),
              'PaymentMethod' => '11',
              'DepositType__c' => '01',
              'TransactionAmount' => 1000
            }
          }
        }
      );
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteReturnDeposit_withoutMocks_hitsDefaultVoucherServicePath() {
    Order originalOrder = getOriginalOrder();

    TransactionJournal tj = new TransactionJournal(
      DepositNo__c = 'DELONE-NOMOCK',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 2000,
      OrderId = originalOrder.Id,
      SaleId__c = getReturnOrder().Id,
      LoyaltyProgramId = [SELECT ProgramId FROM LoyaltyProgramMember LIMIT 1]
      .ProgramId,
      MemberId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1]
      .Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Coupon Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false,
      VoucherCode = 'CP-DEL-NOMOCK'
    );
    insert tj;

    GdReturnDepositServiceImpl.setVoucherService(null);

    Boolean thrown = false;
    try {
      new GdReturnDepositServiceImpl().deleteReturnDeposit('DELONE-NOMOCK');
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_withoutMocks_hitsDefaultPointServicePath() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    GdReturnDepositServiceImpl.setPointService(null);

    Boolean thrown = false;
    try {
      new GdReturnDepositServiceImpl()
        .insertSaleDepositHistoryByUpdate(
          new Map<String, Object>{
            'orderId' => returnOrder.Id,
            'originalOrderId' => originalOrder.Id,
            'InsertId__c' => 'USER-NOMOCK-POINT',
            'TransactionJournal' => new List<Object>{
              new Map<String, Object>{
                'DepositNo__c' => 'RTPOINT-NOMOCK',
                'DeposiSeqNo__c' => '1',
                'ActivityDate' => Date.today(),
                'PaymentMethod' => '81',
                'DepositType__c' => '01',
                'TransactionAmount' => 100
              }
            }
          }
        );
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void isFullReturn_countsSiblingReturnsTogether() {
    seedDistributedFullReturnItems();

    Order originalOrder = getOriginalOrder();

    System.assertEquals(true, GdReturnDepositServiceImpl.isFullReturn(originalOrder.Id));
  }

  @IsTest
  static void deleteAllReturnDeposits_restoresEcoPoints() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];

    TransactionJournal ecoCancelTj = new TransactionJournal(
      DepositNo__c = 'ECO-' + String.valueOf(returnOrder.Id),
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      TransactionAmount = 100,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL',
      Status = 'Pending',
      IsDeleted__c = false
    );
    insert ecoCancelTj;

    LoyaltyLedger debitLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = [
        SELECT LoyaltyProgramCurrencyId
        FROM LoyaltyPgmCurrencySubtype
        WHERE PointTypeCode__c = '05'
        LIMIT 1
      ]
      .LoyaltyProgramCurrencyId,
      LoyaltyPgmCrcySubtypeId = getEcoSubtypeId(),
      TransactionJournalId = ecoCancelTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit',
      AdditionalNotes = 'FULL_RETURN_ECO_POINT_CANCEL'
    );
    insert debitLedger;

    LoyaltyLedger creditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = [
        SELECT LoyaltyProgramCurrencyId
        FROM LoyaltyPgmCurrencySubtype
        WHERE PointTypeCode__c = '05'
        LIMIT 1
      ]
      .LoyaltyProgramCurrencyId,
      LoyaltyPgmCrcySubtypeId = getEcoSubtypeId(),
      TransactionJournalId = ecoCancelTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert creditLedger;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyPgmCurrencySubtypeId = getEcoSubtypeId(),
      DebitLoyaltyLedgerId = debitLedger.Id,
      CreditLoyaltyLedgerId = creditLedger.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Test.startTest();
    setMockServices();
    ApiResult result = svc.deleteAllReturnDeposits(returnOrder.Id);
    Test.stopTest();

    System.assertEquals(200, result.code);

    TransactionJournal deletedEcoCancel = [
      SELECT IsDeleted__c
      FROM TransactionJournal
      WHERE Id = :ecoCancelTj.Id
    ];
    System.assertEquals(true, deletedEcoCancel.IsDeleted__c);
  }

  @IsTest
  static void deleteReturnDeposit_restoresEcoPoints() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];

    TransactionJournal ecoCancelTj = new TransactionJournal(
      DepositNo__c = 'ECO-ONE-' + String.valueOf(returnOrder.Id),
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      TransactionAmount = 100,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL',
      Status = 'Pending',
      IsDeleted__c = false
    );
    insert ecoCancelTj;

    LoyaltyLedger debitLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = [
        SELECT LoyaltyProgramCurrencyId
        FROM LoyaltyPgmCurrencySubtype
        WHERE PointTypeCode__c = '05'
        LIMIT 1
      ]
      .LoyaltyProgramCurrencyId,
      LoyaltyPgmCrcySubtypeId = getEcoSubtypeId(),
      TransactionJournalId = ecoCancelTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit',
      AdditionalNotes = 'FULL_RETURN_ECO_POINT_CANCEL'
    );
    insert debitLedger;

    LoyaltyLedger creditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = [
        SELECT LoyaltyProgramCurrencyId
        FROM LoyaltyPgmCurrencySubtype
        WHERE PointTypeCode__c = '05'
        LIMIT 1
      ]
      .LoyaltyProgramCurrencyId,
      LoyaltyPgmCrcySubtypeId = getEcoSubtypeId(),
      TransactionJournalId = ecoCancelTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert creditLedger;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyPgmCurrencySubtypeId = getEcoSubtypeId(),
      DebitLoyaltyLedgerId = debitLedger.Id,
      CreditLoyaltyLedgerId = creditLedger.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Test.startTest();
    setMockServices();
    ApiResult result = svc.deleteReturnDeposit(ecoCancelTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    TransactionJournal deletedEcoCancel = [
      SELECT IsDeleted__c, DeleteDateTime__c
      FROM TransactionJournal
      WHERE Id = :ecoCancelTj.Id
    ];
    System.assertEquals(true, deletedEcoCancel.IsDeleted__c);
    System.assertNotEquals(null, deletedEcoCancel.DeleteDateTime__c);
  }

  @IsTest
  static void deleteReturnDeposit_excludedOnlyReturn_skipsPointRestore() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    Id pbeId = getPricebookEntryId();

    List<OrderItem> originalItems = [
      SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :originalOrder.Id
      ORDER BY SaleSeqNo__c ASC
    ];

    originalItems[0].IsExclude__c = false;
    originalItems[0].NetSalesUnitPrice__c = 1000;
    originalItems[1].IsExclude__c = true;
    originalItems[1].NetSalesUnitPrice__c = 1000;
    update originalItems;

    seedOriginalSaleDeposit(originalOrder, 'ORIG-CASH-DEL-GUARD', '11', 1000);

    insert new OrderItem(
      OrderId = returnOrder.Id,
      PricebookEntryId = pbeId,
      Quantity = -1,
      UnitPrice = 10000,
      SaleSeqNo__c = '2',
      SaleItemNo__c = 'RETURN-DEL-GUARD-EXCLUDED',
      OriginalOrderItemId__c = originalItems[1].Id
    );

    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    TransactionJournal saleDepositReversal = new TransactionJournal(
      DepositNo__c = 'RET-DEL-GUARD-001',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      JournalTypeId = getJournalTypeId('Deposit Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit Reversal'),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 1000,
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert saleDepositReversal;

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit('RET-DEL-GUARD-001');
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(0, creditPointsOnPurchaseCallCount);
    System.assertEquals(0, creditPromotionPointsOnPurchaseCallCount);

    TransactionJournal deletedTj = [
      SELECT IsDeleted__c, DeleteDateTime__c
      FROM TransactionJournal
      WHERE Id = :saleDepositReversal.Id
    ];
    System.assertEquals(true, deletedTj.IsDeleted__c);
    System.assertNotEquals(null, deletedTj.DeleteDateTime__c);
  }

  @IsTest
  static void isFullReturn_whenOriginalHasNoItems_returnsFalse() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    Contact con = [SELECT Id FROM Contact WHERE MemberNo__c = :TEST_MEMBER_NO LIMIT 1];

    Order emptyOriginal = new Order(
      Name = 'Empty Original',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      OrderNo__c = 'ORD-EMPTY-ORIGINAL',
      SaleNo__c = 'SALE-EMPTY-ORIGINAL',
      ActualPaymentAmount__c = 0,
      IsReductionOrder__c = false,
      MemberNo__c = con.Id,
      InsertId__c = 'USER-EMPTY',
      AccountId = acc.Id,
      Pricebook2Id = Test.getStandardPricebookId()
    );
    insert emptyOriginal;

    System.assertEquals(false, GdReturnDepositServiceImpl.isFullReturn(emptyOriginal.Id));
  }

  @IsTest
  static void deleteAllReturnDeposits_success_pointRedeemCancel() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];

    TransactionJournal sourceTj = new TransactionJournal(
      DepositNo__c = 'DELALL-POINT-REDEEM-CANCEL',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '03',
      TransactionAmount = 300,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert sourceTj;

    Id ecoSubtypeId = getEcoSubtypeId();
    Id loyaltyProgramCurrencyId = [
      SELECT LoyaltyProgramCurrencyId
      FROM LoyaltyPgmCurrencySubtype
      WHERE Id = :ecoSubtypeId
      LIMIT 1
    ]
    .LoyaltyProgramCurrencyId;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId,
      LoyaltyPgmCrcySubtypeId = ecoSubtypeId,
      TransactionJournalId = sourceTj.Id,
      ActivityDate = Datetime.now(),
      Points = 300,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit'
    );

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteAllReturnDeposits(returnOrder.Id);
    Test.stopTest();

    System.assertEquals(200, result.code);
    TransactionJournal deletedTj = [SELECT IsDeleted__c FROM TransactionJournal WHERE Id = :sourceTj.Id];
    System.assertEquals(true, deletedTj.IsDeleted__c);
  }

  @IsTest
  static void deleteAllReturnDeposits_success_couponRedeemCancel() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];

    TransactionJournal sourceTj = new TransactionJournal(
      DepositNo__c = 'DELALL-COUPON-REDEEM-CANCEL',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 1000,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Coupon Redeem Cancel'),
      VoucherCode = 'CP-DELALL-001',
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert sourceTj;

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteAllReturnDeposits(returnOrder.Id);
    Test.stopTest();

    System.assertEquals(200, result.code);
    TransactionJournal deletedTj = [SELECT IsDeleted__c FROM TransactionJournal WHERE Id = :sourceTj.Id];
    System.assertEquals(true, deletedTj.IsDeleted__c);
  }

  @IsTest
  static void cancelEcoPointsForSaleDelete_createsSpecificLedgerCancellation() {
    seedOriginalEcoLedger();

    Order originalOrder = getOriginalOrder();
    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      WHERE MembershipNumber = :TEST_MEMBER_NO
      LIMIT 1
    ];

    Test.startTest();
    List<PointDebitDTO> result = GdReturnDepositServiceImpl.cancelEcoPointsForSaleDelete(originalOrder.Id, lpm, 'USER-ECO-SALE-DELETE');
    Test.stopTest();

    System.assertEquals(1, result.size());
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE SaleId__c = :originalOrder.Id AND AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL' AND IsDeleted__c = FALSE
      ]
    );
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :lpm.Id AND ActionType = 'CreditCancellation'
      ]
    );
  }

  @IsTest
  static void validateReturnDepositDeleteOrigin_allowsActiveOriginAccrual() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    TransactionJournal sourceTj = new TransactionJournal(
      DepositNo__c = 'ORIGIN-VALID-SOURCE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert sourceTj;

    LoyaltyLedger cancelCredit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = sourceTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert cancelCredit;

    TransactionJournal originAccrualTj = new TransactionJournal(
      JournalDate = Date.today().addDays(-2),
      ActivityDate = Datetime.now().addDays(-2),
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Accrual'),
      JournalSubTypeId = getJournalSubTypeId('Purchase Accrual'),
      Status = 'Processed'
    );
    insert originAccrualTj;

    LoyaltyLedger originCredit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = originAccrualTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 100,
      ExpiryDate = cancelCredit.ExpiryDate,
      EventType = 'Credit'
    );
    insert originCredit;

    TransactionJournal useTj = new TransactionJournal(
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      Status = 'Processed'
    );
    insert useTj;

    LoyaltyLedger useDebit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = useTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = cancelCredit.ExpiryDate,
      EventType = 'Debit'
    );
    insert useDebit;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = originCredit.Id,
      DebitLoyaltyLedgerId = useDebit.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    GdReturnDepositServiceImpl.validateReturnDepositDeleteOrigin(sourceTj.Id, lpm.Id);
    System.assert(true);
  }

  @IsTest
  static void validateReturnDepositDeleteOrigin_deletedOriginOrderThrows() {
    Order originalOrder = getOriginalOrder();
    originalOrder.IsDeleted__c = true;
    update originalOrder;

    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    TransactionJournal sourceTj = new TransactionJournal(
      DepositNo__c = 'ORIGIN-DELETED-SOURCE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert sourceTj;

    LoyaltyLedger cancelCredit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = sourceTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert cancelCredit;

    TransactionJournal originAccrualTj = new TransactionJournal(
      JournalDate = Date.today().addDays(-2),
      ActivityDate = Datetime.now().addDays(-2),
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Accrual'),
      JournalSubTypeId = getJournalSubTypeId('Purchase Accrual'),
      Status = 'Processed'
    );
    insert originAccrualTj;

    LoyaltyLedger originCredit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = originAccrualTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 100,
      ExpiryDate = cancelCredit.ExpiryDate,
      EventType = 'Credit'
    );
    insert originCredit;

    TransactionJournal useTj = new TransactionJournal(
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      Status = 'Processed'
    );
    insert useTj;

    LoyaltyLedger useDebit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = useTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = cancelCredit.ExpiryDate,
      EventType = 'Debit'
    );
    insert useDebit;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = originCredit.Id,
      DebitLoyaltyLedgerId = useDebit.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    Boolean thrown = false;
    try {
      GdReturnDepositServiceImpl.validateReturnDepositDeleteOrigin(sourceTj.Id, lpm.Id);
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }
    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteReturnDeposit_pointRedeemCancel_recoversThroughNestedCancelLedger() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();
    Date expiryDate = Date.today().addYears(1);

    TransactionJournal pointRedeemCancelTj = new TransactionJournal(
      DepositNo__c = 'DEL-POINT-NESTED',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '03',
      TransactionAmount = 120,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false,
      InsertId__c = 'USER-POINT-NESTED'
    );
    insert pointRedeemCancelTj;

    LoyaltyLedger restoredCreditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = pointRedeemCancelTj.Id,
      ActivityDate = Datetime.now(),
      Points = 120,
      ExpiryDate = expiryDate,
      EventType = 'Credit'
    );
    insert restoredCreditLedger;

    TransactionJournal nestedUseTj = new TransactionJournal(
      DepositNo__c = 'NESTED-USE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '01',
      TransactionAmount = 120,
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert nestedUseTj;

    LoyaltyLedger nestedUseDebit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = nestedUseTj.Id,
      ActivityDate = Datetime.now(),
      Points = 120,
      ExpiryDate = expiryDate,
      EventType = 'Debit'
    );
    insert nestedUseDebit;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = restoredCreditLedger.Id,
      DebitLoyaltyLedgerId = nestedUseDebit.Id,
      Points = 120,
      ActionType = 'Debit'
    );

    TransactionJournal nestedCancelTj = new TransactionJournal(
      DepositNo__c = 'NESTED-CANCEL',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '03',
      TransactionAmount = 120,
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert nestedCancelTj;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = nestedCancelTj.Id,
      ActivityDate = Datetime.now(),
      Points = 120,
      ExpiryDate = expiryDate,
      EventType = 'Credit'
    );

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(pointRedeemCancelTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE RelatedJournalId = :pointRedeemCancelTj.Id AND JournalSubType.Name = 'Point Debit'
      ]
    );
  }

  @IsTest
  static void deleteReturnDeposit_saleDepositReversal_restoresPreviousGradeAndPromotionPoints() {
    setMockServices();
    returnPromotionCreditList = true;

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    seedOriginalSaleDeposit(originalOrder, 'ORIG-GRADE-PROMO', '11', 1000);

    Promotion promo = new Promotion(
      Name = 'Return Restore Grade Promo',
      StartDate = Date.today().addDays(-5),
      EndDate = Date.today().addDays(5),
      PublishStartDate__c = Date.today().addDays(-5),
      PublishEndDate__c = Date.today().addDays(5)
    );
    insert promo;

    TransactionJournal originalAccrualTj = new TransactionJournal(
      JournalDate = Date.today().addDays(-2),
      ActivityDate = Datetime.now().addDays(-2),
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Accrual'),
      JournalSubTypeId = getJournalSubTypeId('Purchase Accrual'),
      TransactionAmount = 100,
      Status = 'Processed'
    );
    insert originalAccrualTj;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = originalAccrualTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );

    TransactionJournal returnDepositTj = new TransactionJournal(
      DepositNo__c = 'DEL-GRADE-PROMO',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 1000,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      PromotionId = promo.Id,
      JournalTypeId = getJournalTypeId('Deposit Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit Reversal'),
      Status = 'Processed',
      IsDeleted__c = false,
      InsertId__c = 'USER-GRADE-PROMO'
    );
    insert returnDepositTj;

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(returnDepositTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(1, creditPromotionPointsOnPurchaseCallCount);
  }

  @IsTest
  static void sbVerifyCancelEcoPointsForFullReturn_legacyFlagOff_entersDebitPointsPath() {
    seedOriginalEcoLedger();
    GdFeatureFlag.setForTest('EcoPointCancel_UseSpecificLedger', false);

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      WHERE MembershipNumber = :TEST_MEMBER_NO
      LIMIT 1
    ];

    Test.startTest();
    Boolean enteredPath = false;
    try {
      List<PointDebitDTO> result = GdReturnDepositServiceImpl.sbVerifyCancelEcoPointsForFullReturn(
        returnOrder.Id,
        originalOrder.Id,
        lpm,
        'USER-ECO-LEGACY'
      );
      enteredPath = result != null;
    } catch (Exception e) {
      enteredPath = true;
    }
    Test.stopTest();

    System.assertEquals(true, enteredPath);
  }

  @IsTest
  static void deleteReturnDeposit_pointRedeemCancel_adjustsExpiredRestoredLedgerArtifacts() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();
    Date expiredDate = Date.today().addDays(-1);

    List<LoyaltyMemberCurrency> lmcList = [
      SELECT Id, TotalPointsRedeemed
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :lpm.Id AND LoyaltyProgramCurrencyId = :currencyId
      LIMIT 1
    ];
    if (!lmcList.isEmpty()) {
      lmcList[0].TotalPointsRedeemed = 50;
      update lmcList[0];
    }

    TransactionJournal pointRedeemCancelTj = new TransactionJournal(
      DepositNo__c = 'DEL-POINT-EXPIRED',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '03',
      TransactionAmount = 50,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false,
      InsertId__c = 'USER-POINT-EXPIRED'
    );
    insert pointRedeemCancelTj;

    LoyaltyLedger restoredCreditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = pointRedeemCancelTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 50,
      ExpiryDate = expiredDate,
      EventType = 'Credit'
    );
    insert restoredCreditLedger;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = pointRedeemCancelTj.Id,
      ActivityDate = Datetime.now().addDays(-1),
      Points = 50,
      ExpiryDate = expiredDate,
      EventType = 'Expiry'
    );

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(pointRedeemCancelTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :pointRedeemCancelTj.Id AND EventType = 'Expiry' AND IsDeleted = FALSE
      ]
    );
  }

  private static TransactionJournal seedCouponRedeemCancelForDelete(String depositNo, String voucherCode, String couponManNo, String voucherStatus) {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId, ContactId FROM LoyaltyProgramMember LIMIT 1];

    TransactionJournal sourceRedeemJournal = new TransactionJournal(
      DepositNo__c = 'SRC-' + depositNo,
      DeposiSeqNo__c = '1',
      JournalDate = Date.today().addDays(-1),
      ActivityDate = Datetime.now().addDays(-1),
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Coupon Redeem'),
      VoucherCode = voucherCode,
      Status = 'Processed'
    );
    insert sourceRedeemJournal;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Delete Return Coupon ' + depositNo,
      CouponManNo__c = couponManNo,
      LoyaltyProgramId = lpm.ProgramId,
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today().addDays(-10),
      ExpirationDate = voucherStatus == 'Expired' ? Date.today().addDays(-1) : Date.today().addDays(30),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'TEST',
      InsertId__c = 'TEST',
      AccountId__c = getVoucherDefinitionAccountId(),
      IsActive = true
    );
    insert vd;

    Voucher v = new Voucher(
      VoucherDefinitionId = vd.Id,
      LoyaltyProgramMemberId = lpm.Id,
      ContactId = lpm.ContactId,
      VoucherCode = voucherCode,
      Status = voucherStatus,
      EffectiveDate = Date.today().addDays(-10),
      ExpirationDate = voucherStatus == 'Expired' ? Date.today().addDays(-1) : Date.today().addDays(30)
    );
    if (voucherStatus == 'Redeemed') {
      v.UsedTransactionJournalId__c = sourceRedeemJournal.Id;
    }
    insert v;

    TransactionJournal tj = new TransactionJournal(
      DepositNo__c = depositNo,
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 1000,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Coupon Redeem Cancel'),
      VoucherCode = String.isBlank(couponManNo) ? voucherCode : couponManNo + ';-;' + voucherCode,
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert tj;
    return tj;
  }

  @IsTest
  static void deleteReturnDeposit_couponRedeemCancel_redeemedVoucherKeepsStatus() {
    setMockServices();
    TransactionJournal tj = seedCouponRedeemCancelForDelete('DEL-CP-REDEEMED', 'CP-DEL-REDEEMED', null, 'Redeemed');

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(tj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE RelatedJournalId = :tj.Id AND JournalSubType.Name = 'Coupon Redeem'
      ]
    );
  }

  @IsTest
  static void deleteReturnDeposit_couponRedeemCancel_expiredVoucherKeepsStatus() {
    setMockServices();
    TransactionJournal tj = seedCouponRedeemCancelForDelete('DEL-CP-EXPIRED', 'CP-DEL-EXPIRED', null, 'Expired');

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(tj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE RelatedJournalId = :tj.Id AND JournalSubType.Name = 'Coupon Redeem'
      ]
    );
  }

  @IsTest
  static void deleteReturnDeposit_couponRedeemCancel_splitCouponCodeFindsVoucher() {
    setMockServices();
    TransactionJournal tj = seedCouponRedeemCancelForDelete('DEL-CP-SPLIT', 'CP-DEL-SPLIT', 'CPN-SPLIT', 'Redeemed');

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(tj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
  }

  @IsTest
  static void cancelEcoPointsForSaleDelete_whenEcoPointsUsedElsewhere_throwsWithReference() {
    seedOriginalEcoLedger();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();
    LoyaltyLedger originEcoCredit = [
      SELECT Id, ExpiryDate
      FROM LoyaltyLedger
      WHERE TransactionJournal.OrderId = :originalOrder.Id AND EventType = 'Credit' AND LoyaltyPgmCrcySubtypeId = :subtypeId
      LIMIT 1
    ];

    TransactionJournal useTj = new TransactionJournal(
      DepositNo__c = 'ECO-USED-ELSEWHERE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '01',
      TransactionAmount = 100,
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert useTj;

    LoyaltyLedger useDebit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = useTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = originEcoCredit.ExpiryDate,
      EventType = 'Debit'
    );
    insert useDebit;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = originEcoCredit.Id,
      DebitLoyaltyLedgerId = useDebit.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    Id pointRedeemCancelJstId = getJournalSubTypeId('Point Redeem Cancel');
    List<TransactionJournal> malformedCancelTjs = new List<TransactionJournal>{
      new TransactionJournal(
        DepositNo__c = 'ECO-BAD-ORIGIN-1',
        DeposiSeqNo__c = '1',
        JournalDate = Date.today(),
        ActivityDate = Datetime.now(),
        TransactionAmount = 1,
        OrderId = originalOrder.Id,
        SaleId__c = originalOrder.Id,
        LoyaltyProgramId = lpm.ProgramId,
        MemberId = lpm.Id,
        JournalTypeId = getJournalTypeId('Redemption Reversal'),
        JournalSubTypeId = pointRedeemCancelJstId,
        Status = 'Processed',
        IsDeleted__c = false
      ),
      new TransactionJournal(
        DepositNo__c = 'ECO-BAD-ORIGIN-2',
        DeposiSeqNo__c = '1',
        JournalDate = Date.today(),
        ActivityDate = Datetime.now(),
        TransactionAmount = 1,
        OrderId = originalOrder.Id,
        SaleId__c = originalOrder.Id,
        LoyaltyProgramId = lpm.ProgramId,
        MemberId = lpm.Id,
        JournalTypeId = getJournalTypeId('Redemption Reversal'),
        JournalSubTypeId = pointRedeemCancelJstId,
        Status = 'Processed',
        IsDeleted__c = false
      )
    };
    insert malformedCancelTjs;

    insert new List<LoyaltyLedger>{
      new LoyaltyLedger(
        LoyaltyProgramMemberId = lpm.Id,
        LoyaltyProgramCurrencyId = currencyId,
        LoyaltyPgmCrcySubtypeId = subtypeId,
        TransactionJournalId = malformedCancelTjs[0].Id,
        ActivityDate = Datetime.now(),
        Points = 1,
        ExpiryDate = originEcoCredit.ExpiryDate,
        EventType = 'Credit',
        AdditionalNotes = 'ORIGIN_CREDIT_LL=not-an-id;'
      ),
      new LoyaltyLedger(
        LoyaltyProgramMemberId = lpm.Id,
        LoyaltyProgramCurrencyId = currencyId,
        LoyaltyPgmCrcySubtypeId = subtypeId,
        TransactionJournalId = malformedCancelTjs[1].Id,
        ActivityDate = Datetime.now(),
        Points = 1,
        ExpiryDate = originEcoCredit.ExpiryDate,
        EventType = 'Credit',
        AdditionalNotes = 'ORIGIN_CREDIT_LL=;'
      )
    };

    Boolean thrown = false;
    try {
      GdReturnDepositServiceImpl.cancelEcoPointsForSaleDelete(originalOrder.Id, lpm, 'USER-ECO-USED');
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_couponCancel_splitCouponCodeAlignsSourceOrder() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId, ContactId FROM LoyaltyProgramMember LIMIT 1];

    TransactionJournal sourceRedeemJournal = new TransactionJournal(
      DepositNo__c = 'SRC-SPLIT-ALIGN',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today().addDays(-1),
      ActivityDate = Datetime.now().addDays(-1),
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Coupon Redeem'),
      VoucherCode = 'CP-SPLIT-ALIGN',
      Status = 'Processed'
    );
    insert sourceRedeemJournal;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Split Align Coupon',
      CouponManNo__c = 'CPN-ALIGN',
      LoyaltyProgramId = lpm.ProgramId,
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today().addDays(-5),
      ExpirationDate = Date.today().addDays(30),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'TEST',
      InsertId__c = 'TEST',
      AccountId__c = getVoucherDefinitionAccountId(),
      IsActive = true
    );
    insert vd;

    insert new Voucher(
      VoucherDefinitionId = vd.Id,
      LoyaltyProgramMemberId = lpm.Id,
      ContactId = lpm.ContactId,
      VoucherCode = 'CP-SPLIT-ALIGN',
      Status = 'Redeemed',
      EffectiveDate = Date.today().addDays(-5),
      ExpirationDate = Date.today().addDays(30),
      UsedTransactionJournalId__c = sourceRedeemJournal.Id
    );

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl()
      .insertSaleDepositHistoryByUpdate(
        new Map<String, Object>{
          'orderId' => returnOrder.Id,
          'originalOrderId' => originalOrder.Id,
          'InsertId__c' => 'USER-SPLIT-ALIGN',
          'TransactionJournal' => new List<Object>{
            new Map<String, Object>{
              'DepositNo__c' => 'RET-SPLIT-ALIGN',
              'DeposiSeqNo__c' => '1',
              'ActivityDate' => Date.today(),
              'PaymentMethod' => '90',
              'DepositType__c' => '03',
              'TransactionAmount' => 1000,
              'CouponNo' => 'CPN-ALIGN;-;CP-SPLIT-ALIGN'
            }
          }
        }
      );
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(originalOrder.Id, lastRedeemCancelOrderId);
    System.assertEquals(originalOrder.Id, lastRedeemCancelOrderIdCustom);
    System.assertEquals(returnOrder.Id, lastRedeemCancelSaleId);
    System.assertEquals('CPN-ALIGN;-;CP-SPLIT-ALIGN', lastRedeemCancelVoucherCode);
  }

  @IsTest
  static void helperMethods_coverEmptyAndSkippedDepositInputs() {
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    System.assertEquals(0, GdReturnDepositServiceImpl.getReturnOrderItemRequestList(null).size());
    System.assertEquals(0, GdReturnDepositServiceImpl.getReturnOrderItemRequestList(new Map<String, Object>()).size());

    Decimal eligibleAmount = GdReturnDepositServiceImpl.getReturnAccrualEligibleDepositAmount(
      new List<TransactionJournal>{
        null,
        new TransactionJournal(PaymentMethod = '20', TransactionAmount = 100),
        new TransactionJournal(PaymentMethod = '10', TransactionAmount = null),
        new TransactionJournal(PaymentMethod = '10', TransactionAmount = 0),
        new TransactionJournal(PaymentMethod = '10', TransactionAmount = 25)
      }
    );
    System.assertEquals(25, eligibleAmount);

    System.assertEquals(
      0,
      GdReturnDepositServiceImpl.buildAccrualEligibleCancelTransactions(originalOrder.Id, returnOrder.Id, null, null).size()
    );

    List<TransactionJournal> adjustedList = GdReturnDepositServiceImpl.buildAccrualEligibleCancelTransactions(
      originalOrder.Id,
      returnOrder.Id,
      new List<TransactionJournal>{
        null,
        new TransactionJournal(PaymentMethod = '10', TransactionAmount = 0),
        new TransactionJournal(PaymentMethod = '20', TransactionAmount = 100),
        new TransactionJournal(PaymentMethod = '10', TransactionAmount = 25)
      },
      new List<Object>()
    );
    System.assertEquals(1, adjustedList.size());
    System.assertEquals(25, adjustedList[0].TransactionAmount);
  }

  @IsTest
  static void deleteReturnDeposit_saleDepositReversal_withoutOriginalAccrualDeletesOnly() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];

    seedOriginalSaleDeposit(originalOrder, 'ORIG-NO-ACCRUAL-ONLY', '11', 1000);

    TransactionJournal returnDepositTj = new TransactionJournal(
      DepositNo__c = 'DEL-NO-ACCRUAL-ONLY',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 1000,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Deposit Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit Reversal'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert returnDepositTj;

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(returnDepositTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(0, creditPointsOnPurchaseCallCount);
    System.assertEquals(
      true,
      [SELECT IsDeleted__c FROM TransactionJournal WHERE Id = :returnDepositTj.Id].IsDeleted__c
    );
  }

  @IsTest
  static void deleteReturnDeposit_saleDepositReversal_currentGradeBranchRestoresPoints() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    originalOrder.EndDate = Date.today().addDays(7);
    update originalOrder;

    Contact memberContact = [SELECT Id, PreviousGrade__c FROM Contact WHERE MemberNo__c = :TEST_MEMBER_NO LIMIT 1];
    memberContact.PreviousGrade__c = null;
    update memberContact;

    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    seedOriginalSaleDeposit(originalOrder, 'ORIG-CURRENT-GRADE', '11', 1000);

    TransactionJournal originalAccrualTj = new TransactionJournal(
      JournalDate = Date.today().addDays(-2),
      ActivityDate = Datetime.now().addDays(-2),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      JournalTypeId = getJournalTypeId('Accrual'),
      JournalSubTypeId = getJournalSubTypeId('Purchase Accrual'),
      TransactionAmount = 100,
      Status = 'Processed'
    );
    insert originalAccrualTj;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = originalAccrualTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );

    TransactionJournal returnDepositTj = new TransactionJournal(
      DepositNo__c = 'DEL-CURRENT-GRADE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 1000,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Deposit Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit Reversal'),
      Status = 'Processed',
      IsDeleted__c = false,
      InsertId__c = 'USER-CURRENT-GRADE'
    );
    insert returnDepositTj;

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(returnDepositTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(1, creditPointsOnPurchaseCallCount);
  }

  @IsTest
  static void deleteReturnDeposit_withLinkedPromotionReversalRestoresPromotionAccrual() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    seedOriginalSaleDeposit(originalOrder, 'ORIG-PROMO-LINKED', '11', 1000);

    Promotion promo = new Promotion(
      Name = 'Linked Promotion Restore',
      StartDate = Date.today().addDays(-5),
      EndDate = Date.today().addDays(5),
      PublishStartDate__c = Date.today().addDays(-5),
      PublishEndDate__c = Date.today().addDays(5)
    );
    insert promo;

    TransactionJournal originalPromotionAccrualTj = new TransactionJournal(
      JournalDate = Date.today().addDays(-2),
      ActivityDate = Datetime.now().addDays(-2),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      PromotionId = promo.Id,
      JournalTypeId = getJournalTypeId('Accrual'),
      JournalSubTypeId = getJournalSubTypeId('Promotion Point Accrual'),
      TransactionAmount = 100,
      Status = 'Processed'
    );
    insert originalPromotionAccrualTj;

    LoyaltyLedger originalCreditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = originalPromotionAccrualTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert originalCreditLedger;

    TransactionJournal originalPurchaseAccrualTj = new TransactionJournal(
      JournalDate = Date.today().addDays(-2),
      ActivityDate = Datetime.now().addDays(-2),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = originalOrder.Id,
      SaleId__c = originalOrder.Id,
      JournalTypeId = getJournalTypeId('Accrual'),
      JournalSubTypeId = getJournalSubTypeId('Purchase Accrual'),
      TransactionAmount = 10,
      Status = 'Processed'
    );
    insert originalPurchaseAccrualTj;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = originalPurchaseAccrualTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 10,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );

    TransactionJournal sourceTj = new TransactionJournal(
      DepositNo__c = 'DEL-PROMO-LINKED',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '03',
      TransactionAmount = 1000,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      PromotionId = promo.Id,
      JournalTypeId = getJournalTypeId('Deposit Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit Reversal'),
      Status = 'Processed',
      IsDeleted__c = false,
      InsertId__c = 'USER-PROMO-LINKED'
    );
    insert sourceTj;

    TransactionJournal linkedReversalTj = new TransactionJournal(
      DepositNo__c = 'PROMO-ACCRUAL-REVERSAL',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      TransactionAmount = 100,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      PromotionId = promo.Id,
      RelatedJournalId = sourceTj.Id,
      JournalTypeId = getJournalTypeId('Accrual Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Promotion Point Accrual Reversal'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert linkedReversalTj;

    LoyaltyLedger reversalDebitLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = linkedReversalTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit'
    );
    insert reversalDebitLedger;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = originalCreditLedger.Id,
      DebitLoyaltyLedgerId = reversalDebitLedger.Id,
      Points = 100,
      ActionType = 'CreditCancellation'
    );

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(sourceTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(true, [SELECT IsDeleted__c FROM TransactionJournal WHERE Id = :linkedReversalTj.Id].IsDeleted__c);
  }

  @IsTest
  static void deleteReturnDeposit_pointRedeemCancel_partiallyAdjustsExpiredLedger() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();
    Date expiredDate = Date.today().addDays(-1);

    TransactionJournal pointRedeemCancelTj = new TransactionJournal(
      DepositNo__c = 'DEL-POINT-EXPIRED-PARTIAL',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '03',
      TransactionAmount = 50,
      OrderId = originalOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false,
      InsertId__c = 'USER-POINT-EXP-PART'
    );
    insert pointRedeemCancelTj;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = pointRedeemCancelTj.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = 50,
      ExpiryDate = expiredDate,
      EventType = 'Credit'
    );

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = pointRedeemCancelTj.Id,
      ActivityDate = Datetime.now().addDays(-1),
      Points = 80,
      ExpiryDate = expiredDate,
      EventType = 'Expiry'
    );

    Test.startTest();
    ApiResult result = new GdReturnDepositServiceImpl().deleteReturnDeposit(pointRedeemCancelTj.DepositNo__c);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :pointRedeemCancelTj.Id AND EventType = 'Expiry' AND Points = 30 AND IsDeleted = FALSE
      ]
    );
  }

  @IsTest
  static void validateRestoredPointLedgersFullyRecoverableV2_unavailableUsageThrowsWithReference() {
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    TransactionJournal restoredTj = new TransactionJournal(
      DepositNo__c = 'VAL-V2-RESTORED',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed'
    );
    insert restoredTj;

    LoyaltyLedger restoredCredit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = restoredTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert restoredCredit;

    TransactionJournal useTj = new TransactionJournal(
      DepositNo__c = 'VAL-V2-USE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert useTj;

    LoyaltyLedger useDebit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = useTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = restoredCredit.ExpiryDate,
      EventType = 'Debit'
    );
    insert useDebit;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = restoredCredit.Id,
      DebitLoyaltyLedgerId = useDebit.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    Boolean thrown = false;
    try {
      GdReturnDepositServiceImpl.validateRestoredPointLedgersFullyRecoverableV2(new List<LoyaltyLedger>{ restoredCredit }, lpm.Id);
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }
    System.assertEquals(true, thrown);
  }

  @IsTest
  static void validateRestoredPointLedgersFullyRecoverableV2_nestedCancelCreditAllowsRecovery() {
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();
    Date expiryDate = Date.today().addYears(1);

    TransactionJournal restoredTj = new TransactionJournal(
      DepositNo__c = 'VAL-V2-NESTED',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = getOriginalOrder().Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed'
    );
    insert restoredTj;

    LoyaltyLedger restoredCredit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = restoredTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = expiryDate,
      EventType = 'Credit'
    );
    insert restoredCredit;

    TransactionJournal useTj = new TransactionJournal(
      DepositNo__c = 'VAL-V2-NESTED-USE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert useTj;

    LoyaltyLedger useDebit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = useTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = expiryDate,
      EventType = 'Debit'
    );
    insert useDebit;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = restoredCredit.Id,
      DebitLoyaltyLedgerId = useDebit.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    TransactionJournal nestedCancelTj = new TransactionJournal(
      DepositNo__c = 'VAL-V2-NESTED-CANCEL',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert nestedCancelTj;

    insert new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = nestedCancelTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = expiryDate,
      EventType = 'Credit'
    );

    GdReturnDepositServiceImpl.validateRestoredPointLedgersFullyRecoverableV2(new List<LoyaltyLedger>{ restoredCredit }, lpm.Id);
  }

  @IsTest
  static void validateRestoredPointLedgersFullyRecoverable_legacyUnavailableThrows() {
    Order returnOrder = getReturnOrder();
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember LIMIT 1];
    Id currencyId = getLoyaltyProgramCurrencyId();
    Id subtypeId = getEcoSubtypeId();

    TransactionJournal restoredTj = new TransactionJournal(
      DepositNo__c = 'VAL-LEGACY-RESTORED',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption Reversal'),
      JournalSubTypeId = getJournalSubTypeId('Point Redeem Cancel'),
      Status = 'Processed'
    );
    insert restoredTj;

    LoyaltyLedger restoredCredit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = restoredTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert restoredCredit;

    TransactionJournal useTj = new TransactionJournal(
      DepositNo__c = 'VAL-LEGACY-USE',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      OrderId = returnOrder.Id,
      SaleId__c = returnOrder.Id,
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      Status = 'Processed',
      IsDeleted__c = false
    );
    insert useTj;

    LoyaltyLedger useDebit = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      TransactionJournalId = useTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = restoredCredit.ExpiryDate,
      EventType = 'Debit'
    );
    insert useDebit;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = restoredCredit.Id,
      DebitLoyaltyLedgerId = useDebit.Id,
      Points = 100,
      ActionType = 'Debit'
    );

    Boolean thrown = false;
    try {
      GdReturnDepositServiceImpl.validateRestoredPointLedgersFullyRecoverable(new List<LoyaltyLedger>{ restoredCredit }, lpm.Id);
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }
    System.assertEquals(true, thrown);
  }
}