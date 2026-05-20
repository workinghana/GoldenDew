@IsTest
private class GdPointHelpApiControllerV1Test {
  private static Boolean pointServiceCalled = false;

  private class MockPointServiceSuccess implements GdPointService {
    public ApiResult creditPoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult creditEcopoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public Double getPointList(Map<String, Object> reqData) {
      return 0;
    }
    public ApiResult getPointApplyHelp(Map<String, Object> reqData) {
      pointServiceCalled = true;
      return ApiResult.ok(
        200,
        'point help success',
        new Map<String, Object>{ 'pointList' => new List<Object>{ new Map<String, Object>{ 'CD_TYPE_POINT' => '02', 'POINT' => 123.45 } } }
      );
    }
    public ApiResult getPointApplyHelpV2(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getDebitPointList(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPointsV2(TransactionJournal tj, List<LoyaltyLedger> llList) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPointsV3(TransactionJournal tj, Map<Id, Decimal> m) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointsCustom(TransactionJournal tj) {
      return null;
    }
    public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return null;
    }
    public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return null;
    }
    public List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList) {
      return null;
    }
    public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
      return null;
    }
    public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
      return new List<PointCreditDTO>();
    }
    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
      return null;
    }
    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
    }
    public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
      return null;
    }
    public ApiResult deletePoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public Boolean isAccrualEligible(TransactionJournal tj) {
      return true;
    }
    public ApiResult updatePoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockPointServiceCustomThrower implements GdPointService {
    public ApiResult creditPoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult creditEcopoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public Double getPointList(Map<String, Object> reqData) {
      return 0;
    }
    public ApiResult getPointApplyHelp(Map<String, Object> reqData) {
      throw new CustomException(422, 'point service custom error');
    }
    public ApiResult getPointApplyHelpV2(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getDebitPointList(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPointsV2(TransactionJournal tj, List<LoyaltyLedger> llList) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPointsV3(TransactionJournal tj, Map<Id, Decimal> m) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointsCustom(TransactionJournal tj) {
      return null;
    }
    public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return null;
    }
    public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return null;
    }
    public List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList) {
      return null;
    }
    public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
      return null;
    }
    public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
      return new List<PointCreditDTO>();
    }
    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
      return null;
    }
    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
    }
    public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
      return null;
    }
    public ApiResult deletePoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public Boolean isAccrualEligible(TransactionJournal tj) {
      return true;
    }
    public ApiResult updatePoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private class MockPointServiceExploder implements GdPointService {
    public ApiResult creditPoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult creditEcopoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public Double getPointList(Map<String, Object> reqData) {
      return 0;
    }
    public ApiResult getPointApplyHelp(Map<String, Object> reqData) {
      throw new NullPointerException();
    }
    public ApiResult getPointApplyHelpV2(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public ApiResult getDebitPointList(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPointsV2(TransactionJournal tj, List<LoyaltyLedger> llList) {
      return null;
    }
    public List<PointDebitDTO> debitSpecificPointsV3(TransactionJournal tj, Map<Id, Decimal> m) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointsCustom(TransactionJournal tj) {
      return null;
    }
    public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return null;
    }
    public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData) {
      return null;
    }
    public List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList) {
      return null;
    }
    public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
      return null;
    }
    public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
      return new List<PointCreditDTO>();
    }
    public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
      return null;
    }
    public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
      return null;
    }
    public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
      return new List<PointCreditDTO>();
    }
    public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
      return null;
    }
    public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
      return null;
    }
    public ApiResult deletePoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
    public Boolean isAccrualEligible(TransactionJournal tj) {
      return true;
    }
    public ApiResult updatePoint(Map<String, Object> reqData) {
      return ApiResult.ok(200, 'ok', null);
    }
  }

  private static void setupRest(String body) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v1/point/help';
    req.httpMethod = 'POST';
    if (body != null)
      req.requestBody = Blob.valueOf(body);
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @IsTest
  static void getPointList_emptyBody_handlesError() {
    GdPointHelpApiControllerV1.setPointService(new MockPointServiceSuccess());
    setupRest(null);
    Test.startTest();
    GdPointHelpApiControllerV1.getPointList();
    Test.stopTest();
    System.assertNotEquals(null, RestContext.response);
    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void getPointList_invalidJson_handlesError() {
    GdPointHelpApiControllerV1.setPointService(new MockPointServiceSuccess());
    setupRest('{invalid-json}');

    Test.startTest();
    GdPointHelpApiControllerV1.getPointList();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('JSON 역직렬화 실패'));
  }

  @IsTest
  static void getPointList_success_withInjectedService() {
    pointServiceCalled = false;
    GdPointHelpApiControllerV1.setPointService(new MockPointServiceSuccess());
    setupRest('{"MemberNo__c":"M001","StoreCode__c":"STORE-01","Type":"01"}');

    Test.startTest();
    GdPointHelpApiControllerV1.getPointList();
    Test.stopTest();

    System.assertEquals(true, pointServiceCalled);
    System.assertEquals(200, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('point help success'));
    System.assert(RestContext.response.responseBody.toString().contains('pointList'));
    System.assert(RestContext.response.responseBody.toString().contains('123.45'));
    // System.assertEquals(true, pointServiceCalled);
    // System.assertEquals(200, RestContext.response.statusCode);
    // System.assert(RestContext.response.responseBody.toString().contains('포인트 조회 성공'));
    // System.assert(RestContext.response.responseBody.toString().contains('123.45'));
  }

  @IsTest
  static void getPointList_customException_fromService() {
    GdPointHelpApiControllerV1.setPointService(new MockPointServiceCustomThrower());
    setupRest('{"MemberNo__c":"M001"}');

    Test.startTest();
    GdPointHelpApiControllerV1.getPointList();
    Test.stopTest();

    System.assertEquals(422, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('point service custom error'));
  }

  @IsTest
  static void getPointList_exception_fromService() {
    GdPointHelpApiControllerV1.setPointService(new MockPointServiceExploder());
    setupRest('{"MemberNo__c":"M001"}');

    Test.startTest();
    GdPointHelpApiControllerV1.getPointList();
    Test.stopTest();

    System.assertEquals(500, RestContext.response.statusCode);
  }

  private static void setupRestGet(Map<String, String> params) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/gd/v1/point/help';
    req.httpMethod = 'GET';
    if (params != null) {
      for (String key : params.keySet()) {
        req.params.put(key, params.get(key));
      }
    }
    RestContext.request = req;
    RestContext.response = new RestResponse();
  }

  @IsTest
  static void getTotalMemberPoints_missingMemberNo_returns400() {
    setupRestGet(new Map<String, String>());

    Test.startTest();
    GdPointHelpApiControllerV1.getTotalMemberPoints();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('MemberNo__c'));
  }

  @IsTest
  static void getTotalMemberPoints_blankMemberNo_returns400() {
    setupRestGet(new Map<String, String>{ 'MemberNo__c' => '' });

    Test.startTest();
    GdPointHelpApiControllerV1.getTotalMemberPoints();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
  }

  @IsTest
  static void getTotalMemberPoints_unknownMember_returns400() {
    setupRestGet(new Map<String, String>{ 'MemberNo__c' => 'NO_SUCH_MEMBER_FOR_TEST' });

    Test.startTest();
    GdPointHelpApiControllerV1.getTotalMemberPoints();
    Test.stopTest();

    System.assertEquals(400, RestContext.response.statusCode);
    System.assert(RestContext.response.responseBody.toString().contains('존재하지 않는 회원'));
  }
}