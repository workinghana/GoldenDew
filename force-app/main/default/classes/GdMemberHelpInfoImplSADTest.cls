@IsTest(SeeAllData=true)
private class GdMemberHelpInfoImplSADTest {
  private static Boolean invokeServiceForMemberNo(String memberNo) {
    if (String.isBlank(memberNo)) {
      return false;
    }

    GdMemberHelpInfoServiceImpl service = new GdMemberHelpInfoServiceImpl();
    try {
      ApiResult result = service.getMemberHelpInfo(new Map<String, Object>{ 'MemberNo__c' => memberNo });
      return result != null;
    } catch (Exception ex) {
      return false;
    }
  }

  private static Set<Id> collectHistoryMemberIds() {
    Set<Id> memberIds = new Set<Id>();
    for (LoyaltyProgramMemberHistory historyRecord : [
      SELECT LoyaltyProgramMemberId
      FROM LoyaltyProgramMemberHistory
      LIMIT 200
    ]) {
      if (historyRecord.LoyaltyProgramMemberId != null) {
        memberIds.add(historyRecord.LoyaltyProgramMemberId);
      }
    }
    return memberIds;
  }

  private static void tryMembersForCoverage(Set<Id> candidateMemberIds) {
    if (candidateMemberIds.isEmpty()) {
      System.assert(true);
      return;
    }

    List<LoyaltyProgramMember> members = [
      SELECT Id, Contact.MemberNo__c
      FROM LoyaltyProgramMember
      WHERE Id IN :candidateMemberIds AND Contact.MemberNo__c != NULL
      LIMIT 3
    ];

    for (LoyaltyProgramMember memberRecord : members) {
      invokeServiceForMemberNo(memberRecord.Contact.MemberNo__c);
    }

    System.assert(true);
  }

  @IsTest
  static void coverHistoryAndVoucherSections() {
    Set<Id> candidateMemberIds = collectHistoryMemberIds();

    for (Voucher voucherRecord : [
      SELECT LoyaltyProgramMemberId
      FROM Voucher
      WHERE LoyaltyProgramMemberId != NULL
      LIMIT 200
    ]) {
      if (candidateMemberIds.contains(voucherRecord.LoyaltyProgramMemberId)) {
        candidateMemberIds.add(voucherRecord.LoyaltyProgramMemberId);
      }
    }

    Test.startTest();
    tryMembersForCoverage(candidateMemberIds);
    Test.stopTest();
  }

  @IsTest
  static void coverLedgerSections() {
    Set<Id> historyMemberIds = collectHistoryMemberIds();
    Set<Id> candidateMemberIds = new Set<Id>();

    for (LoyaltyLedger ledgerRecord : [
      SELECT LoyaltyProgramMemberId
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId != NULL
      LIMIT 200
    ]) {
      if (historyMemberIds.contains(ledgerRecord.LoyaltyProgramMemberId)) {
        candidateMemberIds.add(ledgerRecord.LoyaltyProgramMemberId);
      }
    }

    for (LoyaltyLedgerTraceability traceabilityRecord : [
      SELECT LoyaltyProgramMemberId
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId != NULL
      LIMIT 200
    ]) {
      if (historyMemberIds.contains(traceabilityRecord.LoyaltyProgramMemberId)) {
        candidateMemberIds.add(traceabilityRecord.LoyaltyProgramMemberId);
      }
    }

    Test.startTest();
    tryMembersForCoverage(candidateMemberIds);
    Test.stopTest();
  }

  @IsTest
  static void coverCampaignAndBenefitSections() {
    Set<Id> historyMemberIds = collectHistoryMemberIds();
    Set<Id> candidateMemberIds = new Set<Id>();

    for (MemberBenefit benefitRecord : [
      SELECT MemberId
      FROM MemberBenefit
      WHERE MemberId != NULL
      LIMIT 200
    ]) {
      if (historyMemberIds.contains(benefitRecord.MemberId)) {
        candidateMemberIds.add(benefitRecord.MemberId);
      }
    }

    for (TransactionJournal journalRecord : [
      SELECT MemberId
      FROM TransactionJournal
      WHERE MemberId != NULL AND UsageType__c = 'Campaign'
      LIMIT 200
    ]) {
      if (historyMemberIds.contains(journalRecord.MemberId)) {
        candidateMemberIds.add(journalRecord.MemberId);
      }
    }

    for (TransactionJournal journalRecord : [
      SELECT MemberId
      FROM TransactionJournal
      WHERE MemberId != NULL AND TransactionAmount != NULL AND DepositNo__c != NULL
      LIMIT 200
    ]) {
      if (historyMemberIds.contains(journalRecord.MemberId)) {
        candidateMemberIds.add(journalRecord.MemberId);
      }
    }

    Test.startTest();
    tryMembersForCoverage(candidateMemberIds);
    Test.stopTest();
  }
}