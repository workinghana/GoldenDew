public with sharing class OrderTriggerHandler extends TriggerHandler {
  private static final String ORDER_STATUS_SALE_SUCCESS = 'saleSuccess'; // 판매 성공
  private static final String ORDER_STATUS_SALE_DELETED = 'saleDeleted'; // 판매 삭제
  private static final String ORDER_STATUS_RETURN_SUCCESS = 'returnSuccess'; // 반품 성공
  private static final String ORDER_STATUS_RETURN_DELETED = 'returnDeleted'; // 반품 삭제
  private static final String ORDER_STATUS_ORDER_SUCCESS = 'orderSuccess'; // 주문 성공

  public OrderTriggerHandler() {
    System.debug('OrderTriggerHandler count');
    this.setMaxLoopCount(2);
  }

  public override void afterUpdate() {
    ApexLogger logger;
    try {
      List<Order> newList = (List<Order>) Trigger.new;
      Map<Id, Order> oldMap = (Map<Id, Order>) Trigger.oldMap;

      if (newList == null || newList.isEmpty()) {
        return;
      }

      Set<Id> mceTargetOrderIds = new Set<Id>();

      // 3년구매금액 반영 대상(판매 등록/삭제, 반품 등록/삭제만)
      Map<Id, String> spendAffectOrderStatusById = new Map<Id, String>();

      for (Order newO : newList) {
        Order oldO = oldMap.get(newO.Id);
        if (oldO == null) {
          continue;
        }

        // 상태 전환 감지
        Boolean toSaleSuccess = (newO.Status == ORDER_STATUS_SALE_SUCCESS) && (oldO.Status == null || oldO.Status != ORDER_STATUS_SALE_SUCCESS); // 판매 성공
        Boolean toSaleDeleted = (newO.Status == ORDER_STATUS_SALE_DELETED) && (oldO.Status == null || oldO.Status != ORDER_STATUS_SALE_DELETED); // 판매 삭제
        Boolean toReturnSuccess = (newO.Status == ORDER_STATUS_RETURN_SUCCESS) && (oldO.Status == null || oldO.Status != ORDER_STATUS_RETURN_SUCCESS); // 반품 성공
        Boolean toReturnDeleted = (newO.Status == ORDER_STATUS_RETURN_DELETED) && (oldO.Status == null || oldO.Status != ORDER_STATUS_RETURN_DELETED); // 반품 삭제
        Boolean toOrderSuccess = (newO.Status == ORDER_STATUS_ORDER_SUCCESS) && (oldO.Status == null || oldO.Status != ORDER_STATUS_ORDER_SUCCESS); // 주문 성공

        // MCE 발송 대상 (주문 성공, 판매 성공, 반품 성공 건)
        if (toSaleSuccess || toReturnSuccess || toOrderSuccess) {
          // todo: 이 부분에서 판매 삭제, 반품 삭제 시에도 발송하는 지 확인 필요
          mceTargetOrderIds.add(newO.Id);
        }

        // 3년구매금액 반영 대상 및 opType 지정
        if (toSaleSuccess) {
          spendAffectOrderStatusById.put(newO.Id, ORDER_STATUS_SALE_SUCCESS); // 판매 등록 +
        } else if (toSaleDeleted) {
          spendAffectOrderStatusById.put(newO.Id, ORDER_STATUS_SALE_DELETED); // 판매 삭제 -
        } else if (toReturnSuccess) {
          spendAffectOrderStatusById.put(newO.Id, ORDER_STATUS_RETURN_SUCCESS); // 반품 등록 -
        } else if (toReturnDeleted) {
          spendAffectOrderStatusById.put(newO.Id, ORDER_STATUS_RETURN_DELETED); // 반품 삭제 +
        }
      }

      // 3년구매금액 업데이트
      if (!spendAffectOrderStatusById.isEmpty()) {
        updateTierQualifyingSpend3Y(spendAffectOrderStatusById);
      }

      if (mceTargetOrderIds.isEmpty() && spendAffectOrderStatusById.isEmpty()) {
        return;
      }

      logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, null, null);
      logger.logging(OrderTriggerHandler.class.getName());
      logger.setRequestDatetime(Datetime.now());
      logger.setStatus('START');
      logger.setDescription('Enqueue McePointService. targetOrderCnt=' + mceTargetOrderIds.size());

      // System.enqueueJob(new McePointService(new List<Id>(mceTargetOrderIds))); // todo: 실제 운영 시 주석 해제

      logger.setStatus('SUCCESS');
      logger.setDescription('McePointService enqueued. orderCnt=' + mceTargetOrderIds.size());
    } catch (Exception e) {
      if (logger != null) {
        try {
          logger.createExceptionLog(e);
        } catch (Exception ignore) {
          // 무시
        }
        logger.setStatus('ERROR');
        logger.setDescription('Exception in OrderTriggerHandler.afterUpdate');
      }
      throw e;
    } finally {
      if (logger != null) {
        logger.setResponseDatetime(Datetime.now());
        logger.addLog();
        ApexLogger.insertLogs();
      }
    }
  }

  /**
   * 3년 구매금액 업데이트
   * - 판매 등록: +구매금액 (2/1~12/31만)
   * - 판매 삭제: -구매금액 (2/1~12/31 + 1/1~1/7 허용)
   * - 반품 등록: -구매금액 (2/1~12/31 + 1/1~1/7 허용)
   * - 반품 삭제: +구매금액 (2/1~12/31 + 1/1~1/7 허용)
   */
  @TestVisible
  private static void updateTierQualifyingSpend3Y(Map<Id, String> orderStatusById) {
    if (orderStatusById == null || orderStatusById.isEmpty()) {
      return;
    }

    List<Order> oList = [
      SELECT Id, MemberNo__c, ActualPaymentAmount__c, EffectiveDate
      FROM Order
      WHERE Id IN :orderStatusById.keySet()
    ];
    if (oList.isEmpty()) {
      return;
    }

    Map<Id, Decimal> deltaByContactId = new Map<Id, Decimal>();

    for (Order o : oList) {
      String orderStatus = orderStatusById.get(o.Id);
      if (orderStatus == null) {
        continue;
      }

      if (o.MemberNo__c == null) {
        continue;
      }
      if (o.EffectiveDate == null) {
        continue;
      }

      // 날짜 조건(요구사항 반영)
      if (!isEligibleEffectiveDate(o.EffectiveDate, orderStatus)) {
        continue;
      }

      Decimal amt = (o.ActualPaymentAmount__c == null) ? 0 : o.ActualPaymentAmount__c;
      if (amt == 0) {
        continue;
      }

      Id contactId;
      try {
        contactId = (Id) o.MemberNo__c; // MemberNo__c가 Contact Id일 때만
      } catch (Exception ignore) {
        continue;
      }

      Decimal delta;
      if (orderStatus == ORDER_STATUS_SALE_SUCCESS) {
        delta = amt; // 판매 등록 +
      } else if (orderStatus == ORDER_STATUS_SALE_DELETED) {
        delta = -amt; // 판매 삭제 -
      } else if (orderStatus == ORDER_STATUS_RETURN_SUCCESS) {
        delta = -amt; // 반품 등록 -
      } else if (orderStatus == ORDER_STATUS_RETURN_DELETED) {
        delta = amt; // 반품 삭제 +
      } else {
        continue;
      }

      deltaByContactId.put(contactId, (deltaByContactId.containsKey(contactId) ? deltaByContactId.get(contactId) : 0) + delta);
    }

    if (deltaByContactId.isEmpty()) {
      return;
    }

    List<Contact> toUpdate = new List<Contact>();
    for (Contact c : [
      SELECT Id, TierQualifyingSpend3Y__c
      FROM Contact
      WHERE Id IN :deltaByContactId.keySet()
      FOR UPDATE
    ]) {
      Decimal cur = (c.TierQualifyingSpend3Y__c == null) ? 0 : c.TierQualifyingSpend3Y__c;
      Decimal next = cur + deltaByContactId.get(c.Id);
      c.TierQualifyingSpend3Y__c = (next < 0) ? 0 : next; // 음수 방지
      toUpdate.add(c);
    }

    if (!toUpdate.isEmpty()) {
      update toUpdate;
    }
  }

  /**
   * 날짜 허용 규칙(요구사항)
   * - 판매 등록만: 2/1~12/31 (1월 전부 불가)
   * - 판매 삭제/반품 등록/반품 삭제: 2/1~12/31 + 1/1~1/7 허용
   */
  private static Boolean isEligibleEffectiveDate(Date d, String orderStatus) {
    if (d == null) {
      return false;
    }

    // 2~12월은 전부 허용
    if (d.month() >= 2) {
      return true;
    }

    // 1월인 경우:
    // 판매 등록은 불가, 그 외(판매삭제/반품등록/반품삭제)만 1~7 허용
    if (d.month() == 1 && d.day() <= 7) {
      return ORDER_STATUS_SALE_SUCCESS.equals(orderStatus) ? false : true;
    }

    return false;
  }
}