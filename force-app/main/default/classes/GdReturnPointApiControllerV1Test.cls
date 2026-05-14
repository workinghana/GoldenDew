/**
 * GdReturnPointApiControllerV1 Test
 *
 * 본 클래스는 모든 메서드가 주석 처리되어 있어 (GdPointDebitApiControllerV1 로 대체됨)
 * 실행 가능한 동작은 없음. 클래스 선언 자체에 대한 minimal coverage 만 확보.
 */
@IsTest
private class GdReturnPointApiControllerV1Test {
  @IsTest
  static void typeReference_classLoadsWithoutError() {
    Test.startTest();
    Type t = GdReturnPointApiControllerV1.class;
    System.assertNotEquals(null, t, 'Type reference 로딩');
    System.assertEquals('GdReturnPointApiControllerV1', t.getName(), '클래스 이름 확인');
    Test.stopTest();
  }

  @IsTest
  static void instantiate_noErrorOnConstructor() {
    Test.startTest();
    GdReturnPointApiControllerV1 controller = new GdReturnPointApiControllerV1();
    System.assertNotEquals(null, controller, '인스턴스 생성 확인');
    Test.stopTest();
  }
}