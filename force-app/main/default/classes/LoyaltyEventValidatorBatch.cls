/**
 * LoyaltyEventValidatorBatch
 *
 * 책임 — 최근 변경된 Order / TransactionJournal 을 스캔해서 이벤트 유형별로
 *        LoyaltyPointEventValidator 의 적절한 validateAndAlert 메서드를 호출.
 *
 *   자동 호출 hook 을 service 클래스에 삽입할 수 없는 제약 하에서, Schedulable +
 *   Batchable 패턴으로 주기적 사후 검증을 구현. 서비스 클래스 미수정.
 *
 * 처리 대상:
 *   - Order LastModifiedDate >= since (SALE_CREATE / SALE_DELETE / RETURN_CREATE / RETURN_DELETE)
 *   - TransactionJournal LastModifiedDate >= since AND IsDeleted__c=TRUE (DEPOSIT_DELETE)
 *
 * 호출 패턴:
 *   Database.executeBatch(new LoyaltyEventValidatorBatch(Datetime.now().addMinutes(-30)), 20);
 *
 * 주의:
 *   - 각 validateAndAlertXxx 는 invalid 시 Slack callout 발생. batch scope 20 으로
 *     callout 한도 (execute 당 100) 안전 마진 확보.
 *   - 같은 Order 가 매 cron 마다 재검증될 수 있음. 결과가 valid 면 alert 안 보내므로
 *     중복 alert 는 발생하지 않음 (멱등).
 */
public without sharing class LoyaltyEventValidatorBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
  public enum Phase { ORDERS, DEPOSITS }

  private final Datetime sinceDatetime;
  private final Phase batchPhase;
  private Integer orderProcessedCount = 0;
  private Integer depositProcessedCount = 0;
  private Integer alertSentCount = 0;
  private Integer errorCount = 0;

  public LoyaltyEventValidatorBatch(Datetime since) {
    this(since, Phase.ORDERS);
  }

  public LoyaltyEventValidatorBatch(Datetime since, Phase ph) {
    this.sinceDatetime = since == null ? Datetime.now().addHours(-1) : since;
    this.batchPhase = ph == null ? Phase.ORDERS : ph;
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    if (batchPhase == Phase.ORDERS) {
      return Database.getQueryLocator([
        SELECT Id, SaleNo__c, IsReductionOrder__c, IsDeleted__c, MemberNo__c
        FROM Order
        WHERE LastModifiedDate >= :sinceDatetime
          AND SaleNo__c != NULL
          AND MemberNo__c != NULL
        ORDER BY LastModifiedDate ASC
      ]);
    }
    return Database.getQueryLocator([
      SELECT Id, DepositNo__c, DeposiSeqNo__c, IsDeleted__c, MemberId
      FROM TransactionJournal
      WHERE LastModifiedDate >= :sinceDatetime
        AND IsDeleted__c = TRUE
      ORDER BY LastModifiedDate ASC
    ]);
  }

  public void execute(Database.BatchableContext bc, List<sObject> scope) {
    if (batchPhase == Phase.ORDERS) {
      processOrders((List<Order>) scope);
    } else {
      processDeposits((List<TransactionJournal>) scope);
    }
  }

  private void processOrders(List<Order> orders) {
    for (Order o : orders) {
      try {
        Boolean ok;
        if (o.IsDeleted__c == true) {
          ok = (o.IsReductionOrder__c == true)
            ? LoyaltyPointEventValidator.validateAndAlertReturnDelete(o.SaleNo__c)
            : LoyaltyPointEventValidator.validateAndAlertSaleDelete(o.SaleNo__c);
        } else if (o.IsReductionOrder__c == true) {
          ok = LoyaltyPointEventValidator.validateAndAlertReturnCreate(o.SaleNo__c);
        } else {
          ok = LoyaltyPointEventValidator.validateAndAlertSaleCreate(o.SaleNo__c);
        }
        orderProcessedCount++;
        if (ok == false) alertSentCount++;
      } catch (Exception e) {
        errorCount++;
        System.debug(LoggingLevel.ERROR,
          '[LoyaltyEventValidatorBatch] orderId=' + o.Id + ' err=' + e.getMessage());
      }
    }
  }

  private void processDeposits(List<TransactionJournal> tjs) {
    // 대상 TJ 의 OrderId / SaleId 를 보고 SALE / RETURN 분기 — 둘 다 시도
    // 우선 SALE 시도 후 RETURN 시도 (validator 가 동일 패턴 처리)
    Set<Id> tjIds = new Map<Id, TransactionJournal>(tjs).keySet();
    Map<Id, Id> orderIdByTjId = new Map<Id, Id>();
    Map<Id, Boolean> isReductionByTjId = new Map<Id, Boolean>();
    for (TransactionJournal tj : [
      SELECT Id, OrderId, SaleId__c, Order.IsReductionOrder__c
      FROM TransactionJournal
      WHERE Id IN :tjIds
    ]) {
      Id effOrderId = tj.OrderId;
      if (effOrderId == null && String.isNotBlank(tj.SaleId__c)) {
        try { effOrderId = (Id) tj.SaleId__c; } catch (Exception e) { effOrderId = null; }
      }
      orderIdByTjId.put(tj.Id, effOrderId);
      isReductionByTjId.put(tj.Id, tj.Order != null && tj.Order.IsReductionOrder__c == true);
    }

    for (TransactionJournal tj : tjs) {
      try {
        Boolean isReturn = isReductionByTjId.get(tj.Id) == true;
        Boolean ok = isReturn
          ? LoyaltyPointEventValidator.validateAndAlertReturnDepositDeleteByTjId(tj.Id)
          : LoyaltyPointEventValidator.validateAndAlertSaleDepositDeleteByTjId(tj.Id);
        depositProcessedCount++;
        if (ok == false) alertSentCount++;
      } catch (Exception e) {
        errorCount++;
        System.debug(LoggingLevel.ERROR,
          '[LoyaltyEventValidatorBatch] tjId=' + tj.Id + ' err=' + e.getMessage());
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(LoggingLevel.INFO,
      '[LoyaltyEventValidatorBatch] phase=' + batchPhase +
      ' orders=' + orderProcessedCount +
      ' deposits=' + depositProcessedCount +
      ' alerts=' + alertSentCount +
      ' errors=' + errorCount);
    // ORDERS 단계가 끝나면 DEPOSITS 단계 자동 chain
    if (batchPhase == Phase.ORDERS) {
      Database.executeBatch(new LoyaltyEventValidatorBatch(sinceDatetime, Phase.DEPOSITS), 20);
    }
  }
}