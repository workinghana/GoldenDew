public with sharing class IssuePointSubTypeValidationBatch implements Database.Batchable<String>, Database.Stateful {
  private static final String ROW_SEPARATOR = '\u0001';

  private Id sourceContentVersionId;
  private Integer totalCount = 0;
  private Integer successCount = 0;
  private Integer failCount = 0;
  private String fatalErrorMessage;
  private Set<String> seenMemberNos = new Set<String>();
  private List<IssuePointSubTypeControllerV1.MemberErrorDTO> previewErrors = new List<IssuePointSubTypeControllerV1.MemberErrorDTO>();

  public IssuePointSubTypeValidationBatch(Id sourceContentVersionId) {
    this.sourceContentVersionId = sourceContentVersionId;
  }

  public Iterable<String> start(Database.BatchableContext bc) {
    List<String> rows = new List<String>();
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc == null ? null : bc.getJobId(), null);
    logger.logging(IssuePointSubTypeValidationBatch.class.getName());
    logger.setMethod('start');
    logger.setRequestDatetime(Datetime.now());
    logger.setDescription('sourceContentVersionId=' + sourceContentVersionId);
    System.debug(LoggingLevel.ERROR, 'VALIDATION start enter');
    System.debug(LoggingLevel.ERROR, 'VALIDATION sourceContentVersionId=' + sourceContentVersionId);
    System.debug(LoggingLevel.ERROR, 'VALIDATION jobId=' + (bc == null ? null : bc.getJobId()));

    try {
      if (sourceContentVersionId == null) {
        fatalErrorMessage = '업로드 파일 정보가 없습니다.';
        return rows;
      }

      ContentVersion contentVersion = [
        SELECT VersionData
        FROM ContentVersion
        WHERE Id = :sourceContentVersionId
        LIMIT 1
      ];
      System.debug(LoggingLevel.ERROR, 'VALIDATION contentVersion loaded');

      String text = contentVersion.VersionData.toString();
      text = text.replace('\r\n', '\n');
      text = text.replace('\r', '\n');

      List<String> lines = splitByNewline(text);
      System.debug(LoggingLevel.ERROR, 'VALIDATION lineCount=' + lines.size());
      System.debug(LoggingLevel.ERROR, 'VALIDATION header=' + (lines.isEmpty() ? null : lines[0]));
      if (lines.isEmpty()) {
        fatalErrorMessage = '파일이 비어 있습니다.';
        return rows;
      }

      Integer memberIdx = extractMemberColumnIndex(lines[0]);
      System.debug(LoggingLevel.ERROR, 'VALIDATION memberIdx=' + memberIdx);

      Integer rowNumber = 1;
      for (Integer i = 1; i < lines.size(); i++) {
        rowNumber++;
        if (String.isBlank(lines[i])) {
          continue;
        }

        List<String> cols = IssuePointSubTypeControllerV1.parseCsvColumns(lines[i]);
        String memberNo = cols.size() > memberIdx ? IssuePointSubTypeControllerV1.normalizeMemberNo(cols[memberIdx]) : '';
        rows.add(String.valueOf(rowNumber) + ROW_SEPARATOR + memberNo);
      }

      totalCount = rows.size();
      System.debug(LoggingLevel.ERROR, 'VALIDATION totalRows=' + totalCount);
      logger.setStatus('SUCCESS');
      logger.setDescription('phase=start, sourceContentVersionId=' + sourceContentVersionId + ', totalRows=' + totalCount);
      logger.setResponseBody('lineCount=' + lines.size() + ', memberIdx=' + memberIdx);
      return rows;
    } catch (CustomException e) {
      fatalErrorMessage = IssuePointSubTypeControllerV1.toDisplayLabelMessage(e.getMessage());
      System.debug(LoggingLevel.ERROR, 'VALIDATION custom error=' + fatalErrorMessage);
      System.debug(LoggingLevel.ERROR, 'VALIDATION custom stack=' + e.getStackTraceString());
      logger.createExceptionLog(e);
      logger.setDescription('phase=startCustomException, sourceContentVersionId=' + sourceContentVersionId);
      return rows;
    } catch (Exception e) {
      fatalErrorMessage = IssuePointSubTypeControllerV1.toDisplayLabelMessage(e.getMessage());
      System.debug(LoggingLevel.ERROR, 'VALIDATION error=' + fatalErrorMessage);
      System.debug(LoggingLevel.ERROR, 'VALIDATION stack=' + e.getStackTraceString());
      logger.createExceptionLog(e);
      logger.setDescription('phase=startException, sourceContentVersionId=' + sourceContentVersionId);
      return rows;
    } finally {
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      insertLoggerSafely();
    }
  }

  public void execute(Database.BatchableContext bc, List<String> scope) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc == null ? null : bc.getJobId(), null);
    logger.logging(IssuePointSubTypeValidationBatch.class.getName());
    logger.setMethod('execute');
    logger.setRequestDatetime(Datetime.now());
    logger.setDescription('scopeSize=' + (scope == null ? null : scope.size()) + ', fatalError=' + fatalErrorMessage);
    System.debug(LoggingLevel.ERROR, 'VALIDATION execute enter');
    System.debug(LoggingLevel.ERROR, 'VALIDATION execute scopeSize=' + (scope == null ? null : scope.size()));
    System.debug(LoggingLevel.ERROR, 'VALIDATION execute fatalError=' + fatalErrorMessage);
    if (String.isBlank(fatalErrorMessage) == false || scope.isEmpty()) {
      logger.setStatus('SUCCESS');
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      insertLoggerSafely();
      return;
    }

    List<RowContext> candidateRows = new List<RowContext>();
    Set<String> memberNos = new Set<String>();

    for (String payload : scope) {
      RowContext row = decodeRow(payload);

      if (String.isBlank(row.memberNo)) {
        addPreviewError('', '회원번호 없음');
        failCount++;
        continue;
      }

      if (seenMemberNos.contains(row.memberNo)) {
        addPreviewError(row.memberNo, '중복 회원번호');
        failCount++;
        continue;
      }

      seenMemberNos.add(row.memberNo);
      candidateRows.add(row);
      memberNos.add(row.memberNo);
    }

    Map<String, LoyaltyProgramMember> memberMap = new Map<String, LoyaltyProgramMember>();
    if (!memberNos.isEmpty()) {
      Map<Id, String> memberNoByContactId = new Map<Id, String>();
      for (Contact contactRecord : [
        SELECT Id, MemberNo__c
        FROM Contact
        WHERE MemberNo__c IN :memberNos
      ]) {
        if (!String.isBlank(contactRecord.MemberNo__c)) {
          memberNoByContactId.put(contactRecord.Id, contactRecord.MemberNo__c);
        }
      }

      if (!memberNoByContactId.isEmpty()) {
        for (LoyaltyProgramMember member : [
          SELECT Id, ContactId
          FROM LoyaltyProgramMember
          WHERE ContactId IN :memberNoByContactId.keySet()
        ]) {
          String memberNo = memberNoByContactId.get(member.ContactId);
          if (!String.isBlank(memberNo) && !memberMap.containsKey(memberNo)) {
            memberMap.put(memberNo, member);
          }
        }
      }
    }

    System.debug(LoggingLevel.ERROR, 'VALIDATION execute memberNos=' + memberNos.size());
    System.debug(LoggingLevel.ERROR, 'VALIDATION execute memberMap=' + memberMap.size());

    for (RowContext row : candidateRows) {
      if (!memberMap.containsKey(row.memberNo)) {
        addPreviewError(row.memberNo, '회원번호에 해당하는 멤버십 정보 없음');
        failCount++;
        continue;
      }

      successCount++;
    }
    logger.setStatus(failCount > 0 ? 'PARTIAL' : 'SUCCESS');
    logger.setDescription(
      'phase=execute, scopeSize=' +
        scope.size() +
        ', candidateRows=' +
        candidateRows.size() +
        ', memberNos=' +
        memberNos.size() +
        ', successTotal=' +
        successCount +
        ', failTotal=' +
        failCount
    );
    logger.setResponseBody('memberMapSize=' + memberMap.size());
    if (!memberNos.isEmpty()) {
      logger.setScopedIds(new Set<String>(memberNos));
    }
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    insertLoggerSafely();
  }

  public void finish(Database.BatchableContext bc) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc == null ? null : bc.getJobId(), null);
    logger.logging(IssuePointSubTypeValidationBatch.class.getName());
    logger.setMethod('finish');
    logger.setRequestDatetime(Datetime.now());
    System.debug(LoggingLevel.ERROR, 'VALIDATION finish enter');
    System.debug(LoggingLevel.ERROR, 'VALIDATION finish jobId=' + (bc == null ? null : bc.getJobId()));
    System.debug(LoggingLevel.ERROR, 'VALIDATION finish total=' + totalCount + ', success=' + successCount + ', fail=' + failCount);
    System.debug(LoggingLevel.ERROR, 'VALIDATION finish fatalError=' + fatalErrorMessage);
    IssuePointSubTypeControllerV1.ValidationSummaryFile summary = new IssuePointSubTypeControllerV1.ValidationSummaryFile();
    summary.status = String.isBlank(fatalErrorMessage)
      ? IssuePointSubTypeControllerV1.JOB_STATUS_COMPLETED
      : IssuePointSubTypeControllerV1.JOB_STATUS_FAILED;
    summary.totalCount = totalCount;
    summary.successCount = successCount;
    summary.failCount = failCount;
    summary.errorMessage = fatalErrorMessage;
    summary.errors = previewErrors;

    insert new ContentVersion(
      Title = 'point-upload-summary-' + bc.getJobId(),
      PathOnClient = 'point-upload-summary-' + bc.getJobId() + '.json',
      Description = IssuePointSubTypeControllerV1.buildSummaryDescription(bc.getJobId()),
      VersionData = Blob.valueOf(JSON.serialize(summary)),
      IsMajorVersion = false
    );
    if (summary.status == IssuePointSubTypeControllerV1.JOB_STATUS_FAILED) {
      logger.setStatus('ERROR');
      logger.setErrorCode('VALIDATION_FAILED');
      logger.setErrorMessage(fatalErrorMessage);
    } else {
      logger.setStatus(failCount > 0 ? 'PARTIAL' : 'SUCCESS');
    }
    logger.setDescription('phase=finish, total=' + totalCount + ', success=' + successCount + ', fail=' + failCount);
    logger.setResponseBody(JSON.serialize(summary));
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    insertLoggerSafely();
  }

  private void addPreviewError(String memberNo, String errorReason) {
    if (previewErrors.size() >= 200) {
      return;
    }
    previewErrors.add(new IssuePointSubTypeControllerV1.MemberErrorDTO(memberNo, IssuePointSubTypeControllerV1.toDisplayLabelMessage(errorReason)));
  }

  private class RowContext {
    Integer rowNumber;
    String memberNo;

    RowContext(Integer rowNumber, String memberNo) {
      this.rowNumber = rowNumber;
      this.memberNo = memberNo;
    }
  }

  private RowContext decodeRow(String payload) {
    Integer separatorIndex = payload == null ? -1 : payload.indexOf(ROW_SEPARATOR);
    if (separatorIndex == -1) {
      return new RowContext(0, payload);
    }

    Integer rowNumber = Integer.valueOf(payload.substring(0, separatorIndex));
    String memberNo = payload.substring(separatorIndex + 1);
    return new RowContext(rowNumber, memberNo);
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

  private static Integer extractMemberColumnIndex(String headerLine) {
    List<String> headers = IssuePointSubTypeControllerV1.parseCsvColumns(headerLine);
    for (Integer i = 0; i < headers.size(); i++) {
      headers[i] = normalizeHeaderName(headers[i]);
    }

    Integer memberIdx = -1;
    for (String memberColumnName : new List<String>{ 'NO_MBR', 'MemberNo__c', 'MemberNo', '회원번호', '회원 번호' }) {
      memberIdx = headers.indexOf(normalizeHeaderName(memberColumnName));
      if (memberIdx != -1) {
        break;
      }
    }
    if (memberIdx == -1) {
      throw new CustomException(400, '회원번호 컬럼이 없습니다.');
    }

    return memberIdx;
  }

  private static String normalizeHeaderName(String headerValue) {
    String normalizedHeader = IssuePointSubTypeControllerV1.normalizeCsvCell(headerValue);
    normalizedHeader = normalizedHeader.replace(' ', '');
    return normalizedHeader.toUpperCase();
  }

  private static void insertLoggerSafely() {
    try {
      ApexLogger.insertLogs();
    } catch (Exception loggingException) {
      System.debug(LoggingLevel.ERROR, 'VALIDATION logger insert error=' + loggingException.getMessage());
    }
  }
}