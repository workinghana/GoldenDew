/**
 * 옵션 C 분기 처리 핸들러 — DELETE /gd/v1/sale
 *
 * Wrap 패턴 (Phase 3 와 동일 — 표준 로직 100% 실행 + 응답 enrich)
 *
 * 적용 시점
 *   GdSaleApiControllerV1.deleteSale() 의 표준 로직 후 entry point 에서
 *   GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(saleNo) == true 인 경우
 *   wrapResponse(...) 호출.
 *
 * 동작
 *   1. 표준 로직 (Order.Status='saleDeleted', OrderItem 처리, 에코 처리 시도) 그대로 실행됨
 *   2. 표준 결과 → 옛 판매라면 응답 message + data 에 옵션 C 분기 정보 추가
 *   3. ApexLogger 상태 PARTIAL (audit trail)
 *
 * Phase 2/3 와 차이
 *   - Phase 2: TJ.AdditionalNotes 마커 (TJ 가 변경 대상)
 *   - Phase 3: 새 환불 deposit TJ 의 AdditionalNotes 마커
 *   - Phase 4: 마커 없음 (Order 에 적합 필드 없음 + DELETE /sale 은 새 TJ 만들지 않음)
 *           → 추적은 ApexLogger PARTIAL + 응답 data 로 가능
 */
public with sharing class GdSaleDeleteBranchHandler {
  // 응답 message 에 추가되는 suffix
  @TestVisible
  private static final String WRAP_MESSAGE_SUFFIX = ' (오픈 전 거래 — 포인트 별도 처리 필요)';

  // 응답 data 에 추가되는 reason
  @TestVisible
  private static final String WRAP_REASON = '오픈 전 거래에 대한 판매 삭제 — 포인트 자동 처리 미적용. 별도 수동 처리 필요.';

  /**
   * 옛 판매 삭제 응답 wrap.
   *
   * @param standardResult  표준 deleteSale 의 결과
   * @param saleNo          삭제 대상 판매 번호
   * @param logger          ApexLogger (null 허용)
   * @return                enrich 된 ApiResult
   *
   * 호출 조건 (controller 가 보장):
   *   - shouldApplyOptionCBranchBySaleNo(saleNo) == true
   *   - 표준 로직 이미 실행 완료 (Order.Status='saleDeleted', OrderItem 처리 등)
   */
  public static ApiResult wrapResponseForOldSale(ApiResult standardResult, String saleNo, ApexLogger logger) {
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

    // === Phase 6.5 — 잔여 적립 자동 차감 (force-debit) ===
    // 안전 우선: 잔여 판매 금액 (= 판매 금액 - 누계 환불) × 등급 적립률 만큼 차감.
    // 이미 환불된 부분은 환불 시점에 처리되었다고 가정.
    // 사용 환원 (사용한 포인트 복원) 은 자동화 불가 (시스템 한계) — 별도 안내.
    ForceDebitOutcome outcome = computeAndForceDebitForSaleDelete(saleNo);

    standardResult.data.put('option_c_force_debit_requested', outcome.requested);
    standardResult.data.put('option_c_force_debit_actual', outcome.actual);
    standardResult.data.put('option_c_force_debit_loss', outcome.loss);
    if (outcome.success) {
      standardResult.data.put('point_processing', 'force_debited_with_estimation');
    }
    if (outcome.debitTjId != null) {
      standardResult.data.put('option_c_force_debit_tj_id', outcome.debitTjId);
    }
    if (outcome.usageRestoreRequired) {
      standardResult.data.put('usage_restore_required', true);
      standardResult.data.put('usage_restore_note', '이 판매에서 포인트로 결제한 금액이 있음 — 사용 환원은 운영자 수동 처리 필요');
    }

    // === Phase 6.5 보강 — PM=81 사용 환원 자동화 시도 (26.05.06 CS) ===
    // 안전 매칭(TJ.Id 직접) 으로 옵션 C force-debit 흔적과 격리.
    // 실패 시 기존 usage_restore_required 시그널 그대로 → fallback.
    if (outcome.usageRestoreRequired) {
      List<Map<String, Object>> usageRestoreResults = tryAutoRestorePointUsage(saleNo);
      if (!usageRestoreResults.isEmpty()) {
        standardResult.data.put('option_c_usage_restore_results', usageRestoreResults);
        // 모두 성공이면 시그널을 false 로 되돌리고 point_processing 갱신
        Boolean allSuccess = true;
        Decimal totalRestored = 0;
        for (Map<String, Object> r : usageRestoreResults) {
          if (!Boolean.valueOf(r.get('success'))) {
            allSuccess = false;
          }
          Object actObj = r.get('actual');
          if (actObj != null)
            totalRestored += (Decimal) actObj;
        }
        standardResult.data.put('option_c_usage_restore_total_actual', totalRestored);
        if (allSuccess) {
          // 사용 환원 자동 처리 완료 — 시그널 해제
          standardResult.data.put('usage_restore_required', false);
          standardResult.data.put('usage_restore_auto_completed', true);
          standardResult.data.remove('usage_restore_note');
        }
      }
    }

    // 로거 PARTIAL 상태 (audit trail)
    if (logger != null) {
      logger.setStatus('PARTIAL');
      logger.setDescription(
        'Option C 분기 wrap: DELETE /sale — Phase 6.5 적용. ' +
          'saleNo=' +
          saleNo +
          ', forceDebitRequested=' +
          outcome.requested +
          ', forceDebitActual=' +
          outcome.actual +
          ', loss=' +
          outcome.loss +
          ', usageRestoreRequired=' +
          outcome.usageRestoreRequired
      );
    }

    // MigrationAdjustmentLog 기록 (실 force 결과 반영)
    Id logId = GdMigrationUtil.recordAdjustmentLog(
      outcome.memberId,
      null,
      'SALE_DELETE_BRANCH',
      'DELETE /gd/v1/sale',
      saleNo,
      outcome.requested,
      outcome.actual,
      'Phase 6.5 — silent fail visualized + force-debit applied (잔여 적립 차감). ' +
        'saleNo=' +
        saleNo +
        ', forceDebitSuccess=' +
        outcome.success +
        ', estimateBreakdown=' +
        outcome.breakdown +
        ', usageRestoreRequired=' +
        outcome.usageRestoreRequired +
        (String.isBlank(outcome.error) ? '' : ', forceDebitError=' + outcome.error)
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
    Boolean usageRestoreRequired = false;
  }

  /**
   * 옛 판매 삭제 시 잔여 적립 자동 차감.
   *
   * 흐름:
   *   1. 판매 Order 조회 (회원 + 금액)
   *   2. 회원 (Contact → LoyaltyProgramMember) 조회
   *   3. 누계 환불 금액 조회 (returnSuccess 만)
   *   4. 잔여 판매 금액 = 판매 금액 - 누계 환불
   *   5. 잔여 ≤ 0 → skip (이미 전액 환불된 판매)
   *   6. calculateAccrualForOldOrder 로 추정
   *   7. forceDebitPointsSafe 호출
   *   8. 사용 환원 필요 여부 검사 (포인트 결제 TJ 존재 여부)
   *
   * 안전성:
   *   - 모든 DML / SOQL try/catch
   *   - 실패 시 outcome.success=false, throw 없음
   */
  private static ForceDebitOutcome computeAndForceDebitForSaleDelete(String saleNo) {
    ForceDebitOutcome out = new ForceDebitOutcome();
    if (String.isBlank(saleNo)) {
      out.error = 'invalid input — blank saleNo';
      return out;
    }

    try {
      // 1. 판매 Order 조회
      List<Order> orders = [
        SELECT Id, MemberNo__c, ActualPaymentAmount__c
        FROM Order
        WHERE SaleNo__c = :saleNo
        LIMIT 1
      ];
      if (orders.isEmpty() || orders[0].MemberNo__c == null) {
        out.error = 'sale not found or member missing';
        return out;
      }
      Id contactId = orders[0].MemberNo__c;
      Id orderId = orders[0].Id;
      Decimal saleAmount = orders[0].ActualPaymentAmount__c;
      if (saleAmount == null || saleAmount <= 0) {
        out.error = 'sale amount missing or non-positive';
        return out;
      }

      // 2. ContactId → LoyaltyProgramMember
      List<LoyaltyProgramMember> lpms = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :contactId LIMIT 1];
      if (lpms.isEmpty()) {
        out.error = 'loyalty member not found for contact';
        return out;
      }
      out.memberId = lpms[0].Id;
      Id programId = lpms[0].ProgramId;

      // 3. 누계 환불 (returnSuccess 만 카운트)
      Decimal totalReturned = 0;
      for (Order ret : [
        SELECT ActualPaymentAmount__c
        FROM Order
        WHERE OriginalOrderId__c = :orderId AND IsDeleted__c = FALSE AND IsReductionOrder__c = TRUE AND Status = 'returnSuccess'
      ]) {
        if (ret.ActualPaymentAmount__c != null && ret.ActualPaymentAmount__c > 0) {
          totalReturned += ret.ActualPaymentAmount__c;
        }
      }

      // 4. 잔여 판매 금액 (이미 환불된 부분은 환불 시점에 처리됐다고 가정)
      Decimal remainingAmount = saleAmount - totalReturned;
      if (remainingAmount <= 0) {
        out.error = 'no remaining amount (already fully refunded)';
        return out;
      }

      // 5. 원판매에 적용된 Promotion (있으면)
      Id promotionId = findPromotionIdForOriginalOrder(orderId);

      // 6. 잔여 적립 추정
      List<GdMigrationUtil.AccrualEstimate> estimates = GdMigrationUtil.calculateAccrualForOldOrder(out.memberId, remainingAmount, promotionId);

      Decimal totalRequested = 0;
      String breakdown = '';
      for (GdMigrationUtil.AccrualEstimate est : estimates) {
        if (est.points != null && est.points > 0) {
          totalRequested += est.points;
          breakdown += (est.subtypeName == null ? '?' : est.subtypeName) + '=' + est.points.toPlainString() + 'P, ';
        }
      }
      out.requested = totalRequested;
      out.breakdown = breakdown;

      if (totalRequested <= 0) {
        out.error = 'no accrual estimate (rate 0 or no benefit)';
        return out;
      }

      // 7. Option C old sale accrual cancel
      GdOptionCPointAdjustmentUtil.AccrualCancelResult fd = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
        out.memberId,
        programId,
        orderId,
        null,
        totalRequested,
        'OPTC_SALE_DELETE_ETC_ACCRUAL_CANCEL: saleNo=' + saleNo + ', remainingAmount=' + remainingAmount.toPlainString() + ', breakdown=' + breakdown
      );
      out.actual = fd.actualPoints;
      out.loss = fd.loss;
      out.success = fd.success;
      out.debitTjId = fd.reversalTjId;
      out.error = fd.error;

      // 8. 사용 환원 필요 여부 (포인트 결제 TJ 존재 여부)
      out.usageRestoreRequired = checkUsageRestoreRequired(orderId);

      return out;
    } catch (Exception e) {
      System.debug('computeAndForceDebitForSaleDelete exception: ' + e.getMessage());
      out.success = false;
      out.error = e.getMessage();
      return out;
    }
  }

  /**
   * 원판매 Order 의 적립 TJ 에서 PromotionId 추출.
   */
  @TestVisible
  private static Id findPromotionIdForOriginalOrder(Id orderId) {
    if (orderId == null) {
      return null;
    }
    try {
      List<TransactionJournal> tjs = [
        SELECT PromotionId
        FROM TransactionJournal
        WHERE OrderId = :orderId AND PromotionId != NULL
        LIMIT 1
      ];
      return tjs.isEmpty() ? null : tjs[0].PromotionId;
    } catch (Exception e) {
      System.debug('findPromotionIdForOriginalOrder exception: ' + e.getMessage());
      return null;
    }
  }

  /**
   * 판매에 포인트 결제 TJ 가 있으면 사용 환원 필요.
   * (PaymentMethod='81' = 포인트 결제)
   */
  @TestVisible
  private static Boolean checkUsageRestoreRequired(Id orderId) {
    if (orderId == null) {
      return false;
    }
    try {
      // [Fix #3 2026-05-25] IsDeleted 필터 제거 + 이미 환원된(del_point_) TJ 제외
      //   배경: 입금 단건 삭제로 IsDel=true 된 PM=81 TJ 가 SOQL 에서 빠져
      //         환원이 필요한데도 시그널이 false 가 되어 safety net 자체 trigger 안 됨.
      //   해결: IsDel 필터 제거. 단 del_point_ prefix 로 이미 환원된 TJ 는 idempotency
      //         차원에서 제외 (중복 환원 방지).
      List<TransactionJournal> pointPaymentTjs = [
        SELECT Id, DepositNo__c
        FROM TransactionJournal
        WHERE OrderId = :orderId AND PaymentMethod = '81' AND (DepositNo__c = NULL OR (NOT DepositNo__c LIKE 'del_point_%'))
        LIMIT 1
      ];
      return !pointPaymentTjs.isEmpty();
    } catch (Exception e) {
      System.debug('checkUsageRestoreRequired exception: ' + e.getMessage());
      return false;
    }
  }

  /**
   * 26.05.06 CS — Phase 6.5 보강
   * 옛 판매의 PM=81 TJ 들을 찾아 사용 환원 자동화 시도.
   *
   * 안전 매칭: GdMigrationUtil.cancelOldSalePointUsageSafe 가 TJ.Id 직접 매칭으로
   *           옵션 C force-debit 흔적과 자동 격리.
   *
   * 반환 형식: PM=81 TJ 1건당 1개의 결과 Map.
   *   - tjId, depositNo, amount, success, requested, actual, unprocessed, error, lltMissing
   *
   * 실패/누락 시 호출자가 시그널 fallback.
   */
  @TestVisible
  private static List<Map<String, Object>> tryAutoRestorePointUsage(String saleNo) {
    List<Map<String, Object>> results = new List<Map<String, Object>>();
    if (String.isBlank(saleNo)) {
      return results;
    }
    try {
      List<Order> orders = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
      if (orders.isEmpty()) {
        return results;
      }
      Id orderId = orders[0].Id;

      // [Fix #3 2026-05-25] IsDeleted 필터 제거 + 이미 환원된(del_point_) TJ 제외
      //   배경: 입금 단건 삭제로 IsDel=true 된 PM=81 TJ 가 SOQL 에서 빠져
      //         safety net 의 환원 대상이 0건이 되어 사용 포인트 영구 손실.
      //   해결: IsDel 필터 제거. del_point_ prefix 환원 TJ 는 idempotency 차원 제외.
      List<TransactionJournal> pm81Tjs = [
        SELECT Id, DepositNo__c, MemberId, OrderId, LoyaltyProgramId, PaymentMethod, TransactionAmount, IsDeleted__c
        FROM TransactionJournal
        WHERE OrderId = :orderId AND PaymentMethod = '81' AND (DepositNo__c = NULL OR (NOT DepositNo__c LIKE 'del_point_%'))
      ];

      for (TransactionJournal pm81Tj : pm81Tjs) {
        GdMigrationUtil.CancelOldSalePointUsageResult r = GdMigrationUtil.cancelOldSalePointUsageSafe(pm81Tj);

        Map<String, Object> entry = new Map<String, Object>{
          'tjId' => pm81Tj.Id,
          'depositNo' => pm81Tj.DepositNo__c,
          'amount' => pm81Tj.TransactionAmount,
          'success' => r.success,
          'requested' => r.requestedPoints,
          'actual' => r.actualPoints,
          'unprocessed' => r.unprocessed,
          'creditTjId' => r.creditTjId,
          'matchedLLTCount' => r.matchedLLTCount,
          'lltMissing' => r.lltMissing,
          'error' => r.error
        };
        results.add(entry);
      }
    } catch (Exception e) {
      System.debug('tryAutoRestorePointUsage exception: ' + e.getMessage());
    }
    return results;
  }
}