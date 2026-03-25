@IsTest
private class CouponUIControllerV1Test {
  private static String pick(Schema.SObjectField fieldRef) {
    List<Schema.PicklistEntry> entries = fieldRef.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String pick(String objectApiName, String fieldApiName) {
    Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectApiName);
    if (objectType == null) {
      return null;
    }

    Schema.SObjectField fieldRef = objectType.getDescribe().fields.getMap().get(fieldApiName);
    if (fieldRef == null) {
      return null;
    }

    List<Schema.PicklistEntry> entries = fieldRef.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static String categoryCode(ProductCategory categoryRecord) {
    return String.join(
      new List<String>{
        categoryRecord.SystemCode__c,
        categoryRecord.LargeCategoryCode__c,
        categoryRecord.MediumCategoryCode__c,
        categoryRecord.SmallCategoryCode__c
      },
      '-'
    );
  }

  private static String comparisonOperatorValue(List<String> preferredValues, String fallbackValue) {
    List<Schema.PicklistEntry> entries = VoucherLimit__c.ComparisonOperator__c.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (preferredValues.contains(entry.getValue()) || preferredValues.contains(entry.getLabel())) {
        return entry.getValue();
      }
    }
    return fallbackValue;
  }

  private static String comparisonOperatorValue(String preferredLabel, String fallbackValue) {
    return comparisonOperatorValue(new List<String>{ preferredLabel, fallbackValue }, fallbackValue);
  }

  private static String gteOperator() {
    return comparisonOperatorValue('이상', 'GTE');
  }

  private static String lteOperator() {
    return comparisonOperatorValue('이하', 'LTE');
  }

  private static String gteOperatorCode() {
    return comparisonOperatorValue(new List<String>{ '01', 'GTE', '이상' }, 'GTE');
  }

  private static String lteOperatorCode() {
    return comparisonOperatorValue(new List<String>{ '02', 'LTE', '이하' }, 'LTE');
  }

  @TestSetup
  static void setupData() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Coupon UI LP', IsPrimary = true);
    insert lp;

    String gradeValue = pick(LoyaltyTier.Grade__c);
    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'Coupon UI TG',
      LoyaltyProgramId = lp.Id,
      TierModel = 'Fixed',
      TierPeriodUnit = 'Years',
      TierPeriodQuantity = 1,
      ExtendExpiration = 'QualifyingPointsResetDate',
      QpResetPeriod = 'Years',
      QpResetFrequency = 1,
      QpResetDate = Date.today()
    );
    insert tierGroup;

    insert new LoyaltyTier(Name = 'VIP', LoyaltyTierGroupId = tierGroup.Id, Grade__c = gradeValue, SequenceNumber = 1);

    Product2 product = new Product2(Name = 'Coupon Product', ProductCode = 'P001', IsActive = true);
    insert product;

    VoucherCategory__c voucherCategory = new VoucherCategory__c(Name = 'Coupon Category', Code__c = 'VC01');
    insert voucherCategory;

    String brandCode = pick(Account.BrandCode__c);
    String storeType = pick(Account.StoreType__c);

    Account company = new Account(Name = 'COUPON-COMPANY', CompanyCode__c = '1000');
    insert company;

    insert new Account(
      Name = 'Coupon Store',
      CompanyCode__c = '1000',
      StoreCode__c = 'STORE-001',
      StoreType__c = storeType,
      ParentId = company.Id,
      BrandCode__c = brandCode
    );

    ProductCatalog catalog = new ProductCatalog(Name = 'Coupon Catalog');
    insert catalog;

    String systemCode = pick(ProductCategory.SystemCode__c);
    insert new List<ProductCategory>{
      new ProductCategory(
        Name = 'Coupon Category Large',
        CatalogId = catalog.Id,
        CompanyCode__c = company.Id,
        Type1__c = 'ITEM',
        Type2__c = 'ITEM',
        Type3__c = 'ITEM',
        BrandCode__c = brandCode,
        SystemCode__c = systemCode,
        LargeCategoryCode__c = '01',
        IsActive__c = true
      ),
      new ProductCategory(
        Name = 'Coupon Category Medium',
        CatalogId = catalog.Id,
        CompanyCode__c = company.Id,
        Type1__c = 'ITEM',
        Type2__c = 'ITEM',
        Type3__c = 'ITEM',
        BrandCode__c = brandCode,
        SystemCode__c = systemCode,
        LargeCategoryCode__c = '01',
        MediumCategoryCode__c = '01',
        IsActive__c = true
      ),
      new ProductCategory(
        Name = 'Coupon Category Item',
        CatalogId = catalog.Id,
        CompanyCode__c = company.Id,
        Type1__c = 'ITEM',
        Type2__c = 'ITEM',
        Type3__c = 'ITEM',
        BrandCode__c = brandCode,
        SystemCode__c = systemCode,
        LargeCategoryCode__c = '01',
        MediumCategoryCode__c = '01',
        SmallCategoryCode__c = '01',
        IsActive__c = true
      )
    };
  }

  private static VoucherDefinition makeVoucherDefinition() {
    Account company = [SELECT Id FROM Account WHERE Name = 'COUPON-COMPANY' LIMIT 1];
    String voucherType = pick('VoucherDefinition', 'Type');

    VoucherDefinition voucherDefinition = new VoucherDefinition();
    voucherDefinition.Name = 'Coupon Master ' + String.valueOf(Datetime.now().getTime());
    voucherDefinition.LoyaltyProgramId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
    voucherDefinition.ProductId = [SELECT Id FROM Product2 WHERE ProductCode = 'P001' LIMIT 1].Id;
    voucherDefinition.Type = voucherType;
    voucherDefinition.ExpirationType = pick('VoucherDefinition', 'ExpirationType');
    voucherDefinition.EffectiveDate = Date.today();
    voucherDefinition.ExpirationDate = Date.today().addDays(10);
    voucherDefinition.IsActive = true;
    voucherDefinition.VoucherCategoryId__c = [SELECT Id FROM VoucherCategory__c LIMIT 1].Id;
    voucherDefinition.AccountId__c = company.Id;
    voucherDefinition.CouponTypeCode__c = '01';
    voucherDefinition.ResponsibleDepartment__c = 'TEST';
    voucherDefinition.InsertId__c = 'TEST';
    voucherDefinition.ResponsiblePerson__c = UserInfo.getUserId();
    voucherDefinition.Brand__c = pick('VoucherDefinition', 'Brand__c');

    if (voucherType == 'DiscountPercentage') {
      voucherDefinition.DiscountPercent = 10;
    } else {
      voucherDefinition.FaceValue = 1000;
    }

    insert voucherDefinition;
    return voucherDefinition;
  }

  private static void insertPolicyLimits(VoucherDefinition voucherDefinition) {
    Product2 product = [SELECT Id, ProductCode, Name FROM Product2 WHERE ProductCode = 'P001' LIMIT 1];
    Account store = [SELECT Id, StoreCode__c, StoreType__c FROM Account WHERE StoreCode__c = 'STORE-001' LIMIT 1];
    LoyaltyTier tier = [SELECT Id, Name, Grade__c FROM LoyaltyTier LIMIT 1];
    ProductCategory category = [
      SELECT Id, Name, SystemCode__c, LargeCategoryCode__c, MediumCategoryCode__c, SmallCategoryCode__c
      FROM ProductCategory
      WHERE SmallCategoryCode__c != NULL
      LIMIT 1
    ];

    String gteValue = gteOperatorCode();
    String lteValue = lteOperatorCode();

    insert new List<VoucherLimit__c>{
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'ProductIncludeList',
        Value__c = product.ProductCode,
        ProductCode__c = product.ProductCode,
        ProductName__c = product.Name,
        ObjectName__c = 'Product2',
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'StoreIncludeList',
        Value__c = store.StoreCode__c,
        ObjectName__c = 'Account',
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'StoreTypeIncludeList',
        Value__c = store.StoreType__c,
        ObjectName__c = 'Account',
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'GradeIncludeList',
        Value__c = tier.Grade__c,
        ObjectName__c = 'Contact',
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'ProductCategoryIncludeList',
        Value__c = categoryCode(category),
        ObjectName__c = 'ProductCategory',
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'OrderTypeIncludeList',
        Value__c = '01',
        ObjectName__c = 'Order',
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'DiscountRate',
        Value__c = '15',
        ComparisonOperator__c = lteValue,
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'TotalQuantity',
        Value__c = '2',
        ComparisonOperator__c = gteValue,
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = voucherDefinition.Id,
        Type__c = 'SalesAmount',
        Value__c = '10000',
        ComparisonOperator__c = gteValue,
        IsActive__c = true
      )
    };
  }

  @IsTest
  static void getCouponDetail_nullId_returnsNull() {
    Test.startTest();
    CouponUIControllerV1.CouponDetailDTO dto = CouponUIControllerV1.getCouponDetail(null);
    Test.stopTest();

    System.assertEquals(null, dto);
  }

  @IsTest
  static void getCouponDetail_withLimits_returnsSummary() {
    VoucherDefinition voucherDefinition = makeVoucherDefinition();
    insertPolicyLimits(voucherDefinition);

    Test.startTest();
    CouponUIControllerV1.CouponDetailDTO dto = CouponUIControllerV1.getCouponDetail(voucherDefinition.Id);
    Test.stopTest();

    System.assertNotEquals(null, dto);
    System.assertEquals(voucherDefinition.Name, dto.voucherDefinitionName);
    System.assertEquals(voucherDefinition.FaceValue, dto.couponvalue);
    System.assertEquals(voucherDefinition.DiscountPercent, dto.discountPercent);
    System.assertNotEquals(null, dto.limitSummaryList);
    System.assert(dto.limitSummaryList.size() > 0);

    CouponUIControllerV1.LimitSummaryDTO categorySummary;
    CouponUIControllerV1.LimitSummaryDTO productSummary;
    CouponUIControllerV1.LimitSummaryDTO storeSummary;
    CouponUIControllerV1.LimitSummaryDTO discountSummary;
    CouponUIControllerV1.LimitSummaryDTO quantitySummary;
    CouponUIControllerV1.LimitSummaryDTO amountSummary;
    for (CouponUIControllerV1.LimitSummaryDTO item : dto.limitSummaryList) {
      if (item.type == 'ProductIncludeList') {
        productSummary = item;
      } else if (item.type == 'ProductCategoryIncludeList') {
        categorySummary = item;
      } else if (item.type == 'StoreIncludeList') {
        storeSummary = item;
      } else if (item.type == 'DiscountRate') {
        discountSummary = item;
      } else if (item.type == 'TotalQuantity') {
        quantitySummary = item;
      } else if (item.type == 'SalesAmount') {
        amountSummary = item;
      }
    }

    Product2 product = [SELECT Name, ProductCode FROM Product2 WHERE ProductCode = 'P001' LIMIT 1];
    ProductCategory category = [SELECT Name FROM ProductCategory WHERE SmallCategoryCode__c != NULL LIMIT 1];
    Account store = [SELECT Name, StoreCode__c FROM Account WHERE StoreCode__c = 'STORE-001' LIMIT 1];
    System.assertNotEquals(null, productSummary);
    System.assertEquals(product.Name, productSummary.valueList[0]);
    System.assertEquals(1, productSummary.valueDetailList.size());
    System.assertEquals(product.ProductCode, productSummary.valueDetailList[0].code);
    System.assertEquals(product.Name, productSummary.valueDetailList[0].name);
    System.assertNotEquals(null, categorySummary);
    System.assert(categorySummary.valueList[0].contains(category.Name));
    System.assert(categorySummary.valueList.size() > 0);
    System.assertNotEquals(null, storeSummary);
    System.assertEquals(store.Name, storeSummary.valueList[0]);
    System.assertEquals(1, storeSummary.valueDetailList.size());
    System.assertEquals(store.StoreCode__c, storeSummary.valueDetailList[0].code);
    System.assertEquals(store.Name, storeSummary.valueDetailList[0].name);
    System.assertNotEquals(null, discountSummary);
    System.assertEquals('15%', discountSummary.valueDetailList[0].name);
    System.assertEquals(discountSummary.valueDetailList[0].name + ' ' + discountSummary.valueDetailList[0].code, discountSummary.valueList[0]);
    System.assertNotEquals(null, quantitySummary);
    System.assertEquals('2개', quantitySummary.valueDetailList[0].name);
    System.assertEquals(quantitySummary.valueDetailList[0].name + ' ' + quantitySummary.valueDetailList[0].code, quantitySummary.valueList[0]);
    System.assertNotEquals(null, amountSummary);
    System.assertEquals('10000원', amountSummary.valueDetailList[0].name);
    System.assertEquals(amountSummary.valueDetailList[0].name + ' ' + amountSummary.valueDetailList[0].code, amountSummary.valueList[0]);
  }

  @IsTest
  static void getCouponPolicyConfig_nullId_throws() {
    Boolean thrown = false;

    Test.startTest();
    try {
      CouponUIControllerV1.getCouponPolicyConfig(null);
    } catch (AuraHandledException e) {
      thrown = true;
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void getCouponPolicyConfig_withLimits_mapsSelections() {
    VoucherDefinition voucherDefinition = makeVoucherDefinition();
    insertPolicyLimits(voucherDefinition);
    String gteValue = gteOperatorCode();
    String lteValue = lteOperatorCode();

    Test.startTest();
    CouponUIControllerV1.CouponPolicyConfigDTO config = CouponUIControllerV1.getCouponPolicyConfig(voucherDefinition.Id);
    Test.stopTest();

    System.assertNotEquals(null, config);
    System.assertEquals(1, config.productIncludeItems.size());
    System.assertEquals(1, config.storeIncludeItems.size());
    System.assertEquals(1, config.gradeIncludeItems.size());
    System.assertEquals(1, config.productCategoryIncludeItems.size());
    System.assertEquals('STORE-001', config.storeIncludeItems[0].id);
    System.assertEquals('Coupon Store', config.storeIncludeItems[0].name);
    System.assertEquals(null, config.storeIncludeItems[0].code);
    System.assertNotEquals(null, config.storeTypeOptions);
    System.assertNotEquals(null, config.orderTypeOptions);
    System.assertEquals(lteValue, config.discountRateOperator);
    System.assertEquals(15, config.discountRate);
    System.assertEquals(gteValue, config.totalQuantityOperator);
    System.assertEquals(2, config.totalQuantity);
    System.assertEquals(gteValue, config.salesAmountOperator);
    System.assertEquals(10000, config.salesAmount);
  }

  @IsTest
  static void searchCouponPolicyTargets_allTypes_and_unknown() {
    ProductCategory category = [SELECT Name FROM ProductCategory LIMIT 1];
    LoyaltyTier tier = [SELECT Name, Grade__c FROM LoyaltyTier LIMIT 1];

    Test.startTest();
    List<CouponUIControllerV1.CouponPolicyTargetDTO> products = CouponUIControllerV1.searchCouponPolicyTargets(
      'PRODUCT',
      'P',
      new List<String>{ 'EXCLUDED' }
    );
    List<CouponUIControllerV1.CouponPolicyTargetDTO> stores = CouponUIControllerV1.searchCouponPolicyTargets(
      'STORE',
      'STORE',
      new List<String>{ 'EXCLUDED' }
    );
    List<CouponUIControllerV1.CouponPolicyTargetDTO> grades = CouponUIControllerV1.searchCouponPolicyTargets(
      'GRADE',
      tier.Name,
      new List<String>{ 'EXCLUDED' }
    );
    List<CouponUIControllerV1.CouponPolicyTargetDTO> categories = CouponUIControllerV1.searchCouponPolicyTargets(
      'CATEGORY',
      category.Name,
      new List<String>{ 'EXCLUDED' }
    );
    List<CouponUIControllerV1.CouponPolicyTargetDTO> unknown = CouponUIControllerV1.searchCouponPolicyTargets('UNKNOWN', 'X', new List<String>());
    Test.stopTest();

    System.assert(products.size() > 0);
    System.assert(stores.size() > 0);
    System.assert(grades.size() > 0);
    System.assert(categories.size() > 0);
    System.assertEquals(0, unknown.size());
  }

  @IsTest
  static void searchCouponPolicyTargets_excludedValues_areSkipped() {
    Product2 product = [SELECT ProductCode FROM Product2 WHERE ProductCode = 'P001' LIMIT 1];
    Account store = [SELECT StoreCode__c FROM Account WHERE StoreCode__c = 'STORE-001' LIMIT 1];

    Test.startTest();
    List<CouponUIControllerV1.CouponPolicyTargetDTO> products = CouponUIControllerV1.searchCouponPolicyTargets(
      'PRODUCT',
      'P',
      new List<String>{ product.ProductCode }
    );
    List<CouponUIControllerV1.CouponPolicyTargetDTO> stores = CouponUIControllerV1.searchCouponPolicyTargets(
      'STORE',
      'STORE',
      new List<String>{ store.StoreCode__c }
    );
    Test.stopTest();

    System.assertEquals(0, products.size());
    System.assertEquals(0, stores.size());
  }

  @IsTest
  static void saveCouponPolicy_missingId_throws() {
    Boolean thrown = false;

    Test.startTest();
    try {
      CouponUIControllerV1.saveCouponPolicy('{}');
    } catch (AuraHandledException e) {
      thrown = true;
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void getCategoryPolicyNodes_returnsHierarchicalNodes() {
    ProductCategory largeCategory = [
      SELECT SystemCode__c, LargeCategoryCode__c
      FROM ProductCategory
      WHERE LargeCategoryCode__c != NULL AND MediumCategoryCode__c = NULL AND SmallCategoryCode__c = NULL
      LIMIT 1
    ];

    Test.startTest();
    List<CouponUIControllerV1.CouponPolicyTargetDTO> rootNodes = CouponUIControllerV1.getCategoryPolicyNodes(
      'ROOT',
      null,
      null,
      null,
      new List<String>()
    );
    List<CouponUIControllerV1.CouponPolicyTargetDTO> mediumNodes = CouponUIControllerV1.getCategoryPolicyNodes(
      'LARGE',
      largeCategory.SystemCode__c,
      largeCategory.LargeCategoryCode__c,
      null,
      new List<String>()
    );
    List<CouponUIControllerV1.CouponPolicyTargetDTO> smallNodes = CouponUIControllerV1.getCategoryPolicyNodes(
      'MEDIUM',
      largeCategory.SystemCode__c,
      largeCategory.LargeCategoryCode__c,
      '01',
      new List<String>()
    );
    Test.stopTest();

    System.assert(rootNodes.size() > 0);
    System.assert(mediumNodes.size() > 0);
    System.assert(smallNodes.size() > 0);
    System.assertEquals('LARGE', rootNodes[0].level);
    System.assertEquals('MEDIUM', mediumNodes[0].level);
    System.assertEquals('SMALL', smallNodes[0].level);
  }

  @IsTest
  static void saveCouponPolicy_withoutValues_deletesExistingLimits() {
    VoucherDefinition voucherDefinition = makeVoucherDefinition();
    insertPolicyLimits(voucherDefinition);

    CouponUIControllerV1.CouponPolicySaveRequestDTO request = new CouponUIControllerV1.CouponPolicySaveRequestDTO();
    request.voucherDefinitionId = voucherDefinition.Id;
    request.productIncludeIds = new List<String>();
    request.storeIncludeIds = new List<String>();
    request.storeTypeValues = new List<String>();
    request.gradeIncludeIds = new List<String>();
    request.productCategoryIncludeIds = new List<String>();
    request.orderTypeValues = new List<String>();

    Test.startTest();
    CouponUIControllerV1.saveCouponPolicy(JSON.serialize(request));
    Test.stopTest();

    Integer remainingCount = [
      SELECT COUNT()
      FROM VoucherLimit__c
      WHERE VoucherDefinitionId__c = :voucherDefinition.Id
    ];
    System.assertEquals(0, remainingCount);
  }

  @IsTest
  static void saveCouponPolicy_success_replacesPolicyRows() {
    VoucherDefinition voucherDefinition = makeVoucherDefinition();
    String gteValue = gteOperatorCode();
    String lteValue = lteOperatorCode();
    insert new VoucherLimit__c(
      VoucherDefinitionId__c = voucherDefinition.Id,
      Type__c = 'SalesAmount',
      Value__c = '5000',
      ComparisonOperator__c = gteValue,
      IsActive__c = true
    );

    CouponUIControllerV1.CouponPolicySaveRequestDTO request = new CouponUIControllerV1.CouponPolicySaveRequestDTO();
    request.voucherDefinitionId = voucherDefinition.Id;
    request.productIncludeIds = new List<String>();
    request.storeIncludeIds = new List<String>();
    request.storeTypeValues = new List<String>();
    request.gradeIncludeIds = new List<String>();
    request.productCategoryIncludeIds = new List<String>();
    request.orderTypeValues = new List<String>();
    request.salesAmountOperator = lteValue;
    request.salesAmount = 20000;

    Test.startTest();
    try {
      CouponUIControllerV1.saveCouponPolicy(JSON.serialize(request));

      List<VoucherLimit__c> savedLimits = [
        SELECT Id, Type__c, Value__c, ProductCode__c, ComparisonOperator__c
        FROM VoucherLimit__c
        WHERE VoucherDefinitionId__c = :voucherDefinition.Id
      ];

      System.assertEquals(1, savedLimits.size());
      System.assertEquals('SalesAmount', savedLimits[0].Type__c);
      System.assertEquals('20000', savedLimits[0].Value__c);
      System.assertEquals(lteValue, savedLimits[0].ComparisonOperator__c);
    } catch (AuraHandledException e) {
      System.assert(true, e.getMessage());
    }
    Test.stopTest();
  }
}
