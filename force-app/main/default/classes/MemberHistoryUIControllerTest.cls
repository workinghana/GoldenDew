@IsTest
private class MemberHistoryUIControllerTest {
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

  @TestSetup
  static void setupData() {
    setMock();

    Contact contactRecord = new Contact(LastName = 'HistoryUI', Email = 'old@test.com', Phone = '01012345678');
    insert contactRecord;

    LoyaltyProgram program = new LoyaltyProgram(Name = 'UI Program', IsPrimary = true);
    insert program;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ContactId = contactRecord.Id,
      ProgramId = program.Id,
      MembershipNumber = 'UI-001',
      EnrollmentDate = Date.today(),
      MemberStatus = 'Active'
    );
    insert member;

    contactRecord.Phone = '01099998888';
    update contactRecord;

    contactRecord.Email = 'updated@test.com';
    update contactRecord;
  }

  @IsTest
  static void test_getMemberHistory() {
    setMock();

    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;

    Test.startTest();
    List<MemberHistoryUIController.MemberChangeHistoryDTO> result = MemberHistoryUIController.getMemberHistory(lpmId);
    Test.stopTest();

    System.assertNotEquals(null, result);
  }

  @IsTest
  static void test_convertFieldLabel_blank() {
    String expected = '해당 변경 라벨을 찾을 수 없음';

    System.assertEquals(expected, MemberHistoryUIController.convertFieldLabel(null));
    System.assertEquals(expected, MemberHistoryUIController.convertFieldLabel(''));
    System.assertEquals(expected, MemberHistoryUIController.convertFieldLabel('   '));
  }

  @IsTest
  static void test_convertFieldLabel_map() {
    System.assertEquals('회원 생성', MemberHistoryUIController.convertFieldLabel('created'));
    System.assertEquals('첫 주문 일자', MemberHistoryUIController.convertFieldLabel('FirstPurchaseDate__c'));
    System.assertEquals('마지막 주문 일자', MemberHistoryUIController.convertFieldLabel('LastPurchaseDate__c'));
  }

  @IsTest
  static void test_convertFieldLabel_contactField() {
    System.assertNotEquals(null, MemberHistoryUIController.convertFieldLabel('Email'));
  }

  @IsTest
  static void test_convertFieldLabel_lpmField() {
    System.assertNotEquals(null, MemberHistoryUIController.convertFieldLabel('MemberStatus'));
  }

  @IsTest
  static void test_convertFieldLabel_unknown() {
    System.assertEquals('해당 변경 라벨을 찾을 수 없음', MemberHistoryUIController.convertFieldLabel('UnknownField__c'));
  }

  @IsTest
  static void test_formatValue() {
    String formatted = MemberHistoryUIController.formatValue('del_20250101_010101_del_20250102_020202_email@test.com');
    System.assert(formatted.contains('\n_del_'));

    System.assertEquals('test@test.com', MemberHistoryUIController.formatValue('test@test.com'));
  }

  @IsTest
  static void test_formatValue_blank() {
    System.assertEquals('', MemberHistoryUIController.formatValue(null));
    System.assertEquals('', MemberHistoryUIController.formatValue(''));
  }

  @IsTest
  static void test_formatValue_dateField_removesTime() {
    System.assertEquals('2025-01-01', MemberHistoryUIController.formatValue('Birthdate', Datetime.newInstanceGmt(2025, 1, 1, 12, 34, 56)));
    System.assertEquals('2025-01-02', MemberHistoryUIController.formatValue('Birthdate', '2025-01-02 12:34:56'));
  }

  @IsTest
  static void test_shouldIncludeHistory() {
    System.assertEquals(false, MemberHistoryUIController.shouldIncludeHistory('', ''));
    System.assertEquals(false, MemberHistoryUIController.shouldIncludeHistory('same', 'same'));
    System.assertEquals(true, MemberHistoryUIController.shouldIncludeHistory('old', 'new'));
    System.assertEquals(true, MemberHistoryUIController.shouldIncludeHistory('', 'new'));
  }

  @IsTest
  static void test_convertPicklistValueToLabel_picklist() {
    Schema.DescribeFieldResult fieldDescribe = findFieldByType(Schema.DisplayType.Picklist);

    System.assertNotEquals(null, fieldDescribe);
    System.assert(!fieldDescribe.getPicklistValues().isEmpty());

    Schema.PicklistEntry entry = fieldDescribe.getPicklistValues()[0];
    String converted = MemberHistoryUIController.convertPicklistValueToLabel(fieldDescribe.getName(), entry.getValue());

    System.assertEquals(entry.getLabel(), converted);
  }

  @IsTest
  static void test_convertPicklistValueToLabel_multiPicklist() {
    Schema.DescribeFieldResult fieldDescribe = findFieldByType(Schema.DisplayType.MultiPicklist);

    if (fieldDescribe == null || fieldDescribe.getPicklistValues().size() < 2) {
      return;
    }

    String rawValue = fieldDescribe.getPicklistValues()[0].getValue() + ';' + fieldDescribe.getPicklistValues()[1].getValue();
    String converted = MemberHistoryUIController.convertPicklistValueToLabel(fieldDescribe.getName(), rawValue);

    System.assertEquals(fieldDescribe.getPicklistValues()[0].getLabel() + ';' + fieldDescribe.getPicklistValues()[1].getLabel(), converted);
  }

  @IsTest
  static void test_convertPicklistValueToLabel_unknownAndBlank() {
    System.assertEquals('', MemberHistoryUIController.convertPicklistValueToLabel('Email', ''));
    System.assertEquals('raw', MemberHistoryUIController.convertPicklistValueToLabel('UnknownField__c', 'raw'));
    System.assertEquals('raw', MemberHistoryUIController.convertPicklistValueToLabel('Email', 'raw'));
  }

  @IsTest
  static void test_formatValue_withFieldApiName() {
    Schema.DescribeFieldResult fieldDescribe = findFieldByType(Schema.DisplayType.Picklist);

    System.assertNotEquals(null, fieldDescribe);
    System.assert(!fieldDescribe.getPicklistValues().isEmpty());

    Schema.PicklistEntry entry = fieldDescribe.getPicklistValues()[0];
    String formatted = MemberHistoryUIController.formatValue(fieldDescribe.getName(), entry.getValue());

    System.assertEquals(entry.getLabel(), formatted);
  }

  @IsTest
  static void test_buildHistoryDto_changedValue() {
    MemberHistoryUIController.MemberChangeHistoryDTO dto = MemberHistoryUIController.buildHistoryDto(
      Datetime.newInstance(2025, 1, 1, 0, 0, 0),
      'member',
      'Email',
      'old@test.com',
      'new@test.com',
      'tester'
    );

    System.assertNotEquals(null, dto);
    System.assertEquals('member', dto.objectType);
    System.assertEquals(MemberHistoryUIController.convertFieldLabel('Email'), dto.fieldName);
    System.assertEquals('old@test.com', dto.oldValue);
    System.assertEquals('new@test.com', dto.newValue);
    System.assertEquals('tester', dto.changedBy);
  }

  @IsTest
  static void test_buildHistoryDto_unchangedValue() {
    MemberHistoryUIController.MemberChangeHistoryDTO dto = MemberHistoryUIController.buildHistoryDto(
      Datetime.now(),
      'member',
      'Email',
      'same@test.com',
      'same@test.com',
      'tester'
    );

    System.assertEquals(null, dto);
  }

  @IsTest
  static void test_buildHistoryDto_blankValue() {
    MemberHistoryUIController.MemberChangeHistoryDTO dto = MemberHistoryUIController.buildHistoryDto(
      Datetime.now(),
      'member',
      'Email',
      null,
      '',
      'tester'
    );

    System.assertEquals(null, dto);
  }

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

  @IsTest
  static void test_comparator_equal() {
    Datetime sameTime = Datetime.newInstance(2025, 1, 1, 0, 0, 0);

    MemberHistoryUIController.MemberChangeHistoryDTO a = new MemberHistoryUIController.MemberChangeHistoryDTO();
    a.changeDate = sameTime;

    MemberHistoryUIController.MemberChangeHistoryDTO b = new MemberHistoryUIController.MemberChangeHistoryDTO();
    b.changeDate = sameTime;

    Integer result = new MemberHistoryUIController.ChangeDateDescComparator().compare(a, b);
    System.assertEquals(0, result);
  }

  @IsTest
  static void test_comparator_reverse() {
    MemberHistoryUIController.MemberChangeHistoryDTO newer = new MemberHistoryUIController.MemberChangeHistoryDTO();
    newer.changeDate = Datetime.newInstance(2025, 1, 1, 0, 0, 0);

    MemberHistoryUIController.MemberChangeHistoryDTO older = new MemberHistoryUIController.MemberChangeHistoryDTO();
    older.changeDate = Datetime.newInstance(2024, 1, 1, 0, 0, 0);

    Integer result = new MemberHistoryUIController.ChangeDateDescComparator().compare(newer, older);
    System.assertEquals(-1, result);
  }

  @IsTest
  static void test_comparator_nullDate() {
    MemberHistoryUIController.MemberChangeHistoryDTO noDate = new MemberHistoryUIController.MemberChangeHistoryDTO();
    MemberHistoryUIController.MemberChangeHistoryDTO withDate = new MemberHistoryUIController.MemberChangeHistoryDTO();
    withDate.changeDate = Datetime.newInstance(2025, 1, 1, 0, 0, 0);

    Integer result = new MemberHistoryUIController.ChangeDateDescComparator().compare(noDate, withDate);
    System.assertEquals(1, result);
  }

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

  private static Schema.DescribeFieldResult findFieldByType(Schema.DisplayType displayType) {
    Schema.DescribeFieldResult fieldDescribe = findFieldByType(Contact.SObjectType, displayType);
    if (fieldDescribe != null) {
      return fieldDescribe;
    }

    return findFieldByType(LoyaltyProgramMember.SObjectType, displayType);
  }

  private static Schema.DescribeFieldResult findFieldByType(Schema.SObjectType objectType, Schema.DisplayType displayType) {
    for (Schema.SObjectField fieldToken : objectType.getDescribe().fields.getMap().values()) {
      Schema.DescribeFieldResult fieldDescribe = fieldToken.getDescribe();
      if (fieldDescribe.getType() == displayType && !fieldDescribe.getPicklistValues().isEmpty()) {
        return fieldDescribe;
      }
    }

    return null;
  }
}