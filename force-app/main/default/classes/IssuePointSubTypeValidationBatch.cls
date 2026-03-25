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

      String text = contentVersion.VersionData.toString();
      text = text.replace('\r\n', '\n');
      text = text.replace('\r', '\n');

      List<String> lines = splitByNewline(text);
      if (lines.isEmpty()) {
        fatalErrorMessage = '파일이 비어 있습니다.';
        return rows;
      }

      Integer memberIdx = extractMemberColumnIndex(lines[0]);

      Integer rowNumber = 1;
      for (Integer i = 1; i < lines.size(); i++) {
        rowNumber++;
        if (String.isBlank(lines[i])) {
          continue;
        }

        List<String> cols = lines[i].split(',');
        String memberNo = cols.size() > memberIdx ? cols[memberIdx].trim() : '';
        rows.add(String.valueOf(rowNumber) + ROW_SEPARATOR + memberNo);
      }

      totalCount = rows.size();
      return rows;
    } catch (AuraHandledException e) {
      fatalErrorMessage = e.getMessage();
      return rows;
    } catch (Exception e) {
      fatalErrorMessage = e.getMessage();
      return rows;
    }
  }

  public void execute(Database.BatchableContext bc, List<String> scope) {
    if (String.isBlank(fatalErrorMessage) == false || scope.isEmpty()) {
      return;
    }

    List<RowContext> candidateRows = new List<RowContext>();
    Set<String> membershipNumbers = new Set<String>();

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
      membershipNumbers.add(row.memberNo);
    }

    Map<String, LoyaltyProgramMember> memberMap = new Map<String, LoyaltyProgramMember>();
    if (!membershipNumbers.isEmpty()) {
      for (LoyaltyProgramMember member : [
        SELECT Id, MembershipNumber
        FROM LoyaltyProgramMember
        WHERE MembershipNumber IN :membershipNumbers
      ]) {
        memberMap.put(member.MembershipNumber, member);
      }
    }

    for (RowContext row : candidateRows) {
      if (!memberMap.containsKey(row.memberNo)) {
        addPreviewError(row.memberNo, 'Loyalty 회원 없음');
        failCount++;
        continue;
      }

      successCount++;
    }
  }

  public void finish(Database.BatchableContext bc) {
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
  }

  private void addPreviewError(String memberNo, String errorReason) {
    if (previewErrors.size() >= 200) {
      return;
    }
    previewErrors.add(new IssuePointSubTypeControllerV1.MemberErrorDTO(memberNo, errorReason));
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
}
