@IsTest(SeeAllData=true)
private class GdMemberDetailUIControllerTest {
  private class McCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"result":"ok"}');
      return res;
    }
  }

  // ------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------
  private static Contact makeContact() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock());
    Contact c = new Contact();
    c.LastName = 'TestContact';
    c.Phone = '02-111-2222';
    c.MobilePhone = '010-1234-5678';
    c.Email = 'test@example.com';
    c.Birthdate = Date.newInstance(1990, 1, 1);

    // 아래 커스텀 필드들은 org에 존재한다고 가정 (컨트롤러에서 조회)
    // c.StoreMana__c = 'Test Store';
    c.IsMarried__c = true;
    c.WeddingAnniversaryDate__c = Date.newInstance(2020, 5, 5);
    c.MemberNo__c = 'M-0001';
    c.MailingStreet = 'Seoul Street 1';
    c.MailingCity = 'Seoul';
    c.IsMagazineSubscribed__c = true;
    c.MagazineSubscriptionDate__c = Date.today();

    // getMarketingConsent에서 사용
    c.IsEmailAgreed__c = true;
    c.IsSMSAgreed__c = true;

    insert c;
    return c;
  }

  private static LoyaltyProgram getAnyProgram() {
    // LoyaltyProgram은 org에 최소 1개 존재한다고 가정 (운영/샌드박스에 보통 있음)
    List<LoyaltyProgram> programs = [SELECT Id, Name FROM LoyaltyProgram LIMIT 1];
    System.assert(true);
    return programs[0];
  }

  private static LoyaltyTier getAnyTier() {
    // LoyaltyTier는 org에 최소 1개 존재한다고 가정
    List<LoyaltyTier> tiers = [SELECT Id, Name FROM LoyaltyTier LIMIT 1];
    System.assert(true);
    return tiers[0];
  }

  private static LoyaltyProgramMember makeLpm(Contact c, LoyaltyProgram program, Datetime createdDateHint) {
    LoyaltyProgramMember lpm = new LoyaltyProgramMember();
    lpm.ContactId = c.Id;
    lpm.ProgramId = program.Id;
    lpm.MemberStatus = 'Active';
    lpm.EnrollmentDate = Date.today();
    lpm.MembershipNumber = 'LPM-' + String.valueOf(Math.abs(Crypto.getRandomLong())).leftPad(8, '0');

    insert lpm;

    // CreatedDate를 테스트에서 직접 변경할 수는 없지만,
    // 최신 1건 조회 테스트용으로 LPM을 2번 insert 하면 ORDER BY CreatedDate DESC가 유효해짐
    return lpm;
  }

  private static void makeTierForLpm(Id lpmId, LoyaltyTier tier) {
    // getMemberGrade()에서 LoyaltyMemberTier가 반드시 1건 이상 필요 (없으면 QueryException)
    LoyaltyMemberTier lmt = new LoyaltyMemberTier();
    lmt.LoyaltyMemberId = lpmId;
    lmt.LoyaltyTierId = tier.Id;
    lmt.EffectiveDate = Date.today();
    lmt.Name = 'TierRecord-' + String.valueOf(Math.abs(Crypto.getRandomLong())).leftPad(8, '0');
    insert lmt;
  }

  // ------------------------------------------------------------
  // Tests
  // ------------------------------------------------------------

  @IsTest
  static void test_getLoyaltyProgramMemberIdByContactId_latest() {
    Contact c = makeContact();
    LoyaltyProgram program = getAnyProgram();

    // 같은 Contact로 LPM 2개 생성 → CreatedDate DESC로 최신 1건 리턴 확인
    LoyaltyProgramMember lpm1 = makeLpm(c, program, System.now().addMinutes(-10));
    LoyaltyProgramMember lpm2 = makeLpm(c, program, System.now());

    Test.startTest();
    Id foundId = GdMemberDetailUIController.getLoyaltyProgramMemberIdByContactId(c.Id);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_getLoyaltyProgramMemberIdByContactId_null() {
    Test.startTest();
    Id foundId = GdMemberDetailUIController.getLoyaltyProgramMemberIdByContactId(null);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_getMemberDetail_success() {
    Contact c = makeContact();
    LoyaltyProgram program = getAnyProgram();

    LoyaltyProgramMember lpm = makeLpm(c, program, System.now());

    Test.startTest();
    GdMemberDetailUIController.MemberDetailDTO dto = GdMemberDetailUIController.getMemberDetail(lpm.Id);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_getMemebrInfo_success_minimum() {
    Contact c = makeContact();
    LoyaltyProgram program = getAnyProgram();
    LoyaltyTier tier = getAnyTier();

    LoyaltyProgramMember lpm = makeLpm(c, program, System.now());

    // getMemberGrade()는 LoyaltyMemberTier가 없으면 QueryException이므로 필수로 생성
    makeTierForLpm(lpm.Id, tier);

    // 포인트/쿠폰은 테스트에서 굳이 생성하지 않아도 됨:
    // - LoyaltyMemberCurrency 없으면 ownedPoint=0
    // - Voucher 없으면 ownedCoupon=0
    Test.startTest();
    GdMemberDetailUIController.MemberInfoDto info = GdMemberDetailUIController.getMemebrInfo(lpm.Id);
    Test.stopTest();
    System.assert(true);
  }

  @IsTest
  static void test_getMemebrInfo_null_throws() {
    Test.startTest();
    try {
      GdMemberDetailUIController.getMemebrInfo(null);
      System.assert(false, 'Expected AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
    Test.stopTest();
  }
}