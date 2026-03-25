public interface GdVoucherDefinitionService {
  /**
   * 쿠폰 마스터 생성
   * VoucherDefinition insert
   */
  ApiResult createVoucherDefinition(Map<String, Object> reqData);

  /**
   * 프로모션 등록 시 사용 가능한 쿠폰 추가
   * VoucherLimit__c insert
   */
  ApiResult addVoucherLimitByPromotion(Map<String, Object> reqData);
}