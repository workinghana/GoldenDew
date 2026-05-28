/**
 * 주문 제품에 관한 REST API 컨트롤러
 *
 * @author Changhwan Kim
 * @since 2026-05-28
 */
@RestResource(urlMapping='/gd/v1/order/item')
global with sharing class GdOrderItemApiControllerV1 {
  /**
   * * 사용 중
   * 주문 품목 삭제
   *
   * @author Hana Lee
   * @since 2026-05-26
   */
  @HttpDelete
  global static void deleteOrderItem() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging(GdOrderItemApiControllerV1.class.getName());

    RestRequest req = RestContext.request;
    logger.setMethod(String.isBlank(req.httpMethod) ? 'DELETE' : req.httpMethod);

    Savepoint sp = Database.setSavepoint();

    Map<String, Object> resData = new Map<String, Object>();
    try {
      logger.setRequestUrl(JSON.serialize(req.params));
      logger.setRequestDatetime(Datetime.now());

      String orderNo = ValidationUtil.stringValidationEx(req.params.get('OrderNo__c'), 'OrderNo__c', true, false);
      String orderSeqNo = ValidationUtil.stringValidationEx(req.params.get('OrderSeqNo__c'), 'OrderSeqNo__c', true, false);

      List<Order> orderList = [
        SELECT Id, OrderNo__c
        FROM Order
        WHERE OrderNo__c = :orderNo AND IsDeleted__c = FALSE
        LIMIT 1
      ];

      if (orderList.isEmpty()) {
        throw new CustomException(400, '해당 주문이 존재하지 않습니다. OrderNo__c=' + orderNo);
      }

      Id orderId = orderList[0].Id;
      String orderItemNo = String.valueOf(orderList[0].Id) + '-' + orderSeqNo;
      List<OrderItem> orderItemList = [
        SELECT Id, OrderId, OrderSeqNo__c, OrderItemNo__c
        FROM OrderItem
        WHERE OrderId = :orderList[0].Id AND OrderItemNo__c = :orderItemNo
        LIMIT 1
      ];

      if (orderItemList.isEmpty()) {
        throw new CustomException(400, '해당 주문 품목이 존재하지 않습니다. OrderNo__c=' + orderNo + ', OrderSeqNo__c=' + orderSeqNo);
      }

      OrderItem orderItem = orderItemList[0];
      Database.DeleteResult deleteResult = Database.delete(orderItem);

      if (!deleteResult.isSuccess()) {
        Database.Error err = deleteResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
      resData.put('orderId', orderId);
      resData.put('orderNo', orderNo);
      resData.put('orderItemId', orderItem.Id);
      resData.put('orderSeqNo', orderSeqNo);
      resData.put('orderItemNo', orderItem.OrderItemNo__c);

      ApiResult result = ApiResult.ok(200, '주문 품목 삭제 완료', resData);

      RestResponseUtil.handleSuccess(result, logger);
    } catch (ValidationException ve) {
      RestResponseUtil.handleCustomException(ve, null, ve.code, ve.detail, logger);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message, logger);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500, logger);
    } finally {
      logger.addLog();
      ApexLogger.insertLogs();
    }
    return;
  }
}