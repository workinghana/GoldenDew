/**
 * ! 보류
 * MCE 관련 비동기 Job
 */
public with sharing class MceAsyncJob {
  /*
implements Queueable, Database.AllowsCallouts {
  protected String apiName;
  protected MceEventReqDto req;
  //   protected ErpAsyncCallback callback;
  //   protected Id recordId;
  //   protected Set<Id> recordIds;
  //   protected SObject o;

  public enum Operation {
    CREDIT_POINT, // 포인트 적립
    DEBIT_POINT // 포인트 차감
  }

  private Operation op;

  // public MceAsyncJob(Operation op, MceEventReqDto req) {
  //   // this.apiName = apiName;
  //   this.req = req;
  //   // this.callback = callback;
  //   this.op = op;
  // }
  public MceAsyncJob(Operation op, Id recordId) {
  }

  public void execute(QueueableContext ctx) {
    // ErpAsyncCallback publisherCb = new ErpAsyncCallbackPublisher();
    Id jobId = ctx.getJobId();
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, jobId, null);
    logger.logging(MceAsyncJob.class.getName());

    try {
      //   if (recordId != null) {
      //     logger.setRecordId(String.valueOf(recordId));
      //   }

      // logger.setRequestBody(req.toString());
      logger.setRequestDatetime(Datetime.now());

      //   ErpApiResponseDto res = doCallout();

      switch on op {
        // 포인트 적립
        when CREDIT_POINT {
          // 로그 객체 생성 (JobType: API)
          // ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
          // logger.logging(GdMemberApiControllerV1.class.getName());
          // MceEventReqDto req = new MceEventReqDto(reqMap);
          // req.setContactKey(v);
          System.debug('when CREDIT_POINT 진입');
          // MceEventResDto res = MceApiClient.sendInteractionEvent(req);
        }
        // // 쿠폰 개별 수정
        // when COUPON_UPDATE {
        //   System.debug('when COUPON_UPDATE 진입');
        //   return ErpCouponApiClient.couponUpdate((ErpCouponReqDto.UpdateRequest) requestDto);
        // }
        // // 쿠폰 마스터 생성
        // when CREATE_MASTER {
        //   System.debug('when CREATE_MASTER 진입');
        //   return ErpCouponApiClient.createMaster((ErpCouponMasterReqDto.IssueRequest) requestDto);
        // }
        // // 쿠폰 마스터 삭제
        // when DELETE_MASTER {
        //   System.debug('when DELETE_MASTER 진입');
        //   return ErpCouponApiClient.deleteMaster((ErpCouponMasterReqDto.DeleteRequest) requestDto);
        // }
        // // 쿠폰 마스터 수정
        // when UPDATE_MASTER {
        //   System.debug('when UPDATE_MASTER 진입');
        //   return ErpCouponApiClient.updateMaster((ErpCouponMasterReqDto.UpdateRequest) requestDto);
        // }
      }

      // 정상 처리시 로그
      logger.setStatus('SUCCESS');
      //   if (res.info.statusCode != null) {
      //     logger.setHttpStatusCode(String.valueOf(res.info.statusCode));
      //   }
      //   if (res.data != null) {
      //     logger.setResponseBody(res.data.toString());
      //   }
      //   if (res.info.requestUrl != null) {
      //     logger.setRequestUrl(res.info.requestUrl);
      //   }
      //   if (res.info.responseDateTime != null) {
      //     logger.setResponseDatetime(res.info.responseDateTime);
      //   }
      //   if (res.info.method != null) {
      //     logger.setMethod(res.info.method);
      //   }
      //   if (callback != null) {
      //     callback.onSuccess(apiName, requestDto, res);
      //   }
    } catch (HttpErrorException he) {
      //   System.debug('recordIds : ' + recordIds);
      //   logger.createHttpErrorExceptionLog(he);
      //   if (callback != null) {
      //     if (recordId != null) {
      //       if (o != null) {
      //         callback.onFailure(apiName, requestDto, he, recordId, o);
      //       } else {
      //         callback.onFailure(apiName, requestDto, he, recordId);
      //       }
      //       publisherCb.onFailure(apiName, requestDto, he, recordId);
      //     } else if (recordIds != null) {
      //       callback.onFailure(apiName, requestDto, he, recordIds);
      //       // publisherCb.onFailure(apiName, requestDto, he, null);  // 보류
      //     }
      //   }
    } catch (Exception e) {
      //   System.debug('recordIds : ' + recordIds);
      //   logger.createExceptionLog(e);
      //   if (callback != null) {
      //     if (recordId != null) {
      //       callback.onFailure(apiName, requestDto, e, recordId);
      //       publisherCb.onFailure(apiName, requestDto, e.getMessage(), recordId);
      //     } else if (recordIds != null) {
      //       System.debug('recordIds : ' + recordIds);
      //       callback.onFailure(apiName, requestDto, e, recordIds);
      //       // publisherCb.onFailure(apiName, requestDto, he, null);  // 보류
      //     }
      //   }
    } finally {
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }
}

// /**
//  * 쿠폰 관련 비동기 Job (통합)
//  * - 쿠폰 마스터/쿠폰 개별 등 모든 쿠폰 작업을 하나의 Queueable로 처리
//  */
  // public class ErpCouponJob extends ErpAsyncJob {
  //   // 어떤 작업인지 구분
  //   public enum Operation {
  //     CREATE_MASTER,
  //     UPDATE_MASTER,
  //     DELETE_MASTER,
  //     COUPON_ISSUE,
  //     COUPON_UPDATE,
  //     COUPON_DELETE
  //   }

  //   private Operation op;

  //   public ErpCouponJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId) {
  //     super(String.valueOf(op), requestDto, callback, recordId);
  //     this.op = op;
  //     // this.requestJson = (requestDto == null) ? null : JSON.serialize(requestDto);
  //   }

  //   public ErpCouponJob(Operation op, Object requestDto, ErpAsyncCallback callback, Set<Id> recordIds) {
  //     super(String.valueOf(op), requestDto, callback, recordIds);
  //     this.op = op;
  //     // this.requestJson = (requestDto == null) ? null : JSON.serialize(requestDto);
  //   }

  //   public ErpCouponJob(Operation op, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject o) {
  //     super(String.valueOf(op), requestDto, callback, recordId, o);
  //     this.op = op;
  //   }

  //   protected override ErpApiResponseDto doCallout() {
  //     // Id jobId = System.getJobId();
  //     // 로그 객체 생성 (JobType: API)
  //     // ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, jobId, null);
  //     // logger.logging(ErpCouponJob.class.getName());
  //     // Operation별로 요청 DTO를 복원해서 ErpCouponApiClient 동기 메서드 호출
  //     switch on op {
  //       when COUPON_ISSUE {
  //         // 로그 객체 생성 (JobType: API)
  //         // ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
  //         // logger.logging(GdMemberApiControllerV1.class.getName());

  //         System.debug('when COUPON_ISSUE 진입');
  //         return ErpCouponApiClient.couponIssue((ErpCouponReqDto.IssueRequest) requestDto);
  //       }
  //       when CREATE_MASTER {
  //         System.debug('when CREATE_MASTER 진입');
  //         return ErpCouponApiClient.createMaster((ErpCouponMasterReqDto.IssueRequest) requestDto);
  //       }
  //       when DELETE_MASTER {
  //         System.debug('when DELETE_MASTER 진입');
  //         return ErpCouponApiClient.deleteMaster((ErpCouponMasterReqDto.DeleteRequest) requestDto);
  //       }
  //       when UPDATE_MASTER {
  //         System.debug('when UPDATE_MASTER 진입');
  //         return ErpCouponApiClient.updateMaster((ErpCouponMasterReqDto.UpdateRequest) requestDto);
  //       }
  //     }

  //     // switch exhaustiveness 대비(컴파일러가 막아주긴 함)
  //     throw new IllegalArgumentException('Unsupported operation: ' + String.valueOf(op));
  //   }
  // }
}