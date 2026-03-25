public with sharing class LoyaltyPgmCrySubtypeViewControllerV1 {
  @AuraEnabled(cacheable=true)
  public static SubtypeViewDto getSubtype(Id recordId) {
    if (recordId == null) {
      return null;
    }

    LoyaltyPgmCurrencySubtype subtype = [
      SELECT
        Id,
        Name,
        Description,
        PointTypeCode__c,
        UsagePriorityNumber,
        CostPerUnit,
        LoyaltyProgramCurrency.Name,
        CreatedBy.Name,
        CreatedDate,
        LastModifiedBy.Name,
        LastModifiedDate
      FROM LoyaltyPgmCurrencySubtype
      WHERE Id = :recordId
      LIMIT 1
    ];

    List<Benefit> benefitList = [
      SELECT Id, Name, Description, PurchasePointRate__c, IsActive, IsBenefitSelectionAllowed, PrioritySequence
      FROM Benefit
      WHERE LoyaltyPgmCurrencySubtypeId__c = :recordId
      ORDER BY PrioritySequence ASC NULLS LAST, LastModifiedDate DESC
    ];

    SubtypeViewDto dto = new SubtypeViewDto();
    dto.id = subtype.Id;
    dto.name = subtype.Name;
    dto.description = subtype.Description;
    dto.pointTypeCode = subtype.PointTypeCode__c;
    dto.usagePriorityNumber = subtype.UsagePriorityNumber;
    dto.costPerUnit = subtype.CostPerUnit;
    dto.programCurrencyName = subtype.LoyaltyProgramCurrency != null ? subtype.LoyaltyProgramCurrency.Name : null;
    dto.createdByName = subtype.CreatedBy != null ? subtype.CreatedBy.Name : null;
    dto.createdDate = subtype.CreatedDate;
    dto.lastModifiedByName = subtype.LastModifiedBy != null ? subtype.LastModifiedBy.Name : null;
    dto.lastModifiedDate = subtype.LastModifiedDate;
    dto.benefitCount = benefitList.size();
    dto.benefits = new List<BenefitDto>();

    for (Benefit benefit : benefitList) {
      BenefitDto benefitDto = new BenefitDto();
      benefitDto.id = benefit.Id;
      benefitDto.name = benefit.Name;
      benefitDto.description = benefit.Description;
      benefitDto.purchasePointRate = benefit.PurchasePointRate__c;
      benefitDto.isActive = benefit.IsActive;
      benefitDto.isBenefitSelectionAllowed = benefit.IsBenefitSelectionAllowed;
      benefitDto.prioritySequence = benefit.PrioritySequence;
      dto.benefits.add(benefitDto);
    }

    return dto;
  }

  public class SubtypeViewDto {
    @AuraEnabled
    public Id id;

    @AuraEnabled
    public String name;

    @AuraEnabled
    public String description;

    @AuraEnabled
    public String pointTypeCode;

    @AuraEnabled
    public Decimal usagePriorityNumber;

    @AuraEnabled
    public Decimal costPerUnit;

    @AuraEnabled
    public String programCurrencyName;

    @AuraEnabled
    public String createdByName;

    @AuraEnabled
    public Datetime createdDate;

    @AuraEnabled
    public String lastModifiedByName;

    @AuraEnabled
    public Datetime lastModifiedDate;

    @AuraEnabled
    public Integer benefitCount;

    @AuraEnabled
    public List<BenefitDto> benefits;
  }

  public class BenefitDto {
    @AuraEnabled
    public Id id;

    @AuraEnabled
    public String name;

    @AuraEnabled
    public String description;

    @AuraEnabled
    public Decimal purchasePointRate;

    @AuraEnabled
    public Boolean isActive;

    @AuraEnabled
    public Boolean isBenefitSelectionAllowed;

    @AuraEnabled
    public Decimal prioritySequence;
  }
}