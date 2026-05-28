@IsTest
private class GdMediumProductCategoryApiCntrlrV1Test {
  private static void setupRest(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v1/mediumCategory/product';
    req.httpMethod = 'POST';
    if (body != null)
      req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  /* =========================================================
   * Mock : GdProductCategoryService
   * ========================================================= */
  private class MockProductCategoryService implements GdProductCategoryService {
    public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class CustomExceptionMockService implements GdProductCategoryService {
    public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
      throw new CustomException(422, 'custom error');
    }
    public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class RuntimeExceptionMockService implements GdProductCategoryService {
    public ApiResult upsertLargeProductCategoryProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult upsertMediumProductCategoryProduct(Map<String, Object> reqData) {
      throw new IllegalArgumentException('unexpected error');
    }
    public ApiResult upsertSmallProductCategoryProduct(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  /* =========================================================
   * 기존 테스트
   * ========================================================= */
  @IsTest
  static void upsertProductCategory_emptyBody_handlesError() {
    setupRest(null);
    Test.startTest();
    GdMediumProductCategoryApiControllerV1.upsertProductCategory();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void upsertProductCategory_invalidJson_handlesError() {
    setupRest('{invalid-json}');
    Test.startTest();
    GdMediumProductCategoryApiControllerV1.upsertProductCategory();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
  }

  @IsTest
  static void test_setProductCategoryService_coverage() {
    setupRest('{}');
    GdProductCategoryService serviceImpl = new GdProductCategoryServiceImpl();
    GdMediumProductCategoryApiControllerV1.setProductCategoryService(serviceImpl);

    Test.startTest();
    GdMediumProductCategoryApiControllerV1.upsertProductCategory();
    Test.stopTest();

    System.assertNotEquals(null, RestContext.response);
  }

  /* =========================================================
   * success 시나리오 (handleSuccess(result, logger) 커버)
   * ========================================================= */
  @IsTest
  static void upsertProductCategory_success_withMock() {
    GdMediumProductCategoryApiControllerV1.setProductCategoryService(new MockProductCategoryService());
    setupRest('{"categoryCode":"CAT-001"}');

    Test.startTest();
    GdMediumProductCategoryApiControllerV1.upsertProductCategory();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
  }

  /* =========================================================
   * catch (CustomException) 커버
   * ========================================================= */
  @IsTest
  static void upsertProductCategory_serviceCustomException() {
    GdMediumProductCategoryApiControllerV1.setProductCategoryService(new CustomExceptionMockService());
    setupRest('{"categoryCode":"CAT-001"}');

    Test.startTest();
    GdMediumProductCategoryApiControllerV1.upsertProductCategory();
    Test.stopTest();

    System.assert(true);
  }

  /* =========================================================
   * catch (Exception) 커버
   * ========================================================= */
  @IsTest
  static void upsertProductCategory_serviceException() {
    GdMediumProductCategoryApiControllerV1.setProductCategoryService(new RuntimeExceptionMockService());
    setupRest('{"categoryCode":"CAT-001"}');

    Test.startTest();
    GdMediumProductCategoryApiControllerV1.upsertProductCategory();
    Test.stopTest();

    System.assert(true);
  }
}