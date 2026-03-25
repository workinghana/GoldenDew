public with sharing class AggrPointExprLedgerChangeEventTriHandler extends TriggerHandler {
    //   private List<LoyaltyAggrPointExprLedgerChangeEvent> triggerNew;
    //   private List<LoyaltyAggrPointExprLedgerChangeEvent> triggerOld;
    //   private Map<Id, LoyaltyAggrPointExprLedgerChangeEvent> triggerMapNew;
    //   private Map<Id, LoyaltyAggrPointExprLedgerChangeEvent> triggerMapOld;

    public AggrPointExprLedgerChangeEventTriHandler() {
        // this.triggerOld = (List<LoyaltyAggrPointExprLedgerChangeEvent>) Trigger.old;
        // this.triggerNew = (List<LoyaltyAggrPointExprLedgerChangeEvent>) Trigger.new;
        // this.triggerMapNew = (Map<Id, LoyaltyAggrPointExprLedgerChangeEvent>) Trigger.newMap;
        // this.triggerMapOld = (Map<Id, LoyaltyAggrPointExprLedgerChangeEvent>) Trigger.oldMap;
    }

    public override void afterInsert() {
        System.debug('LoyaltyAggrPointExprLedgerChangeEvent 체인지 이벤트 테스트');
    }
}