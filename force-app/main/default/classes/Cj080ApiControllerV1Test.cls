@IsTest
private class Cj080ApiControllerV1Test {
  // =========================================================
  // Mock (Queueable 내부에서 callout이 발생할 경우 대비)
  // =========================================================
  private class ErpHttpMock implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{"result":"OK"}');
      return res;
    }
  }

  // =========================================================
  // Helpers: RestContext
  // =========================================================
  private static void setRestContextWithParams(String uNumber, String rNumber) {
    RestRequest req = new RestRequest();
    RestResponse res = new RestResponse();
    req.requestUri = '/services/apexrest/unsubscribe';
    req.httpMethod = 'GET';
    if (uNumber != null)
      req.addParameter('uNumber', uNumber);
    if (rNumber != null)
      req.addParameter('rNumber', rNumber);
    RestContext.request = req;
    RestContext.response = res;
  }

  private static String resBody() {
    return (RestContext.response == null || RestContext.response.responseBody == null) ? '' : RestContext.response.responseBody.toString();
  }

  // =========================================================
  // Helpers: Test Data
  // =========================================================
  private static Id makeStoreRegi(String storeCode) {
    // StoreRegi__c 는 Account Id 라는 전제
    Account acc = new Account();
    acc.Name = 'TEST_STORE_' + storeCode;

    // StoreCode__c 필드 존재할 때만 세팅 (안전)
    Map<String, Schema.SObjectField> aFields = Account.SObjectType.getDescribe().fields.getMap();
    if (aFields != null && aFields.containsKey('StoreCode__c')) {
      acc.put('StoreCode__c', storeCode);
    } else {
      // 만약 여기로 들어오면, 컨트롤러의 SOQL 필터(StoreRegi__r.StoreCode__c != null) 자체가
      // 현실 데이터에서도 항상 실패하게 되므로 메타 확인이 필요합니다.
      System.assert(false, 'Account.StoreCode__c 필드가 org에 없습니다. 컨트롤러 SOQL 조건을 만족시킬 수 없습니다.');
    }

    insert acc;
    return acc.Id;
  }

  private static Contact makeTargetContact(Boolean smsAgreed, String mobilePhone, String memberNo, String storeCode) {
    Id storeRegiId = makeStoreRegi(storeCode);

    Contact c = new Contact();
    c.LastName = 'Test';
    c.MobilePhone = mobilePhone;
    c.put('IsSMSAgreed__c', smsAgreed);
    c.put('MemberNo__c', memberNo);
    c.put('StoreRegi__c', storeRegiId); // ✅ Account Id 연결
    insert c;
    return c;
  }

  // =========================================================
  // 1) ✅ 업데이트 성공 경로 (cList not empty) -> 200 / IsSMSAgreed__c false
  // =========================================================
  @IsTest
  static void test_success_update_200() {
    // Queueable이 callout한다면 필요
    Test.setMock(HttpCalloutMock.class, new ErpHttpMock());

    // rNumber와 Contact.MobilePhone 이 "완전 동일"해야 함
    Contact c = makeTargetContact(true, '01012345678', '00005', 'AD004');

    setRestContextWithParams('0801111111', '01012345678');

    Test.startTest();
    Cj080ApiControllerV1.createUnsubscribe();
    Test.stopTest(); // enqueueJob 실행까지 커버

    System.assertEquals(200, RestContext.response.statusCode, '성공이면 200');
    System.assert(resBody().contains('OK'), 'body=' + resBody());

    Contact updated = [
      SELECT IsSMSAgreed__c
      FROM Contact
      WHERE Id = :c.Id
      LIMIT 1
    ];
    System.assertEquals(false, (Boolean) updated.get('IsSMSAgreed__c'), '수신동의 false로 업데이트되어야 함');
  }

  // =========================================================
  // 2) 대상 없음 -> 200 (no target)
  // =========================================================
  @IsTest
  static void test_no_target_200() {
    setRestContextWithParams('0802222222', '01099998888');
    Cj080ApiControllerV1.createUnsubscribe();
    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(resBody().toLowerCase().contains('no target') || resBody().toLowerCase().contains('ok'), 'body=' + resBody());
  }

  // =========================================================
  // 3) uNumber 누락 -> 400
  // =========================================================
  @IsTest
  static void test_missing_uNumber_400() {
    setRestContextWithParams(null, '01012345678');
    Cj080ApiControllerV1.createUnsubscribe();
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(resBody().contains('uNumber is required'), 'body=' + resBody());
  }

  // =========================================================
  // 4) rNumber 누락 -> 400
  // =========================================================
  @IsTest
  static void test_missing_rNumber_400() {
    setRestContextWithParams('0803333333', null);
    Cj080ApiControllerV1.createUnsubscribe();
    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(resBody().contains('rNumber is required'), 'body=' + resBody());
  }

  // =========================================================
  // 5) Exception catch(500) - request null로 NPE 유도
  // =========================================================
  @IsTest
  static void test_exception_500_request_null() {
    RestContext.request = null;
    RestContext.response = new RestResponse();

    Cj080ApiControllerV1.createUnsubscribe();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assert(resBody().contains('Internal Server Error'), 'body=' + resBody());
  }

  // =========================================================
  // 6) normalize010WithHyphen - 11자리 숫자 (하이픈 없음)
  // =========================================================
  @IsTest
  static void test_normalize_11digits_no_hyphen() {
    String result = Cj080ApiControllerV1.normalize010WithHyphen('01012345678');
    System.assertEquals('010-1234-5678', result, '11자리 숫자 -> 010-XXXX-XXXX');
  }

  // =========================================================
  // 7) normalize010WithHyphen - 11자리 (하이픈 포함 입력)
  // =========================================================
  @IsTest
  static void test_normalize_11digits_with_hyphen() {
    String result = Cj080ApiControllerV1.normalize010WithHyphen('010-1234-5678');
    System.assertEquals('010-1234-5678', result, '하이픈 포함 11자리 -> 010-XXXX-XXXX');
  }

  // =========================================================
  // 8) normalize010WithHyphen - 10자리 숫자 (010-XXX-XXXX 형태)
  // =========================================================
  @IsTest
  static void test_normalize_10digits() {
    String result = Cj080ApiControllerV1.normalize010WithHyphen('0101234567');
    System.assertEquals('010-123-4567', result, '10자리 숫자 -> 010-XXX-XXXX');
  }

  // =========================================================
  // 9) normalize010WithHyphen - blank/null 입력 -> null
  // =========================================================
  @IsTest
  static void test_normalize_blank_returns_null() {
    System.assertEquals(null, Cj080ApiControllerV1.normalize010WithHyphen(null), 'null -> null');
    System.assertEquals(null, Cj080ApiControllerV1.normalize010WithHyphen(''), '빈문자열 -> null');
    System.assertEquals(null, Cj080ApiControllerV1.normalize010WithHyphen('   '), '공백 -> null');
  }

  // =========================================================
  // 10) normalize010WithHyphen - 010 아닌 번호 -> null
  // =========================================================
  @IsTest
  static void test_normalize_non_010_returns_null() {
    System.assertEquals(null, Cj080ApiControllerV1.normalize010WithHyphen('01112345678'), '011 번호 -> null');
    System.assertEquals(null, Cj080ApiControllerV1.normalize010WithHyphen('01612345678'), '016 번호 -> null');
    System.assertEquals(null, Cj080ApiControllerV1.normalize010WithHyphen('0201234567'), '02 번호 -> null');
  }

  // =========================================================
  // 11) normalize010WithHyphen - 010이지만 길이 불일치 -> null
  // =========================================================
  @IsTest
  static void test_normalize_invalid_length_returns_null() {
    System.assertEquals(null, Cj080ApiControllerV1.normalize010WithHyphen('010123456'), '9자리 010 -> null');
    System.assertEquals(null, Cj080ApiControllerV1.normalize010WithHyphen('010123456789'), '12자리 010 -> null');
  }
}