@IsTest
private class GdPointAggrRetryQueueableTest {
  private static Integer seq = 0;
  private static final String MEMBER_NO = 'AGGR-RETRY-001';

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
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Aggr Retry Program', IsPrimary = true);
    insert program;

    Contact contactRecord = new Contact(LastName = 'AggrRetryMember', MemberNo__c = MEMBER_NO);
    insert contactRecord;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      MembershipNumber = MEMBER_NO,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = contactRecord.Id,
      EnrollmentDate = Date.today(),
      ProgramId = program.Id
    );
    insert member;

    JournalType accrualType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    JournalType redemptionType = new JournalType(Name = 'Redemption', ProcessType = 'Loyalty');
    JournalType redemptionReversalType = new JournalType(Name = 'Redemption Reversal', ProcessType = 'Loyalty');
    JournalType accrualReversalType = new JournalType(Name = 'Accrual Reversal', ProcessType = 'Loyalty');
    insert new List<JournalType>{ accrualType, redemptionType, redemptionReversalType, accrualReversalType };

    insert new List<JournalSubType>{
      new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = redemptionReversalType.Id),
      new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = accrualReversalType.Id),
      new JournalSubType(Name = 'Manual Points Credit', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Auto Expire', JournalTypeId = accrualReversalType.Id),
      new JournalSubType(Name = 'Api Forced Expire', JournalTypeId = accrualReversalType.Id),
      new JournalSubType(Name = 'Api Forced Debit', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual Reversal', JournalTypeId = accrualReversalType.Id)
    };

    LoyaltyProgramCurrency currencyRecord = new LoyaltyProgramCurrency(
      LoyaltyProgramId = program.Id,
      Name = '\uD3EC\uC778\uD2B8',
      CurrencyType = 'NonQualifying',
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = 'Fixed',
      ExtendExpiration = 'None',
      ExpiryPeriodFrequency = 2,
      ExpiryPeriodUnit = 'Years',
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert currencyRecord;

    insert new LoyaltyMemberCurrency(Name = 'AGGR-RETRY-LMC', LoyaltyMemberId = member.Id, LoyaltyProgramCurrencyId = currencyRecord.Id);
  }

  @IsTest
  static void execute_nullIds_returnsWithoutError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    Test.startTest();
    System.enqueueJob(new GdPointAggrRetryQueueable(null));
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM LoyaltyAggrSubPointExprLedger__c]);
  }

  @IsTest
  static void execute_emptyIds_returnsWithoutError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    Test.startTest();
    System.enqueueJob(new GdPointAggrRetryQueueable(new List<Id>()));
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM LoyaltyAggrSubPointExprLedger__c]);
  }

  @IsTest
  static void execute_processedJournalId_createsAggregateLedger() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    LoyaltyProgramMember member = testMember();
    LoyaltyProgramCurrency currencyRecord = pointCurrency();
    LoyaltyPgmCurrencySubtype subtype = createCurrencySubtype(currencyRecord.Id);
    Date expiryDate = Date.today().addDays(30);
    TransactionJournal journal = createProcessedJournal(member, 'Purchase Accrual');
    createLedger(journal.Id, member.Id, currencyRecord.Id, subtype.Id, 'Credit', 120, expiryDate);

    Test.startTest();
    System.enqueueJob(new GdPointAggrRetryQueueable(new List<Id>{ journal.Id }));
    Test.stopTest();

    LoyaltyAggrSubPointExprLedger__c aggregateRecord = [
      SELECT LoyaltyProgramMemberId__c, CurrencySubTypeId__c, ExpiryDate__c, AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :member.Id AND CurrencySubTypeId__c = :subtype.Id AND ExpiryDate__c = :expiryDate
      LIMIT 1
    ];
    System.assertEquals(120, aggregateRecord.AccruedPoints__c);
    System.assertEquals(0, aggregateRecord.RedeemedPoints__c);
    System.assertEquals(0, aggregateRecord.ExpiredPoints__c);
  }

  private static LoyaltyProgramMember testMember() {
    return [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      WHERE MembershipNumber = :MEMBER_NO
      LIMIT 1
    ];
  }

  private static LoyaltyProgramCurrency pointCurrency() {
    return [SELECT Id FROM LoyaltyProgramCurrency WHERE Name = '\uD3EC\uC778\uD2B8' LIMIT 1];
  }

  private static Id journalSubTypeId(String name) {
    return [SELECT Id FROM JournalSubType WHERE Name = :name LIMIT 1].Id;
  }

  private static LoyaltyPgmCurrencySubtype createCurrencySubtype(Id currencyId) {
    seq++;
    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = currencyId,
      Name = 'AGGR_RETRY_SUBTYPE_' + seq,
      PointTypeCode__c = '01',
      UsagePriorityNumber = seq,
      IsActive = true
    );
    insert subtype;
    return subtype;
  }

  private static TransactionJournal createProcessedJournal(LoyaltyProgramMember member, String journalSubTypeName) {
    TransactionJournal journal = new TransactionJournal(
      MemberId = member.Id,
      LoyaltyProgramId = member.ProgramId,
      JournalSubTypeId = journalSubTypeId(journalSubTypeName),
      ActivityDate = Datetime.now(),
      Status = 'Processed',
      TransactionAmount = 120,
      InsertId__c = 'TESTER'
    );
    insert journal;
    return journal;
  }

  private static LoyaltyLedger createLedger(
    Id transactionJournalId,
    Id memberId,
    Id currencyId,
    Id subtypeId,
    String eventType,
    Decimal points,
    Date expiryDate
  ) {
    LoyaltyLedger ledger = new LoyaltyLedger(
      TransactionJournalId = transactionJournalId,
      LoyaltyProgramMemberId = memberId,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCrcySubtypeId = subtypeId,
      ActivityDate = Datetime.now(),
      EventType = eventType,
      Points = points,
      ExpiryDate = expiryDate
    );
    insert ledger;
    return ledger;
  }
}