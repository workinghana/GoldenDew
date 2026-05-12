@IsTest
private class ContactUiControllerTest {
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

  private static void setCalloutMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  /* ================= 공통 데이터 생성 ================= */

  private static LoyaltyProgramMember createMember(Boolean withStore) {
    setCalloutMock();

    Account store = null;

    if (withStore) {
      store = new Account(Name = '강남점');
      insert store;
    }

    Contact c = new Contact(
      LastName = '홍길동',
      MobilePhone = '010-1111-2222',
      Email = 'test@test.com',
      Birthdate = Date.newInstance(1990, 1, 1),
      LegalBirthdate__c = '900101',
      Grade__c = '01',
      MailingStreet = '서울시',
      MailingCity = '강남구',
      IsMarried__c = true,
      TierQualifyingSpend3Y__c = 1500000,
      StoreMana__c = withStore ? store.Id : null,
      StoreRegi__c = withStore ? store.Id : null
    );
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Test Program', Status = 'Active');
    insert lp;

    String validStatus = LoyaltyProgramMember.MemberStatus.getDescribe().getPicklistValues()[0].getValue();

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'TEST-001',
      EnrollmentDate = Date.today(),
      MemberStatus = validStatus
    );

    insert lpm;

    return lpm;
  }

  /* ================= 정상 케이스 ================= */

  @IsTest
  static void test_getMemberProfile_success() {
    LoyaltyProgramMember lpm = createMember(true);

    Test.startTest();

    ContactUiController.MemberProfileDTO dto = ContactUiController.getMemberProfile(lpm.Id);

    Test.stopTest();

    System.assertEquals('홍길동', dto.name);
    System.assertEquals('GIP', dto.grade);
    System.assertEquals(true, dto.isMarried);

    /* 매장 이름 검증 */
    System.assertEquals('강남점', dto.storeName);
    System.assertEquals('강남점', dto.signupStore);

    /* 법정생년월일 검증 */
    System.assertEquals('900101', dto.legalBirthdate);

    /* 등급 산정 누적 구매금액 검증 */
    System.assertEquals(1500000, dto.tierQualifyingSpend3Y);
  }

  /* ================= 매장 없는 경우 ================= */

  @IsTest
  static void test_getMemberProfile_without_store() {
    LoyaltyProgramMember lpm = createMember(false);

    ContactUiController.MemberProfileDTO dto = ContactUiController.getMemberProfile(lpm.Id);

    System.assertEquals(null, dto.storeName);
    System.assertEquals(null, dto.signupStore);
  }

  /* ================= null id ================= */

  @IsTest
  static void test_getMemberProfile_nullId() {
    setCalloutMock();

    try {
      ContactUiController.getMemberProfile(null);
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assert(true);
    }
  }

  /* ================= helper 메소드 ================= */

  @IsTest
  static void test_internal_helpers() {
    System.assertEquals('GIP', ContactUiController.getGradeLabel('01'));

    System.assertEquals('UNKNOWN', ContactUiController.getGradeLabel('UNKNOWN'));

    System.assertEquals(null, ContactUiController.getGradeLabel(null));

    Contact c = new Contact(MailingStreet = '서울', MailingCity = '강남');

    System.assertEquals('서울 강남', ContactUiController.buildAddress(c));

    System.assertEquals('', ContactUiController.buildAddress(new Contact()));

    System.assertEquals(null, ContactUiController.buildAddress(null));

    /* getMemberTypeLabel — null/blank */
    System.assertEquals(null, ContactUiController.getMemberTypeLabel(null));
    System.assertEquals(null, ContactUiController.getMemberTypeLabel(''));

    /* getMemberTypeLabel — 매핑 안되는 코드는 그대로 반환 */
    System.assertEquals('UNKNOWN_CODE', ContactUiController.getMemberTypeLabel('UNKNOWN_CODE'));
  }

  /* ================= 법정생년월일 빈 값 ================= */

  @IsTest
  static void test_getMemberProfile_blankLegalBirthdate() {
    setCalloutMock();

    Contact c = new Contact(LastName = '미입력', LegalBirthdate__c = null);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Blank LB Program', Status = 'Active');
    insert lp;

    String validStatus = LoyaltyProgramMember.MemberStatus.getDescribe().getPicklistValues()[0].getValue();

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'BLANK-LB-001',
      EnrollmentDate = Date.today(),
      MemberStatus = validStatus
    );
    insert lpm;

    ContactUiController.MemberProfileDTO dto = ContactUiController.getMemberProfile(lpm.Id);

    System.assertEquals(null, dto.legalBirthdate);
  }

  /* ================= DTO null 경로 ================= */

  @IsTest
  static void test_memberProfileDTO_null() {
    ContactUiController.MemberProfileDTO dto = new ContactUiController.MemberProfileDTO(null);

    System.assertEquals(null, dto.enrollmentDate);
    System.assertEquals(null, dto.memberStatus);
  }

  /* ================= email 변환 로직 ================= */

  @IsTest
  static void test_email_del_prefix() {
    setCalloutMock();

    Account store = new Account(Name = '테스트매장');
    insert store;

    Contact c = new Contact(
      LastName = '삭제메일',
      Email = 'del_20251104_181545_del_20251030_013507_email@test.com',
      IsWithdrawn__c = false,
      StoreMana__c = store.Id,
      StoreRegi__c = store.Id
    );
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Email Program', Status = 'Active');
    insert lp;

    String validStatus = LoyaltyProgramMember.MemberStatus.getDescribe().getPicklistValues()[0].getValue();

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'EMAIL-001',
      EnrollmentDate = Date.today(),
      MemberStatus = validStatus
    );

    insert lpm;

    ContactUiController.MemberProfileDTO dto = ContactUiController.getMemberProfile(lpm.Id);

    System.assertEquals('del_20251104_181545_del_20251030_013507_email@test.com', dto.email);
  }
}