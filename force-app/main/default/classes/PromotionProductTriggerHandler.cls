public with sharing class PromotionProductTriggerHandler extends TriggerHandler {
  private static final Integer ERP_BULK_CHUNK_SIZE = 200;

  private class TestHookException extends Exception {
  }

  // Test-only hook (no runtime effect). Values:
  // 0: off
  // 10: afterInsert item build -> throw CustomException once
  // 11: afterInsert item build -> throw Exception once
  // 12: afterInsert outer try -> throw Exception once
  // 20: afterDelete item build -> throw Exception once
  // 21: afterUpdate item build -> throw Exception once
  // 30: afterInsert end -> throw Exception once (to hit trigger-level catch)
  @TestVisible
  private static Integer testHook = 0;
  @TestVisible
  private static Integer testHookFired = 0;

  public PromotionProductTriggerHandler() {
    this.clearMaxLoopCount();
  }

  public override void afterInsert() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionProductTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<PromotionProduct> newList = (List<PromotionProduct>) Trigger.new;
    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (Test.isRunningTest() && testHook == 12 && testHookFired == 0) {
        testHookFired = 1;
        throw new TestHookException('Forced outer exception (test)');
      }

      if (newList == null || newList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      logger.setScopedIds((List<SObject>) newList, 'Id');
      System.debug(LoggingLevel.INFO, 'PromotionProductTriggerHandler.afterInsert newList size=' + newList.size());

      List<PromotionProduct> ppList = fetchPromotionProducts(collectIds(newList), false);
      List<ErpPromotionProductReqDto.PromotionItem> items = new List<ErpPromotionProductReqDto.PromotionItem>();
      Set<Id> enqueueTargetIds = new Set<Id>();
      System.debug(LoggingLevel.INFO, 'PromotionProductTriggerHandler.afterInsert fetched ppList size=' + ppList.size());

      for (PromotionProduct pp : ppList) {
        try {
          if (Test.isRunningTest() && testHookFired == 0 && testHook == 10) {
            testHookFired = 1;
            throw new CustomException('Forced CustomException (test)');
          }
          if (Test.isRunningTest() && testHookFired == 0 && testHook == 11) {
            testHookFired = 1;
            throw new TestHookException('Forced Exception (test)');
          }

          ErpPromotionProductReqDto.PromotionItem item = new ErpPromotionProductReqDto.PromotionItem(pp);
          item.id_insert = UserInfo.getUserName();
          items.add(item);
          enqueueTargetIds.add(pp.Id);
        } catch (CustomException ce) {
          addFailure(failIds, failMsgs, pp.Id, ce.getMessage());
        } catch (Exception ex) {
          addFailure(failIds, failMsgs, pp.Id, ex.getMessage());
        }
      }

      if (!items.isEmpty()) {
        Integer chunkCount = 0;

        for (Integer startIdx = 0; startIdx < items.size(); startIdx += ERP_BULK_CHUNK_SIZE) {
          Integer endIdx = Math.min(startIdx + ERP_BULK_CHUNK_SIZE, items.size());
          ErpPromotionProductReqDto.CreateRequestList req = new ErpPromotionProductReqDto.CreateRequestList();
          Set<Id> chunkRecordIds = new Set<Id>();

          for (Integer i = startIdx; i < endIdx; i++) {
            req.promotionItemList.add(items[i]);
            chunkRecordIds.add(ppList[i].Id);
          }

          chunkCount++;
          logger.setRequestBody(JSON.serialize(req));
          System.debug(
            LoggingLevel.INFO,
            'PromotionProductTriggerHandler.afterInsert enqueue request chunk=' +
              chunkCount +
              ', itemCount=' +
              req.promotionItemList.size() +
              ', enqueueTargetCount=' +
              chunkRecordIds.size()
          );

          try {
            System.enqueueJob(
              new ErpPromotionProductJob(
                ErpPromotionProductJob.Operation.CREATE_PROMOTION_PRODUCT,
                req,
                new ErpPromotionProductAsyncCallback(),
                chunkRecordIds
              )
            );
            System.debug(LoggingLevel.INFO, 'PromotionProductTriggerHandler.afterInsert enqueue success. chunk=' + chunkCount);

            for (Id successId : chunkRecordIds) {
              successIds.add((String) successId);
            }
          } catch (Exception ex) {
            System.debug(
              LoggingLevel.ERROR,
              'PromotionProductTriggerHandler.afterInsert enqueue failed. chunk=' + chunkCount + ', message=' + ex.getMessage()
            );
            for (Id failedId : chunkRecordIds) {
              addFailure(failIds, failMsgs, failedId, ex.getMessage());
            }
          }
        }
      }

      failIds.removeAll(successIds);
      setLoggerStatus(logger, successIds, failIds);
      logger.setDescription('ERP Promotion Item create done. total=' + ppList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size());
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setDescription('Handler failed: ' + e.getMessage());
    } finally {
      finishLogger(logger, successIds, failIds, failMsgs);
    }

    if (Test.isRunningTest() && testHook == 30 && testHookFired == 0) {
      testHookFired = 1;
      throw new TestHookException('Forced uncaught exception for trigger catch (test)');
    }
  }

  public override void afterUpdate() {
    handleAfterUpdate((Map<Id, PromotionProduct>) Trigger.newMap, (Map<Id, PromotionProduct>) Trigger.oldMap);
  }

  @TestVisible
  private static void handleAfterUpdate(Map<Id, PromotionProduct> newMap, Map<Id, PromotionProduct> oldMap) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionProductTriggerHandler.class.getName());
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

      logger.setScopedIds((List<SObject>) new List<PromotionProduct>(newMap.values()), 'Id');

      Set<Id> changedIds = new Set<Id>();
      for (Id ppId : newMap.keySet()) {
        PromotionProduct ppNew = newMap.get(ppId);
        PromotionProduct ppOld = oldMap.get(ppId);

        if (shouldSkipUpdate(ppNew)) {
          continue;
        }
        if (!isErpSyncRelevantChange(ppOld, ppNew)) {
          continue;
        }

        changedIds.add(ppId);
      }

      List<PromotionProduct> ppList = fetchPromotionProducts(changedIds, false);
      List<ErpPromotionProductReqDto.PromotionItem> items = new List<ErpPromotionProductReqDto.PromotionItem>();
      Set<Id> enqueueTargetIds = new Set<Id>();

      for (PromotionProduct pp : ppList) {
        try {
          if (Test.isRunningTest() && testHookFired == 0 && testHook == 21) {
            testHookFired = 1;
            throw new TestHookException('Forced update exception (test)');
          }

          ErpPromotionProductReqDto.PromotionItem item = new ErpPromotionProductReqDto.PromotionItem(pp);
          item.id_update = UserInfo.getUserName();
          items.add(item);
          enqueueTargetIds.add(pp.Id);
        } catch (Exception ex) {
          addFailure(failIds, failMsgs, pp.Id, ex.getMessage());
        }
      }

      if (!items.isEmpty()) {
        Integer chunkCount = 0;
        List<Id> changedIdList = new List<Id>(enqueueTargetIds);

        for (Integer startIdx = 0; startIdx < items.size(); startIdx += ERP_BULK_CHUNK_SIZE) {
          Integer endIdx = Math.min(startIdx + ERP_BULK_CHUNK_SIZE, items.size());
          ErpPromotionProductReqDto.UpdateRequestList req = new ErpPromotionProductReqDto.UpdateRequestList();
          Set<Id> chunkRecordIds = new Set<Id>();

          for (Integer i = startIdx; i < endIdx; i++) {
            req.promotionItemList.add(items[i]);
            chunkRecordIds.add(changedIdList[i]);
          }

          chunkCount++;
          logger.setRequestBody(JSON.serialize(req));

          try {
            System.enqueueJob(
              new ErpPromotionProductJob(
                ErpPromotionProductJob.Operation.UPDATE_PROMOTION_PRODUCT,
                req,
                new ErpPromotionProductAsyncCallback(),
                chunkRecordIds
              )
            );

            for (Id successId : chunkRecordIds) {
              successIds.add((String) successId);
            }
          } catch (Exception ex) {
            for (Id failedId : chunkRecordIds) {
              addFailure(failIds, failMsgs, failedId, ex.getMessage());
            }
          }
        }
      }

      failIds.removeAll(successIds);
      setLoggerStatus(logger, successIds, failIds);
      logger.setDescription(
        'ERP Promotion Item update done. total=' + changedIds.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
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
    logger.logging(PromotionProductTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<PromotionProduct> oldList = (List<PromotionProduct>) Trigger.old;
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

      List<PromotionProduct> ppList = fetchPromotionProducts(collectIds(oldList), true);
      List<ErpPromotionProductReqDto.PromotionItem> items = new List<ErpPromotionProductReqDto.PromotionItem>();
      Set<Id> enqueueTargetIds = new Set<Id>();

      for (PromotionProduct pp : ppList) {
        try {
          if (Test.isRunningTest() && testHookFired == 0 && testHook == 20) {
            testHookFired = 1;
            throw new TestHookException('Forced Exception (test)');
          }

          ErpPromotionProductReqDto.PromotionItem item = new ErpPromotionProductReqDto.PromotionItem(pp);
          item.id_delete = UserInfo.getUserName();
          items.add(item);
          enqueueTargetIds.add(pp.Id);
        } catch (Exception ex) {
          addFailure(failIds, failMsgs, pp.Id, ex.getMessage());
        }
      }

      if (!items.isEmpty()) {
        Integer chunkCount = 0;
        List<Id> deletedIdList = new List<Id>(enqueueTargetIds);

        for (Integer startIdx = 0; startIdx < items.size(); startIdx += ERP_BULK_CHUNK_SIZE) {
          Integer endIdx = Math.min(startIdx + ERP_BULK_CHUNK_SIZE, items.size());
          ErpPromotionProductReqDto.DeleteRequestList req = new ErpPromotionProductReqDto.DeleteRequestList();
          Set<Id> chunkRecordIds = new Set<Id>();

          for (Integer i = startIdx; i < endIdx; i++) {
            req.promotionItemList.add(items[i]);
            chunkRecordIds.add(deletedIdList[i]);
          }

          chunkCount++;
          logger.setRequestBody(JSON.serialize(req));

          try {
            System.enqueueJob(
              new ErpPromotionProductJob(
                ErpPromotionProductJob.Operation.DELETE_PROMOTION_PRODUCT,
                req,
                new ErpPromotionProductAsyncCallback(),
                chunkRecordIds
              )
            );

            for (Id successId : chunkRecordIds) {
              successIds.add((String) successId);
            }
          } catch (Exception ex) {
            for (Id failedId : chunkRecordIds) {
              addFailure(failIds, failMsgs, failedId, ex.getMessage());
            }
          }
        }
      }

      failIds.removeAll(successIds);
      setLoggerStatus(logger, successIds, failIds);
      logger.setDescription('ERP Promotion Item delete done. total=' + ppList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size());
    } finally {
      finishLogger(logger, successIds, failIds, failMsgs);
    }
  }

  @TestVisible
  private static Set<Id> collectIds(List<PromotionProduct> records) {
    Set<Id> ids = new Set<Id>();
    if (records == null) {
      return ids;
    }

    for (PromotionProduct record : records) {
      ids.add(record.Id);
    }
    return ids;
  }

  @TestVisible
  private static List<PromotionProduct> fetchPromotionProducts(Set<Id> ppIds, Boolean includeDeleted) {
    if (ppIds == null || ppIds.isEmpty()) {
      return new List<PromotionProduct>();
    }

    if (includeDeleted) {
      return [
        SELECT Id, Product.ProductCode, Promotion.PromotionNo__c
        FROM PromotionProduct
        WHERE Id IN :ppIds
        ALL ROWS
      ];
    }

    return [
      SELECT Id, Product.ProductCode, Promotion.PromotionNo__c
      FROM PromotionProduct
      WHERE Id IN :ppIds
    ];
  }

  @TestVisible
  private static Boolean shouldSkipUpdate(PromotionProduct ppNew) {
    try {
      Object value = ppNew.get('ErpSyncSkip__c');
      return value instanceof Boolean && (Boolean) value;
    } catch (Exception ex) {
      return false;
    }
  }

  @TestVisible
  private static Boolean isErpSyncRelevantChange(PromotionProduct ppOld, PromotionProduct ppNew) {
    if (ppOld == null || ppNew == null) {
      return false;
    }

    return ppOld.get('PromotionId') != ppNew.get('PromotionId') || ppOld.get('ProductId') != ppNew.get('ProductId');
  }

  @TestVisible
  private static void addFailure(Set<String> failIds, List<String> failMsgs, Id recordId, String message) {
    failIds.add((String) recordId);
    failMsgs.add('Id=' + recordId + ' | ' + message);
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
