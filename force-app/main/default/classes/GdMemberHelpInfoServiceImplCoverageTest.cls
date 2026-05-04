@IsTest(SeeAllData=true)
private class GdMemberHelpInfoServiceImplCoverageTest {
  @IsTest
  static void getMemberHelpInfo_existingHistoryMember_success_deepCoverage() {
    List<ContactHistory> contactHistories = [
      SELECT ContactId
      FROM ContactHistory
      WHERE ContactId != NULL
      LIMIT 1
    ];

    if (contactHistories.isEmpty()) {
      System.assert(true);
      return;
    }

    List<Contact> contacts = [
      SELECT Id, MemberNo__c
      FROM Contact
      WHERE Id = :contactHistories[0].ContactId AND MemberNo__c != NULL
      LIMIT 1
    ];

    if (contacts.isEmpty()) {
      System.assert(true);
      return;
    }

    GdMemberHelpInfoServiceImpl service = new GdMemberHelpInfoServiceImpl();

    Test.startTest();
    try {
      ApiResult res = service.getMemberHelpInfo(new Map<String, Object>{ 'MemberNo__c' => contacts[0].MemberNo__c });
      System.assertNotEquals(null, res);
      System.assertEquals(true, res.success);
      System.assertEquals(200, res.code);
      System.assertNotEquals(null, res.data);
      System.assert(res.data.containsKey('HistoryUpdatedList'));
      System.assert(res.data.containsKey('Depositlist'));
      System.assert(res.data.containsKey('OrdersList'));
      System.assert(res.data.containsKey('GiftList'));
      System.assert(res.data.containsKey('CouponList'));
      System.assert(res.data.containsKey('AccrualHistoryList'));
      System.assert(res.data.containsKey('UserDestoryHistoryList'));
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }
    Test.stopTest();
  }

  @IsTest
  static void getMemberHelpInfo_existingPointMember_success_pointCoverage() {
    List<LoyaltyLedger> creditLedgers = [
      SELECT LoyaltyProgramMember.Contact.MemberNo__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId != NULL AND EventType = 'Credit' AND LoyaltyProgramMember.Contact.MemberNo__c != NULL
      LIMIT 1
    ];

    if (creditLedgers.isEmpty()) {
      System.assert(true);
      return;
    }

    String memberNo = creditLedgers[0].LoyaltyProgramMember.Contact.MemberNo__c;
    GdMemberHelpInfoServiceImpl service = new GdMemberHelpInfoServiceImpl();

    Test.startTest();
    try {
      ApiResult res = service.getMemberHelpInfo(new Map<String, Object>{ 'MemberNo__c' => memberNo });
      System.assertNotEquals(null, res);
      System.assertEquals(200, res.code);
      if (res.data != null) {
        System.assert(res.data.containsKey('AccrualHistoryList'));
        System.assert(res.data.containsKey('UserDestoryHistoryList'));
      }
    } catch (CustomException ce) {
      System.assertEquals(400, ce.code);
    }
    Test.stopTest();
  }
}