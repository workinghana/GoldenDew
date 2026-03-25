/**
 * todo: 개발 필요
 * 포인트 관련 비동기 Job (통합)
 * - 포인트 작업을 하나의 Queueable로 처리
 */
public class ErpPointJob extends ErpAsyncJob {
  // 어떤 작업인지 구분
  public enum Operation {
    POINT_EXPIRY,
    POINT_CREDIT
  }

  private Operation op;

  public ErpPointJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId) {
    super(String.valueOf(op), requestDto, callback, recordId);
    this.op = op;
  }

  public ErpPointJob(Operation op, Object requestDto, ErpAsyncCallback callback, Set<Id> recordIds) {
    super(String.valueOf(op), requestDto, callback, recordIds);
    this.op = op;
  }

  public ErpPointJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject o) {
    super(String.valueOf(op), requestDto, callback, recordId, o);
    this.op = op;
  }

  protected override ErpApiResponseDto doCallout() {
    // Operation별로 요청 DTO를 복원해서 ErpCouponApiClient 동기 메서드 호출
    switch on op {
      // 포인트 소멸
      when POINT_EXPIRY {
        System.debug('when POINT_EXPIRY 진입');
        return ErpPointApiClient.expiryPoint((ErpPointReqDto.ExpiryRequest) requestDto);
      }
      // 포인트 지급
      when POINT_CREDIT {
        System.debug('when POINT_CREDIT 진입');
        return ErpPointApiClient.creditPoint((ErpPointReqDto.CreditRequest) requestDto);
      }
    }

    // switch exhaustiveness 대비(컴파일러가 막아주긴 함)
    throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
  }
}