/**
 * 옵션 C 분기 처리 핸들러 — PATCH /gd/v1/sale
 *
 * Wrap 패턴 (Phase 4 와 동일 — 표준 로직 100% 실행 + 응답 enrich)
 *
 * 적용 시점
 *   GdSaleApiControllerV1.updateSale() 의 표준 로직 후 entry point 에서
 *   GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(saleNo) == true 인 경우
 *   wrapResponse(...) 호출.
 *
 * 처리 시나리오
 *   - A-2-3 옛 판매 수정 (금액 ↓) — 적립 차감 silent fail
 *   - A-2-4 옛 판매 수정 (금액 ↑) — 적립 추가 silent fail
 *   - A-2-5 옛 판매에 사용 포인트 추가 — silent fail
 *
 * 동작
 *   1. 표준 로직 (Order update, OrderItem upsert, TJ insert) 그대로 실행됨
 *   2. 표준 결과 → 옛 판매라면 응답 message + data 에 옵션 C 분기 정보 추가
 *   3. ApexLogger 상태 PARTIAL (audit trail)
 *
 * Phase 4 와 차이
 *   - Phase 4: DELETE /sale (Order Status 변경만, 다른 부수 효과는 적음)
 *   - Phase 5: PATCH /sale (Order/OrderItem/TJ 모두 변경 가능)
 *   - 핸들러 동작은 동일 (응답 enrich + 로거)
 */
public with sharing class GdSalePatchBranchHandler {

  // 응답 message 에 추가되는 suffix
  @TestVisible
  private static final String WRAP_MESSAGE_SUFFIX = ' (오픈 전 거래 — 포인트 별도 처리 필요)';

  // 응답 data 에 추가되는 reason
  @TestVisible
  private static final String WRAP_REASON =
    '오픈 전 거래에 대한 판매 수정 — 포인트 자동 처리 미적용. 별도 수동 처리 필요.';

  /**
   * 옛 판매 수정 응답 wrap.
   *
   * @param standardResult  표준 updateSale 의 결과
   * @param saleNo          수정 대상 판매 번호
   * @param logger          ApexLogger (null 허용)
   * @return                enrich 된 ApiResult
   *
   * 호출 조건 (controller 가 보장):
   *   - shouldApplyOptionCBranchBySaleNo(saleNo) == true
   *   - 표준 로직 이미 실행 완료 (Order/OrderItem/TJ 처리 등)
   */
  public static ApiResult wrapResponseForOldSale(
    ApiResult standardResult,
    String saleNo,
    ApexLogger logger
  ) {
    // 기존 시그니처 호환 (oldAmount=null)
    return wrapResponseForOldSale(standardResult, saleNo, null, logger);
  }

  /**
   * Phase 6.6 — 변경 전 ActualPaymentAmount 받아 적립 차이 자동 조정.
   *
   * @param oldAmount 변경 전 ActualPaymentAmount (controller 가 service 호출 전 capture)
   *
   * 차이 계산:
   *   newAmount = (Order 의 변경 후 값)
   *   delta = newAmount - oldAmount
   *   adjustPoints = |delta| × 등급 적립률
   *
   *   delta > 0 (증액) → forceCreditPointsSafe (회원에게 추가 적립)
   *   delta < 0 (감액) → forceDebitPointsSafe (회원에서 차감)
   *   delta = 0       → 조정 없음
   *
   * 안전성:
   *   - oldAmount 가 null 이면 조정 skip (controller 가 capture 못 한 케이스)
   *   - 모든 DML / 조회 try/catch
   */
  public static ApiResult wrapResponseForOldSale(
    ApiResult standardResult,
    String saleNo,
    Decimal oldAmount,
    ApexLogger logger
  ) {
    if (standardResult == null) {
      return standardResult;
    }
    if (standardResult.data == null) {
      standardResult.data = new Map<String, Object>();
    }

    // 응답 message + data enrich
    String origMessage = standardResult.message == null ? '' : standardResult.message;
    standardResult.message = origMessage + WRAP_MESSAGE_SUFFIX;
    standardResult.data.put('option_c_branch', true);
    standardResult.data.put('point_processing', 'skipped_due_to_migration');
    standardResult.data.put('reason', WRAP_REASON);
    standardResult.data.put('saleNo', saleNo);

    // === Phase 6.6 — 적립 차이 자동 조정 ===
    AdjustOutcome outcome = computeAndAdjustForSalePatch(saleNo, oldAmount);

    standardResult.data.put('option_c_amount_delta', outcome.amountDelta);
    standardResult.data.put('option_c_points_requested', outcome.requested);
    standardResult.data.put('option_c_points_actual', outcome.actual);
    standardResult.data.put('option_c_points_unprocessed', outcome.unprocessed);
    standardResult.data.put('option_c_direction', outcome.direction);
    if (outcome.success) {
      standardResult.data.put('point_processing',
        outcome.direction == 'credit' ? 'force_credited_with_estimation'
        : outcome.direction == 'debit' ? 'force_debited_with_estimation'
        : 'no_adjustment_needed');
    }
    if (outcome.tjId != null) {
      standardResult.data.put('option_c_adjust_tj_id', outcome.tjId);
    }

    // 로거 PARTIAL 상태 (audit trail)
    if (logger != null) {
      logger.setStatus('PARTIAL');
      logger.setDescription(
        'Option C 분기 wrap: PATCH /sale — Phase 6.6 적용. ' +
        'saleNo=' + saleNo +
        ', amountDelta=' + outcome.amountDelta +
        ', direction=' + outcome.direction +
        ', requested=' + outcome.requested +
        ', actual=' + outcome.actual
      );
    }

    // MigrationAdjustmentLog 기록 (실 force 결과 반영)
    Id logId = GdMigrationUtil.recordAdjustmentLog(
      outcome.memberId, null, 'SALE_MODIFY_BRANCH', 'PATCH /gd/v1/sale',
      saleNo,
      outcome.requested,
      outcome.actual,
      'Phase 6.6 — silent fail visualized + 적립 차이 자동 조정. ' +
      'saleNo=' + saleNo +
      ', oldAmount=' + (oldAmount == null ? 'null' : oldAmount.toPlainString()) +
      ', amountDelta=' + outcome.amountDelta +
      ', direction=' + outcome.direction +
      ', forceSuccess=' + outcome.success +
      ', breakdown=' + outcome.breakdown +
      (String.isBlank(outcome.error) ? '' : ', error=' + outcome.error)
    );
    if (logId != null) {
      standardResult.data.put('adjustment_log_id', logId);
    }

    return standardResult;
  }

  /**
   * 적립 차이 조정 결과.
   */
  @TestVisible
  private class AdjustOutcome {
    Decimal amountDelta = 0;       // newAmount - oldAmount
    String direction = 'none';     // 'credit' / 'debit' / 'none'
    Decimal requested = 0;
    Decimal actual = 0;
    Decimal unprocessed = 0;
    Boolean success = false;
    Id tjId;
    Id memberId;
    String error;
    String breakdown = '';
  }

  /**
   * 변경 전후 금액 차이를 보고 적립 force-credit 또는 force-debit 실행.
   */
  private static AdjustOutcome computeAndAdjustForSalePatch(String saleNo, Decimal oldAmount) {
    AdjustOutcome out = new AdjustOutcome();
    if (String.isBlank(saleNo) || oldAmount == null) {
      out.error = 'invalid input or oldAmount missing';
      return out;
    }

    try {
      // 1. 현재 (변경 후) Order 조회
      List<Order> orders = [
        SELECT Id, MemberNo__c, ActualPaymentAmount__c
        FROM Order WHERE SaleNo__c = :saleNo LIMIT 1
      ];
      if (orders.isEmpty() || orders[0].MemberNo__c == null) {
        out.error = 'sale not found or member missing';
        return out;
      }
      Id contactId = orders[0].MemberNo__c;
      Id orderId = orders[0].Id;
      Decimal newAmount = orders[0].ActualPaymentAmount__c;
      if (newAmount == null) {
        out.error = 'new amount missing';
        return out;
      }

      // 2. 회원 조회
      List<LoyaltyProgramMember> lpms = [
        SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :contactId LIMIT 1
      ];
      if (lpms.isEmpty()) {
        out.error = 'loyalty member not found';
        return out;
      }
      out.memberId = lpms[0].Id;
      Id programId = lpms[0].ProgramId;

      // 3. 차이 계산
      Decimal delta = newAmount - oldAmount;
      out.amountDelta = delta;

      if (delta == 0) {
        out.direction = 'none';
        out.success = true;
        return out;
      }

      // 4. 적립 추정 (절대값 기준)
      Id promotionId = findPromotionIdForOriginalOrder(orderId);
      List<GdMigrationUtil.AccrualEstimate> estimates = GdMigrationUtil.calculateAccrualForOldOrder(
        out.memberId, delta.abs(), promotionId
      );

      Decimal totalPoints = 0;
      String breakdown = '';
      for (GdMigrationUtil.AccrualEstimate est : estimates) {
        if (est.points != null && est.points > 0) {
          totalPoints += est.points;
          breakdown += (est.subtypeName == null ? '?' : est.subtypeName) + '=' + est.points.toPlainString() + 'P, ';
        }
      }
      out.requested = totalPoints;
      out.breakdown = breakdown;

      if (totalPoints <= 0) {
        out.error = 'no accrual estimate';
        out.direction = delta > 0 ? 'credit' : 'debit';
        return out;
      }

      // 5. 방향에 따라 force-credit 또는 force-debit
      if (delta > 0) {
        // 증액 → 적립 추가
        out.direction = 'credit';
        GdMigrationUtil.ForceCreditResult fc = GdMigrationUtil.forceCreditPointsSafe(
          out.memberId, programId, orderId, totalPoints,
          'OPTC_SALE_PATCH_FORCE_CREDIT: saleNo=' + saleNo +
          ', oldAmount=' + oldAmount + ', newAmount=' + newAmount +
          ', delta=' + delta + ', breakdown=' + breakdown
        );
        out.actual = fc.actualPoints;
        out.unprocessed = fc.unprocessed;
        out.success = fc.success;
        out.tjId = fc.creditTjId;
        out.error = fc.error;
      } else {
        // 감액 → 적립 차감
        out.direction = 'debit';
        GdOptionCPointAdjustmentUtil.AccrualCancelResult fd = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
          out.memberId, programId, orderId, null, totalPoints,
          'OPTC_SALE_PATCH_ETC_ACCRUAL_CANCEL: saleNo=' + saleNo +
          ', oldAmount=' + oldAmount + ', newAmount=' + newAmount +
          ', delta=' + delta + ', breakdown=' + breakdown
        );
        out.actual = fd.actualPoints;
        out.unprocessed = fd.loss;
        out.success = fd.success;
        out.tjId = fd.reversalTjId;
        out.error = fd.error;
      }
      return out;
    } catch (Exception e) {
      System.debug('computeAndAdjustForSalePatch exception: ' + e.getMessage());
      out.success = false;
      out.error = e.getMessage();
      return out;
    }
  }

  @TestVisible
  private static Id findPromotionIdForOriginalOrder(Id orderId) {
    if (orderId == null) return null;
    try {
      List<TransactionJournal> tjs = [
        SELECT PromotionId FROM TransactionJournal
        WHERE OrderId = :orderId AND PromotionId != null LIMIT 1
      ];
      return tjs.isEmpty() ? null : tjs[0].PromotionId;
    } catch (Exception e) {
      System.debug('findPromotionIdForOriginalOrder exception: ' + e.getMessage());
      return null;
    }
  }
}