@IsTest
private class DebugUtilTest {
  @IsTest
  static void test_pretty_object_normal_no_throw() {
    DebugUtil.forceSerializeError = false;
    DebugUtil.pretty(new Map<String, Object>{ 'a' => 1, 'b' => 'x' });
    System.assert(true);
  }

  @IsTest
  static void test_pretty_object_forced_serialize_error_caught() {
    DebugUtil.forceSerializeError = true;

    // serialize()에서 throw new Exception(...)이 나야 catch로 잡혀서 테스트 성공
    DebugUtil.pretty(new Map<String, Object>{ 'a' => 1 });

    DebugUtil.forceSerializeError = false;
    System.assert(true);
  }

  @IsTest
  static void test_pretty_label_object_normal_no_throw() {
    DebugUtil.pretty('LABEL', new Map<String, Object>{ 'k' => 'v' });
    System.assert(true);
  }

  @IsTest
  static void test_pretty_label_object_null_no_throw() {
    DebugUtil.pretty('LABEL_NULL', null);
    System.assert(true);
  }

  // =========================================================
  // serialize - 정상 객체 -> JSON 문자열 반환
  // =========================================================
  @IsTest
  static void test_serialize_normal_returns_json() {
    DebugUtil.forceSerializeError = false;
    Map<String, Object> input = new Map<String, Object>{ 'key' => 'value', 'num' => 42 };
    String result = DebugUtil.serialize(input);
    System.assertNotEquals(null, result, '결과가 null이면 안됨');
    System.assert(result.contains('key'), 'key 포함 여부: ' + result);
    System.assert(result.contains('value'), 'value 포함 여부: ' + result);
  }

  // =========================================================
  // serialize - null 입력 -> "null" 문자열 반환
  // =========================================================
  @IsTest
  static void test_serialize_null_returns_null_string() {
    DebugUtil.forceSerializeError = false;
    String result = DebugUtil.serialize(null);
    System.assertEquals('null', result, 'null 객체 직렬화 -> "null"');
  }

  // =========================================================
  // serialize - forceSerializeError=true -> exception throw 검증
  // =========================================================
  @IsTest
  static void test_serialize_forced_error_throws() {
    DebugUtil.forceSerializeError = true;
    Boolean threw = false;
    try {
      DebugUtil.serialize(new Map<String, Object>{ 'x' => 1 });
    } catch (IllegalArgumentException e) {
      threw = true;
      System.assertEquals('Forced serialize error', e.getMessage(), '에러 메시지 일치');
    } finally {
      DebugUtil.forceSerializeError = false;
    }
    System.assert(threw, 'forceSerializeError=true 시 IllegalArgumentException이 발생해야 함');
  }
}