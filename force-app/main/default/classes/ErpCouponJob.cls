/**
 * 쿠폰 관련 비동기 Job (통합)
 * - 쿠폰 마스터/쿠폰 개별 등 모든 쿠폰 작업을 하나의 Queueable로 처리
 */
public class ErpCouponJob extends ErpAsyncJob {
  // 어떤 작업인지 구분
  public enum Operation {
    CREATE_MASTER,
    UPDATE_MASTER,
    DELETE_MASTER,
    COUPON_ISSUE,
    COUPON_UPDATE,
    COUPON_DELETE
  }

  private Operation op;

  public ErpCouponJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId) {
    super(String.valueOf(op), requestDto, callback, recordId);
    this.op = op;
    // this.requestJson = (requestDto == null) ? null : JSON.serialize(requestDto);
  }

  public ErpCouponJob(Operation op, Object requestDto, ErpAsyncCallback callback, Set<Id> recordIds) {
    super(String.valueOf(op), requestDto, callback, recordIds);
    this.op = op;
    // this.requestJson = (requestDto == null) ? null : JSON.serialize(requestDto);
  }

  public ErpCouponJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject o) {
    super(String.valueOf(op), requestDto, callback, recordId, o);
    this.op = op;
  }

  protected override ErpApiResponseDto doCallout() {
    // Id jobId = System.getJobId();
    // 로그 객체 생성 (JobType: API)
    // ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, jobId, null);
    // logger.logging(ErpCouponJob.class.getName());
    // Operation별로 요청 DTO를 복원해서 ErpCouponApiClient 동기 메서드 호출
    switch on op {
      // 쿠폰 개별 지급
      when COUPON_ISSUE {
        // 로그 객체 생성 (JobType: API)
        // ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
        // logger.logging(GdMemberApiControllerV1.class.getName());

        System.debug('when COUPON_ISSUE 진입');
        return ErpCouponApiClient.couponIssue((ErpCouponReqDto.IssueRequest) requestDto);
      }
      // 쿠폰 개별 수정
      when COUPON_UPDATE {
        System.debug('when COUPON_UPDATE 진입');
        return ErpCouponApiClient.couponUpdate((ErpCouponReqDto.UpdateRequest) requestDto);
      }
      // 쿠폰 마스터 생성
      when CREATE_MASTER {
        System.debug('when CREATE_MASTER 진입');
        return ErpCouponApiClient.createMaster((ErpCouponMasterReqDto.IssueRequest) requestDto);
      }
      // 쿠폰 마스터 삭제
      when DELETE_MASTER {
        System.debug('when DELETE_MASTER 진입');
        return ErpCouponApiClient.deleteMaster((ErpCouponMasterReqDto.DeleteRequest) requestDto);
      }
      // 쿠폰 마스터 수정
      when UPDATE_MASTER {
        System.debug('when UPDATE_MASTER 진입');
        return ErpCouponApiClient.updateMaster((ErpCouponMasterReqDto.UpdateRequest) requestDto);
      }
    }

    // switch exhaustiveness 대비(컴파일러가 막아주긴 함)
    throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
  }
}