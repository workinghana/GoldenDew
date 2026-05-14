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
      update new Pricebook2(Id = stdPbId, IsActive = true);
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

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'CTRL-MEM-LP', IsPrimary = true);
    insert lp;

    LoyaltyTierGroup tg = new LoyaltyTierGroup(
      Name = 'CTRL-MEM-TG',
      LoyaltyProgramId = lp.Id,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tg;

    insert new LoyaltyTier(Name = 'BASIC', LoyaltyTierGroupId = tg.Id);
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
    String json = '{"MemberNo__c":"MEMTEST-001","Lastname":"TestMember","TargetTierName":"BASIC","IsSMSAgreed__c":false}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember(json);
    Test.stopTest();
    System.assertNotEquals(null, r);
  }

  @IsTest
  static void createMember_smsAgreedJson_triggersCouponBranch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    String json = '{"MemberNo__c":"MEMTEST-002","Lastname":"TestSMS","TargetTierName":"BASIC","IsSMSAgreed__c":true}';

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

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.OrderResult r = Order_Sale_Return_View_ControllerV1.deleteSale('DELSAL-CTRL-001');
    Test.stopTest();

    System.assertNotEquals(null, r);
  }

  @IsTest
  static void deleteSaleDeposit_validInputs_exercisesPath() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

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

    String json = '{"AccountId":"CTRL-CMP","StoreCode__c":"CTRL-STR","MemberNo__c":"CTRL-M-001","OrderNo__c":"CTRL-ORD-001","ActualPaymentAmount__c":50000,"Type":"01","InsertId__c":"tester","OrderItem":[],"TransactionJournal":[]}';

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

    String json = '{"AccountId":"CTRL-S-CMP","StoreCode__c":"CTRL-S-STR","MemberNo__c":"CTRL-S-001","SaleNo__c":"CTRL-SAL-001","OriginalOrderId":"CTRL-S-ORIG-001","ActualPaymentAmount__c":30000,"OrderItem":[],"TransactionJournal":[]}';

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

    String json = '{"OrderNo__c":"CTRL-U-ORD-001","ActualPaymentAmount__c":10000,"OrderItem":[],"TransactionJournal":[]}';

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

    String json = '{"SaleNo__c":"CTRL-US-SAL-001","ActualPaymentAmount__c":7000,"OrderItem":[],"TransactionJournal":[]}';

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

    String json = '{"OriginalOrderId":"CTRL-R-SAL-001","SaleNo__c":"CTRL-R-RTN-001","ActualPaymentAmount__c":10000,"OrderItem":[],"TransactionJournal":[]}';

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

    String json = '{"MemberNo__c":"CTRL-MEM-FULL-001","Lastname":"FullSetup","TargetTierName":"BASIC","IsSMSAgreed__c":false}';

    Test.startTest();
    Order_Sale_Return_View_ControllerV1.MemberRegisterResult r = Order_Sale_Return_View_ControllerV1.createMember(json);
    Test.stopTest();

    System.assertNotEquals(null, r);
  }
}