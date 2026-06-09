public with sharing class ExpiredVoucherDeleteScheduler implements Schedulable {
  public void execute(SchedulableContext sc) {
    Integer batchSize = 200;

    Database.executeBatch(new ExpiredVoucherDeleteBatch(), batchSize);
  }
}
