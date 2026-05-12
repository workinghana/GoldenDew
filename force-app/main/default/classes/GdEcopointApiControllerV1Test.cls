@IsTest
private class GdEcopointApiControllerV1Test {
  /* =====================================================
   * Mock Service - 성공
   * ===================================================== */
  private class MockPointServiceSuccess implements GdPointService {
    public ApiResult creditEcopoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'SUCCESS', null);
    }

    /* === 인터페이스 필수 메서드 (더미) === */
    public ApiResult creditPoint(Map<String, Object> r) {
      return null;
    }
    public Double getPointList(Map<String, Object> r) {
      return 0;
    }
    public ApiResult getPointApplyHelp(Map<String, Object> r) {
      return null;
    }
    public ApiResult getDebitPointList(Map<String, Object> r) {
      return null;
    }

    public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal t) {
      return null;
    }

    public List<PointDebitDTO> debitSpecificPoints(TransactionJournal t, List<LoyaltyLedger> l) {
      return null;
    }

    public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> r) {
      return null;
    }

    public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> r) {
      return null;
    }

    public List<PointCreditDTO> creditSepcificPoints(TransactionJournal t, List<LoyaltyLedgerTraceability> l) {
      return null;
    }

    public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> d) {
      return null;
    }
    public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
      return new List<PointCreditDTO>();
    }
    public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }

    public Map<String, Object> cancelPointRedemption(TransactionJournal t) {
      return null;
    }

    public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> d) {
      return null;
    }

    public ApiResult deletePoint(Map<String, Object> r) {
      return null;
    }

    public Boolean isAccrualEligible(TransactionJournal t) {
      return true;
    }

    public ApiResult getPointApplyHelpV2(Map<String, Object> r) {
      return null;
    }

    public List<PointCreditDTO> creditPoints(Map<String, Object> r) {
      return null;
    }

    public ApiResult updatePoint(Map<String, Object> r) {
      return null;
    }

    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> journals, Decimal factor) {
      return null;
    }
    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> journals, Decimal factor) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
    }
  }

  /* =====================================================
   * Mock Service - 서비스 예외
   * ===================================================== */
  private class MockPointServiceError implements GdPointService {
    public ApiResult creditEcopoint(Map<String, Object> reqData) {
      throw new CustomException(400, 'SERVICE ERROR');
    }

    /* === 더미 구현 === */
    public ApiResult creditPoint(Map<String, Object> r) {
      return null;
    }
    public Double getPointList(Map<String, Object> r) {
      return 0;
    }
    public ApiResult getPointApplyHelp(Map<String, Object> r) {
      return null;
    }
    public ApiResult getDebitPointList(Map<String, Object> r) {
      return null;
    }

    public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal t) {
      return null;
    }

    public List<PointDebitDTO> debitSpecificPoints(TransactionJournal t, List<LoyaltyLedger> l) {
      return null;
    }

    public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> r) {
      return null;
    }

    public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> r) {
      return null;
    }

    public List<PointCreditDTO> creditSepcificPoints(TransactionJournal t, List<LoyaltyLedgerTraceability> l) {
      return null;
    }

    public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> d) {
      return null;
    }
    public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
      return new List<PointCreditDTO>();
    }
    public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }

    public Map<String, Object> cancelPointRedemption(TransactionJournal t) {
      return null;
    }

    public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> d) {
      return null;
    }

    public ApiResult deletePoint(Map<String, Object> r) {
      return null;
    }

    public Boolean isAccrualEligible(TransactionJournal t) {
      return false;
    }
    public ApiResult getPointApplyHelpV2(Map<String, Object> r) {
      return null;
    }

    public List<PointCreditDTO> creditPoints(Map<String, Object> r) {
      return null;
    }

    public ApiResult updatePoint(Map<String, Object> r) {
      return null;
    }

    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> journals, Decimal factor) {
      return null;
    }
    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> journals, Decimal factor) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
    }
  }

  /* =====================================================
   * 1️⃣ 성공 케이스
   * ===================================================== */
  @IsTest
  static void test_creditEcopoint_success() {
    GdEcopointApiControllerV1.setPointService(new MockPointServiceSuccess());

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/v1/ecopoint';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{ "memberNo":"MEM001" }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdEcopointApiControllerV1.creditEcopoint();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);

    GdEcopointApiControllerV1.setPointService(null);
  }

  /* =====================================================
   * 2️⃣ 빈 Body
   * ===================================================== */
  @IsTest
  static void test_creditEcopoint_emptyBody() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/v1/ecopoint';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdEcopointApiControllerV1.creditEcopoint();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  /* =====================================================
   * 3️⃣ JSON 파싱 실패
   * ===================================================== */
  @IsTest
  static void test_creditEcopoint_invalidJson() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/v1/ecopoint';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{ invalid json }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdEcopointApiControllerV1.creditEcopoint();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  /* =====================================================
   * 4️⃣ 서비스 CustomException
   * ===================================================== */
  @IsTest
  static void test_creditEcopoint_serviceException() {
    GdEcopointApiControllerV1.setPointService(new MockPointServiceError());

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/v1/ecopoint';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{ "memberNo":"MEM001" }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdEcopointApiControllerV1.creditEcopoint();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);

    GdEcopointApiControllerV1.setPointService(null);
  }
}