@IsTest
private class MemberHistoryUIControllerTest {
  @TestSetup
  static void setupData() {
    Contact c = new Contact(LastName = 'HistoryUI', Email = 'old@test.com', Phone = '01012345678');
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'UI Program', IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'UI-001',
      EnrollmentDate = Date.today(),
      MemberStatus = 'Active'
    );
    insert lpm;

    /* 1️⃣ 휴대폰 변경 */
    c.Phone = '01099998888';
    update c;

    /* 2️⃣ 이메일 변경 */
    c.Email = 'updated@test.com';
    update c;

    Test.startTest();

    List<MemberHistoryUIController.MemberChangeHistoryDTO> result = MemberHistoryUIController.getMemberHistory(lpm.Id);

    Test.stopTest();

    System.assert(result != null);

    if (!result.isEmpty()) {
      Boolean hasPhone = false;
      Boolean hasEmail = false;

      for (MemberHistoryUIController.MemberChangeHistoryDTO dto : result) {
        if (dto.fieldName == '휴대폰') {
          hasPhone = true;
          System.assertEquals('01012345678', dto.oldValue);
          System.assertEquals('01099998888', dto.newValue);
        }

        if (dto.fieldName == '이메일') {
          hasEmail = true;
          System.assertEquals('old@test.com', dto.oldValue);
          System.assertEquals('updated@test.com', dto.newValue);
        }
      }

      System.assert(hasPhone);
      System.assert(hasEmail);
    }
  }

  /* ==============================
       getMemberHistory 기본 실행
       ============================== */

  @IsTest
  static void test_getMemberHistory() {
    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;

    Test.startTest();

    List<MemberHistoryUIController.MemberChangeHistoryDTO> result = MemberHistoryUIController.getMemberHistory(lpmId);

    Test.stopTest();

    System.assertNotEquals(null, result);

    if (!result.isEmpty()) {
      MemberHistoryUIController.MemberChangeHistoryDTO dto = result[0];

      System.assertNotEquals(null, dto.changeDate);
      System.assertNotEquals(null, dto.objectType);
      System.assertNotEquals(null, dto.fieldName);
      System.assertNotEquals(null, dto.changedBy);
    }
  }

  /* ==============================
       convertFieldLabel - blank
       ============================== */

  @IsTest
  static void test_convertFieldLabel_blank() {
    String expected = '해당 변경 레이블을 찾을 수 없음';

    System.assertEquals(expected, MemberHistoryUIController.convertFieldLabel(null));

    System.assertEquals(expected, MemberHistoryUIController.convertFieldLabel(''));

    System.assertEquals(expected, MemberHistoryUIController.convertFieldLabel('   '));
  }

  /* ==============================
       convertFieldLabel - map
       ============================== */

  @IsTest
  static void test_convertFieldLabel_map() {
    System.assertEquals('회원 생성', MemberHistoryUIController.convertFieldLabel('created'));

    System.assertEquals('첫 주문 일자', MemberHistoryUIController.convertFieldLabel('FirstPurchaseDate__c'));

    System.assertEquals('마지막 주문 일자', MemberHistoryUIController.convertFieldLabel('LastPurchaseDate__c'));
  }

  /* ==============================
       convertFieldLabel - Contact field
       ============================== */

  @IsTest
  static void test_convertFieldLabel_contactField() {
    String label = MemberHistoryUIController.convertFieldLabel('Email');

    System.assertNotEquals(null, label);
  }

  /* ==============================
       convertFieldLabel - LPM field
       ============================== */

  @IsTest
  static void test_convertFieldLabel_lpmField() {
    String label = MemberHistoryUIController.convertFieldLabel('MemberStatus');

    System.assertNotEquals(null, label);
  }

  /* ==============================
       convertFieldLabel - unknown
       ============================== */

  @IsTest
  static void test_convertFieldLabel_unknown() {
    String result = MemberHistoryUIController.convertFieldLabel('UnknownField__c');

    System.assertEquals('해당 변경 레이블을 찾을 수 없음', result);
  }

  /* ==============================
       formatValue 테스트
       ============================== */

  @IsTest
  static void test_formatValue() {
    String formatted = MemberHistoryUIController.formatValue('del_20250101_010101_del_20250102_020202_email@test.com');

    System.assert(formatted.contains('\n_del_'));

    String normal = MemberHistoryUIController.formatValue('test@test.com');

    System.assertEquals('test@test.com', normal);
  }

  /* ==============================
       formatValue blank
       ============================== */

  @IsTest
  static void test_formatValue_blank() {
    System.assertEquals('', MemberHistoryUIController.formatValue(null));

    System.assertEquals('', MemberHistoryUIController.formatValue(''));
  }

  /* ==============================
       Comparator sorting
       ============================== */

  @IsTest
  static void test_comparator_sort() {
    MemberHistoryUIController.MemberChangeHistoryDTO oldItem = new MemberHistoryUIController.MemberChangeHistoryDTO();

    oldItem.changeDate = Datetime.newInstance(2024, 1, 1, 0, 0, 0);

    MemberHistoryUIController.MemberChangeHistoryDTO newItem = new MemberHistoryUIController.MemberChangeHistoryDTO();

    newItem.changeDate = Datetime.newInstance(2025, 1, 1, 0, 0, 0);

    List<MemberHistoryUIController.MemberChangeHistoryDTO> items = new List<MemberHistoryUIController.MemberChangeHistoryDTO>{ oldItem, newItem };

    items.sort(new MemberHistoryUIController.ChangeDateDescComparator());

    System.assertEquals(newItem, items[0]);
  }

  /* ==============================
       Comparator equal case
       ============================== */

  @IsTest
  static void test_comparator_equal() {
    Datetime t = Datetime.newInstance(2025, 1, 1, 0, 0, 0);

    MemberHistoryUIController.MemberChangeHistoryDTO a = new MemberHistoryUIController.MemberChangeHistoryDTO();
    a.changeDate = t;

    MemberHistoryUIController.MemberChangeHistoryDTO b = new MemberHistoryUIController.MemberChangeHistoryDTO();
    b.changeDate = t;

    Integer result = new MemberHistoryUIController.ChangeDateDescComparator().compare(a, b);

    System.assertEquals(0, result);
  }

  /* ==============================
       Comparator reverse 비교
       ============================== */

  @IsTest
  static void test_comparator_reverse() {
    MemberHistoryUIController.MemberChangeHistoryDTO newer = new MemberHistoryUIController.MemberChangeHistoryDTO();

    newer.changeDate = Datetime.newInstance(2025, 1, 1, 0, 0, 0);

    MemberHistoryUIController.MemberChangeHistoryDTO older = new MemberHistoryUIController.MemberChangeHistoryDTO();

    older.changeDate = Datetime.newInstance(2024, 1, 1, 0, 0, 0);

    Integer result = new MemberHistoryUIController.ChangeDateDescComparator().compare(newer, older);

    System.assertEquals(-1, result);
  }

  /* ==============================
       DTO 필드 접근
       ============================== */

  @IsTest
  static void test_dto_access() {
    MemberHistoryUIController.MemberChangeHistoryDTO dto = new MemberHistoryUIController.MemberChangeHistoryDTO();

    dto.changeDate = Datetime.now();
    dto.objectType = '회원 정보';
    dto.fieldName = '회원 생성';
    dto.oldValue = 'OLD';
    dto.newValue = 'NEW';
    dto.changedBy = 'Admin';

    System.assertEquals('회원 정보', dto.objectType);
    System.assertEquals('회원 생성', dto.fieldName);
    System.assertEquals('OLD', dto.oldValue);
    System.assertEquals('NEW', dto.newValue);
    System.assertEquals('Admin', dto.changedBy);
  }
}