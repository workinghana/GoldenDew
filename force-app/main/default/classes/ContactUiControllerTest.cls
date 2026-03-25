@IsTest
private class ContactUiControllerTest {
  /* ================= 공통 데이터 생성 ================= */

  private static LoyaltyProgramMember createMember(Boolean withStore) {
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
      Grade__c = '01',
      MailingStreet = '서울시',
      MailingCity = '강남구',
      IsMarried__c = true,
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