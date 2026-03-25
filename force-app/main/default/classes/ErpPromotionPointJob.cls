/**
 * ERP 프로모션 포인트 관련 비동기 Job (통합)
 *
 * @author
 * @since 2026-02-05
 */
public with sharing class ErpPromotionPointJob extends ErpAsyncJob {

    /* =====================================================
     * Operation 정의
     * ===================================================== */
    public enum Operation {
        CREATE_PROMOTION_POINT,
        UPDATE_PROMOTION_POINT,
        DELETE_PROMOTION_POINT
    }

    private Operation op;

    /* =====================================================
     * Constructors
     * ===================================================== */
    public ErpPromotionPointJob(
        Operation op,
        Object requestDto,
        ErpAsyncCallback callback,
        Id recordId
    ) {
        super(String.valueOf(op), requestDto, callback, recordId);
        this.op = op;
    }

    public ErpPromotionPointJob(
        Operation op,
        Object requestDto,
        ErpAsyncCallback callback,
        Id recordId,
        SObject o
    ) {
        super(String.valueOf(op), requestDto, callback, recordId, o);
        this.op = op;
    }

    /* =====================================================
     * ERP Callout 실행
     * ===================================================== */
    protected override ErpApiResponseDto doCallout() {

        if (op == Operation.CREATE_PROMOTION_POINT) {
            return ErpPromotionPointApiClient.createPromotionPoint(
                (ErpPromotionPointReqDto.CreateRequest) requestDto
            );

        } else if (op == Operation.UPDATE_PROMOTION_POINT) {
            return ErpPromotionPointApiClient.updatePromotionPoint(
                (ErpPromotionPointReqDto.UpdateRequest) requestDto
            );

        } else if (op == Operation.DELETE_PROMOTION_POINT) {
            return ErpPromotionPointApiClient.deletePromotionPoint(
                (ErpPromotionPointReqDto.DeleteRequest) requestDto
            );
        }

        throw new IllegalArgumentException(
            'Unsupported operation: ' + String.valueOf(op)
        );
    }
}