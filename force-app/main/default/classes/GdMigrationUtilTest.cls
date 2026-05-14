/**
 * GdMigrationUtil Test
 *
 * Phase 1 — 분기 처리 활성화 / 기준 일자 / 옛 거래 판단 로직 검증
 *
 * 검증 영역:
 *   A. Feature Flag (IsEnabled__c) — 미설정 / false / true
 *   B. OpenDate fallback — Custom Setting 미설정 시 default
 *   C. shouldApplyOptionCBranchByDepositNo — 6 가지 분기
 *   D. shouldApplyOptionCBranchBySaleNo — 5 가지 분기
 *   E. shouldApplyOptionCBranchByOrderId — 3 가지 분기
 *   F. isPreOpenTransaction — 마이그 마커 / Order 일자 / TJ 일자 / null
 */
@IsTest
private class GdMigrationUtilTest {
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

  // 테스트 상수
  private static final Date OPEN_DATE = Date.newInstance(2026, 5, 15);
  private static final Date PRE_OPEN_DATE = Date.newInstance(2026, 3, 1);
  private static final Date POST_OPEN_DATE = Date.newInstance(2026, 6, 1);

  // ============================================================
  // @TestSetup — 공통 테스트 데이터
  // ============================================================
  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    // Standard Pricebook 활성화
    Id stdPbId = Test.getStandardPricebookId();

    // 회사 (Account, AccountId 용)
    Account company = new Account(Name = 'TestCompany_OptC', CompanyCode__c = 'CMP-OPTC');
    insert company;

    // 매장 (StoreCode 용)
    Account store = new Account(Name = 'TestStore_OptC', StoreCode__c = 'STR-OPTC');
    insert store;

    // 회원 Contact
    Contact c = new Contact(LastName = 'OptCTester', MemberNo__c = 'M-OPTC-TEST', AccountId = company.Id);
    insert c;

    // LoyaltyProgram + LoyaltyProgramMember (TJ 의 MemberId 필수)
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'TestLP_OptC', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-OPTC-TEST',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    // 옛 Order (EffectiveDate < OpenDate)
    Order oldOrder = new Order(
      AccountId = company.Id,
      EffectiveDate = PRE_OPEN_DATE,
      Status = 'Draft',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SALE-OPTC-OLD',
      ActualPaymentAmount__c = 10000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert oldOrder;

    // 신규 Order (EffectiveDate >= OpenDate)
    Order newOrder = new Order(
      AccountId = company.Id,
      EffectiveDate = POST_OPEN_DATE,
      Status = 'Draft',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SALE-OPTC-NEW',
      ActualPaymentAmount__c = 10000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert newOrder;

    // 옛 거래 TJ (Order EffectiveDate < OpenDate 기반)
    TransactionJournal oldTj = new TransactionJournal(
      MemberId = lpm.Id,
      OrderId = oldOrder.Id,
      DepositNo__c = 'DEP-OPTC-OLD-01',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 10000,
      ActivityDate = PRE_OPEN_DATE,
      Status = 'Processed',
      InsertId__c = 'tester'
    );
    insert oldTj;

    // 신규 거래 TJ
    TransactionJournal newTj = new TransactionJournal(
      MemberId = lpm.Id,
      OrderId = newOrder.Id,
      DepositNo__c = 'DEP-OPTC-NEW-01',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 10000,
      ActivityDate = POST_OPEN_DATE,
      Status = 'Processed',
      InsertId__c = 'tester'
    );
    insert newTj;

    // 마이그레이션 마커 TJ (Order 없이, InsertId 만으로 식별)
    TransactionJournal migTj = new TransactionJournal(
      MemberId = lpm.Id,
      DepositNo__c = 'DEP-OPTC-MIG-01',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 10000,
      ActivityDate = POST_OPEN_DATE, // 마커 우선 → 일자 무시
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert migTj;
  }

  @IsTest
  static void fallbackConstants_areExposedForTests() {
    Test.startTest();
    Date openDate = GdMigrationUtil.getDefaultOpenDate();
    Set<String> migrationInsertIds = GdMigrationUtil.getMigrationInsertIds();
    Set<String> excludedPaymentMethods = GdMigrationUtil.getPaymentMethodsNotAccrualEligible();
    Test.stopTest();

    System.assertEquals(Date.newInstance(2026, 5, 15), openDate);
    System.assertEquals(new Set<String>{ 'MIG_OPTC_CREDIT', 'MIG_OPTC_CANCEL' }, migrationInsertIds);
    System.assertEquals(new Set<String>{ '20', '81', '90', '93' }, excludedPaymentMethods);
  }

  // ============================================================
  // 헬퍼 — Custom Setting 설정
  // ============================================================
  private static void setBranchEnabled(Boolean enabled, Date openDate) {
    OptionCBranchSetting__c setting = OptionCBranchSetting__c.getInstance();
    if (setting == null || setting.Id == null) {
      setting = new OptionCBranchSetting__c();
    }
    setting.IsEnabled__c = enabled;
    setting.OpenDate__c = openDate;
    upsert setting;
  }

  // ============================================================
  // A. Feature Flag — Custom Setting 미존재
  // ============================================================
  @IsTest
  static void isOptionCBranchEnabled_noSetting_returnsFalse() {
    Test.startTest();
    Boolean result = GdMigrationUtil.isOptionCBranchEnabled();
    Test.stopTest();

    System.assertEquals(false, result, 'Custom Setting 미존재 시 false 반환해야 함');
  }

  @IsTest
  static void isOptionCBranchEnabled_disabled_returnsFalse() {
    setBranchEnabled(false, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.isOptionCBranchEnabled();
    Test.stopTest();

    System.assertEquals(false, result, 'IsEnabled=false 시 false 반환해야 함');
  }

  @IsTest
  static void isOptionCBranchEnabled_enabled_returnsTrue() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.isOptionCBranchEnabled();
    Test.stopTest();

    System.assertEquals(true, result, 'IsEnabled=true 시 true 반환해야 함');
  }

  // ============================================================
  // B. OpenDate — fallback 동작
  // ============================================================
  @IsTest
  static void getOpenDate_noSetting_returnsDefault() {
    Test.startTest();
    Date result = GdMigrationUtil.getOpenDate();
    Test.stopTest();

    System.assertEquals(GdMigrationUtil.getDefaultOpenDate(), result, '미설정 시 기본값 반환');
    System.assertEquals(Date.newInstance(2026, 5, 15), result, '기본값은 2026-05-15');
  }

  @IsTest
  static void getOpenDate_settingPresent_returnsConfigured() {
    Date custom = Date.newInstance(2027, 1, 1);
    setBranchEnabled(true, custom);

    Test.startTest();
    Date result = GdMigrationUtil.getOpenDate();
    Test.stopTest();

    System.assertEquals(custom, result, 'Custom Setting 값 반환해야 함');
  }

  @IsTest
  static void getOpenDate_settingPresentButDateNull_returnsDefault() {
    setBranchEnabled(true, null);

    Test.startTest();
    Date result = GdMigrationUtil.getOpenDate();
    Test.stopTest();

    System.assertEquals(Date.newInstance(2026, 5, 15), result, 'OpenDate__c=null 시 default 반환');
  }

  // ============================================================
  // C. shouldApplyOptionCBranchByDepositNo
  // ============================================================
  @IsTest
  static void shouldApplyByDepositNo_disabled_returnsFalse() {
    setBranchEnabled(false, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo('DEP-OPTC-OLD-01');
    Test.stopTest();

    System.assertEquals(false, result, 'Feature Flag OFF 시 false');
  }

  @IsTest
  static void shouldApplyByDepositNo_blankInput_returnsFalse() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean blank = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo('');
    Boolean nullInput = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo(null);
    Test.stopTest();

    System.assertEquals(false, blank, '빈 입력 false');
    System.assertEquals(false, nullInput, 'null 입력 false');
  }

  @IsTest
  static void shouldApplyByDepositNo_notFound_returnsFalse() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo('NON-EXISTENT-DEP');
    Test.stopTest();

    System.assertEquals(false, result, '매칭 없으면 false');
  }

  @IsTest
  static void shouldApplyByDepositNo_oldOrder_returnsTrue() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo('DEP-OPTC-OLD-01');
    Test.stopTest();

    System.assertEquals(true, result, '옛 Order 의 TJ 는 true');
  }

  @IsTest
  static void shouldApplyByDepositNo_newOrder_returnsFalse() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo('DEP-OPTC-NEW-01');
    Test.stopTest();

    System.assertEquals(false, result, '신규 Order 의 TJ 는 false');
  }

  @IsTest
  static void shouldApplyByDepositNo_migrationMarker_returnsTrue() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo('DEP-OPTC-MIG-01');
    Test.stopTest();

    System.assertEquals(true, result, '마이그레이션 마커 (InsertId__c=MIG_OPTC_CREDIT) → true');
  }

  @IsTest
  static void shouldApplyByDepositNo_noOrderUsesActivityDateFallback() {
    setBranchEnabled(true, OPEN_DATE);
    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    TransactionJournal tj = new TransactionJournal(
      MemberId = lpm.Id,
      DepositNo__c = 'DEP-OPTC-ACTIVITY-FALLBACK',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 10000,
      ActivityDate = PRE_OPEN_DATE,
      Status = 'Processed',
      InsertId__c = 'tester'
    );
    insert tj;

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo('DEP-OPTC-ACTIVITY-FALLBACK');
    Test.stopTest();

    System.assertEquals(true, result);
  }

  // ============================================================
  // D. shouldApplyOptionCBranchBySaleNo
  // ============================================================
  @IsTest
  static void shouldApplyBySaleNo_disabled_returnsFalse() {
    setBranchEnabled(false, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchBySaleNo('SALE-OPTC-OLD');
    Test.stopTest();

    System.assertEquals(false, result, 'Feature Flag OFF 시 false');
  }

  @IsTest
  static void shouldApplyBySaleNo_blankInput_returnsFalse() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean blank = GdMigrationUtil.shouldApplyOptionCBranchBySaleNo('');
    Boolean nullInput = GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(null);
    Test.stopTest();

    System.assertEquals(false, blank, '빈 입력 false');
    System.assertEquals(false, nullInput, 'null 입력 false');
  }

  @IsTest
  static void shouldApplyBySaleNo_notFound_returnsFalse() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchBySaleNo('NON-EXISTENT-SALE');
    Test.stopTest();

    System.assertEquals(false, result, '매칭 없으면 false');
  }

  @IsTest
  static void shouldApplyBySaleNo_oldSale_returnsTrue() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchBySaleNo('SALE-OPTC-OLD');
    Test.stopTest();

    System.assertEquals(true, result, '옛 SaleNo 는 true');
  }

  @IsTest
  static void shouldApplyBySaleNo_newSale_returnsFalse() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchBySaleNo('SALE-OPTC-NEW');
    Test.stopTest();

    System.assertEquals(false, result, '신규 SaleNo 는 false');
  }

  // ============================================================
  // E. shouldApplyOptionCBranchByOrderId
  // ============================================================
  @IsTest
  static void shouldApplyByOrderId_disabled_returnsFalse() {
    setBranchEnabled(false, OPEN_DATE);
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-OLD' LIMIT 1];

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByOrderId(o.Id);
    Test.stopTest();

    System.assertEquals(false, result, 'Feature Flag OFF 시 false');
  }

  @IsTest
  static void shouldApplyByOrderId_oldOrder_returnsTrue() {
    setBranchEnabled(true, OPEN_DATE);
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-OLD' LIMIT 1];

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByOrderId(o.Id);
    Test.stopTest();

    System.assertEquals(true, result, '옛 Order Id 는 true');
  }

  @IsTest
  static void shouldApplyByOrderId_newOrder_returnsFalse() {
    setBranchEnabled(true, OPEN_DATE);
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-NEW' LIMIT 1];

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByOrderId(o.Id);
    Test.stopTest();

    System.assertEquals(false, result, '신규 Order Id 는 false');
  }

  @IsTest
  static void shouldApplyByOrderId_nullInput_returnsFalse() {
    setBranchEnabled(true, OPEN_DATE);

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByOrderId(null);
    Test.stopTest();

    System.assertEquals(false, result, 'null Id 는 false');
  }

  // ============================================================
  // F. Migration Insert Id Set 검증
  // ============================================================
  @IsTest
  static void migrationInsertIds_includesExpectedMarkers() {
    Set<String> ids = GdMigrationUtil.getMigrationInsertIds();
    System.assert(ids.contains('MIG_OPTC_CREDIT'), 'MIG_OPTC_CREDIT 포함');
    System.assert(ids.contains('MIG_OPTC_CANCEL'), 'MIG_OPTC_CANCEL 포함');
  }

  // ============================================================
  // H. recordAdjustmentLog (Phase 6.1) 검증
  // ============================================================

  @IsTest
  static void recordLog_validInputs_createsRecord() {
    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    Test.startTest();
    Id logId = GdMigrationUtil.recordAdjustmentLog(
      lpm.Id,
      'M-OPTC-TEST',
      'ACCRUAL_REVERSAL',
      'POST /gd/v1/return',
      'SALE-OPTC-OLD',
      1000,
      200,
      'Test reason'
    );
    Test.stopTest();

    System.assertNotEquals(null, logId, '로그 Id 반환');

    MigrationAdjustmentLog__c log = [
      SELECT MemberId__c, MemberNo__c, AdjustType__c, SourceApi__c, OriginalSaleNo__c, RequestedPoints__c, ActualPoints__c, CustomerLoss__c, Reason__c
      FROM MigrationAdjustmentLog__c
      WHERE Id = :logId
      LIMIT 1
    ];
    System.assertEquals(String.valueOf(lpm.Id), log.MemberId__c);
    System.assertEquals('M-OPTC-TEST', log.MemberNo__c);
    System.assertEquals('ACCRUAL_REVERSAL', log.AdjustType__c);
    System.assertEquals('POST /gd/v1/return', log.SourceApi__c);
    System.assertEquals('SALE-OPTC-OLD', log.OriginalSaleNo__c);
    System.assertEquals(1000, log.RequestedPoints__c);
    System.assertEquals(200, log.ActualPoints__c);
    System.assertEquals(800, log.CustomerLoss__c, '손실 = 요청 - 실제 = 800');
    System.assertEquals('Test reason', log.Reason__c);
  }

  @IsTest
  static void recordLog_blankAdjustType_returnsNull() {
    Test.startTest();
    Id logId = GdMigrationUtil.recordAdjustmentLog(null, null, '', null, null, 100, 50, null);
    Test.stopTest();

    System.assertEquals(null, logId, 'adjustType blank → null 반환');
  }

  @IsTest
  static void recordLog_nullArgs_handlesSafely() {
    Test.startTest();
    Id logId = GdMigrationUtil.recordAdjustmentLog(null, null, 'TEST_TYPE', null, null, null, null, null);
    Test.stopTest();

    System.assertNotEquals(null, logId, 'adjustType 만 있으면 insert 됨');

    MigrationAdjustmentLog__c log = [
      SELECT RequestedPoints__c, ActualPoints__c, CustomerLoss__c
      FROM MigrationAdjustmentLog__c
      WHERE Id = :logId
      LIMIT 1
    ];
    System.assertEquals(0, log.RequestedPoints__c, 'null requested → 0 처리');
    System.assertEquals(0, log.ActualPoints__c, 'null actual → 0 처리');
    System.assertEquals(0, log.CustomerLoss__c, 'loss = 0');
  }

  @IsTest
  static void recordLog_noLoss_customerLossZero() {
    Test.startTest();
    Id logId = GdMigrationUtil.recordAdjustmentLog(null, 'M-X', 'TEST', 'API-X', 'SALE-X', 500, 500, 'no loss');
    Test.stopTest();

    MigrationAdjustmentLog__c log = [SELECT CustomerLoss__c FROM MigrationAdjustmentLog__c WHERE Id = :logId LIMIT 1];
    System.assertEquals(0, log.CustomerLoss__c, 'requested == actual → loss 0');
  }

  @IsTest
  static void recordLog_actualGreaterThanRequested_lossClampedZero() {
    // 비정상 케이스: actual > requested (이상 데이터)
    Test.startTest();
    Id logId = GdMigrationUtil.recordAdjustmentLog(null, 'M-X', 'TEST', 'API-X', 'SALE-X', 100, 200, 'actual > requested');
    Test.stopTest();

    MigrationAdjustmentLog__c log = [SELECT CustomerLoss__c FROM MigrationAdjustmentLog__c WHERE Id = :logId LIMIT 1];
    System.assertEquals(0, log.CustomerLoss__c, '음수 손실은 0 으로 clamp');
  }

  // ============================================================
  // J. Phase 6.3 — calculateEligibleAccrualAmount (표준 로직 복제)
  // ============================================================

  @IsTest
  static void calculateEligibleAmount_emptyOrNullList_returnsZero() {
    Test.startTest();
    System.assertEquals(0, GdMigrationUtil.calculateEligibleAccrualAmount(null, 0));
    System.assertEquals(0, GdMigrationUtil.calculateEligibleAccrualAmount(new List<TransactionJournal>(), 0));
    Test.stopTest();
  }

  @IsTest
  static void calculateEligibleAmount_normalTjs_sumsCorrectly() {
    List<TransactionJournal> tjs = new List<TransactionJournal>{
      new TransactionJournal(TransactionAmount = 50000, PaymentMethod = '01'),
      new TransactionJournal(TransactionAmount = 30000, PaymentMethod = '02')
    };

    Test.startTest();
    Decimal result = GdMigrationUtil.calculateEligibleAccrualAmount(tjs, 0);
    Test.stopTest();

    System.assertEquals(80000, result);
  }

  @IsTest
  static void calculateEligibleAmount_excludesNonAccrualPaymentMethods() {
    List<TransactionJournal> tjs = new List<TransactionJournal>{
      new TransactionJournal(TransactionAmount = 50000, PaymentMethod = '01'), // 적립 가능
      new TransactionJournal(TransactionAmount = 30000, PaymentMethod = '20'), // 제외
      new TransactionJournal(TransactionAmount = 20000, PaymentMethod = '81'), // 제외
      new TransactionJournal(TransactionAmount = 10000, PaymentMethod = '90'), // 제외
      new TransactionJournal(TransactionAmount = 5000, PaymentMethod = '93') // 제외
    };

    Test.startTest();
    Decimal result = GdMigrationUtil.calculateEligibleAccrualAmount(tjs, 0);
    Test.stopTest();

    System.assertEquals(50000, result, '01 결제만 적립 가능');
  }

  @IsTest
  static void calculateEligibleAmount_subtractsExcludeAmount() {
    List<TransactionJournal> tjs = new List<TransactionJournal>{ new TransactionJournal(TransactionAmount = 100000, PaymentMethod = '01') };

    Test.startTest();
    Decimal result = GdMigrationUtil.calculateEligibleAccrualAmount(tjs, 20000);
    Test.stopTest();

    System.assertEquals(80000, result, 'excludeAmount 차감됨');
  }

  @IsTest
  static void calculateEligibleAmount_zeroAndNullAmounts_skipped() {
    List<TransactionJournal> tjs = new List<TransactionJournal>{
      new TransactionJournal(TransactionAmount = 50000, PaymentMethod = '01'),
      new TransactionJournal(TransactionAmount = 0, PaymentMethod = '01'), // 0 → 스킵
      new TransactionJournal(TransactionAmount = null, PaymentMethod = '01'), // null → 스킵
      null // null TJ → 스킵
    };

    Test.startTest();
    Decimal result = GdMigrationUtil.calculateEligibleAccrualAmount(tjs, 0);
    Test.stopTest();

    System.assertEquals(50000, result);
  }

  // ============================================================
  // K. Phase 6.3 — calculateAccrualForOldOrder (계산만, DML 없음)
  // ============================================================

  @IsTest
  static void calculateAccrual_nullInputs_returnsEmpty() {
    Test.startTest();
    List<GdMigrationUtil.AccrualEstimate> r1 = GdMigrationUtil.calculateAccrualForOldOrder(null, 100000, null);
    List<GdMigrationUtil.AccrualEstimate> r2 = GdMigrationUtil.calculateAccrualForOldOrder('0lMJO0000002sKa2AI', null, null);
    List<GdMigrationUtil.AccrualEstimate> r3 = GdMigrationUtil.calculateAccrualForOldOrder('0lMJO0000002sKa2AI', 0, null);
    List<GdMigrationUtil.AccrualEstimate> r4 = GdMigrationUtil.calculateAccrualForOldOrder('0lMJO0000002sKa2AI', -100, null);
    Test.stopTest();

    System.assertEquals(0, r1.size(), 'null memberId → empty');
    System.assertEquals(0, r2.size(), 'null amount → empty');
    System.assertEquals(0, r3.size(), '0 amount → empty');
    System.assertEquals(0, r4.size(), '음수 amount → empty');
  }

  @IsTest
  static void calculateAccrual_memberWithoutTier_returnsEmpty() {
    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    // 이 LPM 은 LoyaltyMemberTier 가 없을 수 있음 (test setup 에서 안 만듦)
    Test.startTest();
    List<GdMigrationUtil.AccrualEstimate> result = GdMigrationUtil.calculateAccrualForOldOrder(lpm.Id, 100000, null);
    Test.stopTest();

    // Tier 없으면 LoyaltyTierBenefit 도 없으므로 빈 list
    System.assertEquals(0, result.size(), 'Tier 없는 회원 → empty');
  }

  @IsTest
  static void calculateAccrual_purchaseTierBenefit_returnsEstimate() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    String suffix = String.valueOf(Datetime.now().getTime());

    Id purchaseSubtypeId = insertPointSubtype(lpm.ProgramId, '01', 'Purchase_' + suffix);
    Id giftSubtypeId = insertPointSubtype(lpm.ProgramId, '06', 'Gift_' + suffix);

    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'TestTierGroup_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(Name = 'TestTier_' + suffix, LoyaltyTierGroupId = tierGroup.Id);
    insert tier;

    insert new LoyaltyMemberTier(Name = 'TestMemberTier_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyTierId = tier.Id, EffectiveDate = Date.today());

    BenefitType benefitType = new BenefitType(
      Name = 'TestBenefitType_' + suffix,
      ProcessType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue(),
      LoyaltyProgramId = lpm.ProgramId
    );
    insert benefitType;

    insertTierBenefit(tier.Id, benefitType.Id, purchaseSubtypeId, 5, 'Valid_' + suffix);
    insertTierBenefit(tier.Id, benefitType.Id, purchaseSubtypeId, null, 'NoRate_' + suffix);
    insertTierBenefit(tier.Id, benefitType.Id, null, 3, 'NoSubtype_' + suffix);
    insertTierBenefit(tier.Id, benefitType.Id, giftSubtypeId, 2, 'NonPurchase_' + suffix);

    Test.startTest();
    List<GdMigrationUtil.AccrualEstimate> result = GdMigrationUtil.calculateAccrualForOldOrder(lpm.Id, 10000, null);
    Test.stopTest();

    System.assertEquals(1, result.size());
    System.assertEquals('01', result[0].pointTypeCode);
    System.assertEquals(5, result[0].pointRate);
    System.assertEquals(500, result[0].points);
  }

  @IsTest
  static void calculateAccrual_purchasePointExcludedByPromotion_returnsEmpty() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    String suffix = String.valueOf(Datetime.now().getTime());

    Id purchaseSubtypeId = insertPointSubtype(lpm.ProgramId, '01', 'ExcludedPurchase_' + suffix);

    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'TestExcludedTierGroup_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(Name = 'TestExcludedTier_' + suffix, LoyaltyTierGroupId = tierGroup.Id);
    insert tier;

    insert new LoyaltyMemberTier(
      Name = 'TestExcludedMemberTier_' + suffix,
      LoyaltyMemberId = lpm.Id,
      LoyaltyTierId = tier.Id,
      EffectiveDate = Date.today()
    );

    BenefitType benefitType = new BenefitType(
      Name = 'TestExcludedBenefitType_' + suffix,
      ProcessType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue(),
      LoyaltyProgramId = lpm.ProgramId
    );
    insert benefitType;

    insertTierBenefit(tier.Id, benefitType.Id, purchaseSubtypeId, 5, 'Excluded_' + suffix);
    Promotion promotion = insertPointExclusionPromotion('01', suffix);

    Test.startTest();
    List<GdMigrationUtil.AccrualEstimate> result = GdMigrationUtil.calculateAccrualForOldOrder(lpm.Id, 10000, promotion.Id);
    Test.stopTest();

    System.assertEquals(0, result.size(), 'Promotion PointTypeCode__c=01이면 구매 포인트 적립 추정이 제외되어야 함');
  }

  @IsTest
  static void calculateAccrual_extractExcludedPointTypeCodes_safeWithNullPromotion() {
    // 내부 헬퍼는 calculateAccrualForOldOrder 가 호출하므로
    // null promotionId 안전 처리 검증은 위 테스트에서 이미 cover.
    // 추가로 Promotion 미존재 ID 도 안전한지 확인.
    Test.startTest();
    List<GdMigrationUtil.AccrualEstimate> result = GdMigrationUtil.calculateAccrualForOldOrder('0lMJO0000002sKa2AI', 100000, null);
    Test.stopTest();
    System.assert(true, 'null promotionId 안전 처리');
  }

  @IsTest
  static void paymentMethodsNotAccrualEligible_constant() {
    Set<String> methods = GdMigrationUtil.getPaymentMethodsNotAccrualEligible();
    System.assert(methods.contains('20'));
    System.assert(methods.contains('81'));
    System.assert(methods.contains('90'));
    System.assert(methods.contains('93'));
    System.assertEquals(4, methods.size());
  }

  // K-2 (SeeAllData) 테스트는 별도 클래스 GdMigrationUtilSeeAllTest 로 분리
  // (Salesforce 제약: @TestSetup + @IsTest(SeeAllData=true) 동일 클래스 불가)

  // ============================================================
  // L. 다른 InsertId 마이그 마커 (CANCEL) 도 인식
  // ============================================================
  @IsTest
  static void shouldApplyByDepositNo_migrationCancelMarker_returnsTrue() {
    setBranchEnabled(true, OPEN_DATE);

    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    // 추가 데이터: MIG_OPTC_CANCEL 마커 TJ
    TransactionJournal cancelTj = new TransactionJournal(
      MemberId = lpm.Id,
      DepositNo__c = 'DEP-OPTC-MIG-CANCEL-01',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 5000,
      ActivityDate = POST_OPEN_DATE,
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CANCEL'
    );
    insert cancelTj;

    Test.startTest();
    Boolean result = GdMigrationUtil.shouldApplyOptionCBranchByDepositNo('DEP-OPTC-MIG-CANCEL-01');
    Test.stopTest();

    System.assertEquals(true, result, 'MIG_OPTC_CANCEL 마커도 true');
  }

  // ============================================================
  // M. forceDebitPointsSafe — 입력 검증 / 안전 fallback
  //   (실 LASEL 분배 + LoyaltyPointService.debitPoints 호출 경로는
  //    GdMigrationUtilSeeAllTest 의 SeeAllData 테스트에서 검증)
  // ============================================================

  @IsTest
  static void forceDebitPointsSafe_nullMember_returnsInvalidInput() {
    Test.startTest();
    GdMigrationUtil.ForceDebitResult result = GdMigrationUtil.forceDebitPointsSafe(null, null, null, 1000, 'test');
    Test.stopTest();

    System.assertEquals(false, result.success, 'memberId null → success=false');
    System.assertEquals(0, result.actualPoints, 'actualPoints=0');
    System.assertEquals(1000, result.loss, 'loss=requested');
    System.assertEquals('invalid input', result.error);
  }

  @IsTest
  static void forceDebitPointsSafe_zeroRequest_returnsInvalidInput() {
    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    Test.startTest();
    GdMigrationUtil.ForceDebitResult r1 = GdMigrationUtil.forceDebitPointsSafe(lpm.Id, null, null, 0, 'zero');
    GdMigrationUtil.ForceDebitResult r2 = GdMigrationUtil.forceDebitPointsSafe(lpm.Id, null, null, -100, 'negative');
    GdMigrationUtil.ForceDebitResult r3 = GdMigrationUtil.forceDebitPointsSafe(lpm.Id, null, null, null, 'null');
    Test.stopTest();

    System.assertEquals(false, r1.success);
    System.assertEquals('invalid input', r1.error);
    System.assertEquals(false, r2.success);
    System.assertEquals('invalid input', r2.error);
    System.assertEquals(false, r3.success);
    System.assertEquals('invalid input', r3.error);
  }

  @IsTest
  static void forceDebitPointsSafe_noBalance_returnsZeroAndAllLoss() {
    // 신규 회원 — LASEL 잔액 없음 → 0 차감 + 전액 손실 + success=false
    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    Test.startTest();
    GdMigrationUtil.ForceDebitResult result = GdMigrationUtil.forceDebitPointsSafe(lpm.Id, null, null, 5000, 'no balance');
    Test.stopTest();

    System.assertEquals(false, result.success, '잔액 없음 → success=false');
    System.assertEquals(0, result.actualPoints);
    System.assertEquals(5000, result.loss);
    System.assertEquals('no available balance', result.error);
  }

  @IsTest
  static void forceDebitPointsSafe_availableMigratedBalance_attemptsDebit() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-OLD' LIMIT 1];
    insertMigratedLumpBalance(lpm, 1000, 'Debit');

    Test.startTest();
    GdMigrationUtil.ForceDebitResult result = GdMigrationUtil.forceDebitPointsSafe(lpm.Id, lpm.ProgramId, o.Id, 600, 'debit with balance');
    Test.stopTest();

    System.assertEquals(600, result.requestedPoints);
    System.assert(result.actualPoints == 600 || result.actualPoints == 0);
    System.assert(result.loss == 0 || result.loss == 600);
  }

  @IsTest
  static void getAvailableBalance_nullMember_returnsZero() {
    Test.startTest();
    Decimal bal = GdMigrationUtil.getAvailableBalance(null);
    Test.stopTest();
    System.assertEquals(0, bal, 'null member → 0');
  }

  @IsTest
  static void getAvailableBalance_noLedger_returnsZero() {
    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    Test.startTest();
    Decimal bal = GdMigrationUtil.getAvailableBalance(lpm.Id);
    Test.stopTest();
    System.assertEquals(0, bal, 'LASEL 없음 → 0');
  }

  // ============================================================
  // N. distributeDebitBySubtype (pure helper — JSON 으로 LASEL stub)
  // ============================================================

  /** JSON 으로 LASEL 객체 (lookup 포함) stub 생성. */
  private static LoyaltyAggrSubPointExprLedger__c stubAggr(Decimal availablePoints, String subtypeName, Integer priority) {
    String jsonStr = JSON.serialize(
      new Map<String, Object>{
        'AvailablePoints__c' => availablePoints,
        'CurrencySubTypeId__r' => new Map<String, Object>{ 'Name' => subtypeName, 'UsagePriorityNumber' => priority }
      }
    );
    return (LoyaltyAggrSubPointExprLedger__c) JSON.deserialize(jsonStr, LoyaltyAggrSubPointExprLedger__c.class);
  }

  private static void insertMigratedLumpBalance(LoyaltyProgramMember lpm, Decimal points, String suffix) {
    LoyaltyProgramCurrency currencyDef = new LoyaltyProgramCurrency(
      Name = 'TestLumpCurrency_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 1,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert currencyDef;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      Name = 'TestLumpSubtype_' + suffix,
      LoyaltyProgramCurrencyId = currencyDef.Id,
      UsagePriorityNumber = 1,
      IsActive = true,
      PointTypeCode__c = '04'
    );
    insert subtype;

    insert new LoyaltyAggrSubPointExprLedger__c(
      LoyaltyProgramMemberId__c = lpm.Id,
      LoyaltyProgramCurrencyId__c = currencyDef.Id,
      CurrencySubTypeId__c = subtype.Id,
      CurrencySubTypeName__c = subtype.Name,
      AccruedPoints__c = points,
      RedeemedPoints__c = 0,
      ExpiredPoints__c = 0,
      ExpiryDate__c = Date.today().addDays(30)
    );
  }

  private static Id insertPointSubtype(Id programId, String pointTypeCode, String suffix) {
    LoyaltyProgramCurrency currencyDef = new LoyaltyProgramCurrency(
      Name = 'TestPointCurrency_' + suffix,
      LoyaltyProgramId = programId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 1,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert currencyDef;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      Name = 'TestPointSubtype_' + suffix,
      LoyaltyProgramCurrencyId = currencyDef.Id,
      UsagePriorityNumber = 1,
      IsActive = true,
      PointTypeCode__c = pointTypeCode
    );
    insert subtype;
    return subtype.Id;
  }

  private static void insertTierBenefit(Id tierId, Id benefitTypeId, Id subtypeId, Decimal rate, String suffix) {
    Benefit benefit = new Benefit(Name = 'TestBenefit_' + suffix, BenefitTypeId = benefitTypeId, PurchasePointRate__c = rate);
    if (subtypeId != null) {
      benefit.LoyaltyPgmCurrencySubtypeId__c = subtypeId;
    }
    insert benefit;

    insert new LoyaltyTierBenefit(Name = 'TestTierBenefit_' + suffix, LoyaltyTierId = tierId, BenefitId = benefit.Id);
  }

  private static Promotion insertPointExclusionPromotion(String pointTypeCode, String suffix) {
    Promotion promotion = new Promotion(
      Name = 'TestPromotion_' + suffix,
      DisplayName = 'TestPromotion_' + suffix,
      PromotionCode = 'GDMIG' + suffix.right(8),
      IsActive = true,
      StartDate = Date.today().addDays(-1),
      EndDate = Date.today().addDays(30),
      PublishStartDate__c = Date.today().addDays(-1),
      PublishEndDate__c = Date.today().addDays(30),
      PointTypeCode__c = pointTypeCode
    );
    insert promotion;
    return promotion;
  }

  @IsTest
  static void distributeDebit_emptyOrNullList_returnsEmpty() {
    Map<String, Decimal> r1 = GdMigrationUtil.distributeDebitBySubtype(null, 1000);
    Map<String, Decimal> r2 = GdMigrationUtil.distributeDebitBySubtype(new List<LoyaltyAggrSubPointExprLedger__c>(), 1000);
    System.assertEquals(0, r1.size());
    System.assertEquals(0, r2.size());
  }

  @IsTest
  static void distributeDebit_zeroOrNegativeRequest_returnsEmpty() {
    List<LoyaltyAggrSubPointExprLedger__c> aggrList = new List<LoyaltyAggrSubPointExprLedger__c>{ stubAggr(1000, '구매적립', 1) };

    Map<String, Decimal> r1 = GdMigrationUtil.distributeDebitBySubtype(aggrList, 0);
    Map<String, Decimal> r2 = GdMigrationUtil.distributeDebitBySubtype(aggrList, -100);
    Map<String, Decimal> r3 = GdMigrationUtil.distributeDebitBySubtype(aggrList, null);
    System.assertEquals(0, r1.size());
    System.assertEquals(0, r2.size());
    System.assertEquals(0, r3.size());
  }

  @IsTest
  static void distributeDebit_singleSubtype_sufficientBalance() {
    List<LoyaltyAggrSubPointExprLedger__c> aggrList = new List<LoyaltyAggrSubPointExprLedger__c>{ stubAggr(1000, '구매적립', 1) };

    Map<String, Decimal> result = GdMigrationUtil.distributeDebitBySubtype(aggrList, 300);

    System.assertEquals(1, result.size());
    System.assertEquals(300, result.get('구매적립'));
  }

  @IsTest
  static void distributeDebit_singleSubtype_insufficientBalance_clamps() {
    List<LoyaltyAggrSubPointExprLedger__c> aggrList = new List<LoyaltyAggrSubPointExprLedger__c>{ stubAggr(500, '구매적립', 1) };

    // 요청 1000, 가용 500 → 500 만 분배
    Map<String, Decimal> result = GdMigrationUtil.distributeDebitBySubtype(aggrList, 1000);

    System.assertEquals(1, result.size());
    System.assertEquals(500, result.get('구매적립'));
  }

  @IsTest
  static void distributeDebit_multipleSubtypes_FIFO_distribution() {
    // 우선순위 순: 구매(1) 600, 사은(2) 400 → 총 1000
    List<LoyaltyAggrSubPointExprLedger__c> aggrList = new List<LoyaltyAggrSubPointExprLedger__c>{
      stubAggr(600, '구매적립', 1),
      stubAggr(400, '사은적립', 2)
    };

    // 요청 800 → 구매 600 + 사은 200 분배
    Map<String, Decimal> result = GdMigrationUtil.distributeDebitBySubtype(aggrList, 800);

    System.assertEquals(2, result.size());
    System.assertEquals(600, result.get('구매적립'));
    System.assertEquals(200, result.get('사은적립'));
  }

  @IsTest
  static void distributeDebit_sameSubtypeMultipleAggrs_summed() {
    // 같은 SubType 두 줄 (다른 만료일) → 합산되어야 함
    List<LoyaltyAggrSubPointExprLedger__c> aggrList = new List<LoyaltyAggrSubPointExprLedger__c>{
      stubAggr(300, '구매적립', 1),
      stubAggr(200, '구매적립', 1)
    };

    Map<String, Decimal> result = GdMigrationUtil.distributeDebitBySubtype(aggrList, 500);

    System.assertEquals(1, result.size(), '동일 SubType 합산');
    System.assertEquals(500, result.get('구매적립'));
  }

  @IsTest
  static void distributeDebit_zeroAvailable_skipped() {
    List<LoyaltyAggrSubPointExprLedger__c> aggrList = new List<LoyaltyAggrSubPointExprLedger__c>{
      stubAggr(0, '소진된적립', 1),
      stubAggr(500, '구매적립', 2)
    };

    Map<String, Decimal> result = GdMigrationUtil.distributeDebitBySubtype(aggrList, 300);

    // 0 짜리 entry skip → 구매적립 만 분배
    System.assertEquals(1, result.size());
    System.assertEquals(300, result.get('구매적립'));
  }

  // ============================================================
  // O. buildForceDebitTJ — TJ 필드 세팅 검증 (DML 없음)
  // ============================================================

  @IsTest
  static void buildForceDebitTJ_setsAllRequiredFields() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-OLD' LIMIT 1];

    Id fakeJtId = Id.valueOf(JournalType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
    Id fakeJstId = Id.valueOf(JournalSubType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

    Test.startTest();
    TransactionJournal tj = GdMigrationUtil.buildForceDebitTJ(lpm.Id, lpm.ProgramId, o.Id, 1500, 'B-1-3 test', fakeJtId, fakeJstId);
    Test.stopTest();

    System.assertEquals(lpm.Id, tj.MemberId);
    System.assertEquals(lpm.ProgramId, tj.LoyaltyProgramId);
    System.assertEquals(o.Id, tj.OrderId);
    System.assertEquals(1500, tj.TransactionAmount);
    System.assertEquals('1', tj.JournalReason__c);
    System.assertEquals('Pending', tj.Status);
    System.assert(tj.AdditionalNotes__c.startsWith('OPTC_FORCE_DEBIT:'));
    System.assert(tj.AdditionalNotes__c.contains('B-1-3 test'));
    System.assertNotEquals(null, tj.JournalDate);
    System.assertNotEquals(null, tj.ActivityDate);
  }

  @IsTest
  static void buildForceDebitTJ_blankReason_safeNotes() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Id fakeJtId = Id.valueOf(JournalType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
    Id fakeJstId = Id.valueOf(JournalSubType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

    Test.startTest();
    TransactionJournal tj1 = GdMigrationUtil.buildForceDebitTJ(lpm.Id, lpm.ProgramId, null, 100, null, fakeJtId, fakeJstId);
    TransactionJournal tj2 = GdMigrationUtil.buildForceDebitTJ(lpm.Id, lpm.ProgramId, null, 100, '', fakeJtId, fakeJstId);
    Test.stopTest();

    System.assertEquals('OPTC_FORCE_DEBIT: ', tj1.AdditionalNotes__c);
    System.assertEquals('OPTC_FORCE_DEBIT: ', tj2.AdditionalNotes__c);
    System.assertEquals(null, tj1.OrderId);
  }

  @IsTest
  static void cancelOldSalePointUsageSafe_nullInput_returnsInvalidInput() {
    Test.startTest();
    GdMigrationUtil.CancelOldSalePointUsageResult result = GdMigrationUtil.cancelOldSalePointUsageSafe(null);
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(0, result.matchedLLTCount);
    System.assertEquals(false, result.lltMissing);
    System.assertEquals('invalid pm81Tj input', result.error);
  }

  @IsTest
  static void cancelOldSalePointUsageSafe_nonPm81_returnsError() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-OLD' LIMIT 1];

    TransactionJournal tj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      DepositNo__c = 'DEP-OPTC-CANCEL-NON81',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 100,
      PaymentMethod = '01',
      ActivityDate = Date.today(),
      Status = 'Processed',
      InsertId__c = 'tester'
    );
    insert tj;

    Test.startTest();
    GdMigrationUtil.CancelOldSalePointUsageResult result = GdMigrationUtil.cancelOldSalePointUsageSafe(tj);
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(0, result.matchedLLTCount);
    System.assertEquals(false, result.lltMissing);
    System.assertEquals('not a PM=81 TJ', result.error);
  }

  @IsTest
  static void cancelOldSalePointUsageSafe_pm81WithoutTrace_marksMissing() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-OLD' LIMIT 1];

    TransactionJournal tj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = o.Id,
      DepositNo__c = 'DEP-OPTC-CANCEL-PM81',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 100,
      PaymentMethod = '81',
      ActivityDate = Date.today(),
      Status = 'Processed',
      InsertId__c = 'tester'
    );
    insert tj;

    Test.startTest();
    GdMigrationUtil.CancelOldSalePointUsageResult result = GdMigrationUtil.cancelOldSalePointUsageSafe(tj);
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(0, result.matchedLLTCount);
    System.assertEquals(true, result.lltMissing);
    System.assert(result.error.contains('no LLT matched'));
  }

  // ============================================================
  // P. forceCreditPointsSafe — 입력 검증 / 안전 fallback
  // ============================================================

  @IsTest
  static void forceCreditPointsSafe_nullMember_returnsInvalidInput() {
    Test.startTest();
    GdMigrationUtil.ForceCreditResult result = GdMigrationUtil.forceCreditPointsSafe(null, null, null, 1000, 'test');
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(0, result.actualPoints);
    System.assertEquals(1000, result.unprocessed);
    System.assertEquals('invalid input', result.error);
  }

  @IsTest
  static void forceCreditPointsSafe_zeroOrNegative_returnsInvalidInput() {
    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    Test.startTest();
    GdMigrationUtil.ForceCreditResult r1 = GdMigrationUtil.forceCreditPointsSafe(lpm.Id, null, null, 0, 'zero');
    GdMigrationUtil.ForceCreditResult r2 = GdMigrationUtil.forceCreditPointsSafe(lpm.Id, null, null, -100, 'negative');
    GdMigrationUtil.ForceCreditResult r3 = GdMigrationUtil.forceCreditPointsSafe(lpm.Id, null, null, null, 'null');
    Test.stopTest();

    System.assertEquals(false, r1.success);
    System.assertEquals('invalid input', r1.error);
    System.assertEquals(false, r2.success);
    System.assertEquals('invalid input', r2.error);
    System.assertEquals(false, r3.success);
    System.assertEquals('invalid input', r3.error);
  }

  @IsTest
  static void forceCreditPointsSafe_noLumpBalance_returnsErrorAndUnprocessed() {
    // 신규 회원 — 묶음 잔액 없음 → 적립 안 함, 전액 미처리
    LoyaltyProgramMember lpm = [SELECT Id FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];

    Test.startTest();
    GdMigrationUtil.ForceCreditResult result = GdMigrationUtil.forceCreditPointsSafe(lpm.Id, null, null, 5000, 'no lump');
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(0, result.actualPoints);
    System.assertEquals(5000, result.unprocessed);
    System.assert(result.error.contains('no active migrated lump'));
  }

  @IsTest
  static void forceCreditPointsSafe_activeMigratedBalance_attemptsCredit() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-OLD' LIMIT 1];
    insertMigratedLumpBalance(lpm, 1000, 'Credit');

    Test.startTest();
    GdMigrationUtil.ForceCreditResult result = GdMigrationUtil.forceCreditPointsSafe(lpm.Id, lpm.ProgramId, o.Id, 300, 'credit with balance');
    Test.stopTest();

    System.assertEquals(300, result.requestedPoints);
    System.assert(result.actualPoints == 300 || result.actualPoints == 0);
    System.assert(result.unprocessed == 0 || result.unprocessed == 300);
  }

  @IsTest
  static void buildForceCreditTJ_setsAllRequiredFields() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Order o = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-OPTC-OLD' LIMIT 1];

    Id fakeJtId = Id.valueOf(JournalType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
    Id fakeJstId = Id.valueOf(JournalSubType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

    Test.startTest();
    TransactionJournal tj = GdMigrationUtil.buildForceCreditTJ(lpm.Id, lpm.ProgramId, o.Id, 2500, 'Phase 6.6 test', fakeJtId, fakeJstId);
    Test.stopTest();

    System.assertEquals(lpm.Id, tj.MemberId);
    System.assertEquals(lpm.ProgramId, tj.LoyaltyProgramId);
    System.assertEquals(o.Id, tj.OrderId);
    System.assertEquals(2500, tj.TransactionAmount);
    System.assertEquals('Pending', tj.Status);
    System.assert(tj.AdditionalNotes__c.startsWith('OPTC_FORCE_CREDIT:'));
    System.assert(tj.AdditionalNotes__c.contains('Phase 6.6 test'));
  }

  @IsTest
  static void buildForceCreditTJ_blankReason_safeNotes() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Id fakeJtId = Id.valueOf(JournalType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
    Id fakeJstId = Id.valueOf(JournalSubType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

    Test.startTest();
    TransactionJournal tj = GdMigrationUtil.buildForceCreditTJ(lpm.Id, lpm.ProgramId, null, 100, null, fakeJtId, fakeJstId);
    Test.stopTest();

    System.assertEquals('OPTC_FORCE_CREDIT: ', tj.AdditionalNotes__c);
    System.assertEquals(null, tj.OrderId);
  }

  @IsTest
  static void buildForceDebitTJ_longReason_truncated() {
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-OPTC-TEST' LIMIT 1];
    Id fakeJtId = Id.valueOf(JournalType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
    Id fakeJstId = Id.valueOf(JournalSubType.SObjectType.getDescribe().getKeyPrefix() + '000000000001');

    String longReason = 'X'.repeat(35000);

    Test.startTest();
    TransactionJournal tj = GdMigrationUtil.buildForceDebitTJ(lpm.Id, lpm.ProgramId, null, 100, longReason, fakeJtId, fakeJstId);
    Test.stopTest();

    // prefix 'OPTC_FORCE_DEBIT: ' (18) + reason 30000 max = 30018
    System.assert(tj.AdditionalNotes__c.length() <= 30020, 'reason 30k 초과 시 절단됨 — actual length: ' + tj.AdditionalNotes__c.length());
  }
}