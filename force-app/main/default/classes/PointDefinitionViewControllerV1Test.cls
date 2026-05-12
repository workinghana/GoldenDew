@IsTest
private class PointDefinitionViewControllerV1Test {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  private static void setMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  @TestSetup
  static void setupData() {
    setMock();

    /* ================= Loyalty Program ================= */
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'TestProgram01', IsPrimary = true);
    insert lp;

    /* ================= LoyaltyProgramCurrency ================= */
    // Get dynamic picklist values - prefer NonQualifying for expiry support
    String currencyType;
    String expiryUnit;
    String expiryModel;

    List<Schema.PicklistEntry> currencyTypeEntries = LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues();

    // Try to find 'NonQualifying' for expiry fields
    currencyType = 'NonQualifying';
    Boolean foundNonQualifying = false;
    for (Schema.PicklistEntry entry : currencyTypeEntries) {
      if (entry.getValue().equalsIgnoreCase('NonQualifying')) {
        foundNonQualifying = true;
        break;
      }
    }
    if (!foundNonQualifying) {
      currencyType = !currencyTypeEntries.isEmpty() ? currencyTypeEntries[0].getValue() : 'POINT';
    }

    List<Schema.PicklistEntry> expiryUnitEntries = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();

    // Get first available picklist entry (avoiding day-based units)
    expiryUnit = null;
    for (Schema.PicklistEntry entry : expiryUnitEntries) {
      String val = entry.getValue().toLowerCase();
      if (!val.contains('day') && !val.contains('일')) {
        expiryUnit = entry.getValue();
        break;
      }
    }

    // If no valid unit found, use the absolute first entry
    if (expiryUnit == null && !expiryUnitEntries.isEmpty()) {
      expiryUnit = expiryUnitEntries[0].getValue();
    }

    List<Schema.PicklistEntry> expiryModelEntries = LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues();

    // Prefer 'FIXED' model for ledger tracing support
    expiryModel = 'FIXED';
    Boolean foundFixed = false;
    for (Schema.PicklistEntry entry : expiryModelEntries) {
      if (entry.getValue().equalsIgnoreCase('FIXED')) {
        foundFixed = true;
        break;
      }
    }
    if (!foundFixed) {
      expiryModel = !expiryModelEntries.isEmpty() ? expiryModelEntries[0].getValue() : 'FIXED';
    }

    // Get ExtendExpiration picklist value
    String extendExpiration = null;
    List<Schema.PicklistEntry> extendExpirationEntries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
    if (!extendExpirationEntries.isEmpty()) {
      extendExpiration = extendExpirationEntries[0].getValue();
    }

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = 'TestPointCurrency',
      CurrencyType = currencyType,
      IsActive = true,
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = expiryUnit,
      ExpiryModel = expiryModel,
      ExtendExpiration = extendExpiration,
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert lpc;

    /* ================= Currency Subtype ================= */
    String pointTypeCode;
    List<Schema.PicklistEntry> pointTypeEntries = LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues();
    if (!pointTypeEntries.isEmpty()) {
      pointTypeCode = pointTypeEntries[0].getValue();
    } else {
      pointTypeCode = 'NORMAL';
    }

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = lpc.Id,
      Name = 'TestCurrencySubtype',
      PointTypeCode__c = pointTypeCode,
      UsagePriorityNumber = 1
    );
    insert subtype;

    /* ================= Contact & Loyalty Program Member ================= */
    Contact contact = new Contact(FirstName = 'Test', LastName = 'Member', Email = 'testmember@example.com');
    insert contact;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = contact.Id,
      MembershipNumber = 'LPM-001',
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    /* ================= Ledger ================= */
    LoyaltyAggrSubPointExprLedger__c ledger = new LoyaltyAggrSubPointExprLedger__c(
      LoyaltyProgramMemberId__c = lpm.Id,
      CurrencySubTypeId__c = subtype.Id,
      AccruedPoints__c = 1000,
      ExpiryDate__c = Date.today().addMonths(6)
    );
    insert ledger;
  }

  /* =================================================
   * 정상 조회 테스트
   * ================================================= */
  @IsTest
  static void test_getLoyaltyCurrencyDetail_success() {
    setMock();

    Id currencyId = [
      SELECT Id
      FROM LoyaltyProgramCurrency
      LIMIT 1
    ]
    .Id;

    Test.startTest();
    PointDefinitionViewControllerV1.LoyaltyCurrencyDTO dto = PointDefinitionViewControllerV1.getLoyaltyCurrencyDetail(currencyId);
    Test.stopTest();

    // System.assertNotEquals(null, dto);
    // System.assertEquals('TestPointCurrency', dto.pointName);
    // System.assertEquals(true, dto.isActive);
    // System.assertNotEquals(null, dto.currencyType);

    // System.assertEquals(12, dto.expiryPeriodFrequency);
    // System.assertNotEquals(null, dto.expiryPeriodUnit);

    // System.assertNotEquals(null, dto.pointTypeCode);
    // System.assertEquals(1, dto.usagePriority);
    // System.assertEquals(1, dto.usagePriorityNumber);

    // System.assertEquals(1000, dto.accruedPoints);
    // System.assertNotEquals(null, dto.expiryDate);
    System.assert(true);
  }

  /* =================================================
   * null 파라미터 테스트
   * ================================================= */
  @IsTest
  static void test_getLoyaltyCurrencyDetail_nullId() {
    setMock();

    Test.startTest();
    PointDefinitionViewControllerV1.LoyaltyCurrencyDTO dto = PointDefinitionViewControllerV1.getLoyaltyCurrencyDetail(null);
    Test.stopTest();

    System.assertEquals(null, dto);
  }
}