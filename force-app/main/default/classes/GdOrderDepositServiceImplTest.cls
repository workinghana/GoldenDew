@IsTest
private class GdOrderDepositServiceImplTest {
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

  private static final String TEST_MEMBER_NO_1 = 'MT-001';
  private static final String TEST_MEMBER_NO_2 = 'MT-002';
  private static final String TEST_MEMBER_NO_3 = 'MT-003';
  private static final String TEST_ORDER_NO = 'ORD-001';

  /**
   * Voucher Service Stub
   */
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
        return null;
      }
      if (methodName == 'redeemCancelVoucher') {
        return null;
      }
      return null;
    }
  }

  /**
   * Point Service Stub
   */
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
        return new List<GdSaleApiController.PointDebitDTO>();
      }
      if (methodName == 'cancelPointRedemption') {
        return new Map<String, Object>{ 'result' => 'success' };
      }
      return null;
    }
  }

  @TestSetup
  static void setupData() {
    Test.setMock(HttpCalloutMock.class, new SuccessCalloutMock());

    Contact cWithPrev = new Contact(LastName = 'TierUser1', Grade__c = '02', PreviousGrade__c = '01', MemberNo__c = TEST_MEMBER_NO_1);
    Contact cWithoutPrev = new Contact(LastName = 'TierUser2', Grade__c = '02', MemberNo__c = TEST_MEMBER_NO_2);
    Contact cNoTier = new Contact(LastName = 'TierUser3', Grade__c = '02', PreviousGrade__c = '02', MemberNo__c = TEST_MEMBER_NO_3);
    insert new List<Contact>{ cWithPrev, cWithoutPrev, cNoTier };

    LoyaltyProgram lp = new LoyaltyProgram(Name = 'TierProgram', IsPrimary = true);
    insert lp;

    LoyaltyProgramMember lpmWithPrev = new LoyaltyProgramMember(
      MembershipNumber = TEST_MEMBER_NO_1,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = cWithPrev.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    LoyaltyProgramMember lpmWithoutPrev = new LoyaltyProgramMember(
      MembershipNumber = TEST_MEMBER_NO_2,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = cWithoutPrev.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    LoyaltyProgramMember lpmNoTier = new LoyaltyProgramMember(
      MembershipNumber = TEST_MEMBER_NO_3,
      MemberStatus = 'Active',
      MemberType = 'Individual',
      ContactId = cNoTier.Id,
      EnrollmentDate = Date.today(),
      ProgramId = lp.Id
    );
    insert new List<LoyaltyProgramMember>{ lpmWithPrev, lpmWithoutPrev, lpmNoTier };

    LoyaltyTierGroup tierGroup = new LoyaltyTierGroup(
      Name = 'Test Tier Group',
      LoyaltyProgramId = lp.Id,
      QpResetPeriod = 'Years',
      QpResetDate = Date.today(),
      QpResetFrequency = 1
    );
    insert tierGroup;

    LoyaltyTier tier = new LoyaltyTier(Name = 'Tier-Gold', LoyaltyTierGroupId = tierGroup.Id);
    insert tier;

    insert new List<LoyaltyMemberTier>{
      new LoyaltyMemberTier(LoyaltyMemberId = lpmWithPrev.Id, LoyaltyTierId = tier.Id, Name = '02'),
      new LoyaltyMemberTier(LoyaltyMemberId = lpmWithoutPrev.Id, LoyaltyTierId = tier.Id, Name = '02')
    };

    Account storeDept = new Account(Name = '백화점 매장', StoreCode__c = 'STORE-01', StoreTypeFour__c = '01');
    Account storeOutlet = new Account(Name = '아울렛 매장', StoreCode__c = 'STORE-05', StoreTypeFour__c = '05');
    Account storeEtc = new Account(Name = '기타 매장', StoreCode__c = 'STORE-99', StoreTypeFour__c = '99');
    insert new List<Account>{ storeDept, storeOutlet, storeEtc };

    Contact orderContact = [
      SELECT Id
      FROM Contact
      WHERE MemberNo__c = :TEST_MEMBER_NO_1
      LIMIT 1
    ];

    Account acnt = new Account(Name = 'TEST_ACCOUNT');
    insert acnt;

    Order ord = new Order(
      Name = 'TEST-ORDER',
      EffectiveDate = Date.today(),
      Status = 'Draft',
      OrderNo__c = TEST_ORDER_NO,
      SaleNo__c = 'SAL-001',
      ActualPaymentAmount__c = 100000,
      IsReductionOrder__c = false,
      MemberNo__c = orderContact.Id,
      AccountId = acnt.Id
    );
    insert ord;

    JournalType depositType = new JournalType(Name = 'Deposit');
    JournalType depositReversalType = new JournalType(Name = 'Deposit Reversal');
    JournalType redemptionType = new JournalType(Name = 'Redemption');
    JournalType redemptionReversalType = new JournalType(Name = 'Redemption Reversal');
    insert new List<JournalType>{ depositType, depositReversalType, redemptionType, redemptionReversalType };

    insert new List<JournalSubType>{
      new JournalSubType(Name = 'Order Deposit', JournalTypeId = depositType.Id),
      new JournalSubType(Name = 'Order Deposit Reversal', JournalTypeId = depositReversalType.Id),
      new JournalSubType(Name = 'Coupon Redeem', JournalTypeId = redemptionType.Id),
      new JournalSubType(Name = 'Coupon Redeem Cancel', JournalTypeId = redemptionReversalType.Id)
    };
  }

  private static void setMockServices() {
    GdVoucherService voucherStub = (GdVoucherService) Test.createStub(GdVoucherService.class, new VoucherServiceStubProvider());
    GdPointService pointStub = (GdPointService) Test.createStub(GdPointService.class, new PointServiceStubProvider());

    GdOrderDepositServiceImpl.setVoucherService(voucherStub);
    GdOrderDepositServiceImpl.setPointService(pointStub);
  }

  private static Order getTestOrder() {
    return [
      SELECT Id, OrderNo__c, MemberNo__c
      FROM Order
      WHERE OrderNo__c = :TEST_ORDER_NO
      LIMIT 1
    ];
  }

  private static Decimal dec(String value) {
    return Decimal.valueOf(value);
  }

  private static Map<String, Object> buildGeneralCreateReq() {
    Order ord = getTestOrder();

    OrderItem oi1 = new OrderItem();
    oi1.UnitPrice = 10000;
    oi1.Quantity = 1;
    oi1.IsExclude__c = true;

    return new Map<String, Object>{
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'DEP001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '11',
          'DepositType__c' => '01',
          'TransactionAmount' => dec('10000')
        }
      },
      'MemberNo__c' => TEST_MEMBER_NO_1,
      'orderId' => ord.Id,
      'oiList' => new List<Object>{ oi1 }
    };
  }

  private static Map<String, Object> buildPointCreateReq() {
    Order ord = getTestOrder();

    OrderItem oi1 = new OrderItem();
    oi1.UnitPrice = 10000;
    oi1.Quantity = 1;
    oi1.IsExclude__c = false;

    OrderItem oi2 = new OrderItem();
    oi2.UnitPrice = 5000;
    oi2.Quantity = 1;
    oi2.IsExclude__c = true;

    return new Map<String, Object>{
      'TransactionJournal' => new List<Object>{
        new Map<String, Object>{
          'DepositNo__c' => 'DEPPOINT001',
          'DeposiSeqNo__c' => '1',
          'ActivityDate' => Date.today(),
          'PaymentMethod' => '81',
          'DepositType__c' => '01',
          'TransactionAmount' => dec('3000')
        }
      },
      'MemberNo__c' => TEST_MEMBER_NO_1,
      'orderId' => ord.Id,
      'oiList' => new List<Object>{ oi1, oi2 },
      'Type' => '01',
      'storeTypeFour' => '01',
      'isGoldenBar' => false
    };
  }

  @IsTest
  static void createOrderDepositHistory_missingJournal_throws() {
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Boolean isThrown = false;

    try {
      svc.createOrderDepositHistory(new Map<String, Object>());
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }

  @IsTest
  static void createOrderDepositHistory_missingMemberNo_throws() {
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Boolean isThrown = false;

    try {
      svc.createOrderDepositHistory(new Map<String, Object>{ 'TransactionJournal' => new List<Object>{ new Map<String, Object>() } });
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }

  @IsTest
  static void createOrderDepositHistory_missingOrderId_throws() {
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Boolean isThrown = false;

    try {
      svc.createOrderDepositHistory(
        new Map<String, Object>{ 'TransactionJournal' => new List<Object>{ new Map<String, Object>() }, 'MemberNo__c' => TEST_MEMBER_NO_1 }
      );
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }

  @IsTest
  static void createOrderDepositHistory_memberNotFound_throws() {
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Boolean isThrown = false;

    try {
      svc.createOrderDepositHistory(
        new Map<String, Object>{
          'TransactionJournal' => new List<Object>{
            new Map<String, Object>{
              'DepositNo__c' => 'DEPX',
              'DeposiSeqNo__c' => '1',
              'ActivityDate' => Date.today(),
              'PaymentMethod' => '11',
              'DepositType__c' => '01',
              'TransactionAmount' => dec('1000')
            }
          },
          'MemberNo__c' => 'NOT-FOUND',
          'orderId' => getTestOrder().Id,
          'oiList' => new List<Object>()
        }
      );
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }

  @IsTest
  static void createOrderDepositHistory_success_generalPayment() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();

    Test.startTest();
    ApiResult result = svc.createOrderDepositHistory(buildGeneralCreateReq());
    Test.stopTest();

    System.assertNotEquals(null, result);

    List<TransactionJournal> tjList = [
      SELECT Id, DepositNo__c, PaymentMethod, DepositType__c, Status, OrderId
      FROM TransactionJournal
      WHERE OrderId = :getTestOrder().Id
    ];
    System.assertEquals(1, tjList.size());
    System.assertEquals('11', tjList[0].PaymentMethod);
  }

  // @IsTest
  // static void createOrderDepositHistory_success_pointPayment() {
  //     setMockServices();
  //     GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();

  //     Test.startTest();
  //     ApiResult result = svc.createOrderDepositHistory(buildPointCreateReq());
  //     Test.stopTest();

  //     System.assertNotEquals(null, result);
  // }

  @IsTest
  static void createOrderDepositHistory_pointUseNotAllowedForOutlet_throws() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();

    Order ord = getTestOrder();

    OrderItem oi1 = new OrderItem();
    oi1.UnitPrice = 10000;
    oi1.Quantity = 1;
    oi1.IsExclude__c = false;

    Boolean isThrown = false;

    try {
      svc.createOrderDepositHistory(
        new Map<String, Object>{
          'TransactionJournal' => new List<Object>{
            new Map<String, Object>{
              'DepositNo__c' => 'DEPPOINT002',
              'DeposiSeqNo__c' => '1',
              'ActivityDate' => Date.today(),
              'PaymentMethod' => '81',
              'DepositType__c' => '01',
              'TransactionAmount' => dec('1000')
            }
          },
          'MemberNo__c' => TEST_MEMBER_NO_1,
          'orderId' => ord.Id,
          'oiList' => new List<Object>{ oi1 },
          'Type' => '01',
          'storeTypeFour' => '05',
          'isGoldenBar' => false
        }
      );
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }

  @IsTest
  static void upsertOrderDeposit_missingJournal_throws() {
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Boolean isThrown = false;

    try {
      svc.upsertOrderDeposit(new Map<String, Object>());
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }

  @IsTest
  static void upsertOrderDeposit_missingOrderId_throws() {
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Boolean isThrown = false;

    try {
      svc.upsertOrderDeposit(new Map<String, Object>{ 'TransactionJournal' => new List<Object>{ new Map<String, Object>() } });
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }

  @IsTest
  static void upsertOrderDeposit_lpmNotFound_throws() {
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Boolean isThrown = false;

    try {
      svc.upsertOrderDeposit(
        new Map<String, Object>{
          'TransactionJournal' => new List<Object>{
            new Map<String, Object>{
              'DepositNo__c' => 'UPSERTERR',
              'DeposiSeqNo__c' => '1',
              'ActivityDate' => Date.today(),
              'PaymentMethod' => '11',
              'DepositType__c' => '01',
              'TransactionAmount' => dec('1000')
            }
          },
          'orderId' => '801000000000000AAA'
        }
      );
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }

  @IsTest
  static void upsertOrderDeposit_success_generalPayment() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Order ord = getTestOrder();

    Test.startTest();
    ApiResult result = svc.upsertOrderDeposit(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'UPSERT001',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '11',
            'DepositType__c' => '01',
            'TransactionAmount' => dec('5000')
          }
        },
        'orderId' => ord.Id
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, result);

    List<TransactionJournal> tjList = [
      SELECT Id, DepositNo__c, PaymentMethod, DepositType__c, Status
      FROM TransactionJournal
      WHERE DepositNo__c = 'UPSERT001-1'
    ];
    System.assertEquals(1, tjList.size());
  }

  @IsTest
  static void upsertOrderDeposit_success_generalCancel() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Order ord = getTestOrder();

    Test.startTest();
    ApiResult result = svc.upsertOrderDeposit(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'UPSERT002',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '11',
            'DepositType__c' => '03',
            'TransactionAmount' => dec('5000')
          }
        },
        'orderId' => ord.Id
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, result);

    List<TransactionJournal> tjList = [
      SELECT Id, DepositNo__c, PaymentMethod, DepositType__c, Status
      FROM TransactionJournal
      WHERE DepositNo__c = 'UPSERT002-1'
    ];
    System.assertEquals(1, tjList.size());
  }

  @IsTest
  static void upsertOrderDeposit_success_pointUse() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Order ord = getTestOrder();

    Test.startTest();
    ApiResult result = svc.upsertOrderDeposit(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'UPSERT003',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '81',
            'DepositType__c' => '01',
            'TransactionAmount' => dec('1000')
          }
        },
        'orderId' => ord.Id
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
  }

  @IsTest
  static void upsertOrderDeposit_success_pointCancel() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Order ord = getTestOrder();

    Test.startTest();
    ApiResult result = svc.upsertOrderDeposit(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'UPSERT004',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '81',
            'DepositType__c' => '03',
            'TransactionAmount' => dec('1000')
          }
        },
        'orderId' => ord.Id
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
  }

  @IsTest
  static void upsertOrderDeposit_success_couponUse() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Order ord = getTestOrder();

    Test.startTest();
    ApiResult result = svc.upsertOrderDeposit(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'UPSERT005',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '11',
            'DepositType__c' => '01',
            'TransactionAmount' => dec('1000'),
            'CouponNo' => 'COUPON-005'
          }
        },
        'orderId' => ord.Id
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
  }

  @IsTest
  static void upsertOrderDeposit_success_couponCancel() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Order ord = getTestOrder();

    Test.startTest();
    ApiResult result = svc.upsertOrderDeposit(
      new Map<String, Object>{
        'TransactionJournal' => new List<Object>{
          new Map<String, Object>{
            'DepositNo__c' => 'UPSERT006',
            'DeposiSeqNo__c' => '1',
            'ActivityDate' => Date.today(),
            'PaymentMethod' => '11',
            'DepositType__c' => '03',
            'TransactionAmount' => dec('1000'),
            'CouponNo' => 'COUPON-006'
          }
        },
        'orderId' => ord.Id
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
  }

  @IsTest
  static void upsertOrderDeposit_invalidDepositType_throws() {
    setMockServices();
    GdOrderDepositServiceImpl svc = new GdOrderDepositServiceImpl();
    Order ord = getTestOrder();
    Boolean isThrown = false;

    try {
      svc.upsertOrderDeposit(
        new Map<String, Object>{
          'TransactionJournal' => new List<Object>{
            new Map<String, Object>{
              'DepositNo__c' => 'UPSERT007',
              'DeposiSeqNo__c' => '1',
              'ActivityDate' => Date.today(),
              'PaymentMethod' => '81',
              'DepositType__c' => '99',
              'TransactionAmount' => dec('1000')
            }
          },
          'orderId' => ord.Id
        }
      );
    } catch (Exception e) {
      isThrown = true;
    }

    System.assertEquals(true, isThrown);
  }
}