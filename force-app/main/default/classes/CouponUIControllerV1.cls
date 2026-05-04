public with sharing class CouponUIControllerV1 {
  private static final Integer SEARCH_LIMIT = 30;
  private static final Integer CATEGORY_SEARCH_LIMIT = 2000;
  private static final Decimal MAX_DISCOUNT_RATE_LIMIT = 100;
  private static final Decimal MIN_TOTAL_QUANTITY_LIMIT = 999999;
  private static final Decimal MIN_SALES_AMOUNT_LIMIT = 999999999;

  private static final List<String> LIMIT_ORDER = new List<String>{
    'ProductIncludeList',
    'StoreIncludeList',
    'StoreTypeIncludeList',
    'DiscountRate',
    'GradeIncludeList',
    'ProductCategoryIncludeList',
    'OrderTypeIncludeList',
    'TotalQuantity',
    'SalesAmount'
  };

  private static final Set<String> POLICY_LIMIT_TYPES = new Set<String>(LIMIT_ORDER);

  private static final Map<String, String> LIMIT_LABEL_MAP = new Map<String, String>{
    'ProductIncludeList' => '사용 가능 제품',
    'StoreIncludeList' => '사용 가능 매장',
    'StoreTypeIncludeList' => '사용 가능 매장 구분',
    'DiscountRate' => '적용 가능 판매 할인율',
    'GradeIncludeList' => '사용 가능 회원 등급',
    'ProductCategoryIncludeList' => '사용 가능 제품 분류',
    'OrderTypeIncludeList' => '사용 가능 주문 구분',
    'TotalQuantity' => '사용 가능 판매 개수',
    'SalesAmount' => '사용 가능 판매 금액'
  };

  private static final Map<String, String> ORDER_TYPE_LABEL_MAP = new Map<String, String>{
    '01' => '고객',
    '02' => '진열',
    '03' => '수선',
    '04' => '가주문',
    '10' => 'B2B'
  };

  @AuraEnabled(cacheable=true)
  public static CouponDetailDTO getCouponDetail(Id voucherDefinitionId) {
    if (voucherDefinitionId == null) {
      return null;
    }

    VoucherDefinition voucherDefinition = [
      SELECT
        Id,
        Name,
        Description,
        CouponManNo__c,
        Type,
        DiscountPercent,
        FaceValue,
        IsActive,
        ExpirationType,
        ExpirationDate,
        ExpirationPeriod,
        ExpirationPeriodUnit
      FROM VoucherDefinition
      WHERE Id = :voucherDefinitionId
      LIMIT 1
    ];

    CouponDetailDTO dto = new CouponDetailDTO();
    dto.voucherDefinitionName = voucherDefinition.Name;
    dto.description = voucherDefinition.Description;
    dto.couponNum = voucherDefinition.CouponManNo__c;
    dto.couponType = voucherDefinition.Type;
    dto.discountPercent = voucherDefinition.DiscountPercent;
    dto.couponvalue = voucherDefinition.FaceValue;
    dto.status = voucherDefinition.IsActive;
    dto.expirationType = voucherDefinition.ExpirationType;
    dto.expirationDate = voucherDefinition.ExpirationDate;
    dto.expirationPeriod = voucherDefinition.ExpirationPeriod;
    dto.expirationPeriodUnit = voucherDefinition.ExpirationPeriodUnit;
    dto.limitSummaryList = buildLimitSummary(buildResolvedLimitContext(getActiveVoucherLimits(voucherDefinitionId)));
    return dto;
  }

  @AuraEnabled(cacheable=true)
  public static CouponPolicyConfigDTO getCouponPolicyConfig(Id voucherDefinitionId) {
    System.debug(voucherDefinitionId);
    if (voucherDefinitionId == null) {
      System.debug('쿠폰 정의 id 없습니다.');
      throw new AuraHandledException('쿠폰 사용 정책을 조회할 쿠폰 ID가 없습니다.');
    }

    ResolvedLimitContext context = buildResolvedLimitContext(getActiveVoucherLimits(voucherDefinitionId));

    CouponPolicyConfigDTO config = new CouponPolicyConfigDTO();
    config.productIncludeItems = buildSelectionList(context, 'ProductIncludeList');
    config.storeIncludeItems = buildSelectionList(context, 'StoreIncludeList');
    config.gradeIncludeItems = buildSelectionList(context, 'GradeIncludeList');
    config.productCategoryIncludeItems = buildSelectionList(context, 'ProductCategoryIncludeList');
    config.storeTypeOptions = buildStoreTypeSelections(context.limitMap.get('StoreTypeIncludeList'));
    config.orderTypeOptions = buildOrderTypeSelections(context.limitMap.get('OrderTypeIncludeList'));
    config.discountRateOperator = readComparisonOperator(context.limitMap.get('DiscountRate'));
    config.discountRate = readDecimalValue(context.limitMap.get('DiscountRate'));
    config.totalQuantityOperator = readComparisonOperator(context.limitMap.get('TotalQuantity'));
    config.totalQuantity = readDecimalValue(context.limitMap.get('TotalQuantity'));
    config.salesAmountOperator = readComparisonOperator(context.limitMap.get('SalesAmount'));
    config.salesAmount = readDecimalValue(context.limitMap.get('SalesAmount'));

    System.debug(config);
    return config;
  }
  @AuraEnabled(cacheable=true)
  public static List<CouponPolicyTargetDTO> searchCouponPolicyTargets(String targetType, String keyword, List<String> excludeIds) {
    Set<String> excludedValues = normalizeTextSet(excludeIds);
    String likeKeyword = '%' + (String.isBlank(keyword) ? '' : keyword.trim()) + '%';

    if (targetType == 'PRODUCT') {
      return searchProducts(likeKeyword, excludedValues);
    }
    if (targetType == 'STORE') {
      return searchStores(likeKeyword, excludedValues);
    }
    if (targetType == 'GRADE') {
      return searchGrades(likeKeyword, excludedValues);
    }
    if (targetType == 'CATEGORY') {
      return searchCategories(likeKeyword, excludedValues);
    }

    return new List<CouponPolicyTargetDTO>();
  }

  @AuraEnabled(cacheable=true)
  public static List<CouponPolicyTargetDTO> getCategoryPolicyNodes(
    String parentLevel,
    String systemCode,
    String largeCode,
    String mediumCode,
    List<String> excludeIds
  ) {
    Set<String> excludedValues = normalizeTextSet(excludeIds);
    String normalizedParentLevel = String.isBlank(parentLevel) ? 'ROOT' : parentLevel.trim().toUpperCase();
    List<CouponPolicyTargetDTO> results = new List<CouponPolicyTargetDTO>();

    if (normalizedParentLevel == 'ROOT') {
      for (ProductCategory category : [
        SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, IsActive__c
        FROM ProductCategory
        WHERE IsActive__c = TRUE AND LargeCategoryCode__c != NULL AND MediumCategoryCode__c = NULL AND SmallCategoryCode__c = NULL
        ORDER BY Name
      ]) {
        if (isExcludedCategory(category, excludedValues)) {
          continue;
        }
        results.add(buildCategoryTarget(category, 'LARGE', category, null));
      }
      return results;
    }

    if (normalizedParentLevel == 'LARGE') {
      if (String.isBlank(systemCode) || String.isBlank(largeCode)) {
        return results;
      }

      ProductCategory largeCategory = getLargeCategory(systemCode, largeCode);
      for (ProductCategory category : [
        SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, IsActive__c
        FROM ProductCategory
        WHERE
          IsActive__c = TRUE
          AND SystemCode__c = :systemCode
          AND LargeCategoryCode__c = :largeCode
          AND MediumCategoryCode__c != NULL
          AND SmallCategoryCode__c = NULL
        ORDER BY Name
      ]) {
        if (isExcludedCategory(category, excludedValues)) {
          continue;
        }
        results.add(buildCategoryTarget(category, 'MEDIUM', largeCategory, category));
      }
      return results;
    }

    if (normalizedParentLevel == 'MEDIUM') {
      if (String.isBlank(systemCode) || String.isBlank(largeCode) || String.isBlank(mediumCode)) {
        return results;
      }

      ProductCategory largeCategory = getLargeCategory(systemCode, largeCode);
      ProductCategory mediumCategory = getMediumCategory(systemCode, largeCode, mediumCode);
      for (ProductCategory category : [
        SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, IsActive__c
        FROM ProductCategory
        WHERE
          IsActive__c = TRUE
          AND SystemCode__c = :systemCode
          AND LargeCategoryCode__c = :largeCode
          AND MediumCategoryCode__c = :mediumCode
          AND SmallCategoryCode__c != NULL
        ORDER BY Name
      ]) {
        if (isExcludedCategory(category, excludedValues)) {
          continue;
        }
        results.add(buildCategoryTarget(category, 'SMALL', largeCategory, mediumCategory));
      }
      return results;
    }

    return results;
  }

  @AuraEnabled
  public static void saveCouponPolicy(String requestJson) {
    Savepoint savepointRef = Database.setSavepoint();
    try {
      CouponPolicySaveRequestDTO request = (CouponPolicySaveRequestDTO) JSON.deserialize(requestJson, CouponPolicySaveRequestDTO.class);

      if (request == null || request.voucherDefinitionId == null) {
        throw new AuraHandledException('저장할 쿠폰 정보가 없습니다.');
      }

      Set<String> productCodes = resolveProductCodes(request.productIncludeIds);
      Set<String> storeCodes = resolveStoreCodes(request.storeIncludeIds);
      Set<String> gradeCodes = resolveGradeCodes(request.gradeIncludeIds);
      Set<String> categoryCodes = resolveCategoryCodes(request.productCategoryIncludeIds);
      Set<String> storeTypes = normalizeTextSet(request.storeTypeValues);
      Set<String> orderTypes = normalizeTextSet(request.orderTypeValues);

      Boolean hasAnyValue =
        !productCodes.isEmpty() ||
        !storeCodes.isEmpty() ||
        !gradeCodes.isEmpty() ||
        !categoryCodes.isEmpty() ||
        !storeTypes.isEmpty() ||
        !orderTypes.isEmpty() ||
        request.discountRate != null ||
        request.totalQuantity != null ||
        request.salesAmount != null;

      if (false && !hasAnyValue) {
        throw new AuraHandledException('저장할 정책이 없습니다.');
      }

      if (!hasAnyValue) {
        List<VoucherLimit__c> emptySelectionDeleteList = [
          SELECT Id
          FROM VoucherLimit__c
          WHERE VoucherDefinitionId__c = :request.voucherDefinitionId AND Type__c IN :POLICY_LIMIT_TYPES
        ];
        if (!emptySelectionDeleteList.isEmpty()) {
          delete emptySelectionDeleteList;
        }
        return;
      }

      validatePolicyNumberRanges(request);

      Map<String, VoucherLimit__c> desiredLimitByKey = buildDesiredPolicyLimits(request);
      Map<String, VoucherLimit__c> existingLimitByKey = new Map<String, VoucherLimit__c>();
      List<VoucherLimit__c> deleteList = new List<VoucherLimit__c>();

      for (VoucherLimit__c existingLimit : [
        SELECT Id, Type__c, Value__c, ProductCode__c, ProductName__c, ObjectName__c, ComparisonOperator__c
        FROM VoucherLimit__c
        WHERE VoucherDefinitionId__c = :request.voucherDefinitionId AND Type__c IN :POLICY_LIMIT_TYPES
      ]) {
        String policyKey = buildPolicyKey(existingLimit);
        if (existingLimitByKey.containsKey(policyKey) || !desiredLimitByKey.containsKey(policyKey)) {
          deleteList.add(existingLimit);
          continue;
        }
        existingLimitByKey.put(policyKey, existingLimit);
      }

      if (!deleteList.isEmpty()) {
        delete deleteList;
      }

      List<VoucherLimit__c> insertList = new List<VoucherLimit__c>();
      for (String policyKey : desiredLimitByKey.keySet()) {
        if (!existingLimitByKey.containsKey(policyKey)) {
          insertList.add(desiredLimitByKey.get(policyKey));
        }
      }

      if (!insertList.isEmpty()) {
        insert insertList;
      }
    } catch (AuraHandledException e) {
      Database.rollback(savepointRef);
      throw e;
    } catch (Exception e) {
      Database.rollback(savepointRef);
      throw new AuraHandledException('쿠폰 사용 정책 저장 실패: ' + e.getMessage());
    }
  }
  private static List<CouponPolicyTargetDTO> searchProducts(String likeKeyword, Set<String> excludedValues) {
    List<CouponPolicyTargetDTO> results = new List<CouponPolicyTargetDTO>();
    for (Product2 product : [
      SELECT Id, Name, ProductCode
      FROM Product2
      WHERE IsActive = TRUE AND ProductCode != NULL AND (Name LIKE :likeKeyword OR ProductCode LIKE :likeKeyword)
      ORDER BY Name
      LIMIT :SEARCH_LIMIT
    ]) {
      if (excludedValues.contains(product.ProductCode) || excludedValues.contains(product.Id)) {
        continue;
      }
      results.add(buildTarget(product.ProductCode, product.Name, product.ProductCode));
    }
    return results;
  }

  private static List<CouponPolicyTargetDTO> searchStores(String likeKeyword, Set<String> excludedValues) {
    List<CouponPolicyTargetDTO> results = new List<CouponPolicyTargetDTO>();
    for (Account accountRecord : [
      SELECT Id, Name, StoreCode__c, StoreType__c
      FROM Account
      WHERE StoreCode__c != NULL AND (Name LIKE :likeKeyword OR StoreCode__c LIKE :likeKeyword OR StoreType__c LIKE :likeKeyword)
      ORDER BY Name
      LIMIT :SEARCH_LIMIT
    ]) {
      if (excludedValues.contains(accountRecord.StoreCode__c) || excludedValues.contains((String) accountRecord.Id)) {
        continue;
      }
      results.add(buildTarget(accountRecord.StoreCode__c, accountRecord.Name, null));
    }
    return results;
  }

  private static List<CouponPolicyTargetDTO> searchGrades(String likeKeyword, Set<String> excludedValues) {
    List<CouponPolicyTargetDTO> results = new List<CouponPolicyTargetDTO>();
    for (LoyaltyTier tier : [
      SELECT Id, Name, Grade__c
      FROM LoyaltyTier
      WHERE Grade__c != NULL AND (Name LIKE :likeKeyword OR Grade__c LIKE :likeKeyword)
      ORDER BY Name
      LIMIT :SEARCH_LIMIT
    ]) {
      if (excludedValues.contains(tier.Grade__c) || excludedValues.contains((String) tier.Id)) {
        continue;
      }
      results.add(buildTarget(tier.Grade__c, tier.Name, null));
    }
    return results;
  }

  private static List<CouponPolicyTargetDTO> searchCategories(String likeKeyword, Set<String> excludedValues) {
    List<ProductCategory> categories = [
      SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, IsActive__c
      FROM ProductCategory
      WHERE IsActive__c = TRUE AND SystemCode__c != NULL AND LargeCategoryCode__c != NULL
      ORDER BY SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, Name
      LIMIT :CATEGORY_SEARCH_LIMIT
    ];

    return buildCategorySearchResults(categories, likeKeyword, excludedValues);
  }

  private static List<LimitSummaryDTO> buildLimitSummary(ResolvedLimitContext context) {
    List<LimitSummaryDTO> result = new List<LimitSummaryDTO>();

    for (String typeKey : LIMIT_ORDER) {
      if (!context.limitMap.containsKey(typeKey)) {
        continue;
      }

      LimitSummaryDTO dto = new LimitSummaryDTO();
      dto.type = typeKey;
      dto.label = LIMIT_LABEL_MAP.get(typeKey);
      dto.valueList = new List<String>();
      dto.valueDetailList = new List<LimitSummaryItemDTO>();

      for (VoucherLimit__c limitRecord : context.limitMap.get(typeKey)) {
        if (typeKey == 'ProductIncludeList') {
          String productCode = resolveProductCode(limitRecord, context);
          String productName = resolveProductName(limitRecord, context);
          dto.valueList.add(String.isBlank(productName) ? productCode : productName);
          dto.valueDetailList.add(new LimitSummaryItemDTO(productCode, String.isBlank(productName) ? productCode : productName));
        } else if (typeKey == 'StoreIncludeList') {
          String storeCode = resolveStoreCode(limitRecord, context);
          String storeName = resolveStoreName(limitRecord, context);
          dto.valueList.add(String.isBlank(storeName) ? storeCode : storeName);
          dto.valueDetailList.add(new LimitSummaryItemDTO(storeCode, String.isBlank(storeName) ? storeCode : storeName));
        } else if (typeKey == 'GradeIncludeList') {
          dto.valueList.add(resolveGradeDisplay(limitRecord, context));
        } else if (typeKey == 'ProductCategoryIncludeList') {
          dto.valueList.add(resolveCategoryDisplay(limitRecord, context));
        } else if (typeKey == 'StoreTypeIncludeList') {
          dto.valueList.add(resolveStoreTypeLabel(limitRecord.Value__c));
        } else if (typeKey == 'OrderTypeIncludeList') {
          dto.valueList.add(
            ORDER_TYPE_LABEL_MAP.containsKey(limitRecord.Value__c) ? ORDER_TYPE_LABEL_MAP.get(limitRecord.Value__c) : limitRecord.Value__c
          );
        } else if (typeKey == 'DiscountRate' || typeKey == 'TotalQuantity' || typeKey == 'SalesAmount') {
          String operatorLabel = resolveComparisonOperatorLabel(limitRecord.ComparisonOperator__c);
          String valueWithUnit = formatNumericLimitValue(typeKey, limitRecord.Value__c);
          dto.valueList.add(String.isBlank(operatorLabel) ? valueWithUnit : valueWithUnit + ' ' + operatorLabel);
          dto.valueDetailList.add(new LimitSummaryItemDTO(operatorLabel, valueWithUnit));
        } else {
          dto.valueList.add(limitRecord.Value__c);
        }
      }

      result.add(dto);
    }

    return result;
  }

  private static ResolvedLimitContext buildResolvedLimitContext(List<VoucherLimit__c> limits) {
    ResolvedLimitContext context = new ResolvedLimitContext();

    Set<String> productCodes = new Set<String>();
    Set<Id> productIds = new Set<Id>();
    Set<String> storeCodes = new Set<String>();
    Set<Id> storeIds = new Set<Id>();
    Set<String> gradeCodes = new Set<String>();
    Set<Id> gradeIds = new Set<Id>();
    Set<String> categoryCodes = new Set<String>();
    Set<Id> categoryIds = new Set<Id>();

    for (VoucherLimit__c limitRecord : limits) {
      if (!context.limitMap.containsKey(limitRecord.Type__c)) {
        context.limitMap.put(limitRecord.Type__c, new List<VoucherLimit__c>());
      }
      context.limitMap.get(limitRecord.Type__c).add(limitRecord);

      if (limitRecord.Type__c == 'ProductIncludeList') {
        if (!String.isBlank(limitRecord.ProductCode__c)) {
          productCodes.add(limitRecord.ProductCode__c);
        } else if (isSalesforceId(limitRecord.Value__c)) {
          productIds.add((Id) limitRecord.Value__c);
        } else {
          productCodes.add(limitRecord.Value__c);
        }
      } else if (limitRecord.Type__c == 'StoreIncludeList') {
        if (isSalesforceId(limitRecord.Value__c)) {
          storeIds.add((Id) limitRecord.Value__c);
        } else {
          storeCodes.add(limitRecord.Value__c);
        }
      } else if (limitRecord.Type__c == 'GradeIncludeList') {
        if (isSalesforceId(limitRecord.Value__c)) {
          gradeIds.add((Id) limitRecord.Value__c);
        } else {
          gradeCodes.add(limitRecord.Value__c);
        }
      } else if (limitRecord.Type__c == 'ProductCategoryIncludeList') {
        if (isSalesforceId(limitRecord.Value__c)) {
          categoryIds.add((Id) limitRecord.Value__c);
        } else {
          categoryCodes.add(limitRecord.Value__c);
        }
      }
    }

    if (!productCodes.isEmpty() || !productIds.isEmpty()) {
      for (Product2 product : [SELECT Id, Name, ProductCode FROM Product2 WHERE ProductCode IN :productCodes OR Id IN :productIds]) {
        context.productByCode.put(product.ProductCode, product);
        context.productById.put(product.Id, product);
      }
    }

    if (!storeCodes.isEmpty() || !storeIds.isEmpty()) {
      for (Account accountRecord : [SELECT Id, Name, StoreCode__c, StoreType__c FROM Account WHERE StoreCode__c IN :storeCodes OR Id IN :storeIds]) {
        context.storeByCode.put(accountRecord.StoreCode__c, accountRecord);
        context.storeById.put(accountRecord.Id, accountRecord);
      }
    }

    if (!gradeCodes.isEmpty() || !gradeIds.isEmpty()) {
      for (LoyaltyTier tier : [SELECT Id, Name, Grade__c FROM LoyaltyTier WHERE Grade__c IN :gradeCodes OR Id IN :gradeIds]) {
        context.gradeByCode.put(tier.Grade__c, tier);
        context.gradeById.put(tier.Id, tier);
      }
    }

    if (!categoryIds.isEmpty()) {
      for (ProductCategory category : [
        SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c
        FROM ProductCategory
        WHERE Id IN :categoryIds
      ]) {
        addResolvedCategory(context, category);
      }
    }

    if (!categoryCodes.isEmpty()) {
      Set<String> systemCodes = extractCategorySystemCodes(categoryCodes);
      for (ProductCategory category : [
        SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, IsActive__c
        FROM ProductCategory
        WHERE IsActive__c = TRUE AND Code IN :categoryCodes
      ]) {
        addResolvedCategory(context, category);
      }

      if (!systemCodes.isEmpty()) {
        for (ProductCategory category : [
          SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, IsActive__c
          FROM ProductCategory
          WHERE IsActive__c = TRUE AND SystemCode__c IN :systemCodes AND LargeCategoryCode__c != NULL
        ]) {
          String categoryCode = buildCategoryCode(category);
          if (categoryCodes.contains(categoryCode)) {
            addResolvedCategory(context, category);
          }
        }
      }
    }

    return context;
  }

  private static List<CouponPolicyTargetDTO> buildSelectionList(ResolvedLimitContext context, String typeKey) {
    List<CouponPolicyTargetDTO> result = new List<CouponPolicyTargetDTO>();
    if (!context.limitMap.containsKey(typeKey)) {
      return result;
    }

    for (VoucherLimit__c limitRecord : context.limitMap.get(typeKey)) {
      if (typeKey == 'ProductIncludeList') {
        Product2 product = resolveProduct(limitRecord, context);
        String productCode = resolveProductCode(limitRecord, context);
        String productName = product == null ? limitRecord.ProductName__c : product.Name;
        result.add(buildTarget(productCode, String.isBlank(productName) ? productCode : productName, productCode));
      } else if (typeKey == 'StoreIncludeList') {
        Account accountRecord = resolveStore(limitRecord, context);
        String storeCode = resolveStoreCode(limitRecord, context);
        result.add(buildTarget(storeCode, accountRecord == null ? storeCode : accountRecord.Name, null));
      } else if (typeKey == 'GradeIncludeList') {
        LoyaltyTier tier = resolveGrade(limitRecord, context);
        String gradeCode = resolveGradeCode(limitRecord, context);
        result.add(buildTarget(gradeCode, tier == null ? gradeCode : tier.Name, null));
      } else if (typeKey == 'ProductCategoryIncludeList') {
        ProductCategory category = resolveCategory(limitRecord, context);
        String categoryCode = resolveCategoryCode(limitRecord, context);
        if (category == null) {
          result.add(buildTarget(categoryCode, categoryCode, null));
        } else {
          ProductCategory largeCategory = context.categoryByCode.get(
            String.join(new List<String>{ category.SystemCode__c, category.LargeCategoryCode__c }, '-')
          );
          ProductCategory mediumCategory = context.categoryByCode.get(
            String.join(new List<String>{ category.SystemCode__c, category.LargeCategoryCode__c, blankIfNull(category.MediumCategoryCode__c) }, '-')
          );
          result.add(buildCategoryTarget(category, resolveCategoryLevel(category), largeCategory, mediumCategory));
        }
      }
    }

    return result;
  }

  private static List<OrderTypeOptionDTO> buildOrderTypeSelections(List<VoucherLimit__c> limits) {
    Map<String, String> labelMap = getPicklistLabelMap(Order.Type);
    Set<String> selectedValues = new Set<String>();
    if (limits != null) {
      for (VoucherLimit__c limitRecord : limits) {
        selectedValues.add(limitRecord.Value__c);
      }
    }

    List<OrderTypeOptionDTO> result = new List<OrderTypeOptionDTO>();
    for (String valueKey : labelMap.keySet()) {
      OrderTypeOptionDTO option = new OrderTypeOptionDTO();
      option.value = valueKey;
      option.label = labelMap.get(valueKey);
      option.selected = selectedValues.contains(valueKey);
      result.add(option);
    }
    return result;
  }

  private static List<OrderTypeOptionDTO> buildStoreTypeSelections(List<VoucherLimit__c> limits) {
    Map<String, String> labelMap = getPicklistLabelMap(Account.StoreType__c);
    Set<String> selectedValues = new Set<String>();
    if (limits != null) {
      for (VoucherLimit__c limitRecord : limits) {
        selectedValues.add(limitRecord.Value__c);
      }
    }

    List<OrderTypeOptionDTO> result = new List<OrderTypeOptionDTO>();
    for (String keyValue : labelMap.keySet()) {
      OrderTypeOptionDTO option = new OrderTypeOptionDTO();
      option.value = keyValue;
      option.label = labelMap.get(keyValue);
      option.selected = selectedValues.contains(keyValue);
      result.add(option);
    }
    return result;
  }

  private static Decimal readDecimalValue(List<VoucherLimit__c> limits) {
    if (limits == null || limits.isEmpty() || String.isBlank(limits[0].Value__c)) {
      return null;
    }
    return Decimal.valueOf(limits[0].Value__c);
  }

  private static String readComparisonOperator(List<VoucherLimit__c> limits) {
    if (limits == null || limits.isEmpty()) {
      return null;
    }
    return limits[0].ComparisonOperator__c;
  }

  private static List<VoucherLimit__c> getActiveVoucherLimits(Id voucherDefinitionId) {
    return [
      SELECT Id, Type__c, Value__c, ProductCode__c, ProductName__c, ObjectName__c, ComparisonOperator__c
      FROM VoucherLimit__c
      WHERE VoucherDefinitionId__c = :voucherDefinitionId AND IsActive__c = TRUE AND Type__c IN :POLICY_LIMIT_TYPES
    ];
  }

  private static Map<String, String> getPicklistLabelMap(Schema.SObjectField fieldRef) {
    Map<String, String> labelMap = new Map<String, String>();
    for (Schema.PicklistEntry entry : fieldRef.getDescribe().getPicklistValues()) {
      labelMap.put(entry.getValue(), entry.getLabel());
    }
    return labelMap;
  }

  private static Product2 resolveProduct(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    if (!String.isBlank(limitRecord.ProductCode__c) && context.productByCode.containsKey(limitRecord.ProductCode__c)) {
      return context.productByCode.get(limitRecord.ProductCode__c);
    }
    if (isSalesforceId(limitRecord.Value__c) && context.productById.containsKey((Id) limitRecord.Value__c)) {
      return context.productById.get((Id) limitRecord.Value__c);
    }
    return context.productByCode.get(limitRecord.Value__c);
  }

  private static Account resolveStore(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    if (isSalesforceId(limitRecord.Value__c) && context.storeById.containsKey((Id) limitRecord.Value__c)) {
      return context.storeById.get((Id) limitRecord.Value__c);
    }
    return context.storeByCode.get(limitRecord.Value__c);
  }

  private static LoyaltyTier resolveGrade(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    if (isSalesforceId(limitRecord.Value__c) && context.gradeById.containsKey((Id) limitRecord.Value__c)) {
      return context.gradeById.get((Id) limitRecord.Value__c);
    }
    return context.gradeByCode.get(limitRecord.Value__c);
  }

  private static ProductCategory resolveCategory(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    if (isSalesforceId(limitRecord.Value__c) && context.categoryById.containsKey((Id) limitRecord.Value__c)) {
      return context.categoryById.get((Id) limitRecord.Value__c);
    }
    return context.categoryByCode.get(limitRecord.Value__c);
  }

  private static String resolveProductCode(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    Product2 product = resolveProduct(limitRecord, context);
    if (product != null && !String.isBlank(product.ProductCode)) {
      return product.ProductCode;
    }
    return !String.isBlank(limitRecord.ProductCode__c) ? limitRecord.ProductCode__c : limitRecord.Value__c;
  }

  private static String resolveStoreCode(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    Account accountRecord = resolveStore(limitRecord, context);
    return accountRecord == null ? limitRecord.Value__c : accountRecord.StoreCode__c;
  }

  private static String resolveProductName(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    Product2 product = resolveProduct(limitRecord, context);
    if (product != null && !String.isBlank(product.Name)) {
      return product.Name;
    }
    return limitRecord.ProductName__c;
  }

  private static String resolveStoreName(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    Account accountRecord = resolveStore(limitRecord, context);
    return accountRecord == null ? null : accountRecord.Name;
  }

  private static String resolveStoreDisplay(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    String storeName = resolveStoreName(limitRecord, context);
    return String.isBlank(storeName) ? resolveStoreCode(limitRecord, context) : storeName;
  }

  private static String resolveGradeCode(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    LoyaltyTier tier = resolveGrade(limitRecord, context);
    return tier == null ? limitRecord.Value__c : tier.Grade__c;
  }

  private static String resolveGradeDisplay(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    LoyaltyTier tier = resolveGrade(limitRecord, context);
    return tier == null ? limitRecord.Value__c : tier.Name;
  }

  private static String resolveCategoryCode(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    ProductCategory category = resolveCategory(limitRecord, context);
    return category == null ? limitRecord.Value__c : buildCategoryCode(category);
  }

  private static String resolveCategoryName(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    ProductCategory category = resolveCategory(limitRecord, context);
    return category == null ? null : category.Name;
  }

  private static String resolveCategoryDisplay(VoucherLimit__c limitRecord, ResolvedLimitContext context) {
    ProductCategory category = resolveCategory(limitRecord, context);
    if (category == null) {
      return limitRecord.Value__c;
    }

    ProductCategory largeCategory = context.categoryByCode.get(
      String.join(new List<String>{ category.SystemCode__c, category.LargeCategoryCode__c }, '-')
    );
    ProductCategory mediumCategory = context.categoryByCode.get(
      String.join(new List<String>{ category.SystemCode__c, category.LargeCategoryCode__c, blankIfNull(category.MediumCategoryCode__c) }, '-')
    );

    CouponPolicyTargetDTO dto = buildCategoryTarget(category, resolveCategoryLevel(category), largeCategory, mediumCategory);
    return dto.pathLabel;
  }

  private static String resolveStoreTypeLabel(String storeTypeValue) {
    Map<String, String> labelMap = getPicklistLabelMap(Account.StoreType__c);
    return labelMap.containsKey(storeTypeValue) ? labelMap.get(storeTypeValue) : storeTypeValue;
  }

  private static String resolveOrderTypeLabel(String orderTypeValue) {
    Map<String, String> labelMap = getPicklistLabelMap(Order.Type);
    return labelMap.containsKey(orderTypeValue) ? labelMap.get(orderTypeValue) : orderTypeValue;
  }

  private static String buildCategoryCode(ProductCategory category) {
    List<String> parts = new List<String>();
    if (!String.isBlank(category.SystemCode__c)) {
      parts.add(category.SystemCode__c);
    }
    if (!String.isBlank(category.LargeCategoryCode__c)) {
      parts.add(category.LargeCategoryCode__c);
    }
    if (!String.isBlank(category.MediumCategoryCode__c)) {
      parts.add(category.MediumCategoryCode__c);
    }
    if (!String.isBlank(category.SmallCategoryCode__c)) {
      parts.add(category.SmallCategoryCode__c);
    }
    return parts.isEmpty() ? null : String.join(parts, '-');
  }

  private static List<VoucherLimit__c> buildProductLimits(Id voucherDefinitionId, Set<String> productCodes) {
    Map<String, Product2> productByCode = new Map<String, Product2>();
    if (!productCodes.isEmpty()) {
      for (Product2 product : [SELECT Id, Name, ProductCode FROM Product2 WHERE ProductCode IN :productCodes]) {
        productByCode.put(product.ProductCode, product);
      }
    }

    List<VoucherLimit__c> result = new List<VoucherLimit__c>();
    for (String productCode : productCodes) {
      VoucherLimit__c limitRecord = buildVoucherLimit(voucherDefinitionId, 'ProductIncludeList', productCode, 'Product2');
      limitRecord.ProductCode__c = productCode;
      if (productByCode.containsKey(productCode)) {
        limitRecord.ProductName__c = productByCode.get(productCode).Name;
      }
      result.add(limitRecord);
    }
    return result;
  }

  private static List<VoucherLimit__c> buildTextLimits(Id voucherDefinitionId, String typeName, String objectName, Set<String> values) {
    List<VoucherLimit__c> result = new List<VoucherLimit__c>();
    for (String value : values) {
      result.add(buildVoucherLimit(voucherDefinitionId, typeName, value, objectName));
    }
    return result;
  }

  private static List<VoucherLimit__c> buildNumericLimits(Id voucherDefinitionId, String typeName, Decimal value, String comparisonOperator) {
    if (value == null) {
      return new List<VoucherLimit__c>();
    }
    if (String.isBlank(comparisonOperator)) {
      throw new AuraHandledException('숫자 조건에는 이상/이하를 선택해 주세요.');
    }
    return new List<VoucherLimit__c>{ buildVoucherLimit(voucherDefinitionId, typeName, String.valueOf(value), null, comparisonOperator) };
  }

  private static VoucherLimit__c buildVoucherLimit(Id voucherDefinitionId, String typeName, String value, String objectName) {
    return buildVoucherLimit(voucherDefinitionId, typeName, value, objectName, null);
  }

  private static VoucherLimit__c buildVoucherLimit(
    Id voucherDefinitionId,
    String typeName,
    String value,
    String objectName,
    String comparisonOperator
  ) {
    VoucherLimit__c limitRecord = new VoucherLimit__c();
    limitRecord.VoucherDefinitionId__c = voucherDefinitionId;
    limitRecord.Type__c = typeName;
    limitRecord.Value__c = value;
    limitRecord.ObjectName__c = objectName;
    limitRecord.ComparisonOperator__c = comparisonOperator;
    limitRecord.IsActive__c = true;
    return limitRecord;
  }

  private static Map<String, VoucherLimit__c> buildDesiredPolicyLimits(CouponPolicySaveRequestDTO request) {
    Set<String> productCodes = resolveProductCodes(request.productIncludeIds);
    Set<String> storeCodes = resolveStoreCodes(request.storeIncludeIds);
    Set<String> gradeCodes = resolveGradeCodes(request.gradeIncludeIds);
    Set<String> categoryCodes = resolveCategoryCodes(request.productCategoryIncludeIds);
    Set<String> storeTypes = normalizeTextSet(request.storeTypeValues);
    Set<String> orderTypes = normalizeTextSet(request.orderTypeValues);

    List<VoucherLimit__c> desiredLimits = new List<VoucherLimit__c>();
    desiredLimits.addAll(buildProductLimits(request.voucherDefinitionId, productCodes));
    desiredLimits.addAll(buildTextLimits(request.voucherDefinitionId, 'StoreIncludeList', 'Account', storeCodes));
    desiredLimits.addAll(buildTextLimits(request.voucherDefinitionId, 'GradeIncludeList', 'Contact', gradeCodes));
    desiredLimits.addAll(buildTextLimits(request.voucherDefinitionId, 'ProductCategoryIncludeList', 'ProductCategory', categoryCodes));
    desiredLimits.addAll(buildTextLimits(request.voucherDefinitionId, 'StoreTypeIncludeList', 'Account', storeTypes));
    desiredLimits.addAll(buildTextLimits(request.voucherDefinitionId, 'OrderTypeIncludeList', 'Order', orderTypes));
    desiredLimits.addAll(buildNumericLimits(request.voucherDefinitionId, 'DiscountRate', request.discountRate, request.discountRateOperator));
    desiredLimits.addAll(buildNumericLimits(request.voucherDefinitionId, 'TotalQuantity', request.totalQuantity, request.totalQuantityOperator));
    desiredLimits.addAll(buildNumericLimits(request.voucherDefinitionId, 'SalesAmount', request.salesAmount, request.salesAmountOperator));

    Map<String, VoucherLimit__c> desiredLimitByKey = new Map<String, VoucherLimit__c>();
    for (VoucherLimit__c desiredLimit : desiredLimits) {
      desiredLimitByKey.put(buildPolicyKey(desiredLimit), desiredLimit);
    }
    return desiredLimitByKey;
  }

  private static void validatePolicyNumberRanges(CouponPolicySaveRequestDTO request) {
    validatePolicyNumberRange(request.discountRate, 0, MAX_DISCOUNT_RATE_LIMIT, '적용 가능 판매 할인율');
    validatePolicyNumberRange(request.totalQuantity, 0, MIN_TOTAL_QUANTITY_LIMIT, '사용 가능 판매개수');
    validatePolicyNumberRange(request.salesAmount, 0, MIN_SALES_AMOUNT_LIMIT, '사용 가능 판매금액');
  }

  private static void validatePolicyNumberRange(Decimal value, Decimal minValue, Decimal maxValue, String fieldLabel) {
    if (value == null) {
      return;
    }

    if (value < minValue || value > maxValue) {
      throw new AuraHandledException(
        fieldLabel + '은(는) ' + String.valueOf(minValue) + ' 이상 ' + String.valueOf(maxValue) + ' 이하로 입력해 주세요.'
      );
    }
  }

  private static CouponPolicyTargetDTO buildTarget(String idValue, String nameValue, String codeValue) {
    CouponPolicyTargetDTO dto = new CouponPolicyTargetDTO();
    dto.id = idValue;
    dto.name = nameValue;
    dto.code = codeValue;
    return dto;
  }

  private static List<CouponPolicyTargetDTO> buildCategorySearchResults(
    List<ProductCategory> categories,
    String likeKeyword,
    Set<String> excludedValues
  ) {
    String keyword = normalizeSearchKeyword(likeKeyword);
    Map<String, ProductCategory> largeByKey = new Map<String, ProductCategory>();
    Map<String, ProductCategory> mediumByKey = new Map<String, ProductCategory>();
    List<ProductCategory> smallCategories = new List<ProductCategory>();

    for (ProductCategory category : categories) {
      String categoryLevel = resolveCategoryLevel(category);
      if (categoryLevel == 'LARGE') {
        largeByKey.put(buildLargeCategoryKey(category), category);
      } else if (categoryLevel == 'MEDIUM') {
        mediumByKey.put(buildMediumCategoryKey(category), category);
      } else if (categoryLevel == 'SMALL') {
        smallCategories.add(category);
      }
    }

    Set<String> matchedLargeKeys = new Set<String>();
    Set<String> matchedMediumKeys = new Set<String>();
    Set<String> matchedSmallCodes = new Set<String>();

    for (ProductCategory category : categories) {
      if (!matchesCategoryKeyword(category, keyword)) {
        continue;
      }

      String categoryLevel = resolveCategoryLevel(category);
      if (categoryLevel == 'LARGE') {
        matchedLargeKeys.add(buildLargeCategoryKey(category));
      } else if (categoryLevel == 'MEDIUM') {
        matchedLargeKeys.add(buildLargeCategoryKey(category));
        matchedMediumKeys.add(buildMediumCategoryKey(category));
      } else if (categoryLevel == 'SMALL') {
        matchedLargeKeys.add(buildLargeCategoryKey(category));
        matchedMediumKeys.add(buildMediumCategoryKey(category));
        matchedSmallCodes.add(buildCategoryCode(category));
      }
    }

    if (String.isBlank(keyword)) {
      matchedLargeKeys.addAll(largeByKey.keySet());
    }

    Map<String, CouponPolicyTargetDTO> resultByCode = new Map<String, CouponPolicyTargetDTO>();
    for (ProductCategory category : categories) {
      String categoryLevel = resolveCategoryLevel(category);
      String largeKey = buildLargeCategoryKey(category);
      String mediumKey = buildMediumCategoryKey(category);
      String categoryCode = buildCategoryCode(category);

      Boolean shouldInclude = false;
      if (categoryLevel == 'LARGE') {
        shouldInclude = matchedLargeKeys.contains(largeKey);
      } else if (categoryLevel == 'MEDIUM') {
        shouldInclude = matchedMediumKeys.contains(mediumKey);
      } else if (categoryLevel == 'SMALL') {
        shouldInclude = matchedSmallCodes.contains(categoryCode);
      }

      if (!shouldInclude || String.isBlank(categoryCode) || excludedValues.contains(categoryCode) || excludedValues.contains((String) category.Id)) {
        continue;
      }

      ProductCategory largeCategory = largeByKey.get(largeKey);
      ProductCategory mediumCategory = mediumByKey.get(mediumKey);
      resultByCode.put(categoryCode, buildCategoryTarget(category, categoryLevel, largeCategory, mediumCategory));
    }

    return resultByCode.values();
  }

  private static CouponPolicyTargetDTO buildCategoryTarget(
    ProductCategory category,
    String categoryLevel,
    ProductCategory largeCategory,
    ProductCategory mediumCategory
  ) {
    CouponPolicyTargetDTO dto = buildTarget(buildCategoryCode(category), category.Name, buildCategoryCode(category));
    dto.level = categoryLevel;
    dto.systemCode = category.SystemCode__c;
    dto.largeCode = category.LargeCategoryCode__c;
    dto.mediumCode = category.MediumCategoryCode__c;
    dto.smallCode = category.SmallCategoryCode__c;
    dto.largeName = largeCategory == null ? category.LargeCategoryCode__c : largeCategory.Name;
    dto.mediumName = mediumCategory == null ? category.MediumCategoryCode__c : mediumCategory.Name;
    dto.smallName = category.SmallCategoryCode__c == null ? null : category.Name;
    dto.pathLabel = buildCategoryPathLabel(dto);
    return dto;
  }

  private static String buildCategoryPathLabel(CouponPolicyTargetDTO dto) {
    List<String> parts = new List<String>();
    if (!String.isBlank(dto.largeName)) {
      parts.add(dto.largeName);
    }
    if (!String.isBlank(dto.mediumName) && dto.level != 'LARGE') {
      parts.add(dto.mediumName);
    }
    if (!String.isBlank(dto.smallName) && dto.level == 'SMALL') {
      parts.add(dto.smallName);
    }
    return String.join(parts, ' > ');
  }

  private static String normalizeSearchKeyword(String likeKeyword) {
    return String.isBlank(likeKeyword) ? '' : likeKeyword.replace('%', '').trim().toLowerCase();
  }

  private static Boolean matchesCategoryKeyword(ProductCategory category, String keyword) {
    if (String.isBlank(keyword)) {
      return true;
    }

    return safeLower(category.Name).contains(keyword);
  }

  private static String safeLower(String value) {
    return String.isBlank(value) ? '' : value.toLowerCase();
  }

  private static String resolveCategoryLevel(ProductCategory category) {
    if (!String.isBlank(category.SmallCategoryCode__c)) {
      return 'SMALL';
    }
    if (!String.isBlank(category.MediumCategoryCode__c)) {
      return 'MEDIUM';
    }
    return 'LARGE';
  }

  private static String buildLargeCategoryKey(ProductCategory category) {
    return String.join(new List<String>{ category.SystemCode__c, category.LargeCategoryCode__c }, '|');
  }

  private static String buildMediumCategoryKey(ProductCategory category) {
    return String.join(new List<String>{ category.SystemCode__c, category.LargeCategoryCode__c, blankIfNull(category.MediumCategoryCode__c) }, '|');
  }

  private static ProductCategory getLargeCategory(String systemCode, String largeCode) {
    List<ProductCategory> categories = [
      SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, IsActive__c
      FROM ProductCategory
      WHERE
        IsActive__c = TRUE
        AND SystemCode__c = :systemCode
        AND LargeCategoryCode__c = :largeCode
        AND MediumCategoryCode__c = NULL
        AND SmallCategoryCode__c = NULL
      LIMIT 1
    ];
    return categories.isEmpty() ? null : categories[0];
  }

  private static ProductCategory getMediumCategory(String systemCode, String largeCode, String mediumCode) {
    List<ProductCategory> categories = [
      SELECT Id, Name, Code, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c, IsActive__c
      FROM ProductCategory
      WHERE
        IsActive__c = TRUE
        AND SystemCode__c = :systemCode
        AND LargeCategoryCode__c = :largeCode
        AND MediumCategoryCode__c = :mediumCode
        AND SmallCategoryCode__c = NULL
      LIMIT 1
    ];
    return categories.isEmpty() ? null : categories[0];
  }

  private static Boolean isExcludedCategory(ProductCategory category, Set<String> excludedValues) {
    String categoryCode = buildCategoryCode(category);
    return excludedValues.contains((String) category.Id) ||
      (!String.isBlank(categoryCode) && excludedValues.contains(categoryCode)) ||
      (!String.isBlank(category.Code) && excludedValues.contains(category.Code));
  }

  private static String blankIfNull(String value) {
    return value == null ? '' : value;
  }

  private static String buildPolicyKey(VoucherLimit__c limitRecord) {
    List<String> keyParts = new List<String>{ normalizePolicyKeyValue(limitRecord.Type__c), normalizePolicyKeyValue(limitRecord.ObjectName__c) };

    if (limitRecord.Type__c == 'ProductIncludeList') {
      keyParts.add(normalizePolicyKeyValue(limitRecord.ProductCode__c));
    } else {
      keyParts.add(normalizePolicyKeyValue(limitRecord.Value__c));
    }

    if (limitRecord.Type__c == 'DiscountRate' || limitRecord.Type__c == 'TotalQuantity' || limitRecord.Type__c == 'SalesAmount') {
      keyParts.add(normalizePolicyKeyValue(limitRecord.ComparisonOperator__c));
    }

    return String.join(keyParts, '|');
  }

  private static String normalizePolicyKeyValue(String value) {
    return String.isBlank(value) ? '' : value.trim();
  }

  private static void addResolvedCategory(ResolvedLimitContext context, ProductCategory category) {
    String categoryCode = buildCategoryCode(category);
    if (!String.isBlank(categoryCode)) {
      context.categoryByCode.put(categoryCode, category);
    }
    if (!String.isBlank(category.Code)) {
      context.categoryByCode.put(category.Code, category);
    }
    context.categoryById.put(category.Id, category);
  }

  private static Set<String> extractCategorySystemCodes(Set<String> categoryCodes) {
    Set<String> systemCodes = new Set<String>();
    for (String categoryCode : categoryCodes) {
      if (String.isBlank(categoryCode)) {
        continue;
      }
      List<String> parts = categoryCode.split('-');
      if (!parts.isEmpty() && !String.isBlank(parts[0])) {
        systemCodes.add(parts[0].trim());
      }
    }
    return systemCodes;
  }

  private static Boolean isSalesforceId(String value) {
    return !String.isBlank(value) && Pattern.matches('^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$', value);
  }

  private static Set<String> normalizeTextSet(List<String> values) {
    Set<String> result = new Set<String>();
    for (String value : values == null ? new List<String>() : values) {
      if (!String.isBlank(value)) {
        result.add(value.trim());
      }
    }
    return result;
  }

  private static Set<String> resolveProductCodes(List<String> values) {
    Set<String> normalizedValues = normalizeTextSet(values);
    Set<String> productCodes = new Set<String>();
    Set<Id> productIds = new Set<Id>();

    for (String value : normalizedValues) {
      if (isSalesforceId(value)) {
        productIds.add((Id) value);
      } else {
        productCodes.add(value);
      }
    }

    if (!productIds.isEmpty()) {
      for (Product2 product : [SELECT ProductCode FROM Product2 WHERE Id IN :productIds AND ProductCode != NULL]) {
        productCodes.add(product.ProductCode);
      }
    }

    return productCodes;
  }

  private static Set<String> resolveStoreCodes(List<String> values) {
    Set<String> normalizedValues = normalizeTextSet(values);
    Set<String> storeCodes = new Set<String>();
    Set<Id> storeIds = new Set<Id>();

    for (String value : normalizedValues) {
      if (isSalesforceId(value)) {
        storeIds.add((Id) value);
      } else {
        storeCodes.add(value);
      }
    }

    if (!storeIds.isEmpty()) {
      for (Account accountRecord : [SELECT StoreCode__c FROM Account WHERE Id IN :storeIds AND StoreCode__c != NULL]) {
        storeCodes.add(accountRecord.StoreCode__c);
      }
    }

    return storeCodes;
  }

  private static Set<String> resolveGradeCodes(List<String> values) {
    Set<String> normalizedValues = normalizeTextSet(values);
    Set<String> gradeCodes = new Set<String>();
    Set<Id> gradeIds = new Set<Id>();

    for (String value : normalizedValues) {
      if (isSalesforceId(value)) {
        gradeIds.add((Id) value);
      } else {
        gradeCodes.add(value);
      }
    }

    if (!gradeIds.isEmpty()) {
      for (LoyaltyTier tier : [SELECT Grade__c FROM LoyaltyTier WHERE Id IN :gradeIds AND Grade__c != NULL]) {
        gradeCodes.add(tier.Grade__c);
      }
    }

    return gradeCodes;
  }

  private static Set<String> resolveCategoryCodes(List<String> values) {
    Set<String> normalizedValues = normalizeTextSet(values);
    Set<String> categoryCodes = new Set<String>();
    Set<Id> categoryIds = new Set<Id>();

    for (String value : normalizedValues) {
      if (isSalesforceId(value)) {
        categoryIds.add((Id) value);
      } else {
        categoryCodes.add(value);
      }
    }

    if (!categoryIds.isEmpty()) {
      for (ProductCategory category : [
        SELECT Id, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c
        FROM ProductCategory
        WHERE Id IN :categoryIds
      ]) {
        String categoryCode = buildCategoryCode(category);
        if (!String.isBlank(categoryCode)) {
          categoryCodes.add(categoryCode);
        }
      }
    }

    return categoryCodes;
  }

  private static String resolveComparisonOperatorLabel(String comparisonOperator) {
    if (comparisonOperator == 'GTE' || comparisonOperator == '이상' || comparisonOperator == '01') {
      return '이상';
    }
    if (comparisonOperator == 'LTE' || comparisonOperator == '이하' || comparisonOperator == '02') {
      return '이하';
    }
    return null;
  }

  private static String formatNumericLimitValue(String typeKey, String value) {
    if (String.isBlank(value)) {
      return value;
    }
    if (typeKey == 'DiscountRate') {
      return value + '%';
    }
    if (typeKey == 'TotalQuantity') {
      return value + '개';
    }
    if (typeKey == 'SalesAmount') {
      return value + '원';
    }
    return value;
  }

  public class CouponDetailDTO {
    @AuraEnabled
    public String voucherDefinitionName;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String couponNum;
    @AuraEnabled
    public String couponType;
    @AuraEnabled
    public Decimal discountPercent;
    @AuraEnabled
    public Decimal couponvalue;
    @AuraEnabled
    public Boolean status;
    @AuraEnabled
    public String expirationType;
    @AuraEnabled
    public Date expirationDate;
    @AuraEnabled
    public Decimal expirationPeriod;
    @AuraEnabled
    public String expirationPeriodUnit;
    @AuraEnabled
    public List<LimitSummaryDTO> limitSummaryList;
  }

  public class LimitSummaryDTO {
    @AuraEnabled
    public String type;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public List<String> valueList;
    @AuraEnabled
    public List<LimitSummaryItemDTO> valueDetailList;
  }

  public class LimitSummaryItemDTO {
    @AuraEnabled
    public String code;
    @AuraEnabled
    public String name;

    public LimitSummaryItemDTO(String code, String name) {
      this.code = code;
      this.name = name;
    }
  }

  public class CouponPolicyConfigDTO {
    @AuraEnabled
    public List<CouponPolicyTargetDTO> productIncludeItems;
    @AuraEnabled
    public List<CouponPolicyTargetDTO> storeIncludeItems;
    @AuraEnabled
    public List<CouponPolicyTargetDTO> gradeIncludeItems;
    @AuraEnabled
    public List<CouponPolicyTargetDTO> productCategoryIncludeItems;
    @AuraEnabled
    public List<OrderTypeOptionDTO> storeTypeOptions;
    @AuraEnabled
    public List<OrderTypeOptionDTO> orderTypeOptions;
    @AuraEnabled
    public String discountRateOperator;
    @AuraEnabled
    public Decimal discountRate;
    @AuraEnabled
    public String totalQuantityOperator;
    @AuraEnabled
    public Decimal totalQuantity;
    @AuraEnabled
    public String salesAmountOperator;
    @AuraEnabled
    public Decimal salesAmount;
  }

  public class CouponPolicyTargetDTO {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String code;
    @AuraEnabled
    public String level;
    @AuraEnabled
    public String systemCode;
    @AuraEnabled
    public String largeCode;
    @AuraEnabled
    public String mediumCode;
    @AuraEnabled
    public String smallCode;
    @AuraEnabled
    public String largeName;
    @AuraEnabled
    public String mediumName;
    @AuraEnabled
    public String smallName;
    @AuraEnabled
    public String pathLabel;
  }

  public class OrderTypeOptionDTO {
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Boolean selected;
  }

  public class CouponPolicySaveRequestDTO {
    @AuraEnabled
    public Id voucherDefinitionId;
    @AuraEnabled
    public List<String> productIncludeIds;
    @AuraEnabled
    public List<String> storeIncludeIds;
    @AuraEnabled
    public List<String> storeTypeValues;
    @AuraEnabled
    public List<String> gradeIncludeIds;
    @AuraEnabled
    public List<String> productCategoryIncludeIds;
    @AuraEnabled
    public List<String> orderTypeValues;
    @AuraEnabled
    public String discountRateOperator;
    @AuraEnabled
    public Decimal discountRate;
    @AuraEnabled
    public String totalQuantityOperator;
    @AuraEnabled
    public Decimal totalQuantity;
    @AuraEnabled
    public String salesAmountOperator;
    @AuraEnabled
    public Decimal salesAmount;
  }

  private class ResolvedLimitContext {
    Map<String, List<VoucherLimit__c>> limitMap = new Map<String, List<VoucherLimit__c>>();
    Map<String, Product2> productByCode = new Map<String, Product2>();
    Map<Id, Product2> productById = new Map<Id, Product2>();
    Map<String, Account> storeByCode = new Map<String, Account>();
    Map<Id, Account> storeById = new Map<Id, Account>();
    Map<String, LoyaltyTier> gradeByCode = new Map<String, LoyaltyTier>();
    Map<Id, LoyaltyTier> gradeById = new Map<Id, LoyaltyTier>();
    Map<String, ProductCategory> categoryByCode = new Map<String, ProductCategory>();
    Map<Id, ProductCategory> categoryById = new Map<Id, ProductCategory>();
  }
}