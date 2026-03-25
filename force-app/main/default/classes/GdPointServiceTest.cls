@IsTest
private class GdPointServiceTest {
  @IsTest
  static void interface_and_impl_exist() {
    Type ifaceType = Type.forName('GdPointService');
    Type implType = Type.forName('GdPointServiceImpl');
    System.assertNotEquals(null, ifaceType);
    System.assertNotEquals(null, implType);

    GdPointService svc = new GdPointServiceImpl();
    System.assertNotEquals(null, svc);
  }

  @IsTest
  static void isAccrualEligible_true_case() {
    GdPointServiceImpl svc = new GdPointServiceImpl();
    TransactionJournal tj = new TransactionJournal();
    tj.DepositType__c = '01';
    tj.PaymentMethod = '10';
    tj.TransactionAmount = 100;

    System.assertEquals(true, svc.isAccrualEligible(tj));
  }

  @IsTest
  static void isAccrualEligible_false_cases() {
    GdPointServiceImpl svc = new GdPointServiceImpl();

    TransactionJournal invalidDepositType = new TransactionJournal();
    invalidDepositType.DepositType__c = '99';
    invalidDepositType.PaymentMethod = '10';
    invalidDepositType.TransactionAmount = 100;
    System.assertEquals(false, svc.isAccrualEligible(invalidDepositType));

    TransactionJournal excludedPayment = new TransactionJournal();
    excludedPayment.DepositType__c = '01';
    excludedPayment.PaymentMethod = '20';
    excludedPayment.TransactionAmount = 100;
    System.assertEquals(false, svc.isAccrualEligible(excludedPayment));

    TransactionJournal zeroAmount = new TransactionJournal();
    zeroAmount.DepositType__c = '01';
    zeroAmount.PaymentMethod = '10';
    zeroAmount.TransactionAmount = 0;
    System.assertEquals(false, svc.isAccrualEligible(zeroAmount));
  }

  @IsTest
  static void cancelRateSorter_orders_expected() {
    List<GdPointServiceImpl.CancelPurchasePoints> items = new List<GdPointServiceImpl.CancelPurchasePoints>{
      new GdPointServiceImpl.CancelPurchasePoints(10, null, 'B', 2),
      new GdPointServiceImpl.CancelPurchasePoints(10, null, 'A', 1),
      new GdPointServiceImpl.CancelPurchasePoints(10, null, 'N', null)
    };

    items.sort(new GdPointServiceImpl.CancelRateSorter());

    System.assertEquals(1, items[0].rate);
    System.assertEquals(2, items[1].rate);
    System.assertEquals(null, items[2].rate);
  }

  @IsTest
  static void usageBucketCancelSorter_compare_expected() {
    Date older = Date.newInstance(2026, 1, 1);
    Date newer = Date.newInstance(2026, 1, 2);

    GdPointServiceImpl.UsageBucket a = new GdPointServiceImpl.UsageBucket(null, newer, 'Alpha', 2, null, null, null);
    GdPointServiceImpl.UsageBucket b = new GdPointServiceImpl.UsageBucket(null, older, 'Beta', 1, null, null, null);

    GdPointServiceImpl.UsageBucketCancelSorter sorter = new GdPointServiceImpl.UsageBucketCancelSorter();
    Integer compared = sorter.compare(a, b);

    System.assertEquals(-1, compared);
  }
}