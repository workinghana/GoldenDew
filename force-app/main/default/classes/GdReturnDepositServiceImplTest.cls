@IsTest
private class GdReturnDepositServiceImplTest {
  private static final String TEST_MEMBER_NO = 'RT-001';
  private static final String ORIGINAL_ORDER_NO = 'ORD-ORIGINAL-001';
  private static final String RETURN_ORDER_NO = 'ORD-RETURN-001';

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
        return ApiResult.ok(200, '쿠폰 처리 성공', new Map<String, Object>{
          'voucher' => 'VOUCHER_OK'
        });
      }

      if (methodName == 'redeemCancelVoucher') {
        return ApiResult.ok(200, '쿠폰 취소 성공', new Map<String, Object>{
          'voucher' => 'VOUCHER_CANCEL_OK'
        });
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
      if (methodName == 'cancelPointRedemption') {
        return new Map<String, Object>{
          'result' => 'cancel-ok'
        };
      }

      if (methodName == 'debitPoint') {
        return new List<GdSaleApiController.PointDebitDTO>();
      }

      if (methodName == 'creditPointsOnPurchase') {
        return new List<PointCreditDTO>{
          new PointCreditDTO()
        };
      }

      if (methodName == 'cancelPointsCreditedOnPurchase') {
        return new List<GdSaleApiController.PointDebitDTO>();
      }

      if (methodName == 'debitSpecificPoints') {
        return new List<GdSaleApiController.PointDebitDTO>();
      }

      if (methodName == 'creditSepcificPoints') {
        return new List<PointCreditDTO>{
          new PointCreditDTO()
        };
      }

      if (methodName == 'creditPointsOnPurchaseByGrade') {
        return new List<PointCreditDTO>{
          new PointCreditDTO()
        };
      }

      return null;
    }
  }

  @TestSetup
  static void setupData() {
    Contact con = new Contact(
      LastName = 'ReturnTester',
      Grade__c = '02',
      PreviousGrade__c = '01',
      MemberNo__c = TEST_MEMBER_NO
    );
    insert con;

    LoyaltyProgram lp = new LoyaltyProgram(
      Name = 'Return Program',
      IsPrimary = true
    );
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
      Name = 'Return Tier Group',
      LoyaltyProgramId = lp.Id,
      QpResetPeriod = 'Years',
      QpResetDate = Date.today(),
      QpResetFrequency = 1
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(
      Name = 'Tier-Gold',
      LoyaltyTierGroupId = tierGroup.Id
    );
    insert tier;

    insert new LoyaltyMemberTier(
      LoyaltyMemberId = lpm.Id,
      LoyaltyTierId = tier.Id,
      Name = '02'
    );

    Account acnt = new Account(
      Name = 'TEST-ACCOUNT'
    );
    insert acnt;

    Order originalOrder = new Order(
      Name = 'Original Order',
      EffectiveDate = Date.today().addDays(-10),
      EndDate = Date.today().addDays(-10),
      Status = 'Draft',
      OrderNo__c = ORIGINAL_ORDER_NO,
      SaleNo__c = 'SALE-ORIGINAL-001',
      ActualPaymentAmount__c = 100000,
      IsReductionOrder = false,
      MemberNo__c = con.Id,
      InsertId__c = 'USER-001',
      AccountId = acnt.Id
    );
    insert originalOrder;

    Order returnOrder = new Order(
      Name = 'Return Order',
      EffectiveDate = Date.today(),
      EndDate = Date.today(),
      Status = 'Draft',
      OrderNo__c = RETURN_ORDER_NO,
      SaleNo__c = 'SALE-RETURN-001',
      ActualPaymentAmount__c = 50000,
      IsReductionOrder = false,
      MemberNo__c = con.Id,
      InsertId__c = 'USER-002',
      AccountId = acnt.Id
    );
    insert returnOrder;

    JournalType depositType = new JournalType(Name = 'Deposit');
    JournalType depositReversalType = new JournalType(Name = 'Deposit Reversal');
    JournalType redemptionType = new JournalType(Name = 'Redemption');
    JournalType redemptionReversalType = new JournalType(Name = 'Redemption Reversal');
    JournalType accrualType = new JournalType(Name = 'Accrual');
    JournalType accrualReversalType = new JournalType(Name = 'Accrual Reversal');
    insert new List<JournalType>{
      depositType,
      depositReversalType,
      redemptionType,
      redemptionReversalType,
      accrualType,
      accrualReversalType
    };

    insert new List<JournalSubType>{
      new JournalSubType(
        Name = 'Sale Deposit',
        JournalTypeId = depositType.Id
      ),
      new JournalSubType(
        Name = 'Sale Deposit Reversal',
        JournalTypeId = depositReversalType.Id
      ),
      new JournalSubType(
        Name = 'Coupon Redeem',
        JournalTypeId = redemptionType.Id
      ),
      new JournalSubType(
        Name = 'Coupon Redeem Cancel',
        JournalTypeId = redemptionReversalType.Id
      ),
      new JournalSubType(
        Name = 'Point Redeem Cancel',
        JournalTypeId = redemptionReversalType.Id
      ),
      new JournalSubType(
        Name = 'Cancel Purchase Accrual',
        JournalTypeId = accrualReversalType.Id
      )
    };
  }

  private static void setMockServices() {
    GdVoucherService voucherStub = (GdVoucherService) Test.createStub(
      GdVoucherService.class,
      new VoucherServiceStubProvider()
    );
    GdPointService pointStub = (GdPointService) Test.createStub(
      GdPointService.class,
      new PointServiceStubProvider()
    );

    GdReturnDepositServiceImpl.setVoucherService(voucherStub);
    GdReturnDepositServiceImpl.setPointService(pointStub);
  }

  private static Order getOriginalOrder() {
    return [
      SELECT Id, OrderNo__c, MemberNo__c, EndDate, ActualPaymentAmount__c, InsertId__c
      FROM Order
      WHERE OrderNo__c = :ORIGINAL_ORDER_NO
      LIMIT 1
    ];
  }

  private static Order getReturnOrder() {
    return [
      SELECT Id, OrderNo__c, MemberNo__c, EndDate, ActualPaymentAmount__c, InsertId__c
      FROM Order
      WHERE OrderNo__c = :RETURN_ORDER_NO
      LIMIT 1
    ];
  }

  private static Id getJournalSubTypeId(String name) {
    return [
      SELECT Id
      FROM JournalSubType
      WHERE Name = :name
      LIMIT 1
    ].Id;
  }

  private static Id getJournalTypeId(String name) {
    return [
      SELECT Id
      FROM JournalType
      WHERE Name = :name
      LIMIT 1
    ].Id;
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_missingRequired_throws() {
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.insertSaleDepositHistoryByUpdate(new Map<String, Object>());
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_saleDeposit() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-TEST',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTDEP001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '01',
          'TransactionAmount' => 10000
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    List<TransactionJournal> tjList = [
      SELECT Id, DepositNo__c, SaleId__c, OrderId, PaymentMethod, DepositType__c
      FROM TransactionJournal
      WHERE DepositNo__c = 'RTDEP001-1'
    ];
    System.assertEquals(1, tjList.size());
    System.assertEquals(returnOrder.Id, tjList[0].SaleId__c);
    System.assertEquals(originalOrder.Id, tjList[0].OrderId);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_pointAndCoupon() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-TEST',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTPOINT001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '81',
          'DepositType__c' => '03',
          'TransactionAmount' => 3000
        },
        new Map<String, Object>{
          'DepositNo__c' => 'RTCOUPON001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '01',
          'TransactionAmount' => 1000,
          'CouponNo' => 'CP-001'
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void deleteAllReturnDeposits_notFound_throws() {
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.deleteAllReturnDeposits('801000000000000AAA');
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteAllReturnDeposits_success_cancelPurchaseAccrual() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    TransactionJournal tj = new TransactionJournal();
    tj.DepositNo__c = 'DELALL001';
    tj.DeposiSeqNo__c = '1';
    tj.JournalDate = Date.today();
    tj.ActivityDate = Datetime.now();
    tj.PaymentMethod = '11';
    tj.DepositType__c = '03';
    tj.TransactionAmount = 5000;
    tj.OrderId = originalOrder.Id;
    tj.SaleId__c = returnOrder.Id;
    tj.LoyaltyProgramId = [
      SELECT ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ].ProgramId;
    tj.MemberId = [
      SELECT Id
      FROM LoyaltyProgramMember
      LIMIT 1
    ].Id;
    tj.JournalTypeId = getJournalTypeId('Accrual Reversal');
    tj.JournalSubTypeId = getJournalSubTypeId('Cancel Purchase Accrual');
    tj.Status = 'Processed';
    tj.IsDeleted__c = false;
    insert tj;

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.deleteAllReturnDeposits(returnOrder.Id);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    TransactionJournal updatedTj = [
      SELECT Id, IsDeleted__c, DeleteDateTime__c
      FROM TransactionJournal
      WHERE Id = :tj.Id
    ];
    System.assertEquals(true, updatedTj.IsDeleted__c);
    System.assertNotEquals(null, updatedTj.DeleteDateTime__c);
  }

  @IsTest
  static void deleteReturnDeposit_notFound_throws() {
    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Boolean thrown = false;

    try {
      svc.deleteReturnDeposit('DEP-NOT-FOUND');
    } catch (Exception e) {
      thrown = true;
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void deleteReturnDeposit_success_couponRedeemCancel() {
    setMockServices();

    Order originalOrder = getOriginalOrder();

    TransactionJournal tj = new TransactionJournal();
    tj.DepositNo__c = 'DELONE001';
    tj.DeposiSeqNo__c = '1';
    tj.JournalDate = Date.today();
    tj.ActivityDate = Datetime.now();
    tj.PaymentMethod = '11';
    tj.DepositType__c = '03';
    tj.TransactionAmount = 2000;
    tj.OrderId = originalOrder.Id;
    tj.SaleId__c = getReturnOrder().Id;
    tj.LoyaltyProgramId = [
      SELECT ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ].ProgramId;
    tj.MemberId = [
      SELECT Id
      FROM LoyaltyProgramMember
      LIMIT 1
    ].Id;
    tj.JournalTypeId = getJournalTypeId('Redemption Reversal');
    tj.JournalSubTypeId = getJournalSubTypeId('Coupon Redeem Cancel');
    tj.Status = 'Processed';
    tj.IsDeleted__c = false;
    tj.VoucherCode = 'CP-DEL-001';
    insert tj;

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.deleteReturnDeposit('DELONE001');
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    TransactionJournal updatedTj = [
      SELECT Id, IsDeleted__c, DeleteDateTime__c
      FROM TransactionJournal
      WHERE Id = :tj.Id
    ];
    System.assertEquals(true, updatedTj.IsDeleted__c);
    System.assertNotEquals(null, updatedTj.DeleteDateTime__c);
  }
  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_saleDepositReversal() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-REV',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTREV001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 7000
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    List<TransactionJournal> tjList = [
      SELECT Id, DepositNo__c, DepositType__c, SaleId__c, OrderId
      FROM TransactionJournal
      WHERE DepositNo__c = 'RTREV001-1'
    ];
    System.assertEquals(1, tjList.size());
    System.assertEquals('03', tjList[0].DepositType__c);
    System.assertEquals(returnOrder.Id, tjList[0].SaleId__c);
    System.assertEquals(originalOrder.Id, tjList[0].OrderId);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_pointDebit() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-POINT',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTPOINT002',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '81',
          'DepositType__c' => '01',
          'TransactionAmount' => 1500
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void insertSaleDepositHistoryByUpdate_success_couponCancel() {
    setMockServices();

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();
    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    Map<String, Object> reqData = new Map<String, Object>{
      'orderId' => returnOrder.Id,
      'originalOrderId' => originalOrder.Id,
      'InsertId__c' => 'USER-COUPON',
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'RTCOUPON002',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '03',
          'TransactionAmount' => 1000,
          'CouponNo' => 'CP-002'
        }
      }
    };

    Test.startTest();
    ApiResult result = svc.insertSaleDepositHistoryByUpdate(reqData);
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);
  }

  @IsTest
  static void deleteReturnDeposit_success_saleDepositReversal_currentGrade() {
    setMockServices();

    Order originalOrder = getOriginalOrder();
    Order returnOrder = getReturnOrder();

    LoyaltyProgramMember lpm = [
      SELECT Id, ProgramId
      FROM LoyaltyProgramMember
      LIMIT 1
    ];

    TransactionJournal tj = new TransactionJournal();
    tj.DepositNo__c = 'DELONESALE001';
    tj.DeposiSeqNo__c = '1';
    tj.JournalDate = Date.today();
    tj.ActivityDate = Datetime.now();
    tj.PaymentMethod = '11';
    tj.DepositType__c = '03';
    tj.TransactionAmount = 8000;
    tj.OrderId = originalOrder.Id;
    tj.SaleId__c = returnOrder.Id;
    tj.LoyaltyProgramId = lpm.ProgramId;
    tj.MemberId = lpm.Id;
    tj.JournalTypeId = getJournalTypeId('Deposit Reversal');
    tj.JournalSubTypeId = getJournalSubTypeId('Sale Deposit Reversal');
    tj.Status = 'Processed';
    tj.IsDeleted__c = false;
    tj.InsertId__c = 'USER-SALE-DEL';
    insert tj;

    GdReturnDepositServiceImpl svc = new GdReturnDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.deleteReturnDeposit('DELONESALE001');
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assertEquals(200, result.code);

    TransactionJournal updatedTj = [
      SELECT Id, IsDeleted__c, DeleteDateTime__c
      FROM TransactionJournal
      WHERE Id = :tj.Id
    ];
    System.assertEquals(true, updatedTj.IsDeleted__c);
    System.assertNotEquals(null, updatedTj.DeleteDateTime__c);
  }
}