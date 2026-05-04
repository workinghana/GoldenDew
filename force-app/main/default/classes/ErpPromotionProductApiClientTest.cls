@IsTest
private class ErpPromotionProductApiClientTest {
  private static String lastEndpoint;

  private class MockHttpSuccess implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      ErpPromotionProductApiClientTest.lastEndpoint = req.getEndpoint();
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"OK","data":null}');
      return res;
    }
  }

  @IsTest
  static void test_createPromotionProduct_nullReq_throwsIAE() {
    try {
      ErpPromotionProductApiClient.createPromotionProduct(null);
      System.assert(false, 'Expected exception');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('required'), e.getMessage());
    }
  }

  @IsTest
  static void test_updatePromotionProduct_nullReq_throwsIAE() {
    try {
      ErpPromotionProductApiClient.updatePromotionProduct(null);
      System.assert(false, 'Expected exception');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('required'), e.getMessage());
    }
  }

  @IsTest
  static void test_deletePromotionProduct_nullReq_throwsIAE() {
    try {
      ErpPromotionProductApiClient.deletePromotionProduct(null);
      System.assert(false, 'Expected exception');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('required'), e.getMessage());
    }
  }

  @IsTest
  static void test_createPromotionProduct_success() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    ErpPromotionProductReqDto.CreateRequestList req = new ErpPromotionProductReqDto.CreateRequestList();
    ErpPromotionProductReqDto.PromotionItem item = new ErpPromotionProductReqDto.PromotionItem();
    item.no_prom = 'PROM-001';
    item.cd_item = 'ITEM-001';
    item.id_insert = 'tester';
    item.id_update = 'tester';
    req.promotionItemList.add(item);

    Test.startTest();
    ErpApiResponseDto res = ErpPromotionProductApiClient.createPromotionProduct(req);
    Test.stopTest();

    System.assertNotEquals(null, res, 'Response DTO should be returned.');
    System.assertEquals(true, res.success, 'success = true');
    System.assertEquals('OK', res.message, 'message = OK');
  }

  @IsTest
  static void test_createPromotionProduct_missingIdUpdate_throwsIAE() {
    ErpPromotionProductReqDto.CreateRequestList req = new ErpPromotionProductReqDto.CreateRequestList();
    ErpPromotionProductReqDto.PromotionItem item = new ErpPromotionProductReqDto.PromotionItem();
    item.no_prom = 'PROM-001';
    item.cd_item = 'ITEM-001';
    item.id_insert = 'tester';
    req.promotionItemList.add(item);

    try {
      ErpPromotionProductApiClient.createPromotionProduct(req);
      System.assert(false, 'Expected exception');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('id_update'), e.getMessage());
    }
  }

  @IsTest
  static void test_updatePromotionProduct_success() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    ErpPromotionProductReqDto.UpdateRequestList req = new ErpPromotionProductReqDto.UpdateRequestList();
    ErpPromotionProductReqDto.PromotionItem item = new ErpPromotionProductReqDto.PromotionItem();
    item.no_prom = 'PROM-UPD-001';
    item.cd_item = 'ITEM-UPD-001';
    item.id_update = 'tester';
    req.promotionItemList.add(item);

    Test.startTest();
    ErpApiResponseDto res = ErpPromotionProductApiClient.updatePromotionProduct(req);
    Test.stopTest();

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
  }

  @IsTest
  static void test_updatePromotionProduct_missingIdUpdate_throwsIAE() {
    ErpPromotionProductReqDto.UpdateRequestList req = new ErpPromotionProductReqDto.UpdateRequestList();
    ErpPromotionProductReqDto.PromotionItem item = new ErpPromotionProductReqDto.PromotionItem();
    item.no_prom = 'PROM-UPD-001';
    item.cd_item = 'ITEM-UPD-001';
    req.promotionItemList.add(item);

    try {
      ErpPromotionProductApiClient.updatePromotionProduct(req);
      System.assert(false, 'Expected exception');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('id_update'), e.getMessage());
    }
  }

  @IsTest
  static void test_deletePromotionProduct_success() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());
    lastEndpoint = null;

    ErpPromotionProductReqDto.DeleteRequestList req = new ErpPromotionProductReqDto.DeleteRequestList();
    ErpPromotionProductReqDto.PromotionItem item = new ErpPromotionProductReqDto.PromotionItem();
    item.no_prom = 'PROM-DEL-001';
    item.cd_item = 'ITEM-DEL-001';
    item.id_delete = 'tester';
    req.promotionItemList.add(item);

    Test.startTest();
    ErpApiResponseDto res = ErpPromotionProductApiClient.deletePromotionProduct(req);
    Test.stopTest();

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
    System.assertNotEquals(null, lastEndpoint);
    System.assert(lastEndpoint.contains('no_prom=PROM-DEL-001'));
    System.assert(lastEndpoint.contains('cd_item=ITEM-DEL-001'));
    System.assert(lastEndpoint.contains('id_delete=tester'));
  }

  @IsTest
  static void test_dto_dateToYmd() {
    Date d = Date.newInstance(2026, 3, 5);
    System.assertEquals('20260305', ErpPromotionProductReqDto.dateToYmd(d));
  }

  @IsTest
  static void test_dto_dateToYmd_null() {
    System.assertEquals('', ErpPromotionProductReqDto.dateToYmd(null));
  }

  @IsTest
  static void test_dto_dtToYmd() {
    Datetime dt = Datetime.newInstanceGmt(2026, 3, 5, 0, 0, 0);
    String result = ErpPromotionProductReqDto.dtToYmd(dt);
    System.assertNotEquals(null, result);
    System.assertEquals(8, result.length(), 'YYYYMMDD format');
  }

  @IsTest
  static void test_dto_dtToYmd_null() {
    System.assertEquals('', ErpPromotionProductReqDto.dtToYmd(null));
  }

  @IsTest
  static void test_dto_boolToYn() {
    System.assertEquals('Y', ErpPromotionProductReqDto.boolToYn(true));
    System.assertEquals('N', ErpPromotionProductReqDto.boolToYn(false));
    System.assertEquals('N', ErpPromotionProductReqDto.boolToYn(null));
  }

  @IsTest
  static void test_dto_isStrNull() {
    System.assertEquals('', ErpPromotionProductReqDto.isStrNull(null));
    System.assertEquals('', ErpPromotionProductReqDto.isStrNull(''));
    System.assertEquals('val', ErpPromotionProductReqDto.isStrNull('val'));
  }

  @IsTest
  static void test_dto_outerClass_defaultConstructor() {
    ErpPromotionProductReqDto dto = new ErpPromotionProductReqDto();
    System.assertNotEquals(null, dto);
  }
}