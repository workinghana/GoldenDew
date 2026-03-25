public with sharing class PromotionPointTriggerHandler extends TriggerHandler {
  public PromotionPointTriggerHandler() {
    this.setMaxLoopCount(2);
  }

  /* =========================================================
   * after insert
   * ========================================================= */
  public override void afterInsert() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionPointTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<PromotionPointLimit__c> newList = (List<PromotionPointLimit__c>) Trigger.new;

    Set<Id> ppIds = new Set<Id>();
    for (PromotionPointLimit__c pp : newList) {
      ppIds.add(pp.Id);
    }

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (newList == null || newList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      logger.setScopedIds((List<SObject>) newList, 'Id');

      List<PromotionPointLimit__c> ppList = [
        SELECT
          Id,
          Name,
          Value__c,
          Type__c,
          PromotionId__c,
          PromotionId__r.PromotionNo__c,
          LoyaltyPgmCurrencySubtypeId__c,
          LoyaltyPgmCurrencySubtypeName__c
        FROM PromotionPointLimit__c
        WHERE Id IN :ppIds
      ];

      for (PromotionPointLimit__c pp : ppList) {
        try {
          ErpPromotionPointReqDto.CreateRequest req = new ErpPromotionPointReqDto.CreateRequest(pp);

          logger.setRequestBody(JSON.serialize(req));

          System.enqueueJob(
            new ErpPromotionPointJob(ErpPromotionPointJob.Operation.CREATE_PROMOTION_POINT, req, new ErpPromotionPointAsyncCallback(), pp.Id)
          );

          successIds.add((String) pp.Id);
        } catch (Exception ex) {
          failIds.add((String) pp.Id);
          failMsgs.add('Id=' + pp.Id + ' | ' + ex.getMessage());
        }
      }

      failIds.removeAll(successIds);

      if (!failIds.isEmpty() && !successIds.isEmpty()) {
        logger.setStatus('PARTIAL');
      } else if (!failIds.isEmpty()) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription(
        'ERP Promotion Point create enqueue done. total=' + ppList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
      );
    } finally {
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

  /* =========================================================
   * after delete
   * ========================================================= */
  public override void afterDelete() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionPointTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<PromotionPointLimit__c> oldList = (List<PromotionPointLimit__c>) Trigger.old;

    Set<Id> ppIds = new Set<Id>();
    for (PromotionPointLimit__c pp : oldList) {
      ppIds.add(pp.Id);
    }

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (oldList == null || oldList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      logger.setScopedIds((List<SObject>) oldList, 'Id');

      // ✅ 실제 존재하는 필드 기준으로 수정
      List<PromotionPointLimit__c> ppList = [
        SELECT Id, Name, PromotionId__c, PromotionId__r.PromotionNo__c
        FROM PromotionPointLimit__c
        WHERE Id IN :ppIds
        ALL ROWS
      ];

      for (PromotionPointLimit__c pp : ppList) {
        try {
          ErpPromotionPointReqDto.DeleteRequest req = new ErpPromotionPointReqDto.DeleteRequest(pp);

          logger.setRequestBody(JSON.serialize(req));

          System.enqueueJob(
            new ErpPromotionPointJob(ErpPromotionPointJob.Operation.DELETE_PROMOTION_POINT, req, new ErpPromotionPointAsyncCallback(), pp.Id)
          );

          successIds.add((String) pp.Id);
        } catch (Exception ex) {
          failIds.add((String) pp.Id);
          failMsgs.add('Id=' + pp.Id + ' | ' + ex.getMessage());
        }
      }

      failIds.removeAll(successIds);

      if (!failIds.isEmpty() && !successIds.isEmpty()) {
        logger.setStatus('PARTIAL');
      } else if (!failIds.isEmpty()) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription(
        'ERP Promotion Point delete enqueue done. total=' + ppList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
      );
    } finally {
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

  /* =====================================================
   * after update : 프로모션 포인트 수정 → ERP 연동
   * ===================================================== */
  private static Boolean afterUpdateRunning = false;

  public override void afterUpdate() {
    // 0. 같은 트랜잭션 재진입 차단
    if (afterUpdateRunning) {
      return;
    }
    afterUpdateRunning = true;

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionPointTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Map<Id, PromotionPointLimit__c> newMap = (Map<Id, PromotionPointLimit__c>) Trigger.newMap;
    Map<Id, PromotionPointLimit__c> oldMap = (Map<Id, PromotionPointLimit__c>) Trigger.oldMap;

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (newMap == null || newMap.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      logger.setScopedIds((List<SObject>) new List<PromotionPointLimit__c>(newMap.values()), 'Id');

      for (Id ppId : newMap.keySet()) {
        PromotionPointLimit__c newRec = newMap.get(ppId);
        PromotionPointLimit__c oldRec = oldMap.get(ppId);

        try {
          /* ---------------------------------------------
           * 1. ERP 콜백 / 내부 update 차단
           * --------------------------------------------- */
          if (newRec.ErpSyncSkip__c == true) {
            continue;
          }

          /* ---------------------------------------------
           * 2. ERP 영향 없는 변경 skip
           * --------------------------------------------- */
          if (
            newRec.Value__c == oldRec.Value__c &&
            newRec.Type__c == oldRec.Type__c &&
            newRec.LoyaltyPgmCurrencySubtypeId__c == oldRec.LoyaltyPgmCurrencySubtypeId__c &&
            newRec.PromotionId__c == oldRec.PromotionId__c
          ) {
            continue;
          }

          /* =================================================
           * 3. UPDATE 요청 생성
           * ================================================= */
          ErpPromotionPointReqDto.UpdateRequest req = new ErpPromotionPointReqDto.UpdateRequest();

          req.cd_company = '1000'; // 회사 코드
          req.no_prom = newRec.PromotionId__r.PromotionNo__c;
          req.no_prom_point = newRec.Name; // 또는 ERP 포인트 코드 필드
          req.nm_prom_point = newRec.Name;
          req.cd_type_prom_point = newRec.Type__c;
          req.nm_type_prom_point = newRec.Type__c; // 필요 시 매핑
          req.cd_type_point = newRec.LoyaltyPgmCurrencySubtypeId__c;
          req.nm_type_point = newRec.LoyaltyPgmCurrencySubtypeName__c;
          req.pt_save = Integer.valueOf(newRec.Value__c);
          req.id_update = UserInfo.getUserName();

          logger.setRequestBody(JSON.serialize(req));

          System.enqueueJob(
            new ErpPromotionPointJob(ErpPromotionPointJob.Operation.UPDATE_PROMOTION_POINT, req, new ErpPromotionPointAsyncCallback(), ppId, oldRec)
          );

          successIds.add((String) ppId);
        } catch (Exception ex) {
          failIds.add((String) ppId);
          failMsgs.add('Id=' + ppId + ' | ' + ex.getMessage());
        }
      }

      failIds.removeAll(successIds);

      logger.setStatus((!failIds.isEmpty() && !successIds.isEmpty()) ? 'PARTIAL' : (!failIds.isEmpty()) ? 'ERROR' : 'SUCCESS');

      logger.setDescription(
        'ERP Promotion Point update enqueue done. total=' + newMap.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setDescription('Handler failed: ' + e.getMessage());
    } finally {
      afterUpdateRunning = false;

      if (!successIds.isEmpty())
        logger.setSuccessRecordIds(successIds);
      if (!failIds.isEmpty())
        logger.setFailedRecordIds(failIds);
      if (!failMsgs.isEmpty())
        logger.setErrorMessage(String.join(failMsgs, ' | '));

      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }
}