public with sharing class MemberDetailUIController {
  @AuraEnabled(cacheable=true)
  public static MemberDetailDTO getMemberDetail(Id loyaltyProgramMemberId) {
    LoyaltyProgramMember lpm = [
      SELECT
        Id,
        EnrollmentDate,
        MemberStatus,
        Program.Name,
        Contact.Name,
        Contact.Phone,
        Contact.MobilePhone,
        Contact.Email,
        Contact.Birthdate,
        Contact.StoreMana__c,
        Contact.IsMarried__c,
        Contact.WeddingAnniversaryDate__c,
        Contact.MemberNo__c,
        Contact.MailingStreet,
        Contact.MailingCity,
        Contact.IsMagazineSubscribed__c,
        Contact.MagazineSubscriptionDate__c
      FROM LoyaltyProgramMember
      WHERE Id = :loyaltyProgramMemberId
      LIMIT 1
    ];

    return new MemberDetailDTO(lpm);
  }

  public class MemberDetailDTO {
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

    @AuraEnabled
    public Boolean isMagazineSubscribed;
    @AuraEnabled
    public Datetime magazineSubscriptionDate;

    public MemberDetailDTO(LoyaltyProgramMember lpm) {
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

        isMagazineSubscribed = lpm.Contact.IsMagazineSubscribed__c;
        magazineSubscriptionDate = lpm.Contact.MagazineSubscriptionDate__c;
      }

      enrollmentDate = lpm.EnrollmentDate;
      memberStatus = lpm.MemberStatus;
      programName = lpm.Program != null ? lpm.Program.Name : null;
    }
  }

  @AuraEnabled(cacheable=true)
  public static MemberInfoDto getMemebrInfo(Id loyaltyProgramMemberId) {
    if (loyaltyProgramMemberId == null) {
      throw new AuraHandledException('해당 회원 id가 없습니다.');
    }

    MemberInfoDto result = new MemberInfoDto();
    result.benefit = getMemberBenefit(loyaltyProgramMemberId);
    result.grade = getMemberGrade(loyaltyProgramMemberId);
    result.marketing = getMarketingConsent(loyaltyProgramMemberId);
    return result;
  }

  private static MemberBenefitDTO getMemberBenefit(Id lpmId) {
    MemberBenefitDTO benefit = new MemberBenefitDTO();

    Id pointCurrencyId = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      WHERE Name = '포인트'
      LIMIT 1
    ]
    .Id;

    AggregateResult ar = [
      SELECT SUM(PointsBalance) totalPoints
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :lpmId AND LoyaltyProgramCurrencyId = :pointCurrencyId
    ];

    Decimal totalPoint = (Decimal) ar.get('totalPoints');
    benefit.ownedPoint = totalPoint != null ? totalPoint.intValue() : 0;

    benefit.ownedCoupon = [
      SELECT COUNT()
      FROM Voucher
      WHERE LoyaltyProgramMemberId = :lpmId AND Status = 'Issued' AND (ExpirationDateTime = NULL OR ExpirationDateTime >= :System.now())
    ];

    return benefit;
  }

  private static MemberGradeDTO getMemberGrade(Id lpmId) {
    MemberGradeDTO grade = new MemberGradeDTO();

    LoyaltyMemberTier lmt = [
      SELECT LoyaltyTier.Name, EffectiveDate
      FROM LoyaltyMemberTier
      WHERE LoyaltyMemberId = :lpmId
      ORDER BY EffectiveDate DESC
      LIMIT 1
    ];

    grade.currentGrade = lmt.LoyaltyTier != null ? lmt.LoyaltyTier.Name : null;
    grade.lastUpdatedDate = lmt.EffectiveDate;

    Date threeYearsAgo = Date.today().addYears(-3);

    AggregateResult ar = [
      SELECT SUM(TransactionAmount) total
      FROM TransactionJournal
      WHERE MemberId = :lpmId AND Status = 'Processed' AND OrderId != NULL AND TransactionAmount > 0 AND ActivityDate >= :threeYearsAgo
    ];

    Decimal total = (Decimal) ar.get('total');
    grade.totalPurchaseAmount = total != null ? total.intValue() : 0;

    return grade;
  }

  private static MarketingConsentDTO getMarketingConsent(Id lpmId) {
    MarketingConsentDTO consent = new MarketingConsentDTO();

    LoyaltyProgramMember lpm = [
      SELECT Contact.IsEmailAgreed__c, Contact.IsSMSAgreed__c, Contact.IsMagazineSubscribed__c, Contact.MagazineSubscriptionDate__c
      FROM LoyaltyProgramMember
      WHERE Id = :lpmId
      LIMIT 1
    ];

    if (lpm.Contact == null) {
      return consent;
    }

    consent.emailConsent = lpm.Contact.IsEmailAgreed__c;
    consent.smsConsent = lpm.Contact.IsSMSAgreed__c;
    consent.magazineConsent = lpm.Contact.IsMagazineSubscribed__c;
    consent.magazineUpdatedDate = lpm.Contact.MagazineSubscriptionDate__c;

    return consent;
  }

  public class MemberInfoDto {
    @AuraEnabled
    public MemberBenefitDTO benefit;
    @AuraEnabled
    public MemberGradeDTO grade;
    @AuraEnabled
    public MarketingConsentDTO marketing;
  }

  public class MemberBenefitDTO {
    @AuraEnabled
    public Integer ownedPoint;
    @AuraEnabled
    public Integer ownedCoupon;
  }

  public class MemberGradeDTO {
    @AuraEnabled
    public String currentGrade;
    @AuraEnabled
    public Integer totalPurchaseAmount;
    @AuraEnabled
    public Integer remainAmount;
    @AuraEnabled
    public Datetime lastUpdatedDate;
  }

  public class MarketingConsentDTO {
    @AuraEnabled
    public Boolean emailConsent;
    @AuraEnabled
    public Datetime emailUpdatedDate;

    @AuraEnabled
    public Boolean smsConsent;
    @AuraEnabled
    public Datetime smsUpdatedDate;

    @AuraEnabled
    public Boolean magazineConsent;
    @AuraEnabled
    public Datetime magazineUpdatedDate;
  }
}