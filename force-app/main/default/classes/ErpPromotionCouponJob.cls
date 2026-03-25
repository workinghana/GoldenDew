/**
 * 프로모션 쿠폰 관련 비동기 Job (통합)
 *
 * @author HANA LEE
 * @since 2026-02-05
 */
public with sharing class ErpPromotionCouponJob extends ErpAsyncJob {
    
    // 어떤 작업인지 구분
    public enum Operation {
        CREATE_PROMOTION_COUPON,
        UPDATE_PROMOTION_COUPON,
        DELETE_PROMOTION_COUPON
    }
    
    private Operation op;
    
    public ErpPromotionCouponJob(
        Operation op,
    Object requestDto,
    ErpAsyncCallback callback,
    Id recordId
    ) {
        super(String.valueOf(op), requestDto, callback, recordId);
        this.op = op;
    }
    
    public ErpPromotionCouponJob(
        Operation op,
    Object requestDto,
    ErpAsyncCallback callback,
    Id recordId,
    SObject o
    ) {
        super(String.valueOf(op), requestDto, callback, recordId, o);
        this.op = op;
    }
    
    /**
     * ERP Callout 실행
     */
    protected override ErpApiResponseDto doCallout() {
        if (op == Operation.CREATE_PROMOTION_COUPON) {
            return ErpPromotionCouponApiClient.createPromotionCoupon(
                (ErpPromotionCouponReqDto.CreateRequest) requestDto
                );
        } else if (op == Operation.UPDATE_PROMOTION_COUPON) {
            throw new IllegalArgumentException('UPDATE not supported yet');
        } else if (op == Operation.DELETE_PROMOTION_COUPON) {
            return ErpPromotionCouponApiClient.deletePromotionCoupon(
                (ErpPromotionCouponReqDto.DeleteRequest) requestDto
                );
        }
        
        throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
    }
    
}