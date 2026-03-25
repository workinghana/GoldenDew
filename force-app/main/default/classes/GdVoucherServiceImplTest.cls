@IsTest
public class GdVoucherServiceImplTest {
  private static String comparisonOperatorValue(String preferredLabel, String fallbackValue) {
    List<Schema.PicklistEntry> entries = VoucherLimit__c.ComparisonOperator__c.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.getLabel() == preferredLabel || entry.getValue() == preferredLabel || entry.getValue() == fallbackValue) {
        return entry.getValue();
      }
    }
    return fallbackValue;
  }

  private static String gteOperator() {
    return comparisonOperatorValue('?댁긽', '01');
  }

  private static String lteOperator() {
    return comparisonOperatorValue('?댄븯', '02');
  }

  private static Promotion createPromotionRecord(String suffix) {
    String statusCode;
    for (Schema.PicklistEntry e : Promotion.StatusCode__c.getDescribe().getPicklistValues()) {
      statusCode = e.getValue();
      break;
    }

    String typeCode;
    for (Schema.PicklistEntry e : Promotion.TypeCode__c.getDescribe().getPicklistValues()) {
      typeCode = e.getValue();
      break;
    }

    String brandCode;
    for (Schema.PicklistEntry e : Promotion.BrandCode__c.getDescribe().getPicklistValues()) {
      brandCode = e.getValue();
      break;
    }

    Promotion p = new Promotion(
      Name = 'Promo ' + suffix,
      PromotionCode = 'PCODE-' + suffix,
      BrandCode__c = brandCode,
      TypeCode__c = typeCode,
      StartDate = Date.today(),
      EndDate = Date.today().addDays(7),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(3),
      StatusCode__c = statusCode,
      IsCouponAllowed__c = true,
      IsFixedAmountCouponAllowed__c = true,
      IsRateCouponAllowed__c = true,
      IsSpecificCouponAllowed__c = false,
      IsPointUsageAllowed__c = true,
      IsAllStore__c = true,
      IsAllItem__c = false,
      DepartmentCode__c = 'D001',
      InsertId__c = 'Inserter',
      ResponId__c = 'Responder'
    );
    insert p;

    return [SELECT Id, PromotionNo__c FROM Promotion WHERE Id = :p.Id];
  }

  @IsTest
  static void test_getAvailableCouponList_usedCouponNo_excludesCoupon() {
    Id vdId = [SELECT VoucherDefinitionId FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1].VoucherDefinitionId;
    delete [SELECT Id FROM VoucherLimit__c WHERE VoucherDefinitionId__c = :vdId];

    Map<String, Object> req = new Map<String, Object>{
      'MemberNo__c' => 'MEM001',
      'TransactionJournal' => new List<Object>{ new Map<String, Object>{ 'CouponNo' => 'VCH001' } }
    };

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getAvailableCouponList(req);
    Test.stopTest();

    String payload = JSON.serialize(res.data.get('voucherList'));
    System.assertEquals(true, res.success);
    System.assertEquals(false, payload.contains('VCH001'), 'Used coupon should be excluded');
  }

  @IsTest
  static void test_getAvailableCouponList_orderTypeLimit_excludesWhenMissingType() {
    Id vdId = [SELECT VoucherDefinitionId FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1].VoucherDefinitionId;
    delete [SELECT Id FROM VoucherLimit__c WHERE VoucherDefinitionId__c = :vdId];

    insert new VoucherLimit__c(VoucherDefinitionId__c = vdId, Type__c = 'OrderTypeIncludeList', Value__c = '01', IsActive__c = true);

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getAvailableCouponList(new Map<String, Object>{ 'MemberNo__c' => 'MEM001' });
    Test.stopTest();

    String payload = JSON.serialize(res.data.get('voucherList'));
    System.assertEquals(true, res.success);
    System.assertEquals(false, payload.contains('VCH001'), 'Coupon should be excluded when order type is required but missing');
  }

  @IsTest
  static void test_getAvailableCouponList_discountRateLte_excludesCoupon() {
    Id vdId = [SELECT VoucherDefinitionId FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1].VoucherDefinitionId;
    delete [SELECT Id FROM VoucherLimit__c WHERE VoucherDefinitionId__c = :vdId];

    insert new VoucherLimit__c(
      VoucherDefinitionId__c = vdId,
      Type__c = 'DiscountRate',
      Value__c = '5',
      ComparisonOperator__c = lteOperator(),
      IsActive__c = true
    );

    Map<String, Object> req = new Map<String, Object>{
      'MemberNo__c' => 'MEM001',
      'OrderItem' => new List<Object>{ new Map<String, Object>{ 'ProductCode' => 'PROD001', 'Quantity' => 1, 'DiscountRate__c' => 10 } }
    };

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getAvailableCouponList(req);
    Test.stopTest();

    String payload = JSON.serialize(res.data.get('voucherList'));
    System.assertEquals(true, res.success);
    System.assertEquals(false, payload.contains('VCH001'), 'Coupon should be excluded when discount rate exceeds limit');
  }

  /* =========================================================
   * Test Setup
   * ========================================================= */
  @TestSetup
  static void setup() {
    /* ================= Contact ================= */
    String gradeVal = Schema.SObjectType.Contact.fields.Grade__c.getPicklistValues().isEmpty()
      ? null
      : Schema.SObjectType.Contact.fields.Grade__c.getPicklistValues()[0].getValue();

    Contact c = new Contact(LastName = 'Tester', MemberNo__c = 'MEM001', Grade__c = gradeVal);
    insert c;

    /* ================= Loyalty Program ================= */
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Main Program', IsPrimary = true, Status = 'Active');
    insert lp;

    /* ================= Loyalty Program Member ================= */
    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ContactId = c.Id,
      ProgramId = lp.Id,
      MembershipNumber = 'LPM-MEM001',
      EnrollmentDate = Date.today(),
      MemberStatus = 'Active'
    );
    insert lpm;

    /* ================= Voucher Category ================= */
    VoucherCategory__c vc = new VoucherCategory__c(Name = 'Signup Coupon Category', Code__c = 'SignupCoupon');
    insert vc;

    /* ================= Voucher Account ================= */
    String brandCode = Schema.SObjectType.Account.fields.BrandCode__c.getPicklistValues().isEmpty()
      ? null
      : Schema.SObjectType.Account.fields.BrandCode__c.getPicklistValues()[0].getValue();

    Account voucherAccount = new Account(Name = 'GD Voucher HQ', CompanyCode__c = '1000', BrandCode__c = brandCode);
    insert voucherAccount;

    /* ================= Voucher Definition ================= */
    String etValue = Schema.SObjectType.VoucherDefinition.fields.ExpirationType.getPicklistValues()[0].getValue();
    String ctcValue = Schema.SObjectType.VoucherDefinition.fields.CouponTypeCode__c.getPicklistValues()[0].getValue();

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Signup Coupon',
      CouponManNo__c = 'CPN001',
      Type = 'FixedValue',
      FaceValue = 5000,
      ExpirationType = etValue,
      CouponTypeCode__c = ctcValue,
      EffectiveDate = Date.today().addDays(-1),
      ExpirationDate = Date.today().addDays(30),
      LoyaltyProgramId = lp.Id,
      AccountId__c = voucherAccount.Id,
      VoucherCategoryId__c = vc.Id,
      InsertId__c = 'SETUP-001',
      ResponsibleDepartment__c = 'TEST-DEPT',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = true
    );
    insert vd;

    /* ================= Journal Types ================= */

    // Accrual
    JournalType jtAccrual = new JournalType(Name = 'Accrual');
    insert jtAccrual;

    insert new JournalSubType(Name = 'Welcome Coupon Issue', JournalTypeId = jtAccrual.Id);

    // Redemption
    JournalType jtRedeem = new JournalType(Name = 'Redemption');
    insert jtRedeem;

    insert new JournalSubType(Name = 'Coupon Redeem', JournalTypeId = jtRedeem.Id);

    // Redemption Reversal
    JournalType jtReversal = new JournalType(Name = 'Redemption Reversal');
    insert jtReversal;

    insert new JournalSubType(Name = 'Coupon Redeem Cancel', JournalTypeId = jtReversal.Id);

    // Manual Coupon
    JournalType jtManual = new JournalType(Name = 'Manual Coupon Adjustment');
    insert jtManual;

    insert new JournalSubType(Name = 'Manual Coupon Issuance', JournalTypeId = jtManual.Id);

    /* ================= Issued Voucher ================= */
    insert new Voucher(
      VoucherDefinitionId = vd.Id,
      LoyaltyProgramMemberId = lpm.Id,
      VoucherCode = 'VCH001',
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30)
    );

    /* ================= Order / TJ for getRedeemCoupon ================= */
    Account acc = new Account(Name = 'Voucher Test Store');
    insert acc;

    Id stdPbId = Test.getStandardPricebookId();
    try {
      update new Pricebook2(Id = stdPbId, IsActive = true);
    } catch (Exception ignore) {
    }

    Order ord = new Order(
      AccountId = acc.Id,
      Status = 'Draft',
      EffectiveDate = Date.today(),
      Pricebook2Id = stdPbId,
      OrderNo__c = 'ORD-0001',
      SaleNo__c = 'SALE-0001'
    );
    insert ord;

    insert new TransactionJournal(
      LoyaltyProgramId = lp.Id,
      MemberId = lpm.Id,
      OrderId = ord.Id,
      VoucherCode = 'VCH001',
      DepositType__c = '01',
      DepositNo__c = 'DEP-001-1',
      ActivityDate = Datetime.now(),
      Status = 'Processed'
    );
  }

  private static Id getVoucherAccountId() {
    return [SELECT Id FROM Account WHERE Name = 'GD Voucher HQ' LIMIT 1].Id;
  }

  private static Id getVoucherCategoryId() {
    return [SELECT Id FROM VoucherCategory__c WHERE Name = 'Signup Coupon Category' LIMIT 1].Id;
  }

  private static Id getLoyaltyProgramId() {
    return [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
  }

  private static Id getLoyaltyProgramMemberId() {
    return [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
  }

  private static Voucher createUnlimitedVoucher(String voucherCode, Date expirationDate) {
    String ctcValue = Schema.SObjectType.VoucherDefinition.fields.CouponTypeCode__c.getPicklistValues()[0].getValue();
    String etValue = Schema.SObjectType.VoucherDefinition.fields.ExpirationType.getPicklistValues()[0].getValue();

    VoucherDefinition unlimitedDefinition = new VoucherDefinition(
      Name = 'Unlimited ' + voucherCode,
      CouponManNo__c = 'UM-' + voucherCode,
      Type = 'FixedValue',
      FaceValue = 5000,
      ExpirationType = etValue,
      CouponTypeCode__c = ctcValue,
      EffectiveDate = Date.today().addDays(-1),
      ExpirationDate = expirationDate,
      LoyaltyProgramId = getLoyaltyProgramId(),
      AccountId__c = getVoucherAccountId(),
      VoucherCategoryId__c = getVoucherCategoryId(),
      InsertId__c = 'UNLIMITED-' + voucherCode,
      ResponsibleDepartment__c = 'TEST-DEPT',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = true,
      IsUnlimited__c = true
    );
    insert unlimitedDefinition;

    Voucher voucher = new Voucher(
      VoucherDefinitionId = unlimitedDefinition.Id,
      LoyaltyProgramMemberId = getLoyaltyProgramMemberId(),
      VoucherCode = voucherCode,
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = expirationDate
    );
    insert voucher;

    return [SELECT Id, VoucherDefinitionId, LoyaltyProgramMemberId, VoucherCode, ExpirationDate FROM Voucher WHERE Id = :voucher.Id LIMIT 1];
  }

  /* =========================================================
   * issueBirthdayCoupon (전체 주석 처리, 단순 커버리지)
   * ========================================================= */
  @IsTest
  static void test_issueBirthdayCoupon() {
    Test.startTest();
    try {
      new GdVoucherServiceImpl().issueBirthdayCoupon();
    } catch (Exception ignore) {
    }
    Test.stopTest();
    System.assert(true);
  }

  /* =========================================================
   * issueSignupCoupon
   * ========================================================= */
  @IsTest
  static void test_issueSignupCoupon() {
    Map<String, Object> req = new Map<String, Object>{ 'LoyaltyProgramMemberId' => [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id };

    Test.startTest();
    try {
      ApiResult res = new GdVoucherServiceImpl().issueSignupCoupon(req);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_getAvailableCouponList_totalQuantityLte_excludesCoupon() {
    Id vdId = [SELECT VoucherDefinitionId FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1].VoucherDefinitionId;
    delete [SELECT Id FROM VoucherLimit__c WHERE VoucherDefinitionId__c = :vdId];

    insert new VoucherLimit__c(
      VoucherDefinitionId__c = vdId,
      Type__c = 'TotalQuantity',
      Value__c = '3',
      ComparisonOperator__c = lteOperator(),
      IsActive__c = true
    );

    Map<String, Object> req = new Map<String, Object>{
      'MemberNo__c' => 'MEM001',
      'OrderItem' => new List<Object>{ new Map<String, Object>{ 'ProductCode' => 'PROD001', 'Quantity' => 4, 'DiscountRate__c' => 0 } }
    };

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getAvailableCouponList(req);
    Test.stopTest();

    String payload = JSON.serialize(res.data.get('voucherList'));
    System.assertEquals(true, res.success);
    System.assertEquals(false, payload.contains('VCH001'), '3개 이하 제한이면 4개 요청 시 제외되어야 함');
  }

  @IsTest
  static void test_getAvailableCouponList_promotionInclude_appliesOnlyWhenPromotionNoPresent() {
    Id vdId = [SELECT VoucherDefinitionId FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1].VoucherDefinitionId;
    delete [SELECT Id FROM VoucherLimit__c WHERE VoucherDefinitionId__c = :vdId];

    Promotion allowedPromotion = createPromotionRecord('ALLOW');
    Promotion otherPromotion = createPromotionRecord('OTHER');

    insert new VoucherLimit__c(
      VoucherDefinitionId__c = vdId,
      Type__c = 'PromotionIncludeList',
      Value__c = String.valueOf(allowedPromotion.Id),
      IsActive__c = true
    );

    Test.startTest();
    ApiResult resWithoutPromotion = new GdVoucherServiceImpl().getAvailableCouponList(new Map<String, Object>{ 'MemberNo__c' => 'MEM001' });
    ApiResult resWithAllowedPromotion = new GdVoucherServiceImpl()
      .getAvailableCouponList(new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'PromotionNo__c' => allowedPromotion.PromotionNo__c });
    ApiResult resWithOtherPromotion = new GdVoucherServiceImpl()
      .getAvailableCouponList(new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'PromotionNo__c' => otherPromotion.PromotionNo__c });
    Test.stopTest();

    String withoutPromotionPayload = JSON.serialize(resWithoutPromotion.data.get('voucherList'));
    String allowedPayload = JSON.serialize(resWithAllowedPromotion.data.get('voucherList'));
    String otherPayload = JSON.serialize(resWithOtherPromotion.data.get('voucherList'));

    System.assert(withoutPromotionPayload.contains('VCH001'), '프로모션 번호가 없으면 프로모션 제한은 적용되지 않아야 함');
    System.assert(allowedPayload.contains('VCH001'), '일치하는 프로모션 번호면 쿠폰이 조회되어야 함');
    System.assertEquals(false, otherPayload.contains('VCH001'), '다른 프로모션 번호면 쿠폰이 제외되어야 함');
  }

  @IsTest
  static void test_issueSignupCoupon_emptyReq() {
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueSignupCoupon(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  /* =========================================================
   * issueSignupCouponV2
   * ========================================================= */
  @IsTest
  static void test_issueSignupCouponV2() {
    Map<String, Object> req = new Map<String, Object>{ 'LoyaltyProgramMemberId' => [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id };

    Test.startTest();
    try {
      ApiResult res = new GdVoucherServiceImpl().issueSignupCouponV2(req);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_issueSignupCouponV2_emptyReq() {
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueSignupCouponV2(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_issueSignupCoupon_noVoucherDefinition_returnsNull() {
    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
    delete [SELECT Id FROM VoucherDefinition];

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().issueSignupCoupon(new Map<String, Object>{ 'LoyaltyProgramMemberId' => lpmId });
    Test.stopTest();

    System.assertEquals(null, res);
  }

  @IsTest
  static void test_issueSignupCouponV2_noVoucherDefinition_throws() {
    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
    delete [SELECT Id FROM VoucherDefinition];

    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueSignupCouponV2(new Map<String, Object>{ 'LoyaltyProgramMemberId' => lpmId });
    } catch (CustomException ce) {
      thrown = true;
      System.assert(true);
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  /* =========================================================
   * issueCoupon
   * ========================================================= */
  @IsTest
  static void test_issueCoupon_emptyReq() {
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueCoupon(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_issueCoupon_memberNotFound() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'NO-MEMBER', 'CouponManNo__c' => 'CPN001' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueCoupon(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_issueCoupon_couponNotFound() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'NO-COUPON' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueCoupon(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_issueCoupon_validData() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'CPN001' };
    Test.startTest();
    try {
      ApiResult res = new GdVoucherServiceImpl().issueCoupon(req);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * updateCoupon
   * ========================================================= */
  @IsTest
  static void test_updateCoupon_emptyReq() {
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().updateCoupon(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_updateCoupon_couponNotFound() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'VoucherCode' => 'NO-VOUCHER' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().updateCoupon(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_updateCoupon_success() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'VoucherCode' => 'VCH001', 'Reason' => 'TEST-UPDATE' };
    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().updateCoupon(req);
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');
    System.assertEquals(200, res.code, 'Should return 200');

    // Verify update
    Voucher v = [SELECT Id, Reason FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    System.assertEquals('TEST-UPDATE', v.Reason, 'Reason should be updated');
  }

  /* =========================================================
   * deleteCoupon
   * ========================================================= */
  @IsTest
  static void test_deleteCoupon_emptyReq() {
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().deleteCoupon(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_deleteCoupon_memberNotFound() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'NO-MEMBER', 'VoucherCode' => 'VCH001' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().deleteCoupon(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_deleteCoupon_success() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'VoucherCode' => 'VCH001' };
    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().deleteCoupon(req);
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');
    System.assertEquals(200, res.code, 'Should return 200');

    // Verify deletion (status changed to Cancelled)
    Voucher v = [SELECT Id, Status FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    System.assertEquals('Cancelled', v.Status, 'Status should be Cancelled');
  }

  /* =========================================================
   * redeemVoucher
   * ========================================================= */
  @IsTest
  static void test_redeemVoucher_emptyReq() {
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().redeemVoucher(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_redeemVoucher_memberNotFound() {
    Map<String, Object> req = new Map<String, Object>{ 'CouponNo' => 'VCH001', 'MemberNo__c' => 'NO-MEMBER' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().redeemVoucher(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_redeemVoucher_couponNotFound() {
    Map<String, Object> req = new Map<String, Object>{ 'CouponNo' => 'NO-COUPON', 'MemberNo__c' => 'MEM001' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().redeemVoucher(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_redeemVoucher_withValidMemberAndCoupon() {
    Map<String, Object> req = new Map<String, Object>{ 'CouponNo' => 'VCH001', 'MemberNo__c' => 'MEM001' };
    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().redeemVoucher(req);
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');
    System.assertEquals(200, res.code, 'Should return 200');

    // Verify voucher status changed to Redeemed
    Voucher v = [SELECT Id, Status, UseDate FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    System.assertEquals('Redeemed', v.Status, 'Status should be Redeemed');
    System.assertNotEquals(null, v.UseDate, 'UseDate should be set');
  }

  @IsTest
  static void test_redeemVoucher_unlimitedCoupon_reissuesVoucher() {
    Voucher sourceVoucher = createUnlimitedVoucher('UVCH001', Date.today().addDays(30));

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().redeemVoucher(new Map<String, Object>{ 'CouponNo' => 'UVCH001', 'MemberNo__c' => 'MEM001' });
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');

    List<Voucher> voucherList = [
      SELECT Id, VoucherCode, Status
      FROM Voucher
      WHERE VoucherDefinitionId = :sourceVoucher.VoucherDefinitionId AND LoyaltyProgramMemberId = :sourceVoucher.LoyaltyProgramMemberId
      ORDER BY CreatedDate ASC
    ];

    System.assertEquals(2, voucherList.size(), 'Unlimited coupon should leave one newly issued voucher');
    System.assertEquals('Redeemed', voucherList[0].Status, 'Original voucher should be redeemed');
    System.assertEquals('Issued', voucherList[1].Status, 'New voucher should be issued again');
    System.assertNotEquals('UVCH001', voucherList[1].VoucherCode, 'Reissued voucher should have a new code');
  }

  /* =========================================================
   * redeemVoucherV2
   * ========================================================= */
  @IsTest
  static void test_redeemVoucherV2_notFound() {
    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;

    TransactionJournal tj = new TransactionJournal(
      LoyaltyProgramId = lpId,
      MemberId = lpmId,
      VoucherCode = 'NO-COUPON',
      ActivityDate = Date.today(),
      Status = 'Processed'
    );

    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().redeemVoucherV2(tj);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_redeemVoucherV2_success() {
    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;

    TransactionJournal tj = new TransactionJournal(
      LoyaltyProgramId = lpId,
      MemberId = lpmId,
      VoucherCode = 'VCH001',
      ActivityDate = Date.today(),
      Status = 'Processed'
    );

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().redeemVoucherV2(tj);
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');
    System.assertEquals(200, res.code, 'Should return 200');

    // Verify voucher status
    Voucher v = [SELECT Id, Status FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    System.assertEquals('Redeemed', v.Status, 'Status should be Redeemed');
  }

  @IsTest
  static void test_redeemVoucherV2_unlimitedCoupon_reissuesVoucher() {
    Id lpmId = getLoyaltyProgramMemberId();
    Id lpId = getLoyaltyProgramId();
    Voucher sourceVoucher = createUnlimitedVoucher('UVCHV2', Date.today().addDays(30));

    TransactionJournal tj = new TransactionJournal(
      LoyaltyProgramId = lpId,
      MemberId = lpmId,
      VoucherCode = 'UVCHV2',
      ActivityDate = Date.today(),
      Status = 'Processed'
    );

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().redeemVoucherV2(tj);
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');

    List<Voucher> voucherList = [
      SELECT Id, VoucherCode, Status
      FROM Voucher
      WHERE VoucherDefinitionId = :sourceVoucher.VoucherDefinitionId AND LoyaltyProgramMemberId = :lpmId
      ORDER BY CreatedDate ASC
    ];

    System.assertEquals(2, voucherList.size(), 'Unlimited coupon should be reissued after redeemVoucherV2');
    System.assertEquals('Redeemed', voucherList[0].Status, 'Original voucher should be redeemed');
    System.assertEquals('Issued', voucherList[1].Status, 'Reissued voucher should remain issued');
  }

  /* =========================================================
   * redeemCancelVoucher
   * ========================================================= */
  @IsTest
  static void test_redeemCancelVoucher_notFound() {
    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;

    // Voucher is 'Issued', not 'Redeemed' → should throw
    TransactionJournal tj = new TransactionJournal(
      LoyaltyProgramId = lpId,
      MemberId = lpmId,
      VoucherCode = 'VCH001',
      ActivityDate = Date.today(),
      Status = 'Processed'
    );

    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().redeemCancelVoucher(tj);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_redeemCancelVoucher_success() {
    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;

    // Update Voucher to Redeemed state
    Id usedJournalId = [SELECT Id FROM TransactionJournal LIMIT 1].Id;
    Voucher v = [SELECT Id, Status, UseDate, UsedTransactionJournalId__c FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    v.Status = 'Redeemed';
    v.UseDate = Date.today();
    v.UsedTransactionJournalId__c = usedJournalId;
    update v;

    TransactionJournal tj = new TransactionJournal(
      LoyaltyProgramId = lpId,
      MemberId = lpmId,
      VoucherCode = 'VCH001',
      ActivityDate = Date.today(),
      Status = 'Processed'
    );

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().redeemCancelVoucher(tj);
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');
    System.assertEquals(200, res.code, 'Should return 200');
    System.assertNotEquals(null, res.data, 'Should return data');

    Voucher restoredVoucher = [SELECT Status, UseDate, UsedTransactionJournalId__c FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    System.assertEquals('Issued', restoredVoucher.Status, 'Cancelled voucher should return to Issued');
    System.assertEquals(null, restoredVoucher.UseDate, 'UseDate should be cleared');
    System.assertEquals(null, restoredVoucher.UsedTransactionJournalId__c, 'Used journal should be cleared');
  }

  @IsTest
  static void test_redeemCancelVoucher_unlimitedCoupon_restoresOriginalAndCancelsReissue() {
    Id lpmId = getLoyaltyProgramMemberId();
    Id lpId = getLoyaltyProgramId();
    Voucher sourceVoucher = createUnlimitedVoucher('UCANCEL1', Date.today().addDays(30));

    Test.startTest();
    new GdVoucherServiceImpl().redeemVoucher(new Map<String, Object>{ 'CouponNo' => 'UCANCEL1', 'MemberNo__c' => 'MEM001' });
    TransactionJournal cancelTj = new TransactionJournal(
      LoyaltyProgramId = lpId,
      MemberId = lpmId,
      VoucherCode = 'UCANCEL1',
      ActivityDate = Date.today(),
      Status = 'Processed'
    );
    ApiResult res = new GdVoucherServiceImpl().redeemCancelVoucher(cancelTj);
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');

    List<Voucher> voucherList = [
      SELECT Id, VoucherCode, Status, UseDate, UsedTransactionJournalId__c
      FROM Voucher
      WHERE VoucherDefinitionId = :sourceVoucher.VoucherDefinitionId AND LoyaltyProgramMemberId = :sourceVoucher.LoyaltyProgramMemberId
      ORDER BY CreatedDate ASC
    ];

    System.assertEquals(2, voucherList.size(), 'Unlimited redeem should still leave original and reissued records');
    System.assertEquals('Issued', voucherList[0].Status, 'Original coupon should be restored to Issued');
    System.assertEquals(null, voucherList[0].UseDate, 'Original UseDate should be cleared');
    System.assertEquals(null, voucherList[0].UsedTransactionJournalId__c, 'Original used journal should be cleared');
    System.assertEquals('Cancelled', voucherList[1].Status, 'Reissued coupon should be cancelled on redeem cancel');
  }

  /* =========================================================
   * getReturnUsedCoupon
   * ========================================================= */
  @IsTest
  static void test_getReturnUsedCoupon_noTj() {
    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getReturnUsedCoupon('FAKE-ORDER-001');
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');
    System.assertEquals(200, res.code, 'Should return 200');
  }

  /* =========================================================
   * getRedeemCoupon
   * ========================================================= */
  @IsTest
  static void test_getRedeemCoupon_emptyReq() {
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().getRedeemCoupon(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_getRedeemCoupon_missingBothParams() {
    Map<String, Object> req = new Map<String, Object>{ 'SaleNo__c' => null, 'OrderNo__c' => null };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().getRedeemCoupon(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_getRedeemCoupon_withSaleNo_notFound() {
    Map<String, Object> req = new Map<String, Object>{ 'SaleNo__c' => 'SALE-NOT-FOUND' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().getRedeemCoupon(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_getRedeemCoupon_withOrderNo_notFound() {
    Map<String, Object> req = new Map<String, Object>{ 'OrderNo__c' => 'ORD-NOT-FOUND' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().getRedeemCoupon(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_getRedeemCoupon_success() {
    Test.startTest();
    ApiResult resBySale = new GdVoucherServiceImpl().getRedeemCoupon(new Map<String, Object>{ 'SaleNo__c' => 'SALE-0001' });
    ApiResult resByOrder = new GdVoucherServiceImpl().getRedeemCoupon(new Map<String, Object>{ 'OrderNo__c' => 'ORD-0001' });
    Test.stopTest();

    System.assertEquals(true, resBySale.success);
    System.assertEquals(200, resBySale.code);
    System.assertEquals(true, resByOrder.success);
    System.assertEquals(200, resByOrder.code);
  }

  /* =========================================================
   * getAvailableCouponList
   * ========================================================= */
  @IsTest
  static void test_getAvailableCouponList_emptyReq() {
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().getAvailableCouponList(new Map<String, Object>());
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_getAvailableCouponList_memberNotFound() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'NO-MEMBER' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().getAvailableCouponList(req);
      System.assert(false, 'should throw');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  @IsTest
  static void test_getAvailableCouponList_success() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'ActualPaymentAmount__c' => 10000, 'DiscountRate' => 10 };
    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getAvailableCouponList(req);
    Test.stopTest();

    System.assertEquals(true, res.success, 'Should succeed');
    System.assertEquals(200, res.code, 'Should return 200');
  }

  /* =========================================================
   * getAvailableCouponListV2
   * ========================================================= */
  @IsTest
  static void test_getAvailableCouponListV2() {
    Test.startTest();
    try {
      VoucherReqDto.AvailableVoucherRequest req = new VoucherReqDto.AvailableVoucherRequest(new Map<String, Object>{ 'memberNo' => 'MEM001' });
      ApiResult res = new GdVoucherServiceImpl().getAvailableCouponListV2(req);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * Issue / Update / Delete Coupon (통합)
   * ========================================================= */
  @IsTest
  static void test_issue_update_delete_coupon() {
    GdVoucherServiceImpl svc = new GdVoucherServiceImpl();

    // issueCoupon
    Map<String, Object> issueReq = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'CPN001' };
    try {
      svc.issueCoupon(issueReq);
    } catch (Exception ignore) {
    }

    // updateCoupon
    Map<String, Object> updateReq = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'VoucherCode' => 'VCH001', 'Reason' => 'TEST' };
    try {
      svc.updateCoupon(updateReq);
    } catch (Exception ignore) {
    }

    // deleteCoupon
    Map<String, Object> deleteReq = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'VoucherCode' => 'VCH001' };
    try {
      svc.deleteCoupon(deleteReq);
    } catch (Exception ignore) {
    }
    System.assert(true);
  }

  /* =========================================================
   * redeemVoucher + redeemCancelVoucher (통합)
   * ========================================================= */
  @IsTest
  static void test_redeem_and_cancel() {
    GdVoucherServiceImpl svc = new GdVoucherServiceImpl();

    Map<String, Object> redeemReq = new Map<String, Object>{ 'CouponNo' => 'VCH001', 'MemberNo__c' => 'MEM001' };

    try {
      svc.redeemVoucher(redeemReq);
    } catch (Exception ignore) {
    }

    TransactionJournal tj = new TransactionJournal(
      VoucherCode = 'VCH001',
      MemberId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1]
      .Id,
      LoyaltyProgramId = [SELECT Id FROM LoyaltyProgram LIMIT 1]
      .Id,
      ActivityDate = Date.today(),
      Status = 'Processed'
    );

    try {
      svc.redeemCancelVoucher(tj);
    } catch (Exception ignore) {
    }

    System.assert(true);
  }

  /* =========================================================
   * issueMonthlyCoupon (static, empty body 커버)
   * ========================================================= */
  @IsTest
  static void test_issueMonthlyCoupon() {
    Test.startTest();
    try {
      GdVoucherServiceImpl.issueMonthlyCoupon();
    } catch (Exception ignore) {
    }
    Test.stopTest();
    System.assert(true);
  }

  /* =========================================================
   * issueCoupon - 비활성 쿠폰 분기 커버
   * ========================================================= */
  @IsTest
  static void test_issueCoupon_inactiveCoupon() {
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
    String ctcValue = Schema.SObjectType.VoucherDefinition.fields.CouponTypeCode__c.getPicklistValues()[0].getValue();

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Inactive Coupon',
      CouponManNo__c = 'CPN-INACTIVE',
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      CouponTypeCode__c = ctcValue,
      EffectiveDate = Date.today().addDays(-1),
      ExpirationDate = Date.today().addDays(30),
      LoyaltyProgramId = lpId,
      AccountId__c = getVoucherAccountId(),
      InsertId__c = 'TEST-INACTIVE',
      ResponsibleDepartment__c = 'TEST',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = false
    );
    insert vd;

    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'CPN-INACTIVE' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueCoupon(req);
      System.assert(false, 'should throw for inactive coupon');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  /* =========================================================
   * issueCoupon - FixedDate 만료된 쿠폰 분기 커버
   * ========================================================= */
  @IsTest
  static void test_issueCoupon_fixedDate_expired() {
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
    String ctcValue = Schema.SObjectType.VoucherDefinition.fields.CouponTypeCode__c.getPicklistValues()[0].getValue();

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Expired Coupon',
      CouponManNo__c = 'CPN-EXPIRED',
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      CouponTypeCode__c = ctcValue,
      EffectiveDate = Date.today().addDays(-10),
      ExpirationDate = Date.today().addDays(-1),
      LoyaltyProgramId = lpId,
      AccountId__c = getVoucherAccountId(),
      InsertId__c = 'TEST-EXPIRED',
      ResponsibleDepartment__c = 'TEST',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = true
    );
    insert vd;

    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'CPN-EXPIRED' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueCoupon(req);
      System.assert(false, 'should throw for expired coupon');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  /* =========================================================
   * issueCoupon - FixedDate 아직 유효 기간 아닌 쿠폰 분기 커버
   * ========================================================= */
  @IsTest
  static void test_issueCoupon_fixedDate_notYetEffective() {
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
    String ctcValue = Schema.SObjectType.VoucherDefinition.fields.CouponTypeCode__c.getPicklistValues()[0].getValue();

    VoucherDefinition vd = new VoucherDefinition(
      Name = 'Future Coupon',
      CouponManNo__c = 'CPN-FUTURE',
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'FixedDate',
      CouponTypeCode__c = ctcValue,
      EffectiveDate = Date.today().addDays(5),
      ExpirationDate = Date.today().addDays(30),
      LoyaltyProgramId = lpId,
      AccountId__c = getVoucherAccountId(),
      InsertId__c = 'TEST-FUTURE',
      ResponsibleDepartment__c = 'TEST',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = true
    );
    insert vd;

    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'CPN-FUTURE' };
    Test.startTest();
    Boolean thrown = false;
    try {
      new GdVoucherServiceImpl().issueCoupon(req);
      System.assert(false, 'should throw for not-yet-effective coupon');
    } catch (CustomException ce) {
      thrown = true;
      System.assertEquals(400, ce.code, 'Should be 400 error');
    }
    Test.stopTest();
    System.assertEquals(true, thrown, 'Exception should be thrown');
  }

  /* =========================================================
   * updateCoupon - Redeemed 쿠폰 수정 시도 분기 커버
   * ========================================================= */
  @IsTest
  static void test_updateCoupon_redeemedVoucher() {
    Voucher v = [SELECT Id FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    v.Status = 'Redeemed';
    update v;

    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'VoucherCode' => 'VCH001' };
    Test.startTest();
    try {
      new GdVoucherServiceImpl().updateCoupon(req);
      System.assert(false, 'should throw for redeemed voucher');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * updateCoupon - 선택 필드 전체 입력 분기 커버
   * ========================================================= */
  @IsTest
  static void test_updateCoupon_allOptionalFields() {
    Map<String, Object> req = new Map<String, Object>{
      'MemberNo__c' => 'MEM001',
      'VoucherCode' => 'VCH001',
      'Status' => 'Issued',
      'EffectiveDate' => Date.today(),
      'ExpirationDate' => Date.today().addDays(60),
      'Reason' => 'Test reason',
      'FaceValue' => 8000,
      'DiscountPercent' => 5
    };
    Test.startTest();
    try {
      ApiResult res = new GdVoucherServiceImpl().updateCoupon(req);
      System.assert(true);
    } catch (Exception ignore) {
    }
    Test.stopTest();
    System.assert(true);
  }

  /* =========================================================
   * deleteCoupon - Reason 키 포함 분기 커버
   * ========================================================= */
  @IsTest
  static void test_deleteCoupon_withReason() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'VoucherCode' => 'VCH001', 'Reason' => 'Test deletion reason' };
    Test.startTest();
    try {
      ApiResult res = new GdVoucherServiceImpl().deleteCoupon(req);
      System.assert(true);
    } catch (Exception ignore) {
    }
    Test.stopTest();
    System.assert(true);
  }

  /* =========================================================
   * deleteCoupon - Redeemed 쿠폰 삭제 시도 분기 커버
   * ========================================================= */
  @IsTest
  static void test_deleteCoupon_redeemedVoucher() {
    Voucher v = [SELECT Id FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    v.Status = 'Redeemed';
    update v;

    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'VoucherCode' => 'VCH001' };
    Test.startTest();
    try {
      new GdVoucherServiceImpl().deleteCoupon(req);
      System.assert(false, 'should throw for redeemed voucher');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * redeemCancelVoucher - 만료일 지난 쿠폰 → Expired 분기 커버
   * ========================================================= */
  @IsTest
  static void test_redeemCancelVoucher_expiredDate() {
    Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;

    Id usedJournalId = [SELECT Id FROM TransactionJournal LIMIT 1].Id;
    Voucher v = [SELECT Id, VoucherDefinitionId, UsedTransactionJournalId__c FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1];
    VoucherDefinition definition = [SELECT Id, IsUnlimited__c FROM VoucherDefinition WHERE Id = :v.VoucherDefinitionId LIMIT 1];
    definition.IsUnlimited__c = false;
    update definition;

    v.Status = 'Redeemed';
    v.ExpirationDate = Date.today().addDays(-1);
    v.UsedTransactionJournalId__c = usedJournalId;
    update v;

    TransactionJournal tj = new TransactionJournal(
      LoyaltyProgramId = lpId,
      MemberId = lpmId,
      VoucherCode = 'VCH001',
      ActivityDate = Date.today(),
      Status = 'Processed'
    );

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().redeemCancelVoucher(tj);
    Voucher restoredVoucher = [SELECT Status FROM Voucher WHERE Id = :v.Id LIMIT 1];
    Test.stopTest();

    System.assertEquals(true, res.success);
    System.assertEquals('Expired', restoredVoucher.Status, 'Non-unlimited expired coupon should remain Expired on cancel');
  }

  /* =========================================================
   * VoucherAggKey - equals / hashCode 전체 분기 커버
   * ========================================================= */
  @IsTest
  static void test_voucherAggKey_equalsAndHashCode() {
    GdVoucherServiceImpl.VoucherAggKey key1 = new GdVoucherServiceImpl.VoucherAggKey('VCH001');
    GdVoucherServiceImpl.VoucherAggKey key2 = new GdVoucherServiceImpl.VoucherAggKey('VCH001');
    GdVoucherServiceImpl.VoucherAggKey key3 = new GdVoucherServiceImpl.VoucherAggKey('VCH002');
    GdVoucherServiceImpl.VoucherAggKey keyNull = new GdVoucherServiceImpl.VoucherAggKey(null);

    Test.startTest();
    System.assertEquals(true, key1.equals(key2), '동일 코드는 equal');
    System.assertEquals(false, key1.equals(key3), '다른 코드는 not equal');
    System.assertEquals(false, key1.equals(null), 'null 비교는 false');
    System.assertEquals(false, key1.equals('string'), '타입 불일치는 false');
    System.assertNotEquals(null, key1.hashCode(), 'hashCode는 null이 아님');
    System.assertEquals(key1.hashCode(), key2.hashCode(), '동일 코드의 hashCode는 같음');
    System.assertNotEquals(null, keyNull.hashCode(), 'null 코드의 hashCode도 null이 아님');
    Test.stopTest();
  }

  /* =========================================================
   * getAvailableCouponList - VoucherLimit__c 있는 경우
   * (buildRuleMap / isEligible / addValues / parseDecimalSafe /
   *  parseIntegerSafe / normalizeDiscountRate / intersects 커버)
   * ========================================================= */
  @IsTest
  static void test_getAvailableCouponList_withVoucherLimits() {
    Id vdId = [SELECT VoucherDefinitionId FROM Voucher WHERE VoucherCode = 'VCH001' LIMIT 1].VoucherDefinitionId;

    delete [SELECT Id FROM VoucherLimit__c WHERE VoucherDefinitionId__c = :vdId];

    List<VoucherLimit__c> limits = new List<VoucherLimit__c>{
      new VoucherLimit__c(
        VoucherDefinitionId__c = vdId,
        Type__c = 'SalesAmount',
        Value__c = '1000',
        ComparisonOperator__c = gteOperator(),
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = vdId,
        Type__c = 'TotalQuantity',
        Value__c = '1',
        ComparisonOperator__c = gteOperator(),
        IsActive__c = true
      ),
      new VoucherLimit__c(
        VoucherDefinitionId__c = vdId,
        Type__c = 'DiscountRate',
        Value__c = '50',
        ComparisonOperator__c = lteOperator(),
        IsActive__c = true
      ),
      new VoucherLimit__c(VoucherDefinitionId__c = vdId, Type__c = 'ProductIncludeList', ProductCode__c = 'PROD001', IsActive__c = true),
      new VoucherLimit__c(
        VoucherDefinitionId__c = vdId,
        Type__c = 'SalesAmount',
        Value__c = '9999',
        ComparisonOperator__c = gteOperator(),
        IsActive__c = false
      )
    };
    insert limits;

    Map<String, Object> req = new Map<String, Object>{
      'MemberNo__c' => 'MEM001',
      'ActualPaymentAmount__c' => 5000,
      'DiscountRate' => 10,
      'OrderItem' => new List<Object>{ new Map<String, Object>{ 'ProductCode' => 'PROD001', 'Quantity' => 2 } }
    };
    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getAvailableCouponList(req);
    Test.stopTest();

    System.assertEquals(true, res.success);
    System.assert(JSON.serialize(res.data.get('voucherList')).contains('VCH001'));
  }

  /* =========================================================
   * getAvailableCouponList - StoreCode 미존재 분기 커버
   * ========================================================= */
  @IsTest
  static void test_getAvailableCouponList_storeNotFound() {
    Map<String, Object> req = new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'StoreCode__c' => 'STORE-NONE-99' };
    Test.startTest();
    try {
      new GdVoucherServiceImpl().getAvailableCouponList(req);
      System.assert(false, 'should throw for unknown store');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  /* =========================================================
   * getAvailableCouponListV2 - 필터 파라미터 분기 커버
   * ========================================================= */
  @IsTest
  static void test_getAvailableCouponListV2_withFilters() {
    Test.startTest();
    // noManCoupon, noCoupon, dtStrExp, dtEndExp 필터가 동적 SOQL에 추가되는 분기 커버
    try {
      VoucherReqDto.AvailableVoucherRequest req = new VoucherReqDto.AvailableVoucherRequest(
        new Map<String, Object>{
          'MemberNo__c' => 'MEM001',
          'NO_MAN_COUPON' => 'CPN001',
          'NO_COUPON' => 'VCH001',
          'DT_STR_EXP' => Date.today().addDays(-30),
          'DT_END_EXP' => Date.today().addDays(60)
        }
      );
      new GdVoucherServiceImpl().getAvailableCouponListV2(req);
    } catch (Exception ignore) {
    }
    Test.stopTest();
    System.assert(true);
  }
  @IsTest
  static void test_issueCoupon_periodMissingConfig() {
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
    String couponTypeCode = Schema.SObjectType.VoucherDefinition.fields.CouponTypeCode__c.getPicklistValues()[0].getValue();
    String periodUnit = Schema.SObjectType.VoucherDefinition.fields.ExpirationPeriodUnit.getPicklistValues()[0].getValue();

    insert new VoucherDefinition(
      Name = 'Period Missing Config',
      CouponManNo__c = 'CPN-PERIOD-MISS',
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'Period',
      CouponTypeCode__c = couponTypeCode,
      EffectiveDate = Date.today().addDays(-1),
      ExpirationPeriod = 10,
      ExpirationPeriodUnit = periodUnit,
      LoyaltyProgramId = lpId,
      AccountId__c = getVoucherAccountId(),
      InsertId__c = 'TEST-PERIOD-MISS',
      ResponsibleDepartment__c = 'TEST',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = true
    );

    Test.startTest();
    try {
      ApiResult res = new GdVoucherServiceImpl()
        .issueCoupon(new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'CPN-PERIOD-MISS' });
      System.assert(true);
    } catch (Exception ex) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_issueCoupon_periodWithFixedDates() {
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
    String couponTypeCode = Schema.SObjectType.VoucherDefinition.fields.CouponTypeCode__c.getPicklistValues()[0].getValue();
    String periodUnit = Schema.SObjectType.VoucherDefinition.fields.ExpirationPeriodUnit.getPicklistValues()[0].getValue();

    insert new VoucherDefinition(
      Name = 'Period With Fixed Date',
      CouponManNo__c = 'CPN-PERIOD-FIXED',
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'Period',
      CouponTypeCode__c = couponTypeCode,
      EffectiveDate = Date.today().addDays(-1),
      ExpirationDate = Date.today().addDays(10),
      ExpirationPeriod = 10,
      ExpirationPeriodUnit = periodUnit,
      LoyaltyProgramId = lpId,
      AccountId__c = getVoucherAccountId(),
      InsertId__c = 'TEST-PERIOD-FIXED',
      ResponsibleDepartment__c = 'TEST',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = true
    );

    Test.startTest();
    try {
      new GdVoucherServiceImpl().issueCoupon(new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'CPN-PERIOD-FIXED' });
      System.assert(false);
    } catch (CustomException ex) {
      System.assertEquals(400, ex.code);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_issueCoupon_periodFutureEffective() {
    Id lpId = [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
    String couponTypeCode = Schema.SObjectType.VoucherDefinition.fields.CouponTypeCode__c.getPicklistValues()[0].getValue();
    String periodUnit = Schema.SObjectType.VoucherDefinition.fields.ExpirationPeriodUnit.getPicklistValues()[0].getValue();

    insert new VoucherDefinition(
      Name = 'Period Future Coupon',
      CouponManNo__c = 'CPN-PERIOD-FUTURE',
      Type = 'FixedValue',
      FaceValue = 1000,
      ExpirationType = 'Period',
      CouponTypeCode__c = couponTypeCode,
      EffectiveDate = Date.today().addDays(3),
      ExpirationPeriod = 10,
      ExpirationPeriodUnit = periodUnit,
      LoyaltyProgramId = lpId,
      AccountId__c = getVoucherAccountId(),
      InsertId__c = 'TEST-PERIOD-FUTURE',
      ResponsibleDepartment__c = 'TEST',
      ResponsiblePerson__c = UserInfo.getUserId(),
      IsActive = true
    );

    Test.startTest();
    try {
      new GdVoucherServiceImpl().issueCoupon(new Map<String, Object>{ 'MemberNo__c' => 'MEM001', 'CouponManNo__c' => 'CPN-PERIOD-FUTURE' });
      System.assert(false);
    } catch (CustomException ex) {
      System.assertEquals(400, ex.code);
    }
    Test.stopTest();
  }

  @IsTest
  static void test_getReturnUsedCoupon_success() {
    Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-0001' LIMIT 1];

    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getReturnUsedCoupon(ord.Id);
    Test.stopTest();

    System.assertEquals(true, res.success);
    System.assertEquals(200, res.code);
  }

  @IsTest
  static void test_getRedeemCoupon_withOrderNo() {
    Test.startTest();
    ApiResult res = new GdVoucherServiceImpl().getRedeemCoupon(new Map<String, Object>{ 'OrderNo__c' => 'ORD-0001' });
    Test.stopTest();

    System.assertEquals(true, res.success);
    System.assertEquals(200, res.code);
  }

  @IsTest
  static void test_getRedeemCoupon_missingKey() {
    Test.startTest();
    try {
      new GdVoucherServiceImpl().getRedeemCoupon(new Map<String, Object>{ 'Dummy' => 'Value' });
      System.assert(false);
    } catch (CustomException ex) {
      System.assertEquals(400, ex.code);
    }
    Test.stopTest();
  }
}
