public without sharing class ApexLogger {
  // =================================================================================================================
  // Class Variables

  // 작업의 유형, 특정 작업에 따른 로깅을 위해 사용
  private JobType jobType;
  // 비동기 작업의 레코드 아이디
  private Id jobId, childJobId;
  // 인터페이스 마스터 레코드 아이디
  private Id interfaceId;
  // 단일 로그 항목, 여러개의 로그를 적재하는 경우 리스트에 추가할 때 초기화
  private Log log;
  // 로그 리스트
  private static List<Log> logs = new List<Log>();
  // 로그 적재 여부 설정
  private static Boolean disableLogging = false;

  // =================================================================================================================
  // Constructor

  /**
   * 기본 생성자 비공개
   */
  private ApexLogger() {
  }

  /**
   * Action 유형의 작업을 로깅할 때 사용되는 생성자
   * @param jobType 로깅할 작업 유형
   */
  public ApexLogger(JobType jobType) {
    this.jobType = jobType;
  }

  /**
   * Asynchronous 유형의 작업을 로깅할 때 사용되는 생성자
   * @param jobType 로깅할 작업 유형
   * @param jobId 비동기 Job Id
   * @param childJobId 현재 처리 중인 작업 청크의 Id
   */
  public ApexLogger(JobType jobType, Id jobId, Id childJobId) {
    this(jobType);
    this.jobId = jobId;
    this.childJobId = childJobId;
  }

  /**
   * Interface 유형의 작업을 로깅할 때 사용되는 생성자
   * @param jobType 로깅할 작업 유형
   * @param interfaceId Interface 마스터 레코드 Id
   */
  public ApexLogger(JobType jobType, Id interfaceId) {
    this(jobType);
    this.interfaceId = interfaceId;
  }

  // =================================================================================================================
  // Start Logging

  /**
   * 로깅 시작
   * @param className 실행 된 클래스 명
   */
  public void logging(String className) {
    this.createLog();
    this.log.info.apexClass = className;
  }

  /**
   * 콜아웃이 여러번 발생하는 경우, API 실행이 모두 종료된 후 로그 적재
   */
  // public static void skipCalloutLogging() {
  // 수동 로깅 기능 활성화 여부
  // DN_BaseCallout.isManualLoggingEnabled = true;
  // }

  /**
   * 로그를 적재하지 않음
   */
  public static void disableLogging() {
    disableLogging = true;
  }

  // =================================================================================================================
  // Finish Logging

  /**
   * 생성할 로그 리스트에 추가
   * - 로그 레코드의 수정을 모두 완료한 후 호출할 것
   */
  public void addLog() {
    this.log.info.endTime = System.currentTimeMillis();
    logs.add(this.log);
  }

  /**
   * 로그 리스트를 ApexAuditTrail__c 레코드로 변환하여 적재
   * 인터페이스 로그의 경우, 요청 및 응답 값을 텍스트 파일로 저장
   * - 트랜잭션의 모든 작업이 완료된 후 호출할 것
   */
  public static void insertLogs() {
    if (disableLogging) {
      return;
    }

    // Http Status Code Map
    // Map<String, String> httpStatusCodeMap = new Map<String, String>();
    // for (PicklistEntry pe : DN_Interface__c.SuccessStatusCode__c.getDescribe().getPicklistValues()) {
    //   httpStatusCodeMap.put(pe.getValue(), pe.getLabel());
    // }

    // create Logs
    List<ApexAuditTrail__c> auditLogs = new List<ApexAuditTrail__c>();
    for (Log log : logs) {
      // create Logs
      ApexAuditTrail__c audit = new ApexAuditTrail__c();
      audit.StartTimeMillis__c = log.info.startTime;
      audit.EndTimeMillis__c = log.info.endTime;
      audit.OwnerId = log.info.ownerId;
      //   audit.RecordTypeId = log.info.recordTypeId;
      //   audit.l_Interface__c = log.info.interfaceId;
      //   audit.JobId__c = log.info.jobId;
      //   audit.RecordId__c = log.info.recordId;
      audit.ErrorCode__c = log.info.errorCode;
      audit.Status__c = log.info.status;
      if (log.info.method != null) {
        audit.Method__c = log.info.method;
      }
      //   if (log.info.httpStatusCode != null) {
      // String httpStatusCode = String.valueOf(log.info.httpStatusCode);
      // audit.HttpStatusCode__c = httpStatusCodeMap.get(httpStatusCode) ?? httpStatusCode;
      audit.HttpStatusCode__c = log.info.httpStatusCode;
      //   }
      audit.RequestUrl__c = log.info.requestUrl;
      audit.RequestDateTime__c = log.info.requestDatetime;
      audit.ResponseDateTime__c = log.info.responseDatetime;
      audit.ApexClass__c = log.info.apexClass;
      //   audit.ChildJobId__c = log.info.childJobId;
      audit.IsBatch__c = log.info.isBatch;
      audit.IsFunctionCallback__c = log.info.isFunctionCallback;
      audit.IsFuture__c = log.info.isFuture;
      audit.IsQueueable__c = log.info.isQueueable;
      audit.IsScheduled__c = log.info.isScheduled;
      audit.Description__c = log.info.description;
      audit.ScopedIds__c = log.scopedIds;
      audit.SuccessRecordIds__c = log.successRecordIds;
      audit.FailedRecordIds__c = log.failedRecordIds;

      // System.debug(log.errorMessage);
      if (String.isNotBlank(log.errorMessage)) {
        audit.ErrorMessage__c = log.errorMessage.left(131072);
      }
      audit.StackTrace__c = log.stackTrace;
      if (String.isNotBlank(log.requestBody)) {
        audit.RequestBody__c = log.requestBody.left(131072);
      }
      if (String.isNotBlank(log.responseBody)) {
        audit.ResponseBody__c = log.responseBody.left(131072);
      }

      auditLogs.add(audit);
    }

    insert auditLogs;

    // create Interface Files
    // List<Attachment> attachments = new List<Attachment>();
    // for (Integer i = 0; i < auditLogs.size(); i++) {
    //   ApexAuditTrail__c audit = auditLogs.get(i);
    //   Log log = logs.get(i);

    // 인터페이스 로그가 아니면 파일을 생성하지 않음
    //   if (audit.l_Interface__c == null) {
    // continue;
    //   }
    // 오류 발생으로 인해서 Request, Response Body 가 없는 경우 파일을 생성하지 않음
    // if (audit.RequestBody__c == null || audit.ResponseBody__c == null) {
    //   continue;
    // }

    // 요청 및 응답 본문의 길이가 필드 길이를 초과하는 경우에만 파일 생성
    //   if (log.requestBody.length() > 131072) {
    //     attachments.add(
    //       new Attachment(
    //         Name = String.format(Label.DN_lab_InterfaceLogFileNameRequest, new List<Object>{ audit.Id }) + '.txt',
    //         Body = EncodingUtil.base64Decode(EncodingUtil.base64Encode(Blob.valueOf(log.responseBody))),
    //         ParentId = audit.Id
    //       )
    //     );
    //   }
    //   if (log.responseBody.length() > 131072) {
    //     attachments.add(
    //       new Attachment(
    //         Name = String.format(Label.DN_lab_InterfaceLogFileNameResponse, new List<Object>{ audit.Id }) + '.txt',
    //         Body = Blob.valueOf(log.responseBody),
    //         ParentId = audit.Id
    //       )
    //     );
    //   }

    //sji 2501001
    //   if (log.errorMessage?.length() != null && log.errorMessage.length() > 131072) {
    //     attachments.add(
    //       new Attachment(
    //         Name = String.format('FAIL_' + Label.DN_lab_InterfaceLogFileNameResponse, new List<Object>{ audit.Id }) + '.txt',
    //         Body = Blob.valueOf(log.errorMessage),
    //         ParentId = audit.Id
    //       )
    //     );
    //   }
    // }

    // if (!attachments.isEmpty()) {
    // insert attachments;
    // }

    // 레코드 생성 이후 로그 리스트 초기화
    logs.clear();
  }

  // =================================================================================================================
  // Getters and Setters

  /**
   * 레코드 리스트의 Id 혹은 고유 식별키를 Set 으로 반환
   * @param scope 레코드 리스트
   * @param fieldName Id 혹은 식별키로 사용할 필드명
   * @return Id 혹은 키 값들을 Set 으로 반환
   */
  public Set<String> getScopedIds(List<SObject> scope, String fieldName) {
    Set<String> scopedIds = new Set<String>();
    for (SObject sObj : scope) {
      scopedIds.add((String) sObj.get(fieldName));
    }

    return scopedIds;
  }

  /**
   * scopedIds 값 직접 설정
   * @param scopedIds Log.scopedIds
   */
  public void setScopedIds(Set<String> scopedIds) {
    this.log.scopedIds = String.join(scopedIds, ';');
  }

  /**
   * SObject 리스트에서 특정 필드의 값을 추출하여 scopedIds 값 설정
   * @param scope 레코드 리스트
   * @param fieldName Id 혹은 식별키로 사용할 필드명
   */
  public void setScopedIds(List<SObject> scope, String fieldName) {
    this.log.scopedIds = String.join(getScopedIds(scope, fieldName), ';');
  }

  /**
   * recordId 값 설정
   * @param recordId LogInfo.recordId
   */
  public void setRecordId(String recordId) {
    this.log.info.recordId = recordId;
  }

  /**
   * description 값 설정
   * @param description LogInfo.description
   */
  public void setDescription(String description) {
    this.log.info.description = description;
  }

  /**
   * status 값 설정
   * @param status LogInfo.status
   */
  public void setStatus(String status) {
    this.log.info.status = status;
  }

  /**
   * status 값 설정
   * @param status LogInfo.status
   */
  public void setMethod(String method) {
    this.log.info.method = method;
  }

  /**
   * errorCode 값 설정
   * @param errorCode LogInfo.errorCode
   */
  public void setErrorCode(String errorCode) {
    this.log.info.errorCode = errorCode;
  }

  /**
   * errorMessage 값 설정
   * @param message Log.errorMessage
   */
  public void setErrorMessage(String message) {
    this.log.errorMessage = message;
  }

  /**
   * stackTrace 값 설정
   * @param stackTrace Log.stackTrace
   */
  public void setStackTrace(String stackTrace) {
    this.log.stackTrace = stackTrace;
  }

  /**
   * httpStatusCode 값 설정
   * @param httpStatusCode LogInfo.httpStatusCode
   */
  public void setHttpStatusCode(String httpStatusCode) {
    this.log.info.httpStatusCode = httpStatusCode;
  }

  /**
   * requestUrl 값 설정
   * @param requestUrl LogInfo.requestUrl
   */
  public void setRequestUrl(String requestUrl) {
    this.log.info.requestUrl = requestUrl;
  }

  /**
   * requestBody 값 설정
   * @param requestBody Log.requestBody
   */
  public void setRequestBody(String requestBody) {
    this.log.requestBody = requestBody;
  }

  /**
   * responseBody 값 설정
   * @param responseBody Log.responseBody
   */
  public void setResponseBody(String responseBody) {
    this.log.responseBody = responseBody;
  }

  /**
   * requestDatetime 값 설정
   * @param requestDatetime LogInfo.requestDatetime
   */
  public void setRequestDatetime(Datetime requestDatetime) {
    this.log.info.requestDatetime = requestDatetime;
  }

  /**
   * responseDatetime 값 설정
   * @param responseDatetime LogInfo.responseDatetime
   */
  public void setResponseDatetime(Datetime responseDatetime) {
    this.log.info.responseDatetime = responseDatetime;
  }

  /**
   * successRecordIds 값 설정
   * @param successRecordIds Log.successRecordIds
   */
  public void setSuccessRecordIds(Set<String> successRecordIds) {
    this.log.successRecordIds = String.join(successRecordIds, ';');
  }

  /**
   * failedRecordIds 값 설정
   * @param failedRecordIds Log.failedRecordIds
   */
  public void setFailedRecordIds(Set<String> failedRecordIds) {
    this.log.failedRecordIds = String.join(failedRecordIds, ';');
  }

  // =================================================================================================================
  // Private Methods

  /**
   * 로그 오브젝트 생성 및 기본값 설정
   */
  private void createLog() {
    this.log = new Log();
    this.log.info = new LogInfo();

    this.log.info.startTime = System.currentTimeMillis();
    // this.log.info.recordTypeId = getRecordTypeId();
    this.log.info.interfaceId = this.interfaceId;
    this.log.info.jobId = this.jobId;
    this.log.info.childJobId = this.childJobId;
    this.log.info.isBatch = System.isBatch();
    this.log.info.isFunctionCallback = System.isFunctionCallback();
    this.log.info.isFuture = System.isFuture();
    this.log.info.isQueueable = System.isQueueable();
    this.log.info.isScheduled = System.isScheduled();
    this.log.info.ownerId = UserInfo.getUserId();
  }

  /**
   * CustomException 로그 생성
   */
  public void createCustomExceptionLog(CustomException ce) {
    this.log.info.responseDatetime = Datetime.now();
    this.log.info.status = 'ERROR';
    this.log.info.errorCode = 'CUSTOM_EXCEPTION';
    this.log.errorMessage = ce.message;
    this.log.stackTrace = ce.getStackTraceString().split('\n')[0];
    this.log.info.responseDatetime = Datetime.now();
  }

  /**
   * Exception 로그 생성
   */
  public void createExceptionLog(Exception e) {
    this.log.info.responseDatetime = Datetime.now();
    this.log.info.status = 'ERROR';
    this.log.info.errorCode = 'EXCEPTION';
    this.log.errorMessage = e.getMessage();
    this.log.stackTrace = e.getStackTraceString().split('\n')[0];
    this.log.info.responseDatetime = Datetime.now();
  }

  /**
   * HttpErrorException 로그 생성
   */
  public void createHttpErrorExceptionLog(HttpErrorException he) {
    this.log.info.responseDatetime = Datetime.now();
    this.log.info.requestUrl = he.endpoint;
    this.log.responseBody = he.responseBody;
    this.log.info.httpStatusCode = String.valueOf(he.statusCode);
    this.log.info.status = 'ERROR';
    this.log.info.method = he.method;
    this.log.info.errorCode = 'HTTP_ERROR_EXCEPTION';
    this.log.errorMessage = he.getMessage();
    this.log.stackTrace = he.getStackTraceString().split('\n')[0];
  }

  /**
   * JobType 에 해당하는 Record Type Id 를 반환
   * @return ApexAuditTrail__c.RecordTypeId
   */
  //   private Id getRecordTypeId() {
  //     String rtDevName;
  //     switch on this.jobType {
  //       when API {
  //         rtDevName = 'Interface';
  //       }
  //       when ASYNCHRONOUS {
  //         rtDevName = 'Async';
  //       }
  //       when ACTION {
  //         rtDevName = 'Action';
  //       }
  //       when else {
  //       }
  //     }

  //     return Schema.SObjectType.ApexAuditTrail__c.getRecordTypeInfosByDeveloperName().get(rtDevName).getRecordTypeId();
  //   }

  // =================================================================================================================
  // Data Transfer Object

  public class Log {
    public LogInfo info;
    public String scopedIds;
    public String errorMessage;
    public String requestBody;
    public String responseBody;
    public String stackTrace;
    public String successRecordIds;
    public String failedRecordIds;
  }

  public class LogInfo {
    public String recordTypeId;
    public String interfaceId;
    public String apexClass;
    public String childJobId;
    public Boolean isBatch;
    public Boolean isFunctionCallback;
    public Boolean isFuture;
    public Boolean isQueueable;
    public Boolean isScheduled;
    public String jobId;
    public String recordId;
    public String errorCode;
    public String httpStatusCode;
    public String requestUrl;
    public Datetime requestDatetime;
    public Datetime responseDatetime;
    public String status; // Picklist (ERROR | PARTIAL | SUCCESS)
    public String method; // Picklist (GET | POST | PATCH | PUT | DELETE)
    public String guid;
    public String description;
    public Long startTime;
    public Long endTime;
    public String ownerId;
  }

  // =================================================================================================================
  // Enum

  public enum JobType {
    API,
    ASYNCHRONOUS,
    ACTION
  }
}