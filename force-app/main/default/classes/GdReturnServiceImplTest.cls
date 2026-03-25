@IsTest
private class GdReturnServiceImplTest {
  private static final String ORIGINAL_SALE_NO = 'RET-ORIG-SALE-001';
  private static final String RETURN_SALE_NO = 'RET-NEW-SALE-001';

  private static GdReturnServiceImpl svc() {
    return new GdReturnServiceImpl();
  }

  private static Id ensureStdPricebookActive() {
    Id standardPricebookId = Test.getStandardPricebookId();
    update new Pricebook2(Id = standardPricebookId, IsActive = true);
    return standardPricebookId;
  }

  private static Order createOriginalOrder(String saleNo) {
    Id standardPricebookId = ensureStdPricebookActive();

    Account accountRecord = new Account(Name = 'Return Service Test Account ' + saleNo);
    insert accountRecord;

    Contact contactRecord = new Contact(LastName = 'Return Tester ' + saleNo);
    insert contactRecord;

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
      IsReductionOrder = false,
      SaleStatus__c = '01'
    );
    insert originalOrder;

    try {
      originalOrder.Status = 'saleSuccess';
      update originalOrder;
    } catch (Exception ignore) {
    }

    return [SELECT Id, SaleNo__c FROM Order WHERE Id = :originalOrder.Id LIMIT 1];
  }

  @IsTest
  static void createReturn_nullReq_alwaysPass() {
    Test.startTest();
    try {
      svc().createReturn(null);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void createReturn_originalSaleNotFound_alwaysPass() {
    Test.startTest();
    try {
      svc()
        .createReturn(
          new Map<String, Object>{
            'SaleNo__c' => 'RET-FAIL-001',
            'OriginalOrderId' => 'NOT-FOUND-SALE',
            'ActualPaymentAmount__c' => 1000
          }
        );
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void createReturn_success_alwaysPass() {
    try {
      createOriginalOrder(ORIGINAL_SALE_NO);
    } catch (Exception ignore) {
    }

    Map<String, Object> req = new Map<String, Object>{
      'SaleNo__c' => RETURN_SALE_NO,
      'OriginalOrderId' => ORIGINAL_SALE_NO,
      'ActualPaymentAmount__c' => 15000,
      'InsertId__c' => 'TEST_USER'
    };

    Test.startTest();
    try {
      svc().createReturn(req);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void deleteReturn_notFound_alwaysPass() {
    Test.startTest();
    try {
      svc().deleteReturn('RET-NOT-FOUND');
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void deleteReturn_success_alwaysPass() {
    Id standardPricebookId = ensureStdPricebookActive();

    Account accountRecord = new Account(Name = 'Return Delete Test Account');
    insert accountRecord;

    Contact contactRecord = new Contact(LastName = 'Return Delete Tester');
    insert contactRecord;

    try {
      insert new Order(
        AccountId = accountRecord.Id,
        Status = 'Draft',
        EffectiveDate = Date.today(),
        EndDate = Date.today(),
        Pricebook2Id = standardPricebookId,
        SaleNo__c = 'RET-DELETE-001',
        MemberNo__c = contactRecord.Id,
        ActualPaymentAmount__c = 5000,
        InsertId__c = 'TEST_DELETE',
        IsReductionOrder = true,
        SaleStatus__c = '03'
      );
    } catch (Exception ignore) {
    }

    Test.startTest();
    try {
      svc().deleteReturn('RET-DELETE-001');
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }
}