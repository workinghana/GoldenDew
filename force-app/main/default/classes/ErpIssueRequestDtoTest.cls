/**
 * ErpIssueRequestDto 테스트
 * - 클래스 본문이 전체 주석 처리된 상태이므로
 *   인스턴스 생성(기본 생성자)만으로 커버
 */
@IsTest
private class ErpIssueRequestDtoTest {

  @IsTest
  static void test_defaultConstructor() {
    Test.startTest();
    ErpIssueRequestDto dto = new ErpIssueRequestDto();
    Test.stopTest();

    System.assertNotEquals(null, dto, 'ErpIssueRequestDto 인스턴스 생성 성공');
  }
}