/**
 * HTTP Callout Error Exception
 *
 * - HTTP 4xx / 5xx 응답 정보를 담는 커스텀 예외
 * - Apex 규칙상 생성자는 정의하지 않음
 */
public with sharing class HttpErrorException extends Exception {
  /** HTTP Status Code (ex: 400, 401, 500) */
  public Integer statusCode;

  /** HTTP Response Body (raw) */
  public String responseBody;

  /** HTTP Response Headers */
  public Map<String, String> responseHeaders;

  /** 요청 Endpoint */
  public String endpoint;

  /** HTTP Method */
  public String method;

  public String requestUrl;

  /**
   * 로그용 요약 문자열
   * (Exception message 대신 사용)
   */
  public String summary() {
    return 'HTTP ERROR' + ' status=' + statusCode + ' method=' + method + ' endpoint=' + endpoint;
  }
}