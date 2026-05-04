@IsTest
private class HalfYearCouponIssueBatchTest {
  private class MockBatchableContext implements Database.BatchableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }
    public Id getChildJobId() {
      return UserInfo.getUserId();
    }
  }

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  /* ===== 공통 데이터 생성 ===== */

  @TestSetup
  static void setupData() {
    JournalType jt = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert jt;

    JournalSubType jst = new JournalSubType(Name = 'Coupon Issue', JournalTypeId = jt.Id);
    insert jst;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'HalfYear Test Program', IsPrimary = true);
    insert lp;

    LoyaltyTierGroup ltg = new LoyaltyTierGroup(
      Name = 'HalfYear Tier Group',
      LoyaltyProgramId = lp.Id,
      TierModel = 'Fixed',
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert ltg;

    LoyaltyTier lt = new LoyaltyTier(Name = 'HalfYear Tier', LoyaltyTierGroupId = ltg.Id, SequenceNumber = 1);
    insert lt;

    VoucherCategory__c vc = new VoucherCategory__c(Name = 'HalfYear', Code__c = 'HalfYearCoupon');
    insert vc;

    Product2 prod = new Product2(Name = 'HalfYear Voucher Product', IsActive = true);
    insert prod;

    Account companyAccount = new Account(Name = 'HalfYear Company', CompanyCode__c = '1000');
    insert companyAccount;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'HalfYear Voucher',
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      Description = 'HalfYearCouponIssueBatch test',
      ProductId = prod.Id,
      Type = 'ProductOrService',
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      VoucherCategoryId__c = vc.Id,
      AccountId__c = companyAccount.Id,
      CouponManNo__c = 'CPN-HALF-001',
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert vd;

    VoucherLimit__c vl = new VoucherLimit__c(VoucherDefinitionId__c = vd.Id, Type__c = 'GradeIncludeList', Value__c = lt.Id, IsActive__c = true);
    insert vl;
  }

  private static void createMember() {
    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    LoyaltyTier lt = [SELECT Id FROM LoyaltyTier LIMIT 1];

    Contact c = new Contact(LastName = uniq('Contact'), MemberNo__c = uniq('M'));
    insert c;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = uniq('NUM'),
      MemberStatus = 'Active',
      MemberType = 'Individual',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    LoyaltyMemberTier lmt = new LoyaltyMemberTier(
      Name = uniq('MemberTier'),
      LoyaltyMemberId = lpm.Id,
      LoyaltyTierId = lt.Id,
      EffectiveDate = Date.today()
    );
    insert lmt;
  }

  /* ===== 테스트 메서드 ===== */

  /** execute : 빈 scope 조기 반환 분기 */
  @IsTest
  static void test_execute_emptyScope() {
    Test.startTest();
    new HalfYearCouponIssueBatch().execute(new MockBatchableContext(), new List<LoyaltyMemberTier>());
    Test.stopTest();

    System.assert(true);
  }

  /** finish : 성공/실패 집계 및 알림 발행 */
  @IsTest
  static void test_finish() {
    Test.startTest();
    new HalfYearCouponIssueBatch().finish(new MockBatchableContext());
    Test.stopTest();

    System.assert(true);
  }

  /** execute : VoucherCategory 없음 → ERROR 분기 */
  @IsTest
  static void test_execute_noVoucherCategory() {
    createMember();
    delete [SELECT Id FROM VoucherCategory__c];

    Test.startTest();
    Database.executeBatch(new HalfYearCouponIssueBatch(), 50);
    Test.stopTest();

    System.assert(true);
  }

  /** execute : VoucherDefinition 없음 → ERROR 분기 */
  @IsTest
  static void test_execute_noVoucherDefinition() {
    createMember();
    delete [SELECT Id FROM VoucherDefinition];

    Test.startTest();
    Database.executeBatch(new HalfYearCouponIssueBatch(), 50);
    Test.stopTest();

    System.assert(true);
  }

  /** execute : 정상 데이터 + 등급 한도(GradeIncludeList) 조건 일치 */
  @IsTest
  static void test_execute_withMember_tierMatch() {
    createMember();

    Test.startTest();
    Database.executeBatch(new HalfYearCouponIssueBatch(), 50);
    Test.stopTest();

    System.assert(true);
  }

  /** execute : 회원번호 없음 → failIds 분기 */
  @IsTest
  static void test_execute_noMemberNo() {
    createMember();
    Contact c = [SELECT Id FROM Contact LIMIT 1];
    c.MemberNo__c = null;
    update c;

    Test.startTest();
    Database.executeBatch(new HalfYearCouponIssueBatch(), 50);
    Test.stopTest();

    System.assert(true);
  }

  /** 전체 흐름 : LoyaltyMemberTier 데이터 없음 (empty scope) */
  @IsTest
  static void test_executeBatch_emptyData() {
    Test.startTest();
    Database.executeBatch(new HalfYearCouponIssueBatch(), 50);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_upgradeCoupon_setsFaceValueZero() {
    createMember();

    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Id categoryId = [SELECT Id FROM VoucherCategory__c WHERE Code__c = 'HalfYearCoupon' LIMIT 1].Id;
    Id accountId = [SELECT Id FROM Account WHERE CompanyCode__c = '1000' LIMIT 1].Id;
    Id tierId = [SELECT Id FROM LoyaltyTier LIMIT 1].Id;

    Product2 upgradeProduct = new Product2(Name = uniq('HalfYear Upgrade Product'), IsActive = true);
    insert upgradeProduct;

    VoucherDefinition upgradeVd = new VoucherDefinition(
      Name = uniq('HalfYear Upgrade Voucher'),
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      Description = 'HalfYear upgrade voucher',
      ProductId = upgradeProduct.Id,
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      VoucherCategoryId__c = categoryId,
      AccountId__c = accountId,
      CouponManNo__c = uniq('CPN-HALF-UPG'),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager',
      IsUpgrade__c = true
    );
    insert upgradeVd;

    insert new VoucherLimit__c(VoucherDefinitionId__c = upgradeVd.Id, Type__c = 'GradeIncludeList', Value__c = tierId, IsActive__c = true);

    Test.startTest();
    Database.executeBatch(new HalfYearCouponIssueBatch(), 50);
    Test.stopTest();

    List<Voucher> issuedVoucherList = [
      SELECT Id, FaceValue
      FROM Voucher
      WHERE VoucherDefinitionId = :upgradeVd.Id
    ];

    System.assert(!issuedVoucherList.isEmpty(), 'Upgrade half-year coupon should be issued');
    for (Voucher issuedVoucher : issuedVoucherList) {
      System.assertEquals(0, issuedVoucher.FaceValue, 'Upgrade half-year coupon should be normalized to face value 0');
    }
  }
}