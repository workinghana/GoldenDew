@IsTest
private class CommonApiAsyncTest {
  @IsTest
  static void construct_emptyClass_succeeds() {
    CommonApiAsync asyncInstance = new CommonApiAsync();

    System.assertNotEquals(null, asyncInstance, 'CommonApiAsync should be constructable.');
  }
}