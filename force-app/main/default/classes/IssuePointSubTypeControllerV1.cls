public with sharing class IssuePointSubTypeControllerV1 {
  private static final Set<String> MEMBER_NO_COLUMN_NAMES = new Set<String>{
    'NO_MBR',
    'MemberNo__c',
    'MemberNo',
    '회원번호',
    '회원 번호',
    '멤버십번호',
    '멤버십 번호'
  };
  public static final String JOB_STATUS_PENDING = 'PENDING';
  public static final String JOB_STATUS_PROCESSING = 'PROCESSING';
  public static final String JOB_STATUS_COMPLETED = 'COMPLETED';
  public static final String JOB_STATUS_FAILED = 'FAILED';
  public static final Integer VALIDATION_BATCH_SCOPE_SIZE = 200;
  public static final String SOURCE_FILE_MARKER_PREFIX = 'POINT_UPLOAD_SOURCE:';
  public static final String SUMMARY_FILE_MARKER_PREFIX = 'POINT_UPLOAD_SUMMARY:';
  private static Map<String, String> displayLabelByApiName;
  @AuraEnabled
  public static UploadJobStartResult startPointFileValidation(String base64Data, String fileName, Id subtypeId) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(IssuePointSubTypeControllerV1.class.getName());
    logger.setMethod('startPointFileValidation');
    logger.setRequestDatetime(Datetime.now());
    logger.setDescription('fileName=' + fileName + ', subtypeId=' + subtypeId + ', scope=' + VALIDATION_BATCH_SCOPE_SIZE);
    logger.setRequestBody('base64Length=' + (base64Data == null ? null : base64Data.length()));
    System.debug(LoggingLevel.ERROR, 'UPLOAD enter');
    System.debug(LoggingLevel.ERROR, 'UPLOAD fileName=' + fileName);
    System.debug(LoggingLevel.ERROR, 'UPLOAD subtypeId=' + subtypeId);
    System.debug(LoggingLevel.ERROR, 'UPLOAD scope=' + VALIDATION_BATCH_SCOPE_SIZE);
    System.debug(LoggingLevel.ERROR, 'UPLOAD base64 length=' + (base64Data == null ? null : base64Data.length()));
    if (String.isBlank(base64Data)) {
      logger.setStatus('ERROR');
      logger.setErrorCode('INVALID_FILE_DATA');
      logger.setErrorMessage('파일 데이터가 없습니다.');
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      insertLoggerSafely();
      throw new AuraHandledException('파일 데이터가 없습니다.');
    }
    ContentVersion contentVersion = new ContentVersion(
      Title = String.isBlank(fileName) ? 'point-upload.csv' : fileName,
      PathOnClient = String.isBlank(fileName) ? 'point-upload.csv' : fileName,
      VersionData = EncodingUtil.base64Decode(base64Data),
      IsMajorVersion = true
    );
    try {
      insert contentVersion;
      System.debug(LoggingLevel.ERROR, 'UPLOAD contentVersionId=' + contentVersion.Id);
      logger.setResponseBody('contentVersionId=' + contentVersion.Id);
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'UPLOAD contentVersion insert error=' + e.getMessage());
      System.debug(LoggingLevel.ERROR, 'UPLOAD contentVersion insert stack=' + e.getStackTraceString());
      logger.createExceptionLog(e);
      logger.setDescription('phase=insertContentVersion, fileName=' + fileName + ', subtypeId=' + subtypeId);
      logger.addLog();
      insertLoggerSafely();
      throw e;
    }

    Id batchJobId;
    try {
      batchJobId = Database.executeBatch(new IssuePointSubTypeValidationBatch(contentVersion.Id), VALIDATION_BATCH_SCOPE_SIZE);
      System.debug(LoggingLevel.ERROR, 'UPLOAD batchJobId=' + batchJobId);
      logger.setResponseBody('contentVersionId=' + contentVersion.Id + ', batchJobId=' + batchJobId);
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'UPLOAD executeBatch error=' + e.getMessage());
      System.debug(LoggingLevel.ERROR, 'UPLOAD executeBatch stack=' + e.getStackTraceString());
      logger.createExceptionLog(e);
      logger.setDescription('phase=executeBatch, contentVersionId=' + contentVersion.Id + ', scope=' + VALIDATION_BATCH_SCOPE_SIZE);
      logger.addLog();
      insertLoggerSafely();
      throw e;
    }

    try {
      update new ContentVersion(Id = contentVersion.Id, Description = buildSourceDescription(batchJobId));
      System.debug(LoggingLevel.ERROR, 'UPLOAD description updated');
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'UPLOAD contentVersion update error=' + e.getMessage());
      System.debug(LoggingLevel.ERROR, 'UPLOAD contentVersion update stack=' + e.getStackTraceString());
      logger.createExceptionLog(e);
      logger.setDescription('phase=updateContentVersion, contentVersionId=' + contentVersion.Id + ', batchJobId=' + batchJobId);
      logger.addLog();
      insertLoggerSafely();
      throw e;
    }
    logger.setStatus('SUCCESS');
    logger.setDescription(
      'phase=completed, contentVersionId=' + contentVersion.Id + ', batchJobId=' + batchJobId + ', scope=' + VALIDATION_BATCH_SCOPE_SIZE
    );
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    insertLoggerSafely();
    UploadJobStartResult result = new UploadJobStartResult();
    result.uploadJobId = batchJobId;
    result.batchJobId = batchJobId;
    result.status = JOB_STATUS_PROCESSING;
    return result;
  }
  @AuraEnabled
  public static UploadJobStatusResult getPointFileValidationStatus(Id uploadJobId) {
    if (uploadJobId == null) {
      throw new AuraHandledException('업로드 작업 정보가 없습니다.');
    }
    AsyncApexJob asyncJob = [
      SELECT Id, Status, ExtendedStatus
      FROM AsyncApexJob
      WHERE Id = :uploadJobId
      LIMIT 1
    ];
    UploadJobStatusResult result = new UploadJobStatusResult();
    result.uploadJobId = uploadJobId;
    result.status = mapAsyncJobStatus(asyncJob.Status);
    result.totalCount = 0;
    result.successCount = 0;
    result.failCount = 0;
    result.errorMessage = result.status == JOB_STATUS_FAILED ? toDisplayLabelMessage(asyncJob.ExtendedStatus) : null;
    result.errors = new List<MemberErrorDTO>();
    ValidationSummaryFile summary = loadValidationSummary(uploadJobId);
    if (summary != null) {
      result.status = summary.status;
      result.totalCount = summary.totalCount == null ? 0 : summary.totalCount;
      result.successCount = summary.successCount == null ? 0 : summary.successCount;
      result.failCount = summary.failCount == null ? 0 : summary.failCount;
      result.errorMessage = String.isBlank(summary.errorMessage) ? result.errorMessage : toDisplayLabelMessage(summary.errorMessage);
      result.errors = summary.errors == null ? new List<MemberErrorDTO>() : summary.errors;
    } else if (result.status == JOB_STATUS_COMPLETED) {
      UploadPreviewResult previewResult = buildUploadPreviewFromSource(uploadJobId);
      result.totalCount = previewResult.successCount + previewResult.failCount;
      result.successCount = previewResult.successCount;
      result.failCount = previewResult.failCount;
      result.errors = previewResult.errors == null ? new List<MemberErrorDTO>() : previewResult.errors;
    }
    result.isCompleted = result.status == JOB_STATUS_COMPLETED;
    result.isFailed = result.status == JOB_STATUS_FAILED;
    return result;
  }
  @AuraEnabled
  public static UploadPreviewResult parsePointFile(String base64Data) {
    if (String.isBlank(base64Data)) {
      throw new AuraHandledException('파일 데이터가 없습니다.');
    }
    return buildUploadPreviewFromText(normalizeFileText(EncodingUtil.base64Decode(base64Data).toString()));
  }
  private static List<String> splitByNewline(String text) {
    List<String> lines = new List<String>();
    if (text == null) {
      return lines;
    }
    Integer startIdx = 0;
    Integer newlineIdx = text.indexOf('\n', startIdx);
    while (newlineIdx != -1) {
      lines.add(text.substring(startIdx, newlineIdx));
      startIdx = newlineIdx + 1;
      newlineIdx = text.indexOf('\n', startIdx);
    }
    if (startIdx < text.length()) {
      lines.add(text.substring(startIdx));
    } else if (text.endsWith('\n')) {
      lines.add('');
    }
    return lines;
  }
  @AuraEnabled
  public static IssuePointResult issuePointByUploadJob(Id uploadJobId, Id subtypeId, Decimal pointAmount, Date expireDate) {
    if (uploadJobId == null) {
      throw new AuraHandledException('업로드 작업 정보가 없습니다.');
    }
    UploadPreviewResult previewResult = buildUploadPreviewFromSource(uploadJobId);
    return issuePoint(previewResult.successMemberIds, subtypeId, pointAmount, expireDate);
  }
  @AuraEnabled
  public static IssuePointResult issuePoint(List<Id> memberIds, Id subtypeId, Decimal pointAmount, Date expireDate) {
    if (memberIds == null || memberIds.isEmpty()) {
      throw new AuraHandledException('지급할 회원이 없습니다.');
    }
    if (subtypeId == null) {
      throw new AuraHandledException('포인트 하위 유형 정보가 없습니다.');
    }
    if (pointAmount == null || pointAmount <= 0) {
      throw new AuraHandledException('포인트 값이 올바르지 않습니다.');
    }
    if (pointAmount > 100000000) {
      throw new AuraHandledException('포인트는 최대 1억까지 지급할 수 있습니다.');
    }
    if (expireDate == null) {
      throw new AuraHandledException('만료일이 없습니다.');
    }
    if (expireDate <= Date.today()) {
      throw new AuraHandledException('만료일은 지급일 다음 날부터 선택할 수 있습니다.');
    }
    Set<Id> memberSet = new Set<Id>(memberIds);
    Id batchJobId;
    if (!Test.isRunningTest()) {
      batchJobId = Database.executeBatch(new IssuePointSubTypeBatch(memberSet, subtypeId, Date.today(), pointAmount, expireDate), 80);
    }
    IssuePointResult result = new IssuePointResult();
    result.success = true;
    result.message = '포인트 지급이 시작되었습니다.';
    result.requestedMemberCount = memberSet.size();
    result.issueJobId = batchJobId;
    result.status = JOB_STATUS_PROCESSING;
    result.processedCount = 0;
    result.successCount = 0;
    result.failCount = 0;
    result.isCompleted = false;
    result.isFailed = false;
    return result;
  }

  @AuraEnabled
  public static IssuePointProgressResult getPointIssueProgress(Id issueJobId, Integer totalCount) {
    if (issueJobId == null) {
      throw new AuraHandledException('지급 작업 정보가 없습니다.');
    }

    AsyncApexJob asyncJob = [
      SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, ExtendedStatus
      FROM AsyncApexJob
      WHERE Id = :issueJobId
      LIMIT 1
    ];

    Integer safeTotalCount = totalCount == null ? 0 : totalCount;
    IssuePointProgressResult result = new IssuePointProgressResult();
    result.issueJobId = issueJobId;
    result.totalCount = safeTotalCount;
    Integer processedJobItems = asyncJob.JobItemsProcessed == null ? 0 : asyncJob.JobItemsProcessed;
    result.processedCount = Math.min(safeTotalCount, Math.max(0, processedJobItems * 150));
    result.successCount = 0;
    result.failCount = 0;
    result.status = mapAsyncJobStatus(asyncJob.Status);
    result.isCompleted = JOB_STATUS_COMPLETED.equals(result.status);
    result.isFailed = JOB_STATUS_FAILED.equals(result.status);
    result.message = result.isFailed ? asyncJob.ExtendedStatus : null;

    if (result.isCompleted) {
      result.processedCount = safeTotalCount;
      applyFinalIssueLog(result, issueJobId);
    } else if (result.isFailed) {
      result.failCount = safeTotalCount;
    }

    return result;
  }
  public class UploadJobStartResult {
    @AuraEnabled
    public Id uploadJobId;
    @AuraEnabled
    public Id batchJobId;
    @AuraEnabled
    public String status;
  }
  public class UploadJobStatusResult {
    @AuraEnabled
    public Id uploadJobId;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer totalCount;
    @AuraEnabled
    public Integer successCount;
    @AuraEnabled
    public Integer failCount;
    @AuraEnabled
    public String errorMessage;
    @AuraEnabled
    public Boolean isCompleted;
    @AuraEnabled
    public Boolean isFailed;
    @AuraEnabled
    public List<MemberErrorDTO> errors;
  }
  public class UploadPreviewResult {
    @AuraEnabled
    public Integer successCount;
    @AuraEnabled
    public Integer failCount;
    @AuraEnabled
    public List<MemberErrorDTO> errors;
    @AuraEnabled
    public List<Id> successMemberIds;
  }
  public class MemberErrorDTO {
    @AuraEnabled
    public String memberNo;
    @AuraEnabled
    public String errorReason;
    public MemberErrorDTO(String memberNo, String errorReason) {
      this.memberNo = memberNo;
      this.errorReason = errorReason;
    }
  }
  public class IssuePointResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Integer requestedMemberCount;
    @AuraEnabled
    public Id issueJobId;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer processedCount;
    @AuraEnabled
    public Integer successCount;
    @AuraEnabled
    public Integer failCount;
    @AuraEnabled
    public Boolean isCompleted;
    @AuraEnabled
    public Boolean isFailed;
  }
  public class IssuePointProgressResult {
    @AuraEnabled
    public Id issueJobId;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Integer totalCount;
    @AuraEnabled
    public Integer processedCount;
    @AuraEnabled
    public Integer successCount;
    @AuraEnabled
    public Integer failCount;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public Boolean isCompleted;
    @AuraEnabled
    public Boolean isFailed;
  }
  public class ValidationSummaryFile {
    public String status;
    public Integer totalCount;
    public Integer successCount;
    public Integer failCount;
    public String errorMessage;
    public List<MemberErrorDTO> errors;
  }
  public static String buildSourceDescription(Id batchJobId) {
    return SOURCE_FILE_MARKER_PREFIX + String.valueOf(batchJobId);
  }
  public static String buildSummaryDescription(Id batchJobId) {
    return SUMMARY_FILE_MARKER_PREFIX + String.valueOf(batchJobId);
  }
  public static ValidationSummaryFile loadValidationSummary(Id batchJobId) {
    List<ContentVersion> summaryFiles = [
      SELECT VersionData
      FROM ContentVersion
      WHERE Description = :buildSummaryDescription(batchJobId)
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    if (summaryFiles.isEmpty()) {
      return null;
    }
    return (ValidationSummaryFile) JSON.deserialize(summaryFiles[0].VersionData.toString(), ValidationSummaryFile.class);
  }

  private static void applyFinalIssueLog(IssuePointProgressResult result, Id issueJobId) {
    List<ApexAuditTrail__c> logs = [
      SELECT Status__c, Description__c, ErrorMessage__c
      FROM ApexAuditTrail__c
      WHERE ApexClass__c = 'IssuePointSubTypeBatch'
      ORDER BY CreatedDate DESC
      LIMIT 20
    ];

    ApexAuditTrail__c log;
    for (ApexAuditTrail__c candidate : logs) {
      if (candidate.Description__c != null && candidate.Description__c.contains('jobId=' + String.valueOf(issueJobId))) {
        log = candidate;
        break;
      }
    }

    if (log == null) {
      result.successCount = result.totalCount;
      return;
    }

    Integer parsedSuccess = extractDescriptionCount(log.Description__c, 'success=');
    Integer parsedFail = extractDescriptionCount(log.Description__c, 'fail=');

    if (parsedSuccess == null && parsedFail == null) {
      result.successCount = result.totalCount;
      return;
    }

    result.successCount = parsedSuccess == null ? Math.max(0, result.totalCount - (parsedFail == null ? 0 : parsedFail)) : parsedSuccess;
    result.failCount = parsedFail == null ? Math.max(0, result.totalCount - result.successCount) : parsedFail;
    result.message = String.isBlank(log.ErrorMessage__c) ? null : log.ErrorMessage__c;
  }

  private static Integer extractDescriptionCount(String description, String marker) {
    if (String.isBlank(description) || String.isBlank(marker)) {
      return null;
    }

    Integer startIdx = description.indexOf(marker);
    if (startIdx == -1) {
      return null;
    }

    startIdx += marker.length();
    Integer endIdx = description.indexOf(',', startIdx);
    String rawValue = endIdx == -1 ? description.substring(startIdx) : description.substring(startIdx, endIdx);
    rawValue = rawValue == null ? null : rawValue.trim();

    if (String.isBlank(rawValue)) {
      return null;
    }

    try {
      return Integer.valueOf(rawValue);
    } catch (Exception ex) {
      return null;
    }
  }
  public static String toDisplayLabelMessage(String message) {
    if (String.isBlank(message)) {
      return message;
    }
    try {
      Map<String, String> labelByApiName = getDisplayLabelByApiName();
      String displayMessage = '';
      String tokenBuilder = '';
      for (Integer i = 0; i < message.length(); i++) {
        String currentChar = message.substring(i, i + 1);
        if (isApiNameCharacter(currentChar)) {
          tokenBuilder += currentChar;
          continue;
        }
        displayMessage += getDisplayToken(tokenBuilder, labelByApiName);
        tokenBuilder = '';
        displayMessage += currentChar;
      }
      displayMessage += getDisplayToken(tokenBuilder, labelByApiName);
      return displayMessage;
    } catch (Exception e) {
      return message;
    }
  }
  private static Map<String, String> getDisplayLabelByApiName() {
    if (displayLabelByApiName != null) {
      return displayLabelByApiName;
    }
    Map<String, String> labelByApiName = new Map<String, String>();
    List<Schema.SObjectType> targetTypes = new List<Schema.SObjectType>{
      Contact.SObjectType,
      LoyaltyProgramMember.SObjectType,
      LoyaltyLedger.SObjectType,
      LoyaltyLedgerTraceability.SObjectType,
      LoyaltyProgramCurrency.SObjectType,
      LoyaltyPgmCurrencySubtype.SObjectType,
      TransactionJournal.SObjectType,
      JournalType.SObjectType,
      JournalSubType.SObjectType
    };
    for (Schema.SObjectType targetType : targetTypes) {
      Schema.DescribeSObjectResult objectDescribe = targetType.getDescribe();
      labelByApiName.put(objectDescribe.getName(), objectDescribe.getLabel());
      for (String fieldApiName : objectDescribe.fields.getMap().keySet()) {
        Schema.DescribeFieldResult fieldDescribe = objectDescribe.fields.getMap().get(fieldApiName).getDescribe();
        if (!String.isBlank(fieldDescribe.getLabel())) {
          labelByApiName.put(fieldApiName, fieldDescribe.getLabel());
        }
      }
    }
    displayLabelByApiName = labelByApiName;
    return displayLabelByApiName;
  }
  private static String getDisplayToken(String token, Map<String, String> labelByApiName) {
    if (String.isBlank(token)) {
      return '';
    }
    return labelByApiName.containsKey(token) ? labelByApiName.get(token) : token;
  }
  private static Boolean isApiNameCharacter(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    String charValue = value.substring(0, 1);
    return ((charValue >= 'A' &&
    charValue <= 'Z') ||
    (charValue >= 'a' &&
    charValue <= 'z') ||
    (charValue >= '0' &&
    charValue <= '9') ||
    charValue == '_');
  }
  private static UploadPreviewResult buildUploadPreviewFromSource(Id batchJobId) {
    List<ContentVersion> sourceFiles = [
      SELECT Id, VersionData
      FROM ContentVersion
      WHERE Description = :buildSourceDescription(batchJobId)
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];
    if (sourceFiles.isEmpty()) {
      throw new AuraHandledException('업로드 원본 파일을 찾을 수 없습니다.');
    }
    return buildUploadPreviewFromText(normalizeFileText(sourceFiles[0].VersionData.toString()));
  }
  private static String mapAsyncJobStatus(String asyncStatus) {
    if (asyncStatus == 'Completed') {
      return JOB_STATUS_COMPLETED;
    }
    if (asyncStatus == 'Failed' || asyncStatus == 'Aborted') {
      return JOB_STATUS_FAILED;
    }
    return JOB_STATUS_PROCESSING;
  }
  // 로열티 멤버 비교(쿼리)
  private static UploadPreviewResult buildUploadPreviewFromText(String text) {
    List<String> lines = splitByNewline(text);
    UploadPreviewResult result = new UploadPreviewResult();
    result.errors = new List<MemberErrorDTO>();
    result.successMemberIds = new List<Id>();
    if (lines.isEmpty()) {
      result.successCount = 0;
      result.failCount = 0;
      return result;
    }
    if (lines.size() > 10000) {
      throw new AuraHandledException('파일은 최대 1만건까지 가능합니다.');
    }
    Integer memberIdx = extractMemberColumnIndex(lines[0]);
    List<String> uniqueMemberNos = new List<String>();
    Set<String> memberSet = new Set<String>();
    for (Integer i = 1; i < lines.size(); i++) {
      if (String.isBlank(lines[i])) {
        continue;
      }
      List<String> cols = parseCsvColumns(lines[i]);
      String memberNo = cols.size() > memberIdx ? normalizeMemberNo(cols[memberIdx]) : '';
      if (String.isBlank(memberNo)) {
        result.errors.add(new MemberErrorDTO('', '회원번호 없음'));
        continue;
      }
      if (memberSet.contains(memberNo)) {
        result.errors.add(new MemberErrorDTO(memberNo, '중복 회원번호'));
        continue;
      }
      memberSet.add(memberNo);
      uniqueMemberNos.add(memberNo);
    }
    Map<String, LoyaltyProgramMember> programMemberMap = new Map<String, LoyaltyProgramMember>();
    if (!uniqueMemberNos.isEmpty()) {
      Map<Id, String> memberNoByContactId = new Map<Id, String>();
      for (Contact contactRecord : [
        SELECT Id, MemberNo__c
        FROM Contact
        WHERE MemberNo__c IN :uniqueMemberNos
      ]) {
        if (!String.isBlank(contactRecord.MemberNo__c)) {
          memberNoByContactId.put(contactRecord.Id, contactRecord.MemberNo__c);
        }
      }
      if (!memberNoByContactId.isEmpty()) {
        for (LoyaltyProgramMember programMember : [
          SELECT Id, ContactId
          FROM LoyaltyProgramMember
          WHERE ContactId IN :memberNoByContactId.keySet()
        ]) {
          String memberNo = memberNoByContactId.get(programMember.ContactId);
          if (!String.isBlank(memberNo) && !programMemberMap.containsKey(memberNo)) {
            programMemberMap.put(memberNo, programMember);
          }
        }
      }
    }
    for (String memberNo : uniqueMemberNos) {
      if (!programMemberMap.containsKey(memberNo)) {
        result.errors.add(new MemberErrorDTO(memberNo, '회원번호에 해당하는 멤버십 정보 없음'));
        continue;
      }
      result.successMemberIds.add(programMemberMap.get(memberNo).Id);
    }
    result.successCount = result.successMemberIds.size();
    result.failCount = result.errors.size();
    return result;
  }
  private static Integer extractMemberColumnIndex(String headerLine) {
    List<String> headers = parseCsvColumns(headerLine);
    for (Integer i = 0; i < headers.size(); i++) {
      headers[i] = normalizeHeaderName(headers[i]);
    }
    Integer memberIdx = -1;
    for (String memberColumnName : MEMBER_NO_COLUMN_NAMES) {
      memberIdx = headers.indexOf(normalizeHeaderName(memberColumnName));
      if (memberIdx != -1) {
        break;
      }
    }
    if (memberIdx == -1) {
      throw new AuraHandledException('NO_MBR 컬럼이 없습니다.');
    }
    return memberIdx;
  }
  private static String normalizeFileText(String text) {
    String normalized = text == null ? '' : text;
    normalized = normalized.replace('\r\n', '\n');
    normalized = normalized.replace('\r', '\n');
    return normalized;
  }
  public static List<String> parseCsvColumns(String line) {
    List<String> columns = new List<String>();
    if (line == null) {
      return columns;
    }
    String currentValue = '';
    Boolean inQuotes = false;
    for (Integer i = 0; i < line.length(); i++) {
      String currentChar = line.substring(i, i + 1);
      if (currentChar == '"') {
        if (inQuotes && i + 1 < line.length() && line.substring(i + 1, i + 2) == '"') {
          currentValue += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (currentChar == ',' && !inQuotes) {
        columns.add(currentValue);
        currentValue = '';
        continue;
      }
      currentValue += currentChar;
    }
    columns.add(currentValue);
    return columns;
  }
  public static String normalizeCsvCell(String value) {
    if (value == null) {
      return '';
    }
    String normalized = value.trim();
    if (!String.isBlank(normalized) && normalized.startsWith('\uFEFF')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('="') && normalized.endsWith('"') && normalized.length() >= 3) {
      normalized = normalized.substring(2, normalized.length() - 1);
    }
    if (normalized.startsWith('"') && normalized.endsWith('"') && normalized.length() >= 2) {
      normalized = normalized.substring(1, normalized.length() - 1);
    }
    normalized = normalized.replace('""', '"').trim();
    if (normalized.startsWith('\'') && normalized.length() > 1) {
      normalized = normalized.substring(1);
    }
    return normalized.trim();
  }
  public static String normalizeMemberNo(String value) {
    String normalized = normalizeCsvCell(value);
    normalized = normalized.replace('\u00A0', '');
    return normalized.trim();
  }
  private static String normalizeHeaderName(String headerValue) {
    String normalizedHeader = normalizeCsvCell(headerValue);
    normalizedHeader = normalizedHeader.replace(' ', '');
    return normalizedHeader.toUpperCase();
  }

  private static void insertLoggerSafely() {
    try {
      ApexLogger.insertLogs();
    } catch (Exception loggingException) {
      System.debug(LoggingLevel.ERROR, 'UPLOAD logger insert error=' + loggingException.getMessage());
    }
  }
}