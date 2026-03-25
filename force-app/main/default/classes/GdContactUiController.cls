public with sharing class GdContactUiController {
  @AuraEnabled(cacheable=true)
  public static MemberProfileDTO getMemberProfile(Id loyaltyProgramMemberId) {
    LoyaltyProgramMember lpm = [
      SELECT
        Id,
        EnrollmentDate, //등록날짜
        MemberStatus, //멤버 상태
        Program.Name, //프로그램 이름
        Contact.Name, //회원 이름
        Contact.Phone, //회원 전화번호
        Contact.MobilePhone, //회원 휴대폰 번호
        Contact.Email, //회원 이메일
        Contact.Birthdate, //회원 생일
        Contact.StoreMana__c, //관리 매장
        Contact.IsMarried__c, //회원 결혼 유무
        Contact.WeddingAnniversaryDate__c, //회원 결혼 일자
        Contact.MemberNo__c, //회원 번호
        Contact.MailingStreet, // 주소
        Contact.MailingCity
      FROM LoyaltyProgramMember
      WHERE Id = :loyaltyProgramMemberId
      LIMIT 1
    ];

    if (lpm == null) {
      throw new AuraHandledException('회원 정보를 찾을 수 없습니다.');
    }

    return new MemberProfileDTO(lpm);
  }

  public class MemberProfileDTO {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String phone;
    @AuraEnabled
    public String mobilePhone;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String memberNumber;
    @AuraEnabled
    public Date birthdate;

    @AuraEnabled
    public Boolean isMarried;
    @AuraEnabled
    public Date weddingAnniversaryDate;
    @AuraEnabled
    public String storeName;

    @AuraEnabled
    public String address;
    @AuraEnabled
    public Date enrollmentDate;
    @AuraEnabled
    public String programName;
    @AuraEnabled
    public String memberStatus;

    public MemberProfileDTO(LoyaltyProgramMember lpm) {
      if (lpm.Contact != null) {
        name = lpm.Contact.Name;
        phone = lpm.Contact.Phone;
        mobilePhone = lpm.Contact.MobilePhone;
        email = lpm.Contact.Email;
        birthdate = lpm.Contact.Birthdate;
        memberNumber = lpm.Contact.MemberNo__c;

        isMarried = lpm.Contact.IsMarried__c;
        weddingAnniversaryDate = lpm.Contact.WeddingAnniversaryDate__c;

        storeName = lpm.Contact.StoreMana__c;

        address =
          (lpm.Contact.MailingStreet != null ? lpm.Contact.MailingStreet : '') +
          ' ' +
          (lpm.Contact.MailingCity != null ? lpm.Contact.MailingCity : '');
      }

      enrollmentDate = lpm.EnrollmentDate;
      memberStatus = lpm.MemberStatus;
      programName = lpm.Program != null ? lpm.Program.Name : null;
    }
  }
}