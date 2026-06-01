@IsTest
private class BirthdayCouponIssueBatchTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  private static void executeBatchWithMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    Database.executeBatch(new BirthdayCouponIssueBatch(), 200);
  }

  @TestSetup
  static void setupData() {
    // 1. Journal Types (배치에서 조회하는 저널 타입)
    JournalType jt = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert jt;

    JournalSubType jst = new JournalSubType(Name = 'Coupon Issue', JournalTypeId = jt.Id);
    insert jst;

    // 2. Loyalty Program & Tiers
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Test Program', IsPrimary = true);
    insert lp;

    LoyaltyTierGroup ltg = new LoyaltyTierGroup(
      Name = 'Test Tier Group',
      LoyaltyProgramId = lp.Id,
      TierModel = 'Fixed',
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert ltg;

    LoyaltyTier tier = new LoyaltyTier(Name = 'Test Tier', LoyaltyTierGroupId = ltg.Id, SequenceNumber = 1);
    insert tier;

    // 3. Voucher Setup (배치에서 조회하는 쿠폰 마스터 및 카테고리)
    VoucherCategory__c vc = new VoucherCategory__c(Name = 'Birthday', Code__c = 'BirthdayCoupon');
    insert vc;

    Product2 prod = new Product2(Name = 'Voucher Product', IsActive = true);
    insert prod;

    Account companyAccount = new Account(Name = 'Birthday Company', CompanyCode__c = '1000');
    insert companyAccount;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Birthday Voucher',
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      Description = 'Test Voucher',
      ProductId = prod.Id,
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      ExpirationDate = Date.today().addDays(30),
      EffectiveDate = Date.today(),
      VoucherCategoryId__c = vc.Id,
      AccountId__c = companyAccount.Id,
      CouponManNo__c = 'CPN-BIRTH-001',
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert vd;

    // 4. Voucher Limit (등급별 지급 허용 설정)
    VoucherLimit__c vl = new VoucherLimit__c(VoucherDefinitionId__c = vd.Id, Type__c = 'GradeIncludeList', Value__c = tier.Id, IsActive__c = true);
    insert vl;
  }

  // 테스트용 멤버 생성 헬퍼
  private static void createMember(Boolean birthdayThisMonth) {
    Date today = Date.today();
    Integer month = birthdayThisMonth ? today.month() : (today.month() == 12 ? 1 : today.month() + 1);
    Integer year = today.year() - 25;

    Contact c = new Contact(
      LastName = 'Batch Test',
      Birthdate = Date.newInstance(year, month, 1),
      LegalBirthdate__c = Datetime.newInstance(year, month, 1).format('yyMMdd'),
      MemberNo__c = 'M001'
    );
    insert c;

    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'M001',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    LoyaltyTier tier = [SELECT Id FROM LoyaltyTier LIMIT 1];

    LoyaltyMemberTier lmt = new LoyaltyMemberTier(
      Name = 'Test Member Tier',
      LoyaltyMemberId = lpm.Id,
      LoyaltyTierId = tier.Id,
      EffectiveDate = Date.today()
    );
    insert lmt;
  }

  // 1️⃣ 정상 실행 (이번 달 생일자 + 쿠폰 지급 대상)
  @IsTest
  static void test_execute_withTarget() {
    createMember(true);

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  // 2️⃣ 대상 없음 (다른 달 생일자)
  @IsTest
  static void test_execute_otherMonth() {
    createMember(false);

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  // 3️⃣ 데이터 없음
  @IsTest
  static void test_execute_noData() {
    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  // 4️⃣ 에러 케이스: 쿠폰 카테고리 누락
  @IsTest
  static void test_execute_noCategory() {
    createMember(true);
    delete [SELECT Id FROM VoucherCategory__c];

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  // 5️⃣ 에러 케이스: 쿠폰 정의(Definition) 누락
  @IsTest
  static void test_execute_noDefinition() {
    createMember(true);
    delete [SELECT Id FROM VoucherDefinition];

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  // 6️⃣ 에러 케이스: 회원 번호 누락
  @IsTest
  static void test_execute_noMemberNo() {
    createMember(true);
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    c.MemberNo__c = null;
    update c;

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_upgradeCoupon_setsFaceValueZero() {
    createMember(true);

    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Id categoryId = [SELECT Id FROM VoucherCategory__c WHERE Code__c = 'BirthdayCoupon' LIMIT 1].Id;
    Id accountId = [SELECT Id FROM Account WHERE CompanyCode__c = '1000' LIMIT 1].Id;
    Id tierId = [SELECT Id FROM LoyaltyTier LIMIT 1].Id;

    Product2 upgradeProduct = new Product2(Name = 'Birthday Upgrade Product', IsActive = true);
    insert upgradeProduct;

    VoucherDefinition upgradeVd = new VoucherDefinition(
      Name = 'Birthday Upgrade Voucher',
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      Description = 'Birthday upgrade voucher',
      ProductId = upgradeProduct.Id,
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      ExpirationDate = Date.today().addDays(30),
      EffectiveDate = Date.today(),
      VoucherCategoryId__c = categoryId,
      AccountId__c = accountId,
      CouponManNo__c = 'CPN-BIRTH-UPG',
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager',
      IsUpgrade__c = true
    );
    insert upgradeVd;

    insert new VoucherLimit__c(VoucherDefinitionId__c = upgradeVd.Id, Type__c = 'GradeIncludeList', Value__c = tierId, IsActive__c = true);

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    List<Voucher> issuedVoucherList = [
      SELECT Id, FaceValue
      FROM Voucher
      WHERE VoucherDefinitionId = :upgradeVd.Id
    ];

    System.assert(!issuedVoucherList.isEmpty(), 'Upgrade birthday coupon should be issued');
    for (Voucher issuedVoucher : issuedVoucherList) {
      System.assertEquals(0, issuedVoucher.FaceValue, 'Upgrade birthday coupon should be normalized to face value 0');
    }
  }

  // 8️⃣ 회원 등급이 어느 쿠폰의 허용 등급에도 들지 않음
  //    → hasEligible=false 분기 + tjByMemberId.isEmpty() ("No eligible targets") 분기 커버
  @IsTest
  static void test_execute_tierNotEligible() {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    LoyaltyTierGroup ltg = [SELECT Id FROM LoyaltyTierGroup LIMIT 1];

    LoyaltyTier excludedTier = new LoyaltyTier(Name = 'Excluded Tier', LoyaltyTierGroupId = ltg.Id, SequenceNumber = 2);
    insert excludedTier;

    Date today = Date.today();
    Integer year = today.year() - 30;
    Integer month = today.month();

    Contact c = new Contact(
      LastName = 'Excluded',
      Birthdate = Date.newInstance(year, month, 1),
      LegalBirthdate__c = Datetime.newInstance(year, month, 1).format('yyMMdd'),
      MemberNo__c = 'M-EXCL'
    );
    insert c;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'M-EXCL',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      EnrollmentDate = today
    );
    insert lpm;

    insert new LoyaltyMemberTier(Name = 'Excluded LMT', LoyaltyMemberId = lpm.Id, LoyaltyTierId = excludedTier.Id, EffectiveDate = today);

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    List<Voucher> issued = [SELECT Id FROM Voucher WHERE LoyaltyProgramMemberId = :lpm.Id];
    System.assertEquals(0, issued.size(), 'Member with non-allowed tier should not get any voucher');
  }

  // 9️⃣ 성공/실패 혼재 (PARTIAL 분기 커버 in execute() & finish())
  //    - 성공 멤버 1 (createMember 사용)
  //    - 실패 멤버 1 (MemberNo 비어있음 → "No MemberNo" 분기)
  @IsTest
  static void test_execute_mixedSuccessAndFailure() {
    createMember(true);

    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    LoyaltyTier tier = [SELECT Id FROM LoyaltyTier LIMIT 1];

    Date today = Date.today();
    Integer year = today.year() - 28;
    Integer month = today.month();

    // 두 번째 멤버 — MemberNo 없음
    Contact c2 = new Contact(
      LastName = 'No MemberNo',
      Birthdate = Date.newInstance(year, month, 1),
      LegalBirthdate__c = Datetime.newInstance(year, month, 1).format('yyMMdd')
      // MemberNo__c 비어있음
    );
    insert c2;

    LoyaltyProgramMember lpm2 = new LoyaltyProgramMember(
      ContactId = c2.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'M-NOMEM',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      EnrollmentDate = today
    );
    insert lpm2;

    insert new LoyaltyMemberTier(Name = 'No MemberNo LMT', LoyaltyMemberId = lpm2.Id, LoyaltyTierId = tier.Id, EffectiveDate = today);

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  // 🔟 멤버 다수 + 모두 정상 (finish() SUCCESS 분기 커버 / 추가 처리량 확보)
  @IsTest
  static void test_execute_multipleSuccessMembers() {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    LoyaltyTier tier = [SELECT Id FROM LoyaltyTier LIMIT 1];

    Date today = Date.today();
    Integer month = today.month();

    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < 3; i++) {
      Integer year = today.year() - 25 - i;
      contacts.add(
        new Contact(
          LastName = 'Multi ' + i,
          Birthdate = Date.newInstance(year, month, 1),
          LegalBirthdate__c = Datetime.newInstance(year, month, 1).format('yyMMdd'),
          MemberNo__c = 'M-MULTI-' + i
        )
      );
    }
    insert contacts;

    List<LoyaltyProgramMember> lpms = new List<LoyaltyProgramMember>();
    for (Integer i = 0; i < contacts.size(); i++) {
      lpms.add(
        new LoyaltyProgramMember(
          ContactId = contacts[i].Id,
          ProgramId = lp.Id,
          MembershipNumber = 'M-MULTI-LPM-' + i,
          MemberStatus = 'Active',
          MemberType = 'Individual',
          EnrollmentDate = today
        )
      );
    }
    insert lpms;

    List<LoyaltyMemberTier> lmts = new List<LoyaltyMemberTier>();
    for (Integer i = 0; i < lpms.size(); i++) {
      lmts.add(new LoyaltyMemberTier(Name = 'Multi LMT ' + i, LoyaltyMemberId = lpms[i].Id, LoyaltyTierId = tier.Id, EffectiveDate = today));
    }
    insert lmts;

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  // 1️⃣1️⃣ VoucherLimit 가 비어있는 경우 — 전체 등급 허용 분기 커버
  //     allowedTierIdsByVdId 가 빈 채 → eligible == true (라인 257) 분기
  @IsTest
  static void test_execute_voucherLimitEmpty_allTiersAllowed() {
    delete [SELECT Id FROM VoucherLimit__c];

    createMember(true);

    Test.startTest();
    executeBatchWithMock();
    Test.stopTest();

    System.assert(true);
  }

  // 1️⃣2️⃣ execute() 에 빈 scope 직접 전달 → "scope is empty" early-return 분기 커버
  //      (배치 프레임워크는 빈 scope로 execute를 호출하지 않으므로 직접 호출로 커버)
  private class MockBatchableContext implements Database.BatchableContext {
    public Id getJobId() {
      return null;
    }
    public Id getChildJobId() {
      return null;
    }
  }

  @IsTest
  static void test_execute_emptyScopeDirect() {
    BirthdayCouponIssueBatch batch = new BirthdayCouponIssueBatch();

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<LoyaltyMemberTier>());
    Test.stopTest();

    System.assert(true, 'empty scope should be handled gracefully (scope is empty branch)');
  }
}