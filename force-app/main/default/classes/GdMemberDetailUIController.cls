public with sharing class GdMemberDetailUIController {
    
    /* =================================================
    ContactId → LoyaltyProgramMemberId 조회
        ================================================= */
        @AuraEnabled(cacheable=false)
    public static Id getLoyaltyProgramMemberIdByContactId(Id contactId) {
        
        if (contactId == null) {
            return null;
        }
        
        List<LoyaltyProgramMember> lpms = [
            SELECT Id
            FROM LoyaltyProgramMember
            WHERE ContactId = :contactId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        return lpms.isEmpty() ? null : lpms[0].Id;
    }
    
    @AuraEnabled(cacheable=true)
    public static MemberDetailDTO getMemberDetail(Id loyaltyProgramMemberId) {
        
        LoyaltyProgramMember lpm = [
            SELECT Id,
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
        
        @AuraEnabled public String name;
        @AuraEnabled public String phone;
        @AuraEnabled public String mobilePhone;
        @AuraEnabled public String email;
        @AuraEnabled public String memberNumber;
        @AuraEnabled public Date birthdate;
        
        @AuraEnabled public Boolean isMarried;
        @AuraEnabled public Date weddingAnniversaryDate;
        @AuraEnabled public String storeName;
        
        @AuraEnabled public String address;
        @AuraEnabled public Date enrollmentDate;
        @AuraEnabled public String programName;
        @AuraEnabled public String memberStatus;
        
        /* ===== 마케팅 (매거진) ===== */
        @AuraEnabled public Boolean isMagazineSubscribed;
        @AuraEnabled public Datetime magazineSubscriptionDate;
        
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
            programName = (lpm.Program != null ? lpm.Program.Name : null);
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static MemberInfoDto getMemebrInfo(Id loyaltyProgramMemberId){
        
        if(loyaltyProgramMemberId==null){
            throw new AuraHandledException('해당 회원 id가 없습니다.');
        }
        
        MemberInfoDto result = new MemberInfoDto();
        
        result.benefit = getMemberBenefit(loyaltyProgramMemberId);
        result.grade = getMemberGrade(loyaltyProgramMemberId);
        result.marketing = getMarketingConsent(loyaltyProgramMemberId);
        
        return result;
    }
    
    //사용 가능 혜택
    private static MemberBenefitDTO getMemberBenefit(Id lpmId) {
        
        MemberBenefitDTO benefit = new MemberBenefitDTO();
        
        LoyaltyProgramMember lpm = [
            SELECT Id
            FROM LoyaltyProgramMember
            WHERE Id = :lpmId
            LIMIT 1
        ];
        
        // 1) 보유 포인트
        List<LoyaltyMemberCurrency> currencies = [
            SELECT 	PointsBalance
            FROM LoyaltyMemberCurrency
            WHERE LoyaltyMemberId  = : lpmId
            LIMIT 1
        ];
        
        benefit.ownedPoint = currencies.isEmpty()
            ? 0
            : Integer.valueOf(currencies[0].PointsBalance);
        
        // 2) 보유 쿠폰 수
        benefit.ownedCoupon = [
            SELECT COUNT()
            FROM Voucher
            WHERE LoyaltyProgramMemberId = :lpmId
            AND Status = 'Issued'
            AND (ExpirationDateTime = null OR ExpirationDateTime >= :System.now())
        ];
        
        return benefit;
    }
    
    // 나의 등급 정보
    private static MemberGradeDTO getMemberGrade(Id lpmId) {
        
        MemberGradeDTO grade = new MemberGradeDTO();
        
        LoyaltyMemberTier lmt = [
            SELECT
                LoyaltyTier.Name,
                EffectiveDate
            FROM LoyaltyMemberTier
            WHERE LoyaltyMemberId = :lpmId
            ORDER BY EffectiveDate DESC
            LIMIT 1
        ];
        
        
        // 현재 등급명
        grade.currentGrade =
            lmt.LoyaltyTier != null ? lmt.LoyaltyTier.Name : null;
        
        // 누적 구매액 (아직 데이터 소스 없음 → 0 처리)
        grade.totalPurchaseAmount = 0;
        
        //정채 필요
        
        // 등급 적용일
        grade.lastUpdatedDate = lmt.EffectiveDate;
        
        return grade;
    }
    
    
    //마케팅 수신 동의 정보
    private static MarketingConsentDTO getMarketingConsent(Id lpmId) {
        
        MarketingConsentDTO consent = new MarketingConsentDTO();
        
        LoyaltyProgramMember lpm = [
            SELECT
                Contact.IsEmailAgreed__c,
                Contact.IsSMSAgreed__c,
                Contact.IsMagazineSubscribed__c,
                Contact.MagazineSubscriptionDate__c
            FROM LoyaltyProgramMember
            WHERE Id = :lpmId
            LIMIT 1
        ];
        
        
        if (lpm.Contact == null) {
            return consent;
        }
        
        consent.emailConsent = lpm.Contact.IsEmailAgreed__c;
        consent.emailUpdatedDate = null; // 이메일 동의일 필드 없음
        
        consent.smsConsent = lpm.Contact.IsSMSAgreed__c;
        consent.smsUpdatedDate = null;   // SMS 동의일 필드 없음
        
        consent.magazineConsent = lpm.Contact.IsMagazineSubscribed__c;
        consent.magazineUpdatedDate = lpm.Contact.MagazineSubscriptionDate__c;
        
        return consent;
        
        
    }
    
    
    
    
    //DTO 집합체
    public class MemberInfoDto{
        @AuraEnabled public MemberBenefitDTO benefit;          // 사용 가능 혜택
        @AuraEnabled public MemberGradeDTO grade;              // 나의 등급 정보
        @AuraEnabled public MarketingConsentDTO marketing;     // 마케팅 수신 동의
        
    }
    
    //나의 혜택 dto
    public class MemberBenefitDTO {
        
        @AuraEnabled public Integer ownedPoint;     // 보유 포인트
        @AuraEnabled public Integer ownedCoupon;    // 보유 쿠폰 수
        
    }
    
    //둥급 정보 dto
    public class MemberGradeDTO {
        
        @AuraEnabled public String currentGrade;        // GIP
        @AuraEnabled public Integer totalPurchaseAmount; // 누적 구매액 (800000)
        @AuraEnabled public Integer remainAmount;        // 다음 등급까지 남은 금액 (50000)
        @AuraEnabled public Datetime lastUpdatedDate;    // 업데이트 일시
        
    }
    
    //마케팅 수신 동의 여부 dto
    
    public class MarketingConsentDTO {
        
        @AuraEnabled public Boolean emailConsent;
        @AuraEnabled public Datetime emailUpdatedDate;
        
        @AuraEnabled public Boolean smsConsent;
        @AuraEnabled public Datetime smsUpdatedDate;
        
        @AuraEnabled public Boolean magazineConsent;
        @AuraEnabled public Datetime magazineUpdatedDate;
        
    }
}