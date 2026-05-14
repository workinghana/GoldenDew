@IsTest
private class GdPointRefreshBatchTest {
  @IsTest
  static void run_withEmptyMembers_finishesWithoutWork() {
    Test.startTest();
    Id jobId = GdPointRefreshBatch.run(new List<String>(), Date.newInstance(2026, 5, 18));
    Test.stopTest();

    System.assertNotEquals(null, jobId);
  }
}