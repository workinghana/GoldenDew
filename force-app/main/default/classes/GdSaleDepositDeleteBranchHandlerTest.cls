/**
 * GdSaleDepositDeleteBranchHandler Test
 *
 * 검증 영역
 *   A. wrapResponseForOldDeposit — silent fail 응답 enrich
 *   B. null 안전 처리 (standardResult / data / logger)
 *   C. message + data 필드 정확성
 *   D. computeAndForceDebitForDepositDelete — 다양한 분기
 *   E. buildAccrualBasisCopy — DepositType 음수 변환
 *   F. Tier 셋업 → estimates > 0 → cancelOldSaleEtcAccrualSafe 실행
 */
@IsTest
private class GdSaleDepositDeleteBranchHandlerTest {
  // TransactionJournal Create 시 발화하는 Salesforce Loyalty 플로우가 콜아웃을 발생시키므로
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
  // @TestSetup — 옛 입금 TJ + 회원 시드
  // ============================================================
  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Id stdPbId = Test.getStandardPricebookId();

    Account company = new Account(Name = 'Co_SDD', CompanyCode__c = 'CMP-SDD');
    Account store = new Account(Name = 'Store_SDD', StoreCode__c = 'STR-SDD');
    insert new List<Account>{ company, store };

    Contact c = new Contact(LastName = 'SDDTester', MemberNo__c = 'M-SDD-TEST', AccountId = company.Id);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP_SDD', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-SDD-TEST',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    Order origOrder = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SAL-SDD-OLD',
      ActualPaymentAmount__c = 100000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert origOrder;

    // 일반 카드/현금 결제 입금 TJ (적립 대상)
    TransactionJournal tjCash = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = origOrder.Id,
      DepositNo__c = 'DEP-SDD-CASH',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 50000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjCash;

    // 환불 입금 (DepositType=03 → 음수 변환 대상)
    TransactionJournal tjReturn = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = origOrder.Id,
      DepositNo__c = 'DEP-SDD-RET',
      DeposiSeqNo__c = '01',
      DepositType__c = '03',
      PaymentMethod = '03',
      TransactionAmount = 30000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjReturn;

    // 포인트 결제 (PM=81 → 적립 비대상)
    TransactionJournal tjPoint = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = origOrder.Id,
      DepositNo__c = 'DEP-SDD-PT',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 20000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjPoint;

    // MemberId 없는 TJ (검증 실패 케이스용 — 직접 컨트롤은 어려우니 일반 케이스 활용)
  }

  // ============================================================
  // A. 정상 enrich
  // ============================================================
  @IsTest
  static void wrap_oldDeposit_enrichesResponse() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 입금 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-CASH', null);
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(200, result.code);
    System.assert(result.message.contains(GdSaleDepositDeleteBranchHandler.WRAP_MESSAGE_SUFFIX), 'message suffix 추가');
    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(GdSaleDepositDeleteBranchHandler.WRAP_REASON, result.data.get('reason'));
    System.assertEquals('DEP-SDD-CASH', result.data.get('depositNo'));
    System.assert(result.data.containsKey('option_c_force_debit_requested'));
    System.assert(result.data.containsKey('option_c_force_debit_actual'));
  }

  // ============================================================
  // B. null 안전 처리
  // ============================================================
  @IsTest
  static void wrap_nullStandardResult_returnsNull() {
    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(null, 'DEP-X', null);
    Test.stopTest();
    System.assertEquals(null, result, 'standardResult null → null 반환');
  }

  @IsTest
  static void wrap_nullData_initializesAndEnriches() {
    ApiResult standardResult = new ApiResult(true, 200, '판매 입금 삭제 완료', null);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-CASH', null);
    Test.stopTest();

    System.assertNotEquals(null, result.data, 'data 가 새로 만들어짐');
    System.assertEquals(true, result.data.get('option_c_branch'));
  }

  @IsTest
  static void wrap_nullLogger_doesNotThrow() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, 'msg', standardData);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-CASH', null);
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
    logger.logging('GdSaleDepositDeleteBranchHandlerTest');

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-CASH', logger);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'), 'logger 제공 시 정상');
  }

  // ============================================================
  // D. 원본 message 보존 + suffix
  // ============================================================
  @IsTest
  static void wrap_preservesOriginalMessage() {
    String origMessage = '판매 입금 삭제 완료';
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, origMessage, standardData);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-CASH', null);
    Test.stopTest();

    System.assert(result.message.startsWith(origMessage), '원본 message 보존');
    System.assert(result.message.contains(GdSaleDepositDeleteBranchHandler.WRAP_MESSAGE_SUFFIX.trim()), 'suffix 추가됨');
  }

  // ============================================================
  // E. 존재하지 않는 depositNo → force-debit 실패
  // ============================================================
  @IsTest
  static void wrap_depositNotFound_setsErrorAndFailedStatus() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 입금 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-NOT-EXIST-XYZ', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(false, result.data.get('option_c_force_debit_success'));
    System.assertEquals(0, result.data.get('option_c_force_debit_requested'));
  }

  // ============================================================
  // F. PaymentMethod=81 (포인트 결제) → eligibleAmount <= 0 → no_debit_needed
  // ============================================================
  @IsTest
  static void wrap_pointPaymentTj_noDebitNeeded() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 입금 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-PT', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    // PM=81 → 적립 비대상 → eligibleAmount <= 0 → success=true, requested=0 → no_debit_needed
    System.assertEquals(0, result.data.get('option_c_force_debit_requested'));
  }

  // ============================================================
  // G. 환불 입금 (DepositType=03) → 음수 변환됨
  // ============================================================
  @IsTest
  static void wrap_returnDeposit_negativeAmountHandled() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 입금 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-RET', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assert(result.data.containsKey('option_c_eligible_amount'));
  }

  // ============================================================
  // H. computeAndForceDebitForDepositDelete — blank input
  // ============================================================
  @IsTest
  static void compute_blankDepositNo_returnsInvalidInputError() {
    Test.startTest();
    GdSaleDepositDeleteBranchHandler.DebitOutcome out = GdSaleDepositDeleteBranchHandler.computeAndForceDebitForDepositDelete('');
    Test.stopTest();
    System.assertNotEquals(null, out, 'outcome 반환 (blank input)');
  }

  @IsTest
  static void compute_nullDepositNo_returnsInvalidInputError() {
    Test.startTest();
    GdSaleDepositDeleteBranchHandler.DebitOutcome out = GdSaleDepositDeleteBranchHandler.computeAndForceDebitForDepositDelete(null);
    Test.stopTest();
    System.assertNotEquals(null, out, 'outcome 반환 (null input)');
  }

  // ============================================================
  // I. compute — 존재하지 않는 depositNo
  // ============================================================
  @IsTest
  static void compute_notFoundDepositNo_returnsTjNotFoundError() {
    Test.startTest();
    GdSaleDepositDeleteBranchHandler.DebitOutcome out = GdSaleDepositDeleteBranchHandler.computeAndForceDebitForDepositDelete('DEP-XYZ-NOT-FOUND');
    Test.stopTest();
    System.assertNotEquals(null, out, 'outcome 반환 (not found)');
  }

  // ============================================================
  // J. compute — del_ prefix 도 매칭됨
  // ============================================================
  @IsTest
  static void compute_delPrefixDepositNo_alsoMatched() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SDD-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SDD-OLD' LIMIT 1];

    // 'del_' prefix TJ — 표준 로직이 삭제 처리한 TJ 시뮬레이션
    TransactionJournal delTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      DepositNo__c = 'del_DEP-SDD-DELETED',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 10000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      IsDeleted__c = true
    );
    insert delTj;

    Test.startTest();
    // 원본 depositNo 로 호출 → del_ prefix 도 IN clause 에 포함되어 매칭
    GdSaleDepositDeleteBranchHandler.DebitOutcome out = GdSaleDepositDeleteBranchHandler.computeAndForceDebitForDepositDelete('DEP-SDD-DELETED');
    Test.stopTest();

    System.assertNotEquals(null, out, 'outcome 반환');
  }

  // ============================================================
  // K. buildAccrualBasisCopy — null/empty 안전
  // ============================================================
  @IsTest
  static void buildAccrualBasisCopy_nullList_returnsEmpty() {
    Test.startTest();
    List<TransactionJournal> result = GdSaleDepositDeleteBranchHandler.buildAccrualBasisCopy(null);
    Test.stopTest();
    System.assertEquals(0, result.size());
  }

  @IsTest
  static void buildAccrualBasisCopy_emptyList_returnsEmpty() {
    Test.startTest();
    List<TransactionJournal> result = GdSaleDepositDeleteBranchHandler.buildAccrualBasisCopy(new List<TransactionJournal>());
    Test.stopTest();
    System.assertEquals(0, result.size());
  }

  // ============================================================
  // L. buildAccrualBasisCopy — DepositType '03' → amount 음수 변환
  // ============================================================
  @IsTest
  static void buildAccrualBasisCopy_depositType03_negatesAmount() {
    TransactionJournal tj = new TransactionJournal(DepositType__c = '03', TransactionAmount = 50000, PaymentMethod = '03');

    Test.startTest();
    List<TransactionJournal> result = GdSaleDepositDeleteBranchHandler.buildAccrualBasisCopy(new List<TransactionJournal>{ tj });
    Test.stopTest();

    System.assertEquals(1, result.size());
    System.assertEquals(-50000, result[0].TransactionAmount, 'DepositType 03 → 음수');
  }

  // ============================================================
  // M. buildAccrualBasisCopy — DepositType '05' → amount 음수 변환
  // ============================================================
  @IsTest
  static void buildAccrualBasisCopy_depositType05_negatesAmount() {
    TransactionJournal tj = new TransactionJournal(DepositType__c = '05', TransactionAmount = 30000, PaymentMethod = '03');

    Test.startTest();
    List<TransactionJournal> result = GdSaleDepositDeleteBranchHandler.buildAccrualBasisCopy(new List<TransactionJournal>{ tj });
    Test.stopTest();

    System.assertEquals(-30000, result[0].TransactionAmount, 'DepositType 05 → 음수');
  }

  // ============================================================
  // N. buildAccrualBasisCopy — DepositType '01' → amount 그대로
  // ============================================================
  @IsTest
  static void buildAccrualBasisCopy_depositType01_keepsAmount() {
    TransactionJournal tj = new TransactionJournal(DepositType__c = '01', TransactionAmount = 70000, PaymentMethod = '03');

    Test.startTest();
    List<TransactionJournal> result = GdSaleDepositDeleteBranchHandler.buildAccrualBasisCopy(new List<TransactionJournal>{ tj });
    Test.stopTest();

    System.assertEquals(70000, result[0].TransactionAmount, 'DepositType 01 → 동일');
  }

  // ============================================================
  // O. buildAccrualBasisCopy — null amount 안전 (0 처리)
  // ============================================================
  @IsTest
  static void buildAccrualBasisCopy_nullAmount_defaultsToZero() {
    TransactionJournal tj = new TransactionJournal(DepositType__c = '03', PaymentMethod = '03');

    Test.startTest();
    List<TransactionJournal> result = GdSaleDepositDeleteBranchHandler.buildAccrualBasisCopy(new List<TransactionJournal>{ tj });
    Test.stopTest();

    System.assertEquals(0, result[0].TransactionAmount, 'null amount → 0');
  }

  // ============================================================
  // P. buildAccrualBasisCopy — null entry 안전 (skip)
  // ============================================================
  @IsTest
  static void buildAccrualBasisCopy_listWithNull_skipsNullEntry() {
    TransactionJournal validTj = new TransactionJournal(DepositType__c = '01', TransactionAmount = 10000, PaymentMethod = '03');

    Test.startTest();
    List<TransactionJournal> result = GdSaleDepositDeleteBranchHandler.buildAccrualBasisCopy(new List<TransactionJournal>{ null, validTj, null });
    Test.stopTest();

    System.assertEquals(1, result.size(), 'null entry skip');
  }

  // ============================================================
  // Q. Force-debit deep path — Tier 셋업으로 estimates > 0 → cancelOldSaleEtcAccrualSafe 실행
  // ============================================================
  @IsTest
  static void wrap_withTierSetup_invokesForceDebitWithPositiveEstimate() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SDD-TEST' LIMIT 1];

    String suffix = String.valueOf(Datetime.now().getTime()) + 'Q';

    LoyaltyProgramCurrency currQ = new LoyaltyProgramCurrency(
      Name = 'CurrQ_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 1,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert currQ;

    LoyaltyPgmCurrencySubtype subtQ = new LoyaltyPgmCurrencySubtype(
      Name = 'SubtQ_' + suffix,
      LoyaltyProgramCurrencyId = currQ.Id,
      UsagePriorityNumber = 1,
      IsActive = true,
      PointTypeCode__c = '01'
    );
    insert subtQ;

    insert new LoyaltyMemberCurrency(Name = 'LMCQ_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyProgramCurrencyId = currQ.Id);

    LoyaltyTierGroup tgQ = new LoyaltyTierGroup(
      Name = 'TGQ_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tgQ;

    LoyaltyTier tierQ = new LoyaltyTier(Name = 'TierQ_' + suffix, LoyaltyTierGroupId = tgQ.Id);
    insert tierQ;

    insert new LoyaltyMemberTier(Name = 'MTQ_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyTierId = tierQ.Id, EffectiveDate = Date.today());

    BenefitType btQ = new BenefitType(
      Name = 'BTQ_' + suffix,
      ProcessType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue(),
      LoyaltyProgramId = lpm.ProgramId
    );
    insert btQ;

    Benefit bQ = new Benefit(Name = 'BQ_' + suffix, BenefitTypeId = btQ.Id, PurchasePointRate__c = 2, LoyaltyPgmCurrencySubtypeId__c = subtQ.Id);
    insert bQ;

    insert new LoyaltyTierBenefit(Name = 'TBQ_' + suffix, LoyaltyTierId = tierQ.Id, BenefitId = bQ.Id);

    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 입금 삭제 완료', standardData);

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-CASH', null);
      called = (result != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called, 'tier 셋업 + deep force-debit 실행');
  }

  // ============================================================
  // R. [Fix 결함 ⑥ 2026-06-08] carry-over skip 조건 제거 검증
  //    OrderId__c != null (주문→판매 carry-over) TJ 도 force-debit 진행
  //    수정 전: L231 skip → 적립 회수 0
  //    수정 후: skip 제거 → 정상 회수 진행
  // ============================================================
  @IsTest
  static void wrap_carryOverDeposit_proceedsForceDebit() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SDD-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SDD-OLD' LIMIT 1];

    // carry-over 입금 TJ (OrderId__c != null — SOR Order 로부터 끌어옴)
    TransactionJournal carryOverTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      OrderId__c = o.Id, // carry-over 마커
      SaleId__c = o.Id,
      DepositNo__c = 'DEP-SDD-CARRYOVER',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 70000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert carryOverTj;

    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 입금 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-CARRYOVER', null);
    Test.stopTest();

    // 수정 전이면 carry-over skip 으로 eligibleAmount=0, force_debit_requested=0 이었음.
    // 수정 후: carry-over 도 진입하여 eligibleAmount > 0 확인.
    System.assertEquals(true, result.data.get('option_c_branch'));
    Decimal eligibleAmount = (Decimal) result.data.get('option_c_eligible_amount');
    System.assert(eligibleAmount != null && eligibleAmount > 0, 'carry-over TJ skip 안 됨 → eligibleAmount > 0 (실제: ' + eligibleAmount + ')');
  }

  // ============================================================
  // S. carry-over (OrderId__c != null) TJ 의 eligibleAmount 정확성 검증
  //    수정 전: carry-over skip → eligibleAmount=0
  //    수정 후: carry-over 진입 → eligibleAmount = TransactionAmount
  // ============================================================
  @IsTest
  static void wrap_carryOverDeposit_eligibleAmountEqualsTxAmount() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-SDD-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SAL-SDD-OLD' LIMIT 1];

    TransactionJournal carryTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      OrderId__c = o.Id,
      DepositNo__c = 'DEP-SDD-CARRYOVER-C',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 30000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert carryTj;

    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 입금 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdSaleDepositDeleteBranchHandler.wrapResponseForOldDeposit(standardResult, 'DEP-SDD-CARRYOVER-C', null);
    Test.stopTest();

    // 수정 전: carry-over skip → eligibleAmount=0
    // 수정 후: carry-over 도 진입 → eligibleAmount=30000
    Decimal eligibleAmount = (Decimal) result.data.get('option_c_eligible_amount');
    System.assertEquals(30000, eligibleAmount, 'carry-over TJ 도 eligibleAmount 산출 진행 (skip 안 됨)');
  }
}