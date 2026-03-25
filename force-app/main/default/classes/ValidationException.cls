public with sharing class ValidationException extends Exception {
  public String methodName; // methodName
  public String detail; // error message
  public Integer code;

  public ValidationException(String methodName, String detail) {
    this.methodName = methodName;
    this.detail = detail;
    this.code = 400;
  }
}