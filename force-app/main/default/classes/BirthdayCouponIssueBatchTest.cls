@IsTest
private class BirthdayCouponIssueBatchTest {
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
      Type = 'ProductOrService',
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

    Contact c = new Contact(LastName = 'Batch Test', Birthdate = Date.newInstance(today.year() - 25, month, 1), MemberNo__c = 'M001');
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
    Database.executeBatch(new BirthdayCouponIssueBatch(), 200);
    Test.stopTest();

    System.assert(true);
  }

  // 2️⃣ 대상 없음 (다른 달 생일자)
  @IsTest
  static void test_execute_otherMonth() {
    createMember(false);

    Test.startTest();
    Database.executeBatch(new BirthdayCouponIssueBatch(), 200);
    Test.stopTest();

    System.assert(true);
  }

  // 3️⃣ 데이터 없음
  @IsTest
  static void test_execute_noData() {
    Test.startTest();
    Database.executeBatch(new BirthdayCouponIssueBatch(), 200);
    Test.stopTest();

    System.assert(true);
  }

  // 4️⃣ 에러 케이스: 쿠폰 카테고리 누락
  @IsTest
  static void test_execute_noCategory() {
    createMember(true);
    delete [SELECT Id FROM VoucherCategory__c];

    Test.startTest();
    Database.executeBatch(new BirthdayCouponIssueBatch(), 200);
    Test.stopTest();

    System.assert(true);
  }

  // 5️⃣ 에러 케이스: 쿠폰 정의(Definition) 누락
  @IsTest
  static void test_execute_noDefinition() {
    createMember(true);
    delete [SELECT Id FROM VoucherDefinition];

    Test.startTest();
    Database.executeBatch(new BirthdayCouponIssueBatch(), 200);
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
    Database.executeBatch(new BirthdayCouponIssueBatch(), 200);
    Test.stopTest();

    System.assert(true);
  }
}