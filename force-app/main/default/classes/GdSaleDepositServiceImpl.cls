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
  private static final String JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL = 'Promotion Point Accrual'; // 프로모션 포인트 적립
  private static final String JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL = 'Promotion Point Accrual Reversal'; // 프로모션 포인트 적립 취소
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM = 'Coupon Redeem'; // 쿠폰 사용
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL = 'Coupon Redeem Cancel'; // 쿠폰 사용 취소

  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';
  private static final String RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';

  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT = 'Debit'; // 포인트 사용
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION = 'DebitCancellation'; // 포인트 사용 취소

  private static void logTiming(String label, Long startMs, Integer startCpu) {
    Long elapsedMs = Datetime.now().getTime() - startMs;
    Integer elapsedCpu = Limits.getCpuTime() - startCpu;
    System.debug(LoggingLevel.WARN, '[TIMING] ' + label + ' | 누적 ' + elapsedMs + 'ms | CPU ' + elapsedCpu + 'ms');
  }

  /**
   * 판매 입금 이력 등록
   * TransactionJournal insert
   *
   * @see GdSaleApiControllerV1
   * @see createSaleDepositHistory
   */
  public ApiResult createSaleDepositHistory(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();

    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      GdVoucherService voucherSvc = getVoucherService();
      GdPointService pointSvc = getPointService();

      List<Object> depositList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true);
      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true);
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false);
      String insertId = ValidationUtil.stringValidation(reqData.get('InsertId__c'), 'InsertId__c', false); // 등록자
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액
      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', true); // 매장 코드
      String storeType = ValidationUtil.stringValidation(reqData.get('storeType'), 'storeType', false); // 매장 구분 코드

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
        Decimal itemAmount = oi.NetSalesUnitPrice__c != null ? oi.NetSalesUnitPrice__c : 0;

        if (oi.IsExclude__c == false) {
          isExclude = false; // 하나라도 false면 계속 false 유지
          earnableAmount += itemAmount; // 적립 가능 품목 금액 합계
        } else {
          excludeAmount += itemAmount; // 포인트 적립 제외 금액
        }
      }

      if (('08'.equals(storeType) || '09'.equals(storeType) || '11'.equals(storeType)) && String.isBlank(promotionNo)) {
        throw new CustomException(400, '해당 매장 구분은 프로모션 번호가 필수입니다. storeType=' + storeType);
      }

      // 프로모션 체크
      logTiming('createSaleDepositHistory.oiAggregation', totalStartMs, totalStartCpu);
      Id promotionId;
      // System.debug('promotionNo : ' + promotionNo);
      if (String.isNotBlank(promotionNo)) {
        // if (promotionNo != null) {
        // System.debug('if (promotionNo != null) { 진입');
        List<Promotion> promotionList = [
          SELECT Id, IsActive, StartDate, EndDate
          FROM Promotion
          WHERE PromotionNo__c = :promotionNo AND PromotionNo__c != NULL
          LIMIT 1
        ];
        if (promotionList.isEmpty()) {
          throw new CustomException(400, '해당 프로모션이 없습니다. ' + promotionNo);
        }
        if (promotionList[0].IsActive == false) {
          throw new CustomException(400, '해당 프로모션은 비활성화 상태입니다. ' + promotionNo);
        }
        // [Promotion Date Validation 2026-04-28] 판매 일자가 프로모션 적용 기간(StartDate ~ EndDate) 내인지 검증
        //   - 판매일자는 Order.EndDate (= 판매 등록 시 받은 EndDate) 사용. orderId 로 별도 조회.
        //   - 범위 외인 경우 시작/종료일자를 함께 알리는 에러 메시지 반환.
        Promotion p = promotionList[0];

        // [Promotion Order-Linked Exception 2026-04-29] 주문에서 끌고온 동일 프로모션이면 기간 검증 스킵
        //   - ERP 측에서 주문→판매 전환 시 프로모션 변경 불가 보장. 주문 시점에 이미 프로모션 유효성 검증을 통과한 것이므로
        //     판매 일자가 프로모션 만료일 이후라도 적용 가능해야 함.
        //   - 식별 방법: 판매 입금 중 OrderNo__c 가 채워진 것이 있고, 그 주문에 적용된 프로모션 == 이번 promotionNo 면 스킵.
        Boolean isOrderLinkedSamePromotion = false;
        String linkedOrderNo = null;
        for (Object dep : depositList) {
          Map<String, Object> depMap = (Map<String, Object>) dep;
          Object orderNoObj = depMap.get('OrderNo__c');
          if (orderNoObj != null && String.isNotBlank(String.valueOf(orderNoObj))) {
            linkedOrderNo = String.valueOf(orderNoObj);
            break;
          }
        }
        if (String.isNotBlank(linkedOrderNo)) {
          List<TransactionJournal> linkedTjList = [
            SELECT Promotion.PromotionNo__c
            FROM TransactionJournal
            WHERE Order.OrderNo__c = :linkedOrderNo
              AND PromotionId != NULL
              AND IsDeleted__c = FALSE
            ORDER BY CreatedDate ASC
            LIMIT 1
          ];
          if (!linkedTjList.isEmpty()
              && linkedTjList[0].Promotion != null
              && linkedTjList[0].Promotion.PromotionNo__c == promotionNo) {
            isOrderLinkedSamePromotion = true;
          }
        }

        // 주문 연계 동일 프로모션이 아닐 때만 판매 일자 기준 기간 검증
        if (!isOrderLinkedSamePromotion) {
          Date saleDate;
          List<Order> orderForDateList = [SELECT EndDate FROM Order WHERE Id = :orderId LIMIT 1];
          if (!orderForDateList.isEmpty() && orderForDateList[0].EndDate != null) {
            saleDate = orderForDateList[0].EndDate;
          }
          if (saleDate == null) {
            saleDate = Date.today();
          }
          if (p.StartDate != null && saleDate < p.StartDate) {
            throw new CustomException(
              400,
              '판매 일자가 프로모션 적용 기간 이전입니다. (프로모션: ' + promotionNo +
              ', 시작일: ' + String.valueOf(p.StartDate) + ', 종료일: ' + String.valueOf(p.EndDate) + ')'
            );
          }
          if (p.EndDate != null && saleDate > p.EndDate) {
            throw new CustomException(
              400,
              '판매 일자가 프로모션 적용 기간 이후입니다. (프로모션: ' + promotionNo +
              ', 시작일: ' + String.valueOf(p.StartDate) + ', 종료일: ' + String.valueOf(p.EndDate) + ')'
            );
          }
        }
        promotionId = p.Id;
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

      logTiming('createSaleDepositHistory.memberSetup', totalStartMs, totalStartCpu);
      Set<String> orderDepositNoSet = new Set<String>();
      Map<String, String> orderDepositOrderNoByKey = new Map<String, String>();

      // 저널 유형 체크
      Id depoistJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true); // 저널 유형 : 입금

      // 저널 하위 유형 체크
      Id saleDepoistJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true); // 저널 하위 유형 : 판매 입금

      Decimal totalPointsToUse = 0;
      Decimal totalTransactionAmount = 0;
      List<TransactionJournal> tjList = new List<TransactionJournal>();
      List<GdSaleApiController.PointDebitDTO> allDebitPointList = new List<GdSaleApiController.PointDebitDTO>();
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
        String depositKey = depositNo + '-' + deposiSeqNo;

        // 신규 로직 (고든 26-04-01) start
        if (depositType == '03' || depositType == '05') {
          totalTransactionAmount -= transactionAmount;
        } else {
          totalTransactionAmount += transactionAmount;
        }
        // 신규 로직 (고든 26-04-01) end

        if (String.isNotBlank(orderNo)) {
          System.debug('if (String.isNotBlank(orderNo)) { 진입 orderNo : ' + orderNo);
          System.debug('if (String.isNotBlank(orderNo)) { 진입 depositKey : ' + depositKey);

          orderDepositNoSet.add(depositKey);
          orderDepositOrderNoByKey.put(depositKey, orderNo);
          continue;
        }

        TransactionJournal tj = new TransactionJournal();
        tj.DepositNo__c = depositKey;
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
        // tj.PromotionId = promotionId;

        if (promotionNo != null) {
          tj.PromotionId = promotionId;
        }

        if (String.isNotBlank(couponNo)) {
          tj.VoucherCode = couponNo;
          tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
          tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);
          tj.Status = 'Processed';
          Long voucherStartMs = Datetime.now().getTime();
          Integer voucherStartCpu = Limits.getCpuTime();
          voucherSvc.redeemVoucherV2(tj);
          logTiming('createSaleDepositHistory.redeemVoucherV2', voucherStartMs, voucherStartCpu);
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
          Long debitPointStartMs = Datetime.now().getTime();
          Integer debitPointStartCpu = Limits.getCpuTime();
          List<GdSaleApiController.PointDebitDTO> debitPointList = pointSvc.debitPoint(tj);
          logTiming('createSaleDepositHistory.debitPoint', debitPointStartMs, debitPointStartCpu);
          if (debitPointList != null && !debitPointList.isEmpty()) {
            for (GdSaleApiController.PointDebitDTO debitPoint : debitPointList) {
              debitPoint.AM_SAL = actualPaymentAmount; // 판매처리된 판매의 금액
              debitPoint.ID_INSERT = insertId; // 등록자
            }
            allDebitPointList.addAll(debitPointList);
          }
        } else {
          tj.JournalTypeId = depoistJtId;
          tj.JournalSubTypeId = saleDepoistJstId;
          tj.Status = 'Processed';
          tjList.add(tj);
        }
      }

      logTiming('createSaleDepositHistory.depositLoop', totalStartMs, totalStartCpu);
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

      // 고재성
      if (totalTransactionAmount > actualPaymentAmount) {
        // 총 입금 금액이 판매 금액보다 많을 경우 => 에러 처리
        throw new CustomException(
          400,
          '총 입금 금액이 실제 결제해야 할 금액을 초과했습니다. 총 입금 금액 : ' +
            totalTransactionAmount +
            ' | 실제 결제 금액 : ' +
            actualPaymentAmount
        );
      }

      if (!allDebitPointList.isEmpty()) {
        data.put('DebitPointList', allDebitPointList);
      }

      if (!tjList.isEmpty()) {
        Long insertStartMs = Datetime.now().getTime();
        Integer insertStartCpu = Limits.getCpuTime();
        List<Database.SaveResult> resultList = Database.insert(tjList);
        logTiming('createSaleDepositHistory.insertTransactionJournals', insertStartMs, insertStartCpu);

        for (Database.SaveResult result : resultList) {
          if (!result.isSuccess()) {
            Database.Error err = result.getErrors()[0];
            throw new CustomException(400, err.getMessage());
          }
        }
      }

      // 주문 입금 건에 판매 ID 삽입
      if (!orderDepositNoSet.isEmpty()) {
        System.debug('if (!orderDepositNoSet.isEmpty()) { 진입');
        Long updateOrderDepositStartMs = Datetime.now().getTime();
        Integer updateOrderDepositStartCpu = Limits.getCpuTime();
        List<TransactionJournal> queriedOrderDepositList = [
          SELECT Id, DepositNo__c, SaleId__c, PaymentMethod, TransactionAmount, MemberId, OrderId, Order.OrderNo__c, PromotionId, LoyaltyProgramId
          FROM TransactionJournal
          WHERE DepositNo__c IN :orderDepositNoSet
        ];
        List<TransactionJournal> updateTargetList = new List<TransactionJournal>();

        // DebugUtil.pretty('orderDepositNoSet', orderDepositNoSet);

        for (TransactionJournal tj : queriedOrderDepositList) {
          String expectedOrderNo = orderDepositOrderNoByKey.get(tj.DepositNo__c);
          String actualOrderNo = tj.Order == null ? null : tj.Order.OrderNo__c;
          if (String.isNotBlank(expectedOrderNo) && expectedOrderNo != actualOrderNo) {
            continue;
          }
          tj.SaleId__c = orderId;
          updateTargetList.add(tj);
        }

        if (!updateTargetList.isEmpty()) {
          tjList.addAll(updateTargetList);
          update updateTargetList;
        }
        logTiming('createSaleDepositHistory.updateOrderDeposits', updateOrderDepositStartMs, updateOrderDepositStartCpu);
      }

      // 구매 시 포인트 적립 로직
      if (!tjList.isEmpty()) {
        List<Account> storeList = [SELECT Id, StoreType__c, StoreGroupCode__c FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
        if (storeList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장 코드입니다. ' + storeCode);
        }
        // 매장 구분이 아울렛(20, 25)인 경우 포인트 적립 X
        // 매장구분4(storeTypeFour) '15' = 면세
        // 26.04.04 WT 수정 : StoreType__c '15', '30', '33', '35'와 StoreGroupCode__c '14' 제외 조건 추가
        if (
          // storeList[0].StoreType__c != '20' &&
          // storeList[0].StoreType__c != '25' &&
          // storeList[0].StoreType__c != '15' &&
          // storeList[0].StoreType__c != '30' &&
          // storeList[0].StoreType__c != '33' &&
          // storeList[0].StoreType__c != '35' &&
          // storeList[0].StoreGroupCode__c != '14' &&
          // storeTypeFour != '15'

          // 매장 구분이 아울렛(20, 25)인 경우 포인트 적립 X
          // 26.04.09 GD 수정 : StoreType__c '33' 제외 조건 수정 start
          storeList[0].StoreType__c != '20' &&
          storeList[0].StoreType__c != '25' &&
          storeList[0].StoreType__c != '33'
        ) {
          // 26.04.09 GD 수정 : StoreType__c '33' 제외 조건 수정 end
          // List<PointCreditDTO> creditPointList = getPointService().creditPointsOnPurchase(tjList);
          Long creditPointStartMs = Datetime.now().getTime();
          Integer creditPointStartCpu = Limits.getCpuTime();
          List<PointCreditDTO> creditPointList = pointSvc.creditPointsOnPurchaseV2(tjList, excludeAmount);
          logTiming('createSaleDepositHistory.creditPointsOnPurchaseV2', creditPointStartMs, creditPointStartCpu);
          List<PointCreditDTO> totalCreditPointList = new List<PointCreditDTO>();
          if (creditPointList != null && creditPointList.size() > 0) {
            for (PointCreditDTO pcDto : creditPointList) {
              pcDto.AM_SAL = actualPaymentAmount; // 판매 금액
              pcDto.ID_INSERT = insertId; // 등록자
              pcDto.NO_PROM_MBR = promotionNo; // 프로모션 번호
              pcDto.NO_GRADE_ADVAN = cList[0].Grade__c; // 승급번호
            }
            totalCreditPointList.addAll(creditPointList);
          }
          Long promotionCreditPointStartMs = Datetime.now().getTime();
          Integer promotionCreditPointStartCpu = Limits.getCpuTime();
          List<PointCreditDTO> promotionCreditPointList = pointSvc.creditPromotionPointsOnPurchase(tjList, excludeAmount);
          logTiming('createSaleDepositHistory.creditPromotionPointsOnPurchase', promotionCreditPointStartMs, promotionCreditPointStartCpu);
          if (promotionCreditPointList != null && promotionCreditPointList.size() > 0) {
            totalCreditPointList.addAll(promotionCreditPointList);
          }
          if (!totalCreditPointList.isEmpty()) {
            for (PointCreditDTO pcDto : totalCreditPointList) {
              pcDto.AM_SAL = actualPaymentAmount;
              pcDto.ID_INSERT = insertId;
              pcDto.NO_PROM_MBR = promotionNo;
              pcDto.NO_GRADE_ADVAN = cList[0].Grade__c;
            }
            data.put('CreditPointList', totalCreditPointList);
          }
        }
      }

      logTiming('createSaleDepositHistory.total (self)', totalStartMs, totalStartCpu);
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
      Set<String> requestedDepositNoSet = new Set<String>();
      for (Object v : transactionJournalList) {
        Map<String, Object> transactionJournal = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);
        String depositNo = ValidationUtil.stringValidation(transactionJournal.get('DepositNo__c'), 'DepositNo__c', true);
        String deposiSeqNo = ValidationUtil.stringValidation(transactionJournal.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true);
        String depositKey = depositNo + '-' + deposiSeqNo;
        if (requestedDepositNoSet.contains(depositKey)) {
          throw new CustomException(400, 'Duplicate deposit request is not allowed. DepositNo__c: ' + depositNo + ', DeposiSeqNo__c: ' + deposiSeqNo);
        }
        requestedDepositNoSet.add(depositKey);
      }
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액

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
      Map<String, TransactionJournal> existingTjMap = new Map<String, TransactionJournal>();
      Date endDate;

      if (!requestedDepositNoSet.isEmpty()) {
        for (TransactionJournal existingTj : [
          SELECT Id, DepositNo__c, TransactionAmount, PaymentMethod, DepositType__c, MemberId, LoyaltyProgramId, VoucherCode, Order.EndDate
          FROM TransactionJournal
          WHERE DepositNo__c IN :requestedDepositNoSet AND SaleId__c = :orderId AND IsDeleted__c = FALSE
          LIMIT 2000
        ]) {
          existingTjMap.put(existingTj.DepositNo__c, existingTj);
          if (existingTj.Order.EndDate != null) {
            endDate = existingTj.Order.EndDate;
          }
        }
      }

      Set<String> depositNoSet = new Set<String>();

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
        TransactionJournal existingTj = existingTjMap.get(depositNo);

        // 고재성
        if (depositType == '03' || depositType == '05') {
          totalTransactionAmount -= transactionAmount;
        } else {
          totalTransactionAmount += transactionAmount;
        }

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
          if (shouldSkipExistingCouponReplay(existingTj, paymentMethod, depositType, couponNo)) {
            continue;
          }
          validateUnsupportedCouponChange(existingTj, paymentMethod, depositType, couponNo);

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
          if (shouldSkipExistingPointReplay(existingTj, depositType, transactionAmount)) {
            continue;
          }
          validateUnsupportedPointChange(existingTj, depositType, transactionAmount);

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
        }
      }

      // 신규 로직 (고든 26-04-01) start
      if (totalTransactionAmount > actualPaymentAmount) {
        // 총 입금 금액이 판매 금액보다 많을 경우 => 에러 처리
        throw new CustomException(
          400,
          '총 입금 금액이 실제 결제해야 할 금액을 초과했습니다. 총 입금 금액 : ' +
            totalTransactionAmount +
            ' | 실제 결제 금액 : ' +
            actualPaymentAmount
        );
      }
      // 신규 로직 (고든 26-04-01) end

      // 일반 결제 차액 계산 + 원 입금 upsert + 포인트 보정 처리
      if (!depositNoSet.isEmpty()) {
        // (1) 기존 원 입금 조회 (업데이트 전)
        Map<String, TransactionJournal> oldTjMap = new Map<String, TransactionJournal>();
        for (String depositKey : depositNoSet) {
          TransactionJournal oldTj = existingTjMap.get(depositKey);
          if (oldTj == null) {
            continue;
          }
          oldTjMap.put(oldTj.DepositNo__c, oldTj);
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

        //String grade = getMemberTierService().resolveAccrualGrade(lpmList[0].Id, endDate);
        // 신규 로직 (고든 26-04-01) start.
        String grade = resolveAccrualGrade(lpmList[0].Id, endDate);
        // 신규 로직 (고든 26-04-01) end.

        // 포인트 지급 할 건 있는 경우
        if (!creditTjList.isEmpty()) {
          System.debug('추가 지급할 건 있습니다.');
          Order o = [SELECT Id, StoreCode__r.StoreType__c, StoreCode__r.StoreGroupCode__c FROM Order WHERE id = :orderId LIMIT 1];
          // 매장 구분이 아울렛(20, 25)인 경우 포인트 적립 X
          // 26.04.04 WT 수정 : StoreType__c '15', '30', '33', '35'와 StoreGroupCode__c '14' 제외 조건 추가
          if (
            // o.StoreCode__r.StoreType__c != '20' &&
            // o.StoreCode__r.StoreType__c != '25' &&
            // o.StoreCode__r.StoreType__c != '15' &&
            // o.StoreCode__r.StoreType__c != '30' &&
            // o.StoreCode__r.StoreType__c != '33' &&
            // o.StoreCode__r.StoreType__c != '35' &&
            // o.StoreCode__r.StoreGroupCode__c != '14'

            // 매장 구분이 아울렛(20, 25)인 경우 포인트 적립 X
            // 26.04.09 GD 수정 : StoreType__c '33' 제외 조건 수정 start
            o.StoreCode__r.StoreType__c != '20' &&
            o.StoreCode__r.StoreType__c != '25' &&
            o.StoreCode__r.StoreType__c != '33'
          ) {
            // 26.04.09 GD 수정 : StoreType__c '33' 제외 조건 수정 end
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
   * 판매 입금 수정 V2
   * @version 2.0
   *
   * @param reqData 요청 값
   * @return ApiResult 판매 입금 이력 수정 결과
   * @throws CustomException
   */
  public ApiResult upsertSaleDepositV2(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      List<Object> transactionJournalList = ValidationUtil.listObjValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      Set<String> requestedDepositNoSet = new Set<String>();
      for (Object v : transactionJournalList) {
        Map<String, Object> transactionJournal = ValidationUtil.mapStrObjValidation(v, 'TransactionJournal', true);
        String depositNo = ValidationUtil.stringValidation(transactionJournal.get('DepositNo__c'), 'DepositNo__c', true);
        String deposiSeqNo = ValidationUtil.stringValidation(transactionJournal.get('DeposiSeqNo__c'), 'DeposiSeqNo__c', true);
        String depositKey = depositNo + '-' + deposiSeqNo;
        if (requestedDepositNoSet.contains(depositKey)) {
          throw new CustomException(400, 'Duplicate deposit request is not allowed. DepositNo__c: ' + depositNo + ', DeposiSeqNo__c: ' + deposiSeqNo);
        }
        requestedDepositNoSet.add(depositKey);
      }
      Decimal actualPaymentAmount = ValidationUtil.decimalValidation(reqData.get('ActualPaymentAmount__c'), 'ActualPaymentAmount__c', false); // 판매 금액

      String requestedPointDepositNo; // 요청된 포인트 입금 번호
      String requestedCouponDepositNo; // 요청된 쿠폰 입금 번호

      String orderId = ValidationUtil.stringValidation(reqData.get('orderId'), 'orderId', true); // Order Id

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

      String existingPointDepositNo; // 기존 포인트 입금 번호
      String existingCouponDepositNo; // 기존 쿠폰 입금 번호

      // 해당 판매 건에 기존 포인트, 쿠폰 입금 건들 조회
      // [기존 코드 시작] 2026-04-23
      // for (TransactionJournal existingTj : [
      //   SELECT Id, DepositNo__c, PaymentMethod, VoucherCode
      //   FROM TransactionJournal
      //   WHERE MemberId = :lpmList[0].Id AND SaleId__c = :orderId AND IsDeleted__c = FALSE AND PaymentMethod != NULL AND PaymentMethod IN ('81', '90') // 포인트 또는 쿠폰
      //   LIMIT 2000
      // ]) {
      // [기존 코드 끝] 2026-04-23

      // [수정 코드 시작] 2026-04-23 - DepositType__c IN ('01','02') 추가.
      //   DELETE /sale/deposit 경로가 취소 역입금(DT=03) TJ 를 'del_point_*' / 'del_coupon_*' 네이밍으로 신규 insert 하는데, 이 TJ 들은 IsDeleted=FALSE, PM=81/90 이지만
      //   "활성 사용중" 이 아닌 "이미 취소된 역입금" 이므로 existingPointDepositNo/existingCouponDepositNo 판별에서 제외되어야 함.
      //   DT=03 을 포함하면 후속 PATCH /sale 시점에 원본 DepositNo 와 불일치 판정되어 "한 판매에서는 포인트 입금 건을 하나만 사용할 수 있습니다." 오차단이 발생.
      for (TransactionJournal existingTj : [
        SELECT Id, DepositNo__c, PaymentMethod, VoucherCode
        FROM TransactionJournal
        WHERE MemberId = :lpmList[0].Id AND SaleId__c = :orderId AND IsDeleted__c = FALSE AND PaymentMethod != NULL AND PaymentMethod IN ('81', '90') AND DepositType__c IN ('01', '02') // 포인트 또는 쿠폰 (활성 사용만, 취소 역입금 제외)
        LIMIT 2000
      ]) {
      // [수정 코드 끝] 2026-04-23
        if ('81'.equals(existingTj.PaymentMethod)) {
          existingPointDepositNo = existingTj.DepositNo__c;
        } else if ('90'.equals(existingTj.PaymentMethod)) {
          existingCouponDepositNo = existingTj.DepositNo__c;
        }
      }

      List<GdSaleApiController.PointDebitDTO> debitPointList = new List<GdSaleApiController.PointDebitDTO>();
      List<TransactionJournal> requestedGeneralTjList = new List<TransactionJournal>();
      List<TransactionJournal> existingGeneralDepositList = new List<TransactionJournal>();
      Map<String, TransactionJournal> existingGeneralDepositMap = new Map<String, TransactionJournal>();
      Id salePromotionId;
      for (TransactionJournal existingGeneralTj : [
        SELECT Id, DepositNo__c, JournalDate, TransactionAmount, PaymentMethod, DepositType__c, PromotionId
        FROM TransactionJournal
        WHERE SaleId__c = :orderId AND IsDeleted__c = FALSE AND PaymentMethod != NULL AND PaymentMethod NOT IN ('81', '90')
        LIMIT 2000
      ]) {
        existingGeneralDepositList.add(existingGeneralTj);
        existingGeneralDepositMap.put(existingGeneralTj.DepositNo__c, existingGeneralTj);
        if (salePromotionId == null && existingGeneralTj.PromotionId != null) {
          salePromotionId = existingGeneralTj.PromotionId;
        }
      }
      if (salePromotionId == null) {
        List<TransactionJournal> salePromotionTjList = [
          SELECT PromotionId
          FROM TransactionJournal
          WHERE SaleId__c = :orderId AND IsDeleted__c = FALSE AND PromotionId != NULL
          LIMIT 1
        ];
        if (!salePromotionTjList.isEmpty()) {
          salePromotionId = salePromotionTjList[0].PromotionId;
        }
      }

      Boolean saleAccrualArtifactsDeleted = false;
      Boolean generalPaymentChanged = false;

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
        TransactionJournal existingTj = existingGeneralDepositMap.get(depositNo);

        if (String.isNotBlank(couponNo) && !'90'.equals(paymentMethod)) {
          throw new CustomException(400, 'CouponNo is only allowed when PaymentMethod is 90.');
        }
        if ('90'.equals(paymentMethod) && String.isBlank(couponNo)) {
          throw new CustomException(400, 'CouponNo is required when PaymentMethod is 90.');
        }

        if ('81'.equals(paymentMethod)) {
          if (String.isNotBlank(existingPointDepositNo) && existingPointDepositNo != depositNo) {
            throw new CustomException(
              400,
              '한 판매에서는 포인트 입금 건을 하나만 사용할 수 있습니다.'
              // '한 판매에서는 포인트 입금 건을 하나만 사용할 수 있습니다. 기존 입금번호: ' + existingPointDepositNo + ', 요청 입금번호: ' + depositNo
            );
          }
          if (String.isNotBlank(requestedPointDepositNo) && requestedPointDepositNo != depositNo) {
            throw new CustomException(400, '한 판매에서는 포인트 입금 건을 하나만 사용할 수 있습니다.');
          }
          requestedPointDepositNo = depositNo;
          // [기존 코드 시작] 2026-04-22
          // continue;
          // [기존 코드 끝] 2026-04-22

          // [수정 코드 시작] 2026-04-22 - 무조건 continue 가 PATCH /sale 의 신규 포인트 TJ INSERT + debitPoint 호출 경로를 차단하던 버그 수정.
          //   기존 DepositNo 와 동일한 재요청(멱등) 은 계속 skip 하되, 신규 DepositNo 는 아래 라인 911 포인트 분기로 fall-through 하여
          //   debitPoint(tj) / cancelPointRedemption(tj) 가 정상 호출되도록 함.
          if (String.isNotBlank(existingPointDepositNo) && existingPointDepositNo == depositNo) {
            continue;
          }
          // [수정 코드 끝] 2026-04-22
        }

        if (String.isNotBlank(couponNo) && '90'.equals(paymentMethod)) {
          if (String.isNotBlank(existingCouponDepositNo) && existingCouponDepositNo != depositNo) {
            throw new CustomException(
              400,
              '한 판매에서는 쿠폰 입금 건을 하나만 사용할 수 있습니다.'
              // '한 판매에서는 쿠폰 입금 건을 하나만 사용할 수 있습니다. 기존 입금번호: ' + existingCouponDepositNo + ', 요청 입금번호: ' + depositNo
            );
          }
          if (String.isNotBlank(requestedCouponDepositNo) && requestedCouponDepositNo != depositNo) {
            throw new CustomException(400, '한 판매에서는 쿠폰 입금 건을 하나만 사용할 수 있습니다.');
          }
          requestedCouponDepositNo = depositNo;
          // [기존 코드 시작] 2026-04-22
          // continue;
          // [기존 코드 끝] 2026-04-22

          // [수정 코드 시작] 2026-04-22 - 포인트 분기와 동일 원칙: 기존 DepositNo 재요청이면 멱등 skip, 신규 DepositNo 는 fall-through
          //   아래 라인 888 쿠폰 분기로 진행하여 redeemVoucherV2(tj) / redeemCancelVoucher(tj) 가 호출되도록 함.
          if (String.isNotBlank(existingCouponDepositNo) && existingCouponDepositNo == depositNo) {
            continue;
          }
          // [수정 코드 끝] 2026-04-22
        }

        // GD 수정 26-04-01 : 총 입금 금액 계산 로직 추가 start
        if (depositType == '03' || depositType == '05') {
          totalTransactionAmount -= transactionAmount;
        } else {
          totalTransactionAmount += transactionAmount;
        }
        // GD 수정 26-04-01 : 총 입금 금액 계산 로직 추가 end

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
          if (shouldSkipExistingCouponReplay(existingTj, paymentMethod, depositType, couponNo)) {
            continue;
          }
          validateUnsupportedCouponChange(existingTj, paymentMethod, depositType, couponNo);

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
        else if ('81'.equals(paymentMethod)) {
          if (shouldSkipExistingPointReplay(existingTj, depositType, transactionAmount)) {
            continue;
          }
          validateUnsupportedPointChange(existingTj, depositType, transactionAmount);

          if ('03'.equals(depositType)) {
            // 포인트 사용 취소
            Map<String, Object> cancelPointResult = getPointService().cancelPointRedemption(tj);
            data.put('CancelPointList', cancelPointResult);
          } else if ('01'.equals(depositType) || '02'.equals(depositType)) {
            // 포인트 사용 — 판매 수정 전용 커스텀 DML 경로 (same-sale 적립 제외, 2026-04-23 V2-SCN06 fix)
            debitPointList = getPointService().debitPointForSaleUpdate(tj);
            data.put('DebitPointList', debitPointList);
          } else {
            throw new CustomException(400, '확인되지 않는 입금 구분 값 입니다. ' + depositType);
          }
        }
        // 일반 결제 일 경우
        else {
          if ('03'.equals(depositType) || '05'.equals(depositType)) {
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true);
          } else {
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_DEPOSIT, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true);
          }
          if (salePromotionId != null) {
            tj.PromotionId = salePromotionId;
          }

          if (false && existingTj != null) {
            Boolean isSameActivityDate = existingTj.JournalDate == activityDate;
            Boolean isSameTransactionAmount = existingTj.TransactionAmount == transactionAmount;
            Boolean isSameDepositType = existingTj.DepositType__c == depositType;
            Boolean isSamePaymentMethod = existingTj.PaymentMethod == paymentMethod;

            if (isSameActivityDate && isSameTransactionAmount && isSameDepositType && isSamePaymentMethod) {
              continue;
            } else {
              if (!saleAccrualArtifactsDeleted) {
                // 해당 판매 건의 포인트 적립 건 취소 처리
                saleAccrualArtifactsDeleted = saleAccrualArtifactsDeleted;
              }

              generalPaymentChanged = generalPaymentChanged;
              delete existingTj;
              existingGeneralDepositMap.remove(depositNo);
            }
          } else {
            if (!saleAccrualArtifactsDeleted) {
              // 해당 판매 건의 포인트 적립 건 취소 처리
              saleAccrualArtifactsDeleted = saleAccrualArtifactsDeleted;
            }
            generalPaymentChanged = generalPaymentChanged;
          }

          tj.Status = 'Processed';
          requestedGeneralTjList.add(tj);
        }
      }

      if (actualPaymentAmount == null) {
        throw new CustomException(400, 'ActualPaymentAmount__c is required.');
      }

      if (totalTransactionAmount > actualPaymentAmount) {
        throw new CustomException(
          400,
          '총 입금 금액이 실제 결제해야 할 금액을 초과했습니다. 총 입금 금액 : ' +
            totalTransactionAmount +
            ' | 실제 결제 금액 : ' +
            actualPaymentAmount
        );
      }

      List<TransactionJournal> deleteGeneralTjList = buildGeneralPaymentDeleteList(existingGeneralDepositList, requestedGeneralTjList);
      List<TransactionJournal> insertGeneralTjList = buildGeneralPaymentInsertList(existingGeneralDepositList, requestedGeneralTjList);
      if (!deleteGeneralTjList.isEmpty() || !insertGeneralTjList.isEmpty()) {
        generalPaymentChanged = true;
        validateSaleAccrualPointsNotUsedInOtherSaleOrOrder((Id) orderId);

        if (!saleAccrualArtifactsDeleted) {
          deleteSaleAccrualArtifactsForGeneralPaymentChange((Id) orderId, lpmList[0].Id);
          saleAccrualArtifactsDeleted = true;
        }

        if (!deleteGeneralTjList.isEmpty()) {
          System.debug('진입1');
          delete deleteGeneralTjList;
          System.debug('진입1-1');
        }

        if (!insertGeneralTjList.isEmpty()) {
          List<Database.SaveResult> insertResults = Database.insert(insertGeneralTjList, false);
          for (Database.SaveResult r : insertResults) {
            if (!r.isSuccess()) {
              Database.Error err = r.getErrors()[0];
              throw new CustomException(400, err.getMessage());
            }
          }
        }
      }

      if (generalPaymentChanged && !requestedGeneralTjList.isEmpty()) {
        recreateSaleAccrualArtifactsForGeneralPaymentChange((Id) orderId, actualPaymentAmount, data);
      }

      // if (!depositNoSet.isEmpty()) {
      //   // (1) 기존 원 입금 조회 (업데이트 전)
      //   Map<String, TransactionJournal> oldTjMap = new Map<String, TransactionJournal>();
      //   for (String depositKey : depositNoSet) {
      //     TransactionJournal oldTj = existingTjMap.get(depositKey);
      //     if (oldTj == null) {
      //       continue;
      //     }
      //     oldTjMap.put(oldTj.DepositNo__c, oldTj);
      //   }

      //   // (2) 원 입금 Upsert
      //   List<Database.UpsertResult> upsertResults = Database.upsert(newTjList, TransactionJournal.DepositNo__c);
      //   for (Database.UpsertResult r : upsertResults) {
      //     if (!r.isSuccess()) {
      //       Database.Error err = r.getErrors()[0];
      //       throw new CustomException(400, err.getMessage());
      //     }
      //   }

      //   List<Map<String, Object>> creditTjList = new List<Map<String, Object>>();
      //   List<Map<String, Object>> debitTjList = new List<Map<String, Object>>();

      // for (TransactionJournal newTj : newTjList) {
      //   TransactionJournal oldTj = oldTjMap.get(newTj.DepositNo__c);

      //   // 기존/신규 적립 대상 여부
      //   Boolean oldEligible = (oldTj != null) ? getPointService().isAccrualEligible(oldTj) : false;
      //   Boolean newEligible = getPointService().isAccrualEligible(newTj);

      //   // 멱등키 설정
      //   String newHash = buildAccrualHash(newTj) + '|' + String.valueOf(newEligible);
      //   String oldHash = (oldTj == null) ? null : (buildAccrualHash(oldTj) + '|' + String.valueOf(oldEligible));

      //   // 이전에 같은 조건으로 이미 반영했으면 스킵
      //   if (oldHash == newHash) {
      //     continue;
      //   }

      //   // 조정 할 금액
      //   Decimal adjust = 0;

      //   // 이전 tj 가 적립 대상 O && 신규 tj 가 적립 대상 O => 차액 만큼 적립 | 차감
      //   if (oldEligible && newEligible) {
      //     System.debug('이전 tj 가 적립 대상 O && 신규 tj 가 적립 대상 O => 차액 만큼 적립 | 차감');
      //     // 신규 입금 금액 - 기존 입금 금액
      //     // adjust 가 + 일 경우 포인트 추가 적립 | - 일 경우 포인트 적립 부분 취소
      //     adjust = newTj.TransactionAmount - oldTj.TransactionAmount;
      //   }
      //   // 이전 tj 가 적립 대상 O && 신규 tj 가 적립 대상 X => 이전 tj에 적립 된 금액 만큼 차감
      //   else if (oldEligible && !newEligible) {
      //     System.debug('이전 tj 가 적립 대상 O && 신규 tj 가 적립 대상 X => 이전 tj에 적립 된 금액 만큼 차감');
      //     // 기존 입금 금액 만큼 포인트 적립 취소
      //     adjust -= oldTj.TransactionAmount;
      //   }
      //   // 이전 tj 가 적립 대상 X && 신규 tj 가 적립 대상 O => 신규 tj에 금액 만큼 지급
      //   else if (!oldEligible && newEligible) {
      //     System.debug('이전 tj 가 적립 대상 X && 신규 tj 가 적립 대상 O => 신규 tj에 금액 만큼 지급');
      //     // 신규 입금 금액 만큼 포인트 추가 적립
      //     adjust += newTj.TransactionAmount;
      //   } else {
      //     System.debug('이전 tj 가 적립 대상 X && 신규 tj 가 적립 대상 X => 추가 지급/차감 없음');
      //     // 이전 tj 가 적립 대상 X && 신규 tj 가 적립 대상 X => 추가 지급/차감 없음
      //     continue;
      //   }
      //   Map<String, Object> m = new Map<String, Object>();
      //   m.put('TransactionJournal', newTj);

      //   if (adjust > 0) {
      //     m.put('adjustAmount', adjust);
      //     m.put('AdditionalNotes__c', '판매 입금 수정 API 요청에 의한 포인트 추가 적립');
      //     creditTjList.add(m);
      //   } else if (adjust < 0) {
      //     m.put('adjustAmount', Math.abs(adjust));
      //     m.put('AdditionalNotes__c', '판매 입금 수정 API 요청에 의한 포인트 적립 취소');
      //     debitTjList.add(m);
      //   }
      // }

      //String grade = getMemberTierService().resolveAccrualGrade(lpmList[0].Id, endDate);
      // 고재성
      // String grade = resolveAccrualGrade(lpmList[0].Id, endDate);

      // 포인트 지급 할 건 있는 경우
      // if (!creditTjList.isEmpty()) {
      //   System.debug('추가 지급할 건 있습니다.');
      //   Order o = [SELECT Id, StoreCode__r.StoreType__c, StoreCode__r.StoreGroupCode__c FROM Order WHERE id = :orderId LIMIT 1];
      //   // 매장 구분이 아울렛(20, 25)인 경우 포인트 적립 X
      //   // 26.04.04 WT 수정 : StoreType__c '15', '30', '33', '35'와 StoreGroupCode__c '14' 제외 조건 추가
      //   if (
      //     o.StoreCode__r.StoreType__c != '20' &&
      //     o.StoreCode__r.StoreType__c != '25' &&
      //     o.StoreCode__r.StoreType__c != '33'
      //   ) {
      //     for (Map<String, Object> creditReqData : creditTjList) {
      //       creditReqData.put('Grade__c', grade);
      //       // 포인트 지급
      //       List<PointCreditDTO> creditResult = getPointService().creditPointsOnPurchaseByGrade(creditReqData);
      //       data.put('CreditPointList', creditResult);
      //     }
      //   }
      // }

      // 포인트 지급 취소 할 건 있는 경우
      //   if (!debitTjList.isEmpty()) {
      //     System.debug('지급 취소할 건 있습니다.');

      //     for (Map<String, Object> debitReqData : debitTjList) {
      //       debitReqData.put('Grade__c', grade);
      //       // 포인트 지급 취소
      //       List<PointDebitDTO> debitResult = getPointService().debitPointsOnPurchaseByGrade(debitReqData);
      //       data.put('CancelPointList', debitResult);
      //     }
      //   }
      // }

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

      // 기존
      // List<TransactionJournal> tjList = [
      //   SELECT Id, PaymentMethod, DepositType__c, TransactionAmount, OrderId__c, VoucherCode
      //   FROM TransactionJournal
      //   WHERE OrderId = :oList[0].Id
      //   LIMIT 100
      // ];

      // 26.05.01 GD - 회원 ID 조회 추가
      List<TransactionJournal> tjList = [
        SELECT Id, PaymentMethod, DepositType__c, TransactionAmount, OrderId__c, VoucherCode, MemberId
        FROM TransactionJournal
        WHERE OrderId = :oList[0].Id
        LIMIT 100
      ];
      //

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
          // 기존
          // List<Voucher> vList = [
          //   SELECT Id, VoucherDefinition.Name, VoucherCode, ExpirationDate, DiscountPercent, FaceValue, Reason
          //   FROM Voucher
          //   WHERE VoucherCode = :tj.VoucherCode
          //   LIMIT 1
          // ];

          // 26.05.01 GD - 쿠폰 코드 분할 쿠폰 조회
          String searchVoucherCode = tj.VoucherCode;
          List<Voucher> vList = new List<Voucher>();

          if (String.isNotBlank(searchVoucherCode) && searchVoucherCode.contains(';-;')) {
              String couponManNo = searchVoucherCode.substringBefore(';-;');
              String realVoucherCode = searchVoucherCode.substringAfter(';-;'); 
              
              vList = [
                  SELECT Id, VoucherDefinition.Name, VoucherCode, ExpirationDate, DiscountPercent, FaceValue, Reason
                  FROM Voucher
                  WHERE VoucherCode = :realVoucherCode
                    AND VoucherDefinition.CouponManNo__c = :couponManNo
                    AND LoyaltyProgramMemberId = : tj.MemberId
                  LIMIT 1
              ];
              
          } else {
              vList = [
                  SELECT Id, VoucherDefinition.Name, VoucherCode, ExpirationDate, DiscountPercent, FaceValue, Reason
                  FROM Voucher
                  WHERE VoucherCode = :searchVoucherCode
                    AND LoyaltyProgramMemberId = : tj.MemberId
                  LIMIT 1
              ];
          }
          //

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
          PromotionId,
          SaleId__c,
          OrderId__c,
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

      // 신규 로직 (하나 26-04-09) start.
      List<GdSaleApiController.PointDebitDTO> promotionPointAccrualCanceled = cancelPromotionPointsCreditedOnSaleDelete(tjList);
      data.put('promotionPointAccrualCanceled', promotionPointAccrualCanceled);
      // 신규 로직 (하나 26-04-09) end.

      return ApiResult.ok(200, '판매 입금 전체 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // 신규 로직 (하나 26-04-09) start.
  //프로모션 포인트 적립 취소 로직 (판매 입금 전체 삭제 시)
  private List<GdSaleApiController.PointDebitDTO> cancelPromotionPointsCreditedOnSaleDelete(List<TransactionJournal> tjList) {
    if (tjList == null || tjList.isEmpty()) {
      return null;
    }

    List<TransactionJournal> promotionDepositList = new List<TransactionJournal>();
    for (TransactionJournal tj : tjList) {
      if (tj != null && tj.PromotionId != null) {
        promotionDepositList.add(tj);
      }
    }

    if (promotionDepositList.isEmpty()) {
      return null;
    }

    return getPointService().cancelPointsCreditedOnPurchase(promotionDepositList);
  }
  // 신규 로직 (하나 26-04-09) end.

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
          PromotionId,
          OrderId__c,
          SaleId__c,
          DepositNo__c,
          IsDeleted__c,
          DeleteDateTime__c,
          VoucherCode
        FROM TransactionJournal
        WHERE DepositNo__c = :depositNo AND IsDeleted__c = FALSE AND SaleId__c != NULL
        LIMIT 1
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 판매 입금 이력이 존재하지 않습니다. ' + depositNo);
      }

      Id pointDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, true);
      Id couponRedeemJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);

      // 포인트 사용 취소
      if (tjList[0].JournalSubTypeId == pointDebitJstId || tjList[0].JournalSubTypeId == couponRedeemJstId) {
        if (tjList[0].OrderId__c == null) {
          TransactionJournal newTj = tjList[0].clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
          newTj.JournalDate = Datetime.now();
          newTj.ActivityDate = Datetime.now();
          newTj.DepositType__c = '03'; // 03 : 환불

          if (tjList[0].JournalSubTypeId == pointDebitJstId) {
            newTj.DepositNo__c = 'del_point_' + tjList[0].DepositNo__c; // Carson 수정 2026-04-17
            // 포인트 사용 취소
            // newTj.Status = 'Pending';
            Map<String, Object> pointRedemptionCanceled = new Map<String, Object>();
            pointRedemptionCanceled = getPointService().cancelPointRedemption(newTj);
            data.put('pointRedemptionCanceled', pointRedemptionCanceled);
          } else {
            newTj.DepositNo__c = 'del_coupon_' + tjList[0].DepositNo__c; // Carson 수정 2026-04-17
            // 쿠폰 사용 취소
            newTj.Status = 'Processed';
            ApiResult voucherResult = getVoucherService().redeemCancelVoucher(newTj);
            data.put('couponCanceled', voucherResult.data);
          }
        }
      } else {
        if (tjList[0].OrderId__c == null) {
          // 다른 주문/판매 건에서 포인트 사용했는지 확인
          List<LoyaltyLedgerTraceability> lltList = [
            SELECT
              Id,
              DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
              DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
              DebitLoyaltyLedger.TransactionJournal.DepositNo__c,
              DebitLoyaltyLedger.TransactionJournal.IsDeleted__c,
              DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c
            FROM LoyaltyLedgerTraceability
            WHERE
              CreditLoyaltyLedger.TransactionJournal.OrderId = :tjList[0].OrderId
              AND ActionType = 'Debit'
              AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
              AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
              OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
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
        }

        // 구매 시 지급된 포인트 적립 취소
        List<GdSaleApiController.PointDebitDTO> purchasePointAccrualCanceled = getPointService().cancelPointsCreditedOnPurchase(tjList);
        data.put('purchasePointAccrualCanceled', purchasePointAccrualCanceled);
      }

      // 주문에서 넘어온 입금 건일 경우
      if (tjList[0].OrderId__c != null) {
        tjList[0].SaleId__c = null;
      } else {
        tjList[0].IsDeleted__c = true;
        tjList[0].DeleteDateTime__c = Datetime.now();
        tjList[0].DepositNo__c = 'del_' + tjList[0].DepositNo__c; // Carson 수정 2026-04-14 추가
      }

      update tjList[0];

      return ApiResult.ok(200, '판매 입금 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 판매 입금 삭제 V2
   *
   * @version V2.0
   * @since 2026-04-13
   * @author Changhwan Kim
   */
  public ApiResult deleteSaleDepositV2(String depositNo) {
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
          OrderId__c,
          SaleId__c,
          DepositNo__c,
          IsDeleted__c,
          DeleteDateTime__c,
          VoucherCode
        FROM TransactionJournal
        WHERE DepositNo__c = :depositNo AND IsDeleted__c = FALSE AND SaleId__c != NULL
        LIMIT 1
      ];
      if (tjList.isEmpty()) {
        throw new CustomException(400, '해당 판매 입금 이력이 존재하지 않습니다. ' + depositNo);
      }

      Id pointDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, true);
      Id couponRedeemJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM, true);

      // 포인트 사용 취소
      if (tjList[0].JournalSubTypeId == pointDebitJstId || tjList[0].JournalSubTypeId == couponRedeemJstId) {
        if (tjList[0].OrderId__c == null) {
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
        }
      } else {
        if (tjList[0].OrderId__c == null) {
          // 다른 주문/판매 건에서 포인트 사용했는지 확인
          List<LoyaltyLedgerTraceability> lltList = [
            SELECT
              Id,
              DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
              DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
              DebitLoyaltyLedger.TransactionJournal.DepositNo__c,
              DebitLoyaltyLedger.TransactionJournal.IsDeleted__c,
              DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c
            FROM LoyaltyLedgerTraceability
            WHERE
              CreditLoyaltyLedger.TransactionJournal.OrderId = :tjList[0].OrderId
              AND ActionType = 'Debit'
              AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
              AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
              OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
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
        }

        // 구매 시 지급된 포인트 적립 취소
        List<GdSaleApiController.PointDebitDTO> purchasePointAccrualCanceled = getPointService().cancelPointsCreditedOnPurchase(tjList);
        data.put('purchasePointAccrualCanceled', purchasePointAccrualCanceled);
      }

      // 주문에서 넘어온 입금 건일 경우
      if (tjList[0].OrderId__c != null) {
        tjList[0].SaleId__c = null;
      } else {
        tjList[0].IsDeleted__c = true;
        tjList[0].DeleteDateTime__c = Datetime.now();
      }

      update tjList[0];

      return ApiResult.ok(200, '판매 입금 삭제 완료', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // 판매 입금 수정 시 기존 적립 건 정리하는 메서드
  private void deleteSaleAccrualArtifactsForGeneralPaymentChange(Id orderId, Id loyaltyMemberId) {
    System.debug('판매 입금 수정 시 기존 적립 건 정리합니다 ~~~');
    // orderId : 판매 Id
    // loyaltyMemberId : 판매한 회원의 로열티 프로그램 멤버 Id

    if (orderId == null || loyaltyMemberId == null) {
      return;
    }

    // 거래 하위 유형
    Set<String> targetSubTypeNames = new Set<String>{
      JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL,
      JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL,
      JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL,
      JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL
    };
    Map<String, Id> subTypeIdByName = new Map<String, Id>();
    for (JournalSubType subType : [SELECT Id, Name FROM JournalSubType WHERE Name IN :targetSubTypeNames]) {
      subTypeIdByName.put(subType.Name, subType.Id);
    }

    Set<Id> targetSubTypeIds = new Set<Id>();
    targetSubTypeIds.addAll(subTypeIdByName.values());
    if (targetSubTypeIds.isEmpty()) {
      return;
    }

    // 해당 판매 건의 포인트 적립/적립 취소 내역 조회
    List<TransactionJournal> targetTjList = [
      SELECT Id, JournalSubTypeId
      FROM TransactionJournal
      WHERE OrderId = :orderId AND IsDeleted__c = FALSE AND JournalSubTypeId IN :targetSubTypeIds
      LIMIT 2000
    ];
    if (targetTjList.isEmpty()) {
      return;
    }

    Map<Id, TransactionJournal> targetTjById = new Map<Id, TransactionJournal>(targetTjList);
    Set<Id> targetTjIds = targetTjById.keySet();

    List<LoyaltyLedger> allLedgerList = [
      SELECT Id, TransactionJournalId, LoyaltyProgramMemberId, ExpiryDate, EventType, Points, LoyaltyPgmCrcySubtypeId, LoyaltyPgmCrcySubtype.Name
      FROM LoyaltyLedger
      WHERE TransactionJournalId IN :targetTjIds AND LoyaltyProgramMemberId = :loyaltyMemberId
      LIMIT 50000
    ];
    Set<Id> targetLedgerIds = new Set<Id>();
    for (LoyaltyLedger ledger : allLedgerList) {
      targetLedgerIds.add(ledger.Id);
    }

    // 적립 로열티 레저 조회
    List<LoyaltyLedger> ledgerList = allLedgerList;

    Decimal totalAvailablePoints = 0; // 지급했던 포인트 총 금액
    Decimal netAccruedPoints = 0;
    Map<String, AggrDelta> deltaByKey = new Map<String, AggrDelta>();
    Set<Id> subtypeIds = new Set<Id>();
    Set<Date> expiryDates = new Set<Date>();
    for (LoyaltyLedger ledger : ledgerList) {
      String key = buildAggrLedgerKey(ledger.LoyaltyProgramMemberId, ledger.LoyaltyPgmCrcySubtypeId, ledger.ExpiryDate);
      AggrDelta delta = deltaByKey.containsKey(key) ? deltaByKey.get(key) : new AggrDelta();
      Decimal signedPoints = (ledger.Points == null ? 0 : ledger.Points);
      if ('Debit'.equals(ledger.EventType)) {
        signedPoints *= -1;
      }
      delta.currencySubTypeName = ledger.LoyaltyPgmCrcySubtype != null ? ledger.LoyaltyPgmCrcySubtype.Name : null;
      delta.accruedDelta += signedPoints;
      netAccruedPoints += signedPoints;
      deltaByKey.put(key, delta);
      subtypeIds.add(ledger.LoyaltyPgmCrcySubtypeId);
      expiryDates.add(ledger.ExpiryDate);
    }

    if (!deltaByKey.isEmpty() && !subtypeIds.isEmpty() && !expiryDates.isEmpty()) {
      Map<String, LoyaltyAggrSubPointExprLedger__c> aggrByKey = new Map<String, LoyaltyAggrSubPointExprLedger__c>();
      for (LoyaltyAggrSubPointExprLedger__c aggr : [
        SELECT
          Id,
          LoyaltyProgramMemberId__c,
          CurrencySubTypeId__c,
          ExpiryDate__c,
          RedeemedPoints__c,
          AccruedPoints__c,
          ExpiredPoints__c,
          CurrencySubTypeName__c
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE LoyaltyProgramMemberId__c = :loyaltyMemberId AND CurrencySubTypeId__c IN :subtypeIds AND ExpiryDate__c IN :expiryDates
        LIMIT 50000
      ]) {
        aggrByKey.put(buildAggrLedgerKey(aggr.LoyaltyProgramMemberId__c, aggr.CurrencySubTypeId__c, aggr.ExpiryDate__c), aggr);
      }

      List<LoyaltyAggrSubPointExprLedger__c> aggrUpdateList = new List<LoyaltyAggrSubPointExprLedger__c>();
      for (String key : deltaByKey.keySet()) {
        if (!aggrByKey.containsKey(key)) {
          continue;
        }
        LoyaltyAggrSubPointExprLedger__c aggr = aggrByKey.get(key);
        AggrDelta delta = deltaByKey.get(key);

        aggr.AccruedPoints__c = (aggr.AccruedPoints__c == null ? 0 : aggr.AccruedPoints__c) - delta.accruedDelta;
        aggrUpdateList.add(aggr);
      }
      if (!aggrUpdateList.isEmpty()) {
        update aggrUpdateList;
      }
    }

    Id pointCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

    List<LoyaltyMemberCurrency> memberCurrencyList = [
      SELECT Id, PointsBalance, TotalPointsAccrued
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :loyaltyMemberId AND LoyaltyProgramCurrencyId = :pointCurrencyId
      LIMIT 1
    ];
    if (!memberCurrencyList.isEmpty()) {
      memberCurrencyList[0].TotalPointsAccrued -= netAccruedPoints;
      update memberCurrencyList[0];
    }

    if (!targetLedgerIds.isEmpty()) {
      List<LoyaltyLedgerTraceability> safeDeleteTraceabilityList = new List<LoyaltyLedgerTraceability>();
      for (LoyaltyLedgerTraceability llt : [
        SELECT
          Id,
          CreditLoyaltyLedgerId,
          DebitLoyaltyLedgerId,
          CreditLoyaltyLedger.TransactionJournal.OrderId,
          CreditLoyaltyLedger.TransactionJournal.IsDeleted__c,
          CreditLoyaltyLedger.TransactionJournal.AdditionalNotes__c,
          DebitLoyaltyLedger.TransactionJournal.OrderId,
          DebitLoyaltyLedger.TransactionJournal.IsDeleted__c,
          DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c
        FROM LoyaltyLedgerTraceability
        WHERE (CreditLoyaltyLedgerId IN :targetLedgerIds OR DebitLoyaltyLedgerId IN :targetLedgerIds) AND LoyaltyProgramMemberId = :loyaltyMemberId
        LIMIT 50000
      ]) {
        Boolean isCreditTarget = targetLedgerIds.contains(llt.CreditLoyaltyLedgerId);
        Boolean isDebitTarget = targetLedgerIds.contains(llt.DebitLoyaltyLedgerId);
        Boolean creditSideSafe =
          llt.CreditLoyaltyLedger == null ||
          llt.CreditLoyaltyLedger.TransactionJournal == null ||
          llt.CreditLoyaltyLedger.TransactionJournal.IsDeleted__c == true ||
          llt.CreditLoyaltyLedger.TransactionJournal.OrderId == orderId ||
          llt.CreditLoyaltyLedger.TransactionJournal.AdditionalNotes__c == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE;
        Boolean debitSideSafe =
          llt.DebitLoyaltyLedger == null ||
          llt.DebitLoyaltyLedger.TransactionJournal == null ||
          llt.DebitLoyaltyLedger.TransactionJournal.IsDeleted__c == true ||
          llt.DebitLoyaltyLedger.TransactionJournal.OrderId == orderId ||
          llt.DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE;

        if ((isCreditTarget && debitSideSafe) || (isDebitTarget && creditSideSafe)) {
          safeDeleteTraceabilityList.add(llt);
        }
      }

      if (!safeDeleteTraceabilityList.isEmpty()) {
        delete safeDeleteTraceabilityList;
      }
    }

    if (!allLedgerList.isEmpty()) {
      System.debug('진입2');
      delete allLedgerList;
      System.debug('진입2-1');
    }

    System.debug('진입3');
    delete targetTjList;
    System.debug('진입3-1');
  }

  // 해당 판매 건에 적립된 포인트가 다른 판매/주문에서 사용된 건이 있는지 체크 (판매 수정 시)
  private void validateSaleAccrualPointsNotUsedInOtherSaleOrOrder(Id orderId) {
    if (orderId == null) {
      return;
    }

    Set<String> targetSubTypeNames = new Set<String>{ JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL };
    Set<Id> targetSubTypeIds = new Set<Id>();
    for (JournalSubType subType : [SELECT Id FROM JournalSubType WHERE Name IN :targetSubTypeNames]) {
      targetSubTypeIds.add(subType.Id);
    }
    if (targetSubTypeIds.isEmpty()) {
      return;
    }

    List<LoyaltyLedgerTraceability> lltList = [
      SELECT
        Id,
        DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
        DebitLoyaltyLedger.TransactionJournal.DepositNo__c,
        DebitLoyaltyLedger.TransactionJournal.OrderId,
        DebitLoyaltyLedger.TransactionJournal.IsDeleted__c,
        DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c
      FROM LoyaltyLedgerTraceability
      WHERE
        CreditLoyaltyLedger.TransactionJournal.OrderId = :orderId
        AND CreditLoyaltyLedger.TransactionJournal.JournalSubTypeId IN :targetSubTypeIds
        AND ActionType = 'Debit'
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND DebitLoyaltyLedger.TransactionJournal.OrderId != :orderId
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
      LIMIT 1
    ];
    if (lltList.isEmpty()) {
      return;
    }

    if (lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c != null) {
      throw new CustomException(
        400,
        '해당 판매에서 적립된 포인트가 다른 판매에서 이미 사용되어 판매 수정이 불가합니다. 판매번호: ' +
          lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c +
          ' / 입금번호: ' +
          lltList[0].DebitLoyaltyLedger.TransactionJournal.DepositNo__c
      );
    } else if (lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c != null) {
      throw new CustomException(
        400,
        '해당 판매에서 적립된 포인트가 다른 주문에서 이미 사용되어 판매 수정이 불가합니다. 주문번호: ' +
          lltList[0].DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c +
          ' / 입금번호: ' +
          lltList[0].DebitLoyaltyLedger.TransactionJournal.DepositNo__c
      );
    }

    throw new CustomException(400, '해당 판매에서 적립된 포인트가 다른 주문/판매에서 이미 사용되어 판매 수정이 불가합니다.');
  }

  // 판매 수정 시 포인트 재 계산해서 재 지급 처리
  private void recreateSaleAccrualArtifactsForGeneralPaymentChange(Id orderId, Decimal actualPaymentAmount, Map<String, Object> data) {
    if (orderId == null) {
      return;
    }

    List<Order> orderList = [
      SELECT Id, MemberNo__r.Grade__c, StoreCode__r.StoreType__c
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];
    if (orderList.isEmpty()) {
      return;
    }

    Decimal excludeAmount = 0;
    for (OrderItem oi : [
      SELECT NetSalesUnitPrice__c, IsExclude__c
      FROM OrderItem
      WHERE OrderId = :orderId
    ]) {
      if (oi.IsExclude__c == true) {
        excludeAmount += (oi.NetSalesUnitPrice__c == null ? 0 : oi.NetSalesUnitPrice__c);
      }
    }

    List<TransactionJournal> saleDepositList = [
      SELECT
        Id,
        MemberId,
        LoyaltyProgramId,
        OrderId,
        OrderId__c,
        SaleId__c,
        PromotionId,
        Promotion.PromotionNo__c,
        PaymentMethod,
        DepositType__c,
        TransactionAmount
      FROM TransactionJournal
      WHERE SaleId__c = :orderId AND IsDeleted__c = FALSE AND PaymentMethod != NULL AND PaymentMethod NOT IN ('81', '90')
      LIMIT 2000
    ];
    if (saleDepositList.isEmpty()) {
      return;
    }

    Id promotionId;
    String promotionNo;
    for (TransactionJournal tj : saleDepositList) {
      if (promotionId == null && tj.PromotionId != null) {
        promotionId = tj.PromotionId;
        promotionNo = (tj.Promotion == null) ? null : tj.Promotion.PromotionNo__c;
      }
    }
    if (promotionId != null) {
      for (TransactionJournal tj : saleDepositList) {
        if (tj.PromotionId == null) {
          tj.PromotionId = promotionId;
        }
      }
    }

    if (
      orderList[0].StoreCode__r != null &&
      orderList[0].StoreCode__r.StoreType__c != '20' &&
      orderList[0].StoreCode__r.StoreType__c != '25' &&
      orderList[0].StoreCode__r.StoreType__c != '33'
    ) {
      List<TransactionJournal> accrualBaseTjList = buildAccrualBaseTransactionJournals(saleDepositList);
      if (accrualBaseTjList.isEmpty()) {
        return;
      }
      List<PointCreditDTO> totalCreditPointList = new List<PointCreditDTO>();

      // 구매 시 포인트 지급
      List<PointCreditDTO> creditPointList = getPointService().creditPointsOnPurchaseV2(accrualBaseTjList, excludeAmount);
      if (creditPointList != null && !creditPointList.isEmpty()) {
        for (PointCreditDTO pcDto : creditPointList) {
          pcDto.AM_SAL = actualPaymentAmount;
          pcDto.NO_GRADE_ADVAN = orderList[0].MemberNo__r == null ? null : orderList[0].MemberNo__r.Grade__c;
          pcDto.NO_PROM_MBR = promotionNo;
        }
        totalCreditPointList.addAll(creditPointList);
      }

      // 프로모션 포인트 지급
      List<PointCreditDTO> promotionCreditPointList = getPointService().creditPromotionPointsOnPurchase(accrualBaseTjList, excludeAmount);
      if (promotionCreditPointList != null && !promotionCreditPointList.isEmpty()) {
        for (PointCreditDTO pcDto : promotionCreditPointList) {
          pcDto.AM_SAL = actualPaymentAmount;
          pcDto.NO_GRADE_ADVAN = orderList[0].MemberNo__r == null ? null : orderList[0].MemberNo__r.Grade__c;
          pcDto.NO_PROM_MBR = promotionNo;
        }
        totalCreditPointList.addAll(promotionCreditPointList);
      }

      if (!totalCreditPointList.isEmpty()) {
        data.put('CreditPointList', totalCreditPointList);
      }
    }
  }

  private static List<TransactionJournal> buildAccrualBaseTransactionJournals(List<TransactionJournal> saleDepositList) {
    List<TransactionJournal> accrualBaseTjList = new List<TransactionJournal>();
    if (saleDepositList == null || saleDepositList.isEmpty()) {
      return accrualBaseTjList;
    }

    for (TransactionJournal sourceTj : saleDepositList) {
      if (sourceTj == null) {
        continue;
      }

      TransactionJournal accrualTj = new TransactionJournal();
      accrualTj.MemberId = sourceTj.MemberId;
      accrualTj.LoyaltyProgramId = sourceTj.LoyaltyProgramId;
      accrualTj.OrderId = sourceTj.OrderId;
      accrualTj.OrderId__c = sourceTj.OrderId__c;
      accrualTj.SaleId__c = sourceTj.SaleId__c;
      accrualTj.PromotionId = sourceTj.PromotionId;
      accrualTj.PaymentMethod = sourceTj.PaymentMethod;
      accrualTj.DepositType__c = sourceTj.DepositType__c;

      Decimal amount = sourceTj.TransactionAmount == null ? 0 : sourceTj.TransactionAmount;
      if ('03'.equals(sourceTj.DepositType__c) || '05'.equals(sourceTj.DepositType__c)) {
        amount *= -1;
      }
      accrualTj.TransactionAmount = amount;

      accrualBaseTjList.add(accrualTj);
    }

    return accrualBaseTjList;
  }

  private static List<TransactionJournal> buildGeneralPaymentDeleteList(
    List<TransactionJournal> existingList,
    List<TransactionJournal> requestedList
  ) {
    List<TransactionJournal> deleteList = new List<TransactionJournal>();
    Map<String, String> requestedSignatureByKey = buildGeneralPaymentSignatureByKey(requestedList);

    if (existingList == null || existingList.isEmpty()) {
      return deleteList;
    }

    for (TransactionJournal existingTj : existingList) {
      String depositKey = existingTj.DepositNo__c;
      String requestedSignature = requestedSignatureByKey.get(depositKey);
      if (requestedSignature == null || requestedSignature != buildGeneralPaymentSignature(existingTj)) {
        deleteList.add(existingTj);
      }
    }

    return deleteList;
  }

  private static List<TransactionJournal> buildGeneralPaymentInsertList(
    List<TransactionJournal> existingList,
    List<TransactionJournal> requestedList
  ) {
    List<TransactionJournal> insertList = new List<TransactionJournal>();
    Map<String, String> existingSignatureByKey = buildGeneralPaymentSignatureByKey(existingList);

    if (requestedList == null || requestedList.isEmpty()) {
      return insertList;
    }

    for (TransactionJournal requestedTj : requestedList) {
      String depositKey = requestedTj.DepositNo__c;
      String existingSignature = existingSignatureByKey.get(depositKey);
      if (existingSignature == null || existingSignature != buildGeneralPaymentSignature(requestedTj)) {
        insertList.add(requestedTj);
      }
    }

    return insertList;
  }

  private static Map<String, String> buildGeneralPaymentSignatureByKey(List<TransactionJournal> tjList) {
    Map<String, String> signatureByKey = new Map<String, String>();
    if (tjList == null || tjList.isEmpty()) {
      return signatureByKey;
    }

    for (TransactionJournal tj : tjList) {
      signatureByKey.put(tj.DepositNo__c, buildGeneralPaymentSignature(tj));
    }

    return signatureByKey;
  }

  private static Boolean hasSameGeneralPaymentSet(List<TransactionJournal> existingList, List<TransactionJournal> requestedList) {
    Integer existingSize = existingList == null ? 0 : existingList.size();
    Integer requestedSize = requestedList == null ? 0 : requestedList.size();
    if (existingSize != requestedSize) {
      return false;
    }
    if (existingSize == 0) {
      return true;
    }

    // 기존 입금 담기
    Map<String, String> existingSignatureByKey = new Map<String, String>();
    for (TransactionJournal tj : existingList) {
      existingSignatureByKey.put(tj.DepositNo__c, buildGeneralPaymentSignature(tj));
      System.debug('buildGeneralPaymentSignature(tj) : ' + buildGeneralPaymentSignature(tj));
    }

    // 기존 입금과 요청 입금 검증
    for (TransactionJournal tj : requestedList) {
      String depositKey = tj.DepositNo__c;
      if (!existingSignatureByKey.containsKey(depositKey)) {
        return false;
      }
      if (existingSignatureByKey.get(depositKey) != buildGeneralPaymentSignature(tj)) {
        System.debug('buildGeneralPaymentSignature(tj) : ' + buildGeneralPaymentSignature(tj));
        return false;
      }
    }
    return true;
  }

  private static String buildGeneralPaymentSignature(TransactionJournal tj) {
    String journalDate = tj.JournalDate == null ? '' : String.valueOf(tj.JournalDate);
    String transactionAmount = normalizeDecimalForSignature(tj.TransactionAmount);
    return String.valueOf(tj.DepositNo__c) +
      '|' +
      journalDate +
      '|' +
      transactionAmount +
      '|' +
      String.valueOf(tj.DepositType__c) +
      '|' +
      String.valueOf(tj.PaymentMethod);
  }

  private static String normalizeDecimalForSignature(Decimal value) {
    if (value == null) {
      return '';
    }

    Decimal normalizedValue = value.stripTrailingZeros();
    return String.valueOf(normalizedValue);
  }

  private static String buildAggrLedgerKey(Id memberId, Id subtypeId, Date expiryDate) {
    return String.valueOf(memberId) + '|' + String.valueOf(subtypeId) + '|' + String.valueOf(expiryDate);
  }

  private class AggrDelta {
    Decimal redeemedDelta = 0; // 사용 포인트
    Decimal accruedDelta = 0; // 적립 포인트
    Decimal expiredDelta = 0; // 만료 포인트
    String currencySubTypeName; // 포인트 하위 유형 이름
  }

  /**
   * 적립 멱등키(효과 해시) 생성
   * - 적립에 영향을 주는 값만 포함
   */
  private static Boolean shouldSkipExistingCouponReplay(TransactionJournal existingTj, String paymentMethod, String depositType, String couponNo) {
    return existingTj != null &&
      String.isNotBlank(couponNo) &&
      existingTj.PaymentMethod == paymentMethod &&
      existingTj.DepositType__c == depositType &&
      existingTj.VoucherCode == couponNo;
  }

  private static void validateUnsupportedCouponChange(TransactionJournal existingTj, String paymentMethod, String depositType, String couponNo) {
    if (existingTj == null || String.isBlank(existingTj.VoucherCode)) {
      return;
    }
    if (shouldSkipExistingCouponReplay(existingTj, paymentMethod, depositType, couponNo)) {
      return;
    }
    throw new CustomException(400, '판매 수정에서는 기존 쿠폰 입금 건 변경을 지원하지 않습니다. DepositNo=' + existingTj.DepositNo__c);
  }

  private static Boolean shouldSkipExistingPointReplay(TransactionJournal existingTj, String depositType, Decimal transactionAmount) {
    return existingTj != null &&
      existingTj.PaymentMethod == '81' &&
      existingTj.DepositType__c == depositType &&
      existingTj.TransactionAmount == transactionAmount;
  }

  private static void validateUnsupportedPointChange(TransactionJournal existingTj, String depositType, Decimal transactionAmount) {
    if (existingTj == null || existingTj.PaymentMethod != '81') {
      return;
    }
    if (shouldSkipExistingPointReplay(existingTj, depositType, transactionAmount)) {
      return;
    }
    throw new CustomException(400, '판매 수정에서는 기존 포인트 사용 입금 건 변경을 지원하지 않습니다. DepositNo=' + existingTj.DepositNo__c);
  }

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