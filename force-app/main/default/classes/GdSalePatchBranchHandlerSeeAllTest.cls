/**
 * Phase 6.6 - Force-Credit / Force-Debit success path 검증 (SeeAllData).
 * @TestSetup 가 있는 GdSalePatchBranchHandlerTest 와 SeeAllData 충돌 회피.
 */
@IsTest(SeeAllData=true)
private class GdSalePatchBranchHandlerSeeAllTest {

  /** 활성 lump 회원 (PointTypeCode='04') + 등급 보유 한 명 검색 */
  private static LoyaltyAggrSubPointExprLedger__c findActiveLumpAgg() {
    List<LoyaltyAggrSubPointExprLedger__c> agg = [
      SELECT LoyaltyProgramMemberId__c, LoyaltyProgramMemberId__r.ContactId,
             LoyaltyProgramMemberId__r.ProgramId
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE CurrencySubTypeId__r.PointTypeCode__c = '04'
        AND AvailablePoints__c > 100
        AND ExpiryDate__c >= TODAY
      LIMIT 1
    ];
    return agg.isEmpty() ? null : agg[0];
  }

  /** 회원에 등급 매겨져 있는지 확인 */
  private static Boolean memberHasTier(Id lpmId) {
    return ![SELECT Id FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :lpmId LIMIT 1].isEmpty();
  }

  /** 옛 Order 시드 (시드 시 RUNID 로 격리) */
  private static Order seedOldOrder(String runId, Id contactId, Decimal amount) {
    Id stdPbId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
    Account company = new Account(Name = runId + '-CO', CompanyCode__c = runId + '-CO');
    Account store = new Account(Name = runId + '-STR', StoreCode__c = runId + '-STR');
    insert new List<Account>{ company, store };

    Order o = new Order(
      AccountId = company.Id, EffectiveDate = Date.newInstance(2026, 3, 1),
      Status = 'saleSuccess', Pricebook2Id = stdPbId,
      MemberNo__c = contactId, StoreCode__c = store.Id,
      SaleNo__c = runId + '-SALE', ActualPaymentAmount__c = amount,
      Type = 'Standard', SaleStatus__c = '01', InsertId__c = 'tester'
    );
    insert o;
    return o;
  }

  @IsTest
  static void wrap_realLumpMember_increaseDelta_attemptsForceCredit() {
    LoyaltyAggrSubPointExprLedger__c agg = findActiveLumpAgg();
    if (agg == null || !memberHasTier(agg.LoyaltyProgramMemberId__c)) {
      System.assert(true, '활성 lump 회원/등급 없음 — skip');
      return;
    }

    Order origOrder = seedOldOrder(
      'TEST-PHASE66-INC-' + Datetime.now().getTime(),
      agg.LoyaltyProgramMemberId__r.ContactId, 100000
    );

    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    // delta = +1,000 (증액) → force-credit
    Decimal oldAmount = 99000;

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(
      standardResult, origOrder.SaleNo__c, oldAmount, null
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(true, result.data.get('option_c_branch'));
    System.assertEquals(1000, result.data.get('option_c_amount_delta'));
    System.assertEquals('credit', result.data.get('option_c_direction'));
  }

  @IsTest
  static void wrap_realLumpMember_decreaseDelta_attemptsForceDebit() {
    LoyaltyAggrSubPointExprLedger__c agg = findActiveLumpAgg();
    if (agg == null || !memberHasTier(agg.LoyaltyProgramMemberId__c)) {
      return;
    }

    Order origOrder = seedOldOrder(
      'TEST-PHASE66-DEC-' + Datetime.now().getTime(),
      agg.LoyaltyProgramMemberId__r.ContactId, 100000
    );

    Map<String, Object> standardData = new Map<String, Object>();
    ApiResult standardResult = ApiResult.ok(200, '판매 수정 완료', standardData);

    // delta = -1,000 (감액) → force-debit
    Decimal oldAmount = 101000;

    Test.startTest();
    ApiResult result = GdSalePatchBranchHandler.wrapResponseForOldSale(
      standardResult, origOrder.SaleNo__c, oldAmount, null
    );
    Test.stopTest();

    System.assertEquals(-1000, result.data.get('option_c_amount_delta'));
    System.assertEquals('debit', result.data.get('option_c_direction'));
  }
}