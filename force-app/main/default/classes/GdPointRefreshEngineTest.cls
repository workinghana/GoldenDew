@IsTest
private class GdPointRefreshEngineTest {
  @IsTest
  static void simulate_preservesOriginDateWhenDebitCancelRestoresMultipleOrigins() {
    Date d1 = Date.newInstance(2026, 5, 18);
    Date d2 = Date.newInstance(2026, 5, 25);
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();

    GdPointRefreshEngine.PointEvent opening = new GdPointRefreshEngine.PointEvent('OPENING', GdPointRefreshEngine.EVENT_CREDIT, d1, 100);
    opening.pointTypeCode = '01';
    opening.usagePriority = 1;
    opening.expiryDate = d1.addYears(2);
    events.add(opening);

    GdPointRefreshEngine.PointEvent saleCredit = new GdPointRefreshEngine.PointEvent('SALE_B_CREDIT', GdPointRefreshEngine.EVENT_CREDIT, d2, 100);
    saleCredit.pointTypeCode = '01';
    saleCredit.usagePriority = 1;
    saleCredit.expiryDate = d2.addYears(2);
    saleCredit.saleNo = 'SALE_B';
    events.add(saleCredit);

    GdPointRefreshEngine.PointEvent debit = new GdPointRefreshEngine.PointEvent('SALE_C_DEBIT', GdPointRefreshEngine.EVENT_DEBIT, Date.newInstance(2026, 5, 26), 150);
    debit.pointTypeCode = '01';
    debit.saleNo = 'SALE_C';
    events.add(debit);

    GdPointRefreshEngine.PointEvent cancel = new GdPointRefreshEngine.PointEvent('RETURN_C_CANCEL', GdPointRefreshEngine.EVENT_DEBIT_CANCEL, Date.newInstance(2026, 5, 27), 150);
    cancel.sourceDebitEventKey = 'SALE_C_DEBIT';
    events.add(cancel);

    Test.startTest();
    GdPointRefreshEngine.Result result = new GdPointRefreshEngine().simulate(events);
    Test.stopTest();

    System.assertEquals(200, result.totalRemaining);
    System.assertEquals(2, result.debitCancellations.size());

    Map<Date, Decimal> restoredByDate = new Map<Date, Decimal>();
    for (GdPointRefreshEngine.CreditBucket bucket : result.buckets) {
      if (bucket.bucketKey != null && bucket.bucketKey.startsWith('RETURN_C_CANCEL:RESTORE:')) {
        Decimal current = restoredByDate.containsKey(bucket.accrualDate) ? restoredByDate.get(bucket.accrualDate) : 0;
        restoredByDate.put(bucket.accrualDate, current + bucket.originalPoints);
      }
    }

    System.assertEquals(100, restoredByDate.get(d1));
    System.assertEquals(50, restoredByDate.get(d2));
  }

  @IsTest
  static void simulate_excludesSameSaleCreditWhenUsingPoints() {
    Date d = Date.newInstance(2026, 5, 18);
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();

    GdPointRefreshEngine.PointEvent opening = new GdPointRefreshEngine.PointEvent('OPENING', GdPointRefreshEngine.EVENT_CREDIT, d, 100);
    opening.pointTypeCode = '01';
    opening.usagePriority = 1;
    events.add(opening);

    GdPointRefreshEngine.PointEvent saleCredit = new GdPointRefreshEngine.PointEvent('SALE_A_CREDIT', GdPointRefreshEngine.EVENT_CREDIT, d, 100);
    saleCredit.pointTypeCode = '01';
    saleCredit.usagePriority = 1;
    saleCredit.saleNo = 'SALE_A';
    events.add(saleCredit);

    GdPointRefreshEngine.PointEvent debit = new GdPointRefreshEngine.PointEvent('SALE_A_DEBIT', GdPointRefreshEngine.EVENT_DEBIT, d, 50);
    debit.saleNo = 'SALE_A';
    events.add(debit);

    GdPointRefreshEngine.Result result = new GdPointRefreshEngine().simulate(events);

    System.assertEquals(150, result.totalRemaining);
    System.assertEquals('OPENING', result.allocations[0].creditBucketKey);
    System.assertEquals(50, result.allocations[0].points);
  }

  @IsTest
  static void simulate_keepsManualCreditAsUsableOrigin() {
    Date d = Date.newInstance(2026, 5, 20);
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();

    GdPointRefreshEngine.PointEvent manualCredit = new GdPointRefreshEngine.PointEvent('MANUAL_UI_CREDIT', GdPointRefreshEngine.EVENT_CREDIT, d, 300);
    manualCredit.pointTypeCode = '04';
    manualCredit.usagePriority = 2;
    manualCredit.manualCredit = true;
    events.add(manualCredit);

    GdPointRefreshEngine.PointEvent debit = new GdPointRefreshEngine.PointEvent('SALE_DEBIT', GdPointRefreshEngine.EVENT_DEBIT, d.addDays(1), 120);
    events.add(debit);

    GdPointRefreshEngine.Result result = new GdPointRefreshEngine().simulate(events);

    System.assertEquals(180, result.totalRemaining);
    System.assertEquals('MANUAL_UI_CREDIT', result.allocations[0].creditBucketKey);
  }
}