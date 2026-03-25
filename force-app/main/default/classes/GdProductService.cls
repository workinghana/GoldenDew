public interface GdProductService {
  /**
   * 품목 등록
   */
  ApiResult createProduct(Map<String, Object> reqData);

  /**
   * 품목 수정
   */
  ApiResult updateProduct(Map<String, Object> reqData);

  /**
   * 품목 도움창 조회 (프로모션 연동)
   */
  ApiResult getProductByPromotion(String promotionNo);
}