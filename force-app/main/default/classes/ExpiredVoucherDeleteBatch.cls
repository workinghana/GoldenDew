public with sharing class ExpiredVoucherDeleteBatch implements Database.Batchable<SObject>, Database.Stateful {
  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  /* ================= START ================= */

  public Database.QueryLocator start(Database.BatchableContext bc) {
    // 만료일(ExpirationDate, Date 타입)이 오늘 기준 1년 이전인 Voucher = 만료 후 2년 경과
    Date targetDate = Date.today().addYears(-1);

    System.debug('================ START =================');
    System.debug('Batch Job Id = ' + bc.getJobId());
    System.debug('targetDate = ' + targetDate);

    return Database.getQueryLocator(
      [
        SELECT Id, Status, ExpirationDate
        FROM Voucher
        WHERE ExpirationDate != NULL AND ExpirationDate <= :targetDate
      ]
    );
  }

  /* ================= EXECUTE ================= */

  public void execute(Database.BatchableContext bc, List<Voucher> scope) {
    System.debug('================ EXECUTE START =================');
    System.debug('scope size = ' + scope.size());

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(ExpiredVoucherDeleteBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (scope == null || scope.isEmpty()) {
        return;
      }

      // 롤백 지점 설정
      Savepoint sp = Database.setSavepoint();

      Database.DeleteResult[] results = Database.delete(scope, false);

      for (Integer i = 0; i < results.size(); i++) {
        String voucherId = scope[i].Id;

        if (results[i].isSuccess()) {
          successIds.add(voucherId);
        } else {
          failIds.add(voucherId);
          for (Database.Error err : results[i].getErrors()) {
            failMsgs.add('Voucher 삭제 실패: Id=' + voucherId + ', msg=' + err.getMessage());
          }
        }
      }

      if (!failIds.isEmpty()) {
        // ★ 한 건이라도 실패하면 이 청크 전체 롤백 (성공분도 되돌림)
        Database.rollback(sp);
        successIds.clear(); // 롤백됐으므로 성공 처리 무효화
        logger.setStatus('ERROR');
        System.debug('실패 발생 → 청크 롤백. 실패 건수=' + failIds.size());
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription('chunkSize=' + scope.size() + ', deleted=' + successIds.size() + ', fail=' + failIds.size());
    } catch (Exception e) {
      System.debug('Exception 발생=' + e.getMessage());
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      failMsgs.add('Exception: ' + e.getMessage());
    } finally {
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      Boolean hasFailure = !failIds.isEmpty() || !failMsgs.isEmpty();

      if (hasFailure) {
        if (!failIds.isEmpty()) {
          logger.setFailedRecordIds(failIds); // ← 실패한 voucher Id만 기록
        }
        if (!failMsgs.isEmpty()) {
          logger.setErrorMessage(String.join(failMsgs, ' | '));
        }
        logger.setResponseDatetime(Datetime.now());
        logger.addLog();
        ApexLogger.insertLogs();
      }

      System.debug('EXECUTE 종료');
    }
  }

  /* ================= FINISH ================= */

  public void finish(Database.BatchableContext bc) {
    System.debug('================ FINISH =================');

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

    logger.logging(ExpiredVoucherDeleteBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL success=' + successCnt + ', fail=' + failCnt);
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();

    ApexLogger.insertLogs();

    System.debug('Batch FINISH 완료');
  }
}
