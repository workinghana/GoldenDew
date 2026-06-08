/**
 * GdOptionCPointAdjustmentUtil Test
 *
 * 검증 영역: [Non-Accrual Store Guard 2026-05-20]
 *   원판매 매장이 적립 불가(StoreType IN '20'/'25'/'33')일 때
 *   cancelOldSaleEtcAccrualSafe 가 force-debit 을 skip 하는지 검증.
 *
 * 시나리오:
 *   A. isOriginalOrderNonAccrualStore 헬퍼 — 6 케이스
 *      (적립 불가 3종 / 적립 가능 1종 / null Order / StoreCode__c null)
 *   B. cancelOldSaleEtcAccrualSafe 가드 통합 — 2 케이스
 *      (적립 불가 매장 skip / invalid input)
 */
@IsTest
private class GdOptionCPointAdjustmentUtilTest {
  // ============================================================
  // @TestSetup — 공통 매장/Order 데이터
  // ============================================================
  @TestSetup
  static void setupData() {
    Id stdPbId = Test.getStandardPricebookId();

    Account company = new Account(Name = 'TestCompany_OptCAdj', CompanyCode__c = 'CMP-OPTCADJ');
    insert company;

    // 적립 불가 매장 3종 + 적립 가능 매장 1종
    List<Account> stores = new List<Account>{
      new Account(Name = 'OutletStore20', StoreCode__c = 'STR-20', StoreType__c = '20'),
      new Account(Name = 'OutletStore25', StoreCode__c = 'STR-25', StoreType__c = '25'),
      new Account(Name = 'DutyFreeStore33', StoreCode__c = 'STR-33', StoreType__c = '33'),
      new Account(Name = 'NormalStore01', StoreCode__c = 'STR-01', StoreType__c = '01')
    };
    insert stores;

    Map<String, Id> storeIdByCode = new Map<String, Id>();
    for (Account a : stores) {
      storeIdByCode.put(a.StoreCode__c, a.Id);
    }

    Contact c = new Contact(LastName = 'OptCAdjTester', MemberNo__c = 'M-OPTCADJ', AccountId = company.Id);
    insert c;

    // 각 매장별 Order 1건씩 + StoreCode 미설정 Order 1건
    List<Order> orders = new List<Order>{
      buildOrder(company.Id, c.Id, storeIdByCode.get('STR-20'), 'SAL-OPTCADJ-20', stdPbId),
      buildOrder(company.Id, c.Id, storeIdByCode.get('STR-25'), 'SAL-OPTCADJ-25', stdPbId),
      buildOrder(company.Id, c.Id, storeIdByCode.get('STR-33'), 'SAL-OPTCADJ-33', stdPbId),
      buildOrder(company.Id, c.Id, storeIdByCode.get('STR-01'), 'SAL-OPTCADJ-01', stdPbId),
      buildOrder(company.Id, c.Id, null, 'SAL-OPTCADJ-NONE', stdPbId)
    };
    insert orders;
  }

  private static Order buildOrder(Id companyId, Id contactId, Id storeId, String saleNo, Id pbId) {
    return new Order(
      AccountId = companyId,
      EffectiveDate = Date.newInstance(2026, 5, 6),
      Status = 'Draft',
      Pricebook2Id = pbId,
      MemberNo__c = contactId,
      StoreCode__c = storeId,
      SaleNo__c = saleNo,
      ActualPaymentAmount__c = 3108000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
  }

  private static Id orderIdBySaleNo(String saleNo) {
    return [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1].Id;
  }

  private class PointGraph {
    Id loyaltyProgramId;
    Id memberId;
    Id currencyId;
    Id subtypeId;
    Id creditLedgerId;
    Id debitLedgerId;
    Id debitTransactionJournalId;
    Id originalOrderId;
    Id returnOrderId;
  }

  private static Id ensureJournalType(String name) {
    List<JournalType> existing = [SELECT Id FROM JournalType WHERE Name = :name LIMIT 1];
    if (!existing.isEmpty()) {
      return existing[0].Id;
    }
    JournalType jt = new JournalType(Name = name, ProcessType = 'Loyalty');
    insert jt;
    return jt.Id;
  }

  private static Id ensureJournalSubType(String name, Id journalTypeId) {
    List<JournalSubType> existing = [
      SELECT Id
      FROM JournalSubType
      WHERE Name = :name AND JournalTypeId = :journalTypeId
      LIMIT 1
    ];
    if (!existing.isEmpty()) {
      return existing[0].Id;
    }
    JournalSubType jst = new JournalSubType(Name = name, JournalTypeId = journalTypeId);
    insert jst;
    return jst.Id;
  }

  private static PointGraph seedCancelablePointGraph(Decimal creditPoints, Decimal usedPoints, Boolean pointRedeemCancelCredit, Boolean currentReturnRestore) {
    PointGraph graph = new PointGraph();

    ensureJournalSubType('Cancel Purchase Accrual', ensureJournalType('Accrual Reversal'));
    Id accrualJtId = ensureJournalType('Accrual');
    Id purchaseAccrualJstId = ensureJournalSubType('Purchase Accrual', accrualJtId);
    Id redemptionReversalJtId = ensureJournalType('Redemption Reversal');
    Id pointRedeemCancelJstId = ensureJournalSubType('Point Redeem Cancel', redemptionReversalJtId);
    Id pointDebitJstId = ensureJournalSubType('Point Debit', ensureJournalType('Redemption'));

    Contact c = [SELECT Id FROM Contact WHERE MemberNo__c = 'M-OPTCADJ' LIMIT 1];
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'TestLP_OptCAdj_Full_' + String.valueOf(Math.abs(Crypto.getRandomInteger())), IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-OPTCADJ-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      EnrollmentDate = Date.today()
    );
    insert lpm;

    LoyaltyProgramCurrency pointCurrency = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = '포인트',
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
    insert pointCurrency;

    insert new LoyaltyMemberCurrency(Name = 'OptCAdj LMC', LoyaltyMemberId = lpm.Id, LoyaltyProgramCurrencyId = pointCurrency.Id);

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      Name = '사은포인트',
      PointTypeCode__c = '04',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subtype;

    Id originalOrderId = orderIdBySaleNo('SAL-OPTCADJ-01');
    Id returnOrderId = orderIdBySaleNo('SAL-OPTCADJ-NONE');

    TransactionJournal creditTj = new TransactionJournal(
      JournalDate = Datetime.now(),
      ActivityDate = Datetime.now(),
      LoyaltyProgramId = lp.Id,
      MemberId = lpm.Id,
      OrderId = originalOrderId,
      SaleId__c = pointRedeemCancelCredit && currentReturnRestore ? returnOrderId : originalOrderId,
      JournalTypeId = pointRedeemCancelCredit ? redemptionReversalJtId : accrualJtId,
      JournalSubTypeId = pointRedeemCancelCredit ? pointRedeemCancelJstId : purchaseAccrualJstId,
      TransactionAmount = creditPoints,
      Status = 'Processed'
    );
    insert creditTj;

    LoyaltyLedger creditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = pointCurrency.Id,
      LoyaltyPgmCrcySubtypeId = subtype.Id,
      TransactionJournalId = creditTj.Id,
      ActivityDate = Datetime.now(),
      Points = creditPoints,
      ExpiryDate = Date.today().addDays(30),
      EventType = 'Credit'
    );
    insert creditLedger;

    if (usedPoints != null && usedPoints > 0) {
      TransactionJournal debitTj = new TransactionJournal(
        JournalDate = Datetime.now(),
        ActivityDate = Datetime.now(),
        LoyaltyProgramId = lp.Id,
        MemberId = lpm.Id,
        OrderId = originalOrderId,
        JournalTypeId = ensureJournalType('Redemption'),
        JournalSubTypeId = pointDebitJstId,
        TransactionAmount = usedPoints,
        Status = 'Processed'
      );
      insert debitTj;
      graph.debitTransactionJournalId = debitTj.Id;

      LoyaltyLedger debitLedger = new LoyaltyLedger(
        LoyaltyProgramMemberId = lpm.Id,
        LoyaltyProgramCurrencyId = pointCurrency.Id,
        LoyaltyPgmCrcySubtypeId = subtype.Id,
        TransactionJournalId = debitTj.Id,
        ActivityDate = Datetime.now(),
        Points = usedPoints,
        ExpiryDate = Date.today().addDays(30),
        EventType = 'Debit'
      );
      insert debitLedger;
      graph.debitLedgerId = debitLedger.Id;

      insert new LoyaltyLedgerTraceability(
        LoyaltyProgramMemberId = lpm.Id,
        LoyaltyProgramCurrencyId = pointCurrency.Id,
        LoyaltyPgmCurrencySubtypeId = subtype.Id,
        CreditLoyaltyLedgerId = creditLedger.Id,
        DebitLoyaltyLedgerId = debitLedger.Id,
        Points = usedPoints,
        ActionType = 'Debit'
      );
    }

    graph.loyaltyProgramId = lp.Id;
    graph.memberId = lpm.Id;
    graph.currencyId = pointCurrency.Id;
    graph.subtypeId = subtype.Id;
    graph.creditLedgerId = creditLedger.Id;
    graph.originalOrderId = originalOrderId;
    graph.returnOrderId = returnOrderId;
    return graph;
  }

  // ============================================================
  // A. isOriginalOrderNonAccrualStore 헬퍼
  // ============================================================

  @IsTest
  static void testHelper_StoreType20_returnsTrue() {
    Id oid = orderIdBySaleNo('SAL-OPTCADJ-20');
    Test.startTest();
    Boolean result = GdOptionCPointAdjustmentUtil.isOriginalOrderNonAccrualStore(oid);
    Test.stopTest();
    System.assertEquals(true, result, 'StoreType=20 (아울렛) 은 적립 불가 매장으로 판정되어야 함');
  }

  @IsTest
  static void testHelper_StoreType25_returnsTrue() {
    Id oid = orderIdBySaleNo('SAL-OPTCADJ-25');
    Test.startTest();
    Boolean result = GdOptionCPointAdjustmentUtil.isOriginalOrderNonAccrualStore(oid);
    Test.stopTest();
    System.assertEquals(true, result, 'StoreType=25 (아울렛) 은 적립 불가 매장으로 판정되어야 함');
  }

  @IsTest
  static void testHelper_StoreType33_returnsTrue() {
    Id oid = orderIdBySaleNo('SAL-OPTCADJ-33');
    Test.startTest();
    Boolean result = GdOptionCPointAdjustmentUtil.isOriginalOrderNonAccrualStore(oid);
    Test.stopTest();
    System.assertEquals(true, result, 'StoreType=33 (면세) 은 적립 불가 매장으로 판정되어야 함');
  }

  @IsTest
  static void testHelper_StoreType01_returnsFalse() {
    Id oid = orderIdBySaleNo('SAL-OPTCADJ-01');
    Test.startTest();
    Boolean result = GdOptionCPointAdjustmentUtil.isOriginalOrderNonAccrualStore(oid);
    Test.stopTest();
    System.assertEquals(false, result, 'StoreType=01 (백화점) 은 적립 가능 매장 — 가드 통과해야 함');
  }

  @IsTest
  static void testHelper_NullOrderId_returnsFalse() {
    Test.startTest();
    Boolean result = GdOptionCPointAdjustmentUtil.isOriginalOrderNonAccrualStore(null);
    Test.stopTest();
    System.assertEquals(false, result, 'originalOrderId=null 일 때는 false (보수적 — skip 안 함)');
  }

  @IsTest
  static void testHelper_NullStoreCodeOnOrder_returnsFalse() {
    Id oid = orderIdBySaleNo('SAL-OPTCADJ-NONE');
    Test.startTest();
    Boolean result = GdOptionCPointAdjustmentUtil.isOriginalOrderNonAccrualStore(oid);
    Test.stopTest();
    System.assertEquals(false, result, 'Order.StoreCode__c 가 null 이면 false (보수적 — 매장 판단 불가)');
  }

  // ============================================================
  // B. cancelOldSaleEtcAccrualSafe 가드 통합
  // ============================================================

  @IsTest
  static void testGuard_NonAccrualStore_SkipsForceDebit() {
    Id memberId = createDummyMember();
    Id loyaltyProgramId = [SELECT ProgramId FROM LoyaltyProgramMember WHERE Id = :memberId LIMIT 1].ProgramId;
    Id originalOrderId = orderIdBySaleNo('SAL-OPTCADJ-25');

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      memberId,
      loyaltyProgramId,
      originalOrderId,
      null,
      31080,
      'unit-test: non-accrual store skip'
    );
    Test.stopTest();

    System.assertEquals(true, result.success, '적립 불가 매장 skip 은 정상 종료(success=true)');
    System.assertEquals(0, result.actualPoints, '차감된 포인트 없음(actualPoints=0)');
    System.assertEquals(0, result.loss, '손실 없음(loss=0) — 적립 자체가 없었으므로');
    System.assert(result.error != null && result.error.contains('non-accrual'), 'error 메시지에 non-accrual 표기 — 실제 error: ' + result.error);
    System.assertEquals(null, result.reversalTjId, 'Reversal TJ 미생성');
  }

  @IsTest
  static void testGuard_InvalidInput_ReturnsInvalidInputError() {
    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      null, // memberId null → invalid input 분기
      null,
      null,
      null,
      0,
      'unit-test: invalid input'
    );
    Test.stopTest();

    System.assertEquals(false, result.success, 'invalid input 은 실패 처리');
    System.assertEquals('invalid input', result.error, 'error 메시지가 invalid input');
  }

  // ============================================================
  // 헬퍼 — 더미 LoyaltyProgramMember 생성
  // ============================================================
  @IsTest
  static void testCancelSuccess_PrioritizesSameOriginalOrderAndCreatesReversalArtifacts() {
    PointGraph graph = seedCancelablePointGraph(100, 10, false, false);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      graph.memberId,
      graph.loyaltyProgramId,
      graph.originalOrderId,
      graph.returnOrderId,
      50,
      'unit-test: success'
    );
    Test.stopTest();

    System.assertEquals(true, result.success, 'Cancelable option C points should be canceled.');
    System.assertEquals(50, result.actualPoints);
    System.assertEquals(0, result.loss);
    System.assertNotEquals(null, result.reversalTjId);
    System.assertEquals(1, [SELECT COUNT() FROM LoyaltyLedger WHERE TransactionJournalId = :result.reversalTjId AND EventType = 'Debit']);
    System.assertEquals(
      1,
      [SELECT COUNT() FROM LoyaltyLedgerTraceability WHERE CreditLoyaltyLedgerId = :graph.creditLedgerId AND ActionType = 'CreditCancellation']
    );
  }

  @IsTest
  static void testCancelPartial_WhenRequestExceedsBalance_ReturnsLoss() {
    PointGraph graph = seedCancelablePointGraph(40, 15, false, false);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      graph.memberId,
      graph.loyaltyProgramId,
      graph.originalOrderId,
      null,
      100,
      'unit-test: partial'
    );
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(25, result.actualPoints);
    System.assertEquals(75, result.loss);
  }

  @IsTest
  static void testCancel_NoCreditLedger_ReturnsNoActiveLedgerError() {
    Id memberId = createDummyMember();
    Id loyaltyProgramId = [SELECT ProgramId FROM LoyaltyProgramMember WHERE Id = :memberId LIMIT 1].ProgramId;
    ensureJournalSubType('Cancel Purchase Accrual', ensureJournalType('Accrual Reversal'));
    insert new LoyaltyProgramCurrency(
      LoyaltyProgramId = loyaltyProgramId,
      Name = '포인트',
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

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      memberId,
      loyaltyProgramId,
      orderIdBySaleNo('SAL-OPTCADJ-01'),
      null,
      10,
      'unit-test: no ledger'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals('no active option c etc credit ledger', result.error);
  }

  @IsTest
  static void testCancel_FullyUsedCreditLedger_ReturnsNoCancelableBalanceError() {
    PointGraph graph = seedCancelablePointGraph(30, 30, false, false);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      graph.memberId,
      graph.loyaltyProgramId,
      graph.originalOrderId,
      null,
      10,
      'unit-test: fully used'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals('no cancelable option c etc balance', result.error);
  }

  @IsTest
  static void testCancel_DebitCancellationRestoresCancelableBalance() {
    PointGraph graph = seedCancelablePointGraph(30, 30, false, false);
    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = graph.memberId,
      LoyaltyProgramCurrencyId = graph.currencyId,
      LoyaltyPgmCurrencySubtypeId = graph.subtypeId,
      CreditLoyaltyLedgerId = graph.creditLedgerId,
      DebitLoyaltyLedgerId = graph.debitLedgerId,
      Points = 15,
      ActionType = 'DebitCancellation'
    );

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      graph.memberId,
      graph.loyaltyProgramId,
      graph.originalOrderId,
      null,
      20,
      'unit-test: debit cancellation restores balance'
    );
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(15, result.actualPoints);
    System.assertEquals(5, result.loss);
  }

  @IsTest
  static void testCancel_PointRedeemCancelFromOtherReturnIsFilteredOut() {
    PointGraph graph = seedCancelablePointGraph(50, 0, true, false);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      graph.memberId,
      graph.loyaltyProgramId,
      graph.originalOrderId,
      graph.returnOrderId,
      10,
      'unit-test: filtered restore'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals('no active option c etc credit ledger', result.error);
  }

  @IsTest
  static void testCancel_PointRedeemCancelForCurrentReturnIsCancelable() {
    PointGraph graph = seedCancelablePointGraph(50, 0, true, true);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      graph.memberId,
      graph.loyaltyProgramId,
      graph.originalOrderId,
      graph.returnOrderId,
      10,
      'unit-test: current restore'
    );
    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(10, result.actualPoints);
  }

  private static Id createDummyMember() {
    Contact c = [SELECT Id FROM Contact WHERE MemberNo__c = 'M-OPTCADJ' LIMIT 1];
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'TestLP_OptCAdj', IsPrimary = false);
    insert lp;
    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-OPTCADJ',
      EnrollmentDate = Date.today()
    );
    insert lpm;
    return lpm.Id;
  }

  // ============================================================
  // C. [Fix 결함 ① 2026-06-06] OPTC_FORCE_CREDIT prefix 가드
  //    AdditionalNotes__c 가 'OPTC_FORCE_CREDIT:' prefix 인 Credit LL 은
  //    filterCancelableOptionCCreditLedgers 에서 제외되어 회수 대상에서 빠짐.
  // ============================================================
  @IsTest
  static void testCancel_OptcForceCreditLedger_FilteredOut() {
    // 기존 헬퍼로 일반 Credit LL 시드 (subtype PT='04', 100P)
    PointGraph graph = seedCancelablePointGraph(100, 0, false, false);

    // 추가 force-credit Credit LL 발행 (AdditionalNotes='OPTC_FORCE_CREDIT:..')
    Id accrualJtId = ensureJournalType('Accrual');
    Id purchaseAccrualJstId = ensureJournalSubType('Purchase Accrual', accrualJtId);

    TransactionJournal forceCreditTj = new TransactionJournal(
      JournalDate = Datetime.now(),
      ActivityDate = Datetime.now(),
      LoyaltyProgramId = graph.loyaltyProgramId,
      MemberId = graph.memberId,
      OrderId = graph.originalOrderId,
      SaleId__c = graph.originalOrderId,
      JournalTypeId = accrualJtId,
      JournalSubTypeId = purchaseAccrualJstId,
      TransactionAmount = 50,
      Status = 'Processed',
      AdditionalNotes__c = 'OPTC_FORCE_CREDIT: usage restore test'
    );
    insert forceCreditTj;

    LoyaltyLedger forceCreditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = graph.memberId,
      LoyaltyProgramCurrencyId = graph.currencyId,
      LoyaltyPgmCrcySubtypeId = graph.subtypeId,
      TransactionJournalId = forceCreditTj.Id,
      ActivityDate = Datetime.now(),
      Points = 50,
      ExpiryDate = Date.today().addDays(30),
      EventType = 'Credit'
    );
    insert forceCreditLedger;

    // cancel 요청 (정상 LL 100P + force-credit LL 50P 가 시드되어 있지만 force-credit 은 필터됨)
    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      graph.memberId,
      graph.loyaltyProgramId,
      graph.originalOrderId,
      null,
      150, // 150P 요청 — force-credit 까지 빨려들면 다 회수 가능했어야 함
      'unit-test: OPTC_FORCE_CREDIT filter'
    );
    Test.stopTest();

    // 정상 LL 100P 만 회수 가능 → actual=100, loss=50 (force-credit 50P 는 가드로 인해 제외됨)
    System.assertEquals(true, result.success, '정상 LL 100P 회수 성공');
    System.assertEquals(100, result.actualPoints, 'force-credit LL 가드 작동 → 일반 LL 만 회수');
    System.assertEquals(50, result.loss, 'force-credit LL 50P 는 회수 대상에서 제외 → loss=50');

    // force-credit LL 에 CreditCancellation LLT 가 생기지 않았는지 확인
    Integer cancelLLTOnForceCredit = [
      SELECT COUNT()
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId = :forceCreditLedger.Id AND ActionType = 'CreditCancellation'
    ];
    System.assertEquals(0, cancelLLTOnForceCredit, 'force-credit LL 에는 CreditCancellation LLT 생성되지 않음');
  }

  // ============================================================
  // D. [Fix 결함 ① 2026-06-06] AdditionalNotes__c 가 blank 인 경우 정상 회수 진행
  // ============================================================
  @IsTest
  static void testCancel_BlankAdditionalNotes_NotFiltered() {
    // 일반 Credit LL 시드 (AdditionalNotes blank — 기본 동작)
    PointGraph graph = seedCancelablePointGraph(100, 0, false, false);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      graph.memberId,
      graph.loyaltyProgramId,
      graph.originalOrderId,
      null,
      50,
      'unit-test: blank additional notes not filtered'
    );
    Test.stopTest();

    // AdditionalNotes blank → 가드 통과 → 정상 회수
    System.assertEquals(true, result.success);
    System.assertEquals(50, result.actualPoints, 'AdditionalNotes blank LL 은 정상 회수');
    System.assertEquals(0, result.loss);
  }
}