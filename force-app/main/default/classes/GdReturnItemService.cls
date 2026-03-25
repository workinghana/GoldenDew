public interface GdReturnItemService {
  /**
   * 반품 상세 등록
   */
  ApiResult createReturnItem(Map<String, Object> reqData);

  /**
   * 반품 상세 삭제
   */
  ApiResult deleteReturnItem(Id orderId);
}