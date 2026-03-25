/**
 * ERP 프로모션 매장 도메인 후처리 콜백
 * - 공통 이벤트 발행(ErpAsyncFailure__e)은 ErpAsyncCallbackPublisher가 담당
 * - 이 클래스는 "프로모션 매장 레코드 상태 변경/복원" 같은 도메인 후처리만 담당
 *
 * @author
 * @since 2026-02-XX
 */
public with sharing class ErpPromotionStoreAsyncCallback implements ErpAsyncCallback {
  // =========================
  // API Name Constants
  // =========================
  public static final String API_CREATE_PROMOTION_STORE = 'CREATE_PROMOTION_STORE';
  public static final String API_UPDATE_PROMOTION_STORE = 'UPDATE_PROMOTION_STORE';
  public static final String API_DELETE_PROMOTION_STORE = 'DELETE_PROMOTION_STORE';

  public ErpPromotionStoreAsyncCallback() {
  }

  /**
   * 성공 시 후처리
   * - 현재 요구사항 없음 (필요 시 확장)
   */
  public void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto) {
    // 현재는 성공 후 별도 도메인 처리 없음
  }

  /**
   * 실패 시 후처리 (단건 + HttpError)
   */
  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId) {
    if (API_DELETE_PROMOTION_STORE.equals(apiName)) {
      if (recordId == null) {
        return;
      }

      List<PromotionAccount__c> paList = [
        SELECT Id
        FROM PromotionAccount__c
        WHERE Id = :recordId AND IsDeleted = TRUE
        LIMIT 1
        ALL ROWS
      ];

      if (!paList.isEmpty()) {
        undelete paList[0];
        System.debug('프로모션 매장 삭제 실패 → 레코드 복원 성공');
      } else {
        System.debug('프로모션 매장 레코드를 찾을 수 없습니다. Id=' + recordId);
      }
    }
  }

  /**
   * 실패 시 후처리 (원본 SObject 포함)
   */
  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId, SObject oldObject) {
    // 현재 매장 도메인은 원복 로직 없음
  }

  /**
   * 문자열 에러 기반 실패 후처리
   */
  public void onFailure(String apiName, Object requestDto, String errorMessage, String stackTrace) {
    // 로그용
  }

  public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {
    // 필요 시 recordId 기반 처리 가능
  }

  /**
   * 다건 실패 후처리 (HttpError)
   */
  public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) {
    // 현재 매장 도메인은 다건 원복 요구 없음
  }

  /**
   * 다건 실패 후처리 (Exception)
   */
  public void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds) {
    // 현재 매장 도메인은 다건 원복 요구 없음
  }

  /**
   * 단건 실패 후처리 (Exception)
   */
  public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {
    // 필요 시 확장
  }

  // =========================
  // Helpers
  // =========================

  /** ERP 표준 응답 { success, message, data } 에서 message 추출 */
  @TestVisible
  private static String extractMessage(String responseBody) {
    if (String.isBlank(responseBody)) {
      return null;
    }

    try {
      Object obj = JSON.deserializeUntyped(responseBody);
      if (obj instanceof Map<String, Object>) {
        Map<String, Object> m = (Map<String, Object>) obj;
        Object msg = m.get('message');
        if (msg != null) {
          return String.valueOf(msg);
        }
      }
    } catch (Exception e) {
      return responseBody;
    }

    return responseBody;
  }
}