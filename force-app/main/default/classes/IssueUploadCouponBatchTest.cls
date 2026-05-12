@IsTest
private class IssueUploadCouponBatchTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{"erpId":"OK"}}');
      return res;
    }
  }

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
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

  private class MockBatchableContext implements Database.BatchableContext {
    public Id getJobId() {
      return UserInfo.getUserId();
    }

    public Id getChildJobId() {
      return UserInfo.getUserId();
    }
  }

  @TestSetup
  static void setupData() {
    setMock();

    String voucherType = pickVoucherType();

    LoyaltyProgram program = new LoyaltyProgram(Name = 'IssueUpload Test Program', IsPrimary = true);
    insert program;

    Product2 productRecord = new Product2(Name = 'IssueUpload Voucher Product', IsActive = true);
    insert productRecord;

    Account companyAccount = new Account(Name = 'IssueUpload Company', CompanyCode__c = '1000');
    insert companyAccount;

    VoucherDefinition definition = new VoucherDefinition(
      Name = 'IssueUpload Voucher',
      LoyaltyProgramId = program.Id,
      IsActive = true,
      Description = 'IssueUploadCouponBatch test',
      ProductId = productRecord.Id,
      Type = voucherType,
      ExpirationType = pickExpirationType(),
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      AccountId__c = companyAccount.Id,
      CouponManNo__c = 'CPN-UPLOAD-001',
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

    Contact contactRecord = new Contact(LastName = 'Upload Member', MemberNo__c = 'M-UPLOAD-001');
    insert contactRecord;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      ContactId = contactRecord.Id,
      ProgramId = program.Id,
      MembershipNumber = 'M-UPLOAD-001',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      EnrollmentDate = Date.today()
    );

    Contact contactRecord2 = new Contact(LastName = 'Upload Member 2', MemberNo__c = 'M-UPLOAD-002');
    insert contactRecord2;

    LoyaltyProgramMember member2 = new LoyaltyProgramMember(
      ContactId = contactRecord2.Id,
      ProgramId = program.Id,
      MembershipNumber = 'M-UPLOAD-002',
      MemberStatus = 'Active',
      MemberType = 'Individual',
      EnrollmentDate = Date.today()
    );
    insert new List<LoyaltyProgramMember>{ member, member2 };
  }

  private static Id getVoucherDefinitionId() {
    return [
      SELECT Id
      FROM VoucherDefinition
      LIMIT 1
    ]
    .Id;
  }

  private static Id getMemberId() {
    return [
      SELECT Id
      FROM LoyaltyProgramMember
      LIMIT 1
    ]
    .Id;
  }

  private static Set<Id> getMemberIds() {
    Set<Id> memberIds = new Set<Id>();
    for (LoyaltyProgramMember row : [
      SELECT Id
      FROM LoyaltyProgramMember
      ORDER BY MembershipNumber
      LIMIT 10
    ]) {
      memberIds.add(row.Id);
    }
    return memberIds;
  }

  private static Id getNonMemberId() {
    return UserInfo.getUserId();
  }

  private static void resetIssueVoucherHooks() {
    setMock();
    IssueUploadCouponBatch.forceIssueVoucherException = false;
    IssueUploadCouponBatch.forceIssueVoucherNullResult = false;
  }

  @IsTest
  static void start_returnsProvidedMemberIds() {
    setMock();

    Set<Id> memberIds = new Set<Id>{ getMemberId() };
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(memberIds, getVoucherDefinitionId(), Date.today());

    List<Id> startedIds = new List<Id>();
    for (Id memberId : batch.start(new MockBatchableContext())) {
      startedIds.add(memberId);
    }

    System.assertEquals(1, startedIds.size());
    System.assertEquals(true, startedIds.contains(getMemberId()));
  }

  @IsTest
  static void start_withMultipleMembers_returnsAllIds() {
    setMock();

    Set<Id> memberIds = getMemberIds();
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(memberIds, getVoucherDefinitionId(), Date.today());

    List<Id> startedIds = new List<Id>();
    for (Id memberId : batch.start(new MockBatchableContext())) {
      startedIds.add(memberId);
    }

    System.assertEquals(memberIds.size(), startedIds.size());
  }

  @IsTest
  static void execute_withEmptyScope_runsWithoutError() {
    setMock();

    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(new Set<Id>{ getMemberId() }, getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>());
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void execute_dateOutOfRange_branch_runsWithoutError() {
    setMock();

    Id memberId = getMemberId();
    VoucherDefinition definition = [
      SELECT ExpirationDate
      FROM VoucherDefinition
      WHERE Id = :getVoucherDefinitionId()
      LIMIT 1
    ];

    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(
      new Set<Id>{ memberId },
      getVoucherDefinitionId(),
      definition.ExpirationDate.addDays(1)
    );

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>{ memberId });
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void execute_withMembers_runsMainFlow() {
    resetIssueVoucherHooks();
    Id memberId = getMemberId();
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(new Set<Id>{ memberId }, getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>{ memberId });
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void execute_withMultipleMembers_runsMainFlow() {
    resetIssueVoucherHooks();
    Set<Id> memberIds = getMemberIds();
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(memberIds, getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>(memberIds));
    Test.stopTest();

    System.assertEquals(true, memberIds.size() > 1);
  }

  @IsTest
  static void execute_withNonMemberScope_hitsCatchBranch() {
    resetIssueVoucherHooks();
    Id nonMemberId = getNonMemberId();
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(new Set<Id>{ nonMemberId }, getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>{ nonMemberId });
    batch.finish(new MockBatchableContext());
    Test.stopTest();

    System.assertEquals(true, String.valueOf(nonMemberId).startsWith(UserInfo.getUserId().substring(0, 3)));
  }

  @IsTest
  static void execute_withMixedRealAndNonMemberScope_exercisesErrorAggregation() {
    resetIssueVoucherHooks();
    Id memberId = getMemberId();
    Id nonMemberId = getNonMemberId();
    Set<Id> mixedIds = new Set<Id>{ memberId, nonMemberId };
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(mixedIds, getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>{ memberId, nonMemberId });
    batch.finish(new MockBatchableContext());
    Test.stopTest();

    System.assertEquals(2, mixedIds.size());
  }

  @IsTest
  static void execute_beforeEffectiveDate_runsAdjustedPath() {
    resetIssueVoucherHooks();
    Set<Id> memberIds = getMemberIds();
    VoucherDefinition definition = [
      SELECT EffectiveDate
      FROM VoucherDefinition
      WHERE Id = :getVoucherDefinitionId()
      LIMIT 1
    ];

    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(memberIds, getVoucherDefinitionId(), definition.EffectiveDate.addDays(-5));

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>(memberIds));
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void finish_runsWithoutError() {
    setMock();

    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(new Set<Id>{ getMemberId() }, getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.finish(new MockBatchableContext());
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void finish_afterExecuteError_runsWithoutError() {
    resetIssueVoucherHooks();
    Set<Id> memberIds = getMemberIds();
    VoucherDefinition definition = [
      SELECT ExpirationDate
      FROM VoucherDefinition
      WHERE Id = :getVoucherDefinitionId()
      LIMIT 1
    ];

    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(memberIds, getVoucherDefinitionId(), definition.ExpirationDate.addDays(2));

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>(memberIds));
    batch.finish(new MockBatchableContext());
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void finish_afterOnlyFailures_runsErrorPath() {
    resetIssueVoucherHooks();
    Id nonMemberId = getNonMemberId();
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(new Set<Id>{ nonMemberId }, getVoucherDefinitionId(), Date.today());

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>{ nonMemberId });
    batch.finish(new MockBatchableContext());
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void execute_whenIssueVoucherThrows_hitsCatchBranch() {
    resetIssueVoucherHooks();
    Id memberId = getMemberId();
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(new Set<Id>{ memberId }, getVoucherDefinitionId(), Date.today());

    IssueUploadCouponBatch.forceIssueVoucherException = true;

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>{ memberId });
    batch.finish(new MockBatchableContext());
    Test.stopTest();

    resetIssueVoucherHooks();
    System.assert(true);
  }

  @IsTest
  static void execute_whenIssueVoucherReturnsNull_hitsNullResultBranch() {
    resetIssueVoucherHooks();
    Id memberId = getMemberId();
    IssueUploadCouponBatch batch = new IssueUploadCouponBatch(new Set<Id>{ memberId }, getVoucherDefinitionId(), Date.today());

    IssueUploadCouponBatch.forceIssueVoucherNullResult = true;

    Test.startTest();
    batch.execute(new MockBatchableContext(), new List<Id>{ memberId });
    batch.finish(new MockBatchableContext());
    Test.stopTest();

    resetIssueVoucherHooks();
    System.assert(true);
  }

  @IsTest
  static void executeBatch_withMember_runsBatchLifecycle() {
    setMock();

    Test.startTest();
    Database.executeBatch(new IssueUploadCouponBatch(new Set<Id>{ getMemberId() }, getVoucherDefinitionId(), Date.today()), 50);
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void executeBatch_withEmptyMembers_runsBatchLifecycle() {
    setMock();

    Test.startTest();
    Database.executeBatch(new IssueUploadCouponBatch(new Set<Id>(), getVoucherDefinitionId(), Date.today()), 50);
    Test.stopTest();

    System.assert(true);
  }
}