public with sharing class GdReturnDepositServiceImpl implements GdReturnDepositService {
  private static GdVoucherService voucherService;
  private static GdPointService pointService;

  private static final String JOURNAL_TYPE_NAME_DEPOSIT = 'Deposit';
  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual';
  private static final String JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL = 'Accrual Reversal';
  private static final String JOURNAL_TYPE_NAME_REDEMPTION = 'Redemption';
  private static final String JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL = 'Redemption Reversal';
  private static final String JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL = 'Deposit Reversal';

  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT = 'Order Deposit';
  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL = 'Order Deposit Reversal';
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT = 'Sale Deposit';
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL = 'Sale Deposit Reversal';
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_DEBIT = 'Point Debit';
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL = 'Purchase Accrual';
  private static final String JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual';
  private static final String JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL = 'Promotion Point Accrual Reversal';
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM = 'Coupon Redeem';
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL = 'Coupon Redeem Cancel';
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT = 'Api Forced Credit'; // API 요청에 의한 포인트 강제 지급(적립) 처리
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT = 'Api Forced Debit'; // API 요청에 의한 포인트 강제 차감 처리

  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT = 'Debit';
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION = 'DebitCancellation';
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION = 'CreditCancellation';

  private static final String ECO_POINT_TYPE_CODE = '05';
  private static final String ECO_POINT_CANCEL_NOTE = 'FULL_RETURN_ECO_POINT_CANCEL';
  private static final String ECO_POINT_RESTORE_NOTE = 'FULL_RETURN_ECO_POINT_RESTORE';
  private static final String ECO_POINT_CANCEL_RESULT_KEY = 'FullReturnEcoPointCancelList';
  private static final String ECO_POINT_RESTORE_RESULT_KEY = 'FullReturnEcoPointRestoreList';
  // [Eco Cancel Fix 2026-05-03] 반품 입금 삭제 재차감 보조 TJ 마커 (다른 5개 메서드와 동일 정책)
  //   다른 클래스 정의: GdMemberHelpInfoServiceImpl:46, GdReturnServiceImpl:7, GdSaleDepositServiceImpl:73, GdPointServiceImpl:40
  private static final String RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';

  private static void logTiming(String label, Long startMs, Integer startCpu) {
    Long elapsedMs = Datetime.now().getTime() - startMs;
    Integer elapsedCpu = Limits.getCpuTime() - startCpu;
    System.debug(LoggingLevel.WARN, '[TIMING] ' + label + ' | 누적 ' + elapsedMs + 'ms | CPU ' + elapsedCpu + 'ms');
  }

  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  private static GdVoucherService getVoucherService() {
    if (voucherService == null) {
      voucherService = new GdVoucherServiceImpl();
    }
    return voucherService;
  }

  @TestVisible
  private static void setPointService(GdPointService mock) {
    pointService = mock;
  }

  private static GdPointService getPointService() {
    if (pointService == null) {
      pointService = new GdPointServiceImpl();
    }
    return pointService;
  }

  private static void alignCouponCancelJournalToRedeemSource(TransactionJournal tj) {
    if (tj == null || String.isBlank(tj.VoucherCode) || tj.MemberId == null) {
      return;
    }

    // 기존
    // List<Voucher> voucherList = [
    //   SELECT UsedTransactionJournalId__c, UsedTransactionJournalId__r.OrderId, UsedTransactionJournalId__r.OrderId__c
    //   FROM Voucher
    //   WHERE VoucherCode = :tj.VoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Redeemed'
    //   LIMIT 1
    // ];

    // 26.05.01 GD - 쿠폰 코드 분할 쿠폰 조회
    String searchVoucherCode = tj.VoucherCode;
    List<Voucher> voucherList = new List<Voucher>();

    if (String.isNotBlank(searchVoucherCode) && searchVoucherCode.contains(';-;')) {
        String couponManNo = searchVoucherCode.substringBefore(';-;');
        String realVoucherCode = searchVoucherCode.substringAfter(';-;'); 
        
        voucherList = [
            SELECT UsedTransactionJournalId__c, UsedTransactionJournalId__r.OrderId, UsedTransactionJournalId__r.OrderId__c
            FROM Voucher
            WHERE VoucherCode = :realVoucherCode 
              AND LoyaltyProgramMemberId = :tj.MemberId 
              AND Status = 'Redeemed'
              AND VoucherDefinition.CouponManNo__c = :couponManNo
            LIMIT 1
        ];
    } else {
        voucherList = [
            SELECT UsedTransactionJournalId__c, UsedTransactionJournalId__r.OrderId, UsedTransactionJournalId__r.OrderId__c
            FROM Voucher
            WHERE VoucherCode = :searchVoucherCode 
              AND LoyaltyProgramMemberId = :tj.MemberId 
              AND Status = 'Redeemed'
            LIMIT 1
        ];
    }

    if (voucherList.isEmpty() || voucherList[0].UsedTransactionJournalId__c == null) {
      return;
    }

    TransactionJournal sourceRedeemJournal = voucherList[0].UsedTransactionJournalId__r;
    if (sourceRedeemJournal == null) {
      return;
    }

    if (sourceRedeemJournal.OrderId != null) {
      tj.OrderId = sourceRedeemJournal.OrderId;
    }

    if (sourceRedeemJournal.OrderId__c != null) {
      tj.OrderId__c = sourceRedeemJournal.OrderId__c;
    } else if (sourceRedeemJournal.OrderId != null) {
      tj.OrderId__c = sourceRedeemJournal.OrderId;
    }
  }

  /**
   * 반품 입금 이력 생성
   */
  public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      List<Object> transactionJournalList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      List<Object> returnOrderItemRequestList = getReturnOrderItemRequestList(reqData);

      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // 반품 건 OrderId
      String originalOrderId = ValidationUtil.stringValidation(reqData.get('originalOrderId'), 'originalOrderId', true); // 원판매 Id
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true); // 등록자

      List<Order> returnOrderList = [SELECT Id, ActualPaymentAmount__c, InsertId__c FROM Order WHERE Id = :orderId LIMIT 1];
      if (returnOrderList.isEmpty()) {
        throw new CustomException(400, '해당 반품 건이 없습니다. ' + orderId);
      }
      // 프로모션 번호 체크
      List<TransactionJournal> tjPromotionNoList = [
        SELECT Id, PromotionId, Promotion.PromotionNo__c
        FROM TransactionJournal
        WHERE OrderId = :originalOrderId AND PromotionId != NULL
        ORDER BY CreatedDate ASC
        LIMIT 1
      ];

      // 로열티 회원 체크
      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId, Contact.Grade__c
        FROM LoyaltyProgramMember
        WHERE ContactId IN (SELECT MemberNo__c FROM Order WHERE Id = :originalOrderId)
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 주문에 회원이 존재하지 않습니다. ' + originalOrderId);
      }

      // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.initialSetup', totalStartMs, totalStartCpu);

      GdVoucherService voucherSvc = getVoucherService();
      GdPointService pointSvc = getPointService();

      List<TransactionJournal> tjList = new List<TransactionJournal>();
      List<TransactionJournal> depositTransactionList = new List<TransactionJournal>();
      List<TransactionJournal> cancelDepositTransactionList = new List<TransactionJournal>();

      for (Object v : transactionJournalList) {
        Map<String, Object> transactionJournal = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);

        String depositNo = ValidationUtil.stringValidation(transactionJournal.get('DepositNo__c'), 'DepositNo__c', true);
        String deposiSeqNo = ValidationUtil.stringValidation(transactionJournal.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true);
        Date activityDate = ValidationUtil.dateValidation(transactionJournal.get('ActivityDate'), 'ActivityDate', true);
        String paymentMethod = ValidationUtil.stringValidation(transactionJournal.get('PaymentMethod'), 'PaymentMethod', true);
        String depositType = ValidationUtil.stringValidation(transactionJournal.get('DepositType__c'), 'DepositType__c', true);
        Decimal transactionAmount = ValidationUtil.decimalValidation(transactionJournal.get('TransactionAmount'), 'TransactionAmount', true);
        String couponNo = ValidationUtil.stringValidationEx(transactionJournal.get('CouponNo'), 'CouponNo', false, true);

        TransactionJournal tj = new TransactionJournal();
        tj.DepositNo__c = depositNo + '-' + deposiSeqNo;
        tj.DeposiSeqNo__c = deposiSeqNo;
        tj.LoyaltyProgramId = lpmList[0].ProgramId;
        tj.JournalDate = activityDate;
        tj.ActivityDate = Datetime.now();
        tj.PaymentMethod = paymentMethod;
        tj.DepositType__c = depositType;
        tj.TransactionAmount = transactionAmount;
        tj.MemberId = lpmList[0].Id;
        tj.OrderId = originalOrderId;
        tj.SaleId__c = orderId;
        tj.Status = 'Pending';
        tj.InsertId__c = insertId;
        if (!tjPromotionNoList.isEmpty()) {
          tj.PromotionId = tjPromotionNoList[0].PromotionId;
        }

        if (String.isNotBlank(couponNo)) {
          tj.VoucherCode = couponNo;
          tj.Status = 'Processed';
          if ('03'.equals(depositType)) {
            alignCouponCancelJournalToRedeemSource(tj);
            // 쿠폰 사용 취소
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true);
            // Long actionStartMs = Datetime.now().getTime();
            // Integer actionStartCpu = Limits.getCpuTime();
            voucherSvc.redeemCancelVoucher(tj);
            // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.redeemCancelVoucher', actionStartMs, actionStartCpu);
          } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            // 쿠폰 사용
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
            // Long actionStartMs = Datetime.now().getTime();
            // Integer actionStartCpu = Limits.getCpuTime();
            voucherSvc.redeemVoucherV2(tj);
            // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.redeemVoucherV2', actionStartMs, actionStartCpu);
          }
          continue;
        }
              System.debug('1');

        if ('81'.equals(paymentMethod)) {
          // 포인트 사용 취소 (03 = 환불)
          if ('03'.equals(depositType)) {
            // Long actionStartMs = Datetime.now().getTime();
            // Integer actionStartCpu = Limits.getCpuTime();
              System.debug('121');
            Map<String, Object> cancelPointResult = pointSvc.cancelPointRedemption(tj);
              System.debug('122');
            // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.cancelPointRedemption', actionStartMs, actionStartCpu);
            data.put('CancelPointList', cancelPointResult);
          }
          // 포인트 사용 (01 = 선수금 | 02 = 잔금)
          else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            // Long actionStartMs = Datetime.now().getTime();
            // Integer actionStartCpu = Limits.getCpuTime();
              System.debug('123');
            List<GdSaleApiController.PointDebitDTO> debitPointList = pointSvc.debitPoint(tj);
              System.debug('124');
            // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.debitPoint', actionStartMs, actionStartCpu);
            data.put('DebitPointList', debitPointList);
          }
        } else {
          tj.Status = 'Processed';
          if ('01'.equals(depositType) || '02'.equals(depositType)) {
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true);
            depositTransactionList.add(tj);
          } else if ('03'.equals(depositType)) {
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true);
            cancelDepositTransactionList.add(tj);
          }
          tjList.add(tj);
        }
      }
              System.debug('12');

      // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.depositLoop', totalStartMs, totalStartCpu);
      if (!tjList.isEmpty()) {
        List<Database.SaveResult> resultList = Database.insert(tjList);
        // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.insertTransactionJournals', totalStartMs, totalStartCpu);
        for (Database.SaveResult result : resultList) {
          if (!result.isSuccess()) {
            Database.Error err = result.getErrors()[0];
            throw new CustomException(400, err.getMessage());
          }
        }
      }
              System.debug('13');

      // 구매 시 포인트 적립 로직
      if (!depositTransactionList.isEmpty()) {
        // Long actionStartMs = Datetime.now().getTime();
        // Integer actionStartCpu = Limits.getCpuTime();
        List<PointCreditDTO> creditPointList = pointSvc.creditPointsOnPurchase(depositTransactionList);
        // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.creditPointsOnPurchase', actionStartMs, actionStartCpu);
        for (PointCreditDTO pcDto : creditPointList) {
          pcDto.AM_SAL = returnOrderList[0].ActualPaymentAmount__c;
          pcDto.ID_INSERT = returnOrderList[0].InsertId__c;
          if (!tjPromotionNoList.isEmpty()) {
            pcDto.NO_PROM_MBR = tjPromotionNoList[0].Promotion.PromotionNo__c;
          }
          pcDto.NO_GRADE_ADVAN = lpmList[0].Contact.Grade__c;
        }
        data.put('CreditPointList', creditPointList);
      }
              System.debug('14');

      // 구매 시 포인트 적립 취소 로직
      if (!cancelDepositTransactionList.isEmpty()) {
        // System.debug('구매 시 포인트 적립 취소 로직 진입');
        // Long actionStartMs = Datetime.now().getTime();
        // Integer actionStartCpu = Limits.getCpuTime();
        // List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedList = pointSvc.cancelPointsCreditedOnPurchase(cancelDepositTransactionList);  // 기존 로직

        // 신규 로직 Start.(26.04.02)
        List<TransactionJournal> accrualEligibleCancelTransactions = buildAccrualEligibleCancelTransactions(
          originalOrderId,
          orderId,
          cancelDepositTransactionList,
          returnOrderItemRequestList
        );
        List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedList = null;
        if (!accrualEligibleCancelTransactions.isEmpty()) {
          cancelPointsCreditedList = pointSvc.cancelPointsCreditedOnPurchase(accrualEligibleCancelTransactions);
        }
        // 신규 로직 End.(26.04.02)
        // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.cancelPointsCreditedOnPurchase', actionStartMs, actionStartCpu);
        data.put('CancelPointsCreditedList', cancelPointsCreditedList);
      }
              System.debug('15');

      // 통반품 여부 확인
      if (isFullReturn(originalOrderId)) {
        // System.debug('통반품입니다.');
        // Long actionStartMs = Datetime.now().getTime();
        // Integer actionStartCpu = Limits.getCpuTime();
        // 에코포인트 회수
        List<PointDebitDTO> ecoPointCancelList = cancelEcoPointsForFullReturn(orderId, originalOrderId, lpmList[0], insertId);
        // logTiming('GdReturnDepositServiceImpl.insertSaleDepositHistoryByUpdate.cancelEcoPointsForFullReturn', actionStartMs, actionStartCpu);
        if (!ecoPointCancelList.isEmpty()) {
          data.put(ECO_POINT_CANCEL_RESULT_KEY, ecoPointCancelList);
        }
      }
      // 고재성 - 정률 쿠폰 사용 시, 부분 반품 불가
      else {
        // 기존
        // List<TransactionJournal> couponUsedOrderJournalList = [
        //   SELECT Id, VoucherCode, MemberId
        //   FROM TransactionJournal
        //   WHERE SaleId__c = :originalOrderId AND VoucherCode != NULL AND JournalSubTypeName__c = 'Coupon Redeem'
        //   LIMIT 1
        // ];

        // 26.05.01 GD - 회원 ID 조회 추가
        List<TransactionJournal> couponUsedOrderJournalList = [
          SELECT Id, VoucherCode, MemberId
          FROM TransactionJournal
          WHERE SaleId__c = :originalOrderId AND VoucherCode != NULL AND JournalSubTypeName__c = 'Coupon Redeem'
          LIMIT 1
        ];
        //

        if (!couponUsedOrderJournalList.isEmpty()) {
          // 기존
          // List<Voucher> percentageVouchers = [
          //   SELECT Id
          //   FROM Voucher
          //   WHERE VoucherCode = :couponUsedOrderJournalList[0].VoucherCode AND VoucherDefinition.Type = 'DiscountPercentage'
          //   LIMIT 1
          // ];

          // 26.05.01 GD - 쿠폰 코드 분할 쿠폰 조회
          String searchVoucherCode = couponUsedOrderJournalList[0].VoucherCode;
          Id memberId = couponUsedOrderJournalList[0].MemberId;           
          List<Voucher> percentageVouchers = new List<Voucher>();

          if (String.isNotBlank(searchVoucherCode) && searchVoucherCode.contains(';-;')) {
              String couponManNo = searchVoucherCode.substringBefore(';-;');
              String realVoucherCode = searchVoucherCode.substringAfter(';-;');
              
              percentageVouchers = [
                  SELECT Id
                  FROM Voucher
                  WHERE VoucherCode = :realVoucherCode
                    AND VoucherDefinition.CouponManNo__c = :couponManNo
                    AND LoyaltyProgramMemberId = :memberId
                    AND VoucherDefinition.Type = 'DiscountPercentage'
                  LIMIT 1
              ];
          } else {
              percentageVouchers = [
                  SELECT Id
                  FROM Voucher
                  WHERE VoucherCode = :searchVoucherCode
                    AND LoyaltyProgramMemberId = :memberId 
                    AND VoucherDefinition.Type = 'DiscountPercentage'
                  LIMIT 1
              ];
          }
          //

          if (!percentageVouchers.isEmpty()) {
            throw new CustomException(400, '정률 쿠폰 사용 시, 부분 반품이 불가합니다. 해당 판매 ID : ' + originalOrderId);
          }
        }
      }

      return ApiResult.ok(200, '반품 입금 이력 생성 완료.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // ! 사용 여부 보류
  /**
   * 반품 입금 전체 삭제
   */
  public ApiResult deleteAllReturnDeposits(Id orderId) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<TransactionJournal> tjList = [
        SELECT
          Id,
          JournalSubTypeId,
          PaymentMethod,
          TransactionAmount,
          OrderId,
          LoyaltyProgramId,
          MemberId,
          PromotionId,
          SaleId__c,
          DepositNo__c,
          IsDeleted__c,
          DeleteDateTime__c,
          VoucherCode,
          Order.OrderNo__c,
          Order.SaleNo__c,
          AdditionalNotes__c
        FROM TransactionJournal
        WHERE SaleId__c = :orderId AND IsDeleted__c = FALSE
        LIMIT 200
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 반품의 입금 이력이 존재하지 않습니다. ' + orderId);
      }

      Id couponRedeemCancelJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true);
      Id pointRedeemCancelJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, true);
      Id cancelPurchaseAccrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL, true);
      Id promotionPointAccrualReversalJstId = SObjectUtil.findIdByName(
        JournalSubType.SObjectType,
        JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL,
        true
      );
      Id pointDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, true);

      List<PointCreditDTO> ecoRestoreResult = new List<PointCreditDTO>();

      for (TransactionJournal tj : tjList) {
        TransactionJournal newTj = buildDeleteTransactionJournal(tj);

        // if (isEcoPointCancelJournal(tj, pointDebitJstId)) {
        //   ecoRestoreResult.addAll(restoreEcoPointsFromReturn(newTj, tj.Id));
        // } else
        if (
          tj.JournalSubTypeId == pointRedeemCancelJstId ||
          tj.JournalSubTypeId == couponRedeemCancelJstId ||
          tj.JournalSubTypeId == cancelPurchaseAccrualJstId ||
          tj.JournalSubTypeId == promotionPointAccrualReversalJstId
        ) {
          if (tj.JournalSubTypeId == pointRedeemCancelJstId) {
            newTj.AdditionalNotes__c = 'Restore point usage due to return deletion';
            List<LoyaltyLedger> llList = [
              SELECT Id, LoyaltyPgmCrcySubtypeId, Points, LoyaltyPgmCrcySubtype.Name, AdditionalNotes
              FROM LoyaltyLedger
              WHERE TransactionJournalId = :tj.Id
              LIMIT 100
            ];
            List<PointDebitDTO> debitPointResult = getPointService().debitSpecificPoints(newTj, llList);
            data.put('RestorePointUsageList', debitPointResult);
          } else if (tj.JournalSubTypeId == couponRedeemCancelJstId) {
            newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
            newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
            newTj.AdditionalNotes__c = 'Restore coupon usage due to return deletion';
            newTj.Status = 'Processed';
            getVoucherService().redeemVoucherV2(newTj);
          } else {
            newTj.AdditionalNotes__c = tj.JournalSubTypeId == promotionPointAccrualReversalJstId
              ? 'Restore promotion point accrual due to return deletion'
              : 'Restore purchase accrual due to return deletion';
            List<LoyaltyLedgerTraceability> lltList = [
              SELECT
                CreditLoyaltyLedger.ExpiryDate,
                LoyaltyPgmCurrencySubtype.Name,
                LoyaltyPgmCurrencySubtype.PointTypeCode__c,
                Points,
                DebitLoyaltyLedger.AdditionalNotes
              FROM LoyaltyLedgerTraceability
              WHERE DebitLoyaltyLedger.TransactionJournal.Id = :tj.Id
              LIMIT 200
            ];
            List<PointCreditDTO> creditPointResult = getPointService().creditSepcificPoints(newTj, lltList);
            data.put(
              tj.JournalSubTypeId == promotionPointAccrualReversalJstId ? 'RestorePromotionPointAccrualList' : 'RestorePurchaseAccrualList',
              creditPointResult
            );
          }
        }

        tj.IsDeleted__c = true;
        tj.DeleteDateTime__c = Datetime.now();
      }
      update tjList;

      if (!ecoRestoreResult.isEmpty()) {
        data.put(ECO_POINT_RESTORE_RESULT_KEY, ecoRestoreResult);
      }

      return ApiResult.ok(200, 'Return deposits deleted.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 반품 입금 삭제
   */
  public ApiResult deleteReturnDeposit(String depositNo) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<TransactionJournal> tjList = [
        SELECT
          Id,
          JournalSubTypeId,
          PaymentMethod,
          TransactionAmount,
          OrderId,
          LoyaltyProgramId,
          MemberId,
          SaleId__c,
          DepositNo__c,
          IsDeleted__c,
          DeleteDateTime__c,
          VoucherCode,
          JournalDate,
          Order.EndDate,
          InsertId__c,
          Order.ActualPaymentAmount__c,
          Promotion.PromotionNo__c,
          PromotionId,
          AdditionalNotes__c,
          Order.OrderNo__c,
          Order.SaleNo__c
        FROM TransactionJournal
        WHERE DepositNo__c = :depositNo AND IsDeleted__c = FALSE
        LIMIT 1
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 입금 이력이 존재하지 않습니다. ' + depositNo);
      }

      TransactionJournal sourceTj = tjList[0];
      // System.debug('sourceTj.Id : ' + sourceTj.Id);

      TransactionJournal newTj = buildDeleteTransactionJournal(sourceTj);
      List<TransactionJournal> linkedAccrualReversalTjList = new List<TransactionJournal>();

      Id couponRedeemCancelJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true); // 쿠폰 사용 취소
      Id pointRedeemCancelJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, true); // 포인트 사용 취소
      Id saleDepositReversalJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true); // 판매 입금 취소
      Id apiForcedDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT, true); // api 요청에 의한 강제 차감
      Id cancelPurchaseAccrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL, true);
      Id promotionPointAccrualReversalJstId = SObjectUtil.findIdByName(
        JournalSubType.SObjectType,
        JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL,
        true
      );
      // Id pointDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, true);

      // if (isEcoPointCancelJournal(sourceTj, apiForcedDebitJstId)) {
      //   // 에코포인트 지급 취소 건 복원
      //   System.debug('에코포인트 지급 취소 건 복원합니다.');
      //   List<PointCreditDTO> ecoRestoreResult = restoreEcoPointsFromReturn(newTj, sourceTj.Id);
      //   if (!ecoRestoreResult.isEmpty()) {
      //     data.put(ECO_POINT_RESTORE_RESULT_KEY, ecoRestoreResult);
      //   }
      // } else
      linkedAccrualReversalTjList = [
        SELECT
          Id,
          JournalSubTypeId,
          LoyaltyProgramId,
          MemberId,
          OrderId,
          PromotionId,
          OrderId__c,
          SaleId__c,
          DepositNo__c,
          RelatedJournalId,
          IsDeleted__c,
          DeleteDateTime__c
        FROM TransactionJournal
        WHERE
          RelatedJournalId = :sourceTj.Id
          AND MemberId = :sourceTj.MemberId
          AND IsDeleted__c = FALSE
          AND JournalSubTypeId IN :new Set<Id>{ cancelPurchaseAccrualJstId, promotionPointAccrualReversalJstId }
      ];
      // if (!linkedAccrualReversalTjList.isEmpty()) {
      //   System.debug('linkedAccrualReversalTjList[0].RelatedJournalId : ' + linkedAccrualReversalTjList[0].RelatedJournalId);
      // }

      if (
        sourceTj.JournalSubTypeId == pointRedeemCancelJstId ||
        sourceTj.JournalSubTypeId == couponRedeemCancelJstId ||
        sourceTj.JournalSubTypeId == saleDepositReversalJstId
      ) {
        if (sourceTj.JournalSubTypeId == pointRedeemCancelJstId) {
          // System.debug('if (sourceTj.JournalSubTypeId == pointRedeemCancelJstId) { 진입 (포인트 사용 취소)');

          newTj.AdditionalNotes__c = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';
          // [수정] 2026-04-21: 만료된 포인트 필터링 추가
          // 원인: 반품 시점에 ExpiryDate가 지나 복원되지 못한 포인트는 LoyaltyLedger에 남아있지만
          //       Salesforce 표준 LoyaltyManagement.debitPoints API가 "가용 포인트 부족"으로 거부하여 500 에러 발생.
          // 해결: ExpiryDate < TODAY 건을 재차감 대상에서 분리하여 호출 자체를 스킵하고, 응답에 별도 key로 기록.
          //       동일 파일 Sale Deposit Reversal 분기(line 690)의 ExpiryDate >= TODAY 기준과 일관.
          List<LoyaltyLedger> llList = [
            SELECT Id, LoyaltyPgmCrcySubtypeId, Points, LoyaltyPgmCrcySubtype.Name, AdditionalNotes, ExpiryDate
            FROM LoyaltyLedger
            WHERE TransactionJournalId = :sourceTj.Id AND LoyaltyProgramMemberId = :sourceTj.MemberId
            LIMIT 100
          ];

          List<LoyaltyLedger> activeLedgers = new List<LoyaltyLedger>();
          List<LoyaltyLedger> expiredLedgers = new List<LoyaltyLedger>();
          for (LoyaltyLedger ll : llList) {
            if (ll.ExpiryDate != null && ll.ExpiryDate < Date.today()) {
              expiredLedgers.add(ll);
            } else {
              activeLedgers.add(ll);
            }
          }

          List<PointDebitDTO> debitPointResult = new List<PointDebitDTO>();
          if (!activeLedgers.isEmpty()) {
            debitPointResult = getPointService().debitSpecificPoints(newTj, activeLedgers);
          }
          data.put('포인트 사용 내역 복구', debitPointResult);

          if (!expiredLedgers.isEmpty()) {
            List<Map<String, Object>> expiredSkipped = new List<Map<String, Object>>();
            for (LoyaltyLedger ll : expiredLedgers) {
              expiredSkipped.add(new Map<String, Object>{
                'PointTypeName' => ll.LoyaltyPgmCrcySubtype.Name,
                'Points' => ll.Points,
                'ExpiryDate' => ll.ExpiryDate,
                'Note' => '만료 포인트 재차감 스킵 (사용 상태 유지)'
              });
            }
            data.put('포인트 사용 만료 확정(재차감 스킵)', expiredSkipped);
          }
        } else if (sourceTj.JournalSubTypeId == couponRedeemCancelJstId) {
          // 기존 "쿠폰 사용" 내역 복구 진입 - 쿠폰 상태별 분기 처리
          // List<Voucher> vList = [
          //   SELECT Id, Status, ExpirationDate, VoucherCode, LoyaltyProgramMemberId,
          //          VoucherDefinitionId, VoucherDefinition.Name, VoucherDefinition.IsUnlimited__c,
          //          UsedTransactionJournalId__c
          //   FROM Voucher
          //   WHERE VoucherCode = :sourceTj.VoucherCode
          //     AND LoyaltyProgramMemberId = :sourceTj.MemberId
          //   LIMIT 1
          // ];

          // 26.05.01 GD - 쿠폰 코드 분할 "쿠폰 사용" 내역 복구 진입 - 쿠폰 상태별 분기 처리
          String searchVoucherCode = sourceTj.VoucherCode;
          List<Voucher> vList = new List<Voucher>();

          if (String.isNotBlank(searchVoucherCode) && searchVoucherCode.contains(';-;')) {
              String couponManNo = searchVoucherCode.substringBefore(';-;');
              String realVoucherCode = searchVoucherCode.substringAfter(';-;'); 
              
              vList = [
                  SELECT Id, Status, ExpirationDate, VoucherCode, LoyaltyProgramMemberId,
                        VoucherDefinitionId, VoucherDefinition.Name, VoucherDefinition.IsUnlimited__c,
                        UsedTransactionJournalId__c
                  FROM Voucher
                  WHERE VoucherCode = :realVoucherCode
                    AND VoucherDefinition.CouponManNo__c = :couponManNo
                    AND LoyaltyProgramMemberId = :sourceTj.MemberId
                  LIMIT 1
              ];
          } else {
              vList = [
                  SELECT Id, Status, ExpirationDate, VoucherCode, LoyaltyProgramMemberId,
                        VoucherDefinitionId, VoucherDefinition.Name, VoucherDefinition.IsUnlimited__c,
                        UsedTransactionJournalId__c
                  FROM Voucher
                  WHERE VoucherCode = :searchVoucherCode
                    AND LoyaltyProgramMemberId = :sourceTj.MemberId
                  LIMIT 1
              ];
          }

          if (vList.isEmpty()) {
            throw new CustomException(400, '쿠폰 레코드가 존재하지 않습니다. ' + sourceTj.VoucherCode);
          }

          Voucher v = vList[0];
          newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
          newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
          newTj.Status = 'Processed';

          if (v.Status == 'Issued') {
            // 만료 전 반품 또는 무제한 쿠폰: Issued 상태 -> 다시 Redeemed 로 복구
            newTj.AdditionalNotes__c = '반품 입금 삭제로 인한 "쿠폰 사용" 내역 복구';
            ApiResult voucherResult = getVoucherService().redeemVoucherV2(newTj);
            data.put('쿠폰 사용 내역 복구', voucherResult.data.get('voucher'));
          } else if (v.Status == 'Redeemed') {
            // 만료 후 반품으로 Redeemed 유지된 쿠폰: 상태 변경 없이 기록 TJ 만 insert
            newTj.AdditionalNotes__c = '반품 입금 삭제: 쿠폰 사용 상태 유지 (만료 후 반품 취소)';
            insert newTj;
            data.put('쿠폰 상태 유지', new Map<String, Object>{
              'VoucherCode' => v.VoucherCode,
              'Status' => v.Status,
              'ExpirationDate' => v.ExpirationDate,
              'Note' => '만료 후 반품 취소 - 쿠폰 Redeemed 상태 유지'
            });
          } else if (v.Status == 'Expired') {
            // 레거시 데이터 (과거 반품에서 Expired 로 전이된 쿠폰): 복원 불가, 기록만 남김
            newTj.AdditionalNotes__c = '반품 입금 삭제: 이미 Expired 쿠폰 (레거시 복원 불가)';
            insert newTj;
            data.put('쿠폰 Expired 상태 유지', new Map<String, Object>{
              'VoucherCode' => v.VoucherCode,
              'Status' => v.Status,
              'ExpirationDate' => v.ExpirationDate,
              'Note' => '레거시 Expired 쿠폰 - 복원 불가'
            });
          } else {
            throw new CustomException(400, '알 수 없는 쿠폰 상태입니다. status=' + v.Status + ', voucherCode=' + v.VoucherCode);
          }
        } else {
          // System.debug('} else { 진입 (판매 입금 취소)');
          // "판매 입금" 내역 복구 진입

          // [Wina 수정 2026.04.04]
          // 설명: 적립불가 품목만 있는 반품 삭제는 구매 포인트 복구 대상이 아니다.
          // 원판매에서 적립 가능한 입금 금액보다 반품에서 제외되어야 할 금액이 크거나 같으면,
          // 이 시점에서 포인트 재적립 로직을 종료해야 포인트가 다시 살아나는 현상을 막을 수 있다.
          Decimal originalAccrualEligibleAmount = getOriginalAccrualEligibleDepositAmount(sourceTj.OrderId); // 원판매에서 적립 가능한 입금 금액 조회
          Decimal returnExcludedAmount = sourceTj.SaleId__c != null ? getExcludedReturnAmount(sourceTj.SaleId__c) : 0; // 반품에서 적립 불가로 제외되어야 할 금액 조회
          Decimal recoverableAccrualAmount = originalAccrualEligibleAmount - returnExcludedAmount; // 복구 가능한 적립 금액 계산

          // 복구 가능한 적립 금액이 0 이하인 경우, 포인트 복구 로직을 수행하지 않고 입금 내역만 삭제 처리
          if (recoverableAccrualAmount <= 0) {
            sourceTj.IsDeleted__c = true;
            sourceTj.DeleteDateTime__c = Datetime.now();
            update sourceTj;
            // if (!linkedAccrualReversalTjList.isEmpty()) {
            // update linkedAccrualReversalTjList;
            // }
            return ApiResult.ok(200, '반품 입금 삭제 완료', data);
          }

          // 신규 로직 Start 2026-04-19
          // [변경] recoverableAccrualAmount > 0 이더라도 원판매에 실제 구매 포인트 적립 내역이 없으면 복구 불필요
          // [이유] payment method 기반 금액 계산은 포인트 적립 여부와 무관함.
          //        아울렛 등 포인트 미적립 판매는 deposit 금액이 양수여도 LoyaltyLedger 적립 기록이 없으므로
          //        linkedAccrualReversalTjList가 비어 else 분기에서 creditPointsOnPurchase가 잘못 호출됨
          Id purchaseAccrualJtId2 = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
          Id purchaseAccrualJstId2 = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true);
          Boolean hadOriginalPurchaseAccrual = ![
            SELECT Id FROM LoyaltyLedger
            WHERE
              TransactionJournal.OrderId = :sourceTj.OrderId
              AND TransactionJournal.JournalTypeId = :purchaseAccrualJtId2
              AND TransactionJournal.JournalSubTypeId = :purchaseAccrualJstId2
              AND EventType = 'Credit'
            LIMIT 1
          ].isEmpty();

          if (!hadOriginalPurchaseAccrual) {
            sourceTj.IsDeleted__c = true;
            sourceTj.DeleteDateTime__c = Datetime.now();
            update sourceTj;
            return ApiResult.ok(200, '반품 입금 삭제 완료', data);
          }
          // 신규 로직 End 2026-04-19

          // 회원 등급 조회
          List<LoyaltyMemberTier> lmtList = [SELECT Id, LastModifiedDate FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :sourceTj.MemberId LIMIT 1];
          if (lmtList.isEmpty()) {
            throw new CustomException(400, '해당 회원의 등급이 존재하지 않습니다. ' + sourceTj.MemberId);
          }

          Date orderDate = sourceTj.Order.EndDate;
          Date modifiedDate = lmtList[0].LastModifiedDate.date();

          List<PointCreditDTO> creditPointsOnPurchaseResult = new List<PointCreditDTO>();
          List<PointCreditDTO> creditPromotionPointsResult = new List<PointCreditDTO>();
          if (!linkedAccrualReversalTjList.isEmpty()) {
            // System.debug('if (!linkedAccrualReversalTjList.isEmpty()) { 진입');
            for (TransactionJournal reversalTj : linkedAccrualReversalTjList) {
              TransactionJournal restoreTj = buildDeleteTransactionJournal(reversalTj);
              restoreTj.AdditionalNotes__c = reversalTj.JournalSubTypeId == promotionPointAccrualReversalJstId
                ? 'Restore promotion point accrual due to return deletion'
                : 'Restore purchase accrual due to return deletion';
              // [수정] 2026-04-03: 만료된 포인트 필터링 추가
              // 기존: ExpiryDate < TODAY인 포인트도 복구되는 문제
              // 수정: AND CreditLoyaltyLedger.ExpiryDate >= TODAY 필터 추가
              // 원인: ExpiryDate가 TODAY보다 작으면 이미 소멸한 포인트이므로 복구 대상에서 제외해야 함

              /*
              // [기존 코드 - 주석 처리] 2026-04-03
              List<LoyaltyLedgerTraceability> lltList = [
                SELECT
                  CreditLoyaltyLedger.ExpiryDate,
                  LoyaltyPgmCurrencySubtype.Name,
                  LoyaltyPgmCurrencySubtype.PointTypeCode__c,
                  Points,
                  DebitLoyaltyLedger.AdditionalNotes
                FROM LoyaltyLedgerTraceability
                WHERE DebitLoyaltyLedger.TransactionJournal.Id = :reversalTj.Id
                LIMIT 200
              ];
              */

              /*
              // [수정된 코드 - 주석 처리] 2026-04-03
              // [버그] ExpiryDate = TODAY(당일)인 포인트가 SOQL에 포함되는 문제
              //        >= TODAY 조건은 ExpiryDate = TODAY인 경우(CASE2)를 포함하지만
              //        Salesforce Loyalty 소멸 배치가 자정에 해당 포인트를 소멸시키므로 복구 대상이 아님
              List<LoyaltyLedgerTraceability> lltList = [
                SELECT
                  CreditLoyaltyLedger.ExpiryDate,
                  LoyaltyPgmCurrencySubtype.Name,
                  LoyaltyPgmCurrencySubtype.PointTypeCode__c,
                  Points,
                  DebitLoyaltyLedger.AdditionalNotes
                FROM LoyaltyLedgerTraceability
                WHERE DebitLoyaltyLedger.TransactionJournal.Id = :reversalTj.Id AND CreditLoyaltyLedger.ExpiryDate >= TODAY
                LIMIT 200
              ];
              */

              // [수정된 코드] 2026-04-04
              // [변경] ExpiryDate >= TODAY → ExpiryDate > TODAY
              // [이유] Salesforce Loyalty 소멸 배치는 ExpiryDate = TODAY인 포인트를 자정(00:00)에 소멸 처리하므로
              //        반품일(TODAY)과 ExpiryDate가 같은 경우(CASE2)에도 포인트는 이미 소멸된 상태
              //        ExpiryDate > TODAY 조건으로 당일 소멸 포인트를 SOQL 단계에서 제외
              // List<LoyaltyLedgerTraceability> lltList = [
              //   SELECT
              //     CreditLoyaltyLedger.ExpiryDate,
              //     LoyaltyPgmCurrencySubtype.Name,
              //     LoyaltyPgmCurrencySubtype.PointTypeCode__c,
              //     Points,
              //     DebitLoyaltyLedger.AdditionalNotes
              //   FROM LoyaltyLedgerTraceability
              //   WHERE
              //     DebitLoyaltyLedger.TransactionJournal.Id = :reversalTj.Id
              //     AND CreditLoyaltyLedger.ExpiryDate > TODAY
              //     AND LoyaltyProgramMemberId = :sourceTj.MemberId
              //   LIMIT 200
              // ];

              // [수정된 코드] 2026-04-06 Carson
              List<LoyaltyLedgerTraceability> lltList = [
                SELECT
                  CreditLoyaltyLedger.ExpiryDate,
                  LoyaltyPgmCurrencySubtype.Name,
                  LoyaltyPgmCurrencySubtype.PointTypeCode__c,
                  Points,
                  DebitLoyaltyLedger.AdditionalNotes
                FROM LoyaltyLedgerTraceability
                WHERE
                  DebitLoyaltyLedger.TransactionJournal.RelatedJournalId = :sourceTj.Id
                  AND DebitLoyaltyLedger.TransactionJournalId = :reversalTj.Id
                  AND CreditLoyaltyLedger.ExpiryDate >= TODAY
                  AND LoyaltyProgramMemberId = :sourceTj.MemberId
                  AND ActionType = 'CreditCancellation'
                LIMIT 200
              ];

              // 포인트 적립 취소된 내역 복원 = 재지급
              // System.debug('lltList.size()aaaaaaa : ' + lltList.size());
              List<PointCreditDTO> restoreResult = getPointService().creditSepcificPoints(restoreTj, lltList);
              if (reversalTj.JournalSubTypeId == promotionPointAccrualReversalJstId) {
                creditPromotionPointsResult.addAll(restoreResult);
              } else {
                creditPointsOnPurchaseResult.addAll(restoreResult);
              }
              reversalTj.IsDeleted__c = true;
              reversalTj.DeleteDateTime__c = Datetime.now();

              // 추가 로직 carson 2026-04-06 start
              // 기존 LoyaltyLedgerTraceability 삭제
              List<Database.DeleteResult> deleteResultList = Database.delete(lltList);

              for (Database.DeleteResult deleteResult : deleteResultList) {
                if (!deleteResult.isSuccess()) {
                  Database.Error err = deleteResult.getErrors()[0];
                  throw new CustomException(400, err.getMessage());
                }
              }
              // 추가 로직 carson 2026-04-06 end
            }
            String promotionNo = (sourceTj.PromotionId != null && sourceTj.Promotion != null) ? sourceTj.Promotion.PromotionNo__c : null;
            if (creditPointsOnPurchaseResult != null) {
              for (PointCreditDTO pcDto : creditPointsOnPurchaseResult) {
                pcDto.AM_SAL = sourceTj.Order.ActualPaymentAmount__c;
                pcDto.ID_INSERT = sourceTj.InsertId__c;
                pcDto.NO_PROM_MBR = promotionNo;
              }
            }
            if (creditPromotionPointsResult != null) {
              for (PointCreditDTO pcDto : creditPromotionPointsResult) {
                pcDto.AM_SAL = sourceTj.Order.ActualPaymentAmount__c;
                pcDto.ID_INSERT = sourceTj.InsertId__c;
                pcDto.NO_PROM_MBR = promotionNo;
              }
            }
          } else {
            String grade;
            if (orderDate < modifiedDate) {
              // System.debug('if (orderDate < modifiedDate) { 진입');
              // 이전 등급으로 다시 적립

              // 기존 로직 Start 2026-04-06
              // // 이전 등급 조회
              // List<LoyaltyProgramMember> lpmList = [
              //   SELECT Id, Contact.PreviousGrade__c, Contact.Grade__c
              //   FROM LoyaltyProgramMember
              //   WHERE Contact.PreviousGrade__c != NULL AND Id = :sourceTj.MemberId
              //   LIMIT 1
              // ];
              // if (lpmList.isEmpty()) {
              //   throw new CustomException(400, '회원의 이전 등급이 존재하지 않습니다. ' + sourceTj.MemberId);
              // }
              // grade = lpmList[0].Contact.Grade__c;
              // 기존 로직 End 2026-04-06
              // 신규 로직 Carson Start 2026-04-06
              List<LoyaltyProgramMember> lpmList = [
                SELECT Id, Contact.PreviousGrade__c, Contact.Grade__c
                FROM LoyaltyProgramMember
                WHERE Id = :sourceTj.MemberId
                LIMIT 1
              ];
              if (lpmList.isEmpty()) {
                throw new CustomException(400, '해당 회원을 찾을 수 없습니다. ' + sourceTj.MemberId);
              }
              if (lpmList[0].Contact.PreviousGrade__c == null) {
                grade = lpmList[0].Contact.Grade__c;
              } else {
                grade = lpmList[0].Contact.PreviousGrade__c;
              }
              // 신규 로직 Carson End 2026-04-06
              List<String> grades = new List<String>{ '01', '02', '03', '04' };
              // if (grades.contains(lpmList[0].Contact.PreviousGrade__c)) { // 기존 로직
              if (grades.contains(grade)) {
                // 신규 로직 Carson 2026-04-06
                Map<String, Object> reqData = new Map<String, Object>();
                // reqData.put('Grade__c', lpmList[0].Contact.PreviousGrade__c);  // 기존 로직
                reqData.put('Grade__c', grade); // 신규 로직 Carson 2026-04-06
                reqData.put('TransactionJournal', sourceTj);
                reqData.put('AdditionalNotes__c', '반품 입금 삭제로 인한 "구매 시 포인트 적립" 내역 복구');
                creditPointsOnPurchaseResult = getPointService().creditPointsOnPurchaseByGrade(reqData);
              }
            } else {
              // System.debug('sourceTj.Id : ' + sourceTj.Id);
              creditPointsOnPurchaseResult = getPointService().creditPointsOnPurchase(new List<TransactionJournal>{ sourceTj });
            }

            // System.debug('sourceTj.PromotionId : ' + sourceTj.PromotionId);
            if (sourceTj.PromotionId != null) {
              // System.debug('if (sourceTj.PromotionId != null) { 진입');
              creditPromotionPointsResult = getPointService().creditPromotionPointsOnPurchase(new List<TransactionJournal>{ sourceTj }, 0);
            }

            if (creditPointsOnPurchaseResult != null) {
              for (PointCreditDTO pcDto : creditPointsOnPurchaseResult) {
                pcDto.AM_SAL = sourceTj.Order.ActualPaymentAmount__c;
                pcDto.ID_INSERT = sourceTj.InsertId__c;
                pcDto.NO_PROM_MBR = (sourceTj.PromotionId != null && sourceTj.Promotion != null) ? sourceTj.Promotion.PromotionNo__c : null;
                pcDto.NO_GRADE_ADVAN = grade;
              }
            }
            if (creditPromotionPointsResult != null) {
              for (PointCreditDTO pcDto : creditPromotionPointsResult) {
                pcDto.AM_SAL = sourceTj.Order.ActualPaymentAmount__c;
                pcDto.ID_INSERT = sourceTj.InsertId__c;
                pcDto.NO_PROM_MBR = (sourceTj.PromotionId != null && sourceTj.Promotion != null) ? sourceTj.Promotion.PromotionNo__c : null;
                pcDto.NO_GRADE_ADVAN = grade;
              }
            }
          }
          if (creditPromotionPointsResult != null) {
            // System.debug('if (creditPromotionPointsResult != null) { 진입');
            if (!creditPromotionPointsResult.isEmpty()) {
              // System.debug('if (!creditPromotionPointsResult.isEmpty()) { 진입');
              data.put('프로모션 포인트 지급 내역 복구', creditPromotionPointsResult);
            }
          }
          data.put('포인트 지급 내역 복구', creditPointsOnPurchaseResult);
        }
      }

      sourceTj.IsDeleted__c = true;
      sourceTj.DeleteDateTime__c = Datetime.now();
      update sourceTj;

      // 주석 처리 - 2026-04-06 Carson
      // if (!linkedAccrualReversalTjList.isEmpty()) {
      //   update linkedAccrualReversalTjList;
      // }
      // 주석 처리 - 2026-04-06 Carson

      return ApiResult.ok(200, '반품 입금 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // 거래 이력 삭제
  private static TransactionJournal buildDeleteTransactionJournal(TransactionJournal tj) {
    TransactionJournal newTj = tj.clone(false, true, false, false);
    newTj.DepositNo__c = (tj.DepositNo__c != null) ? 'del_' + tj.DepositNo__c : 'del_' + tj.Id;
    newTj.JournalDate = Datetime.now();
    newTj.ActivityDate = Datetime.now();
    // newTj.ActivityDate = Datetime.now().addDays(-1);
    newTj.DepositType__c = null;
    newTj.RelatedJournalId = tj.Id;
    return newTj;
  }

  /**
   * 통반품 여부 확인
   */
  @TestVisible
  private static Boolean isFullReturn(Id originalOrderId) {
    Map<Id, Decimal> originalQtyByProductId = new Map<Id, Decimal>();
    for (OrderItem originalOi : [
      SELECT Quantity, PricebookEntry.Product2Id
      FROM OrderItem
      WHERE OrderId = :originalOrderId AND PricebookEntry.Product2Id != NULL
    ]) {
      Id productId = originalOi.PricebookEntry.Product2Id;
      Decimal currentQty = originalQtyByProductId.containsKey(productId) ? originalQtyByProductId.get(productId) : 0;
      originalQtyByProductId.put(productId, currentQty + originalOi.Quantity);
    }
    if (originalQtyByProductId.isEmpty()) {
      System.debug('if (originalQtyByProductId.isEmpty()) {');
      return false;
    }

    Map<Id, Decimal> returnQtyByProductId = new Map<Id, Decimal>();
    for (OrderItem returnOi : [
      SELECT Quantity, PricebookEntry.Product2Id
      FROM OrderItem
      WHERE
        Order.OriginalOrderId__c = :originalOrderId
        AND Order.IsReductionOrder__c = TRUE
        AND Order.IsDeleted__c = FALSE
        AND PricebookEntry.Product2Id != NULL
    ]) {
      Id productId = returnOi.PricebookEntry.Product2Id;
      if (!originalQtyByProductId.containsKey(productId)) {
        System.debug('if (!originalQtyByProductId.containsKey(productId)) {');
        return false;
      }
      Decimal returnedMagnitude = (returnOi.Quantity == null) ? 0 : returnOi.Quantity.abs();
      Decimal currentQty = returnQtyByProductId.containsKey(productId) ? returnQtyByProductId.get(productId) : 0;
      returnQtyByProductId.put(productId, currentQty + returnedMagnitude);
    }

    if (returnQtyByProductId.size() != originalQtyByProductId.size()) {
      System.debug('if (returnQtyByProductId.size() != originalQtyByProductId.size()) {');
      return false;
    }

    for (Id productId : originalQtyByProductId.keySet()) {
      Decimal returnedQty = returnQtyByProductId.get(productId);
      System.debug('returnedQty : ' + returnedQty);
      System.debug('originalQtyByProductId.get(productId) : ' + originalQtyByProductId.get(productId));
      if (returnedQty == null || returnedQty < originalQtyByProductId.get(productId)) {
        System.debug('if (returnedQty == null || returnedQty < originalQtyByProductId.get(productId)) {');
        return false;
      }
    }
    return true;
  }

  // 신규 로직 Start.(26.04.02)
  /**
   * 원판매에서 적립 불가 금액 합계 계산
   */
  @TestVisible
  private static List<Object> getReturnOrderItemRequestList(Map<String, Object> reqData) {
    if (reqData == null) {
      return new List<Object>();
    }

    Object rawOrderItemList = reqData.containsKey('OrderItem') ? reqData.get('OrderItem') : reqData.get('oiList');
    if (rawOrderItemList == null) {
      return new List<Object>();
    }

    return ValidationUtil.listObjValidation(rawOrderItemList, 'OrderItem', true);
  }

  @TestVisible
  private static Decimal getExcludedReturnAmount(Id returnOrderId) {
    return getExcludedReturnAmount(null, new List<Object>(), returnOrderId);
  }

  @TestVisible
  private static Decimal getExcludedReturnAmount(Id originalOrderId, List<Object> returnOrderItemRequestList, Id returnOrderId) {
    if (originalOrderId != null && returnOrderItemRequestList != null && !returnOrderItemRequestList.isEmpty()) {
      Decimal excludedAmountFromRequest = getExcludedReturnAmountFromRequest(originalOrderId, returnOrderItemRequestList);
      return excludedAmountFromRequest;
    }

    return getExcludedReturnAmountFromStoredReturnItems(returnOrderId);
  }

  private static Decimal getExcludedReturnAmountFromRequest(Id originalOrderId, List<Object> returnOrderItemRequestList) {
    Decimal excludedAmount = 0;
    Set<Id> originalOrderItemIdSet = new Set<Id>();
    Set<String> saleSeqNoSet = new Set<String>();
    List<Map<String, Object>> normalizedReturnOrderItemList = new List<Map<String, Object>>();

    for (Object v : returnOrderItemRequestList) {
      Map<String, Object> returnOrderItem = ValidationUtil.mapStrObjValidation(v, 'OrderItem', true);
      String originalOrderItemIdRaw = ValidationUtil.stringValidationEx(
        returnOrderItem.get('OriginalOrderItemId__c'),
        'OriginalOrderItemId__c',
        false,
        true
      );
      String saleSeqNo = ValidationUtil.stringValidationEx(returnOrderItem.get('SaleSeqNo__c'), 'SaleSeqNo__c', false, true);
      Decimal netSalesUnitPrice = ValidationUtil.decimalValidation(returnOrderItem.get('NetSalesUnitPrice__c'), 'NetSalesUnitPrice__c', false);

      if (String.isNotBlank(originalOrderItemIdRaw)) {
        originalOrderItemIdSet.add((Id) originalOrderItemIdRaw);
      }
      if (String.isNotBlank(saleSeqNo)) {
        saleSeqNoSet.add(saleSeqNo);
      }

      normalizedReturnOrderItemList.add(
        new Map<String, Object>{
          'OriginalOrderItemId__c' => originalOrderItemIdRaw,
          'SaleSeqNo__c' => saleSeqNo,
          'NetSalesUnitPrice__c' => netSalesUnitPrice
        }
      );
    }

    Map<Id, OrderItem> originalOrderItemById = new Map<Id, OrderItem>();
    Map<String, OrderItem> originalOrderItemBySaleSeqNo = new Map<String, OrderItem>();

    if (!originalOrderItemIdSet.isEmpty() || !saleSeqNoSet.isEmpty()) {
      for (OrderItem originalOi : [
        SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c
        FROM OrderItem
        WHERE OrderId = :originalOrderId AND (Id IN :originalOrderItemIdSet OR SaleSeqNo__c IN :saleSeqNoSet)
      ]) {
        originalOrderItemById.put(originalOi.Id, originalOi);
        if (String.isNotBlank(originalOi.SaleSeqNo__c) && !originalOrderItemBySaleSeqNo.containsKey(originalOi.SaleSeqNo__c)) {
          originalOrderItemBySaleSeqNo.put(originalOi.SaleSeqNo__c, originalOi);
        }
      }
    }

    for (Map<String, Object> normalizedReturnOrderItem : normalizedReturnOrderItemList) {
      String originalOrderItemIdRaw = (String) normalizedReturnOrderItem.get('OriginalOrderItemId__c');
      String saleSeqNo = (String) normalizedReturnOrderItem.get('SaleSeqNo__c');
      Decimal returnItemAmount = (Decimal) normalizedReturnOrderItem.get('NetSalesUnitPrice__c');

      OrderItem originalOi = null;
      if (String.isNotBlank(originalOrderItemIdRaw)) {
        originalOi = originalOrderItemById.get((Id) originalOrderItemIdRaw);
      }
      if (originalOi == null && String.isNotBlank(saleSeqNo)) {
        originalOi = originalOrderItemBySaleSeqNo.get(saleSeqNo);
      }
      if (originalOi == null) {
        throw new CustomException(400, '원판매 상세를 찾을 수 없습니다. originalOrderId=' + originalOrderId + ', saleSeqNo=' + saleSeqNo);
      }
      if (originalOi.IsExclude__c == true) {
        excludedAmount += returnItemAmount != null ? returnItemAmount : (originalOi.NetSalesUnitPrice__c != null ? originalOi.NetSalesUnitPrice__c : 0);
      }
    }

    return excludedAmount;
  }

  private static Decimal getExcludedReturnAmountFromStoredReturnItems(Id returnOrderId) {
    Decimal excludedAmount = 0;
    for (OrderItem returnOi : [
      SELECT IsExclude__c, NetSalesUnitPrice__c, OriginalOrderItemId__c, OriginalOrderItem.IsExclude__c, OriginalOrderItem.NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :returnOrderId
    ]) {
      Boolean isExcluded = returnOi.OriginalOrderItemId__c != null ? returnOi.OriginalOrderItem.IsExclude__c : returnOi.IsExclude__c;
      Decimal itemAmount = returnOi.OriginalOrderItemId__c != null ? returnOi.OriginalOrderItem.NetSalesUnitPrice__c : returnOi.NetSalesUnitPrice__c;

      if (isExcluded == true) {
        excludedAmount += itemAmount != null ? itemAmount : 0; // 적립 제외 금액
      }
    }

    return excludedAmount;
  }

  /**
   * 반품 포인트 적립 대상 결제 금액 합계 계산
   */
  @TestVisible
  private static Decimal getReturnAccrualEligibleDepositAmount(List<TransactionJournal> cancelDepositTransactionList) {
    Decimal eligibleDepositAmount = 0;

    for (TransactionJournal tj : cancelDepositTransactionList) {
      if (tj == null) {
        continue;
      }
      if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
        continue;
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
        continue;
      }
      eligibleDepositAmount += tj.TransactionAmount;
    }

    return eligibleDepositAmount;
  }

  /**
   * 원판매 입금 이력 중 포인트 적립 대상 결제 금액 합계 계산
   */
  @TestVisible
  private static Decimal getOriginalAccrualEligibleDepositAmount(Id originalOrderId) {
    Decimal eligibleDepositAmount = 0;
    Id saleDepositJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true);

    for (TransactionJournal tj : [
      SELECT PaymentMethod, TransactionAmount
      FROM TransactionJournal
      WHERE OrderId = :originalOrderId AND JournalSubTypeId = :saleDepositJstId AND IsDeleted__c = FALSE
    ]) {
      if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
        continue;
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
        continue;
      }
      eligibleDepositAmount += tj.TransactionAmount;
    }

    return eligibleDepositAmount;
  }

  /**
   * 적립 취소 대상 거래 이력 생성
   * - 원판매에서 적립 가능 금액이 있는 경우에만 생성
   */
  @TestVisible
  private static List<TransactionJournal> buildAccrualEligibleCancelTransactions(
    Id originalOrderId,
    Id returnOrderId,
    List<TransactionJournal> cancelDepositTransactionList,
    List<Object> returnOrderItemRequestList
  ) {
    List<TransactionJournal> result = new List<TransactionJournal>();
    if (cancelDepositTransactionList == null || cancelDepositTransactionList.isEmpty()) {
      return result;
    }

    Decimal returnExcludedAmount = getExcludedReturnAmount(originalOrderId, returnOrderItemRequestList, returnOrderId);
    System.debug('반품 적립 불가 금액 합계 returnExcludedAmount : ' + returnExcludedAmount);
    Decimal returnEligibleDepositAmount = getReturnAccrualEligibleDepositAmount(cancelDepositTransactionList);
    System.debug('반품 포인트 적립 대상 결제 금액 합계 returnEligibleDepositAmount : ' + returnEligibleDepositAmount);
    Decimal remainingEligibleAmount = returnEligibleDepositAmount - returnExcludedAmount;
    System.debug('remainingEligibleAmount : ' + remainingEligibleAmount);

    if (returnEligibleDepositAmount <= 0 || remainingEligibleAmount <= 0) {
      return result;
    }

    for (TransactionJournal sourceTj : cancelDepositTransactionList) {
      if (sourceTj == null || remainingEligibleAmount <= 0) {
        continue;
      }
      Decimal sourceAmount = sourceTj.TransactionAmount != null ? sourceTj.TransactionAmount : 0;
      if (sourceAmount <= 0) {
        continue;
      }
      if (sourceTj.PaymentMethod == '20' || sourceTj.PaymentMethod == '81' || sourceTj.PaymentMethod == '90' || sourceTj.PaymentMethod == '93') {
        continue;
      }

      Decimal adjustedAmount = sourceAmount > remainingEligibleAmount ? remainingEligibleAmount : sourceAmount;
      TransactionJournal adjustedTj = sourceTj.clone(true, true, false, false);
      adjustedTj.TransactionAmount = adjustedAmount;
      result.add(adjustedTj);
      remainingEligibleAmount -= adjustedAmount;
    }

    return result;
  }
  // 신규 로직 End.(26.04.02)

  /**
   * 에코포인트 회수
   **/
  private static List<PointDebitDTO> cancelEcoPointsForFullReturn(Id returnOrderId, Id originalOrderId, LoyaltyProgramMember lpm, String insertId) {
    // 에코포인트 회수했는지 체크
    if (hasActiveEcoCancellation(returnOrderId)) {
      System.debug('if (hasActiveEcoCancellation(returnOrderId)) { 진입');
      return new List<PointDebitDTO>();
    }

    // 취소할 금액 계산
    Integer remainingPoint = getCancelableEcoPointLedgers(originalOrderId);
    // List<LoyaltyLedger> ecoLedgerList = getCancelableEcoPointLedgers(originalOrderId);
    if (remainingPoint <= 0) {
      System.debug('if (ecoLedgerList.isEmpty()) { 진입');
      return new List<PointDebitDTO>();
    }

    // 저널 유형 체크
    Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
    // 저날 하위 유형 체크
    Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT, 'JournalTypeId' => jtId };
    Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

    // 취소할 거래 이력 생성
    TransactionJournal ecoCancelTj = new TransactionJournal();
    ecoCancelTj.DepositNo__c = 'ECO-' + String.valueOf(returnOrderId);
    ecoCancelTj.DeposiSeqNo__c = '1';
    ecoCancelTj.JournalDate = Datetime.now();
    ecoCancelTj.ActivityDate = Datetime.now();
    ecoCancelTj.LoyaltyProgramId = lpm.ProgramId;
    ecoCancelTj.MemberId = lpm.Id;
    ecoCancelTj.OrderId = originalOrderId;
    ecoCancelTj.SaleId__c = returnOrderId;
    ecoCancelTj.InsertId__c = insertId;
    ecoCancelTj.AdditionalNotes__c = ECO_POINT_CANCEL_NOTE;
    ecoCancelTj.transactionAmount = remainingPoint;
    ecoCancelTj.JournalReason__c = '1'; // 1 : 사용
    ecoCancelTj.JournalTypeId = jtId;
    ecoCancelTj.JournalSubTypeId = jstId;
    ecoCancelTj.Status = 'Pending';

    insert ecoCancelTj;

    List<Map<String, Object>> reqList = new List<Map<String, Object>>();
    Map<String, Object> req = new Map<String, Object>();
    req.put('loyaltyProgramMemberId', ecoCancelTj.MemberId);
    req.put('points', remainingPoint);
    req.put('journalId', ecoCancelTj.Id);
    req.put('loyaltyProgramCurrencySubtypeName', '에코포인트');
    reqList.add(req);

    List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);

    System.debug('여기까지 진입');

    // 포인트 사용 추적 조회
    List<LoyaltyLedgerTraceability> lltList = [
      SELECT
        LoyaltyPgmCurrencySubtype.Name,
        Points,
        CreditLoyaltyLedger.ExpiryDate,
        LoyaltyProgramMember.Contact.MemberNo__c,
        LastModifiedDate,
        DebitLoyaltyLedgerId,
        LoyaltyPgmCurrencySubtype.PointTypeCode__c,
        CreditLoyaltyLedgerId
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :ecoCancelTj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :ecoCancelTj.Id
      LIMIT 100
    ];
    if (lltList.isEmpty()) {
      throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + ecoCancelTj.Id);
    }
    List<LoyaltyLedgerTraceability> newLltList = new List<LoyaltyLedgerTraceability>();
    for (LoyaltyLedgerTraceability llt : lltList) {
      LoyaltyLedgerTraceability newLlt = llt.clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
      newLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;

      newLltList.add(newLlt);
    }

    // llt.ActionType 필드가 update 불가하여, 새로운 LoyaltyLedgerTraceability insert 후 기존 LoyaltyLedgerTraceability는 삭제
    List<Database.SaveResult> insertResultList = Database.insert(newLltList);

    for (Database.SaveResult insertResult : insertResultList) {
      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
    }

    // 기존 LoyaltyLedgerTraceability 삭제
    List<Database.DeleteResult> deleteResultList = Database.delete(lltList);

    for (Database.DeleteResult deleteResult : deleteResultList) {
      if (!deleteResult.isSuccess()) {
        Database.Error err = deleteResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
    }

    List<PointDebitDTO> pdDtoList = new List<PointDebitDTO>();
    for (LoyaltyLedgerTraceability llt : newLltList) {
      PointDebitDTO pcDto = new PointDebitDTO();
      pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
      pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // ecoCancelTj.Id; -> llt.CreditLoyaltyLedgerId;
      pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
      pcDto.CD_RESON = ecoCancelTj.JournalReason__c;
      pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c; // 회원 번호
      if (String.isNotBlank(ecoCancelTj.Order.OrderNo__c)) {
        pcDto.NO_SAL = ecoCancelTj.Order.OrderNo__c; // 주문 번호
      } else if (String.isNotBlank(ecoCancelTj.Order.SaleNo__c)) {
        pcDto.NO_SAL = ecoCancelTj.Order.SaleNo__c; // 판매 번호
      }
      pcDto.PT_USE = llt.Points; // 사용처리된 금액
      pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 사용처리된 금액

      pdDtoList.add(pcDto);
    }

    return pdDtoList;
    // return getPointService().debitSpecificPoints(ecoCancelTj, ecoLedgerList);
  }

  /**
   * 에코포인트 회수했는지 체크
   */
  private static Boolean hasActiveEcoCancellation(Id returnOrderId) {
    return [
        SELECT COUNT()
        FROM TransactionJournal
        WHERE SaleId__c = :returnOrderId AND IsDeleted__c = FALSE AND AdditionalNotes__c = :ECO_POINT_CANCEL_NOTE
      ] > 0;
  }

  /**
   * 에코포인트 지급 취소
   */
  @TestVisible
  private static Integer getCancelableEcoPointLedgers(Id originalOrderId) {
    System.debug('getCancelableEcoPointLedgers 진입');
    Id accrualJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
    Id apiForcedCreditJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT, true);

    // 원판매에서 에코포인트 적립된 LoyaltyLedger 조회
    // [Eco Cancel Fix 2026-05-03 / 결함 A] 재적립 LL (FULL_RETURN_ECO_POINT_RESTORE) 제외
    //   배경: 통반품 → 취소 → 재통반품 시, 1차 통반품 취소로 만들어진 재적립 LL 이
    //         원판매 OrderId 매칭으로 잡혀서 차감 대상에 중복 포함됨.
    //   해결: AdditionalNotes != FULL_RETURN_ECO_POINT_RESTORE (=ECO_POINT_RESTORE_NOTE) 필터.
    //         GdPointServiceImpl 의 같은 마커 처리(라인 346,350,1193,1197) 와 일관.
    List<LoyaltyLedger> originalEcoCreditLedgerList = [
      SELECT Id, Points, LoyaltyPgmCrcySubtype.Name
      FROM LoyaltyLedger
      WHERE
        TransactionJournal.OrderId = :originalOrderId
        AND TransactionJournal.JournalTypeId = :accrualJtId
        AND TransactionJournal.JournalSubTypeId = :apiForcedCreditJstId
        AND LoyaltyPgmCrcySubtype.PointTypeCode__c = :ECO_POINT_TYPE_CODE
        AND EventType = 'Credit'
        AND (TransactionJournal.AdditionalNotes__c = NULL
        OR TransactionJournal.AdditionalNotes__c != :ECO_POINT_RESTORE_NOTE)
      LIMIT 200
    ];
    if (originalEcoCreditLedgerList.isEmpty()) {
      return 0;
    }

    Set<Id> creditLedgerIdSet = new Set<Id>();
    for (LoyaltyLedger ll : originalEcoCreditLedgerList) {
      creditLedgerIdSet.add(ll.Id);
    }

    // 지급된 에코포인트가 사용 추적 조회
    // [Eco Cancel Fix 2026-05-03] 두 가지 보조 LLT 마커 제외
    //   1) 반품 입금 삭제 재차감 보조 (RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
    //      - 부분반품 → 입금 삭제 → ... → 통반품 시 재차감 보조 LLT 가 사용량으로 잘못 합산됨.
    //   2) [결함 C2] 1차 통반품 차감 흔적 (ECO_POINT_CANCEL_NOTE)
    //      - 통반품 → 취소 → 재통반품 시, 1차 차감 LLT (FULL_RETURN_ECO_POINT_CANCEL) 가
    //        IsDeleted=FALSE 로 살아있어 사용량으로 합산됨. 통반품 취소 시 restoreEcoPointsFromReturn
    //        이 새 적립 LL 만 만들고 1차 차감 흔적은 건드리지 않으므로, 조회 측에서 마커 기반 제외 필요.
    //   해결: 두 마커 모두 OR 조건으로 제외 (다른 메서드와 동일한 v3 paradigm 정책).
    Map<Id, Integer> usedPointByCreditLedgerId = new Map<Id, Integer>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT CreditLoyaltyLedgerId, Points, ActionType
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId IN :creditLedgerIdSet
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE
        AND DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :ECO_POINT_CANCEL_NOTE))
      LIMIT 2000
    ]) {
      // 사용한 금액
      Integer current = usedPointByCreditLedgerId.containsKey(llt.CreditLoyaltyLedgerId)
        ? usedPointByCreditLedgerId.get(llt.CreditLoyaltyLedgerId)
        : 0;

      System.debug('에코포인트 사용한 금액 : ' + current);

      // 사용한 금액 || 적립 취소 금액
      if (
        llt.ActionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT ||
        llt.ActionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
      ) {
        current += (Integer) llt.Points;
      }
      // else if (llt.ActionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION) {
      //   current -= llt.Points;
      // }
      usedPointByCreditLedgerId.put(llt.CreditLoyaltyLedgerId, current);
    }

    // 취소할 금액
    // List<LoyaltyLedger> cancelableLedgerList = new List<LoyaltyLedger>();
    // [Eco Cancel Fix 2026-05-03 / 결함 B] 누적 합산으로 변경 (덮어쓰기 → += )
    //   배경: 기존 코드는 remainingPoint 를 매 루프마다 덮어써서 적립 LL 이 여러 건일 때
    //         마지막 LL 의 잔여만 반환 (비결정적, SOQL ORDER BY 없음).
    //         결함 A fix 후엔 통상 1건이지만 안전을 위해 누적으로 변경.
    //         Math.max(0, ...) 로 음수 방어 (사용량이 적립량을 초과한 비정상 데이터 케이스).
    Integer remainingPoint = 0; // 취소할 금액
    for (LoyaltyLedger ecoLedger : originalEcoCreditLedgerList) {
      // 사용한 금액
      Integer usedPoint = usedPointByCreditLedgerId.containsKey(ecoLedger.Id) ? usedPointByCreditLedgerId.get(ecoLedger.Id) : 0;
      // 해당 적립 LL 의 잔여 (음수 방어)
      Integer ledgerRemaining = Math.max(0, (Integer) ecoLedger.Points - (Integer) usedPoint);
      remainingPoint += ledgerRemaining;
      System.debug('에코포인트 취소할 금액 (누적): ' + remainingPoint);
      // if (remainingPoint > 0) {
      // ecoLedger.Points = remainingPoint;
      // cancelableLedgerList.add(ecoLedger);
      // }
    }

    return remainingPoint;
  }

  // 에코포인트 지급 취소 저널 여부 확인
  private static Boolean isEcoPointCancelJournal(TransactionJournal tj, Id apiForcedDebitJstId) {
    return tj.JournalSubTypeId == apiForcedDebitJstId && tj.AdditionalNotes__c == ECO_POINT_CANCEL_NOTE;
  }

  // // 에코포인트 지급 취소 복원 (재지급)
  // // private static List<PointCreditDTO> restoreEcoPointsFromReturn(TransactionJournal newTj, Id sourceTransactionJournalId) {
  // public static List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
  //   Id apiForcedDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT, true); // api 요청에 의한 강제 차감

  //   // 에코포인트 지급 취소 저널 조회
  //   List<TransactionJournal> ecoCreditCancelJournalList = [
  //     SELECT
  //       Id,
  //       JournalSubTypeId,
  //       PaymentMethod,
  //       TransactionAmount,
  //       OrderId,
  //       LoyaltyProgramId,
  //       MemberId,
  //       SaleId__c,
  //       DepositNo__c,
  //       IsDeleted__c,
  //       DeleteDateTime__c,
  //       VoucherCode,
  //       JournalDate,
  //       Order.EndDate,
  //       InsertId__c,
  //       Order.ActualPaymentAmount__c,
  //       Promotion.PromotionNo__c,
  //       AdditionalNotes__c
  //     FROM TransactionJournal
  //     WHERE SaleId__c = :orderId AND AdditionalNotes__c = :ECO_POINT_CANCEL_NOTE AND JournalSubTypeId = :apiForcedDebitJstId
  //     LIMIT 1
  //   ];
  //   if (ecoCreditCancelJournalList.isEmpty()) {
  //     return new List<PointCreditDTO>();
  //   }

  //   TransactionJournal newTj = new TransactionJournal();

  //   newTj.LoyaltyProgramId = ecoCreditCancelJournalList[0].LoyaltyProgramId; // 로열티 프로그램 Id
  //   newTj.MemberId = ecoCreditCancelJournalList[0].MemberId; // 적립 대상 멤버 Id
  //   // if (endDate != null) {
  //   //   newTj.JournalDate = TimeUtil.dateToUtcStartOfDay(endDate); // 거래 일자
  //   //   newTj.ActivityDate = TimeUtil.dateToUtcStartOfDay(endDate); // 활동 일자

  //   //   expirationDate = endDate.addYears(2);
  //   // } else {
  //   newTj.JournalDate = Datetime.now(); // 거래 일자
  //   newTj.ActivityDate = Datetime.now(); // 활동 일자
  //   // }
  //   newTj.TransactionAmount = ecoCreditCancelJournalList[0].TransactionAmount; // 지급 포인트
  //   newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
  //   newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT, true);
  //   // if (saleId != null) {
  //   newTj.OrderId = ecoCreditCancelJournalList[0].OrderId;
  //   newTj.SaleId__c = ecoCreditCancelJournalList[0].SaleId__c;
  //   newTj.AdditionalNotes__c = ECO_POINT_RESTORE_NOTE;
  //   // }

  //   insert newTj;

  //   List<LoyaltyLedgerTraceability> lltList = [
  //     SELECT CreditLoyaltyLedger.ExpiryDate, LoyaltyPgmCurrencySubtype.Name, Points, DebitLoyaltyLedger.AdditionalNotes
  //     FROM LoyaltyLedgerTraceability
  //     WHERE DebitLoyaltyLedger.TransactionJournal.Id = :ecoCreditCancelJournalList[0].Id
  //     LIMIT 200
  //   ];
  //   if (lltList.isEmpty()) {
  //     return new List<PointCreditDTO>();
  //   }

  //   // return getPointService().creditSepcificPoints(newTj, lltList);

  //   // Id creditPointJt = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true); // 포인트/쿠폰 지급
  //   // Id purchaseAccrualJt = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT, true); // API 요청에 의한 포인트 강제 지급(적립) 처리

  //   // newTj.JournalTypeId = creditPointJt;
  //   // newTj.JournalSubTypeId = purchaseAccrualJt;

  //   // insert newTj;

  //   List<Map<String, Object>> reqList = new List<Map<String, Object>>();

  //   for (LoyaltyLedgerTraceability llt : lltList) {
  //     Map<String, Object> req = new Map<String, Object>();
  //     req.put('loyaltyProgramMemberId', newTj.MemberId);
  //     req.put('journalId', newTj.Id);
  //     req.put('loyaltyProgramCurrencySubtypeName', llt.LoyaltyPgmCurrencySubtype.Name);
  //     req.put('points', llt.Points);
  //     req.put('additionalNotes', ECO_POINT_RESTORE_NOTE);
  //     req.put('pointsExpirationDate', String.valueOf(llt.CreditLoyaltyLedger.ExpiryDate));
  //     reqList.add(req);
  //   }

  //   LoyaltyPointService.creditPoints(reqList);

  //   List<LoyaltyLedger> llList = [
  //     SELECT
  //       Id,
  //       TransactionJournalId,
  //       LoyaltyPgmCrcySubtype.Name,
  //       Points,
  //       ExpiryDate,
  //       EscrowPointsCreditDate,
  //       ActivityDate,
  //       CreatedDate,
  //       EventType,
  //       AdditionalNotes,
  //       LoyaltyPgmCrcySubtype.PointTypeCode__c
  //     FROM LoyaltyLedger
  //     WHERE TransactionJournalId = :newTj.Id
  //     LIMIT 100
  //   ];

  //   TransactionJournal tj2 = [
  //     SELECT
  //       Id,
  //       MemberId,
  //       TYPEOF Member
  //         WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
  //       END
  //     FROM TransactionJournal
  //     WHERE Id = :newTj.Id
  //     LIMIT 1
  //   ];
  //   SObject memberObj = tj2.getSObject('Member');
  //   if (memberObj == null) {
  //     throw new CustomException(500, 'memberObj is null');
  //   }
  //   SObject contactObj = memberObj.getSObject('Contact');
  //   if (contactObj == null) {
  //     throw new CustomException(500, 'contactObj is null');
  //   }
  //   String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

  //   Decimal totalPoints = 0;

  //   List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
  //   for (LoyaltyLedger ll : llList) {
  //     PointCreditDTO pcDto = new PointCreditDTO();
  //     pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
  //     pcDto.CD_TYPE_POINT = ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
  //     pcDto.NO_MBR = memberNo;
  //     pcDto.PT_TARGET = ll.Points; // 적립 포인트
  //     pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
  //     pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
  //     pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate.addDays(-1)); // 포인트 유효기간 종료일
  //     pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate); // 소멸 예정일
  //     pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
  //     pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
  //     pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
  //     pcDtoList.add(pcDto);

  //     if (ll.Points > 0) {
  //       totalPoints += ll.Points;
  //     }
  //   }
  //   newTj.TransactionAmount = totalPoints;
  //   update newTj;

  //   return pcDtoList;
  // }
}