public with sharing class PointDefinitionViewControllerV1 {
  @AuraEnabled(cacheable=true)
  public static LoyaltyCurrencyDTO getLoyaltyCurrencyDetail(Id loyaltyCurrencyId) {
    if (loyaltyCurrencyId == null) {
      return null;
    }

    /* ================= 1. 포인트 정의 ================= */
    LoyaltyProgramCurrency lpc = [
      SELECT Id, Name, IsActive, CurrencyType, ExpiryPeriodFrequency, ExpiryPeriodUnit, ExpiryModel, CostperUnit, HasEscrow, DoesAllowLedgerTracing
      FROM LoyaltyProgramCurrency
      WHERE Id = :loyaltyCurrencyId
      LIMIT 1
    ];

    /* ================= 2. 포인트 하위 유형 ================= */
    LoyaltyPgmCurrencySubtype subtype;
    List<LoyaltyPgmCurrencySubtype> subtypeList = [
      SELECT PointTypeCode__c, UsagePriorityNumber
      FROM LoyaltyPgmCurrencySubtype
      WHERE LoyaltyProgramCurrencyId = :loyaltyCurrencyId
      ORDER BY UsagePriorityNumber ASC
      LIMIT 1
    ];

    if (!subtypeList.isEmpty()) {
      subtype = subtypeList[0];
    }

    /* ================= 3. 포인트 원장 ================= */
    LoyaltyAggrSubPointExprLedger__c ledger;
    List<LoyaltyAggrSubPointExprLedger__c> ledgerList = [
      SELECT AccruedPoints__c, AvailablePoints__c, ExpiryDate__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramCurrencyId__c = :loyaltyCurrencyId
      ORDER BY ExpiryDate__c ASC
      LIMIT 1
    ];

    if (!ledgerList.isEmpty()) {
      ledger = ledgerList[0];
    }

    /* ================= DTO 매핑 ================= */
    LoyaltyCurrencyDTO dto = new LoyaltyCurrencyDTO();
    dto.pointName = lpc.Name;
    dto.isActive = lpc.IsActive;
    dto.currencyType = lpc.CurrencyType;

    dto.expiryPeriodFrequency = lpc.ExpiryPeriodFrequency;
    dto.expiryPeriodUnit = lpc.ExpiryPeriodUnit;

    if (subtype != null) {
      dto.pointTypeCode = subtype.PointTypeCode__c;
      dto.usagePriority = subtype.UsagePriorityNumber;
      dto.usagePriorityNumber = subtype.UsagePriorityNumber;
    }

    if (ledger != null) {
      dto.accruedPoints = ledger.AvailablePoints__c;
      dto.expiryDate = ledger.ExpiryDate__c;
    }

    return dto;
  }

  /* ================= DTO ================= */
  public class LoyaltyCurrencyDTO {
    @AuraEnabled
    public String pointName;
    @AuraEnabled
    public String pointTypeCode;
    @AuraEnabled
    public String currencyType;
    @AuraEnabled
    public Boolean isActive;
    @AuraEnabled
    public Integer usagePriority;
    @AuraEnabled
    public Decimal accruedPoints;
    @AuraEnabled
    public Integer expiryPeriodFrequency;
    @AuraEnabled
    public String expiryPeriodUnit;
    @AuraEnabled
    public Date expiryDate;
    @AuraEnabled
    public Integer usagePriorityNumber;
  }
}