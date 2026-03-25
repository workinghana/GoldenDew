@IsTest
private class ErpMemberAsyncCallbackTest {
  @IsTest
  static void test_extractMessage_blank_returns_null() {
    String msg = ErpMemberAsyncCallback.extractMessage(null);
    System.assertEquals(null, msg);

    msg = ErpMemberAsyncCallback.extractMessage('');
    System.assertEquals(null, msg);

    msg = ErpMemberAsyncCallback.extractMessage('   ');
    System.assertEquals(null, msg);
  }

  @IsTest
  static void test_extractMessage_valid_json_with_message() {
    String body = '{"success":false,"message":"INVALID_MEMBER","data":null}';
    String msg = ErpMemberAsyncCallback.extractMessage(body);
    System.assertEquals('INVALID_MEMBER', msg);
  }

  @IsTest
  static void test_extractMessage_valid_json_without_message_returns_original() {
    String body = '{"success":false,"data":{"a":1}}';
    String msg = ErpMemberAsyncCallback.extractMessage(body);
    System.assertEquals(body, msg);
  }

  @IsTest
  static void test_extractMessage_non_json_returns_original() {
    String body = 'NOT_JSON_TEXT';
    String msg = ErpMemberAsyncCallback.extractMessage(body);
    System.assertEquals(body, msg);
  }

  @IsTest
  static void test_onSuccess_and_onFailure_no_throw() {
    // 현재 구현은 비어있으므로 "예외 없이 호출 가능"만 검증
    ErpMemberAsyncCallback cb = new ErpMemberAsyncCallback();

    cb.onSuccess('ANY', null, null);

    cb.onFailure('ANY', null, (HttpErrorException) null, (Id) null);
    cb.onFailure('ANY', null, (HttpErrorException) null, (Id) null, (SObject) null);

    cb.onFailure('ANY', null, 'err', 'stack');
    cb.onFailure('ANY', null, 'err', (Id) null);

    cb.onFailure('ANY', null, (HttpErrorException) null, new Set<Id>());
    cb.onFailure('ANY', null, (Exception) null, new Set<Id>());
    cb.onFailure('ANY', null, (Exception) null, (Id) null);

    System.assert(true);
  }
}