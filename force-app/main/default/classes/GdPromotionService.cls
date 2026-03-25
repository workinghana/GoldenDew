public interface GdPromotionService {
  /**
   * 프로모션 등록
   */
  ApiResult createPromotion(Map<String, Object> reqData);

  /**
   * 프로모션 조회
   */
  ApiResult getPromotionList(Map<String, String> reqData);
  // List<GdPromotionApiController.PromotionDTO> getPromotionList(Map<String, String> reqData);

  /**
   * 프로모션 상세 조회
   */
  ApiResult getPromotionDetail(String promotionNo);
}