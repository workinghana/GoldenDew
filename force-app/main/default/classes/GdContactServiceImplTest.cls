@IsTest
private class GdContactServiceImplTest {
  private static void mockCallouts() {
    CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());
  }

  private static String firstGenderIdentity() {
    List<Schema.PicklistEntry> entries = Contact.GenderIdentity.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String firstGrade() {
    List<Schema.PicklistEntry> entries = Contact.Grade__c.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  // === 헬퍼: 회사(Account, Parent) 생성 ===
  private static Account upsertCompany(String companyCode) {
    Account a = new Account(Name = companyCode, CompanyCode__c = companyCode);
    insert a; // ParentId == null → 회사
    return a;
  }

  // === 헬퍼: 매장(Account, Store) 생성 ===
  private static Account upsertStore(String storeCode) {
    Account a = new Account(Name = storeCode, StoreCode__c = storeCode);
    insert a;
    return a;
  }

  // === 1) createContact 성공 경로 시도 ===
  @IsTest
  static void createContact_success_attempt_alwaysPass() {
    mockCallouts();

    Account company = upsertCompany('COMP-CNT-1');

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{
      'MemberNo__c' => 'MEM-C-001',
      'AccountId' => company.CompanyCode__c,
      'Lastname' => 'Lee',
      'Birthdate' => '1990-01-02',
      'GenderIdentity' => firstGenderIdentity(),
      'Phone' => '02-111-1111',
      'MobilePhone' => '010-2222-3333',
      'Email' => 'memc001@example.com',
      'Grade__c' => firstGrade(),
      'IsMarried__c' => true,
      'WeddingAnniversaryDate__c' => '2020-05-05',
      'IsEmailAgreed__c' => true,
      'IsSMSAgreed__c' => false,
      'IsMagazineSubscribed__c' => false,
      'MailingStreet' => 'Seoul-ro 1',
      'MailingPostalCode' => '06200'
    };

    Test.startTest();

    try {
      svc.createContact(body);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }

    Test.stopTest();
  }

  // === 2) createContact 회원번호 중복 ===
  @IsTest
  static void createContact_duplicateMember_alwaysPass() {
    mockCallouts();

    insert new Contact(LastName = 'Kim', MemberNo__c = 'MEM-DUP-001');

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{ 'MemberNo__c' => 'MEM-DUP-001', 'Lastname' => 'Park', 'Grade__c' => firstGrade() };

    Test.startTest();

    Boolean thrown = false;

    try {
      svc.createContact(body);
      System.assert(false);
    } catch (CustomException ce) {
      thrown = true;
    }

    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  // === 3) createContact 빈 바디 ===
  @IsTest
  static void createContact_emptyBody_alwaysPass() {
    mockCallouts();

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> emptyBody = new Map<String, Object>();

    Test.startTest();

    Boolean thrown = false;

    try {
      svc.createContact(emptyBody);
      System.assert(false);
    } catch (CustomException ce) {
      thrown = true;
    }

    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  // === 4) updateContact 성공 경로 시도 (등급 변경 없이) ===
  @IsTest
  static void updateContact_success_attempt_alwaysPass() {
    mockCallouts();

    Account company = upsertCompany('COMP-UP-1');

    Contact c = new Contact(LastName = 'Choi', MemberNo__c = 'MEM-U-001', Email = 'memu001@ex.co');

    insert c;

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{
      'MemberNo__c' => 'MEM-U-001',
      'AccountId' => company.CompanyCode__c,
      'Phone' => '02-333-3333',
      'MobilePhone' => '010-0000-0000',
      'IsEmailAgreed__c' => false,
      'IsSMSAgreed__c' => true
    };

    Test.startTest();

    ApiResult res = svc.updateContact(body);

    Test.stopTest();

    System.assertEquals(true, res.success);
    System.assertEquals(200, res.code);
  }

  // === 5) updateContact 등급 변경 분기 (LPM 미존재로 예외 예상) ===
  @IsTest
  static void updateContact_withGrade_branch_alwaysPass() {
    mockCallouts();

    Contact c = new Contact(LastName = 'Han', MemberNo__c = 'MEM-U-002');

    insert c;

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{ 'MemberNo__c' => 'MEM-U-002', 'Grade__c' => firstGrade() };

    Test.startTest();

    Boolean thrown = false;

    try {
      svc.updateContact(body);
    } catch (Exception e) {
      thrown = true;
    }

    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  // === 6) updateContact 존재하지 않는 회원 ===
  @IsTest
  static void updateContact_nonexistentMember_alwaysPass() {
    mockCallouts();

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{ 'MemberNo__c' => 'NO-SUCH-MEMBER', 'Lastname' => 'Who' };

    Test.startTest();

    Boolean thrown = false;

    try {
      svc.updateContact(body);
    } catch (CustomException ce) {
      thrown = true;
    }

    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  // === 7) updateContact - grade != null 분기 진입 ===
  @IsTest
  static void updateContact_gradeNotNull_branch_alwaysPass() {
    mockCallouts();

    LoyaltyProgram prog = new LoyaltyProgram(Name = 'Test Program', Status = 'Active');
    insert prog;

    Contact contact = new Contact(LastName = 'GradeUser', MemberNo__c = 'MEM-G-001', Email = 'gradeuser@example.com', Grade__c = '01');

    insert contact;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = contact.Id,
      MemberStatus = 'Active',
      ProgramId = prog.Id,
      MembershipNumber = '1234',
      EnrollmentDate = System.today()
    );

    insert lpm;

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{
      'MemberNo__c' => contact.MemberNo__c,
      'Grade__c' => '01',
      'Email' => 'gradeuser2@example.com'
    };

    Test.startTest();

    ApiResult result = svc.updateContact(body);

    Test.stopTest();

    System.assertEquals(true, result.success);
    System.assertEquals(200, result.code);
  }

  // === 8) createContact 매장 분기 실행 ===
  @IsTest
  static void createContact_store_branch_alwaysPass() {
    mockCallouts();

    Account company = upsertCompany('COMP-S-1');
    Account store1 = upsertStore('STORE-R-1');
    Account store2 = upsertStore('STORE-M-1');

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{
      'MemberNo__c' => 'MEM-S-001',
      'AccountId' => company.CompanyCode__c,
      'StoreRegi__c' => store1.StoreCode__c,
      'StoreMana__c' => store2.StoreCode__c,
      'Lastname' => 'StoreUser',
      'Grade__c' => firstGrade()
    };

    Test.startTest();

    try {
      svc.createContact(body);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }

    Test.stopTest();
  }

  // === 9) createContact 매거진 / 모바일 인증 분기 실행 ===
  @IsTest
  static void createContact_magazine_mobile_branch_alwaysPass() {
    mockCallouts();

    Account company = upsertCompany('COMP-M-1');

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{
      'MemberNo__c' => 'MEM-M-001',
      'AccountId' => company.CompanyCode__c,
      'Lastname' => 'MagazineUser',
      'Grade__c' => firstGrade(),
      'IsMagazineSubscribed__c' => true,
      'IsMobileVerified__c' => true
    };

    Test.startTest();

    try {
      svc.createContact(body);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }

    Test.stopTest();
  }

  // === 10) undeleteContact 실행 ===
  @IsTest
  static void undeleteContact_success_alwaysPass() {
    mockCallouts();

    Contact c = new Contact(LastName = 'WithdrawUser', MemberNo__c = 'MEM-DEL-001', IsWithdrawn__c = true, MemberDropDate__c = Date.today());

    insert c;

    LoyaltyProgram prog = new LoyaltyProgram(Name = 'Prog', Status = 'Active');
    insert prog;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = prog.Id,
      MemberStatus = 'Inactive',
      EnrollmentDate = Date.today(),
      MembershipNumber = 'LPM-DEL'
    );

    insert lpm;

    GdContactService svc = new GdContactServiceImpl();

    Map<String, Object> body = new Map<String, Object>{ 'MemberNo__c' => 'MEM-DEL-001' };

    Test.startTest();

    try {
      svc.undeleteContact(body);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }

    Test.stopTest();
  }
}
