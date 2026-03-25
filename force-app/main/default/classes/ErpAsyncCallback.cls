/**
 * ERP Async Callback (공통)
 * - 비동기 ERP 호출 결과를 처리하기 위한 표준 콜백 인터페이스
 *
 * @author Changhwan Kim
 */
public interface ErpAsyncCallback {
  void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto);
  void onFailure(String apiName, Object requestDto, String errorMessage, String stackTrace);
  void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId);
  void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId, SObject o);
  void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId);
  void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds);
  void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds);
  void onFailure(String apiName, Object requestDto, Exception error, Id recordId);
}