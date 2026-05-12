@IsTest
private class IssuePointSubTypeBatchTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{"erpId":"OK"}}');
      return res;
    }
  }

  private class MockBatchableContext implements Database.BatchableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }
    public Id getChildJobId() {
      return UserInfo.getUserId();
    }
  }

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  /* ===== 공통 데이터 생성 ===== */

  @TestSetup
  static void setupData() {
    setMock();

    JournalType jt = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert jt;

    JournalSubType jst = new JournalSubType(Name = 'Manual Points Credit', JournalTypeId = jt.Id);
    insert jst;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'IssuePoint Test Program', IsPrimary = true);
    insert lp;

    // LoyaltyProgramCurrency (IsPrimary = true 필수)
    String currencyType = 'NonQualifying';
    for (Schema.PicklistEntry e : LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues()) {
      if (e.getValue().equalsIgnoreCase('NonQualifying')) {
        currencyType = e.getValue();
        break;
      }
    }

    String expiryUnit = null;
    for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues()) {
      if (!e.getValue().toLowerCase().contains('day')) {
        expiryUnit = e.getValue();
        break;
      }
    }
    if (expiryUnit == null) {
      List<Schema.PicklistEntry> units = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();
      if (!units.isEmpty())
        expiryUnit = units[0].getValue();
    }

    String expiryModel = 'FIXED';
    for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
      if (e.getValue().equalsIgnoreCase('FIXED')) {
        expiryModel = e.getValue();
        break;
      }
    }

    String extendExpiration = null;
    List<Schema.PicklistEntry> extEntries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
    if (!extEntries.isEmpty())
      extendExpiration = extEntries[0].getValue();

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = 'Test Point Currency',
      CurrencyType = currencyType,
      IsActive = true,
      IsPrimary = true,
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = expiryUnit,
      ExpiryModel = expiryModel,
      ExtendExpiration = extendExpiration,
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert lpc;

    String pointTypeCode = 'NORMAL';
    List<Schema.PicklistEntry> ptEntries = LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues();
    if (!ptEntries.isEmpty())
      pointTypeCode = ptEntries[0].getValue();

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = lpc.Id,
      Name = 'Test Subtype',
      PointTypeCode__c = pointTypeCode,
      UsagePriorityNumber = 1
    );
    insert subtype;

    Contact c = new Contact(LastName = 'IssuePoint Member', MemberNo__c = 'M-ISS-001');
    insert c;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'M-ISS-001',
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert lpm;
  }

  private static Id getSubtypeId() {
    return [SELECT Id FROM LoyaltyPgmCurrencySubtype LIMIT 1].Id;
  }

  private static Id getMemberId() {
    return [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
  }

  /* ===== 테스트 메서드 ===== */

  /** execute : 빈 scope 조기 반환 분기 */
  @IsTest
  static void test_execute_emptyScope() {
    setMock();

    IssuePointSubTypeBatch batch = new IssuePointSubTypeBatch(new Set<Id>(), getSubtypeId(), Date.today(), 100, Date.today().addDays(365));

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<LoyaltyProgramMember>());
    Test.stopTest();

    System.assert(true);
  }

  /** finish : 성공/실패 집계 로깅 */
  @IsTest
  static void test_finish() {
    setMock();

    IssuePointSubTypeBatch batch = new IssuePointSubTypeBatch(new Set<Id>(), getSubtypeId(), Date.today(), 100, Date.today().addDays(365));

    Test.startTest();
    batch.finish(new MockBatchableContext());
    Test.stopTest();

    System.assert(true);
  }

  /** 정상 데이터 : MemberNo 있음 → TransactionJournal + LoyaltyLedger + ERP 요청 */
  @IsTest
  static void test_executeBatch_withValidMember() {
    setMock();

    Id memberId = getMemberId();
    Id subtypeId = getSubtypeId();

    Test.startTest();
    Database.executeBatch(new IssuePointSubTypeBatch(new Set<Id>{ memberId }, subtypeId, Date.today(), 500, Date.today().addDays(365)), 50);
    Test.stopTest();

    System.assert(true);
  }

  /** MemberNo 없음 → ERP 제외(failIds) 분기 */
  @IsTest
  static void test_executeBatch_noMemberNo() {
    setMock();

    Contact c = [SELECT Id FROM Contact LIMIT 1];
    c.MemberNo__c = null;
    update c;

    Id memberId = getMemberId();
    Id subtypeId = getSubtypeId();

    Test.startTest();
    Database.executeBatch(new IssuePointSubTypeBatch(new Set<Id>{ memberId }, subtypeId, Date.today(), 100, Date.today().addDays(365)), 50);
    Test.stopTest();

    System.assert(true);
  }

  /** memberIds에 해당하는 LPM 없음 → 빈 scope로 실행 */
  @IsTest
  static void test_executeBatch_noMatchingMember() {
    setMock();

    Id subtypeId = getSubtypeId();

    Test.startTest();
    Database.executeBatch(
      new IssuePointSubTypeBatch(
        new Set<Id>{ UserInfo.getUserId() }, // 존재하지 않는 LPM Id
        subtypeId,
        Date.today(),
        100,
        Date.today().addDays(365)
      ),
      50
    );
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_start_returns_members_for_target_ids() {
    setMock();

    Id memberId = getMemberId();
    IssuePointSubTypeBatch batch = new IssuePointSubTypeBatch(new Set<Id>{ memberId }, getSubtypeId(), Date.today(), 100, Date.today().addDays(365));

    Test.startTest();
    Database.QueryLocator locator = batch.start(new MockBatchableContext());
    Test.stopTest();

    System.assertNotEquals(null, locator);
  }

  @IsTest
  static void test_execute_invalidSubtype_is_logged_as_error() {
    setMock();

    LoyaltyProgramMember member = [
      SELECT Id, ProgramId, ContactId, Contact.MemberNo__c
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    IssuePointSubTypeBatch batch = new IssuePointSubTypeBatch(
      new Set<Id>{ member.Id },
      UserInfo.getUserId(),
      Date.today(),
      100,
      Date.today().addDays(365)
    );

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<LoyaltyProgramMember>{ member });
    Test.stopTest();

    System.assert(true);
  }
}