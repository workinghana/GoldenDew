public with sharing class GdOrderItemServiceImpl implements GdOrderItemService {
  public GdOrderItemServiceImpl() {
  }

  /**
   * 사용 중
   * 주문 상세 등록
   * OrderItem 생성
   */
  public ApiResult createOrderItem(Map<String, Object> reqData) {
    try {
      List<Object> orderItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);

      List<OrderItem> oiList = new List<OrderItem>();
      List<Map<String, Object>> parsedOrderItemList = new List<Map<String, Object>>();
      Set<String> productCodeSet = new Set<String>();

      Boolean isGoldenBar = false;

      for (Object v : orderItemList) {
        Map<String, Object> orderItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);

        String orderSeqNo = ValidationUtil.stringValidation(orderItem.get('OrderSeqNo__c'), 'OrderSeqNo__c', true); // 주문 일련 번호
        String status = ValidationUtil.stringValidation(orderItem.get('Status__c'), 'Status__c', true); // 주문 상세 상태
        String productCode = ValidationUtil.stringValidation(orderItem.get('ProductCode'), 'ProductCode', true); // 상품 코드
        Integer quantity = ValidationUtil.integerValidation(orderItem.get('Quantity'), 'Quantity', true); // 수량
        Decimal netSalesUnitPrice = ValidationUtil.decimalValidation(orderItem.get('NetSalesUnitPrice__c'), 'NetSalesUnitPrice__c', true); // 판매단가
        Decimal discountRate = ValidationUtil.decimalValidation(orderItem.get('DiscountRate__c'), 'DiscountRate__c', false); // 할인율

        Boolean isExclude = ValidationUtil.booleanValidation(orderItem.get('isExclude'), 'isExclude', false); // 포인트 적립 제외 여부
        parsedOrderItemList.add(
          new Map<String, Object>{
            'OrderSeqNo__c' => orderSeqNo,
            'Status__c' => status,
            'ProductCode' => productCode,
            'Quantity' => quantity,
            'NetSalesUnitPrice__c' => netSalesUnitPrice,
            'DiscountRate__c' => discountRate,
            'isExclude' => isExclude
          }
        );
        productCodeSet.add(productCode);
      }

      Map<String, Product2> productByCode = new Map<String, Product2>();
      for (Product2 productRecord : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodeSet]) {
        productByCode.put(productRecord.ProductCode, productRecord);
      }

      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      Map<String, PricebookEntry> pricebookEntryByCode = new Map<String, PricebookEntry>();
      for (PricebookEntry pricebookEntry : [
        SELECT Id, UnitPrice, Name, ProductCode
        FROM PricebookEntry
        WHERE ProductCode IN :productCodeSet AND Pricebook2Id = :standardPricebookId
      ]) {
        if (!pricebookEntryByCode.containsKey(pricebookEntry.ProductCode)) {
          pricebookEntryByCode.put(pricebookEntry.ProductCode, pricebookEntry);
        }
      }

      Set<Id> productIdSet = new Set<Id>();
      for (Product2 productRecord : productByCode.values()) {
        productIdSet.add(productRecord.Id);
      }

      Set<Id> goldenBarProductIdSet = new Set<Id>();
      if (!productIdSet.isEmpty()) {
        for (ProductCategoryProduct productCategoryProduct : [
          SELECT ProductId
          FROM ProductCategoryProduct
          WHERE ProductCategory.Name LIKE '%골드바%' AND ProductId IN :productIdSet
        ]) {
          goldenBarProductIdSet.add(productCategoryProduct.ProductId);
        }
      }

      for (Map<String, Object> parsedOrderItem : parsedOrderItemList) {
        String orderSeqNo = (String) parsedOrderItem.get('OrderSeqNo__c');
        String status = (String) parsedOrderItem.get('Status__c');
        String productCode = (String) parsedOrderItem.get('ProductCode');
        Integer quantity = (Integer) parsedOrderItem.get('Quantity');
        Decimal netSalesUnitPrice = (Decimal) parsedOrderItem.get('NetSalesUnitPrice__c');
        Decimal discountRate = (Decimal) parsedOrderItem.get('DiscountRate__c');
        Boolean isExclude = (Boolean) parsedOrderItem.get('isExclude');

        Product2 productRecord = productByCode.get(productCode);
        if (productRecord == null) {
          throw new CustomException(400, '해당 품목이 존재하지 않습니다. 품목 코드 : ' + productCode);
        }

        if (goldenBarProductIdSet.contains(productRecord.Id)) {
          isGoldenBar = true;
        }

        PricebookEntry pricebookEntry = pricebookEntryByCode.get(productCode);
        if (pricebookEntry == null) {
          throw new CustomException(400, '해당 PricebookEntry 가 없습니다.');
        }

        OrderItem oi = new OrderItem(
          OrderId = orderId,
          Status__c = status,
          PricebookEntryId = pricebookEntry.Id, // 필수
          Quantity = quantity,
          UnitPrice = pricebookEntry.UnitPrice,
          OrderItemNo__c = orderId + '-' + orderSeqNo, // 주문 상세 번호 (외부 ID)
          IsExclude__c = (isExclude != null) ? isExclude : false,
          NetSalesUnitPrice__c = netSalesUnitPrice,
          DiscountRate__c = discountRate
        );
        oiList.add(oi);
      }

      List<Database.SaveResult> resultList = Database.insert(oiList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('oiList', oiList);
      data.put('isGoldenBar', isGoldenBar);
      return ApiResult.ok(200, '주문 상세 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 주문 상세 수정
   * OrderItem upsert
   */
  public ApiResult upsertOrderItem(Map<String, Object> reqData) {
    try {
      List<Object> orderItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);

      List<OrderItem> oiList = new List<OrderItem>();

      for (Object v : orderItemList) {
        Map<String, Object> orderItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);

        String orderSeqNo = ValidationUtil.stringValidation(orderItem.get('OrderSeqNo__c'), 'OrderSeqNo__c', true); // 주문 일련 번호
        String status = ValidationUtil.stringValidation(orderItem.get('Status__c'), 'Status__c', false); // 주문 상세 상태
        String productCode = ValidationUtil.stringValidation(orderItem.get('ProductCode'), 'ProductCode', true); // 상품 코드
        Integer quantity = ValidationUtil.integerValidation(orderItem.get('Quantity'), 'Quantity', true); // 수량
        Decimal netSalesUnitPrice = ValidationUtil.decimalValidation(orderItem.get('NetSalesUnitPrice__c'), 'NetSalesUnitPrice__c', false); // 판매단가
        Decimal discountRate = ValidationUtil.decimalValidation(orderItem.get('DiscountRate__c'), 'DiscountRate__c', false); // 할인율

        // Product2 조회
        List<Product2> productList = [SELECT Id FROM Product2 WHERE Product2.ProductCode = :productCode LIMIT 1];
        if (productList.isEmpty()) {
          throw new CustomException(400, '해당 품목이 존재하지 않습니다. 품목 코드 : ' + productCode);
        }

        // Standard Pricebook 조회
        Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

        // PricebookEntry 조회
        List<PricebookEntry> pricebookEntryList = [
          SELECT Id, UnitPrice, Name
          FROM PricebookEntry
          WHERE ProductCode = :productCode AND Pricebook2Id = :standardPricebookId
          LIMIT 1
        ];
        if (pricebookEntryList.isEmpty()) {
          throw new CustomException(400, '해당 PricebookEntry 가 없습니다.');
        }

        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.PricebookEntryId = pricebookEntryList[0].Id;
        oi.Quantity = quantity;
        oi.UnitPrice = pricebookEntryList[0].UnitPrice;
        if (status != null) {
          oi.Status__c = status;
        }
        oi.OrderSeqNo__c = orderSeqNo;
        oi.OrderItemNo__c = orderId + '-' + orderSeqNo; // 주문 상세 번호 (외부 ID)
        if (netSalesUnitPrice != null) {
          oi.NetSalesUnitPrice__c = netSalesUnitPrice;
        }
        if (discountRate != null) {
          oi.DiscountRate__c = discountRate;
        }

        oiList.add(oi);
      }

      List<Database.UpsertResult> resultList = Database.upsert(oiList, OrderItem.OrderItemNo__c);

      for (Database.UpsertResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Map<String, Object> data = new Map<String, Object>();
      return ApiResult.ok(200, '주문 상세 수정 완료.', data);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 이관 대상
   * 판매 상세 삭제
   * OrderItem update
   */
  public ApiResult deleteSaleItem(Map<String, Object> reqData) {
    try {
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);
      Datetime deleteDateTime = ValidationUtil.datetimeValidation(reqData.get('DeleteDateTime__c'), 'DeleteDateTime__c', true); // 삭제 일시

      List<OrderItem> oiList = [SELECT Id FROM OrderItem WHERE OrderId = :orderId LIMIT 200];
      if (oiList.isEmpty()) {
        throw new CustomException(400, '해당 주문의 상세 항목이 존재하지 않습니다. ' + orderId);
      }

      for (OrderItem oi : oiList) {
        oi.DeleteDateTime__c = deleteDateTime;
      }

      List<Database.SaveResult> resultList = Database.update(oiList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Map<String, Object> data = new Map<String, Object>();
      return ApiResult.ok(200, '판매 상세 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 사용 중
   * 판매 상세 등록
   * OrderItem insert
   */
  public ApiResult createSaleItem(Map<String, Object> reqData) {
    try {
      List<Object> saleItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);

      List<OrderItem> oiList = new List<OrderItem>();
      List<Map<String, Object>> normalizedSaleItems = new List<Map<String, Object>>();
      Set<String> productCodeSet = new Set<String>();
      Set<String> orderNoSet = new Set<String>();

      for (Object v : saleItemList) {
        Map<String, Object> saleItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);

        String saleSeqNo = ValidationUtil.stringValidation(saleItem.get('SaleSeqNo__c'), 'SaleSeqNo__c', true); // 판매 일련 번호
        String orderNo = ValidationUtil.stringValidation(saleItem.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호
        String productCode = ValidationUtil.stringValidation(saleItem.get('ProductCode'), 'ProductCode', true); // 상품 코드
        Integer quantity = ValidationUtil.integerValidation(saleItem.get('Quantity'), 'Quantity', true); // 수량
        Decimal netSalesUnitPrice = ValidationUtil.decimalValidation(saleItem.get('NetSalesUnitPrice__c'), 'NetSalesUnitPrice__c', true); // 판매단가
        Decimal discountRate = ValidationUtil.decimalValidation(saleItem.get('DiscountRate__c'), 'DiscountRate__c', false); // 할인율
        Boolean isExclude = ValidationUtil.booleanValidation(saleItem.get('isExclude'), 'isExclude', false); // 포인트 적립 제외 여부

        normalizedSaleItems.add(
          new Map<String, Object>{
            'saleSeqNo' => saleSeqNo,
            'orderNo' => orderNo,
            'productCode' => productCode,
            'quantity' => quantity,
            'netSalesUnitPrice' => netSalesUnitPrice,
            'discountRate' => discountRate,
            'isExclude' => isExclude
          }
        );

        productCodeSet.add(productCode);
        if (String.isNotBlank(orderNo)) {
          orderNoSet.add(orderNo);
        }
      }

      Map<String, Product2> productByCode = new Map<String, Product2>();
      for (Product2 productRow : [SELECT Id, ProductCode FROM Product2 WHERE ProductCode IN :productCodeSet]) {
        productByCode.put(productRow.ProductCode, productRow);
      }

      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      Map<String, PricebookEntry> pricebookEntryByCode = new Map<String, PricebookEntry>();
      for (PricebookEntry pricebookEntryRow : [
        SELECT Id, UnitPrice, Name, ProductCode
        FROM PricebookEntry
        WHERE ProductCode IN :productCodeSet AND Pricebook2Id = :standardPricebookId
      ]) {
        if (!pricebookEntryByCode.containsKey(pricebookEntryRow.ProductCode)) {
          pricebookEntryByCode.put(pricebookEntryRow.ProductCode, pricebookEntryRow);
        }
      }

      Map<String, Order> orderByOrderNo = new Map<String, Order>();
      if (!orderNoSet.isEmpty()) {
        for (Order orderRow : [SELECT Id, OrderNo__c FROM Order WHERE OrderNo__c IN :orderNoSet]) {
          orderByOrderNo.put(orderRow.OrderNo__c, orderRow);
        }
      }

      for (Map<String, Object> saleItem : normalizedSaleItems) {
        String saleSeqNo = (String) saleItem.get('saleSeqNo');
        String orderNo = (String) saleItem.get('orderNo');
        String productCode = (String) saleItem.get('productCode');
        Integer quantity = (Integer) saleItem.get('quantity');
        Decimal netSalesUnitPrice = (Decimal) saleItem.get('netSalesUnitPrice');
        Decimal discountRate = (Decimal) saleItem.get('discountRate');
        Boolean isExclude = (Boolean) saleItem.get('isExclude');

        if (!productByCode.containsKey(productCode)) {
          throw new CustomException(400, '해당 품목이 존재하지 않습니다. 품목 코드 : ' + productCode);
        }

        if (!pricebookEntryByCode.containsKey(productCode)) {
          throw new CustomException(400, '해당 PricebookEntry 가 없습니다.');
        }

        PricebookEntry pricebookEntry = pricebookEntryByCode.get(productCode);

        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.PricebookEntryId = pricebookEntry.Id;
        oi.Quantity = quantity;
        oi.UnitPrice = pricebookEntry.UnitPrice;
        oi.SaleSeqNo__c = saleSeqNo;
        oi.SaleItemNo__c = orderId + '-' + saleSeqNo; // 판매 상세 번호 (외부 ID)
        oi.IsExclude__c = (isExclude != null) ? isExclude : false;
        oi.NetSalesUnitPrice__c = netSalesUnitPrice;
        oi.DiscountRate__c = discountRate;

        if (String.isNotBlank(orderNo)) {
          if (!orderByOrderNo.containsKey(orderNo)) {
            throw new CustomException(400, '해당 주문 건이 없습니다. ' + orderNo);
          }
          oi.OrderId__c = orderByOrderNo.get(orderNo).Id;
        }

        oiList.add(oi);
      }

      List<Database.SaveResult> resultList = Database.insert(oiList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('oiList', oiList);
      return ApiResult.ok(200, '판매 상세 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 판매 상세 수정
   * OrderItem upsert
   */
  public ApiResult upsertSaleItem(Map<String, Object> reqData) {
    try {
      List<Object> saleItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);

      List<OrderItem> oiList = new List<OrderItem>();

      for (Object v : saleItemList) {
        Map<String, Object> saleItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);

        String saleSeqNo = ValidationUtil.stringValidation(saleItem.get('SaleSeqNo__c'), 'SaleSeqNo__c', true); // 판매 일련 번호
        String orderNo = ValidationUtil.stringValidation(saleItem.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호
        String productCode = ValidationUtil.stringValidation(saleItem.get('ProductCode'), 'ProductCode', true); // 상품 코드
        Integer quantity = ValidationUtil.integerValidation(saleItem.get('Quantity'), 'Quantity', true); // 수량
        Decimal netSalesUnitPrice = ValidationUtil.decimalValidation(saleItem.get('NetSalesUnitPrice__c'), 'NetSalesUnitPrice__c', false); // 판매단가
        Decimal discountRate = ValidationUtil.decimalValidation(saleItem.get('DiscountRate__c'), 'DiscountRate__c', false); // 할인율

        // Product2 조회
        List<Product2> productList = [SELECT Id FROM Product2 WHERE Product2.ProductCode = :productCode LIMIT 1];
        if (productList.isEmpty()) {
          throw new CustomException(400, '해당 품목이 존재하지 않습니다. 품목 코드 : ' + productCode);
        }

        // Standard Pricebook 조회
        Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

        // PricebookEntry 조회
        List<PricebookEntry> pricebookEntryList = [
          SELECT Id, UnitPrice, Name
          FROM PricebookEntry
          WHERE ProductCode = :productCode AND Pricebook2Id = :standardPricebookId
          LIMIT 1
        ];
        if (pricebookEntryList.isEmpty()) {
          throw new CustomException(400, '해당 PricebookEntry 가 없습니다.');
        }

        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.PricebookEntryId = pricebookEntryList[0].Id;
        oi.Quantity = quantity;
        oi.UnitPrice = pricebookEntryList[0].UnitPrice;
        oi.SaleSeqNo__c = saleSeqNo;
        oi.SaleItemNo__c = orderId + '-' + saleSeqNo; // 판매 상세 번호 (외부 ID)

        if (orderNo != null) {
          List<Order> oList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
          if (oList.isEmpty()) {
            throw new CustomException(400, '해당 주문 건이 없습니다. ' + orderNo);
          }
          oi.OrderId__c = oList[0].Id;
        }
        if (netSalesUnitPrice != null) {
          oi.NetSalesUnitPrice__c = netSalesUnitPrice;
        }
        if (discountRate != null) {
          oi.DiscountRate__c = discountRate;
        }

        oiList.add(oi);
      }

      List<Database.UpsertResult> resultList = Database.upsert(oiList, OrderItem.SaleItemNo__c);

      for (Database.UpsertResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Map<String, Object> data = new Map<String, Object>();
      return ApiResult.ok(200, '판매 상세 수정 완료.', data);
    } catch (Exception e) {
      throw e;
    }
  }
}