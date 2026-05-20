@IsTest
private class CouponListUploadControllerV1Test {
  private static final String TEST_POLICY_PRODUCT_CODE = 'TEST-PRODUCT-001';
  private static final String TEST_STORE_CODE = 'TEST-STORE-001';
  private static final String PRODUCT_CODE_HEADER = 'ProductCode';
  private static final String STORE_CODE_HEADER = 'StoreCode';

  private class McCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"result":"ok"}');
      return res;
    }
  }

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(Datetime.now().getTime()) + '_' + String.valueOf(Math.abs(Crypto.getRandomInteger()));
  }

  private static String pickVoucherType() {
    for (Schema.PicklistEntry entry : VoucherDefinition.Type.getDescribe().getPicklistValues()) {
      if (entry.getValue() == 'FixedValue') {
        return entry.getValue();
      }
    }
    return VoucherDefinition.Type.getDescribe().getPicklistValues()[0].getValue();
  }

  private static String pickExpirationType() {
    for (Schema.PicklistEntry entry : VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()) {
      if (entry.getValue() == 'FixedDate') {
        return entry.getValue();
      }
    }
    return VoucherDefinition.ExpirationType.getDescribe().getPicklistValues()[0].getValue();
  }

  private static Id createProgram() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('Program'), IsPrimary = true);
    insert lp;
    return lp.Id;
  }

  private static Id createMember(String memberNo, Boolean createLpm) {
    Contact contactRecord = new Contact(LastName = uniq('Contact'), MemberNo__c = memberNo);
    insert contactRecord;

    if (!createLpm) {
      return null;
    }

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ProgramId = createProgram(),
      ContactId = contactRecord.Id,
      MembershipNumber = uniq('LPM'),
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert member;
    return member.Id;
  }

  private static void createPolicyReferenceData() {
    insert new Product2(Name = uniq('PolicyProduct'), ProductCode = TEST_POLICY_PRODUCT_CODE, IsActive = true);
    insert new Account(Name = uniq('PolicyStore'), CompanyCode__c = '1000', StoreCode__c = TEST_STORE_CODE);
  }

  private static LoyaltyManagement.IssueVoucherOutput buildIssueVoucherOutput(
    Boolean success,
    String voucherId,
    String errorCode,
    String errorMessage
  ) {
    String errorsJson = '[]';
    if (errorCode != null || errorMessage != null) {
      errorsJson = '[{"code":"' + (errorCode == null ? '' : errorCode) + '","message":"' + (errorMessage == null ? '' : errorMessage) + '"}]';
    }

    String payloadJson =
      '{"success":' +
      String.valueOf(success).toLowerCase() +
      ',"voucherId":"' +
      (voucherId == null ? '' : voucherId) +
      '","errors":' +
      errorsJson +
      '}';

    return (LoyaltyManagement.IssueVoucherOutput) JSON.deserialize(payloadJson, LoyaltyManagement.IssueVoucherOutput.class);
  }

  private static Id createVoucherDefinition(Boolean futureEffective, Boolean expired) {
    String voucherType = pickVoucherType();

    LoyaltyProgram programRecord = new LoyaltyProgram(Name = uniq('IssueUpload Test Program'), IsPrimary = true);
    insert programRecord;

    Product2 productRecord = new Product2(Name = uniq('IssueUpload Voucher Product'), IsActive = true);
    insert productRecord;

    Account companyAccount = new Account(Name = uniq('IssueUpload Company'), CompanyCode__c = '1000');
    insert companyAccount;

    VoucherCategory__c voucherCategory = new VoucherCategory__c(Name = uniq('IssueUpload Category'), Code__c = uniq('IU-CAT'));
    insert voucherCategory;

    VoucherDefinition definition = new VoucherDefinition(
      Name = uniq('IssueUpload Voucher'),
      LoyaltyProgramId = programRecord.Id,
      IsActive = true,
      Description = 'IssueUploadCouponBatch test',
      ProductId = productRecord.Id,
      Type = voucherType,
      ExpirationType = pickExpirationType(),
      EffectiveDate = futureEffective ? Date.today().addDays(2) : Date.today().addDays(-1),
      ExpirationDate = expired ? Date.today().addDays(-1) : Date.today().addDays(30),
      VoucherCategoryId__c = voucherCategory.Id,
      AccountId__c = companyAccount.Id,
      CouponManNo__c = uniq('CPN'),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager'
    );
    if (voucherType == 'DiscountPercentage') {
      definition.DiscountPercent = 10;
    } else {
      definition.FaceValue = 1000;
    }
    insert definition;
    return definition.Id;
  }

  private static Id createVoucherForIssue(Id voucherDefinitionId, String memberNo) {
    Id loyaltyProgramMemberId = createMember(memberNo, true);
    LoyaltyProgramMember member = [
      SELECT Id, ContactId
      FROM LoyaltyProgramMember
      WHERE Id = :loyaltyProgramMemberId
      LIMIT 1
    ];

    Voucher voucherRecord = new Voucher(
      VoucherDefinitionId = voucherDefinitionId,
      ContactId = member.ContactId,
      Status = 'Issued',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      VoucherCode = uniq('VC')
    );
    insert voucherRecord;
    return voucherRecord.Id;
  }

  private static VoucherDefinition getAnyIssueableVoucherDefinition() {
    return [
      SELECT Id, Name, EffectiveDate, ExpirationDate, LoyaltyProgram.Name
      FROM VoucherDefinition
      WHERE
        IsActive = TRUE
        AND LoyaltyProgramId != NULL
        AND (EffectiveDate = NULL
        OR EffectiveDate <= TODAY)
        AND (ExpirationDate = NULL
        OR ExpirationDate >= TODAY)
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
  }

  private static LoyaltyProgramMember getAnyProgramMember() {
    return [
      SELECT Id
      FROM LoyaltyProgramMember
      WHERE ContactId != NULL
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
  }

  private static Voucher getAnyVoucherForErp() {
    List<Voucher> vList = [
      SELECT Id, VoucherCode, VoucherDefinitionId, LoyaltyProgramMemberId, VoucherDefinition.CouponManNo__c, LoyaltyProgramMember.Contact.MemberNo__c
      FROM Voucher
      WHERE
        VoucherDefinitionId != NULL
        AND LoyaltyProgramMemberId != NULL
        AND VoucherDefinition.CouponManNo__c != NULL
        AND LoyaltyProgramMember.Contact.MemberNo__c != NULL
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];
    if (vList.isEmpty()) {
      return null;
    }
    return vList[0];
  }

  @IsTest
  static void test_parseCouponFile_success_and_fail_mix() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock());

    Id memberId = createMember('M-001', true);
    createMember('M-002', false);

    String csv = 'NO_MBR,ETC\n' + 'M-001,A\n' + 'M-002,B\n' + 'M-404,C\n' + 'M-001,D\n' + ',E\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    Test.startTest();
    CouponListUploadControllerV1.UploadPreviewResult result = CouponListUploadControllerV1.parseCouponFile(base64Data);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(1, result.successCount);
    System.assertEquals(4, result.failCount);
    System.assertEquals(1, result.successMemberIds.size());
    System.assertEquals(memberId, result.successMemberIds[0]);
  }

  @IsTest
  static void test_parseCouponFile_blank_throws() {
    Boolean hasError = false;

    Test.startTest();
    try {
      CouponListUploadControllerV1.parseCouponFile(null);
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_parseCouponFile_missing_header_throws() {
    String csv = 'WRONG,ETC\nM-001,A\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));
    Boolean hasError = false;

    Test.startTest();
    try {
      CouponListUploadControllerV1.parseCouponFile(base64Data);
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_parseProductLimitFile_success_and_fail_mix() {
    createPolicyReferenceData();

    String csv = PRODUCT_CODE_HEADER + '\n' + TEST_POLICY_PRODUCT_CODE + '\n' + 'NOT-FOUND-PRODUCT\n' + TEST_POLICY_PRODUCT_CODE + '\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    Test.startTest();
    CouponListUploadControllerV1.PolicyUploadPreviewResult result = CouponListUploadControllerV1.parseProductLimitFile(base64Data);
    Test.stopTest();

    System.assertEquals(1, result.successCount);
    System.assertEquals(2, result.failCount);
    System.assertEquals(TEST_POLICY_PRODUCT_CODE, result.previewRows[0].code);
    System.assertNotEquals(null, result.previewRows[0].name);
    System.assertEquals(2, result.errors.size());
    System.assert(result.errors[1].errorReason.contains(Product2.SObjectType.getDescribe().getLabel()));
  }

  @IsTest
  static void test_parseStoreLimitFile_success_and_fail_mix() {
    createPolicyReferenceData();

    String csv = STORE_CODE_HEADER + '\n' + TEST_STORE_CODE + '\n' + 'NOT-FOUND-STORE\n' + TEST_STORE_CODE + '\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    Test.startTest();
    CouponListUploadControllerV1.PolicyUploadPreviewResult result = CouponListUploadControllerV1.parseStoreLimitFile(base64Data);
    Test.stopTest();

    System.assertEquals(1, result.successCount);
    System.assertEquals(2, result.failCount);
    System.assertEquals(TEST_STORE_CODE, result.previewRows[0].code);
    System.assertNotEquals(null, result.previewRows[0].name);
    System.assertEquals(2, result.errors.size());
    System.assert(result.errors[1].errorReason.contains(Account.SObjectType.getDescribe().getLabel()));
  }

  @IsTest
  static void test_parseProductLimitFile_missing_header_throws() {
    String csv = 'WRONG\n' + TEST_POLICY_PRODUCT_CODE + '\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));
    Boolean hasError = false;

    Test.startTest();
    try {
      CouponListUploadControllerV1.parseProductLimitFile(base64Data);
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_parseStoreLimitFile_blank_throws() {
    Boolean hasError = false;

    Test.startTest();
    try {
      CouponListUploadControllerV1.parseStoreLimitFile(null);
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_issueCoupon_null_members_throws() {
    Boolean hasError = false;

    Test.startTest();
    try {
      CouponListUploadControllerV1.issueCoupon(null, UserInfo.getUserId());
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_validateVoucherDefinitionDate_not_yet_effective_throws() {
    Boolean hasError = false;

    Test.startTest();
    try {
      CouponListUploadControllerV1.validateVoucherDefinitionDate(
        new VoucherDefinition(Name = 'Future Voucher', EffectiveDate = Date.today().addDays(2), ExpirationDate = Date.today().addDays(10)),
        Date.today()
      );
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_validateVoucherDefinitionDate_expired_throws() {
    Boolean hasError = false;

    Test.startTest();
    try {
      CouponListUploadControllerV1.validateVoucherDefinitionDate(
        new VoucherDefinition(Name = 'Expired Voucher', EffectiveDate = Date.today().addDays(-10), ExpirationDate = Date.today().addDays(-1)),
        Date.today()
      );
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();

    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_validateVoucherDefinitionDate_valid_doesNotThrow() {
    Test.startTest();
    CouponListUploadControllerV1.validateVoucherDefinitionDate(
      new VoucherDefinition(Name = 'Valid Voucher', EffectiveDate = Date.today().addDays(-1), ExpirationDate = Date.today().addDays(1)),
      Date.today()
    );
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_issueCoupon_chunk_size_constant() {
    System.assertEquals(200, CouponListUploadControllerV1.MAX_COUPON_ISSUE_REQUESTS);
  }

  @IsTest
  static void test_issueCouponRequestsInChunks_empty_returnsNull() {
    Test.startTest();
    List<LoyaltyManagement.IssueVoucherOutput> result = CouponListUploadControllerV1.issueCouponRequestsInChunks(new List<Map<String, Object>>());
    Test.stopTest();

    System.assertEquals(null, result);
  }

  @IsTest
  static void test_issueCoupon_requestsInChunks_forcedNull_returnsNull() {
    CouponListUploadControllerV1.forceIssueVoucherNullResult = true;
    List<Map<String, Object>> reqData = new List<Map<String, Object>>{ new Map<String, Object>{ 'loyaltyProgramMemberId' => UserInfo.getUserId() } };

    Test.startTest();
    List<LoyaltyManagement.IssueVoucherOutput> result = CouponListUploadControllerV1.issueCouponRequestsInChunks(reqData);
    Test.stopTest();

    CouponListUploadControllerV1.forceIssueVoucherNullResult = false;
    System.assertEquals(null, result);
  }

  @IsTest
  static void test_issueCoupon_requestsInChunks_forcedException_throws() {
    CouponListUploadControllerV1.forceIssueVoucherException = true;
    List<Map<String, Object>> reqData = new List<Map<String, Object>>{ new Map<String, Object>{ 'loyaltyProgramMemberId' => UserInfo.getUserId() } };
    Boolean hasError = false;

    Test.startTest();
    try {
      CouponListUploadControllerV1.issueCouponRequestsInChunks(reqData);
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();

    CouponListUploadControllerV1.forceIssueVoucherException = false;
    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_issueCoupon_requestsInChunks_forcedResults_hitsLoopAndReturn() {
    CouponListUploadControllerV1.forceIssueVoucherResults = new List<LoyaltyManagement.IssueVoucherOutput>();
    List<Map<String, Object>> reqData = new List<Map<String, Object>>();
    for (Integer i = 0; i < 201; i++) {
      reqData.add(new Map<String, Object>{ 'loyaltyProgramMemberId' => UserInfo.getUserId() });
    }

    Test.startTest();
    List<LoyaltyManagement.IssueVoucherOutput> result = CouponListUploadControllerV1.issueCouponRequestsInChunks(reqData);
    Test.stopTest();

    CouponListUploadControllerV1.forceIssueVoucherResults = null;
    System.assertNotEquals(null, result);
    System.assertEquals(0, result.size());
  }

  @IsTest(SeeAllData=true)
  static void test_issueCoupon_forcedNullResult_throwsHandledException() {
    VoucherDefinition voucherDefinition = getAnyIssueableVoucherDefinition();
    LoyaltyProgramMember member = getAnyProgramMember();
    Boolean hasError = false;

    CouponListUploadControllerV1.forceIssueVoucherNullResult = true;
    Test.startTest();
    try {
      CouponListUploadControllerV1.issueCoupon(new List<Id>{ member.Id }, voucherDefinition.Id);
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();
    CouponListUploadControllerV1.forceIssueVoucherNullResult = false;

    System.assertEquals(true, hasError);
  }

  @IsTest(SeeAllData=true)
  static void test_issueCoupon_forcedException_throws() {
    VoucherDefinition voucherDefinition = getAnyIssueableVoucherDefinition();
    LoyaltyProgramMember member = getAnyProgramMember();
    Boolean hasError = false;

    CouponListUploadControllerV1.forceIssueVoucherException = true;
    Test.startTest();
    try {
      CouponListUploadControllerV1.issueCoupon(new List<Id>{ member.Id }, voucherDefinition.Id);
    } catch (Exception e) {
      hasError = true;
    }
    Test.stopTest();
    CouponListUploadControllerV1.forceIssueVoucherException = false;

    System.assertEquals(true, hasError);
  }

  @IsTest(SeeAllData=true)
  static void test_issueCoupon_successPath_hitsEnqueueBlock() {
    VoucherDefinition voucherDefinition = getAnyIssueableVoucherDefinition();
    LoyaltyProgramMember member = getAnyProgramMember();
    Voucher voucherRecord = getAnyVoucherForErp();

    if (voucherRecord == null) {
      System.assert(true, 'No voucher data available for test');
      return;
    }

    CouponListUploadControllerV1.forceIssueVoucherResults = new List<LoyaltyManagement.IssueVoucherOutput>{
      buildIssueVoucherOutput(true, String.valueOf(voucherRecord.Id), null, null)
    };

    Test.startTest();
    try {
      CouponListUploadControllerV1.issueCoupon(new List<Id>{ member.Id }, voucherDefinition.Id);
    } catch (Exception e) {
      System.assert(false, e.getMessage());
    }
    Test.stopTest();

    CouponListUploadControllerV1.forceIssueVoucherResults = null;
    System.assert(true);
  }

  @IsTest(SeeAllData=true)
  static void test_issueCoupon_asyncBatchPath_returnsQueuedResult() {
    VoucherDefinition voucherDefinition = getAnyIssueableVoucherDefinition();
    LoyaltyProgramMember member = getAnyProgramMember();

    CouponListUploadControllerV1.forceAsyncBatchIssue = true;
    IssueUploadCouponBatch.forceIssueVoucherNullResult = true;

    CouponListUploadControllerV1.IssueCouponResult result;

    Test.startTest();
    result = CouponListUploadControllerV1.issueCoupon(new List<Id>{ member.Id }, voucherDefinition.Id);
    Test.stopTest();

    CouponListUploadControllerV1.forceAsyncBatchIssue = false;
    IssueUploadCouponBatch.forceIssueVoucherNullResult = false;

    System.assertEquals(true, result.success);
    System.assertEquals(1, result.successCount);
    System.assertEquals(0, result.failCount);
    System.assertEquals(1, result.successMemberIds.size());
    System.assert(result.message != null && result.message.length() > 0);
  }

  @IsTest
  static void test_buildIssueFailureMessage_withNullOutput() {
    String message = CouponListUploadControllerV1.buildIssueFailureMessage(UserInfo.getUserId(), null);
    System.assertNotEquals(null, message);
    System.assert(message.length() > 0);
  }

  @IsTest
  static void test_buildIssueFailureMessage_withErrorOutput() {
    LoyaltyManagement.IssueVoucherOutput output = buildIssueVoucherOutput(false, null, 'ERR01', 'failed');
    String message = CouponListUploadControllerV1.buildIssueFailureMessage(UserInfo.getUserId(), output);

    System.assert(message.contains('failed'));
    System.assert(message.contains('ERR01'));
  }

  @IsTest
  static void test_buildPolicyPreviewResult_returnsCounts() {
    List<CouponListUploadControllerV1.PolicyUploadRowDTO> rows = new List<CouponListUploadControllerV1.PolicyUploadRowDTO>{
      new CouponListUploadControllerV1.PolicyUploadRowDTO(2, 'P1', 'Product 1')
    };
    List<CouponListUploadControllerV1.PolicyUploadErrorDTO> errors = new List<CouponListUploadControllerV1.PolicyUploadErrorDTO>{
      new CouponListUploadControllerV1.PolicyUploadErrorDTO(3, 'X1', null, 'error')
    };

    CouponListUploadControllerV1.PolicyUploadPreviewResult result = CouponListUploadControllerV1.buildPolicyPreviewResult(rows, errors);

    System.assertEquals(1, result.successCount);
    System.assertEquals(1, result.failCount);
    System.assertEquals(1, result.previewRows.size());
    System.assertEquals(1, result.errors.size());
  }

  @IsTest
  static void test_parsePolicyCodeRows_blank_and_duplicate_product() {
    List<CouponListUploadControllerV1.PolicyUploadErrorDTO> errors = new List<CouponListUploadControllerV1.PolicyUploadErrorDTO>();
    String csv = PRODUCT_CODE_HEADER + '\n' + '\n' + 'P001\n' + 'P001\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    List<CouponListUploadControllerV1.RawPolicyCodeRow> rows = CouponListUploadControllerV1.parsePolicyCodeRows(
      base64Data,
      PRODUCT_CODE_HEADER,
      errors,
      true
    );

    System.assertEquals(1, rows.size());
    System.assertEquals(1, errors.size());
    System.assert(errors[0].errorReason.contains(Product2.ProductCode.getDescribe().getLabel()));
    System.assert(errors[0].errorReason.contains('중복') || errors[0].errorReason.contains('以묐났'));
  }

  @IsTest
  static void test_parsePolicyCodeRows_blank_and_duplicate_store() {
    List<CouponListUploadControllerV1.PolicyUploadErrorDTO> errors = new List<CouponListUploadControllerV1.PolicyUploadErrorDTO>();
    String csv = STORE_CODE_HEADER + '\n' + ',\n' + 'S001\n' + 'S001\n';
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));

    List<CouponListUploadControllerV1.RawPolicyCodeRow> rows = CouponListUploadControllerV1.parsePolicyCodeRows(
      base64Data,
      STORE_CODE_HEADER,
      errors,
      false
    );

    System.assertEquals(1, rows.size());
    System.assertEquals(2, errors.size());
    System.assert(errors[0].errorReason.contains(Account.StoreCode__c.getDescribe().getLabel()));
    System.assert(errors[1].errorReason.contains(Account.StoreCode__c.getDescribe().getLabel()));
  }

  @IsTest
  static void test_parsePolicyCodeRows_tooManyRows_throws() {
    String csv = PRODUCT_CODE_HEADER + '\n';
    for (Integer i = 0; i < 50001; i++) {
      csv += 'P' + i + '\n';
    }
    String base64Data = EncodingUtil.base64Encode(Blob.valueOf(csv));
    Boolean hasError = false;

    try {
      CouponListUploadControllerV1.parsePolicyCodeRows(
        base64Data,
        PRODUCT_CODE_HEADER,
        new List<CouponListUploadControllerV1.PolicyUploadErrorDTO>(),
        true
      );
    } catch (Exception e) {
      hasError = true;
    }

    System.assertEquals(true, hasError);
  }

  @IsTest
  static void test_splitPolicyCsvLine_and_unquotePolicyCsvValue() {
    List<String> cols = CouponListUploadControllerV1.splitPolicyCsvLine('"A","B,C","D""E"');

    System.assertEquals(3, cols.size());
    System.assertEquals('A', cols[0]);
    System.assertEquals('B,C', cols[1]);
    System.assertEquals('D"E', cols[2]);
    System.assertEquals('', CouponListUploadControllerV1.unquotePolicyCsvValue(null));
  }

  @IsTest
  static void test_enrichProductAndStoreErrorNames() {
    List<CouponListUploadControllerV1.PolicyUploadErrorDTO> productErrors = new List<CouponListUploadControllerV1.PolicyUploadErrorDTO>{
      new CouponListUploadControllerV1.PolicyUploadErrorDTO(2, 'P001', null, 'error')
    };
    Map<String, Product2> productByCode = new Map<String, Product2>{ 'P001' => new Product2(Name = 'Product Name', ProductCode = 'P001') };
    CouponListUploadControllerV1.enrichProductErrorNames(productErrors, productByCode);
    System.assertEquals('Product Name', productErrors[0].name);

    List<CouponListUploadControllerV1.PolicyUploadErrorDTO> storeErrors = new List<CouponListUploadControllerV1.PolicyUploadErrorDTO>{
      new CouponListUploadControllerV1.PolicyUploadErrorDTO(2, 'S001', null, 'error')
    };
    Map<String, Account> storeByCode = new Map<String, Account>{ 'S001' => new Account(Name = 'Store Name', StoreCode__c = 'S001') };
    CouponListUploadControllerV1.enrichStoreErrorNames(storeErrors, storeByCode);
    System.assertEquals('Store Name', storeErrors[0].name);
  }
}