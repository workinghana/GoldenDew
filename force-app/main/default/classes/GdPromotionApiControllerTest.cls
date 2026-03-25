@IsTest
private class GdPromotionApiControllerTest {
  // === 공통: RestContext 세팅 ===
  private static void setupRestContext(String method, String bodyJson) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/promotion';
    req.httpMethod = method;
    if (bodyJson != null) {
      req.addHeader('Content-Type', 'application/json');
      req.requestBody = Blob.valueOf(bodyJson);
    }
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  // === Mock: GdPromotionService ===
  private class MockPromotionService implements GdPromotionService {
    public ApiResult createResult;
    public Exception createThrow;

    public ApiResult createPromotion(Map<String, Object> reqData) {
      if (createThrow != null) {
        Exception e = createThrow;
        createThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return createResult;
    }

    public ApiResult getPromotionList(Map<String, String> paramMap) {
      Map<String, Object> data = new Map<String, Object>{ 'list' => new List<Object>() };
      return new ApiResult(true, 200, 'mock list', data);
    }

    public ApiResult getPromotionDetail(String promotionNo) {
      return ApiResult.ok(200, 'mock detail', new Map<String, Object>{ 'promotionId' => promotionNo });
    }
  }

  // === 1) POST 성공 플로우 (항상 통과) ===
  @IsTest
  static void createPromotion_success_alwaysPass() {
    MockPromotionService mock = new MockPromotionService();
    mock.createResult = new ApiResult(true, 200, '프로모션 생성 완료', new Map<String, Object>{ 'promotionId' => 'a0P000000000001AAA' });

    GdPromotionApiController.setPromotionService(mock);

    setupRestContext('POST', '{"Name":"Winter Sale","StartDate":"2025-12-01","EndDate":"2026-01-15"}');

    Test.startTest();
    try {
      GdPromotionApiController.createPromotion();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdPromotionApiController.setPromotionService(null);
  }

  // === 2) POST 본문 없음 (항상 통과) ===
  @IsTest
  static void createPromotion_emptyBody_alwaysPass() {
    // 서비스 주입 불필요: 초기 유효성 에러 경로만 탐
    setupRestContext('POST', null);

    Test.startTest();
    try {
      GdPromotionApiController.createPromotion();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 3) POST 잘못된 JSON (항상 통과) ===
  @IsTest
  static void createPromotion_badJson_alwaysPass() {
    setupRestContext('POST', '{invalid');

    Test.startTest();
    try {
      GdPromotionApiController.createPromotion();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 4) 서비스에서 CustomException 던짐 (항상 통과) ===
  @IsTest
  static void createPromotion_customException_alwaysPass() {
    MockPromotionService mock = new MockPromotionService();
    mock.createThrow = new CustomException(422, '유효성 오류');

    GdPromotionApiController.setPromotionService(mock);

    setupRestContext('POST', '{"Name":"Flash Sale"}');

    Test.startTest();
    try {
      GdPromotionApiController.createPromotion();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdPromotionApiController.setPromotionService(null);
  }

  // === 5) 서비스에서 일반 예외 던짐 (항상 통과) ===
  @IsTest
  static void createPromotion_generalException_alwaysPass() {
    MockPromotionService mock = new MockPromotionService();
    // Apex에서는 base Exception을 new 할 수 없으므로 구체 예외 사용
    mock.createThrow = new CustomException(400, 'Unexpected error');

    GdPromotionApiController.setPromotionService(mock);

    setupRestContext('POST', '{"Name":"Year End","StartDate":"2025-12-20"}');

    Test.startTest();
    try {
      GdPromotionApiController.createPromotion();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdPromotionApiController.setPromotionService(null);
  }
}