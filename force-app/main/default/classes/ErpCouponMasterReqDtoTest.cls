@IsTest
private class ErpCouponMasterReqDtoTest {

  /* =====================================================
   * 공통 헬퍼 : Account + LoyaltyProgram + VoucherDefinition 생성
   * ===================================================== */
  private static Account buildAccount() {
    Account acc = new Account(Name = 'TestCo_ECMRD', CompanyCode__c = 'TC01');
    insert acc;
    return acc;
  }

  private static LoyaltyProgram buildLoyaltyProgram() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'TestLP_ECMRD', IsPrimary = false);
    insert lp;
    return lp;
  }

  private static VoucherDefinition buildAndInsertVd(Id lpId, Id accId, String expirationType) {
    VoucherDefinition vd = new VoucherDefinition();
    vd.Name = 'TestVD_ECMRD';
    vd.Type = 'FixedValue';
    vd.FaceValue = 10000;
    vd.EffectiveDate = Date.today();
    vd.ExpirationDate = Date.today().addDays(365);
    vd.ExpirationType = expirationType;
    vd.IsActive = true;
    vd.LoyaltyProgramId = lpId;
    vd.CouponTypeCode__c = VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue();
    vd.CouponManNo__c = 'MAN-001';
    vd.InsertId__c = 'tester';
    vd.ResponsibleDepartment__c = 'IT';
    vd.ResponsiblePerson__c = UserInfo.getUserId();
    vd.brand__c = VoucherDefinition.brand__c.getDescribe().getPicklistValues()[0].getValue();
    vd.Description = 'Test description';
    // Period 만료 타입은 ExpirationPeriodUnit + ExpirationPeriod 필수
    if (expirationType == 'Period') {
      List<Schema.PicklistEntry> units = VoucherDefinition.ExpirationPeriodUnit.getDescribe().getPicklistValues();
      if (!units.isEmpty()) {
        vd.ExpirationPeriodUnit = units[0].getValue();
      }
      vd.ExpirationPeriod = 12;
    }
    if (accId != null) {
      vd.AccountId__c = accId;
    }
    insert vd;
    return vd;
  }

  /* =====================================================
   * ErpCouponMasterReqDto 외부 클래스 기본 생성자
   * ===================================================== */
  @IsTest
  static void test_outerClass_defaultConstructor() {
    ErpCouponMasterReqDto dto = new ErpCouponMasterReqDto();
    System.assertNotEquals(null, dto, 'ErpCouponMasterReqDto 생성 성공');
  }

  /* =====================================================
   * IssueRequest - 기본 생성자 + 필드 직접 할당
   * ===================================================== */
  @IsTest
  static void test_issueRequest_defaultConstructor_fieldAssignment() {
    ErpCouponMasterReqDto.IssueRequest req = new ErpCouponMasterReqDto.IssueRequest();
    req.cd_company      = 'TC01';
    req.no_man_coupon   = 'MAN-001';
    req.nm_coupon       = '테스트쿠폰';
    req.cd_brand        = 'GD';
    req.cd_type_coupon  = '01';
    req.dt_issue        = '20260101';
    req.no_str_coupon   = 'C0001';
    req.no_end_coupon   = 'C9999';
    req.cd_type_day_exp = '01';
    req.dt_str_exp      = '20260101';
    req.dt_end_exp      = '20261231';
    req.ds_mon_exp      = '12';
    req.tx_coupon       = '비고 내용';
    req.rt_disc         = 10;
    req.am_disc         = 5000;
    req.cd_dept         = 'IT';
    req.id_respon       = 'RESPON01';
    req.id_insert       = 'tester';

    System.assertEquals('TC01',    req.cd_company);
    System.assertEquals('MAN-001', req.no_man_coupon);
    System.assertEquals('테스트쿠폰', req.nm_coupon);
    System.assertEquals('GD',      req.cd_brand);
    System.assertEquals(10,        req.rt_disc);
    System.assertEquals(5000,      req.am_disc);
  }

  /* =====================================================
   * DeleteRequest - 기본 생성자 + 필드 직접 할당
   * ===================================================== */
  @IsTest
  static void test_deleteRequest_defaultConstructor_fieldAssignment() {
    ErpCouponMasterReqDto.DeleteRequest req = new ErpCouponMasterReqDto.DeleteRequest();
    req.no_man_coupon = 'MAN-DEL-001';
    req.id_delete     = 'deleter01';

    System.assertEquals('MAN-DEL-001', req.no_man_coupon);
    System.assertEquals('deleter01',   req.id_delete);
  }

  /* =====================================================
   * UpdateRequest - 기본 생성자 + 필드 직접 할당
   * ===================================================== */
  @IsTest
  static void test_updateRequest_defaultConstructor_fieldAssignment() {
    ErpCouponMasterReqDto.UpdateRequest req = new ErpCouponMasterReqDto.UpdateRequest();
    req.cd_company      = 'TC01';
    req.no_man_coupon   = 'MAN-UPD-001';
    req.nm_coupon       = '수정쿠폰';
    req.cd_brand        = 'GD';
    req.cd_type_coupon  = '02';
    req.dt_issue        = '20260201';
    req.no_str_coupon   = 'U0001';
    req.no_end_coupon   = 'U9999';
    req.cd_type_day_exp = '02';
    req.dt_str_exp      = '20260201';
    req.dt_end_exp      = '20261231';
    req.ds_mon_exp      = '6';
    req.tx_coupon       = '수정 비고';
    req.rt_disc         = 0;
    req.am_disc         = 3000;
    req.cd_dept         = 'SALES';
    req.id_respon       = 'RESPON02';
    req.id_insert       = 'updater';

    System.assertEquals('TC01',        req.cd_company);
    System.assertEquals('MAN-UPD-001', req.no_man_coupon);
    System.assertEquals(3000,          req.am_disc);
  }

  /* =====================================================
   * IssueRequest(VoucherDefinition) - VD 기반 생성자 + mapExpirationType 커버
   * : ExpirationType = 'Period' → cd_type_day_exp = '01'
   * ===================================================== */
  @IsTest
  static void test_issueRequest_vd_expirationTypePeriod() {
    Account acc = buildAccount();
    LoyaltyProgram lp = buildLoyaltyProgram();

    String etPeriod = null;
    for (Schema.PicklistEntry pe : VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()) {
      if (pe.getValue() == 'Period') { etPeriod = 'Period'; break; }
    }
    if (etPeriod == null) {
      etPeriod = VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue();
    }

    String expectedBrand = VoucherDefinition.brand__c.getDescribe().getPicklistValues()[0].getValue();
    VoucherDefinition vd = buildAndInsertVd(lp.Id, acc.Id, etPeriod);

    VoucherDefinition vdWithRel = [
      SELECT Id, Name, CouponManNo__c, brand__c, CouponTypeCode__c, CreatedDate,
             CodePrefix, CodeSuffix, ExpirationType, EffectiveDate, ExpirationDate,
             ExpirationPeriod, Description, DiscountPercent, FaceValue,
             ResponsibleDepartment__c, ResponsiblePerson__c, InsertId__c,
             AccountId__r.CompanyCode__c
      FROM VoucherDefinition WHERE Id = :vd.Id LIMIT 1
    ];

    Test.startTest();
    ErpCouponMasterReqDto.IssueRequest req = new ErpCouponMasterReqDto.IssueRequest(vdWithRel);
    Test.stopTest();

    System.assertNotEquals(null, req, 'IssueRequest(VD) 생성 성공');
    System.assertEquals(expectedBrand, req.cd_brand,  'cd_brand 매핑');
    System.assertEquals('tester',      req.id_insert, 'id_insert 매핑');
    System.assertEquals(0,             req.rt_disc,   'rt_disc 매핑 (DiscountPercent null → 0)');
  }

  /* =====================================================
   * IssueRequest(VD) - ExpirationType = 'FixedDate' → '02'
   * ===================================================== */
  @IsTest
  static void test_issueRequest_vd_expirationTypeFixedDate() {
    Account acc = buildAccount();
    LoyaltyProgram lp = buildLoyaltyProgram();

    String etFixed = null;
    for (Schema.PicklistEntry pe : VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()) {
      if (pe.getValue() == 'FixedDate') { etFixed = 'FixedDate'; break; }
    }
    if (etFixed == null) {
      // FixedDate 픽리스트가 없으면 첫 번째 값으로 fallback
      etFixed = VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue();
    }

    VoucherDefinition vd = buildAndInsertVd(lp.Id, acc.Id, etFixed);
    VoucherDefinition vdWithRel = [
      SELECT Id, Name, CouponManNo__c, brand__c, CouponTypeCode__c, CreatedDate,
             CodePrefix, CodeSuffix, ExpirationType, EffectiveDate, ExpirationDate,
             ExpirationPeriod, Description, DiscountPercent, FaceValue,
             ResponsibleDepartment__c, ResponsiblePerson__c, InsertId__c,
             AccountId__r.CompanyCode__c
      FROM VoucherDefinition WHERE Id = :vd.Id LIMIT 1
    ];

    Test.startTest();
    ErpCouponMasterReqDto.IssueRequest req = new ErpCouponMasterReqDto.IssueRequest(vdWithRel);
    Test.stopTest();

    System.assertNotEquals(null, req, 'IssueRequest(VD, FixedDate) 생성 성공');
  }

  /* =====================================================
   * IssueRequest(VD) - nullable 필드 분기 커버
   * brand__c=null, CodePrefix=null, CodeSuffix=null,
   * EffectiveDate=null, ExpirationDate=null, ExpirationPeriod=null,
   * Description=null, DiscountPercent=null, FaceValue=null
   * ===================================================== */
  @IsTest
  static void test_issueRequest_vd_nullableFields() {
    Account acc = buildAccount();
    LoyaltyProgram lp = buildLoyaltyProgram();

    // brand__c=null, Description=null, DiscountPercent=null 분기 커버
    // 날짜 필드는 org 검증 규칙에 따라 필수이므로 유효한 값으로 설정
    VoucherDefinition vd = buildAndInsertVd(lp.Id, acc.Id,
      VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue());

    // brand / Description / DiscountPercent 를 null 로 업데이트
    vd.brand__c    = null;
    vd.Description = null;
    update vd;

    VoucherDefinition vdWithRel = [
      SELECT Id, Name, CouponManNo__c, brand__c, CouponTypeCode__c, CreatedDate,
             CodePrefix, CodeSuffix, ExpirationType, EffectiveDate, ExpirationDate,
             ExpirationPeriod, Description, DiscountPercent, FaceValue,
             ResponsibleDepartment__c, ResponsiblePerson__c, InsertId__c,
             AccountId__r.CompanyCode__c
      FROM VoucherDefinition WHERE Id = :vd.Id LIMIT 1
    ];

    Test.startTest();
    ErpCouponMasterReqDto.IssueRequest req = new ErpCouponMasterReqDto.IssueRequest(vdWithRel);
    Test.stopTest();

    System.assertEquals('', req.cd_brand,  'brand null → 빈 문자열');
    System.assertEquals('', req.tx_coupon, 'Description null → 빈 문자열');
    System.assertEquals(0,  req.rt_disc,   'DiscountPercent null → 0');
    System.assertNotEquals(null, req.am_disc, 'am_disc 매핑됨');
  }

  /* =====================================================
   * DeleteRequest(VoucherDefinition) - VD 기반 생성자
   * ===================================================== */
  @IsTest
  static void test_deleteRequest_vd_constructor() {
    LoyaltyProgram lp = buildLoyaltyProgram();
    String etValue = VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue();
    VoucherDefinition vd = buildAndInsertVd(lp.Id, null, etValue);

    Test.startTest();
    ErpCouponMasterReqDto.DeleteRequest req = new ErpCouponMasterReqDto.DeleteRequest(vd);
    Test.stopTest();

    System.assertEquals('MAN-001', req.no_man_coupon, 'no_man_coupon 매핑');
    System.assertNotEquals(null,   req.id_delete,     'id_delete(userId) 세팅');
  }

  /* =====================================================
   * UpdateRequest(VoucherDefinition) - VD 기반 생성자
   * ===================================================== */
  @IsTest
  static void test_updateRequest_vd_constructor() {
    Account acc = buildAccount();
    LoyaltyProgram lp = buildLoyaltyProgram();
    String etValue = VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue();
    VoucherDefinition vd = buildAndInsertVd(lp.Id, acc.Id, etValue);

    VoucherDefinition vdWithRel = [
      SELECT Id, Name, CouponManNo__c, brand__c, CouponTypeCode__c, CreatedDate,
             CodePrefix, CodeSuffix, ExpirationType, EffectiveDate, ExpirationDate,
             ExpirationPeriod, Description, DiscountPercent, FaceValue,
             ResponsibleDepartment__c, ResponsiblePerson__c, InsertId__c,
             AccountId__r.CompanyCode__c
      FROM VoucherDefinition WHERE Id = :vd.Id LIMIT 1
    ];

    Test.startTest();
    ErpCouponMasterReqDto.UpdateRequest req = new ErpCouponMasterReqDto.UpdateRequest(vdWithRel);
    Test.stopTest();

    System.assertNotEquals(null, req,            'UpdateRequest(VD) 생성 성공');
    System.assertEquals('MAN-001', req.no_man_coupon, 'no_man_coupon 매핑');
    System.assertEquals('tester',  req.id_insert,     'id_insert 매핑');
  }
}