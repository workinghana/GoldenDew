public with sharing class ContactUiController {
  /* ================= 등급 코드 → 라벨 매핑 ================= */

  private static final Map<String, String> GRADE_LABEL_MAP = new Map<String, String>{
    '01' => 'GIP',
    '02' => 'VIP',
    '03' => 'VVIP',
    '04' => 'SVIP',
    '11' => '직원(직)',
    '12' => '직원소개',
    '13' => '관계사직원',
    '14' => '직원(위)',
    '51' => '홈페이지',
    '58' => '(R)일반',
    '59' => '(R)VIP'
  };

  @TestVisible
  private static String getGradeLabel(String gradeCode) {
    if (String.isBlank(gradeCode)) {
      return null;
    }
    return GRADE_LABEL_MAP.containsKey(gradeCode) ? GRADE_LABEL_MAP.get(gradeCode) : gradeCode;
  }

  @TestVisible
  private static String getMemberTypeLabel(String memberTypeCode) {
    if (String.isBlank(memberTypeCode)) {
      return null;
    }

    Schema.DescribeFieldResult fieldDesc = Contact.MemberType__c.getDescribe();
    for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
      if (entry.getValue() == memberTypeCode) {
        return entry.getLabel();
      }
    }
    return memberTypeCode;
  }

  @TestVisible
  private static String buildAddress(Contact c) {
    if (c == null)
      return null;

    String street = c.MailingStreet != null ? c.MailingStreet : '';
    String city = c.MailingCity != null ? c.MailingCity : '';

    return (street + ' ' + city).trim();
  }

  /* ================= 회원 정보 ================= */

  @AuraEnabled(cacheable=true)
  public static MemberProfileDTO getMemberProfile(Id loyaltyProgramMemberId) {
    if (loyaltyProgramMemberId == null) {
      throw new AuraHandledException('회원 ID가 없습니다.');
    }

    LoyaltyProgramMember lpm = [
      SELECT
        Id,
        EnrollmentDate,
        MemberStatus,
        Contact.Name,
        Contact.MobilePhone,
        Contact.Email,
        Contact.Birthdate,
        Contact.LegalBirthdate__c,
        Contact.StoreMana__c,
        Contact.StoreMana__r.Name,
        Contact.StoreRegi__c,
        Contact.StoreRegi__r.Name,
        Contact.IsMarried__c,
        Contact.WeddingAnniversaryDate__c,
        Contact.IsMobileVerified__c,
        Contact.MemberNo__c,
        Contact.MailingStreet,
        Contact.MailingCity,
        Contact.AddressDetail__c,
        Contact.Grade__c,
        Contact.MemberDropDate__c,
        Contact.IsWithdrawn__c,
        Contact.MemberType__c,
        Contact.TierQualifyingSpend3Y__c
      FROM LoyaltyProgramMember
      WHERE Id = :loyaltyProgramMemberId
      LIMIT 1
    ];

    return new MemberProfileDTO(lpm);
  }

  /* ================= DTO ================= */

  public class MemberProfileDTO {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String mobilePhone;
    @AuraEnabled
    public String email;
    @AuraEnabled
    public String memberNumber;
    @AuraEnabled
    public Date birthdate;
    @AuraEnabled
    public String legalBirthdate;

    @AuraEnabled
    public Boolean isMarried;
    @AuraEnabled
    public Date weddingAnniversaryDate;
    @AuraEnabled
    public Boolean isMobileVerified;

    @AuraEnabled
    public String storeName;
    @AuraEnabled
    public String signupStore;

    @AuraEnabled
    public String address;
    @AuraEnabled
    public String addressDetail;
    @AuraEnabled
    public Date enrollmentDate;
    @AuraEnabled
    public String memberStatus;
    @AuraEnabled
    public String grade;

    @AuraEnabled
    public Date withdrawDate;
    @AuraEnabled
    public Boolean isWithdrawn;

    @AuraEnabled
    public String memberType;

    @AuraEnabled
    public Decimal tierQualifyingSpend3Y;

    public MemberProfileDTO(LoyaltyProgramMember lpm) {
      if (lpm != null && lpm.Contact != null) {
        name = lpm.Contact.Name;
        mobilePhone = lpm.Contact.MobilePhone;

        email = lpm.Contact.Email;

        birthdate = lpm.Contact.Birthdate;
        legalBirthdate = lpm.Contact.LegalBirthdate__c;
        memberNumber = lpm.Contact.MemberNo__c;

        isMarried = lpm.Contact.IsMarried__c;
        weddingAnniversaryDate = lpm.Contact.WeddingAnniversaryDate__c;
        isMobileVerified = lpm.Contact.IsMobileVerified__c;

        /* 🔹 관리 매장 이름 */

        storeName = (lpm.Contact.StoreMana__r != null) ? lpm.Contact.StoreMana__r.Name : null;

        /* 🔹 가입 매장 이름 */

        signupStore = (lpm.Contact.StoreRegi__r != null) ? lpm.Contact.StoreRegi__r.Name : null;

        address = ContactUiController.buildAddress(lpm.Contact);
        addressDetail = lpm.Contact.AddressDetail__c;
        grade = ContactUiController.getGradeLabel(lpm.Contact.Grade__c);

        withdrawDate = lpm.Contact.MemberDropDate__c;
        isWithdrawn = lpm.Contact.IsWithdrawn__c;

        memberType = ContactUiController.getMemberTypeLabel(lpm.Contact.MemberType__c);
        tierQualifyingSpend3Y = lpm.Contact.TierQualifyingSpend3Y__c;
      }

      enrollmentDate = (lpm != null) ? lpm.EnrollmentDate : null;
      memberStatus = (lpm != null) ? lpm.MemberStatus : null;
    }
  }
}