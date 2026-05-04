@IsTest
private class GdReturnItemServiceImplTest {
  private static final String PRODUCT_CODE = 'RITEM-PROD-001';
  private static final String SALE_SEQ_NO = 'RISEQ-001';
  private static final String ORIG_ORDER_NO = 'RIORIG-ORDER-001';
  private static final String RET_ORDER_NO = 'RIRET-ORDER-001';

  @TestSetup
  static void setup() {
    Id stdPbId = Test.getStandardPricebookId();
    update new Pricebook2(Id = stdPbId, IsActive = true);

    Account acc = new Account(Name = 'ReturnItem Test Account');
    insert acc;

    Order originalOrder = new Order(
      AccountId = acc.Id,
      Status = 'Draft',
      EffectiveDate = Date.today(),
      Pricebook2Id = stdPbId,
      OrderNo__c = ORIG_ORDER_NO
    );
    insert originalOrder;

    Order returnOrder = new Order(
      AccountId = acc.Id,
      Status = 'Draft',
      EffectiveDate = Date.today(),
      Pricebook2Id = stdPbId,
      OrderNo__c = RET_ORDER_NO
    );
    insert returnOrder;

    Product2 prod = new Product2(Name = 'ReturnItem Test Product', ProductCode = PRODUCT_CODE, IsActive = true);
    insert prod;

    PricebookEntry pbe = new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = prod.Id, UnitPrice = 10000, IsActive = true);
    insert pbe;

    insert new OrderItem(OrderId = originalOrder.Id, PricebookEntryId = pbe.Id, Quantity = 2, UnitPrice = 10000, SaleSeqNo__c = SALE_SEQ_NO);
  }

  private static Order getOrder(String orderNo) {
    return [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
  }

  @IsTest
  static void createReturnItem_missingRequired_throws() {
    Boolean thrown = false;

    try {
      new GdReturnItemServiceImpl().createReturnItem(new Map<String, Object>());
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createReturnItem_success() {
    Order originalOrder = getOrder(ORIG_ORDER_NO);
    Order returnOrder = getOrder(RET_ORDER_NO);

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'OrderItem' => new List<Object>{ new Map<String, Object>{ 'SaleSeqNo__c' => SALE_SEQ_NO, 'ProductCode' => PRODUCT_CODE, 'Quantity' => 1 } }
    };

    Test.startTest();
    ApiResult result = new GdReturnItemServiceImpl().createReturnItem(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(1, [SELECT COUNT() FROM OrderItem WHERE OrderId = :returnOrder.Id AND SaleSeqNo__c = :SALE_SEQ_NO]);
  }

  @IsTest
  static void createReturnItem_success_withOrderNo() {
    Order originalOrder = getOrder(ORIG_ORDER_NO);
    Order returnOrder = getOrder(RET_ORDER_NO);

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'OrderItem' => new List<Object>{
        new Map<String, Object>{ 'SaleSeqNo__c' => SALE_SEQ_NO, 'ProductCode' => PRODUCT_CODE, 'Quantity' => 1, 'OrderNo__c' => ORIG_ORDER_NO }
      }
    };

    Test.startTest();
    ApiResult result = new GdReturnItemServiceImpl().createReturnItem(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);

    OrderItem createdItem = [
      SELECT Id, OrderId__c
      FROM OrderItem
      WHERE OrderId = :returnOrder.Id AND OrderId__c = :originalOrder.Id
      LIMIT 1
    ];
    System.assertNotEquals(null, createdItem.Id);
  }

  @IsTest
  static void createReturnItem_success_multipleItems() {
    Id stdPbId = Test.getStandardPricebookId();
    Product2 secondProduct = new Product2(Name = 'ReturnItem Test Product 2', ProductCode = 'RITEM-PROD-002', IsActive = true);
    insert secondProduct;
    PricebookEntry secondPbe = new PricebookEntry(Pricebook2Id = stdPbId, Product2Id = secondProduct.Id, UnitPrice = 7000, IsActive = true);
    insert secondPbe;

    Order originalOrder = getOrder(ORIG_ORDER_NO);
    Order returnOrder = getOrder(RET_ORDER_NO);

    insert new OrderItem(OrderId = originalOrder.Id, PricebookEntryId = secondPbe.Id, Quantity = 1, UnitPrice = 7000, SaleSeqNo__c = 'RISEQ-002');

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'OrderItem' => new List<Object>{
        new Map<String, Object>{ 'SaleSeqNo__c' => SALE_SEQ_NO, 'ProductCode' => PRODUCT_CODE, 'Quantity' => 1 },
        new Map<String, Object>{ 'SaleSeqNo__c' => 'RISEQ-002', 'ProductCode' => 'RITEM-PROD-002', 'Quantity' => 1 }
      }
    };

    Test.startTest();
    ApiResult result = new GdReturnItemServiceImpl().createReturnItem(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(2, [SELECT COUNT() FROM OrderItem WHERE OrderId = :returnOrder.Id]);
  }

  @IsTest
  static void createReturnItem_success_sameProductRepeatedItems() {
    Id stdPbId = Test.getStandardPricebookId();
    PricebookEntry sameProductPbe = [
      SELECT Id
      FROM PricebookEntry
      WHERE Pricebook2Id = :stdPbId AND Product2.ProductCode = :PRODUCT_CODE
      LIMIT 1
    ];
    Order originalOrder = getOrder(ORIG_ORDER_NO);
    Order returnOrder = getOrder(RET_ORDER_NO);

    insert new OrderItem(
      OrderId = originalOrder.Id,
      PricebookEntryId = sameProductPbe.Id,
      Quantity = 1,
      UnitPrice = 10000,
      SaleSeqNo__c = 'RISEQ-003'
    );

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'OrderItem' => new List<Object>{
        new Map<String, Object>{ 'SaleSeqNo__c' => SALE_SEQ_NO, 'ProductCode' => PRODUCT_CODE, 'Quantity' => -1 },
        new Map<String, Object>{ 'SaleSeqNo__c' => 'RISEQ-003', 'ProductCode' => PRODUCT_CODE, 'Quantity' => -1 }
      }
    };

    Test.startTest();
    ApiResult result = new GdReturnItemServiceImpl().createReturnItem(reqData);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(2, [SELECT COUNT() FROM OrderItem WHERE OrderId = :returnOrder.Id AND Product2.ProductCode = :PRODUCT_CODE]);
  }

  @IsTest
  static void createReturnItem_productNotFound_throws() {
    Order originalOrder = getOrder(ORIG_ORDER_NO);
    Order returnOrder = getOrder(RET_ORDER_NO);
    Boolean thrown = false;

    Test.startTest();
    try {
      new GdReturnItemServiceImpl()
        .createReturnItem(
          new Map<String, Object>{
            'orderId' => returnOrder.Id,
            'originalOrderId' => originalOrder.Id,
            'OrderItem' => new List<Object>{
              new Map<String, Object>{ 'SaleSeqNo__c' => SALE_SEQ_NO, 'ProductCode' => 'NONEXISTENT-9999', 'Quantity' => 1 }
            }
          }
        );
    } catch (CustomException e) {
      thrown = true;
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createReturnItem_pricebookEntryNotFound_throws() {
    insert new Product2(Name = 'No PBE Product', ProductCode = 'RI-NO-PBE-001', IsActive = true);

    Order originalOrder = getOrder(ORIG_ORDER_NO);
    Order returnOrder = getOrder(RET_ORDER_NO);
    Boolean thrown = false;

    Test.startTest();
    try {
      new GdReturnItemServiceImpl()
        .createReturnItem(
          new Map<String, Object>{
            'orderId' => returnOrder.Id,
            'originalOrderId' => originalOrder.Id,
            'OrderItem' => new List<Object>{
              new Map<String, Object>{ 'SaleSeqNo__c' => SALE_SEQ_NO, 'ProductCode' => 'RI-NO-PBE-001', 'Quantity' => 1 }
            }
          }
        );
    } catch (CustomException e) {
      thrown = true;
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createReturnItem_originalItemNotFound_throws() {
    Order originalOrder = getOrder(ORIG_ORDER_NO);
    Order returnOrder = getOrder(RET_ORDER_NO);
    Boolean thrown = false;

    Test.startTest();
    try {
      new GdReturnItemServiceImpl()
        .createReturnItem(
          new Map<String, Object>{
            'orderId' => returnOrder.Id,
            'originalOrderId' => originalOrder.Id,
            'OrderItem' => new List<Object>{
              new Map<String, Object>{ 'SaleSeqNo__c' => 'SEQ-NOT-EXIST-9999', 'ProductCode' => PRODUCT_CODE, 'Quantity' => 1 }
            }
          }
        );
    } catch (CustomException e) {
      thrown = true;
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createReturnItem_orderNoNotFound_throws() {
    Order originalOrder = getOrder(ORIG_ORDER_NO);
    Order returnOrder = getOrder(RET_ORDER_NO);
    Boolean thrown = false;

    Test.startTest();
    try {
      new GdReturnItemServiceImpl()
        .createReturnItem(
          new Map<String, Object>{
            'orderId' => returnOrder.Id,
            'originalOrderId' => originalOrder.Id,
            'OrderItem' => new List<Object>{
              new Map<String, Object>{
                'SaleSeqNo__c' => SALE_SEQ_NO,
                'ProductCode' => PRODUCT_CODE,
                'Quantity' => 1,
                'OrderNo__c' => 'INVALID-ORD-NO-9999'
              }
            }
          }
        );
    } catch (CustomException e) {
      thrown = true;
    }
    Test.stopTest();

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteReturnItem_notFound_throws() {
    Boolean thrown = false;

    try {
      new GdReturnItemServiceImpl().deleteReturnItem(Id.valueOf('801000000000000AAA'));
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteReturnItem_success() {
    Order returnOrder = getOrder(RET_ORDER_NO);

    Id stdPbId = Test.getStandardPricebookId();
    PricebookEntry pbe = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id = :stdPbId LIMIT 1];

    insert new OrderItem(
      OrderId = returnOrder.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 10000,
      SaleSeqNo__c = 'DEL-SEQ-001',
      SaleItemNo__c = String.valueOf(returnOrder.Id) + '-DEL-SEQ-001'
    );

    Test.startTest();
    ApiResult result = new GdReturnItemServiceImpl().deleteReturnItem(returnOrder.Id);
    Test.stopTest();

    System.assertEquals(200, result.code);
    System.assertEquals(0, [SELECT COUNT() FROM OrderItem WHERE OrderId = :returnOrder.Id]);
  }
}