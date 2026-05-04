//@RestResource(urlMapping='/gd/account')
global with sharing class GdAccountApiController {
  private static GdAccountService accountService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setAccountService(GdAccountService mock) {
    accountService = mock;
  }

  private static GdAccountService getAccountService() {
    if (accountService == null)
      accountService = new GdAccountServiceImpl();
    return accountService;
  }

  /**
   * 매장 및 회사 등록
   * Account create
   */
  //@HttpPost
  global static void createAccount() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Account 생성
      ApiResult result = getAccountService().createAccount(reqData);

      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }

  /**
   * 매장 및 회사 수정
   * Account update
   */
  //@HttpPatch
  global static void updateAccount() {
    RestRequest req = RestContext.request;
    Savepoint sp = Database.setSavepoint();
    try {
      String raw = RestContext.request.requestBody == null ? null : RestContext.request.requestBody.toString();
      if (String.isBlank(raw)) {
        throw new CustomException(400, '요청 본문이 비었습니다.');
      }

      Map<String, Object> reqData;
      try {
        reqData = (Map<String, Object>) JSON.deserializeUntyped(raw);
      } catch (Exception e) {
        throw new CustomException(400, 'JSON 역직렬화 실패: ' + e.getMessage());
      }

      // Account update
      ApiResult result = getAccountService().updateAccount(reqData);

      RestResponseUtil.handleSuccess(result);
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }
}