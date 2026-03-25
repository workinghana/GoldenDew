@IsTest
private class GdSaleDepositServiceImplTest {
  private static final String TEST_MEMBER_NO = 'SD-001';
  private static final String TEST_SALE_NO = 'SALE-001';
  private static final String TEST_STORE_CODE = 'STORE-01';

  private class VoucherServiceStubProvider implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbedObject,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      if (methodName == 'redeemVoucherV2') {
        return ApiResult.ok(200, '쿠폰 사용 성공', new Map<String, Object>{ 'voucher' => 'USED' });
      }
      if (methodName == 'redeemCancelVoucher') {
        return ApiResult.ok(200, '쿠폰 사용 취소 성공', new Map<String, Object>{ 'voucher' => 'CANCELED' });
      }
      return null;
    }
  }

  private class PointServiceStubProvider implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbedObject,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      if (methodName == 'debitPoint') {
        return new List<GdSaleApiController.PointDebitDTO>{ new GdSaleApiController.PointDebitDTO() };
      }

      if (methodName == 'cancelPointRedemption') {
        return new Map<String, Object>{ 'result' => 'cancelPointRedemption' };
      }

      if (methodName == 'creditPointsOnPurchaseV2') {
        return new List<PointCreditDTO>{ new PointCreditDTO() };
      }

      if (methodName == 'cancelPointsCreditedOnPurchase') {
        return new List<GdSaleApiController.PointDebitDTO>{ new GdSaleApiController.PointDebitDTO() };
      }

      if (methodName == 'isAccrualEligible') {
        TransactionJournal tj = (TransactionJournal) args[0];
        return tj != null && tj.PaymentMethod != '81' && tj.DepositType__c != '03';
      }

      if (methodName == 'creditPointsOnPurchaseByGrade') {
        return new List<PointCreditDTO>{ new PointCreditDTO() };
      }

      if (methodName == 'debitPointsOnPurchaseByGrade') {
        return new List<PointDebitDTO>{ new PointDebitDTO() };
      }

      return null;
    }
  }

  private class MemberTierServiceStubProvider implements System.StubProvider {
    public Object handleMethodCall(
      Object stubbedObject,
      String methodName,
      Type returnType,
      List<Type> paramTypes,
      List<String> paramNames,
      List<Object> args
    ) {
      if (methodName == 'resolveAccrualGrade') {
        return '02';
      }
      return null;
    }
  }

  @TestSetup
  static void setupData() {
    Contact con = new Contact(LastName = 'SaleTester', Grade__c = '02', PreviousGrade__c = '01', MemberNo__c = TEST_MEMBER_NO);
    insert con;

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'Sale Program', IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpm = new LoyaltyProgramMember(
      MembershipNumber = TEST_MEMBER_NO,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = con.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert lpm;

    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'Sale Tier Group',
      LoyaltyProgramId = lp.Id,
      QpResetPeriod = 'Years',
      QpResetDate = Date.today(),
      QpResetFrequency = 1
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(Name = 'Tier-Gold', LoyaltyTierGroupId = tierGroup.Id);
    insert tier;

    insert new LoyaltyMemberTier(LoyaltyMemberId = lpm.Id, LoyaltyTierId = tier.Id, Name = '02');

    Account store = new Account(Name = '테스트 매장', StoreCode__c = TEST_STORE_CODE, StoreType__c = '01');
    insert store;

    Order ord = new Order(
      Name = 'TEST-SALE-ORDER',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      OrderNo__c = 'ORDER-001',
      SaleNo__c = TEST_SALE_NO,
      ActualPaymentAmount__c = 100000,
      IsReductionOrder = false,
      MemberNo__c = con.Id,
      InsertId__c = 'USER-001',
      StoreCode__c = store.Id,
      AccountId = store.Id
    );
    insert ord;

    JournalType depositType = new JournalType(Name = 'Deposit');
    JournalType depositReversalType = new JournalType(Name = 'Deposit Reversal');
    JournalType redemptionType = new JournalType(Name = 'Redemption');
    JournalType redemptionReversalType = new JournalType(Name = 'Redemption Reversal');
    insert new List<JournalType>{ depositType, depositReversalType, redemptionType, redemptionReversalType };

    insert new List<JournalSubType>{
      new JournalSubType(Name = 'Sale Deposit', JournalTypeId = depositType.Id),
      new JournalSubType(Name = 'Order Deposit Reversal', JournalTypeId = depositReversalType.Id),
      new JournalSubType(Name = 'Point Debit', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Point Redeem Cancel', JournalTypeId = redemptionReversalType.Id),
      new JournalSubType(Name = 'Coupon Redeem', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Coupon Redeem Cancel', JournalTypeId = redemptionReversalType.Id)
    };
  }

  private static void setMockServices() {
    GdVoucherService voucherStub = (GdVoucherService) Test.createStub(GdVoucherService.class, new VoucherServiceStubProvider());
    GdPointService pointStub = (GdPointService) Test.createStub(GdPointService.class, new PointServiceStubProvider());
    GdMemberTierService tierStub = (GdMemberTierService) Test.createStub(GdMemberTierService.class, new MemberTierServiceStubProvider());

    GdSaleDepositServiceImpl.setVoucherService(voucherStub);
    GdSaleDepositServiceImpl.setPointService(pointStub);
    GdSaleDepositServiceImpl.setMemberTierService(tierStub);
  }

  private static Order getTestOrder() {
    return [
      SELECT Id, SaleNo__c, MemberNo__c, StoreCode__c, StoreCode__r.StoreType__c, EndDate
      FROM Order
      WHERE SaleNo__c = :TEST_SALE_NO
      LIMIT 1
    ];
  }

  private static Id getJournalTypeId(String name) {
    return [
      SELECT Id
      FROM JournalType
      WHERE Name = :name
      LIMIT 1
    ]
    .Id;
  }

  private static Id getJournalSubTypeId(String name) {
    return [
      SELECT Id
      FROM JournalSubType
      WHERE Name = :name
      LIMIT 1
    ]
    .Id;
  }

  @IsTest
  static void createSaleDepositHistory_missingRequired_throws() {
    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.createSaleDepositHistory(new Map<String, Object>());
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void createSaleDepositHistory_success_generalPayment() {
    setMockServices();

    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();
    Order ord = getTestOrder();

    OrderItem oi1 = new OrderItem();
    oi1.UnitPrice = 10000;
    oi1.Quantity = 1;
    oi1.IsExclude__c = false;

    OrderItem oi2 = new OrderItem();
    oi2.UnitPrice = 5000;
    oi2.Quantity = 1;
    oi2.IsExclude__c = true;

    Map<String, Object> reqData = new Map<String, Object>{
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'SALEDEP001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '01',
          'TransactionAmount' => 10000
        }
      },
      'MemberNo__c' => TEST_MEMBER_NO,
      'orderId' => ord.Id,
      'InsertId__c' => 'USER-001',
      'ActualPaymentAmount__c' => 100000,
      'StoreCode__c' => TEST_STORE_CODE,
      'oiList' => new List<Object>{ oi1, oi2 }
    };

    Test.startTest();
    ApiResult result = svc.createSaleDepositHistory(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    List<TransactionJournal> tjList = [
      SELECT Id, DepositNo__c, SaleId__c, OrderId, PaymentMethod
      FROM TransactionJournal
      WHERE DepositNo__c = 'SALEDEP001-1'
    ];
    System.assertEquals(1, tjList.size());
    System.assertEquals(ord.Id, tjList[0].SaleId__c);
  }

  // @IsTest
  // static void createSaleDepositHistory_success_pointPayment() {
  //   setMockServices();

  //   GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();
  //   Order ord = getTestOrder();

  //   OrderItem oi1 = new OrderItem();
  //   oi1.UnitPrice = 10000;
  //   oi1.Quantity = 1;
  //   oi1.IsExclude__c = false;

  //   Map<String, Object> reqData = new Map<String, Object>{
  //     'TransactionJournal' => new List<Object>{
  //       new Map<String, Object>{
  //         'DepositNo__c' => 'SALEPOINT001',
  //         'DeposiSeqNo__c' => '1',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => '81',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 3000
  //       }
  //     },
  //     'MemberNo__c' => TEST_MEMBER_NO,
  //     'orderId' => ord.Id,
  //     'InsertId__c' => 'USER-001',
  //     'ActualPaymentAmount__c' => 100000,
  //     'StoreCode__c' => TEST_STORE_CODE,
  //     'oiList' => new List<Object>{ oi1 }
  //   };

  //   Test.startTest();
  //   ApiResult result = svc.createSaleDepositHistory(reqData);
  //   Test.stopTest();

  //   System.assertNotEquals(null, result);
  //   System.assertEquals(200, result.code);
  // }

  @IsTest
  static void createSaleDepositHistory_pointOverEarnable_throws() {
    setMockServices();

    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();
    Order ord = getTestOrder();

    OrderItem oi1 = new OrderItem();
    oi1.UnitPrice = 1000;
    oi1.Quantity = 1;
    oi1.IsExclude__c = false;

    Boolean thrown = false;

    try {
      svc.createSaleDepositHistory(
        new Map<String, Object>{
          'TransactionJournal' => new List<Object>{
            new Map<String, Object>{
              'DepositNo__c' => 'SALEPOINT002',
              'DeposiSeqNo__c' => '1',
              'ActivityDate' => Date.today(),
              'PaymentMethod' => '81',
              'DepositType__c' => '01',
              'TransactionAmount' => 5000
            }
          },
          'MemberNo__c' => TEST_MEMBER_NO,
          'orderId' => ord.Id,
          'InsertId__c' => 'USER-001',
          'ActualPaymentAmount__c' => 100000,
          'StoreCode__c' => TEST_STORE_CODE,
          'oiList' => new List<Object>{ oi1 }
        }
      );
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void upsertSaleDeposit_missingRequired_throws() {
    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.upsertSaleDeposit(new Map<String, Object>());
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void upsertSaleDeposit_success_generalPayment() {
    setMockServices();

    Order ord = getTestOrder();
    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    TransactionJournal oldTj = new TransactionJournal(
      DepositNo__c = 'UPSALE001-1',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today().addDays(-1),
      ActivityDate = Datetime.now().addDays(-1),
      PaymentMethod = '11',
      DepositType__c = '01',
      TransactionAmount = 1000,
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = ord.Id,
      SaleId__c = ord.Id,
      JournalTypeId = getJournalTypeId('Deposit'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit'),
      Status = 'Processed'
    );
    insert oldTj;

    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.upsertSaleDeposit(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'UPSALE001',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '11',
            'DepositType__c' => '01',
            'TransactionAmount' => 3000
          }
        },
        'orderId' => ord.Id
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void upsertSaleDeposit_success_pointAndCoupon() {
    setMockServices();

    Order ord = getTestOrder();
    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.upsertSaleDeposit(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'UPSALEPOINT',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '81',
            'DepositType__c' => '01',
            'TransactionAmount' => 1000
          },
          new Map<String, Object>{
            'DepositNo__c' => 'UPSALECOUPON',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '11',
            'DepositType__c' => '03',
            'TransactionAmount' => 1000,
            'CouponNo' => 'CP-001'
          }
        },
        'orderId' => ord.Id
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void getSaleDepositList_notFound_throws() {
    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.getSaleDepositList('SALE-NOT-FOUND');
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void getSaleDepositList_success() {
    setMockServices();

    Order ord = getTestOrder();
    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    insert new TransactionJournal(
      DepositNo__c = 'GETSALE001-1',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '01',
      TransactionAmount = 12000,
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = ord.Id,
      SaleId__c = ord.Id,
      Status = 'Processed',
      JournalTypeId = getJournalTypeId('Deposit'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit')
    );

    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.getSaleDepositList(TEST_SALE_NO);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void deleteAllSaleDeposits_notFound_throws() {
    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.deleteAllSaleDeposits('801000000000000AAA');
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteAllSaleDeposits_success() {
    setMockServices();

    Order ord = getTestOrder();
    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    insert new List<TransactionJournal>{
      new TransactionJournal(
        DepositNo__c = 'DELALLSALE001',
        DeposiSeqNo__c = '1',
        JournalDate = Date.today(),
        ActivityDate = Datetime.now(),
        PaymentMethod = '81',
        DepositType__c = '01',
        TransactionAmount = 1000,
        MemberId = lpm.Id,
        LoyaltyProgramId = lpm.ProgramId,
        OrderId = ord.Id,
        SaleId__c = ord.Id,
        Status = 'Processed',
        JournalTypeId = getJournalTypeId('Redemption'),
        JournalSubTypeId = getJournalSubTypeId('Point Debit'),
        IsDeleted__c = false
      ),
      new TransactionJournal(
        DepositNo__c = 'DELALLSALE002',
        DeposiSeqNo__c = '1',
        JournalDate = Date.today(),
        ActivityDate = Datetime.now(),
        PaymentMethod = '11',
        DepositType__c = '01',
        TransactionAmount = 2000,
        MemberId = lpm.Id,
        LoyaltyProgramId = lpm.ProgramId,
        OrderId = ord.Id,
        SaleId__c = ord.Id,
        Status = 'Processed',
        JournalTypeId = getJournalTypeId('Redemption'),
        JournalSubTypeId = getJournalSubTypeId('Coupon Redeem'),
        IsDeleted__c = false,
        VoucherCode = 'CP-DEL-001'
      )
    };

    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.deleteAllSaleDeposits(ord.Id);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void deleteSaleDeposit_notFound_throws() {
    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.deleteSaleDeposit('DEP-NOT-FOUND');
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteSaleDeposit_success_pointDebit() {
    setMockServices();

    Order ord = getTestOrder();
    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    TransactionJournal tj = new TransactionJournal(
      DepositNo__c = 'DELSALE001',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '81',
      DepositType__c = '01',
      TransactionAmount = 1000,
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = ord.Id,
      SaleId__c = ord.Id,
      Status = 'Processed',
      JournalTypeId = getJournalTypeId('Redemption'),
      JournalSubTypeId = getJournalSubTypeId('Point Debit'),
      IsDeleted__c = false
    );
    insert tj;

    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.deleteSaleDeposit('DELSALE001');
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void deleteSaleDeposit_success_generalDeposit() {
    setMockServices();

    Order ord = getTestOrder();
    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    TransactionJournal tj = new TransactionJournal(
      DepositNo__c = 'DELSALE002',
      DeposiSeqNo__c = '1',
      JournalDate = Date.today(),
      ActivityDate = Datetime.now(),
      PaymentMethod = '11',
      DepositType__c = '01',
      TransactionAmount = 1000,
      MemberId = lpm.Id,
      LoyaltyProgramId = lpm.ProgramId,
      OrderId = ord.Id,
      SaleId__c = ord.Id,
      Status = 'Processed',
      JournalTypeId = getJournalTypeId('Deposit'),
      JournalSubTypeId = getJournalSubTypeId('Sale Deposit'),
      IsDeleted__c = false
    );
    insert tj;

    GdSaleDepositServiceImpl svc = new GdSaleDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.deleteSaleDeposit('DELSALE002');
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }
}