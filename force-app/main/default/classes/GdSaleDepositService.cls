/**
 * 판매 입금 관련 인터페이스
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 */
public interface GdSaleDepositService {
  /**
   * 판매 입금 조회
   */
  ApiResult getSaleDepositList(String saleNo);

  /**
   * 판매 입금 이력 생성
   */
  ApiResult createSaleDepositHistory(Map<String, Object> reqData);

  /**
   * 판매 입금 전체 삭제
   */
  ApiResult deleteAllSaleDeposits(Id orderId);

  /**
   * 판매 입금 삭제
   */
  ApiResult deleteSaleDeposit(String depositNo);

  /**
   * 판매 입금 삭제 V2
   *
   * @version 2.0
   * @return ApiResult
   * @throws CustomException
   */
  ApiResult deleteSaleDepositV2(String depositNo);

  /**
   * 판매 입금 이력 수정
   *
   * @return ApiResult
   * @throws CustomException
   */
  ApiResult upsertSaleDeposit(Map<String, Object> reqData);

  /**
   * 판매 입금 이력 수정 V2
   *
   * @version 2.0
   * @return ApiResult
   * @throws CustomException
   */
  ApiResult upsertSaleDepositV2(Map<String, Object> reqData);
}