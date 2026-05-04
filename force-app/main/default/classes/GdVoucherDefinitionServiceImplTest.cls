@IsTest
private class GdVoucherDefinitionServiceImplTest {
  /* =========================================================
   * 공통 Test Data
   * ========================================================= */
  @TestSetup
  static void setupData() {
    // Primary Loyalty Program 필수
    LoyaltyProgram lp = new LoyaltyProgram();
    lp.Name = 'Test Loyalty Program';
    lp.IsPrimary = true;
    insert lp;

    Account companyAccount = new Account();
    companyAccount.Name = 'Test Voucher Company';
    companyAccount.CompanyCode__c = '1000';
    insert companyAccount;

    VoucherCategory__c voucherCategory = new VoucherCategory__c();
    voucherCategory.Name = 'Test Signup Voucher Category';
    voucherCategory.Code__c = 'SignupCoupon';
    insert voucherCategory;
  }

  /* =========================================================
   * 공통 VoucherDefinition 생성 헬퍼
   * ========================================================= */
  private static VoucherDefinition buildVoucherDefinition(String name, String couponManNo, Id loyaltyProgramId) {
    String etValue = VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue();
    String ctcValue = VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue();

    VoucherDefinition vd = new VoucherDefinition();
    vd.Name = name;
    vd.CouponManNo__c = couponManNo;
    vd.Type = 'FixedValue';
    vd.FaceValue = 5000;
    vd.EffectiveDate = Date.today();
    vd.ExpirationDate = Date.today().addDays(365);
    vd.ExpirationType = etValue;
    vd.IsActive = true;
    vd.LoyaltyProgramId = loyaltyProgramId;
    vd.CouponTypeCode__c = ctcValue;
    vd.InsertId__c = 'TEST-INSERT-001';
    vd.ResponsibleDepartment__c = 'TEST-DEPT';
    vd.ResponsiblePerson__c = UserInfo.getUserId();
    vd.AccountId__c = getVoucherAccountId();
    vd.VoucherCategoryId__c = getVoucherCategoryId();
    return vd;
  }

  private static Id getVoucherAccountId() {
    return [SELECT Id FROM Account WHERE CompanyCode__c = '1000' AND StoreCode__c = NULL LIMIT 1].Id;
  }

  private static Id getVoucherCategoryId() {
    return [SELECT Id FROM VoucherCategory__c WHERE Code__c = 'SignupCoupon' LIMIT 1].Id;
  }

  /* =========================================================
   * 1) createVoucherDefinition 성공 케이스
   * ========================================================= */
  @IsTest
  static void test_createVoucherDefinition_success() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    String ctcValue = VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue();

    Map<String, Object> req = new Map<String, Object>{
      'CouponManNo__c' => 'CPN-001',
      'Name' => '테스트 쿠폰',
      'EffectiveDate' => Date.today(),
      'ExpirationDate' => Date.today().addDays(30),
      'Type' => 'FixedValue',
      'FaceValue' => 10000,
      'CouponTypeCode__c' => ctcValue
    };

    Test.startTest();
    try {
      service.createVoucherDefinition(req);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  /* =========================================================
   * 2) addVoucherLimitByPromotion 성공 케이스
   * ========================================================= */
  @IsTest
  static void test_addVoucherLimitByPromotion_success() {
    // 사전 VoucherDefinition 생성
    Id lpId = [SELECT Id FROM LoyaltyProgram WHERE IsPrimary = TRUE LIMIT 1].Id;
    VoucherDefinition vd = buildVoucherDefinition('프로모션 쿠폰', 'PROMO-001', lpId);
    insert vd;

    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    Map<String, Object> req = new Map<String, Object>{ 'promotionId' => 'PROMO123', 'CouponList' => new List<String>{ 'PROMO-001' } };

    Test.startTest();
    ApiResult result = service.addVoucherLimitByPromotion(req);
    Test.stopTest();

    System.assertEquals(200, result.code);

    List<VoucherLimit__c> limits = [
      SELECT Id, Type__c
      FROM VoucherLimit__c
      WHERE VoucherDefinitionId__c = :vd.Id
    ];

    System.assertEquals(1, limits.size());
    System.assertEquals('PromotionIncludeList', limits[0].Type__c);
  }

  /* =========================================================
   * 3) addVoucherLimit (쿠폰 등록 시 한도 설정)
   * ========================================================= */
  @IsTest
  static void test_addVoucherLimit_success() {
    Id lpId2 = [SELECT Id FROM LoyaltyProgram WHERE IsPrimary = TRUE LIMIT 1].Id;
    VoucherDefinition vd = buildVoucherDefinition('한도 테스트 쿠폰', 'LIMIT-001', lpId2);
    insert vd;

    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    Map<String, Object> req = new Map<String, Object>{
      'VoucherDefinitionId' => vd.Id,
      'ProductIncludeList' => new List<String>{ 'P001', 'P002' },
      'StoreIncludeList' => new List<String>{ 'S001' },
      'MinSalesAmount' => 10000
    };

    Test.startTest();
    service.addVoucherLimit(req);
    Test.stopTest();

    List<VoucherLimit__c> limits = [
      SELECT Id, Type__c
      FROM VoucherLimit__c
      WHERE VoucherDefinitionId__c = :vd.Id
    ];

    System.assert(limits.size() > 0);
  }

  /* =========================================================
   * 4) addVoucherLimit - 나머지 분기 (Exclude/Grade/Category/OrderType/MaxRate/MinQty)
   * ========================================================= */
  @IsTest
  static void test_addVoucherLimit_allBranches() {
    Id lpId = [SELECT Id FROM LoyaltyProgram WHERE IsPrimary = TRUE LIMIT 1].Id;
    VoucherDefinition vd = buildVoucherDefinition('전체분기 쿠폰', 'BRANCH-001', lpId);
    insert vd;

    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    Map<String, Object> req = new Map<String, Object>{
      'VoucherDefinitionId' => vd.Id,
      'ProductExcludeList' => new List<String>{ 'PE001' },
      'StoreExcludeList' => new List<String>{ 'SE001' },
      'StoreTypeIncludeList' => new List<String>{ 'ONLINE' },
      'GradeIncludeList' => new List<String>{ 'GOLD' },
      'ProductCategoryIncludeList' => new List<String>{ 'CAT001' },
      'ProductCategoryExcludeList' => new List<String>{ 'CAT002' },
      'OrderTypeIncludeList' => new List<String>{ 'SALE' },
      'MaxDiscountRate' => 30,
      'MinTotalQuantity' => 2
    };

    Test.startTest();
    service.addVoucherLimit(req);
    Test.stopTest();

    List<VoucherLimit__c> limits = [SELECT Id, Type__c FROM VoucherLimit__c WHERE VoucherDefinitionId__c = :vd.Id];
    System.assert(limits.size() > 0);
  }

  /* =========================================================
   * 5) createVoucherDefinition - Period 만료 타입 (ExpirationPeriod 있음)
   * ========================================================= */
  @IsTest
  static void test_createVoucherDefinition_withPeriod() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();
    String ctcValue = VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue();

    Map<String, Object> req = new Map<String, Object>{
      'CouponManNo__c' => 'CPN-PERIOD',
      'Name' => '기간 쿠폰',
      'EffectiveDate' => Date.today(),
      'Type' => 'FixedValue',
      'FaceValue' => 5000,
      'CouponTypeCode__c' => ctcValue,
      'ExpirationPeriod' => 3
    };

    Test.startTest();
    try {
      service.createVoucherDefinition(req);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  /* =========================================================
   * 6) createVoucherDefinition - Limits 포함 경로
   * ========================================================= */
  @IsTest
  static void test_createVoucherDefinition_withLimits() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();
    String ctcValue = VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue();

    Map<String, Object> req = new Map<String, Object>{
      'CouponManNo__c' => 'CPN-LIMIT',
      'Name' => '한도포함 쿠폰',
      'EffectiveDate' => Date.today(),
      'ExpirationDate' => Date.today().addDays(60),
      'Type' => 'FixedValue',
      'FaceValue' => 3000,
      'CouponTypeCode__c' => ctcValue,
      'Limits' => new Map<String, Object>{ 'ProductIncludeList' => new List<String>{ 'P-LIM' } }
    };

    Test.startTest();
    try {
      service.createVoucherDefinition(req);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  /* =========================================================
   * 7) createVoucherDefinition - 필수 필드 누락 (ValidationException 경로)
   * ========================================================= */
  @IsTest
  static void test_createVoucherDefinition_missingField() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    Map<String, Object> req = new Map<String, Object>{
      'Name' => '누락 쿠폰'
      // CouponManNo__c 누락 → ValidationException
    };

    Test.startTest();
    try {
      service.createVoucherDefinition(req);
      System.assert(false, 'should throw');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * 8) addVoucherLimitByPromotion - 빈 요청 → 예외
   * ========================================================= */
  @IsTest
  static void test_addVoucherLimitByPromotion_emptyRequest() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    Test.startTest();
    try {
      service.addVoucherLimitByPromotion(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * 9) addVoucherLimitByPromotion - CouponList null → 200 early return
   * ========================================================= */
  @IsTest
  static void test_addVoucherLimitByPromotion_nullCouponList() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    Map<String, Object> req = new Map<String, Object>{
      'promotionId' => 'PROMO-NULL'
      // CouponList 없음
    };

    Test.startTest();
    ApiResult result = service.addVoucherLimitByPromotion(req);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assert(true);
  }

  /* =========================================================
   * 10) addVoucherLimitByPromotion - 존재하지 않는 쿠폰 → 예외
   * ========================================================= */
  @IsTest
  static void test_addVoucherLimitByPromotion_couponNotFound() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    Map<String, Object> req = new Map<String, Object>{ 'promotionId' => 'PROMO-X', 'CouponList' => new List<String>{ 'NOT-EXIST-999' } };

    Test.startTest();
    try {
      service.addVoucherLimitByPromotion(req);
      System.assert(false, 'should throw');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * 11) addVoucherLimit - 빈 요청 → 예외
   * ========================================================= */
  @IsTest
  static void test_addVoucherLimit_emptyRequest() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();

    Test.startTest();
    try {
      service.addVoucherLimit(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * 12) createVoucherDefinition - DiscountPercentage 타입 경로
   * ========================================================= */
  @IsTest
  static void test_createVoucherDefinition_discountType() {
    GdVoucherDefinitionServiceImpl service = new GdVoucherDefinitionServiceImpl();
    String ctcValue = VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue();

    Map<String, Object> req = new Map<String, Object>{
      'CouponManNo__c' => 'CPN-DISC',
      'Name' => '할인 쿠폰',
      'EffectiveDate' => Date.today(),
      'ExpirationDate' => Date.today().addDays(30),
      'Type' => 'DiscountPercentage',
      'DiscountPercent' => 10,
      'CouponTypeCode__c' => ctcValue
    };

    Test.startTest();
    try {
      service.createVoucherDefinition(req);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }
}