/**
 * 회원 예상 등급 필드 값 변경 Batch Class
 * - Contact의 TierQualifyingSpend3Y__c 값을 기반으로 ExpectedGrade__c 업데이트
 *
 * @author Changhwan Kim
 * @since 2026-01-30
 */
public with sharing class ExpectedGradeCalculationBatch implements Database.Batchable<SObject>, Database.Stateful {
  // =========================
  // Stateful Total Result
  // =========================
  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  public ExpectedGradeCalculationBatch() {
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    // (기존 로직 유지) - Contact 탈퇴일이 없는 대상
    return Database.getQueryLocator(
      [
        SELECT TierQualifyingSpend3Y__c, MemberDropDate__c, ExpectedGrade__c
        FROM Contact
        WHERE MemberDropDate__c = NULL
      ]
    );
  }

  public void execute(Database.BatchableContext bc, List<Contact> cList) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(ExpectedGradeCalculationBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    // 청크 범위 식별
    if (cList != null && !cList.isEmpty()) {
      logger.setScopedIds((List<SObject>) cList, 'Id');
    }

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      // scope empty 처리
      if (cList == null || cList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      // 등급(티어) 조회
      List<LoyaltyTier> ltList = [
        SELECT Id, MinimumEligibleBalance, Grade__c
        FROM LoyaltyTier
        WHERE MinimumEligibleBalance != NULL
        ORDER BY MinimumEligibleBalance DESC
      ];
      if (ltList.isEmpty()) {
        // 청크 전체 실패로 기록(대상은 있었는데 기준티어가 없어서 처리 불가)
        for (Contact c : cList) {
          failIds.add(c.Id);
        }
        logger.setStatus('ERROR');
        logger.setErrorCode('NOT_FOUND');
        logger.setErrorMessage('LoyaltyTier is empty');
        return;
      }

      // =========================
      // Business Logic (그대로)
      // =========================
      for (Contact c : cList) {
        try {
          Decimal spend = (c.TierQualifyingSpend3Y__c == null) ? 0 : c.TierQualifyingSpend3Y__c;

          for (LoyaltyTier lt : ltList) {
            Decimal minAmt = (Decimal) lt.MinimumEligibleBalance;
            if (spend >= minAmt) {
              c.ExpectedGrade__c = lt.Grade__c;
              break; // DESC 정렬이므로 첫 매칭이 가장 높은 등급
            }
          }

          successIds.add(c.Id);
        } catch (Exception e) {
          failIds.add(c.Id);
          failMsgs.add('ContactId=' + c.Id + ' err=' + e.getMessage());
        }
      }

      // 부분 성공 DML
      // - 개별 실패는 failIds에 이미 반영돼 있으니,
      //   update 자체는 allOrNone=false로 돌려서 DML 실패도 개별 집계
      Database.SaveResult[] srList = Database.update(cList, false);
      for (Integer i = 0; i < srList.size(); i++) {
        Database.SaveResult sr = srList[i];
        Contact c = cList[i];

        if (!sr.isSuccess()) {
          // DML 실패는 성공 집합에서 제외하고 실패로 전환
          successIds.remove(c.Id);
          failIds.add(c.Id);

          for (Database.Error err : sr.getErrors()) {
            failMsgs.add('DML update failed. ContactId=' + c.Id + ', msg=' + err.getMessage());
          }
        }
      }

      // 성공한 건은 실패 목록에서 제거
      failIds.removeAll(successIds);

      Boolean hasAnyFail = !failIds.isEmpty();
      Boolean hasAnySuccess = !successIds.isEmpty();

      if (hasAnyFail && hasAnySuccess) {
        logger.setStatus('PARTIAL');
      } else if (hasAnyFail) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription('chunkSize=' + cList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size());
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
    } finally {
      // Stateful total 집계
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      // logger 세팅
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

  public void finish(Database.BatchableContext bc) {
    // 최종 실패 목록 정리(성공한 Id는 실패에서 제거)
    totalFail.removeAll(totalSuccess);

    Integer successCnt = totalSuccess.size();
    Integer failCnt = totalFail.size();

    String status;
    SchedulerNotificationPublisher.ResultStatus notifStatus;

    if (failCnt > 0 && successCnt > 0) {
      status = 'PARTIAL';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.PARTIAL;
    } else if (failCnt > 0) {
      status = 'ERROR';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.ERROR;
    } else {
      status = 'SUCCESS';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.SUCCESS;
    }

    // finish 로그
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(ExpectedGradeCalculationBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL success=' + successCnt + ', fail=' + failCnt);
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();

    String msg = 'Status=' + status + ', success=' + successCnt + ', fail=' + failCnt + ', jobId=' + bc.getJobId();
    SchedulerNotificationPublisher.publishResult('ExpectedGradeCalculationBatch', notifStatus, msg, bc.getJobId(), null);
  }
}