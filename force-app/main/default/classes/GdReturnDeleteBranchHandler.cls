/**
 * 옵션 C 분기 처리 핸들러 — DELETE /gd/v1/return (환불 자체 삭제)
 *
 * 적용 시점
 *   GdReturnApiControllerV1.deleteReturn() 의 표준 로직 후 entry point 에서
 *   GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(saleNo) == true 인 경우
 *   wrapResponse(...) 호출.
 *
 * Phase 6.8 동작 — 환불 취소 자동 복원
 *   환불 등록 시 force-debit 으로 차감했던 포인트를 자동 복원.
 *
 *   ⚠️ 중요한 설계 함정 (시스템 한계 영역 4 — 음수 잔액 표현 불가):
 *
 *     [음수 잔액 케이스]
 *       환불 1차 → 차감 시도 1,000P, 잔액 0 → 미차감 1,000 기록, 잔액 0 그대로
 *
 *     [환불 취소 단순 복원의 위험]
 *       단순히 차감 시도액 1,000P 를 복원하면:
 *         회원 잔액 0 → 1,000  ← 회원에게 부당 이익 1,000P
 *         원래 흐름 -1,000 → 0 이어야 함 (변동 없음이 정합)
 *
 *     [올바른 처리]
 *       처리 기록 (MigrationAdjustmentLog__c) 에서 1차 환불의 ActualPoints (실 차감액) 조회
 *       → 실 차감액만 복원 (미차감액 CustomerLoss 는 복원 안 함)
 *       → 회원 잔액 정합 유지
 */
public with sharing class GdReturnDeleteBranchHandler {

  @TestVisible
  private static final String WRAP_MESSAGE_SUFFIX = ' (오픈 전 거래 — 환불 취소 자동 처리)';

  @TestVisible
  private static final String WRAP_REASON =
    '오픈 전 거래에 대한 환불 취소 — 차감했던 포인트 자동 복원 (실 차감액만, 미차감액은 복원 안 함).';

  /**
   * 환불 취소 응답 wrap + 자동 복원.
   *
   * @param standardResult  표준 deleteReturn 의 결과
   * @param saleNo          삭제 대상 환불 번호 (환불 Order 의 SaleNo__c)
   * @param logger          ApexLogger
   * @return                enrich 된 ApiResult
   */
  public static ApiResult wrapResponseForOldReturn(
    ApiResult standardResult,
    String saleNo,
    ApexLogger logger
  ) {
    if (standardResult == null) {
      return standardResult;
    }
    if (standardResult.data == null) {
      standardResult.data = new Map<String, Object>();
    }

    String origMessage = standardResult.message == null ? '' : standardResult.message;
    standardResult.message = origMessage + WRAP_MESSAGE_SUFFIX;
    standardResult.data.put('option_c_branch', true);
    standardResult.data.put('reason', WRAP_REASON);
    standardResult.data.put('saleNo', saleNo);

    // === Phase 6.8 — 환불 취소 자동 복원 ===
    // 처리 기록에서 환불 등록 시 차감 정보 조회 → 실 차감액만 force-credit 으로 복원
    RestoreOutcome outcome = computeAndRestoreForReturnDelete(saleNo);

    standardResult.data.put('option_c_restore_eligible', outcome.eligibleAmount);
    standardResult.data.put('option_c_restore_actual', outcome.actual);
    standardResult.data.put('option_c_restore_unprocessed', outcome.unprocessed);
    standardResult.data.put('option_c_restore_unrestored_loss', outcome.unrestoredLoss);
    standardResult.data.put('option_c_restore_already_restored', outcome.alreadyRestored);
    if (outcome.success) {
      standardResult.data.put('point_processing', 'force_credited_restoration');
    } else {
      standardResult.data.put('point_processing', outcome.eligibleAmount > 0 ? 'restoration_failed' : 'no_restoration_needed');
    }
    if (outcome.creditTjId != null) {
      standardResult.data.put('option_c_restore_tj_id', outcome.creditTjId);
    }

    if (logger != null) {
      logger.setStatus('PARTIAL');
      logger.setDescription(
        'Option C 분기 wrap: DELETE /return — Phase 6.8 환불 취소 자동 복원. ' +
        'saleNo=' + saleNo +
        ', eligibleAmount=' + outcome.eligibleAmount +
        ', actual=' + outcome.actual +
        ', alreadyRestored=' + outcome.alreadyRestored +
        ', unrestoredLoss=' + outcome.unrestoredLoss
      );
    }

    Id logId = GdMigrationUtil.recordAdjustmentLog(
      outcome.memberId, null, 'RETURN_DELETE_BRANCH', 'DELETE /gd/v1/return',
      saleNo,
      outcome.eligibleAmount,
      outcome.actual,
      'Phase 6.8 — 환불 취소 자동 복원 (실 차감액만, 미차감액 복원 안 함). ' +
      'saleNo=' + saleNo +
      ', restoreSuccess=' + outcome.success +
      ', alreadyRestored=' + outcome.alreadyRestored +
      ', unrestoredLoss=' + outcome.unrestoredLoss +
      (String.isBlank(outcome.error) ? '' : ', error=' + outcome.error)
    );
    if (logId != null) {
      standardResult.data.put('adjustment_log_id', logId);
    }

    return standardResult;
  }

  /**
   * 자동 복원 결과.
   */
  @TestVisible
  private class RestoreOutcome {
    Decimal eligibleAmount = 0;     // 복원 대상 금액 (= 환불 등록 시 ActualPoints 합)
    Decimal actual = 0;
    Decimal unprocessed = 0;
    Decimal alreadyRestored = 0;
    Decimal unrestoredLoss = 0;     // 환불 등록 시 미차감액 (복원 안 함)
    Boolean success = false;
    Id creditTjId;
    Id memberId;
    String error;
  }

  /**
   * 환불 취소 시 자동 복원 — 처리 기록 기반.
   *
   * 흐름:
   *   1. 환불 Order 조회 (saleNo → Order)
   *   2. 환불 Order 의 OriginalOrderId (원판매) 추출
   *   3. 처리 기록 조회: 원판매의 RETURN_REGISTER_BRANCH 기록
   *   4. ActualPoints (실 차감액) = 복원 대상
   *      CustomerLoss (미차감액) = 복원 안 함 (영역 4 함정 회피)
   *   5. force-credit 으로 ActualPoints 만 복원
   */
  private static RestoreOutcome computeAndRestoreForReturnDelete(String returnSaleNo) {
    RestoreOutcome out = new RestoreOutcome();
    if (String.isBlank(returnSaleNo)) {
      out.error = 'invalid input — blank saleNo';
      return out;
    }

    try {
      // 1. 환불 Order 조회 (이 시점 IsDeleted__c=true 상태일 수 있음)
      List<Order> returnOrders = [
        SELECT Id, OriginalOrderId__c, MemberNo__c
        FROM Order
        WHERE SaleNo__c = :returnSaleNo
        LIMIT 1
      ];
      if (returnOrders.isEmpty() || returnOrders[0].OriginalOrderId__c == null) {
        out.error = 'return order not found or no original order';
        return out;
      }
      Id returnOrderId = returnOrders[0].Id;
      Id originalOrderId = returnOrders[0].OriginalOrderId__c;
      Id contactId = returnOrders[0].MemberNo__c;

      // 2. 원판매 SaleNo__c 추출 (처리 기록 검색용)
      List<Order> origOrders = [SELECT SaleNo__c FROM Order WHERE Id = :originalOrderId LIMIT 1];
      if (origOrders.isEmpty()) {
        out.error = 'original order not found';
        return out;
      }
      String origSaleNo = origOrders[0].SaleNo__c;

      // 3. 회원 조회
      if (contactId != null) {
        List<LoyaltyProgramMember> lpms = [
          SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE ContactId = :contactId LIMIT 1
        ];
        if (!lpms.isEmpty()) {
          out.memberId = lpms[0].Id;
        }
      }

      // 4. 처리 기록 조회: 1:1 매칭 (ReturnOrderId 우선 + fallback)
      // 26.05.06 CS - 매칭 트랩 회피.
      //   1차: ReturnOrderId__c = 삭제 대상 반품 Order Id 로 1:1 매칭
      //   2차 fallback: 1차에서 못 찾으면 (기존 데이터 호환), OriginalSaleNo + ReturnOrderId__c IS NULL 중
      //                 가장 오래된 1건 (FIFO) 매칭. ReturnOrderId 가 채워진 신규 기록은 제외해서
      //                 fallback 매칭이 신규 기록을 잠식하지 않도록.
      String returnOrderIdStr = String.valueOf(returnOrderId);
      List<MigrationAdjustmentLog__c> logs = [
        SELECT ActualPoints__c, CustomerLoss__c, ReturnOrderId__c
        FROM MigrationAdjustmentLog__c
        WHERE ReturnOrderId__c = :returnOrderIdStr
          AND AdjustType__c = 'RETURN_REGISTER_BRANCH'
        ORDER BY CreatedDate DESC
        LIMIT 1
      ];
      if (logs.isEmpty()) {
        // Fallback — ReturnOrderId 없는 기존 기록만 대상 (신규 기록 잠식 방지)
        logs = [
          SELECT ActualPoints__c, CustomerLoss__c, ReturnOrderId__c
          FROM MigrationAdjustmentLog__c
          WHERE OriginalSaleNo__c = :origSaleNo
            AND AdjustType__c = 'RETURN_REGISTER_BRANCH'
            AND ReturnOrderId__c = NULL
          ORDER BY CreatedDate ASC
          LIMIT 1
        ];
      }
      if (logs.isEmpty()) {
        out.error = 'no RETURN_REGISTER_BRANCH log found — nothing to restore';
        return out;
      }

      // 5. 실 차감액만 복원 (미차감액은 복원 안 함 — 영역 4 함정 회피)
      Decimal actualDebited = logs[0].ActualPoints__c == null ? 0 : logs[0].ActualPoints__c;
      Decimal unrestoredLoss = logs[0].CustomerLoss__c == null ? 0 : logs[0].CustomerLoss__c;
      out.unrestoredLoss = unrestoredLoss;

      if (actualDebited <= 0) {
        // 차감 0 이었으면 복원할 것 없음 (영역 4 의 잔액 0 케이스)
        out.success = true;
        out.error = 'no actual debit to restore (전액 미차감 케이스)';
        return out;
      }

      if (out.memberId == null) {
        out.error = 'member not found';
        return out;
      }

      // A return can be processed as deposit-delete before full return-delete.
      // In that case the deposit-delete branch may already have restored some
      // or all points cancelled by the return registration. Restore only the
      // remaining amount here to avoid double restoration.
      out.alreadyRestored = calculateReturnDepositDeleteRestoredAmount(returnOrderId, out.memberId);
      Decimal remainingToRestore = actualDebited - out.alreadyRestored;
      if (remainingToRestore < 0) {
        remainingToRestore = 0;
      }
      out.eligibleAmount = remainingToRestore;

      if (remainingToRestore <= 0) {
        out.success = true;
        out.error = 'already restored by return deposit delete';
        return out;
      }

      // 6. force-credit
      GdMigrationUtil.ForceCreditResult fc = GdMigrationUtil.forceCreditPointsSafe(
        out.memberId,
        [SELECT ProgramId FROM LoyaltyProgramMember WHERE Id = :out.memberId LIMIT 1].ProgramId,
        originalOrderId,
        remainingToRestore,
        'OPTC_RETURN_DELETE_RESTORE: returnSaleNo=' + returnSaleNo +
        ', origSaleNo=' + origSaleNo +
        ', actualDebited=' + actualDebited.toPlainString() +
        ', alreadyRestored=' + out.alreadyRestored.toPlainString() +
        ', restoreAmount=' + remainingToRestore.toPlainString() +
        ', unrestoredLoss=' + unrestoredLoss.toPlainString() + ' (영역 4 함정 회피)'
      );
      out.actual = fc.actualPoints;
      out.unprocessed = fc.unprocessed;
      out.success = fc.success;
      out.creditTjId = fc.creditTjId;
      out.error = fc.error;
      return out;
    } catch (Exception e) {
      System.debug('computeAndRestoreForReturnDelete exception: ' + e.getMessage());
      out.success = false;
      out.error = e.getMessage();
      return out;
    }
  }

  private static Decimal calculateReturnDepositDeleteRestoredAmount(Id returnOrderId, Id memberId) {
    if (returnOrderId == null || memberId == null) {
      return 0;
    }

    Decimal loggedAmount = 0;
    String returnOrderIdStr = String.valueOf(returnOrderId);
    for (MigrationAdjustmentLog__c logRow : [
      SELECT ActualPoints__c
      FROM MigrationAdjustmentLog__c
      WHERE ReturnOrderId__c = :returnOrderIdStr
        AND AdjustType__c = 'RETURN_DEPOSIT_DELETE_BRANCH'
    ]) {
      if (logRow.ActualPoints__c != null && logRow.ActualPoints__c > 0) {
        loggedAmount += logRow.ActualPoints__c;
      }
    }

    Decimal markerAmount = 0;
    Set<String> deletedReturnDepositTjIds = new Set<String>();
    for (TransactionJournal sourceTj : [
      SELECT Id
      FROM TransactionJournal
      WHERE SaleId__c = :returnOrderId
        AND MemberId = :memberId
        AND AdditionalNotes__c LIKE '%OPTC_BRANCH_RETURN_DEPOSIT_DELETE%'
    ]) {
      deletedReturnDepositTjIds.add(String.valueOf(sourceTj.Id));
    }

    if (!deletedReturnDepositTjIds.isEmpty()) {
      for (TransactionJournal restoreTj : [
        SELECT TransactionAmount, AdditionalNotes__c
        FROM TransactionJournal
        WHERE MemberId = :memberId
          AND AdditionalNotes__c LIKE 'OPTC_FORCE_CREDIT: OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT:%'
      ]) {
        if (String.isBlank(restoreTj.AdditionalNotes__c)) {
          continue;
        }
        for (String sourceTjId : deletedReturnDepositTjIds) {
          if (restoreTj.AdditionalNotes__c.contains('tjId=' + sourceTjId)) {
            markerAmount += restoreTj.TransactionAmount == null ? 0 : restoreTj.TransactionAmount;
            break;
          }
        }
      }
    }

    return loggedAmount > markerAmount ? loggedAmount : markerAmount;
  }
}