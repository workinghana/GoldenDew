public without sharing class OrderTriggerHandler extends TriggerHandler {
  private static final String ORDER_STATUS_SALE_SUCCESS = 'saleSuccess'; // 판매 성공
  private static final String ORDER_STATUS_SALE_DELETED = 'saleDeleted'; // 판매 삭제
  private static final String ORDER_STATUS_RETURN_SUCCESS = 'returnSuccess'; // 반품 성공
  private static final String ORDER_STATUS_RETURN_DELETED = 'returnDeleted'; // 반품 삭제
  private static final String ORDER_STATUS_ORDER_SUCCESS = 'orderSuccess'; // 주문 성공

  public OrderTriggerHandler() {
    System.debug('OrderTriggerHandler count');
    this.setMaxLoopCount(3);
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

      // 🆕 골든듀 모니터링용 - 활동유형별 Contact ID 집합
      Map<String, Set<Id>> monitoringContactIdsByType = new Map<String, Set<Id>>{
        'Order' => new Set<Id>(),
        'Sale' => new Set<Id>(),
        'SaleDelete' => new Set<Id>(),
        'ReturnCreate' => new Set<Id>(),
        'ReturnDelete' => new Set<Id>()
      };

      // 🆕 모니터링 대상 존재 여부 플래그 (성능: 매번 Map 순회 안 하도록)
      Boolean hasMonitoringTarget = false;

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

        // 🆕 골든듀 모니터링 대상 분류 (SOQL 없이 메모리만)
        if (newO.MemberNo__c != null) {
          if (toOrderSuccess) {
            monitoringContactIdsByType.get('Order').add(newO.MemberNo__c);
            hasMonitoringTarget = true;
          }
          if (toSaleSuccess || toSaleDeleted) {
            monitoringContactIdsByType.get(toSaleSuccess ? 'Sale' : 'SaleDelete').add(newO.MemberNo__c);
            hasMonitoringTarget = true;
          }
          if (toReturnSuccess || toReturnDeleted) {
            monitoringContactIdsByType.get(toReturnSuccess ? 'ReturnCreate' : 'ReturnDelete').add(newO.MemberNo__c);
            hasMonitoringTarget = true;
          }
        }
      }

      // 3년구매금액 업데이트
      if (!spendAffectOrderStatusById.isEmpty()) {
        updateTierQualifyingSpend3Y(spendAffectOrderStatusById);
      }

      // 🆕 모니터링 대상이 있을 때만 @future 호출
      if (hasMonitoringTarget) {
        enqueueMonitoring(monitoringContactIdsByType);
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

    // 기존 로직
    // List<Order> oList = [
    //   SELECT Id, MemberNo__c, ActualPaymentAmount__c, EffectiveDate
    //   FROM Order
    //   WHERE Id IN :orderStatusById.keySet()
    // ];

    // 신규 로직 - 고재성
    List<OrderItem> oList = [
      SELECT
        OrderId,
        Order.MemberNo__c,
        NetSalesUnitPrice__c,
        OriginalOrderItemId__r.NetSalesUnitPrice__c, // 반품 상태일 때 가져올 원거래의 NetSalesUnitPrice
        Order.EffectiveDate
      FROM OrderItem
      WHERE
        OrderId IN :orderStatusById.keySet()
        AND (Order.StoreCode__r.StoreType__c IN ('11', '40')
        OR Order.StoreCode__r.StoreTypeFour__c = '01')
        AND Order.Status IN ('saleSuccess', 'saleDeleted', 'returnSuccess', 'returnDeleted')
        AND Product2Id NOT IN (
          SELECT ProductId
          FROM ProductCategoryProduct
          WHERE ProductCategory.Name = '골드바'
        )
        AND (NOT Product2.Name LIKE '%수선%')
        AND (NOT Product2.Name LIKE '%각인%')
        AND (NOT Product2.Name LIKE '%위약금%')
        AND (NOT Product2.Name LIKE '%재감비%')
        AND (NOT Product2.Name LIKE '%재인쇄비%')
      ALL ROWS
    ];

    if (oList.isEmpty()) {
      return;
    }

    Map<Id, Decimal> deltaByContactId = new Map<Id, Decimal>();

    // 기존 로직
    // for (Order o : oList) {
    //   String orderStatus = orderStatusById.get(o.Id);
    //   if (orderStatus == null) {
    //     continue;
    //   }

    //   if (o.MemberNo__c == null) {
    //     continue;
    //   }
    //   if (o.EffectiveDate == null) {
    //     continue;
    //   }

    //   // 날짜 조건(요구사항 반영)
    //   if (!isEligibleEffectiveDate(o.EffectiveDate, orderStatus)) {
    //     continue;
    //   }

    //   Decimal amt = (o.ActualPaymentAmount__c == null) ? 0 : o.ActualPaymentAmount__c;
    //   if (amt == 0) {
    //     continue;
    //   }

    //   Id contactId;
    //   try {
    //     contactId = (Id) o.MemberNo__c; // MemberNo__c가 Contact Id일 때만
    //   } catch (Exception ignore) {
    //     continue;
    //   }

    // 신규 로직 - 고재성
    for (OrderItem o : oList) {
      String orderStatus = orderStatusById.get(o.OrderId);
      if (orderStatus == null) {
        continue;
      }

      if (o.Order.MemberNo__c == null) {
        continue;
      }
      if (o.Order.EffectiveDate == null) {
        continue;
      }

      // 날짜 조건(요구사항 반영)
      if (!isEligibleEffectiveDate(o.Order.EffectiveDate, orderStatus)) {
        continue;
      }

      // 기존 로직
      // Decimal amt = (o.NetSalesUnitPrice__c == null) ? 0 : o.NetSalesUnitPrice__c;
      // if (amt == 0) {
      //   continue;
      // }

      // 신규 로직 - 상태에 따라 참조할 금액(amt) 분기 처리
      Decimal amt = 0;
      if (orderStatus == ORDER_STATUS_SALE_SUCCESS || orderStatus == ORDER_STATUS_SALE_DELETED) {
        amt = (o.NetSalesUnitPrice__c == null) ? 0 : o.NetSalesUnitPrice__c;
      } else if (orderStatus == ORDER_STATUS_RETURN_SUCCESS || orderStatus == ORDER_STATUS_RETURN_DELETED) {
        // 반품의 경우 원거래(OriginalOrderItem)의 금액을 참조
        amt = (o.OriginalOrderItemId__c != null &&
          o.OriginalOrderItemId__r.NetSalesUnitPrice__c != null)
          ? o.OriginalOrderItemId__r.NetSalesUnitPrice__c
          : 0;
      }

      if (amt == 0) {
        continue;
      }

      Id contactId;
      try {
        contactId = (Id) o.Order.MemberNo__c; // MemberNo__c가 Contact Id일 때만
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
      // FOR UPDATE
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

  /**
   * 🆕 골든듀 모니터링 비동기 호출
   * - 호출 전에 호출자에서 빈 여부 확인 필수
   * - 빈 Set은 자체적으로도 한 번 더 거름 (이중 안전장치)
   */
  private static void enqueueMonitoring(Map<String, Set<Id>> contactIdsByType) {
    try {
      // 빈 Set은 제외하고 직렬화 (페이로드 최소화)
      Map<String, List<Id>> serializable = new Map<String, List<Id>>();
      for (String type : contactIdsByType.keySet()) {
        Set<Id> ids = contactIdsByType.get(type);
        if (ids != null && !ids.isEmpty()) {
          serializable.put(type, new List<Id>(ids));
        }
      }

      // 모든 활동유형이 비었다면 호출 안 함 (이중 안전장치)
      if (serializable.isEmpty()) {
        return;
      }

      String payloadJson = JSON.serialize(serializable);
      LoyaltyActivityCounter.processMonitoringAsync(payloadJson);
    } catch (Exception e) {
      // 모니터링 실패는 절대 throw 하지 않음 (주문 트랜잭션 보호)
      System.debug(LoggingLevel.ERROR, '[골든듀 모니터링] enqueue 실패: ' + e.getMessage());
    }
  }
}