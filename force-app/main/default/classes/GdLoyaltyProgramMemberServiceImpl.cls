public with sharing class GdLoyaltyProgramMemberServiceImpl implements GdLoyaltyProgramMemberService {
  public GdLoyaltyProgramMemberServiceImpl() {
  }

  private static final String LOYALTY_PROGRAM_NAME = 'Golden Dew';

  public enum MemberStatus {
    Active, // 활성화
    Inactive // 비활성화
  }

  public enum MemberType {
    Corporate, // 기업
    Individual // 개인
  }

  /**
   * 멤버십 회원 생성 - LoyaltyProgramMember insert
   */
  public ApiResult createLoyaltyProgramMember(Contact c) {
    try {
      if (c == null) {
        throw new CustomException(400, 'Contact is null');
      }

      List<LoyaltyProgram> lpList = [SELECT Id FROM LoyaltyProgram WHERE Name = :LOYALTY_PROGRAM_NAME LIMIT 1];
      if (lpList.isEmpty()) {
        throw new CustomException(400, 'LoyaltyProgram is null');
      }
      LoyaltyProgram lp = lpList[0];

      LoyaltyProgramMember lpm = new LoyaltyProgramMember();
      lpm.MembershipNumber = c.MemberNo__c; // 멤버십 번호
      lpm.MemberStatus = String.valueOf(MemberStatus.Active); // 멤버 상태 | 활성화, 비활성화
      lpm.MemberType = String.valueOf(MemberType.Individual); // 멤버 타입 | 개인, 그룹, 기업
      lpm.ContactId = c.Id; // Contact Id
      lpm.EnrollmentDate = System.today(); // 등록 날짜
      lpm.ProgramId = lp.Id; // LoyaltyProgram Id

      Database.SaveResult result = Database.insert(lpm);

      if (!result.isSuccess()) {
        Database.Error err = result.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('LoyaltyProgramMemberId', lpm.Id);
      return ApiResult.ok(200, 'LoyaltyProgramMember created.', data);
    } catch (Exception e) {
      throw e;
    }
  }
}