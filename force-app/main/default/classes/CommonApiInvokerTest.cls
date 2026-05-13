@IsTest
private class CommonApiInvokerTest {
  @IsTest
  static void construct_emptyClass_succeeds() {
    CommonApiInvoker invoker = new CommonApiInvoker();

    System.assertNotEquals(null, invoker, 'CommonApiInvoker should be constructable.');
  }
}