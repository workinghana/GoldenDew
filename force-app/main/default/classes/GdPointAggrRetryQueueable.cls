public with sharing class GdPointAggrRetryQueueable implements Queueable {
  private List<Id> transactionJournalIds;

  public GdPointAggrRetryQueueable(List<Id> transactionJournalIds) {
    this.transactionJournalIds = transactionJournalIds == null ? new List<Id>() : transactionJournalIds;
  }

  public void execute(QueueableContext context) {
    if (transactionJournalIds == null || transactionJournalIds.isEmpty()) {
      return;
    }

    GdTransactionJournalTriggerHandler.aggregateProcessedTransactionJournals(new Set<Id>(transactionJournalIds));
  }
}