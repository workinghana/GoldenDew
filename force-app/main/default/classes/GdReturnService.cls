public interface GdReturnService {
  /**
   * 반품 등록
   */
  ApiResult createReturn(Map<String, Object> reqData);

  /**
   * 반품 전체 삭제
   */
  ApiResult deleteReturn(String saleNo);
}