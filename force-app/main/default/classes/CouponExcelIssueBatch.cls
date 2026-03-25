public with sharing class CouponExcelIssueBatch implements Database.Batchable<String>, Database.Stateful {
  private Id voucherDefinitionId;
  private Id contentDocumentId;

  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  public CouponExcelIssueBatch(Id vdId, Id docId) {
    this.voucherDefinitionId = vdId;
    this.contentDocumentId = docId;
  }

  /* ================= START ================= */
  public Iterable<String> start(Database.BatchableContext bc) {
    ContentVersion cv = [
      SELECT VersionData
      FROM ContentVersion
      WHERE ContentDocumentId = :contentDocumentId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    String text = cv.VersionData.toString();
    List<String> memberNos = new List<String>();

    if (String.isBlank(text)) {
      return memberNos;
    }

    Integer startPos = 0;
    Integer lineEnd;

    // 🔥 1️⃣ 헤더 추출 (split('\n') 제거)
    lineEnd = text.indexOf('\n', startPos);
    if (lineEnd == -1) {
      throw new AuraHandledException('CSV 형식이 올바르지 않습니다.');
    }

    String headerLine = text.substring(startPos, lineEnd);
    List<String> headers = headerLine.split(',');

    Integer idx = headers.indexOf('MemberNo__c');
    if (idx == -1) {
      throw new AuraHandledException('MemberNo__c 컬럼이 없습니다.');
    }

    startPos = lineEnd + 1;

    // 🔥 2️⃣ 데이터 라인 반복 (Regex 미사용)
    while (true) {
      lineEnd = text.indexOf('\n', startPos);
      if (lineEnd == -1) {
        break;
      }

      String line = text.substring(startPos, lineEnd);
      startPos = lineEnd + 1;

      if (String.isBlank(line))
        continue;

      List<String> cols = line.split(',');

      if (cols.size() > idx) {
        memberNos.add(cols[idx].trim());
      }
    }

    return memberNos;
  }

  /* ================= EXECUTE ================= */
  public void execute(Database.BatchableContext bc, List<String> scope) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);

    logger.logging(CouponExcelIssueBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      Map<String, Contact> contactMap = new Map<String, Contact>();

      for (Contact c : [
        SELECT Id, MemberNo__c
        FROM Contact
        WHERE MemberNo__c IN :scope
      ]) {
        contactMap.put(c.MemberNo__c, c);
      }

      List<Voucher> insertList = new List<Voucher>();

      for (String memberNo : scope) {
        if (!contactMap.containsKey(memberNo)) {
          failIds.add(memberNo);
          failMsgs.add('회원 없음: ' + memberNo);
          continue;
        }

        insertList.add(new Voucher(VoucherDefinitionId = voucherDefinitionId, ContactId = contactMap.get(memberNo).Id, Status = 'Issued'));
      }

      if (!insertList.isEmpty()) {
        Database.SaveResult[] results = Database.insert(insertList, false);

        for (Integer i = 0; i < results.size(); i++) {
          if (results[i].isSuccess()) {
            successIds.add(scope[i]);
          } else {
            failIds.add(scope[i]);

            for (Database.Error err : results[i].getErrors()) {
              failMsgs.add('Insert 실패: memberNo=' + scope[i] + ', msg=' + err.getMessage());
            }
          }
        }
      }

      failIds.removeAll(successIds);

      Boolean hasFail = !failIds.isEmpty();
      Boolean hasSuccess = !successIds.isEmpty();

      if (hasFail && hasSuccess) {
        logger.setStatus('PARTIAL');
      } else if (hasFail) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription('chunkSize=' + scope.size() + ', success=' + successIds.size() + ', fail=' + failIds.size());
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
    } finally {
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      if (!successIds.isEmpty()) {
        logger.setSuccessRecordIds(successIds);
      }

      if (!failIds.isEmpty()) {
        logger.setFailedRecordIds(failIds);
      }

      if (!failMsgs.isEmpty()) {
        logger.setErrorMessage(String.join(failMsgs, ' | '));
      }

      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  /* ================= FINISH ================= */
  public void finish(Database.BatchableContext bc) {
    totalFail.removeAll(totalSuccess);

    Integer successCnt = totalSuccess.size();
    Integer failCnt = totalFail.size();

    String status;

    if (failCnt > 0 && successCnt > 0) {
      status = 'PARTIAL';
    } else if (failCnt > 0) {
      status = 'ERROR';
    } else {
      status = 'SUCCESS';
    }

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);

    logger.logging(CouponExcelIssueBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL success=' + successCnt + ', fail=' + failCnt);
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();
  }
}