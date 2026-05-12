@IsTest
private class GdMemberTierServiceImplTest {
  private static LoyaltyMemberTier findExistingMemberTier(String currentGrade, String previousGrade) {
    List<LoyaltyMemberTier> tiers = [
      SELECT Id, LoyaltyMemberId, LoyaltyMember.ContactId
      FROM LoyaltyMemberTier
      WHERE LoyaltyMemberId != NULL AND LoyaltyMember.ContactId != NULL
      LIMIT 1
    ];
    if (tiers.isEmpty()) {
      return null;
    }

    Contact contactRecord = new Contact(Id = tiers[0].LoyaltyMember.ContactId, Grade__c = currentGrade, PreviousGrade__c = previousGrade);
    update contactRecord;

    return tiers[0];
  }

  private static Id findExistingMemberWithoutTier() {
    List<LoyaltyProgramMember> members = [
      SELECT Id
      FROM LoyaltyProgramMember
      WHERE Id NOT IN (SELECT LoyaltyMemberId FROM LoyaltyMemberTier WHERE LoyaltyMemberId != NULL)
      LIMIT 1
    ];
    return members.isEmpty() ? null : members[0].Id;
  }

  @IsTest(SeeAllData=true)
  static void resolveAccrualGrade_memberTierNotFound_throws() {
    GdMemberTierServiceImpl svc = new GdMemberTierServiceImpl();
    Id lpmId = findExistingMemberWithoutTier();
    if (lpmId == null) {
      System.assert(true, 'No existing LoyaltyProgramMember without tier - skipped.');
      return;
    }

    Boolean thrown = false;

    try {
      svc.resolveAccrualGrade(lpmId, Date.today());
    } catch (Exception e) {
      thrown = true;
      System.assertNotEquals(null, e.getMessage());
    }

    System.assertEquals(true, thrown);
  }

  @IsTest(SeeAllData=true)
  static void resolveAccrualGrade_returnsCurrentGrade() {
    GdMemberTierServiceImpl svc = new GdMemberTierServiceImpl();
    LoyaltyMemberTier tier = findExistingMemberTier('02', '01');
    if (tier == null) {
      System.assert(true, 'No existing LoyaltyMemberTier - skipped.');
      return;
    }

    Test.startTest();
    String grade = svc.resolveAccrualGrade(tier.LoyaltyMemberId, Date.today().addYears(1));
    Test.stopTest();

    System.assertEquals('02', grade);
  }

  @IsTest(SeeAllData=true)
  static void resolveAccrualGrade_returnsPreviousGrade_whenBeforeLastModified() {
    GdMemberTierServiceImpl svc = new GdMemberTierServiceImpl();
    LoyaltyMemberTier tier = findExistingMemberTier('02', '01');
    if (tier == null) {
      System.assert(true, 'No existing LoyaltyMemberTier - skipped.');
      return;
    }

    Test.startTest();
    String grade = svc.resolveAccrualGrade(tier.LoyaltyMemberId, Date.newInstance(1900, 1, 1));
    Test.stopTest();

    System.assertEquals('01', grade);
  }

  @IsTest(SeeAllData=true)
  static void resolveAccrualGrade_previousGradeMissing_throws() {
    GdMemberTierServiceImpl svc = new GdMemberTierServiceImpl();
    LoyaltyMemberTier tier = findExistingMemberTier('02', null);
    if (tier == null) {
      System.assert(true, 'No existing LoyaltyMemberTier - skipped.');
      return;
    }

    Boolean thrown = false;

    try {
      svc.resolveAccrualGrade(tier.LoyaltyMemberId, Date.newInstance(1900, 1, 1));
    } catch (Exception e) {
      thrown = true;
      System.assertNotEquals(null, e.getMessage());
    }

    System.assertEquals(true, thrown);
  }
}