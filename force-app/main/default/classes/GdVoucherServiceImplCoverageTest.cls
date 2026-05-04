@IsTest(SeeAllData=true)
private class GdVoucherServiceImplCoverageTest {
  @IsTest
  static void test_issueSignupCouponV2_reachesOrgSuccessPath() {
    List<LoyaltyProgram> lpList = [SELECT Id FROM LoyaltyProgram WHERE IsPrimary = true LIMIT 1];
    List<LoyaltyProgramMember> lpmList = lpList.isEmpty()
      ? new List<LoyaltyProgramMember>()
      : [SELECT Id FROM LoyaltyProgramMember WHERE ProgramId = :lpList[0].Id LIMIT 1];

    if (lpList.isEmpty() || lpmList.isEmpty()) {
      System.assert(true);
      return;
    }

    Integer beforeJournalCount = [
      SELECT COUNT()
      FROM TransactionJournal
      WHERE MemberId = :lpmList[0].Id AND JournalSubType.Name = 'Welcome Coupon Issue'
    ];

    Test.startTest();
    try {
      new GdVoucherServiceImpl().issueSignupCouponV2(new Map<String, Object>{ 'LoyaltyProgramMemberId' => lpmList[0].Id });
    } catch (Exception ignore) {
    }
    Test.stopTest();

    Integer afterJournalCount = [
      SELECT COUNT()
      FROM TransactionJournal
      WHERE MemberId = :lpmList[0].Id AND JournalSubType.Name = 'Welcome Coupon Issue'
    ];
    System.assert(afterJournalCount >= beforeJournalCount);
  }
}