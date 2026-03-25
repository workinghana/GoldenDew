/**
 * ERP 프로모션 포인트 도메인 후처리 콜백
 * - 공통 이벤트 발행(ErpAsyncFailure__e)은 ErpAsyncCallbackPublisher가 담당
 * - 이 클래스는 "프로모션 포인트 관련 레코드 상태 변경" 같은 도메인 후처리만 담당
 *
 * @author 
 * @since 2026-02-05
 */
public with sharing class ErpPromotionPointAsyncCallback
    implements ErpAsyncCallback {

    // 필요 시 apiName 상수화
    public static final String API_CREATE_PROMOTION_POINT = 'CREATE_PROMOTION_POINT';
    public static final String API_UPDATE_PROMOTION_POINT = 'UPDATE_PROMOTION_POINT';
    public static final String API_DELETE_PROMOTION_POINT = 'DELETE_PROMOTION_POINT';

    public ErpPromotionPointAsyncCallback() {
    }

    /**
     * 성공 시 후처리
     * - 현재 요구사항 없음 (필요 시 확장)
     */
    public void onSuccess(
        String apiName,
        Object requestDto,
        ErpApiResponseDto responseDto
    ) {
        // 성공 후처리 필요 시 구현
        // 예: PromotionPoint__c 상태 변경 등
    }

    /**
     * 실패 시 후처리
     * - DELETE 실패 시 Salesforce 레코드 복원
     */
    public void onFailure(
        String apiName,
        Object requestDto,
        HttpErrorException httpError,
        Id recordId
    ) {
        if (API_DELETE_PROMOTION_POINT.equals(apiName)) {

            if (recordId == null) {
                return;
            }

            List<PromotionPointLimit__c> ppList = [
                SELECT Id
                FROM PromotionPointLimit__c
                WHERE Id = :recordId
                  AND IsDeleted = TRUE
                LIMIT 1
                ALL ROWS
            ];

            if (!ppList.isEmpty()) {
                undelete ppList[0];
                System.debug('프로모션 포인트 삭제 실패 → 복원 성공');
            } else {
                System.debug(
                    '프로모션 포인트 레코드를 찾을 수 없습니다. Id=' + recordId
                );
            }
        }
    }

    /**
     * 실패 시 후처리 (이전 값 기반 원복)
     * - 현재 미사용 (필요 시 확장)
     */
    public void onFailure(
        String apiName,
        Object requestDto,
        HttpErrorException httpError,
        Id recordId,
        SObject oldObj
    ) {
        // 포인트 수정 실패 시 이전 값으로 원복하는 로직 필요하면 여기 구현
    }

    /**
     * 문자열/스택 기반 실패 콜백 (로그 전용)
     */
    public void onFailure(
        String apiName,
        Object requestDto,
        String errorMessage,
        String stackTrace
    ) {
        // 일반 로그 용도
    }

    public void onFailure(
        String apiName,
        Object requestDto,
        String errorMessage,
        Id recordId
    ) {
    }

    public void onFailure(
        String apiName,
        Object requestDto,
        HttpErrorException httpError,
        Set<Id> recordIds
    ) {
    }

    public void onFailure(
        String apiName,
        Object requestDto,
        Exception error,
        Set<Id> recordIds
    ) {
    }

    public void onFailure(
        String apiName,
        Object requestDto,
        Exception error,
        Id recordId
    ) {
    }

    // =========================
    // Helpers
    // =========================

    /** ERP 표준 응답 { success, message, data } 에서 message만 추출 */
    @TestVisible
    public static String extractMessage(String responseBody) {
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