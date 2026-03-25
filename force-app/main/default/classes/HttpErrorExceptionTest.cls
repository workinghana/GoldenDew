@IsTest
private class HttpErrorExceptionTest {
  @IsTest
  static void test_summary() {
    // given
    HttpErrorException ex = new HttpErrorException();
    ex.statusCode = 500;
    ex.method = 'POST';
    ex.endpoint = '/services/apexrest/unsubscribe';
    ex.responseBody = '{"error":"Internal Server Error"}';
    ex.responseHeaders = new Map<String, String>{ 'Content-Type' => 'application/json' };
    ex.requestUrl = 'https://example.my.salesforce.com/services/apexrest/unsubscribe';

    // when
    String s = ex.summary();

    // then
    System.assertNotEquals(null, s);
    System.assert(s.contains('HTTP ERROR'), 'summary prefix should exist');
    System.assert(s.contains('status=500'), 'statusCode should be in summary');
    System.assert(s.contains('method=POST'), 'method should be in summary');
    System.assert(s.contains('endpoint=/services/apexrest/unsubscribe'), 'endpoint should be in summary');
  }

  @IsTest
  static void test_summary_with_null_fields_does_not_throw() {
    // given: 일부 필드가 null이어도 summary()는 문자열 반환해야 함
    HttpErrorException ex = new HttpErrorException();
    ex.statusCode = null;
    ex.method = null;
    ex.endpoint = null;

    // when
    String s = ex.summary();

    // then
    System.assertNotEquals(null, s);
    // null이 문자열로 붙는지 여부는 구현상 "null"이 들어갈 수 있음. 핵심은 예외가 안 나는 것.
    System.assert(s.startsWith('HTTP ERROR'), 'summary should start with HTTP ERROR');
  }
}