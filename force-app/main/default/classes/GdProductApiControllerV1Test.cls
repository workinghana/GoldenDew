@IsTest
private class GdProductApiControllerV1Test {
  private class MockProductServiceSuccess implements GdProductService {
    public ApiResult createProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'OK', new Map<String, Object>{ 'productId' => 'P-001' });
    }
    public ApiResult updateProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'OK', new Map<String, Object>{ 'productId' => 'P-001' });
    }
    public ApiResult getProductByPromotion(String promotionNo) {
      return null;
    }
  }

  private class MockProductServiceCustomError implements GdProductService {
    public ApiResult createProduct(Map<String, Object> reqData) {
      throw new CustomException(422, 'PRODUCT CUSTOM ERROR');
    }
    public ApiResult updateProduct(Map<String, Object> reqData) {
      throw new CustomException(422, 'PRODUCT CUSTOM ERROR');
    }
    public ApiResult getProductByPromotion(String promotionNo) {
      return null;
    }
  }

  private class MockProductServiceRuntimeError implements GdProductService {
    public ApiResult createProduct(Map<String, Object> reqData) {
      String forcedNull;
      forcedNull.length();
      return null;
    }
    public ApiResult updateProduct(Map<String, Object> reqData) {
      String forcedNull;
      forcedNull.length();
      return null;
    }
    public ApiResult getProductByPromotion(String promotionNo) {
      return null;
    }
  }

  private class MockPricebookEntryServiceSuccess implements GdPricebookEntryService {
    public ApiResult createPricebookEntryByProduct2(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'OK', null);
    }
    public ApiResult updatePricebookEntryByProduct2(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'OK', null);
    }
  }

  private class MockPricebookEntryServiceCustomError implements GdPricebookEntryService {
    public ApiResult createPricebookEntryByProduct2(Map<String, Object> reqData) {
      throw new CustomException(409, 'PBE CUSTOM ERROR');
    }
    public ApiResult updatePricebookEntryByProduct2(Map<String, Object> reqData) {
      throw new CustomException(409, 'PBE CUSTOM ERROR');
    }
  }

  private class MockPricebookEntryServiceRuntimeError implements GdPricebookEntryService {
    public ApiResult createPricebookEntryByProduct2(Map<String, Object> reqData) {
      String forcedNull;
      forcedNull.length();
      return null;
    }
    public ApiResult updatePricebookEntryByProduct2(Map<String, Object> reqData) {
      String forcedNull;
      forcedNull.length();
      return null;
    }
  }

  private static void setupRest(String method, String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v1/product';
    req.httpMethod = method;
    if (body != null) req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @IsTest
  static void createProduct_emptyBody_handlesError() {
    GdProductApiControllerV1.setProductService(new MockProductServiceSuccess());
    GdProductApiControllerV1.setPricebookEntryService(new MockPricebookEntryServiceSuccess());
    setupRest('POST', null);
    Test.startTest();
    GdProductApiControllerV1.createProduct();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode);
    GdProductApiControllerV1.setProductService(null);
    GdProductApiControllerV1.setPricebookEntryService(null);
  }

  @IsTest
  static void updateProduct_invalidJson_handlesError() {
    GdProductApiControllerV1.setProductService(new MockProductServiceSuccess());
    GdProductApiControllerV1.setPricebookEntryService(new MockPricebookEntryServiceSuccess());
    setupRest('PATCH', '{invalid-json}');
    Test.startTest();
    GdProductApiControllerV1.updateProduct();
    Test.stopTest();
    System.assertEquals(500, RestContext.response.statusCode);
    GdProductApiControllerV1.setProductService(null);
    GdProductApiControllerV1.setPricebookEntryService(null);
  }

  @IsTest
  static void createProduct_success() {
    GdProductApiControllerV1.setProductService(new MockProductServiceSuccess());
    GdProductApiControllerV1.setPricebookEntryService(new MockPricebookEntryServiceSuccess());
    setupRest('POST', '{"productCode":"SKU-001","name":"Test"}');

    Test.startTest();
    GdProductApiControllerV1.createProduct();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('"success" : true'));
    GdProductApiControllerV1.setProductService(null);
    GdProductApiControllerV1.setPricebookEntryService(null);
  }

  @IsTest
  static void createProduct_productCustomException() {
    GdProductApiControllerV1.setProductService(new MockProductServiceCustomError());
    GdProductApiControllerV1.setPricebookEntryService(new MockPricebookEntryServiceSuccess());
    setupRest('POST', '{"productCode":"SKU-001","name":"Test"}');

    Test.startTest();
    GdProductApiControllerV1.createProduct();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('PRODUCT CUSTOM ERROR'));
    GdProductApiControllerV1.setProductService(null);
    GdProductApiControllerV1.setPricebookEntryService(null);
  }

  @IsTest
  static void createProduct_pricebookRuntimeException() {
    GdProductApiControllerV1.setProductService(new MockProductServiceSuccess());
    GdProductApiControllerV1.setPricebookEntryService(new MockPricebookEntryServiceRuntimeError());
    setupRest('POST', '{"productCode":"SKU-001","name":"Test"}');

    Test.startTest();
    GdProductApiControllerV1.createProduct();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertNotEquals(null, RestContext.response.responseBody);
    GdProductApiControllerV1.setProductService(null);
    GdProductApiControllerV1.setPricebookEntryService(null);
  }

  @IsTest
  static void updateProduct_success() {
    GdProductApiControllerV1.setProductService(new MockProductServiceSuccess());
    GdProductApiControllerV1.setPricebookEntryService(new MockPricebookEntryServiceSuccess());
    setupRest('PATCH', '{"productId":"P-001","name":"Updated"}');

    Test.startTest();
    GdProductApiControllerV1.updateProduct();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('"success" : true'));
    GdProductApiControllerV1.setProductService(null);
    GdProductApiControllerV1.setPricebookEntryService(null);
  }

  @IsTest
  static void updateProduct_pricebookCustomException() {
    GdProductApiControllerV1.setProductService(new MockProductServiceSuccess());
    GdProductApiControllerV1.setPricebookEntryService(new MockPricebookEntryServiceCustomError());
    setupRest('PATCH', '{"productId":"P-001","name":"Updated"}');

    Test.startTest();
    GdProductApiControllerV1.updateProduct();
    Test.stopTest();

    System.assertEquals(409, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('PBE CUSTOM ERROR'));
    GdProductApiControllerV1.setProductService(null);
    GdProductApiControllerV1.setPricebookEntryService(null);
  }

  @IsTest
  static void updateProduct_productRuntimeException() {
    GdProductApiControllerV1.setProductService(new MockProductServiceRuntimeError());
    GdProductApiControllerV1.setPricebookEntryService(new MockPricebookEntryServiceSuccess());
    setupRest('PATCH', '{"productId":"P-001","name":"Updated"}');

    Test.startTest();
    GdProductApiControllerV1.updateProduct();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertNotEquals(null, RestContext.response.responseBody);
    GdProductApiControllerV1.setProductService(null);
    GdProductApiControllerV1.setPricebookEntryService(null);
  }
}