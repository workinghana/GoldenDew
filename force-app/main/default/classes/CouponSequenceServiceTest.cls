@IsTest
private class CouponSequenceServiceTest {
  private static String expectedMonthCode(Integer monthNumber) {
    Map<Integer, String> monthMap = new Map<Integer, String>{
      1 => 'JA',
      2 => 'FE',
      3 => 'MA',
      4 => 'AP',
      5 => 'MY',
      6 => 'JN',
      7 => 'JL',
      8 => 'AU',
      9 => 'SE',
      10 => 'OC',
      11 => 'NO',
      12 => 'DE'
    };
    return monthMap.get(monthNumber);
  }

  private static String expectedKey() {
    Date baseDate = Date.today();
    return 'COP-' + String.valueOf(baseDate.year()) + '-' + expectedMonthCode(baseDate.month());
  }

  private static String expectedCodePrefix() {
    Date baseDate = Date.today();
    return 'COP' + String.valueOf(baseDate.year()) + expectedMonthCode(baseDate.month());
  }

  private static VoucherDefinition createBareVoucherDefinition(String nameValue) {
    VoucherDefinition voucherDefinitionRecord = new VoucherDefinition();
    voucherDefinitionRecord.Name = nameValue;
    return voucherDefinitionRecord;
  }

  private static VoucherDefinition createInsertableVoucherDefinition(String nameValue) {
    LoyaltyProgram loyaltyProgramRecord = [SELECT Id FROM LoyaltyProgram LIMIT 1];
    Product2 productRecord = [SELECT Id FROM Product2 LIMIT 1];
    VoucherCategory__c voucherCategoryRecord = [SELECT Id FROM VoucherCategory__c LIMIT 1];
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];

    return new VoucherDefinition(
      Name = nameValue,
      LoyaltyProgramId = loyaltyProgramRecord.Id,
      ProductId = productRecord.Id,
      VoucherCategoryId__c = voucherCategoryRecord.Id,
      AccountId__c = accountRecord.Id,
      Type = 'ProductOrService',
      ExpirationType = 'FixedDate',
      EffectiveDate = Date.today(),
      ExpirationDate = Date.today().addDays(30),
      CouponTypeCode__c = '01',
      ResponsibleDepartment__c = 'Marketing',
      InsertId__c = 'TestUser',
      ResponsiblePerson__c = 'Manager',
      IsActive = true
    );
  }

  @TestSetup
  static void setupData() {
    insert new LoyaltyProgram(Name = 'Coupon Seq Program');
    insert new Product2(Name = 'Coupon Seq Product', IsActive = true);
    insert new VoucherCategory__c(Name = 'Coupon Seq Category', Code__c = 'SEQ');
    insert new Account(Name = 'Coupon Seq Account', CompanyCode__c = '1000');
  }

  @IsTest
  static void assignCouponCodes_emptyInputs_doNothing() {
    Test.startTest();
    CouponSequenceService.assignCouponCodes(null);
    CouponSequenceService.assignCouponCodes(new List<VoucherDefinition>());
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM SequenceControl__c]);
  }

  @IsTest
  static void assignCouponCodes_singleRecord_assignsFirstSequence() {
    VoucherDefinition voucherDefinitionRecord = createBareVoucherDefinition('Single Coupon');

    Test.startTest();
    CouponSequenceService.assignCouponCodes(new List<VoucherDefinition>{ voucherDefinitionRecord });
    Test.stopTest();

    SequenceControl__c sequenceRecord = [
      SELECT Key__c, LastSeq__c
      FROM SequenceControl__c
      WHERE Key__c = :expectedKey()
      LIMIT 1
    ];

    System.assert(voucherDefinitionRecord.CouponManNo__c.startsWith(expectedCodePrefix()));
    System.assert(voucherDefinitionRecord.CouponManNo__c.endsWith('0001'));
    System.assertEquals(expectedKey(), sequenceRecord.Key__c);
    System.assertEquals(1, Integer.valueOf(sequenceRecord.LastSeq__c));
  }

  @IsTest
  static void assignCouponCodes_bulkRecords_assignsUniqueSequences() {
    List<VoucherDefinition> voucherDefinitionList = new List<VoucherDefinition>{
      createBareVoucherDefinition('Bulk Coupon 1'),
      createBareVoucherDefinition('Bulk Coupon 2'),
      createBareVoucherDefinition('Bulk Coupon 3')
    };

    Test.startTest();
    CouponSequenceService.assignCouponCodes(voucherDefinitionList);
    Test.stopTest();

    Set<String> couponManNoSet = new Set<String>();
    for (VoucherDefinition voucherDefinitionRecord : voucherDefinitionList) {
      System.assert(voucherDefinitionRecord.CouponManNo__c.startsWith(expectedCodePrefix()));
      couponManNoSet.add(voucherDefinitionRecord.CouponManNo__c);
    }

    SequenceControl__c sequenceRecord = [
      SELECT LastSeq__c
      FROM SequenceControl__c
      WHERE Key__c = :expectedKey()
      LIMIT 1
    ];

    System.assertEquals(3, couponManNoSet.size());
    System.assertEquals(3, Integer.valueOf(sequenceRecord.LastSeq__c));
  }

  @IsTest
  static void assignCouponCodes_existingManualValue_isPreserved() {
    VoucherDefinition manualVoucherDefinition = createBareVoucherDefinition('Manual Coupon');
    manualVoucherDefinition.CouponManNo__c = 'MANUAL-CODE-0001';

    Test.startTest();
    CouponSequenceService.assignCouponCodes(new List<VoucherDefinition>{ manualVoucherDefinition });
    Test.stopTest();

    System.assertEquals('MANUAL-CODE-0001', manualVoucherDefinition.CouponManNo__c);
    System.assertEquals(0, [SELECT COUNT() FROM SequenceControl__c]);
  }

  @IsTest
  static void assignCouponCodes_mixedManualAndBlank_onlyBlankIsAssigned() {
    VoucherDefinition manualVoucherDefinition = createBareVoucherDefinition('Manual Coupon');
    manualVoucherDefinition.CouponManNo__c = 'MANUAL-CODE-0002';
    VoucherDefinition blankVoucherDefinition = createBareVoucherDefinition('Blank Coupon');

    Test.startTest();
    CouponSequenceService.assignCouponCodes(new List<VoucherDefinition>{ manualVoucherDefinition, blankVoucherDefinition });
    Test.stopTest();

    SequenceControl__c sequenceRecord = [
      SELECT LastSeq__c
      FROM SequenceControl__c
      WHERE Key__c = :expectedKey()
      LIMIT 1
    ];

    System.assertEquals('MANUAL-CODE-0002', manualVoucherDefinition.CouponManNo__c);
    System.assert(blankVoucherDefinition.CouponManNo__c.startsWith(expectedCodePrefix()));
    System.assertEquals(1, Integer.valueOf(sequenceRecord.LastSeq__c));
  }

  @IsTest
  static void assignCouponCodes_existingSequence_continuesFromLastNumber() {
    insert new SequenceControl__c(Key__c = expectedKey(), LastSeq__c = 5);

    VoucherDefinition firstVoucherDefinition = createBareVoucherDefinition('Next Coupon 1');
    VoucherDefinition secondVoucherDefinition = createBareVoucherDefinition('Next Coupon 2');

    Test.startTest();
    CouponSequenceService.assignCouponCodes(new List<VoucherDefinition>{ firstVoucherDefinition, secondVoucherDefinition });
    Test.stopTest();

    SequenceControl__c updatedSequenceRecord = [
      SELECT LastSeq__c
      FROM SequenceControl__c
      WHERE Key__c = :expectedKey()
      LIMIT 1
    ];

    System.assertEquals(expectedCodePrefix() + '0006', firstVoucherDefinition.CouponManNo__c);
    System.assertEquals(expectedCodePrefix() + '0007', secondVoucherDefinition.CouponManNo__c);
    System.assertEquals(7, Integer.valueOf(updatedSequenceRecord.LastSeq__c));
  }

  @IsTest
  static void trigger_beforeInsert_assignsCouponManNo() {
    VoucherDefinition voucherDefinitionRecord = createInsertableVoucherDefinition('Trigger Coupon');

    Test.startTest();
    insert voucherDefinitionRecord;
    Test.stopTest();

    VoucherDefinition insertedVoucherDefinition = [
      SELECT CouponManNo__c
      FROM VoucherDefinition
      WHERE Id = :voucherDefinitionRecord.Id
      LIMIT 1
    ];

    System.assert(insertedVoucherDefinition.CouponManNo__c.startsWith(expectedCodePrefix()));
  }
}