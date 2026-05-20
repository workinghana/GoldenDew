@IsTest
private class PromotionPointTriggerTest {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"ok","data":{}}');
      return res;
    }
  }

  @TestSetup
  static void setupData() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'TPP-LP', IsPrimary = false);
    insert lp;

    String expiryUnit = null;
    for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues()) {
      if (!e.getValue().toLowerCase().contains('day')) {
        expiryUnit = e.getValue();
        break;
      }
    }
    if (expiryUnit == null) {
      List<Schema.PicklistEntry> units = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();
      if (!units.isEmpty()) {
        expiryUnit = units[0].getValue();
      }
    }

    String expiryModel = 'FIXED';
    for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
      if (e.getValue().equalsIgnoreCase('FIXED')) {
        expiryModel = e.getValue();
        break;
      }
    }

    String extendExpiration = null;
    List<Schema.PicklistEntry> extEntries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
    if (!extEntries.isEmpty()) {
      extendExpiration = extEntries[0].getValue();
    }

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lp.Id,
      Name = 'TPP-Currency',
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = expiryUnit,
      ExpiryModel = expiryModel,
      ExtendExpiration = extendExpiration,
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert lpc;

    String pointTypeCode = LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues()[0].getValue();
    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = lpc.Id,
      Name = 'TPP-Subtype',
      PointTypeCode__c = pointTypeCode,
      UsagePriorityNumber = 1
    );
    insert subtype;

    Promotion p = new Promotion(
      Name = 'TPP-Promo',
      StartDate = Date.today(),
      EndDate = Date.today().addDays(7),
      PublishStartDate__c = Date.today(),
      PublishEndDate__c = Date.today().addDays(3),
      IsCouponAllowed__c = true,
      IsFixedAmountCouponAllowed__c = false,
      IsRateCouponAllowed__c = true,
      IsSpecificCouponAllowed__c = false,
      IsPointUsageAllowed__c = false,
      IsAllStore__c = false,
      IsAllItem__c = false
    );
    insert p;
  }

  private static String pointLimitTypeAllowingValue() {
    List<Schema.PicklistEntry> entries = PromotionPointLimit__c.Type__c.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      String value = String.valueOf(entry.getValue());
      String label = String.valueOf(entry.getLabel());
      String normalized = (value + ' ' + label).toLowerCase();
      if (!normalized.contains('기본') && !normalized.contains('basic') && !normalized.contains('default')) {
        return value;
      }
    }
    return entries.isEmpty() ? null : entries[0].getValue();
  }

  private static PromotionPointLimit__c makeLimit() {
    Id promoId = [SELECT Id FROM Promotion WHERE Name = 'TPP-Promo' LIMIT 1].Id;
    Id subtypeId = [SELECT Id FROM LoyaltyPgmCurrencySubtype WHERE Name = 'TPP-Subtype' LIMIT 1].Id;
    String typeValue = pointLimitTypeAllowingValue();

    PromotionPointLimit__c limitRecord = new PromotionPointLimit__c(
      Name = 'TPP-Limit-' + String.valueOf(Datetime.now().getTime()),
      PromotionId__c = promoId,
      Type__c = typeValue,
      LoyaltyPgmCurrencySubtypeId__c = subtypeId
    );
    if (typeValue != null && !String.valueOf(typeValue).contains('기본')) {
      limitRecord.Value__c = 100;
    }
    return limitRecord;
  }

  @IsTest
  static void trigger_afterInsert_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    PromotionPointLimit__c ppl = makeLimit();

    Test.startTest();
    insert ppl;
    Test.stopTest();

    System.assertNotEquals(null, ppl.Id);
  }

  @IsTest
  static void trigger_afterUpdate_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    PromotionPointLimit__c ppl = makeLimit();
    insert ppl;

    ppl.Value__c = 90;

    Test.startTest();
    update ppl;
    Test.stopTest();

    PromotionPointLimit__c updated = [SELECT Id, Value__c FROM PromotionPointLimit__c WHERE Id = :ppl.Id LIMIT 1];
    System.assertEquals(90, updated.Value__c);
  }

  @IsTest
  static void trigger_afterDelete_runs() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    PromotionPointLimit__c ppl = makeLimit();
    insert ppl;

    Test.startTest();
    delete ppl;
    Test.stopTest();

    Integer countAfter = [SELECT COUNT() FROM PromotionPointLimit__c WHERE Id = :ppl.Id];
    System.assertEquals(0, countAfter);
  }
}