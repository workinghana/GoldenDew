@IsTest
private class GdPointAggregationUtilTest {
  private static Integer seq = 0;
  private static final String MEMBER_NO = 'AGGR-UTIL-001';
  private static final String STORE_CODE = 'AGGR-UTIL-STORE';
  private static final String ORDER_SALE_NO = 'AGGR-UTIL-SALE-001';

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

    Id standardPricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = standardPricebookId, IsActive = true);

    Contact contactRecord = new Contact(LastName = 'AggrUtilMember', MemberNo__c = MEMBER_NO);
    insert contactRecord;

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Aggr Util Program', IsPrimary = true);
    insert program;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      MembershipNumber = MEMBER_NO,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = contactRecord.Id,
      EnrollmentDate = Date.today(),
      ProgramId = program.Id
    );
    insert member;

    Account store = new Account(Name = 'Aggr Util Store', StoreCode__c = STORE_CODE, StoreType__c = '01', StoreTypeFour__c = '01');
    insert store;

    insert new Order(
      Name = 'Aggr Util Order',
      AccountId = store.Id,
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = standardPricebookId,
      OrderNo__c = 'AGGR-UTIL-ORD-001',
      SaleNo__c = ORDER_SALE_NO,
      ActualPaymentAmount__c = 100000,
      IsReductionOrder__c = false,
      MemberNo__c = contactRecord.Id,
      StoreCode__c = store.Id,
      InsertId__c = 'TESTER'
    );

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

    insert new LoyaltyMemberCurrency(Name = 'AGGR-UTIL-LMC', LoyaltyMemberId = member.Id, LoyaltyProgramCurrencyId = currencyRecord.Id);

    JournalType accrualType = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
    JournalType redemptionType = new JournalType(Name = 'Redemption', ProcessType = 'Loyalty');
    JournalType redemptionReversalType = new JournalType(Name = 'Redemption Reversal', ProcessType = 'Loyalty');
    JournalType accrualReversalType = new JournalType(Name = 'Accrual Reversal', ProcessType = 'Loyalty');
    insert new List<JournalType>{ accrualType, redemptionType, redemptionReversalType, accrualReversalType };

    insert new List<JournalSubType>{
      new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = redemptionReversalType.Id),
      new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Manual Points Credit', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = accrualReversalType.Id),
      new JournalSubType(Name = 'Auto Expire', JournalTypeId = accrualReversalType.Id),
      new JournalSubType(Name = 'Api Forced Expire', JournalTypeId = accrualReversalType.Id),
      new JournalSubType(Name = 'Api Forced Debit', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Api Forced Credit', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual', JournalTypeId = accrualType.Id),
      new JournalSubType(Name = 'Promotion Point Accrual Reversal', JournalTypeId = accrualReversalType.Id)
    };
  }

  @IsTest
  static void rebuild_nullMember_returnsWithoutError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    Test.startTest();
    GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger(null);
    Test.stopTest();

    System.assertEquals(0, [SELECT COUNT() FROM LoyaltyAggrSubPointExprLedger__c]);
  }

  @IsTest
  static void rebuild_ledgersAndTraceability_recreatesAggregateRows() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    LoyaltyProgramMember member = memberByNo(MEMBER_NO);
    LoyaltyProgramCurrency currencyRecord = pointCurrency();
    LoyaltyPgmCurrencySubtype subtype = createCurrencySubtype(currencyRecord.Id, '01');
    LoyaltyPgmCurrencySubtype staleSubtype = createCurrencySubtype(currencyRecord.Id, '02');
    Order orderRecord = [SELECT Id FROM Order WHERE SaleNo__c = :ORDER_SALE_NO LIMIT 1];
    Date expiryDate = Date.today().addDays(40);
    Date staleExpiryDate = Date.today().addDays(80);

    insert new LoyaltyAggrSubPointExprLedger__c(
      LoyaltyProgramMemberId__c = member.Id,
      CurrencySubTypeId__c = staleSubtype.Id,
      ExpiryDate__c = staleExpiryDate,
      CurrencySubTypeName__c = staleSubtype.Name,
      AccruedPoints__c = 30,
      RedeemedPoints__c = 20,
      ExpiredPoints__c = 10,
      LoyaltyProgramCurrencyId__c = currencyRecord.Id
    );

    LoyaltyLedger purchaseCredit = createLedger(
      createJournal(member, 'Purchase Accrual', orderRecord.Id, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Credit',
      100,
      expiryDate
    );
    createLedger(
      createJournal(member, 'Manual Points Credit', null, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Credit',
      40,
      expiryDate
    );
    createLedger(createJournal(member, 'Api Forced Credit', null, null, null).Id, member.Id, currencyRecord.Id, subtype.Id, 'Credit', 15, expiryDate);
    createLedger(
      createJournal(member, 'Promotion Point Accrual', null, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Credit',
      25,
      expiryDate
    );
    createLedger(createJournal(member, 'Auto Expire', null, null, null).Id, member.Id, currencyRecord.Id, subtype.Id, 'Expiry', 10, expiryDate);
    createLedger(
      createJournal(member, 'Point Redeem Cancel', null, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Credit',
      8,
      expiryDate
    );

    LoyaltyLedger pointDebitLedger = createLedger(
      createJournal(member, 'Point Debit', null, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Debit',
      30,
      null
    );
    createTrace(member.Id, currencyRecord.Id, subtype.Id, purchaseCredit.Id, pointDebitLedger.Id, 'Debit', 30);

    LoyaltyLedger cancelAccrualDebitLedger = createLedger(
      createJournal(member, 'Cancel Purchase Accrual', null, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Debit',
      20,
      null
    );
    createTrace(member.Id, currencyRecord.Id, subtype.Id, purchaseCredit.Id, cancelAccrualDebitLedger.Id, 'CreditCancellation', 20);

    LoyaltyLedger apiForcedExpireDebitLedger = createLedger(
      createJournal(member, 'Api Forced Expire', null, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Debit',
      5,
      null
    );
    createTrace(member.Id, currencyRecord.Id, subtype.Id, purchaseCredit.Id, apiForcedExpireDebitLedger.Id, 'Debit', 5);

    createLedger(
      createJournal(member, 'Cancel Purchase Accrual', orderRecord.Id, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Debit',
      15,
      null
    );

    Test.startTest();
    GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger(member.Id);
    Test.stopTest();

    LoyaltyAggrSubPointExprLedger__c aggregateRecord = [
      SELECT CurrencySubTypeName__c, AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c, LoyaltyProgramCurrencyId__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :member.Id AND CurrencySubTypeId__c = :subtype.Id AND ExpiryDate__c = :expiryDate
      LIMIT 1
    ];
    System.assertEquals(subtype.Name, aggregateRecord.CurrencySubTypeName__c);
    System.assertEquals(currencyRecord.Id, aggregateRecord.LoyaltyProgramCurrencyId__c);
    System.assert(aggregateRecord.AccruedPoints__c > 0);
    System.assert(aggregateRecord.RedeemedPoints__c >= 0);
    System.assert(aggregateRecord.ExpiredPoints__c >= 10);

    LoyaltyAggrSubPointExprLedger__c staleAggregate = [
      SELECT AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :member.Id AND CurrencySubTypeId__c = :staleSubtype.Id AND ExpiryDate__c = :staleExpiryDate
      LIMIT 1
    ];
    System.assertEquals(0, staleAggregate.AccruedPoints__c);
    System.assertEquals(0, staleAggregate.RedeemedPoints__c);
    System.assertEquals(0, staleAggregate.ExpiredPoints__c);
  }

  @IsTest
  static void rebuild_existingAggregate_updatesValuesToCurrentLedgerState() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
    ApexLogger.disableLogging();

    LoyaltyProgramMember member = memberByNo(MEMBER_NO);
    LoyaltyProgramCurrency currencyRecord = pointCurrency();
    LoyaltyPgmCurrencySubtype subtype = createCurrencySubtype(currencyRecord.Id, '03');
    Date expiryDate = Date.today().addDays(20);

    insert new LoyaltyAggrSubPointExprLedger__c(
      LoyaltyProgramMemberId__c = member.Id,
      CurrencySubTypeId__c = subtype.Id,
      ExpiryDate__c = expiryDate,
      CurrencySubTypeName__c = 'OLD_NAME',
      AccruedPoints__c = 1,
      RedeemedPoints__c = 1,
      ExpiredPoints__c = 1,
      LoyaltyProgramCurrencyId__c = currencyRecord.Id
    );
    createLedger(
      createJournal(member, 'Manual Points Credit', null, null, null).Id,
      member.Id,
      currencyRecord.Id,
      subtype.Id,
      'Credit',
      77,
      expiryDate
    );

    Test.startTest();
    GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger(member.Id);
    Test.stopTest();

    LoyaltyAggrSubPointExprLedger__c updatedAggregate = [
      SELECT CurrencySubTypeName__c, AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :member.Id AND CurrencySubTypeId__c = :subtype.Id AND ExpiryDate__c = :expiryDate
      LIMIT 1
    ];
    System.assertEquals(subtype.Name, updatedAggregate.CurrencySubTypeName__c);
    System.assertEquals(77, updatedAggregate.AccruedPoints__c);
    System.assertEquals(0, updatedAggregate.RedeemedPoints__c);
    System.assertEquals(0, updatedAggregate.ExpiredPoints__c);
  }

  private static LoyaltyProgramMember memberByNo(String memberNo) {
    return [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = :memberNo LIMIT 1];
  }

  private static LoyaltyProgramCurrency pointCurrency() {
    return [SELECT Id FROM LoyaltyProgramCurrency WHERE Name = '\uD3EC\uC778\uD2B8' LIMIT 1];
  }

  private static Id journalSubTypeId(String name) {
    return [SELECT Id FROM JournalSubType WHERE Name = :name LIMIT 1].Id;
  }

  private static LoyaltyPgmCurrencySubtype createCurrencySubtype(Id currencyId, String pointTypeCode) {
    seq++;
    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = currencyId,
      Name = 'AGGR_UTIL_SUBTYPE_' + seq,
      PointTypeCode__c = pointTypeCode,
      UsagePriorityNumber = seq,
      IsActive = true
    );
    insert subtype;
    return subtype;
  }

  private static TransactionJournal createJournal(
    LoyaltyProgramMember member,
    String journalSubTypeName,
    Id orderId,
    Id saleId,
    String legacyOrderId
  ) {
    TransactionJournal journal = new TransactionJournal(
      MemberId = member.Id,
      LoyaltyProgramId = member.ProgramId,
      JournalSubTypeId = journalSubTypeId(journalSubTypeName),
      OrderId = orderId,
      SaleId__c = saleId,
      OrderId__c = legacyOrderId,
      JournalDate = Datetime.now(),
      ActivityDate = Datetime.now(),
      Status = 'Processed',
      TransactionAmount = 100,
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

  private static void createTrace(Id memberId, Id currencyId, Id subtypeId, Id creditLedgerId, Id debitLedgerId, String actionType, Decimal points) {
    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = memberId,
      LoyaltyProgramCurrencyId = currencyId,
      LoyaltyPgmCurrencySubtypeId = subtypeId,
      CreditLoyaltyLedgerId = creditLedgerId,
      DebitLoyaltyLedgerId = debitLedgerId,
      ActionType = actionType,
      Points = points
    );
  }
}