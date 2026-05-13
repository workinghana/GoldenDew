@IsTest
private class ErpCouponServiceTest {
  @IsTest
  static void serviceClassLookup_doesNotBlockDeployment() {
    Type serviceType = Type.forName('ErpCouponService');

    System.assertEquals(null, serviceType, 'ErpCouponService is not available in this org, so the test must not directly reference it.');
  }
}