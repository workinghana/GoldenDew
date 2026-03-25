public with sharing class GdReturnItemServiceImpl implements GdReturnItemService {
  /**
   * 반품 상세 등록
   */
  public ApiResult createReturnItem(Map<String, Object> reqData) {
    try {
      List<Object> saleItemList = ValidationUtil.listObjValidation(reqData.get('OrderItem'), 'OrderItem', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);
      String originalOrderId = ValidationUtil.stringValidation(reqData.get('originalOrderId'), 'originalOrderId', true); // 원판매 Id

      List<OrderItem> oiList = new List<OrderItem>();

      // Standard Pricebook 조회
      Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = TRUE LIMIT 1].Id;

      for (Object v : saleItemList) {
        Map<String, Object> saleItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);

        String saleSeqNo = ValidationUtil.stringValidation(saleItem.get('SaleSeqNo__c'), 'SaleSeqNo__c', true); // 원판매 일련 번호
        String orderNo = ValidationUtil.stringValidation(saleItem.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호
        String productCode = ValidationUtil.stringValidation(saleItem.get('ProductCode'), 'ProductCode', true); // 상품 코드
        Integer quantity = ValidationUtil.integerValidation(saleItem.get('Quantity'), 'Quantity', true); // 수량

        // Product2 조회
        List<Product2> productList = [SELECT Id FROM Product2 WHERE Product2.ProductCode = :productCode LIMIT 1];
        if (productList.isEmpty()) {
          throw new CustomException(400, '해당 품목이 존재하지 않습니다. 품목 코드 : ' + productCode);
        }

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

        // 원판매 상세 Id 조회
        List<OrderItem> originalOrderItemList = [
          SELECT Id
          FROM OrderItem
          WHERE OrderId = :originalOrderId AND SaleSeqNo__c = :saleSeqNo
          LIMIT 1
        ];
        if (originalOrderItemList.isEmpty()) {
          throw new CustomException(400, '해당 원판매 건이 없습니다. ' + originalOrderId + '-' + saleSeqNo);
        }

        OrderItem oi = new OrderItem();
        oi.OrderId = orderId;
        oi.PricebookEntryId = pricebookEntryList[0].Id;
        oi.Quantity = quantity;
        oi.UnitPrice = pricebookEntryList[0].UnitPrice;
        oi.SaleSeqNo__c = saleSeqNo;
        oi.SaleItemNo__c = orderId + '-' + saleSeqNo; // 판매 상세 번호 (외부 ID)
        oi.OriginalOrderItemId = originalOrderItemList[0].Id;

        if (orderNo != null) {
          List<Order> oList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
          if (oList.isEmpty()) {
            throw new CustomException(400, '해당 주문 건이 없습니다. ' + orderNo);
          }
          oi.OrderId__c = oList[0].Id; // 주문 번호
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