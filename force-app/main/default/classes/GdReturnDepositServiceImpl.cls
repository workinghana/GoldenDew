public with sharing class GdReturnDepositServiceImpl implements GdReturnDepositService {
  private static GdVoucherService voucherService;
  private static GdPointService pointService;

  // 테스트 클래스 용도
  @TestVisible
  private static void setVoucherService(GdVoucherService mock) {
    voucherService = mock;
  }

  private static GdVoucherService getVoucherService() {
    if (voucherService == null)
      voucherService = new GdVoucherServiceImpl();
    return voucherService;
  }

  // 테스트 클래스 용도
  @TestVisible
  private static void setPointService(GdPointService mock) {
    pointService = mock;
  }

  private static GdPointService getPointService() {
    if (pointService == null)
      pointService = new GdPointServiceImpl();
    return pointService;
  }

  private static final String JOURNAL_TYPE_NAME_DEPOSIT = 'Deposit'; // 입금/결제
  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual'; // 포인트/쿠폰 지급
  private static final String JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL = 'Accrual Reversal'; // 포인트/쿠폰 지급 취소
  private static final String JOURNAL_TYPE_NAME_REDEMPTION = 'Redemption'; // 포인트/쿠폰 사용
  private static final String JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL = 'Redemption Reversal'; // 포인트/쿠폰 사용 취소
  private static final String JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL = 'Deposit Reversal'; // 입금/결제 취소

  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT = 'Order Deposit'; // 주문 입금
  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL = 'Order Deposit Reversal'; // 주문 입금 취소
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT = 'Sale Deposit'; // 판매 입금
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL = 'Sale Deposit Reversal'; // 판매 입금 취소
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_DEBIT = 'Point Debit'; // 포인트 사용
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel'; // 포인트 사용 취소
  private static final String JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL = 'Purchase Accrual'; // 구매 시 포인트 적립
  private static final String JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual'; // 구매 시 포인트 적립 취소
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM = 'Coupon Redeem'; // 쿠폰 사용
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL = 'Coupon Redeem Cancel'; // 쿠폰 사용 취소

  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';

  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT = 'Debit'; // 포인트 사용
  // private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION = 'DebitCancellation'; // 포인트 사용 취소

  /**
   * 반품 입금 이력 생성
   */
  public ApiResult insertSaleDepositHistoryByUpdate(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Object> transactionJournalList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);

      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // 주문 번호
      String originalOrderId = ValidationUtil.stringValidation(reqData.get('originalOrderId'), 'originalOrderId', true); // 원판매 Id
      String insertId = ValidationUtil.stringValidationEx(reqData.get('InsertId__c'), 'InsertId__c', false, true); // 등록자

      List<Order> oList = [SELECT Id, ActualPaymentAmount__c, InsertId__c FROM Order WHERE Id = :orderId LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, '해당 원주문이 없습니다. ' + originalOrderId);
      }

      // 프로모션 번호 체크
      List<TransactionJournal> tjPromotionNoList = [
        SELECT Id, Promotion.PromotionNo__c
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

      List<GdSaleApiController.PointDebitDTO> debitPointList = new List<GdSaleApiController.PointDebitDTO>();

      List<TransactionJournal> tjList = new List<TransactionJournal>();

      List<TransactionJournal> depositTransactionList = new List<TransactionJournal>();
      List<TransactionJournal> cancelDepositTransactionList = new List<TransactionJournal>();

      for (Object v : transactionJournalList) {
        Map<String, Object> transactionJournal = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);

        String depositNo = ValidationUtil.stringValidation(transactionJournal.get('DepositNo__c'), 'DepositNo__c', true); // 입금 번호
        String deposiSeqNo = ValidationUtil.stringValidation(transactionJournal.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true); // 입금 일련 번호
        Date activityDate = ValidationUtil.dateValidation(transactionJournal.get('ActivityDate'), 'ActivityDate', true); // 입금 일자
        String paymentMethod = ValidationUtil.stringValidation(transactionJournal.get('PaymentMethod'), 'PaymentMethod', true); // 결제 구분 코드
        String depositType = ValidationUtil.stringValidation(transactionJournal.get('DepositType__c'), 'DepositType__c', true); // 입금 구분 코드
        Decimal transactionAmount = ValidationUtil.decimalValidation(transactionJournal.get('TransactionAmount'), 'TransactionAmount', true); // 입금 금액
        String couponNo = ValidationUtil.stringValidationEx(transactionJournal.get('CouponNo'), 'CouponNo', false, true); // 쿠폰 번호

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

        if (String.isNotBlank(couponNo)) {
          tj.VoucherCode = couponNo;
          tj.Status = 'Processed';
          if ('03'.equals(depositType)) {
            // 쿠폰 사용 취소
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true);
            getVoucherService().redeemCancelVoucher(tj);
          } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            // 쿠폰 사용
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
            getVoucherService().redeemVoucherV2(tj);
          }
          continue;
        }

        if ('81'.equals(paymentMethod)) {
          // 포인트 사용 취소 (03 = 환불)
          if ('03'.equals(depositType)) {
            Map<String, Object> cancelPointResult = getPointService().cancelPointRedemption(tj);
            data.put('CancelPointList', cancelPointResult);
          }
          // 포인트 사용 (01 = 선수금 | 02 = 잔금)
          else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            debitPointList = getPointService().debitPoint(tj);
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

      List<Database.SaveResult> resultList = Database.insert(tjList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      // 구매 시 포인트 적립 로직
      if (!depositTransactionList.isEmpty()) {
        List<PointCreditDTO> creditPointList = getPointService().creditPointsOnPurchase(depositTransactionList);
        for (PointCreditDTO pcDto : creditPointList) {
          pcDto.AM_SAL = oList[0].ActualPaymentAmount__c; // 판매 금액
          pcDto.ID_INSERT = oList[0].InsertId__c; // 등록자
          if (!tjPromotionNoList.isEmpty()) {
            pcDto.NO_PROM_MBR = tjPromotionNoList[0].Promotion.PromotionNo__c; // 프로모션 번호
          }
          pcDto.NO_GRADE_ADVAN = lpmList[0].Contact.Grade__c; // 승급번호
        }
        data.put('CreditPointList', creditPointList);
      }
      // 구매 시 포인트 적립 취소 로직
      if (!cancelDepositTransactionList.isEmpty()) {
        List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedList = getPointService()
          .cancelPointsCreditedOnPurchase(cancelDepositTransactionList);
        data.put('CancelPointsCreditedList', cancelPointsCreditedList);
      }

      return ApiResult.ok(200, '반품 입금 이력 생성 완료.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

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
          SaleId__c,
          DepositNo__c,
          IsDeleted__c,
          DeleteDateTime__c,
          VoucherCode,
          Order.OrderNo__c,
          Order.SaleNo__c
        FROM TransactionJournal
        WHERE SaleId__c = :orderId AND IsDeleted__c = FALSE
        LIMIT 200
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 반품의 입금 이력이 존재하지 않습니다. ' + orderId);
      }

      Id couponRedeemCancelJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true); // 쿠폰 사용 취소
      Id pointRedeemCancelJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, true); // 포인트 사용 취소
      Id cancelPurchaseAccrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL, true); // 구매 시 포인트 적립 취소

      List<TransactionJournal> creditPointsOnPurchaseList = new List<TransactionJournal>();
      List<PointDebitDTO> debitPointResult = new List<PointDebitDTO>();
      List<PointCreditDTO> creditPointResult = new List<PointCreditDTO>();
      for (TransactionJournal tj : tjList) {
        TransactionJournal newTj = tj.clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
        if (tj.DepositNo__c != null) {
          newTj.DepositNo__c = 'del_' + tj.DepositNo__c;
        } else {
          newTj.DepositNo__c = 'del_' + tj.Id;
        }
        newTj.JournalDate = Datetime.now();
        newTj.ActivityDate = Datetime.now();
        newTj.DepositType__c = null;
        newTj.RelatedJournalId = tj.Id; // 관련 거래

        if (
          tj.JournalSubTypeId ==
          pointRedeemCancelJstId || // 포인트 사용 취소
          tj.JournalSubTypeId == couponRedeemCancelJstId || // 쿠폰 사용 취소
          tj.JournalSubTypeId == cancelPurchaseAccrualJstId // 구매 포인트 적립 취소
        ) {
          if (tj.JournalSubTypeId == pointRedeemCancelJstId) {
            newTj.AdditionalNotes__c = '반품 전체 삭제로 인한 "포인트 사용" 내역 복구';

            // 포인트 사용 취소를 취소 = 포인트 사용
            System.debug('포인트 사용 취소를 취소 = 포인트 사용 진입 !');

            // 원 거래 이력에서 사용 된 포인트 거래 이력(LoyaltyLedger) 조회
            List<LoyaltyLedger> llList = [
              SELECT Id, LoyaltyPgmCrcySubtypeId, Points, LoyaltyPgmCrcySubtype.Name, AdditionalNotes
              FROM LoyaltyLedger
              WHERE TransactionJournalId = :tj.Id
              LIMIT 100
            ];

            debitPointResult = getPointService().debitSpecificPoints(newTj, llList);
            data.put('포인트 사용 내역 복구', debitPointResult);
          } else if (tj.JournalSubTypeId == couponRedeemCancelJstId) {
            newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true); // 쿠폰 사용
            newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true); // 쿠폰 사용
            newTj.AdditionalNotes__c = '반품 전체 삭제로 인한 "쿠폰 사용" 내역 복구';
            newTj.Status = 'Processed';

            // 쿠폰 사용 취소를 취소 = 쿠폰 사용
            System.debug('쿠폰 사용 취소를 취소 = 쿠폰 사용 진입 !');
            ApiResult voucherResult = getVoucherService().redeemVoucherV2(newTj);
          } else {
            newTj.AdditionalNotes__c = '반품 전체 삭제로 인한 "구매 시 포인트 적립" 내역 복구';

            // 구매 시 포인트 적립 취소를 취소 = 구매 시 포인트 적립
            System.debug('구매 시 포인트 적립 취소를 취소 = 구매 시 포인트 적립 진입 !');
            List<LoyaltyLedgerTraceability> lltList = [
              SELECT CreditLoyaltyLedger.ExpiryDate, LoyaltyPgmCurrencySubtype.Name, Points, DebitLoyaltyLedger.AdditionalNotes
              FROM LoyaltyLedgerTraceability
              WHERE DebitLoyaltyLedger.TransactionJournal.Id = :tj.Id
              LIMIT 200
            ];

            System.debug('newTj.DepositNo__c : ' + newTj.DepositNo__c);
            creditPointResult = getPointService().creditSepcificPoints(newTj, lltList);
            data.put('구매 시 포인트 적립 내역 복구', creditPointResult);
          }
        }

        tj.IsDeleted__c = true;
        tj.DeleteDateTime__c = Datetime.now();
      }
      update tjList;

      return ApiResult.ok(200, '반품 입금 전체 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 개발 중
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
          insertId__c,
          Order.ActualPaymentAmount__c,
          Promotion.PromotionNo__c
        FROM TransactionJournal
        WHERE DepositNo__c = :depositNo AND IsDeleted__c = FALSE
        LIMIT 1
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 입금 이력이 존재하지 않습니다. ' + depositNo);
      }

      Id couponRedeemCancelJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true); // 쿠폰 사용 취소
      Id pointRedeemCancelJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, true); // 포인트 사용 취소
      Id saleDepositReversalJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true); // 판매 입금 취소

      List<TransactionJournal> creditPointsOnPurchaseList = new List<TransactionJournal>();
      List<PointDebitDTO> debitPointResult = new List<PointDebitDTO>();
      List<PointCreditDTO> creditPointResult = new List<PointCreditDTO>();

      TransactionJournal newTj = tjList[0].clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)

      if (tjList[0].DepositNo__c != null) {
        newTj.DepositNo__c = 'del_' + tjList[0].DepositNo__c;
      } else {
        newTj.DepositNo__c = 'del_' + tjList[0].Id;
      }

      newTj.JournalDate = Datetime.now();
      newTj.ActivityDate = Datetime.now();
      newTj.DepositType__c = null;
      newTj.RelatedJournalId = tjList[0].Id; // 관련 거래

      if (
        tjList[0].JournalSubTypeId ==
        pointRedeemCancelJstId || // 포인트 사용 취소
        tjList[0].JournalSubTypeId == couponRedeemCancelJstId || // 쿠폰 사용 취소
        tjList[0].JournalSubTypeId == saleDepositReversalJstId // 판매 입금 취소
      ) {
        if (tjList[0].JournalSubTypeId == pointRedeemCancelJstId) {
          // "포인트 사용" 내역 복구 진입

          newTj.AdditionalNotes__c = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';

          // 포인트 사용 취소를 취소 = 포인트 사용

          // 원 거래 이력에서 사용 된 포인트 거래 이력(LoyaltyLedger) 조회
          List<LoyaltyLedger> llList = [
            SELECT Id, LoyaltyPgmCrcySubtypeId, Points, LoyaltyPgmCrcySubtype.Name, AdditionalNotes
            FROM LoyaltyLedger
            WHERE TransactionJournalId = :tjList[0].Id
            LIMIT 100
          ];

          debitPointResult = getPointService().debitSpecificPoints(newTj, llList);
          data.put('포인트 사용 내역 복구', debitPointResult);
        } else if (tjList[0].JournalSubTypeId == couponRedeemCancelJstId) {
          // "쿠폰 사용" 내역 복구 진입

          newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true); // 쿠폰 사용
          newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true); // 쿠폰 사용
          newTj.AdditionalNotes__c = '반품 입금 삭제로 인한 "쿠폰 사용" 내역 복구';
          newTj.Status = 'Processed';

          // 쿠폰 사용 취소를 취소 = 쿠폰 사용
          ApiResult voucherResult = getVoucherService().redeemVoucherV2(newTj);
          data.put('쿠폰 사용 내역 복구', voucherResult.data.get('voucher'));
        } else {
          // "판매 입금" 내역 복구 진입

          // 회원 등급 조회
          List<LoyaltyMemberTier> lmtList = [SELECT Id, LastModifiedDate FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :tjList[0].MemberId LIMIT 1];
          if (lmtList.isEmpty()) {
            throw new CustomException(400, '해당 회원의 등급이 존재하지 않습니다. ' + tjList[0].MemberId);
          }

          Date orderDate = tjList[0].Order.EndDate; // 판매 일자
          Date modifiedDate = lmtList[0].LastModifiedDate.date(); // 회원 등급 수정 일자

          List<PointCreditDTO> creditPointsOnPurchaseResult = new List<PointCreditDTO>();

          String grade;
          if (orderDate < modifiedDate) {
            // 이전 등급으로 다시 적립

            // 이전 등급 조회
            List<LoyaltyProgramMember> lpmList = [
              SELECT Id, Contact.PreviousGrade__c, Contact.Grade__c
              FROM LoyaltyProgramMember
              WHERE Contact.PreviousGrade__c != NULL AND id = :tjList[0].MemberId
              LIMIT 1
            ];
            if (lpmList.isEmpty()) {
              throw new CustomException(400, '회원의 이전 등급이 존재하지 않습니다. ' + tjList[0].MemberId);
            }
            grade = lpmList[0].Contact.Grade__c;

            List<String> grades = new List<String>{ '01', '02', '03', '04' };

            if (grades.contains(lpmList[0].Contact.PreviousGrade__c)) {
              Map<String, Object> reqData = new Map<String, Object>();
              reqData.put('Grade__c', lpmList[0].Contact.PreviousGrade__c);
              reqData.put('TransactionJournal', tjList[0]);
              reqData.put('AdditionalNotes__c', '반품 입금 삭제로 인한 "구매 시 포인트 적립" 내역 복구');

              creditPointsOnPurchaseResult = getPointService().creditPointsOnPurchaseByGrade(reqData);
            }
          } else {
            // 현재 등급으로 다시 적립

            creditPointsOnPurchaseResult = getPointService().creditPointsOnPurchase(tjList);
          }

          for (PointCreditDTO pcDto : creditPointsOnPurchaseResult) {
            pcDto.AM_SAL = tjList[0].Order.ActualPaymentAmount__c; // 판매 금액
            pcDto.ID_INSERT = tjList[0].insertId__c; // 등록자
            pcDto.NO_PROM_MBR = tjList[0].Promotion.PromotionNo__c; // 프로모션 번호
            pcDto.NO_GRADE_ADVAN = grade; // 승급번호
          }
          data.put('포인트 지급 내역 복구', creditPointsOnPurchaseResult);
        }

        tjList[0].IsDeleted__c = true;
        tjList[0].DeleteDateTime__c = Datetime.now();
      }
      update tjList[0];

      return ApiResult.ok(200, '반품 입금 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}