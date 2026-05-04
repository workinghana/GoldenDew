@IsTest
private class GdReturnServiceImplTest {
  private static final String ORIGINAL_SALE_NO = 'RET-ORIG-SALE-001';
  private static final String RETURN_SALE_NO = 'RET-NEW-SALE-001';
  private static final String RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';

  private static GdReturnServiceImpl svc() {
    return new GdReturnServiceImpl();
  }

  private static Id ensureStdPricebookActive() {
    Id standardPricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = standardPricebookId, IsActive = true);
    return standardPricebookId;
  }

  private static Account createAccount(String suffix) {
    Account accountRecord = new Account(Name = 'Return Service Test Account ' + suffix);
    insert accountRecord;
    return accountRecord;
  }

  private static Contact createContact(String suffix) {
    Contact contactRecord = new Contact(LastName = 'Return Tester ' + suffix);
    insert contactRecord;
    return contactRecord;
  }

  private static Product2 createProduct(String suffix) {
    Product2 product = new Product2(Name = 'Return Product ' + suffix, ProductCode = 'RET-P-' + suffix, IsActive = true);
    insert product;
    return product;
  }

  private static Id createPricebookEntry(Id pricebook2Id, Id product2Id) {
    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebook2Id, Product2Id = product2Id, UnitPrice = 10000, IsActive = true);
    insert pbe;
    return pbe.Id;
  }

  private static Order createOriginalOrder(String saleNo) {
    Id standardPricebookId = ensureStdPricebookActive();
    Account accountRecord = createAccount(saleNo);
    Contact contactRecord = createContact(saleNo);
    Product2 product = createProduct(saleNo);
    Id pbeId = createPricebookEntry(standardPricebookId, product.Id);

    Order originalOrder = new Order(
      AccountId = accountRecord.Id,
      Status = 'Draft',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Pricebook2Id = standardPricebookId,
      SaleNo__c = saleNo,
      OrderNo__c = saleNo + '-ORD',
      MemberNo__c = contactRecord.Id,
      ActualPaymentAmount__c = 15000,
      InsertId__c = 'TEST_USER',
      IsReductionOrder__c = false,
      SaleStatus__c = '01'
    );
    insert originalOrder;

    insert new OrderItem(
      OrderId = originalOrder.Id,
      PricebookEntryId = pbeId,
      Quantity = 1,
      UnitPrice = 10000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = saleNo + '-ITEM-1'
    );

    originalOrder.Status = 'saleSuccess';
    update originalOrder;

    return [
      SELECT Id, AccountId, StoreCode__c, MemberNo__c, SaleNo__c, Pricebook2Id, Status
      FROM Order
      WHERE Id = :originalOrder.Id
      LIMIT 1
    ];
  }

  private static LoyaltyProgramMember createLoyaltyMember(Contact contactRecord, String suffix) {
    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Return Service Program ' + suffix, IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      MembershipNumber = 'RET-MBR-' + suffix,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = contactRecord.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert lpm;
    return lpm;
  }

  private static void createPointUsageTraceability(
    LoyaltyProgramMember lpm,
    Id creditOrderId,
    Id debitOrderId,
    String suffix,
    Boolean isDebitJournalDeleted,
    String debitAdditionalNotes
  ) {
    TransactionJournal originalCreditTj = new TransactionJournal(
      DepositNo__c = 'RET-CREDIT-' + suffix,
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = creditOrderId,
      TransactionAmount = 100,
      Status = 'Processed'
    );
    insert originalCreditTj;

    TransactionJournal debitUseTj = new TransactionJournal(
      DepositNo__c = 'RET-DEBIT-' + suffix,
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      LoyaltyProgramId = lpm.ProgramId,
      MemberId = lpm.Id,
      OrderId = debitOrderId,
      TransactionAmount = 100,
      Status = 'Processed',
      IsDeleted__c = isDebitJournalDeleted,
      AdditionalNotes__c = debitAdditionalNotes
    );
    insert debitUseTj;

    LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
      LoyaltyProgramId = lpm.ProgramId,
      Name = 'POINT-' + suffix,
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
    insert lpc;

    LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
      LoyaltyProgramCurrencyId = lpc.Id,
      Name = 'POINT-SUBTYPE-' + suffix,
      PointTypeCode__c = '01',
      UsagePriorityNumber = 1,
      IsActive = true
    );
    insert subtype;

    LoyaltyLedger creditLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = lpc.Id,
      LoyaltyPgmCrcySubtypeId = subtype.Id,
      TransactionJournalId = originalCreditTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Credit'
    );
    insert creditLedger;

    LoyaltyLedger debitLedger = new LoyaltyLedger(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyProgramCurrencyId = lpc.Id,
      LoyaltyPgmCrcySubtypeId = subtype.Id,
      TransactionJournalId = debitUseTj.Id,
      ActivityDate = Datetime.now(),
      Points = 100,
      ExpiryDate = Date.today().addYears(1),
      EventType = 'Debit'
    );
    insert debitLedger;

    insert new LoyaltyLedgerTraceability(
      LoyaltyProgramMemberId = lpm.Id,
      LoyaltyPgmCurrencySubtypeId = subtype.Id,
      DebitLoyaltyLedgerId = debitLedger.Id,
      CreditLoyaltyLedgerId = creditLedger.Id,
      Points = 100,
      ActionType = 'Debit'
    );
  }

  @IsTest
  static void createReturn_nullReq_throws() {
    Boolean thrown = false;

    Test.startTest();
    try {
      svc().createReturn(null);
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createReturn_originalSaleNotFound_throws() {
    Boolean thrown = false;

    Test.startTest();
    try {
      svc()
        .createReturn(
          new Map<String, Object>{
            'SaleNo__c' => 'RET-FAIL-001',
            'OriginalOrderId' => 'NOT-FOUND-SALE',
            'ActualPaymentAmount__c' => 1000,
            'InsertId__c' => 'TEST_USER'
          }
        );
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createReturn_success_createsReductionOrder() {
    Order originalOrder = createOriginalOrder(ORIGINAL_SALE_NO);

    Map<String, Object> req = new Map<String, Object>{
      'SaleNo__c' => RETURN_SALE_NO,
      'OriginalOrderId' => ORIGINAL_SALE_NO,
      'ActualPaymentAmount__c' => 15000,
      'InsertId__c' => 'TEST_USER'
    };

    Test.startTest();
    ApiResult result = svc().createReturn(req);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertNotEquals(null, result.data.get('orderId'));
    System.assertEquals(originalOrder.Id, result.data.get('originalOrderId'));

    Order createdReturn = [
      SELECT
        Id,
        AccountId,
        MemberNo__c,
        SaleNo__c,
        Status,
        SaleStatus__c,
        IsReductionOrder__c,
        OriginalOrderId__c,
        InsertId__c,
        ActualPaymentAmount__c
      FROM Order
      WHERE Id = :(Id) result.data.get('orderId')
      LIMIT 1
    ];
    System.assertEquals(RETURN_SALE_NO, createdReturn.SaleNo__c);
    System.assertEquals('Draft', createdReturn.Status);
    System.assertEquals('03', createdReturn.SaleStatus__c);
    System.assertEquals(true, createdReturn.IsReductionOrder__c);
    System.assertEquals(originalOrder.Id, createdReturn.OriginalOrderId__c);
    System.assertEquals(originalOrder.AccountId, createdReturn.AccountId);
    System.assertEquals(originalOrder.MemberNo__c, createdReturn.MemberNo__c);
    System.assertEquals('TEST_USER', createdReturn.InsertId__c);
    System.assertEquals(15000, createdReturn.ActualPaymentAmount__c);
  }

  @IsTest
  static void createReturn_withoutActualPaymentAmount_leavesAmountNull() {
    Order originalOrder = createOriginalOrder(ORIGINAL_SALE_NO + '-NULLAMT');

    Test.startTest();
    ApiResult result = svc()
      .createReturn(
        new Map<String, Object>{
          'SaleNo__c' => RETURN_SALE_NO + '-NULLAMT',
          'OriginalOrderId' => ORIGINAL_SALE_NO + '-NULLAMT',
          'InsertId__c' => 'TEST_USER'
        }
      );
    Test.stopTest();

    Order createdReturn = [
      SELECT ActualPaymentAmount__c
      FROM Order
      WHERE Id = :(Id) result.data.get('orderId')
      LIMIT 1
    ];
    System.assertEquals(null, createdReturn.ActualPaymentAmount__c);
    System.assertEquals(originalOrder.Id, result.data.get('originalOrderId'));
  }

  @IsTest
  static void createReturn_duplicateSaleNo_throws() {
    createOriginalOrder(ORIGINAL_SALE_NO + '-DUP');
    createOriginalOrder(RETURN_SALE_NO + '-DUP');

    Boolean thrown = false;

    Test.startTest();
    try {
      svc()
        .createReturn(
          new Map<String, Object>{
            'SaleNo__c' => RETURN_SALE_NO + '-DUP',
            'OriginalOrderId' => ORIGINAL_SALE_NO + '-DUP',
            'ActualPaymentAmount__c' => 15000,
            'InsertId__c' => 'TEST_USER'
          }
        );
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createReturn_whenOriginalPointsAlreadyUsed_throws() {
    Order originalOrder = createOriginalOrder(ORIGINAL_SALE_NO + '-USED');
    Contact originalContact = [
      SELECT Id
      FROM Contact
      WHERE Id = :originalOrder.MemberNo__c
      LIMIT 1
    ];
    LoyaltyProgramMember lpm = createLoyaltyMember(originalContact, 'USED');

    Id standardPricebookId = ensureStdPricebookActive();
    Account debitAccount = createAccount('USED-DEBIT');
    Contact debitContact = createContact('USED-DEBIT');
    Product2 debitProduct = createProduct('USED-DEBIT');
    Id debitPbeId = createPricebookEntry(standardPricebookId, debitProduct.Id);

    Order debitOrder = new Order(
      AccountId = debitAccount.Id,
      Status = 'Draft',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Pricebook2Id = standardPricebookId,
      SaleNo__c = 'RET-USED-DEBIT-SALE',
      OrderNo__c = 'RET-USED-DEBIT-ORD',
      MemberNo__c = debitContact.Id,
      ActualPaymentAmount__c = 5000,
      InsertId__c = 'TEST_USER',
      IsReductionOrder__c = false,
      SaleStatus__c = '01'
    );
    insert debitOrder;

    insert new OrderItem(
      OrderId = debitOrder.Id,
      PricebookEntryId = debitPbeId,
      Quantity = 1,
      UnitPrice = 5000,
      SaleSeqNo__c = '1',
      SaleItemNo__c = 'USED-DEBIT-ITEM-1'
    );

    debitOrder.Status = 'saleSuccess';
    update debitOrder;

    createPointUsageTraceability(lpm, originalOrder.Id, debitOrder.Id, 'USED-001', false, null);

    Boolean thrown = false;

    Test.startTest();
    try {
      svc()
        .createReturn(
          new Map<String, Object>{
            'SaleNo__c' => RETURN_SALE_NO + '-USED',
            'OriginalOrderId' => ORIGINAL_SALE_NO + '-USED',
            'ActualPaymentAmount__c' => 15000,
            'InsertId__c' => 'TEST_USER'
          }
        );
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createReturn_ignoresReturnDepositDeleteRestoreDebit() {
    Order originalOrder = createOriginalOrder(ORIGINAL_SALE_NO + '-RESTORE');
    Contact originalContact = [
      SELECT Id
      FROM Contact
      WHERE Id = :originalOrder.MemberNo__c
      LIMIT 1
    ];
    LoyaltyProgramMember lpm = createLoyaltyMember(originalContact, 'RESTORE');

    createPointUsageTraceability(lpm, originalOrder.Id, originalOrder.Id, 'RESTORE-001', false, RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE);

    Test.startTest();
    ApiResult result = svc()
      .createReturn(
        new Map<String, Object>{
          'SaleNo__c' => RETURN_SALE_NO + '-RESTORE',
          'OriginalOrderId' => ORIGINAL_SALE_NO + '-RESTORE',
          'ActualPaymentAmount__c' => 15000,
          'InsertId__c' => 'TEST_USER'
        }
      );
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertNotEquals(null, result.data.get('orderId'));
    System.assertEquals(originalOrder.Id, result.data.get('originalOrderId'));
  }

  @IsTest
  static void deleteReturn_notFound_throws() {
    Boolean thrown = false;

    Test.startTest();
    try {
      svc().deleteReturn('RET-NOT-FOUND');
    } catch (CustomException e) {
      thrown = true;
      System.assertEquals(400, e.code);
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteReturn_success_marksDeleted() {
    Id standardPricebookId = ensureStdPricebookActive();
    Account accountRecord = createAccount('DELETE');
    Contact contactRecord = createContact('DELETE');

    Order returnOrder = new Order(
      AccountId = accountRecord.Id,
      Status = 'Draft',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Pricebook2Id = standardPricebookId,
      SaleNo__c = 'RET-DELETE-001',
      MemberNo__c = contactRecord.Id,
      ActualPaymentAmount__c = 5000,
      InsertId__c = 'TEST_DELETE',
      IsReductionOrder__c = true,
      SaleStatus__c = '03'
    );
    insert returnOrder;

    Test.startTest();
    ApiResult result = svc().deleteReturn('RET-DELETE-001');
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(returnOrder.Id, result.data.get('orderId'));

    Order deletedOrder = [
      SELECT Id, IsDeleted__c, DeleteDateTime__c, Status
      FROM Order
      WHERE Id = :returnOrder.Id
      LIMIT 1
    ];
    System.assertEquals(true, deletedOrder.IsDeleted__c);
    System.assertNotEquals(null, deletedOrder.DeleteDateTime__c);
    System.assertEquals('returnDeletedDraft', deletedOrder.Status);
  }
}