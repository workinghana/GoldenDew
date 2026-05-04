@IsTest
private class GdEcopointApiControllerTest {
  /* =====================================================
   * Mock Service - 성공 케이스
   * ===================================================== */
  private class MockPointServiceSuccess implements GdPointService {
    public ApiResult creditEcopoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'SUCCESS', null);
    }

    // ====== 나머지 인터페이스 메서드는 최소 더미 구현 ======

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
    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> journals, Decimal amount) {
      return new List<PointCreditDTO>();
    }
  }

  /* =====================================================
   * Mock Service - 에러 케이스
   * ===================================================== */
  private class MockPointServiceError implements GdPointService {
    public ApiResult creditEcopoint(Map<String, Object> reqData) {
      throw new CustomException(400, 'SERVICE ERROR');
    }

    // ====== 동일하게 최소 더미 구현 ======

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
    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> journals, Decimal amount) {
      return new List<PointCreditDTO>();
    }
  }

  /* =====================================================
   * 1️⃣ 정상 요청 테스트
   * ===================================================== */
  @IsTest
  static void test_creditEcopoint_success() {
    GdEcopointApiController.setPointService(new MockPointServiceSuccess());

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/ecopoint';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{ "memberNo":"MEM001" }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdEcopointApiController.creditEcopoint();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);

    GdEcopointApiController.setPointService(null);
  }

  /* =====================================================
   * 2️⃣ 빈 Body 테스트
   * ===================================================== */
  @IsTest
  static void test_creditEcopoint_emptyBody() {
    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/ecopoint';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdEcopointApiController.creditEcopoint();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  /* =====================================================
   * 3️⃣ 서비스 예외 테스트
   * ===================================================== */
  @IsTest
  static void test_creditEcopoint_serviceError() {
    GdEcopointApiController.setPointService(new MockPointServiceError());

    RestRequest req = new RestRequest();
    req.requestUri = '/services/apexrest/gd/ecopoint';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf('{ "memberNo":"MEM001" }');

    RestContext.request = req;
    RestContext.response = new RestResponse();

    Test.startTest();
    GdEcopointApiController.creditEcopoint();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);

    GdEcopointApiController.setPointService(null);
  }
}