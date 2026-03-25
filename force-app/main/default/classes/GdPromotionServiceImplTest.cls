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
    Promotion p = new Promotion(
      Name = name,
      PromotionCode = 'PCODE-' + String.valueOf(Datetime.now().getTime()),
      StartDate = Date.today(),
      EndDate = Date.today().addDays(7),
      IsAllStore__c = isAllStore,
      IsAllItem__c = false,
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
        StartDate,
        EndDate,
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
    System.assertEquals(0, detail.STORES.size());
    System.assertEquals(0, detail.ITEMS.size());
    System.assertEquals(0, detail.COUPONS.size());
    System.assertEquals(0, detail.POINTS.size());
  }

  @IsTest
  static void getPromotionDetail_withStoreAndPoint_success() {
    Promotion p = insertPromotionRecord('DETAIL-EXTRA-PROMO', false);
    Account acc = insertStoreAccount('Detail Store', 'STORE-DETAIL-01');
    insert new PromotionAccount__c(PromotionId__c = p.Id, AccountId__c = acc.Id, IsActive__c = true);
    LoyaltyPgmCurrencySubtype subtype = insertCurrencySubtype();
    String pointLimitType = PromotionPointLimit__c.Type__c.getDescribe().getPicklistValues().isEmpty()
      ? null
      : PromotionPointLimit__c.Type__c.getDescribe().getPicklistValues()[0].getValue();

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