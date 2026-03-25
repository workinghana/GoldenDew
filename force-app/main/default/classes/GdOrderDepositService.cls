/**
 * 주문 입금 관련 인터페이스
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 */
public interface GdOrderDepositService {
  // /**
  //  * 주문 입금 이력 조회
  //  *
  //  * @return ApiResult
  //  * @throws CustomException
  //  */
  // ApiResult getOrderDepositList(String orderNo);

  /**
   * 주문 입금 이력 생성
   *
   * @return ApiResult
   * @throws CustomException
   */
  ApiResult createOrderDepositHistory(Map<String, Object> reqData);

  /**
   * 주문 입금 이력 수정
   *
   * @return ApiResult
   * @throws CustomException
   */
  ApiResult upsertOrderDeposit(Map<String, Object> reqData);
}