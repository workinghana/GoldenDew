public class ErpPromotionStoreJob extends ErpAsyncJob {
  public enum Operation {
    CREATE_PROMOTION_STORE,
    UPDATE_PROMOTION_STORE,
    DELETE_PROMOTION_STORE
  }

  private Operation op;

  public ErpPromotionStoreJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId) {
    super(String.valueOf(op), requestDto, callback, recordId);
    this.op = op;
  }

  public ErpPromotionStoreJob(Operation op, Object requestDto, ErpAsyncCallback callback, Set<Id> recordIds) {
    super(String.valueOf(op), requestDto, callback, recordIds);
    this.op = op;
  }

  public ErpPromotionStoreJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject oldObj) {
    super(String.valueOf(op), requestDto, callback, recordId, oldObj);
    this.op = op;
  }

  protected override ErpApiResponseDto doCallout() {
    if (op == Operation.CREATE_PROMOTION_STORE) {
      return ErpPromotionStoreApiClient.createPromotionStore((ErpPromotionStoreReqDto.CreateRequestList) requestDto);
    }

    if (op == Operation.UPDATE_PROMOTION_STORE) {
      return ErpPromotionStoreApiClient.updatePromotionStore((ErpPromotionStoreReqDto.UpdateRequestList) requestDto);
    }

    if (op == Operation.DELETE_PROMOTION_STORE) {
      return ErpPromotionStoreApiClient.deletePromotionStore((ErpPromotionStoreReqDto.DeleteRequestList) requestDto);
    }

    throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
  }
}