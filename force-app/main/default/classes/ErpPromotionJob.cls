/**
 * 프로모션 관련 비동기 Job (통합)
 *
 * @author Changhwan Kim
 * @since 2026-01-27
 */
public class ErpPromotionJob extends ErpAsyncJob {
  // 어떤 작업인지 구분
  public enum Operation {
    CREATE_MASTER,
    UPDATE_MASTER,
    DELETE_MASTER
  }

  private Operation op;

  public ErpPromotionJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId) {
    super(String.valueOf(op), requestDto, callback, recordId);
    this.op = op;
  }

  public ErpPromotionJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject o) {
    super(String.valueOf(op), requestDto, callback, recordId, o);
    this.op = op;
  }

  protected override ErpApiResponseDto doCallout() {
    switch on op {
      when CREATE_MASTER {
        System.debug('when CREATE_MASTER 진입');
        return ErpPromotionApiClient.createMaster((ErpPromotionReqDto.CreateRequest) requestDto);
      }
      when DELETE_MASTER {
        System.debug('when DELETE_MASTER 진입');
        return ErpPromotionApiClient.deleteMaster((ErpPromotionReqDto.DeleteRequest) requestDto);
      }
      when UPDATE_MASTER {
        System.debug('when UPDATE_MASTER 진입');
        return ErpPromotionApiClient.updateMaster((ErpPromotionReqDto.UpdateRequest) requestDto);
      }
    }

    // switch exhaustiveness 대비(컴파일러가 막아주긴 함)
    throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
  }
}