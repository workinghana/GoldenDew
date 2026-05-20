/**
 * MceEventResDto 테스트 클래스
 * HttpResponse 파싱 및 수동 실패 객체 생성 로직 검증
 */
@isTest
private class MceEventResDtoTest {
  @isTest
  static void testFromResponse_Success() {
    // 1. 성공 케이스 (200 OK)
    HttpResponse res = new HttpResponse();
    res.setStatusCode(200);
    res.setStatus('OK');
    res.setBody('{"status":"success"}');

    Test.startTest();
    MceEventResDto result = MceEventResDto.fromResponse(res);
    Test.stopTest();

    Assert.isTrue(result.success, '200번대 응답은 success가 true여야 합니다.');
    Assert.areEqual(200, result.statusCode);
    Assert.areEqual('OK', result.status);
  }

  @isTest
  static void testFromResponse_ErrorWithJson() {
    // 2. 에러 케이스 (400 Bad Request) + JSON 본문 파싱
    HttpResponse res = new HttpResponse();
    res.setStatusCode(400);
    res.setStatus('Bad Request');
    // errorCode, message 필드가 포함된 에러 JSON
    res.setBody('{"errorcode": "INVALID_KEY", "message": "The key is missing"}');

    Test.startTest();
    MceEventResDto result = MceEventResDto.fromResponse(res);
    Test.stopTest();

    Assert.isFalse(result.success);
    Assert.areEqual('INVALID_KEY', result.errorCode);
    Assert.areEqual('The key is missing', result.errorMessage);
  }

  @isTest
  static void testFromResponse_ErrorWithInvalidJson() {
    // 3. 에러 케이스 + 잘못된 JSON 형식 (catch 블록 커버)
    HttpResponse res = new HttpResponse();
    res.setStatusCode(500);
    res.setBody('{ invalid_json : }'); // JSON 파싱 에러 유발

    Test.startTest();
    MceEventResDto result = MceEventResDto.fromResponse(res);
    Test.stopTest();

    Assert.isFalse(result.success);
    Assert.isNull(result.errorCode, '파싱 실패 시 errorCode는 null이어야 합니다.');
  }

  @isTest
  static void testFromResponse_NonJsonBody() {
    // 4. 에러 케이스 + 일반 텍스트 본문 (startsWith('{') 분기 커버)
    HttpResponse res = new HttpResponse();
    res.setStatusCode(404);
    res.setBody('Not Found');

    Test.startTest();
    MceEventResDto result = MceEventResDto.fromResponse(res);
    Test.stopTest();

    Assert.isFalse(result.success);
    Assert.areEqual('Not Found', result.body);
  }

  @isTest
  static void testFailStaticMethod() {
    // 5. fail 정적 메서드 직접 호출 테스트
    Test.startTest();
    MceEventResDto result = MceEventResDto.fail(503, 'SERVICE_UNAVAILABLE', 'Server is down', 'Raw body content');
    Test.stopTest();

    Assert.isFalse(result.success);
    Assert.areEqual(503, result.statusCode);
    Assert.areEqual('SERVICE_UNAVAILABLE', result.errorCode);
    Assert.areEqual('Server is down', result.errorMessage);
    Assert.areEqual('Raw body content', result.body);
  }
}