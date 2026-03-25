/**
 * 주문 관련 인터페이스
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 */
public interface GdOrderService {
  /**
   * 주문 등록
   *
   * @return ApiResult
   * @throws CustomException
   */
  ApiResult createOrder(Map<String, Object> reqData);

  /**
   * 주문 수정
   *
   * @return ApiResult
   * @throws CustomException
   */
  ApiResult updateOrder(Map<String, Object> reqData);

  /**
   * ! 이관중
   * 판매 등록
   * Order insert
   */
  ApiResult createSale(Map<String, Object> reqData);

  /**
   * ! 이관 대상
   * 판매 수정
   * Order update
   */
  ApiResult updateSale(Map<String, Object> reqData);

  /**
   * ! 이관 대상
   * 판매 전체 삭제
   * Order update
   */
  ApiResult deleteSale(String saleNo);
}