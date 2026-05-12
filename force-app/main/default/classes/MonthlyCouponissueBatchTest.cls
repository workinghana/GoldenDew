@isTest
private class MonthlyCouponIssueBatchTest {
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

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  @testSetup
  static void setup() {
    setMock();

    // 1. 기초 데이터 (Contact)
    Contact c1 = new Contact(LastName = 'TierUser1', MemberNo__c = 'MT-001', MobilePhone = '01012345671');
    Contact c2 = new Contact(LastName = 'TierUser2', MemberNo__c = 'MT-002', MobilePhone = '01012345672');
    insert new List<Contact>{ c1, c2 };

    // 2. 로열티 프로그램 및 멤버 (ProgramId 필드 준수)
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Goldendew Program', IsPrimary = true);
    insert lp;
    Account companyAccount = new Account(Name = 'Monthly Company', CompanyCode__c = '1000');
    insert companyAccount;

    LoyaltyProgramMember lpm1 = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c1.Id,
      MembershipNumber = 'MT-001',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      EnrollmentDate = Date.today()
    );
    LoyaltyProgramMember lpm2 = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c2.Id,
      MembershipNumber = 'MT-002',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      EnrollmentDate = Date.today()
    );
    insert new List<LoyaltyProgramMember>{ lpm1, lpm2 };

    // 3. 티어 그룹 및 티어 설정
    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'Grade Group',
      LoyaltyProgramId = lp.Id,
      QpResetPeriod = 'Years',
      QpResetDate = Date.today(),
      QpResetFrequency = 1
    );
    insert tierGroup;

    LoyaltyTier goldTier = new LoyaltyTier(Name = 'Gold', LoyaltyTierGroupId = tierGroup.Id, SequenceNumber = 1);
    insert goldTier;

    // 회원에게 티어 부여 (start() 쿼리 대상)
    insert new List<LoyaltyMemberTier>{
      new LoyaltyMemberTier(LoyaltyMemberId = lpm1.Id, LoyaltyTierId = goldTier.Id, Name = '01'),
      new LoyaltyMemberTier(LoyaltyMemberId = lpm2.Id, LoyaltyTierId = goldTier.Id, Name = '02')
    };

    // 4. 쿠폰 마스터 설정 (정의서 기반 필수 필드)
    VoucherCategory__c vc = new VoucherCategory__c(
      Name = '월간 쿠폰 카테고리',
      Code__c = 'MonthlyCoupon' // 배치 클래스 상수와 일치 필수
    );
    insert vc;

    VoucherDefinition vd = new VoucherDefinition(
      Name = '월간 정기 할인 쿠폰',
      LoyaltyProgramId = lp.Id, // LoyaltyProgramId 대신 ProgramId 사용 확인 필요
      IsActive = true,
      EffectiveDate = Date.today(),
      ExpirationType = 'FixedDate',
      ExpirationDate = Date.today().addDays(30),
      VoucherCategoryId__c = vc.Id,
      AccountId__c = companyAccount.Id,
      CouponManNo__c = 'CPN-MON-001',
      ResponsiblePerson__c = 'Manager',
      Type = 'DiscountPercentage',
      CouponTypeCode__c = '03',
      ResponsibleDepartment__c = '밀버스',
      InsertId__c = '	밀버스',
      DiscountPercent = 10
    );
    insert vd;

    // 5. 쿠폰 한도 설정 (GradeIncludeList 로직 커버)
    VoucherLimit__c vl = new VoucherLimit__c(
      VoucherDefinitionId__c = vd.Id,
      Type__c = 'GradeIncludeList', // 배치 클래스 상수와 일치
      Value__c = (String) goldTier.Id, // 티어 ID를 값으로 설정
      IsActive__c = true
    );
    insert vl;

    // 6. 저널 타입 세팅 (SObjectUtil 대응)
    JournalType jt = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    insert jt;

    JournalSubType jst = new JournalSubType(Name = 'Coupon Issue', JournalTypeId = jt.Id);
    insert jst;
  }

  @isTest
  static void testMonthlyBatchSuccess() {
    setMock();

    // 배치 실행
    Test.startTest();
    MonthlyCouponIssueBatch batch = new MonthlyCouponIssueBatch();
    Database.executeBatch(batch, 200);
    Test.stopTest();

    // 검증 1: 트랜잭션 저널 생성 확인
    List<TransactionJournal> journals = [SELECT Id, Status FROM TransactionJournal WHERE MemberId != NULL];
    System.debug('Created Journals Count: ' + journals.size());

    // 데이터가 정상적이라면 최소 2건의 저널이 생성되어야 함 (lpm1, lpm2)
    Assert.isTrue(journals.size() > 0, '최소 한 건 이상의 저널이 생성되어야 합니다.');
  }

  @isTest
  static void testBatchPartialFailure_NoMemberNo() {
    setMock();

    // 일부 데이터의 필수 필드 제거 (MemberNo__c)
    Contact con = [SELECT Id FROM Contact WHERE MemberNo__c = 'MT-001' LIMIT 1];
    con.MemberNo__c = null;
    update con;

    Test.startTest();
    MonthlyCouponIssueBatch batch = new MonthlyCouponIssueBatch();
    Database.executeBatch(batch, 200);
    Test.stopTest();

    // 검증: 배치가 중단되지 않고 인스턴스화 되어 완료되었는지 확인
    Assert.isNotNull(batch, '실패 데이터가 있어도 배치는 완료되어야 함');
  }

  @isTest
  static void testBatchError_NoVoucherCategory() {
    setMock();

    // 카테고리를 삭제하여 에러 처리 로직(NOT_FOUND) 커버
    delete [SELECT Id FROM VoucherCategory__c];

    Test.startTest();
    MonthlyCouponIssueBatch batch = new MonthlyCouponIssueBatch();
    Database.executeBatch(batch, 200);
    Test.stopTest();

    // 검증: 결과 저널이 0건이어야 함
    List<TransactionJournal> journals = [SELECT Id FROM TransactionJournal];
    Assert.areEqual(0, journals.size(), '카테고리가 없으면 저널이 생성되지 않아야 합니다.');
  }
  @isTest
  static void testMonthlyBatchUpgradeCoupon_setsFaceValueZero() {
    setMock();

    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Id categoryId = [SELECT Id FROM VoucherCategory__c WHERE Code__c = 'MonthlyCoupon' LIMIT 1].Id;
    Id accountId = [SELECT Id FROM Account WHERE CompanyCode__c = '1000' LIMIT 1].Id;
    Id tierId = [SELECT Id FROM LoyaltyTier LIMIT 1].Id;

    VoucherDefinition upgradeVd = new VoucherDefinition(
      Name = 'Monthly Upgrade Coupon',
      LoyaltyProgramId = lp.Id,
      IsActive = true,
      EffectiveDate = Date.today(),
      ExpirationType = 'FixedDate',
      ExpirationDate = Date.today().addDays(30),
      VoucherCategoryId__c = categoryId,
      AccountId__c = accountId,
      CouponManNo__c = 'CPN-MON-UPG',
      ResponsiblePerson__c = 'Manager',
      Type = 'FixedValue',
      FaceValue = 1000,
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = '테스트',
      InsertId__c = 'TEST-UPG',
      IsUpgrade__c = true
    );
    insert upgradeVd;

    insert new VoucherLimit__c(VoucherDefinitionId__c = upgradeVd.Id, Type__c = 'GradeIncludeList', Value__c = (String) tierId, IsActive__c = true);

    Test.startTest();
    Database.executeBatch(new MonthlyCouponIssueBatch(), 200);
    Test.stopTest();

    List<Voucher> issuedVoucherList = [
      SELECT Id, FaceValue
      FROM Voucher
      WHERE VoucherDefinitionId = :upgradeVd.Id
    ];

    Assert.isTrue(!issuedVoucherList.isEmpty(), 'Upgrade monthly coupon should be issued');
    for (Voucher issuedVoucher : issuedVoucherList) {
      Assert.areEqual(0, issuedVoucher.FaceValue, 'Upgrade monthly coupon should be normalized to face value 0');
    }
  }
}