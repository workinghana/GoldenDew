@IsTest
private class LoyaltyMemberServiceImplTest {
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
  static void test_createIndividualMember_contactNull() {
    LoyaltyMemberServiceImpl service = new LoyaltyMemberServiceImpl();

    Test.startTest();
    ApiResult result = service.createIndividualMemberByContact(null);
    Test.stopTest();

    System.assertEquals(400, result.code);
    System.assertEquals('Contact is null', result.message);
  }

  @IsTest
  static void test_createIndividualMember_contactProvided() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Contact c = new Contact(LastName = 'TestUser', MemberNo__c = 'M-10001', Email = 'test@example.com');
    insert c;

    LoyaltyMemberServiceImpl service = new LoyaltyMemberServiceImpl();

    Test.startTest();
    ApiResult result = service.createIndividualMemberByContact(c);
    Test.stopTest();

    System.assertEquals(500, result.code);
  }
}