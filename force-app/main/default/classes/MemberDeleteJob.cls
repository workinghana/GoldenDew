public with sharing class MemberDeleteJob {
  public static void register() {
    System.schedule('MemberDeleteSchedulerJob', '0 0 0 * * ?', new MemberDeleteScheduler());
  }
}