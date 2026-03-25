/**
 * 프로모션 제품 관련 비동기 Job (통합)
 *
 * @author Changhwan Kim
 * @since 2026-02-04
 */
public class ErpPromotionProductJob extends ErpAsyncJob {
  // 어떤 작업인지 구분
  public enum Operation {
    CREATE_PROMOTION_PRODUCT,
    UPDATE_PROMOTION_PRODUCT,
    DELETE_PROMOTION_PRODUCT
  }

  private Operation op;

  public ErpPromotionProductJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId) {
    super(String.valueOf(op), requestDto, callback, recordId);
    this.op = op;
    // this.requestJson = (requestDto == null) ? null : JSON.serialize(requestDto);
  }

  public ErpPromotionProductJob(Operation op, Object requestDto, ErpAsyncCallback callback, Set<Id> recordIds) {
    super(String.valueOf(op), requestDto, callback, recordIds);
    this.op = op;
  }

  public ErpPromotionProductJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject o) {
    super(String.valueOf(op), requestDto, callback, recordId, o);
    this.op = op;
  }

  protected override ErpApiResponseDto doCallout() {
    if (op == Operation.CREATE_PROMOTION_PRODUCT) {
      System.debug('when CREATE_PROMOTION_PRODUCT ???');
      return ErpPromotionProductApiClient.createPromotionProduct((ErpPromotionProductReqDto.CreateRequestList) requestDto);
    }

    if (op == Operation.UPDATE_PROMOTION_PRODUCT) {
      System.debug('when UPDATE_PROMOTION_PRODUCT ???');
      return ErpPromotionProductApiClient.updatePromotionProduct((ErpPromotionProductReqDto.UpdateRequestList) requestDto);
    }

    if (op == Operation.DELETE_PROMOTION_PRODUCT) {
      System.debug('when DELETE_PROMOTION_PRODUCT ???');
      return ErpPromotionProductApiClient.deletePromotionProduct((ErpPromotionProductReqDto.DeleteRequestList) requestDto);
    }

    throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
  }
}