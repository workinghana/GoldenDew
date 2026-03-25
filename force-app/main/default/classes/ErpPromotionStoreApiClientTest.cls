@IsTest
private class ErpPromotionStoreApiClientTest {
  @TestSetup
  static void setupOnce() {
    CommonApiClient.setTokenRefresher(new CommonApiClientTestTokenRefresher());
  }

  @IsTest
  static void test_createPromotionStore_success() {
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    ErpPromotionStoreReqDto.CreateRequestList req = new ErpPromotionStoreReqDto.CreateRequestList();
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.CreateRequest('1000', 'PROM001', 'S001', 'Gangnam', 'tester'));
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.CreateRequest('1000', 'PROM001', 'S002', 'Jamsil', 'tester'));

    Test.startTest();
    ErpApiResponseDto result = ErpPromotionStoreApiClient.createPromotionStore(req);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertNotEquals(null, result.info);
    System.assertEquals(200, result.info.statusCode);
  }

  @IsTest
  static void test_updatePromotionStore_success() {
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    ErpPromotionStoreReqDto.UpdateRequestList req = new ErpPromotionStoreReqDto.UpdateRequestList();
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.UpdateRequest('1000', 'PROM002', 'S002', 'Myeongdong', 'updater'));

    Test.startTest();
    ErpApiResponseDto result = ErpPromotionStoreApiClient.updatePromotionStore(req);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertNotEquals(null, result.info);
    System.assertEquals(200, result.info.statusCode);
  }

  @IsTest
  static void test_deletePromotionStore_success() {
    CommonApiClientUniversalMock.reset();
    Test.setMock(HttpCalloutMock.class, new CommonApiClientUniversalMock());

    ErpPromotionStoreReqDto.DeleteRequestList req = new ErpPromotionStoreReqDto.DeleteRequestList();
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.DeleteRequest('PROM003', 'S003', 'deleter'));
    req.promotionStoreList.add(new ErpPromotionStoreReqDto.DeleteRequest('PROM003', 'S004', 'deleter'));

    Test.startTest();
    ErpApiResponseDto result = ErpPromotionStoreApiClient.deletePromotionStore(req);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertNotEquals(null, result.info);
    System.assertEquals(200, result.info.statusCode);
  }

  @IsTest
  static void test_createPromotionStore_nullRequest_throws() {
    Test.startTest();
    try {
      ErpPromotionStoreApiClient.createPromotionStore(null);
      System.assert(false);
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('Request body is required.'));
    }
    Test.stopTest();
  }

  @IsTest
  static void test_updatePromotionStore_nullRequest_throws() {
    Test.startTest();
    try {
      ErpPromotionStoreApiClient.updatePromotionStore(null);
      System.assert(false);
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('Request body is required.'));
    }
    Test.stopTest();
  }

  @IsTest
  static void test_deletePromotionStore_nullRequest_throws() {
    Test.startTest();
    try {
      ErpPromotionStoreApiClient.deletePromotionStore(null);
      System.assert(false);
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('Request body is required.'));
    }
    Test.stopTest();
  }
}
