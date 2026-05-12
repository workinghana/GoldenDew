/**
 * GdReturnDeleteBranchHandler Test (Phase 6.8)
 */
@IsTest
private class GdReturnDeleteBranchHandlerTest {
  // Order Create 시 발화하는 RTF_Tier_Qualifying_Point_Award / RTF_Write_Purchase_Date 플로우가
  // Salesforce Loyalty creditPoints invocable action 을 호출하면서 콜아웃을 발생시키므로
  // @TestSetup 에서 HttpCalloutMock 을 세팅한다.
  private class SuccessCalloutMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setStatus('OK');
      res.setHeader('Content-Type', 'application/json');
      res.setBody('{"ok":true}');
      return res;
    }
  }

  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Id stdPbId = Test.getStandardPricebookId();
    Account company = new Account(Name = 'Co_RD', CompanyCode__c = 'CMP-RD');
    Account store = new Account(Name = 'Store_RD', StoreCode__c = 'STR-RD');
    insert new List<Account>{ company, store };

    Contact c = new Contact(LastName = 'RDTester', MemberNo__c = 'M-RD-TEST', AccountId = company.Id);
    insert c;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'LP_RD', IsPrimary = false);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      ProgramId = lp.Id,
      ContactId = c.Id,
      MemberStatus = 'Active',
      MembershipNumber = 'M-RD-TEST',
      EnrollmentDate = Date.today()
    );
    insert lpm;

    // 원판매
    Order origOrder = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SAL-RD-OLD',
      ActualPaymentAmount__c = 100000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert origOrder;

    // 환불 Order (이미 returnDeleted 상태로 시드, OriginalOrderId 연결)
    Order returnOrder = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 4, 1),
      Status = 'returnDeleted',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'RTN-RD-DEL',
      ActualPaymentAmount__c = 30000,
      Type = 'Standard',
      SaleStatus__c = '03',
      IsReductionOrder__c = true,
      OriginalOrderId__c = origOrder.Id,
      IsDeleted__c = true,
      InsertId__c = 'tester'
    );
    insert returnOrder;

    // 환불 등록 시 처리 기록 시드 (실 차감 1,000P + 미차감 200P)
    GdMigrationUtil.recordAdjustmentLog(
      lpm.Id,
      null,
      'RETURN_REGISTER_BRANCH',
      'POST /gd/v1/return',
      'SAL-RD-OLD',
      1200,
      1000,
      'Test seed for Phase 6.8'
    );

    // 별도 원판매 — 처리 기록 없음 (NoLog 케이스용)
    Order origOrderNoLog = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 3, 5),
      Status = 'saleSuccess',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'SAL-RD-NOLOG-OLD',
      ActualPaymentAmount__c = 50000,
      Type = 'Standard',
      SaleStatus__c = '01',
      InsertId__c = 'tester'
    );
    insert origOrderNoLog;

    Order returnOrderNoLog = new Order(
      AccountId = company.Id,
      EffectiveDate = Date.newInstance(2026, 4, 1),
      Status = 'returnDeleted',
      Pricebook2Id = stdPbId,
      MemberNo__c = c.Id,
      StoreCode__c = store.Id,
      SaleNo__c = 'RTN-RD-NOLOG',
      ActualPaymentAmount__c = 30000,
      Type = 'Standard',
      SaleStatus__c = '03',
      IsReductionOrder__c = true,
      OriginalOrderId__c = origOrderNoLog.Id,
      IsDeleted__c = true,
      InsertId__c = 'tester'
    );
    insert returnOrderNoLog;
  }

  @IsTest
  static void wrap_validReturn_invokesRestorePath() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '반품 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdReturnDeleteBranchHandler.wrapResponseForOldReturn(standardResult, 'RTN-RD-DEL', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assert(result.data.containsKey('option_c_restore_eligible'));
    System.assertNotEquals(null, result.data.get('adjustment_log_id'));
  }

  @IsTest
  static void wrap_returnNoLog_skipsRestoration() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '반품 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdReturnDeleteBranchHandler.wrapResponseForOldReturn(standardResult, 'RTN-RD-NOLOG', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(0, result.data.get('option_c_restore_eligible'));
  }

  @IsTest
  static void wrap_returnNotFound_recordsError() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '반품 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdReturnDeleteBranchHandler.wrapResponseForOldReturn(standardResult, 'RTN-RD-NOTFOUND', null);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(0, result.data.get('option_c_restore_actual'));
  }

  @IsTest
  static void wrap_blankSaleNo_skipsRestoration() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '반품 삭제 완료', standardData);

    Test.startTest();
    ApiResult result = GdReturnDeleteBranchHandler.wrapResponseForOldReturn(standardResult, '', null);
    Test.stopTest();

    System.assertEquals(0, result.data.get('option_c_restore_eligible'));
  }

  @IsTest
  static void wrap_nullStandardResult_returnsNull() {
    Test.startTest();
    ApiResult result = GdReturnDeleteBranchHandler.wrapResponseForOldReturn(null, 'X', null);
    Test.stopTest();
    System.assertEquals(null, result);
  }

  @IsTest
  static void wrap_nullData_initializesAndEnriches() {
    ApiResult standardResult = new ApiResult(true, 200, '반품 삭제 완료', null);

    Test.startTest();
    ApiResult result = GdReturnDeleteBranchHandler.wrapResponseForOldReturn(standardResult, 'RTN-RD-DEL', null);
    Test.stopTest();

    System.assertNotEquals(null, result.data);
    System.assertEquals(true, result.data.get('option_c_branch'));
  }

  @IsTest
  static void wrap_loggerProvided_setsPartial() {
    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '반품 삭제 완료', standardData);

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.API);
    logger.logging('GdReturnDeleteBranchHandlerTest');

    Test.startTest();
    ApiResult result = GdReturnDeleteBranchHandler.wrapResponseForOldReturn(standardResult, 'RTN-RD-DEL', logger);
    Test.stopTest();

    System.assertEquals(true, result.data.get('option_c_branch'));
  }
}