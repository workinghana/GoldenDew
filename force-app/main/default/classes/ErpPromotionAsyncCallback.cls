/**
 * ERP 프로모션 도메인 후처리 콜백
 * - 공통 이벤트 발행(ErpAsyncFailure__e)은 ErpAsyncCallbackPublisher가 담당
 * - 이 클래스는 "프로모션 관련 레코드 상태 변경" 같은 도메인 후처리만 담당
 *
 * @author Changhwan Kim
 * @since 2026-01-27
 */
public with sharing class ErpPromotionAsyncCallback implements ErpAsyncCallback {
    // 필요하면 apiName 상수화 (프로젝트 네이밍에 맞춰 수정)
    public static final String API_CREATE_MASTER = 'CREATE_MASTER';
    public static final String API_UPDATE_MASTER = 'UPDATE_MASTER';
    public static final String API_DELETE_MASTER = 'DELETE_MASTER';

    public ErpPromotionAsyncCallback() {
    }

    /**
     * 성공 시 후처리 (원하면 구현)
     * - 예: 쿠폰 상태 ISSUED로 변경 등
     */
    public void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto) {
        // 지금 요구사항은 "실패 시 상태 변경"이므로 일단 비워둬도 됩니다.
        // 필요하면 apiName 별로 성공 후처리 추가 가능
    }

    /**
     * 실패 시 후처리 (쿠폰 상태 변경)
     * - HttpErrorException.responseBody에서 message 추출해서 실패 사유 저장 가능
     */
    public void onFailure(
        String apiName,
        Object requestDto,
        HttpErrorException httpError,
        Id recordId
    ) {
        if (API_DELETE_MASTER.equals(apiName)) {
            if (recordId == null) {
                return;
            }
            List<Promotion> pList = [
                SELECT Id
                FROM Promotion
                WHERE Id = :recordId AND IsDeleted = TRUE
                LIMIT 1
                ALL ROWS
            ];
            if (!pList.isEmpty()) {
                undelete pList[0];
                System.debug('프로모션 마스터 삭제 실패 => 복원 성공');
            } else {
                System.debug('프로모션 레코드를 찾을 수 없습니다. Id=' + recordId);
            }
        }
    }

    /**
     * 실패 시 후처리 (쿠폰 이전 값으로 원복)
     */
    public void onFailure(
        String apiName,
        Object requestDto,
        HttpErrorException httpError,
        Id recordId,
        SObject o
    ) {
        if (!API_UPDATE_MASTER.equals(apiName)) {
            return;
        }
        if (recordId == null) {
            return;
        }
        if (o == null) {
            // TODO: 알림(원복 불가: old 값 없음)
            return;
        }

        Promotion pOld;
        try {
            pOld = (Promotion) o;
        } catch (Exception castEx) {
            // TODO: 알림(캐스팅 실패)
            return;
        }

        // 1) 원복: UpdateRequest에 반영되는 필드만 명시적으로 세팅
        Promotion rollbackPromotion = new Promotion(
            Id = recordId,
            // 트리거 enqueue 방지 플래그 (원복 시)
            ErpSyncSkip__c = true,
            // ===== UpdateRequest에서 사용하는 필드들 =====
            Name = pOld.Name,
            BrandCode__c = pOld.BrandCode__c,
            TypeCode__c = pOld.TypeCode__c,
            StartDate = pOld.StartDate,
            EndDate = pOld.EndDate,
            PublishStartDate__c = pOld.PublishStartDate__c,
            PublishEndDate__c = pOld.PublishEndDate__c,
            StatusCode__c = pOld.StatusCode__c,
            IsCouponAllowed__c = pOld.IsCouponAllowed__c,
            IsFixedAmountCouponAllowed__c = pOld.IsFixedAmountCouponAllowed__c,
            IsRateCouponAllowed__c = pOld.IsRateCouponAllowed__c,
            IsSpecificCouponAllowed__c = pOld.IsSpecificCouponAllowed__c,
            IsPointUsageAllowed__c = pOld.IsPointUsageAllowed__c,
            IsAllStore__c = pOld.IsAllStore__c,
            IsAllItem__c = pOld.IsAllItem__c
        );

        // 2) 원복 실행 (트리거는 ErpSyncSkip__c=true라 enqueue 스킵)
        update rollbackPromotion;

        // 3) 플래그 해제 (이 update는 afterUpdate에서 ErpSyncSkip__c=true라 continue로 빠지게 만들어야 안전)
        //    => PromotionTriggerHandler에서 "ErpSyncSkip__c == true면 continue"가 이미 있어야 함.
        Promotion releaseFlag = new Promotion(Id = recordId, ErpSyncSkip__c = false);
        update releaseFlag;
    }

    /**
     * (옵션) 문자열/스택으로 넘어오는 실패 후처리도 받을 수 있게 비워둠
     */
    public void onFailure(
        String apiName,
        Object requestDto,
        String errorMessage,
        String stackTrace
    ) {
        // 필요 시: recordId를 여기서 못 받으니 일반 로그용으로만 사용하거나,
        // requestDto에 recordId가 포함되어 있으면 파싱해서 업데이트하는 방식도 가능
    }

    public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {
    }

    public void onFailure(
        String apiName,
        Object requestDto,
        HttpErrorException httpError,
        Set<Id> recordIds
    ) {
        // System.debug('onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) 진입');

        // // 쿠폰 관련 API만 처리 (필요 시 조건 수정)
        // if (isCouponApi(apiName)) {
        //   if (recordIds.isEmpty()) {
        //     return;
        //   }
        //   List<Voucher> vList = [
        //     SELECT Id, Status, ProcessResult__c
        //     FROM Voucher
        //     WHERE Id IN :recordIds
        //   ];
        //   if (!vList.isEmpty()) {
        //     for (Voucher v : vList) {
        //       v.Status = 'Cancelled';
        //       v.ProcessResult__c = 'ISSUE_FAILED';
        //     }
        //     update vList;
        //   } else {
        //     System.debug('쿠폰 레코드 리스트를 찾을 수 없습니다.');
        //   }
        // }
    }
    public void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds) {
        // // 쿠폰 관련 API만 처리 (필요 시 조건 수정)
        // if (isCouponApi(apiName)) {
        //   if (recordIds.isEmpty()) {
        //     return;
        //   }
        //   List<Voucher> vList = [
        //     SELECT Id, Status, ProcessResult__c
        //     FROM Voucher
        //     WHERE Id IN :recordIds
        //   ];
        //   if (!vList.isEmpty()) {
        //     for (Voucher v : vList) {
        //       v.Status = 'Cancelled';
        //       v.ProcessResult__c = 'ISSUE_FAILED';
        //     }
        //     update vList;
        //   } else {
        //     System.debug('쿠폰 레코드 리스트를 찾을 수 없습니다.');
        //   }
        // }
    }

    public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {
        // // 쿠폰 관련 API만 처리 (필요 시 조건 수정)
        // if (isCouponApi(apiName)) {
        //   if (recordId == null) {
        //     return;
        //   }
        //   List<Voucher> vList = [
        //     SELECT Id, Status, ProcessResult__c
        //     FROM Voucher
        //     WHERE Id = :recordId
        //     LIMIT 1
        //   ];
        //   if (!vList.isEmpty()) {
        //     vList[0].Status = 'Cancelled';
        //     vList[0].ProcessResult__c = 'ISSUE_FAILED';
        //     update vList[0];
        //   } else {
        //     System.debug('쿠폰 레코드를 찾을 수 없습니다. Id=' + recordId);
        //   }
        // } else if (isCouponMasterApi(apiName)) {
        // } else {
        //   return;
        // }
    }

    // ---------- helpers ----------

    //   private static Boolean isCouponApi(String apiName) {
    //     return apiName == API_COUPON_ISSUE || apiName == API_COUPON_UPDATE;
    //   }

    //   private static Boolean isCouponMasterApi(String apiName) {
    //     return apiName == API_CREATE_MASTER || apiName == API_UPDATE_MASTER || apiName == API_DELETE_MASTER;
    //   }

    /** ERP 표준 응답 { success, message, data } 에서 message만 추출 */
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
            // JSON 파싱 실패 시 원문 그대로 사용
            return responseBody;
        }

        return responseBody; // 최후의 안전망
    }

    @TestVisible
    static String testExtractMessage(String responseBody) {
        return extractMessage(responseBody);
    }
}