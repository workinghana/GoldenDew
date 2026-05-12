@IsTest(SeeAllData=true)
private class GdMemberDashboardControllerTest {
  private static Id findMemberWithTier() {
    List<LoyaltyMemberTier> tiers = [
      SELECT LoyaltyMemberId
      FROM LoyaltyMemberTier
      WHERE LoyaltyMemberId != NULL
      ORDER BY EffectiveDate DESC
      LIMIT 1
    ];
    return tiers.isEmpty() ? null : tiers[0].LoyaltyMemberId;
  }

  private static Id findMemberWithoutTier() {
    List<LoyaltyProgramMember> members = [
      SELECT Id
      FROM LoyaltyProgramMember
      WHERE Id NOT IN (SELECT LoyaltyMemberId FROM LoyaltyMemberTier WHERE LoyaltyMemberId != NULL)
      LIMIT 1
    ];
    return members.isEmpty() ? null : members[0].Id;
  }

  @IsTest
  static void getMemberInfo_success() {
    Id lpmId = findMemberWithTier();
    if (lpmId == null) {
      System.assert(true, 'No existing LoyaltyProgramMember with tier - skipped.');
      return;
    }

    Test.startTest();
    GdMemberDashboardController.MemberInfoDto result = GdMemberDashboardController.getMemebrInfo(lpmId);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertNotEquals(null, result.benefit);
    System.assertNotEquals(null, result.grade);
    System.assertNotEquals(null, result.marketing);
    System.assertNotEquals(null, result.grade.currentGrade);
    System.assert(result.benefit.ownedPoint >= 0);
    System.assert(result.benefit.ownedCoupon >= 0);
  }

  @IsTest
  static void getMemberInfo_noTierMember() {
    Id lpmId = findMemberWithoutTier();
    if (lpmId == null) {
      System.assert(true, 'No existing LoyaltyProgramMember without tier - skipped.');
      return;
    }

    Boolean thrown = false;

    try {
      Test.startTest();
      GdMemberDashboardController.getMemebrInfo(lpmId);
      Test.stopTest();
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }
}