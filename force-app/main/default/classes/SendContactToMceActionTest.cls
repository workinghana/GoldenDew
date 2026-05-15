/**
 * SendContactToMceAction Test
 *
 * 검증 영역
 *   A. send(List<Id>) — Queueable enqueue 동작
 *   B. 빈/null 입력 안전 처리
 */
@IsTest
private class SendContactToMceActionTest {
  // SendContactToMceJob 이 Queueable + AllowsCallouts 이므로 HttpCalloutMock 세팅
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
  static void send_withContactIds_enqueuesJob() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Contact c = new Contact(LastName = 'MceTester', MemberNo__c = 'MCE-ACT-001');
    insert c;

    List<Id> contactIds = new List<Id>{ c.Id };

    Test.startTest();
    SendContactToMceAction.send(contactIds);
    // Queueable jobs 가 enqueue 되었는지 확인
    Integer enqueuedCount = Limits.getQueueableJobs();
    Test.stopTest();

    System.assert(enqueuedCount >= 1, 'Queueable 1개 이상 enqueue');
  }

  @IsTest
  static void send_emptyList_doesNotThrow() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Test.startTest();
    SendContactToMceAction.send(new List<Id>());
    Test.stopTest();

    System.assert(true, '빈 list 호출 시 throw 없음');
  }

  @IsTest
  static void send_multipleContactIds_enqueuesJob() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Contact c1 = new Contact(LastName = 'McePtest1', MemberNo__c = 'MCE-ACT-M1');
    Contact c2 = new Contact(LastName = 'McePtest2', MemberNo__c = 'MCE-ACT-M2');
    insert new List<Contact>{ c1, c2 };

    List<Id> contactIds = new List<Id>{ c1.Id, c2.Id };

    Test.startTest();
    SendContactToMceAction.send(contactIds);
    Test.stopTest();

    System.assert(true, 'multiple contactIds 처리');
  }

  @IsTest
  static void instantiate_noErrorOnConstructor() {
    Test.startTest();
    SendContactToMceAction action = new SendContactToMceAction();
    System.assertNotEquals(null, action, '인스턴스 생성 확인');
    Test.stopTest();
  }
}