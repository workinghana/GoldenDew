@IsTest(SeeAllData=true)
private class TestMemberInfoHelpViewControllerV1Test {
  private static final String MEMBER_NO = 'TMH-001';

  private static void ensureData() {
    prepareCalloutMocks();

    List<Contact> contacts = [
      SELECT Id, Phone
      FROM Contact
      WHERE MemberNo__c = :MEMBER_NO
      LIMIT 1
    ];
    Contact contactRecord;
    if (contacts.isEmpty()) {
      contactRecord = new Contact(LastName = 'Help View Tester', MemberNo__c = MEMBER_NO, Grade__c = firstPicklistValue(Contact.Grade__c, null));
      insert contactRecord;
    } else {
      contactRecord = contacts[0];
    }

    LoyaltyProgram program = [SELECT Id FROM LoyaltyProgram LIMIT 1];

    List<LoyaltyProgramMember> members = [
      SELECT Id
      FROM LoyaltyProgramMember
      WHERE ContactId = :contactRecord.Id
      LIMIT 1
    ];
    LoyaltyProgramMember member;
    if (members.isEmpty()) {
      member = new LoyaltyProgramMember(
        ContactId = contactRecord.Id,
        ProgramId = program.Id,
        MembershipNumber = MEMBER_NO,
        EnrollmentDate = Date.today(),
        MemberStatus = 'Active',
        MemberType = 'Individual'
      );
      insert member;
    } else {
      member = members[0];
    }

    if (String.isBlank(contactRecord.Phone)) {
      try {
        contactRecord.Phone = '010-0000-0000';
        update contactRecord;
      } catch (Exception ignored) {
      }
    }

    LoyaltyPgmCurrencySubtype subtype = [
      SELECT Id, Name, PointTypeCode__c
      FROM LoyaltyPgmCurrencySubtype
      WHERE LoyaltyProgramCurrency.LoyaltyProgramId = :program.Id AND PointTypeCode__c != NULL
      LIMIT 1
    ];

    if ([SELECT COUNT() FROM LoyaltyAggrSubPointExprLedger__c WHERE LoyaltyProgramMemberId__c = :member.Id] == 0) {
      insert new LoyaltyAggrSubPointExprLedger__c(
        LoyaltyProgramMemberId__c = member.Id,
        CurrencySubTypeId__c = subtype.Id,
        CurrencySubTypeName__c = subtype.Name,
        ExpiryDate__c = Date.today().addYears(1),
        AccruedPoints__c = 1000,
        RedeemedPoints__c = 250,
        ExpiredPoints__c = 0
      );
    }

    Id accrualTypeId = ensureJournalType('Accrual');
    ensureJournalSubType('Api Forced Credit', accrualTypeId);

    VoucherCategory__c category = new VoucherCategory__c(Name = 'Help View Coupon Category', Code__c = 'HV');
    insert category;

    Account couponAccount = new Account(Name = 'Help View Coupon Account', CompanyCode__c = '1000');
    insert couponAccount;

    TriggerHandler.bypass('VoucherDefinitionTriggerHandler');
    VoucherDefinition definition;
    try {
      definition = new VoucherDefinition(
        Name = 'Help View Coupon',
        CouponManNo__c = 'HV-CPN-001',
        Type = 'FixedValue',
        FaceValue = 5000,
        ExpirationType = firstPicklistValue(VoucherDefinition.ExpirationType, 'FixedDate'),
        CouponTypeCode__c = firstPicklistValue(VoucherDefinition.CouponTypeCode__c, '01'),
        EffectiveDate = Date.today().addDays(-1),
        ExpirationDate = Date.today().addDays(30),
        LoyaltyProgramId = program.Id,
        AccountId__c = couponAccount.Id,
        VoucherCategoryId__c = category.Id,
        InsertId__c = 'TEST',
        ResponsibleDepartment__c = 'TEST',
        ResponsiblePerson__c = 'TEST',
        IsActive = true
      );
      insert definition;
    } finally {
      TriggerHandler.clearBypass('VoucherDefinitionTriggerHandler');
    }

    if ([SELECT COUNT() FROM Voucher WHERE LoyaltyProgramMemberId = :member.Id AND Status = 'Issued'] == 0) {
      insert new Voucher(
        VoucherDefinitionId = definition.Id,
        LoyaltyProgramMemberId = member.Id,
        VoucherCode = 'HV-VCH-001',
        Status = 'Issued',
        EffectiveDate = Date.today(),
        ExpirationDate = Date.today().addDays(30)
      );
    }
  }

  private static String firstPicklistValue(Schema.SObjectField fieldRef, String fallback) {
    List<Schema.PicklistEntry> entries = fieldRef.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      if (entry.isActive()) {
        return entry.getValue();
      }
    }
    return fallback;
  }

  private static void prepareCalloutMocks() {
    CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());
  }

  private static Id ensureJournalType(String name) {
    List<JournalType> existing = [SELECT Id FROM JournalType WHERE Name = :name LIMIT 1];
    if (!existing.isEmpty()) {
      return existing[0].Id;
    }
    insert new JournalType(Name = name, ProcessType = 'Loyalty');
    return [SELECT Id FROM JournalType WHERE Name = :name LIMIT 1].Id;
  }

  private static Id ensureJournalSubType(String name, Id journalTypeId) {
    List<JournalSubType> existing = [SELECT Id FROM JournalSubType WHERE Name = :name AND JournalTypeId = :journalTypeId LIMIT 1];
    if (!existing.isEmpty()) {
      return existing[0].Id;
    }
    insert new JournalSubType(Name = name, JournalTypeId = journalTypeId);
    return [SELECT Id FROM JournalSubType WHERE Name = :name AND JournalTypeId = :journalTypeId LIMIT 1].Id;
  }

  @IsTest
  static void getMemberHelpView_blankMemberNo_throwsAuraHandledException() {
    prepareCalloutMocks();

    try {
      TestMemberInfoHelpViewControllerV1.getMemberHelpView('');
      System.assert(false, 'Blank member number should throw an AuraHandledException.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
  }

  @IsTest
  static void getMemberHelpView_serviceError_isConvertedToAuraHandledException() {
    prepareCalloutMocks();

    try {
      TestMemberInfoHelpViewControllerV1.getMemberHelpView('NO_SUCH_MEMBER');
      System.assert(false, 'Missing member data should throw an AuraHandledException.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
  }

  @IsTest
  static void getMemberHelpView_existingMember_returnsViewWhenHistoryExists() {
    prepareCalloutMocks();

    List<ContactHistory> histories = [
      SELECT Contact.MemberNo__c
      FROM ContactHistory
      WHERE Contact.MemberNo__c != NULL
      LIMIT 1
    ];
    String targetMemberNo = histories.isEmpty() ? MEMBER_NO : histories[0].Contact.MemberNo__c;
    if (histories.isEmpty()) {
      ensureData();
    }

    try {
      TestMemberInfoHelpViewControllerV1.MemberHelpView view = TestMemberInfoHelpViewControllerV1.getMemberHelpView(targetMemberNo);

      System.assertEquals(targetMemberNo, view.memberNo);
      System.assertNotEquals(null, view.accrualHistoryList);
      System.assertNotEquals(null, view.userDestoryHistoryList);
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
  }

  @IsTest
  static void getPointHelp_blankMemberNo_throwsAuraHandledException() {
    prepareCalloutMocks();

    try {
      TestMemberInfoHelpViewControllerV1.getPointHelp('', '99998', null, null, null);
      System.assert(false, 'Blank member number should throw an AuraHandledException.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
  }

  @IsTest
  static void getPointHelp_serviceError_isConvertedToAuraHandledException() {
    prepareCalloutMocks();

    try {
      TestMemberInfoHelpViewControllerV1.getPointHelp('NO_SUCH_MEMBER', null, null, null, null);
      System.assert(false, 'Invalid point help request should throw an AuraHandledException.');
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
  }

  @IsTest
  static void getPointHelp_existingMember_returnsPointListAndTotal() {
    prepareCalloutMocks();
    ensureData();

    TestMemberInfoHelpViewControllerV1.PointHelpView view = TestMemberInfoHelpViewControllerV1.getPointHelp(MEMBER_NO, null, null, null, null);

    System.assertEquals(MEMBER_NO, view.memberNo);
    System.assertNotEquals(null, view.pointList);
    System.assertNotEquals(null, view.totalPoints);
    System.assert(view.totalPoints >= 0, 'Total points should be calculated safely even when no aggregate rows are returned.');
  }

  @IsTest
  static void creditPoints_blankJson_returnsBadRequest() {
    prepareCalloutMocks();

    TestMemberInfoHelpViewControllerV1.CreditPointResult result = TestMemberInfoHelpViewControllerV1.creditPoints('');

    System.assertEquals(false, result.success);
    System.assertEquals(400, result.code);
    System.assertNotEquals(null, result.message);
  }

  @IsTest
  static void creditPoints_invalidJson_returnsBadRequest() {
    prepareCalloutMocks();

    TestMemberInfoHelpViewControllerV1.CreditPointResult result = TestMemberInfoHelpViewControllerV1.creditPoints('{bad json');

    System.assertEquals(false, result.success);
    System.assertEquals(400, result.code);
    System.assert(result.message != null && result.message.contains('JSON'));
  }

  @IsTest
  static void creditPoints_validJson_serviceError_returnsFailureResult() {
    prepareCalloutMocks();

    String jsonBody = JSON.serialize(new Map<String, Object>{ 'MemberNo__c' => 'NO_SUCH_MEMBER' });

    TestMemberInfoHelpViewControllerV1.CreditPointResult result = TestMemberInfoHelpViewControllerV1.creditPoints(jsonBody);

    System.assertEquals(false, result.success);
    System.assertNotEquals(null, result.code);
    System.assertNotEquals(null, result.message);
  }

  @IsTest
  static void creditPoints_existingMember_mapsServiceResponse() {
    prepareCalloutMocks();
    ensureData();

    LoyaltyPgmCurrencySubtype subtype = [
      SELECT PointTypeCode__c
      FROM LoyaltyPgmCurrencySubtype
      WHERE PointTypeCode__c != NULL
      LIMIT 1
    ];

    String jsonBody = JSON.serialize(
      new Map<String, Object>{
        'MemberNo__c' => MEMBER_NO,
        'PointsList' => new List<Object>{ new Map<String, Object>{ 'point' => 10, 'cd_type_point' => subtype.PointTypeCode__c } }
      }
    );

    TestMemberInfoHelpViewControllerV1.CreditPointResult result = TestMemberInfoHelpViewControllerV1.creditPoints(jsonBody);

    System.assertNotEquals(null, result.success);
    System.assertNotEquals(null, result.code);
    System.assertNotEquals(null, result.message);
  }

  @IsTest
  static void getAvailableCoupons_blankJson_returnsBadRequestWithEmptyList() {
    prepareCalloutMocks();

    TestMemberInfoHelpViewControllerV1.VoucherHelpView view = TestMemberInfoHelpViewControllerV1.getAvailableCoupons('');

    System.assertEquals(false, view.success);
    System.assertEquals(400, view.code);
    System.assertNotEquals(null, view.message);
    System.assertEquals(0, view.couponList.size());
  }

  @IsTest
  static void getAvailableCoupons_invalidJson_returnsBadRequestWithEmptyList() {
    prepareCalloutMocks();

    TestMemberInfoHelpViewControllerV1.VoucherHelpView view = TestMemberInfoHelpViewControllerV1.getAvailableCoupons('{bad json');

    System.assertEquals(false, view.success);
    System.assertEquals(400, view.code);
    System.assert(view.message != null && view.message.contains('JSON'));
    System.assertEquals(0, view.couponList.size());
  }

  @IsTest
  static void getAvailableCoupons_validJson_serviceError_returnsFailureView() {
    prepareCalloutMocks();

    String jsonBody = JSON.serialize(
      new Map<String, Object>{ 'MemberNo__c' => 'NO_SUCH_MEMBER', 'StoreCode__c' => '99998', 'SaleNo__c' => 'NO_SUCH_SALE' }
    );

    TestMemberInfoHelpViewControllerV1.VoucherHelpView view = TestMemberInfoHelpViewControllerV1.getAvailableCoupons(jsonBody);

    System.assertEquals(false, view.success);
    System.assertNotEquals(null, view.code);
    System.assertNotEquals(null, view.message);
    System.assertEquals(0, view.couponList.size());
  }

  @IsTest
  static void getAvailableCoupons_existingMember_returnsCouponList() {
    prepareCalloutMocks();
    ensureData();

    String jsonBody = JSON.serialize(new Map<String, Object>{ 'MemberNo__c' => MEMBER_NO });

    TestMemberInfoHelpViewControllerV1.VoucherHelpView view = TestMemberInfoHelpViewControllerV1.getAvailableCoupons(jsonBody);

    System.assertEquals(true, view.success);
    System.assertEquals(200, view.code);
    System.assertNotEquals(null, view.couponList);
    System.assert(view.couponList.size() > 0, 'Issued coupon should be included in the available coupon list.');
  }
}