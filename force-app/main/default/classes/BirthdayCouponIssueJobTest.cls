@IsTest
private class BirthdayCouponIssueJobTest {
  @IsTest
  static void test_execute() {
    Test.startTest();
    new BirthdayCouponIssueJob().execute(null);
    Test.stopTest();

    System.assert(true);
  }
}