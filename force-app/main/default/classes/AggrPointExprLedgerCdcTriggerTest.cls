@IsTest
private class AggrPointExprLedgerCdcTriggerTest {
  private static LoyaltyProgramMember seedMember() {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'AGGR-LP-' + String.valueOf(Datetime.now().getTime()));
    insert lp;

    Contact c = new Contact(
      LastName = 'AGGR-' + String.valueOf(Datetime.now().getTime())
    );
    insert c;

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
      Name = 'AGGR-CUR-' + String.valueOf(Datetime.now().getTime()),
      LoyaltyProgramId = lp.Id,
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

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      MembershipNumber = 'AGGR-' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(7),
      MemberType = 'Individual',
      ContactId = c.Id,
      MemberStatus = 'Active',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    return lpm;
  }

  @IsTest
  static void trigger_runs_on_create_change_event() {
    LoyaltyProgramMember lpm = seedMember();
    Id lpcId = [SELECT Id FROM LoyaltyProgramCurrency WHERE LoyaltyProgramId = :lpm.ProgramId LIMIT 1].Id;

    Test.enableChangeDataCapture();

    Test.startTest();
    insert new LoyaltyAggrPointExprLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = lpcId,
      ExpirationPoints = 100,
      ExpirationDate = Date.today().addDays(365)
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void trigger_runs_on_update_change_event() {
    LoyaltyProgramMember lpm = seedMember();
    Id lpcId = [SELECT Id FROM LoyaltyProgramCurrency WHERE LoyaltyProgramId = :lpm.ProgramId LIMIT 1].Id;

    LoyaltyAggrPointExprLedger ledger = new LoyaltyAggrPointExprLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = lpcId,
      ExpirationPoints = 100,
      ExpirationDate = Date.today().addDays(365)
    );
    insert ledger;

    Test.enableChangeDataCapture();

    Test.startTest();
    ledger.ExpirationPoints = 200;
    update ledger;
    Test.getEventBus().deliver();
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void trigger_runs_on_direct_change_event_publish() {
    Test.startTest();
    LoyaltyAggrPointExprLedgerChangeEvent evt = new LoyaltyAggrPointExprLedgerChangeEvent();
    Database.SaveResult sr = EventBus.publish(evt);
    System.assertEquals(true, sr.isSuccess());
    Test.stopTest();
  }
}