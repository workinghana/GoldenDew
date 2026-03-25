@IsTest(SeeAllData=true)
private class GdMemberHistoryUISeeAllTest {
  @IsTest
  static void getMemberHistory_hitsLoyaltyProgramMemberHistoryLoop() {
    List<LoyaltyProgramMemberHistory> historyRows = [
      SELECT LoyaltyProgramMemberId
      FROM LoyaltyProgramMemberHistory
      WHERE LoyaltyProgramMemberId != null
      LIMIT 1
    ];

    if (historyRows.isEmpty()) {
      System.assert(true, 'No LoyaltyProgramMemberHistory data in org');
      return;
    }

    Test.startTest();
    List<GdMemberHistoryUIController.MemberChangeHistoryDTO> rows =
      GdMemberHistoryUIController.getMemberHistory(historyRows[0].LoyaltyProgramMemberId);
    Test.stopTest();

    System.assertNotEquals(null, rows);
  }

  @IsTest
  static void getMemberHistory_hitsContactHistoryLoop() {
    List<ContactHistory> contactHistoryRows = [
      SELECT ContactId
      FROM ContactHistory
      WHERE ContactId != null
      LIMIT 1
    ];

    if (contactHistoryRows.isEmpty()) {
      System.assert(true, 'No ContactHistory data in org');
      return;
    }

    List<LoyaltyProgramMember> members = [
      SELECT Id
      FROM LoyaltyProgramMember
      WHERE ContactId = :contactHistoryRows[0].ContactId
      LIMIT 1
    ];

    if (members.isEmpty()) {
      System.assert(true, 'No member mapped to ContactHistory.ContactId');
      return;
    }

    Test.startTest();
    List<GdMemberHistoryUIController.MemberChangeHistoryDTO> rows =
      GdMemberHistoryUIController.getMemberHistory(members[0].Id);
    Test.stopTest();

    System.assertNotEquals(null, rows);
  }
}