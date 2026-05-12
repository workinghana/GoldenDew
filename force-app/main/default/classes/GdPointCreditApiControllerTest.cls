@IsTest
private class GdPointCreditApiControllerTest {
  private class MockPointServiceSuccess implements GdPointService {
    public ApiResult creditPoint(Map<String, Object> reqData) {
      Map<String, Object> data = new Map<String, Object>{ 'result' => 'ok' };
      return ApiResult.ok(200, 'SUCCESS', data);
    }

    public ApiResult creditEcopoint(Map<String, Object> r) {
      return null;
    }
    public Double getPointList(Map<String, Object> r) {
      return 0;
    }
    public ApiResult getPointApplyHelp(Map<String, Object> r) {
      return null;
    }
    public ApiResult getPointApplyHelpV2(Map<String, Object> r) {
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
    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
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
    public ApiResult updatePoint(Map<String, Object> reqData) {
      return null;
    }
  }

  private class MockPointServiceCustomError implements GdPointService {
    public ApiResult creditPoint(Map<String, Object> reqData) {
      throw new CustomException(422, 'CUSTOM ERROR');
    }

    public ApiResult creditEcopoint(Map<String, Object> r) {
      return null;
    }
    public Double getPointList(Map<String, Object> r) {
      return 0;
    }
    public ApiResult getPointApplyHelp(Map<String, Object> r) {
      return null;
    }
    public ApiResult getPointApplyHelpV2(Map<String, Object> r) {
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
    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
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
    public ApiResult updatePoint(Map<String, Object> reqData) {
      return null;
    }
  }

  private class MockPointServiceRuntimeError implements GdPointService {
    public ApiResult creditPoint(Map<String, Object> reqData) {
      String forcedNull;
      forcedNull.length();
      return null;
    }

    public ApiResult creditEcopoint(Map<String, Object> r) {
      return null;
    }
    public Double getPointList(Map<String, Object> r) {
      return 0;
    }
    public ApiResult getPointApplyHelp(Map<String, Object> r) {
      return null;
    }
    public ApiResult getPointApplyHelpV2(Map<String, Object> r) {
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
    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
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
    public ApiResult updatePoint(Map<String, Object> reqData) {
      return null;
    }
  }

  private static void setupRest(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/point/credit';
    req.httpMethod = 'POST';
    if (body != null)
      req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @IsTest
  static void creditPoints_emptyBody_handlesError() {
    GdPointCreditApiController.setPointService(new MockPointServiceSuccess());
    setupRest(null);
    Test.startTest();
    GdPointCreditApiController.creditPoints();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode);
    GdPointCreditApiController.setPointService(null);
  }

  @IsTest
  static void creditPoints_invalidJson_handlesError() {
    GdPointCreditApiController.setPointService(new MockPointServiceSuccess());
    setupRest('{invalid-json}');
    Test.startTest();
    GdPointCreditApiController.creditPoints();
    Test.stopTest();
    System.assertEquals(400, RestContext.response.statusCode);
    GdPointCreditApiController.setPointService(null);
  }

  @IsTest
  static void creditPoints_success() {
    GdPointCreditApiController.setPointService(new MockPointServiceSuccess());
    setupRest('{"memberNo":"MEM001","points":100}');

    Test.startTest();
    GdPointCreditApiController.creditPoints();
    Test.stopTest();

    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('"success" : true'));
    GdPointCreditApiController.setPointService(null);
  }

  @IsTest
  static void creditPoints_serviceCustomException() {
    GdPointCreditApiController.setPointService(new MockPointServiceCustomError());
    setupRest('{"memberNo":"MEM001","points":100}');

    Test.startTest();
    GdPointCreditApiController.creditPoints();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('CUSTOM ERROR'));
    GdPointCreditApiController.setPointService(null);
  }

  @IsTest
  static void creditPoints_serviceRuntimeException() {
    GdPointCreditApiController.setPointService(new MockPointServiceRuntimeError());
    setupRest('{"memberNo":"MEM001","points":100}');

    Test.startTest();
    GdPointCreditApiController.creditPoints();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
    System.assertNotEquals(null, RestContext.response.responseBody);
    GdPointCreditApiController.setPointService(null);
  }
}