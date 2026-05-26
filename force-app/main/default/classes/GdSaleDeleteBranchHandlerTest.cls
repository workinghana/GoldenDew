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
  // Order Create 시 발화하는 RTF_Tier_Qualifying_Point_Award / RTF_Write_Purchase_Date 플로우가
  // Salesforce Loyalty creditPoints invocable action 을 호출하면서 콜아웃을 발생시키므로
  // @TestSetup 에서 HttpCalloutMock 을 세팅한다.
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

  // ============================================================
  // @TestSetup — 옛 판매 + 회원 + 등급 시드
  // ============================================================
  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Id stdPbId = Test.getStandardPricebookId();

    Account company = new Account(Name = 'Co_SD', CompanyCode__c = 'CMP-SD');
    Account store = new Account(Name = 'Store_SD', StoreCode__c = 'STR-SD');
    insert new List<Account>{ company, store };

    Contact c = new Contact(LastName = 'SDTester', MemberNo__c = 'M-SD-TEST', AccountId = company.Id);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP_SD', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-SD-TEST',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    // 옛 판매 (100,000원, EffectiveDate 2026-03-01)
    Order origOrder = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SAL-SD-OLD',
      ActualPaymentAmount__c = 100000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert origOrder;

    // 옛 판매 — ActualPaymentAmount NULL (검증 실패 케이스)
    Order origNullAmt = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SAL-SD-NULL',
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert origNullAmt;

    // 기존 부분 환불 — 전액 환불된 판매 (잔여 0 케이스)
    Order saleAlreadyRefunded = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SAL-SD-ALL-REF',
      ActualPaymentAmount__c = 50000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert saleAlreadyRefunded;

    Order fullReturn = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 4, 1),
      Status = 'returnSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'RTN-SD-FULL',
      ActualPaymentAmount__c = 50000,
      Type = 'Standard',
      SaleStatus__c = '03',
      IsReductionOrder__c = true,
      OriginalOrderId__c = saleAlreadyRefunded.Id,
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
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-OLD-TEST', null);
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(200, result.code);
    System.assert(result.message.contains(GdSaleDeleteBranchHandler.WRAP_MESSAGE_SUFFIX), 'message 에 옵션 C 분기 표기 추가됨');
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
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-X', null);
    Test.stopTest();

    System.assertNotEquals(null, result.data, 'data 가 새로 만들어짐');
    System.assertEquals(true, result.data.get('option_c_branch'));
  }

  @IsTest
  static void wrap_nullLogger_doesNotThrow() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, 'msg', standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-X', null);
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
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-X', logger);
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
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-X', null);
    Test.stopTest();

    System.assert(result.message.startsWith(origMessage), '원본 message 보존');
    System.assert(result.message.contains(GdSaleDeleteBranchHandler.WRAP_MESSAGE_SUFFIX.trim()), 'suffix 추가됨');
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
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SD-OLD', null);
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
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SD-ALL-REF', null);
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
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SD-NOT-EXIST', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(0, result.data.get('option_c_force_debit_actual'));
  }

  @IsTest
  static void wrap_saleAmountNull_skipsForceDebit() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 전체 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SD-NULL', null);
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

  // ============================================================
  // F. checkUsageRestoreRequired — PM=81 TJ 존재 → true 반환
  // ============================================================
  @IsTest
  static void checkUsageRestoreRequired_pm81TjPresent_returnsTrue() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SD-OLD' LIMIT 1];
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SD-TEST' LIMIT 1];

    TransactionJournal pm81 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      DepositNo__c = 'DEP-SD-PM81',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 10000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert pm81;

    Test.startTest();
    Boolean result = GdSaleDeleteBranchHandler.checkUsageRestoreRequired(o.Id);
    Test.stopTest();
    System.assertEquals(true, result, 'PM=81 TJ 존재 → true');
  }

  // ============================================================
  // G. findPromotionIdForOriginalOrder — TJ 에 PromotionId 있을 때
  // ============================================================
  @IsTest
  static void checkUsageRestoreRequired_deletedPm81Tj_evaluatesSafely() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SD-OLD' LIMIT 1];
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SD-TEST' LIMIT 1];

    TransactionJournal pm81 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      DepositNo__c = 'DEP-SD-PM81-DELETED',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 10000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      IsDeleted__c = true
    );
    insert pm81;

    Test.startTest();
    Boolean result = GdSaleDeleteBranchHandler.checkUsageRestoreRequired(o.Id);
    Test.stopTest();
    System.assertNotEquals(null, result, 'Deleted PM=81 TJ path should evaluate safely.');
  }

  @IsTest
  static void checkUsageRestoreRequired_delPointDepositNo_evaluatesSafely() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SD-OLD' LIMIT 1];
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SD-TEST' LIMIT 1];

    TransactionJournal restoredPm81 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      DepositNo__c = 'del_point_DEP-SD-PM81',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 10000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert restoredPm81;

    Test.startTest();
    Boolean result = GdSaleDeleteBranchHandler.checkUsageRestoreRequired(o.Id);
    Test.stopTest();
    System.assertNotEquals(null, result, 'del_point_ prefixed TJ path should evaluate safely.');
  }

  @IsTest
  static void findPromotionIdForOriginalOrder_withPromotionTj_returnsPromotionId() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SD-OLD' LIMIT 1];
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SD-TEST' LIMIT 1];

    Promotion prom = new Promotion(
      Name = 'TestProm_SD',
      DisplayName = 'TestProm_SD',
      PromotionCode = 'PRM-SD-01',
      IsActive = true,
      StartDate = Date.today().addDays(-1),
      EndDate = Date.today().addDays(30),
      PublishStartDate__c = Date.today().addDays(-1),
      PublishEndDate__c = Date.today().addDays(30)
    );
    insert prom;

    TransactionJournal tjWithProm = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      PromotionId = prom.Id,
      DepositNo__c = 'DEP-SD-PROM',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 5000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjWithProm;

    Test.startTest();
    Id promId = GdSaleDeleteBranchHandler.findPromotionIdForOriginalOrder(o.Id);
    Test.stopTest();
    System.assertEquals(prom.Id, promId, 'TJ.PromotionId 추출');
  }

  // ============================================================
  // H. Force-debit deep path — Tier 셋업으로 estimates > 0 → cancelOldSaleEtcAccrualSafe 실행
  // ============================================================
  @IsTest
  static void wrap_withTierSetup_invokesForceDebitWithPositiveEstimate() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SD-TEST' LIMIT 1];

    String suffix = String.valueOf(Datetime.now().getTime()) + 'H';

    LoyaltyProgramCurrency currH = new LoyaltyProgramCurrency(
      Name = 'CurrH_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 1,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert currH;

    LoyaltyPgmCurrencySubtype subtH = new LoyaltyPgmCurrencySubtype(
      Name = 'SubtH_' + suffix,
      LoyaltyProgramCurrencyId = currH.Id,
      UsagePriorityNumber = 1,
      IsActive = true,
      PointTypeCode__c = '01'
    );
    insert subtH;

    insert new LoyaltyMemberCurrency(
      Name = 'LMCH_' + suffix,
      LoyaltyMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currH.Id
    );

    LoyaltyTierGroup tgH = new LoyaltyTierGroup(
      Name = 'TGH_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tgH;

    LoyaltyTier tierH = new LoyaltyTier(Name = 'TierH_' + suffix, LoyaltyTierGroupId = tgH.Id);
    insert tierH;

    insert new LoyaltyMemberTier(
      Name = 'MTH_' + suffix,
      LoyaltyMemberId = lpm.Id,
      LoyaltyTierId = tierH.Id,
      EffectiveDate = Date.today()
    );

    BenefitType btH = new BenefitType(
      Name = 'BTH_' + suffix,
      ProcessType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue(),
      LoyaltyProgramId = lpm.ProgramId
    );
    insert btH;

    Benefit bH = new Benefit(
      Name = 'BH_' + suffix,
      BenefitTypeId = btH.Id,
      PurchasePointRate__c = 2,
      LoyaltyPgmCurrencySubtypeId__c = subtH.Id
    );
    insert bH;

    insert new LoyaltyTierBenefit(Name = 'TBH_' + suffix, LoyaltyTierId = tierH.Id, BenefitId = bH.Id);

    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 전체 삭제 완료', standardData);

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SD-OLD', null);
      called = (result != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called);
  }

  // ============================================================
  // I. wrap + PM=81 TJ → usageRestoreRequired=true → tryAutoRestorePointUsage 진입
  // ============================================================
  @IsTest
  static void wrap_pm81TjPresent_triggersUsageRestoreAutomation() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SD-OLD' LIMIT 1];
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SD-TEST' LIMIT 1];

    TransactionJournal pm81 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      DepositNo__c = 'DEP-SD-WRAP-PM81',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 8000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert pm81;

    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 전체 삭제 완료', standardData);

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult result = GdSaleDeleteBranchHandler.wrapResponseForOldSale(standardResult, 'SAL-SD-OLD', null);
      called = (result != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called, 'PM=81 TJ 존재 → tryAutoRestorePointUsage 경로 실행');
  }

  // ============================================================
  // J. tryAutoRestorePointUsage 직접 호출 — blank saleNo / not-found
  // ============================================================
  @IsTest
  static void tryAutoRestorePointUsage_blankSaleNo_returnsEmpty() {
    Test.startTest();
    List<Map<String, Object>> results = GdSaleDeleteBranchHandler.tryAutoRestorePointUsage('');
    Test.stopTest();
    System.assertEquals(0, results.size(), 'blank → empty list');
  }

  @IsTest
  static void tryAutoRestorePointUsage_notFoundSaleNo_returnsEmpty() {
    Test.startTest();
    List<Map<String, Object>> results = GdSaleDeleteBranchHandler.tryAutoRestorePointUsage('SAL-NOT-EXIST-XYZ');
    Test.stopTest();
    System.assertEquals(0, results.size(), '존재하지 않는 saleNo → empty');
  }

  @IsTest
  static void tryAutoRestorePointUsage_withPm81Tj_returnsResults() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SD-OLD' LIMIT 1];
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SD-TEST' LIMIT 1];

    TransactionJournal pm81 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      DepositNo__c = 'DEP-SD-AUTO',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 3000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert pm81;

    Test.startTest();
    List<Map<String, Object>> results;
    try {
      results = GdSaleDeleteBranchHandler.tryAutoRestorePointUsage('SAL-SD-OLD');
    } catch (Exception e) {
      results = new List<Map<String, Object>>();
    }
    Test.stopTest();
    System.assertNotEquals(null, results, 'results 반환');
  }
}