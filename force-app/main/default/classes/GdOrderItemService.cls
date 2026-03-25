public interface GdOrderItemService {
  /**
   * 주문 상세 등록
   * OrderItem insert
   */
  ApiResult createOrderItem(Map<String, Object> reqData);

  /**
   * 주문 상세 수정
   * OrderItem upsert
   */
  ApiResult upsertOrderItem(Map<String, Object> reqData);

  /**
   * 판매 상세 등록
   * OrderItem insert
   */
  ApiResult createSaleItem(Map<String, Object> reqData);

  /**
   * 판매 삭제
   * OrderItem update
   */
  ApiResult deleteSaleItem(Map<String, Object> reqData);

  /**
   * 판매 상세 수정
   * OrderItem upsert
   */
  ApiResult upsertSaleItem(Map<String, Object> reqData);
}