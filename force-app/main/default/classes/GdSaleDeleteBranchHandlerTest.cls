/**
 * GdSaleDeleteBranchHandler Test
 *
 * 검증 영역
 *   A. wrapResponseForOldSale — silent fail 응답 enrich
 *   B. null 처리 (standardResult / data / logger)
 *   C. message + data 필드 정확성
 */
@IsTest
private class GdSaleDeleteBranchHandlerTest {

  // ============================================================
  // @TestSetup — 옛 판매 + 회원 + 등급 시드
  // ============================================================
  @TestSetup
  static void setupData() {
    Id stdPbId = Test.getStandardPricebookId();

    Account company = new Account(Name = 'Co_SD', CompanyCode__c = 'CMP-SD');
    Account store = new Account(Name = 'Store_SD', StoreCode__c = 'STR-SD');
    insert new List<Account>{ company, store };

    Contact c = new Contact(LastName = 'SDTester', MemberNo__c = 'M-SD-TEST', AccountId = company.Id);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP_SD', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id, ContactId = c.Id, MemberStatus = 'Active',
      MembershipNumber = 'M-SD-TEST', EnrollmentDate = Date.today()
    );
    insert lpm;

    // 옛 판매 (100,000원, EffectiveDate 2026-03-01)
    Order origOrder = new Order(
      AccountId = company.Id, EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess', Pricebook2Id = stdPbId,
      MemberNo__c = c.Id, StoreCode__c = store.Id,
      SaleNo__c = 'SAL-SD-OLD', ActualPaymentAmount__c = 100000,
      Type = 'Standard', SaleStatus__c = '01', InsertId__c = 'tester'
    );
    insert origOrder;

    // 옛 판매 — ActualPaymentAmount NULL (검증 실패 케이스)
    Order origNullAmt = new Order(
      AccountId = company.Id, EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess', Pricebook2Id = stdPbId,
      MemberNo__c = c.Id, StoreCode__c = store.Id,
      SaleNo__c = 'SAL-SD-NULL', Type = 'Standard',
      SaleStatus__c = '01', InsertId__c = 'tester'
    );
    insert origNullAmt;

    // 기존 부분 환불 — 전액 환불된 판매 (잔여 0 케이스)
    Order saleAlreadyRefunded = new Order(
      AccountId = company.Id, EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess', Pricebook2Id = stdPbId,
      MemberNo__c = c.Id, StoreCode__c = store.Id,
      SaleNo__c = 'SAL-SD-ALL-REF', ActualPaymentAmount__c = 50000,
      Type = 'Standard', SaleStatus__c = '01', InsertId__c = 'tester'
    );
    insert saleAlreadyRefunded;

    Order fullReturn = new Order(
      AccountId = company.Id, EffectiveDate = Date.newInstance(2026, 4, 1),
      Status = 'returnSuccess', Pricebook2Id = stdPbId,
      MemberNo__c = c.Id, StoreCode__c = store.Id,
      SaleNo__c = 'RTN-SD-FULL', ActualPaymentAmount__c = 50000,
      Type = 'Standard', SaleStatus__c = '03',
      IsReductionOrder__c = true, OriginalOrderId__c = saleAlreadyRefunded.Id,
      InsertId__c = 'tester'
    );
    insert fullReturn;
  }

  // ============================================================
  // A. 정상 enrich
  // ============================================================
  @IsTest
  static void wrap_oldSale_enrichesResponse() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 전체 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-OLD-TEST', null
    );
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(200, result.code);
    System.assert(
      result.message.contains(GdSaleDeleteBranchHandler.WRAP_MESSAGE_SUFFIX),
      'message 에 옵션 C 분기 표기 추가됨'
    );
    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals('skipped_due_to_migration', result.data.get('point_processing'));
    System.assertEquals(GdSaleDeleteBranchHandler.WRAP_REASON, result.data.get('reason'));
    System.assertEquals('SAL-OLD-TEST', result.data.get('saleNo'));
  }

  // ============================================================
  // B. null 안전 처리
  // ============================================================
  @IsTest
  static void wrap_nullStandardResult_returnsNull() {
    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(null, 'SAL-X', null);
    Test.stopTest();

    System.assertEquals(null, result, 'standardResult null → null 반환');
  }

  @IsTest
  static void wrap_nullData_initializesAndEnriches() {
    // data 가 null 인 표준 응답이 와도 enrich 가능
    ApiResult standardResult = new ApiResult(true, 200, '판매 전체 삭제 완료', null);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-X', null
    );
    Test.stopTest();

    System.assertNotEquals(null, result.data, 'data 가 새로 만들어짐');
    System.assertEquals(true, result.data.get('option_c_branch'));
  }

  @IsTest
  static void wrap_nullLogger_doesNotThrow() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, 'msg', standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-X', null
    );
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'), 'logger null 안전');
  }

  // ============================================================
  // C. logger 제공 시 PARTIAL 상태
  // ============================================================
  @IsTest
  static void wrap_loggerProvided_setsPartialStatus() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, 'msg', standardData);

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging('GdSaleDeleteBranchHandlerTest');

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-X', logger
    );
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'), 'logger 제공 시 정상 동작');
  }

  // ============================================================
  // D. 기존 응답 message 보존 + suffix 추가
  // ============================================================
  @IsTest
  static void wrap_preservesOriginalMessage() {
    String origMessage = '판매 전체 삭제 완료';
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, origMessage, standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-X', null
    );
    Test.stopTest();

    System.assert(result.message.startsWith(origMessage), '원본 message 보존');
    System.assert(
      result.message.contains(GdSaleDeleteBranchHandler.WRAP_MESSAGE_SUFFIX.trim()),
      'suffix 추가됨'
    );
  }

  // ============================================================
  // E. Phase 6.5 — Force-Debit 경로
  //   (LoyaltyTierBenefit 미시드 → totalRequested=0 → 'no accrual estimate' path)
  // ============================================================

  @IsTest
  static void wrap_validSale_invokesForceDebitPath() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 전체 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-SD-OLD', null
    );
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assert(result.data.containsKey('option_c_force_debit_requested'));
    System.assert(result.data.containsKey('option_c_force_debit_actual'));
    System.assert(result.data.containsKey('option_c_force_debit_loss'));
    System.assertNotEquals(null, result.data.get('adjustment_log_id'));
  }

  @IsTest
  static void wrap_saleAlreadyFullyRefunded_skipsForceDebit() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 전체 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-SD-ALL-REF', null
    );
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    // 전액 환불된 판매 → force-debit skip → requested 0
    System.assertEquals(0, result.data.get('option_c_force_debit_requested'));
    System.assertEquals(0, result.data.get('option_c_force_debit_actual'));
  }

  @IsTest
  static void wrap_saleNotFound_recordsErrorInLog() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 전체 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-SD-NOT-EXIST', null
    );
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(0, result.data.get('option_c_force_debit_actual'));
  }

  @IsTest
  static void wrap_saleAmountNull_skipsForceDebit() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 전체 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(
      standardResult, 'SAL-SD-NULL', null
    );
    Test.stopTest();

    System.assertEquals(0, result.data.get('option_c_force_debit_requested'));
  }

  @IsTest
  static void findPromotionIdForOriginalOrder_returnsNullWhenNoTj() {
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SD-OLD' LIMIT 1];
    Test.startTest();
    Id promId = GdSaleDeleteBranchHandler.findPromotionIdForOriginalOrder(o.Id);
    Test.stopTest();
    System.assertEquals(null, promId);
  }

  @IsTest
  static void findPromotionIdForOriginalOrder_nullInput_returnsNull() {
    Test.startTest();
    Id promId = GdSaleDeleteBranchHandler.findPromotionIdForOriginalOrder(null);
    Test.stopTest();
    System.assertEquals(null, promId);
  }

  @IsTest
  static void checkUsageRestoreRequired_noPointPaymentTj_returnsFalse() {
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SD-OLD' LIMIT 1];
    Test.startTest();
    Boolean result = GdSaleDeleteBranchHandler.checkUsageRestoreRequired(o.Id);
    Test.stopTest();
    System.assertEquals(false, result);
  }

  @IsTest
  static void checkUsageRestoreRequired_nullInput_returnsFalse() {
    Test.startTest();
    Boolean result = GdSaleDeleteBranchHandler.checkUsageRestoreRequired(null);
    Test.stopTest();
    System.assertEquals(false, result);
  }
}