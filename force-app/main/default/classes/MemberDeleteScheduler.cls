public with sharing class MemberDeleteScheduler implements Schedulable {
  public void execute(SchedulableContext sc) {
    Integer batchSize = 200;

    Database.executeBatch(new MemberDeleteBatch(), batchSize);
  }
}