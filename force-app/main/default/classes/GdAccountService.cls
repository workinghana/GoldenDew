public interface GdAccountService {
  /**
   * 매장 및 회사 등록
   * Accout insert
   */
  ApiResult createAccount(Map<String, Object> reqData);

  /**
   * 매장 및 회사 수정
   * Accout update
   */
  ApiResult updateAccount(Map<String, Object> reqData);

  /**
   * 매장 및 회사 삭제
   * Accout delete
   */
  ApiResult deleteAccount(Map<String, Object> reqData);
}