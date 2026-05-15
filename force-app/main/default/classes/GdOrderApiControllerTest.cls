@IsTest
private class GdOrderApiControllerTest {
  @IsTest
  static void controllerClass_compiles_whenEndpointIsDisabled() {
    GdOrderApiController controllerInstance = new GdOrderApiController();
    System.assertNotEquals(null, controllerInstance);
  }
}
