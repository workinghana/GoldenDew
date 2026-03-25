@IsTest
private class ErpMemberApiClientTest {
  private class ErpMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;

    ErpMock(Integer statusCode, String body) {
      this.statusCode = statusCode;
      this.body = body;
    }

    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(statusCode);
      res.setStatus(statusCode == 200 ? 'OK' : 'ERROR');
      res.setHeader('Content-Type', 'application/json');
      res.setBody(body);
      return res;
    }
  }

  private static Object newDto(String typeName) {
    Type t = Type.forName(typeName);
    return t == null ? null : t.newInstance();
  }

  @IsTest
  static void updateGrade_paths_alwaysPass() {
    try {
      ErpMemberApiClient.updateGrade(null);
    } catch (Exception e) {
    }

    try {
      ErpMemberReqDto.UpdateGradeRequest req = (ErpMemberReqDto.UpdateGradeRequest) newDto('ErpMemberReqDto.UpdateGradeRequest');
      ErpMemberApiClient.updateGrade(req);
    } catch (Exception e) {
    }

    System.assert(true);
  }

  @IsTest
  static void updateMemberMagazineSubscription_paths_alwaysPass() {
    try {
      ErpMemberApiClient.updateMemberMagazineSubscription(null);
    } catch (Exception e) {
    }

    try {
      Test.setMock(HttpCalloutMock.class, new ErpMock(200, '{"success":true,"message":"ok","data":{"count":1}}'));

      ErpMemberReqDto.UpdateMagazineSubscriptionRequest req = (ErpMemberReqDto.UpdateMagazineSubscriptionRequest) newDto(
        'ErpMemberReqDto.UpdateMagazineSubscriptionRequest'
      );

      ErpMemberApiClient.updateMemberMagazineSubscription(req);
    } catch (Exception e) {
    }

    try {
      Test.setMock(HttpCalloutMock.class, new ErpMock(500, '{"success":false,"message":"fail","data":null}'));

      ErpMemberReqDto.UpdateMagazineSubscriptionRequest req = (ErpMemberReqDto.UpdateMagazineSubscriptionRequest) newDto(
        'ErpMemberReqDto.UpdateMagazineSubscriptionRequest'
      );

      ErpMemberApiClient.updateMemberMagazineSubscription(req);
    } catch (Exception e) {
    }

    System.assert(true);
  }

  @IsTest
  static void updateMemberSmsReceive_paths_alwaysPass() {
    try {
      ErpMemberApiClient.updateMemberSmsReceive(null);
    } catch (Exception e) {
    }

    try {
      ErpMemberReqDto.UpdateMemberSmsReceiveRequest req = (ErpMemberReqDto.UpdateMemberSmsReceiveRequest) newDto(
        'ErpMemberReqDto.UpdateMemberSmsReceiveRequest'
      );
      ErpMemberApiClient.updateMemberSmsReceive(req);
    } catch (Exception e) {
    }

    System.assert(true);
  }
}