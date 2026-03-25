@IsTest
private class LoyaltyPgmCrySubtypeViewControllerV1Test {
  private static Integer seqCounter = 1;

  private static String uniq(String prefix) {
    return prefix + '_' + String.valueOf(System.currentTimeMillis());
  }

  private static String getProcessType() {
    List<Schema.PicklistEntry> entries = BenefitType.ProcessType.getDescribe().getPicklistValues();
    return entries.isEmpty() ? 'Loyalty' : entries[0].getValue();
  }

  private static LoyaltyProgram createProgram() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('LP'), IsPrimary = true);
    insert lp;
    return lp;
  }

  private static LoyaltyProgramCurrency createProgramCurrency(Id lpId) {
    LoyaltyProgramCurrency c = new LoyaltyProgramCurrency(
      Name = '포인트',
      LoyaltyProgramId = lpId,
      IsActive = true,
      CurrencyType = 'NonQualifying',
      ExpiryModel = 'Fixed',
      ExpiryPeriodFrequency = 2,
      ExpiryPeriodUnit = 'Years',
      ExtendExpiration = 'None',
      IsPrimary = true,
      DoesAllowLedgerTracing = true
    );
    insert c;
    return c;
  }

  // 🔥 수정됨
  private static LoyaltyPgmCurrencySubtype createSubtype(Id programCurrencyId, String name) {
    Integer nextSeq =
      [
        SELECT COUNT()
        FROM LoyaltyPgmCurrencySubtype
      ] + 1;

    LoyaltyPgmCurrencySubtype s = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = programCurrencyId,
      Name = name,
      PointTypeCode__c = String.valueOf(nextSeq).leftPad(2, '0'),
      UsagePriorityNumber = nextSeq,
      IsActive = true
    );

    insert s;
    return s;
  }

  private static BenefitType createBenefitType(Id lpId) {
    BenefitType bt = new BenefitType(Name = uniq('BT'), ProcessType = getProcessType(), LoyaltyProgramId = lpId);
    insert bt;
    return bt;
  }

  private static Benefit createBenefit(Id subtypeId, Id btId, String name, Integer seq) {
    Benefit b = new Benefit(
      Name = name,
      Description = name + ' desc',
      IsActive = true,
      IsBenefitSelectionAllowed = true,
      PrioritySequence = seq,
      BenefitTypeId = btId,
      PurchasePointRate__c = 3,
      LoyaltyPgmCurrencySubtypeId__c = subtypeId
    );
    insert b;
    return b;
  }

  @TestSetup
  static void setup() {
    LoyaltyProgram lp = createProgram();
    LoyaltyProgramCurrency programCurrency = createProgramCurrency(lp.Id);

    LoyaltyPgmCurrencySubtype subtype = createSubtype(programCurrency.Id, 'MainSubtype');
    BenefitType bt = createBenefitType(lp.Id);

    createBenefit(subtype.Id, bt.Id, 'Benefit1', 1);
  }

  private static Id getSubtypeId() {
    return [SELECT Id FROM LoyaltyPgmCurrencySubtype LIMIT 1].Id;
  }

  @IsTest
  static void test_nullId() {
    Test.startTest();
    LoyaltyPgmCrySubtypeViewControllerV1.SubtypeViewDto res = LoyaltyPgmCrySubtypeViewControllerV1.getSubtype(null);
    Test.stopTest();

    System.assertEquals(null, res);
  }

  @IsTest
  static void test_valid() {
    Id id = getSubtypeId();

    Test.startTest();
    LoyaltyPgmCrySubtypeViewControllerV1.SubtypeViewDto res = LoyaltyPgmCrySubtypeViewControllerV1.getSubtype(id);
    Test.stopTest();

    System.assertNotEquals(null, res);
    System.assertEquals(id, res.id);
    System.assertEquals(1, res.benefitCount);
    System.assertEquals(1, res.benefits.size());
  }

  @IsTest
  static void test_noBenefit() {
    LoyaltyProgramCurrency programCurrency = [SELECT Id FROM LoyaltyProgramCurrency LIMIT 1];

    LoyaltyPgmCurrencySubtype s = createSubtype(programCurrency.Id, 'NoBenefit');

    Test.startTest();
    LoyaltyPgmCrySubtypeViewControllerV1.SubtypeViewDto res = LoyaltyPgmCrySubtypeViewControllerV1.getSubtype(s.Id);
    Test.stopTest();

    System.assertEquals(0, res.benefitCount);
    System.assertEquals(0, res.benefits.size());
  }

  @IsTest
  static void test_multipleBenefit_order() {
    Id id = getSubtypeId();
    BenefitType bt = [SELECT Id FROM BenefitType LIMIT 1];

    createBenefit(id, bt.Id, 'Benefit2', 2);
    createBenefit(id, bt.Id, 'BenefitNullSeq', null);

    Test.startTest();
    LoyaltyPgmCrySubtypeViewControllerV1.SubtypeViewDto res = LoyaltyPgmCrySubtypeViewControllerV1.getSubtype(id);
    Test.stopTest();

    System.assertEquals(3, res.benefitCount);
    System.assertEquals('Benefit1', res.benefits[0].name);
    System.assertEquals('Benefit2', res.benefits[1].name);
  }

  // 🔥 수정됨
  @IsTest
  static void test_invalidId_exception() {
    Id fakeId = UserInfo.getUserId();

    Test.startTest();
    try {
      LoyaltyPgmCrySubtypeViewControllerV1.getSubtype(fakeId);
      System.assert(false, 'Exception should have been thrown');
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();
  }
}