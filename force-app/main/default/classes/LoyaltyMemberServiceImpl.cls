/**
 * ! 운영 배포 X
 */
public with sharing class LoyaltyMemberServiceImpl implements LoyaltyMemberService {
  public LoyaltyMemberServiceImpl() {
  }

  public enum MemberStatus {
    Active,
    Inactive
  }

  /**
   * 멤버십 개인 회원 생성
   * ! 미사용
   */
  public ApiResult createIndividualMemberByContact(Contact c) {
    if (c == null) {
      return ApiResult.fail(400, 'Contact is null');
    }

    try {
      MemberContactInput mciDto = new MemberContactInput.Builder()
        .setAdditionalContactFieldValues(new Map<String, String>{ 'MemberNo__c' => c.MemberNo__c })
        .setAllowDuplicateRecords(false)
        .setEmail(c.email)
        .setLastName(c.LastName)
        .build();
      ConnectApi.MemberContactInput mci = mciDto.toConnectApi();

      Map<String, String> additionalMemberFieldValues = new Map<String, String>();

      IndividualMemberInput imDto = new IndividualMemberInput.Builder()
        .setAdditionalMemberFieldValues(additionalMemberFieldValues)
        .setAssociatedContactDetails(mci)
        .setEnrollmentDate(System.now())
        .setMemberStatus('Active')
        .setMembershipNumber(c.MemberNo__c)
        .build();
      ConnectApi.IndividualMemberInput im = imDto.toConnectApi();
      ConnectApi.IndividualMemberOutput output = ConnectApi.LoyaltyManagementConnect.enrollIndividualMember('Golden Dew', im);

      return ApiResult.ok(200, 'Loyalty Member created.', null);
    } catch (Exception e) {
      return ApiResult.fail(500, 'error');
    }
  }
}