public with sharing class PromotionTriggerHandler extends TriggerHandler {
  public PromotionTriggerHandler() {
    this.setMaxLoopCount(2);
  }

  public override void afterInsert() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<Promotion> newList = (List<Promotion>) Trigger.new;

    Set<Id> pIds = new Set<Id>();
    for (Promotion p : newList) {
      pIds.add(p.Id);
    }

    List<Promotion> pList = [
      SELECT
        Id,
        PromotionNo__c,
        Name,
        BrandCode__c,
        toLabel(BrandCode__c) brandCodeLabel,
        TypeCode__c,
        toLabel(TypeCode__c) typeCodeLabel,
        StartDate,
        EndDate,
        PublishStartDate__c,
        PublishEndDate__c,
        StatusCode__c,
        toLabel(StatusCode__c) statusCodeLabel,
        IsCouponAllowed__c,
        IsFixedAmountCouponAllowed__c,
        IsRateCouponAllowed__c,
        IsSpecificCouponAllowed__c,
        IsPointUsageAllowed__c,
        IsAllStore__c,
        IsAllItem__c,
        CreatedBy.Name,
        LastModifiedBy.Name,
        InsertId__c,
        ResponId__c,
        DepartmentCode__c,
        PromotionCode
      FROM Promotion
      WHERE Id IN :pIds
    ];

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (pList == null || pList.isEmpty()) {
        logger.setStatus('SUCCESS'); logger.setDescription('scope is empty'); return;
      }

      logger.setScopedIds((List<SObject>) pList, 'Id');

      for (Promotion p : pList) {
        try {
          p.PromotionCode = p.PromotionNo__c;

          ErpPromotionReqDto.CreateRequest req = new ErpPromotionReqDto.CreateRequest(p);
          req.nm_type_prom = (String) p.get('typeCodeLabel');
          req.nm_stat = (String) p.get('statusCodeLabel');
          req.nm_brand = (String) p.get('brandCodeLabel');

          logger.setRequestBody(JSON.serialize(req));

          System.enqueueJob(new ErpPromotionJob(ErpPromotionJob.Operation.CREATE_MASTER, req, new ErpPromotionAsyncCallback(), p.Id));

          successIds.add((String) p.Id);
        } catch (CustomException ce) {
          failIds.add((String) p.Id); failMsgs.add('Id=' + p.Id + ' | ' + ce.getMessage());
        } catch (Exception ex) {
          failIds.add((String) p.Id); failMsgs.add('Id=' + p.Id + ' | ' + ex.getMessage());
        }
      }
      update pList;

      failIds.removeAll(successIds);

      // status: SUCCESS / PARTIAL / ERROR
      if (!failIds.isEmpty() && !successIds.isEmpty()) {
        logger.setStatus('PARTIAL');
      } else if (!failIds.isEmpty()) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription(
        'ERP promotion master create done. total=' + pList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
      );
    } catch (Exception e) {
      logger.createExceptionLog(e); logger.setStatus('ERROR'); logger.setDescription('Handler failed: ' + e.getMessage());
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

  public override void afterDelete() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<Promotion> oldList = (List<Promotion>) Trigger.old;

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (oldList == null || oldList.isEmpty()) {
        logger.setStatus('SUCCESS'); logger.setDescription('scope is empty'); return;
      }

      logger.setScopedIds((List<SObject>) oldList, 'Id');

      for (Promotion p : oldList) {
        try {
          ErpPromotionReqDto.DeleteRequest req = new ErpPromotionReqDto.DeleteRequest(p);

          logger.setRequestBody(JSON.serialize(req));

          System.enqueueJob(new ErpPromotionJob(ErpPromotionJob.Operation.DELETE_MASTER, req, new ErpPromotionAsyncCallback(), p.Id));

          successIds.add((String) p.Id);
        } catch (Exception ex) {
          failIds.add((String) p.Id); failMsgs.add('Id=' + p.Id + ' | ' + ex.getMessage());
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
        'ERP promotion master delete enqueue done. total=' + oldList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
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

  public override void afterUpdate() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Map<Id, Promotion> newMap = (Map<Id, Promotion>) Trigger.newMap;
    Map<Id, Promotion> oldMap = (Map<Id, Promotion>) Trigger.oldMap;

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    try {
      if (newMap == null || newMap.isEmpty()) {
        logger.setStatus('SUCCESS'); logger.setDescription('scope is empty'); return;
      }

      logger.setScopedIds((List<SObject>) new List<Promotion>(newMap.values()), 'Id');

      // 1) ERP 동기화 대상(Id)만 추림
      Set<Id> targetIds = new Set<Id>();
      for (Id pId : newMap.keySet()) {
        Promotion pNew = newMap.get(pId);
        Promotion pOld = oldMap.get(pId);
        if (pNew == null || pOld == null) {
          continue;
        }

        // 1-1) 내부 원복/후처리면 스킵
        if (pNew.ErpSyncSkip__c == true) {
          continue;
        }

        // 1-2) ERP 반영 필드 변경이 없으면 스킵
        if (!isErpSyncRelevantChange(pOld, pNew)) {
          continue;
        }

        targetIds.add(pId);
      }

      if (targetIds.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('No ERP-relevant changes.');
        return;
      }

      // 2) Update DTO에 필요한 필드 + toLabel 재조회
      List<Promotion> pList = [
        SELECT
          Id,
          PromotionNo__c,
          Name,
          BrandCode__c,
          toLabel(BrandCode__c) brandCodeLabel,
          TypeCode__c,
          toLabel(TypeCode__c) typeCodeLabel,
          StartDate,
          EndDate,
          PublishStartDate__c,
          PublishEndDate__c,
          StatusCode__c,
          toLabel(StatusCode__c) statusCodeLabel,
          IsCouponAllowed__c,
          IsFixedAmountCouponAllowed__c,
          IsRateCouponAllowed__c,
          IsSpecificCouponAllowed__c,
          IsPointUsageAllowed__c,
          IsAllStore__c,
          IsAllItem__c,
          CreatedBy.Name,
          LastModifiedBy.Name
        FROM Promotion
        WHERE Id IN :targetIds
      ];

      if (pList == null || pList.isEmpty()) {
        logger.setStatus('SUCCESS'); logger.setDescription('No Promotion found after filtering. targetCnt=' + targetIds.size()); return;
      }

      Integer enqCnt = 0;

      for (Promotion p : pList) {
        try {
          // 3) UpdateRequest 구성
          ErpPromotionReqDto.UpdateRequest req = new ErpPromotionReqDto.UpdateRequest(p);

          // 4) label(=toLabel alias) 주입
          req.nm_brand = (String) p.get('brandCodeLabel');
          req.nm_type_prom = (String) p.get('typeCodeLabel');
          req.nm_stat = (String) p.get('statusCodeLabel');

          // 로깅: 너무 커지면 대표 1건만 남기기
          if (enqCnt == 0) {
            logger.setRequestBody(JSON.serialize(req));
          }

          // 5) UPDATE_MASTER enqueue
          System.enqueueJob(new ErpPromotionJob(ErpPromotionJob.Operation.UPDATE_MASTER, req, new ErpPromotionAsyncCallback(), p.Id));

          enqCnt++;
          successIds.add((String) p.Id);
        } catch (CustomException ce) {
          failIds.add((String) p.Id); failMsgs.add('Id=' + p.Id + ' | ' + ce.getMessage());
        } catch (Exception ex) {
          failIds.add((String) p.Id); failMsgs.add('Id=' + p.Id + ' | ' + ex.getMessage());
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
        'ERP promotion master update enqueue done. target=' +
          targetIds.size() +
          ', fetched=' +
          pList.size() +
          ', enqueued=' +
          enqCnt +
          ', success=' +
          successIds.size() +
          ', fail=' +
          failIds.size()
      );
    } catch (Exception e) {
      logger.createExceptionLog(e); logger.setStatus('ERROR'); logger.setDescription('Handler failed: ' + e.getMessage());
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

  /**
   * ERP에 반영해야 하는 변경인지 판단
   * - Update/Insert DTO가 참조하는 필드만 비교
   * - ErpSyncSkip__c 같은 제어용 필드는 제외
   */
  @TestVisible
  private static Boolean isErpSyncRelevantChange(Promotion oldP, Promotion newP) {
    if (oldP == null || newP == null) {
      return true;
    }

    if (oldP.Name != newP.Name) {
      return true;
    }
    if (oldP.PromotionNo__c != newP.PromotionNo__c) {
      return true;
    }
    if (oldP.BrandCode__c != newP.BrandCode__c) {
      return true;
    }
    if (oldP.TypeCode__c != newP.TypeCode__c) {
      return true;
    }

    if (oldP.StartDate != newP.StartDate) {
      return true;
    }
    if (oldP.EndDate != newP.EndDate) {
      return true;
    }
    if (oldP.PublishStartDate__c != newP.PublishStartDate__c) {
      return true;
    }
    if (oldP.PublishEndDate__c != newP.PublishEndDate__c) {
      return true;
    }

    if (oldP.StatusCode__c != newP.StatusCode__c) {
      return true;
    }

    if (oldP.IsCouponAllowed__c != newP.IsCouponAllowed__c) {
      return true;
    }
    if (oldP.IsFixedAmountCouponAllowed__c != newP.IsFixedAmountCouponAllowed__c) {
      return true;
    }
    if (oldP.IsRateCouponAllowed__c != newP.IsRateCouponAllowed__c) {
      return true;
    }
    if (oldP.IsSpecificCouponAllowed__c != newP.IsSpecificCouponAllowed__c) {
      return true;
    }
    if (oldP.IsPointUsageAllowed__c != newP.IsPointUsageAllowed__c) {
      return true;
    }

    if (oldP.IsAllStore__c != newP.IsAllStore__c) {
      return true;
    }
    if (oldP.IsAllItem__c != newP.IsAllItem__c) {
      return true;
    }

    if (oldP.InsertId__c != newP.InsertId__c) {
      return true;
    }
    if (oldP.ResponId__c != newP.ResponId__c) {
      return true;
    }

    return false;
  }
}