trigger AggrPointExprLedgerChangeEventTrigger on LoyaltyAggrPointExprLedgerChangeEvent(after insert) {
  new AggrPointExprLedgerChangeEventTriHandler().run();
}
