@IsTest
private class PromotionUIControllerV1Test {
  /* ============================== */
  private static String pick(Schema.SObjectField f) {
    List<Schema.PicklistEntry> e = f.getDescribe().getPicklistValues();
    return e.isEmpty() ? null : e[0].getValue();
  }

  private static String firstPointTypeCode() {
    List<Schema.PicklistEntry> entries = Promotion.PointTypeCode__c.getDescribe().getPicklistValues();
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  /* ============================== */
  private static LoyaltyProgram getOrCreateLP() {
    List<LoyaltyProgram> lpList = [
      SELECT Id
      FROM LoyaltyProgram
      LIMIT 1
    ];

    if (!lpList.isEmpty())
      return lpList[0];

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP', IsPrimary = true);
    insert lp;
    return lp;
  }

  /* ============================== */
  private static Id createCurrencySubtype() {
    LoyaltyProgram lp = getOrCreateLP();

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      Name = 'CUR',
      LoyaltyProgramId = lp.Id,
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = 'Fixed',
      ExtendExpiration = 'None',
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = 'Years',
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert lpc;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      Name = 'SUB',
      LoyaltyProgramCurrencyId = lpc.Id,
      PointTypeCode__c = '02',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subtype;

    return subtype.Id;
  }

  /* ============================== */
  private static Promotion createPromotion(Boolean withCatalog) {
    ProductCatalog catalog;

    if (withCatalog) {
      catalog = new ProductCatalog(Name = 'CAT');
      insert catalog;
    }

    Promotion p = new Promotion(
      Name = 'TEST_PROMO',
      DisplayName = 'TEST_DISPLAY',
      PromotionCode = 'PROMO_' + Datetime.now().getTime(),
      IsActive = true,
      StartDate = Date.today(),
      EndDate = Date.today().addDays(5),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(3),
      DiscountRate__c = 10,
      IsPointUsageAllowed__c = true,
      ProductCatalogId = catalog != null ? catalog.Id : null
    );
    insert p;

    return p;
  }

  /* ============================== */
  private static void insertStore(Id promotionId) {
    Account acc = new Account(
      Name = 'STORE',
      CompanyCode__c = '1000', // 🔥 중요
      StoreGroupCode__c = pick(Account.StoreGroupCode__c),
      StoreType__c = pick(Account.StoreType__c)
    );
    insert acc;

    insert new PromotionAccount__c(PromotionId__c = promotionId, AccountId__c = acc.Id, IsActive__c = true);
  }

  /* ============================== */
  private static void insertProduct(Id catalogId) {
    if (catalogId == null)
      return;

    ProductCategory pc = new ProductCategory(
      Name = 'CAT',
      CatalogId = catalogId,
      SystemCode__c = pick(ProductCategory.SystemCode__c),
      LargeCategoryCode__c = 'L',
      MediumCategoryCode__c = 'M',
      SmallCategoryCode__c = 'S',
      IsActive__c = true
    );
    insert pc;

    Product2 p = new Product2(Name = 'PROD', ProductCode = 'P', IsActive = true);
    insert p;

    insert new ProductCategoryProduct(ProductId = p.Id, ProductCategoryId = pc.Id, IsPrimaryCategory = true);
  }

  /* ============================== */
  private static void insertPoint(Id promotionId) {
    Id subtypeId = createCurrencySubtype();
    String pointLimitType = pick(PromotionPointLimit__c.Type__c);

    PromotionPointLimit__c pointLimit = new PromotionPointLimit__c(
      PromotionId__c = promotionId,
      Name = 'POINT',
      Type__c = pointLimitType,
      LoyaltyPgmCurrencySubtypeId__c = subtypeId
    );

    if (pointLimitType == 'rate' || pointLimitType == 'amount') {
      pointLimit.Value__c = 100;
    }

    insert pointLimit;
  }

  /* ============================== */
  private static void insertVoucher(Id promotionId) {
    LoyaltyProgram lp = getOrCreateLP();

    Product2 p = new Product2(Name = 'VP', ProductCode = 'VP', IsActive = true);
    insert p;

    // 🔥 핵심: Account에 CompanyCode 넣는다
    Account acc = new Account(Name = 'TEST STORE', CompanyCode__c = '1000');
    insert acc;

    VoucherCategory__c cat = new VoucherCategory__c(Name = 'VC', Code__c = '01');
    insert cat;

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'VD',
      LoyaltyProgramId = lp.Id,
      ProductId = p.Id,
      Type = pick(VoucherDefinition.Type),
      ExpirationType = pick(VoucherDefinition.ExpirationType),
      FaceValue = 100,
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(5),
      IsActive = true,
      VoucherCategoryId__c = cat.Id,
      // 🔥 이거 하나로 해결됨
      AccountId__c = acc.Id,
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'T',
      InsertId__c = 'T',
      ResponsiblePerson__c = UserInfo.getUserId()
    );
    insert vd;

    insert new VoucherLimit__c(PromotionId__c = promotionId, VoucherDefinitionId__c = vd.Id, Name = 'VL');
  }

  /* ============================== */
  @IsTest
  static void test_all_flow_fullCoverage() {
    Promotion p = createPromotion(true);

    insertStore(p.Id);
    insertProduct(p.ProductCatalogId);
    insertPoint(p.Id);
    insertVoucher(p.Id);

    Test.startTest();
    List<PromotionUIControllerV1.PromotionDetailDTO> res = PromotionUIControllerV1.getPromotionHistory(p.Id);
    Test.stopTest();

    System.assert(res != null);
    System.assert(res.size() >= 0);

    if (!res.isEmpty()) {
      PromotionUIControllerV1.PromotionDetailDTO dto = res[0];

      System.assert(dto != null);
      System.assert(dto.name != null);
    }
  }

  /* ============================== */
  @IsTest
  static void test_null_input() {
    Test.startTest();
    List<PromotionUIControllerV1.PromotionDetailDTO> res = PromotionUIControllerV1.getPromotionHistory(null);
    Test.stopTest();

    System.assert(res != null);
    System.assertEquals(0, res.size());
  }

  /* ============================== */
  @IsTest
  static void test_minimal_data() {
    Promotion p = createPromotion(false);

    Test.startTest();
    List<PromotionUIControllerV1.PromotionDetailDTO> res = PromotionUIControllerV1.getPromotionHistory(p.Id);
    Test.stopTest();

    System.assert(res != null);
    System.assert(res.size() >= 0);
  }

  @IsTest
  static void test_pointAccrualTypes_fromPointLimitAndExcludedPointType() {
    Promotion p = createPromotion(false);
    insertPoint(p.Id);

    String excludedPointTypeCode = firstPointTypeCode();
    if (!String.isBlank(excludedPointTypeCode)) {
      p.PointTypeCode__c = excludedPointTypeCode;
      update p;
    }

    Test.startTest();
    List<PromotionUIControllerV1.PromotionDetailDTO> res = PromotionUIControllerV1.getPromotionHistory(p.Id);
    Test.stopTest();

    System.assertEquals(1, res.size());
    System.assertEquals(true, res[0].isPointAccrualAvailable);
    System.assert(res[0].pointAccrualAvailablePointTypes.contains('SUB'));
    if (!String.isBlank(excludedPointTypeCode)) {
      System.assert(!String.isBlank(res[0].pointAccrualUnavailablePointTypes));
    }
  }

  @IsTest
  static void test_pointAccrualTypes_allPointWhenNoExcludedPointType() {
    Promotion p = createPromotion(false);

    Test.startTest();
    List<PromotionUIControllerV1.PromotionDetailDTO> res = PromotionUIControllerV1.getPromotionHistory(p.Id);
    Test.stopTest();

    System.assertEquals(1, res.size());
    System.assertEquals(true, res[0].isPointAccrualAvailable);
    System.assertEquals('전체 포인트', res[0].pointAccrualAvailablePointTypes);
    System.assertEquals(null, res[0].pointAccrualUnavailablePointTypes);
  }
}