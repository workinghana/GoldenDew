public with sharing class PromotionCouponTriggerHandler extends TriggerHandler {
  public PromotionCouponTriggerHandler() {
    this.setMaxLoopCount(2);
  }

  /* =====================================================
   * after insert : 프로모션 쿠폰 등록 → ERP 연동
   * ===================================================== */
  public override void afterInsert() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionCouponTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<VoucherLimit__c> newList = (List<VoucherLimit__c>) Trigger.new;

    Set<Id> pcIds = new Set<Id>();
    for (VoucherLimit__c pc : newList) {
      pcIds.add(pc.Id);
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

      List<VoucherLimit__c> vlList = [
        SELECT
          Id,
          Name,
          Type__c,
          Value__c,
          ExternalId__c,
          Erp_Sync_Skip__c,
          PromotionId__r.PromotionNo__c,
          VoucherDefinitionId__r.EffectiveDate,
          VoucherDefinitionId__r.ExpirationDate,
          VoucherDefinitionId__r.CouponManNo__c,
          VoucherDefinitionId__r.CouponTypeCode__c,
          VoucherDefinitionId__r.AccountId__c
        FROM VoucherLimit__c
        WHERE Id IN :pcIds
      ];

      for (VoucherLimit__c vl : vlList) {
        ErpPromotionCouponReqDto.CreateRequest req = new ErpPromotionCouponReqDto.CreateRequest();

        //프로모션에 대한 쿠폰 설정만
        if (vl.Type__c != 'PromotionIncludeList') {
          continue;
        }

        if (vl.PromotionId__r == null) {
          continue;
        }

        // 회사코드
        req.cd_company = vl.VoucherDefinitionId__r.AccountId__c;

        // 프로모션 번호
        req.no_prom = vl.PromotionId__r.PromotionNo__c;

        // 쿠폰 번호
        req.no_man_coupon = vl.ExternalId__c;

        // 쿠폰명
        req.nm_man_coupon = vl.Name;

        // 쿠폰 유형 코드
        req.cd_type_coupon = vl.VoucherDefinitionId__r.CouponTypeCode__c;

        //유효 시작일 + 종료일
        Date startDate = vl.VoucherDefinitionId__r.EffectiveDate;
        Date endDate = vl.VoucherDefinitionId__r.ExpirationDate;

        Datetime startDt = Datetime.newInstance(startDate.year(), startDate.month(), startDate.day(), 0, 0, 0);

        Datetime endDt = Datetime.newInstance(endDate.year(), endDate.month(), endDate.day(), 0, 0, 0);

        req.dt_str_exp = startDt.format('yyyyMMdd');
        req.dt_end_exp = endDt.format('yyyyMMdd');

        // 할인 값 분기
        if (vl.Type__c == '01') {
          req.am_disc = vl.Value__c; // 정액
        } else {
          req.rt_disc = vl.Value__c; // 정률
        }

        req.id_insert = UserInfo.getUserName();

        System.enqueueJob(
          new ErpPromotionCouponJob(ErpPromotionCouponJob.Operation.CREATE_PROMOTION_COUPON, req, new ErpPromotionCouponAsyncCallback(), vl.Id)
        );
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
        'ERP Promotion Coupon create enqueue done. total=' + vlList.size() + ', success=' + successIds.size() + ', fail=' + failIds.size()
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setDescription('Handler failed: ' + e.getMessage());
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
   * after delete : 프로모션 쿠폰 삭제 → ERP 연동
   * ===================================================== */
  public override void afterDelete() {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionCouponTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    List<VoucherLimit__c> oldList = (List<VoucherLimit__c>) Trigger.old;

    Set<Id> ids = new Set<Id>();
    for (VoucherLimit__c vl : oldList) {
      ids.add(vl.Id);
    }

    try {
      if (oldList == null || oldList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      logger.setScopedIds((List<SObject>) oldList, 'Id');

      List<VoucherLimit__c> vlList = [
        SELECT Id, ExternalId__c, PromotionId__r.PromotionNo__c
        FROM VoucherLimit__c
        WHERE Id IN :ids
        ALL ROWS
      ];

      for (VoucherLimit__c vl : vlList) {
        //프로모션에 대한 쿠폰 설정만
        if (vl.PromotionId__r == null) {
          continue;
        }

        ErpPromotionCouponReqDto.DeleteRequest req = new ErpPromotionCouponReqDto.DeleteRequest();

        req.no_prom = vl.PromotionId__r.PromotionNo__c;
        req.cd_coupon = vl.ExternalId__c;
        req.id_delete = UserInfo.getUserName();

        System.enqueueJob(
          new ErpPromotionCouponJob(ErpPromotionCouponJob.Operation.DELETE_PROMOTION_COUPON, req, new ErpPromotionCouponAsyncCallback(), vl.Id)
        );
      }

      logger.setStatus('SUCCESS');
      logger.setDescription('ERP Promotion Coupon delete enqueue done. total=' + vlList.size());
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setDescription('Handler failed: ' + e.getMessage());
    } finally {
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  /* =====================================================
   * after update
   * ===================================================== */
  private static Boolean afterUpdateRunning = false;

  public override void afterUpdate() {
    if (afterUpdateRunning)
      return;
    afterUpdateRunning = true;

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ACTION);
    logger.logging(PromotionCouponTriggerHandler.class.getName());
    logger.setRequestDatetime(Datetime.now());

    Map<Id, VoucherLimit__c> newMap = (Map<Id, VoucherLimit__c>) Trigger.newMap;
    Map<Id, VoucherLimit__c> oldMap = (Map<Id, VoucherLimit__c>) Trigger.oldMap;

    try {
      if (newMap == null || newMap.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('scope is empty');
        return;
      }

      logger.setScopedIds((List<SObject>) new List<VoucherLimit__c>(newMap.values()), 'Id');

      Set<Id> ids = newMap.keySet();

      List<VoucherLimit__c> vlList = [
        SELECT
          Id,
          Name,
          Type__c,
          Value__c,
          ExternalId__c,
          Erp_Sync_Skip__c,
          PromotionId__r.PromotionNo__c,
          VoucherDefinitionId__r.Type,
          VoucherDefinitionId__r.EffectiveDate,
          VoucherDefinitionId__r.ExpirationDate,
          VoucherDefinitionId__r.CouponTypeCode__c,
          VoucherDefinitionId__r.AccountId__c
        FROM VoucherLimit__c
        WHERE Id IN :ids
      ];

      for (VoucherLimit__c vl : vlList) {
        VoucherLimit__c oldRec = oldMap.get(vl.Id);

        //프로모션에 대한 쿠폰 설정만
        if (vl.Type__c != 'PromotionIncludeList') {
          continue;
        }

        if (vl.PromotionId__r == null) {
          continue;
        }
        // 1. ERP 콜백 차단
        if (vl.Erp_Sync_Skip__c == true) {
          continue;
        }

        // 2. ERP 영향 없는 변경 skip
        if (vl.Value__c == oldRec.Value__c && vl.Type__c == oldRec.Type__c && vl.Name == oldRec.Name) {
          continue;
        }

        ErpPromotionCouponReqDto.UpdateRequest req = new ErpPromotionCouponReqDto.UpdateRequest();

        req.cd_company = vl.VoucherDefinitionId__r.AccountId__c;
        req.no_prom = vl.PromotionId__r.PromotionNo__c;
        req.no_man_coupon = vl.ExternalId__c;
        req.nm_man_coupon = vl.Name;

        req.cd_type_coupon = vl.VoucherDefinitionId__r.CouponTypeCode__c;

        req.nm_type_coupon = vl.VoucherDefinitionId__r.CouponTypeCode__c; // 필요시 라벨 매핑

        /* ===== 날짜 변환 ===== */
        req.dt_str_exp = ErpPromotionCouponReqDto.dateToYmd(vl.VoucherDefinitionId__r.EffectiveDate);

        req.dt_end_exp = ErpPromotionCouponReqDto.dateToYmd(vl.VoucherDefinitionId__r.ExpirationDate);

        /* ===== 할인 분기 ===== */
        Decimal discValue = null;

        if (vl.Value__c != null) {
          discValue = Decimal.valueOf(String.valueOf(vl.Value__c));
        }

        String discountType = vl.VoucherDefinitionId__r.Type;

        if (discountType == 'FixedValue') {
          req.am_disc = discValue;
          req.rt_disc = null;
        } else if (discountType == 'DiscountPercentage') {
          req.rt_disc = discValue;
          req.am_disc = null;
        }

        req.id_update = UserInfo.getUserName();

        System.enqueueJob(
          new ErpPromotionCouponJob(
            ErpPromotionCouponJob.Operation.UPDATE_PROMOTION_COUPON,
            req,
            new ErpPromotionCouponAsyncCallback(),
            vl.Id,
            oldRec
          )
        );
      }

      logger.setStatus('SUCCESS');
      logger.setDescription('ERP Promotion Coupon update enqueue done. total=' + vlList.size());
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setDescription('Handler failed: ' + e.getMessage());
    } finally {
      afterUpdateRunning = false;
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }
}