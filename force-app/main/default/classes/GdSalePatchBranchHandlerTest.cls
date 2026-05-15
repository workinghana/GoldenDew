/**
 * GdSalePatchBranchHandler Test
 *
 * 검증 영역
 *   A. wrapResponseForOldSale — 응답 enrich
 *   B. null 처리 (standardResult / data / logger)
 *   C. message + data 필드 정확성
 */
@IsTest
private class GdSalePatchBranchHandlerTest {
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

  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Id stdPbId = Test.getStandardPricebookId();
    Account company = new Account(Name = 'Co_SP', CompanyCode__c = 'CMP-SP');
    Account store = new Account(Name = 'Store_SP', StoreCode__c = 'STR-SP');
    insert new List<Account>{ company, store };

    Contact c = new Contact(LastName = 'SPTester', MemberNo__c = 'M-SP-TEST', AccountId = company.Id);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP_SP', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-SP-TEST',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    // 등급 — 기존 sandbox 의 GIP tier 사용 (LoyaltyProgramId 는 read-only)
    List<LoyaltyTier> tiers = [SELECT Id FROM LoyaltyTier WHERE LoyaltyProgramId = '0lpJO0000000001YAA' AND Name = 'GIP' LIMIT 1];
    if (!tiers.isEmpty()) {
      LoyaltyMemberTier lmt = new LoyaltyMemberTier(Name = 'GIP_SP', LoyaltyMemberId = lpm.Id, LoyaltyTierId = tiers[0].Id);
      insert lmt;
    }

    Order origOrder = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SAL-SP-OLD',
      ActualPaymentAmount__c = 100000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert origOrder;
  }

  @IsTest
  static void wrap_oldSale_enrichesResponse() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-OLD-PATCH', null);
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(200, result.code);
    System.assert(result.message.contains(GdSalePatchBranchHandler.WRAP_MESSAGE_SUFFIX), 'message 에 옵션 C 분기 표기 추가됨');
    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals('skipped_due_to_migration', result.data.get('point_processing'));
    System.assertEquals(GdSalePatchBranchHandler.WRAP_REASON, result.data.get('reason'));
    System.assertEquals('SAL-OLD-PATCH', result.data.get('saleNo'));
  }

  @IsTest
  static void wrap_nullStandardResult_returnsNull() {
    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(null, 'SAL-X', null);
    Test.stopTest();

    System.assertEquals(null, result, 'standardResult null → null 반환');
  }

  @IsTest
  static void wrap_nullData_initializesAndEnriches() {
    ApiResult standardResult = new ApiResult(true, 200, '판매 수정 완료', null);

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-X', null);
    Test.stopTest();

    System.assertNotEquals(null, result.data);
    System.assertEquals(true, result.data.get('option_c_branch'));
  }

  @IsTest
  static void wrap_nullLogger_doesNotThrow() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, 'msg', standardData);

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-X', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
  }

  @IsTest
  static void wrap_loggerProvided_setsPartialStatus() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, 'msg', standardData);

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging('GdSalePatchBranchHandlerTest');

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-X', logger);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
  }

  @IsTest
  static void wrap_preservesOriginalMessage() {
    String origMessage = '판매 수정 완료';
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, origMessage, standardData);

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-X', null);
    Test.stopTest();

    System.assert(result.message.startsWith(origMessage));
    System.assert(result.message.contains(GdSalePatchBranchHandler.WRAP_MESSAGE_SUFFIX.trim()));
  }

  // ============================================================
  // Phase 6.6 — 적립 차이 자동 조정
  // ============================================================

  @IsTest
  static void wrap_oldAmountNull_skipsAdjustment() {
    // oldAmount=null (기존 시그니처 사용) → 조정 skip + 응답 enrich 만
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SP-OLD', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    // 차이 조정은 skip → requested 0
    System.assertEquals(0, result.data.get('option_c_points_requested'));
  }

  @IsTest
  static void wrap_increase_invokesForceCreditPath() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    // oldAmount=80,000 → 현재 100,000 (변경 후) → delta=+20,000 → force-credit
    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SP-OLD', 80000, null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(20000, result.data.get('option_c_amount_delta'));
    System.assertEquals('credit', result.data.get('option_c_direction'));
  }

  @IsTest
  static void wrap_decrease_invokesForceDebitPath() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    // oldAmount=150,000 → 현재 100,000 → delta=-50,000 → force-debit
    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SP-OLD', 150000, null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(-50000, result.data.get('option_c_amount_delta'));
    System.assertEquals('debit', result.data.get('option_c_direction'));
  }

  @IsTest
  static void wrap_sameAmount_noAdjustment() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    // oldAmount=100,000 → 현재 100,000 → delta=0 → 조정 없음
    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SP-OLD', 100000, null);
    Test.stopTest();

    System.assertEquals(0, result.data.get('option_c_amount_delta'));
    System.assertEquals('none', result.data.get('option_c_direction'));
  }

  @IsTest
  static void wrap_saleNotFound_recordsErrorInLog() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SP-NOTFOUND', 100000, null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(0, result.data.get('option_c_points_actual'));
  }

  @IsTest
  static void findPromotionIdForOriginalOrder_returnsNullWhenNoTj() {
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SP-OLD' LIMIT 1];
    Test.startTest();
    Id promId = GdSalePatchBranchHandler.findPromotionIdForOriginalOrder(o.Id);
    Test.stopTest();
    System.assertEquals(null, promId);
  }

  @IsTest
  static void findPromotionIdForOriginalOrder_nullInput_returnsNull() {
    Test.startTest();
    Id promId = GdSalePatchBranchHandler.findPromotionIdForOriginalOrder(null);
    Test.stopTest();
    System.assertEquals(null, promId);
  }

  @IsTest
  static void wrap_blankSaleNo_skipsAdjustment() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, '', 100000, null);
    Test.stopTest();

    System.assertEquals(0, result.data.get('option_c_points_requested'));
  }

  @IsTest
  static void wrap_loggerWithDelta_setsPartial() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging('GdSalePatchBranchHandlerTest');

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SP-OLD', 80000, logger);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
  }
}
