@IsTest
private class MemberDetailUIControllerTest {
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

  private static void setupCalloutMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  /* ============================= */
  private static Contact createContact() {
    setupCalloutMock();

    Contact c = new Contact(
      LastName = 'TEST',
      Phone = '010',
      MobilePhone = '010',
      Email = 'test@test.com',
      Birthdate = Date.today(),
      IsMarried__c = true,
      WeddingAnniversaryDate__c = Date.today(),
      MemberNo__c = 'M-' + Datetime.now().getTime(),
      MailingStreet = '서울',
      MailingCity = '강남',
      IsMagazineSubscribed__c = true,
      MagazineSubscriptionDate__c = Date.today(),
      IsEmailAgreed__c = true,
      IsSMSAgreed__c = false
    );
    insert c;
    return c;
  }

  /* ============================= */
  private static LoyaltyProgram createProgram() {
    List<LoyaltyProgram> lpList = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    if (!lpList.isEmpty())
      return lpList[0];

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP', IsPrimary = true);
    insert lp;
    return lp;
  }

  /* ============================= */
  private static LoyaltyProgramMember createLPM(Id contactId, Id programId) {
    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = contactId,
      ProgramId = programId,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today(),
      MembershipNumber = 'LPM-' + Math.random()
    );
    insert lpm;
    return lpm;
  }

  /* ============================= */
  private static void createCurrency(Id programId, Id lpmId) {
    LoyaltyProgramCurrency cur = new LoyaltyProgramCurrency(
      Name = '포인트',
      LoyaltyProgramId = programId,
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = 'Fixed',
      ExtendExpiration = 'None',
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = 'Months'
    );
    insert cur;

    insert new LoyaltyMemberCurrency(Name = 'TEST', LoyaltyMemberId = lpmId, LoyaltyProgramCurrencyId = cur.Id);
  }

  /* ============================= */
  private static void createVoucher(Id lpmId) {
    insert new Voucher(LoyaltyProgramMemberId = lpmId, Status = 'Issued', EffectiveDate = Date.today());
  }

  /* ============================= */
  // 🔥 기존 createTier(Id) 삭제하고 이것만 사용
  private static void createTier(Id lpmId, Id programId) {
    // Tier Group
    LoyaltyTierGroup tg = new LoyaltyTierGroup(
      Name = 'TEST GROUP',
      LoyaltyProgramId = programId,
      TierModel = 'Fixed',
      TierPeriodUnit = 'Years',
      TierPeriodQuantity = 1,
      ExtendExpiration = 'QualifyingPointsResetDate',
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tg;

    // Tier
    LoyaltyTier tier = new LoyaltyTier(Name = 'VIP', LoyaltyTierGroupId = tg.Id);
    insert tier;

    // Member Tier
    insert new LoyaltyMemberTier(Name = 'TEST MEMBER TIER', LoyaltyMemberId = lpmId, LoyaltyTierId = tier.Id, EffectiveDate = Date.today());
  }

  /* ============================= */
  private static void createTransaction(Id lpmId) {
    // 1️⃣ Account 생성
    Account acc = new Account(Name = 'TEST ACCOUNT');
    insert acc;

    // 2️⃣ Order 생성 (🔥 AccountId 추가)
    Order o = new Order(
      Name = 'TEST ORDER',
      EffectiveDate = Date.today(),
      Status = 'Draft',
      AccountId = acc.Id // 🔥 핵심
    );
    insert o;

    // 3️⃣ Transaction 생성
    insert new TransactionJournal(MemberId = lpmId, Status = 'Processed', TransactionAmount = 1000, ActivityDate = Datetime.now(), OrderId = o.Id);
  }

  /* ============================= */
  @IsTest
  static void test_getMemberDetail() {
    Contact c = createContact();
    LoyaltyProgram lp = createProgram();
    LoyaltyProgramMember lpm = createLPM(c.Id, lp.Id);

    Test.startTest();
    MemberDetailUIController.MemberDetailDTO dto = MemberDetailUIController.getMemberDetail(lpm.Id);
    Test.stopTest();

    System.assert(dto != null);
    System.assert(dto.name != null);
  }

  /* ============================= */
  @IsTest
  static void test_getMemberInfo_FULL() {
    Contact c = createContact();
    LoyaltyProgram lp = createProgram();
    LoyaltyProgramMember lpm = createLPM(c.Id, lp.Id);

    createCurrency(lp.Id, lpm.Id);
    createVoucher(lpm.Id);
    createTier(lpm.Id, lp.Id); // 🔥 반드시 이렇게 호출
    createTransaction(lpm.Id);

    Test.startTest();
    MemberDetailUIController.MemberInfoDto res = MemberDetailUIController.getMemebrInfo(lpm.Id);
    Test.stopTest();

    System.assert(res != null);
    System.assert(res.benefit != null);
    System.assert(res.grade != null);
    System.assert(res.marketing != null);
  }

  /* ============================= */
  @IsTest
  static void test_getMemberInfo_null() {
    Boolean isError = false;

    Test.startTest();
    try {
      MemberDetailUIController.getMemebrInfo(null);
    } catch (Exception e) {
      isError = true;
    }
    Test.stopTest();

    System.assert(isError);
  }
}
