public interface GdPricebookEntryService {
  /**
   * 가격 항목 등록
   * PricebookEntry insert
   */
  ApiResult createPricebookEntryByProduct2(Map<String, Object> reqData);

  /**
   * 가격 항목 수정
   * PricebookEntry update
   */
  ApiResult updatePricebookEntryByProduct2(Map<String, Object> reqData);
}