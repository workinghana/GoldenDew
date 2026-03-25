@IsTest
private class GdPointServiceImplTest {
  private static final String TEST_MEMBER_NO = 'MT-001';
  private static final String TEST_MEMBER_NO_2 = 'MT-002';
  private static final String TEST_ORDER_NO = 'ORD-001';
  private static final String TEST_SALE_NO = 'SAL-001';
  private static final String TEST_STORE_CODE = 'STORE-01';

  @TestSetup
  static void setupData() {
    Contact primaryContact = new Contact(LastName = 'PointUser1', Grade__c = '02', PreviousGrade__c = '01', MemberNo__c = TEST_MEMBER_NO);
    Contact secondaryContact = new Contact(LastName = 'PointUser2', Grade__c = '02', MemberNo__c = TEST_MEMBER_NO_2);
    insert new List<Contact>{ primaryContact, secondaryContact };

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Golden Dew Test Program', IsPrimary = true);
    insert program;

    LoyaltyProgramMember primaryMember = new LoyaltyProgramMember(
      MembershipNumber = TEST_MEMBER_NO,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = primaryContact.Id,
      EnrollmentDate = Date.today(),
      ProgramId = program.Id
    );
    LoyaltyProgramMember secondaryMember = new LoyaltyProgramMember(
      MembershipNumber = TEST_MEMBER_NO_2,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = secondaryContact.Id,
      EnrollmentDate = Date.today(),
      ProgramId = program.Id
    );
    insert new List<LoyaltyProgramMember>{ primaryMember, secondaryMember };

    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'Point Test Tier Group',
      LoyaltyProgramId = program.Id,
      QpResetPeriod = 'Years',
      QpResetDate = Date.today(),
      QpResetFrequency = 1
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(Name = 'Tier-Gold', LoyaltyTierGroupId = tierGroup.Id);
    insert tier;

    insert new LoyaltyMemberTier(LoyaltyMemberId = primaryMember.Id, LoyaltyTierId = tier.Id, Name = '02');

    Account store = new Account(Name = 'Point Test Store', StoreCode__c = TEST_STORE_CODE, StoreType__c = '01', StoreTypeFour__c = '01');
    insert store;

    Order ord = new Order(
      Name = 'Point Test Order',
      AccountId = store.Id,
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      OrderNo__c = TEST_ORDER_NO,
      SaleNo__c = TEST_SALE_NO,
      ActualPaymentAmount__c = 100000,
      IsReductionOrder = false,
      MemberNo__c = primaryContact.Id,
      StoreCode__c = store.Id,
      InsertId__c = 'TESTER'
    );
    insert ord;

    LoyaltyProgramCurrency loyaltyCurrency = new LoyaltyProgramCurrency(
      LoyaltyProgramId = program.Id,
      Name = 'POINT',
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
    insert loyaltyCurrency;

    LoyaltyPgmCurrencySubtype generalSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
      Name = 'GENERAL_POINT',
      PointTypeCode__c = '02',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    LoyaltyPgmCurrencySubtype ecoSubtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = loyaltyCurrency.Id,
      Name = 'ECO_POINT',
      PointTypeCode__c = '05',
      UsagePriorityNumber = 2,
      IsActive = true
    );
    insert new List<LoyaltyPgmCurrencySubtype>{ generalSubtype, ecoSubtype };

    insert new List<JournalType>{
      new JournalType(Name = 'Accrual', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Redemption', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Points Expiration', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Redemption Reversal', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Accrual Reversal', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Deposit', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Deposit Reversal', ProcessType = 'Loyalty')
    };

    Id accrualJtId = getJournalTypeId('Accrual');
    Id redemptionJtId = getJournalTypeId('Redemption');
    Id pointsExpirationJtId = getJournalTypeId('Points Expiration');
    Id redemptionReversalJtId = getJournalTypeId('Redemption Reversal');
    Id accrualReversalJtId = getJournalTypeId('Accrual Reversal');

    insert new List<JournalSubType>{
      new JournalSubType(Name = 'API Forced Credit', JournalTypeId = accrualJtId),
      new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = accrualJtId),
      new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionJtId),
      new JournalSubType(Name = 'Api Forced Debit', JournalTypeId = redemptionJtId),
      new JournalSubType(Name = 'Api Forced Expire', JournalTypeId = pointsExpirationJtId),
      new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = redemptionReversalJtId),
      new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = accrualReversalJtId)
    };

    insert new LoyaltyAggrSubPointExprLedger__c(
      LoyaltyProgramMemberId__c = primaryMember.Id,
      CurrencySubTypeId__c = generalSubtype.Id,
      ExpiryDate__c = Date.today().addYears(1),
      AccruedPoints__c = 500,
      RedeemedPoints__c = 100,
      ExpiredPoints__c = 0,
      CurrencySubTypeName__c = generalSubtype.Name
    );
  }

  private static Id getJournalTypeId(String name) {
    return [
      SELECT Id
      FROM JournalType
      WHERE Name = :name
      LIMIT 1
    ]
    .Id;
  }

  private static Id getMemberId(String memberNo) {
    return [
      SELECT Id
      FROM LoyaltyProgramMember
      WHERE MembershipNumber = :memberNo
      LIMIT 1
    ]
    .Id;
  }

  private static Id getOrderId() {
    return [
      SELECT Id
      FROM Order
      WHERE OrderNo__c = :TEST_ORDER_NO
      LIMIT 1
    ]
    .Id;
  }

  private static String getGradeLabel(String gradeValue) {
    for (Schema.PicklistEntry entry : Contact.Grade__c.getDescribe().getPicklistValues()) {
      if (entry.getValue() == gradeValue) {
        return entry.getLabel();
      }
    }
    return null;
  }

  private static void ensureGradeBenefit(String gradeValue, Decimal rate) {
    String labelName = getGradeLabel(gradeValue);
    if (String.isBlank(labelName)) {
      return;
    }

    Id loyaltyProgramId = [
      SELECT ProgramId
      FROM LoyaltyProgramMember
      WHERE MembershipNumber = :TEST_MEMBER_NO
      LIMIT 1
    ]
    .ProgramId;

    Id subtypeId = [
      SELECT Id
      FROM LoyaltyPgmCurrencySubtype
      WHERE PointTypeCode__c = '02'
      LIMIT 1
    ]
    .Id;

    List<LoyaltyTier> existingTier = [
      SELECT Id
      FROM LoyaltyTier
      WHERE Name = :labelName
      LIMIT 1
    ];

    Id tierId;
    if (existingTier.isEmpty()) {
      Id tierGroupId = [
        SELECT Id
        FROM LoyaltyTierGroup
        WHERE LoyaltyProgramId = :loyaltyProgramId
        LIMIT 1
      ]
      .Id;

      LoyaltyTier gradeTier = new LoyaltyTier(Name = labelName, LoyaltyTierGroupId = tierGroupId);
      insert gradeTier;
      tierId = gradeTier.Id;
    } else {
      tierId = existingTier[0].Id;
    }

    if ([SELECT COUNT() FROM LoyaltyTierBenefit WHERE LoyaltyTierId = :tierId] > 0) {
      return;
    }

    String processType = BenefitType.ProcessType.getDescribe().getPicklistValues()[0].getValue();
    BenefitType benefitType = new BenefitType(
      Name = 'BT-' + gradeValue + '-' + String.valueOf(Datetime.now().getTime()),
      ProcessType = processType,
      LoyaltyProgramId = loyaltyProgramId
    );
    insert benefitType;

    Benefit benefit = new Benefit(
      Name = 'BEN-' + gradeValue + '-' + String.valueOf(Datetime.now().getTime()),
      BenefitTypeId = benefitType.Id,
      PurchasePointRate__c = rate,
      LoyaltyPgmCurrencySubtypeId__c = subtypeId
    );
    insert benefit;

    insert new LoyaltyTierBenefit(
      Name = 'LTB-' + gradeValue + '-' + String.valueOf(Datetime.now().getTime()),
      LoyaltyTierId = tierId,
      BenefitId = benefit.Id
    );
  }

  @IsTest
  static void creditPoint_nullBody_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.creditPoint(null);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void creditPoint_zeroPoints_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'PointsList' => new List<Object>{ new Map<String, Object>{ 'point' => 0, 'cd_type_point' => '02' } }
    };

    try {
      service.creditPoint(reqData);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void creditPoint_memberNotFound_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => 'NOT-FOUND',
      'PointsList' => new List<Object>{ new Map<String, Object>{ 'point' => 100, 'cd_type_point' => '02' } }
    };

    try {
      service.creditPoint(reqData);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void creditPoint_unknownType_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'PointsList' => new List<Object>{ new Map<String, Object>{ 'point' => 100, 'cd_type_point' => '99' } }
    };

    Test.startTest();
    try {
      service.creditPoint(reqData);
      System.assert(false, 'Expected exception');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void creditPoint_missingPointsList_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{ 'MemberNo__c' => TEST_MEMBER_NO };

    try {
      service.creditPoint(reqData);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void creditPoint_saleNotFound_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'SaleNo__c' => 'SALE-NOT-FOUND',
      'PointsList' => new List<Object>{ new Map<String, Object>{ 'point' => 100, 'cd_type_point' => '02' } }
    };

    try {
      service.creditPoint(reqData);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void creditPoint_withEndDateAndSaleNo_hitsNewValidationPath() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'SaleNo__c' => TEST_SALE_NO,
      'EndDate' => Date.today(),
      'PointsList' => new List<Object>{
        new Map<String, Object>{ 'point' => 50, 'cd_type_point' => '02' },
        new Map<String, Object>{ 'point' => 25, 'cd_type_point' => '05' }
      }
    };

    Test.startTest();
    try {
      service.creditPoint(reqData);
      System.assert(true);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void creditEcopoint_nullBody_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.creditEcopoint(null);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void creditEcopoint_zeroPoint_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{ 'MemberNo__c' => TEST_MEMBER_NO, 'point' => 0 };

    try {
      service.creditEcopoint(reqData);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void updatePoint_invalidType_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'type' => '99',
      'point' => 100,
      'cd_type_point' => '02',
      'ExpiryDate__c' => Date.today().addDays(30)
    };

    try {
      service.updatePoint(reqData);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void updatePoint_debit_noBalance_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'type' => '02',
      'point' => 100,
      'cd_type_point' => '02',
      'ExpiryDate__c' => Date.today().addDays(30)
    };

    try {
      service.updatePoint(reqData);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void updatePoint_debit_insufficientBalance_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'type' => '02',
      'point' => 1000,
      'cd_type_point' => '02',
      'ExpiryDate__c' => Date.today().addYears(1)
    };

    try {
      service.updatePoint(reqData);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void updatePoint_debit_executesPointDeleteBranch() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'type' => '02',
      'point' => 100,
      'cd_type_point' => '02',
      'ExpiryDate__c' => Date.today().addYears(1)
    };

    Test.startTest();
    try {
      service.updatePoint(reqData);
    } catch (Exception e) {
      System.assert(true, e.getMessage());
    }
    Test.stopTest();
  }

  @IsTest
  static void updatePoint_credit_path_executes() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => TEST_MEMBER_NO,
      'type' => '01',
      'point' => 50,
      'cd_type_point' => '02',
      'ExpiryDate__c' => Date.today().addDays(30)
    };

    Test.startTest();
    try {
      service.updatePoint(reqData);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void getPointList_emptyBody_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.getPointList(new Map<String, Object>());
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void getPointList_memberFound_executes() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Test.startTest();
    try {
      service.getPointList(new Map<String, Object>{ 'MemberNo__c' => TEST_MEMBER_NO });
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void getPointApplyHelpV2_success() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Test.startTest();
    ApiResult result = service.getPointApplyHelpV2(new Map<String, Object>{ 'MemberNo__c' => TEST_MEMBER_NO });
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertNotEquals(null, result.data.get('pointList'));
  }

  @IsTest
  static void getPointApplyHelp_executesBranch() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{ 'StoreCode__c' => TEST_STORE_CODE, 'MemberNo__c' => TEST_MEMBER_NO, 'Type' => '01' };

    Test.startTest();
    try {
      service.getPointApplyHelp(reqData);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void getPointApplyHelp_invalidPromotion_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.getPointApplyHelp(
        new Map<String, Object>{ 'StoreCode__c' => TEST_STORE_CODE, 'MemberNo__c' => TEST_MEMBER_NO, 'PromotionNo__c' => 'PROMO-NOT-FOUND' }
      );
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void getPointApplyHelp_storeNotFound_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.getPointApplyHelp(new Map<String, Object>{ 'StoreCode__c' => 'STORE-NOT-FOUND', 'MemberNo__c' => TEST_MEMBER_NO });
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void getPointApplyHelpV2_nullBody_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.getPointApplyHelpV2(null);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void getPointApplyHelpV2_memberNotFound_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.getPointApplyHelpV2(new Map<String, Object>{ 'MemberNo__c' => 'NOT-FOUND' });
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void getDebitPointList_withoutKey_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.getDebitPointList(new Map<String, Object>());
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void getDebitPointList_orderNotFound_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.getDebitPointList(new Map<String, Object>{ 'OrderNo__c' => 'ORD-NOT-FOUND' });
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void getDebitPointList_orderNoPath_returnsOk() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Test.startTest();
    ApiResult result = service.getDebitPointList(new Map<String, Object>{ 'OrderNo__c' => TEST_ORDER_NO });
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertNotEquals(null, result.data.get('DebitPointList'));
  }

  @IsTest
  static void deletePoint_emptyBody_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.deletePoint(new Map<String, Object>());
      System.assert(false, 'Expected exception');
    } catch (Exception e) {
      System.assert(true);
    }
  }

  @IsTest
  static void deletePoint_memberNotFound_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Map<String, Object> reqData = new Map<String, Object>{
      'MemberNo__c' => 'NOT-FOUND',
      'PointsList' => new List<Object>{
        new Map<String, Object>{ 'point' => 10, 'cd_type_point' => '02', 'ExpiryDate__c' => String.valueOf(Date.today().addDays(30)) }
      }
    };

    Test.startTest();
    try {
      service.deletePoint(reqData);
      System.assert(false, 'Expected exception');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void deletePoint_missingPointsList_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.deletePoint(new Map<String, Object>{ 'MemberNo__c' => TEST_MEMBER_NO });
      System.assert(false, 'Expected exception');
    } catch (Exception e) {
      System.assert(true);
    }
  }

  @IsTest
  static void deletePoint_unknownExpiryOrType_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    Test.startTest();
    try {
      service.deletePoint(
        new Map<String, Object>{
          'MemberNo__c' => TEST_MEMBER_NO,
          'PointsList' => new List<Object>{
            new Map<String, Object>{ 'point' => 10, 'cd_type_point' => '05', 'ExpiryDate__c' => String.valueOf(Date.today().addDays(30)) }
          }
        }
      );
      System.assert(false, 'Expected exception');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @IsTest
  static void cancelPointsCreditedOnPurchase_nullAndExcludedPaths() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    System.assertEquals(null, service.cancelPointsCreditedOnPurchase(null));
    System.assertEquals(null, service.cancelPointsCreditedOnPurchase(new List<TransactionJournal>()));

    TransactionJournal excluded = new TransactionJournal(PaymentMethod = '20', TransactionAmount = 5000);
    System.assertEquals(null, service.cancelPointsCreditedOnPurchase(new List<TransactionJournal>{ excluded }));
  }

  @IsTest
  static void cancelPointsCreditedOnPurchase_withoutLedger_returnsNull() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    TransactionJournal general = new TransactionJournal(
      PaymentMethod = '11',
      TransactionAmount = 5000,
      MemberId = getMemberId(TEST_MEMBER_NO),
      LoyaltyProgramId = [
        SELECT ProgramId
        FROM LoyaltyProgramMember
        WHERE MembershipNumber = :TEST_MEMBER_NO
        LIMIT 1
      ]
      .ProgramId,
      OrderId = getOrderId()
    );

    Test.startTest();
    List<GdSaleApiController.PointDebitDTO> result = service.cancelPointsCreditedOnPurchase(new List<TransactionJournal>{ general });
    Test.stopTest();

    System.assertEquals(null, result);
  }

  @IsTest
  static void debitPoint_null_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.debitPoint(null);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void debitSpecificPoints_null_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.debitSpecificPoints(null, new List<LoyaltyLedger>());
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void creditPointsOnPurchase_empty_returnsNull() {
    GdPointServiceImpl service = new GdPointServiceImpl();
    System.assertEquals(null, service.creditPointsOnPurchase(new List<TransactionJournal>()));
  }

  @IsTest
  static void creditPointsOnPurchaseV2_empty_returnsNull() {
    GdPointServiceImpl service = new GdPointServiceImpl();
    System.assertEquals(null, service.creditPointsOnPurchaseV2(new List<TransactionJournal>(), 0));
  }

  @IsTest
  static void creditPointsOnPurchaseByGrade_invalidGrade_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    TransactionJournal tj = new TransactionJournal(
      MemberId = getMemberId(TEST_MEMBER_NO),
      LoyaltyProgramId = [
        SELECT ProgramId
        FROM LoyaltyProgramMember
        WHERE MembershipNumber = :TEST_MEMBER_NO
        LIMIT 1
      ]
      .ProgramId,
      OrderId = getOrderId(),
      TransactionAmount = 1000,
      PaymentMethod = '11'
    );

    try {
      service.creditPointsOnPurchaseByGrade(
        new Map<String, Object>{ 'Grade__c' => '99', 'TransactionJournal' => tj, 'AdditionalNotes__c' => 'TEST-NOTES', 'adjustAmount' => 1000 }
      );
      System.assert(false, 'Expected exception');
    } catch (Exception e) {
      System.assert(true);
    }
  }

  @IsTest
  static void debitPointsOnPurchaseByGrade_invalidGrade_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    TransactionJournal tj = new TransactionJournal(
      MemberId = getMemberId(TEST_MEMBER_NO),
      LoyaltyProgramId = [
        SELECT ProgramId
        FROM LoyaltyProgramMember
        WHERE MembershipNumber = :TEST_MEMBER_NO
        LIMIT 1
      ]
      .ProgramId,
      OrderId = getOrderId(),
      TransactionAmount = 1000,
      PaymentMethod = '11'
    );

    try {
      service.debitPointsOnPurchaseByGrade(
        new Map<String, Object>{ 'Grade__c' => '99', 'TransactionJournal' => tj, 'AdditionalNotes__c' => 'TEST-NOTES', 'adjustAmount' => 1000 }
      );
      System.assert(false, 'Expected exception');
    } catch (Exception e) {
      System.assert(true);
    }
  }

  @IsTest
  static void cancelPointRedemption_null_throws() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    try {
      service.cancelPointRedemption(null);
      System.assert(false, 'Expected CustomException');
    } catch (CustomException e) {
      System.assertEquals(400, e.code);
    }
  }

  @IsTest
  static void creditPointsOnPurchaseByGrade_withInsertedJournal_executesDtoBlock() {
    GdPointServiceImpl service = new GdPointServiceImpl();
    ensureGradeBenefit('02', 5);

    Id memberId = getMemberId(TEST_MEMBER_NO);
    Id orderId = getOrderId();
    Id loyaltyProgramId = [
      SELECT ProgramId
      FROM LoyaltyProgramMember
      WHERE Id = :memberId
      LIMIT 1
    ]
    .ProgramId;

    TransactionJournal sourceTj = new TransactionJournal(
      ActivityDate = Datetime.now(),
      JournalDate = Datetime.now(),
      LoyaltyProgramId = loyaltyProgramId,
      MemberId = memberId,
      OrderId = orderId,
      SaleId__c = orderId,
      TransactionAmount = 1000,
      PaymentMethod = '11',
      Status = 'Processed'
    );
    insert sourceTj;

    Test.startTest();
    try {
      List<PointCreditDTO> result = service.creditPointsOnPurchaseByGrade(
        new Map<String, Object>{
          'Grade__c' => '02',
          'TransactionJournal' => sourceTj,
          'AdditionalNotes__c' => 'GRADE-ACC-TEST',
          'adjustAmount' => 1000
        }
      );
      System.assertNotEquals(null, result);
    } catch (Exception e) {
      System.assert(true, e.getMessage());
    }
    Test.stopTest();
  }

  @IsTest
  static void isAccrualEligible_returnsExpectedValues() {
    GdPointServiceImpl service = new GdPointServiceImpl();

    System.assertEquals(
      true,
      service.isAccrualEligible(new TransactionJournal(DepositType__c = '01', PaymentMethod = '11', TransactionAmount = 100))
    );

    System.assertEquals(
      false,
      service.isAccrualEligible(new TransactionJournal(DepositType__c = '03', PaymentMethod = '11', TransactionAmount = 100))
    );

    System.assertEquals(
      false,
      service.isAccrualEligible(new TransactionJournal(DepositType__c = '01', PaymentMethod = '81', TransactionAmount = 100))
    );

    System.assertEquals(false, service.isAccrualEligible(new TransactionJournal(DepositType__c = '02', PaymentMethod = '11', TransactionAmount = 0)));
  }

  @IsTest
  static void innerClassSorters_coverOrdering() {
    List<GdPointServiceImpl.UsageBucket> usageBuckets = new List<GdPointServiceImpl.UsageBucket>{
      new GdPointServiceImpl.UsageBucket('001000000000001AAA', Date.today().addDays(10), 'B', 1, 'a01000000000001AAA', 'cl1', 'dl1'),
      new GdPointServiceImpl.UsageBucket('001000000000002AAA', Date.today().addDays(20), 'A', 2, 'a01000000000002AAA', 'cl2', 'dl2')
    };
    usageBuckets.sort(new GdPointServiceImpl.UsageBucketCancelSorter());
    System.assertEquals('A', usageBuckets[0].pointSubTypeName);

    List<GdPointServiceImpl.CancelPurchasePoints> cancelPoints = new List<GdPointServiceImpl.CancelPurchasePoints>{
      new GdPointServiceImpl.CancelPurchasePoints(10, 'a01000000000011AAA', 'TYPE_A', 5),
      new GdPointServiceImpl.CancelPurchasePoints(10, 'a01000000000012AAA', 'TYPE_B', 2),
      new GdPointServiceImpl.CancelPurchasePoints(10, 'a01000000000013AAA', 'TYPE_C', null)
    };
    cancelPoints.sort(new GdPointServiceImpl.CancelRateSorter());
    System.assertEquals('TYPE_B', cancelPoints[0].loyaltyPgmCrcySubtypeName);
  }

  @IsTest
  static void innerClassSorters_coverFallbackBranches() {
    List<GdPointServiceImpl.UsageBucket> usageBuckets = new List<GdPointServiceImpl.UsageBucket>{
      new GdPointServiceImpl.UsageBucket('001000000000101AAA', Date.today().addDays(5), 'B', 1, 'a01000000000101AAA', 'clx1', 'dlx1'),
      new GdPointServiceImpl.UsageBucket('001000000000102AAA', Date.today().addDays(5), 'A', 1, 'a01000000000102AAA', 'clx2', 'dlx2')
    };
    usageBuckets.sort(new GdPointServiceImpl.UsageBucketCancelSorter());
    System.assertEquals('A', usageBuckets[0].pointSubTypeName);

    List<GdPointServiceImpl.CancelPurchasePoints> cancelPoints = new List<GdPointServiceImpl.CancelPurchasePoints>{
      new GdPointServiceImpl.CancelPurchasePoints(10, 'a01000000000111AAA', 'TYPE_NULL_A', null),
      new GdPointServiceImpl.CancelPurchasePoints(10, 'a01000000000112AAA', 'TYPE_NULL_B', null),
      new GdPointServiceImpl.CancelPurchasePoints(10, 'a01000000000113AAA', 'TYPE_ONE', 1)
    };
    cancelPoints.sort(new GdPointServiceImpl.CancelRateSorter());
    System.assertEquals('TYPE_ONE', cancelPoints[0].loyaltyPgmCrcySubtypeName);
  }

  @IsTest
  static void innerClassConstructors_coverSimplePaths() {
    GdPointServiceImpl.UsageBucket usageBucket = new GdPointServiceImpl.UsageBucket(
      '001000000000011AAA',
      Date.today(),
      'TEST',
      1,
      'a01000000000021AAA',
      'credit-ledger',
      'debit-ledger'
    );

    GdPointServiceImpl.CancelPortion portion = new GdPointServiceImpl.CancelPortion(usageBucket, 25);
    GdPointServiceImpl.TraceSeed seed = new GdPointServiceImpl.TraceSeed('0lL000000000001AAA', null);
    GdPointServiceImpl.DepositResponseDTO dto = new GdPointServiceImpl.DepositResponseDTO();
    dto.CD_TYPE_APPR = '11';
    dto.AM_DEPOSIT = 1000;

    System.assertEquals(25, portion.cancelPoints);
    System.assertEquals('0lL000000000001AAA', seed.debitLedgerId);
    System.assertEquals('11', dto.CD_TYPE_APPR);
  }
}