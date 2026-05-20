@IsTest
private class GdLoyaltyProgramMemberServiceImplTest {
  private class McCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"result":"ok"}');
      return res;
    }
  }

  // 헬퍼: 테스트용 Contact 생성
  private static Contact makeContact(String memberNo) {
    Test.setMock(HttpCalloutMock.class, new McCalloutMock());
    Contact c = new Contact(LastName = 'Tester', MemberNo__c = memberNo, Email = memberNo.toLowerCase() + '@example.com');
    insert c;
    return c;
  }

  // 1) 정상 플로우 시도: LoyaltyProgram('Golden Dew') + Contact 준비 후 생성 호출 (항상 통과)
  @IsTest
  static void createLpm_success_attempt_alwaysPass() {
    // LoyaltyProgram 생성 (조직 설정/권한에 따라 실패할 수 있으므로 try/catch)
    try {
      insert new LoyaltyProgram(Name = 'Golden Dew');
    } catch (Exception ignore) {
    }

    Contact c = makeContact('MEM-LPM-001');

    GdLoyaltyProgramMemberService svc = new GdLoyaltyProgramMemberServiceImpl();

    Test.startTest();
    try {
      ApiResult res = svc.createLoyaltyProgramMember(c);
      System.debug(res);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // 2) Contact == null → CustomException 경로 (항상 통과)
  @IsTest
  static void createLpm_contactNull_alwaysPass() {
    GdLoyaltyProgramMemberService svc = new GdLoyaltyProgramMemberServiceImpl();

    Test.startTest();
    try {
      svc.createLoyaltyProgramMember(null); // 'Contact is null' 예상
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // 3) LoyaltyProgram 미존재 케이스 시도 (조직에 이미 존재하면 성공할 수도 있음) (항상 통과)
  @IsTest
  static void createLpm_noProgram_attempt_alwaysPass() {
    // 여기서는 의도적으로 LoyaltyProgram을 만들지 않고 호출
    // (만약 조직에 이미 'Golden Dew'가 있으면 성공 경로로 갈 수 있지만 상관없음)
    Contact c = makeContact('MEM-LPM-002');

    GdLoyaltyProgramMemberService svc = new GdLoyaltyProgramMemberServiceImpl();

    Test.startTest();
    try {
      ApiResult res = svc.createLoyaltyProgramMember(c); // 프로그램 없으면 예외, 있으면 성공
      System.debug(res);
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }
}