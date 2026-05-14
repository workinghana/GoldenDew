@IsTest
private class GdOptionCPointAdjustmentUtilTest {
  private static final String MEMBER_NO = 'OPT-C-ADJ-001';
  private static final String STORE_CODE = 'OPT-C-STORE';
  private static final String ORIGINAL_SALE_NO = 'OPT-C-SALE-001';
  private static final String RETURN_SALE_NO = 'OPT-C-RETURN-001';
  private static final String OTHER_RETURN_SALE_NO = 'OPT-C-RETURN-002';

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

    Id standardPricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = standardPricebookId, IsActive = true);

    Contact memberContact = new Contact(LastName = 'OptionCMember', Grade__c = '02', MemberNo__c = MEMBER_NO);
    insert memberContact;

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Option C Adjustment Program', IsPrimary = true);
    insert program;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      MembershipNumber = MEMBER_NO,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = memberContact.Id,
      EnrollmentDate = Date.today(),
      ProgramId = program.Id
    );
    insert member;

    Account store = new Account(Name = 'Option C Store', StoreCode__c = STORE_CODE, StoreType__c = '01', StoreTypeFour__c = '01');
    insert store;

    insert new List<Order>{
      new Order(
        Name = 'Option C Original Order',
        AccountId = store.Id,
        EffectiveDate = Date.today(),
        EndDate = Date.today(),
        Status = 'Draft',
        Pricebook2Id = standardPricebookId,
        OrderNo__c = 'OPT-C-ORD-001',
        SaleNo__c = ORIGINAL_SALE_NO,
        ActualPaymentAmount__c = 100000,
        IsReductionOrder__c = false,
        MemberNo__c = memberContact.Id,
        StoreCode__c = store.Id,
        InsertId__c = 'TESTER'
      ),
      new Order(
        Name = 'Option C Return Order',
        AccountId = store.Id,
        EffectiveDate = Date.today(),
        EndDate = Date.today(),
        Status = 'Draft',
        Pricebook2Id = standardPricebookId,
        OrderNo__c = 'OPT-C-ORD-002',
        SaleNo__c = RETURN_SALE_NO,
        ActualPaymentAmount__c = -50000,
        IsReductionOrder__c = true,
        MemberNo__c = memberContact.Id,
        StoreCode__c = store.Id,
        InsertId__c = 'TESTER'
      ),
      new Order(
        Name = 'Option C Other Return Order',
        AccountId = store.Id,
        EffectiveDate = Date.today(),
        EndDate = Date.today(),
        Status = 'Draft',
        Pricebook2Id = standardPricebookId,
        OrderNo__c = 'OPT-C-ORD-003',
        SaleNo__c = OTHER_RETURN_SALE_NO,
        ActualPaymentAmount__c = -30000,
        IsReductionOrder__c = true,
        MemberNo__c = memberContact.Id,
        StoreCode__c = store.Id,
        InsertId__c = 'TESTER'
      )
    };

    LoyaltyProgramCurrency currencyRecord = new LoyaltyProgramCurrency(
      LoyaltyProgramId = program.Id,
      Name = '\uD3EC\uC778\uD2B8',
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
    insert currencyRecord;

    insert new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = currencyRecord.Id,
      Name = 'OPTION_C_ETC_POINT',
      PointTypeCode__c = '04',
      UsagePriorityNumber = 1,
      IsActive = true
    );

    insert new LoyaltyMemberCurrency(Name = 'OPT-C-LMC', LoyaltyMemberId = member.Id, LoyaltyProgramCurrencyId = currencyRecord.Id);

    insert new List<JournalType>{
      new JournalType(Name = 'Accrual', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Redemption', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Redemption Reversal', ProcessType = 'Loyalty'),
      new JournalType(Name = 'Accrual Reversal', ProcessType = 'Loyalty')
    };

    insert new List<JournalSubType>{
      new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = journalTypeId('Accrual')),
      new JournalSubType(Name = 'Point Debit', JournalTypeId = journalTypeId('Redemption')),
      new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = journalTypeId('Redemption Reversal')),
      new JournalSubType(Name = 'Cancel Purchase Accrual', JournalTypeId = journalTypeId('Accrual Reversal'))
    };
  }

  @IsTest
  static void cancelOldSaleEtcAccrualSafe_invalidInput_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      null,
      null,
      null,
      null,
      0,
      null
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals('invalid input', result.error);
    System.assertEquals(0, result.requestedPoints);
    System.assertEquals(0, result.loss);
  }

  @IsTest
  static void cancelOldSaleEtcAccrualSafe_noCreditLedger_returnsError() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    LoyaltyProgramMember member = testMember();
    Order originalOrder = orderBySaleNo(ORIGINAL_SALE_NO);
    Order returnOrder = orderBySaleNo(RETURN_SALE_NO);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      member.Id,
      member.ProgramId,
      originalOrder.Id,
      returnOrder.Id,
      100,
      'no ledger'
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals('no active option c etc credit ledger', result.error);
    System.assertEquals(100, result.loss);
  }

  @IsTest
  static void cancelOldSaleEtcAccrualSafe_fullCancel_createsReversalLedgerAndTrace() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    LoyaltyProgramMember member = testMember();
    Order originalOrder = orderBySaleNo(ORIGINAL_SALE_NO);
    Order returnOrder = orderBySaleNo(RETURN_SALE_NO);
    LoyaltyLedger creditLedger = insertCreditLedger(member, originalOrder.Id, null, 'Purchase Accrual', 100);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      member.Id,
      member.ProgramId,
      originalOrder.Id,
      returnOrder.Id,
      70,
      'full cancel'
    );
    Test.stopTest();

    System.assertEquals(true, result.success, assertionMessage(result));
    System.assertEquals(70, result.actualPoints);
    System.assertEquals(0, result.loss);
    System.assertNotEquals(null, result.reversalTjId);

    TransactionJournal reversalJournal = [
      SELECT OrderId, SaleId__c, AdditionalNotes__c, JournalSubType.Name
      FROM TransactionJournal
      WHERE Id = :result.reversalTjId
    ];
    System.assertEquals(originalOrder.Id, reversalJournal.OrderId);
    System.assertEquals(returnOrder.Id, reversalJournal.SaleId__c);
    System.assertEquals('Cancel Purchase Accrual', reversalJournal.JournalSubType.Name);
    System.assert(reversalJournal.AdditionalNotes__c.contains('OPTC_OLD_SALE_ETC_ACCRUAL_CANCEL'));

    LoyaltyLedger debitLedger = [
      SELECT Points, EventType, TransactionJournalId
      FROM LoyaltyLedger
      WHERE TransactionJournalId = :result.reversalTjId
      LIMIT 1
    ];
    System.assertEquals('Debit', debitLedger.EventType);
    System.assertEquals(70, debitLedger.Points);

    LoyaltyLedgerTraceability traceabilityRecord = [
      SELECT Points, ActionType, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId
      FROM LoyaltyLedgerTraceability
      WHERE DebitLoyaltyLedgerId = :debitLedger.Id
      LIMIT 1
    ];
    System.assertEquals(70, traceabilityRecord.Points);
    System.assertEquals('CreditCancellation', traceabilityRecord.ActionType);
    System.assertEquals(creditLedger.Id, traceabilityRecord.CreditLoyaltyLedgerId);
  }

  @IsTest
  static void cancelOldSaleEtcAccrualSafe_priorTraceLimitsAvailablePoints() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    LoyaltyProgramMember member = testMember();
    Order originalOrder = orderBySaleNo(ORIGINAL_SALE_NO);
    Order returnOrder = orderBySaleNo(RETURN_SALE_NO);
    LoyaltyLedger creditLedger = insertCreditLedger(member, originalOrder.Id, null, 'Purchase Accrual', 100);
    insertPriorTrace(member, creditLedger, 'Debit', 40);
    insertPriorTrace(member, creditLedger, 'DebitCancellation', 10);
    insertPriorTrace(member, creditLedger, 'CreditCancellation', 20);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      member.Id,
      member.ProgramId,
      originalOrder.Id,
      returnOrder.Id,
      70,
      'partial cancel'
    );
    Test.stopTest();

    System.assertEquals(true, result.success, assertionMessage(result));
    System.assertEquals(50, result.actualPoints);
    System.assertEquals(20, result.loss);
  }

  @IsTest
  static void cancelOldSaleEtcAccrualSafe_pointRedeemCancelKeepsOnlyCurrentReturnCredit() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    LoyaltyProgramMember member = testMember();
    Order originalOrder = orderBySaleNo(ORIGINAL_SALE_NO);
    Order returnOrder = orderBySaleNo(RETURN_SALE_NO);
    Order otherReturnOrder = orderBySaleNo(OTHER_RETURN_SALE_NO);
    insertCreditLedger(member, originalOrder.Id, otherReturnOrder.Id, 'Point Redeem Cancel', 90);
    insertCreditLedger(member, originalOrder.Id, returnOrder.Id, 'Point Redeem Cancel', 30);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      member.Id,
      member.ProgramId,
      originalOrder.Id,
      returnOrder.Id,
      50,
      'filter current return'
    );
    Test.stopTest();

    System.assertEquals(true, result.success, assertionMessage(result));
    System.assertEquals(30, result.actualPoints);
    System.assertEquals(20, result.loss);
  }

  @IsTest
  static void cancelOldSaleEtcAccrualSafe_secondPassUsesOtherOrderCredit() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    LoyaltyProgramMember member = testMember();
    Order originalOrder = orderBySaleNo(ORIGINAL_SALE_NO);
    Order returnOrder = orderBySaleNo(RETURN_SALE_NO);
    Order otherReturnOrder = orderBySaleNo(OTHER_RETURN_SALE_NO);
    insertCreditLedger(member, otherReturnOrder.Id, null, 'Purchase Accrual', 25);

    Test.startTest();
    GdOptionCPointAdjustmentUtil.AccrualCancelResult result = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
      member.Id,
      member.ProgramId,
      originalOrder.Id,
      returnOrder.Id,
      20,
      'second pass'
    );
    Test.stopTest();

    System.assertEquals(true, result.success, assertionMessage(result));
    System.assertEquals(20, result.actualPoints);
    System.assertEquals(0, result.loss);
  }

  private static LoyaltyProgramMember testMember() {
    return [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE MembershipNumber = :MEMBER_NO LIMIT 1];
  }

  private static String assertionMessage(GdOptionCPointAdjustmentUtil.AccrualCancelResult result) {
    return result == null || result.error == null ? 'unexpected failure' : result.error;
  }

  private static Order orderBySaleNo(String saleNo) {
    return [SELECT Id, SaleNo__c FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
  }

  private static Id journalTypeId(String name) {
    return [SELECT Id FROM JournalType WHERE Name = :name LIMIT 1].Id;
  }

  private static JournalSubType journalSubType(String name) {
    return [SELECT Id, JournalTypeId FROM JournalSubType WHERE Name = :name LIMIT 1];
  }

  private static LoyaltyProgramCurrency pointCurrency() {
    return [SELECT Id FROM LoyaltyProgramCurrency WHERE Name = '\uD3EC\uC778\uD2B8' LIMIT 1];
  }

  private static LoyaltyPgmCurrencySubtype optionCSubtype() {
    return [SELECT Id FROM LoyaltyPgmCurrencySubtype WHERE PointTypeCode__c = '04' LIMIT 1];
  }

  private static TransactionJournal insertJournal(LoyaltyProgramMember member, Id orderId, Id saleId, String journalSubTypeName, Decimal amount) {
    JournalSubType subType = journalSubType(journalSubTypeName);
    TransactionJournal journal = new TransactionJournal(
      MemberId = member.Id,
      LoyaltyProgramId = member.ProgramId,
      OrderId = orderId,
      SaleId__c = saleId,
      JournalDate = Datetime.now(),
      ActivityDate = Datetime.now(),
      JournalTypeId = subType.JournalTypeId,
      JournalSubTypeId = subType.Id,
      TransactionAmount = amount,
      Status = 'Processed',
      InsertId__c = 'TESTER'
    );
    insert journal;
    return journal;
  }

  private static LoyaltyLedger insertCreditLedger(LoyaltyProgramMember member, Id orderId, Id saleId, String journalSubTypeName, Decimal points) {
    TransactionJournal journal = insertJournal(member, orderId, saleId, journalSubTypeName, points);
    LoyaltyLedger ledger = new LoyaltyLedger(
      LoyaltyProgramMemberId = member.Id,
      LoyaltyProgramCurrencyId = pointCurrency().Id,
      LoyaltyPgmCrcySubtypeId = optionCSubtype().Id,
      TransactionJournalId = journal.Id,
      ActivityDate = Datetime.now().addDays(-2),
      Points = points,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert ledger;
    return ledger;
  }

  private static void insertPriorTrace(LoyaltyProgramMember member, LoyaltyLedger creditLedger, String actionType, Decimal points) {
    TransactionJournal debitJournal = insertJournal(member, null, null, 'Point Debit', points);
    LoyaltyLedger debitLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = member.Id,
      LoyaltyProgramCurrencyId = pointCurrency().Id,
      LoyaltyPgmCrcySubtypeId = optionCSubtype().Id,
      TransactionJournalId = debitJournal.Id,
      ActivityDate = Datetime.now().addDays(-1),
      Points = points,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit'
    );
    insert debitLedger;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = member.Id,
      LoyaltyProgramCurrencyId = pointCurrency().Id,
      LoyaltyPgmCurrencySubtypeId = optionCSubtype().Id,
      Points = points,
      ActionType = actionType,
      DebitLoyaltyLedgerId = debitLedger.Id,
      CreditLoyaltyLedgerId = creditLedger.Id
    );
  }
}