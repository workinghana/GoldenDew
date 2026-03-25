public with sharing class GdSaleItemServiceImpl implements GdSaleItemService {
  public GdSaleItemServiceImpl() {
  }

  /**
   * 판매 상세 삭제
   * OrderItem update
   */
  public ApiResult deleteSaleItem(Id orderId) {
    try {
      List<OrderItem> oiList = [SELECT Id FROM OrderItem WHERE OrderId = :orderId LIMIT 200];
      if (oiList.isEmpty()) {
        throw new CustomException(400, '해당 주문의 상세 항목이 존재하지 않습니다. ' + orderId);
      }

      for (OrderItem oi : oiList) {
        oi.DeleteDateTime__c = System.now();
      }

      List<Database.SaveResult> resultList = Database.update(oiList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      return ApiResult.ok(200, '판매 상세 삭제 완료', null);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}