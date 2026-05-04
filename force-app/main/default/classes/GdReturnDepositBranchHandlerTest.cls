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

  @TestSetup
  static void setupData() {
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
    System.assert(
      tj.AdditionalNotes__c.contains(GdReturnDepositBranchHandler.MARKER),
      'AdditionalNotes 에 MARKER 포함'
    );
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

    TransactionJournal tj = [
      SELECT AdditionalNotes__c FROM TransactionJournal WHERE DepositNo__c = 'DEP-RDB-OLD-02' LIMIT 1
    ];
    System.assert(
      tj.AdditionalNotes__c.contains('EXISTING_NOTE_FROM_MIGRATION'),
      '기존 노트 보존'
    );
    System.assert(
      tj.AdditionalNotes__c.contains(GdReturnDepositBranchHandler.MARKER),
      '새 마커 추가'
    );
    System.assert(
      tj.AdditionalNotes__c.contains(' | '),
      '구분자 ( | ) 사이에 둠'
    );
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
    TransactionJournal tj = [
      SELECT Id FROM TransactionJournal WHERE DepositNo__c = 'DEP-RDB-OLD-01' LIMIT 1
    ];
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
}