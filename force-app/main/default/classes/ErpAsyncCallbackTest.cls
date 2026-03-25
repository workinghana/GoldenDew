/**
 * ErpAsyncCallback 인터페이스 테스트
 * - 구현체를 통해 모든 메서드 시그니처 커버
 */
@IsTest
private class ErpAsyncCallbackTest {

  /* =====================================================
   * ErpAsyncCallback 구현체 (모든 오버로드 구현)
   * ===================================================== */
  private class TestCallbackImpl implements ErpAsyncCallback {
    public String lastMethod;
    public String lastApiName;
    public String lastError;

    public void onSuccess(String apiName, Object requestDto, ErpApiResponseDto responseDto) {
      lastMethod  = 'onSuccess';
      lastApiName = apiName;
    }

    public void onFailure(String apiName, Object requestDto, String errorMessage, String stackTrace) {
      lastMethod = 'onFailure_msg_stack';
      lastError  = errorMessage;
    }

    public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId) {
      lastMethod = 'onFailure_httpErr_id';
    }

    public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Id recordId, SObject o) {
      lastMethod = 'onFailure_httpErr_id_obj';
    }

    public void onFailure(String apiName, Object requestDto, String errorMessage, Id recordId) {
      lastMethod = 'onFailure_msg_id';
      lastError  = errorMessage;
    }

    public void onFailure(String apiName, Object requestDto, HttpErrorException httpError, Set<Id> recordIds) {
      lastMethod = 'onFailure_httpErr_ids';
    }

    public void onFailure(String apiName, Object requestDto, Exception error, Set<Id> recordIds) {
      lastMethod = 'onFailure_exc_ids';
    }

    public void onFailure(String apiName, Object requestDto, Exception error, Id recordId) {
      lastMethod = 'onFailure_exc_id';
    }
  }

  /* =====================================================
   * 인터페이스 할당 확인
   * ===================================================== */
  @IsTest
  static void test_interfaceAssignment() {
    ErpAsyncCallback cb = new TestCallbackImpl();
    System.assertNotEquals(null, cb, 'ErpAsyncCallback 구현체 생성');
  }

  /* =====================================================
   * onSuccess
   * ===================================================== */
  @IsTest
  static void test_onSuccess() {
    TestCallbackImpl cb = new TestCallbackImpl();
    ErpApiResponseDto resp = new ErpApiResponseDto();
    resp.success = true;
    resp.message = 'OK';

    cb.onSuccess('testApi', null, resp);

    System.assertEquals('onSuccess', cb.lastMethod);
    System.assertEquals('testApi',   cb.lastApiName);
  }

  /* =====================================================
   * onFailure(apiName, req, String errorMessage, String stackTrace)
   * ===================================================== */
  @IsTest
  static void test_onFailure_message_stackTrace() {
    TestCallbackImpl cb = new TestCallbackImpl();
    cb.onFailure('testApi', null, 'error msg', 'stack trace here');

    System.assertEquals('onFailure_msg_stack', cb.lastMethod);
    System.assertEquals('error msg',           cb.lastError);
  }

  /* =====================================================
   * onFailure(apiName, req, HttpErrorException, Id recordId)
   * ===================================================== */
  @IsTest
  static void test_onFailure_httpError_recordId() {
    TestCallbackImpl cb  = new TestCallbackImpl();
    HttpErrorException ex = new HttpErrorException();
    ex.statusCode         = 500;
    ex.responseBody       = 'Internal Server Error';

    cb.onFailure('testApi', null, ex, (Id) null);

    System.assertEquals('onFailure_httpErr_id', cb.lastMethod);
  }

  /* =====================================================
   * onFailure(apiName, req, HttpErrorException, Id recordId, SObject o)
   * ===================================================== */
  @IsTest
  static void test_onFailure_httpError_recordId_sObject() {
    TestCallbackImpl cb  = new TestCallbackImpl();
    HttpErrorException ex = new HttpErrorException();
    ex.statusCode         = 400;
    Account acc = new Account(Name = 'TestAcc');

    cb.onFailure('testApi', null, ex, (Id) null, acc);

    System.assertEquals('onFailure_httpErr_id_obj', cb.lastMethod);
  }

  /* =====================================================
   * onFailure(apiName, req, String errorMessage, Id recordId)
   * ===================================================== */
  @IsTest
  static void test_onFailure_message_recordId() {
    TestCallbackImpl cb = new TestCallbackImpl();
    cb.onFailure('testApi', null, 'some error', (Id) null);

    System.assertEquals('onFailure_msg_id', cb.lastMethod);
    System.assertEquals('some error',       cb.lastError);
  }

  /* =====================================================
   * onFailure(apiName, req, HttpErrorException, Set<Id> recordIds)
   * ===================================================== */
  @IsTest
  static void test_onFailure_httpError_setIds() {
    TestCallbackImpl cb  = new TestCallbackImpl();
    HttpErrorException ex = new HttpErrorException();
    ex.statusCode         = 503;

    cb.onFailure('testApi', null, ex, new Set<Id>());

    System.assertEquals('onFailure_httpErr_ids', cb.lastMethod);
  }

  /* =====================================================
   * onFailure(apiName, req, Exception error, Set<Id> recordIds)
   * ===================================================== */
  @IsTest
  static void test_onFailure_exception_setIds() {
    TestCallbackImpl cb = new TestCallbackImpl();
    Exception ex = new IllegalArgumentException('test exception');

    cb.onFailure('testApi', null, ex, new Set<Id>());

    System.assertEquals('onFailure_exc_ids', cb.lastMethod);
  }

  /* =====================================================
   * onFailure(apiName, req, Exception error, Id recordId)
   * ===================================================== */
  @IsTest
  static void test_onFailure_exception_recordId() {
    TestCallbackImpl cb = new TestCallbackImpl();
    Exception ex = new IllegalArgumentException('test exception');

    cb.onFailure('testApi', null, ex, (Id) null);

    System.assertEquals('onFailure_exc_id', cb.lastMethod);
  }

  /* =====================================================
   * HttpErrorException - summary() 메서드 커버
   * ===================================================== */
  @IsTest
  static void test_httpErrorException_summary() {
    HttpErrorException ex = new HttpErrorException();
    ex.statusCode   = 404;
    ex.method       = 'GET';
    ex.endpoint     = '/test/path';
    ex.responseBody = 'Not Found';

    String s = ex.summary();

    System.assert(s.contains('404'),   'statusCode in summary');
    System.assert(s.contains('GET'),   'method in summary');
    System.assert(s.contains('/test'), 'endpoint in summary');
  }
}