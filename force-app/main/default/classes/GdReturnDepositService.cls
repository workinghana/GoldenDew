public interface GdReturnDepositService {
  /**
   * 반품 입금 등록
   */
  ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData);

  /**
   * 반품 쿠폰 조회
   */
  // ApiResult getReturnCounpon(String reqData);

  /**
   * ! 개발 중
   * 반품 입금 전체 삭제
   */
  ApiResult deleteAllReturnDeposits(Id orderId);

  /**
   * 반품 입금 삭제
   */
  ApiResult deleteReturnDeposit(String depositNo);
}