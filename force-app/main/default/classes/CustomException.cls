public with sharing class CustomException extends Exception {
  public Integer code; // error code / 에러 코드
  public String message; // error message / 에러 메세지

  public CustomException(Integer code, String message) {
    this.code = code;
    this.message = message;
  }
}