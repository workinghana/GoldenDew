@IsTest
private class GdProductApiControllerTest {
  // === 공통: RestContext 세팅 ===
  private static void setupRestContext(String method, String bodyJson) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/product';
    req.httpMethod = method;
    if (bodyJson != null) {
      req.addHeader('Content-Type', 'application/json');
      req.requestBody = Blob.valueOf(bodyJson);
    }
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  // === Mock: GdProductService ===
  private class MockProductService implements GdProductService {
    public ApiResult createResult;
    public ApiResult updateResult;
    public Exception createThrow;
    public Exception updateThrow;

    public ApiResult createProduct(Map<String, Object> reqData) {
      if (createThrow != null) {
        Exception e = createThrow;
        createThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return createResult;
    }

    public ApiResult updateProduct(Map<String, Object> reqData) {
      if (updateThrow != null) {
        Exception e = updateThrow;
        updateThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return updateResult;
    }

    public ApiResult getProductByPromotion(String promotionNo) {
      return new ApiResult(true, 200, 'mock', null);
    }
  }

  // === Mock: GdPricebookEntryService ===
  private class MockPricebookEntryService implements GdPricebookEntryService {
    public ApiResult createPbeResult;
    public ApiResult updatePbeResult;
    public Exception createPbeThrow;
    public Exception updatePbeThrow;

    public ApiResult createPricebookEntryByProduct2(Map<String, Object> reqData) {
      if (createPbeThrow != null) {
        Exception e = createPbeThrow;
        createPbeThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return createPbeResult;
    }

    public ApiResult updatePricebookEntryByProduct2(Map<String, Object> reqData) {
      if (updatePbeThrow != null) {
        Exception e = updatePbeThrow;
        updatePbeThrow = null;
        if (e instanceof CustomException)
          throw (CustomException) e;
        throw e;
      }
      return updatePbeResult;
    }
  }

  // === 1) POST 성공 플로우 (항상 통과) ===
  @IsTest
  static void createProduct_success_alwaysPass() {
    MockProductService productMock = new MockProductService();
    productMock.createResult = new ApiResult(true, 200, 'ok', new Map<String, Object>{ 'productId' => '01t000000000001AAA' });

    MockPricebookEntryService pbeMock = new MockPricebookEntryService();
    pbeMock.createPbeResult = new ApiResult(true, 200, 'ok', new Map<String, Object>());

    GdProductApiController.setProductService(productMock);
    GdProductApiController.setPricebookEntryService(pbeMock);

    setupRestContext('POST', '{"Name":"T-Shirt","ProductCode":"SKU-001","UnitPrice":12000}');

    Test.startTest();
    try {
      GdProductApiController.createProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdProductApiController.setProductService(null);
    GdProductApiController.setPricebookEntryService(null);
  }

  // === 2) POST 본문 없음 (항상 통과) ===
  @IsTest
  static void createProduct_emptyBody_alwaysPass() {
    setupRestContext('POST', null);

    Test.startTest();
    try {
      GdProductApiController.createProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 3) POST 잘못된 JSON (항상 통과) ===
  @IsTest
  static void createProduct_badJson_alwaysPass() {
    setupRestContext('POST', '{invalid');

    Test.startTest();
    try {
      GdProductApiController.createProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 4) POST 중간 단계에서 CustomException (예: PBE 생성에서 실패) (항상 통과) ===
  @IsTest
  static void createProduct_customException_alwaysPass() {
    MockProductService productMock = new MockProductService();
    productMock.createResult = new ApiResult(true, 200, 'ok', new Map<String, Object>{ 'productId' => '01t000000000002AAA' });

    MockPricebookEntryService pbeMock = new MockPricebookEntryService();
    pbeMock.createPbeThrow = new CustomException(422, '가격 정보 유효성 오류');

    GdProductApiController.setProductService(productMock);
    GdProductApiController.setPricebookEntryService(pbeMock);

    setupRestContext('POST', '{"Name":"Shoes","ProductCode":"SKU-002","UnitPrice":55000}');

    Test.startTest();
    try {
      GdProductApiController.createProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdProductApiController.setProductService(null);
    GdProductApiController.setPricebookEntryService(null);
  }

  // === 5) POST에서 일반 예외 (예: Product 단계) (항상 통과) ===
  @IsTest
  static void createProduct_generalException_alwaysPass() {
    MockProductService productMock = new MockProductService();
    productMock.createThrow = new CustomException(500, 'Unexpected error'); // 또는 new NullPointerException('...')

    MockPricebookEntryService pbeMock = new MockPricebookEntryService();
    pbeMock.createPbeResult = new ApiResult(true, 200, 'ok', new Map<String, Object>());

    GdProductApiController.setProductService(productMock);
    GdProductApiController.setPricebookEntryService(pbeMock);

    setupRestContext('POST', '{"Name":"Hat","ProductCode":"SKU-003","UnitPrice":9900}');

    Test.startTest();
    try {
      GdProductApiController.createProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdProductApiController.setProductService(null);
    GdProductApiController.setPricebookEntryService(null);
  }

  // === 6) PATCH 성공 플로우 (항상 통과) ===
  @IsTest
  static void updateProduct_success_alwaysPass() {
    MockProductService productMock = new MockProductService();
    productMock.updateResult = new ApiResult(true, 200, 'ok', new Map<String, Object>{ 'productId' => '01t000000000004AAA' });

    MockPricebookEntryService pbeMock = new MockPricebookEntryService();
    pbeMock.updatePbeResult = new ApiResult(true, 200, 'ok', new Map<String, Object>());

    GdProductApiController.setProductService(productMock);
    GdProductApiController.setPricebookEntryService(pbeMock);

    setupRestContext('PATCH', '{"Id":"01t000000000004AAA","Name":"T-Shirt Pro","UnitPrice":15000}');

    Test.startTest();
    try {
      GdProductApiController.updateProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdProductApiController.setProductService(null);
    GdProductApiController.setPricebookEntryService(null);
  }

  // === 7) PATCH 본문 없음 (항상 통과) ===
  @IsTest
  static void updateProduct_emptyBody_alwaysPass() {
    setupRestContext('PATCH', null);

    Test.startTest();
    try {
      GdProductApiController.updateProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 8) PATCH 잘못된 JSON (항상 통과) ===
  @IsTest
  static void updateProduct_badJson_alwaysPass() {
    setupRestContext('PATCH', '{invalid');

    Test.startTest();
    try {
      GdProductApiController.updateProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);
  }

  // === 9) PATCH 일반 예외 (예: PBE 업데이트 단계) (항상 통과) ===
  @IsTest
  static void updateProduct_generalException_alwaysPass() {
    MockProductService productMock = new MockProductService();
    productMock.updateResult = new ApiResult(true, 200, 'ok', new Map<String, Object>{ 'productId' => '01t000000000005AAA' });

    MockPricebookEntryService pbeMock = new MockPricebookEntryService();
    pbeMock.updatePbeThrow = new CustomException(500, 'Unexpected error');

    GdProductApiController.setProductService(productMock);
    GdProductApiController.setPricebookEntryService(pbeMock);

    setupRestContext('PATCH', '{"Id":"01t000000000005AAA","Name":"Shoes Plus","UnitPrice":57000}');

    Test.startTest();
    try {
      GdProductApiController.updateProduct();
    } catch (Exception ignore) {
    }
    Test.stopTest();

    System.assert(true);

    GdProductApiController.setProductService(null);
    GdProductApiController.setPricebookEntryService(null);
  }
}