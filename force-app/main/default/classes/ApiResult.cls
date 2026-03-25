public with sharing class ApiResult {
  public Boolean success;
  public Integer code;
  public String message;
  public Map<String, Object> data;

  public ApiResult() {
  }

  public ApiResult(
    Boolean success,
    Integer code,
    String message,
    Map<String, Object> data
  ) {
    this.success = success;
    this.code = code;
    this.message = message;
    this.data = data;
  }

  /**
   * API 결과값 : 성공
   */
  public static ApiResult ok(
    Integer code,
    String message,
    Map<String, Object> data
  ) {
    return new ApiResult(true, code, message, data);
  }

  /**
   * API 결과값 : 실패
   */
  public static ApiResult fail(Integer code, String message) {
    return new ApiResult(false, code, message, null);
  }
}