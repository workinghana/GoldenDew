@IsTest
private class PointLedgerUIControllerV1Test {
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"ok":true}');
      return res;
    }
  }

  private static void setupCalloutMock() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());
  }

  private static String pickFirst(List<Schema.PicklistEntry> entries, String fallbackValue) {
    return (entries != null && !entries.isEmpty()) ? entries[0].getValue() : fallbackValue;
  }

  private static String resolveCurrencyType() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('NonQualifying')) {
        return entry.getValue();
      }
    }
    return pickFirst(LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues(), 'NonQualifying');
  }

  private static String resolveExpiryModel() {
    for (Schema.PicklistEntry entry : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
      if (entry.getValue().equalsIgnoreCase('Fixed')) {
        return entry.getValue();
      }
    }
    return pickFirst(LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues(), null);
  }

  private static String resolveExpiryUnit() {
    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      String value = entry.getValue().toLowerCase();
      if (value.contains('year') || value.contains('month')) {
        return entry.getValue();
      }
    }
    return pickFirst(entries, null);
  }

  private static String resolveExtendExpiration() {
    List<Schema.PicklistEntry> entries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
    for (Schema.PicklistEntry entry : entries) {
      String value = entry.getValue().toLowerCase();
      if (value.contains('none') || value.contains('expir')) {
        return entry.getValue();
      }
    }
    return pickFirst(entries, null);
  }

  private static Map<String, Id> setupCoreData(String membershipNumber) {
    setupCalloutMock();

    Contact contact = new Contact(LastName = 'Tester-' + membershipNumber, MemberNo__c = membershipNumber);
    insert contact;

    LoyaltyProgram program = new LoyaltyProgram(Name = 'Point Ledger Program ' + membershipNumber, IsPrimary = true);
    insert program;

    LoyaltyProgramMember member = new LoyaltyProgramMember(
      MembershipNumber = membershipNumber,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = contact.Id,
      EnrollmentDate = Date.today(),
      ProgramId = program.Id
    );
    insert member;

    LoyaltyProgramCurrency programCurrency = new LoyaltyProgramCurrency(
      Name = 'Point Currency ' + membershipNumber,
      LoyaltyProgramId = program.Id,
      CurrencyType = resolveCurrencyType(),
      IsActive = true,
      IsPrimary = true,
      ExpiryModel = resolveExpiryModel(),
      ExtendExpiration = resolveExtendExpiration(),
      ExpiryPeriodFrequency = 12,
      ExpiryPeriodUnit = resolveExpiryUnit(),
      CostperUnit = 1,
      HasEscrow = false,
      DoesAllowLedgerTracing = true
    );
    insert programCurrency;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      Name = 'Purchase Points ' + membershipNumber,
      LoyaltyProgramCurrencyId = programCurrency.Id,
      PointTypeCode__c = pickFirst(LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues(), '02'),
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subtype;

    Account account = new Account(Name = 'Account ' + membershipNumber);
    insert account;

    Product2 product = new Product2(Name = 'Product ' + membershipNumber, IsActive = true);
    insert product;

    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = product.Id, UnitPrice = 100, IsActive = true);
    insert pbe;

    Order orderRecord = new Order(
      AccountId = account.Id,
      Pricebook2Id = Test.getStandardPricebookId(),
      Status = 'Draft',
      EffectiveDate = Date.today(),
      SaleNo__c = 'SALE-' + membershipNumber,
      ActualPaymentAmount__c = 1000,
      MemberNo__c = contact.Id
    );
    insert orderRecord;

    insert new OrderItem(OrderId = orderRecord.Id, Quantity = 1, UnitPrice = 100, PricebookEntryId = pbe.Id);

    Map<String, Id> ids = new Map<String, Id>();
    ids.put('contactId', contact.Id);
    ids.put('memberId', member.Id);
    ids.put('programId', program.Id);
    ids.put('currencyId', programCurrency.Id);
    ids.put('subtypeId', subtype.Id);
    ids.put('orderId', orderRecord.Id);
    return ids;
  }

  private static TransactionJournal createJournal(
    Id memberId,
    Id programId,
    Id orderId,
    String journalTypeName,
    String journalSubTypeName,
    String paymentMethod,
    Decimal amount
  ) {
    JournalType journalType = new JournalType(Name = journalTypeName + String.valueOf(Crypto.getRandomInteger()), ProcessType = 'Loyalty');
    insert journalType;

    JournalSubType journalSubType = new JournalSubType(
      Name = journalSubTypeName + String.valueOf(Crypto.getRandomInteger()),
      JournalTypeId = journalType.Id
    );
    insert journalSubType;

    TransactionJournal journal = new TransactionJournal(
      MemberId = memberId,
      LoyaltyProgramId = programId,
      OrderId = orderId,
      ActivityDate = Datetime.now(),
      JournalDate = Datetime.now(),
      JournalTypeId = journalType.Id,
      JournalSubTypeId = journalSubType.Id,
      PaymentMethod = paymentMethod,
      TransactionAmount = amount,
      Status = 'Processed'
    );
    insert journal;

    return journal;
  }

  private static TransactionJournal createJournalWithExactSubtypeName(
    Id memberId,
    Id programId,
    Id orderId,
    String journalTypeName,
    String journalSubTypeName,
    String paymentMethod,
    Decimal amount
  ) {
    JournalType journalType = new JournalType(Name = journalTypeName + String.valueOf(Crypto.getRandomInteger()), ProcessType = 'Loyalty');
    insert journalType;

    JournalSubType journalSubType = new JournalSubType(Name = journalSubTypeName, JournalTypeId = journalType.Id);
    insert journalSubType;

    TransactionJournal journal = new TransactionJournal(
      MemberId = memberId,
      LoyaltyProgramId = programId,
      OrderId = orderId,
      ActivityDate = Datetime.now(),
      JournalDate = Datetime.now(),
      JournalTypeId = journalType.Id,
      JournalSubTypeId = journalSubType.Id,
      PaymentMethod = paymentMethod,
      TransactionAmount = amount,
      Status = 'Processed'
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

  private static void createTraceability(
    Id memberId,
    Id currencyId,
    Id subtypeId,
    Id creditLedgerId,
    Id debitLedgerId,
    String actionType,
    Decimal points
  ) {
    LoyaltyLedgerTraceability traceability = new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = memberId,
      LoyaltyProgramCurrencyId = currencyId,
      CreditLoyaltyLedgerId = creditLedgerId,
      DebitLoyaltyLedgerId = debitLedgerId,
      ActionType = actionType,
      Points = points
    );

    if (subtypeId != null) {
      traceability.LoyaltyPgmCurrencySubtypeId = subtypeId;
    }

    insert traceability;
  }

  @IsTest
  static void testGetPointLedgerRows_nullInput() {
    Test.startTest();
    List<PointLedgerUIControllerV1.PointLedgerRowDTO> rows = PointLedgerUIControllerV1.getPointLedgerRows(null, null);
    Test.stopTest();

    System.assertNotEquals(null, rows);
    System.assertEquals(0, rows.size());
  }

  @IsTest
  static void testResolveLoyaltyProgramMemberId_nullInput() {
    Test.startTest();
    Id resolvedId = PointLedgerUIControllerV1.resolveLoyaltyProgramMemberId(null);
    Test.stopTest();

    System.assertEquals(null, resolvedId);
  }

  @IsTest
  static void testResolveLoyaltyProgramMemberId_memberRecord() {
    Map<String, Id> ids = setupCoreData('PLM-RESOLVE-MEMBER');

    Test.startTest();
    Id resolvedId = PointLedgerUIControllerV1.resolveLoyaltyProgramMemberId(ids.get('memberId'));
    Test.stopTest();

    System.assertEquals(ids.get('memberId'), resolvedId);
  }

  @IsTest
  static void testResolveLoyaltyProgramMemberId_orderRecord() {
    Map<String, Id> ids = setupCoreData('PLM-RESOLVE-ORDER');

    Test.startTest();
    Id resolvedId = PointLedgerUIControllerV1.resolveLoyaltyProgramMemberId(ids.get('orderId'));
    Test.stopTest();

    System.assertEquals(ids.get('memberId'), resolvedId);
  }

  @IsTest
  static void testResolveOrderId_orderRecord() {
    Map<String, Id> ids = setupCoreData('PLM-RESOLVE-ORDER-ID');

    Test.startTest();
    Id resolvedId = PointLedgerUIControllerV1.resolveOrderId(ids.get('orderId'));
    Test.stopTest();

    System.assertEquals(ids.get('orderId'), resolvedId);
  }

  @IsTest
  static void testResolveOrderId_nonOrderRecord() {
    Map<String, Id> ids = setupCoreData('PLM-RESOLVE-NON-ORDER');

    Test.startTest();
    Id resolvedId = PointLedgerUIControllerV1.resolveOrderId(ids.get('memberId'));
    Test.stopTest();

    System.assertEquals(null, resolvedId);
  }

  @IsTest
  static void testGetPointLedgerRows_emptyResult() {
    Map<String, Id> ids = setupCoreData('PLM-EMPTY');

    Test.startTest();
    List<PointLedgerUIControllerV1.PointLedgerRowDTO> rows = PointLedgerUIControllerV1.getPointLedgerRows(ids.get('memberId'), null);
    Test.stopTest();

    System.assertNotEquals(null, rows);
    System.assertEquals(0, rows.size());
  }

  @IsTest
  static void testGetPointLedgerRows_success() {
    Map<String, Id> ids = setupCoreData('PLM-SUCCESS');

    TransactionJournal creditJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'Accrual',
      'Purchase Accrual',
      '10',
      1000
    );
    createLedger(creditJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Credit', 1000, Date.today().addYears(1));

    TransactionJournal debitJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'Redemption',
      'Point Debit',
      '81',
      200
    );
    createLedger(debitJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Debit', -200, null);

    TransactionJournal expiryJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'Expiration',
      'Auto Expire',
      null,
      0
    );
    createLedger(expiryJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Expiry', -100, null);

    createJournal(ids.get('memberId'), ids.get('programId'), ids.get('orderId'), 'PaymentCoupon', 'Coupon Payment', '90', 300);
    createJournal(ids.get('memberId'), ids.get('programId'), ids.get('orderId'), 'PaymentPoint', 'Point Payment', '81', 200);
    createJournal(ids.get('memberId'), ids.get('programId'), ids.get('orderId'), 'PaymentHq', 'HQ Payment', '93', 100);

    Test.startTest();
    List<PointLedgerUIControllerV1.PointLedgerRowDTO> rows = PointLedgerUIControllerV1.getPointLedgerRows(ids.get('memberId'), ids.get('orderId'));
    Test.stopTest();

    System.assertNotEquals(null, rows);
    System.assert(rows.size() > 0);

    PointLedgerUIControllerV1.PointLedgerRowDTO firstRow = rows[0];
    System.assertNotEquals(null, firstRow.ledgerId);
    System.assertNotEquals(null, firstRow.pointTypeName);
    System.assert(firstRow.accruedPoints >= 0);
    System.assert(firstRow.usedPoints >= 0);
    System.assert(firstRow.expiredPoints >= 0);
    System.assert(firstRow.depositCouponAmount >= 0);
    System.assert(firstRow.depositPointAmount >= 0);
    System.assert(firstRow.depositHqExchangeAmount >= 0);
  }

  @IsTest
  static void testGetPointLedgerRows_filtersByOrderId() {
    Map<String, Id> ids = setupCoreData('PLM-ORDER-FILTER');

    Order secondOrder = new Order(
      AccountId = [
        SELECT AccountId
        FROM Order
        WHERE Id = :ids.get('orderId')
      ]
      .AccountId,
      Pricebook2Id = Test.getStandardPricebookId(),
      Status = 'Draft',
      EffectiveDate = Date.today(),
      SaleNo__c = 'SALE-ORDER-FILTER-2',
      ActualPaymentAmount__c = 2000,
      MemberNo__c = ids.get('contactId')
    );
    insert secondOrder;

    TransactionJournal firstOrderJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'AccrualFilterA',
      'Purchase Accrual',
      '10',
      1000
    );
    createLedger(firstOrderJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Credit', 1000, Date.today().addYears(1));

    TransactionJournal secondOrderJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      secondOrder.Id,
      'AccrualFilterB',
      'Purchase Accrual',
      '10',
      2000
    );
    createLedger(secondOrderJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Credit', 2000, Date.today().addYears(1));

    Test.startTest();
    List<PointLedgerUIControllerV1.PointLedgerRowDTO> rows = PointLedgerUIControllerV1.getPointLedgerRows(ids.get('memberId'), ids.get('orderId'));
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals('SALE-PLM-ORDER-FILTER', rows[0].saleNo);
    System.assertEquals(1000, rows[0].accruedPoints);
  }

  @IsTest
  static void testGetPointLedgerRows_excludesCouponCancelFromDepositSummary() {
    Map<String, Id> ids = setupCoreData('PLM-COUPON-CANCEL');

    TransactionJournal creditJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'AccrualCouponCancel',
      'Purchase Accrual',
      '10',
      1000
    );
    createLedger(creditJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Credit', 1000, Date.today().addYears(1));

    createJournalWithExactSubtypeName(ids.get('memberId'), ids.get('programId'), ids.get('orderId'), 'CouponRedeem', 'Coupon Payment', '90', 300);
    createJournalWithExactSubtypeName(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'CouponRedeemCancel',
      'Coupon Redeem Cancel',
      '90',
      300
    );

    Test.startTest();
    List<PointLedgerUIControllerV1.PointLedgerRowDTO> rows = PointLedgerUIControllerV1.getPointLedgerRows(ids.get('memberId'), ids.get('orderId'));
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals(300, rows[0].depositCouponAmount);
  }

  @IsTest
  static void testGetPointLedgerRows_excludesCancelPurchaseAccrualRow() {
    Map<String, Id> ids = setupCoreData('PLM-CANCEL-ACCRUAL');

    TransactionJournal creditJournal = createJournalWithExactSubtypeName(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'AccrualCancelA',
      'Purchase Accrual',
      '10',
      1000
    );
    createLedger(creditJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Credit', 1000, Date.today().addYears(1));

    TransactionJournal cancelJournal = createJournalWithExactSubtypeName(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'AccrualCancelB',
      'Cancel Purchase Accrual',
      '10',
      1000
    );
    createLedger(cancelJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Debit', -1000, Date.today().addYears(1));

    Test.startTest();
    List<PointLedgerUIControllerV1.PointLedgerRowDTO> rows = PointLedgerUIControllerV1.getPointLedgerRows(ids.get('memberId'), ids.get('orderId'));
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals(1000, rows[0].accruedPoints);
  }

  @IsTest
  static void testGetPointLedgerRows_excludesPointRedeemCancelCreditRow() {
    Map<String, Id> ids = setupCoreData('PLM-PRC-CREDIT');

    TransactionJournal accrualJournal = createJournalWithExactSubtypeName(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'AccrualKeep',
      'Purchase Accrual',
      '10',
      1000
    );
    createLedger(accrualJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Credit', 1000, Date.today().addYears(1));

    TransactionJournal pointRedeemCancelJournal = createJournalWithExactSubtypeName(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'RedeemCancelKeepOut',
      'Point Redeem Cancel',
      '81',
      500
    );
    createLedger(
      pointRedeemCancelJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Credit',
      500,
      Date.today().addYears(1)
    );

    Test.startTest();
    List<PointLedgerUIControllerV1.PointLedgerRowDTO> rows = PointLedgerUIControllerV1.getPointLedgerRows(ids.get('memberId'), ids.get('orderId'));
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals(1000, rows[0].accruedPoints);
  }

  @IsTest
  static void testGetPointRedemptionRows_nullInput() {
    Test.startTest();
    List<PointLedgerUIControllerV1.PointRedemptionRowDTO> rows = PointLedgerUIControllerV1.getPointRedemptionRows(null, null);
    Test.stopTest();

    System.assertNotEquals(null, rows);
    System.assertEquals(0, rows.size());
  }

  @IsTest
  static void testGetPointRedemptionRows_emptyResult() {
    Map<String, Id> ids = setupCoreData('PRM-EMPTY');

    Test.startTest();
    List<PointLedgerUIControllerV1.PointRedemptionRowDTO> rows = PointLedgerUIControllerV1.getPointRedemptionRows(ids.get('memberId'), null);
    Test.stopTest();

    System.assertNotEquals(null, rows);
    System.assertEquals(0, rows.size());
  }

  @IsTest
  static void testGetPointRedemptionRows_success() {
    Map<String, Id> ids = setupCoreData('PRM-SUCCESS');

    TransactionJournal creditJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'Accrual',
      'Purchase Accrual',
      '10',
      1000
    );
    LoyaltyLedger creditLedger = createLedger(
      creditJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Credit',
      1000,
      Date.today().addYears(1)
    );

    TransactionJournal debitJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'Redemption',
      'Point Debit',
      '81',
      200
    );
    LoyaltyLedger debitLedger = createLedger(debitJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Debit', -200, null);

    TransactionJournal cancelJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'RedemptionCancel',
      'Point Redeem Cancel',
      '81',
      200
    );
    LoyaltyLedger cancelLedger = createLedger(
      cancelJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Debit',
      -200,
      null
    );

    createTraceability(ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), creditLedger.Id, debitLedger.Id, 'Debit', 200);
    createTraceability(ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), creditLedger.Id, cancelLedger.Id, 'DebitCancellation', 200);
    createTraceability(ids.get('memberId'), ids.get('currencyId'), null, creditLedger.Id, debitLedger.Id, 'Debit', 50);

    Test.startTest();
    List<PointLedgerUIControllerV1.PointRedemptionRowDTO> rows = PointLedgerUIControllerV1.getPointRedemptionRows(
      ids.get('memberId'),
      ids.get('orderId')
    );
    Test.stopTest();

    System.assertNotEquals(null, rows);
    System.assert(rows.size() > 0);

    Boolean hasCancelRow = false;
    Boolean hasNormalRow = false;

    for (PointLedgerUIControllerV1.PointRedemptionRowDTO row : rows) {
      System.assertNotEquals(null, row.ledgerId);
      System.assert(row.redemptionPoints >= 0);

      if (row.isCancel == true) {
        hasCancelRow = true;
      } else {
        hasNormalRow = true;
      }
    }

    System.assertEquals(true, hasCancelRow);
    System.assertEquals(true, hasNormalRow);
  }

  @IsTest
  static void testGetPointRedemptionRows_filtersByOrderId() {
    Map<String, Id> ids = setupCoreData('PRM-ORDER-FILTER');

    Order secondOrder = new Order(
      AccountId = [
        SELECT AccountId
        FROM Order
        WHERE Id = :ids.get('orderId')
      ]
      .AccountId,
      Pricebook2Id = Test.getStandardPricebookId(),
      Status = 'Draft',
      EffectiveDate = Date.today(),
      SaleNo__c = 'SALE-PRM-ORDER-FILTER-2',
      ActualPaymentAmount__c = 3000,
      MemberNo__c = ids.get('contactId')
    );
    insert secondOrder;

    TransactionJournal firstCreditJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'AccrualFilterCreditA',
      'Purchase Accrual',
      '10',
      1000
    );
    LoyaltyLedger firstCreditLedger = createLedger(
      firstCreditJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Credit',
      1000,
      Date.today().addYears(1)
    );

    TransactionJournal firstDebitJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'RedemptionFilterDebitA',
      'Point Debit',
      '81',
      200
    );
    LoyaltyLedger firstDebitLedger = createLedger(
      firstDebitJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Debit',
      -200,
      null
    );
    createTraceability(ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), firstCreditLedger.Id, firstDebitLedger.Id, 'Debit', 200);

    TransactionJournal secondCreditJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      secondOrder.Id,
      'AccrualFilterCreditB',
      'Purchase Accrual',
      '10',
      2000
    );
    LoyaltyLedger secondCreditLedger = createLedger(
      secondCreditJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Credit',
      2000,
      Date.today().addYears(1)
    );

    TransactionJournal secondDebitJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      secondOrder.Id,
      'RedemptionFilterDebitB',
      'Point Debit',
      '81',
      300
    );
    LoyaltyLedger secondDebitLedger = createLedger(
      secondDebitJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Debit',
      -300,
      null
    );
    createTraceability(ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), secondCreditLedger.Id, secondDebitLedger.Id, 'Debit', 300);

    Test.startTest();
    List<PointLedgerUIControllerV1.PointRedemptionRowDTO> rows = PointLedgerUIControllerV1.getPointRedemptionRows(
      ids.get('memberId'),
      ids.get('orderId')
    );
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals('SALE-PRM-ORDER-FILTER', rows[0].saleNo);
    System.assertEquals(200, rows[0].redemptionPoints);
  }

  @IsTest
  static void testGetPointRedemptionRows_includesExpiryAsDestruction() {
    Map<String, Id> ids = setupCoreData('PRM-EXPIRY');

    TransactionJournal expiryJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'ExpiryOnly',
      'Auto Expire',
      null,
      0
    );
    createLedger(expiryJournal.Id, ids.get('memberId'), ids.get('currencyId'), ids.get('subtypeId'), 'Expiry', -150, Date.today().addDays(5));

    Test.startTest();
    List<PointLedgerUIControllerV1.PointRedemptionRowDTO> rows = PointLedgerUIControllerV1.getPointRedemptionRows(
      ids.get('memberId'),
      ids.get('orderId')
    );
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals('Purchase Points PRM-EXPIRY', rows[0].pointTypeName);
    System.assertEquals('소멸', rows[0].redemptionType);
    System.assertEquals(150, rows[0].redemptionPoints);
    System.assertEquals(Date.today().addDays(5), rows[0].redemptionDate);
    System.assertEquals(false, rows[0].isCancel);
  }

  @IsTest
  static void testGetPointRedemptionRows_includesCreditCancellationAsAccrualCancel() {
    Map<String, Id> ids = setupCoreData('PRM-CREDIT-CANCEL');

    TransactionJournal creditJournal = createJournal(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'AccrualCreditCancel',
      'Purchase Accrual',
      '10',
      1000
    );
    LoyaltyLedger creditLedger = createLedger(
      creditJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Credit',
      1000,
      Date.today().addYears(1)
    );

    TransactionJournal cancelJournal = createJournalWithExactSubtypeName(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'AccrualReversalCreditCancel',
      'Cancel Purchase Accrual',
      '10',
      1000
    );
    LoyaltyLedger cancelLedger = createLedger(
      cancelJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Debit',
      -1000,
      Date.today().addYears(1)
    );
    createTraceability(
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      creditLedger.Id,
      cancelLedger.Id,
      'CreditCancellation',
      1000
    );

    Test.startTest();
    List<PointLedgerUIControllerV1.PointRedemptionRowDTO> rows = PointLedgerUIControllerV1.getPointRedemptionRows(
      ids.get('memberId'),
      ids.get('orderId')
    );
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals('적립취소', rows[0].redemptionType);
    System.assertEquals(1000, rows[0].redemptionPoints);
    System.assertEquals(false, rows[0].isCancel);
  }
  @IsTest
  static void testGetPointRedemptionRows_includesPointRedeemCancelCreditAsUsageCancel() {
    Map<String, Id> ids = setupCoreData('PRM-REDEEM-CANCEL-CREDIT');

    TransactionJournal pointRedeemCancelJournal = createJournalWithExactSubtypeName(
      ids.get('memberId'),
      ids.get('programId'),
      ids.get('orderId'),
      'RedeemCancelOnly',
      'Point Redeem Cancel',
      '81',
      500
    );
    createLedger(
      pointRedeemCancelJournal.Id,
      ids.get('memberId'),
      ids.get('currencyId'),
      ids.get('subtypeId'),
      'Credit',
      500,
      Date.today().addYears(1)
    );

    Test.startTest();
    List<PointLedgerUIControllerV1.PointRedemptionRowDTO> rows = PointLedgerUIControllerV1.getPointRedemptionRows(
      ids.get('memberId'),
      ids.get('orderId')
    );
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals('사용취소', rows[0].redemptionType);
    System.assertEquals(500, rows[0].redemptionPoints);
    System.assertEquals(true, rows[0].isCancel);
    System.assertEquals('SALE-PRM-REDEEM-CANCEL-CREDIT', rows[0].saleNo);
  }
}
