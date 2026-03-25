/**
 * ERP 비동기 Job 공통 템플릿
 * - callout 허용
 * - 성공/실패 콜백 표준화
 *
 * @author Changhwan Kim
 */
public abstract class ErpAsyncJob implements Queueable, Database.AllowsCallouts {
  protected String apiName;
  protected Object requestDto;
  protected ErpAsyncCallback callback;
  protected Id recordId;
  protected Set<Id> recordIds;
  protected SObject o;

  protected ErpAsyncJob(String apiName, Object requestDto, ErpAsyncCallback callback) {
    this.apiName = apiName;
    this.requestDto = requestDto;
    this.callback = callback;
  }

  protected ErpAsyncJob(String apiName, Object requestDto, ErpAsyncCallback callback, Id recordId) {
    this.apiName = apiName;
    this.requestDto = requestDto;
    this.callback = callback;
    this.recordId = recordId;
  }

  protected ErpAsyncJob(String apiName, Object requestDto, ErpAsyncCallback callback, Set<Id> recordIds) {
    this.apiName = apiName;
    this.requestDto = requestDto;
    this.callback = callback;
    this.recordIds = recordIds;
  }

  protected ErpAsyncJob(String apiName, Object requestDto, ErpAsyncCallback callback, Id recordId, SObject o) {
    this.apiName = apiName;
    this.requestDto = requestDto;
    this.callback = callback;
    this.recordId = recordId;
    this.o = o;
  }

  // 실제 호출 구현은 서브클래스에서
  protected abstract ErpApiResponseDto doCallout();

  public void execute(QueueableContext ctx) {
    ErpAsyncCallback publisherCb = new ErpAsyncCallbackPublisher();
    Id jobId = ctx.getJobId();
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, jobId, null);
    logger.logging(ErpAsyncJob.class.getName());

    try {
      if (recordId != null) {
        logger.setRecordId(String.valueOf(recordId));
      }

      logger.setRequestBody(toLongTextJson(requestDto));
      logger.setRequestDatetime(Datetime.now());

      ErpApiResponseDto res = doCallout();

      // 정상 처리시 로그
      logger.setStatus('SUCCESS');
      if (res.info.statusCode != null) {
        logger.setHttpStatusCode(String.valueOf(res.info.statusCode));
      }
      if (res.data != null) {
        logger.setResponseBody(toLongTextJson(res.data));
      }
      if (res.info.requestUrl != null) {
        logger.setRequestUrl(res.info.requestUrl);
      }
      if (res.info.responseDateTime != null) {
        logger.setResponseDatetime(res.info.responseDateTime);
      }
      if (res.info.method != null) {
        logger.setMethod(res.info.method);
      }
      if (callback != null) {
        callback.onSuccess(apiName, requestDto, res);
      }
    } catch (HttpErrorException he) {
      System.debug('recordIds : ' + recordIds);
      logger.createHttpErrorExceptionLog(he);
      if (callback != null) {
        if (recordId != null) {
          if (o != null) {
            callback.onFailure(apiName, requestDto, he, recordId, o);
          } else {
            callback.onFailure(apiName, requestDto, he, recordId);
          }
          publisherCb.onFailure(apiName, requestDto, he, recordId);
        } else if (recordIds != null) {
          callback.onFailure(apiName, requestDto, he, recordIds);
          publisherCb.onFailure(apiName, requestDto, he, recordIds);
        }
      }
    } catch (Exception e) {
      System.debug('recordIds : ' + recordIds);
      logger.createExceptionLog(e);
      if (callback != null) {
        if (recordId != null) {
          callback.onFailure(apiName, requestDto, e, recordId);
          publisherCb.onFailure(apiName, requestDto, e.getMessage(), recordId);
        } else if (recordIds != null) {
          System.debug('recordIds : ' + recordIds);
          callback.onFailure(apiName, requestDto, e, recordIds);
          // publisherCb.onFailure(apiName, requestDto, he, null);  // 보류
        }
      }
    } finally {
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  // Long Text Area 최대 길이(필드 설정이 131,072이면 그대로)
  private static final Integer DEFAULT_MAX_LEN = 131072;

  /**
   * 객체를 Audit Log(긴 텍스트 영역)에 저장하기 좋은 문자열로 변환한다.
   * - toString() 대신 JSON.serialize 사용
   * - maxLen 초과 시 안전하게 substring
   */
  public String toLongTextJson(Object obj) {
    return toLongTextJson(obj, DEFAULT_MAX_LEN, true);
  }

  // /**
  //  * @param obj        저장할 객체(요청 DTO 등)
  //  * @param maxLen     필드 최대 길이 (예: 131072)
  //  * @param addEllipsis 자를 때 끝에 "..."를 붙일지 여부
  //  */
  public String toLongTextJson(Object obj, Integer maxLen, Boolean addEllipsis) {
    if (obj == null) {
      return null;
    }

    // maxLen 방어
    Integer limitLength = (maxLen == null || maxLen <= 0) ? DEFAULT_MAX_LEN : maxLen;

    String json;
    try {
      json = System.JSON.serialize(obj);
    } catch (Exception e) {
      // 직렬화 실패 시에도 로그가 완전히 비지 않게 최소 정보 저장
      json = '{"_serializeError":"' + escapeForJson(e.getMessage()) + '"}';
    }

    if (json == null) {
      return null;
    }
    if (json.length() <= limitLength) {
      return json;
    }

    if (addEllipsis == true && limitLength > 3) {
      return json.substring(0, limitLength - 3) + '...';
    }
    return json.substring(0, limitLength);
  }

  // JSON 문자열에 넣기 위한 최소 이스케이프
  private String escapeForJson(String s) {
    if (s == null) {
      return '';
    }
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t');
  }
}