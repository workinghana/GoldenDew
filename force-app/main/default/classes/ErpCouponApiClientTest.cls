@IsTest
private class ErpCouponApiClientTest {

  /* =====================================================
   * HTTP 성공 Mock (200 + JSON body)
   * ===================================================== */
  private class MockHttpSuccess implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"success":true,"message":"OK","data":null}');
      return res;
    }
  }

  /* =====================================================
   * null 요청 → IllegalArgumentException
   * ===================================================== */
  @IsTest
  static void test_createMaster_nullReq_throwsIAE() {
    try {
      ErpCouponApiClient.createMaster(null);
      System.assert(false, '예외 발생해야 함');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('required'), e.getMessage());
    }
  }

  @IsTest
  static void test_updateMaster_nullReq_throwsIAE() {
    try {
      ErpCouponApiClient.updateMaster(null);
      System.assert(false, '예외 발생해야 함');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('required'), e.getMessage());
    }
  }

  @IsTest
  static void test_deleteMaster_nullReq_throwsIAE() {
    try {
      ErpCouponApiClient.deleteMaster(null);
      System.assert(false, '예외 발생해야 함');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('required'), e.getMessage());
    }
  }

  @IsTest
  static void test_couponIssue_nullReq_throwsIAE() {
    try {
      ErpCouponApiClient.couponIssue(null);
      System.assert(false, '예외 발생해야 함');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('required'), e.getMessage());
    }
  }

  @IsTest
  static void test_couponUpdate_nullReq_throwsIAE() {
    try {
      ErpCouponApiClient.couponUpdate(null);
      System.assert(false, '예외 발생해야 함');
    } catch (IllegalArgumentException e) {
      System.assert(e.getMessage().contains('required'), e.getMessage());
    }
  }

  /* =====================================================
   * createMaster - 성공 경로
   * ===================================================== */
  @IsTest
  static void test_createMaster_success() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    ErpCouponMasterReqDto.IssueRequest req = new ErpCouponMasterReqDto.IssueRequest();
    req.cd_company     = 'TC01';
    req.no_man_coupon  = 'MAN-001';
    req.nm_coupon      = '테스트쿠폰';
    req.id_insert      = 'tester';

    Test.startTest();
    ErpApiResponseDto res = ErpCouponApiClient.createMaster(req);
    Test.stopTest();

    System.assertNotEquals(null, res, '응답 DTO 반환');
    System.assertEquals(true, res.success, 'success = true');
    System.assertEquals('OK', res.message, 'message = OK');
  }

  /* =====================================================
   * updateMaster - 성공 경로
   * ===================================================== */
  @IsTest
  static void test_updateMaster_success() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    ErpCouponMasterReqDto.UpdateRequest req = new ErpCouponMasterReqDto.UpdateRequest();
    req.cd_company    = 'TC01';
    req.no_man_coupon = 'MAN-UPD-001';
    req.id_insert     = 'tester';

    Test.startTest();
    ErpApiResponseDto res = ErpCouponApiClient.updateMaster(req);
    Test.stopTest();

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
  }

  /* =====================================================
   * deleteMaster - 성공 경로 (query params 방식)
   * ===================================================== */
  @IsTest
  static void test_deleteMaster_success() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    ErpCouponMasterReqDto.DeleteRequest req = new ErpCouponMasterReqDto.DeleteRequest();
    req.no_man_coupon = 'MAN-DEL-001';
    req.id_delete     = 'tester';

    Test.startTest();
    ErpApiResponseDto res = ErpCouponApiClient.deleteMaster(req);
    Test.stopTest();

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
  }

  /* =====================================================
   * couponIssue - 성공 경로
   * ===================================================== */
  @IsTest
  static void test_couponIssue_success() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    ErpCouponReqDto.IssueRequest req = new ErpCouponReqDto.IssueRequest();
    ErpCouponReqDto.CouponDetailModel item = new ErpCouponReqDto.CouponDetailModel('MAN-001', 'CPN-001', 'MBR-001', 'tester');
    req.couponDetailModels.add(item);

    Test.startTest();
    ErpApiResponseDto res = ErpCouponApiClient.couponIssue(req);
    Test.stopTest();

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
  }

  /* =====================================================
   * couponUpdate - 성공 경로
   * ===================================================== */
  @IsTest
  static void test_couponUpdate_success() {
    Test.setMock(HttpCalloutMock.class, new MockHttpSuccess());

    ErpCouponReqDto.UpdateRequest req = new ErpCouponReqDto.UpdateRequest();
    ErpCouponReqDto.CouponDetailUpdateModel item = new ErpCouponReqDto.CouponDetailUpdateModel();
    item.no_man_coupon   = 'MAN-001';
    item.no_mbr          = 'MBR-001';
    item.no_coupon       = 'CPN-001';
    item.id_update       = 'tester';
    item.cd_stat_coupon  = '03';
    req.couponDetailUpdateModels.add(item);

    Test.startTest();
    ErpApiResponseDto res = ErpCouponApiClient.couponUpdate(req);
    Test.stopTest();

    System.assertNotEquals(null, res);
    System.assertEquals(true, res.success);
  }

  /* =====================================================
   * ErpApiResponseDto - hasObjectData / hasListData 커버
   * ===================================================== */
  @IsTest
  static void test_erpApiResponseDto_hasObjectData() {
    ErpApiResponseDto dto = new ErpApiResponseDto();
    dto.data = new Map<String, Object>{ 'key' => 'val' };
    System.assertEquals(true,  dto.hasObjectData(), 'Map → hasObjectData true');
    System.assertEquals(false, dto.hasListData(),   'Map → hasListData false');
  }

  @IsTest
  static void test_erpApiResponseDto_hasListData() {
    ErpApiResponseDto dto = new ErpApiResponseDto();
    dto.data = new List<Object>{ 'item1' };
    System.assertEquals(false, dto.hasObjectData(), 'List → hasObjectData false');
    System.assertEquals(true,  dto.hasListData(),   'List → hasListData true');
  }

  @IsTest
  static void test_erpApiResponseDto_nullData() {
    ErpApiResponseDto dto = new ErpApiResponseDto();
    dto.data = null;
    System.assertEquals(false, dto.hasObjectData(), 'null → hasObjectData false');
    System.assertEquals(false, dto.hasListData(),   'null → hasListData false');
  }
}