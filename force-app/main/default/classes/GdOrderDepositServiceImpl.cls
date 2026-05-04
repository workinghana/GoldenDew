/**
 * 주문 입금 관련 로직 처리하는 서비스 구현 클래스
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 * @see GdOrderDepositService
 */
public with sharing class GdOrderDepositServiceImpl implements GdOrderDepositService {
  private static GdVoucherService voucherService;
  private static GdPointService pointService;

  // 테스트 클래스 용도
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

  // 테스트 클래스 용도
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
   * ! 사용 x
   * 주문 입금 조회
   */
  // public ApiResult getOrderDepositList(String orderNo) {
  //   try {
  //     List<Order> oList = [SELECT Id FROM Order WHERE OrderNo__c = :orderNo LIMIT 1];
  //     if (oList.isEmpty()) {
  //       throw new CustomException(400, '해당 주문건이 없습니다. ' + orderNo);
  //     }

  //     List<TransactionJournal> tjList = [
  //       SELECT Id, PaymentMethod, DepositType__c, TransactionAmount, OrderId__c, VoucherCode
  //       FROM TransactionJournal
  //       WHERE OrderId = :oList[0].Id
  //       LIMIT 100
  //     ];

  //     if (tjList.isEmpty()) {
  //       throw new CustomException(400, '해당 주문건의 입금 내역이 없습니다. ' + orderNo);
  //     }

  //     List<GdOrderDepositApiController.DepositResponseDTO> depositList = new List<GdOrderDepositApiController.DepositResponseDTO>();
  //     List<String> voucherCodeList = new List<String>();
  //     for (TransactionJournal tj : tjList) {
  //       GdOrderDepositApiController.DepositResponseDTO res = new GdOrderDepositApiController.DepositResponseDTO();
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

  //     return ApiResult.ok(200, '주문 입금 조회 성공', data);
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }

  /**
   * 주문 입금 이력 생성
   * TransactionJournal insert
   */
  public ApiResult createOrderDepositHistory(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Object> depositList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // 주문 번호
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false); // 프로모션 번호

      String type = ValidationUtil.stringValidation(reqData.get('Type'), 'Type', false); // 주문 구분 코드
      String storeTypeFour = ValidationUtil.stringValidation(reqData.get('storeTypeFour'), 'storeTypeFour', false); // 매장구분4
      // 26.04.09 GD 계정 storeType 추가
      String storeType = ValidationUtil.stringValidation(reqData.get('storeType'), 'storeType', false); // 매장 구분 코드
      Boolean isGoldenBar = ValidationUtil.booleanValidation(reqData.get('isGoldenBar'), 'isGoldenBar', false); // 골드바 상품 구매 여부

      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액

      Integer usedCouponCount = 0; // 쿠폰 사용 횟수

      System.debug('storeType : ' + storeType);
      System.debug('promotionNo : ' + promotionNo);
      if (('08'.equals(storeType) || '09'.equals(storeType) || '11'.equals(storeType)) && String.isBlank(promotionNo)) {
        throw new CustomException(400, '해당 매장 구분은 프로모션 번호가 필수입니다. storeType=' + storeType);
      }

      Id promotionId;
      if (!String.isEmpty(promotionNo)) {
        // if (promotionNo != null) {
        List<Promotion> promotionList = [
          SELECT Id, IsActive, StartDate, EndDate
          FROM Promotion
          WHERE PromotionNo__c = :promotionNo
          LIMIT 1
        ];
        if (promotionList.isEmpty()) {
          throw new CustomException(400, '해당 프로모션이 없습니다. ' + promotionNo);
        }
        if (promotionList[0].IsActive == false) {
          throw new CustomException(400, '해당 프로모션은 비활성화 상태입니다. ' + promotionNo);
        }
        // [Promotion Date Validation 2026-04-28] 주문 등록일(= 오늘) 이 프로모션 적용 기간(StartDate ~ EndDate) 내인지 검증
        //   - 주문은 별도 주문 일자를 받지 않으므로 등록 시점 Date.today() 를 기준으로 함.
        //   - 범위 외이면 시작/종료일자를 함께 알리는 에러 메시지 반환. (판매 등록과 동일 패턴)
        Promotion p = promotionList[0];
        Date orderDate = Date.today();
        if (p.StartDate != null && orderDate < p.StartDate) {
          throw new CustomException(
            400,
            '주문 일자가 프로모션 적용 기간 이전입니다. (프로모션: ' + promotionNo +
            ', 시작일: ' + String.valueOf(p.StartDate) + ', 종료일: ' + String.valueOf(p.EndDate) + ')'
          );
        }
        if (p.EndDate != null && orderDate > p.EndDate) {
          throw new CustomException(
            400,
            '주문 일자가 프로모션 적용 기간 이후입니다. (프로모션: ' + promotionNo +
            ', 시작일: ' + String.valueOf(p.StartDate) + ', 종료일: ' + String.valueOf(p.EndDate) + ')'
          );
        }
        promotionId = p.Id;
        // }
      }

      Boolean isExclude = true; // 포인트 적립 제외 여부
      Decimal earnableAmount = 0; // 적립 가능 품목 금액 합계

      List<Object> oiList = (List<Object>) reqData.get('oiList');
      for (Object v : oiList) {
        OrderItem oi = (OrderItem) v;

        if (oi.IsExclude__c == false) {
          isExclude = false; // 하나라도 false면 계속 false 유지
          System.debug('해당 상품은 포인트 적립 대상입니다.');
          earnableAmount += oi.NetSalesUnitPrice__c != null ? oi.NetSalesUnitPrice__c : 0;
        } else {
          System.debug('해당 상품은 포인트 적립 제외 대상입니다.');
        }
      }

      // 회원 체크
      List<Contact> cList = [SELECT Id FROM Contact WHERE MemberNo__c = :memberNo LIMIT 1];
      if (cList.isEmpty()) {
        throw new CustomException(400, '없는 회원입니다. ' + memberNo);
      }

      // 로열티 프로그램 멤버 체크
      List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :cList[0].Id LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '로열티 멤버가 아닙니다. ' + memberNo);
      }

      // 저널 유형 체크
      List<JournalType> jtList = [SELECT Id FROM journalType WHERE Name = :JOURNAL_TYPE_NAME_DEPOSIT LIMIT 1];
      if (jtList.isEmpty()) {
        throw new CustomException(400, '저널 타입이 없습니다. ' + JOURNAL_TYPE_NAME_DEPOSIT);
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstList = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT AND JournalTypeId = :jtList[0].Id
        LIMIT 1
      ];
      if (jstList.isEmpty()) {
        throw new CustomException(400, '저널 하위 타입이 없습니다. ' + JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT);
      }

      List<GdSaleApiController.PointDebitDTO> debitPointList = new List<GdSaleApiController.PointDebitDTO>();

      Decimal totalPointsToUse = 0;
      Decimal totalTransactionAmount = 0;
      List<TransactionJournal> tjList = new List<TransactionJournal>();
      for (Object v : depositList) {
        Map<String, Object> deposit = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);

        String depositNo = ValidationUtil.stringValidation(deposit.get('DepositNo__c'), 'DepositNo__c', true); // 입금 번호
        String deposiSeqNo = ValidationUtil.stringValidation(deposit.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true); // 입금 일련 번호
        Date activityDate = ValidationUtil.dateValidation(deposit.get('ActivityDate'), 'ActivityDate', true); // 입금 일자
        String paymentMethod = ValidationUtil.stringValidation(deposit.get('PaymentMethod'), 'PaymentMethod', true); // 결제 구분 코드
        String depositType = ValidationUtil.stringValidation(deposit.get('DepositType__c'), 'DepositType__c', true); // 입금 구분 코드
        Decimal transactionAmount = ValidationUtil.decimalValidation(deposit.get('TransactionAmount'), 'TransactionAmount', true); // 입금 금액
        String couponNo = ValidationUtil.stringValidationEx(deposit.get('CouponNo'), 'CouponNo', false, true); // 쿠폰 번호

        // 고재성
        if(depositType == '03' || depositType == '05') {
          totalTransactionAmount -= transactionAmount;
        } else {
          totalTransactionAmount += transactionAmount;
        }

        TransactionJournal tj = new TransactionJournal();
        tj.DepositNo__c = depositNo + '-' + deposiSeqNo;
        tj.DeposiSeqNo__c = deposiSeqNo;
        tj.JournalDate = activityDate;
        tj.ActivityDate = Datetime.now();
        tj.PaymentMethod = paymentMethod;
        tj.LoyaltyProgramId = lpmList[0].ProgramId;
        tj.DepositType__c = depositType;
        tj.TransactionAmount = transactionAmount;
        tj.MemberId = lpmList[0].Id;
        tj.OrderId = orderId;
        tj.OrderId__c = orderId;

        if (promotionNo != null) {
          tj.PromotionId = promotionId;
        }

        // 쿠폰 사용 일 경우
        if (String.isNotBlank(couponNo)) {
          // usedCouponCount++;
          // if (usedCouponCount > 1) {
          //   throw new CustomException(400, '주문 1건 당 쿠폰 1매 만 사용 가능합니다.');
          // }

          // '01' => 백화점 | '20' => 예술의 전당점
          // if ('01'.equals(storeTypeFour) || '20'.equals(storeTypeFour)) {
          //   if (isGoldenBar) {
          //     // throw new CustomException(400, '주문 1건 당 쿠폰 1매 만 사용 가능합니다.');
          //   }
          // }

          // '15' => 면세
          // if ('15'.equals(storeTypeFour)) {
          //   throw new CustomException(400, '면세점은 쿠폰 사용이 불가합니다.');
          // }

          tj.VoucherCode = couponNo;
          tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
          tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
          tj.Status = 'Processed';
          getVoucherService().redeemVoucherV2(tj);
          continue;
        }

        // 포인트 사용 일 경우
        if ('81'.equals(paymentMethod)) {
          // '05' => 아울렛 | '15' => 면세
          // if (('05'.equals(storeTypeFour) && !'03'.equals(type))) {
          //   throw new CustomException(400, '아울렛은 포인트 사용이 불가합니다. (수선 주문은 가능)');
          // }
          // if ('15'.equals(storeTypeFour)) {
          //   throw new CustomException(400, '면세점은 포인트 사용이 불가합니다.');
          // }
          // if ('01'.equals(storeTypeFour) || '20'.equals(storeTypeFour)) {
          //   if (isGoldenBar) {
          //     throw new CustomException(400, '골드바 구매 시 포인트 사용이 불가합니다.');
          //   }
          // }

          // 26.04.09 GD 수정 포인트 적립 매장 구분 코드 로직 수정
          if ((('20'.equals(storeType) || '25'.equals(storeType)) && !'03'.equals(type))) {
            throw new CustomException(400, '아울렛은 포인트 사용이 불가합니다. (수선 주문은 가능)');
          } 
          if ('33'.equals(storeType)) {
            throw new CustomException(400, '면세점은 포인트 사용이 불가합니다.');
          }
          if ('08'.equals(storeType) || '09'.equals(storeType) || '11'.equals(storeType)) {
            if (isGoldenBar) {
              throw new CustomException(400, '골드바 구매 시 포인트 사용이 불가합니다.');
            }
          }

          if (isExclude) {
            // 포인트 적립 제외 상품만 있을 경우, 포인트를 사용했을 때 => 에러 처리
            throw new CustomException(400, '포인트 적립 제외 상품만 포함된 주문 건은 포인트를 사용할 수 없습니다.');
          }
          totalPointsToUse += tj.TransactionAmount;

          // 포인트 사용
          debitPointList = getPointService().debitPoint(tj);
          data.put('DebitPointList', debitPointList);
        } else {
          tj.JournalTypeId = jtList[0].Id;
          tj.JournalSubTypeId = jstList[0].Id;
          tj.Status = 'Processed';
          tjList.add(tj);
        }
      }

      // 고재성
      if (totalTransactionAmount > actualPaymentAmount) {
        // 총 입금 금액이 판매 금액보다 많을 경우 => 에러 처리
        throw new CustomException(
          400,
          '총 입금 금액이 실제 결제해야 할 금액을 초과했습니다. 총 입금 금액 : ' + totalTransactionAmount + ' | 판매 금액 : ' + actualPaymentAmount
        );
      }

      if (totalPointsToUse > earnableAmount) {
        // 포인트 사용 금액이 적립 가능 품목 금액보다 많을 경우 => 에러 처리
        throw new CustomException(
          400,
          '포인트 사용은 적립 가능 품목 금액 합계까지만 사용 가능합니다. 총 적립 가능 품목 금액 : ' +
            earnableAmount +
            ' | 총 포인트 사용 금액 : ' +
            totalPointsToUse
        );
      }

      List<Database.SaveResult> resultList = Database.insert(tjList);

      for (Database.SaveResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      data.put('DebitPointList', debitPointList);

      return ApiResult.ok(200, '주문 입금 이력 생성', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 주문 입금 이력 수정
   *
   * @param reqData 요청 값
   * @return ApiResult 주문 입금 이력 수정 결과
   * @throws CustomException
   */
  public ApiResult upsertOrderDeposit(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Object> transactionJournalList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);

      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // 주문 번호
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액

      // 로열티 회원 체크
      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE ContactId IN (SELECT MemberNo__c FROM Order WHERE Id = :orderId)
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 주문에 회원이 존재하지 않습니다. ' + orderId);
      }

      Set<String> depositNoSet = new Set<String>();
      Map<String, TransactionJournal> existingTjByDepositNo = new Map<String, TransactionJournal>();

      for (TransactionJournal tj : [
        SELECT Id, DepositNo__c
        FROM TransactionJournal
        WHERE OrderId = :orderId AND DepositNo__c != NULL
      ]) {
        depositNoSet.add(tj.DepositNo__c);
        existingTjByDepositNo.put(tj.DepositNo__c, tj);
      }

      List<GdSaleApiController.PointDebitDTO> debitPointList = new List<GdSaleApiController.PointDebitDTO>();

      // 일반 결제 건 거래 이력(TransactionJournal) Upsert 객체
      List<TransactionJournal> tjList = new List<TransactionJournal>();

      Decimal totalTransactionAmount = 0;
      for (Object v : transactionJournalList) {
        Map<String, Object> transactionJournal = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);

        String depositNo = ValidationUtil.stringValidation(transactionJournal.get('DepositNo__c'), 'DepositNo__c', true); // 입금 번호
        String deposiSeqNo = ValidationUtil.stringValidation(transactionJournal.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true); // 입금 일련 번호
        Date activityDate = ValidationUtil.dateValidation(transactionJournal.get('ActivityDate'), 'ActivityDate', true); // 입금 일자
        String paymentMethod = ValidationUtil.stringValidation(transactionJournal.get('PaymentMethod'), 'PaymentMethod', true); // 결제 구분 코드
        String depositType = ValidationUtil.stringValidation(transactionJournal.get('DepositType__c'), 'DepositType__c', true); // 입금 구분 코드
        Decimal transactionAmount = ValidationUtil.decimalValidation(transactionJournal.get('TransactionAmount'), 'TransactionAmount', true); // 입금 금액
        String couponNo = ValidationUtil.stringValidationEx(transactionJournal.get('CouponNo'), 'CouponNo', false, true); // 쿠폰 번호

        depositNo += '-' + deposiSeqNo;
        // 고재성
        if(depositType == '03' || depositType == '05') {
          totalTransactionAmount -= transactionAmount;
        } else {
          totalTransactionAmount += transactionAmount;
        }

        // 26.04.13 GD 수정 신규 로직
        if (!depositNoSet.isEmpty()) {
          if (depositNoSet.contains(depositNo)) {
            System.debug('기존 입금건');
            if ('81'.equals(paymentMethod) || '90'.equals(paymentMethod)) {
              continue;
            }
          }
        }

        TransactionJournal tj = new TransactionJournal();
        if (existingTjByDepositNo.containsKey(depositNo) && !'81'.equals(paymentMethod) && !'90'.equals(paymentMethod)) {
          tj.Id = existingTjByDepositNo.get(depositNo).Id;
        }
        tj.DepositNo__c = depositNo;
        tj.DeposiSeqNo__c = deposiSeqNo;
        tj.LoyaltyProgramId = lpmList[0].ProgramId;
        tj.JournalDate = activityDate;
        tj.ActivityDate = Datetime.now();
        tj.PaymentMethod = paymentMethod;
        tj.DepositType__c = depositType;
        tj.TransactionAmount = transactionAmount;
        tj.MemberId = lpmList[0].Id;
        tj.OrderId = orderId;
        tj.OrderId__c = orderId;
        tj.Status = 'Pending';

        // 쿠폰 사용/사용 취소 일 경우
        if (String.isNotBlank(couponNo) || '90'.equals(paymentMethod)) {
          // 기존 26.04.13 GD 수정 전
          // if (!depositNoSet.isEmpty()) {
          //   if (depositNoSet.contains(depositNo)) {
          //     // System.debug('존재함');
          //     continue;
          //   }
          // }

          tj.VoucherCode = couponNo;
          tj.Status = 'Processed';
          if ('03'.equals(depositType)) {
            // 쿠폰 사용 취소
            // tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
            // tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL, true);
            getVoucherService().redeemCancelVoucher(tj);
            continue;
          } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            // 쿠폰 사용
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
            getVoucherService().redeemVoucherV2(tj);
          } else {
            throw new CustomException(400, '확인되지 않는 입금 구분 값 입니다. ' + depositType);
          }
        } else if (
          // 포인트 사용/사용 취소 일 경우
          '81'.equals(paymentMethod)
        ) {
          // // 기존 26.04.13 GD 수정 전
          // if (!depositNoSet.isEmpty()) {
          //   if (depositNoSet.contains(depositNo)) {
          //     // System.debug('존재함');
          //     continue;
          //   }
          // }
          if ('03'.equals(depositType)) {
            // 포인트 사용 취소
            // [기존 코드 시작] 2026-04-22
            // Map<String, Object> cancelPointResult = getPointService().cancelPointRedemption(tj);
            // data.put('CancelPointList', cancelPointResult);
            // [기존 코드 끝] 2026-04-22

            // [수정 코드 시작] 2026-04-22 - 포인트 사용 취소(PATCH /order PM=81 DT=03) 후, 원본 Debit TJ 의 AdditionalNotes__c 를 RESTORE_NOTE 로 UPDATE하여
            //   후속 POST /return 의 차단 SOQL (GdReturnServiceImpl.cls:64-99) 에서 해당 LLT가 "이미 복구됨"으로 제외되도록 함.
            //   DELETE /return-deposit 경로(GdReturnDepositServiceImpl.cls:534) 와 동일 시맨틱 정합성 확보.
            //   안전성: 동일 OrderId + PM=81 + DT=01/02 + IsDeleted=FALSE + AdditionalNotes=NULL + TransactionAmount 일치 조건으로 좁혀 부분 취소 오판 방지.
            Map<String, Object> cancelPointResult = getPointService().cancelPointRedemption(tj);
            data.put('CancelPointList', cancelPointResult);

            // 역입금이 성공적으로 처리된 경우에만 원본 Debit TJ 를 "이미 복구됨" 으로 마킹
            // 금액 매칭 (reversal amount == original debit amount) 으로 부분 취소 케이스 보호
            List<TransactionJournal> origDebitTjs = [
              SELECT Id, AdditionalNotes__c
              FROM TransactionJournal
              WHERE OrderId = :orderId
                AND PaymentMethod = '81'
                AND DepositType__c IN ('01', '02')
                AND IsDeleted__c = FALSE
                AND AdditionalNotes__c = NULL
                AND TransactionAmount = :tj.TransactionAmount
              LIMIT 5
            ];
            if (!origDebitTjs.isEmpty()) {
              for (TransactionJournal origTj : origDebitTjs) {
                origTj.AdditionalNotes__c = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';
              }
              update origDebitTjs;
            }
            // [수정 코드 끝] 2026-04-22
          } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            // 포인트 사용
            debitPointList = getPointService().debitPoint(tj);
            data.put('DebitPointList', debitPointList);
          } else {
            throw new CustomException(400, '확인되지 않는 입금 구분 값 입니다. ' + depositType);
          }
        }
        // 일반 결제 일 경우
        else {
          if ('03'.equals(depositType)) {
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, true); // 입금 취소
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL, true); // 주문 입금 취소
          } else {
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true); // 입금 취소
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT, true); // 주문 입금 취소
          }
          tj.Status = 'Processed';
          tjList.add(tj);
        }
      }

      // 고재성
      if (totalTransactionAmount > actualPaymentAmount) {
        // 총 입금 금액이 판매 금액보다 많을 경우 => 에러 처리
        throw new CustomException(
          400,
          '총 입금 금액이 판매 금액을 초과했습니다. 총 입금 금액 : ' + totalTransactionAmount + ' | 판매 금액 : ' + actualPaymentAmount
        );
      }

      // 기존 26.04.13 GD 수정 전
      List<Database.UpsertResult> resultList = Database.upsert(tjList, TransactionJournal.DepositNo__c);

      for (Database.UpsertResult result : resultList) {
        if (!result.isSuccess()) {
          Database.Error err = result.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      // 26.04.13 GD 수정 주문 입금 이력 신규 로직
      // List<Database.SaveResult> resultList = Database.insert(tjList);

      // for (Database.SaveResult result : resultList) {
      //   if (!result.isSuccess()) {
      //     Database.Error err = result.getErrors()[0];
      //     throw new CustomException(400, err.getMessage());
      //   }
      // }

      return ApiResult.ok(200, '주문 입금 이력 수정 완료.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }
}