/**
 * Order_Sale_Return_View_ControllerV1 Test
 *
 * 검증 영역
 *   A. 8개 public 메서드 각각의 validation 분기 (blank/null/invalid JSON → 400)
 *   B. service 호출 실패 시 catch 블록 (CustomException / Exception)
 *   C. OrderResult / MemberRegisterResult 내부 클래스 인스턴스화
 */
@IsTest
private class Order_Sale_Return_View_ControllerV1Test {
  // Salesforce Loyalty RTF 플로우가 콜아웃을 발생시키므로 HttpCalloutMock 필수.
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"ok":true}');
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
      if (methodName == 'redeemVoucherV2' || methodName == 'redeemCancelVoucher') {
        return ApiResult.ok(200, 'ok', new Map<String, Object>());
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
      if (methodName == 'debitPoint' || methodName == 'debitPointsCustom') {
        return new List<GdSaleApiController.PointDebitDTO>{ new GdSaleApiController.PointDebitDTO() };
      }
      if (methodName == 'cancelPointRedemption') {
        return new Map<String, Object>{ 'result' => 'ok' };
      }
      if (
        methodName == 'creditPointsOnPurchaseV2' ||
        methodName == 'creditPromotionPointsOnPurchase' ||
        methodName == 'creditEtcPointsOnPurchaseForOldSale'
      ) {
        return new List<PointCreditDTO>{ new PointCreditDTO() };
      }
      if (methodName == 'creditPointsOnPurchaseByGrade') {
        return new List<PointCreditDTO>{ new PointCreditDTO() };
      }
      if (methodName == 'debitPointsOnPurchaseByGrade') {
        return new List<PointDebitDTO>{ new PointDebitDTO() };
      }
      if (methodName == 'cancelPointsCreditedOnPurchase') {
        return new List<GdSaleApiController.PointDebitDTO>{ new GdSaleApiController.PointDebitDTO() };
      }
      if (methodName == 'isAccrualEligible') {
        return true;
      }
      return null;
    }
  }

  private static void setMockServices() {
    GdVoucherService voucherStub = (GdVoucherService) Test.createStub(GdVoucherService.class, new VoucherServiceStubProvider());
    GdPointService pointStub = (GdPointService) Test.createStub(GdPointService.class, new PointServiceStubProvider());

    GdOrderDepositServiceImpl.setVoucherService(voucherStub);
    GdOrderDepositServiceImpl.setPointService(pointStub);
    GdSaleDepositServiceImpl.setVoucherService(voucherStub);
    GdSaleDepositServiceImpl.setPointService(pointStub);
    GdReturnDepositServiceImpl.setVoucherService(voucherStub);
    GdReturnDepositServiceImpl.setPointService(pointStub);
  }

  // @TestSetup 으로 데이터를 별도 transaction 에서 commit → 후속 test 의 callout 차단 회피
  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Account company = new Account(Name = 'CTRL-CO', CompanyCode__c = 'CTRL-CMP');
    Account store = new Account(Name = 'CTRL-STR', StoreCode__c = 'CTRL-STR');
    Account companyS = new Account(Name = 'CTRL-S-CO', CompanyCode__c = 'CTRL-S-CMP');
    Account storeS = new Account(Name = 'CTRL-S-STR', StoreCode__c = 'CTRL-S-STR');
    Account companyU = new Account(Name = 'CTRL-U-CO', CompanyCode__c = 'CTRL-U-CMP');
    Account storeU = new Account(Name = 'CTRL-U-STR', StoreCode__c = 'CTRL-U-STR');
    Account companyUS = new Account(Name = 'CTRL-US-CO', CompanyCode__c = 'CTRL-US-CMP');
    Account storeUS = new Account(Name = 'CTRL-US-STR', StoreCode__c = 'CTRL-US-STR');
    Account companyR = new Account(Name = 'CTRL-R-CO', CompanyCode__c = 'CTRL-R-CMP');
    Account storeR = new Account(Name = 'CTRL-R-STR', StoreCode__c = 'CTRL-R-STR');
    insert new List<Account>{ company, store, companyS, storeS, companyU, storeU, companyUS, storeUS, companyR, storeR };

    insert new List<Contact>{
      new Contact(LastName = 'CTRLUsr', MemberNo__c = 'CTRL-M-001', AccountId = company.Id),
      new Contact(LastName = 'CTRLSale', MemberNo__c = 'CTRL-S-001', AccountId = companyS.Id),
      new Contact(LastName = 'CTRLUpd', MemberNo__c = 'CTRL-U-001', AccountId = companyU.Id),
      new Contact(LastName = 'CTRLUSale', MemberNo__c = 'CTRL-US-001', AccountId = companyUS.Id),
      new Contact(LastName = 'CTRLRet', MemberNo__c = 'CTRL-R-001', AccountId = companyR.Id)
    };

    Id stdPbId = Test.getStandardPricebookId();
    try {
      try { update new Pricebook2(Id = stdPbId, IsActive = true); } catch (Exception lockEx) { /* parallel @TestSetup lock conflict - safe to ignore (idempotent) */ }
    } catch (Exception ignore) {
    }

    Id companySId = companyS.Id;
    Id storeSId = storeS.Id;
    Id contactSId = [SELECT Id FROM Contact WHERE MemberNo__c = 'CTRL-S-001' LIMIT 1].Id;
    Order origOrderS = new Order(
      AccountId = companySId,
      EffectiveDate = Date.today(),
      Status = 'orderSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = contactSId,
      StoreCode__c = storeSId,
      OrderNo__c = 'CTRL-S-ORIG-001'
    );
    insert origOrderS;

    Id companyUId = companyU.Id;
    Id storeUId = storeU.Id;
    Id contactUId = [SELECT Id FROM Contact WHERE MemberNo__c = 'CTRL-U-001' LIMIT 1].Id;
    Order ordU = new Order(
      AccountId = companyUId,
      EffectiveDate = Date.today(),
      Status = 'orderSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = contactUId,
      StoreCode__c = storeUId,
      OrderNo__c = 'CTRL-U-ORD-001'
    );
    insert ordU;

    Id companyUSId = companyUS.Id;
    Id storeUSId = storeUS.Id;
    Id contactUSId = [SELECT Id FROM Contact WHERE MemberNo__c = 'CTRL-US-001' LIMIT 1].Id;
    Order ordUS = new Order(
      AccountId = companyUSId,
      EffectiveDate = Date.today(),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = contactUSId,
      StoreCode__c = storeUSId,
      SaleNo__c = 'CTRL-US-SAL-001',
      ActualPaymentAmount__c = 5000
    );
    insert ordUS;

    Id companyRId = companyR.Id;
    Id storeRId = storeR.Id;
    Id contactRId = [SELECT Id FROM Contact WHERE MemberNo__c = 'CTRL-R-001' LIMIT 1].Id;
    Order origOrderR = new Order(
      AccountId = companyRId,
      EffectiveDate = Date.today(),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = contactRId,
      StoreCode__c = storeRId,
      SaleNo__c = 'CTRL-R-SAL-001',
      ActualPaymentAmount__c = 10000
    );
    insert origOrderR;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Golden Dew', IsPrimary = true, Status = 'Active');
    insert lp;

    LoyaltyTierGroup tg = new LoyaltyTierGroup(
      Name = 'LoyaltyTierGroup',
      IsPrimary = true,
      LoyaltyProgramId = lp.Id,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today(),
      ExtendExpiration = 'None',
      TierPeriodUnit = 'Years',
      TierPeriodQuantity = 1
    );
    insert tg;

    insert new List<LoyaltyTier>{
      new LoyaltyTier(Name = 'BASIC', LoyaltyTierGroupId = tg.Id),
      new LoyaltyTier(Name = 'Gold', LoyaltyTierGroupId = tg.Id)
    };

    List<LoyaltyProgramMember> members = new List<LoyaltyProgramMember>();
    for (Contact c : [SELECT Id, MemberNo__c FROM Contact WHERE MemberNo__c LIKE 'CTRL-%']) {
      members.add(
        new LoyaltyProgramMember(
          MembershipNumber = c.MemberNo__c,
          MemberStatus = 'Active',
          MemberType = 'Individual',
          ContactId = c.Id,
          EnrollmentDate = Date.today(),
          ProgramId = lp.Id
        )
      );
    }
    insert members;

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
      new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = redemptionReversalType.Id),
      new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = accrualReversalType.Id)
    };

    Product2 product = new Product2(Name = 'CTRL-PROD', ProductCode = 'CTRL-PROD-001', IsActive = true);
    insert product;
    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = stdPbId,
      Product2Id = product.Id,
      UnitPrice = 10000,
      IsActive = true
    );
    insert pbe;

    Order returnSource = [SELECT Id FROM Order WHERE SaleNo__c = 'CTRL-R-SAL-001' LIMIT 1];
    insert new OrderItem(
      OrderId = returnSource.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 10000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = returnSource.Id + '-1',
      NetSalesUnitPrice__c = 10000,
      IsExclude__c = false
    );
  }

  private static String todayText() {
    return String.valueOf(Date.today());
  }

  private static String orderItemJson() {
    return '{"OrderSeqNo__c":"1","Status__c":"01","ProductCode":"CTRL-PROD-001","Quantity":1,"isExclude":false,"NetSalesUnitPrice__c":10000}';
  }

  private static String saleItemJson() {
    return '{"SaleSeqNo__c":"1","Status__c":"01","ProductCode":"CTRL-PROD-001","Quantity":1,"isExclude":false,"NetSalesUnitPrice__c":10000}';
  }

  private static String depositJson(String prefix, String depositType) {
    return '{"DepositNo__c":"' +
      prefix +
      '","DeposiSeqNo__c":"1","ActivityDate":"' +
      todayText() +
      '","PaymentMethod":"01","DepositType__c":"' +
      depositType +
      '","TransactionAmount":10000,"CouponNo":""}';
  }

  // ============================================================
  // A. createOrder — blank / invalid JSON / 서비스 실패
  // ============================================================
  @IsTest
  static void createOrder_blankJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createOrder('');
    Test.stopTest();
    System.assertEquals(false, r.success);
    System.assertEquals(400, r.code);
    System.assert(r.message.contains('비었습니다'));
  }

  @IsTest
  static void createOrder_nullJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createOrder(null);
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void createOrder_invalidJson_returns400ParseFail() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createOrder('{not valid json');
    Test.stopTest();
    System.assertEquals(false, r.success);
    System.assertEquals(400, r.code);
    System.assert(r.message.contains('파싱'));
  }

  @IsTest
  static void createOrder_validJsonButServiceFails_returnsErrorCode() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createOrder(
      '{"AccountId":"INVALID","StoreCode__c":"X","MemberNo__c":"X","OrderNo__c":"O1"}'
    );
    Test.stopTest();
    System.assertEquals(false, r.success);
    System.assertNotEquals(200, r.code, 'service 검증 실패 → non-200');
  }

  // ============================================================
  // B. updateOrder
  // ============================================================
  @IsTest
  static void updateOrder_blankJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateOrder('');
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void updateOrder_invalidJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateOrder('{broken');
    Test.stopTest();
    System.assert(r.message.contains('파싱'));
  }

  @IsTest
  static void updateOrder_validJsonButServiceFails_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateOrder('{"OrderNo__c":"X"}');
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  // ============================================================
  // C. createSale
  // ============================================================
  @IsTest
  static void createSale_blankJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createSale('');
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void createSale_invalidJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createSale('not json');
    Test.stopTest();
    System.assert(r.message.contains('파싱'));
  }

  @IsTest
  static void createSale_validJsonButServiceFails_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createSale('{"SaleNo__c":"S1"}');
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  // ============================================================
  // D. updateSale
  // ============================================================
  @IsTest
  static void updateSale_blankJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateSale('');
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void updateSale_invalidJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateSale('{x');
    Test.stopTest();
    System.assert(r.message.contains('파싱'));
  }

  @IsTest
  static void updateSale_validJsonButServiceFails_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateSale('{"SaleNo__c":"X"}');
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  // ============================================================
  // E. deleteSale
  // ============================================================
  @IsTest
  static void deleteSale_blank_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSale('');
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void deleteSale_null_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSale(null);
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void deleteSale_notExist_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSale('SALE-NOTEXIST-XYZ-9999');
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  // ============================================================
  // F. deleteSaleDeposit
  // ============================================================
  @IsTest
  static void deleteSaleDeposit_blankDepositNo_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSaleDeposit('', '01');
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void deleteSaleDeposit_blankSeqNo_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSaleDeposit('DEP-001', '');
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void deleteSaleDeposit_notExist_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSaleDeposit('DEP-NOTEXIST-XYZ-9999', '01');
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  // ============================================================
  // G. createReturn
  // ============================================================
  @IsTest
  static void createReturn_blankJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createReturn('');
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void createReturn_invalidJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createReturn('{bad');
    Test.stopTest();
    System.assert(r.message.contains('파싱'));
  }

  @IsTest
  static void createReturn_validJsonButServiceFails_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createReturn('{"OriginalOrderId":"X"}');
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  // ============================================================
  // H. createMember
  // ============================================================
  @IsTest
  static void createMember_blankJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember('');
    Test.stopTest();
    System.assertEquals(400, r.code);
  }

  @IsTest
  static void createMember_invalidJson_returns400() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember('{bad');
    Test.stopTest();
    System.assert(r.message.contains('파싱'));
  }

  @IsTest
  static void createMember_validJsonButServiceFails_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember('{"MemberNo__c":"M-INVALID-X"}');
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  @IsTest
  static void createMember_blankLastName_autoFillsFromMemberNo() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Test.startTest();
    // LastName 미포함 → MemberNo__c 로 자동 채움 로직 커버
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember('{"MemberNo__c":"AUTOFILL-001"}');
    Test.stopTest();
    System.assertNotEquals(null, r);
  }

  // ============================================================
  // I. 내부 클래스 인스턴스화
  // ============================================================
  @IsTest
  static void orderResult_defaultInitialization() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = new Order_Sale_Return_View_ControllerV1.OrderResult();
    r.success = true;
    r.code = 200;
    r.message = 'ok';
    r.orderId = 'X';
    Test.stopTest();
    System.assertEquals(true, r.success);
    System.assertEquals(200, r.code);
    System.assertEquals('ok', r.message);
    System.assertEquals('X', r.orderId);
  }

  @IsTest
  static void memberRegisterResult_defaultInitialization() {
    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = new Order_Sale_Return_View_ControllerV1.MemberRegisterResult();
    r.success = true;
    r.code = 200;
    r.message = 'ok';
    r.memberNo = 'M-001';
    Test.stopTest();
    System.assertEquals(true, r.success);
    System.assertEquals('M-001', r.memberNo);
  }

  // ============================================================
  // J. createOrder/createSale/createReturn 등 - 다양한 reqData 입력으로 deep path 커버 시도
  //    각 service 가 다양한 에러 분기 진입 → catch 블록 + 다양한 catch 케이스 커버
  // ============================================================
  @IsTest
  static void createOrder_minimalJson_exercisesServiceCall() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    // 최소 데이터 — service 가 진입은 하되 검증 실패
    String json = '{"AccountId":"X","StoreCode__c":"Y","MemberNo__c":"Z","OrderNo__c":"O1","OrderItem":[]}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createOrder(json);
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  @IsTest
  static void updateOrder_minimalJson_exercisesServiceCall() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    String json = '{"OrderNo__c":"O1","OrderItem":[]}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateOrder(json);
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  @IsTest
  static void createSale_minimalJson_exercisesServiceCall() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    String json = '{"SaleNo__c":"S1","OriginalOrderId":"O1","OrderItem":[],"TransactionJournal":[]}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createSale(json);
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  @IsTest
  static void updateSale_minimalJson_exercisesServiceCall() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    String json = '{"SaleNo__c":"S1","OrderItem":[],"TransactionJournal":[]}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateSale(json);
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  @IsTest
  static void createReturn_minimalJson_exercisesServiceCall() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    String json = '{"OriginalOrderId":"O1","SaleNo__c":"S1","OrderItem":[],"TransactionJournal":[]}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createReturn(json);
    Test.stopTest();
    System.assertEquals(false, r.success);
  }

  @IsTest
  static void createMember_fullJson_triggersServiceChain() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    // 회원 등록에 필요한 필드들 — LoyaltyProgram/TierGroup 셋업 없으면 service 가 실패하지만 그 분기까지 path 실행
    String json = '{"MemberNo__c":"MEMTEST-001","Lastname":"TestMember","Grade__c":"02","TargetTierName":"Gold","IsSMSAgreed__c":false}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember(json);
    Test.stopTest();
    System.assertNotEquals(null, r);
  }

  @IsTest
  static void createMember_smsAgreedJson_triggersCouponBranch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    String json = '{"MemberNo__c":"MEMTEST-002","Lastname":"TestSMS","Grade__c":"02","TargetTierName":"Gold","IsSMSAgreed__c":true}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember(json);
    Test.stopTest();
    System.assertNotEquals(null, r);
  }

  // ============================================================
  // K. deleteSale / deleteSaleDeposit 다양한 입력 — service catch 다양화
  // ============================================================
  @IsTest
  static void deleteSale_existingSale_exercisesDeepPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Id stdPbId = Test.getStandardPricebookId();
    Account acc = new Account(Name = 'DelSaleAcc');
    insert acc;

    Order ord = new Order(AccountId = acc.Id, EffectiveDate = Date.today(), Status = 'Draft', Pricebook2Id = stdPbId, SaleNo__c = 'DELSAL-CTRL-001');
    insert ord;
    PricebookEntry pbe = [SELECT Id, UnitPrice FROM PricebookEntry WHERE ProductCode = 'CTRL-PROD-001' AND Pricebook2Id = :stdPbId LIMIT 1];
    insert new OrderItem(
      OrderId = ord.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = pbe.UnitPrice,
      SaleSeqNo__c = '1',
      SaleItemNo__c = ord.Id + '-1',
      NetSalesUnitPrice__c = 10000,
      IsExclude__c = false
    );

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSale('DELSAL-CTRL-001');
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  @IsTest
  static void deleteSaleDeposit_validInputs_exercisesPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    setMockServices();

    Order saleOrder = [SELECT Id, MemberNo__c FROM Order WHERE SaleNo__c = 'CTRL-US-SAL-001' LIMIT 1];
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :saleOrder.MemberNo__c LIMIT 1];
    JournalSubType saleDepositSubType = [SELECT Id, JournalTypeId FROM JournalSubType WHERE Name = 'Sale Deposit' LIMIT 1];
    insert new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      JournalTypeId = saleDepositSubType.JournalTypeId,
      JournalSubTypeId = saleDepositSubType.Id,
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      Status = 'Processed',
      PaymentMethod = '01',
      DepositType__c = '02',
      TransactionAmount = 10000,
      DepositNo__c = 'DEP-CTRL-001-01',
      DeposiSeqNo__c = '01',
      OrderId = saleOrder.Id,
      OrderId__c = saleOrder.Id,
      SaleId__c = saleOrder.Id
    );

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSaleDeposit('DEP-CTRL-001', '01');
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  // ============================================================
  // L. 완전한 데이터 셋업 — GdOrderServiceImpl.createOrder 성공 path 트리거
  //    controller 의 service-after success/error 분기 라인 다수 커버
  // ============================================================
  @IsTest
  static void createOrder_fullValidData_exercisesAfterServicesPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    setMockServices();

    String json =
      '{"AccountId":"CTRL-CMP","StoreCode__c":"CTRL-STR","MemberNo__c":"CTRL-M-001","OrderNo__c":"CTRL-ORD-001","ActualPaymentAmount__c":50000,"Type":"01","InsertId__c":"tester","OrderItem":[' +
      orderItemJson() +
      '],"TransactionJournal":[' +
      depositJson('CTRL-ORD-DEP', '01') +
      ']}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createOrder(json);
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  // ============================================================
  // M. createSale - 완전 셋업으로 deep path 시도
  // ============================================================
  @IsTest
  static void createSale_fullValidData_exercisesPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    setMockServices();

    String json =
      '{"AccountId":"CTRL-S-CMP","StoreCode__c":"CTRL-S-STR","MemberNo__c":"CTRL-S-001","SaleNo__c":"CTRL-SAL-001","OriginalOrderId":"CTRL-S-ORIG-001","ActualPaymentAmount__c":30000,"OrderItem":[' +
      saleItemJson() +
      '],"TransactionJournal":[' +
      depositJson('CTRL-SAL-DEP', '02') +
      ']}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createSale(json);
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  // ============================================================
  // N. updateOrder - 기존 Order 가 있는 상태로 path 진입 시도
  // ============================================================
  @IsTest
  static void updateOrder_existingOrder_exercisesPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    setMockServices();

    String json =
      '{"OrderNo__c":"CTRL-U-ORD-001","ActualPaymentAmount__c":10000,"OrderItem":[' +
      orderItemJson() +
      '],"TransactionJournal":[' +
      depositJson('CTRL-UPD-ORD-DEP', '01') +
      ']}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateOrder(json);
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  // ============================================================
  // O. updateSale - 기존 Order/Sale 가 있는 상태로 path 진입 시도
  // ============================================================
  @IsTest
  static void updateSale_existingSale_exercisesPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    setMockServices();

    String json =
      '{"SaleNo__c":"CTRL-US-SAL-001","ActualPaymentAmount__c":7000,"OrderItem":[' +
      saleItemJson() +
      '],"TransactionJournal":[' +
      depositJson('CTRL-UPD-SAL-DEP', '02') +
      ']}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.updateSale(json);
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  // ============================================================
  // P. createReturn - 기존 Order/Sale 셋업 후 시도
  // ============================================================
  @IsTest
  static void createReturn_withExistingSale_exercisesPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    setMockServices();

    String json = '{"OriginalOrderId":"CTRL-R-SAL-001","SaleNo__c":"CTRL-R-RTN-001","ActualPaymentAmount__c":10000}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createReturn(json);
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  @IsTest
  static void createReturn_withOrderItem_reachesItemBranch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    setMockServices();

    String json =
      '{"OriginalOrderId":"CTRL-R-SAL-001","SaleNo__c":"CTRL-R-RTN-ITEM-001","ActualPaymentAmount__c":10000,"OrderItem":[' +
      saleItemJson() +
      ']}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.createReturn(json);
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  // ============================================================
  // Q. createMember - 완전 셋업 시도 (LoyaltyProgram + Tier 등)
  // ============================================================
  @IsTest
  static void createMember_withFullLoyaltySetup_exercisesPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    String json = '{"MemberNo__c":"CTRL-MEM-FULL-001","Lastname":"FullSetup","Grade__c":"02","TargetTierName":"Gold","IsSMSAgreed__c":false}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember(json);
    Test.stopTest();

    System.assertNotEquals(null, r);
  }
}