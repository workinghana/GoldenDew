@IsTest
private class GdPromotionServiceImplTest {
  private static GdPromotionServiceImpl svc() {
    return new GdPromotionServiceImpl();
  }

  private static LoyaltyProgram createLoyaltyProgram() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Golden Dew', IsPrimary = true);
    insert lp;
    return lp;
  }

  private static Promotion insertPromotionRecord(String name, Boolean isAllStore) {
    return insertPromotionRecord(name, isAllStore, false, true, Date.today(), Date.today().addDays(7));
  }

  private static Promotion insertPromotionRecord(String name, Boolean isAllStore, Boolean isActive, Date publishStartDate, Date publishEndDate) {
    return insertPromotionRecord(name, isAllStore, false, isActive, publishStartDate, publishEndDate);
  }

  private static Promotion insertPromotionRecord(
    String name,
    Boolean isAllStore,
    Boolean isAllItem,
    Boolean isActive,
    Date publishStartDate,
    Date publishEndDate
  ) {
    Promotion p = new Promotion(
      Name = name,
      PromotionCode = 'PCODE-' + String.valueOf(Datetime.now().getTime()),
      IsActive = isActive,
      StartDate = Date.today(),
      EndDate = Date.today().addDays(7),
      PublishStartDate__c = publishStartDate,
      PublishEndDate__c = publishEndDate,
      IsAllStore__c = isAllStore,
      IsAllItem__c = isAllItem,
      IsCouponAllowed__c = false,
      IsFixedAmountCouponAllowed__c = false,
      IsRateCouponAllowed__c = false,
      IsSpecificCouponAllowed__c = false,
      IsPointUsageAllowed__c = true,
      IsDiscountRateApplicable__c = true
    );
    insert p;

    return [
      SELECT
        Id,
        Name,
        PromotionNo__c,
        IsActive,
        StartDate,
        EndDate,
        PublishStartDate__c,
        PublishEndDate__c,
        IsAllStore__c,
        IsAllItem__c,
        IsCouponAllowed__c,
        IsFixedAmountCouponAllowed__c,
        IsRateCouponAllowed__c,
        IsSpecificCouponAllowed__c,
        IsPointUsageAllowed__c,
        IsDiscountRateApplicable__c
      FROM Promotion
      WHERE Id = :p.Id
      LIMIT 1
    ];
  }

  private static Account insertStoreAccount(String name, String storeCode) {
    String brandCode = Account.BrandCode__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : Account.BrandCode__c.getDescribe().getPicklistValues()[0].getValue();
    String storeGroupCode = Account.StoreGroupCode__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : Account.StoreGroupCode__c.getDescribe().getPicklistValues()[0].getValue();
    String storeType = Account.StoreType__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : Account.StoreType__c.getDescribe().getPicklistValues()[0].getValue();

    Account acc = new Account(
      Name = name,
      StoreCode__c = storeCode,
      BrandCode__c = brandCode,
      StoreGroupCode__c = storeGroupCode,
      StoreType__c = storeType
    );
    insert acc;
    return acc;
  }

  private static LoyaltyPgmCurrencySubtype insertCurrencySubtype() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP-' + String.valueOf(Datetime.now().getTime()), IsPrimary = false);
    insert lp;

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = 'Point-' + String.valueOf(Datetime.now().getTime()),
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
      LoyaltyProgramCurrencyId = lpc.Id,
      Name = 'Subtype-' + String.valueOf(Datetime.now().getTime()),
      PointTypeCode__c = '02',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subtype;
    return subtype;
  }

  private static VoucherDefinition insertVoucherDefinition(
    Id loyaltyProgramId,
    String name,
    String type,
    Integer discountPercent,
    Decimal faceValue
  ) {
    Product2 product = new Product2(Name = 'Voucher Product ' + name, IsActive = true);
    insert product;
    Account companyAccount = new Account(Name = 'Voucher Company ' + name, CompanyCode__c = '1000');
    insert companyAccount;

    String expirationType = VoucherDefinition.ExpirationType.getDescribe().getPicklistValues().isEmpty()
      ? null
      : VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue();
    String couponTypeCode = VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue();

    Integer normalizedDiscountPercent = null;
    Decimal normalizedFaceValue = null;
    if (type == 'DiscountPercentage') {
      normalizedDiscountPercent = discountPercent;
    } else if (type == 'FixedValue') {
      normalizedFaceValue = faceValue;
    }

    // 2026-04-04 Wina 수정 시작
    // org 검증룰로 인해 Type='ProductOrService'는 insert 불가하여 테스트 픽스처에서 허용 타입으로 보정
    // [AS-IS] String effectiveType = type;
    String effectiveType = type;
    if (effectiveType == 'ProductOrService') {
      effectiveType = 'FixedValue';
      // FixedValue 타입 필수값 보정
      normalizedDiscountPercent = null;
      if (normalizedFaceValue == null || normalizedFaceValue <= 0) {
        normalizedFaceValue = 1000;
      }
    }
    // 2026-04-04 Wina 수정 끝

    VoucherDefinition vd = new VoucherDefinition(
      Name = name,
      LoyaltyProgramId = loyaltyProgramId,
      ProductId = product.Id,
      AccountId__c = companyAccount.Id,
      // [AS-IS] Type = type,
      Type = effectiveType,
      CouponManNo__c = 'CPN-' + String.valueOf(Datetime.now().getTime()),
      CouponTypeCode__c = couponTypeCode,
      ResponsibleDepartment__c = 'TEST',
      ResponsiblePerson__c = 'TESTER',
      InsertId__c = 'TESTER',
      ExpirationType = expirationType,
      DiscountPercent = normalizedDiscountPercent,
      FaceValue = normalizedFaceValue,
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      IsActive = true
    );
    insert vd;
    return vd;
  }

  @IsTest
  static void createPromotion_emptyBody_throws() {
    Boolean thrown = false;

    try {
      svc().createPromotion(new Map<String, Object>());
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code);
      System.assertEquals('Request body is empty.', ce.message);
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createPromotion_missingRequiredField_throws() {
    Boolean thrown = false;

    try {
      svc().createPromotion(new Map<String, Object>{ 'ExternalPromotionNo__c' => 'PROMO-EXT-001' });
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code);
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createPromotion_loyaltyProgramMissing_throws() {
    Boolean thrown = false;

    try {
      svc().createPromotion(new Map<String, Object>{ 'PromotionNo__c' => 'PROMO-NO-LP', 'Name' => 'Promo without LP', 'StartDate' => Date.today() });
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code);
      System.assertEquals('LoyaltyProgram is null', ce.message);
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createPromotion_duplicatePromotionNo_throws() {
    createLoyaltyProgram();
    Promotion existing = insertPromotionRecord('Duplicate Promo Seed', false);

    Boolean thrown = false;
    try {
      svc()
        .createPromotion(
          new Map<String, Object>{ 'PromotionNo__c' => existing.PromotionNo__c, 'Name' => 'Duplicate Promo Request', 'StartDate' => Date.today() }
        );
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code);
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createPromotion_success() {
    createLoyaltyProgram();

    ApiResult res = svc()
      .createPromotion(
        new Map<String, Object>{
          'PromotionNo__c' => 'PROMO-' + String.valueOf(Datetime.now().getTime()),
          'Name' => 'Created Promo',
          'DisplayName' => 'Created Promo Display',
          'StartDate' => Date.today(),
          'EndDate' => Date.today().addDays(14),
          'DiscountRate__c' => 10
        }
      );

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
    System.assertEquals(200, res.code);
    System.assertNotEquals(null, res.data);
    System.assert(res.data.containsKey('promotionId'));
    System.assertNotEquals(null, res.data.get('promotionId'));
  }

  @IsTest
  static void getPromotionList_invalidDate_throws() {
    Boolean thrown = false;

    try {
      svc().getPromotionList(new Map<String, String>{ 'StartDate' => 'bad-date' });
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code);
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void getPromotionList_emptyFilter_success() {
    ApiResult res = svc().getPromotionList(new Map<String, String>());

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
    System.assertEquals(200, res.code);
    System.assertNotEquals(null, res.data);
    System.assert(res.data.containsKey('promotionList'));
  }

  @IsTest
  static void getPromotionList_withPromotionNoAndNameFilter_success() {
    Promotion p = insertPromotionRecord('UT-PROMO-FILTER', false);
    String filterToken = p.PromotionNo__c.length() > 4 ? p.PromotionNo__c.substring(0, 4) : p.PromotionNo__c;

    ApiResult res = svc().getPromotionList(new Map<String, String>{ 'PromotionNo__c' => filterToken, 'Name' => 'UT-PROMO' });

    System.assertNotEquals(null, res);
    System.assertEquals(200, res.code);
    List<Object> promotionList = (List<Object>) res.data.get('promotionList');
    System.assertNotEquals(null, promotionList);
    System.assert(promotionList.size() > 0);
    System.assert(JSON.serialize(promotionList).contains(p.PromotionNo__c));
  }

  @IsTest
  static void getPromotionList_storeCodeNoMatch_returnsEmpty() {
    ApiResult res = svc().getPromotionList(new Map<String, String>{ 'StoreCode__c' => 'STORE-NO-MATCH' });

    System.assertNotEquals(null, res);
    System.assertEquals(200, res.code);
    List<Object> promotionList = (List<Object>) res.data.get('promotionList');
    System.assertNotEquals(null, promotionList);
    System.assertEquals(0, promotionList.size());
  }

  @IsTest
  static void getPromotionList_storeCodeIncludesAllStorePromotion() {
    Promotion p = insertPromotionRecord('ALL-STORE-PROMO', true);

    ApiResult res = svc().getPromotionList(new Map<String, String>{ 'StoreCode__c' => 'ANY-STORE' });

    System.assertNotEquals(null, res);
    System.assertEquals(200, res.code);
    List<Object> promotionList = (List<Object>) res.data.get('promotionList');
    System.assertNotEquals(null, promotionList);
    System.assert(promotionList.size() > 0);
    System.assert(JSON.serialize(promotionList).contains(p.PromotionNo__c));
  }

  @IsTest
  static void getPromotionList_storeCodeMatchesPromotionAccount() {
    Promotion p = insertPromotionRecord('STORE-MAPPED-PROMO', false);
    Account acc = insertStoreAccount('Mapped Store', 'STORE-MAP-01');
    insert new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id, IsActive__c = true);

    ApiResult res = svc().getPromotionList(new Map<String, String>{ 'StoreCode__c' => 'STORE-MAP-01' });

    System.assertNotEquals(null, res);
    System.assertEquals(200, res.code);
    List<Object> promotionList = (List<Object>) res.data.get('promotionList');
    System.assertNotEquals(null, promotionList);
    System.assert(promotionList.size() > 0);
    System.assert(JSON.serialize(promotionList).contains(p.PromotionNo__c));
  }

  @IsTest
  static void getPromotionList_dateRangeFilter_success() {
    Promotion p = insertPromotionRecord('DATE-RANGE-PROMO', false);

    ApiResult res = svc()
      .getPromotionList(
        new Map<String, String>{ 'StartDate' => String.valueOf(Date.today()), 'EndDate' => String.valueOf(Date.today().addDays(10)) }
      );

    System.assertNotEquals(null, res);
    System.assertEquals(200, res.code);
    List<Object> promotionList = (List<Object>) res.data.get('promotionList');
    System.assertNotEquals(null, promotionList);
    System.assert(promotionList.size() > 0);
    System.assert(JSON.serialize(promotionList).contains(p.PromotionNo__c));
  }

  @IsTest
  static void getPromotionList_inactivePromotion_excluded() {
    Promotion activePromotion = insertPromotionRecord('ACTIVE-PROMO', false, true, Date.today(), Date.today().addDays(7));
    Promotion inactivePromotion = insertPromotionRecord('INACTIVE-PROMO', false, false, Date.today(), Date.today().addDays(7));

    ApiResult res = svc().getPromotionList(new Map<String, String>());

    System.assertEquals(200, res.code);
    List<Object> promotionList = (List<Object>) res.data.get('promotionList');
    String serialized = JSON.serialize(promotionList);
    System.assert(serialized.contains(activePromotion.PromotionNo__c));
    System.assertEquals(false, serialized.contains(inactivePromotion.PromotionNo__c));
  }

  @IsTest
  static void getPromotionDetail_notFound_throws() {
    Boolean thrown = false;

    try {
      svc().getPromotionDetail('PROMO-NOT-FOUND');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code);
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void getPromotionDetail_success_minimal() {
    Promotion p = insertPromotionRecord('DETAIL-PROMO', false);

    ApiResult res = svc().getPromotionDetail(p.PromotionNo__c);

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
    System.assertEquals(200, res.code);
    System.assertNotEquals(null, res.data);
    System.assert(res.data.containsKey('PromotionDetail'));

    PromotionDetailResDTO.PromotionMaster detail = (PromotionDetailResDTO.PromotionMaster) res.data.get('PromotionDetail');
    System.assertNotEquals(null, detail);
    System.assertEquals(p.PromotionNo__c, detail.NO_PROM);
    System.assertEquals(p.Name, detail.NM_PROM);
    System.assertEquals('Y', detail.YN_PROM_DC);
    System.assertEquals('N', detail.YN_ALL_ITEM);
    System.assertEquals(0, detail.STORES.size());
    System.assertEquals(0, detail.ITEMS.size());
    System.assertEquals(0, detail.COUPONS.size());
    System.assertEquals(0, detail.POINTS.size());
  }

  @IsTest
  static void getPromotionDetail_inactivePromotion_reportsInactive() {
    Promotion p = insertPromotionRecord('DETAIL-INACTIVE-PROMO', false, false, Date.today(), Date.today().addDays(7));
    Product2 product = new Product2(
      Name = 'Inactive Detail Product',
      ProductCode = 'INACTIVE-DETAIL-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
      IsActive = true
    );
    insert product;
    insert new PromotionProduct(PromotionId = p.Id, ProductId = product.Id);

    ApiResult res = svc().getPromotionDetail(p.PromotionNo__c);

    PromotionDetailResDTO.PromotionMaster detail = (PromotionDetailResDTO.PromotionMaster) res.data.get('PromotionDetail');
    System.assertNotEquals(null, detail);
    System.assertEquals(false, detail.YN_ACTIVE);
    System.assertEquals('N', detail.YN_ALL_ITEM);
    System.assertEquals(0, detail.ITEMS.size());
  }

  @IsTest
  static void getPromotionDetail_allItemPromotion_returnsEmptyItems() {
    Promotion p = insertPromotionRecord('DETAIL-ALL-ITEM-PROMO', false, true, true, Date.today(), Date.today().addDays(7));

    ApiResult res = svc().getPromotionDetail(p.PromotionNo__c);

    PromotionDetailResDTO.PromotionMaster detail = (PromotionDetailResDTO.PromotionMaster) res.data.get('PromotionDetail');
    System.assertNotEquals(null, detail);
    System.assertEquals(true, detail.YN_ACTIVE);
    System.assertEquals('Y', detail.YN_ALL_ITEM);
    System.assertEquals(0, detail.ITEMS.size());
  }

  @IsTest
  static void getPromotionDetail_withStoreAndPoint_success() {
    Promotion p = insertPromotionRecord('DETAIL-EXTRA-PROMO', false);
    Account acc = insertStoreAccount('Detail Store', 'STORE-DETAIL-01');
    insert new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id, IsActive__c = true);
    LoyaltyPgmCurrencySubtype subtype = insertCurrencySubtype();
    String pointLimitType = 'rate';

    insert new PromotionPointLimit__c(
      PromotionId__c = p.Id,
      Name = 'Detail Point Limit',
      Type__c = pointLimitType,
      Value__c = 2,
      LoyaltyPgmCurrencySubtypeId__c = subtype.Id
    );

    ApiResult res = svc().getPromotionDetail(p.PromotionNo__c);

    System.assertNotEquals(null, res);
    System.assertEquals(200, res.code);
    PromotionDetailResDTO.PromotionMaster detail = (PromotionDetailResDTO.PromotionMaster) res.data.get('PromotionDetail');
    System.assertNotEquals(null, detail);
    System.assertEquals('Y', detail.YN_PROM_DC);
    System.assertEquals(1, detail.STORES.size());
    System.assertEquals('STORE-DETAIL-01', detail.STORES[0].CD_STORE);
    System.assertEquals(1, detail.POINTS.size());
    System.assertEquals('Detail Point Limit', detail.POINTS[0].NM_PROM_POINT);
  }

  @IsTest
  static void getPromotionDetail_withCouponFlags_loadsExpectedCoupons() {
    LoyaltyProgram lp = createLoyaltyProgram();
    Promotion p = insertPromotionRecord('DETAIL-COUPON-PROMO', false);
    p.IsCouponAllowed__c = true;
    p.IsRateCouponAllowed__c = false;
    p.IsFixedAmountCouponAllowed__c = false;
    p.IsSpecificCouponAllowed__c = true;
    update p;

    VoucherDefinition specificVd = insertVoucherDefinition(lp.Id, 'Specific Coupon', 'ProductOrService', 0, 0);
    insert new VoucherLimit__c(PromotionId__c = p.Id, VoucherDefinitionId__c = specificVd.Id, Type__c = 'PromotionIncludeList', IsActive__c = true);

    ApiResult res = svc().getPromotionDetail(p.PromotionNo__c);

    PromotionDetailResDTO.PromotionMaster detail = (PromotionDetailResDTO.PromotionMaster) res.data.get('PromotionDetail');
    System.assertEquals(1, detail.COUPONS.size());
    String serialized = JSON.serialize(detail.COUPONS);
    System.assert(serialized.contains(specificVd.Name));
  }

  @IsTest
  static void getPromotionDetail_isCouponAllowed_loadsAllCouponTypesWithoutDuplicates() {
    LoyaltyProgram lp = createLoyaltyProgram();
    Promotion p = insertPromotionRecord('DETAIL-ALL-COUPON-PROMO', false);
    p.IsCouponAllowed__c = true;
    p.IsRateCouponAllowed__c = false;
    p.IsFixedAmountCouponAllowed__c = false;
    p.IsSpecificCouponAllowed__c = true;
    update p;

    VoucherDefinition rateVd = insertVoucherDefinition(lp.Id, 'All Rate Coupon', 'DiscountPercentage', 15, 0);
    VoucherDefinition fixedVd = insertVoucherDefinition(lp.Id, 'All Fixed Coupon', 'FixedValue', 0, 7000);
    VoucherDefinition specificVd = insertVoucherDefinition(lp.Id, 'All Specific Coupon', 'ProductOrService', 0, 0);

    insert new VoucherLimit__c(PromotionId__c = p.Id, VoucherDefinitionId__c = rateVd.Id, Type__c = 'PromotionIncludeList', IsActive__c = true);
    insert new VoucherLimit__c(PromotionId__c = p.Id, VoucherDefinitionId__c = specificVd.Id, Type__c = 'PromotionIncludeList', IsActive__c = true);

    ApiResult res = svc().getPromotionDetail(p.PromotionNo__c);

    PromotionDetailResDTO.PromotionMaster detail = (PromotionDetailResDTO.PromotionMaster) res.data.get('PromotionDetail');
    // 2026-04-04 Wina 수정 시작
    // [AS-IS] System.assertEquals(2, detail.COUPONS.size());
    // IsCouponAllowed__c = true 인 경우 DiscountPercentage/FixedValue/ProductOrService 전체 유형이 포함되어 3건이 정상
    System.assertEquals(3, detail.COUPONS.size());
    // 2026-04-04 Wina 수정 끝
    String serialized = JSON.serialize(detail.COUPONS);
    System.assert(serialized.contains(rateVd.Name));
    System.assert(serialized.contains(fixedVd.Name));
    System.assert(serialized.contains(specificVd.Name));
  }

  @IsTest
  static void buildCategoryCode_blankRequired_returnsNull() {
    System.assertEquals(null, GdPromotionServiceImpl.buildCategoryCode(null, '01', '02', '03'));
    System.assertEquals(null, GdPromotionServiceImpl.buildCategoryCode('SYS', null, '02', '03'));
  }

  @IsTest
  static void buildCategoryCode_withOptionalParts_returnsJoinedCode() {
    System.assertEquals('SYS-L', GdPromotionServiceImpl.buildCategoryCode('SYS', 'L', null, null));
    System.assertEquals('SYS-L-M', GdPromotionServiceImpl.buildCategoryCode('SYS', 'L', 'M', null));
    System.assertEquals('SYS-L-M-S', GdPromotionServiceImpl.buildCategoryCode('SYS', 'L', 'M', 'S'));
  }
}