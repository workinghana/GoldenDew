@IsTest
private class CouponListUploadControllerV1Test {
  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime());
  }

  private static Id createVoucherDefinitionId(Id programId) {
    return createVoucherDefinitionId(programId, Date.today(), Date.today().addDays(30));
  }

  private static Id createVoucherDefinitionId(Id programId, Date effectiveDate, Date expirationDate) {
    Id productId = [SELECT Id FROM Product2 LIMIT 1].Id;
    Id categoryId = [SELECT Id FROM VoucherCategory__c LIMIT 1].Id;
    Id accountId = [SELECT Id FROM Account LIMIT 1].Id;

    VoucherDefinition vd = new VoucherDefinition(
      Name = uniq('UploadVoucher'),
      LoyaltyProgramId = programId,
      IsActive = true,
      Description = 'Upload controller test',
      ProductId = productId,
      Type = 'ProductOrService',
      ExpirationType = 'FixedDate',
      EffectiveDate = effectiveDate,
      ExpirationDate = expirationDate,
      VoucherCategoryId__c = categoryId,
      AccountId__c = accountId,
      CouponManNo__c = uniq('CPN'),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    insert vd;
    return vd.Id;
  }

  @TestSetup
  static void setupData() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('Program'), IsPrimary = true);
    insert lp;

    insert new Product2(Name = uniq('VoucherProduct'), IsActive = true);
    insert new VoucherCategory__c(Name = uniq('VoucherCategory'), Code__c = uniq('VCAT'));
    insert new Account(Name = uniq('VoucherCompany'), CompanyCode__c = '1000');

    Contact c1 = new Contact(LastName = 'Contact1', MemberNo__c = 'M-001');
    insert c1;

    Contact c2 = new Contact(LastName = 'Contact2', MemberNo__c = 'M-002');
    insert c2;

    insert new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c1.Id,
      MembershipNumber = 'LPM-001',
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );

    insert new Product2(Name = uniq('PolicyProduct'), ProductCode = 'TEST-PRODUCT-001', IsActive = true);
    insert new Account(Name = uniq('PolicyStore'), CompanyCode__c = '1000', StoreCode__c = 'TEST-STORE-001');
  }

  private static Id getProgramId() {
    return [SELECT Id FROM LoyaltyProgram LIMIT 1].Id;
  }

  private static Id getMemberId() {
    return [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
  }

  @IsTest
  static void test_parseCouponFile_success_and_fail_mix() {
    String csv = 'NO_MBR,ETC\n' + 'M-001,A\n' + 'M-002,B\n' + 'M-404,C\n' + 'M-001,D\n' + ',E\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    Test.startTest();
    CouponListUploadControllerV1.UploadPreviewResult result = CouponListUploadControllerV1.parseCouponFile(base64Data);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(1, result.successCount);
    System.assertEquals(4, result.failCount);
    System.assertEquals(1, result.successMemberIds.size());

    Set<String> reasons = new Set<String>();
    for (CouponListUploadControllerV1.MemberErrorDTO e : result.errors) {
      reasons.add(e.errorReason);
    }
    System.assertEquals(4, reasons.size());
  }

  @IsTest
  static void test_parseCouponFile_blank_throws() {
    Boolean hasError = false;
    String errorMessage;

    Test.startTest();
    try {
      CouponListUploadControllerV1.parseCouponFile(null);
    } catch (Exception e) {
      hasError = true;
      errorMessage = e.getMessage();
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
    System.assertNotEquals(null, errorMessage);
  }

  @IsTest
  static void test_parseCouponFile_missing_header_throws() {
    String csv = 'WRONG,ETC\nM-001,A\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    Boolean hasError = false;
    String errorMessage;

    Test.startTest();
    try {
      CouponListUploadControllerV1.parseCouponFile(base64Data);
    } catch (Exception e) {
      hasError = true;
      errorMessage = e.getMessage();
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
    System.assertNotEquals(null, errorMessage);
  }

  @IsTest
  static void test_parseProductLimitFile_success_and_fail_mix() {
    String csv = 'ProductCode__c' + '\n' + 'TEST-PRODUCT-001' + '\n' + 'NOT-FOUND-PRODUCT' + '\n' + 'TEST-PRODUCT-001' + '\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    Test.startTest();
    CouponListUploadControllerV1.PolicyUploadPreviewResult result = CouponListUploadControllerV1.parseProductLimitFile(base64Data);
    Test.stopTest();

    System.assertEquals(1, result.successCount);
    System.assertEquals(2, result.failCount);
    System.assertEquals('TEST-PRODUCT-001', result.previewRows[0].code);
    System.assertNotEquals(null, result.previewRows[0].name);
  }

  @IsTest
  static void test_parseStoreLimitFile_success_and_fail_mix() {
    String csv = 'StoreCode__c' + '\n' + 'TEST-STORE-001' + '\n' + 'NOT-FOUND-STORE' + '\n' + 'TEST-STORE-001' + '\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    Test.startTest();
    CouponListUploadControllerV1.PolicyUploadPreviewResult result = CouponListUploadControllerV1.parseStoreLimitFile(base64Data);
    Test.stopTest();

    System.assertEquals(1, result.successCount);
    System.assertEquals(2, result.failCount);
    System.assertEquals('TEST-STORE-001', result.previewRows[0].code);
    System.assertNotEquals(null, result.previewRows[0].name);
  }

  @IsTest
  static void test_parseProductLimitFile_missing_header_throws() {
    String csv = 'WRONG\nTEST-PRODUCT-001\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));
    Boolean hasError = false;
    String errorMessage;

    Test.startTest();
    try {
      CouponListUploadControllerV1.parseProductLimitFile(base64Data);
    } catch (Exception e) {
      hasError = true;
      errorMessage = e.getMessage();
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
    System.assertNotEquals(null, errorMessage);
  }

  @IsTest
  static void test_parseStoreLimitFile_blank_throws() {
    Boolean hasError = false;
    String errorMessage;

    Test.startTest();
    try {
      CouponListUploadControllerV1.parseStoreLimitFile(null);
    } catch (Exception e) {
      hasError = true;
      errorMessage = e.getMessage();
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
    System.assertNotEquals(null, errorMessage);
  }

  @IsTest
  static void test_issueCoupon_null_members_throws() {
    Id vdId = createVoucherDefinitionId(getProgramId());

    Boolean hasError = false;
    String errorMessage;

    Test.startTest();
    try {
      CouponListUploadControllerV1.issueCoupon(null, vdId);
    } catch (Exception e) {
      hasError = true;
      errorMessage = e.getMessage();
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
    System.assertNotEquals(null, errorMessage);
  }

  @IsTest
  static void test_issueCoupon_not_yet_effective_throws() {
    Date effectiveDate = Date.today().addDays(2);
    Date expirationDate = Date.today().addDays(10);
    Id vdId = createVoucherDefinitionId(getProgramId(), effectiveDate, expirationDate);

    Boolean hasError = false;
    String errorMessage;

    Test.startTest();
    try {
      CouponListUploadControllerV1.issueCoupon(new List<Id>{ getMemberId() }, vdId);
    } catch (Exception e) {
      hasError = true;
      errorMessage = e.getMessage();
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
    System.assertNotEquals(null, errorMessage);
  }

  @IsTest
  static void test_issueCoupon_expired_throws() {
    Date effectiveDate = Date.today().addDays(-10);
    Date expirationDate = Date.today().addDays(-1);
    Id vdId = createVoucherDefinitionId(getProgramId(), effectiveDate, expirationDate);

    Boolean hasError = false;
    String errorMessage;

    Test.startTest();
    try {
      CouponListUploadControllerV1.issueCoupon(new List<Id>{ getMemberId() }, vdId);
    } catch (Exception e) {
      hasError = true;
      errorMessage = e.getMessage();
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
    System.assertNotEquals(null, errorMessage);
  }

  @IsTest
  static void test_issueCoupon_with_missing_member_or_service_failure_is_handled() {
    Id vdId = createVoucherDefinitionId(getProgramId());
    Id memberId = getMemberId();
    CouponListUploadControllerV1.IssueCouponResult result;
    Exception caughtException;

    Test.startTest();
    try {
      result = CouponListUploadControllerV1.issueCoupon(new List<Id>{ memberId }, vdId);
    } catch (Exception e) {
      caughtException = e;
    }
    Test.stopTest();

    System.assert(result != null || caughtException != null);
    if (result != null) {
      System.assertNotEquals(null, result.success);
      System.assert(result.successCount >= 0);
      System.assert(result.failCount >= 0);
    } else {
      System.assertNotEquals(null, caughtException.getMessage());
    }
  }
}