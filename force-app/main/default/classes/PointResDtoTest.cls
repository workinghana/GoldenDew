@IsTest
private class PointResDtoTest {
  @IsTest
  static void availablePointResponse_nonNullTotal_mapsCorrectly() {
    Account acc = new Account(Name = 'ARTestTech', Industry = 'Technology', AnnualRevenue = 500);
    insert acc;

    AggregateResult ar = [
      SELECT Industry pointTypeCode, SUM(AnnualRevenue) totalPoints
      FROM Account
      WHERE Id = :acc.Id
      GROUP BY Industry
    ][0];

    PointResDto.AvailablePointResponse resp = new PointResDto.AvailablePointResponse(ar);
    System.assertEquals('Technology', resp.CD_TYPE_POINT);
    System.assertEquals(500, resp.points);
  }

  @IsTest
  static void availablePointResponse_nullTotal_returnsZero() {
    Account acc = new Account(Name = 'ARTestNull', Industry = 'Education');
    insert acc;

    AggregateResult ar = [
      SELECT Industry pointTypeCode, SUM(AnnualRevenue) totalPoints
      FROM Account
      WHERE Id = :acc.Id
      GROUP BY Industry
    ][0];

    PointResDto.AvailablePointResponse resp = new PointResDto.AvailablePointResponse(ar);
    System.assertEquals(0, resp.points);
  }

  @IsTest
  static void creditPointResponse_nullLl_allDefaults() {
    PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(null);

    System.assertEquals('', resp.YM_CREATE);
    System.assertEquals('', resp.NM_TYPE_POINT);
    System.assertEquals('', resp.NM_TYPE_SAVE);
    System.assertEquals('', resp.DT_SAVE_PLAN);
    System.assertEquals(0, resp.PT_SAVE_PLAN);
    System.assertEquals('', resp.DT_SAVE);
    System.assertEquals(0, resp.PT_SAVE);
    System.assertEquals(0, resp.PT_USE);
    System.assertEquals(0, resp.PT_DESTROY);
    System.assertEquals('', resp.DT_LIMIT_START);
    System.assertEquals('', resp.DT_LIMIT_END);
    System.assertEquals('', resp.DT_DESTROY_PLAN);
    System.assertEquals('', resp.DT_DESTROY_DEL_SALE);
    System.assertEquals('', resp.NO_SAL);
    System.assertEquals(0, resp.AM_SAL);
    System.assertEquals(0, resp.PT_TARGET);
    System.assertEquals(0, resp.PT_USE_SALE);
  }

  @IsTest
  static void creditPointResponse_withDates_mapsDateAndPointFields() {
    LoyaltyLedger ll = new LoyaltyLedger();
    ll.ActivityDate = Datetime.newInstanceGmt(2025, 6, 15, 0, 0, 0);
    ll.Points = 500;
    ll.ExpiryDate = Date.newInstance(2026, 3, 1);

    PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);

    System.assertEquals('202506', resp.YM_CREATE);
    System.assertEquals('20250615', resp.DT_SAVE);
    System.assertEquals(500, resp.PT_SAVE);
    System.assertEquals('20260301', resp.DT_LIMIT_END);
    System.assertEquals('20260302', resp.DT_DESTROY_PLAN);
    System.assertEquals('', resp.NM_TYPE_SAVE);
    System.assertEquals('', resp.NM_TYPE_POINT);
    System.assertEquals('', resp.NO_SAL);
    System.assertEquals(0, resp.AM_SAL);
  }

  @IsTest
  static void creditPointResponse_withEscrowDate_mapsPlanFields() {
    LoyaltyLedger ll = new LoyaltyLedger();
    ll.ActivityDate = Datetime.newInstanceGmt(2025, 1, 10, 0, 0, 0);
    ll.Points = 200;
    ll.EscrowPointsCreditDate = Date.newInstance(2025, 2, 1);

    PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);

    System.assertNotEquals('', resp.DT_SAVE_PLAN);
    System.assertEquals(200, resp.PT_SAVE_PLAN);
  }

  @IsTest
  static void creditPointResponse_knownSubTypeName_mapsToLabel() {
    Id fakeId = UserInfo.getUserId();

    JournalSubType jst = new JournalSubType(Name = 'Purchase Accrual');
    TransactionJournal tj = new TransactionJournal();
    tj.JournalSubTypeId = fakeId;
    tj.JournalSubType = jst;

    LoyaltyLedger ll = new LoyaltyLedger();
    ll.TransactionJournalId = fakeId;
    ll.TransactionJournal = tj;

    PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);
    System.assertNotEquals('', resp.NM_TYPE_SAVE);
  }

  @IsTest
  static void creditPointResponse_unknownSubTypeName_returnsOriginal() {
    Id fakeId = UserInfo.getUserId();

    JournalSubType jst = new JournalSubType(Name = 'UnknownType');
    TransactionJournal tj = new TransactionJournal();
    tj.JournalSubTypeId = fakeId;
    tj.JournalSubType = jst;

    LoyaltyLedger ll = new LoyaltyLedger();
    ll.TransactionJournalId = fakeId;
    ll.TransactionJournal = tj;

    PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);
    System.assertEquals('UnknownType', resp.NM_TYPE_SAVE);
  }

  @IsTest
  static void creditPointResponse_withOrderInfo_mapsFields() {
    Id fakeId = UserInfo.getUserId();

    Order fakeOrder = new Order(SaleNo__c = 'SAL-999', ActualPaymentAmount__c = 75000);
    TransactionJournal tj = new TransactionJournal();
    tj.JournalSubTypeId = fakeId;
    tj.JournalSubType = new JournalSubType(Name = 'Manual Points Credit');
    tj.OrderId = fakeId;
    tj.Order = fakeOrder;

    LoyaltyLedger ll = new LoyaltyLedger();
    ll.TransactionJournalId = fakeId;
    ll.TransactionJournal = tj;

    PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);

    System.assertEquals('SAL-999', resp.NO_SAL);
    System.assertEquals(75000, resp.AM_SAL);
    System.assertNotEquals('', resp.NM_TYPE_SAVE);
  }

  @IsTest
  static void creditPointResponse_withSummaryValues_mapsAdditionalFields() {
    Id fakeId = UserInfo.getUserId();

    Order fakeOrder = new Order(SaleNo__c = 'SAL-100', ActualPaymentAmount__c = 50000);
    TransactionJournal tj = new TransactionJournal();
    tj.JournalSubTypeId = fakeId;
    tj.JournalSubType = new JournalSubType(Name = 'Purchase Accrual');
    tj.OrderId = fakeId;
    tj.Order = fakeOrder;

    LoyaltyLedger ll = new LoyaltyLedger();
    ll.ActivityDate = Datetime.newInstanceGmt(2025, 7, 1, 0, 0, 0);
    ll.Points = 500;
    ll.TransactionJournalId = fakeId;
    ll.TransactionJournal = tj;

    PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll, 120, 30, 1000);

    System.assertEquals(120, resp.PT_USE);
    System.assertEquals(30, resp.PT_DESTROY);
    System.assertEquals(1000, resp.PT_USE_SALE);
    System.assertEquals('SAL-100', resp.NO_SAL);
  }

  @IsTest
  static void debitPointResponse_nonInsertedLlt_returnsDefaults() {
    LoyaltyLedgerTraceability llt = new LoyaltyLedgerTraceability();

    PointResDto.DebitPointResponse resp = new PointResDto.DebitPointResponse(llt);

    System.assertEquals('', resp.YM_CREATE);
    System.assertEquals('', resp.NM_PERSON);
    System.assertEquals('', resp.DT_USE);
    System.assertEquals(0, resp.PT_USE);
    System.assertEquals('', resp.NO_SAL);
    System.assertEquals('', resp.NO_SAL_SAVE);
    System.assertEquals('', resp.NO_SAL_RTN);
    System.assertEquals(0, resp.AM_SAL);
  }
}
