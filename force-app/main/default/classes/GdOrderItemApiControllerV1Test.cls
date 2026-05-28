@IsTest
private class GdOrderItemApiControllerV1Test {
  private static void setupRest(Map<String, String> params) {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/v1/order/item';
    req.httpMethod = 'DELETE';
    if (params != null) {
      for (String key : params.keySet()) {
        req.params.put(key, params.get(key));
      }
    }
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @TestSetup
  static void setupData() {
    insert new Account(Name = 'Order Item API Test Account');
  }

  private static Order createOrderRecord(String orderNo) {
    Account accountRecord = [SELECT Id FROM Account LIMIT 1];
    Id standardPricebookId = Test.getStandardPricebookId();
    try {
      update new Pricebook2(Id = standardPricebookId, IsActive = true);
    } catch (Exception ignore) {
    }

    Order orderRecord = new Order(
      AccountId = accountRecord.Id,
      Status = 'Draft',
      EffectiveDate = Date.today(),
      Pricebook2Id = standardPricebookId,
      OrderNo__c = orderNo
    );
    insert orderRecord;
    return orderRecord;
  }

  private static OrderItem createOrderItem(Order orderRecord, String orderSeqNo) {
    Product2 productRecord = new Product2(
      Name = 'Order Item API Test Product',
      ProductCode = 'OIAPI-' + orderSeqNo,
      IsActive = true
    );
    insert productRecord;

    PricebookEntry pbe = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = productRecord.Id,
      UnitPrice = 1000,
      IsActive = true
    );
    insert pbe;

    OrderItem item = new OrderItem(
      OrderId = orderRecord.Id,
      PricebookEntryId = pbe.Id,
      Quantity = 1,
      UnitPrice = 1000,
      OrderSeqNo__c = orderSeqNo,
      OrderItemNo__c = String.valueOf(orderRecord.Id) + '-' + orderSeqNo
    );
    insert item;
    return item;
  }

  @IsTest
  static void deleteOrderItem_missingOrderNo_returns400() {
    setupRest(new Map<String, String>{ 'OrderSeqNo__c' => '001' });

    Test.startTest();
    GdOrderItemApiControllerV1.deleteOrderItem();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void deleteOrderItem_orderNotFound_returns400() {
    setupRest(new Map<String, String>{ 'OrderNo__c' => 'ORD-NOT-FOUND', 'OrderSeqNo__c' => '001' });

    Test.startTest();
    GdOrderItemApiControllerV1.deleteOrderItem();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void deleteOrderItem_orderItemNotFound_returns400() {
    createOrderRecord('ORD-OIAPI-NOITEM');
    setupRest(new Map<String, String>{ 'OrderNo__c' => 'ORD-OIAPI-NOITEM', 'OrderSeqNo__c' => '999' });

    Test.startTest();
    GdOrderItemApiControllerV1.deleteOrderItem();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void deleteOrderItem_success_returns200AndDeletesItem() {
    Order orderRecord = createOrderRecord('ORD-OIAPI-SUCCESS');
    OrderItem item = createOrderItem(orderRecord, '001');
    setupRest(new Map<String, String>{ 'OrderNo__c' => 'ORD-OIAPI-SUCCESS', 'OrderSeqNo__c' => '001' });

    Test.startTest();
    GdOrderItemApiControllerV1.deleteOrderItem();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assertEquals(0, [SELECT COUNT() FROM OrderItem WHERE Id = :item.Id]);
  }
}