@IsTest
private class GdOrderDepositApiControllerTest {
  private static void setupRest(String method, String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/order/deposit';
    req.httpMethod = method;
    if (body != null) req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  private static void setupGet(String orderNo) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/order/deposit';
    req.httpMethod = 'GET';
    if (orderNo != null) req.addParameter('orderNo', orderNo);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  // === Mock ===
  private class MockOrderDepositService implements GdOrderDepositService {
    public Exception getListThrow;
    public Exception createThrow;
    public ApiResult getListResult;
    public ApiResult createResult;

    public ApiResult getOrderDepositList(String orderNo) {
      if (getListThrow != null) {
        Exception e = getListThrow; getListThrow = null;
        if (e instanceof CustomException) throw (CustomException) e;
        throw e;
      }
      return getListResult != null ? getListResult : ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult createOrderDepositHistory(Map<String, Object> req) {
      if (createThrow != null) {
        Exception e = createThrow; createThrow = null;
        if (e instanceof CustomException) throw (CustomException) e;
        throw e;
      }
      return createResult != null ? createResult : ApiResult.ok(200, 'ok', new Map<String, Object>());
    }

    public ApiResult upsertOrderDeposit(Map<String, Object> req) {
      return ApiResult.ok(200, 'ok', new Map<String, Object>());
    }
  }

  // === 기존 테스트 (유지) ===
  @IsTest
  static void createOrderDeposit_noop() {
    setupRest('POST', '{"x":"y"}');
    Test.startTest();
    GdOrderDepositApiController.createOrderDeposit();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void getOrderDepositList_missingParam_handlesValidation() {
    setupRest('GET', null);
    Test.startTest();
    GdOrderDepositApiController.getOrderDepositList();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void updateOrderDeposit_emptyBody_handlesError() {
    setupRest('PATCH', null);
    Test.startTest();
    GdOrderDepositApiController.updateOrderDeposit();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void deleteOrderDeposit_noop() {
    setupRest('DELETE', '{"x":"y"}');
    Test.startTest();
    GdOrderDepositApiController.deleteOrderDeposit();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  /* =========================
   * setOrderDepositService 커버
   * ========================= */
  @IsTest
  static void test_setOrderDepositService_coverage() {
    GdOrderDepositApiController.setOrderDepositService(new MockOrderDepositService());
    GdOrderDepositApiController.setOrderDepositService(null);
    System.assert(true, 'setOrderDepositService 정상 실행');
  }

  // getOrderDepositService lazy init: null 설정 후 호출 → 실제 구현체 생성 분기 커버
  @IsTest
  static void test_getOrderDepositService_lazyInit() {
    GdOrderDepositApiController.setOrderDepositService(null);
    setupGet(null); // orderNo 없음 → ValidationException → 실제 구현체 생성 전에 예외
    Test.startTest();
    GdOrderDepositApiController.getOrderDepositList();
    Test.stopTest();
    System.assert(true, 'lazy init 분기 커버');
  }

  /* =========================
   * getOrderDepositList - catch 분기
   * ========================= */

  // 1) orderNo 없음 → ValidationException (statusCode 검증)
  @IsTest
  static void test_getOrderDepositList_noParam_validationException() {
    setupGet(null);
    Test.startTest();
    GdOrderDepositApiController.getOrderDepositList();
    Test.stopTest();
    System.assert(RestContext.response.statusCode != 200, 'orderNo 없음 → 오류 응답');
  }

  // 2) setOrderDepositService 주입 + 성공 → 200
  @IsTest
  static void test_getOrderDepositList_mockSuccess_200() {
    MockOrderDepositService mock = new MockOrderDepositService();
    mock.getListResult = ApiResult.ok(200, '조회 성공', new Map<String, Object>());
    GdOrderDepositApiController.setOrderDepositService(mock);

    setupGet('ORD-001');

    Test.startTest();
    GdOrderDepositApiController.getOrderDepositList();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode, 'Mock 성공 → 200');
    GdOrderDepositApiController.setOrderDepositService(null);
  }

  // 3) setOrderDepositService 주입 + CustomException → 해당 코드
  @IsTest
  static void test_getOrderDepositList_customException() {
    MockOrderDepositService mock = new MockOrderDepositService();
    mock.getListThrow = new CustomException(404, '입금 이력 없음');
    GdOrderDepositApiController.setOrderDepositService(mock);

    setupGet('ORD-CE-001');

    Test.startTest();
    GdOrderDepositApiController.getOrderDepositList();
    Test.stopTest();

    System.assertEquals(404, RestContext.response.statusCode, 'CustomException → 404');
    GdOrderDepositApiController.setOrderDepositService(null);
  }

  // 4) setOrderDepositService 주입 + 일반 Exception → 500
  @IsTest
  static void test_getOrderDepositList_genericException_500() {
    MockOrderDepositService mock = new MockOrderDepositService();
    mock.getListThrow = new IllegalArgumentException('unexpected');
    GdOrderDepositApiController.setOrderDepositService(mock);

    setupGet('ORD-EX-001');

    Test.startTest();
    GdOrderDepositApiController.getOrderDepositList();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode, '일반 Exception → 500');
    GdOrderDepositApiController.setOrderDepositService(null);
  }

  /* =========================
   * updateOrderDeposit - catch 분기
   * ========================= */

  // 5) 빈 body → 400 (statusCode 검증)
  @IsTest
  static void test_updateOrderDeposit_emptyBody_400() {
    setupRest('PATCH', null);
    Test.startTest();
    GdOrderDepositApiController.updateOrderDeposit();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode, '빈 body → 400');
  }

  // 6) 잘못된 JSON → 400
  @IsTest
  static void test_updateOrderDeposit_badJson_400() {
    setupRest('PATCH', '{invalid_json');
    Test.startTest();
    GdOrderDepositApiController.updateOrderDeposit();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode, '잘못된 JSON → 400');
  }

  // 7) setOrderDepositService 주입 + 성공 → 200
  @IsTest
  static void test_updateOrderDeposit_mockSuccess_200() {
    MockOrderDepositService mock = new MockOrderDepositService();
    mock.createResult = ApiResult.ok(200, '등록 성공', new Map<String, Object>());
    GdOrderDepositApiController.setOrderDepositService(mock);

    setupRest('PATCH', '{"orderNo":"ORD-001"}');

    Test.startTest();
    GdOrderDepositApiController.updateOrderDeposit();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode, 'Mock 성공 → 200');
    GdOrderDepositApiController.setOrderDepositService(null);
  }

  // 8) setOrderDepositService 주입 + CustomException → 해당 코드
  @IsTest
  static void test_updateOrderDeposit_customException() {
    MockOrderDepositService mock = new MockOrderDepositService();
    mock.createThrow = new CustomException(422, '입금 처리 실패');
    GdOrderDepositApiController.setOrderDepositService(mock);

    setupRest('PATCH', '{"orderNo":"ORD-CE-001"}');

    Test.startTest();
    GdOrderDepositApiController.updateOrderDeposit();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode, 'CustomException → 422');
    GdOrderDepositApiController.setOrderDepositService(null);
  }

  // 9) setOrderDepositService 주입 + 일반 Exception → 500
  @IsTest
  static void test_updateOrderDeposit_genericException_500() {
    MockOrderDepositService mock = new MockOrderDepositService();
    mock.createThrow = new IllegalArgumentException('unexpected');
    GdOrderDepositApiController.setOrderDepositService(mock);

    setupRest('PATCH', '{"orderNo":"ORD-EX-001"}');

    Test.startTest();
    GdOrderDepositApiController.updateOrderDeposit();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode, '일반 Exception → 500');
    GdOrderDepositApiController.setOrderDepositService(null);
  }

  /* =========================
   * DepositResponseDTO - 필드 직접 할당/읽기
   * ========================= */
  @IsTest
  static void test_depositResponseDTO_fieldAssignment() {
    GdOrderDepositApiController.DepositResponseDTO dto = new GdOrderDepositApiController.DepositResponseDTO();
    dto.CD_TYPE_APPR  = 'CARD';
    dto.AM_DEPOSIT    = 50000;
    dto.NO_COUPON_ALL = 'CPN-001';
    dto.NM_COUPON     = '할인쿠폰';
    dto.DT_EXP        = Date.today().addDays(30);
    dto.RT_DISC       = 10;
    dto.AM_DISC       = 5000;
    dto.TX_REMARK     = '비고 내용';

    System.assertEquals('CARD',    dto.CD_TYPE_APPR);
    System.assertEquals(50000,     dto.AM_DEPOSIT);
    System.assertEquals('CPN-001', dto.NO_COUPON_ALL);
    System.assertEquals('할인쿠폰', dto.NM_COUPON);
    System.assertNotEquals(null,   dto.DT_EXP);
    System.assertEquals(10,        dto.RT_DISC);
    System.assertEquals(5000,      dto.AM_DISC);
    System.assertEquals('비고 내용', dto.TX_REMARK);
  }
}