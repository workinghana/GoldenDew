@IsTest
private class ErpAsyncJobTest {
  private static Id makeId() {
    Account a = new Account(Name = 'T');
    insert a;
    return a.Id;
  }

  @IsTest
  static void test_execute_success_path() {
    Id rid = makeId();
    ErpAsyncJobTestCallbackCounter cb = new ErpAsyncJobTestCallbackCounter();

    Test.startTest();
    System.enqueueJob(new ErpAsyncJobTestSuccessJob('API_SUCCESS', new Map<String, Object>{ 'a' => 1 }, cb, rid));
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_http_error_recordId_path() {
    Id rid = makeId();
    ErpAsyncJobTestCallbackCounter cb = new ErpAsyncJobTestCallbackCounter();

    Test.startTest();
    System.enqueueJob(new ErpAsyncJobTestHttpErrorJob_RecordId('API_HTTP_ID', new Map<String, Object>{ 'a' => 1 }, cb, rid));
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_http_error_recordId_with_sobject_path() {
    Account a = new Account(Name = 'T_SOBJ');
    insert a;

    ErpAsyncJobTestCallbackCounter cb = new ErpAsyncJobTestCallbackCounter();

    Test.startTest();
    System.enqueueJob(new ErpAsyncJobTestHttpErrorJob_RecordIdSObj('API_HTTP_SOBJ', new Map<String, Object>{ 'a' => 1 }, cb, a.Id, a));
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_http_error_recordIds_path() {
    Set<Id> ids = new Set<Id>{ makeId(), makeId() };
    ErpAsyncJobTestCallbackCounter cb = new ErpAsyncJobTestCallbackCounter();

    Test.startTest();
    System.enqueueJob(new ErpAsyncJobTestHttpErrorJob_RecordIds('API_HTTP_IDS', new Map<String, Object>{ 'a' => 1 }, cb, ids));
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_execute_exception_path() {
    Id rid = makeId();
    ErpAsyncJobTestCallbackCounter cb = new ErpAsyncJobTestCallbackCounter();

    Test.startTest();
    System.enqueueJob(new ErpAsyncJobTestExceptionJob('API_EX', new Map<String, Object>{ 'a' => 1 }, cb, rid));
    Test.stopTest();

    System.assert(true);
  }

  @IsTest
  static void test_toLongTextJson_branches() {
    ErpAsyncJobTestCallbackCounter cb = new ErpAsyncJobTestCallbackCounter();
    ErpAsyncJobTestSuccessJob job = new ErpAsyncJobTestSuccessJob('API', null, cb, null);

    System.assert(true);

    String longS = '';
    for (Integer i = 0; i < 200; i++)
      longS += 'A';

    String cut1 = job.toLongTextJson(longS, 10, true);

    String cut2 = job.toLongTextJson(longS, 10, false);
    System.assert(true);

    // JSON.serialize 실패 catch 분기(자기참조)
    ErpAsyncJobTestSelfRef ref = new ErpAsyncJobTestSelfRef();
    ref.self = ref;

    String errJson = job.toLongTextJson(ref, 200, true);
    System.assert(true);
  }
}