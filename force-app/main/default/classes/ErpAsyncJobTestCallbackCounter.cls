@IsTest
public class ErpAsyncJobTestCallbackCounter implements ErpAsyncCallback {
  public Integer successCnt = 0;
  public Integer httpFailCnt = 0;
  public Integer exFailCnt = 0;

  public void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto) {
    successCnt++;
  }

  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId) {
    httpFailCnt++;
  }
  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId, SObject o) {
    httpFailCnt++;
  }
  public void onFailure(String apiName, Object requestDto, String errorMessage, String stackTrace) {
  }
  public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {
  }
  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) {
    httpFailCnt++;
  }
  public void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds) {
    exFailCnt++;
  }
  public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {
    exFailCnt++;
  }
}