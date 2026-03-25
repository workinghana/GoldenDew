@IsTest
private class PromotionDetailResDTOTest {
  // =========================================================
  // 공통 helper: Promotion insert
  // =========================================================
  private static Promotion insertPromotion() {
    String storeTypeValue = null;
    // List<Schema.PicklistEntry> entries = Promotion.StoreType__c.getDescribe().getPicklistValues();
    // if (!entries.isEmpty()) {
    // storeTypeValue = entries[0].getValue();
    // }

    Promotion p = new Promotion(
      Name = 'DetailTestPromo',
      DisplayName = 'DetailTestPromo Display',
      PromotionCode = 'PDRTO-001',
      IsActive = true,
      StartDate = Date.today(),
      EndDate = Date.today().addDays(30),
      IsDiscountRateApplicable__c = true
      // ,
      // StoreType__c  = storeTypeValue
    );
    insert p;

    return [
      SELECT Id, Name, PromotionNo__c, IsDiscountRateApplicable__c
      FROM Promotion
      WHERE Id = :p.Id
      LIMIT 1
    ];
  }

  // =========================================================
  // PromotionDetailResDTO 기본 생성자
  // =========================================================

  @IsTest
  static void defaultConstructor_instantiates() {
    PromotionDetailResDTO dto = new PromotionDetailResDTO();
    System.assertNotEquals(null, dto);
  }

  // =========================================================
  // PromotionMaster
  // =========================================================

  @IsTest
  static void promotionMaster_mapsFieldsAndInitializesLists() {
    Promotion p = insertPromotion();

    Test.startTest();
    PromotionDetailResDTO.PromotionMaster master = new PromotionDetailResDTO.PromotionMaster(p);
    Test.stopTest();

    System.assertEquals(p.PromotionNo__c, master.NO_PROM, 'PromotionNo__c → NO_PROM');
    System.assertEquals(p.Name, master.NM_PROM, 'Name → NM_PROM');
    System.assertNotEquals(null, master.STORES, 'STORES 리스트 초기화');
    System.assertNotEquals(null, master.ITEMS, 'ITEMS 리스트 초기화');
    System.assertNotEquals(null, master.COUPONS, 'COUPONS 리스트 초기화');
    System.assertNotEquals(null, master.POINTS, 'POINTS 리스트 초기화');
    System.assertEquals(0, master.STORES.size());
    System.assertEquals(0, master.ITEMS.size());
    System.assertEquals(0, master.COUPONS.size());
    System.assertEquals(0, master.POINTS.size());
  }

  // =========================================================
  // PromotionStore (in-memory Account 관계 설정)
  // =========================================================

  @IsTest
  static void promotionStore_mapsAccountFields() {
    Account acc = new Account(
      Name = 'TestStore',
      StoreCode__c = 'SC-01',
      BrandCode__c = 'BR-01',
      StoreGroupCode__c = 'GRP-01'
      // ,
      // StoreType__c    = null
    );

    PromotionAccount__c pa = new PromotionAccount__c();
    pa.AccountId__r = acc;

    Test.startTest();
    PromotionDetailResDTO.PromotionStore store = new PromotionDetailResDTO.PromotionStore(pa);
    Test.stopTest();

    System.assertEquals('SC-01', store.CD_STORE, 'StoreCode__c → CD_STORE');
    System.assertEquals('TestStore', store.NM_STORE, 'Name → NM_STORE');
    System.assertEquals('BR-01', store.NM_BRAND, 'BrandCode__c → NM_BRAND');
    System.assertEquals('GRP-01', store.NM_GRP_STORE, 'StoreGroupCode__c → NM_GRP_STORE');
    // System.assertEquals(null,     store.NM_TYPE_STORE, 'StoreType__c null');
  }

  // =========================================================
  // PromotionItem — pcp null (단순 분기)
  // =========================================================

  @IsTest
  static void promotionItem_pcpNull_categoryFieldsEmpty() {
    Product2 prod = new Product2(Name = 'TestProduct', ProductCode = 'PROD-001', Family = 'TestFamily', ProductAccountCategoryCode__c = 'ACC-CAT');

    PromotionProduct pp = new PromotionProduct();
    pp.Product = prod;

    Test.startTest();
    PromotionDetailResDTO.PromotionItem item = new PromotionDetailResDTO.PromotionItem(pp, null, null, null);
    Test.stopTest();

    System.assertEquals('PROD-001', item.CD_ITEM, 'ProductCode → CD_ITEM');
    System.assertEquals('TestProduct', item.NM_ITEM, 'Name → NM_ITEM');
    System.assertEquals('TestFamily', item.NM_CLAS_GROP_ITEM, 'Family → NM_CLAS_GROP_ITEM');
    System.assertEquals('ACC-CAT', item.NM_CLAS_ACCT_ITEM, 'ProductAccountCategoryCode__c → NM_CLAS_ACCT_ITEM');
    System.assertEquals('', item.NM_CLAS_LARG_ITEM, 'pcp null → 대분류 빈 문자열');
    System.assertEquals('', item.NM_CLAS_MEDI_ITEM, 'pcp null → 중분류 빈 문자열');
    System.assertEquals('', item.NM_CLAS_SMAL_ITEM, 'pcp null → 소분류 빈 문자열');
  }

  @IsTest
  static void promotionItem_nullProductFamily_returnsEmpty() {
    Product2 prod = new Product2(Name = 'NoFamilyProduct', ProductCode = 'PROD-002', Family = null, ProductAccountCategoryCode__c = null);

    PromotionProduct pp = new PromotionProduct();
    pp.Product = prod;

    Test.startTest();
    PromotionDetailResDTO.PromotionItem item = new PromotionDetailResDTO.PromotionItem(pp, null, null, null);
    Test.stopTest();

    System.assertEquals('', item.NM_CLAS_GROP_ITEM, 'Family null → 빈 문자열');
    System.assertEquals('', item.NM_CLAS_ACCT_ITEM, 'ProductAccountCategoryCode__c null → 빈 문자열');
  }

  @IsTest
  static void promotionItem_withPcp_populatesCategoryNames() {
    Product2 prod = new Product2(Name = 'CatProduct', ProductCode = 'PROD-003');

    PromotionProduct pp = new PromotionProduct();
    pp.Product = prod;

    ProductCategory cat = new ProductCategory(
      SystemCode__c = 'SYS',
      LargeCategoryCode__c = 'LC',
      MediumCategoryCode__c = 'MC',
      SmallCategoryCode__c = 'SC'
    );

    ProductCategoryProduct pcp = new ProductCategoryProduct();
    pcp.ProductCategory = cat;

    Map<String, String> nameMap = new Map<String, String>{ 'SYS-LC' => 'Large Name', 'SYS-LC-MC' => 'Medium Name', 'SYS-LC-MC-SC' => 'Small Name' };

    Test.startTest();
    PromotionDetailResDTO.PromotionItem item = new PromotionDetailResDTO.PromotionItem(pp, pcp, null, nameMap);
    Test.stopTest();

    System.assertEquals('Large Name', item.NM_CLAS_LARG_ITEM, '대분류명 매핑');
    System.assertEquals('Medium Name', item.NM_CLAS_MEDI_ITEM, '중분류명 매핑');
    System.assertEquals('Small Name', item.NM_CLAS_SMAL_ITEM, '소분류명 매핑');
    System.assertEquals(0, item.AM_RETAIL_CURR, 'pe null → AM_RETAIL_CURR = 0');
  }

  @IsTest
  static void promotionItem_blankCategoryCode_returnsEmpty() {
    Product2 prod = new Product2(Name = 'NoCatProduct', ProductCode = 'PROD-004');
    PromotionProduct pp = new PromotionProduct();
    pp.Product = prod;

    // sys가 blank → buildCategoryCode returns null → 분류명 모두 ''
    ProductCategory cat = new ProductCategory(
      SystemCode__c = '',
      LargeCategoryCode__c = 'LC',
      MediumCategoryCode__c = 'MC',
      SmallCategoryCode__c = 'SC'
    );
    ProductCategoryProduct pcp = new ProductCategoryProduct();
    pcp.ProductCategory = cat;

    Test.startTest();
    PromotionDetailResDTO.PromotionItem item = new PromotionDetailResDTO.PromotionItem(pp, pcp, null, new Map<String, String>());
    Test.stopTest();

    System.assertEquals('', item.NM_CLAS_LARG_ITEM, 'sys blank → 대분류 빈 문자열');
    System.assertEquals('', item.NM_CLAS_MEDI_ITEM, 'sys blank → 중분류 빈 문자열');
    System.assertEquals('', item.NM_CLAS_SMAL_ITEM, 'sys blank → 소분류 빈 문자열');
  }

  // =========================================================
  // PromotionCoupon — mapVoucherTypeToCode 간접 검증
  // =========================================================

  private static PromotionDetailResDTO.PromotionCoupon buildCoupon(String voucherType, Integer discPct, Decimal faceVal, Date effDate, Date expDate) {
    VoucherDefinition vd = new VoucherDefinition(
      Name = 'TestCoupon',
      Type = voucherType,
      DiscountPercent = discPct,
      FaceValue = faceVal,
      EffectiveDate = effDate,
      ExpirationDate = expDate
    );

    VoucherLimit__c vl = new VoucherLimit__c();
    vl.VoucherDefinitionId__r = vd;

    return new PromotionDetailResDTO.PromotionCoupon(vl);
  }

  @IsTest
  static void promotionCoupon_fixedValue_returnsJeongaek() {
    Test.startTest();
    PromotionDetailResDTO.PromotionCoupon coupon = buildCoupon('FixedValue', 0, 5000, Date.newInstance(2025, 1, 1), Date.newInstance(2025, 12, 31));
    Test.stopTest();

    System.assertEquals('TestCoupon', coupon.NM_MAN_COUPON);
    System.assertEquals('정액', coupon.NM_TYPE_COUPON, 'FixedValue → 정액');
    System.assertEquals(0, coupon.RT_DISC);
    System.assertEquals(5000, coupon.AM_DISC);
    System.assertEquals('20250101', coupon.DT_STR_EXP, '유효시작일 yyyyMMdd');
    System.assertEquals('20251231', coupon.DT_END_EXP, '유효종료일 yyyyMMdd');
  }

  @IsTest
  static void promotionCoupon_discountPercentage_returnsJeongnyul() {
    Test.startTest();
    PromotionDetailResDTO.PromotionCoupon coupon = buildCoupon('DiscountPercentage', 10, 0, null, null);
    Test.stopTest();

    System.assertEquals('정률', coupon.NM_TYPE_COUPON, 'DiscountPercentage → 정률');
    System.assertEquals(10, coupon.RT_DISC);
    System.assertEquals('', coupon.DT_STR_EXP, 'EffectiveDate null → 빈 문자열');
    System.assertEquals('', coupon.DT_END_EXP, 'ExpirationDate null → 빈 문자열');
  }

  @IsTest
  static void promotionCoupon_productOrService_returnsGita() {
    Test.startTest();
    PromotionDetailResDTO.PromotionCoupon coupon = buildCoupon('ProductOrService', null, null, null, null);
    Test.stopTest();

    System.assertEquals('기타(특정)', coupon.NM_TYPE_COUPON, 'ProductOrService → 기타(특정)');
    System.assertEquals(0, coupon.RT_DISC, 'DiscountPercent null → 0');
    System.assertEquals(0, coupon.AM_DISC, 'FaceValue null → 0');
  }

  @IsTest
  static void promotionCoupon_unknownType_returnsEmpty() {
    Test.startTest();
    PromotionDetailResDTO.PromotionCoupon coupon = buildCoupon('UnknownType', 0, 0, null, null);
    Test.stopTest();

    System.assertEquals('', coupon.NM_TYPE_COUPON, '미정의 타입 → 빈 문자열');
  }

  @IsTest
  static void promotionCoupon_nullType_returnsEmpty() {
    Test.startTest();
    PromotionDetailResDTO.PromotionCoupon coupon = buildCoupon(null, 0, 0, null, null);
    Test.stopTest();

    System.assertEquals('', coupon.NM_TYPE_COUPON, 'null 타입 → 빈 문자열');
  }

  // =========================================================
  // PromotionPoint
  // =========================================================

  @IsTest
  static void promotionPoint_mapsAllFields() {
    // LoyaltyPgmCurrencySubtypeName__c 는 read-only 필드 — in-memory 설정 불가
    PromotionPointLimit__c ppl = new PromotionPointLimit__c(Name = 'TestPointLimit', Type__c = 'Multiplier', Value__c = 1.5);

    Test.startTest();
    PromotionDetailResDTO.PromotionPoint point = new PromotionDetailResDTO.PromotionPoint(ppl);
    Test.stopTest();

    System.assertEquals('TestPointLimit', point.NM_PROM_POINT, 'Name → NM_PROM_POINT');
    System.assertEquals('Multiplier', point.NM_TYPE_PROM_POINT, 'Type__c → NM_TYPE_PROM_POINT');
    // NM_TYPE_POINT = LoyaltyPgmCurrencySubtypeName__c (read-only, null in test)
    System.assertEquals(null, point.NM_TYPE_POINT, 'read-only 필드 → null');
    System.assertEquals(1.5, point.PT_SAVE, 'Value__c → PT_SAVE');
  }
}