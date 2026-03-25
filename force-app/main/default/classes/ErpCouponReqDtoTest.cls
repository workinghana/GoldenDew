@IsTest
private class ErpCouponReqDtoTest {
  @IsTest
  static void opEnum_containsExpectedValues() {
    System.assertEquals('ISSUE_OP', String.valueOf(ErpCouponReqDto.Op.ISSUE_OP));
    System.assertEquals('UPDATE_OP', String.valueOf(ErpCouponReqDto.Op.UPDATE_OP));
  }

  @IsTest
  static void issueRequest_constructor_initializesList() {
    ErpCouponReqDto.IssueRequest req = new ErpCouponReqDto.IssueRequest();

    System.assertNotEquals(null, req);
    System.assertNotEquals(null, req.couponDetailModels);
    System.assertEquals(0, req.couponDetailModels.size());
  }

  @IsTest
  static void couponDetailModel_defaultConstructor_keepsFieldsNull() {
    ErpCouponReqDto.CouponDetailModel model = new ErpCouponReqDto.CouponDetailModel();

    System.assertEquals(null, model.no_man_coupon);
    System.assertEquals(null, model.no_man_coupon_mil);
    System.assertEquals(null, model.no_mbr);
    System.assertEquals(null, model.id_insert);
  }

  @IsTest
  static void couponDetailModel_paramConstructor_mapsAllFields() {
    ErpCouponReqDto.CouponDetailModel model = new ErpCouponReqDto.CouponDetailModel('MAN-001', 'MIL-001', 'MBR-001', 'USER-001');

    System.assertEquals('MAN-001', model.no_man_coupon);
    System.assertEquals('MIL-001', model.no_man_coupon_mil);
    System.assertEquals('MBR-001', model.no_mbr);
    System.assertEquals('USER-001', model.id_insert);
  }

  @IsTest
  static void updateRequest_constructor_initializesList() {
    ErpCouponReqDto.UpdateRequest req = new ErpCouponReqDto.UpdateRequest();

    System.assertNotEquals(null, req);
    System.assertNotEquals(null, req.couponDetailUpdateModels);
    System.assertEquals(0, req.couponDetailUpdateModels.size());
  }

  @IsTest
  static void couponDetailUpdateModel_defaultConstructor_keepsFieldsNull() {
    ErpCouponReqDto.CouponDetailUpdateModel model = new ErpCouponReqDto.CouponDetailUpdateModel();

    System.assertEquals(null, model.no_man_coupon);
    System.assertEquals(null, model.no_mbr);
    System.assertEquals(null, model.no_coupon);
    System.assertEquals(null, model.id_update);
    System.assertEquals(null, model.dt_end_exp_mbr);
    System.assertEquals(null, model.cd_stat_coupon);
  }

  @IsTest
  static void couponDetailUpdateModel_voucherConstructor_mapsExpiredStatus() {
    Voucher voucherRecord = createVoucher('MAN-999', 'MBR-999', 'VOUCHER-001', 'Expired');

    Test.startTest();
    ErpCouponReqDto.CouponDetailUpdateModel model = new ErpCouponReqDto.CouponDetailUpdateModel(voucherRecord);
    Test.stopTest();

    System.assertEquals('MAN-999', model.no_man_coupon);
    System.assertEquals('MBR-999', model.no_mbr);
    System.assertEquals('VOUCHER-001', model.no_coupon);
    System.assertNotEquals(null, model.id_update);
    System.assertEquals(String.valueOf(voucherRecord.ExpirationDate).replaceAll('-', ''), model.dt_end_exp_mbr);
    System.assertEquals('03', model.cd_stat_coupon);
  }

  @IsTest
  static void couponDetailUpdateModel_voucherConstructor_mapsUnknownStatusToBlank() {
    Voucher voucherRecord = createVoucher('MAN-888', 'MBR-888', 'VOUCHER-002', 'Issued');

    Test.startTest();
    ErpCouponReqDto.CouponDetailUpdateModel model = new ErpCouponReqDto.CouponDetailUpdateModel(voucherRecord);
    Test.stopTest();

    System.assertEquals('MAN-888', model.no_man_coupon);
    System.assertEquals('MBR-888', model.no_mbr);
    System.assertEquals('VOUCHER-002', model.no_coupon);
    System.assertEquals('', model.cd_stat_coupon);
  }

  @IsTest
  static void couponDetailUpdateModel_voucherConstructor_mapsUnmappedStatusToBlank_secondCase() {
    Voucher voucherRecord = createVoucher('MAN-777', 'MBR-777', 'VOUCHER-003', 'Redeemed');

    Test.startTest();
    ErpCouponReqDto.CouponDetailUpdateModel model = new ErpCouponReqDto.CouponDetailUpdateModel(voucherRecord);
    Test.stopTest();

    System.assertEquals('MAN-777', model.no_man_coupon);
    System.assertEquals('MBR-777', model.no_mbr);
    System.assertEquals('VOUCHER-003', model.no_coupon);
    System.assertEquals('', model.cd_stat_coupon);
  }

  private static Voucher createVoucher(String couponManNo, String memberNo, String voucherCode, String statusValue) {
    LoyaltyProgram program = new LoyaltyProgram(Name = 'Program ' + voucherCode, IsPrimary = true);
    insert program;

    Product2 productRecord = new Product2(Name = 'Product ' + voucherCode, IsActive = true);
    insert productRecord;

    Account companyAccount = new Account(Name = 'Company ' + voucherCode, CompanyCode__c = '1000');
    insert companyAccount;

    VoucherDefinition definition = new VoucherDefinition(
      Name = 'Test Coupon ' + voucherCode,
      LoyaltyProgramId = program.Id,
      IsActive = true,
      ProductId = productRecord.Id,
      ExpirationType = 'FixedDate',
      ExpirationDate = Date.today().addDays(30),
      EffectiveDate = Date.today(),
      Type = 'ProductOrService',
      AccountId__c = companyAccount.Id,
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert definition;
    definition.CouponManNo__c = couponManNo;
    update definition;

    Account accountRecord = new Account(Name = 'Account ' + voucherCode);
    insert accountRecord;

    Contact contactRecord = new Contact(FirstName = 'Test', LastName = 'Contact ' + voucherCode, AccountId = accountRecord.Id);
    insert contactRecord;
    contactRecord.MemberNo__c = memberNo;
    update contactRecord;

    Voucher voucherRecord = new Voucher(
      VoucherDefinitionId = definition.Id,
      ContactId = contactRecord.Id,
      VoucherCode = voucherCode,
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      Status = statusValue
    );
    insert voucherRecord;

    return [
      SELECT Id, VoucherCode, ExpirationDate, Status, VoucherDefinition.CouponManNo__c, Contact.MemberNo__c
      FROM Voucher
      WHERE Id = :voucherRecord.Id
    ];
  }
}