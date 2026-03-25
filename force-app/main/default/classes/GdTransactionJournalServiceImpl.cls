// ! 사용 x
public with sharing class GdTransactionJournalServiceImpl implements GdTransactionJournalService {
  // private static GdVoucherService voucherService;

  // // 테스트 클래스 용도
  // @TestVisible
  // private static void setVoucherService(GdVoucherService mock) {
  //   voucherService = mock;
  // }

  // @TestVisible
  // private static GdVoucherService getVoucherService() {
  //   if (voucherService == null)
  //     voucherService = new GdVoucherServiceImpl();
  //   return voucherService;
  // }

  // private static final String JOURNAL_TYPE_NAME_DEPOSIT = 'Deposit'; // 입금/결제
  // private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual'; // 포인트/쿠폰 지급
  // private static final String JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL = 'Accrual Reversal'; // 포인트/쿠폰 지급 취소
  // private static final String JOURNAL_TYPE_NAME_REDEMPTION = 'Redemption'; // 포인트/쿠폰 사용
  // private static final String JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL = 'Redemption Reversal'; // 포인트/쿠폰 사용 취소
  // private static final String JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL = 'Deposit Reversal'; // 입금/결제 취소

  // private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT = 'Order Deposit'; // 주문 입금
  // private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL = 'Order Deposit Reversal'; // 주문 입금 취소
  // private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT = 'Sale Deposit'; // 판매 입금
  // private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL = 'Sale Deposit Reversal'; // 판매 입금 취소
  // private static final String JOURNAL_SUB_TYPE_NAME_POINT_DEBIT = 'Point Debit'; // 포인트 사용
  // private static final String JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel'; // 포인트 사용 취소
  // private static final String JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL = 'Purchase Accrual'; // 구매 시 포인트 적립
  // private static final String JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual'; // 구매 시 포인트 적립 취소
  // private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM = 'Coupon Redeem'; // 쿠폰 사용
  // private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL = 'Coupon Redeem Cancel'; // 쿠폰 사용 취소

  // private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';

  // private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT = 'Debit'; // 포인트 사용
  // private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION = 'DebitCancellation'; // 포인트 사용 취소

  // public GdTransactionJournalServiceImpl() {
  // }

  // /**
  //  * 주문 입금 이력 생성
  //  * TransactionJournal insert
  //  */
  // public ApiResult createOrderDepositHistory(Map<String, Object> reqData) {
  //   Map<String, Object> data = new Map<String, Object>();
  //   try {
  //     List<Object> depositList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
  //     String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
  //     String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // 주문 번호
  //     String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false); // 프로모션 번호
  //     Id promotionId;
  //     if (promotionNo != null) {
  //       List<Promotion> promotionList = [SELECT Id FROM Promotion WHERE PromotionNo__c = :promotionNo LIMIT 1];
  //       if (promotionList.isEmpty()) {
  //         throw new CustomException(400, '해당 프로모션이 없습니다. ' + promotionNo);
  //       }
  //       promotionId = promotionList[0].Id;
  //     }

  //     // 회원 체크
  //     List<Contact> cList = [SELECT Id FROM Contact WHERE MemberNo__c = :memberNo LIMIT 1];
  //     if (cList.isEmpty()) {
  //       throw new CustomException(400, '없는 회원입니다. ' + memberNo);
  //     }

  //     // 로열티 프로그램 멤버 체크
  //     List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :cList[0].Id LIMIT 1];
  //     if (lpmList.isEmpty()) {
  //       throw new CustomException(400, '로열티 멤버가 아닙니다. ' + memberNo);
  //     }

  //     // 저널 유형 체크
  //     List<JournalType> jtList = [SELECT Id FROM journalType WHERE Name = :JOURNAL_TYPE_NAME_DEPOSIT LIMIT 1];
  //     if (jtList.isEmpty()) {
  //       throw new CustomException(400, '저널 타입이 없습니다. ' + JOURNAL_TYPE_NAME_DEPOSIT);
  //     }

  //     // 저널 하위 유형 체크
  //     List<JournalSubType> jstList = [
  //       SELECT Id
  //       FROM JournalSubType
  //       WHERE Name = :JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT AND JournalTypeId = :jtList[0].Id
  //       LIMIT 1
  //     ];
  //     if (jstList.isEmpty()) {
  //       throw new CustomException(400, '저널 하위 타입이 없습니다. ' + JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT);
  //     }

  //     List<GdSaleApiController.PointDebitDTO> debitPointList = new List<GdSaleApiController.PointDebitDTO>();

  //     List<TransactionJournal> tjList = new List<TransactionJournal>();
  //     for (Object v : depositList) {
  //       Map<String, Object> deposit = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);

  //       String depositNo = ValidationUtil.stringValidation(deposit.get('DepositNo__c'), 'DepositNo__c', true); // 입금 번호
  //       String deposiSeqNo = ValidationUtil.stringValidation(deposit.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true); // 입금 일련 번호
  //       Date activityDate = ValidationUtil.dateValidation(deposit.get('ActivityDate'), 'ActivityDate', true); // 입금 일자
  //       String paymentMethod = ValidationUtil.stringValidation(deposit.get('PaymentMethod'), 'PaymentMethod', true); // 결제 구분 코드
  //       String depositType = ValidationUtil.stringValidation(deposit.get('DepositType__c'), 'DepositType__c', true); // 입금 구분 코드
  //       Decimal transactionAmount = ValidationUtil.decimalValidation(deposit.get('TransactionAmount'), 'TransactionAmount', true); // 입금 금액
  //       String couponNo = ValidationUtil.stringValidationEx(deposit.get('CouponNo'), 'CouponNo', false, true); // 쿠폰 번호

  //       TransactionJournal tj = new TransactionJournal();
  //       tj.DepositNo__c = depositNo + '-' + deposiSeqNo;
  //       tj.DeposiSeqNo__c = deposiSeqNo;
  //       tj.JournalDate = activityDate;
  //       tj.ActivityDate = Datetime.now();
  //       tj.PaymentMethod = paymentMethod;
  //       tj.LoyaltyProgramId = lpmList[0].ProgramId;
  //       tj.DepositType__c = depositType;
  //       tj.TransactionAmount = transactionAmount;
  //       tj.MemberId = lpmList[0].Id;
  //       tj.OrderId = orderId;
  //       tj.OrderId__c = orderId;

  //       if (promotionNo != null) {
  //         tj.PromotionId = promotionId;
  //       }

  //       if (String.isNotBlank(couponNo)) {
  //         tj.VoucherCode = couponNo;
  //         tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
  //         tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
  //         tj.Status = 'Processed';
  //         getVoucherService().redeemVoucherV2(tj);
  //         continue;
  //       }

  //       // 포인트 사용 일 경우
  //       if ('81'.equals(paymentMethod)) {
  //         // 포인트 사용
  //         debitPointList = debitPoint(tj);
  //         data.put('DebitPointList', debitPointList);
  //       } else {
  //         tj.JournalTypeId = jtList[0].Id;
  //         tj.JournalSubTypeId = jstList[0].Id;
  //         tj.Status = 'Processed';
  //         tjList.add(tj);
  //       }
  //     }

  //     List<Database.SaveResult> resultList = Database.insert(tjList);

  //     for (Database.SaveResult result : resultList) {
  //       if (!result.isSuccess()) {
  //         Database.Error err = result.getErrors()[0];
  //         throw new CustomException(400, err.getMessage());
  //       }
  //     }

  //     data.put('DebitPointList', debitPointList);

  //     return ApiResult.ok(200, '주문 입금 이력 생성', data);
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  // /**
  //  * ! 이관 대상
  //  * 주문 입금 이력 수정
  //  * TransactionJournal insert
  //  * LoyaltyLedger insert
  //  * LoyaltyLedgerTraceability insert
  //  */
  // public ApiResult insertOrderDepositHistoryByUpdate(Map<String, Object> reqData) {
  //   Map<String, Object> data = new Map<String, Object>();
  //   try {
  //     List<Object> transactionJournalList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);

  //     String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // 주문 번호

  //     // 로열티 회원 체크
  //     List<LoyaltyProgramMember> lpmList = [
  //       SELECT Id, ProgramId
  //       FROM LoyaltyProgramMember
  //       WHERE ContactId IN (SELECT MemberNo__c FROM Order WHERE Id = :orderId)
  //       LIMIT 1
  //     ];
  //     if (lpmList.isEmpty()) {
  //       throw new CustomException(400, '해당 주문에 회원이 존재하지 않습니다. ' + orderId);
  //     }

  //     List<GdSaleApiController.PointDebitDTO> debitPointList = new List<GdSaleApiController.PointDebitDTO>();

  //     List<TransactionJournal> tjList = new List<TransactionJournal>();

  //     for (Object v : transactionJournalList) {
  //       Map<String, Object> transactionJournal = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);

  //       String depositNo = ValidationUtil.stringValidation(transactionJournal.get('DepositNo__c'), 'DepositNo__c', true); // 입금 번호
  //       String deposiSeqNo = ValidationUtil.stringValidation(transactionJournal.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true); // 입금 일련 번호
  //       Date activityDate = ValidationUtil.dateValidation(transactionJournal.get('ActivityDate'), 'ActivityDate', true); // 입금 일자
  //       String paymentMethod = ValidationUtil.stringValidation(transactionJournal.get('PaymentMethod'), 'PaymentMethod', true); // 결제 구분 코드
  //       String depositType = ValidationUtil.stringValidation(transactionJournal.get('DepositType__c'), 'DepositType__c', true); // 입금 구분 코드
  //       Decimal transactionAmount = ValidationUtil.decimalValidation(transactionJournal.get('TransactionAmount'), 'TransactionAmount', true); // 입금 금액
  //       String couponNo = ValidationUtil.stringValidationEx(transactionJournal.get('CouponNo'), 'CouponNo', false, true); // 쿠폰 번호

  //       TransactionJournal tj = new TransactionJournal();
  //       tj.DepositNo__c = depositNo + '-' + deposiSeqNo;
  //       tj.DeposiSeqNo__c = deposiSeqNo;
  //       tj.LoyaltyProgramId = lpmList[0].ProgramId;
  //       tj.JournalDate = activityDate;
  //       tj.ActivityDate = Datetime.now();
  //       tj.PaymentMethod = paymentMethod;
  //       tj.DepositType__c = depositType;
  //       tj.TransactionAmount = transactionAmount;
  //       tj.MemberId = lpmList[0].Id;
  //       tj.OrderId = orderId;
  //       tj.OrderId__c = orderId;
  //       tj.Status = 'Pending';

  //       if (String.isNotBlank(couponNo)) {
  //         tj.VoucherCode = couponNo;
  //         tj.Status = 'Processed';
  //         if ('03'.equals(depositType)) {
  //           // 쿠폰 사용 취소
  //           tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
  //           tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true);
  //           getVoucherService().redeemCancelVoucher(tj);
  //         } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
  //           // 쿠폰 사용
  //           tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
  //           tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
  //           getVoucherService().redeemVoucherV2(tj);
  //         }
  //         continue;
  //       }

  //       if ('81'.equals(paymentMethod)) {
  //         if ('03'.equals(depositType)) {
  //           // 포인트 사용 취소
  //           Map<String, Object> cancelPointResult = cancelPointRedemption(tj);
  //           data.put('CancelPointList', cancelPointResult);
  //         } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
  //           // 포인트 사용
  //           debitPointList = debitPoint(tj);
  //           data.put('DebitPointList', debitPointList);
  //         }
  //       } else {
  //         tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, true);
  //         tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL, true);
  //         tj.Status = 'Processed';
  //         tjList.add(tj);
  //       }
  //     }

  //     List<Database.SaveResult> resultList = Database.insert(tjList);

  //     for (Database.SaveResult result : resultList) {
  //       if (!result.isSuccess()) {
  //         Database.Error err = result.getErrors()[0];
  //         throw new CustomException(400, err.getMessage());
  //       }
  //     }

  //     return ApiResult.ok(200, '주문 입금 이력 수정 완료.', data);
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  // /**
  //  * ! 이관중
  //  * 판매 입금 이력 생성
  //  * 프로모션 적용
  //  * TransactionJournal insert
  //  */
  // public ApiResult createSaleDepositHistory(Map<String, Object> reqData) {
  //   Map<String, Object> data = new Map<String, Object>();

  //   try {
  //     List<Object> depositList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
  //     String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
  //     String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);
  //     String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false);
  //     String insertId = ValidationUtil.stringValidation(reqData.get('InsertId__c'), 'InsertId__c', false); // 등록자
  //     Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액

  //     // 프로모션 체크
  //     Id promotionId;
  //     if (promotionNo != null) {
  //       List<Promotion> promotionList = [SELECT Id FROM Promotion WHERE PromotionNo__c = :promotionNo LIMIT 1];
  //       if (promotionList.isEmpty()) {
  //         throw new CustomException(400, '해당 프로모션이 없습니다. ' + promotionNo);
  //       }
  //       promotionId = promotionList[0].Id;
  //     }
  //     // 회원 체크
  //     List<Contact> cList = [SELECT Id, Grade__c FROM Contact WHERE MemberNo__c = :memberNo LIMIT 1];
  //     if (cList.isEmpty()) {
  //       throw new CustomException(400, '없는 회원입니다. ' + memberNo);
  //     }

  //     // 로열티 프로그램 멤버 체크
  //     List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :cList[0].Id LIMIT 1];
  //     if (lpmList.isEmpty()) {
  //       throw new CustomException(400, '로열티 멤버가 아닙니다. ' + memberNo);
  //     }

  //     // 저널 유형 체크
  //     Id depoistJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true); // 저널 유형 : 입금

  //     // 저널 하위 유형 체크
  //     Id saleDepoistJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true); // 저널 하위 유형 : 판매 입금

  //     List<TransactionJournal> tjList = new List<TransactionJournal>();
  //     for (Object v : depositList) {
  //       Map<String, Object> deposit = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);

  //       String depositNo = ValidationUtil.stringValidation(deposit.get('DepositNo__c'), 'DepositNo__c', true); // 입금 번호
  //       String deposiSeqNo = ValidationUtil.stringValidation(deposit.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true); // 입금 일련 번호
  //       Date activityDate = ValidationUtil.dateValidation(deposit.get('ActivityDate'), 'ActivityDate', true); // 입금 일자
  //       String paymentMethod = ValidationUtil.stringValidation(deposit.get('PaymentMethod'), 'PaymentMethod', true); // 결제 구분 코드
  //       String depositType = ValidationUtil.stringValidation(deposit.get('DepositType__c'), 'DepositType__c', true); // 입금 구분 코드
  //       Decimal transactionAmount = ValidationUtil.decimalValidation(deposit.get('TransactionAmount'), 'TransactionAmount', true); // 입금 금액
  //       String couponNo = ValidationUtil.stringValidationEx(deposit.get('CouponNo'), 'CouponNo', false, true); // 쿠폰 번호

  //       TransactionJournal tj = new TransactionJournal();
  //       tj.DepositNo__c = depositNo + '-' + deposiSeqNo;
  //       tj.DeposiSeqNo__c = deposiSeqNo;
  //       tj.JournalDate = activityDate;
  //       tj.ActivityDate = Datetime.now();
  //       tj.PaymentMethod = paymentMethod;
  //       tj.LoyaltyProgramId = lpmList[0].ProgramId;
  //       tj.DepositType__c = depositType;
  //       tj.TransactionAmount = transactionAmount;
  //       tj.MemberId = lpmList[0].Id;
  //       tj.OrderId = orderId;
  //       tj.SaleId__c = orderId;

  //       if (promotionNo != null) {
  //         tj.PromotionId = promotionId;
  //       }

  //       if (String.isNotBlank(couponNo)) {
  //         tj.VoucherCode = couponNo;
  //         tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
  //         tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
  //         tj.Status = 'Processed';
  //         getVoucherService().redeemVoucherV2(tj);
  //         continue;
  //       }

  //       // 포인트 사용 일 경우
  //       if ('81'.equals(paymentMethod)) {
  //         // 포인트 사용
  //         List<GdSaleApiController.PointDebitDTO> debitPointList = debitPoint(tj);
  //         for (GdSaleApiController.PointDebitDTO debitPoint : debitPointList) {
  //           debitPoint.AM_SAL = actualPaymentAmount; // 판매처리된 판매의 금액
  //           debitPoint.ID_INSERT = insertId; // 등록자
  //         }

  //         data.put('DebitPointList', debitPointList);
  //       } else {
  //         tj.JournalTypeId = depoistJtId;
  //         tj.JournalSubTypeId = saleDepoistJstId;
  //         tj.Status = 'Processed';
  //         tjList.add(tj);
  //       }
  //     }

  //     List<Database.SaveResult> resultList = Database.insert(tjList);

  //     for (Database.SaveResult result : resultList) {
  //       if (!result.isSuccess()) {
  //         Database.Error err = result.getErrors()[0];
  //         throw new CustomException(400, err.getMessage());
  //       }
  //     }

  //     // 구매 시 포인트 적립 로직
  //     if (!tjList.isEmpty()) {
  //       List<PointCreditDTO> creditPointList = creditPointsOnPurchase(tjList);
  //       for (PointCreditDTO pcDto : creditPointList) {
  //         pcDto.AM_SAL = actualPaymentAmount; // 판매 금액
  //         pcDto.ID_INSERT = insertId; // 등록자
  //         pcDto.NO_PROM_MBR = promotionNo; // 프로모션 번호
  //         pcDto.NO_GRADE_ADVAN = cList[0].Grade__c; // 승급번호
  //       }
  //       data.put('CreditPointList', creditPointList);
  //     }

  //     return ApiResult.ok(200, '판매 입금 이력 생성', data);
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  // /**
  //  * 판매 입금 이력 수정
  //  * TransactionJournal insert
  //  * LoyaltyLedger insert
  //  * LoyaltyLedgerTraceability insert
  //  */
  // public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
  //   Map<String, Object> data = new Map<String, Object>();
  //   try {
  //     List<Object> transactionJournalList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);

  //     String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // 주문 번호

  //     List<Order> oList = [SELECT Id, ActualPaymentAmount__c, InsertId__c FROM Order WHERE Id = :orderId LIMIT 1];
  //     if (oList.isEmpty()) {
  //       throw new CustomException(400, '해당 주문이 없습니다. ' + orderId);
  //     }

  //     List<TransactionJournal> tjPromotionNoList = [
  //       SELECT Id, Promotion.PromotionNo__c
  //       FROM TransactionJournal
  //       WHERE OrderId = :orderId AND PromotionId != NULL
  //       ORDER BY CreatedDate ASC
  //       LIMIT 1
  //     ];

  //     // 로열티 회원 체크
  //     List<LoyaltyProgramMember> lpmList = [
  //       SELECT Id, ProgramId, Contact.Grade__c
  //       FROM LoyaltyProgramMember
  //       WHERE ContactId IN (SELECT MemberNo__c FROM Order WHERE Id = :orderId)
  //       LIMIT 1
  //     ];
  //     if (lpmList.isEmpty()) {
  //       throw new CustomException(400, '해당 주문에 회원이 존재하지 않습니다. ' + orderId);
  //     }

  //     List<GdSaleApiController.PointDebitDTO> debitPointList = new List<GdSaleApiController.PointDebitDTO>();

  //     List<TransactionJournal> tjList = new List<TransactionJournal>();

  //     List<TransactionJournal> depositTransactionList = new List<TransactionJournal>();
  //     List<TransactionJournal> cancelDepositTransactionList = new List<TransactionJournal>();

  //     for (Object v : transactionJournalList) {
  //       Map<String, Object> transactionJournal = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);

  //       String depositNo = ValidationUtil.stringValidation(transactionJournal.get('DepositNo__c'), 'DepositNo__c', true); // 입금 번호
  //       String deposiSeqNo = ValidationUtil.stringValidation(transactionJournal.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true); // 입금 일련 번호
  //       Date activityDate = ValidationUtil.dateValidation(transactionJournal.get('ActivityDate'), 'ActivityDate', true); // 입금 일자
  //       String paymentMethod = ValidationUtil.stringValidation(transactionJournal.get('PaymentMethod'), 'PaymentMethod', true); // 결제 구분 코드
  //       String depositType = ValidationUtil.stringValidation(transactionJournal.get('DepositType__c'), 'DepositType__c', true); // 입금 구분 코드
  //       Decimal transactionAmount = ValidationUtil.decimalValidation(transactionJournal.get('TransactionAmount'), 'TransactionAmount', true); // 입금 금액
  //       String couponNo = ValidationUtil.stringValidationEx(transactionJournal.get('CouponNo'), 'CouponNo', false, true); // 쿠폰 번호

  //       TransactionJournal tj = new TransactionJournal();
  //       tj.DepositNo__c = depositNo + '-' + deposiSeqNo;
  //       tj.DeposiSeqNo__c = deposiSeqNo;
  //       tj.LoyaltyProgramId = lpmList[0].ProgramId;
  //       tj.JournalDate = activityDate;
  //       tj.ActivityDate = Datetime.now();
  //       tj.PaymentMethod = paymentMethod;
  //       tj.DepositType__c = depositType;
  //       tj.TransactionAmount = transactionAmount;
  //       tj.MemberId = lpmList[0].Id;
  //       tj.OrderId = orderId;
  //       tj.SaleId__c = orderId;
  //       tj.Status = 'Pending';

  //       if (String.isNotBlank(couponNo)) {
  //         tj.VoucherCode = couponNo;
  //         tj.Status = 'Processed';
  //         if ('03'.equals(depositType)) {
  //           // 쿠폰 사용 취소
  //           tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
  //           tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true);
  //           getVoucherService().redeemCancelVoucher(tj);
  //         } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
  //           // 쿠폰 사용
  //           tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
  //           tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
  //           getVoucherService().redeemVoucherV2(tj);
  //         }
  //         continue;
  //       }

  //       if ('81'.equals(paymentMethod)) {
  //         // 포인트 사용 취소 (03 = 환불)
  //         if ('03'.equals(depositType)) {
  //           Map<String, Object> cancelPointResult = cancelPointRedemption(tj);
  //           data.put('CancelPointList', cancelPointResult);
  //         }
  //         // 포인트 사용 (01 = 선수금 | 02 = 잔금)
  //         else if ('01'.equals(depositType) || '02'.equals(depositType)) {
  //           debitPointList = debitPoint(tj);
  //           data.put('DebitPointList', debitPointList);
  //         }
  //       } else {
  //         tj.Status = 'Processed';

  //         if ('01'.equals(depositType) || '02'.equals(depositType)) {
  //           tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true);
  //           tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true);
  //           depositTransactionList.add(tj);
  //         } else if ('03'.equals(depositType)) {
  //           tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, true);
  //           tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true);
  //           cancelDepositTransactionList.add(tj);
  //         }
  //         tjList.add(tj);
  //       }
  //     }

  //     List<Database.SaveResult> resultList = Database.insert(tjList);

  //     for (Database.SaveResult result : resultList) {
  //       if (!result.isSuccess()) {
  //         Database.Error err = result.getErrors()[0];
  //         throw new CustomException(400, err.getMessage());
  //       }
  //     }

  //     // 구매 시 포인트 적립 로직
  //     if (!depositTransactionList.isEmpty()) {
  //       List<PointCreditDTO> creditPointList = creditPointsOnPurchase(depositTransactionList);
  //       for (PointCreditDTO pcDto : creditPointList) {
  //         pcDto.AM_SAL = oList[0].ActualPaymentAmount__c; // 판매 금액
  //         pcDto.ID_INSERT = oList[0].InsertId__c; // 등록자
  //         if (!tjPromotionNoList.isEmpty()) {
  //           pcDto.NO_PROM_MBR = tjPromotionNoList[0].Promotion.PromotionNo__c; // 프로모션 번호
  //         }
  //         pcDto.NO_GRADE_ADVAN = lpmList[0].Contact.Grade__c; // 승급번호
  //       }
  //       data.put('CreditPointList', creditPointList);
  //     }
  //     // 구매 시 포인트 적립 취소 로직
  //     if (!cancelDepositTransactionList.isEmpty()) {
  //       cancelPointsCreditedOnPurchase(cancelDepositTransactionList);
  //       // List<Map<String, Object>> cancelPointsCreditedOnPurchaseList = cancelPointsCreditedOnPurchase(cancelDepositTransactionList);
  //       // data.put('CancelPointsCreditedOnPurchaseList', cancelPointsCreditedOnPurchaseList);
  //     }

  //     return ApiResult.ok(200, '판매 입금 이력 수정 완료.', data);
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  // // ! 사용 x
  // /**
  //  * 주문 입금 조회
  //  */
  // // public ApiResult getOrderDepositList(String orderNo) {
  // //   try {
  // //     List<Order> oList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
  // //     if (oList.isEmpty()) {
  // //       throw new CustomException(400, '해당 주문건이 없습니다. ' + orderNo);
  // //     }

  // //     List<TransactionJournal> tjList = [
  // //       SELECT Id, PaymentMethod, DepositType__c, TransactionAmount, OrderId__c, VoucherCode
  // //       FROM TransactionJournal
  // //       WHERE OrderId = :oList[0].Id
  // //       LIMIT 100
  // //     ];

  // //     if (tjList.isEmpty()) {
  // //       throw new CustomException(400, '해당 주문건의 입금 내역이 없습니다. ' + orderNo);
  // //     }

  // //     List<DepositResponseDTO> depositList = new List<DepositResponseDTO>();
  // //     List<String> voucherCodeList = new List<String>();
  // //     for (TransactionJournal tj : tjList) {
  // //       DepositResponseDTO res = new DepositResponseDTO();
  // //       res.CD_TYPE_APPR = tj.PaymentMethod;
  // //       res.AM_DEPOSIT = tj.TransactionAmount;

  // //       if (tj.VoucherCode != null) {
  // //         List<Voucher> vList = [
  // //           SELECT Id, VoucherDefinition.Name, VoucherCode, ExpirationDate, DiscountPercent, FaceValue, Reason
  // //           FROM Voucher
  // //           WHERE VoucherCode = :tj.VoucherCode
  // //           LIMIT 1
  // //         ];
  // //         if (vList.isEmpty()) {
  // //           throw new CustomException(400, 'Voucher is empty.');
  // //         }
  // //         res.NO_COUPON_ALL = vList[0].VoucherCode; // 쿠폰 코드
  // //         res.NM_COUPON = vList[0].VoucherDefinition.Name; // 쿠폰명
  // //         res.DT_EXP = vList[0].ExpirationDate; // 만료일자
  // //         res.RT_DISC = vList[0].DiscountPercent; // 할인율
  // //         res.AM_DISC = vList[0].FaceValue; // 할인 금액
  // //         res.TX_REMARK = vList[0].Reason; // 비고
  // //       }
  // //       depositList.add(res);
  // //     }

  // //     Map<String, Object> data = new Map<String, Object>();
  // //     data.put('depositList', depositList);

  // //     return ApiResult.ok(200, '주문 입금 조회 성공', data);
  // //   } catch (ValidationException ve) {
  // //     throw new CustomException(ve.code, ve.detail);
  // //   } catch (Exception e) {
  // //     throw e;
  // //   }
  // // }

  // /**
  //  * ! 이관 대상
  //  * 판매 입금 조회
  //  */
  // public ApiResult getSaleDepositList(String saleNo) {
  //   try {
  //     List<Order> oList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
  //     if (oList.isEmpty()) {
  //       throw new CustomException(400, '해당 판매건이 없습니다. ' + saleNo);
  //     }

  //     List<TransactionJournal> tjList = [
  //       SELECT Id, PaymentMethod, DepositType__c, TransactionAmount, OrderId__c, VoucherCode
  //       FROM TransactionJournal
  //       WHERE OrderId = :oList[0].Id
  //       LIMIT 100
  //     ];

  //     if (tjList.isEmpty()) {
  //       throw new CustomException(400, '해당 판매건의 입금 내역이 없습니다. ' + saleNo);
  //     }

  //     List<DepositResponseDTO> depositList = new List<DepositResponseDTO>();
  //     List<String> voucherCodeList = new List<String>();
  //     for (TransactionJournal tj : tjList) {
  //       DepositResponseDTO res = new DepositResponseDTO();
  //       res.CD_TYPE_APPR = tj.PaymentMethod;
  //       res.AM_DEPOSIT = tj.TransactionAmount;

  //       if (tj.VoucherCode != null) {
  //         List<Voucher> vList = [
  //           SELECT Id, VoucherDefinition.Name, VoucherCode, ExpirationDate, DiscountPercent, FaceValue, Reason
  //           FROM Voucher
  //           WHERE VoucherCode = :tj.VoucherCode
  //           LIMIT 1
  //         ];
  //         if (vList.isEmpty()) {
  //           throw new CustomException(400, 'Voucher is empty.');
  //         }
  //         res.NO_COUPON_ALL = vList[0].VoucherCode; // 쿠폰 코드
  //         res.NM_COUPON = vList[0].VoucherDefinition.Name; // 쿠폰명
  //         res.DT_EXP = vList[0].ExpirationDate; // 만료일자
  //         res.RT_DISC = vList[0].DiscountPercent; // 할인율
  //         res.AM_DISC = vList[0].FaceValue; // 할인 금액
  //         res.TX_REMARK = vList[0].Reason; // 비고
  //       }
  //       depositList.add(res);
  //     }

  //     Map<String, Object> data = new Map<String, Object>();
  //     data.put('depositList', depositList);

  //     return ApiResult.ok(200, '판매 입금 조회', data);
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  // /**
  //  * ! 이관중
  //  * 구매 시 포인트 지급
  //  */
  // public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
  //   try {
  //     if (data.isEmpty()) {
  //       return null;
  //     }

  //     // 저널 유형 체크
  //     List<JournalType> jtListByCreditPoint = [SELECT Id FROM journalType WHERE Name = :JOURNAL_TYPE_NAME_ACCRUAL LIMIT 1];
  //     if (jtListByCreditPoint.isEmpty()) {
  //       throw new CustomException(400, '저널 타입(포인트 지급)이 없습니다. ' + JOURNAL_TYPE_NAME_ACCRUAL);
  //     }

  //     // 저널 하위 유형 체크
  //     List<JournalSubType> jstListByCreditPoint = [
  //       SELECT Id
  //       FROM JournalSubType
  //       WHERE Name = :JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL AND JournalTypeId = :jtListByCreditPoint[0].Id
  //       LIMIT 1
  //     ];
  //     if (jstListByCreditPoint.isEmpty()) {
  //       throw new CustomException(400, '저널 하위 타입(포인트 지급)이 없습니다. ' + JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);
  //     }

  //     // 계층 보상 가져오기
  //     List<LoyaltyTierBenefit> ltbList = [
  //       SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c
  //       FROM LoyaltyTierBenefit
  //       WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
  //     ];
  //     if (ltbList.isEmpty()) {
  //       throw new CustomException(400, '해당 회원의 등급 보상이 없습니다. ' + data[0].MemberId);
  //     }

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.ActivityDate = Datetime.now();
  //     tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
  //     tj.MemberId = data[0].MemberId;
  //     tj.OrderId = data[0].OrderId;
  //     tj.JournalTypeId = jtListByCreditPoint[0].Id;
  //     tj.JournalSubTypeId = jstListByCreditPoint[0].Id;
  //     tj.Status = 'Pending';

  //     insert tj;

  //     List<Map<String, Object>> reqList = new List<Map<String, Object>>();

  //     Decimal totalAmount = 0;
  //     for (TransactionJournal v : data) {
  //       if (v.PaymentMethod == '20' || v.PaymentMethod == '81' || v.PaymentMethod == '90' || v.PaymentMethod == '93') {
  //         continue;
  //       }
  //       if (v.TransactionAmount == null || v.TransactionAmount == 0) {
  //         continue;
  //       }

  //       totalAmount += v.TransactionAmount;
  //     }

  //     for (LoyaltyTierBenefit ltb : ltbList) {
  //       Map<String, Object> req = new Map<String, Object>();
  //       req.put('loyaltyProgramMemberId', data[0].MemberId);
  //       req.put('journalId', tj.Id);
  //       req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
  //       req.put('points', totalAmount * (ltb.Benefit.PurchasePointRate__c / 100));
  //       req.put(
  //         'additionalNotes',
  //         ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
  //           '|' +
  //           String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
  //           '|' +
  //           String.valueOf(ltb.Benefit.PurchasePointRate__c)
  //       );
  //       reqList.add(req);
  //     }

  //     LoyaltyPointService.creditPoints(reqList);

  //     List<LoyaltyLedger> llList = [
  //       SELECT
  //         Id,
  //         TransactionJournalId,
  //         LoyaltyPgmCrcySubtype.Name,
  //         Points,
  //         ExpiryDate,
  //         EscrowPointsCreditDate,
  //         ActivityDate,
  //         CreatedDate,
  //         EventType,
  //         AdditionalNotes
  //       FROM LoyaltyLedger
  //       WHERE TransactionJournalId = :tj.Id
  //       LIMIT 100
  //     ];

  //     TransactionJournal tj2 = [
  //       SELECT
  //         Id,
  //         MemberId,
  //         TYPEOF Member
  //           WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
  //         END
  //       FROM TransactionJournal
  //       WHERE Id = :tj.Id
  //       LIMIT 1
  //     ];
  //     SObject memberObj = tj2.getSObject('Member');
  //     if (memberObj == null) {
  //       throw new CustomException(500, 'memberObj is null');
  //     }
  //     SObject contactObj = memberObj.getSObject('Contact');
  //     if (contactObj == null) {
  //       throw new CustomException(500, 'contactObj is null');
  //     }
  //     String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

  //     List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
  //     for (LoyaltyLedger ll : llList) {
  //       PointCreditDTO pcDto = new PointCreditDTO();
  //       pcDto.CD_JOURNAL = tj.Id;
  //       pcDto.CD_TYPE_POINT = '01';
  //       pcDto.NO_MBR = memberNo;
  //       pcDto.PT_TARGET = ll.Points; // 적립 포인트
  //       pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
  //       pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
  //       pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1)); // 포인트 유효기간 종료일
  //       pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate); // 소멸 예정일
  //       pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
  //       pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
  //       pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
  //       pcDtoList.add(pcDto);
  //     }

  //     return pcDtoList;
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  // /**
  //  * 구매 시 지급된 포인트 적립 취소
  //  */
  // public void cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
  //   try {
  //     if (data == null || data.isEmpty()) {
  //       return;
  //     }

  //     // 환급 할 금액
  //     Decimal totalCancelAmount = 0;
  //     for (TransactionJournal tj : data) {
  //       // 포인트 적립 제외 구분 코드
  //       if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
  //         continue;
  //       }
  //       if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
  //         continue;
  //       }

  //       totalCancelAmount += tj.TransactionAmount;
  //     }

  //     // 포인트 적립 취소 할 금액이 없음.
  //     if (totalCancelAmount <= 0) {
  //       return;
  //     }

  //     Id accrualJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
  //     Id accrualReversalJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, true);
  //     Id purchaseAccrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true);
  //     Id cancelPurchaseAccrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL, true);

  //     List<LoyaltyLedger> llList = [
  //       SELECT Points, AdditionalNotes, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtypeId, EventType, CreatedDate
  //       FROM LoyaltyLedger
  //       WHERE
  //         TransactionJournal.OrderId = :data[0].OrderId
  //         AND (TransactionJournal.JournalTypeId = :accrualJtId
  //         OR TransactionJournal.JournalTypeId = :accrualReversalJtId)
  //         AND (TransactionJournal.JournalSubTypeId = :purchaseAccrualJstId
  //         OR TransactionJournal.JournalSubTypeId = :cancelPurchaseAccrualJstId)
  //       ORDER BY CreatedDate ASC
  //       LIMIT 100
  //     ];

  //     if (llList.isEmpty()) {
  //       throw new CustomException(400, '구매 시 적립된 포인트 내역이 존재하지 않습니다. ' + data[0].OrderId);
  //     }

  //     Map<String, Decimal> netPointMap = new Map<String, Decimal>();

  //     for (LoyaltyLedger ll : llList) {
  //       if (String.isBlank(ll.AdditionalNotes)) {
  //         continue;
  //       }

  //       String key = ll.AdditionalNotes;

  //       if (!netPointMap.containsKey(key)) {
  //         netPointMap.put(key, 0);
  //       }

  //       if (ll.EventType == 'Credit') {
  //         netPointMap.put(key, netPointMap.get(key) + ll.Points);
  //       } else if (ll.EventType == 'Debit') {
  //         netPointMap.put(key, netPointMap.get(key) - ll.Points);
  //       }
  //     }

  //     List<CancelPurchasePoints> cppList = new List<CancelPurchasePoints>();

  //     for (String key : netPointMap.keySet()) {
  //       Decimal remainPts = netPointMap.get(key);
  //       if (remainPts == null || remainPts <= 0) {
  //         continue;
  //       }

  //       List<String> parts = key.split('\\|');

  //       String subtypeName = parts[0];
  //       Id subtypeId = (Id) parts[1];
  //       String rateStr = parts[2];
  //       Decimal rate = Decimal.valueOf(rateStr);

  //       cppList.add(new CancelPurchasePoints(remainPts, subtypeId, subtypeName, rate));
  //     }

  //     if (cppList.isEmpty()) {
  //       return;
  //     }

  //     TransactionJournal tj = new TransactionJournal();
  //     tj.ActivityDate = Datetime.now();
  //     tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
  //     tj.MemberId = data[0].MemberId;
  //     tj.OrderId = data[0].OrderId;
  //     tj.JournalTypeId = accrualReversalJtId;
  //     tj.JournalSubTypeId = cancelPurchaseAccrualJstId;
  //     tj.Status = 'Pending';

  //     insert tj;

  //     Map<Id, List<CancelPurchasePoints>> cppGroupMap = new Map<Id, List<CancelPurchasePoints>>();

  //     for (CancelPurchasePoints cp : cppList) {
  //       if (!cppGroupMap.containsKey(cp.loyaltyPgmCrcySubtypeId)) {
  //         cppGroupMap.put(cp.loyaltyPgmCrcySubtypeId, new List<CancelPurchasePoints>());
  //       }
  //       cppGroupMap.get(cp.loyaltyPgmCrcySubtypeId).add(cp);
  //     }

  //     List<Map<String, Object>> reqList = new List<Map<String, Object>>();

  //     for (Id subtypeId : cppGroupMap.keySet()) {
  //       // 포인트 별로 환불 원금 다시 시작
  //       Decimal remainCancelAmountForSubtype = totalCancelAmount;

  //       List<CancelPurchasePoints> bucketList = cppGroupMap.get(subtypeId);

  //       // 비율 오름차순 정렬 (1.00 → 2.00 → 3.00 ...)
  //       bucketList.sort(new CancelRateSorter());

  //       for (CancelPurchasePoints cp : bucketList) {
  //         if (remainCancelAmountForSubtype <= 0) {
  //           break;
  //         }

  //         Decimal rateFraction = cp.rate / 100;
  //         if (rateFraction <= 0) {
  //           continue;
  //         }

  //         // 이 버킷에서 최대 취소 가능한 원금 금액
  //         // cp.points = 남아있는 포인트
  //         // cp.points / rateFraction = 해당 포인트가 커버하는 원금
  //         Decimal maxCancelableAmount = cp.points / rateFraction;

  //         // 이번 포인트 타입에서 남아있는 환불 원금과 비교
  //         Decimal useAmountFromThis = (remainCancelAmountForSubtype > maxCancelableAmount) ? maxCancelableAmount : remainCancelAmountForSubtype;

  //         if (useAmountFromThis <= 0) {
  //           continue;
  //         }

  //         // 실제 취소할 포인트
  //         Decimal cancelPoints = useAmountFromThis * rateFraction;

  //         if (cancelPoints > cp.points) {
  //           cancelPoints = cp.points;
  //         }

  //         if (cancelPoints <= 0) {
  //           continue;
  //         }

  //         Map<String, Object> req = new Map<String, Object>();
  //         req.put('loyaltyProgramMemberId', data[0].MemberId);
  //         req.put('points', cancelPoints);
  //         req.put('journalId', tj.Id);
  //         req.put('additionalNotes', cp.loyaltyPgmCrcySubtypeName + '|' + String.valueOf(cp.loyaltyPgmCrcySubtypeId) + '|' + String.valueOf(cp.rate));
  //         req.put('loyaltyProgramCurrencySubtypeName', cp.loyaltyPgmCrcySubtypeName);

  //         reqList.add(req);

  //         // 이 포인트 타입에서 남아있는 환불 원금 차감
  //         remainCancelAmountForSubtype -= useAmountFromThis;
  //       }
  //     }

  //     if (!reqList.isEmpty()) {
  //       LoyaltyPointService.debitPoints(reqList);
  //     }
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  // /**
  //  * 포인트 사용
  //  */
  // public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj) {
  //   try {
  //     if (tj == null) {
  //       throw new CustomException(400, 'TransactionJournal is null');
  //     }

  //     // 저널 유형 체크
  //     Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);

  //     // 저날 하위 유형 체크
  //     Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
  //     Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

  //     tj.JournalReason__c = '1'; // 1 : 사용
  //     tj.JournalTypeId = jtId;
  //     tj.JournalSubTypeId = jstId;
  //     tj.Status = 'Pending';

  //     insert tj;

  //     List<Map<String, Object>> reqList = new List<Map<String, Object>>();
  //     Map<String, Object> req = new Map<String, Object>();

  //     req.put('loyaltyProgramMemberId', tj.MemberId);
  //     req.put('points', tj.transactionAmount);
  //     req.put('journalId', tj.Id);
  //     reqList.add(req);
  //     List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);

  //     // 포인트 사용 추적 조회
  //     List<LoyaltyLedgerTraceability> lltList = [
  //       SELECT
  //         LoyaltyPgmCurrencySubtype.Name,
  //         Points,
  //         CreditLoyaltyLedger.ExpiryDate,
  //         LoyaltyProgramMember.Contact.MemberNo__c,
  //         LastModifiedDate,
  //         DebitLoyaltyLedgerId,
  //         LoyaltyPgmCurrencySubtype.PointTypeCode__c
  //       FROM LoyaltyLedgerTraceability
  //       WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
  //       LIMIT 100
  //     ];
  //     if (lltList.isEmpty()) {
  //       throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
  //     }

  //     List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
  //     for (LoyaltyLedgerTraceability llt : lltList) {
  //       GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
  //       pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
  //       pcDto.CD_JOURNAL = tj.Id;
  //       pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
  //       pcDto.CD_RESON = tj.JournalReason__c;
  //       pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c;
  //       pcDto.NO_SAL = llt.LoyaltyProgramMember.Contact.MemberNo__c;
  //       pcDto.PT_USE = llt.Points; // 사용처리된 금액
  //       pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 사용처리된 금액

  //       pdDtoList.add(pcDto);
  //     }
  //     return pdDtoList;
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  // /**
  //  * 포인트 사용 취소
  //  */
  // // public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
  // //   Map<String, Object> response = new Map<String, Object>();

  // //   try {
  // //     if (tj == null) {
  // //       throw new CustomException(400, 'TransactionJournal is null');
  // //     }

  // //     // 저널 유형 체크
  // //     Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);

  // //     // 저날 하위 유형 체크
  // //     Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, 'JournalTypeId' => jtId };
  // //     Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

  // //     tj.JournalTypeId = jtId;
  // //     tj.JournalSubTypeId = jstId;
  // //     tj.Status = 'Pending';

  // //     insert tj;

  // //     // 포인트 마스터 Id
  // //     Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

  // //     List<Order> oList = [SELECT Id FROM Order WHERE Id = :tj.OrderId LIMIT 1];
  // //     if (oList.isEmpty()) {
  // //       throw new CustomException(400, 'Order is null');
  // //     }

  // //     // 포인트 사용/사용취소 상세 이력 조회
  // //     List<LoyaltyLedgerTraceability> lltList = [
  // //       SELECT
  // //         Id,
  // //         CreditLoyaltyLedgerId,
  // //         DebitLoyaltyLedgerId,
  // //         CreditLoyaltyLedger.ExpiryDate,
  // //         LoyaltyPgmCurrencySubtype.Name,
  // //         LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
  // //         ActionType,
  // //         Points,
  // //         LoyaltyPgmCurrencySubtypeId
  // //       FROM LoyaltyLedgerTraceability
  // //       WHERE
  // //         LoyaltyProgramMemberId = :tj.MemberId
  // //         AND (CreditLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId
  // //         OR DebitLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId)
  // //         AND ActionType = 'Debit'
  // //         AND Points > 0
  // //       ORDER BY CreditLoyaltyLedger.ExpiryDate DESC, LoyaltyPgmCurrencySubtype.UsagePriorityNumber DESC
  // //       LIMIT 100
  // //     ];

  // //     if (lltList.isEmpty()) {
  // //       throw new CustomException(400, '포인트 사용 내역이 존재하지 않습니다. ' + tj.OrderId);
  // //     }

  // //     // 포인트 사용 건 추출 = 사용('Debit') - 사용 취소('DebitCancellation')
  // //     Map<String, NetUsage> netMap = new Map<String, NetUsage>();

  // //     for (LoyaltyLedgerTraceability llt : lltList) {
  // //       String creditLoyaltyLedgerId = ValidationUtil.stringValidation(llt.CreditLoyaltyLedgerId, 'CreditLoyaltyLedgerId', true); // 적립 원장 ID
  // //       String debitLoyaltyLedgerId = ValidationUtil.stringValidation(llt.DebitLoyaltyLedgerId, 'DebitLoyaltyLedgerId', true); // 사용 원장 ID
  // //       Date expiryDate = ValidationUtil.dateValidation(llt.CreditLoyaltyLedger.ExpiryDate, 'CreditLoyaltyLedger.ExpiryDate', true); // 적립 원장의 만료일
  // //       String loyaltyPgmCurrencySubtypeName = ValidationUtil.stringValidation( // 포인트 하위 유형 이름
  // //         llt.LoyaltyPgmCurrencySubtype.Name,
  // //         'LoyaltyPgmCurrencySubtype.Name',
  // //         true
  // //       );
  // //       Integer usagePriorityNumber = ValidationUtil.integerValidation( // 포인트 하위 유형 사용 우선 순위
  // //         llt.LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
  // //         'LoyaltyPgmCurrencySubtype.UsagePriorityNumber',
  // //         true
  // //       );
  // //       String actionType = ValidationUtil.stringValidation(llt.ActionType, 'ActionType', true); // 사용 유형
  // //       Decimal points = ValidationUtil.decimalValidation(llt.Points, 'Points', true); // 포인트
  // //       String loyaltyPgmCurrencySubtypeId = ValidationUtil.stringValidation(llt.LoyaltyPgmCurrencySubtypeId, 'LoyaltyPgmCurrencySubtypeId', true); // 포인트 하위 유형 ID

  // //       String key = String.valueOf(expiryDate) + '|' + loyaltyPgmCurrencySubtypeName + '|' + String.valueOf(usagePriorityNumber);

  // //       if (!netMap.containsKey(key)) {
  // //         netMap.put(
  // //           key,
  // //           new NetUsage(
  // //             llt.Id,
  // //             expiryDate,
  // //             loyaltyPgmCurrencySubtypeName,
  // //             usagePriorityNumber,
  // //             loyaltyPgmCurrencySubtypeId,
  // //             creditLoyaltyLedgerId,
  // //             debitLoyaltyLedgerId
  // //           )
  // //         );
  // //       }
  // //       NetUsage nu = netMap.get(key);

  // //       nu.netPoints += points;
  // //     }

  // //     // Map -> List 변환
  // //     List<NetUsage> netList = new List<NetUsage>(netMap.values());

  // //     // 만료일 DESC, 우선순위 DESC 로 정렬
  // //     netList.sort(new NetUsageCancelSorter());

  // //     Decimal remain = tj.TransactionAmount; // 취소할 금액
  // //     Date today = Date.today(); // 오늘 날짜

  // //     List<CancelPortion> expiredCancelList = new List<CancelPortion>(); // 만료 대상 리스트
  // //     List<CancelPortion> unexpiredCancelList = new List<CancelPortion>(); // 만료 대상 아닌 리스트

  // //     // 취소 할 포인트 선정
  // //     for (NetUsage nu : netList) {
  // //       if (remain <= 0)
  // //         break;

  // //       // 이 구간에서 취소 가능한 포인트 없음
  // //       if (nu.netPoints == null || nu.netPoints <= 0) {
  // //         continue;
  // //       }

  // //       // 이 항목에서 최대 취소 가능한 양
  // //       Decimal possible = nu.netPoints;
  // //       Decimal fromThis = (remain > possible) ? possible : remain;

  // //       if (fromThis <= 0) {
  // //         continue;
  // //       }

  // //       Boolean isExpired = (nu.expiryDate != null && nu.expiryDate <= today); // todo : 포인트 만료일자 확인 후 다시 설정 필요

  // //       if (isExpired) {
  // //         expiredCancelList.add(new CancelPortion(nu, fromThis));
  // //       } else {
  // //         unexpiredCancelList.add(new CancelPortion(nu, fromThis));
  // //       }

  // //       remain -= fromThis;
  // //     }

  // //     // ================================================================================================================================
  // //     // 기존 Debit LLT 부분 제거 + 재생성 블록
  // //     List<LoyaltyLedgerTraceability> deleteDebitList = new List<LoyaltyLedgerTraceability>();
  // //     List<LoyaltyLedgerTraceability> insertRemainDebitList = new List<LoyaltyLedgerTraceability>();

  // //     // 어떤 LLT가 얼마나 취소됐는지 집계
  // //     Map<Id, Decimal> cancelSumByLLT = new Map<Id, Decimal>();

  // //     for (CancelPortion cp : expiredCancelList) {
  // //       cancelSumByLLT.put(
  // //         cp.loyaltyLedgerTraceabilityId,
  // //         (cancelSumByLLT.containsKey(cp.loyaltyLedgerTraceabilityId) ? cancelSumByLLT.get(cp.loyaltyLedgerTraceabilityId) : 0) + cp.cancelPoints
  // //       );
  // //     }

  // //     for (CancelPortion cp : unexpiredCancelList) {
  // //       cancelSumByLLT.put(
  // //         cp.loyaltyLedgerTraceabilityId,
  // //         (cancelSumByLLT.containsKey(cp.loyaltyLedgerTraceabilityId) ? cancelSumByLLT.get(cp.loyaltyLedgerTraceabilityId) : 0) + cp.cancelPoints
  // //       );
  // //     }

  // //     if (cancelSumByLLT.isEmpty()) {
  // //       throw new CustomException(400, '취소 대상 금액이 존재하지 않습니다.');
  // //     }

  // //     //  원본 Debit LLT 다시 조회 (Id 기준으로만)
  // //     List<LoyaltyLedgerTraceability> originalDebitList = [
  // //       SELECT Id, Points, LoyaltyProgramMemberId, LoyaltyPgmCurrencySubtypeId, LoyaltyProgramCurrencyId, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId
  // //       FROM LoyaltyLedgerTraceability
  // //       WHERE Id IN :cancelSumByLLT.keySet()
  // //     ];

  // //     // LLT 하나씩 판단
  // //     for (LoyaltyLedgerTraceability orig : originalDebitList) {
  // //       Decimal originalPts = orig.Points;
  // //       Decimal cancelledPts = cancelSumByLLT.get(orig.Id);
  // //       Decimal remainPts = originalPts - cancelledPts;

  // //       // 기존 LLT는 무조건 delete
  // //       deleteDebitList.add(orig);

  // //       // 남은 포인트가 있으면 새로운 Debit LLT로 생성
  // //       if (remainPts > 0) {
  // //         LoyaltyLedgerTraceability newDebit = new LoyaltyLedgerTraceability();
  // //         newDebit.LoyaltyProgramMemberId = orig.LoyaltyProgramMemberId;
  // //         newDebit.LoyaltyPgmCurrencySubtypeId = orig.LoyaltyPgmCurrencySubtypeId;
  // //         newDebit.LoyaltyProgramCurrencyId = orig.LoyaltyProgramCurrencyId;
  // //         newDebit.Points = remainPts;
  // //         newDebit.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
  // //         newDebit.DebitLoyaltyLedgerId = orig.DebitLoyaltyLedgerId;
  // //         newDebit.CreditLoyaltyLedgerId = orig.CreditLoyaltyLedgerId;

  // //         insertRemainDebitList.add(newDebit);
  // //       }
  // //     }

  // //     // (DML 실행 순서 중요)
  // //     if (!deleteDebitList.isEmpty()) {
  // //       delete deleteDebitList;
  // //     }
  // //     if (!insertRemainDebitList.isEmpty()) {
  // //       insert insertRemainDebitList;
  // //     }
  // //     // ================================================================================================================================

  // //     // 포인트 사용 취소 금액이 남아 있는 경우
  // //     if (remain > 0) {
  // //       throw new CustomException(400, '취소 요청 포인트가 실제 사용 포인트보다 큽니다.');
  // //     }

  // //     // 취소 -> 만료 처리 케이스
  // //     if (!expiredCancelList.isEmpty()) {
  // //       List<LoyaltyLedger> expireLedgerList = new List<LoyaltyLedger>();
  // //       List<TraceSeed> traceSeedList = new List<TraceSeed>();

  // //       List<Map<String, Object>> expiredPointList = new List<Map<String, Object>>();

  // //       for (CancelPortion expiredCancel : expiredCancelList) {
  // //         // 사용 취소 원장
  // //         LoyaltyLedger expireLedger = new LoyaltyLedger();
  // //         expireLedger.LoyaltyProgramMemberId = tj.MemberId;
  // //         expireLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
  // //         expireLedger.TransactionJournalId = tj.Id;
  // //         expireLedger.ActivityDate = Datetime.now();
  // //         expireLedger.LoyaltyPgmCrcySubtypeId = expiredCancel.loyaltyPgmCurrencySubtypeId;
  // //         expireLedger.Points = expiredCancel.cancelPoints;
  // //         expireLedger.ExpiryDate = expiredCancel.expiryDate;
  // //         expireLedger.EventType = 'Credit'; // 지급

  // //         expireLedgerList.add(expireLedger);

  // //         // 만료 원장 (사용 취소 원장 복제)
  // //         LoyaltyLedger creditLedger = expireLedger.clone(false, true, true, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
  // //         creditLedger.EventType = 'Expiry'; // 만료
  // //         expireLedgerList.add(creditLedger);

  // //         traceSeedList.add(
  // //           new TraceSeed(
  // //             expiredCancel.debitLoyaltyLedgerId, // 기존 사용(차감) 레저 Id
  // //             creditLedger // 새로 만든 사용취소용 레저(Traceability에서 Credit 쪽으로 볼 대상)
  // //           )
  // //         );

  // //         // return 값 담기
  // //         Map<String, Object> expiredPoint = new Map<String, Object>();
  // //         expiredPoint.put('Point', expiredCancel.cancelPoints);
  // //         expiredPoint.put('Name', expiredCancel.pointSubTypeName);
  // //         expiredPoint.put('ExpiryDate', String.valueOf(expiredCancel.expiryDate));
  // //         expiredPointList.add(expiredPoint);
  // //       }
  // //       response.put('ExpiryPointList', expiredPointList);

  // //       insert expireLedgerList;

  // //       List<LoyaltyLedgerTraceability> debitCancellationTracebilityList = new List<LoyaltyLedgerTraceability>();

  // //       for (TraceSeed seed : traceSeedList) {
  // //         LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability();
  // //         t.LoyaltyProgramMemberId = tj.MemberId;
  // //         t.LoyaltyPgmCurrencySubtypeId = seed.creditLedger.LoyaltyPgmCrcySubtypeId;
  // //         t.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
  // //         t.Points = seed.creditLedger.Points;
  // //         t.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION;
  // //         t.DebitLoyaltyLedgerId = seed.debitLedgerId; // 원래 사용 원장 ID
  // //         t.CreditLoyaltyLedgerId = seed.creditLedger.Id; // 지금 만든 취소용 원장 ID

  // //         debitCancellationTracebilityList.add(t);
  // //       }

  // //       if (!debitCancellationTracebilityList.isEmpty()) {
  // //         insert debitCancellationTracebilityList;
  // //       }
  // //     }

  // //     // 취소 -> 재지급 하는 케이스
  // //     if (!unexpiredCancelList.isEmpty()) {
  // //       List<Map<String, Object>> reqList = new List<Map<String, Object>>();

  // //       List<Map<String, Object>> recreditPointList = new List<Map<String, Object>>();

  // //       Map<String, TraceSeed> traceSeedMap = new Map<String, TraceSeed>();

  // //       for (CancelPortion unexpiredCancel : unexpiredCancelList) {
  // //         Map<String, Object> req = new Map<String, Object>();
  // //         req.put('loyaltyProgramMemberId', tj.MemberId);
  // //         req.put('loyaltyProgramCurrencyId', loyaltyProgramCurrencyId);
  // //         req.put('journalId', tj.Id);
  // //         req.put('loyaltyProgramCurrencySubtypeName', unexpiredCancel.pointSubTypeName);
  // //         req.put('points', unexpiredCancel.cancelPoints);
  // //         req.put('pointsExpirationDate', String.valueOf(unexpiredCancel.expiryDate));
  // //         reqList.add(req);

  // //         String traceKey = String.valueOf(tj.Id) + '|' + unexpiredCancel.pointSubTypeName + '|' + String.valueOf(unexpiredCancel.expiryDate);

  // //         traceSeedMap.put(
  // //           traceKey,
  // //           new TraceSeed(
  // //             unexpiredCancel.debitLoyaltyLedgerId, // 기존 사용(차감) 레저 Id
  // //             null
  // //           )
  // //         );

  // //         // return 값 담기
  // //         Map<String, Object> recreditPoint = new Map<String, Object>();
  // //         recreditPoint.put('Point', unexpiredCancel.cancelPoints);
  // //         recreditPoint.put('Name', unexpiredCancel.pointSubTypeName);
  // //         recreditPoint.put('ExpiryDate', String.valueOf(unexpiredCancel.expiryDate));
  // //         recreditPointList.add(recreditPoint);
  // //       }
  // //       response.put('RecreditPointList', recreditPointList);

  // //       List<LoyaltyManagement.CreditPointsOutput> creditPointsOutputs = LoyaltyPointService.creditPoints(reqList);

  // //       List<LoyaltyLedger> creditLedgerList = [
  // //         SELECT Id, ExpiryDate, LoyaltyPgmCrcySubtype.Name, TransactionJournalId, Points
  // //         FROM LoyaltyLedger
  // //         WHERE TransactionJournalId = :tj.Id AND EventType = 'Credit'
  // //         LIMIT 100
  // //       ];

  // //       for (LoyaltyLedger creditLedger : creditLedgerList) {
  // //         String traceKey =
  // //           String.valueOf(creditLedger.TransactionJournalId) +
  // //           '|' +
  // //           creditLedger.LoyaltyPgmCrcySubtype.Name +
  // //           '|' +
  // //           String.valueOf(creditLedger.ExpiryDate);

  // //         if (traceSeedMap.containsKey(traceKey)) {
  // //           TraceSeed seed = traceSeedMap.get(traceKey);
  // //           seed.creditLedger = creditLedger;
  // //         }
  // //       }

  // //       // Traceability 생성
  // //       List<LoyaltyLedgerTraceability> traceList = new List<LoyaltyLedgerTraceability>();

  // //       for (String key : traceSeedMap.keySet()) {
  // //         TraceSeed seed = traceSeedMap.get(key);

  // //         if (seed.creditLedger == null) {
  // //           throw new CustomException(500, '재지급 원장 매핑 실패 : ' + key);
  // //         }

  // //         LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability();
  // //         t.LoyaltyProgramMemberId = tj.MemberId;
  // //         t.LoyaltyPgmCurrencySubtypeId = seed.creditLedger.LoyaltyPgmCrcySubtypeId;
  // //         t.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
  // //         t.Points = seed.creditLedger.Points;
  // //         t.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION;
  // //         t.DebitLoyaltyLedgerId = seed.debitLedgerId; // 원 사용 원장
  // //         t.CreditLoyaltyLedgerId = seed.creditLedger.Id; // 재지급 원장

  // //         traceList.add(t);
  // //       }

  // //       if (!traceList.isEmpty()) {
  // //         insert traceList;
  // //       }
  // //     } else {
  // //       tj.Status = 'Processed';
  // //       update tj;
  // //     }
  // //     return response;
  // //   } catch (ValidationException ve) {
  // //     throw new CustomException(ve.code, ve.detail);
  // //   } catch (Exception e) {
  // //     throw e;
  // //   }
  // // }

  // // 포인트 사용 취소를 위한 계산용 클래스
  // public class NetUsage {
  //   public Id loyaltyLedgerTraceabilityId;
  //   public Date expiryDate;
  //   public String pointSubTypeName;
  //   public Integer usagePriority;
  //   public Decimal netPoints = 0;
  //   public Id loyaltyPgmCurrencySubtypeId;
  //   public String creditLoyaltyLedgerId;
  //   public String debitLoyaltyLedgerId;

  //   public NetUsage(Id id, Date e, String s, Integer p, Id lpcsi, String clli, String dlli) {
  //     loyaltyLedgerTraceabilityId = id;
  //     expiryDate = e;
  //     pointSubTypeName = s;
  //     usagePriority = p;
  //     loyaltyPgmCurrencySubtypeId = lpcsi;
  //     creditLoyaltyLedgerId = clli;
  //     debitLoyaltyLedgerId = dlli;
  //   }
  // }

  // // 포인트 사용 취소 할 포인트 정렬 메서드
  // public class NetUsageCancelSorter implements System.Comparator<Object> {
  //   public Integer compare(Object a, Object b) {
  //     NetUsage x = (NetUsage) a;
  //     NetUsage y = (NetUsage) b;
  //     // 만료일이 느린 순으로 정렬
  //     if (x.expiryDate > y.expiryDate) {
  //       return -1; // x를 먼저
  //     }
  //     if (x.expiryDate < y.expiryDate) {
  //       return 1; // y를 먼저
  //     }

  //     // 우선순위 정렬 (사용 우선 순위가 낮은 순서대로 정렬)
  //     if (x.usagePriority > y.usagePriority) {
  //       return -1;
  //     }
  //     if (x.usagePriority < y.usagePriority) {
  //       return 1;
  //     }

  //     // 최종 (이름 순..)
  //     return x.pointSubTypeName.toLowerCase().compareTo(y.pointSubTypeName.toLowerCase());
  //   }
  // }

  // // 포인트 사용 취소를 위한 클래스
  // public class CancelPortion {
  //   public Id loyaltyLedgerTraceabilityId;
  //   public Date expiryDate;
  //   public String pointSubTypeName;
  //   public Integer usagePriority;
  //   public Decimal cancelPoints;
  //   public Id loyaltyPgmCurrencySubtypeId;
  //   public String creditLoyaltyLedgerId;
  //   public String debitLoyaltyLedgerId;

  //   public CancelPortion(NetUsage nu, Decimal cancelPoints) {
  //     this.loyaltyLedgerTraceabilityId = nu.loyaltyLedgerTraceabilityId;
  //     this.expiryDate = nu.expiryDate;
  //     this.pointSubTypeName = nu.pointSubTypeName;
  //     this.usagePriority = nu.usagePriority;
  //     this.cancelPoints = cancelPoints;
  //     this.loyaltyPgmCurrencySubtypeId = nu.loyaltyPgmCurrencySubtypeId;
  //     this.creditLoyaltyLedgerId = nu.creditLoyaltyLedgerId;
  //     this.debitLoyaltyLedgerId = nu.debitLoyaltyLedgerId;
  //   }
  // }

  // // 포인트 사용 취소를 위한 추적용 클래스
  // public class TraceSeed {
  //   public Id debitLedgerId;
  //   public LoyaltyLedger creditLedger;

  //   public TraceSeed(Id debitLedgerId, LoyaltyLedger creditLedger) {
  //     this.debitLedgerId = debitLedgerId;
  //     this.creditLedger = creditLedger;
  //   }
  // }

  // // 구매 적립 포인트 취소를 위한 클래스
  // public class CancelPurchasePoints {
  //   public Decimal points; // 해당 비율/타입에 대해 남아 있는 순 포인트
  //   public Id loyaltyPgmCrcySubtypeId; // 포인트 하위 유형 Id
  //   public String loyaltyPgmCrcySubtypeName; // 포인트 하위 유형 Name
  //   public Decimal rate;

  //   public CancelPurchasePoints(Decimal p, Id lpcsi, String lpcsn, Decimal r) {
  //     this.points = p;
  //     this.loyaltyPgmCrcySubtypeId = lpcsi;
  //     this.loyaltyPgmCrcySubtypeName = lpcsn;
  //     this.rate = r;
  //   }
  // }

  // // 구매 적립 포인트 취소를 위한 정렬 메서드
  // public class CancelRateSorter implements Comparator<CancelPurchasePoints> {
  //   public Integer compare(CancelPurchasePoints a, CancelPurchasePoints b) {
  //     if (a.rate == null && b.rate == null)
  //       return 0;
  //     if (a.rate == null)
  //       return 1;
  //     if (b.rate == null)
  //       return -1;

  //     if (a.rate < b.rate)
  //       return -1;
  //     if (a.rate > b.rate)
  //       return 1;
  //     return 0;
  //   }
  // }

  // public class DepositResponseDTO {
  //   public String CD_TYPE_APPR; // 결제 구분
  //   public Decimal AM_DEPOSIT; // 금액
  //   public String NO_COUPON_ALL; // 쿠폰 코드
  //   public String NM_COUPON; // 쿠폰명
  //   public Date DT_EXP; // 만료 날짜
  //   public Integer RT_DISC; // 할인율
  //   public Decimal AM_DISC; // 할인 금액
  //   public String TX_REMARK; // 비고
  // }
}