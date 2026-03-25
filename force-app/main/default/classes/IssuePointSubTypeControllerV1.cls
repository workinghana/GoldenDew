public with sharing class IssuePointSubTypeControllerV1 {
  public static final String JOB_STATUS_PENDING = 'PENDING';
  public static final String JOB_STATUS_PROCESSING = 'PROCESSING';
  public static final String JOB_STATUS_COMPLETED = 'COMPLETED';
  public static final String JOB_STATUS_FAILED = 'FAILED';
  public static final Integer VALIDATION_BATCH_SCOPE_SIZE = 1000;
  public static final String SOURCE_FILE_MARKER_PREFIX = 'POINT_UPLOAD_SOURCE:';
  public static final String SUMMARY_FILE_MARKER_PREFIX = 'POINT_UPLOAD_SUMMARY:';

  @AuraEnabled
  public static UploadJobStartResult startPointFileValidation(String base64Data, String fileName, Id subtypeId) {
    if (String.isBlank(base64Data)) {
      throw new AuraHandledException('파일 데이터가 없습니다.');
    }

    ContentVersion contentVersion = new ContentVersion(
      Title = String.isBlank(fileName) ? 'point-upload.csv' : fileName,
      PathOnClient = String.isBlank(fileName) ? 'point-upload.csv' : fileName,
      VersionData = EncodingUtil.base64Decode(base64Data),
      IsMajorVersion = true
    );
    insert contentVersion;

    Id batchJobId = Database.executeBatch(new IssuePointSubTypeValidationBatch(contentVersion.Id), VALIDATION_BATCH_SCOPE_SIZE);

    update new ContentVersion(Id = contentVersion.Id, Description = buildSourceDescription(batchJobId));

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
    result.errorMessage = result.status == JOB_STATUS_FAILED ? asyncJob.ExtendedStatus : null;
    result.errors = new List<MemberErrorDTO>();

    ValidationSummaryFile summary = loadValidationSummary(uploadJobId);
    if (summary != null) {
      result.status = summary.status;
      result.totalCount = summary.totalCount == null ? 0 : summary.totalCount;
      result.successCount = summary.successCount == null ? 0 : summary.successCount;
      result.failCount = summary.failCount == null ? 0 : summary.failCount;
      result.errorMessage = String.isBlank(summary.errorMessage) ? result.errorMessage : summary.errorMessage;
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

    Set<Id> memberSet = new Set<Id>(memberIds);

    if (!Test.isRunningTest()) {
      Database.executeBatch(new IssuePointSubTypeBatch(memberSet, subtypeId, Date.today(), pointAmount, expireDate), 150);
    }

    IssuePointResult result = new IssuePointResult();
    result.success = true;
    result.message = '포인트 지급이 시작되었습니다.';
    result.requestedMemberCount = memberSet.size();
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

    if (lines.size() > 50000) {
      throw new AuraHandledException('파일은 최대 5만건까지 가능합니다.');
    }

    Integer memberIdx = extractMemberColumnIndex(lines[0]);
    List<String> uniqueMemberNos = new List<String>();
    Set<String> memberSet = new Set<String>();

    for (Integer i = 1; i < lines.size(); i++) {
      if (String.isBlank(lines[i])) {
        continue;
      }

      List<String> cols = lines[i].split(',');
      String memberNo = cols.size() > memberIdx ? cols[memberIdx].trim() : '';

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
      for (LoyaltyProgramMember programMember : [
        SELECT Id, MembershipNumber
        FROM LoyaltyProgramMember
        WHERE MembershipNumber IN :uniqueMemberNos
      ]) {
        if (!String.isBlank(programMember.MembershipNumber)) {
          programMemberMap.put(programMember.MembershipNumber, programMember);
        }
      }
    }

    for (String memberNo : uniqueMemberNos) {
      if (!programMemberMap.containsKey(memberNo)) {
        result.errors.add(new MemberErrorDTO(memberNo, 'Loyalty 회원 없음'));
        continue;
      }

      result.successMemberIds.add(programMemberMap.get(memberNo).Id);
    }

    result.successCount = result.successMemberIds.size();
    result.failCount = result.errors.size();
    return result;
  }

  private static Integer extractMemberColumnIndex(String headerLine) {
    List<String> headers = headerLine.split(',');
    for (Integer i = 0; i < headers.size(); i++) {
      headers[i] = headers[i].trim();
    }

    Integer memberIdx = headers.indexOf('NO_MBR');
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
}
