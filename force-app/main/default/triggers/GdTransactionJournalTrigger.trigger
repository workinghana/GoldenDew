trigger GdTransactionJournalTrigger on TransactionJournal(after update) {
  GdTransactionJournalTriggerHandler handler = new GdTransactionJournalTriggerHandler();

  System.debug('트리거 발동');
  handler.run();
}