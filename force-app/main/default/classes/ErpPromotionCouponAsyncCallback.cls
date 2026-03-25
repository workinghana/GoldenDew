/**
 * ERP 프로모션 쿠폰 도메인 후처리 콜백
 * - 프로모션 쿠폰 ERP 연동 실패/성공 후처리 담당
 * - 공통 이벤트 발행은 ErpAsyncCallbackPublisher에서 처리
 *
 * @author 
 * @since 2026-02-05
 */
public with sharing class ErpPromotionCouponAsyncCallback
    implements ErpAsyncCallback {

    public static final String API_CREATE_PROMOTION_COUPON = 'CREATE_PROMOTION_COUPON';
    public static final String API_DELETE_PROMOTION_COUPON = 'DELETE_PROMOTION_COUPON';

    public ErpPromotionCouponAsyncCallback() {}

    /* =====================================================
     * Success
     * ===================================================== */
    public void onSuccess(
        String apiName,
        Object requestDto,
        ErpApiResponseDto responseDto
    ) {
        // 현재 요구사항 없음
        // 필요 시 쿠폰 상태 업데이트 등 추가
    }

    /* =====================================================
     * Failure (단건)
     * ===================================================== */
    public void onFailure(
        String apiName,
        Object requestDto,
        HttpErrorException httpError,
        Id recordId
    ) {
        if (API_DELETE_PROMOTION_COUPON.equals(apiName)) {
            if (recordId == null) return;

            List<Coupon> cList = [
                SELECT Id
                FROM Coupon
                WHERE Id = :recordId AND IsDeleted = TRUE
                LIMIT 1
                ALL ROWS
            ];

            if (!cList.isEmpty()) {
                undelete cList[0];
                System.debug('프로모션 쿠폰 삭제 실패 → 복원 성공');
            } else {
                System.debug('쿠폰 레코드를 찾을 수 없습니다. Id=' + recordId);
            }
        }
    }

    /* =====================================================
     * Failure (기타 overload — 사용 안 해도 인터페이스 때문에 필요)
     * ===================================================== */
    public void onFailure(String apiName, Object requestDto, String errorMessage, String stackTrace) {}
    public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {}
    public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId, SObject o) {}
    public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) {}
    public void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds) {}
    public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {}
}