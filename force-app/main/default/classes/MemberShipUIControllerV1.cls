public with sharing class MemberShipUIControllerV1 {
  @AuraEnabled(cacheable=true)
  public static MemberShipDetailDto getMemberTierView(Id loyaltyTierId) {
    if (loyaltyTierId == null)
      return null;

    List<LoyaltyTier> tierList = [
      SELECT Id, Name, Description, LoyaltyTierGroupId, SystemModstamp, Color, Grade__c
      FROM LoyaltyTier
      WHERE Id = :loyaltyTierId
      LIMIT 1
    ];

    if (tierList.isEmpty())
      return null;

    LoyaltyTier tier = tierList[0];

    Integer memberCount = [
      SELECT COUNT()
      FROM LoyaltyMemberTier
      WHERE LoyaltyTierId = :tier.Id
    ];

    MemberShipDetailDto dto = new MemberShipDetailDto();
    dto.tierName = tier.Name;
    dto.description = tier.Description;
    dto.memberCount = memberCount;
    dto.effectiveDate = tier.SystemModstamp.date();
    dto.tierColor = tier.Color;
    dto.benefits = new List<TierBenefitDto>();

    for (LoyaltyTierBenefit tierBenefit : [
      SELECT Benefit.Name, Benefit.PurchasePointRate__c, Benefit.IsActive
      FROM LoyaltyTierBenefit
      WHERE LoyaltyTierId = :loyaltyTierId AND BenefitId != NULL AND Benefit.IsActive = TRUE
      ORDER BY Benefit.Name
    ]) {
      TierBenefitDto benefitDto = new TierBenefitDto();
      benefitDto.benefitName = tierBenefit.Benefit != null ? tierBenefit.Benefit.Name : null;
      benefitDto.rate = tierBenefit.Benefit != null ? tierBenefit.Benefit.PurchasePointRate__c : null;
      dto.benefits.add(benefitDto);
    }

    return dto;
  }

  @AuraEnabled
  public static void issueTierCoupon(Id loyaltyTierId, Id voucherDefinitionId) {
    if (loyaltyTierId == null || voucherDefinitionId == null) {
      throw new AuraHandledException('등급 또는 쿠폰 정보가 없습니다.');
    }

    String tierGradeCode = getTierGradeCode(loyaltyTierId);

    if (!isVoucherAllowedForTier(voucherDefinitionId, tierGradeCode)) {
      throw new AuraHandledException('해당 등급 회원에게 지급할 수 없는 쿠폰입니다.');
    }

    Database.executeBatch(new IssueTierCouponBatch(loyaltyTierId, voucherDefinitionId, Date.today()), 100);
  }

  @AuraEnabled(cacheable=true)
  public static List<VoucherOptionDto> getTierCouponOptions(Id loyaltyTierId) {
    if (loyaltyTierId == null)
      return new List<VoucherOptionDto>();

    String tierGradeCode = getTierGradeCode(loyaltyTierId);

    List<VoucherDefinition> listVd = [
      SELECT Id, Name
      FROM VoucherDefinition
      WHERE IsActive = TRUE
    ];

    List<VoucherOptionDto> result = new List<VoucherOptionDto>();

    for (VoucherDefinition vd : listVd) {
      result.add(new VoucherOptionDto(vd.Id, vd.Name));
    }

    return result;
  }

  private static String getTierGradeCode(Id loyaltyTierId) {
    List<LoyaltyTier> tierList = [
      SELECT Grade__c
      FROM LoyaltyTier
      WHERE Id = :loyaltyTierId
      LIMIT 1
    ];

    if (tierList.isEmpty() || String.isBlank(tierList[0].Grade__c)) {
      throw new AuraHandledException('등급 코드가 없습니다.');
    }

    return tierList[0].Grade__c;
  }

  // 🔥 핵심 수정
  @TestVisible
  private static Boolean isVoucherAllowedForTier(Id vdId, String gradeCode) {
    List<VoucherLimit__c> limits = [
      SELECT Value__c
      FROM VoucherLimit__c
      WHERE VoucherDefinitionId__c = :vdId AND Type__c = 'GradeIncludeList' AND IsActive__c = TRUE
    ];

    if (limits.isEmpty())
      return true;

    for (VoucherLimit__c l : limits) {
      if (l.Value__c == gradeCode)
        return true;
    }

    return false;
  }

  public class MemberShipDetailDto {
    @AuraEnabled
    public String tierName;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Integer memberCount;
    @AuraEnabled
    public Date effectiveDate;
    @AuraEnabled
    public String tierColor;
    @AuraEnabled
    public List<TierBenefitDto> benefits;
  }

  public class TierBenefitDto {
    @AuraEnabled
    public String benefitName;
    @AuraEnabled
    public Decimal rate;
  }

  public class VoucherOptionDto {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;
    public VoucherOptionDto(String id, String name) {
      this.label = name;
      this.value = id;
    }
  }
}