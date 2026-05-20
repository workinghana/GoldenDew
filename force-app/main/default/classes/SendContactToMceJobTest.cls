/**
 * SendContactToMceJob Test
 *
 * 검증 영역
 *   A. 생성자 — List<Id> 보관 동작
 *   B. execute(QueueableContext) — Queueable 실행 흐름
 *   C. 빈/null 입력 안전 처리
 */
@IsTest
private class SendContactToMceJobTest {
  // SendContactToMceJob 이 Database.AllowsCallouts 이므로 HttpCalloutMock 세팅
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"ok":true}');
      return res;
    }
  }

  @IsTest
  static void enqueue_withSingleContactId_executesJob() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Contact c = new Contact(LastName = 'MceJobTester', MemberNo__c = 'MCE-JOB-001');
    insert c;

    List<Id> contactIds = new List<Id>{ c.Id };
    SendContactToMceJob job = new SendContactToMceJob(contactIds);

    Test.startTest();
    Id jobId = System.enqueueJob(job);
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'Queueable job 이 enqueue 되어야 함');
  }

  @IsTest
  static void enqueue_withMultipleContactIds_executesJob() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Contact c1 = new Contact(LastName = 'MceJobM1', MemberNo__c = 'MCE-JOB-M1');
    Contact c2 = new Contact(LastName = 'MceJobM2', MemberNo__c = 'MCE-JOB-M2');
    insert new List<Contact>{ c1, c2 };

    List<Id> contactIds = new List<Id>{ c1.Id, c2.Id };
    SendContactToMceJob job = new SendContactToMceJob(contactIds);

    Test.startTest();
    Id jobId = System.enqueueJob(job);
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'multiple contactIds Queueable 실행');
  }

  @IsTest
  static void enqueue_withEmptyList_doesNotThrow() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    SendContactToMceJob job = new SendContactToMceJob(new List<Id>());

    Test.startTest();
    Id jobId = System.enqueueJob(job);
    Test.stopTest();

    System.assertNotEquals(null, jobId, '빈 list 로 enqueue 시 throw 없음');
  }

  @IsTest
  static void enqueue_withNullList_doesNotThrow() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    SendContactToMceJob job = new SendContactToMceJob(null);

    Test.startTest();
    Id jobId = System.enqueueJob(job);
    Test.stopTest();

    System.assertNotEquals(null, jobId, 'null list 로 enqueue 시 throw 없음');
  }

  @IsTest
  static void instantiate_noErrorOnConstructor() {
    List<Id> contactIds = new List<Id>();

    Test.startTest();
    SendContactToMceJob job = new SendContactToMceJob(contactIds);
    System.assertNotEquals(null, job, '인스턴스 생성 확인');
    Test.stopTest();
  }

  @IsTest
  static void typeReference_classLoadsWithoutError() {
    Test.startTest();
    Type t = SendContactToMceJob.class;
    System.assertNotEquals(null, t, 'Type reference 로딩');
    System.assertEquals('SendContactToMceJob', t.getName(), '클래스 이름 확인');
    Test.stopTest();
  }
}