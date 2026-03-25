@IsTest
private class GdTransactionJournalServiceImplTest {
  // // ===== Mock GdVoucherService =====
  // private class MockVoucherService implements GdVoucherService {
  //     public void issueBirthdayCoupon() {
  //     }
  //     public ApiResult issueSignupCoupon(Map<String, Object> reqData) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult issueSignupCouponV2(Map<String, Object> reqData) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult getAvailableCouponList(Map<String, Object> reqData) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult redeemVoucher(Map<String, Object> reqData) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult redeemVoucherV2(TransactionJournal tj) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult redeemCancelVoucher(TransactionJournal tj) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult issueCoupon(Map<String, Object> reqData) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult updateCoupon(Map<String, Object> reqData) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult deleteCoupon(Map<String, Object> reqData) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult getReturnUsedCoupon(String originalOrderId) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  //     public ApiResult getRedeemCoupon(Map<String, Object> reqData) {
  //         return ApiResult.ok(200, 'mock', null);
  //     }
  // }

  // // ===== 공통 상수 =====
  // private static final String MBR_OK = 'MEM-TJ-001';
  // private static final String MBR_NO_LPM = 'MEM-TJ-NOLPM';
  // private static final String PROMO_OK = 'PROMO-TJ-001';

  // // ===== 공통 헬퍼 =====
  // private static Id ensureStdPricebook() {
  //     Id pbId = Test.getStandardPricebookId();
  //     update new Pricebook2(Id = pbId, IsActive = true);
  //     return pbId;
  // }

  // private static GdTransactionJournalService svc() {
  //     return new GdTransactionJournalServiceImpl();
  // }

  // private static GdTransactionJournalService svcWithMock() {
  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     GdTransactionJournalServiceImpl.setVoucherService(new MockVoucherService());
  //     return impl;
  // }

  // // ===== @testSetup =====
  // @testSetup
  // static void setup() {
  //     Id pbId = ensureStdPricebook();

  //     Account acct = new Account(Name = 'TJ-TestCo');
  //     insert acct;

  //     // 로열티 프로그램
  //     LoyaltyProgram lp = new LoyaltyProgram(
  //         Name = 'TJ-LoyaltyProg',
  //         IsPrimary = true,
  //         Status = 'Active'
  //     );
  //     insert lp;

  //     // 정상 회원 (LPM 있음)
  //     Contact cOk = new Contact(LastName = 'TJ-User', MemberNo__c = MBR_OK);
  //     insert cOk;

  //     LoyaltyProgramMember lpm = new LoyaltyProgramMember(
  //         MembershipNumber = MBR_OK,
  //         MemberStatus = 'Active',
  //         MemberType = 'Individual',
  //         ContactId = cOk.Id,
  //         EnrollmentDate = Date.today(),
  //         ProgramId = lp.Id
  //     );
  //     insert lpm;

  //     // LPM 없는 회원
  //     Contact cNoLpm = new Contact(LastName = 'TJ-NoLpm', MemberNo__c = MBR_NO_LPM);
  //     insert cNoLpm;

  //     // 프로모션
  //     Promotion promo = new Promotion(
  //         Name = 'TJ-Promo',
  //         StartDate = Date.today(),
  //         LoyaltyProgramId = lp.Id
  //     );
  //     insert promo;

  //     // 일반 주문 (회원 없음)
  //     Order ordPlain = new Order(
  //         AccountId = acct.Id,
  //         EffectiveDate = Date.today(),
  //         Status = 'Draft',
  //         Pricebook2Id = pbId,
  //         OrderNo__c = 'ORD-TJ-PLAIN'
  //     );
  //     insert ordPlain;

  //     // 회원 연결 주문 (insertByUpdate 계열용)
  //     Order ordWithMember = new Order(
  //         AccountId = acct.Id,
  //         EffectiveDate = Date.today(),
  //         Status = 'Draft',
  //         Pricebook2Id = pbId,
  //         MemberNo__c = cOk.Id,
  //         OrderNo__c = 'ORD-TJ-MBR',
  //         SaleNo__c = 'SALE-TJ-MBR'
  //     );
  //     insert ordWithMember;

  //     // JournalType / JournalSubType
  //     try {
  //         JournalType jtDeposit = new JournalType(Name = 'Deposit');
  //         JournalType jtAccrual = new JournalType(Name = 'Accrual');
  //         JournalType jtAccrualReversal = new JournalType(Name = 'Accrual Reversal');
  //         JournalType jtRedemption = new JournalType(Name = 'Redemption');
  //         JournalType jtRedemptionRev = new JournalType(Name = 'Redemption Reversal');
  //         JournalType jtDepositReversal = new JournalType(Name = 'Deposit Reversal');
  //         insert new List<JournalType>{
  //             jtDeposit,
  //             jtAccrual,
  //             jtAccrualReversal,
  //             jtRedemption,
  //             jtRedemptionRev,
  //             jtDepositReversal
  //         };

  //         insert new List<JournalSubType>{
  //             new JournalSubType(Name = 'Order Deposit', JournalTypeId = jtDeposit.Id),
  //             new JournalSubType(
  //                 Name = 'Order Deposit Reversal',
  //                 JournalTypeId = jtDepositReversal.Id
  //             ),
  //             new JournalSubType(Name = 'Sale Deposit', JournalTypeId = jtDeposit.Id),
  //             new JournalSubType(
  //                 Name = 'Sale Deposit Reversal',
  //                 JournalTypeId = jtDepositReversal.Id
  //             ),
  //             new JournalSubType(Name = 'Point Debit', JournalTypeId = jtRedemption.Id),
  //             new JournalSubType(
  //                 Name = 'Point Redeem Cancel',
  //                 JournalTypeId = jtRedemptionRev.Id
  //             ),
  //             new JournalSubType(Name = 'Purchase Accrual', JournalTypeId = jtAccrual.Id),
  //             new JournalSubType(
  //                 Name = 'Cancel Purchase Accrual',
  //                 JournalTypeId = jtAccrualReversal.Id
  //             ),
  //             new JournalSubType(Name = 'Coupon Redeem', JournalTypeId = jtRedemption.Id),
  //             new JournalSubType(
  //                 Name = 'Coupon Redeem Cancel',
  //                 JournalTypeId = jtRedemptionRev.Id
  //             )
  //         };
  //     } catch (Exception e) {
  //         System.debug('JournalType/SubType setup skipped: ' + e.getMessage());
  //     }

  //     // LoyaltyProgramCurrency (포인트)
  //     try {
  //         insert new LoyaltyProgramCurrency(Name = '포인트', LoyaltyProgramId = lp.Id);
  //     } catch (Exception e) {
  //         System.debug('LoyaltyProgramCurrency setup skipped: ' + e.getMessage());
  //     }
  // }

  // // ========================================================
  // // createOrderDepositHistory
  // // ========================================================

  // @IsTest
  // static void test_createOrderDeposit_requiredFieldsMissing() {
  //     // TransactionJournal 키 없음 → ValidationException → CustomException
  //     Test.startTest();
  //     try {
  //         svc().createOrderDepositHistory(new Map<String, Object>());
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createOrderDeposit_memberNotFound() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'D001',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 10000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => 'GHOST-MEMBER',
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createOrderDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createOrderDeposit_noLpm() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'D002',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Cash',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 5000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_NO_LPM,
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createOrderDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createOrderDeposit_promotionNotFound() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'D003',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 3000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'PromotionNo__c' => 'PROMO-NOT-EXIST',
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createOrderDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createOrderDeposit_withValidPromotion() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'D004',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 20000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'PromotionNo__c' => PROMO_OK,
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         ApiResult res = svc().createOrderDepositHistory(req);
  //         System.debug(res);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createOrderDeposit_pointPayment() {
  //     // paymentMethod = '81' → debitPoint 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'D005',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => '81',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 5000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createOrderDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createOrderDeposit_couponPayment() {
  //     // CouponNo 있음 → redeemVoucherV2 경로 (Mock 사용)
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'D006',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 10000,
  //         'CouponNo' => 'COUPON-MOCK-001'
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svcWithMock().createOrderDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createOrderDeposit_normalDeposit() {
  //     // 일반 결제 → TransactionJournal insert 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'D007',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 30000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         ApiResult res = svc().createOrderDepositHistory(req);
  //         System.debug(res);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // insertOrderDepositHistoryByUpdate
  // // ========================================================

  // @IsTest
  // static void test_insertOrderDeposit_requiredFieldsMissing() {
  //     Test.startTest();
  //     try {
  //         svc().insertOrderDepositHistoryByUpdate(new Map<String, Object>());
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertOrderDeposit_noLpm() {
  //     // 회원 없는 주문 → LPM 조회 실패
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU001',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 5000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertOrderDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertOrderDeposit_normalDeposit_depositType01() {
  //     // 회원 연결 주문 + 일반 결제 + depositType=01
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU002',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 10000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         ApiResult res = svc().insertOrderDepositHistoryByUpdate(req);
  //         System.debug(res);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertOrderDeposit_normalDeposit_depositType02() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU003',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Bank',
  //         'DepositType__c' => '02',
  //         'TransactionAmount' => 8000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertOrderDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertOrderDeposit_pointDebit_depositType01() {
  //     // paymentMethod='81', depositType='01' → debitPoint 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU004',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => '81',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 3000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertOrderDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertOrderDeposit_pointCancel_depositType03() {
  //     // paymentMethod='81', depositType='03' → cancelPointRedemption 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU005',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => '81',
  //         'DepositType__c' => '03',
  //         'TransactionAmount' => 2000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertOrderDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertOrderDeposit_couponRedeem_depositType01() {
  //     // CouponNo + depositType='01' → redeemVoucherV2
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU006',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 5000,
  //         'CouponNo' => 'COUPON-MOCK-002'
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svcWithMock().insertOrderDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertOrderDeposit_couponCancel_depositType03() {
  //     // CouponNo + depositType='03' → redeemCancelVoucher
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU007',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '03',
  //         'TransactionAmount' => 5000,
  //         'CouponNo' => 'COUPON-MOCK-003'
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svcWithMock().insertOrderDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // createSaleDepositHistory
  // // ========================================================

  // @IsTest
  // static void test_createSaleDeposit_requiredFieldsMissing() {
  //     Test.startTest();
  //     try {
  //         svc().createSaleDepositHistory(new Map<String, Object>());
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createSaleDeposit_memberNotFound() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SD001',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 10000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => 'GHOST-MEMBER',
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createSaleDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createSaleDeposit_noLpm() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SD002',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Cash',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 5000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_NO_LPM,
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createSaleDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createSaleDeposit_promotionNotFound() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SD003',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 3000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'PromotionNo__c' => 'PROMO-NOT-EXIST',
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createSaleDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createSaleDeposit_normalDeposit() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SD004',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 40000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         ApiResult res = svc().createSaleDepositHistory(req);
  //         System.debug(res);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createSaleDeposit_pointPayment() {
  //     // paymentMethod='81' → debitPoint 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SD005',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => '81',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 5000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createSaleDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createSaleDeposit_couponPayment() {
  //     // CouponNo → redeemVoucherV2 (Mock)
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SD006',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 10000,
  //         'CouponNo' => 'COUPON-MOCK-SALE'
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svcWithMock().createSaleDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_createSaleDeposit_withPromoAndInsertId() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SD007',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 25000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'PromotionNo__c' => PROMO_OK,
  //         'InsertId__c' => 'USER001',
  //         'ActualPaymentAmount__c' => 25000,
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createSaleDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // insertSaleDepositHistoryByUpdate
  // // ========================================================

  // @IsTest
  // static void test_insertSaleDeposit_requiredFieldsMissing() {
  //     Test.startTest();
  //     try {
  //         svc().insertSaleDepositHistoryByUpdate(new Map<String, Object>());
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_orderNotFound() {
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU001',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 5000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => '0061234567890AB',
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_noLpm() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU002',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 7000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_depositType01() {
  //     // 일반 결제 + depositType='01' → depositTransactionList → creditPointsOnPurchase
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU003',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 15000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_depositType02() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU004',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Bank',
  //         'DepositType__c' => '02',
  //         'TransactionAmount' => 8000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_depositType03_cancelDeposit() {
  //     // depositType='03' → cancelDepositTransactionList → cancelPointsCreditedOnPurchase
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU005',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '03',
  //         'TransactionAmount' => 5000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_pointDebit_depositType01() {
  //     // paymentMethod='81', depositType='01' → debitPoint 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU006',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => '81',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 4000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_pointCancel_depositType03() {
  //     // paymentMethod='81', depositType='03' → cancelPointRedemption 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU007',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => '81',
  //         'DepositType__c' => '03',
  //         'TransactionAmount' => 3000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_couponRedeem_depositType01() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU008',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 10000,
  //         'CouponNo' => 'COUPON-SU-001'
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svcWithMock().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_insertSaleDeposit_couponCancel_depositType03() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU009',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '03',
  //         'TransactionAmount' => 5000,
  //         'CouponNo' => 'COUPON-SU-002'
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svcWithMock().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // getOrderDepositList
  // // ========================================================

  // @IsTest
  // static void test_getOrderDeposit_orderNotFound() {
  //     Test.startTest();
  //     try {
  //         svc().getOrderDepositList('ORD-NO-EXIST');
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_getOrderDeposit_noJournal() {
  //     // 주문은 있지만 TransactionJournal 없음
  //     Test.startTest();
  //     try {
  //         svc().getOrderDepositList('ORD-TJ-PLAIN');
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_getOrderDeposit_withJournal() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.OrderId = ord.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.PaymentMethod = 'Card';
  //     tj.TransactionAmount = 10000;
  //     tj.ActivityDate = Datetime.now();
  //     insert tj;

  //     Test.startTest();
  //     try {
  //         ApiResult res = svc().getOrderDepositList('ORD-TJ-PLAIN');
  //         System.debug(res);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_getOrderDeposit_nullParam() {
  //     Test.startTest();
  //     try {
  //         svc().getOrderDepositList(null);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // getSaleDepositList
  // // ========================================================

  // @IsTest
  // static void test_getSaleDeposit_saleNotFound() {
  //     Test.startTest();
  //     try {
  //         svc().getSaleDepositList('SALE-NO-EXIST');
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_getSaleDeposit_noJournal() {
  //     Test.startTest();
  //     try {
  //         svc().getSaleDepositList('SALE-TJ-MBR');
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_getSaleDeposit_withJournal() {
  //     Order ord = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-TJ-MBR' LIMIT 1];
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.OrderId = ord.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.PaymentMethod = 'Cash';
  //     tj.TransactionAmount = 20000;
  //     tj.ActivityDate = Datetime.now();
  //     insert tj;

  //     Test.startTest();
  //     try {
  //         ApiResult res = svc().getSaleDepositList('SALE-TJ-MBR');
  //         System.debug(res);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_getSaleDeposit_nullParam() {
  //     Test.startTest();
  //     try {
  //         svc().getSaleDepositList(null);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // debitPoint (직접 호출)
  // // ========================================================

  // @IsTest
  // static void test_debitPoint_nullTj() {
  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.debitPoint(null);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_debitPoint_withTj() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.TransactionAmount = 5000;
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.debitPoint(tj);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // cancelPointRedemption (직접 호출)
  // // ========================================================

  // @IsTest
  // static void test_cancelPointRedemption_nullTj() {
  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointRedemption(null);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_cancelPointRedemption_withTj() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.TransactionAmount = 3000;
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointRedemption(tj);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // creditPointsOnPurchase (직접 호출)
  // // ========================================================

  // @IsTest
  // static void test_creditPointsOnPurchase_emptyList() {
  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.creditPointsOnPurchase(new List<TransactionJournal>());
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_creditPointsOnPurchase_withTj() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.PaymentMethod = 'Card';
  //     tj.TransactionAmount = 20000;
  //     tj.ActivityDate = Datetime.now();
  //     // creditPointsOnPurchase 는 insert 된 TJ List 를 인자로 받으나,
  //     // 테스트에서는 insert 없이 직접 전달 (내부에서 insert 발생)

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.creditPointsOnPurchase(new List<TransactionJournal>{ tj });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // cancelPointsCreditedOnPurchase (직접 호출)
  // // ========================================================

  // @IsTest
  // static void test_cancelPointsCreditedOnPurchase_nullList() {
  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointsCreditedOnPurchase(null);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_cancelPointsCreditedOnPurchase_emptyList() {
  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointsCreditedOnPurchase(new List<TransactionJournal>());
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_cancelPointsCreditedOnPurchase_allExcludedPaymentMethods() {
  //     // PaymentMethod 가 모두 제외 대상('20','81','90','93') → totalCancelAmount=0 → 조기 리턴
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.PaymentMethod = '81'; // 제외 대상
  //     tj.TransactionAmount = 5000;
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointsCreditedOnPurchase(new List<TransactionJournal>{ tj });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_cancelPointsCreditedOnPurchase_withValidTj() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.PaymentMethod = 'Card';
  //     tj.TransactionAmount = 10000;
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointsCreditedOnPurchase(new List<TransactionJournal>{ tj });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // MockVoucherService 주입 확인 (getVoucherService / setVoucherService)
  // // ========================================================

  // @IsTest
  // static void test_setAndGetVoucherService() {
  //     MockVoucherService mock = new MockVoucherService();
  //     GdTransactionJournalServiceImpl.setVoucherService(mock);
  //     GdVoucherService result = GdTransactionJournalServiceImpl.getVoucherService();
  //     System.assertEquals(mock, result, 'Mock 서비스가 올바르게 주입되어야 합니다.');
  // }

  // @IsTest
  // static void test_getVoucherService_defaultInstance() {
  //     // voucherService null 상태에서 호출 → GdVoucherServiceImpl 생성
  //     GdTransactionJournalServiceImpl.setVoucherService(null);
  //     GdVoucherService result = GdTransactionJournalServiceImpl.getVoucherService();
  //     System.assertNotEquals(null, result, '기본 VoucherService가 생성되어야 합니다.');
  // }

  // // ========================================================
  // // NetUsage 생성자 직접 테스트
  // // ========================================================

  // @IsTest
  // static void test_netUsage_constructor() {
  //     Date expiryDate = Date.today().addDays(30);
  //     GdTransactionJournalServiceImpl.NetUsage nu = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         expiryDate,
  //         'TypeA',
  //         3,
  //         null,
  //         'creditId',
  //         'debitId'
  //     );
  //     System.assertEquals(expiryDate, nu.expiryDate);
  //     System.assertEquals('TypeA', nu.pointSubTypeName);
  //     System.assertEquals(3, nu.usagePriority);
  //     System.assertEquals(0, nu.netPoints);
  //     System.assertEquals('creditId', nu.creditLoyaltyLedgerId);
  //     System.assertEquals('debitId', nu.debitLoyaltyLedgerId);
  // }

  // // ========================================================
  // // CancelPortion 생성자 직접 테스트
  // // ========================================================

  // @IsTest
  // static void test_cancelPortion_constructor() {
  //     Date expiryDate = Date.today().addDays(10);
  //     GdTransactionJournalServiceImpl.NetUsage nu = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         expiryDate,
  //         'TypeB',
  //         2,
  //         null,
  //         'c1',
  //         'd1'
  //     );
  //     nu.netPoints = 1000;

  //     GdTransactionJournalServiceImpl.CancelPortion cp = new GdTransactionJournalServiceImpl.CancelPortion(
  //         nu,
  //         500
  //     );
  //     System.assertEquals(500, cp.cancelPoints);
  //     System.assertEquals('TypeB', cp.pointSubTypeName);
  //     System.assertEquals(expiryDate, cp.expiryDate);
  //     System.assertEquals(2, cp.usagePriority);
  //     System.assertEquals('c1', cp.creditLoyaltyLedgerId);
  //     System.assertEquals('d1', cp.debitLoyaltyLedgerId);
  // }

  // // ========================================================
  // // TraceSeed 생성자 직접 테스트
  // // ========================================================

  // @IsTest
  // static void test_traceSeed_constructor() {
  //     GdTransactionJournalServiceImpl.TraceSeed seed = new GdTransactionJournalServiceImpl.TraceSeed(
  //         null,
  //         null
  //     );
  //     System.assertEquals(null, seed.debitLedgerId);
  //     System.assertEquals(null, seed.creditLedger);
  // }

  // // ========================================================
  // // CancelPurchasePoints 생성자 직접 테스트
  // // ========================================================

  // @IsTest
  // static void test_cancelPurchasePoints_constructor() {
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints cpp = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         200,
  //         null,
  //         'SubTypeX',
  //         3.5
  //     );
  //     System.assertEquals(200, cpp.points);
  //     System.assertEquals('SubTypeX', cpp.loyaltyPgmCrcySubtypeName);
  //     System.assertEquals(3.5, cpp.rate);
  // }

  // // ========================================================
  // // CancelRateSorter.compare() - 모든 분기
  // // ========================================================

  // @IsTest
  // static void test_cancelRateSorter_bothNull() {
  //     GdTransactionJournalServiceImpl.CancelRateSorter sorter = new GdTransactionJournalServiceImpl.CancelRateSorter();
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints a = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints b = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         null
  //     );
  //     System.assertEquals(0, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_cancelRateSorter_aNull() {
  //     GdTransactionJournalServiceImpl.CancelRateSorter sorter = new GdTransactionJournalServiceImpl.CancelRateSorter();
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints a = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints b = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         5.0
  //     );
  //     System.assertEquals(1, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_cancelRateSorter_bNull() {
  //     GdTransactionJournalServiceImpl.CancelRateSorter sorter = new GdTransactionJournalServiceImpl.CancelRateSorter();
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints a = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         5.0
  //     );
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints b = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         null
  //     );
  //     System.assertEquals(-1, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_cancelRateSorter_aLessThanB() {
  //     GdTransactionJournalServiceImpl.CancelRateSorter sorter = new GdTransactionJournalServiceImpl.CancelRateSorter();
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints a = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         2.0
  //     );
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints b = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         5.0
  //     );
  //     System.assertEquals(-1, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_cancelRateSorter_aGreaterThanB() {
  //     GdTransactionJournalServiceImpl.CancelRateSorter sorter = new GdTransactionJournalServiceImpl.CancelRateSorter();
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints a = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         7.0
  //     );
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints b = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         3.0
  //     );
  //     System.assertEquals(1, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_cancelRateSorter_equal() {
  //     GdTransactionJournalServiceImpl.CancelRateSorter sorter = new GdTransactionJournalServiceImpl.CancelRateSorter();
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints a = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         4.0
  //     );
  //     GdTransactionJournalServiceImpl.CancelPurchasePoints b = new GdTransactionJournalServiceImpl.CancelPurchasePoints(
  //         100,
  //         null,
  //         'T',
  //         4.0
  //     );
  //     System.assertEquals(0, sorter.compare(a, b));
  // }

  // // ========================================================
  // // NetUsageCancelSorter.compare() - 모든 분기
  // // ========================================================

  // @IsTest
  // static void test_netUsageCancelSorter_aExpiryGreater() {
  //     // a.expiryDate > b.expiryDate → -1 (a가 더 늦게 만료 → a 먼저)
  //     GdTransactionJournalServiceImpl.NetUsage a = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         Date.today().addDays(20),
  //         'TypeA',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsage b = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         Date.today().addDays(5),
  //         'TypeB',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsageCancelSorter sorter = new GdTransactionJournalServiceImpl.NetUsageCancelSorter();
  //     System.assertEquals(-1, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_netUsageCancelSorter_aExpiryLess() {
  //     // a.expiryDate < b.expiryDate → 1
  //     GdTransactionJournalServiceImpl.NetUsage a = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         Date.today().addDays(3),
  //         'TypeA',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsage b = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         Date.today().addDays(15),
  //         'TypeB',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsageCancelSorter sorter = new GdTransactionJournalServiceImpl.NetUsageCancelSorter();
  //     System.assertEquals(1, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_netUsageCancelSorter_sameDateAPriorityGreater() {
  //     // expiryDate 동일, a.usagePriority > b.usagePriority → -1
  //     Date d = Date.today().addDays(10);
  //     GdTransactionJournalServiceImpl.NetUsage a = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         d,
  //         'TypeA',
  //         5,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsage b = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         d,
  //         'TypeB',
  //         2,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsageCancelSorter sorter = new GdTransactionJournalServiceImpl.NetUsageCancelSorter();
  //     System.assertEquals(-1, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_netUsageCancelSorter_sameDateAPriorityLess() {
  //     // expiryDate 동일, a.usagePriority < b.usagePriority → 1
  //     Date d = Date.today().addDays(10);
  //     GdTransactionJournalServiceImpl.NetUsage a = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         d,
  //         'TypeA',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsage b = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         d,
  //         'TypeB',
  //         4,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsageCancelSorter sorter = new GdTransactionJournalServiceImpl.NetUsageCancelSorter();
  //     System.assertEquals(1, sorter.compare(a, b));
  // }

  // @IsTest
  // static void test_netUsageCancelSorter_sameDateSamePriorityNameCompare() {
  //     // expiryDate 동일, priority 동일 → 이름 알파벳 비교
  //     Date d = Date.today().addDays(10);
  //     GdTransactionJournalServiceImpl.NetUsage a = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         d,
  //         'Alpha',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsage b = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         d,
  //         'Zeta',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsageCancelSorter sorter = new GdTransactionJournalServiceImpl.NetUsageCancelSorter();
  //     Integer result = sorter.compare(a, b); // 'alpha' < 'zeta' → negative
  //     System.assert(result < 0, 'Alpha이 Zeta보다 앞에 와야 합니다.');
  // }

  // // ========================================================
  // // DepositResponseDTO 필드 접근 테스트
  // // ========================================================

  // @IsTest
  // static void test_depositResponseDTO_allFields() {
  //     GdTransactionJournalServiceImpl.DepositResponseDTO dto = new GdTransactionJournalServiceImpl.DepositResponseDTO();
  //     dto.CD_TYPE_APPR = 'Card';
  //     dto.AM_DEPOSIT = 50000;
  //     dto.NO_COUPON_ALL = 'CPN-001';
  //     dto.NM_COUPON = '테스트쿠폰';
  //     dto.DT_EXP = Date.today().addDays(30);
  //     dto.RT_DISC = 10;
  //     dto.AM_DISC = 5000;
  //     dto.TX_REMARK = '비고내용';

  //     System.assertEquals('Card', dto.CD_TYPE_APPR);
  //     System.assertEquals(50000, dto.AM_DEPOSIT);
  //     System.assertEquals('CPN-001', dto.NO_COUPON_ALL);
  //     System.assertEquals('테스트쿠폰', dto.NM_COUPON);
  //     System.assertEquals(10, dto.RT_DISC);
  //     System.assertEquals(5000, dto.AM_DISC);
  //     System.assertEquals('비고내용', dto.TX_REMARK);
  // }

  // // ========================================================
  // // cancelPointsCreditedOnPurchase - '20','90','93' 제외 경로
  // // ========================================================

  // @IsTest
  // static void test_cancelPointsCreditedOnPurchase_paymentMethod20() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.PaymentMethod = '20';
  //     tj.TransactionAmount = 3000;
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointsCreditedOnPurchase(new List<TransactionJournal>{ tj });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_cancelPointsCreditedOnPurchase_paymentMethod90() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.PaymentMethod = '90';
  //     tj.TransactionAmount = 2000;
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointsCreditedOnPurchase(new List<TransactionJournal>{ tj });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // @IsTest
  // static void test_cancelPointsCreditedOnPurchase_zeroAmount() {
  //     // TransactionAmount = 0 → skip → totalCancelAmount = 0 → 조기 리턴
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.PaymentMethod = 'Card';
  //     tj.TransactionAmount = 0;
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointsCreditedOnPurchase(new List<TransactionJournal>{ tj });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // creditPointsOnPurchase - 제외 결제수단 포함 리스트 (totalAmount 계산 분기)
  // // ========================================================

  // @IsTest
  // static void test_creditPointsOnPurchase_mixedPaymentMethods() {
  //     // '20','81','90','93' paymentMethod → totalAmount 계산에서 skip 되는 경로
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj20 = new TransactionJournal();
  //     tj20.MemberId = lpm.Id;
  //     tj20.LoyaltyProgramId = lp.Id;
  //     tj20.OrderId = ord.Id;
  //     tj20.PaymentMethod = '20';
  //     tj20.TransactionAmount = 1000;
  //     tj20.ActivityDate = Datetime.now();

  //     TransactionJournal tj93 = new TransactionJournal();
  //     tj93.MemberId = lpm.Id;
  //     tj93.LoyaltyProgramId = lp.Id;
  //     tj93.OrderId = ord.Id;
  //     tj93.PaymentMethod = '93';
  //     tj93.TransactionAmount = 2000;
  //     tj93.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.creditPointsOnPurchase(new List<TransactionJournal>{ tj20, tj93 });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // createOrderDepositHistory - 복수 deposit 항목 테스트
  // // ========================================================

  // // ========================================================
  // // insertOrderDepositHistoryByUpdate - 복수 항목 (쿠폰02 분기)
  // // ========================================================

  // @IsTest
  // static void test_insertOrderDeposit_couponRedeem_depositType02() {
  //     // CouponNo + depositType='02' → redeemVoucherV2 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU008',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '02',
  //         'TransactionAmount' => 5000,
  //         'CouponNo' => 'COUPON-MOCK-004'
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svcWithMock().insertOrderDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // insertSaleDepositHistoryByUpdate - 쿠폰 depositType02
  // // ========================================================

  // @IsTest
  // static void test_insertSaleDeposit_couponRedeem_depositType02() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SU010',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '02',
  //         'TransactionAmount' => 8000,
  //         'CouponNo' => 'COUPON-SU-003'
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svcWithMock().insertSaleDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // getOrderDepositList - VoucherCode 있는 TJ (Voucher 없음 → 예외)
  // // ========================================================

  // @IsTest
  // static void test_getOrderDeposit_withTjHavingVoucherCode() {
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.OrderId = ord.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.PaymentMethod = 'Card';
  //     tj.TransactionAmount = 5000;
  //     tj.ActivityDate = Datetime.now();
  //     tj.VoucherCode = 'VOUCHER-NOT-EXIST-001'; // Voucher 레코드 없음 → 조회 시 empty
  //     insert tj;

  //     Test.startTest();
  //     try {
  //         svc().getOrderDepositList('ORD-TJ-PLAIN');
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // getSaleDepositList - VoucherCode 있는 TJ (Voucher 없음 → 예외)
  // // ========================================================

  // @IsTest
  // static void test_getSaleDeposit_withTjHavingVoucherCode() {
  //     Order ord = [SELECT Id FROM Order WHERE SaleNo__c = 'SALE-TJ-MBR' LIMIT 1];
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.OrderId = ord.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.PaymentMethod = 'Card';
  //     tj.TransactionAmount = 8000;
  //     tj.ActivityDate = Datetime.now();
  //     tj.VoucherCode = 'VOUCHER-NOT-EXIST-002';
  //     insert tj;

  //     Test.startTest();
  //     try {
  //         svc().getSaleDepositList('SALE-TJ-MBR');
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // cancelPointsCreditedOnPurchase - '93' 제외 경로
  // // ========================================================

  // @IsTest
  // static void test_cancelPointsCreditedOnPurchase_paymentMethod93() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.PaymentMethod = '93';
  //     tj.TransactionAmount = 4000;
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.cancelPointsCreditedOnPurchase(new List<TransactionJournal>{ tj });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // createOrderDepositHistory - 실제 PromotionNo__c 사용 (프로모션 찾기 성공 경로)
  // // ========================================================

  // @IsTest
  // static void test_createOrderDeposit_withRealPromotionNo() {
  //     // 자동 번호 필드 PromotionNo__c 를 쿼리로 읽어 실제 값으로 사용
  //     Promotion promo = [
  //         SELECT Id, PromotionNo__c
  //         FROM Promotion
  //         WHERE Name = 'TJ-Promo'
  //         LIMIT 1
  //     ];
  //     if (promo.PromotionNo__c == null) {
  //         // PromotionNo__c가 설정 안됐으면 테스트 생략
  //         System.assert(true, 'PromotionNo__c is null, skipping');
  //         return;
  //     }

  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'D-RP01',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 15000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'PromotionNo__c' => promo.PromotionNo__c,
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createOrderDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // createSaleDepositHistory - 실제 PromotionNo__c 사용
  // // ========================================================

  // @IsTest
  // static void test_createSaleDeposit_withRealPromotionNo() {
  //     Promotion promo = [
  //         SELECT Id, PromotionNo__c
  //         FROM Promotion
  //         WHERE Name = 'TJ-Promo'
  //         LIMIT 1
  //     ];
  //     if (promo.PromotionNo__c == null) {
  //         System.assert(true, 'PromotionNo__c is null, skipping');
  //         return;
  //     }

  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-PLAIN' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'SD-RP01',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '01',
  //         'TransactionAmount' => 20000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'MemberNo__c' => MBR_OK,
  //         'orderId' => String.valueOf(ord.Id),
  //         'PromotionNo__c' => promo.PromotionNo__c,
  //         'InsertId__c' => 'USER001',
  //         'ActualPaymentAmount__c' => 20000,
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().createSaleDepositHistory(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // insertOrderDepositHistoryByUpdate - depositType='03', paymentMethod 非81 (cancelDeposit 경로)
  // // ========================================================

  // @IsTest
  // static void test_insertOrderDeposit_normalCancel_depositType03() {
  //     // paymentMethod='Card', depositType='03' → cancelDepositTransactionList 경로
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];
  //     Map<String, Object> tj = new Map<String, Object>{
  //         'DepositNo__c' => 'DU009',
  //         'DeposiSeqNo__c' => '01',
  //         'ActivityDate' => Date.today(),
  //         'PaymentMethod' => 'Card',
  //         'DepositType__c' => '03',
  //         'TransactionAmount' => 5000
  //     };
  //     Map<String, Object> req = new Map<String, Object>{
  //         'orderId' => String.valueOf(ord.Id),
  //         'TransactionJournal' => new List<Object>{ tj }
  //     };

  //     Test.startTest();
  //     try {
  //         svc().insertOrderDepositHistoryByUpdate(req);
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // creditPointsOnPurchase - null/0 TransactionAmount skip 경로
  // // ========================================================

  // @IsTest
  // static void test_creditPointsOnPurchase_zeroAmount() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];
  //     Order ord = [SELECT Id FROM Order WHERE OrderNo__c = 'ORD-TJ-MBR' LIMIT 1];

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.MemberId = lpm.Id;
  //     tj.LoyaltyProgramId = lp.Id;
  //     tj.OrderId = ord.Id;
  //     tj.PaymentMethod = 'Card';
  //     tj.TransactionAmount = 0; // → skip
  //     tj.ActivityDate = Datetime.now();

  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     Test.startTest();
  //     try {
  //         impl.creditPointsOnPurchase(new List<TransactionJournal>{ tj });
  //     } catch (Exception e) {
  //         System.debug(e.getMessage());
  //     }
  //     Test.stopTest();
  //     System.assert(true);
  // }

  // // ========================================================
  // // NetUsageCancelSorter - null expiryDate 비교 (edge case)
  // // ========================================================

  // @IsTest
  // static void test_netUsageCancelSorter_sameDate_samePriority_sameNameEqual() {
  //     Date d = Date.today().addDays(10);
  //     GdTransactionJournalServiceImpl.NetUsage a = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         d,
  //         'Same',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsage b = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         d,
  //         'Same',
  //         1,
  //         null,
  //         null,
  //         null
  //     );
  //     GdTransactionJournalServiceImpl.NetUsageCancelSorter sorter = new GdTransactionJournalServiceImpl.NetUsageCancelSorter();
  //     Integer result = sorter.compare(a, b);
  //     System.assertEquals(0, result, '동일한 이름이면 0을 반환해야 합니다.');
  // }

  // // ========================================================
  // // CancelPortion - loyaltyPgmCurrencySubtypeId 필드 확인
  // // ========================================================

  // @IsTest
  // static void test_cancelPortion_subtypeId() {
  //     GdTransactionJournalServiceImpl.NetUsage nu = new GdTransactionJournalServiceImpl.NetUsage(
  //         null,
  //         Date.today().addDays(15),
  //         'TypeC',
  //         3,
  //         null,
  //         'c2',
  //         'd2'
  //     );
  //     nu.netPoints = 500;
  //     GdTransactionJournalServiceImpl.CancelPortion cp = new GdTransactionJournalServiceImpl.CancelPortion(
  //         nu,
  //         250
  //     );
  //     System.assertEquals(null, cp.loyaltyPgmCurrencySubtypeId);
  //     System.assertEquals(3, cp.usagePriority);
  //     System.assertEquals(250, cp.cancelPoints);
  //     System.assertEquals(null, cp.loyaltyLedgerTraceabilityId);
  // }

  // // ========================================================
  // // TraceSeed - non-null 값으로 생성 확인
  // // ========================================================

  // @IsTest
  // static void test_traceSeed_withValues() {
  //     LoyaltyProgram lp = [SELECT Id FROM LoyaltyProgram WHERE Name = 'TJ-LoyaltyProg' LIMIT 1];
  //     LoyaltyProgramMember lpm = [
  //         SELECT Id
  //         FROM LoyaltyProgramMember
  //         WHERE MembershipNumber = :MBR_OK
  //         LIMIT 1
  //     ];

  //     LoyaltyLedger ll = new LoyaltyLedger();
  //     ll.LoyaltyProgramMemberId = lpm.Id;
  //     ll.LoyaltyProgramCurrencyId = null;
  //     ll.Points = 100;
  //     ll.EventType = 'Credit';
  //     ll.ActivityDate = Datetime.now();
  //     // LoyaltyLedger는 직접 insert하지 않고 객체만 생성
  //     GdTransactionJournalServiceImpl.TraceSeed seed = new GdTransactionJournalServiceImpl.TraceSeed(
  //         lpm.Id,
  //         ll
  //     );
  //     System.assertEquals(lpm.Id, seed.debitLedgerId);
  //     System.assertNotEquals(null, seed.creditLedger);
  //     System.assertEquals(100, seed.creditLedger.Points);
  // }

  // // ========================================================
  // // GdTransactionJournalServiceImpl 생성자 호출 확인
  // // ========================================================

  // @IsTest
  // static void test_constructor() {
  //     GdTransactionJournalServiceImpl impl = new GdTransactionJournalServiceImpl();
  //     System.assertNotEquals(null, impl);
  // }
}