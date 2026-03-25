public with sharing class LoyaltyMemberTierUpdateBatch implements Database.Batchable<SObject>, Database.Stateful {
  private static final String LOYALTY_PROGRAM_NAME = System.Label.LoyaltyProgramName;
  private static final String TIER_GROUP_NAME = System.Label.TierGroupName;

  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  public Database.QueryLocator start(Database.BatchableContext bc) {
    return Database.getQueryLocator(
      [
        SELECT ExpectedGrade__c, Grade__c, MemberNo__c
        FROM Contact
        WHERE ExpectedGrade__c != NULL AND MemberDropDate__c = NULL AND Grade__c != NULL
      ]
    );
  }

  public void execute(Database.BatchableContext bc, List<Contact> cList) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(LoyaltyMemberTierUpdateBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    if (cList != null && !cList.isEmpty()) {
      logger.setScopedIds((List<SObject>) cList, 'Id');
    }

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    Integer contactUpdateFailCnt = 0;
    Integer changeTierFailCnt = 0;

    try {
      if (cList == null || cList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      // 1) 청크에서 필요한 예상등급 코드 수집
      Set<String> expectedGradeSet = new Set<String>();
      for (Contact c : cList) {
        if (!String.isBlank(c.ExpectedGrade__c)) {
          expectedGradeSet.add(c.ExpectedGrade__c.trim());
        }
      }

      // 2) 해당 코드에 매칭되는 LoyaltyTier 조회
      Map<String, String> tierNameByGrade = new Map<String, String>();
      if (!expectedGradeSet.isEmpty()) {
        for (LoyaltyTier lt : [
          SELECT Id, Name, Grade__c
          FROM LoyaltyTier
          WHERE Grade__c IN :expectedGradeSet
        ]) {
          if (!String.isBlank(lt.Grade__c) && !String.isBlank(lt.Name)) {
            tierNameByGrade.put(lt.Grade__c, lt.Name);
          }
        }
      }

      List<Contact> targetContacts = new List<Contact>();
      Map<Id, Contact> contactById = new Map<Id, Contact>();

      for (Contact c : cList) {
        c.Grade__c = c.ExpectedGrade__c;

        targetContacts.add(c);
        contactById.put(c.Id, c);
      }

      // 변경 대상이 없다면 종료
      if (targetContacts.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('chunkSize=' + cList.size() + ', no target');
        return;
      }

      // 4) Contact update (부분 성공 권장)
      Database.SaveResult[] updResults = Database.update(targetContacts, false);
      Set<Id> updatedContactIdSet = new Set<Id>();

      for (Integer i = 0; i < updResults.size(); i++) {
        Database.SaveResult sr = updResults[i];
        Contact c = targetContacts[i];

        if (sr.isSuccess()) {
          updatedContactIdSet.add(c.Id);
        } else {
          contactUpdateFailCnt++;
          failIds.add((String) c.Id);

          for (Database.Error err : sr.getErrors()) {
            failMsgs.add('Contact update failed. contactId=' + c.Id + ', msg=' + err.getMessage());
          }
        }
      }

      // update 성공한 Contact만 티어 변경 대상으로 진행
      if (updatedContactIdSet.isEmpty()) {
        logger.setStatus('ERROR');
        logger.setErrorCode('DML_FAILED');
        logger.setErrorMessage('All Contact updates failed in this chunk.');
        return;
      }

      // 5) LoyaltyProgramMember 조회 (update 성공 대상만)
      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ContactId, Contact.ExpectedGrade__c
        FROM LoyaltyProgramMember
        WHERE ContactId IN :updatedContactIdSet
      ];
      if (lpmList.isEmpty()) {
        for (Id cid : updatedContactIdSet) {
          failIds.add((String) cid);
        }
        logger.setStatus('ERROR');
        logger.setErrorCode('NOT_FOUND');
        logger.setErrorMessage('LoyaltyProgramMember not found for updated contacts.');
        return;
      }

      // 6) ChangeTierInput 생성
      List<LoyaltyManagement.ChangeTierInput> changeTierList = new List<LoyaltyManagement.ChangeTierInput>();
      List<Id> inputContactIds = new List<Id>(); // 결과 매핑(입력 순서 기준)

      for (LoyaltyProgramMember lpm : lpmList) {
        String expectedGrade = (lpm.ContactId != null && lpm.Contact.ExpectedGrade__c != null) ? lpm.Contact.ExpectedGrade__c.trim() : null;

        String targetTierName = (expectedGrade == null) ? null : tierNameByGrade.get(expectedGrade);

        if (String.isBlank(targetTierName)) {
          failIds.add((String) lpm.ContactId);
          failMsgs.add('Tier mapping missing. contactId=' + lpm.ContactId + ', expectedGrade=' + expectedGrade);
          continue;
        }

        LoyaltyManagement.ChangeTierInput input = new LoyaltyManagement.ChangeTierInputBuilder()
          .setLoyaltyProgramMemberId(lpm.Id)
          .setProgramName(LOYALTY_PROGRAM_NAME)
          .setTierGroupName(TIER_GROUP_NAME)
          .setTargetTierName(targetTierName)
          .setChangeReason('등급 전환일 : ' + String.valueOf(Date.today()))
          .build();

        changeTierList.add(input);
        inputContactIds.add(lpm.ContactId);
      }

      // changeTier 호출 + 성공 contact 추출
      Set<Id> changeTierSuccessContactIds = new Set<Id>();

      // 입력이 없으면(매핑 실패만 있는 케이스) 여기서 상태 판단으로 넘어감
      if (!changeTierList.isEmpty()) {
        // 7) changeTier 호출
        List<LoyaltyManagement.ChangeTierOutput> results = LoyaltyManagement.LoyaltyResources.changeTier(changeTierList);

        Integer n = Math.min(results.size(), inputContactIds.size());

        for (Integer i = 0; i < n; i++) {
          Id contactId = inputContactIds[i];
          LoyaltyManagement.ChangeTierOutput r = results[i];

          if (r != null && r.isSuccess()) {
            successIds.add((String) contactId);
            changeTierSuccessContactIds.add(contactId);
          } else {
            changeTierFailCnt++;
            failIds.add((String) contactId);

            String errMsg = 'ChangeTier failed. contactId=' + contactId;
            try {
              if (r != null && r.getErrors() != null && !r.getErrors().isEmpty()) {
                errMsg += ', code=' + r.getErrors()[0].getCode() + ', msg=' + r.getErrors()[0].getMessage();
              }
            } catch (Exception ignore) {
              // 무시
            }
            failMsgs.add(errMsg);
          }
        }

        if (results.size() != inputContactIds.size()) {
          failMsgs.add('Result size mismatch. inputs=' + inputContactIds.size() + ', results=' + results.size());
        }
      }

      // 성공한 건은 실패 목록에서 제거
      failIds.removeAll(successIds);

      // =========================================================
      // 8) ERP PATCH(/Crm/Members/bulk) 호출은 Queueable로
      // - changeTier 성공한 contact만 ERP 전송
      // =========================================================
      if (!changeTierSuccessContactIds.isEmpty()) {
        ErpMemberReqDto.UpdateGradeRequest erpReq = new ErpMemberReqDto.UpdateGradeRequest();
        erpReq.ID_UPDATE = '밀버스';

        for (Id cid : changeTierSuccessContactIds) {
          Contact c = contactById.get(cid);
          if (c == null) {
            continue;
          }

          String noMbr = c.MemberNo__c;
          String cdGrade = c.Grade__c;

          if (String.isBlank(noMbr) || String.isBlank(cdGrade)) {
            failMsgs.add('ERP payload missing. contactId=' + cid + ', NO_MBR=' + noMbr + ', CD_GRADE_MBR=' + cdGrade);
            continue;
          }

          erpReq.memebrModelList.add(new ErpMemberReqDto.UpdateGradeMemebrModel(noMbr, cdGrade));
        }

        if (!erpReq.memebrModelList.isEmpty()) {
          System.enqueueJob(new ErpMemberJob(ErpMemberJob.Operation.UPDATE_GRADE, erpReq, new ErpMemberAsyncCallback(), changeTierSuccessContactIds));
        }
      }

      Boolean hasAnyFail = !failIds.isEmpty();
      Boolean hasAnySuccess = !successIds.isEmpty();

      if (hasAnyFail && hasAnySuccess) {
        logger.setStatus('PARTIAL');
      } else if (hasAnyFail) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription(
        'chunkSize=' +
          cList.size() +
          ', contactUpdateSuccess=' +
          updatedContactIdSet.size() +
          ', contactUpdateFailCnt=' +
          contactUpdateFailCnt +
          ', changeTierInputs=' +
          changeTierList.size() +
          ', success=' +
          successIds.size() +
          ', fail=' +
          failIds.size() +
          ', changeTierFailCnt=' +
          changeTierFailCnt +
          ', erpTargets=' +
          changeTierSuccessContactIds.size()
      );
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

  public void finish(Database.BatchableContext bc) {
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

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(LoyaltyMemberTierUpdateBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription('TOTAL success=' + successCnt + ', fail=' + failCnt);
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();

    String msg = 'Status=' + status + ', success=' + successCnt + ', fail=' + failCnt + ', jobId=' + bc.getJobId();
    SchedulerNotificationPublisher.publishResult('LoyaltyMemberTierUpdateBatch', notifStatus, msg, bc.getJobId(), null);

    // 등급산정 구매금액 재설정 Batch Class 실행
    // Database.executeBatch(new TierQualifyingSpend3YRecalcBatch(), 200);
  }
}