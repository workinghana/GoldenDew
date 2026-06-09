public with sharing class MemberDeleteScheduler implements Schedulable {
  public void execute(SchedulableContext sc) {
    Integer batchSize = 1;

    Database.executeBatch(new MemberDeleteBatch(), batchSize);
  }
}
