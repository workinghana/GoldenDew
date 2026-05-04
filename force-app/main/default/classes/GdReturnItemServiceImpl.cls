public with sharing class GdReturnItemServiceImpl implements GdReturnItemService {
  private static void logTiming(String label, Long startMs, Integer startCpu) {
    Long elapsedMs = Datetime.now().getTime() - startMs;
    Integer elapsedCpu = Limits.getCpuTime() - startCpu;
    System.debug(LoggingLevel.WARN, '[TIMING] ' + label + ' | 누적 ' + elapsedMs + 'ms | CPU ' + elapsedCpu + 'ms');
  }
  /**
   * 반품 상세 등록
   */
  public ApiResult createReturnItem(Map<String, Object> reqData) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      List<Object> saleItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);
      String originalOrderId = ValidationUtil.stringValidation(reqData.get('originalOrderId'), 'originalOrderId', true); // ?먰뙋留?Id

      List<OrderItem> oiList = new List<OrderItem>();
      List<Map<String, Object>> normalizedSaleItemList = new List<Map<String, Object>>();
      Set<String> productCodeSet = new Set<String>();
      Set<String> saleSeqNoSet = new Set<String>();
      Set<String> orderNoSet = new Set<String>();

      // Standard Pricebook 조회
      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;
      logTiming('GdReturnItemServiceImpl.createReturnItem.loadPricebook', totalStartMs, totalStartCpu);

      for (Object v : saleItemList) {
        Map<String, Object> saleItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);

        String saleSeqNo = ValidationUtil.stringValidation(saleItem.get('SaleSeqNo__c'), 'SaleSeqNo__c', true); // 원판매 일련 번호
        String orderNo = ValidationUtil.stringValidation(saleItem.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호
        String productCode = ValidationUtil.stringValidation(saleItem.get('ProductCode'), 'ProductCode', true); // 상품 코드
        Integer quantity = ValidationUtil.integerValidation(saleItem.get('Quantity'), 'Quantity', true); // 수량
        Decimal netSalesUnitPrice = ValidationUtil.decimalValidation(saleItem.get('NetSalesUnitPrice__c'), 'NetSalesUnitPrice__c', false); // 판매단가
        Decimal discountRate = ValidationUtil.decimalValidation(saleItem.get('DiscountRate__c'), 'DiscountRate__c', false); // 할인율

        productCodeSet.add(productCode);
        saleSeqNoSet.add(saleSeqNo);
        if (String.isNotBlank(orderNo)) {
          orderNoSet.add(orderNo);
        }

        normalizedSaleItemList.add(
          new Map<String, Object>{
            'SaleSeqNo__c' => saleSeqNo,
            'OrderNo__c' => orderNo,
            'ProductCode' => productCode,
            'Quantity' => quantity,
            'NetSalesUnitPrice__c' => netSalesUnitPrice,
            'DiscountRate__c' => discountRate
          }
        );
      }

      Map<String, PricebookEntry> pbeByProductCode = new Map<String, PricebookEntry>();
      for (PricebookEntry pbe : [
        SELECT Id, UnitPrice, ProductCode
        FROM PricebookEntry
        WHERE ProductCode IN :productCodeSet AND Pricebook2Id = :standardPricebookId
      ]) {
        if (String.isNotBlank(pbe.ProductCode) && !pbeByProductCode.containsKey(pbe.ProductCode)) {
          pbeByProductCode.put(pbe.ProductCode, pbe);
        }
      }

      Map<String, OrderItem> originalOrderItemBySaleSeqNo = new Map<String, OrderItem>();
      for (OrderItem originalOi : [
        SELECT Id, SaleSeqNo__c
        FROM OrderItem
        WHERE OrderId = :originalOrderId AND SaleSeqNo__c IN :saleSeqNoSet
      ]) {
        if (String.isNotBlank(originalOi.SaleSeqNo__c) && !originalOrderItemBySaleSeqNo.containsKey(originalOi.SaleSeqNo__c)) {
          originalOrderItemBySaleSeqNo.put(originalOi.SaleSeqNo__c, originalOi);
        }
      }

      Map<String, Order> orderByOrderNo = new Map<String, Order>();
      if (!orderNoSet.isEmpty()) {
        for (Order o : [SELECT Id, OrderNo__c FROM Order WHERE OrderNo__c IN :orderNoSet]) {
          if (String.isNotBlank(o.OrderNo__c) && !orderByOrderNo.containsKey(o.OrderNo__c)) {
            orderByOrderNo.put(o.OrderNo__c, o);
          }
        }
      }

      for (Map<String, Object> saleItem : normalizedSaleItemList) {
        String saleSeqNo = (String) saleItem.get('SaleSeqNo__c');
        String orderNo = (String) saleItem.get('OrderNo__c');
        String productCode = (String) saleItem.get('ProductCode');
        Decimal netSalesUnitPrice = (Decimal) saleItem.get('NetSalesUnitPrice__c');
        Decimal discountRate = (Decimal) saleItem.get('DiscountRate__c');
        Integer quantity = (Integer) saleItem.get('Quantity');

        PricebookEntry matchedPbe = pbeByProductCode.get(productCode);
        if (matchedPbe == null) {
          throw new CustomException(400, '해당 품목이 존재하지 않습니다. 품목 코드 : ' + productCode);
        }

        OrderItem originalOrderItem = originalOrderItemBySaleSeqNo.get(saleSeqNo);
        if (originalOrderItem == null) {
          throw new CustomException(400, '해당 원판매 건이 없습니다. ' + originalOrderId + '-' + saleSeqNo);
        }

        System.debug('matchedPbe.Id : ' + matchedPbe.Id);
        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.PricebookEntryId = matchedPbe.Id;
        oi.Quantity = quantity;
        oi.UnitPrice = matchedPbe.UnitPrice;
        oi.SaleSeqNo__c = saleSeqNo;
        oi.SaleItemNo__c = orderId + '-' + saleSeqNo; // 판매 상세 번호 (외부 ID)
        oi.OriginalOrderItemId__c = originalOrderItem.Id;
        oi.NetSalesUnitPrice__c = netSalesUnitPrice;
        oi.DiscountRate__c = discountRate;

        if (String.isNotBlank(orderNo)) {
          Order matchedOrder = orderByOrderNo.get(orderNo);
          if (matchedOrder == null) {
            throw new CustomException(400, '해당 주문 건이 없습니다. ' + orderNo);
          }
          oi.OrderId__c = matchedOrder.Id; // 주문 번호
        }

        oiList.add(oi);
      }

      logTiming('GdReturnItemServiceImpl.createReturnItem.buildOrderItems', totalStartMs, totalStartCpu);
      List<Database.SaveResult> resultList = Database.insert(oiList);
      logTiming('GdReturnItemServiceImpl.createReturnItem.insertOrderItems', totalStartMs, totalStartCpu);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Map<String, Object> data = new Map<String, Object>();
      logTiming('GdReturnItemServiceImpl.createReturnItem.total', totalStartMs, totalStartCpu);
      return ApiResult.ok(200, '반품 상세 등록 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 반품 상세 삭제
   */
  public ApiResult deleteReturnItem(Id orderId) {
    try {
      List<OrderItem> oiList = [SELECT Id, DeleteDateTime__c, Quantity FROM OrderItem WHERE OrderId = :orderId LIMIT 200];
      if (oiList.isEmpty()) {
        throw new CustomException(400, '해당 주문의 상세 항목이 존재하지 않습니다. ' + orderId);
      }

      // for (OrderItem oi : oiList) {
      //   oi.DeleteDateTime__c = System.now();
      //   oi.Quantity = 0;
      // }

      List<Database.DeleteResult> resultList = Database.delete(oiList, false);

      for (Database.DeleteResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      return ApiResult.ok(200, '반품 상세 삭제 완료', null);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}