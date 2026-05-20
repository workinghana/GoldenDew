@IsTest
private class GdContactTriggerTest {
  private class McCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"result":"ok"}');
      return res;
    }
  }

  @IsTest
  static void beforeUpdate_firesWithoutError() {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock());

    Contact c = new Contact(LastName = 'TriggerTest');
    insert c;

    Test.startTest();
    c.LastName = 'TriggerTestUpdated';
    update c;
    Test.stopTest();

    Contact updated = [SELECT LastName FROM Contact WHERE Id = :c.Id LIMIT 1];
    System.assertEquals('TriggerTestUpdated', updated.LastName);
  }
}