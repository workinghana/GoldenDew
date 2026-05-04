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
  private static List<TransactionJournal> capturedCancelPointsCreditedData;

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

    public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
      creditPromotionPointsOnPurchaseCallCount = (creditPromotionPointsOnPurchaseCallCount == null)
        ? 1
        : creditPromotionPointsOnPurchaseCallCount + 1;
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
    Order originalOrder = getOriginalOrder();

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

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
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
    Boolean thrown = false;

    try {
      svc.insertSaleDepositHistoryByUpdate(
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
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
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
}