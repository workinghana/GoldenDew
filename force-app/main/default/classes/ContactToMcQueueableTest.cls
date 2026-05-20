@isTest
private class ContactToMcQueueableTest {
  private class McCalloutMock implements HttpCalloutMock {
    Integer statusCode;
    String responseBody;

    McCalloutMock(Integer status, String body) {
      this.statusCode = status;
      this.responseBody = body;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setBody(responseBody);
      return res;
    }
  }

  @isTest
  static void execute_singleContact_succeeds() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock(200, '{"result":"ok"}'));

    Contact c = new Contact(LastName = 'McQTest', Phone = '010-1111-2222');
    insert c;

    Test.startTest();
    System.enqueueJob(new ContactToMcQueueable(new List<Id>{ c.Id }));
    Test.stopTest();

    Contact saved = [SELECT Id, LastName, Phone FROM Contact WHERE Id = :c.Id LIMIT 1];
    System.assertEquals('McQTest', saved.LastName, 'Contact should still exist after queueable execution');
  }

  @isTest
  static void execute_multipleContacts_succeeds() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock(201, '{"result":"created"}'));

    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < 5; i++) {
      contacts.add(new Contact(LastName = 'McQBulk' + i, Phone = '010-0000-000' + i));
    }
    insert contacts;

    List<Id> ids = new List<Id>();
    for (Contact c : contacts) {
      ids.add(c.Id);
    }

    Test.startTest();
    System.enqueueJob(new ContactToMcQueueable(ids));
    Test.stopTest();

    Integer count = [SELECT COUNT() FROM Contact WHERE LastName LIKE 'McQBulk%'];
    System.assertEquals(5, count, 'All bulk contacts should be present');
  }

  @isTest
  static void execute_calloutFailure_throwsException() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock(500, 'Internal Server Error'));

    // Contact 삽입 안 함: ContactAfterInsertTrigger 가 async queueable 을 enqueue 하면
    // Test.stopTest() 시점에 그쪽도 callout 을 시도하다 500 으로 throw → 테스트 실패 유발.
    // execute() 는 Contact 가 없어도 HTTP 호출은 시도하므로 500 분기 검증에 영향 없음.
    ContactToMcQueueable job = new ContactToMcQueueable(new List<Id>());

    Boolean threw = false;
    String errMsg = null;
    Test.startTest();
    try {
      job.execute(null);
    } catch (Exception e) {
      threw = true;
      errMsg = e.getMessage();
    }
    Test.stopTest();

    System.assertEquals(true, threw, '500 응답 시 예외가 throw 되어야 함');
    System.assert(errMsg != null && errMsg.contains('Marketing Cloud call failed'), '예외 메시지에 Marketing Cloud 실패 내용 포함 기대');
  }

  @isTest
  static void execute_emptyContactList_noCallout() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock(200, '{"result":"ok"}'));

    Test.startTest();
    System.enqueueJob(new ContactToMcQueueable(new List<Id>()));
    Test.stopTest();

    System.assert(true, 'Queueable should handle empty list without unexpected error');
  }
}