/**
 * 옵션 C 분기 처리 핸들러 — POST /gd/v1/return
 *
 * 두 가지 진입점 (둘 다 표준 로직 변경 0건)
 *   ① validateReturnAmountWithinPolicy(reqData)
 *      - 모든 POST /return 에 적용 (옛/신규 무관, IsEnabled 무관)
 *      - NEW BUG (검증 보고서 #12) — 누계 환불 금액이 원판매 금액 초과 시 차단
 *      - 기본 정책 위반 시 CustomException(400) throw
 *      - 통과 시 void return → 표준 로직 그대로 진행
 *
 *   ② wrapResponseIfSilentFail(standardResult, reqData, logger)
 *      - 옛 판매 + IsEnabled=true + 표준 로직 후에 호출
 *      - 표준의 결과 (data.CancelPointsCreditedList) 가 silent fail 인지 감지
 *      - 감지 시:
 *          · 응답 message + data 에 명시적 옵션 C 분기 정보 추가
 *          · 새로 생성된 환불 deposit TJ.AdditionalNotes__c 에 마커 추가
 *          · ApexLogger 상태 PARTIAL
 *      - 미감지 시: standardResult 그대로 반환 (표준이 정상 동작했음)
 *
 * 핵심 안전성
 *   - 표준 service 호출 0건 (validateReturnAmount), 또는 결과만 read (wrap)
 *   - 표준 로직의 모든 부수 효과 (Order 생성, OrderItem, 환불 deposit, 쿠폰, 사용 환원 등) 그대로 보존
 *   - 마커 추가 실패 시 try/catch — API 응답에 영향 X
 */
public with sharing class GdReturnBranchHandler {

  // 환불 deposit TJ 의 AdditionalNotes 에 추가되는 마커
  @TestVisible
  private static final String MARKER = 'OPTC_BRANCH_RETURN_REGISTER';

  // AdditionalNotes 안전 길이
  private static final Integer MAX_NOTES_LENGTH = 32000;

  // wrap 시 응답 message 에 추가되는 suffix
  @TestVisible
  private static final String WRAP_MESSAGE_SUFFIX = ' (오픈 전 거래 — 포인트 자동 처리 결과 확인 필요)';

  // wrap 시 응답 data 에 추가되는 reason
  @TestVisible
  private static final String WRAP_REASON =
    '오픈 전 거래에 대한 환불 처리 — 포인트 자동 차감 적용. 미차감액 발생 시 정기 점검 검토 대상.';

  // ============================================================
  // ① validateReturnAmountWithinPolicy
  //    NEW BUG 차단 — 누계 환불 금액이 원판매 금액 초과 시 throw
  // ============================================================

  /**
   * 환불 한도 / 데이터 결함 검증.
   *
   * 정책:
   *   - 누계 (returnSuccess 만) + 이번 환불 금액 ≤ 원판매 금액 → 통과
   *   - 초과 시 → 400 throw (기본 정책 위반)
   *
   * 다음 경우는 검증 skip (표준이 처리):
   *   - OriginalOrderId 누락 / blank
   *   - ActualPaymentAmount__c 누락 / 형식 오류
   *   - 원판매 Order 미존재 (표준이 400 throw 함)
   *
   * 다음 경우는 우리가 추가로 throw:
   *   - 원판매 ActualPaymentAmount__c = NULL (한도 검증 불가)
   *   - 이번 환불 금액 ≤ 0 (음수 / 0)
   */
  public static void validateReturnAmountWithinPolicy(Map<String, Object> reqData) {
    if (reqData == null) {
      return; // 표준이 빈 본문 체크 함
    }

    String originalSaleNo = toString(reqData.get('OriginalOrderId'));
    if (String.isBlank(originalSaleNo)) {
      return; // 표준 검증으로 위임
    }

    Decimal requestedAmount = toDecimal(reqData.get('ActualPaymentAmount__c'));
    if (requestedAmount == null) {
      return; // 표준 검증으로 위임 (해당 필드 optional)
    }

    if (requestedAmount <= 0) {
      throw new CustomException(
        400,
        '환불 금액이 유효하지 않음 (기본 정책 위반). ' +
        'requestedAmount=' + requestedAmount + '. ' +
        '양수 금액으로 재요청 바람.'
      );
    }

    // 원판매 Order 조회
    List<Order> originalOrderList = [
      SELECT Id, ActualPaymentAmount__c
      FROM Order
      WHERE SaleNo__c = :originalSaleNo
      LIMIT 1
    ];
    if (originalOrderList.isEmpty()) {
      return; // 표준 createReturn 이 400 throw 함
    }

    Decimal originalAmount = originalOrderList[0].ActualPaymentAmount__c;
    if (originalAmount == null) {
      throw new CustomException(
        400,
        '원판매 금액 정보 없음 — 환불 한도 검증 불가 (기본 정책 위반). ' +
        'originalSaleNo=' + originalSaleNo + '. ' +
        '데이터 보정 후 재시도. 또는 고객사 정책 결정 영역.'
      );
    }

    // 기존 반품 (returnSuccess 만) 누계 합산
    List<Order> existingReturns = [
      SELECT Id, SaleNo__c, ActualPaymentAmount__c, Status
      FROM Order
      WHERE OriginalOrderId__c = :originalOrderList[0].Id
        AND IsDeleted__c = FALSE
        AND IsReductionOrder__c = TRUE
        AND Status = 'returnSuccess'
    ];

    Decimal totalReturned = 0;
    String existingReturnSummary = '';
    for (Order ret : existingReturns) {
      if (ret.ActualPaymentAmount__c != null && ret.ActualPaymentAmount__c > 0) {
        totalReturned += ret.ActualPaymentAmount__c;
        existingReturnSummary += ret.SaleNo__c + '(' + ret.ActualPaymentAmount__c + '), ';
      }
    }

    if (totalReturned + requestedAmount > originalAmount) {
      Decimal remainingAllowed = originalAmount - totalReturned;
      if (remainingAllowed < 0) {
        remainingAllowed = 0;
      }
      throw new CustomException(
        400,
        '원판매 금액 초과 환불 불가 (기본 정책 위반). ' +
        'originalSaleNo=' + originalSaleNo +
        ', 원판매 금액=' + originalAmount +
        ', 누계 환불 금액=' + totalReturned +
        ', 이번 시도 금액=' + requestedAmount +
        ', 합계=' + (totalReturned + requestedAmount) +
        ', 잔여 환불 가능=' + remainingAllowed +
        '. 기존 반품: [' + existingReturnSummary + ']. ' +
        '초과 환불은 고객사 정책 결정 영역.'
      );
    }
  }

  // ============================================================
  // ② wrapResponseIfSilentFail
  //    표준 로직 후 silent fail 감지 시 응답 enrich
  // ============================================================

  /**
   * 옵션 C 분기 처리 — wrap 패턴.
   *
   * 표준 로직은 이미 모두 실행된 상태. 우리는:
   *   1. CancelPointsCreditedList 가 null/missing 인지 감지 (silent fail 신호)
   *   2. silent fail 감지 시:
   *      - 응답 message 에 옵션 C 분기 표기 추가
   *      - 응답 data 에 option_c_branch / point_processing / reason 추가
   *      - 새 환불 deposit TJ 의 AdditionalNotes 에 마커 추가
   *      - ApexLogger 상태 PARTIAL
   *   3. silent fail 미감지 시: standardResult 그대로 반환
   *
   * 호출 조건 (controller 가 보장):
   *   - shouldApplyOptionCBranchBySaleNo(originalSaleNo) == true
   *   - 즉 IsEnabled=true + 옛 판매
   */
  public static ApiResult wrapResponseIfSilentFail(
    ApiResult standardResult,
    Map<String, Object> reqData,
    ApexLogger logger
  ) {
    if (standardResult == null || standardResult.data == null) {
      return standardResult;
    }
    if (reqData == null) {
      return standardResult;
    }

    // 운영자가 포인트 처리를 요청한 경우만 silent fail 감지 의미 있음
    Boolean operatorRequestedPointProcessing = reqData.containsKey('TransactionJournal');
    if (!operatorRequestedPointProcessing) {
      return standardResult; // 점수 처리 미요청 — silent fail 무관
    }

    // CancelPointsCreditedList 가 missing 또는 null → silent fail
    Boolean silentFailDetected =
      !standardResult.data.containsKey('CancelPointsCreditedList') ||
      standardResult.data.get('CancelPointsCreditedList') == null;

    if (!silentFailDetected) {
      return standardResult; // 표준이 정상 처리 — wrap 불필요
    }

    // 1. 응답 message + data enrich
    String origMessage = standardResult.message == null ? '' : standardResult.message;
    standardResult.message = origMessage + WRAP_MESSAGE_SUFFIX;
    standardResult.data.put('option_c_branch', true);
    standardResult.data.put('point_processing', 'skipped_due_to_migration');
    standardResult.data.put('reason', WRAP_REASON);

    // 2. TJ 마커 추가 (실패해도 API 응답에 영향 X)
    //    환불 deposit TJ 는 OrderId=원판매 Order Id 로 저장되므로
    //    request body 의 TransactionJournal[i].DepositNo__c + '-' + DeposiSeqNo__c 으로 정확히 식별
    try {
      Set<String> targetDepositNos = extractDepositNosFromRequest(reqData);
      if (!targetDepositNos.isEmpty()) {
        addMarkerToReturnDepositTjsByDepositNo(targetDepositNos, toString(reqData.get('OriginalOrderId')));
      }
    } catch (Exception e) {
      System.debug('OPTC_BRANCH_RETURN_REGISTER marker update failed: ' + e.getMessage());
    }

    // 3. 로거
    if (logger != null) {
      logger.setStatus('PARTIAL');
      logger.setDescription(
        'Option C 분기 wrap: POST /return — silent fail 감지 (CancelPointsCreditedList null/missing), 응답 enriched. ' +
        'originalSaleNo=' + reqData.get('OriginalOrderId') +
        ', returnOrderId=' + reqData.get('orderId')
      );
    }

    // 4. Phase 6.4 — 환불 금액 기준 적립 추정 + 강제 차감 (force-debit)
    String origSaleNo = toString(reqData.get('OriginalOrderId'));
    Decimal reqAmount = toDecimal(reqData.get('ActualPaymentAmount__c'));
    ForceDebitOutcome outcome = computeAndForceDebitForReturn(
      origSaleNo, reqAmount, toString(reqData.get('orderId')), reqData
    );

    // 응답 enrich (force-debit 결과)
    standardResult.data.put('option_c_force_debit_requested', outcome.requested);
    standardResult.data.put('option_c_force_debit_actual', outcome.actual);
    standardResult.data.put('option_c_force_debit_loss', outcome.loss);
    // 26.05.07 CS - 적립 base 보정 추적
    standardResult.data.put('option_c_refund_amount', outcome.refundAmount);
    standardResult.data.put('option_c_excluded_item_amount', outcome.excludedItemAmount);
    standardResult.data.put('option_c_non_accrual_pm_amount', outcome.nonAccrualPMAmount);
    standardResult.data.put('option_c_eligible_amount', outcome.eligibleAmount);
    if (outcome.success) {
      standardResult.data.put('point_processing', 'force_debited_with_estimation');
    }
    if (outcome.debitTjId != null) {
      standardResult.data.put('option_c_force_debit_tj_id', outcome.debitTjId);
    }

    // 5. MigrationAdjustmentLog 기록 (Phase 6.4 — 실 force 결과 반영)
    // 26.05.06 CS - 반품 Order Id 를 매핑 키로 함께 저장 (1:1 매칭, 매칭 트랩 회피).
    Id returnOrderIdForLog = null;
    Object returnOrderIdRaw = reqData.get('orderId');
    if (returnOrderIdRaw != null) {
      try {
        returnOrderIdForLog = (Id) String.valueOf(returnOrderIdRaw);
      } catch (Exception e) {
        // Id 변환 실패 시 null 유지 (안전 정책)
        System.debug('returnOrderId Id 변환 실패: ' + e.getMessage());
      }
    }
    Id logId = GdMigrationUtil.recordAdjustmentLog(
      outcome.memberId,
      null,
      'RETURN_REGISTER_BRANCH',
      'POST /gd/v1/return',
      origSaleNo,
      outcome.requested,
      outcome.actual,
      'Phase 6.4 — silent fail visualized + force-debit applied. ' +
      'returnOrderId=' + reqData.get('orderId') +
      ', requestedRefundAmount=' + (reqAmount == null ? 'null' : reqAmount.toPlainString()) +
      ', excludedItemAmount=' + outcome.excludedItemAmount +
      ', nonAccrualPMAmount=' + outcome.nonAccrualPMAmount +
      ', eligibleAmount=' + outcome.eligibleAmount +
      ', forceDebitSuccess=' + outcome.success +
      ', estimateBreakdown=' + outcome.breakdown +
      (String.isBlank(outcome.error) ? '' : ', forceDebitError=' + outcome.error),
      returnOrderIdForLog
    );
    if (logId != null) {
      standardResult.data.put('adjustment_log_id', logId);
    }

    return standardResult;
  }

  /**
   * 적립 추정 + 강제 차감 결과.
   */
  @TestVisible
  private class ForceDebitOutcome {
    Decimal requested = 0;
    Decimal actual = 0;
    Decimal loss = 0;
    Boolean success = false;
    Id debitTjId;
    Id memberId;
    String error;
    String breakdown = '';
    // 26.05.07 CS - 적립 base 보정 추적용
    Decimal refundAmount = 0;
    Decimal excludedItemAmount = 0;
    Decimal nonAccrualPMAmount = 0;
    Decimal eligibleAmount = 0;
  }

  /**
   * 원판매 정보 조회 → 환불 금액 기준 적립 추정 → forceDebitPointsSafe 호출.
   * 모든 단계 try/catch — 실패 시 outcome 에 반영, throw 안 함.
   *
   * 26.05.07 CS - reqData 페이로드 기반 적립 base 보정 추가.
   *   eligibleAmount = refundAmount - 적립 불가 품목 금액 - 적립 비대상 PM 금액
   *   표준 calculateEligibleAccrualAmount 와 일관된 정책 적용.
   */
  private static ForceDebitOutcome computeAndForceDebitForReturn(
    String originalSaleNo,
    Decimal refundAmount,
    String returnOrderId,
    Map<String, Object> reqData
  ) {
    ForceDebitOutcome out = new ForceDebitOutcome();
    out.refundAmount = (refundAmount == null) ? 0 : refundAmount;
    if (String.isBlank(originalSaleNo) || refundAmount == null || refundAmount <= 0) {
      out.error = 'invalid input';
      return out;
    }

    try {
      // 원판매 Order 조회 (회원/금액)
      List<Order> origOrders = [
        SELECT Id, MemberNo__c, ActualPaymentAmount__c
        FROM Order
        WHERE SaleNo__c = :originalSaleNo
        LIMIT 1
      ];
      if (origOrders.isEmpty() || origOrders[0].MemberNo__c == null) {
        out.error = 'original sale not found or member missing';
        return out;
      }

      Id contactId = origOrders[0].MemberNo__c;
      Id originalOrderId = origOrders[0].Id;

      // ContactId → LoyaltyProgramMember
      List<LoyaltyProgramMember> lpms = [
        SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :contactId LIMIT 1
      ];
      if (lpms.isEmpty()) {
        out.error = 'loyalty member not found for contact';
        return out;
      }
      out.memberId = lpms[0].Id;
      Id programId = lpms[0].ProgramId;

      // 원판매에 적용된 Promotion 조회 (적립 TJ 의 PromotionId)
      Id promotionId = findPromotionIdForOriginalOrder(originalOrderId);

      // === 26.05.07 CS 적립 base 보정 ===
      // 1. 적립 불가 품목 (IsExclude=true) 금액 차감
      out.excludedItemAmount = computeExcludedItemAmountForReturn(originalOrderId, reqData);
      // 2. 적립 비대상 PM (20/81/90/93) 환불 금액 차감
      out.nonAccrualPMAmount = computeNonAccrualPMAmountFromTjPayload(reqData);
      Decimal eligibleAmount = refundAmount - out.excludedItemAmount - out.nonAccrualPMAmount;
      if (eligibleAmount < 0) {
        eligibleAmount = 0;
      }
      out.eligibleAmount = eligibleAmount;

      if (eligibleAmount <= 0) {
        out.error = 'no eligible amount after exclusion (모두 적립 비대상)';
        return out;
      }

      // 적립 추정 (보정된 eligibleAmount 사용)
      List<GdMigrationUtil.AccrualEstimate> estimates = GdMigrationUtil.calculateAccrualForOldOrder(
        out.memberId, eligibleAmount, promotionId
      );

      Decimal totalRequested = 0;
      String breakdown = '';
      for (GdMigrationUtil.AccrualEstimate est : estimates) {
        if (est.points != null && est.points > 0) {
          totalRequested += est.points;
          breakdown += (est.subtypeName == null ? '?' : est.subtypeName) +
            '=' + est.points.toPlainString() + 'P, ';
        }
      }
      out.requested = totalRequested;
      out.breakdown = breakdown;

      if (totalRequested <= 0) {
        out.error = 'no accrual estimate (rate 0 or no benefit)';
        return out;
      }

      // 강제 차감 (잔액 부족 시 부분 차감 + 손실 기록)
      GdOptionCPointAdjustmentUtil.AccrualCancelResult fd = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
        out.memberId, programId, originalOrderId, (Id) returnOrderId, totalRequested,
        'OPTC_RETURN_REGISTER_ETC_ACCRUAL_CANCEL: returnOrderId=' + returnOrderId +
        ', originalSaleNo=' + originalSaleNo +
        ', refundAmount=' + refundAmount.toPlainString() +
        ', excludedItemAmount=' + out.excludedItemAmount.toPlainString() +
        ', nonAccrualPMAmount=' + out.nonAccrualPMAmount.toPlainString() +
        ', eligibleAmount=' + eligibleAmount.toPlainString() +
        ', breakdown=' + breakdown
      );
      out.actual = fd.actualPoints;
      out.loss = fd.loss;
      out.success = fd.success;
      out.debitTjId = fd.reversalTjId;
      out.error = fd.error;
      return out;
    } catch (Exception e) {
      System.debug('computeAndForceDebitForReturn exception: ' + e.getMessage());
      out.success = false;
      out.error = e.getMessage();
      out.loss = (refundAmount == null) ? 0 : refundAmount;
      return out;
    }
  }

  /**
   * 원판매 Order 의 적립 TJ 에서 PromotionId 추출 (있으면).
   * 마이그된 옛 거래는 lump credit TJ 가 있으나 PromotionId 가 비어있을 수도.
   * 못 찾으면 null → calculateAccrualForOldOrder 에서 promotion 제외 없이 계산.
   */
  @TestVisible
  private static Id findPromotionIdForOriginalOrder(Id originalOrderId) {
    if (originalOrderId == null) {
      return null;
    }
    try {
      List<TransactionJournal> tjs = [
        SELECT PromotionId
        FROM TransactionJournal
        WHERE OrderId = :originalOrderId
          AND PromotionId != null
        LIMIT 1
      ];
      return tjs.isEmpty() ? null : tjs[0].PromotionId;
    } catch (Exception e) {
      System.debug('findPromotionIdForOriginalOrder exception: ' + e.getMessage());
      return null;
    }
  }

  // ============================================================
  // 내부 헬퍼
  // ============================================================

  /**
   * 요청 body 의 TransactionJournal 배열에서 DepositNo__c 와 DeposiSeqNo__c 추출.
   * 표준 service 가 TJ.DepositNo__c 에 'DepositNo-DeposiSeqNo' 형식으로 저장하므로
   * 같은 형식으로 결합해서 반환.
   */
  @TestVisible
  private static Set<String> extractDepositNosFromRequest(Map<String, Object> reqData) {
    Set<String> result = new Set<String>();
    if (reqData == null) {
      return result;
    }
    Object tjListObj = reqData.get('TransactionJournal');
    if (!(tjListObj instanceof List<Object>)) {
      return result;
    }
    for (Object tjObj : (List<Object>) tjListObj) {
      if (!(tjObj instanceof Map<String, Object>)) {
        continue;
      }
      Map<String, Object> tjMap = (Map<String, Object>) tjObj;
      String depositNo = toString(tjMap.get('DepositNo__c'));
      String depositSeqNo = toString(tjMap.get('DeposiSeqNo__c'));
      if (String.isNotBlank(depositNo) && String.isNotBlank(depositSeqNo)) {
        result.add(depositNo + '-' + depositSeqNo);
      }
    }
    return result;
  }

  /**
   * 정확한 DepositNo__c 매칭으로 새 환불 TJ 마커 추가.
   * 기존 AdditionalNotes 보존, ' | ' 구분자, 32k 안전 truncate.
   */
  private static void addMarkerToReturnDepositTjsByDepositNo(Set<String> depositNos, String originalSaleNo) {
    if (depositNos == null || depositNos.isEmpty()) {
      return;
    }
    List<TransactionJournal> tjs = [
      SELECT Id, AdditionalNotes__c
      FROM TransactionJournal
      WHERE DepositNo__c IN :depositNos
        AND IsDeleted__c = FALSE
        AND JournalSubType.Name = 'Sale Deposit Reversal'
      LIMIT 50
    ];
    if (tjs.isEmpty()) {
      return;
    }

    List<TransactionJournal> toUpdate = new List<TransactionJournal>();
    String markerEntry = MARKER +
      ': originalSaleNo=' + (originalSaleNo == null ? '' : originalSaleNo) +
      ', point_processing=skipped_due_to_migration';

    for (TransactionJournal tj : tjs) {
      String existing = String.isBlank(tj.AdditionalNotes__c) ? '' : tj.AdditionalNotes__c + ' | ';
      String combined = existing + markerEntry;
      if (combined.length() > MAX_NOTES_LENGTH) {
        combined = combined.substring(0, MAX_NOTES_LENGTH);
      }
      tj.AdditionalNotes__c = combined;
      toUpdate.add(tj);
    }
    if (!toUpdate.isEmpty()) {
      update toUpdate;
    }
  }

  /**
   * Map 의 다양한 numeric 표현을 Decimal 로 안전 변환.
   * 변환 실패 / null 시 null 반환.
   */
  private static Decimal toDecimal(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Decimal) {
      return (Decimal) value;
    }
    if (value instanceof Integer) {
      return Decimal.valueOf((Integer) value);
    }
    if (value instanceof Long) {
      return Decimal.valueOf((Long) value);
    }
    if (value instanceof Double) {
      return Decimal.valueOf((Double) value);
    }
    if (value instanceof String) {
      try {
        return Decimal.valueOf((String) value);
      } catch (Exception e) {
        return null;
      }
    }
    return null;
  }

  /**
   * Map value 를 String 으로 안전 변환.
   */
  private static String toString(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof String) {
      return (String) value;
    }
    return String.valueOf(value);
  }

  // ============================================================
  // 26.05.07 CS — 적립 base 보정 helper
  //
  // 옵션 C 옛 판매 반품 등록 시 추정 base 가 환불 총액 그대로 사용되고 있어
  // 표준 calculateEligibleAccrualAmount 의 정책과 어긋남. 두 가지 보정:
  //   1. 적립 불가 품목 (OrderItem.IsExclude__c=true) 금액 차감
  //   2. 적립 비대상 PaymentMethod (20/81/90/93) 환불 금액 차감
  // ============================================================

  // 적립 비대상 PaymentMethod (표준 calculateEligibleAccrualAmount 와 동일)
  @TestVisible
  private static final Set<String> NON_ACCRUAL_PMS = new Set<String>{ '20', '81', '90', '93' };

  /**
   * 반품 환불 페이로드에서 적립 불가 품목 (IsExclude=true) 금액 산출.
   *
   * 표준 GdReturnDepositServiceImpl.getExcludedReturnAmountFromRequest 의 패턴을 따름:
   *   - 페이로드 OrderItem 의 OriginalOrderItemId__c / SaleSeqNo__c 로 원판매 OrderItem 매칭
   *   - 원판매 OrderItem.IsExclude__c=true 인 라인만 합산
   *   - 페이로드의 NetSalesUnitPrice__c 우선, 비어있으면 원판매 단가×수량 fallback
   *
   * 안전성: 모든 단계 try/catch, 실패 시 0 반환 (보정 안 함, 기존 동작 유지).
   */
  @TestVisible
  private static Decimal computeExcludedItemAmountForReturn(
    Id originalOrderId, Map<String, Object> reqData
  ) {
    if (originalOrderId == null || reqData == null) return 0;
    try {
      Object oiListObj = reqData.get('OrderItem');
      if (!(oiListObj instanceof List<Object>)) return 0;

      Set<Id> originalOiIdSet = new Set<Id>();
      Set<String> saleSeqNoSet = new Set<String>();
      List<Map<String, Object>> normalized = new List<Map<String, Object>>();

      for (Object v : (List<Object>) oiListObj) {
        if (!(v instanceof Map<String, Object>)) continue;
        Map<String, Object> oi = (Map<String, Object>) v;
        String oiIdStr = toString(oi.get('OriginalOrderItemId__c'));
        String saleSeqNo = toString(oi.get('SaleSeqNo__c'));
        Decimal netSalesUnitPrice = toDecimal(oi.get('NetSalesUnitPrice__c'));
        if (String.isNotBlank(oiIdStr)) {
          try { originalOiIdSet.add((Id) oiIdStr); } catch (Exception e) {}
        }
        if (String.isNotBlank(saleSeqNo)) saleSeqNoSet.add(saleSeqNo);
        normalized.add(new Map<String, Object>{
          'OriginalOrderItemId__c' => oiIdStr,
          'SaleSeqNo__c' => saleSeqNo,
          'NetSalesUnitPrice__c' => netSalesUnitPrice
        });
      }
      if (originalOiIdSet.isEmpty() && saleSeqNoSet.isEmpty()) return 0;

      Map<Id, OrderItem> originalById = new Map<Id, OrderItem>();
      Map<String, OrderItem> originalBySaleSeqNo = new Map<String, OrderItem>();
      for (OrderItem origOi : [
        SELECT Id, SaleSeqNo__c, IsExclude__c, NetSalesUnitPrice__c, Quantity
        FROM OrderItem
        WHERE OrderId = :originalOrderId
          AND (Id IN :originalOiIdSet OR SaleSeqNo__c IN :saleSeqNoSet)
      ]) {
        originalById.put(origOi.Id, origOi);
        if (String.isNotBlank(origOi.SaleSeqNo__c)
            && !originalBySaleSeqNo.containsKey(origOi.SaleSeqNo__c)) {
          originalBySaleSeqNo.put(origOi.SaleSeqNo__c, origOi);
        }
      }

      Decimal excluded = 0;
      for (Map<String, Object> norm : normalized) {
        String oiIdStr = (String) norm.get('OriginalOrderItemId__c');
        String saleSeqNo = (String) norm.get('SaleSeqNo__c');
        Decimal returnItemAmount = (Decimal) norm.get('NetSalesUnitPrice__c');

        OrderItem origOi = null;
        if (String.isNotBlank(oiIdStr)) {
          try { origOi = originalById.get((Id) oiIdStr); } catch (Exception e) {}
        }
        if (origOi == null && String.isNotBlank(saleSeqNo)) {
          origOi = originalBySaleSeqNo.get(saleSeqNo);
        }
        if (origOi == null) continue;
        if (origOi.IsExclude__c != true) continue;

        if (returnItemAmount != null) {
          excluded += returnItemAmount;
        } else {
          Decimal unitPrice = origOi.NetSalesUnitPrice__c == null ? 0 : origOi.NetSalesUnitPrice__c;
          Decimal qty = origOi.Quantity == null ? 1 : origOi.Quantity;
          excluded += unitPrice * qty;
        }
      }
      return excluded;
    } catch (Exception e) {
      System.debug('computeExcludedItemAmountForReturn exception: ' + e.getMessage());
      return 0;
    }
  }

  /**
   * 환불 TJ 페이로드에서 적립 비대상 PaymentMethod (20/81/90/93) 합계 산출.
   *
   * 안전성: 모든 단계 try/catch, 실패 시 0 반환.
   */
  @TestVisible
  private static Decimal computeNonAccrualPMAmountFromTjPayload(Map<String, Object> reqData) {
    if (reqData == null) return 0;
    try {
      Object tjListObj = reqData.get('TransactionJournal');
      if (!(tjListObj instanceof List<Object>)) return 0;
      Decimal total = 0;
      for (Object tjObj : (List<Object>) tjListObj) {
        if (!(tjObj instanceof Map<String, Object>)) continue;
        Map<String, Object> tj = (Map<String, Object>) tjObj;
        String pm = toString(tj.get('PaymentMethod'));
        Decimal amount = toDecimal(tj.get('TransactionAmount'));
        if (pm != null && NON_ACCRUAL_PMS.contains(pm) && amount != null && amount > 0) {
          total += amount;
        }
      }
      return total;
    } catch (Exception e) {
      System.debug('computeNonAccrualPMAmountFromTjPayload exception: ' + e.getMessage());
      return 0;
    }
  }
}