@IsTest
private class LoyaltyPointInstantValidatorTest {
  @IsTest
  static void validateByMemberNo_whenMemberMissing_returnsInvalidResult() {
    LoyaltyPointInstantValidator.ValidationResult result =
      LoyaltyPointInstantValidator.validateByMemberNo('NO_SUCH_MEMBER');

    System.assertEquals(false, result.isValid);
    System.assertEquals('NO_SUCH_MEMBER', result.memberNo);
    System.assertEquals(0, result.lmcBalance);
    System.assertEquals(0, result.calculatedBalance);
    System.assertEquals(0, result.difference);
    System.assertEquals('Active LoyaltyProgramMember not found.', result.summary);
  }

  @IsTest
  static void validateByContactIds_whenEmpty_returnsEmptyList() {
    List<LoyaltyPointInstantValidator.ValidationResult> results =
      LoyaltyPointInstantValidator.validateByContactIds(new Set<Id>());

    System.assertEquals(0, results.size());
  }
}