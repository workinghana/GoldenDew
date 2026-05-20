@IsTest
private class GdMemberHistoryUIControllerTest {
  private class McCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"result":"ok"}');
      return res;
    }
  }

  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock());

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'History Program', IsPrimary = true);
    insert lp;

    Contact c = new Contact(LastName = 'HistoryUser', MemberNo__c = 'MH-001');
    insert c;

    LoyaltyProgramMember withContact = new LoyaltyProgramMember(
      MembershipNumber = 'MH-001',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = c.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert withContact;

    withContact.MemberStatus = 'Inactive';
    update withContact;

    c.Phone = '010-1234-5678';
    update c;

  }

  @IsTest
  static void getMemberHistory_withContact_returnsList() {
    Id lpmId = [
      SELECT Id
      FROM LoyaltyProgramMember
      WHERE MembershipNumber = 'MH-001'
      LIMIT 1
    ].Id;

    Test.startTest();
    List<GdMemberHistoryUIController.MemberChangeHistoryDTO> rows =
      GdMemberHistoryUIController.getMemberHistory(lpmId);
    Test.stopTest();

    System.assertNotEquals(null, rows);
  }

  @IsTest
  static void getMemberHistory_deletedMember_throws() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock());

    LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Contact c = [SELECT Id FROM Contact WHERE MemberNo__c = 'MH-001' LIMIT 1];
    LoyaltyProgramMember temp = new LoyaltyProgramMember(
      MembershipNumber = 'MH-003',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = c.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert temp;
    Id deletedId = temp.Id;
    delete temp;

    Boolean thrown = false;
    try {
      GdMemberHistoryUIController.getMemberHistory(deletedId);
    } catch (QueryException qe) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void convertFieldLabel_mapping() {
    String label = GdMemberHistoryUIController.convertFieldLabel('created');
    System.assertNotEquals('created', label);
  }

  @IsTest
  static void convertFieldLabel_defaultAndBlank() {
    String unknown = GdMemberHistoryUIController.convertFieldLabel('UnknownField');
    String blank = GdMemberHistoryUIController.convertFieldLabel('');

    System.assertEquals('UnknownField', unknown);
    System.assertEquals('', blank);
  }

  @IsTest
  static void comparator_compare_branches() {
    GdMemberHistoryUIController.MemberChangeHistoryDTO newer =
      new GdMemberHistoryUIController.MemberChangeHistoryDTO();
    GdMemberHistoryUIController.MemberChangeHistoryDTO older =
      new GdMemberHistoryUIController.MemberChangeHistoryDTO();
    GdMemberHistoryUIController.MemberChangeHistoryDTO same =
      new GdMemberHistoryUIController.MemberChangeHistoryDTO();
    GdMemberHistoryUIController.MemberChangeHistoryDTO nullDate =
      new GdMemberHistoryUIController.MemberChangeHistoryDTO();

    newer.changeDate = System.now();
    older.changeDate = System.now().addDays(-1);
    same.changeDate = newer.changeDate;

    GdMemberHistoryUIController.ChangeDateDescComparator comp =
      new GdMemberHistoryUIController.ChangeDateDescComparator();

    System.assertEquals(-1, comp.compare(newer, older));
    System.assertEquals(1, comp.compare(older, newer));
    System.assertEquals(0, comp.compare(newer, same));
    System.assertEquals(1, comp.compare(nullDate, newer));
  }

}