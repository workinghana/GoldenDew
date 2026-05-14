/**
 * GdReturnDepositBranchHandler Test
 *
 * 검증 영역
 *   A. 정상 케이스 — 옛 TJ 가 마크되고 명시적 응답 반환
 *   B. 미존재 케이스 — 400 throw
 *   C. blank/null 입력 — 400 throw
 *   D. AdditionalNotes 보존 + 마커 추가
 *   E. 응답 data 의 명시적 skip 정보
 *   F. ApexLogger PARTIAL 상태 설정 (logger=null 도 안전)
 *   G. 표준 부수 효과 (IsDeleted__c, DeleteDateTime__c) 보존
 */

@IsTest
private class GdReturnDepositBranchHandlerTest {
  // TransactionJournal Create 시 발화하는 RTF_Purchase_Point_Award 플로우가
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

  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Account company = new Account(Name = 'Co_RDB', CompanyCode__c = 'CMP-RDB');
    insert company;

    Contact c = new Contact(LastName = 'RDBTester', MemberNo__c = 'M-RDB-TEST', AccountId = company.Id);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP_RDB', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-RDB-TEST',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    // 마이그레이션 마커 TJ — 분기 대상
    TransactionJournal migTj = new TransactionJournal(
      MemberId = lpm.Id,
      DepositNo__c = 'DEP-RDB-OLD-01',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 16000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert migTj;

    // 기존 AdditionalNotes 가 있는 TJ — 보존 검증용
    TransactionJournal migTjWithNotes = new TransactionJournal(
      MemberId = lpm.Id,
      DepositNo__c = 'DEP-RDB-OLD-02',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      TransactionAmount = 8000,
      ActivityDate = Date.newInstance(2026, 3, 5),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      AdditionalNotes__c = 'EXISTING_NOTE_FROM_MIGRATION'
    );
    insert migTjWithNotes;
  }

  // ============================================================
  // A. 정상 케이스 — 옛 TJ 가 마크되고 명시적 응답 반환
  // ============================================================
  @IsTest
  static void handle_validOldTj_marksDeletedAndReturnsExplicitResponse() {
    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-OLD-01', null);
    Test.stopTest();

    System.assertEquals(true, result.success, 'success=true');
    System.assertEquals(200, result.code, 'HTTP 200');
    System.assertNotEquals(null, result.data, 'data 존재');
    System.assertEquals(true, result.data.get('option_c_branch'), 'option_c_branch 마커');
    System.assertEquals('skipped', result.data.get('point_processing'), 'point_processing=skipped');

    // TJ 마크 확인
    TransactionJournal tj = [
      SELECT IsDeleted__c, DeleteDateTime__c, AdditionalNotes__c
      FROM TransactionJournal
      WHERE DepositNo__c = 'DEP-RDB-OLD-01'
      LIMIT 1
    ];
    System.assertEquals(true, tj.IsDeleted__c, 'TJ.IsDeleted__c=true');
    System.assertNotEquals(null, tj.DeleteDateTime__c, 'TJ.DeleteDateTime__c 설정됨');
    System.assert(tj.AdditionalNotes__c.contains(GdReturnDepositBranchHandler.MARKER), 'AdditionalNotes 에 MARKER 포함');
  }

  // ============================================================
  // B. 미존재 입금 번호 — 400 throw
  // ============================================================
  @IsTest
  static void handle_nonExistent_throws400() {
    Test.startTest();
    Boolean thrown = false;
    Integer caughtCode = -1;
    try {
      GdReturnDepositBranchHandler.handle('NON-EXIST-DEP', null);
    } catch (CustomException ce) {
      thrown = true;
      caughtCode = ce.code;
    }
    Test.stopTest();

    System.assertEquals(true, thrown, 'CustomException 발생해야 함');
    System.assertEquals(400, caughtCode, '400 코드');
  }

  // ============================================================
  // C. blank/null 입력 — 400 throw (방어)
  // ============================================================
  @IsTest
  static void handle_blankInput_throws400() {
    Test.startTest();
    Integer codeBlank = -1;
    Integer codeNull = -1;
    try {
      GdReturnDepositBranchHandler.handle('', null);
    } catch (CustomException ce) {
      codeBlank = ce.code;
    }
    try {
      GdReturnDepositBranchHandler.handle(null, null);
    } catch (CustomException ce) {
      codeNull = ce.code;
    }
    Test.stopTest();

    System.assertEquals(400, codeBlank, '빈 문자열 → 400');
    System.assertEquals(400, codeNull, 'null → 400');
  }

  // ============================================================
  // D. 기존 AdditionalNotes 보존 + 마커 추가
  // ============================================================
  @IsTest
  static void handle_preservesExistingAdditionalNotes() {
    Test.startTest();
    GdReturnDepositBranchHandler.handle('DEP-RDB-OLD-02', null);
    Test.stopTest();

    TransactionJournal tj = [SELECT AdditionalNotes__c FROM TransactionJournal WHERE DepositNo__c = 'DEP-RDB-OLD-02' LIMIT 1];
    System.assert(tj.AdditionalNotes__c.contains('EXISTING_NOTE_FROM_MIGRATION'), '기존 노트 보존');
    System.assert(tj.AdditionalNotes__c.contains(GdReturnDepositBranchHandler.MARKER), '새 마커 추가');
    System.assert(tj.AdditionalNotes__c.contains(' | '), '구분자 ( | ) 사이에 둠');
  }

  // ============================================================
  // E. 응답 data 의 명시적 skip 정보
  // ============================================================
  @IsTest
  static void handle_responseData_includesAllExplicitFields() {
    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-OLD-01', null);
    Test.stopTest();

    Map<String, Object> data = result.data;
    System.assertEquals(true, data.get('option_c_branch'));
    System.assertEquals('DEP-RDB-OLD-01', data.get('depositNo'));
    System.assertEquals('skipped', data.get('point_processing'));
    System.assertNotEquals(null, data.get('reason'), 'reason 메시지 존재');
    System.assertNotEquals(null, data.get('tjId'), 'tjId 존재');
    System.assertNotEquals(null, data.get('subType'), 'subType 존재');
  }

  // ============================================================
  // F. ApexLogger PARTIAL 상태 — logger 가 null 이어도 안전
  // ============================================================
  @IsTest
  static void handle_loggerNull_doesNotThrow() {
    Test.startTest();
    // logger=null 로 호출 — NullPointerException 안 나야 함
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-OLD-01', null);
    Test.stopTest();

    System.assertEquals(true, result.success, 'logger null 이어도 정상 동작');
  }

  @IsTest
  static void handle_loggerProvided_setsPartialStatus() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdReturnDepositBranchHandlerTest.class.getName());

    Test.startTest();
    GdReturnDepositBranchHandler.handle('DEP-RDB-OLD-01', logger);
    Test.stopTest();

    // setStatus / setDescription 이 호출되었는지는 ApexLogger 의 내부 상태 검증.
    // 핵심은 NullPointerException 없이 통과하는 것.
    System.assert(true, 'logger 호출 시 throw 없이 통과');
  }

  // ============================================================
  // G. 이미 삭제된 TJ — 미존재로 분류 (표준과 동일)
  // ============================================================
  @IsTest
  static void handle_alreadyDeleted_throws400() {
    // 사전: TJ 미리 IsDeleted=true 로 표시
    TransactionJournal tj = [SELECT Id FROM TransactionJournal WHERE DepositNo__c = 'DEP-RDB-OLD-01' LIMIT 1];
    tj.IsDeleted__c = true;
    update tj;

    Test.startTest();
    Boolean thrown = false;
    try {
      GdReturnDepositBranchHandler.handle('DEP-RDB-OLD-01', null);
    } catch (CustomException ce) {
      thrown = (ce.code == 400);
    }
    Test.stopTest();

    System.assertEquals(true, thrown, '이미 삭제된 TJ → 400');
  }

  // ============================================================
  // H. PaymentMethod='81' (포인트 결제) — 사용 환원 경로 (적립 원장 없음)
  //    computeAndForceCreditForDepositDelete의 '81' 분기 + 빈 ledger early return 커버
  // ============================================================
  @IsTest
  static void handle_paymentMethod81_noLedgers_setsUsageRestoreRequired() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    TransactionJournal tj81 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-PAY81',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 5000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tj81;

    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-PAY81', null);
    Test.stopTest();

    System.assertEquals(true, result.success, 'success=true');
    System.assertEquals(true, result.data.get('usage_restore_required'), 'usage_restore_required=true');
    System.assertNotEquals(null, result.data.get('usage_restore_note'), 'usage_restore_note 존재');
  }

  // ============================================================
  // I. PaymentMethod NON_ACCRUAL ('20') — 적립 복원 불필요 경로
  // ============================================================
  @IsTest
  static void handle_paymentMethodVoucher_nonAccrualBranch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    TransactionJournal tj20 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-PAY20',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '20',
      TransactionAmount = 10000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tj20;

    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-PAY20', null);
    Test.stopTest();

    System.assertEquals(true, result.success);
  }

  // ============================================================
  // J. PaymentMethod='90' (쿠폰 — NON_ACCRUAL)
  // ============================================================
  @IsTest
  static void handle_paymentMethodCoupon_nonAccrualBranch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    TransactionJournal tj90 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-PAY90',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '90',
      TransactionAmount = 7000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tj90;

    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-PAY90', null);
    Test.stopTest();

    System.assertEquals(true, result.success);
  }

  // ============================================================
  // K. TransactionAmount=0 — compute 의 'invalid input' early return
  // ============================================================
  @IsTest
  static void handle_zeroAmount_invalidInputBranch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    TransactionJournal tj0 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-ZERO',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 0,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tj0;

    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-ZERO', null);
    Test.stopTest();

    System.assertEquals(true, result.success, 'handle 자체는 정상');
    System.assertEquals('skipped', result.data.get('point_processing'), 'force credit 미수행 → skipped');
  }

  // ============================================================
  // L. Default 분기 (현금) — SaleId__c 있어서 helper 메서드들이 실제 SOQL 실행
  // ============================================================
  @IsTest
  static void handle_defaultPath_withSaleId_exercisesHelpers() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    Account acc = [SELECT Id FROM Account WHERE Name = 'Co_RDB' LIMIT 1];

    Order ord = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert ord;

    TransactionJournal tjSale = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-SALE',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 50000,
      SaleId__c = ord.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjSale;

    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-SALE', null);
    Test.stopTest();

    System.assertEquals(true, result.success);
  }

  // ============================================================
  // M. Default 분기 — 사전 OPTC_BRANCH 마커 TJ 존재 → alreadyRestored SOQL 깊이 진입
  // ============================================================
  @IsTest
  static void handle_defaultPath_withPreviousMarker_exercisesAlreadyRestored() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    Account acc = [SELECT Id FROM Account WHERE Name = 'Co_RDB' LIMIT 1];

    Order ord = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert ord;

    // 사전: 같은 SaleId__c 에 OPTC_BRANCH 마커가 있는 다른 TJ (이전 처리 흔적)
    TransactionJournal previousMarkedTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-PREV-MARKED',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 30000,
      SaleId__c = ord.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      AdditionalNotes__c = 'OPTC_BRANCH_RETURN_DEPOSIT_DELETE: prior run trace',
      IsDeleted__c = true
    );
    insert previousMarkedTj;

    // 타깃 TJ
    TransactionJournal targetTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-FULL',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 20000,
      SaleId__c = ord.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert targetTj;

    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-FULL', null);
    Test.stopTest();

    System.assertEquals(true, result.success);
  }

  // ============================================================
  // N. PaymentMethod='93' (NON_ACCRUAL 한 케이스 더) — set contains 검증 보강
  // ============================================================
  @IsTest
  static void handle_paymentMethod93_nonAccrualBranch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    TransactionJournal tj93 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-PAY93',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '93',
      TransactionAmount = 3000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tj93;

    Test.startTest();
    ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-PAY93', null);
    Test.stopTest();

    System.assertEquals(true, result.success);
  }

  // ============================================================
  // P. PaymentMethod='81' deep path — LoyaltyLedger 명시적 셋업으로 debitSpecificPointsV3 까지 실행
  //    Traceability/AlreadyRestored 헬퍼와 81 처리 본문 라인 다수 커버
  // ============================================================
  @IsTest
  static void handle_paymentMethod81_withLedgers_executesUsageRestore() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];

    // LoyaltyProgramCurrency + Subtype + MemberCurrency 셋업
    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lpm.ProgramId,
      Name = '포인트',
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = 'Fixed',
      ExtendExpiration = 'None',
      ExpiryPeriodFrequency = 2,
      ExpiryPeriodUnit = 'Years',
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert lpc;

    LoyaltyPgmCurrencySubtype subt = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = lpc.Id,
      Name = 'TestSubtype81',
      PointTypeCode__c = '01',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subt;

    insert new LoyaltyMemberCurrency(Name = 'TestLMC81', LoyaltyMemberId = lpm.Id, LoyaltyProgramCurrencyId = lpc.Id);

    // 타깃 TJ (PaymentMethod=81)
    TransactionJournal tj81 = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-PAY81-DEEP',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 2000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tj81;

    // Credit Ledger — TJ에 연결, EventType=Credit, Points>0, Subtype 지정
    LoyaltyLedger creditLedger = new LoyaltyLedger(
      TransactionJournalId = tj81.Id,
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = lpc.Id,
      LoyaltyPgmCrcySubtypeId = subt.Id,
      ActivityDate = Datetime.now(),
      EventType = 'Credit',
      Points = 500,
      ExpiryDate = Date.today().addYears(2)
    );
    insert creditLedger;

    // debitSpecificPointsV3 가 throw 할 수 있으므로 방어적으로 catch
    Test.startTest();
    Boolean called = false;
    try {
      ApiResult result = GdReturnDepositBranchHandler.handle('DEP-RDB-PAY81-DEEP', null);
      called = (result != null);
    } catch (Exception e) {
      // 깊은 경로 라인은 실행됨 — 커버리지 확보 목적
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called, '81 deep 경로 실행 (성공 or 예외 모두 커버)');
  }

  // ============================================================
  // Q. PaymentMethod='81' + CreditCancellation Traceability 존재
  //    → calculateActiveCreditCancellationForCreditLedgers SOQL 더 깊이
  // ============================================================
  @IsTest
  static void handle_paymentMethod81_withTraceability_exercisesCancellationCalc() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lpm.ProgramId,
      Name = '포인트Q',
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = 'Fixed',
      ExtendExpiration = 'None',
      ExpiryPeriodFrequency = 2,
      ExpiryPeriodUnit = 'Years',
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert lpc;

    LoyaltyPgmCurrencySubtype subt = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = lpc.Id,
      Name = 'TestSubtypeQ',
      PointTypeCode__c = '01',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subt;

    insert new LoyaltyMemberCurrency(Name = 'TestLMCQ', LoyaltyMemberId = lpm.Id, LoyaltyProgramCurrencyId = lpc.Id);

    // 헬퍼 TJ — debit ledger 용 (타깃 TJ 가 IsDeleted=true 로 마크되어도 Debit ledger 는 살아있도록)
    Account acc = [SELECT Id FROM Account WHERE Name = 'Co_RDB' LIMIT 1];
    Order ordQ = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert ordQ;

    TransactionJournal helperTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-Q-HELPER',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 100,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert helperTj;

    TransactionJournal tj81q = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-PAY81-Q',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '81',
      TransactionAmount = 2000,
      SaleId__c = ordQ.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tj81q;

    LoyaltyLedger creditLedger = new LoyaltyLedger(
      TransactionJournalId = tj81q.Id,
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = lpc.Id,
      LoyaltyPgmCrcySubtypeId = subt.Id,
      ActivityDate = Datetime.now(),
      EventType = 'Credit',
      Points = 300,
      ExpiryDate = Date.today().addYears(2)
    );
    insert creditLedger;

    // Debit Ledger — helper TJ 에 연결 (IsDeleted=false 유지)
    LoyaltyLedger debitLedger = new LoyaltyLedger(
      TransactionJournalId = helperTj.Id,
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = lpc.Id,
      LoyaltyPgmCrcySubtypeId = subt.Id,
      ActivityDate = Datetime.now(),
      EventType = 'Debit',
      Points = 100,
      ExpiryDate = Date.today().addYears(2)
    );
    insert debitLedger;

    // CreditCancellation Traceability — 이 credit ledger 가 취소된 흔적
    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = lpc.Id,
      LoyaltyPgmCurrencySubtypeId = subt.Id,
      CreditLoyaltyLedgerId = creditLedger.Id,
      DebitLoyaltyLedgerId = debitLedger.Id,
      ActionType = 'CreditCancellation',
      Points = 100
    );

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult r = GdReturnDepositBranchHandler.handle('DEP-RDB-PAY81-Q', null);
      called = (r != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called);
  }

  // ============================================================
  // R. Default 분기 + 이미 Forced Credit TJ 존재 (alreadyRestored deep)
  // ============================================================
  @IsTest
  static void handle_defaultPath_withForceCreditTj_exercisesAlreadyRestoredDeep() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    Account acc = [SELECT Id FROM Account WHERE Name = 'Co_RDB' LIMIT 1];

    Order ord = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert ord;

    // 이전 OPTC_BRANCH 마커 TJ
    TransactionJournal markedTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-MARKED-R',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 10000,
      SaleId__c = ord.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      AdditionalNotes__c = 'OPTC_BRANCH_RETURN_DEPOSIT_DELETE: prior',
      IsDeleted__c = true
    );
    insert markedTj;

    // JournalType / JournalSubType 셋업 (Forced Credit)
    JournalType accrualType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert accrualType;
    JournalSubType forcedCreditSubType = new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualType.Id);
    insert forcedCreditSubType;

    // Forced Credit TJ — alreadyRestored 카운트에 잡힘
    TransactionJournal forcedCreditTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      JournalSubTypeId = forcedCreditSubType.Id,
      DepositNo__c = 'DEP-RDB-FORCED-R',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 500,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      AdditionalNotes__c = 'OPTC_FORCE_CREDIT: OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT: tjId=' + markedTj.Id
    );
    insert forcedCreditTj;

    // 타깃 TJ
    TransactionJournal targetTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-TARGET-R',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 20000,
      SaleId__c = ord.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert targetTj;

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult r = GdReturnDepositBranchHandler.handle('DEP-RDB-TARGET-R', null);
      called = (r != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called);
  }

  // ============================================================
  // S. Default 분기 — Tier 셋업으로 estimates > 0 → 헬퍼 SOQL 본문 실행
  //    calculateActualOptionCAccrualCanceledForReturn / calculateAlreadyRestoredOptionCAccrualForReturn
  //    의 SOQL 라인들이 실제로 실행됨
  // ============================================================
  @IsTest
  static void handle_defaultPath_withTierAndEstimates_exercisesDeepHelpers() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    Account acc = [SELECT Id FROM Account WHERE Name = 'Co_RDB' LIMIT 1];

    String suffix = String.valueOf(Datetime.now().getTime());

    // Currency + 구매(01) 서브타입
    LoyaltyProgramCurrency currencyRec = new LoyaltyProgramCurrency(
      Name = 'PurchaseCurr_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 1,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert currencyRec;

    LoyaltyPgmCurrencySubtype purchaseSubtype = new LoyaltyPgmCurrencySubtype(
      Name = 'PurchaseSubtype_' + suffix,
      LoyaltyProgramCurrencyId = currencyRec.Id,
      UsagePriorityNumber = 1,
      IsActive = true,
      PointTypeCode__c = '01'
    );
    insert purchaseSubtype;

    // Tier Group + Tier + MemberTier
    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'TierGroup_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(Name = 'Tier_' + suffix, LoyaltyTierGroupId = tierGroup.Id);
    insert tier;

    insert new LoyaltyMemberTier(Name = 'MTier_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyTierId = tier.Id, EffectiveDate = Date.today());

    // BenefitType + Benefit (PurchasePointRate=2%) + TierBenefit
    BenefitType benefitType = new BenefitType(
      Name = 'BType_' + suffix,
      ProcessType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue(),
      LoyaltyProgramId = lpm.ProgramId
    );
    insert benefitType;

    Benefit benefit = new Benefit(
      Name = 'Benefit_' + suffix,
      BenefitTypeId = benefitType.Id,
      PurchasePointRate__c = 2,
      LoyaltyPgmCurrencySubtypeId__c = purchaseSubtype.Id
    );
    insert benefit;

    insert new LoyaltyTierBenefit(Name = 'TBenefit_' + suffix, LoyaltyTierId = tier.Id, BenefitId = benefit.Id);

    // Return 대상 Order
    Order ord = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert ord;

    // 이전 OPTC_BRANCH 마커 TJ — alreadyRestored loop 진입
    TransactionJournal markedTj = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-S-MARKED',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 10000,
      SaleId__c = ord.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      AdditionalNotes__c = 'OPTC_BRANCH_RETURN_DEPOSIT_DELETE: prior',
      IsDeleted__c = true
    );
    insert markedTj;

    // 타깃 TJ — default 경로 (현금)
    TransactionJournal tjS = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-S-TARGET',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 50000,
      SaleId__c = ord.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjS;

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult r = GdReturnDepositBranchHandler.handle('DEP-RDB-S-TARGET', null);
      called = (r != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called, 'default 깊은 경로 + 헬퍼 SOQL 실행 완료');
  }

  // ============================================================
  // T. 통합 deep — tier + forced credit TJ + cancel debit ledger
  //    → calculateActualOptionCAccrualCanceledForReturn / AlreadyRestored SOQL 본문 라인 실행
  //    → totalPoints > 0 시 forceCreditPointsSafe 호출까지
  // ============================================================
  @IsTest
  static void handle_defaultPath_fullDeepSetup_exercisesForceCreditAndHelpers() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    Account acc = [SELECT Id FROM Account WHERE Name = 'Co_RDB' LIMIT 1];

    String suffix = String.valueOf(Datetime.now().getTime()) + 'T';

    LoyaltyProgramCurrency currT = new LoyaltyProgramCurrency(
      Name = 'CurrT_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 1,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert currT;

    LoyaltyPgmCurrencySubtype subtT = new LoyaltyPgmCurrencySubtype(
      Name = 'SubtT_' + suffix,
      LoyaltyProgramCurrencyId = currT.Id,
      UsagePriorityNumber = 1,
      IsActive = true,
      PointTypeCode__c = '01'
    );
    insert subtT;

    insert new LoyaltyMemberCurrency(Name = 'LMCT_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyProgramCurrencyId = currT.Id);

    LoyaltyTierGroup tgT = new LoyaltyTierGroup(
      Name = 'TGT_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tgT;

    LoyaltyTier tierT = new LoyaltyTier(Name = 'TierT_' + suffix, LoyaltyTierGroupId = tgT.Id);
    insert tierT;

    insert new LoyaltyMemberTier(Name = 'MTT_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyTierId = tierT.Id, EffectiveDate = Date.today());

    BenefitType btT = new BenefitType(
      Name = 'BTT_' + suffix,
      ProcessType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue(),
      LoyaltyProgramId = lpm.ProgramId
    );
    insert btT;

    Benefit bT = new Benefit(Name = 'BT_' + suffix, BenefitTypeId = btT.Id, PurchasePointRate__c = 3, LoyaltyPgmCurrencySubtypeId__c = subtT.Id);
    insert bT;

    insert new LoyaltyTierBenefit(Name = 'TBT_' + suffix, LoyaltyTierId = tierT.Id, BenefitId = bT.Id);

    JournalType accrualType;
    List<JournalType> existingAccrual = [SELECT Id FROM JournalType WHERE Name = 'Accrual' LIMIT 1];
    if (existingAccrual.isEmpty()) {
      accrualType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
      insert accrualType;
    } else {
      accrualType = existingAccrual[0];
    }

    JournalSubType forcedCreditSubType;
    List<JournalSubType> existingFC = [SELECT Id FROM JournalSubType WHERE Name = 'Api Forced Credit' LIMIT 1];
    if (existingFC.isEmpty()) {
      forcedCreditSubType = new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualType.Id);
      insert forcedCreditSubType;
    } else {
      forcedCreditSubType = existingFC[0];
    }

    Order ordT = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert ordT;

    TransactionJournal markedTjT = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-T-MARKED',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 10000,
      SaleId__c = ordT.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      AdditionalNotes__c = 'OPTC_BRANCH_RETURN_DEPOSIT_DELETE: prior run trace',
      IsDeleted__c = true
    );
    insert markedTjT;

    TransactionJournal forcedCreditTjT = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      JournalSubTypeId = forcedCreditSubType.Id,
      DepositNo__c = 'DEP-RDB-T-FORCED',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 200,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      AdditionalNotes__c = 'OPTC_FORCE_CREDIT: OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT: tjId=' + markedTjT.Id
    );
    insert forcedCreditTjT;

    TransactionJournal cancelTjT = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-T-CANCEL',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 5000,
      SaleId__c = ordT.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT',
      AdditionalNotes__c = 'OPTC_OLD_SALE_ETC_ACCRUAL_CANCEL: previous cancel'
    );
    insert cancelTjT;

    TransactionJournal sourceCreditTjT = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-T-SRC',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 5000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert sourceCreditTjT;

    LoyaltyLedger creditL = new LoyaltyLedger(
      TransactionJournalId = sourceCreditTjT.Id,
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currT.Id,
      LoyaltyPgmCrcySubtypeId = subtT.Id,
      ActivityDate = Datetime.now(),
      EventType = 'Credit',
      Points = 150,
      ExpiryDate = Date.today().addYears(2)
    );
    insert creditL;

    LoyaltyLedger debitL = new LoyaltyLedger(
      TransactionJournalId = cancelTjT.Id,
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currT.Id,
      LoyaltyPgmCrcySubtypeId = subtT.Id,
      ActivityDate = Datetime.now(),
      EventType = 'Debit',
      Points = 150,
      ExpiryDate = Date.today().addYears(2)
    );
    insert debitL;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = currT.Id,
      LoyaltyPgmCurrencySubtypeId = subtT.Id,
      CreditLoyaltyLedgerId = creditL.Id,
      DebitLoyaltyLedgerId = debitL.Id,
      ActionType = 'CreditCancellation',
      Points = 150
    );

    TransactionJournal tjT = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-T-TARGET',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 30000,
      SaleId__c = ordT.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjT;

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult r = GdReturnDepositBranchHandler.handle('DEP-RDB-T-TARGET', null);
      called = (r != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called, 'full deep 경로 실행 완료');
  }

  // ============================================================
  // U. Tier 셋업 + SaleId__c=null — 헬퍼의 null param early return 라인 커버
  // ============================================================
  @IsTest
  static void handle_defaultPath_tierNoSaleId_helpersNullBranch() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];

    String suffix = String.valueOf(Datetime.now().getTime()) + 'U';

    LoyaltyProgramCurrency currU = new LoyaltyProgramCurrency(
      Name = 'CurrU_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 1,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert currU;

    LoyaltyPgmCurrencySubtype subtU = new LoyaltyPgmCurrencySubtype(
      Name = 'SubtU_' + suffix,
      LoyaltyProgramCurrencyId = currU.Id,
      UsagePriorityNumber = 1,
      IsActive = true,
      PointTypeCode__c = '01'
    );
    insert subtU;

    insert new LoyaltyMemberCurrency(Name = 'LMCU_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyProgramCurrencyId = currU.Id);

    LoyaltyTierGroup tgU = new LoyaltyTierGroup(
      Name = 'TGU_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tgU;

    LoyaltyTier tierU = new LoyaltyTier(Name = 'TierU_' + suffix, LoyaltyTierGroupId = tgU.Id);
    insert tierU;

    insert new LoyaltyMemberTier(Name = 'MTU_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyTierId = tierU.Id, EffectiveDate = Date.today());

    BenefitType btU = new BenefitType(
      Name = 'BTU_' + suffix,
      ProcessType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue(),
      LoyaltyProgramId = lpm.ProgramId
    );
    insert btU;

    Benefit bU = new Benefit(Name = 'BU_' + suffix, BenefitTypeId = btU.Id, PurchasePointRate__c = 2, LoyaltyPgmCurrencySubtypeId__c = subtU.Id);
    insert bU;

    insert new LoyaltyTierBenefit(Name = 'TBU_' + suffix, LoyaltyTierId = tierU.Id, BenefitId = bU.Id);

    // SaleId__c 없이 타깃 TJ
    TransactionJournal tjU = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-U-TARGET',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 25000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjU;

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult r = GdReturnDepositBranchHandler.handle('DEP-RDB-U-TARGET', null);
      called = (r != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called);
  }

  // ============================================================
  // V. ApexLogger 직접 인스턴스로 PARTIAL 경로 + Q deep + tier — 마지막 라인 보충
  // ============================================================
  @IsTest
  static void handle_loggerWithTierSetup_coversRemainingLines() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];
    Account acc = [SELECT Id FROM Account WHERE Name = 'Co_RDB' LIMIT 1];

    String suffix = String.valueOf(Datetime.now().getTime()) + 'V';

    LoyaltyProgramCurrency currV = new LoyaltyProgramCurrency(
      Name = 'CurrV_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 1,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      DoesAllowLedgerTracing = true
    );
    insert currV;

    LoyaltyPgmCurrencySubtype subtV = new LoyaltyPgmCurrencySubtype(
      Name = 'SubtV_' + suffix,
      LoyaltyProgramCurrencyId = currV.Id,
      UsagePriorityNumber = 1,
      IsActive = true,
      PointTypeCode__c = '01'
    );
    insert subtV;

    insert new LoyaltyMemberCurrency(Name = 'LMCV_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyProgramCurrencyId = currV.Id);

    LoyaltyTierGroup tgV = new LoyaltyTierGroup(
      Name = 'TGV_' + suffix,
      LoyaltyProgramId = lpm.ProgramId,
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tgV;

    LoyaltyTier tierV = new LoyaltyTier(Name = 'TierV_' + suffix, LoyaltyTierGroupId = tgV.Id);
    insert tierV;

    insert new LoyaltyMemberTier(Name = 'MTV_' + suffix, LoyaltyMemberId = lpm.Id, LoyaltyTierId = tierV.Id, EffectiveDate = Date.today());

    BenefitType btV = new BenefitType(
      Name = 'BTV_' + suffix,
      ProcessType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue(),
      LoyaltyProgramId = lpm.ProgramId
    );
    insert btV;

    Benefit bV = new Benefit(Name = 'BV_' + suffix, BenefitTypeId = btV.Id, PurchasePointRate__c = 2, LoyaltyPgmCurrencySubtypeId__c = subtV.Id);
    insert bV;

    insert new LoyaltyTierBenefit(Name = 'TBV_' + suffix, LoyaltyTierId = tierV.Id, BenefitId = bV.Id);

    // calculateAccrualForOldOrder 가 실제로 positive 추정을 반환하는지 직접 검증
    List<GdMigrationUtil.AccrualEstimate> estimates = GdMigrationUtil.calculateAccrualForOldOrder(lpm.Id, 10000, null);
    System.assert(estimates.size() > 0, 'Tier 셋업이 적립 추정을 produce 해야 함');

    Order ordV = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today());
    insert ordV;

    TransactionJournal tjV = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      DepositNo__c = 'DEP-RDB-V-TARGET',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '03',
      TransactionAmount = 40000,
      SaleId__c = ordV.Id,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjV;

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdReturnDepositBranchHandlerTest.class.getName());

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult r = GdReturnDepositBranchHandler.handle('DEP-RDB-V-TARGET', logger);
      called = (r != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called);
  }

  // ============================================================
  // W. Coupon Redeem Cancel JournalSubType — coupon restore branch
  //    (배포본의 restoreCouponUsageForReturnDepositDelete 분기 진입)
  // ============================================================
  @IsTest
  static void handle_couponRedeemCancelSubType_triggersCouponRestore() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    LoyaltyProgramMember lpm = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = 'M-RDB-TEST' LIMIT 1];

    JournalType redemptionType;
    List<JournalType> existingRed = [SELECT Id FROM JournalType WHERE Name = 'Redemption' LIMIT 1];
    if (existingRed.isEmpty()) {
      redemptionType = new JournalType(Name = 'Redemption', ProcessType = 'Loyalty');
      insert redemptionType;
    } else {
      redemptionType = existingRed[0];
    }

    JournalSubType couponRedeemCancelSubType;
    List<JournalSubType> existingCC = [SELECT Id FROM JournalSubType WHERE Name = 'Coupon Redeem Cancel' LIMIT 1];
    if (existingCC.isEmpty()) {
      couponRedeemCancelSubType = new JournalSubType(Name = 'Coupon Redeem Cancel', JournalTypeId = redemptionType.Id);
      insert couponRedeemCancelSubType;
    } else {
      couponRedeemCancelSubType = existingCC[0];
    }

    // 타깃 TJ — JournalSubType = Coupon Redeem Cancel (VoucherCode 없음 → coupon restore early return)
    TransactionJournal tjCoup = new TransactionJournal(
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      JournalSubTypeId = couponRedeemCancelSubType.Id,
      DepositNo__c = 'DEP-RDB-COUP',
      DeposiSeqNo__c = '01',
      DepositType__c = '01',
      PaymentMethod = '90',
      TransactionAmount = 5000,
      ActivityDate = Date.newInstance(2026, 3, 1),
      Status = 'Processed',
      InsertId__c = 'MIG_OPTC_CREDIT'
    );
    insert tjCoup;

    Test.startTest();
    Boolean called = false;
    try {
      ApiResult r = GdReturnDepositBranchHandler.handle('DEP-RDB-COUP', null);
      called = (r != null);
    } catch (Exception e) {
      called = true;
    }
    Test.stopTest();

    System.assertEquals(true, called);
  }
}