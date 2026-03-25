/**
 * 판매 입금 관련 로직 처리하는 서비스 구현 클래스
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 * @see GdSaleDepositService
 */
public with sharing class GdSaleDepositServiceImpl implements GdSaleDepositService {
  private static GdVoucherService voucherService;
  private static GdPointService pointService;
  private static GdMemberTierService memberTierService;

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

  // 테스트 클래스 용도
  @TestVisible
  private static void setMemberTierService(GdMemberTierService mock) {
    memberTierService = mock;
  }

  private static GdMemberTierService getMemberTierService() {
    if (memberTierService == null) {
      memberTierService = new GdMemberTierServiceImpl();
    }
    return memberTierService;
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
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION = 'DebitCancellation'; // 포인트 사용 취소

  /**
   * 판매 입금 이력 생성
   * TransactionJournal insert
   *
   * @see GdSaleApiControllerV1
   * @see createSaleDepositHistory
   */
  public ApiResult createSaleDepositHistory(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();

    try {
      List<Object> depositList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false);
      String insertId = ValidationUtil.stringValidation(reqData.get('InsertId__c'), 'InsertId__c', false); // 등록자
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액
      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', true); // 매장 코드

      String storeTypeFour = ValidationUtil.stringValidation(reqData.get('storeTypeFour'), 'storeTypeFour', false); // 매장구분4

      Boolean isExclude = false; // 포인트 적립 제외 여부
      Decimal excludeAmount = 0; // 포인트 적립 제외 금액
      Decimal earnableAmount = 0; // 적립 가능 품목 금액 합계
      // Decimal totalAvailablePointUsageAmount = 0; // 포인트 사용 가능 금액 합계

      // List<Object> oiList = (List<Object>) reqData.get('oiList');
      // for (Object v : oiList) {
      //   OrderItem oi = (OrderItem) v;

      //   if (oi.IsExclude__c != null) {
      //     if (oi.IsExclude__c == true) {
      //       System.debug('해당 상품은 포인트 적립 제외 대상입니다.'); // 포인트 적립 불가 항목
      //       isExclude = oi.IsExclude__c;
      //       excludeAmount += (oi.NetSalesUnitPrice__c != null) ? oi.NetSalesUnitPrice__c : 0;
      //     } else {
      //       System.debug('해당 상품은 포인트 적립 대상입니다.'); // 포인트 적립 가능 항목
      //       earnableAmount += (oi.NetSalesUnitPrice__c != null) ? oi.NetSalesUnitPrice__c : 0;
      //     }
      //   }
      // }

      List<Object> oiList = (List<Object>) reqData.get('oiList');
      for (Object v : oiList) {
        OrderItem oi = (OrderItem) v;

        if (oi.IsExclude__c == false) {
          isExclude = false; // 하나라도 false면 계속 false 유지
          System.debug('해당 상품은 포인트 적립 대상입니다.');
          earnableAmount += oi.NetSalesUnitPrice__c != null ? oi.NetSalesUnitPrice__c : 0; // 적립 가능 품목 금액 합계
        } else {
          excludeAmount += oi.NetSalesUnitPrice__c != null ? oi.NetSalesUnitPrice__c : 0; // 포인트 적립 제외 금액
          System.debug('해당 상품은 포인트 적립 제외 대상입니다.');
        }
      }

      // System.debug('포인트 적립 제외 금액 : ' + excludeAmount);
      System.debug('적립 가능 품목 금액 합계 : ' + earnableAmount);

      // 프로모션 체크
      Id promotionId;
      if (promotionNo != null) {
        List<Promotion> promotionList = [SELECT Id FROM Promotion WHERE PromotionNo__c = :promotionNo LIMIT 1];
        if (promotionList.isEmpty()) {
          throw new CustomException(400, '해당 프로모션이 없습니다. ' + promotionNo);
        }
        promotionId = promotionList[0].Id;
      }
      // 회원 체크
      List<Contact> cList = [SELECT Id, Grade__c FROM Contact WHERE MemberNo__c = :memberNo LIMIT 1];
      if (cList.isEmpty()) {
        throw new CustomException(400, '없는 회원입니다. ' + memberNo);
      }

      // 로열티 프로그램 멤버 체크
      List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :cList[0].Id LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '로열티 멤버가 아닙니다. ' + memberNo);
      }

      Set<String> orderDepositNoSet = new Set<String>();

      // 저널 유형 체크
      Id depoistJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true); // 저널 유형 : 입금

      // 저널 하위 유형 체크
      Id saleDepoistJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true); // 저널 하위 유형 : 판매 입금

      Decimal totalPointsToUse = 0;
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
        String orderNo = ValidationUtil.stringValidationEx(deposit.get('OrderNo__c'), 'OrderNo__c', false, true); // 주문 번호

        if (String.isNotBlank(orderNo)) {
          orderDepositNoSet.add(depositNo + '-' + deposiSeqNo);
          continue;
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
        tj.SaleId__c = orderId;

        if (promotionNo != null) {
          tj.PromotionId = promotionId;
        }

        if (String.isNotBlank(couponNo)) {
          tj.VoucherCode = couponNo;
          tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
          tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
          tj.Status = 'Processed';
          getVoucherService().redeemVoucherV2(tj);
          continue;
        }

        // 포인트 사용 일 경우
        if ('81'.equals(paymentMethod)) {
          if (isExclude) {
            // 포인트 적립 제외 상품만 있을 경우, 포인트를 사용했을 때 => 에러 처리
            throw new CustomException(400, '포인트 적립 제외 상품만 포함된 판매 건은 포인트를 사용할 수 없습니다.');
          }
          totalPointsToUse += tj.TransactionAmount;

          // 포인트 사용
          List<GdSaleApiController.PointDebitDTO> debitPointList = getPointService().debitPoint(tj);
          for (GdSaleApiController.PointDebitDTO debitPoint : debitPointList) {
            debitPoint.AM_SAL = actualPaymentAmount; // 판매처리된 판매의 금액
            debitPoint.ID_INSERT = insertId; // 등록자
          }

          data.put('DebitPointList', debitPointList);
        } else {
          tj.JournalTypeId = depoistJtId;
          tj.JournalSubTypeId = saleDepoistJstId;
          tj.Status = 'Processed';
          tjList.add(tj);
        }
      }

      // 주문 입금 건에 판매 ID 삽입
      if (!orderDepositNoSet.isEmpty()) {
        List<TransactionJournal> updateTargetList = [
          SELECT Id, DepositNo__c, SaleId__c
          FROM TransactionJournal
          WHERE DepositNo__c IN :orderDepositNoSet
        ];

        for (TransactionJournal tj : updateTargetList) {
          tj.SaleId__c = orderId;
        }

        if (!updateTargetList.isEmpty()) {
          update updateTargetList;
        }
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

      // 구매 시 포인트 적립 로직
      if (!tjList.isEmpty()) {
        List<Account> storeList = [SELECT Id, StoreType__c FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
        if (storeList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다. ' + storeCode);
        }
        // 매장 구분이 아울렛(20, 25)인 경우 포인트 적립 X
        // 매장구분4(storeTypeFour) '15' = 면세
        if (storeList[0].StoreType__c != '20' && storeList[0].StoreType__c != '25' && storeTypeFour != '15') {
          // List<PointCreditDTO> creditPointList = getPointService().creditPointsOnPurchase(tjList);
          List<PointCreditDTO> creditPointList = getPointService().creditPointsOnPurchaseV2(tjList, excludeAmount);
          if (creditPointList != null && creditPointList.size() > 0) {
            for (PointCreditDTO pcDto : creditPointList) {
              pcDto.AM_SAL = actualPaymentAmount; // 판매 금액
              pcDto.ID_INSERT = insertId; // 등록자
              pcDto.NO_PROM_MBR = promotionNo; // 프로모션 번호
              pcDto.NO_GRADE_ADVAN = cList[0].Grade__c; // 승급번호
            }
            data.put('CreditPointList', creditPointList);
          }
        }
      }

      return ApiResult.ok(200, '판매 입금 이력 생성', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 판매 입금 이력 수정
   *
   * @param reqData 요청 값
   * @return ApiResult 판매 입금 이력 수정 결과
   * @throws CustomException
   */
  public ApiResult upsertSaleDeposit(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Object> transactionJournalList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);

      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // 주문 번호

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

      List<GdSaleApiController.PointDebitDTO> debitPointList = new List<GdSaleApiController.PointDebitDTO>();

      // 일반 결제 건 거래 이력(TransactionJournal) Upsert 객체
      List<TransactionJournal> newTjList = new List<TransactionJournal>();

      Set<String> depositNoSet = new Set<String>();

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

        TransactionJournal tj = new TransactionJournal();
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
        tj.SaleId__c = orderId;
        tj.Status = 'Pending';

        // 쿠폰 사용/사용 취소 일 경우
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
          } else {
            throw new CustomException(400, '확인되지 않는 입금 구분 값 입니다. ' + depositType);
          }
        }

        // 포인트 사용/사용 취소 일 경우
        if ('81'.equals(paymentMethod)) {
          if ('03'.equals(depositType)) {
            // 포인트 사용 취소
            Map<String, Object> cancelPointResult = getPointService().cancelPointRedemption(tj);
            data.put('CancelPointList', cancelPointResult);
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
          tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, true);
          tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL, true);

          // if ('03'.equals(depositType)) {
          //   tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, true); // 입금 취소
          //   tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL, true); // 주문 입금 취소
          // } else {
          //   tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true); // 입금 취소
          //   tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT, true); // 주문 입금 취소
          // }

          tj.Status = 'Processed';
          newTjList.add(tj);

          depositNoSet.add(tj.DepositNo__c);
        }
      }

      // 일반 결제 차액 계산 + 원 입금 upsert + 포인트 보정 처리
      if (!depositNoSet.isEmpty()) {
        Date endDate;

        // (1) 기존 원 입금 조회 (업데이트 전)
        Map<String, TransactionJournal> oldTjMap = new Map<String, TransactionJournal>();
        for (TransactionJournal oldTj : [
          SELECT Id, DepositNo__c, TransactionAmount, PaymentMethod, DepositType__c, MemberId, LoyaltyProgramId, Order.EndDate
          FROM TransactionJournal
          WHERE DepositNo__c IN :depositNoSet AND SaleId__c = :orderId
          LIMIT 2000
        ]) {
          oldTjMap.put(oldTj.DepositNo__c, oldTj);

          if (oldTj.Order.EndDate != null) {
            endDate = oldTj.Order.EndDate;
          }
        }

        // (2) 원 입금 Upsert
        List<Database.UpsertResult> upsertResults = Database.upsert(newTjList, TransactionJournal.DepositNo__c);
        for (Database.UpsertResult r : upsertResults) {
          if (!r.isSuccess()) {
            Database.Error err = r.getErrors()[0];
            throw new CustomException(400, err.getMessage());
          }
        }

        List<Map<String, Object>> creditTjList = new List<Map<String, Object>>();
        List<Map<String, Object>> debitTjList = new List<Map<String, Object>>();

        for (TransactionJournal newTj : newTjList) {
          TransactionJournal oldTj = oldTjMap.get(newTj.DepositNo__c);

          // 기존/신규 적립 대상 여부
          Boolean oldEligible = (oldTj != null) ? getPointService().isAccrualEligible(oldTj) : false;
          Boolean newEligible = getPointService().isAccrualEligible(newTj);

          // 멱등키 설정
          String newHash = buildAccrualHash(newTj) + '|' + String.valueOf(newEligible);
          String oldHash = (oldTj == null) ? null : (buildAccrualHash(oldTj) + '|' + String.valueOf(oldEligible));

          // 이전에 같은 조건으로 이미 반영했으면 스킵
          if (oldHash == newHash) {
            continue;
          }

          // 조정 할 금액
          Decimal adjust = 0;

          // 이전 tj 가 적립 대상 O && 신규 tj 가 적립 대상 O => 차액 만큼 적립 | 차감
          if (oldEligible && newEligible) {
            System.debug('이전 tj 가 적립 대상 O && 신규 tj 가 적립 대상 O => 차액 만큼 적립 | 차감');
            // 신규 입금 금액 - 기존 입금 금액
            // adjust 가 + 일 경우 포인트 추가 적립 | - 일 경우 포인트 적립 부분 취소
            adjust = newTj.TransactionAmount - oldTj.TransactionAmount;
          }
          // 이전 tj 가 적립 대상 O && 신규 tj 가 적립 대상 X => 이전 tj에 적립 된 금액 만큼 차감
          else if (oldEligible && !newEligible) {
            System.debug('이전 tj 가 적립 대상 O && 신규 tj 가 적립 대상 X => 이전 tj에 적립 된 금액 만큼 차감');
            // 기존 입금 금액 만큼 포인트 적립 취소
            adjust -= oldTj.TransactionAmount;
          }
          // 이전 tj 가 적립 대상 X && 신규 tj 가 적립 대상 O => 신규 tj에 금액 만큼 지급
          else if (!oldEligible && newEligible) {
            System.debug('이전 tj 가 적립 대상 X && 신규 tj 가 적립 대상 O => 신규 tj에 금액 만큼 지급');
            // 신규 입금 금액 만큼 포인트 추가 적립
            adjust += newTj.TransactionAmount;
          } else {
            System.debug('이전 tj 가 적립 대상 X && 신규 tj 가 적립 대상 X => 추가 지급/차감 없음');
            // 이전 tj 가 적립 대상 X && 신규 tj 가 적립 대상 X => 추가 지급/차감 없음
            continue;
          }
          Map<String, Object> m = new Map<String, Object>();
          m.put('TransactionJournal', newTj);

          if (adjust > 0) {
            m.put('adjustAmount', adjust);
            m.put('AdditionalNotes__c', '판매 입금 수정 API 요청에 의한 포인트 추가 적립');
            creditTjList.add(m);
          } else if (adjust < 0) {
            m.put('adjustAmount', Math.abs(adjust));
            m.put('AdditionalNotes__c', '판매 입금 수정 API 요청에 의한 포인트 적립 취소');
            debitTjList.add(m);
          }
        }

        String grade = getMemberTierService().resolveAccrualGrade(lpmList[0].Id, endDate);

        // 포인트 지급 할 건 있는 경우
        if (!creditTjList.isEmpty()) {
          System.debug('추가 지급할 건 있습니다.');
          Order o = [SELECT Id, StoreCode__r.StoreType__c FROM Order WHERE id = :orderId LIMIT 1];
          // 매장 구분이 아울렛(20, 25)인 경우 포인트 적립 X
          if (o.StoreCode__r.StoreType__c != '20' && o.StoreCode__r.StoreType__c != '25') {
            for (Map<String, Object> creditReqData : creditTjList) {
              creditReqData.put('Grade__c', grade);
              // 포인트 지급
              List<PointCreditDTO> creditResult = getPointService().creditPointsOnPurchaseByGrade(creditReqData);
              data.put('CreditPointList', creditResult);
            }
          }
        }

        // 포인트 지급 취소 할 건 있는 경우
        if (!debitTjList.isEmpty()) {
          System.debug('지급 취소할 건 있습니다.');

          for (Map<String, Object> debitReqData : debitTjList) {
            debitReqData.put('Grade__c', grade);
            // 포인트 지급 취소
            List<PointDebitDTO> debitResult = getPointService().debitPointsOnPurchaseByGrade(debitReqData);
            data.put('CancelPointList', debitResult);
          }
        }
      }

      return ApiResult.ok(200, '판매 입금 이력 수정 완료.', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 판매 입금 조회
   */
  public ApiResult getSaleDepositList(String saleNo) {
    try {
      List<Order> oList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, '해당 판매건이 없습니다. ' + saleNo);
      }

      List<TransactionJournal> tjList = [
        SELECT Id, PaymentMethod, DepositType__c, TransactionAmount, OrderId__c, VoucherCode
        FROM TransactionJournal
        WHERE OrderId = :oList[0].Id
        LIMIT 100
      ];

      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 판매건의 입금 내역이 없습니다. ' + saleNo);
      }

      List<GdSaleDepositApiControllerV1.DepositResponseDTO> depositList = new List<GdSaleDepositApiControllerV1.DepositResponseDTO>();
      List<String> voucherCodeList = new List<String>();
      for (TransactionJournal tj : tjList) {
        GdSaleDepositApiControllerV1.DepositResponseDTO res = new GdSaleDepositApiControllerV1.DepositResponseDTO();
        res.CD_TYPE_APPR = tj.PaymentMethod;
        res.AM_DEPOSIT = tj.TransactionAmount;

        if (tj.VoucherCode != null) {
          List<Voucher> vList = [
            SELECT Id, VoucherDefinition.Name, VoucherCode, ExpirationDate, DiscountPercent, FaceValue, Reason
            FROM Voucher
            WHERE VoucherCode = :tj.VoucherCode
            LIMIT 1
          ];
          if (vList.isEmpty()) {
            throw new CustomException(400, 'Voucher is empty.');
          }
          res.NO_COUPON_ALL = vList[0].VoucherCode; // 쿠폰 코드
          res.NM_COUPON = vList[0].VoucherDefinition.Name; // 쿠폰명
          res.DT_EXP = vList[0].ExpirationDate; // 만료일자
          res.RT_DISC = vList[0].DiscountPercent; // 할인율
          res.AM_DISC = vList[0].FaceValue; // 할인 금액
          res.TX_REMARK = vList[0].Reason; // 비고
        }
        depositList.add(res);
      }

      Map<String, Object> data = new Map<String, Object>();
      data.put('depositList', depositList);

      return ApiResult.ok(200, '판매 입금 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 판매 입금 전체 삭제
   */
  public ApiResult deleteAllSaleDeposits(Id orderId) {
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
          VoucherCode
        FROM TransactionJournal
        WHERE OrderId = :orderId AND IsDeleted__c = FALSE
        LIMIT 200
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 판매의 입금 이력이 존재하지 않습니다. ' + orderId);
      }

      Id pointDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, true);
      Id couponRedeemJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);

      Map<String, Object> pointRedemptionCanceled = new Map<String, Object>();
      for (TransactionJournal tj : tjList) {
        if (tj.JournalSubTypeId == pointDebitJstId || tj.JournalSubTypeId == couponRedeemJstId) {
          TransactionJournal newTj = tj.clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
          newTj.DepositNo__c = 'del_' + tj.DepositNo__c;
          newTj.JournalDate = Datetime.now();
          newTj.ActivityDate = Datetime.now();
          newTj.DepositType__c = '03'; // 03 : 환불

          if (tj.JournalSubTypeId == pointDebitJstId) {
            // 포인트 사용 취소
            // newTj.Status = 'Pending';
            pointRedemptionCanceled = getPointService().cancelPointRedemption(newTj);
          } else {
            // 쿠폰 사용 취소
            newTj.Status = 'Processed';
            ApiResult voucherResult = getVoucherService().redeemCancelVoucher(newTj);
            data.put('couponCanceled', voucherResult.data);
          }
        }

        tj.IsDeleted__c = true;
        tj.DeleteDateTime__c = Datetime.now();
      }
      update tjList;
      data.put('pointRedemptionCanceled', pointRedemptionCanceled);

      // 구매 시 지급된 포인트 적립 취소
      List<GdSaleApiController.PointDebitDTO> purchasePointAccrualCanceled = getPointService().cancelPointsCreditedOnPurchase(tjList);
      data.put('purchasePointAccrualCanceled', purchasePointAccrualCanceled);

      return ApiResult.ok(200, '판매 입금 전체 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 판매 입금 삭제
   */
  public ApiResult deleteSaleDeposit(String depositNo) {
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
          VoucherCode
        FROM TransactionJournal
        WHERE DepositNo__c = :depositNo AND IsDeleted__c = FALSE
        LIMIT 1
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 입금 이력이 존재하지 않습니다. ' + depositNo);
      }

      Id pointDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, true);
      Id couponRedeemJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);

      // 포인트 사용 취소
      if (tjList[0].JournalSubTypeId == pointDebitJstId || tjList[0].JournalSubTypeId == couponRedeemJstId) {
        TransactionJournal newTj = tjList[0].clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
        newTj.DepositNo__c = 'del_' + tjList[0].DepositNo__c;
        newTj.JournalDate = Datetime.now();
        newTj.ActivityDate = Datetime.now();
        newTj.DepositType__c = '03'; // 03 : 환불

        if (tjList[0].JournalSubTypeId == pointDebitJstId) {
          // 포인트 사용 취소
          // newTj.Status = 'Pending';
          Map<String, Object> pointRedemptionCanceled = new Map<String, Object>();
          pointRedemptionCanceled = getPointService().cancelPointRedemption(newTj);
          data.put('pointRedemptionCanceled', pointRedemptionCanceled);
        } else {
          // 쿠폰 사용 취소
          newTj.Status = 'Processed';
          ApiResult voucherResult = getVoucherService().redeemCancelVoucher(newTj);
          data.put('couponCanceled', voucherResult.data);
        }
      } else {
        // 다른 주문/판매 건에서 포인트 사용했는지 확인
        List<LoyaltyLedgerTraceability> lltList = [
          SELECT
            Id,
            DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
            DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
            DebitLoyaltyLedger.TransactionJournal.DepositNo__c
          FROM LoyaltyLedgerTraceability
          WHERE CreditLoyaltyLedger.TransactionJournal.OrderId = :tjList[0].OrderId AND ActionType = 'Debit'
          LIMIT 1
        ];
        if (!lltList.isEmpty()) {
          if (lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c != null) {
            throw new CustomException(
              400,
              '해당 입금 건은 삭제할 수 없습니다. 이미 사용한 판매 건이 존재합니다. 판매번호: ' +
                lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c +
                '/ 입금번호: ' +
                lltList[0].DebitLoyaltyLedger.TransactionJournal.DepositNo__c
            );
          } else if (lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c != null) {
            throw new CustomException(
              400,
              '해당 입금 건은 삭제할 수 없습니다. 이미 사용한 주문 건이 존재합니다. 주문번호: ' +
                lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c +
                '/ 입금번호: ' +
                lltList[0].DebitLoyaltyLedger.TransactionJournal.DepositNo__c
            );
          }
        }

        // 구매 시 지급된 포인트 적립 취소
        List<GdSaleApiController.PointDebitDTO> purchasePointAccrualCanceled = getPointService().cancelPointsCreditedOnPurchase(tjList);
        data.put('purchasePointAccrualCanceled', purchasePointAccrualCanceled);
      }

      tjList[0].IsDeleted__c = true;
      tjList[0].DeleteDateTime__c = Datetime.now();
      update tjList[0];

      return ApiResult.ok(200, '판매 입금 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 적립 멱등키(효과 해시) 생성
   * - 적립에 영향을 주는 값만 포함
   */
  private static String buildAccrualHash(TransactionJournal tj) {
    String amount = (tj.TransactionAmount == null) ? '0' : String.valueOf(tj.TransactionAmount.setScale(0));
    return String.valueOf(tj.PaymentMethod) + '|' + String.valueOf(tj.DepositType__c) + '|' + amount;
  }

  private String resolveAccrualGrade(Id lpmId, Date orderDate) {
    // 1) 현재 등급/이전 등급 조회
    LoyaltyProgramMember lpm = [
      SELECT Id, Contact.Grade__c, Contact.PreviousGrade__c
      FROM LoyaltyProgramMember
      WHERE Id = :lpmId
      LIMIT 1
    ];

    // 2) 회원 등급 변경 일자 조회(가장 최근 티어 수정일)
    LoyaltyMemberTier lmt = [
      SELECT Id, LastModifiedDate
      FROM LoyaltyMemberTier
      WHERE LoyaltyMemberId = :lpmId
      ORDER BY LastModifiedDate DESC
      LIMIT 1
    ];

    Date gradeModifiedDate = lmt.LastModifiedDate.date();

    // 판매일이 등급 변경일과 같으면 "이전 등급" 적용 (단, PreviousGrade가 있을 때)
    if (orderDate == gradeModifiedDate && !String.isBlank(lpm.Contact.PreviousGrade__c)) {
      return lpm.Contact.PreviousGrade__c;
    }
    return lpm.Contact.Grade__c;
  }
}