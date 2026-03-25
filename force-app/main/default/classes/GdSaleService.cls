/**
 * 판매 서비스 로직 인터페이스
 */
public interface GdSaleService {
  /**
   * ! 보류
   * 판매 등록
   */
  // ApiResult createSale(Map<String, Object> reqData);

  /**
   * 판매 전체 삭제
   * Order update
   */
  ApiResult deleteSale(String saleNo);
}