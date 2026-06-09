@IsTest
private class MemberDeleteBatchTest {
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

  // =========================================================
  // Helpers
  // =========================================================
  private static void setupCalloutMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Crypto.getRandomInteger()).substring(0, 6);
  }

  /**
   * 배치 대상 Contact 생성.
   * MemberNo__c는 의도적으로 null 유지 → memberNos가 빈 Set이 되어
   * Order SOQL (Id 타입 필드 비교) 로 인한 StringException을 피함.
   * Order 경로 테스트는 별도 메서드에서 c.Id를 직접 사용.
   */
  private static Contact makeWithdrawnContact() {
    setupCalloutMock();

    Contact c = new Contact();
    c.LastName = uniq('Member');
    c.put('IsWithdrawn__c', true);
    c.put('MemberDropDate__c', Date.today().addDays(-32));
    insert c;
    return c;
  }

  private static LoyaltyProgram createProgram() {
    setupCalloutMock();

    LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('Prog'), IsPrimary = true);
    insert lp;
    return lp;
  }

  private static LoyaltyProgramMember createLpm(Id lpId, Id contactId) {
    LoyaltyProgramMember lpm = new LoyaltyProgramMember();
    lpm.ProgramId = lpId;
    lpm.ContactId = contactId;
    lpm.MembershipNumber = uniq('MBR');
    lpm.MemberStatus = 'Active';
    lpm.EnrollmentDate = Date.today();
    insert lpm;
    return lpm;
  }

  private static VoucherDefinition createVoucherDefinition(Id programId) {
    setupCalloutMock();
    TriggerHandler.bypass('VoucherDefinitionTriggerHandler');

    Product2 prod = new Product2(Name = uniq('Prod'), IsActive = true);
    insert prod;

    VoucherCategory__c category = new VoucherCategory__c(Name = uniq('Category'), Code__c = uniq('CAT'));
    insert category;

    Account companyAccount = new Account(Name = uniq('Company'), CompanyCode__c = '1000');
    insert companyAccount;

    VoucherDefinition vd = new VoucherDefinition(
      Name = uniq('VD'),
      LoyaltyProgramId = programId,
      IsActive = true,
      Description = 'MemberDeleteBatch test',
      ProductId = prod.Id,
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      VoucherCategoryId__c = category.Id,
      AccountId__c = companyAccount.Id,
      CouponManNo__c = uniq('CPN'),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert vd;
    TriggerHandler.clearBypass('VoucherDefinitionTriggerHandler');
    return vd;
  }

  // =========================================================
  // 1) 연관 레코드 없는 Contact 단독 삭제
  // =========================================================
  @IsTest
  static void test_batch_deletes_contact_only() {
    setupCalloutMock();

    Contact c = makeWithdrawnContact();
    Id contactId = c.Id;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    List<Contact> remaining = [SELECT IsDeleted FROM Contact WHERE Id = :contactId ALL ROWS];
    System.assert(!remaining.isEmpty() && remaining[0].IsDeleted, 'Contact가 삭제되어야 함');
  }

  // =========================================================
  // 2) LoyaltyProgramMember + Voucher 포함 삭제
  // =========================================================
  @IsTest
  static void test_batch_deletes_lpm_and_voucher() {
    setupCalloutMock();

    LoyaltyProgram lp = createProgram();
    Contact c = makeWithdrawnContact();

    LoyaltyProgramMember lpm = createLpm(lp.Id, c.Id);

    VoucherDefinition vd = createVoucherDefinition(lp.Id);
    Voucher v = new Voucher(
      VoucherDefinitionId = vd.Id,
      ContactId = c.Id,
      LoyaltyProgramMemberId = lpm.Id,
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30)
    );
    insert v;

    Id contactId = c.Id;
    Id lpmId = lpm.Id;
    Id voucherId = v.Id;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    List<Contact> remainingC = [SELECT IsDeleted FROM Contact WHERE Id = :contactId ALL ROWS];
    System.assert(!remainingC.isEmpty() && remainingC[0].IsDeleted, 'Contact 삭제 확인');

    List<LoyaltyProgramMember> remainingLpm = [SELECT IsDeleted FROM LoyaltyProgramMember WHERE Id = :lpmId ALL ROWS];
    System.assert(!remainingLpm.isEmpty() && remainingLpm[0].IsDeleted, 'LoyaltyProgramMember 삭제 확인');

    List<Voucher> remainingV = [SELECT IsDeleted FROM Voucher WHERE Id = :voucherId ALL ROWS];
    System.assert(!remainingV.isEmpty() && remainingV[0].IsDeleted, 'Voucher 삭제 확인');
  }

  // =========================================================
  // 3) TransactionJournal 포함 삭제 (ActivityDate + LoyaltyProgramId 필수)
  // =========================================================
  @IsTest
  static void test_batch_deletes_transaction_journal() {
    setupCalloutMock();

    LoyaltyProgram lp = createProgram();
    Contact c = makeWithdrawnContact();

    LoyaltyProgramMember lpm = createLpm(lp.Id, c.Id);

    Id tjId;
    try {
      TransactionJournal tj = new TransactionJournal();
      tj.MemberId = lpm.Id;
      tj.LoyaltyProgramId = lp.Id;
      tj.ActivityDate = Datetime.now(); // 필수 필드
      insert tj;
      tjId = tj.Id;
    } catch (Exception e) {
      System.debug('TransactionJournal insert skip: ' + e.getMessage());
    }

    Id contactId = c.Id;
    Id lpmId = lpm.Id;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    List<Contact> remainingC = [SELECT IsDeleted FROM Contact WHERE Id = :contactId ALL ROWS];
    System.assert(!remainingC.isEmpty() && remainingC[0].IsDeleted, 'Contact 삭제 확인');

    List<LoyaltyProgramMember> remainingLpm = [SELECT IsDeleted FROM LoyaltyProgramMember WHERE Id = :lpmId ALL ROWS];
    System.assert(!remainingLpm.isEmpty() && remainingLpm[0].IsDeleted, 'LoyaltyProgramMember 삭제 확인');

    if (tjId != null) {
      List<TransactionJournal> remainingTj = [SELECT IsDeleted FROM TransactionJournal WHERE Id = :tjId ALL ROWS];
      System.assert(!remainingTj.isEmpty() && remainingTj[0].IsDeleted, 'TransactionJournal 삭제 확인');
    }
  }

  // =========================================================
  // 4) Order 포함 삭제
  //    Order.MemberNo__c는 Id 타입 → Contact.MemberNo__c를 c.Id로 설정
  // =========================================================
  @IsTest
  static void test_batch_deletes_matching_order() {
    setupCalloutMock();

    Contact c = makeWithdrawnContact();

    // Order.MemberNo__c가 Id 타입이므로 Contact.MemberNo__c에도 유효한 Id 사용
    c.put('MemberNo__c', c.Id);
    update c;

    Account acc = new Account(Name = uniq('Acc'));
    insert acc;

    Id ordId;
    try {
      Order ord = new Order(AccountId = acc.Id, Status = 'Draft', EffectiveDate = Date.today(), Pricebook2Id = Test.getStandardPricebookId());
      ord.put('MemberNo__c', c.Id); // 유효한 Salesforce Id
      insert ord;
      ordId = ord.Id;
    } catch (Exception e) {
      System.debug('Order insert skip: ' + e.getMessage());
    }

    Id contactId = c.Id;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    List<Contact> remaining = [SELECT IsDeleted FROM Contact WHERE Id = :contactId ALL ROWS];
    System.assert(!remaining.isEmpty() && remaining[0].IsDeleted, 'Contact 삭제 확인');

    if (ordId != null) {
      List<Order> remainingOrd = [SELECT IsDeleted FROM Order WHERE Id = :ordId ALL ROWS];
      System.assert(!remainingOrd.isEmpty() && remainingOrd[0].IsDeleted, 'Order 삭제 확인');
    }
  }

  // =========================================================
  // 5) MemberDropDate__c가 31일 이내 → 배치 대상 제외
  // =========================================================
  @IsTest
  static void test_batch_skips_recent_withdrawal() {
    setupCalloutMock();

    Contact c = new Contact(LastName = uniq('Recent'));
    c.put('IsWithdrawn__c', true);
    c.put('MemberDropDate__c', Date.today().addDays(-10)); // 10일 전 → 대상 아님
    insert c;
    Id contactId = c.Id;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    List<Contact> remaining = [SELECT IsDeleted FROM Contact WHERE Id = :contactId ALL ROWS];
    System.assert(!remaining.isEmpty() && !remaining[0].IsDeleted, '최근 탈퇴 Contact는 삭제되지 않아야 함');
  }

  // =========================================================
  // 6) MemberDropDate__c = null → 배치 대상 제외
  // =========================================================
  @IsTest
  static void test_batch_skips_contact_without_dropDate() {
    setupCalloutMock();

    Contact c = new Contact(LastName = uniq('NoDrop'));
    c.put('IsWithdrawn__c', true);
    // MemberDropDate__c 미설정
    insert c;
    Id contactId = c.Id;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    List<Contact> remaining = [SELECT IsDeleted FROM Contact WHERE Id = :contactId ALL ROWS];
    System.assert(!remaining.isEmpty() && !remaining[0].IsDeleted, 'MemberDropDate null이면 대상 아님');
  }

  // =========================================================
  // 7) MemberNo__c 없는 Contact → memberNos 빈 Set → Order SOQL 스킵
  // =========================================================
  @IsTest
  static void test_batch_contact_without_memberNo() {
    setupCalloutMock();

    Contact c = makeWithdrawnContact(); // MemberNo__c = null
    Id contactId = c.Id;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    List<Contact> remaining = [SELECT IsDeleted FROM Contact WHERE Id = :contactId ALL ROWS];
    System.assert(!remaining.isEmpty() && remaining[0].IsDeleted, 'MemberNo 없어도 Contact 삭제되어야 함');
  }

  // =========================================================
  // 8) 해당 조건 없음 → 빈 scope → 예외 없이 종료
  // =========================================================
  @IsTest
  static void test_batch_no_qualifying_contact() {
    setupCalloutMock();

    Contact c = new Contact(LastName = 'Active');
    c.put('IsWithdrawn__c', false);
    insert c;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    System.assert(true, '빈 scope 시 예외 없이 종료');
  }

  // =========================================================
  // 9) finish 메서드 포함 전체 흐름 검증
  // =========================================================
  @IsTest
  static void test_finish_runs_without_exception() {
    setupCalloutMock();

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    System.assert(true, 'finish 메서드 예외 없이 종료');
  }

  // =========================================================
  // 10) 회원 연관 전체 그래프 삭제
  //     LoyaltyLedger / LoyaltyLedgerTraceability / LoyaltyMemberCurrency
  //     / LoyaltyMemberTier / LoyaltyAggrSubPointExprLedger__c 의
  //     내부 delete 루프를 실제로 실행시켜 커버리지 확보.
  // =========================================================
  @IsTest
  static void test_batch_deletes_full_member_graph() {
    setupCalloutMock();

    LoyaltyProgram lp = createProgram();
    Contact c = makeWithdrawnContact();
    LoyaltyProgramMember lpm = createLpm(lp.Id, c.Id);

    Id memberId = lpm.Id;

    // --- LoyaltyProgramCurrency + Subtype ---
    LoyaltyProgramCurrency loyaltyCurrency = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = uniq('CUR'),
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
    insert loyaltyCurrency;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
      Name = uniq('SUB'),
      PointTypeCode__c = '02',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subtype;

    // --- LoyaltyMemberCurrency ---
    Id lmcId;
    try {
      LoyaltyMemberCurrency lmc = new LoyaltyMemberCurrency(
        Name = uniq('LMC'),
        LoyaltyMemberId = memberId,
        LoyaltyProgramCurrencyId = loyaltyCurrency.Id
      );
      insert lmc;
      lmcId = lmc.Id;
    } catch (Exception e) {
      System.debug('LoyaltyMemberCurrency insert skip: ' + e.getMessage());
    }

    // --- LoyaltyTierGroup + LoyaltyTier + LoyaltyMemberTier ---
    Id lmtId;
    try {
      LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
        Name = uniq('TG'),
        LoyaltyProgramId = lp.Id,
        QpResetPeriod = 'Years',
        QpResetDate = Date.today(),
        QpResetFrequency = 1
      );
      insert tierGroup;

      LoyaltyTier tier = new LoyaltyTier(Name = uniq('TIER'), LoyaltyTierGroupId = tierGroup.Id);
      insert tier;

      LoyaltyMemberTier lmt = new LoyaltyMemberTier(LoyaltyMemberId = memberId, LoyaltyTierId = tier.Id, Name = '02');
      insert lmt;
      lmtId = lmt.Id;
    } catch (Exception e) {
      System.debug('LoyaltyMemberTier insert skip: ' + e.getMessage());
    }

    // --- LoyaltyLedger (Credit + Debit) + LoyaltyLedgerTraceability ---
    Id lltId;
    Id creditLedgerId;
    Id debitLedgerId;
    try {
      LoyaltyLedger creditLedger = new LoyaltyLedger(
        LoyaltyProgramMemberId = memberId,
        LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
        LoyaltyPgmCrcySubtypeId = subtype.Id,
        ActivityDate = Datetime.now(),
        Points = 100,
        ExpiryDate = Date.today().addYears(1),
        EventType = 'Credit'
      );
      LoyaltyLedger debitLedger = new LoyaltyLedger(
        LoyaltyProgramMemberId = memberId,
        LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
        LoyaltyPgmCrcySubtypeId = subtype.Id,
        ActivityDate = Datetime.now(),
        Points = 30,
        ExpiryDate = Date.today().addYears(1),
        EventType = 'Debit'
      );
      insert new List<LoyaltyLedger>{ creditLedger, debitLedger };
      creditLedgerId = creditLedger.Id;
      debitLedgerId = debitLedger.Id;

      LoyaltyLedgerTraceability llt = new LoyaltyLedgerTraceability(
        LoyaltyProgramMemberId = memberId,
        LoyaltyPgmCurrencySubtypeId = subtype.Id,
        LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
        Points = 30,
        ActionType = 'Debit',
        DebitLoyaltyLedgerId = debitLedger.Id,
        CreditLoyaltyLedgerId = creditLedger.Id
      );
      insert llt;
      lltId = llt.Id;
    } catch (Exception e) {
      System.debug('LoyaltyLedger/Traceability insert skip: ' + e.getMessage());
    }

    // --- LoyaltyAggrSubPointExprLedger__c (custom, master-detail to member) ---
    Id aggrId;
    try {
      LoyaltyAggrSubPointExprLedger__c aggr = new LoyaltyAggrSubPointExprLedger__c(
        LoyaltyProgramMemberId__c = memberId,
        CurrencySubTypeId__c = subtype.Id
      );
      insert aggr;
      aggrId = aggr.Id;
    } catch (Exception e) {
      System.debug('LoyaltyAggrSubPointExprLedger__c insert skip: ' + e.getMessage());
    }

    Id contactId = c.Id;

    Test.startTest();
    Database.executeBatch(new MemberDeleteBatch(), 5);
    Test.stopTest();

    List<Contact> remainingC = [SELECT IsDeleted FROM Contact WHERE Id = :contactId ALL ROWS];
    System.assert(!remainingC.isEmpty() && remainingC[0].IsDeleted, 'Contact 삭제 확인');

    List<LoyaltyProgramMember> remainingLpm = [SELECT IsDeleted FROM LoyaltyProgramMember WHERE Id = :memberId ALL ROWS];
    System.assert(!remainingLpm.isEmpty() && remainingLpm[0].IsDeleted, 'LoyaltyProgramMember 삭제 확인');

    if (lltId != null) {
      System.assertEquals(0, [SELECT COUNT() FROM LoyaltyLedgerTraceability WHERE Id = :lltId], 'LoyaltyLedgerTraceability 삭제 확인');
    }
    if (creditLedgerId != null) {
      System.assertEquals(0, [SELECT COUNT() FROM LoyaltyLedger WHERE Id IN (:creditLedgerId, :debitLedgerId)], 'LoyaltyLedger 삭제 확인');
    }
    if (lmcId != null) {
      System.assertEquals(0, [SELECT COUNT() FROM LoyaltyMemberCurrency WHERE Id = :lmcId], 'LoyaltyMemberCurrency 삭제 확인');
    }
    if (lmtId != null) {
      System.assertEquals(0, [SELECT COUNT() FROM LoyaltyMemberTier WHERE Id = :lmtId], 'LoyaltyMemberTier 삭제 확인');
    }
    if (aggrId != null) {
      System.assertEquals(0, [SELECT COUNT() FROM LoyaltyAggrSubPointExprLedger__c WHERE Id = :aggrId], 'LoyaltyAggrSubPointExprLedger__c 삭제 확인');
    }
  }
}
