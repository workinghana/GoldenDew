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
  private static final String JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL = 'Promotion Point Accrual';
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
        WHERE
          VoucherCode = :realVoucherCode
          AND LoyaltyProgramMemberId = :tj.MemberId
          AND Status = 'Redeemed'
          AND VoucherDefinition.CouponManNo__c = :couponManNo
        LIMIT 1
      ];
    } else {
      voucherList = [
        SELECT UsedTransactionJournalId__c, UsedTransactionJournalId__r.OrderId, UsedTransactionJournalId__r.OrderId__c
        FROM Voucher
        WHERE VoucherCode = :searchVoucherCode AND LoyaltyProgramMemberId = :tj.MemberId AND Status = 'Redeemed'
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

      Boolean isOptionCOldSale = false;
      try {
        isOptionCOldSale = GdMigrationUtil.shouldApplyOptionCBranchByOrderId((Id) originalOrderId);
      } catch (Exception ignoredOptC) {
        isOptionCOldSale = false;
      }

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
            tj.JournalTypeId = SObjectCacheUtil.findIdByNameCached(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
            tj.JournalSubTypeId = SObjectCacheUtil.findIdByNameCached(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true);
            voucherSvc.redeemCancelVoucher(tj);
          } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            // 쿠폰 사용
            tj.JournalTypeId = SObjectCacheUtil.findIdByNameCached(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
            tj.JournalSubTypeId = SObjectCacheUtil.findIdByNameCached(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
            voucherSvc.redeemVoucherV2(tj);
          }
          continue;
        }

        if ('81'.equals(paymentMethod)) {
          // 포인트 사용 취소 (03 = 환불)
          if ('03'.equals(depositType)) {
            Map<String, Object> cancelPointResult = pointSvc.cancelPointRedemption(tj);
            data.put('CancelPointList', cancelPointResult);
          }
          // 포인트 사용 (01 = 선수금 | 02 = 잔금)
          else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            // 신규 로직 (26.05.11 CS)
            throw new CustomException(400, '반품 시 입금 구분 코드 오류. 입금 구분 코드 : ' + depositType);
            // 반품 등록 시 depositType는 '03'으로만 들어 온다고 함.

            /*
            // 기존 로직
            List<GdSaleApiController.PointDebitDTO> debitPointList = pointSvc.debitPoint(tj);
            data.put('DebitPointList', debitPointList);

            */
          }
        } else {
          tj.Status = 'Processed';
          if ('01'.equals(depositType) || '02'.equals(depositType)) {
            tj.JournalTypeId = SObjectCacheUtil.findIdByNameCached(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true);
            tj.JournalSubTypeId = SObjectCacheUtil.findIdByNameCached(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true);
            depositTransactionList.add(tj);
          } else if ('03'.equals(depositType)) {
            tj.JournalTypeId = SObjectCacheUtil.findIdByNameCached(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, true);
            tj.JournalSubTypeId = SObjectCacheUtil.findIdByNameCached(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true);
            cancelDepositTransactionList.add(tj);
          }
          tjList.add(tj);
        }
      }

      if (!tjList.isEmpty()) {
        List<Database.SaveResult> resultList = Database.insert(tjList);
        for (Database.SaveResult result : resultList) {
          if (!result.isSuccess()) {
            Database.Error err = result.getErrors()[0];
            throw new CustomException(400, err.getMessage());
          }
        }
      }

      // 구매 시 포인트 적립 로직
      if (!depositTransactionList.isEmpty()) {
        List<PointCreditDTO> creditPointList = pointSvc.creditPointsOnPurchase(depositTransactionList);
        // [Null Safe Fix 2026-05-07] creditPointsOnPurchase 가 적립 대상 금액 0 케이스에서 null 반환할 수 있음.
        //   GdPointServiceImpl.creditPointsOnPurchase 의 early return 추가로 인해 null 안전 처리 필요.
        if (creditPointList != null) {
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
      }

      // 구매 시 포인트 적립 취소 로직
      if (!cancelDepositTransactionList.isEmpty()) {
        // List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedList = pointSvc.cancelPointsCreditedOnPurchase(cancelDepositTransactionList);  // 기존 로직

        // 신규 로직 Start.(26.04.02)
        List<TransactionJournal> accrualEligibleCancelTransactions = buildAccrualEligibleCancelTransactions(
          originalOrderId,
          orderId,
          cancelDepositTransactionList,
          returnOrderItemRequestList
        );

        // [Return Register Validation Move 2026-05-08] createReturn 에서 이전된 검증.
        //   배경: createReturn 단계에서는 어떤 입금이 환불될지 모르기에 모든 케이스를 차단했음.
        //         쿠폰/포인트/상품권 등 적립 대상 아닌 입금만 환불하는 부분 반품도 부당 차단.
        //   해결: 반품 입금 등록 시점에 적립 대상 환불 (accrualEligibleCancelTransactions 비어있지 않음) 인 경우만 검증.
        //         즉 적립 영향 발생할 때만 → A판매 적립 포인트가 다른 곳에서 사용되었는지 확인 → 차단.
        //   안전망:
        //     - LIMIT 50000 명시 (governor 한계 보호).
        //     - SubType filter 미추가 (deleteSaleDeposit 와 동일한 차단 폭) → 일관성.
        //     - 모든 사용처 collect/dedupe/정렬 (deleteSale/deleteSaleDeposit 패턴 통일).
        if (isOptionCOldSale) {
          accrualEligibleCancelTransactions.clear();
        }

        if (!accrualEligibleCancelTransactions.isEmpty()) {
          // [Refunded Usage Exclusion 2026-05-08] deleteSale 과 동일 패턴 — Cancel Credit 환불/재사용 차감 식.
          //   기존 단순 LLT 매칭 검증 → calculateUnrefundedUsage 로 환불받은 사용분 자동 제외.
          //   부분 반품도 같은 정합 정책 적용 (B 반품 후 A 적립이 회수 가능한 경우만 차단).
          GdSaleServiceImpl.UnrefundedUsageResult validationResult = GdSaleServiceImpl.calculateUnrefundedUsage(originalOrderId);
          if (validationResult.shouldBlock()) {
            throw new CustomException(
              400,
              validationResult.buildBlockMessage('반품 입금 등록 불가 — 적립된 포인트가 다른 주문/판매에서 이미 사용되었습니다.')
            );
          }
        }

        List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedList = null;
        if (!accrualEligibleCancelTransactions.isEmpty()) {
          cancelPointsCreditedList = pointSvc.cancelPointsCreditedOnPurchase(accrualEligibleCancelTransactions);
        }
        // 신규 로직 End.(26.04.02)
        data.put('CancelPointsCreditedList', cancelPointsCreditedList);
      }

      // 통반품 여부 확인
      if (isFullReturn(originalOrderId)) {
        // 에코포인트 회수
        List<PointDebitDTO> ecoPointCancelList = cancelEcoPointsForFullReturn(orderId, originalOrderId, lpmList[0], insertId);
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
              WHERE
                VoucherCode = :realVoucherCode
                AND VoucherDefinition.CouponManNo__c = :couponManNo
                AND LoyaltyProgramMemberId = :memberId
                AND VoucherDefinition.Type = 'DiscountPercentage'
              LIMIT 1
            ];
          } else {
            percentageVouchers = [
              SELECT Id
              FROM Voucher
              WHERE VoucherCode = :searchVoucherCode AND LoyaltyProgramMemberId = :memberId AND VoucherDefinition.Type = 'DiscountPercentage'
              LIMIT 1
            ];
          }

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

  // ! 사용 x
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
            // [Origin Check 2026-05-08] deleteReturnDeposit 와 동일 — origin 적립 판매 활성 검증.
            validateReturnDepositDeleteOrigin(tj.Id, tj.MemberId);
            newTj.AdditionalNotes__c = RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE;
            List<LoyaltyLedger> llList = [
              SELECT Id, EventType, LoyaltyPgmCrcySubtypeId, Points, LoyaltyPgmCrcySubtype.Name, AdditionalNotes, ExpiryDate
              FROM LoyaltyLedger
              WHERE TransactionJournalId = :tj.Id AND LoyaltyProgramMemberId = :tj.MemberId
              LIMIT 100
            ];
            List<LoyaltyLedger> restoredCreditLedgers = filterRestoredPointCreditLedgers(llList);
            Map<Id, Decimal> recoverableAmountByLedgerId = buildReturnDeleteRecoverablePointAmounts(restoredCreditLedgers, tj.MemberId);
            List<PointDebitDTO> debitPointResult = getPointService().debitSpecificPointsV3(newTj, recoverableAmountByLedgerId);
            adjustExpiredRestoredPointLedgersAfterReturnDelete(recoverableAmountByLedgerId, tj.MemberId);
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
                CreditLoyaltyLedger.AdditionalNotes,
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
      rebuildPointAggregationForReturnDepositMembers(tjList);

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
   * * 사용 중
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

      // [Fix Bug B 2026-05-27] SaleId__c fallback 매칭 추가.
      //   배경: 기존 SOQL 은 RelatedJournalId = sourceTj.Id 만 매칭하나, 반품 등록 시 발생한
      //         Cancel Purchase Accrual TJ 의 RelatedJournalId 가 null 인 경우가 있어 매칭 실패.
      //         → 반품 입금 삭제 시 부수 CPA TJ 미정리 → 후속 반품 등록 시 같은 적립 LL 이중 cancel.
      //         (회원 253007200063 케이스의 38,220 over-cancellation 사건)
      //   해결: RelatedJournalId 매칭 + sourceTj.SaleId__c 존재 시 SaleId__c 매칭 fallback.
      //         SOQL 안에 변수 null check 불가능하므로 Apex 분기.
      String saleIdText = sourceTj.SaleId__c;
      if (String.isNotBlank(saleIdText)) {
        linkedAccrualReversalTjList = [
          SELECT
            Id, JournalSubTypeId, LoyaltyProgramId, MemberId, OrderId, PromotionId,
            OrderId__c, SaleId__c, DepositNo__c, RelatedJournalId, IsDeleted__c, DeleteDateTime__c
          FROM TransactionJournal
          WHERE MemberId = :sourceTj.MemberId
            AND IsDeleted__c = FALSE
            AND JournalSubTypeId IN :new Set<Id>{ cancelPurchaseAccrualJstId, promotionPointAccrualReversalJstId }
            AND (RelatedJournalId = :sourceTj.Id OR SaleId__c = :saleIdText)
        ];
      } else {
        linkedAccrualReversalTjList = [
          SELECT
            Id, JournalSubTypeId, LoyaltyProgramId, MemberId, OrderId, PromotionId,
            OrderId__c, SaleId__c, DepositNo__c, RelatedJournalId, IsDeleted__c, DeleteDateTime__c
          FROM TransactionJournal
          WHERE MemberId = :sourceTj.MemberId
            AND IsDeleted__c = FALSE
            AND JournalSubTypeId IN :new Set<Id>{ cancelPurchaseAccrualJstId, promotionPointAccrualReversalJstId }
            AND RelatedJournalId = :sourceTj.Id
        ];
      }

      if (
        sourceTj.JournalSubTypeId == pointRedeemCancelJstId ||
        sourceTj.JournalSubTypeId == couponRedeemCancelJstId ||
        sourceTj.JournalSubTypeId == saleDepositReversalJstId
      ) {
        if (sourceTj.JournalSubTypeId == pointRedeemCancelJstId) {
          // ? 포인트 내역 복구 진입

          // [Origin Check 2026-05-08] B 반품의 Point Redeem Cancel 삭제 = 사용 복원 (재차감) 시도.
          //   재차감하려면 origin 적립 LL 의 판매 (A판매) 가 활성 상태여야 함.
          //   A 가 이미 삭제됐다면 LL_A 로 재차감 불가 → 다른 적립 LL 끌어쓰거나 가용 부족 에러 발생 가능 → 정합 깨짐.
          //   해결: Cancel Credit LL 의 origin 적립 판매가 IsDeleted=true 면 차단.
          //   Cancel Credit LL → origin 매핑은 같은 (SubType, ExpiryDate) 의 Purchase/Promotion Accrual LL 로 추적.
          validateReturnDepositDeleteOrigin(sourceTj.Id, sourceTj.MemberId);

          newTj.AdditionalNotes__c = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';
          // [수정] 2026-04-21: 만료된 포인트 필터링 추가
          // 원인: 반품 시점에 ExpiryDate가 지나 복원되지 못한 포인트는 LoyaltyLedger에 남아있지만
          //       Salesforce 표준 LoyaltyManagement.debitPoints API가 "가용 포인트 부족"으로 거부하여 500 에러 발생.
          // 해결: ExpiryDate < TODAY 건을 재차감 대상에서 분리하여 호출 자체를 스킵하고, 응답에 별도 key로 기록.
          //       동일 파일 Sale Deposit Reversal 분기(line 690)의 ExpiryDate >= TODAY 기준과 일관.
          List<LoyaltyLedger> llList = [
            SELECT Id, EventType, LoyaltyPgmCrcySubtypeId, Points, LoyaltyPgmCrcySubtype.Name, AdditionalNotes, ExpiryDate
            FROM LoyaltyLedger
            WHERE TransactionJournalId = :sourceTj.Id AND LoyaltyProgramMemberId = :sourceTj.MemberId
            LIMIT 100
          ];

          List<LoyaltyLedger> expiredLedgers = new List<LoyaltyLedger>();
          List<PointDebitDTO> debitPointResult = new List<PointDebitDTO>();
          if (!llList.isEmpty()) {
            List<LoyaltyLedger> restoredCreditLedgers = filterRestoredPointCreditLedgers(llList);
            Map<Id, Decimal> recoverableAmountByLedgerId = buildReturnDeleteRecoverablePointAmounts(restoredCreditLedgers, sourceTj.MemberId);
            debitPointResult = getPointService().debitSpecificPointsV3(newTj, recoverableAmountByLedgerId);
            adjustExpiredRestoredPointLedgersAfterReturnDelete(recoverableAmountByLedgerId, sourceTj.MemberId);
          }
          data.put('포인트 사용 내역 복구', debitPointResult);

          if (!expiredLedgers.isEmpty()) {
            List<Map<String, Object>> expiredSkipped = new List<Map<String, Object>>();
            for (LoyaltyLedger ll : expiredLedgers) {
              expiredSkipped.add(
                new Map<String, Object>{
                  'PointTypeName' => ll.LoyaltyPgmCrcySubtype.Name,
                  'Points' => ll.Points,
                  'ExpiryDate' => ll.ExpiryDate,
                  'Note' => '만료 포인트 재차감 스킵 (사용 상태 유지)'
                }
              );
            }
            data.put('포인트 사용 만료 확정(재차감 스킵)', expiredSkipped);
          }
        } else if (sourceTj.JournalSubTypeId == couponRedeemCancelJstId) {
          // ? 쿠폰 내역 복구 진입

          // 26.05.01 GD - 쿠폰 코드 분할 "쿠폰 사용" 내역 복구 진입 - 쿠폰 상태별 분기 처리
          String searchVoucherCode = sourceTj.VoucherCode;
          List<Voucher> vList = new List<Voucher>();

          if (String.isNotBlank(searchVoucherCode) && searchVoucherCode.contains(';-;')) {
            String couponManNo = searchVoucherCode.substringBefore(';-;');
            String realVoucherCode = searchVoucherCode.substringAfter(';-;');

            vList = [
              SELECT
                Id,
                Status,
                ExpirationDate,
                VoucherCode,
                LoyaltyProgramMemberId,
                VoucherDefinitionId,
                VoucherDefinition.Name,
                VoucherDefinition.IsUnlimited__c,
                UsedTransactionJournalId__c
              FROM Voucher
              WHERE VoucherCode = :realVoucherCode AND VoucherDefinition.CouponManNo__c = :couponManNo AND LoyaltyProgramMemberId = :sourceTj.MemberId
              LIMIT 1
            ];
          } else {
            vList = [
              SELECT
                Id,
                Status,
                ExpirationDate,
                VoucherCode,
                LoyaltyProgramMemberId,
                VoucherDefinitionId,
                VoucherDefinition.Name,
                VoucherDefinition.IsUnlimited__c,
                UsedTransactionJournalId__c
              FROM Voucher
              WHERE VoucherCode = :searchVoucherCode AND LoyaltyProgramMemberId = :sourceTj.MemberId
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
            data.put(
              '쿠폰 상태 유지',
              new Map<String, Object>{
                'VoucherCode' => v.VoucherCode,
                'Status' => v.Status,
                'ExpirationDate' => v.ExpirationDate,
                'Note' => '만료 후 반품 취소 - 쿠폰 Redeemed 상태 유지'
              }
            );
          } else if (v.Status == 'Expired') {
            // 레거시 데이터 (과거 반품에서 Expired 로 전이된 쿠폰): 복원 불가, 기록만 남김
            newTj.AdditionalNotes__c = '반품 입금 삭제: 이미 Expired 쿠폰 (레거시 복원 불가)';
            insert newTj;
            data.put(
              '쿠폰 Expired 상태 유지',
              new Map<String, Object>{
                'VoucherCode' => v.VoucherCode,
                'Status' => v.Status,
                'ExpirationDate' => v.ExpirationDate,
                'Note' => '레거시 Expired 쿠폰 - 복원 불가'
              }
            );
          } else {
            throw new CustomException(400, '알 수 없는 쿠폰 상태입니다. status=' + v.Status + ', voucherCode=' + v.VoucherCode);
          }
        } else {
          // ? 일반 입금 복구 진입

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
            rebuildPointAggregationForMembers(new Set<Id>{ sourceTj.MemberId });
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
              SELECT Id
              FROM LoyaltyLedger
              WHERE
                TransactionJournal.OrderId = :sourceTj.OrderId
                AND TransactionJournal.JournalTypeId = :purchaseAccrualJtId2
                AND TransactionJournal.JournalSubTypeId = :purchaseAccrualJstId2
                AND EventType = 'Credit'
              LIMIT 1
            ]
            .isEmpty();

          if (!hadOriginalPurchaseAccrual) {
            sourceTj.IsDeleted__c = true;
            sourceTj.DeleteDateTime__c = Datetime.now();
            update sourceTj;
            rebuildPointAggregationForMembers(new Set<Id>{ sourceTj.MemberId });
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
                  CreditLoyaltyLedger.AdditionalNotes,
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
                  CreditLoyaltyLedger.AdditionalNotes,
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
                  CreditLoyaltyLedger.AdditionalNotes,
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
              // Preserve CreditCancellation traceability. The restore Credit offsets the
              // cancellation, while the trace remains necessary for aggregation/help-info
              // to identify the original sale accrual bucket.
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
              creditPointsOnPurchaseResult = getPointService().creditPointsOnPurchase(new List<TransactionJournal>{ sourceTj });
            }

            if (sourceTj.PromotionId != null) {
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
            if (!creditPromotionPointsResult.isEmpty()) {
              data.put('프로모션 포인트 지급 내역 복구', creditPromotionPointsResult);
            }
          }
          data.put('포인트 지급 내역 복구', creditPointsOnPurchaseResult);
        }
      }

      sourceTj.IsDeleted__c = true;
      sourceTj.DeleteDateTime__c = Datetime.now();
      update sourceTj;
      if (!linkedAccrualReversalTjList.isEmpty()) {
        update linkedAccrualReversalTjList;
      }
      rebuildPointAggregationForMembers(new Set<Id>{ sourceTj.MemberId });

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

  private static void rebuildPointAggregationForReturnDepositMembers(List<TransactionJournal> transactionJournals) {
    Set<Id> memberIds = new Set<Id>();
    if (transactionJournals != null) {
      for (TransactionJournal tj : transactionJournals) {
        if (tj != null && tj.MemberId != null) {
          memberIds.add(tj.MemberId);
        }
      }
    }
    rebuildPointAggregationForMembers(memberIds);
  }

  private static void rebuildPointAggregationForMembers(Set<Id> memberIds) {
    if (memberIds == null || memberIds.isEmpty()) {
      return;
    }
    for (Id memberId : memberIds) {
      if (memberId != null) {
        GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger(memberId);
      }
    }
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
        return false;
      }
      Decimal returnedMagnitude = (returnOi.Quantity == null) ? 0 : returnOi.Quantity.abs();
      Decimal currentQty = returnQtyByProductId.containsKey(productId) ? returnQtyByProductId.get(productId) : 0;
      returnQtyByProductId.put(productId, currentQty + returnedMagnitude);
    }

    if (returnQtyByProductId.size() != originalQtyByProductId.size()) {
      return false;
    }

    for (Id productId : originalQtyByProductId.keySet()) {
      Decimal returnedQty = returnQtyByProductId.get(productId);
      if (returnedQty == null || returnedQty < originalQtyByProductId.get(productId)) {
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
        // 26.05.05 CS - Quantity 추가. fallback 시 단가×수량 으로 계산.
        SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c, Quantity
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
        // 26.05.05 CS - Quantity 반영.
        // returnItemAmount(요청에서 들어온 NetSalesUnitPrice__c) 는 호출자가 명시한 "반품 항목 금액" 으로 그대로 사용.
        // returnItemAmount 가 비어있는 경우만 원판매 단가×수량 으로 fallback.
        if (returnItemAmount != null) {
          excludedAmount += returnItemAmount;
        } else {
          Decimal unitPrice = originalOi.NetSalesUnitPrice__c != null ? originalOi.NetSalesUnitPrice__c : 0;
          Decimal qty = originalOi.Quantity != null ? originalOi.Quantity : 1;
          excludedAmount += unitPrice * qty;
        }
      }
    }

    return excludedAmount;
  }

  private static Decimal getExcludedReturnAmountFromStoredReturnItems(Id returnOrderId) {
    Decimal excludedAmount = 0;
    for (OrderItem returnOi : [
      // 26.05.05 CS - Quantity 추가. 반품 OrderItem 의 Quantity 를 단가에 곱해서 적립 제외 금액 산출.
      //   IsExclude/단가 판정 기준(원판매 vs 반품) 과 무관하게, 실제 반품된 수량은 returnOi.Quantity 를 사용.
      SELECT
        IsExclude__c,
        NetSalesUnitPrice__c,
        Quantity,
        OriginalOrderItemId__c,
        OriginalOrderItem.IsExclude__c,
        OriginalOrderItem.NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :returnOrderId
    ]) {
      Boolean isExcluded = returnOi.OriginalOrderItemId__c != null ? returnOi.OriginalOrderItem.IsExclude__c : returnOi.IsExclude__c;
      Decimal unitPrice = returnOi.OriginalOrderItemId__c != null ? returnOi.OriginalOrderItem.NetSalesUnitPrice__c : returnOi.NetSalesUnitPrice__c;

      if (isExcluded == true) {
        Decimal price = unitPrice != null ? unitPrice : 0;
        Decimal qty = returnOi.Quantity != null ? returnOi.Quantity.abs() : 1;
        excludedAmount += price * qty;
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
   * * 사용 중
   * 원판매 입금 이력 중 포인트 적립 대상 결제 금액 합계 계산
   */
  @TestVisible
  private static Decimal getOriginalAccrualEligibleDepositAmount(Id originalOrderId) {
    Decimal eligibleDepositAmount = 0;
    Id saleDepositJstId = SObjectCacheUtil.findIdByNameCached(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true);
    Id orderDepositJstId = SObjectCacheUtil.findIdByNameCached(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT, true);

    /*
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
    */
    for (TransactionJournal tj : [
      SELECT PaymentMethod, TransactionAmount
      FROM TransactionJournal
      WHERE
        (OrderId = :originalOrderId
        OR SaleId__c = :originalOrderId) // ← OR 추가
        AND JournalSubTypeId IN (
          :saleDepositJstId,
          :orderDepositJstId // ← IN으로 변경 (신규 로직 26.05.18 CS)
        )
        AND IsDeleted__c = FALSE
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
   * [SB 검증 전용] cancelEcoPointsForFullReturn 의 anonymous Apex 호출용 wrapper.
   * 운영 흐름은 insertSaleDepositHistoryByUpdate 내부에서만 호출됨. 외부 호출 금지.
   * 2026-05-05 추가 (Flag ON/OFF 단위 검증용 — 검증 완료 후 제거 가능).
   */
  public static List<PointDebitDTO> sbVerifyCancelEcoPointsForFullReturn(
    Id returnOrderId,
    Id originalOrderId,
    LoyaltyProgramMember lpm,
    String insertId
  ) {
    return cancelEcoPointsForFullReturn(returnOrderId, originalOrderId, lpm, insertId);
  }

  /**
   * [운영용 entry point] 판매 전체 삭제 흐름(GdSaleApiControllerV1.deleteSale)에서 호출되는 에코포인트 회수.
   *
   * 통반품 흐름의 cancelEcoPointsForFullReturn 와 동일한 정책으로 처리한다.
   * Feature Flag 'EcoPointCancel_UseSpecificLedger' ON 시 자기 판매 LL 만 가리키는 _v2 경로로 위임.
   * Flag OFF 시 호출자(GdSaleApiControllerV1.deleteSale) 측 기존 블록이 그대로 유지됨 — 본 메서드는 호출되지 않음.
   *
   * 호출 측 책임: Flag ON 일 때만 본 메서드 호출. Flag OFF 일 때는 기존 코드 경로로 분기.
   *
   * 2026-05-05 추가 (판매 삭제 흐름의 cross-sale 누설 결함 수정용).
   */
  public static List<PointDebitDTO> cancelEcoPointsForSaleDelete(Id orderId, LoyaltyProgramMember lpm, String insertId) {
    return cancelEcoPointsForFullReturn_v2(orderId, orderId, lpm, insertId);
  }

  /**
   * 에코포인트 회수
   **/
  @TestVisible
  private static List<PointDebitDTO> cancelEcoPointsForFullReturn(Id returnOrderId, Id originalOrderId, LoyaltyProgramMember lpm, String insertId) {
    // [Feature Flag 분기 — 2026-05-05] EcoPointCancel_UseSpecificLedger ON 시 신규 경로 사용
    // 신규 경로는 표준 LoyaltyPointService.debitPoints() 의 FIFO 분배가 다른 판매의 에코 적립 LL 로
    // 흘러가는 결함을 우회하고, 자기 판매(originalOrderId) 의 에코 적립 LL 을 직접 가리키는
    // Debit LL / Trace 를 수동 생성. Flag OFF 시 기존 로직 그대로 실행 (회귀 영향 없음).
    // * 현재 Flag On 상태
    if (GdFeatureFlag.isEnabled('EcoPointCancel_UseSpecificLedger')) {
      return cancelEcoPointsForFullReturn_v2(returnOrderId, originalOrderId, lpm, insertId);
    }

    // 에코포인트 회수했는지 체크
    if (hasActiveEcoCancellation(returnOrderId)) {
      System.debug('if (hasActiveEcoCancellation(returnOrderId)) { 진입');
      return new List<PointDebitDTO>();
    }

    // [Eco Usage Validation 2026-05-08] _v2 와 동일 — 에코 사용 차단 검증.
    // 에코포인트가 다른 주문/판매에서 사용되었을 경우 차단한다.
    validateEcoUsageBeforeCancel(originalOrderId);

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
   * cancelEcoPointsForFullReturn_v2 — Feature Flag 'EcoPointCancel_UseSpecificLedger' ON 시 사용
   *
   * 표준 LoyaltyPointService.debitPoints() 의 FIFO 분배 결함을 우회하기 위해
   * 자기 판매(originalOrderId) 의 에코 적립 LL 을 직접 가리키는 Debit LL 과 Trace 를 수동 생성한다.
   *
   * 결함 메커니즘 (Flag OFF):
   *   1. debitPoints API 가 자동 Trace 를 만들어 만료일 빠른 가용 포인트부터 FIFO 차감
   *   2. 다른 판매(예: A 판매) 의 에코 적립 LL 이 차감 대상으로 잡혀
   *      Credit=A판매 / Debit=B판매 형태의 잘못된 LLT 가 생성됨
   *   3. 이후 A 판매 삭제 검증 SOQL 이 이 LLT 를 보고 "사용 중" 으로 오판하여 차단
   *
   * 신규 경로 (Flag ON):
   *   1. originalOrderId 의 에코 적립 LL 만 직접 조회 (자기 판매 한정)
   *   2. 원본 적립 LL 의 SubType / ExpiryDate 를 정확히 가리키는 Debit LL / Trace 직접 생성
   *   3. tj.Status 를 Pending → Processed 로 update 시 트리거가 정확한 Trace 를 보고 처리
   *   4. Trace ActionType 'Debit' → 'CreditCancellation' 으로 사후 교체
   *      (회원 도움창 PT_DESTROY 집계가 CreditCancellation 만 합산하므로 필수)
   *   5. LMC.TotalPointsRedeemed 직접 갱신 (표준 API 우회 시 자동 갱신 누락 보정)
   *
   * 응답 DTO 구조 (PointDebitDTO) 와 호출자 인터페이스는 기존과 100% 동일.
   *
   * 2026-05-05 작성 (cancelAccrualPointsBySubtype_v2 동일 패턴 차용).
   */
  private class EcoPointCancelContext {
    List<LoyaltyLedger> originalEcoCreditLedgerList = new List<LoyaltyLedger>();
    Map<Id, Decimal> remainingByLedgerId = new Map<Id, Decimal>();
    Integer remainingPoint = 0;
    Id loyaltyProgramCurrencyId;
  }

  private static EcoPointCancelContext buildEcoPointCancelContext(Id originalOrderId) {
    EcoPointCancelContext ctx = new EcoPointCancelContext();

    Id accrualJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
    Id apiForcedCreditJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT, true);

    ctx.originalEcoCreditLedgerList = [
      SELECT
        Id,
        Points,
        LoyaltyPgmCrcySubtypeId,
        LoyaltyPgmCrcySubtype.Name,
        LoyaltyProgramCurrencyId,
        LoyaltyProgramMemberId,
        ExpiryDate,
        ActivityDate,
        CreatedDate
      FROM LoyaltyLedger
      WHERE
        TransactionJournal.OrderId = :originalOrderId
        AND TransactionJournal.JournalTypeId = :accrualJtId
        AND TransactionJournal.JournalSubTypeId = :apiForcedCreditJstId
        AND LoyaltyPgmCrcySubtype.PointTypeCode__c = :ECO_POINT_TYPE_CODE
        AND EventType = 'Credit'
        AND (TransactionJournal.AdditionalNotes__c = NULL
        OR TransactionJournal.AdditionalNotes__c != :ECO_POINT_RESTORE_NOTE)
      ORDER BY CreatedDate ASC
      LIMIT 200
    ];

    if (ctx.originalEcoCreditLedgerList.isEmpty()) {
      return ctx;
    }

    ctx.loyaltyProgramCurrencyId = ctx.originalEcoCreditLedgerList[0].LoyaltyProgramCurrencyId;
    for (LoyaltyLedger ll : ctx.originalEcoCreditLedgerList) {
      ctx.remainingByLedgerId.put(ll.Id, ll.Points == null ? 0 : ll.Points);
    }

    // [v3 net-match 2026-05-15 / CAR_269999800262]
    //   v3 paradigm (PointCancel_PreserveTrace=ON) 에서는 사용 cancel 시 CC LLT 가 발행되지 않고
    //   Cancel Credit LL 만 발행됨. LLT 만 보는 단순 합산은 사용 cancel 된 양도 활성 사용으로 잘못
    //   인식하여 잔여 = 0 으로 계산 → 에코 회수가 안 됨.
    //   해결: Debit LLT 합 - 같은 origin 의 Cancel Credit LL.Points 합 = net 활성 사용.
    //   동일 패턴: validateEcoUsageBeforeCancel (line 2907~), GdSaleServiceImpl.calculateUnrefundedUsage.
    Map<Id, Decimal> debitSumByLedgerId = new Map<Id, Decimal>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE
        CreditLoyaltyLedgerId IN :ctx.remainingByLedgerId.keySet()
        AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE
        AND DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :ECO_POINT_CANCEL_NOTE))
      GROUP BY CreditLoyaltyLedgerId
    ]) {
      debitSumByLedgerId.put((Id) ar.get('creditLedgerId'), (Decimal) ar.get('totalPoints'));
    }

    Id memberId = ctx.originalEcoCreditLedgerList[0].LoyaltyProgramMemberId;
    Map<Id, Decimal> cancelSumByOriginLLId = new Map<Id, Decimal>();
    for (LoyaltyLedger cc : [
      SELECT Id, Points, AdditionalNotes
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
        AND EventType = 'Credit'
        AND Points > 0
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND AdditionalNotes LIKE '%ORIGIN_CREDIT_LL=%'
      LIMIT 50000
    ]) {
      Id originId = extractOriginCreditLedgerIdFromNotes(cc.AdditionalNotes);
      if (originId == null || !ctx.remainingByLedgerId.containsKey(originId))
        continue;
      Decimal pts = cc.Points == null ? 0 : cc.Points;
      cancelSumByOriginLLId.put(originId, (cancelSumByOriginLLId.containsKey(originId) ? cancelSumByOriginLLId.get(originId) : 0) + pts);
    }

    for (Id ledgerId : new Set<Id>(ctx.remainingByLedgerId.keySet())) {
      Decimal debit = debitSumByLedgerId.containsKey(ledgerId) ? debitSumByLedgerId.get(ledgerId) : 0;
      Decimal cancel = cancelSumByOriginLLId.containsKey(ledgerId) ? cancelSumByOriginLLId.get(ledgerId) : 0;
      Decimal netUsed = debit - cancel;
      if (netUsed < 0)
        netUsed = 0;
      Decimal remaining = ctx.remainingByLedgerId.get(ledgerId) - netUsed;
      ctx.remainingByLedgerId.put(ledgerId, remaining < 0 ? 0 : remaining);
    }

    for (LoyaltyLedger ecoLedger : ctx.originalEcoCreditLedgerList) {
      Decimal remaining = ctx.remainingByLedgerId.get(ecoLedger.Id);
      Integer ledgerRemaining = Math.max(0, (Integer) (remaining == null ? 0 : remaining));
      ctx.remainingByLedgerId.put(ecoLedger.Id, ledgerRemaining);
      ctx.remainingPoint += ledgerRemaining;
    }

    return ctx;
  }

  @TestVisible
  private static List<PointDebitDTO> cancelEcoPointsForFullReturn_v2(
    Id returnOrderId,
    Id originalOrderId,
    LoyaltyProgramMember lpm,
    String insertId
  ) {
    Savepoint sp = Database.setSavepoint();
    try {
      // 에코포인트 회수했는지 체크 (기존 로직과 동일)
      if (hasActiveEcoCancellation(returnOrderId)) {
        return new List<PointDebitDTO>();
      }

      // [Eco Usage Validation 2026-05-08] 통반품/판매전체삭제 시 에코 사용 차단 검증.
      //   배경: A판매에서 에코 적립 → B판매에서 사용 → A 통반품/삭제 시도
      //         이때 A 의 에코 적립을 회수해야 정합. 그러나 이미 B에서 사용된 양은 회수 불가.
      //   기존 동작: getCancelableEcoPointLedgers 가 "잔여" 만 계산 → 잔여만 회수, 사용분은 통과
      //         → 회원 잔액 정합성 깨짐 (A 적립이 사실상 무효화돼야 하는데 살아있음).
      //   해결: A판매 에코 적립 LL 의 활성 사용 LLT 가 1건이라도 있으면 차단.
      //         사용자가 별도로 사용 입금 삭제 / 반품 후 재시도 필요.
      //   안전망: 이미 사용된 흔적 → ECO_POINT_CANCEL_NOTE / RESTORE_NOTE 마커 제외 (회수 흔적 자체는 차단 X).
      validateEcoUsageBeforeCancel(originalOrderId);

      // 취소할 금액 계산 (기존 로직과 동일)
      EcoPointCancelContext ecoCtx = buildEcoPointCancelContext(originalOrderId);
      Integer remainingPoint = ecoCtx.remainingPoint;
      if (remainingPoint <= 0) {
        return new List<PointDebitDTO>();
      }

      // [Step 1] 저널 유형 / 하위 유형 Id 조회 (기존 로직과 동일)
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

      // [Step 2] 자기 판매(originalOrderId) 의 에코 적립 LL 조회
      // (getCancelableEcoPointLedgers 의 SOQL 과 동일 조건 — 동일 마커 제외)
      // LoyaltyProgramCurrencyId 는 첫번째 적립 LL 에서 추출 (모두 동일 — 에코포인트 한 종류)
      Id loyaltyProgramCurrencyId = ecoCtx.loyaltyProgramCurrencyId;

      // [Step 3] 각 원본 적립 LL 의 잔여 한도 계산
      // (이미 차감된 분량 = 기존 LLT 의 Debit + CreditCancellation 합계)
      List<LoyaltyLedger> originalEcoCreditLedgerList = ecoCtx.originalEcoCreditLedgerList;
      Map<Id, Decimal> remainingByLedgerId = ecoCtx.remainingByLedgerId;

      // Map<Id, Order> saleOrderById = loadSaleOrdersByJournalList(data);
      Date saleEndDate = null;
      List<Order> oList = [
        SELECT Id, EndDate, EffectiveDate, SaleNo__c, IsDeleted__c
        FROM Order
        WHERE id = :returnOrderId
        LIMIT 1
      ];
      if (!oList.isEmpty()) {
        saleEndDate = oList[0].EndDate;
      }

      // 기존 차감 분량 합산 (RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE 와
      // ECO_POINT_CANCEL_NOTE 마커는 제외 — getCancelableEcoPointLedgers 와 동일 정책)
      // [Eco Cancel IsDeleted Fix 2026-05-05] 입금 삭제로 무효화된 Debit TJ 의 LLT 도 제외.
      //   배경: 사용 → 사용 입금 삭제 흐름에서 원 Debit TJ.IsDeleted=TRUE 처리되지만 LLT 자체는 보존됨.
      //         IsDeleted 필터 누락 시 무효화된 사용분도 "사용량" 으로 합산되어
      //         적립처 판매 삭제 시 에코 회수가 안 됨 (잔여 0 으로 잘못 인식).
      //   해결: GdSaleDepositServiceImpl/GdReturnServiceImpl/GdMemberHelpInfoServiceImpl 의 동일 패턴과 통일.
      // [Step 4] ecoCancelTj insert (기존 로직과 동일 필드 구성)
      TransactionJournal ecoCancelTj = new TransactionJournal();
      ecoCancelTj.DepositNo__c = 'ECO-' + String.valueOf(returnOrderId);
      ecoCancelTj.DeposiSeqNo__c = '1';
      // ecoCancelTj.JournalDate = Datetime.now();  // 기존
      ecoCancelTj.JournalDate = saleEndDate == null ? Datetime.now() : TimeUtil.dateToUtcStartOfDay(saleEndDate);
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

      // [Step 5] 차감액을 자기 판매 적립 LL 에 직접 분배 (FIFO: CreatedDate ASC)
      List<LoyaltyLedger> newDebitLedgerList = new List<LoyaltyLedger>();
      List<Integer> traceMapDebitIdx = new List<Integer>();
      List<Id> traceMapCreditLedgerId = new List<Id>();
      List<Decimal> traceMapAllocated = new List<Decimal>();
      List<Id> traceMapSubtypeId = new List<Id>();

      Decimal cancelAmount = remainingPoint;
      for (LoyaltyLedger originalLedger : originalEcoCreditLedgerList) {
        if (cancelAmount <= 0) {
          break;
        }
        Decimal available = remainingByLedgerId.get(originalLedger.Id);
        if (available == null || available <= 0) {
          continue;
        }

        Decimal allocated = (cancelAmount > available) ? available : cancelAmount;
        if (allocated <= 0) {
          continue;
        }

        // Debit LL 직접 생성 (원본 적립 LL 의 SubType 정확히 매핑)
        LoyaltyLedger debitLL = new LoyaltyLedger();
        debitLL.LoyaltyProgramMemberId = lpm.Id;
        debitLL.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        debitLL.TransactionJournalId = ecoCancelTj.Id;
        debitLL.LoyaltyPgmCrcySubtypeId = originalLedger.LoyaltyPgmCrcySubtypeId;
        debitLL.Points = allocated;
        debitLL.EventType = 'Debit';
        debitLL.ActivityDate = Datetime.now();

        Integer debitIdx = newDebitLedgerList.size();
        newDebitLedgerList.add(debitLL);

        traceMapDebitIdx.add(debitIdx);
        traceMapCreditLedgerId.add(originalLedger.Id);
        traceMapAllocated.add(allocated);
        traceMapSubtypeId.add(originalLedger.LoyaltyPgmCrcySubtypeId);

        cancelAmount -= allocated;
      }

      if (cancelAmount > 0) {
        throw new CustomException(400, '에코포인트 회수 분배 실패 — 자기 판매 적립 LL 잔여 부족. 남은 포인트: ' + cancelAmount);
      }

      if (newDebitLedgerList.isEmpty()) {
        return new List<PointDebitDTO>();
      }

      // [Step 6] Debit LL insert
      insert newDebitLedgerList;

      // [Step 7] Trace 직접 생성 (ActionType = 'Debit' → 트리거 진입 조건 충족)
      List<LoyaltyLedgerTraceability> newTraceList = new List<LoyaltyLedgerTraceability>();
      for (Integer i = 0; i < traceMapDebitIdx.size(); i++) {
        LoyaltyLedger debitLL = newDebitLedgerList[traceMapDebitIdx[i]];
        LoyaltyLedgerTraceability trace = new LoyaltyLedgerTraceability();
        trace.LoyaltyProgramMemberId = lpm.Id;
        trace.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        trace.LoyaltyPgmCurrencySubtypeId = traceMapSubtypeId[i];
        trace.CreditLoyaltyLedgerId = traceMapCreditLedgerId[i];
        trace.DebitLoyaltyLedgerId = debitLL.Id;
        trace.Points = traceMapAllocated[i];
        trace.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
        newTraceList.add(trace);
      }
      insert newTraceList;

      // [Step 8] TJ.Status 를 Pending → Processed 로 update
      // 이 시점에 Aggregate 트리거 발화 → ApiForcedDebit 분기에서 totalAccrualPoint -= 적용
      // (자기 판매 LL 의 SubType / ExpiryDate 만 가리키므로 잘못된 버킷 갱신 없음)
      Decimal totalCancelPointsForTj = 0;
      for (Decimal p : traceMapAllocated) {
        totalCancelPointsForTj += p;
      }
      ecoCancelTj.TransactionAmount = totalCancelPointsForTj;
      ecoCancelTj.Status = 'Processed';
      update ecoCancelTj;

      // [Step 9] Trace ActionType 'Debit' → 'CreditCancellation' 으로 교체
      // ActionType 필드가 updateable=false 라 update 불가 → delete + 재 insert.
      // 이유:
      //  - 트리거는 이미 'Debit' Trace 처리 완료 (Aggregate 갱신 끝남)
      //  - 회원 도움창 buildAccrualExpiredPointMap (PT_DESTROY 집계) 가
      //    ActionType = 'CreditCancellation' 만 합산하므로 통반품 에코 회수를 소멸로 표시하려면 필수
      //  - 기존 (Flag OFF) 로직 line 1392-1410 와 동일 동작
      List<LoyaltyLedgerTraceability> tracesToReplace = [
        SELECT Id, LoyaltyProgramMemberId, LoyaltyProgramCurrencyId, LoyaltyPgmCurrencySubtypeId, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId, Points
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :newTraceList
      ];

      List<LoyaltyLedgerTraceability> replacementTraces = new List<LoyaltyLedgerTraceability>();
      for (LoyaltyLedgerTraceability t : tracesToReplace) {
        LoyaltyLedgerTraceability newT = new LoyaltyLedgerTraceability();
        newT.LoyaltyProgramMemberId = t.LoyaltyProgramMemberId;
        newT.LoyaltyProgramCurrencyId = t.LoyaltyProgramCurrencyId;
        newT.LoyaltyPgmCurrencySubtypeId = t.LoyaltyPgmCurrencySubtypeId;
        newT.CreditLoyaltyLedgerId = t.CreditLoyaltyLedgerId;
        newT.DebitLoyaltyLedgerId = t.DebitLoyaltyLedgerId;
        newT.Points = t.Points;
        newT.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;
        replacementTraces.add(newT);
      }

      Database.delete(tracesToReplace);
      if (!replacementTraces.isEmpty()) {
        insert replacementTraces;
      }

      // [Step 10] LMC.TotalPointsRedeemed 직접 갱신
      // 표준 LoyaltyPointService.debitPoints 를 우회했기 때문에 LMC 자동 갱신이 누락됨.
      // (cancelAccrualPointsBySubtype_v2 의 Step 11.5 패턴과 동일)
      List<LoyaltyMemberCurrency> lmcList = [
        SELECT Id, TotalPointsRedeemed
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :lpm.Id AND LoyaltyProgramCurrency.Id = :loyaltyProgramCurrencyId
        LIMIT 1
      ];
      if (!lmcList.isEmpty()) {
        LoyaltyMemberCurrency lmc = lmcList[0];
        lmc.TotalPointsRedeemed = (lmc.TotalPointsRedeemed == null ? 0 : lmc.TotalPointsRedeemed) + totalCancelPointsForTj;
        update lmc;
      }

      // [Step 11] 응답 DTO 빌드 (기존 응답 구조 100% 동일 유지)
      // 방금 생성한 Trace (replacementTraces) 의 Id 기반으로 빌드
      Set<Id> newTraceIdSet = new Set<Id>();
      for (LoyaltyLedgerTraceability t : replacementTraces) {
        if (t.Id != null) {
          newTraceIdSet.add(t.Id);
        }
      }

      List<LoyaltyLedgerTraceability> resultLltList = [
        SELECT
          Id,
          DebitLoyaltyLedgerId,
          CreditLoyaltyLedgerId,
          Points,
          LastModifiedDate,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          LoyaltyPgmCurrencySubtype.Name,
          LoyaltyProgramMember.Contact.MemberNo__c
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :newTraceIdSet
        LIMIT 1000
      ];

      // Order 정보 조회 (NO_SAL 채우기 — 기존 로직 line 1420-1424 동일)
      Order orderInfo = null;
      List<Order> orderList = [SELECT OrderNo__c, SaleNo__c FROM Order WHERE Id = :originalOrderId LIMIT 1];
      if (!orderList.isEmpty()) {
        orderInfo = orderList[0];
      }

      List<PointDebitDTO> pdDtoList = new List<PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : resultLltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId;
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype != null ? llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c : null;
        pcDto.CD_RESON = ecoCancelTj.JournalReason__c;
        pcDto.NO_MBR = (llt.LoyaltyProgramMember != null &&
          llt.LoyaltyProgramMember.Contact != null)
          ? llt.LoyaltyProgramMember.Contact.MemberNo__c
          : null;
        if (orderInfo != null) {
          if (String.isNotBlank(orderInfo.OrderNo__c)) {
            pcDto.NO_SAL = orderInfo.OrderNo__c;
          } else if (String.isNotBlank(orderInfo.SaleNo__c)) {
            pcDto.NO_SAL = orderInfo.SaleNo__c;
          }
        }
        pcDto.PT_USE = llt.Points;
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);
        pdDtoList.add(pcDto);
      }

      return pdDtoList;
    } catch (CustomException ce) {
      Database.rollback(sp);
      throw ce;
    } catch (Exception e) {
      Database.rollback(sp);
      throw e;
    }
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
  /**
   * [Origin Check 2026-05-08] 반품 입금 삭제 시 origin 적립 판매 활성 검증.
   *
   * 배경:
   *   B 반품의 Point Redeem Cancel 삭제 = 사용 복원 (재차감) 시도.
   *   재차감하려면 origin 적립 LL 의 판매 (A판매) 가 활성 상태여야 함.
   *   A 가 이미 삭제됐다면 LL_A 로 재차감 불가 → 다른 적립 LL 끌어쓰거나 가용 부족 에러 → 정합 깨짐.
   *
   * 검증:
   *   sourceTj 의 Cancel Credit LL 들 → 같은 (SubType, ExpiryDate) 의 Purchase/Promotion Accrual LL 식별
   *   → 그 LL 들의 TJ.Order.IsDeleted=true 가 1건이라도 있으면 차단.
   *
   * 안전성:
   *   - LL.IsDeleted=false AND TJ.IsDeleted=false 만 활성으로 인정 (origin 매핑 노이즈 제외).
   *   - origin LL 자체가 없으면 (수동 적립 등) 검증 생략 (종래 동작).
   */
  private static void validateReturnDepositDeleteOrigin(Id sourceTjId, Id memberId) {
    // [SOQL Optimization 2026-05-08] 4 SOQL → 2 SOQL.
    //   기존: cancelCreditLLs(1) + originCandidates(2) + matchedLlts(3) + reversedLlts(4)
    //   수정: 사용 LLT 매칭(matched) 을 semi-join 으로 origin 후보 조회와 통합 → SOQL 수 감소.
    //   효과: deleteAllReturnDeposits loop 내부 호출 시 SOQL 누적 절반.

    // SOQL #1: sourceTj 의 Cancel Credit LL 들
    List<LoyaltyLedger> cancelCreditLLs = [
      SELECT Id, LoyaltyPgmCrcySubtypeId, ExpiryDate, TransactionJournal.OrderId
      FROM LoyaltyLedger
      WHERE TransactionJournalId = :sourceTjId AND EventType = 'Credit' AND IsDeleted = FALSE
      LIMIT 100
    ];
    if (cancelCreditLLs.isEmpty()) {
      return;
    }

    Set<Id> subtypeIds = new Set<Id>();
    Set<Date> expiryDates = new Set<Date>();
    Set<Id> usedOrderIds = new Set<Id>();
    for (LoyaltyLedger c : cancelCreditLLs) {
      subtypeIds.add(c.LoyaltyPgmCrcySubtypeId);
      expiryDates.add(c.ExpiryDate);
      if (c.TransactionJournal != null && c.TransactionJournal.OrderId != null) {
        usedOrderIds.add(c.TransactionJournal.OrderId);
      }
    }

    // SOQL #2: 사용 LLT 와 origin LL 정보 통합 조회 (semi-join 으로 origin 매칭)
    //   사용 LLT 의 CreditLL 이 같은 (SubType, ExpiryDate) 의 Purchase/Promotion Accrual 인 것만 매칭.
    //   결과 LLT 의 CreditLL 정보 (Order.IsDeleted, SaleNo) 까지 한번에 가져옴.
    Set<String> originSubTypeNames = new Set<String>{ JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL };
    Set<String> deletedSaleNoSet = new Set<String>();
    Set<Id> matchedOriginIds = new Set<Id>();
    Map<Id, String> originSaleNoById = new Map<Id, String>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT
        CreditLoyaltyLedgerId,
        CreditLoyaltyLedger.TransactionJournal.OrderId,
        CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        CreditLoyaltyLedger.TransactionJournal.Order.IsDeleted__c
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND ActionType = 'Debit'
        AND DebitLoyaltyLedger.TransactionJournal.OrderId IN :usedOrderIds
        AND CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId IN :subtypeIds
        AND CreditLoyaltyLedger.ExpiryDate IN :expiryDates
        AND CreditLoyaltyLedger.TransactionJournal.JournalSubType.Name IN :originSubTypeNames
      LIMIT 50000
    ]) {
      Id originId = llt.CreditLoyaltyLedgerId;
      matchedOriginIds.add(originId);
      String saleNo = (llt.CreditLoyaltyLedger != null &&
        llt.CreditLoyaltyLedger.TransactionJournal != null &&
        llt.CreditLoyaltyLedger.TransactionJournal.Order != null)
        ? llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c
        : null;
      Boolean orderIsDeleted = (llt.CreditLoyaltyLedger != null &&
      llt.CreditLoyaltyLedger.TransactionJournal != null &&
      llt.CreditLoyaltyLedger.TransactionJournal.Order != null &&
      llt.CreditLoyaltyLedger.TransactionJournal.Order.IsDeleted__c == true);
      if (saleNo != null) {
        originSaleNoById.put(originId, saleNo);
        if (orderIsDeleted) {
          deletedSaleNoSet.add(saleNo);
        }
      }
    }
    if (matchedOriginIds.isEmpty()) {
      return;
    }

    // SOQL #3: origin LL 의 적립 회수 (CreditCancellation LLT) 검증
    //   배경: A판매 입금 삭제 시 Cancel Purchase Accrual 발생 → origin LL_A 의 적립 사라짐.
    //         이 상태에서 사용 복원 (재차감) 시도 → 잔액 마이너스.
    //   AggregateResult 로 origin 별 합산 — 합 > 0 이면 회수된 origin.
    Set<Id> reversedOriginLLIds = new Set<Id>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId originId, SUM(Points) totalPts
      FROM LoyaltyLedgerTraceability
      WHERE
        CreditLoyaltyLedgerId IN :matchedOriginIds
        AND ActionType = 'CreditCancellation'
        AND IsDeleted = FALSE
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND DebitLoyaltyLedger.TransactionJournal.JournalType.Name = :JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
      GROUP BY CreditLoyaltyLedgerId
      LIMIT 50000
    ]) {
      Id originId = (Id) ar.get('originId');
      Decimal sumPts = ar.get('totalPts') == null ? 0 : ((Decimal) ar.get('totalPts')).abs();
      if (sumPts > 0) {
        reversedOriginLLIds.add(originId);
      }
    }
    Set<String> reversedSaleNoSet = new Set<String>();
    for (Id originId : reversedOriginLLIds) {
      String saleNo = originSaleNoById.get(originId);
      if (String.isNotBlank(saleNo)) {
        reversedSaleNoSet.add(saleNo);
      }
    }

    // A prior CreditCancellation on the origin accrual does not by itself make this return deposit delete invalid.
    // The restored credit ledger's actual recoverability is validated later by buildReturnDeleteRecoverablePointAmounts().
    if (deletedSaleNoSet.isEmpty()) {
      return;
    }

    String detail = '반품 입금 삭제 불가 — 원 적립이 이미 회수되었거나 판매가 삭제되었습니다.';
    if (!deletedSaleNoSet.isEmpty()) {
      List<String> sortedSale = new List<String>(deletedSaleNoSet);
      sortedSale.sort();
      detail += ' 삭제된 판매: ' + String.join(sortedSale, ', ');
    }
    if (!reversedSaleNoSet.isEmpty()) {
      List<String> sortedReversed = new List<String>(reversedSaleNoSet);
      sortedReversed.sort();
      detail += ' 적립 회수된 판매: ' + String.join(sortedReversed, ', ');
    }
    throw new CustomException(400, detail);
  }

  /**
   * Return deletion re-applies the point usage that was canceled by the return.
   * Partial recovery is not valid here: every restored credit ledger must be fully available.
   */
  private static List<LoyaltyLedger> filterRestoredPointCreditLedgers(List<LoyaltyLedger> ledgers) {
    List<LoyaltyLedger> result = new List<LoyaltyLedger>();
    if (ledgers == null) {
      return result;
    }

    for (LoyaltyLedger ll : ledgers) {
      if (ll != null && ll.EventType == 'Credit' && ll.Id != null && ll.Points != null && ll.Points > 0 && ll.LoyaltyPgmCrcySubtypeId != null) {
        result.add(ll);
      }
    }
    return result;
  }

  private static void adjustExpiredRestoredPointLedgersAfterReturnDelete(Map<Id, Decimal> debitedPointsByCreditLedgerId, Id memberId) {
    if (debitedPointsByCreditLedgerId == null || debitedPointsByCreditLedgerId.isEmpty() || memberId == null) {
      return;
    }

    Map<Id, Decimal> expiredDebitPointsByCreditLedgerId = new Map<Id, Decimal>();
    Map<String, Decimal> expiredDebitPointsByExpiryKey = new Map<String, Decimal>();
    Map<Id, Decimal> expiredDebitPointsByCurrencyId = new Map<Id, Decimal>();
    Set<Id> transactionJournalIds = new Set<Id>();
    Set<Id> subtypeIds = new Set<Id>();
    Set<Date> expiryDates = new Set<Date>();
    Set<Id> currencyIds = new Set<Id>();
    Decimal expiredDebitTotal = 0;

    for (LoyaltyLedger creditLedger : [
      SELECT Id, Points, TransactionJournalId, LoyaltyProgramCurrencyId, LoyaltyPgmCrcySubtypeId, ExpiryDate
      FROM LoyaltyLedger
      WHERE
        Id IN :debitedPointsByCreditLedgerId.keySet()
        AND LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND ExpiryDate < :Date.today()
      LIMIT 50000
    ]) {
      Decimal requestedPoints = debitedPointsByCreditLedgerId.get(creditLedger.Id);
      if (requestedPoints == null || requestedPoints <= 0 || creditLedger.Points == null || creditLedger.Points <= 0) {
        continue;
      }

      Decimal debitPoints = Math.min(requestedPoints.abs(), creditLedger.Points.abs());
      if (
        debitPoints <= 0 ||
        creditLedger.TransactionJournalId == null ||
        creditLedger.LoyaltyPgmCrcySubtypeId == null ||
        creditLedger.ExpiryDate == null
      ) {
        continue;
      }

      expiredDebitPointsByCreditLedgerId.put(creditLedger.Id, debitPoints);
      String expiryKey = buildPointRecoverabilityKey(
        creditLedger.TransactionJournalId,
        creditLedger.LoyaltyPgmCrcySubtypeId,
        creditLedger.ExpiryDate
      );
      Decimal current = expiredDebitPointsByExpiryKey.containsKey(expiryKey) ? expiredDebitPointsByExpiryKey.get(expiryKey) : 0;
      expiredDebitPointsByExpiryKey.put(expiryKey, current + debitPoints);
      if (creditLedger.LoyaltyProgramCurrencyId != null) {
        Decimal currencyCurrent = expiredDebitPointsByCurrencyId.containsKey(creditLedger.LoyaltyProgramCurrencyId)
          ? expiredDebitPointsByCurrencyId.get(creditLedger.LoyaltyProgramCurrencyId)
          : 0;
        expiredDebitPointsByCurrencyId.put(creditLedger.LoyaltyProgramCurrencyId, currencyCurrent + debitPoints);
        currencyIds.add(creditLedger.LoyaltyProgramCurrencyId);
      }
      transactionJournalIds.add(creditLedger.TransactionJournalId);
      subtypeIds.add(creditLedger.LoyaltyPgmCrcySubtypeId);
      expiryDates.add(creditLedger.ExpiryDate);
      expiredDebitTotal += debitPoints;
    }

    if (expiredDebitTotal <= 0) {
      return;
    }

    List<LoyaltyLedger> expiryLedgersToDelete = new List<LoyaltyLedger>();
    List<LoyaltyLedger> expiryLedgersToInsert = new List<LoyaltyLedger>();
    for (LoyaltyLedger expiryLedger : [
      SELECT Id, Points, TransactionJournalId, LoyaltyProgramMemberId, LoyaltyProgramCurrencyId, LoyaltyPgmCrcySubtypeId, ExpiryDate, ActivityDate
      FROM LoyaltyLedger
      WHERE
        TransactionJournalId IN :transactionJournalIds
        AND LoyaltyProgramMemberId = :memberId
        AND LoyaltyPgmCrcySubtypeId IN :subtypeIds
        AND ExpiryDate IN :expiryDates
        AND EventType = 'Expiry'
        AND IsDeleted = FALSE
      ORDER BY CreatedDate ASC, Id ASC
      LIMIT 50000
    ]) {
      String expiryKey = buildPointRecoverabilityKey(
        expiryLedger.TransactionJournalId,
        expiryLedger.LoyaltyPgmCrcySubtypeId,
        expiryLedger.ExpiryDate
      );
      Decimal remainingDebitPoints = expiredDebitPointsByExpiryKey.get(expiryKey);
      if (remainingDebitPoints == null || remainingDebitPoints <= 0) {
        continue;
      }

      Decimal expiryPoints = expiryLedger.Points == null ? 0 : expiryLedger.Points.abs();
      if (expiryPoints <= 0) {
        continue;
      }

      Decimal consumedPoints = Math.min(remainingDebitPoints, expiryPoints);
      Decimal remainingExpiryPoints = expiryPoints - consumedPoints;
      expiryLedgersToDelete.add(expiryLedger);
      if (remainingExpiryPoints > 0) {
        expiryLedgersToInsert.add(
          new LoyaltyLedger(
            LoyaltyProgramMemberId = expiryLedger.LoyaltyProgramMemberId,
            LoyaltyProgramCurrencyId = expiryLedger.LoyaltyProgramCurrencyId,
            TransactionJournalId = expiryLedger.TransactionJournalId,
            LoyaltyPgmCrcySubtypeId = expiryLedger.LoyaltyPgmCrcySubtypeId,
            Points = remainingExpiryPoints,
            EventType = 'Expiry',
            ActivityDate = expiryLedger.ActivityDate,
            ExpiryDate = expiryLedger.ExpiryDate
          )
        );
      }
      expiredDebitPointsByExpiryKey.put(expiryKey, remainingDebitPoints - consumedPoints);
    }

    if (!expiryLedgersToDelete.isEmpty()) {
      delete expiryLedgersToDelete;
    }
    if (!expiryLedgersToInsert.isEmpty()) {
      insert expiryLedgersToInsert;
    }

    for (LoyaltyMemberCurrency lmc : [
      SELECT Id, LoyaltyProgramCurrencyId, TotalPointsRedeemed
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :memberId AND LoyaltyProgramCurrencyId IN :currencyIds
      FOR UPDATE
    ]) {
      Decimal expiredCurrencyDebitTotal = expiredDebitPointsByCurrencyId.get(lmc.LoyaltyProgramCurrencyId);
      if (expiredCurrencyDebitTotal == null || expiredCurrencyDebitTotal <= 0) {
        continue;
      }
      Decimal redeemed = lmc.TotalPointsRedeemed == null ? 0 : lmc.TotalPointsRedeemed;
      lmc.TotalPointsRedeemed = Math.max(0, redeemed - expiredCurrencyDebitTotal);
      update lmc;
    }
  }

  private static Map<Id, Decimal> buildReturnDeleteRecoverablePointAmounts(List<LoyaltyLedger> restoredLedgers, Id memberId) {
    if (restoredLedgers == null || restoredLedgers.isEmpty()) {
      return new Map<Id, Decimal>();
    }

    Map<Id, Decimal> requiredByLedgerId = new Map<Id, Decimal>();
    Decimal requiredPoints = 0;
    for (LoyaltyLedger ll : restoredLedgers) {
      if (ll == null || ll.Id == null || ll.Points == null || ll.Points <= 0) {
        continue;
      }
      Decimal points = ll.Points.abs();
      requiredByLedgerId.put(ll.Id, points);
      requiredPoints += points;
    }
    if (requiredByLedgerId.isEmpty()) {
      return new Map<Id, Decimal>();
    }

    Set<String> useRefs = new Set<String>();
    Map<Id, Decimal> recoverableAmountByLedgerId = collectReturnDeleteRecoverablePointAmounts(
      requiredByLedgerId,
      memberId,
      0,
      new Set<Id>(),
      useRefs
    );

    Decimal recoverablePoints = 0;
    for (Decimal points : recoverableAmountByLedgerId.values()) {
      recoverablePoints += points;
    }
    if (recoverablePoints + 0.000001 < requiredPoints) {
      String detail = '반품 삭제가 불가합니다. 해당 반품으로 복원된 포인트가 다른 주문/판매에서 사용 중이거나 이미 회수되어, 원래 포인트 사용 상태로 되돌릴 수 없습니다.';
      if (!useRefs.isEmpty()) {
        List<String> sortedRefs = new List<String>(useRefs);
        sortedRefs.sort();
        detail += ' 먼저 다음 사용 건을 취소한 뒤 다시 처리해 주세요: ' + String.join(sortedRefs, ', ');
      }
      throw new CustomException(400, detail);
    }

    if (recoverableAmountByLedgerId.isEmpty()) {
      throw new CustomException(400, '반품 삭제가 불가합니다. 다시 사용 처리할 수 있는 포인트 원장이 존재하지 않습니다.');
    }
    return recoverableAmountByLedgerId;
  }

  private static Map<Id, Decimal> collectReturnDeleteRecoverablePointAmounts(
    Map<Id, Decimal> requiredByLedgerId,
    Id memberId,
    Integer depth,
    Set<Id> visitedLedgerIds,
    Set<String> useRefs
  ) {
    Map<Id, Decimal> resultByLedgerId = new Map<Id, Decimal>();
    if (requiredByLedgerId == null || requiredByLedgerId.isEmpty() || depth > 10) {
      return resultByLedgerId;
    }

    Map<Id, Decimal> queryRequiredByLedgerId = new Map<Id, Decimal>();
    for (Id ledgerId : requiredByLedgerId.keySet()) {
      if (ledgerId != null && !visitedLedgerIds.contains(ledgerId)) {
        queryRequiredByLedgerId.put(ledgerId, requiredByLedgerId.get(ledgerId));
        visitedLedgerIds.add(ledgerId);
      }
    }
    if (queryRequiredByLedgerId.isEmpty()) {
      return resultByLedgerId;
    }

    Map<Id, LoyaltyLedger> creditLedgerById = new Map<Id, LoyaltyLedger>(
      [
        SELECT Id, Points, LoyaltyPgmCrcySubtypeId, ExpiryDate
        FROM LoyaltyLedger
        WHERE Id IN :queryRequiredByLedgerId.keySet() AND LoyaltyProgramMemberId = :memberId AND EventType = 'Credit' AND IsDeleted = FALSE
      ]
    );
    if (creditLedgerById.isEmpty()) {
      return resultByLedgerId;
    }

    Set<String> reducingActionTypes = new Set<String>{
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT,
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION,
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
    };
    Map<Id, Decimal> reductionByLedgerId = new Map<Id, Decimal>();
    Map<Id, Decimal> debitCancellationByLedgerId = new Map<Id, Decimal>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :creditLedgerById.keySet()
        AND IsDeleted = FALSE
        AND ActionType IN :reducingActionTypes
        AND (DebitLoyaltyLedgerId = NULL
        OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
      GROUP BY CreditLoyaltyLedgerId, ActionType
      LIMIT 50000
    ]) {
      Id creditId = (Id) ar.get('creditId');
      String actionType = (String) ar.get('actionType');
      Decimal totalPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs();
      if (actionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION) {
        Decimal current = debitCancellationByLedgerId.containsKey(creditId) ? debitCancellationByLedgerId.get(creditId) : 0;
        debitCancellationByLedgerId.put(creditId, current + totalPoints);
      } else {
        Decimal current = reductionByLedgerId.containsKey(creditId) ? reductionByLedgerId.get(creditId) : 0;
        reductionByLedgerId.put(creditId, current + totalPoints);
      }
    }

    Map<Id, Decimal> remainingRequiredByLedgerId = new Map<Id, Decimal>();
    for (Id ledgerId : creditLedgerById.keySet()) {
      LoyaltyLedger ledger = creditLedgerById.get(ledgerId);
      Decimal requestedPoints = queryRequiredByLedgerId.get(ledgerId) == null ? 0 : queryRequiredByLedgerId.get(ledgerId).abs();
      Decimal ledgerPoints = ledger.Points == null ? 0 : ledger.Points.abs();
      Decimal reducedPoints = reductionByLedgerId.containsKey(ledgerId) ? reductionByLedgerId.get(ledgerId) : 0;
      Decimal canceledDebitPoints = debitCancellationByLedgerId.containsKey(ledgerId) ? debitCancellationByLedgerId.get(ledgerId) : 0;
      Decimal unavailablePoints = Math.max(0, reducedPoints - canceledDebitPoints);
      Decimal availablePoints = Math.max(0, ledgerPoints - unavailablePoints);
      Decimal fromThisLedger = Math.min(requestedPoints, availablePoints);
      if (fromThisLedger > 0) {
        resultByLedgerId.put(ledgerId, fromThisLedger);
      }
      Decimal remaining = requestedPoints - fromThisLedger;
      if (remaining > 0) {
        remainingRequiredByLedgerId.put(ledgerId, remaining);
      }
    }
    if (remainingRequiredByLedgerId.isEmpty()) {
      return resultByLedgerId;
    }

    Map<String, Decimal> requiredByUseKey = new Map<String, Decimal>();
    Set<Id> usedOrderIds = new Set<Id>();
    Set<Id> subtypeIds = new Set<Id>();
    Set<Date> expiryDates = new Set<Date>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT
        CreditLoyaltyLedgerId,
        Points,
        LoyaltyPgmCurrencySubtypeId,
        CreditLoyaltyLedger.ExpiryDate,
        DebitLoyaltyLedger.TransactionJournal.OrderId,
        DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
        DebitLoyaltyLedger.TransactionJournal.DepositNo__c
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :remainingRequiredByLedgerId.keySet()
        AND IsDeleted = FALSE
        AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      LIMIT 50000
    ]) {
      TransactionJournal debitTj = llt.DebitLoyaltyLedger == null ? null : llt.DebitLoyaltyLedger.TransactionJournal;
      Id usedOrderId = debitTj == null ? null : debitTj.OrderId;
      Date expiryDate = llt.CreditLoyaltyLedger == null ? null : llt.CreditLoyaltyLedger.ExpiryDate;
      if (usedOrderId == null || llt.LoyaltyPgmCurrencySubtypeId == null || expiryDate == null) {
        continue;
      }

      Decimal remainingForLedger = remainingRequiredByLedgerId.get(llt.CreditLoyaltyLedgerId);
      if (remainingForLedger == null || remainingForLedger <= 0) {
        continue;
      }
      Decimal requiredPoints = Math.min(remainingForLedger, llt.Points == null ? 0 : llt.Points.abs());
      if (requiredPoints <= 0) {
        continue;
      }

      String refNo = null;
      if (debitTj != null) {
        if (debitTj.Order != null && String.isNotBlank(debitTj.Order.SaleNo__c)) {
          refNo = debitTj.Order.SaleNo__c;
        } else if (debitTj.Order != null && String.isNotBlank(debitTj.Order.OrderNo__c)) {
          refNo = debitTj.Order.OrderNo__c;
        } else if (String.isNotBlank(debitTj.DepositNo__c)) {
          refNo = debitTj.DepositNo__c;
        }
      }
      if (String.isNotBlank(refNo)) {
        useRefs.add(refNo);
      }

      String useKey = buildPointRecoverabilityKey(usedOrderId, llt.LoyaltyPgmCurrencySubtypeId, expiryDate);
      Decimal current = requiredByUseKey.containsKey(useKey) ? requiredByUseKey.get(useKey) : 0;
      requiredByUseKey.put(useKey, current + requiredPoints);
      remainingRequiredByLedgerId.put(llt.CreditLoyaltyLedgerId, remainingForLedger - requiredPoints);
      usedOrderIds.add(usedOrderId);
      subtypeIds.add(llt.LoyaltyPgmCurrencySubtypeId);
      expiryDates.add(expiryDate);
    }

    if (requiredByUseKey.isEmpty() || usedOrderIds.isEmpty()) {
      return resultByLedgerId;
    }

    Map<String, List<LoyaltyLedger>> cancelLedgersByUseKey = new Map<String, List<LoyaltyLedger>>();
    for (LoyaltyLedger cancelLedger : [
      SELECT Id, Points, TransactionJournal.OrderId, LoyaltyPgmCrcySubtypeId, ExpiryDate
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
        AND TransactionJournal.OrderId IN :usedOrderIds
        AND LoyaltyPgmCrcySubtypeId IN :subtypeIds
        AND ExpiryDate IN :expiryDates
      ORDER BY CreatedDate ASC, Id ASC
      LIMIT 50000
    ]) {
      String useKey = buildPointRecoverabilityKey(
        cancelLedger.TransactionJournal.OrderId,
        cancelLedger.LoyaltyPgmCrcySubtypeId,
        cancelLedger.ExpiryDate
      );
      if (!cancelLedgersByUseKey.containsKey(useKey)) {
        cancelLedgersByUseKey.put(useKey, new List<LoyaltyLedger>());
      }
      cancelLedgersByUseKey.get(useKey).add(cancelLedger);
    }

    Map<Id, Decimal> childRequiredByLedgerId = new Map<Id, Decimal>();
    for (String useKey : requiredByUseKey.keySet()) {
      Decimal remaining = requiredByUseKey.get(useKey);
      List<LoyaltyLedger> cancelLedgers = cancelLedgersByUseKey.get(useKey);
      if (remaining == null || remaining <= 0 || cancelLedgers == null || cancelLedgers.isEmpty()) {
        continue;
      }
      for (LoyaltyLedger cancelLedger : cancelLedgers) {
        if (remaining <= 0) {
          break;
        }
        if (visitedLedgerIds.contains(cancelLedger.Id)) {
          continue;
        }
        Decimal ledgerPoints = cancelLedger.Points == null ? 0 : cancelLedger.Points.abs();
        Decimal take = Math.min(remaining, ledgerPoints);
        if (take <= 0) {
          continue;
        }
        childRequiredByLedgerId.put(cancelLedger.Id, take);
        remaining -= take;
      }
    }

    Map<Id, Decimal> childAmounts = collectReturnDeleteRecoverablePointAmounts(
      childRequiredByLedgerId,
      memberId,
      depth + 1,
      visitedLedgerIds,
      useRefs
    );
    for (Id ledgerId : childAmounts.keySet()) {
      Decimal current = resultByLedgerId.containsKey(ledgerId) ? resultByLedgerId.get(ledgerId) : 0;
      resultByLedgerId.put(ledgerId, current + childAmounts.get(ledgerId));
    }

    return resultByLedgerId;
  }

  @TestVisible
  private static void validateRestoredPointLedgersFullyRecoverableV2(List<LoyaltyLedger> restoredLedgers, Id memberId) {
    if (restoredLedgers == null || restoredLedgers.isEmpty()) {
      return;
    }

    Set<Id> restoredLedgerIds = new Set<Id>();
    Decimal requiredPoints = 0;
    for (LoyaltyLedger ll : restoredLedgers) {
      if (ll == null || ll.Id == null) {
        continue;
      }
      restoredLedgerIds.add(ll.Id);
      requiredPoints += ll.Points == null ? 0 : ll.Points.abs();
    }
    if (restoredLedgerIds.isEmpty()) {
      return;
    }

    Set<String> useRefs = new Set<String>();
    Decimal recoverablePoints = calculateRecoverableRestoredPointAmount(restoredLedgerIds, memberId, 0, new Set<Id>(), useRefs);
    if (recoverablePoints + 0.000001 >= requiredPoints) {
      return;
    }

    String detail = '반품 삭제가 불가합니다. 해당 반품으로 복원된 포인트가 다른 주문/판매에서 사용 중이거나 이미 회수되어, 원래 포인트 사용 상태로 되돌릴 수 없습니다.';
    if (!useRefs.isEmpty()) {
      List<String> sortedRefs = new List<String>(useRefs);
      sortedRefs.sort();
      detail += ' 먼저 다음 사용 건을 취소한 뒤 다시 처리해 주세요: ' + String.join(sortedRefs, ', ');
    }
    throw new CustomException(400, detail);
  }

  private static Decimal calculateRecoverableRestoredPointAmount(
    Set<Id> creditLedgerIds,
    Id memberId,
    Integer depth,
    Set<Id> visitedLedgerIds,
    Set<String> useRefs
  ) {
    if (creditLedgerIds == null || creditLedgerIds.isEmpty() || depth > 10) {
      return 0;
    }

    Set<Id> queryLedgerIds = new Set<Id>();
    for (Id ledgerId : creditLedgerIds) {
      if (ledgerId != null && !visitedLedgerIds.contains(ledgerId)) {
        queryLedgerIds.add(ledgerId);
        visitedLedgerIds.add(ledgerId);
      }
    }
    if (queryLedgerIds.isEmpty()) {
      return 0;
    }

    Map<Id, LoyaltyLedger> creditLedgerById = new Map<Id, LoyaltyLedger>(
      [
        SELECT Id, Points, LoyaltyPgmCrcySubtypeId, ExpiryDate
        FROM LoyaltyLedger
        WHERE Id IN :queryLedgerIds AND LoyaltyProgramMemberId = :memberId AND EventType = 'Credit' AND IsDeleted = FALSE
      ]
    );
    if (creditLedgerById.isEmpty()) {
      return 0;
    }

    Set<String> reducingActionTypes = new Set<String>{
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT,
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION,
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
    };
    Map<Id, Decimal> reductionByLedgerId = new Map<Id, Decimal>();
    Map<Id, Decimal> debitCancellationByLedgerId = new Map<Id, Decimal>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :creditLedgerById.keySet()
        AND IsDeleted = FALSE
        AND ActionType IN :reducingActionTypes
        AND (DebitLoyaltyLedgerId = NULL
        OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
      GROUP BY CreditLoyaltyLedgerId, ActionType
      LIMIT 50000
    ]) {
      Id creditId = (Id) ar.get('creditId');
      String actionType = (String) ar.get('actionType');
      Decimal totalPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs();
      if (actionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION) {
        Decimal current = debitCancellationByLedgerId.containsKey(creditId) ? debitCancellationByLedgerId.get(creditId) : 0;
        debitCancellationByLedgerId.put(creditId, current + totalPoints);
      } else {
        Decimal current = reductionByLedgerId.containsKey(creditId) ? reductionByLedgerId.get(creditId) : 0;
        reductionByLedgerId.put(creditId, current + totalPoints);
      }
    }

    Decimal recoverablePoints = 0;
    Map<Id, Decimal> unavailableByLedgerId = new Map<Id, Decimal>();
    for (Id ledgerId : creditLedgerById.keySet()) {
      LoyaltyLedger ledger = creditLedgerById.get(ledgerId);
      Decimal ledgerPoints = ledger.Points == null ? 0 : ledger.Points.abs();
      Decimal reducedPoints = reductionByLedgerId.containsKey(ledgerId) ? reductionByLedgerId.get(ledgerId) : 0;
      Decimal canceledDebitPoints = debitCancellationByLedgerId.containsKey(ledgerId) ? debitCancellationByLedgerId.get(ledgerId) : 0;
      Decimal unavailablePoints = Math.max(0, reducedPoints - canceledDebitPoints);
      Decimal availablePoints = ledgerPoints - unavailablePoints;
      if (availablePoints > 0) {
        recoverablePoints += availablePoints;
      }
      if (unavailablePoints > 0) {
        unavailableByLedgerId.put(ledgerId, unavailablePoints);
      }
    }
    if (unavailableByLedgerId.isEmpty()) {
      return recoverablePoints;
    }

    Map<String, Decimal> requiredByUseKey = new Map<String, Decimal>();
    Set<Id> usedOrderIds = new Set<Id>();
    Set<Id> subtypeIds = new Set<Id>();
    Set<Date> expiryDates = new Set<Date>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT
        CreditLoyaltyLedgerId,
        Points,
        LoyaltyPgmCurrencySubtypeId,
        CreditLoyaltyLedger.ExpiryDate,
        DebitLoyaltyLedger.TransactionJournal.OrderId,
        DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
        DebitLoyaltyLedger.TransactionJournal.DepositNo__c
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :unavailableByLedgerId.keySet()
        AND IsDeleted = FALSE
        AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      LIMIT 50000
    ]) {
      TransactionJournal debitTj = llt.DebitLoyaltyLedger == null ? null : llt.DebitLoyaltyLedger.TransactionJournal;
      Id usedOrderId = debitTj == null ? null : debitTj.OrderId;
      Date expiryDate = llt.CreditLoyaltyLedger == null ? null : llt.CreditLoyaltyLedger.ExpiryDate;
      if (usedOrderId == null || llt.LoyaltyPgmCurrencySubtypeId == null || expiryDate == null) {
        continue;
      }

      Decimal remainingUnavailable = unavailableByLedgerId.get(llt.CreditLoyaltyLedgerId);
      if (remainingUnavailable == null || remainingUnavailable <= 0) {
        continue;
      }
      Decimal requiredPoints = Math.min(remainingUnavailable, llt.Points == null ? 0 : llt.Points.abs());
      if (requiredPoints <= 0) {
        continue;
      }

      String refNo = null;
      if (debitTj != null) {
        if (debitTj.Order != null && String.isNotBlank(debitTj.Order.SaleNo__c)) {
          refNo = debitTj.Order.SaleNo__c;
        } else if (debitTj.Order != null && String.isNotBlank(debitTj.Order.OrderNo__c)) {
          refNo = debitTj.Order.OrderNo__c;
        } else if (String.isNotBlank(debitTj.DepositNo__c)) {
          refNo = debitTj.DepositNo__c;
        }
      }
      if (String.isNotBlank(refNo)) {
        useRefs.add(refNo);
      }

      String useKey = buildPointRecoverabilityKey(usedOrderId, llt.LoyaltyPgmCurrencySubtypeId, expiryDate);
      Decimal current = requiredByUseKey.containsKey(useKey) ? requiredByUseKey.get(useKey) : 0;
      requiredByUseKey.put(useKey, current + requiredPoints);
      unavailableByLedgerId.put(llt.CreditLoyaltyLedgerId, remainingUnavailable - requiredPoints);
      usedOrderIds.add(usedOrderId);
      subtypeIds.add(llt.LoyaltyPgmCurrencySubtypeId);
      expiryDates.add(expiryDate);
    }

    if (requiredByUseKey.isEmpty() || usedOrderIds.isEmpty()) {
      return recoverablePoints;
    }

    Map<String, Set<Id>> cancelLedgerIdsByUseKey = new Map<String, Set<Id>>();
    for (LoyaltyLedger cancelLedger : [
      SELECT Id, TransactionJournal.OrderId, LoyaltyPgmCrcySubtypeId, ExpiryDate
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
        AND TransactionJournal.OrderId IN :usedOrderIds
        AND LoyaltyPgmCrcySubtypeId IN :subtypeIds
        AND ExpiryDate IN :expiryDates
      LIMIT 50000
    ]) {
      String useKey = buildPointRecoverabilityKey(
        cancelLedger.TransactionJournal.OrderId,
        cancelLedger.LoyaltyPgmCrcySubtypeId,
        cancelLedger.ExpiryDate
      );
      if (!cancelLedgerIdsByUseKey.containsKey(useKey)) {
        cancelLedgerIdsByUseKey.put(useKey, new Set<Id>());
      }
      if (visitedLedgerIds.contains(cancelLedger.Id)) {
        continue;
      }
      cancelLedgerIdsByUseKey.get(useKey).add(cancelLedger.Id);
    }

    for (String useKey : requiredByUseKey.keySet()) {
      Set<Id> cancelLedgerIds = cancelLedgerIdsByUseKey.get(useKey);
      if (cancelLedgerIds == null || cancelLedgerIds.isEmpty()) {
        continue;
      }
      Decimal cancelRecoverable = calculateRecoverableRestoredPointAmount(cancelLedgerIds, memberId, depth + 1, visitedLedgerIds, useRefs);
      recoverablePoints += Math.min(requiredByUseKey.get(useKey), cancelRecoverable);
    }

    return recoverablePoints;
  }

  private static String buildPointRecoverabilityKey(Id orderId, Id subtypeId, Date expiryDate) {
    return String.valueOf(orderId) + '|' + String.valueOf(subtypeId) + '|' + String.valueOf(expiryDate);
  }

  @TestVisible
  private static void validateRestoredPointLedgersFullyRecoverable(List<LoyaltyLedger> restoredLedgers, Id memberId) {
    if (restoredLedgers == null || restoredLedgers.isEmpty()) {
      return;
    }

    Set<Id> restoredLedgerIds = new Set<Id>();
    Map<Id, Decimal> restoredPointsByLedgerId = new Map<Id, Decimal>();
    for (LoyaltyLedger ll : restoredLedgers) {
      if (ll == null || ll.Id == null) {
        continue;
      }
      restoredLedgerIds.add(ll.Id);
      restoredPointsByLedgerId.put(ll.Id, ll.Points == null ? 0 : ll.Points.abs());
    }
    if (restoredLedgerIds.isEmpty()) {
      return;
    }

    Set<String> reducingActionTypes = new Set<String>{
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT,
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION,
      LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
    };
    Map<Id, Decimal> reductionByLedgerId = new Map<Id, Decimal>();
    Map<Id, Decimal> debitCancellationByLedgerId = new Map<Id, Decimal>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :restoredLedgerIds
        AND IsDeleted = FALSE
        AND ActionType IN :reducingActionTypes
        AND (DebitLoyaltyLedgerId = NULL
        OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
      GROUP BY CreditLoyaltyLedgerId, ActionType
      LIMIT 50000
    ]) {
      Id creditId = (Id) ar.get('creditId');
      String actionType = (String) ar.get('actionType');
      Decimal totalPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs();
      if (actionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION) {
        Decimal current = debitCancellationByLedgerId.containsKey(creditId) ? debitCancellationByLedgerId.get(creditId) : 0;
        debitCancellationByLedgerId.put(creditId, current + totalPoints);
      } else {
        Decimal current = reductionByLedgerId.containsKey(creditId) ? reductionByLedgerId.get(creditId) : 0;
        reductionByLedgerId.put(creditId, current + totalPoints);
      }
    }

    Set<Id> unavailableLedgerIds = new Set<Id>();
    for (Id ledgerId : restoredLedgerIds) {
      Decimal restoredPoints = restoredPointsByLedgerId.get(ledgerId);
      Decimal reducedPoints = reductionByLedgerId.containsKey(ledgerId) ? reductionByLedgerId.get(ledgerId) : 0;
      Decimal canceledDebitPoints = debitCancellationByLedgerId.containsKey(ledgerId) ? debitCancellationByLedgerId.get(ledgerId) : 0;
      Decimal unavailablePoints = Math.max(0, reducedPoints - canceledDebitPoints);
      Decimal availablePoints = restoredPoints - unavailablePoints;
      if (availablePoints + 0.000001 < restoredPoints) {
        unavailableLedgerIds.add(ledgerId);
      }
    }
    if (unavailableLedgerIds.isEmpty()) {
      return;
    }

    Set<String> useRefs = new Set<String>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT
        DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
        DebitLoyaltyLedger.TransactionJournal.DepositNo__c
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :unavailableLedgerIds
        AND IsDeleted = FALSE
        AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      LIMIT 200
    ]) {
      String refNo = null;
      if (llt.DebitLoyaltyLedger != null && llt.DebitLoyaltyLedger.TransactionJournal != null) {
        TransactionJournal tj = llt.DebitLoyaltyLedger.TransactionJournal;
        if (tj.Order != null && String.isNotBlank(tj.Order.SaleNo__c)) {
          refNo = tj.Order.SaleNo__c;
        } else if (tj.Order != null && String.isNotBlank(tj.Order.OrderNo__c)) {
          refNo = tj.Order.OrderNo__c;
        } else if (String.isNotBlank(tj.DepositNo__c)) {
          refNo = tj.DepositNo__c;
        }
      }
      if (String.isNotBlank(refNo)) {
        useRefs.add(refNo);
      }
    }

    String detail = '반품 삭제가 불가합니다. 해당 반품으로 복원된 포인트가 다른 주문/판매에서 사용 중이거나 이미 회수되어, 원래 포인트 사용 상태로 되돌릴 수 없습니다.';
    if (!useRefs.isEmpty()) {
      List<String> sortedRefs = new List<String>(useRefs);
      sortedRefs.sort();
      detail += ' 먼저 다음 사용 건을 취소한 뒤 다시 처리해 주세요: ' + String.join(sortedRefs, ', ');
    }
    throw new CustomException(400, detail);
  }

  /**
   * [Eco Usage Validation 2026-05-08] 에코포인트 회수 시 사용 차단 검증.
   *
   * 배경:
   *   A판매에서 에코 적립 → B판매에서 사용 → A 통반품 또는 A 전체 삭제 시도
   *   이때 A 의 에코 적립을 회수해야 정합 보장. 그러나 이미 B에서 사용된 양은 회수 불가.
   *
   * 검증:
   *   A판매 에코 적립 LL 들의 활성 사용 LLT 가 1건이라도 있으면 차단.
   *   - ActionType='Debit' (실제 사용)
   *   - DebitTJ.IsDeleted=false (활성)
   *   - notes != RESTORE_NOTE (반품 입금 삭제 재차감 보조 아님)
   *   - notes != ECO_POINT_CANCEL_NOTE (이미 회수 흔적 아님)
   *
   * 메시지: deleteSale / deleteSaleDeposit / createReturn 패턴과 통일 — 모든 사용처 collect/dedupe/정렬.
   *
   * 호출 위치: cancelEcoPointsForFullReturn / _v2 의 회수 시도 직전.
   *   통반품 (insertSaleDepositHistoryByUpdate) 와 판매 전체 삭제 (cancelEcoPointsForSaleDelete) 모두 자동 적용.
   *
   * 안전성: hasActiveEcoCancellation 체크 후 호출 → 이미 회수된 케이스는 영향 없음.
   *         A판매에 에코 적립 자체가 없으면 (originalEcoCreditLedgerIds 빈 셋) 검증 우회.
   */
  private static void validateEcoUsageBeforeCancel(Id originalOrderId) {
    // [v3 net-match 2026-05-15 / CAR_269999800260]
    //   배경: v3 paradigm (PointCancel_PreserveTrace=ON) 에서는 사용 cancel 시 Cancel Credit LL 만
    //         발행되고 원본 Debit LLT 는 보존됨 (CreditCancellation/DebitCancellation LLT 미발행).
    //   기존 동작: 활성 Debit LLT 1건이라도 있으면 차단 → v3 cancel 된 사용을 active 로 오인식.
    //   해결: SAL_252 의 에코 적립 LL 을 ORIGIN_CREDIT_LL 로 가리키는 Point Redeem Cancel LL 의
    //         Points 합 vs. 활성 Debit LLT Points 합 → net 잔량 > 0 일 때만 차단.
    //         CAR_258 의 calculateUnrefundedUsage main loop net-match 와 동일 패턴.
    List<LoyaltyLedger> originalEcoCreditLLs = [
      SELECT Id, LoyaltyProgramMemberId
      FROM LoyaltyLedger
      WHERE
        TransactionJournal.OrderId = :originalOrderId
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT
        AND LoyaltyPgmCrcySubtype.PointTypeCode__c = :ECO_POINT_TYPE_CODE
        AND EventType = 'Credit'
        AND (TransactionJournal.AdditionalNotes__c = NULL
        OR TransactionJournal.AdditionalNotes__c != :ECO_POINT_RESTORE_NOTE)
      LIMIT 200
    ];
    if (originalEcoCreditLLs.isEmpty()) {
      return;
    }
    Set<Id> originalEcoCreditLLIds = new Set<Id>();
    Id memberId = null;
    for (LoyaltyLedger ll : originalEcoCreditLLs) {
      originalEcoCreditLLIds.add(ll.Id);
      memberId = ll.LoyaltyProgramMemberId;
    }

    List<LoyaltyLedgerTraceability> usageLltList = [
      SELECT
        Id,
        Points,
        CreditLoyaltyLedgerId,
        DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
        DebitLoyaltyLedger.TransactionJournal.DepositNo__c
      FROM LoyaltyLedgerTraceability
      WHERE
        CreditLoyaltyLedgerId IN :originalEcoCreditLLIds
        AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE
        AND DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :ECO_POINT_CANCEL_NOTE))
      LIMIT 50000
    ];
    if (usageLltList.isEmpty()) {
      return;
    }

    Map<Id, Decimal> debitSumByOriginLLId = new Map<Id, Decimal>();
    for (LoyaltyLedgerTraceability llt : usageLltList) {
      Id originId = llt.CreditLoyaltyLedgerId;
      Decimal pts = llt.Points == null ? 0 : llt.Points;
      debitSumByOriginLLId.put(originId, (debitSumByOriginLLId.containsKey(originId) ? debitSumByOriginLLId.get(originId) : 0) + pts);
    }

    Map<Id, Decimal> cancelSumByOriginLLId = new Map<Id, Decimal>();
    for (LoyaltyLedger cc : [
      SELECT Id, Points, AdditionalNotes
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
        AND EventType = 'Credit'
        AND Points > 0
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND AdditionalNotes LIKE '%ORIGIN_CREDIT_LL=%'
      LIMIT 50000
    ]) {
      Id originId = extractOriginCreditLedgerIdFromNotes(cc.AdditionalNotes);
      if (originId == null || !originalEcoCreditLLIds.contains(originId))
        continue;
      Decimal pts = cc.Points == null ? 0 : cc.Points;
      cancelSumByOriginLLId.put(originId, (cancelSumByOriginLLId.containsKey(originId) ? cancelSumByOriginLLId.get(originId) : 0) + pts);
    }

    Set<String> saleNumberSet = new Set<String>();
    Set<String> orderNumberSet = new Set<String>();
    Set<String> depositNumberSet = new Set<String>();
    for (LoyaltyLedgerTraceability llt : usageLltList) {
      Id originId = llt.CreditLoyaltyLedgerId;
      Decimal debit = debitSumByOriginLLId.containsKey(originId) ? debitSumByOriginLLId.get(originId) : 0;
      Decimal cancel = cancelSumByOriginLLId.containsKey(originId) ? cancelSumByOriginLLId.get(originId) : 0;
      if (debit - cancel <= 0.000001) {
        continue;
      }
      if (llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c != null) {
        saleNumberSet.add(llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c);
      } else if (llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c != null) {
        orderNumberSet.add(llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c);
      }
      if (llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c != null) {
        depositNumberSet.add(llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c);
      }
    }
    if (saleNumberSet.isEmpty() && orderNumberSet.isEmpty() && depositNumberSet.isEmpty()) {
      return;
    }
    List<String> saleSorted = new List<String>(saleNumberSet);
    saleSorted.sort();
    List<String> orderSorted = new List<String>(orderNumberSet);
    orderSorted.sort();
    List<String> depositSorted = new List<String>(depositNumberSet);
    depositSorted.sort();
    String saleNumberList = String.join(saleSorted, ', ');
    String orderNumberList = String.join(orderSorted, ', ');
    String depositNumberList = String.join(depositSorted, ', ');

    String detail = '에코포인트 회수 불가 — 적립된 에코포인트가 다른 주문/판매에서 이미 사용되었습니다.';
    if (String.isNotBlank(saleNumberList)) {
      detail += ' 판매번호: ' + saleNumberList;
    }
    if (String.isNotBlank(orderNumberList)) {
      detail += (String.isNotBlank(saleNumberList) ? ' / ' : ' ') + '주문번호: ' + orderNumberList;
    }
    if (String.isNotBlank(depositNumberList)) {
      detail += ' / 입금번호: ' + depositNumberList;
    }
    throw new CustomException(400, detail);
  }

  /**
   * [v3 net-match helper 2026-05-15] AdditionalNotes 에서 ORIGIN_CREDIT_LL=<id>; 토큰 추출.
   *   GdSaleServiceImpl 의 extractOriginCreditLedgerId 와 동일 패턴.
   */
  private static Id extractOriginCreditLedgerIdFromNotes(String notes) {
    if (String.isBlank(notes))
      return null;
    String token = 'ORIGIN_CREDIT_LL=';
    Integer idx = notes.indexOf(token);
    if (idx < 0)
      return null;
    String tail = notes.substring(idx + token.length());
    Integer semiIdx = tail.indexOf(';');
    String idStr = semiIdx >= 0 ? tail.substring(0, semiIdx) : tail;
    idStr = idStr.trim();
    if (String.isBlank(idStr))
      return null;
    try {
      return (Id) idStr;
    } catch (Exception e) {
      return null;
    }
  }

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
    // [Eco Cancel IsDeleted Fix 2026-05-05] 입금 삭제로 무효화된 Debit TJ 의 LLT 도 제외.
    //   (cancelEcoPointsForFullReturn_v2 의 잔여 한도 SOQL 과 동일 정책)
    Map<Id, Integer> usedPointByCreditLedgerId = new Map<Id, Integer>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT CreditLoyaltyLedgerId, Points, ActionType
      FROM LoyaltyLedgerTraceability
      WHERE
        CreditLoyaltyLedgerId IN :creditLedgerIdSet
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
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