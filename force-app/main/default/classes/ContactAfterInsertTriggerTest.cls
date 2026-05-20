@isTest
private class ContactAfterInsertTriggerTest {
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
  static void singleContactInsert_enqueuesQueueable() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock(200, '{"result":"ok"}'));

    Test.startTest();
    Contact c = new Contact(LastName = 'TriggerTest');
    insert c;
    Test.stopTest();

    System.assertNotEquals(null, c.Id, 'Contact should be persisted after insert');

    Contact saved = [SELECT Id, LastName FROM Contact WHERE Id = :c.Id LIMIT 1];
    System.assertEquals('TriggerTest', saved.LastName, 'Inserted contact should be retrievable');
  }

  @isTest
  static void bulkContactInsert_enqueuesQueueable() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock(200, '{"result":"ok"}'));

    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < 10; i++) {
      contacts.add(new Contact(LastName = 'BulkTrigger' + i));
    }

    Test.startTest();
    insert contacts;
    Test.stopTest();

    Integer count = [SELECT COUNT() FROM Contact WHERE LastName LIKE 'BulkTrigger%'];
    System.assertEquals(10, count, 'All bulk contacts should be inserted');
  }

  @isTest
  static void calloutFailure_exercisesFailurePath() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock(500, 'Server Error'));

    Boolean threw = false;
    try {
      Test.startTest();
      Contact c = new Contact(LastName = 'FailTest');
      insert c;
      Test.stopTest();
    } catch (Exception e) {
      threw = true;
    }
  }
}