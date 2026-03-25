public interface GdLoyaltyTierService {
  /**
   * 회원 등급 변경
   * LoyaltyTier update | insert
   */
  ApiResult changeTier(Map<String, Object> reqData);
}