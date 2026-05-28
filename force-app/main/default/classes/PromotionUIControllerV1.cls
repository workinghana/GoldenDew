public with sharing class PromotionUIControllerV1 {
  /* =====================================================
   * Picklist Label 조회 함수 (Map 없이 단순화)
   * ===================================================== */
  private static String getPicklistLabel(Schema.SObjectField field, String value) {
    if (value == null)
      return null;

    for (Schema.PicklistEntry entry : field.getDescribe().getPicklistValues()) {
      if (entry.getValue() == value) {
        return entry.getLabel();
      }
    }
    return value; // fallback
  }

  /* =====================================================
   * API
   * ===================================================== */
  @AuraEnabled(cacheable=true)
  public static List<PromotionDetailDTO> getPromotionHistory(Id promotionId) {
    List<PromotionDetailDTO> result = new List<PromotionDetailDTO>();
    if (promotionId == null)
      return result;

    /* ================= Promotion ================= */

    Promotion p = [
      SELECT
        Id,
        Name,
        DisplayName,
        PromotionCode,
        IsActive,
        StartDate,
        EndDate,
        PublishStartDate__c,
        PublishEndDate__c,
        DiscountRate__c,
        ProductCatalogId,
        IsPointUsageAllowed__c,
        PointTypeCode__c,
        StoreType__c
      FROM Promotion
      WHERE Id = :promotionId
      LIMIT 1
    ];

    PromotionDetailDTO dto = new PromotionDetailDTO();

    dto.name = p.Name;
    dto.DisplayName = p.DisplayName;
    dto.PromotionCode = p.PromotionCode;
    dto.IsActive = p.IsActive;
    dto.StartDate = p.StartDate;
    dto.EndDate = p.EndDate;
    dto.PublishStartDate = p.PublishStartDate__c;
    dto.PublishEndDate = p.PublishEndDate__c;
    dto.DiscountRate = p.DiscountRate__c;
    dto.IsPointUsageAllowed = p.IsPointUsageAllowed__c;

    /* =====================================================
     * 매장 조회 (Picklist Label 기반)
     * ===================================================== */

    List<PromotionAccount__c> paList = [
      SELECT AccountId__c
      FROM PromotionAccount__c
      WHERE PromotionId__c = :promotionId AND IsActive__c = TRUE
    ];

    Set<Id> accountIds = new Set<Id>();
    for (PromotionAccount__c pa : paList) {
      accountIds.add(pa.AccountId__c);
    }

    List<Account> accounts = new List<Account>();
    if (!accountIds.isEmpty()) {
      accounts = [
        SELECT Id, Name
        FROM Account
        WHERE Id IN :accountIds
      ];
    }

    Set<String> storeNames = new Set<String>();

    for (Account acc : accounts) {
      if (!String.isBlank(acc.Name)) {
        storeNames.add(acc.Name);
      }
    }

    // 매장(구분): PromotionAccount__c 자식 → Account.Name (26.05.28 hana 수정)
    dto.storegroup = storeNames.isEmpty() ? null : String.join(new List<String>(storeNames), ';');

    // 매장(계열): Promotion.StoreType__c 멀티픽리스트 Label 기반 (26.05.28 hana 수정)
    dto.storedetail = getMultiPicklistLabels(Promotion.StoreType__c, p.StoreType__c);

    /* =====================================================
     * 상품 조회
     * ===================================================== */

    List<ProductCategoryProduct> pcpList = new List<ProductCategoryProduct>();
    if (p.ProductCatalogId != null) {
      pcpList = [
        SELECT ProductId
        FROM ProductCategoryProduct
        WHERE CatalogId = :p.ProductCatalogId
      ];
    }

    Set<Id> productIds = new Set<Id>();
    for (ProductCategoryProduct pcp : pcpList) {
      if (pcp.ProductId != null) {
        productIds.add(pcp.ProductId);
      }
    }

    List<Product2> products = new List<Product2>();
    if (!productIds.isEmpty()) {
      products = [
        SELECT Name
        FROM Product2
        WHERE Id IN :productIds
      ];
    }

    List<String> productNames = new List<String>();
    for (Product2 prod : products) {
      productNames.add(prod.Name);
    }

    dto.productNames = productNames.isEmpty() ? null : String.join(productNames, ', ');

    /* =====================================================
     * 포인트 적립 여부
     * ===================================================== */

    List<PromotionPointLimit__c> pointLimitList = [
      SELECT LoyaltyPgmCurrencySubtypeName__c, LoyaltyPgmCurrencySubtypeId__r.Name
      FROM PromotionPointLimit__c
      WHERE PromotionId__c = :promotionId
    ];

    dto.pointAccrualAvailablePointTypes = buildPointAccrualAvailablePointTypes(pointLimitList, p.PointTypeCode__c);
    dto.pointAccrualUnavailablePointTypes = getMultiPicklistLabels(Promotion.PointTypeCode__c, p.PointTypeCode__c);
    dto.isPointAccrualAvailable = !String.isBlank(dto.pointAccrualAvailablePointTypes);

    /* =====================================================
     * 쿠폰 존재 여부
     * ===================================================== */

    Integer voucherCount = [
      SELECT COUNT()
      FROM VoucherLimit__c
      WHERE PromotionId__c = :promotionId
    ];

    dto.isCouponAvailable = voucherCount > 0;

    result.add(dto);
    return result;
  }

  /* =====================================================
   * DTO
   * ===================================================== */
  public class PromotionDetailDTO {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String DisplayName;
    @AuraEnabled
    public String PromotionCode;
    @AuraEnabled
    public Boolean IsActive;

    @AuraEnabled
    public Date StartDate;
    @AuraEnabled
    public Date EndDate;
    @AuraEnabled
    public Date PublishStartDate;
    @AuraEnabled
    public Date PublishEndDate;

    @AuraEnabled
    public Decimal DiscountRate;

    @AuraEnabled
    public String storegroup;
    @AuraEnabled
    public String storedetail;

    @AuraEnabled
    public String productNames;

    @AuraEnabled
    public Boolean isPointAccrualAvailable;
    @AuraEnabled
    public String pointAccrualAvailablePointTypes;
    @AuraEnabled
    public String pointAccrualUnavailablePointTypes;

    @AuraEnabled
    public Boolean IsPointUsageAllowed;

    @AuraEnabled
    public Boolean isCouponAvailable;
  }

  private static String buildPointAccrualAvailablePointTypes(List<PromotionPointLimit__c> pointLimitList, String excludedPointTypeCodes) {
    Set<String> pointTypeNames = new Set<String>();

    if (pointLimitList != null) {
      for (PromotionPointLimit__c pointLimit : pointLimitList) {
        String pointTypeName = !String.isBlank(pointLimit.LoyaltyPgmCurrencySubtypeName__c)
          ? pointLimit.LoyaltyPgmCurrencySubtypeName__c
          : (pointLimit.LoyaltyPgmCurrencySubtypeId__r == null ? null : pointLimit.LoyaltyPgmCurrencySubtypeId__r.Name);

        if (!String.isBlank(pointTypeName)) {
          pointTypeNames.add(pointTypeName);
        }
      }
    }

    if (!pointTypeNames.isEmpty()) {
      return String.join(new List<String>(pointTypeNames), ', ');
    }

    return String.isBlank(excludedPointTypeCodes) ? '전체 포인트' : null;
  }

  private static String getMultiPicklistLabels(Schema.SObjectField fieldRef, String rawValues) {
    if (String.isBlank(rawValues)) {
      return null;
    }

    Map<String, String> labelByValue = new Map<String, String>();
    for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
      labelByValue.put(entry.getValue(), entry.getLabel());
    }

    List<String> labels = new List<String>();
    for (String rawValue : rawValues.split(';')) {
      String value = rawValue == null ? null : rawValue.trim();
      if (String.isBlank(value)) {
        continue;
      }
      labels.add(labelByValue.containsKey(value) ? labelByValue.get(value) : value);
    }

    return labels.isEmpty() ? null : String.join(labels, ', ');
  }
}
