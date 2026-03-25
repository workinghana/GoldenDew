public with sharing class PromotionStoreTriggerHandler extends TriggerHandler {
  private static final Integer ERP_BULK_CHUNK_SIZE = 200;
  private static Boolean afterUpdateRunning = false;

  public PromotionStoreTriggerHandler() {
    this.clearMaxLoopCount();
  }

  public override void afterInsert() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionStoreTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<PromotionAccount__c> newList = (List<PromotionAccount__c>) Trigger.new;
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
      List<PromotionAccount__c> paList = fetchPromotionAccounts(collectIds(newList), false, true);

      for (Integer startIdx = 0; startIdx < paList.size(); startIdx += ERP_BULK_CHUNK_SIZE) {
        Integer endIdx = Math.min(startIdx + ERP_BULK_CHUNK_SIZE, paList.size());
        ErpPromotionStoreReqDto.CreateRequestList req = new ErpPromotionStoreReqDto.CreateRequestList();
        Set<Id> chunkIds = new Set<Id>();

        try {
          for (Integer i = startIdx; i < endIdx; i++) {
            PromotionAccount__c pa = paList[i];
            req.promotionStoreList.add(new ErpPromotionStoreReqDto.CreateRequest(pa));
            chunkIds.add(pa.Id);
          }

          logger.setRequestBody(JSON.serialize(req));
          System.enqueueJob(
            new ErpPromotionStoreJob(ErpPromotionStoreJob.Operation.CREATE_PROMOTION_STORE, req, new ErpPromotionStoreAsyncCallback(), chunkIds)
          );

          for (Id chunkId : chunkIds) {
            successIds.add((String) chunkId);
          }
        } catch (Exception ex) {
          for (Id chunkId : chunkIds) {
            failIds.add((String) chunkId);
            failMsgs.add('Id=' + chunkId + ' | ' + ex.getMessage());
          }
        }
      }

      failIds.removeAll(successIds);
      setLoggerStatus(logger, successIds, failIds);
      logger.setDescription(
        'ERP Promotion Store create enqueue done. total=' + paList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setDescription('Handler failed: ' + e.getMessage());
    } finally {
      finishLogger(logger, successIds, failIds, failMsgs);
    }
  }

  public override void afterDelete() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionStoreTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<PromotionAccount__c> oldList = (List<PromotionAccount__c>) Trigger.old;
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
      List<PromotionAccount__c> paList = fetchPromotionAccounts(collectIds(oldList), true, false);

      for (Integer startIdx = 0; startIdx < paList.size(); startIdx += ERP_BULK_CHUNK_SIZE) {
        Integer endIdx = Math.min(startIdx + ERP_BULK_CHUNK_SIZE, paList.size());
        ErpPromotionStoreReqDto.DeleteRequestList req = new ErpPromotionStoreReqDto.DeleteRequestList();
        Set<Id> chunkIds = new Set<Id>();

        try {
          for (Integer i = startIdx; i < endIdx; i++) {
            PromotionAccount__c pa = paList[i];
            req.promotionStoreList.add(new ErpPromotionStoreReqDto.DeleteRequest(pa));
            chunkIds.add(pa.Id);
          }

          logger.setRequestBody(JSON.serialize(req));
          System.enqueueJob(
            new ErpPromotionStoreJob(ErpPromotionStoreJob.Operation.DELETE_PROMOTION_STORE, req, new ErpPromotionStoreAsyncCallback(), chunkIds)
          );

          for (Id chunkId : chunkIds) {
            successIds.add((String) chunkId);
          }
        } catch (Exception ex) {
          for (Id chunkId : chunkIds) {
            failIds.add((String) chunkId);
            failMsgs.add('Id=' + chunkId + ' | ' + ex.getMessage());
          }
        }
      }

      failIds.removeAll(successIds);
      setLoggerStatus(logger, successIds, failIds);
      logger.setDescription(
        'ERP Promotion Store delete enqueue done. total=' + paList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
      );
    } finally {
      finishLogger(logger, successIds, failIds, failMsgs);
    }
  }

  public override void afterUpdate() {
    if (afterUpdateRunning) {
      return;
    }
    afterUpdateRunning = true;

    handleAfterUpdate((Map<Id, PromotionAccount__c>) Trigger.newMap, (Map<Id, PromotionAccount__c>) Trigger.oldMap);
    afterUpdateRunning = false;
  }

  @TestVisible
  private static void handleAfterUpdate(Map<Id, PromotionAccount__c> newMap, Map<Id, PromotionAccount__c> oldMap) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionStoreTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());
    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (newMap == null || newMap.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      logger.setScopedIds((List<SObject>) new List<PromotionAccount__c>(newMap.values()), 'Id');

      List<Id> changedIds = new List<Id>();
      List<PromotionAccount__c> oldChangedList = new List<PromotionAccount__c>();
      List<PromotionAccount__c> newChangedList = new List<PromotionAccount__c>();

      for (Id paId : newMap.keySet()) {
        PromotionAccount__c newRec = newMap.get(paId);
        PromotionAccount__c oldRec = oldMap.get(paId);

        if (newRec.ErpSyncSkip__c == true) {
          continue;
        }
        if (!isPromotionStoreChanged(oldRec, newRec)) {
          continue;
        }

        changedIds.add(paId);
        oldChangedList.add(oldRec);
        newChangedList.add(newRec);
        successIds.add((String) paId);
      }

      Map<Id, Promotion> oldPromotionsById = new Map<Id, Promotion>();
      Map<Id, Account> oldAccountsById = new Map<Id, Account>();
      Map<Id, Promotion> newPromotionsById = new Map<Id, Promotion>();
      Map<Id, Account> newAccountsById = new Map<Id, Account>();

      Set<Id> oldPromotionIds = new Set<Id>();
      Set<Id> oldAccountIds = new Set<Id>();
      Set<Id> newPromotionIds = new Set<Id>();
      Set<Id> newAccountIds = new Set<Id>();

      for (PromotionAccount__c oldRec : oldChangedList) {
        if (oldRec.PromotionId__c != null) {
          oldPromotionIds.add(oldRec.PromotionId__c);
        }
        if (oldRec.AccountId__c != null) {
          oldAccountIds.add(oldRec.AccountId__c);
        }
      }

      for (PromotionAccount__c newRec : newChangedList) {
        if (newRec.PromotionId__c != null) {
          newPromotionIds.add(newRec.PromotionId__c);
        }
        if (newRec.AccountId__c != null) {
          newAccountIds.add(newRec.AccountId__c);
        }
      }

      if (!oldPromotionIds.isEmpty()) {
        oldPromotionsById = new Map<Id, Promotion>(
          [
            SELECT Id, PromotionNo__c
            FROM Promotion
            WHERE Id IN :oldPromotionIds
          ]
        );
      }

      if (!oldAccountIds.isEmpty()) {
        oldAccountsById = new Map<Id, Account>(
          [
            SELECT Id, StoreCode__c
            FROM Account
            WHERE Id IN :oldAccountIds
          ]
        );
      }

      if (!newPromotionIds.isEmpty()) {
        newPromotionsById = new Map<Id, Promotion>(
          [
            SELECT Id, PromotionNo__c
            FROM Promotion
            WHERE Id IN :newPromotionIds
          ]
        );
      }

      if (!newAccountIds.isEmpty()) {
        newAccountsById = new Map<Id, Account>(
          [
            SELECT Id, StoreCode__c, CompanyCode__c, Name
            FROM Account
            WHERE Id IN :newAccountIds
          ]
        );
      }

      for (Integer startIdx = 0; startIdx < changedIds.size(); startIdx += ERP_BULK_CHUNK_SIZE) {
        Integer endIdx = Math.min(startIdx + ERP_BULK_CHUNK_SIZE, changedIds.size());
        ErpPromotionStoreReqDto.DeleteRequestList deleteReq = new ErpPromotionStoreReqDto.DeleteRequestList();
        ErpPromotionStoreReqDto.CreateRequestList createReq = new ErpPromotionStoreReqDto.CreateRequestList();
        Set<Id> chunkIds = new Set<Id>();

        try {
          for (Integer i = startIdx; i < endIdx; i++) {
            PromotionAccount__c oldRec = oldChangedList[i];
            PromotionAccount__c newRec = newChangedList[i];
            Promotion oldPromotion = oldPromotionsById.get(oldRec.PromotionId__c);
            Account oldAccount = oldAccountsById.get(oldRec.AccountId__c);
            Promotion newPromotion = newPromotionsById.get(newRec.PromotionId__c);
            Account newAccount = newAccountsById.get(newRec.AccountId__c);
            Id chunkId = changedIds[i];

            if (oldPromotion == null || oldAccount == null || newPromotion == null || newAccount == null) {
              throw new CustomException('Related promotion/store data is missing.');
            }

            deleteReq.promotionStoreList.add(
              new ErpPromotionStoreReqDto.DeleteRequest(oldPromotion.PromotionNo__c, oldAccount.StoreCode__c, UserInfo.getUserName())
            );
            createReq.promotionStoreList.add(
              new ErpPromotionStoreReqDto.CreateRequest(
                newAccount.CompanyCode__c,
                newPromotion.PromotionNo__c,
                newAccount.StoreCode__c,
                newAccount.Name,
                UserInfo.getUserName()
              )
            );
            chunkIds.add(chunkId);
          }

          logger.setRequestBody(JSON.serialize(deleteReq));
          System.enqueueJob(
            new ErpPromotionStoreJob(ErpPromotionStoreJob.Operation.DELETE_PROMOTION_STORE, deleteReq, new ErpPromotionStoreAsyncCallback(), chunkIds)
          );

          logger.setRequestBody(JSON.serialize(createReq));
          System.enqueueJob(
            new ErpPromotionStoreJob(ErpPromotionStoreJob.Operation.CREATE_PROMOTION_STORE, createReq, new ErpPromotionStoreAsyncCallback(), chunkIds)
          );
        } catch (Exception ex) {
          for (Id chunkId : chunkIds) {
            successIds.remove((String) chunkId);
            failIds.add((String) chunkId);
            failMsgs.add('Id=' + chunkId + ' | ' + ex.getMessage());
          }
        }
      }

      failIds.removeAll(successIds);
      setLoggerStatus(logger, successIds, failIds);
      logger.setDescription(
        'ERP Promotion Store update (delete+create) enqueue done. total=' +
          changedIds.size() +
          ', success=' +
          successIds.size() +
          ', fail=' +
          failIds.size()
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setDescription('Handler failed: ' + e.getMessage());
    } finally {
      finishLogger(logger, successIds, failIds, failMsgs);
    }
  }

  @TestVisible
  private static Set<Id> collectIds(List<PromotionAccount__c> records) {
    Set<Id> ids = new Set<Id>();
    if (records == null) {
      return ids;
    }

    for (PromotionAccount__c record : records) {
      ids.add(record.Id);
    }
    return ids;
  }

  @TestVisible
  private static List<PromotionAccount__c> fetchPromotionAccounts(Set<Id> paIds, Boolean includeDeleted, Boolean includeCreateFields) {
    if (paIds == null || paIds.isEmpty()) {
      return new List<PromotionAccount__c>();
    }

    if (includeDeleted) {
      return [
        SELECT Id, PromotionId__r.PromotionNo__c, AccountId__r.StoreCode__c
        FROM PromotionAccount__c
        WHERE Id IN :paIds
        ALL ROWS
      ];
    }

    if (includeCreateFields) {
      return [
        SELECT Id, PromotionId__r.PromotionNo__c, AccountId__r.StoreCode__c, AccountId__r.Name, AccountId__r.CompanyCode__c
        FROM PromotionAccount__c
        WHERE Id IN :paIds
      ];
    }

    return [
      SELECT Id, PromotionId__r.PromotionNo__c, AccountId__r.StoreCode__c, AccountId__r.Name, AccountId__r.CompanyCode__c
      FROM PromotionAccount__c
      WHERE Id IN :paIds
    ];
  }

  @TestVisible
  private static Boolean isPromotionStoreChanged(PromotionAccount__c oldRec, PromotionAccount__c newRec) {
    return oldRec.PromotionId__c != newRec.PromotionId__c || oldRec.AccountId__c != newRec.AccountId__c;
  }

  @TestVisible
  private static void setLoggerStatus(ApexLogger logger, Set<String> successIds, Set<String> failIds) {
    if (!failIds.isEmpty() && !successIds.isEmpty()) {
      logger.setStatus('PARTIAL');
    } else if (!failIds.isEmpty()) {
      logger.setStatus('ERROR');
    } else {
      logger.setStatus('SUCCESS');
    }
  }

  @TestVisible
  private static void finishLogger(ApexLogger logger, Set<String> successIds, Set<String> failIds, List<String> failMsgs) {
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
