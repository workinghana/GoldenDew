/**
 * 옵션 C 분기 처리 핸들러 — DELETE /gd/v1/sale/deposit (판매 입금 단건 삭제)
 *
 * Wrap 패턴 (기존 핸들러들과 동일 — 표준 로직 100% 실행 + 응답 enrich + force-debit)
 *
 * 적용 시점
 *   GdSaleDepositApiControllerV1.deleteSaleDeposit() 의 표준 로직 후 entry point 에서
 *   GdMigrationUtil.shouldApplyOptionCBranchByDepositNo(depositNo) == true 인 경우
 *   wrapResponseForOldDeposit(...) 호출.
 *
 * 처리 시나리오
 *   - 옛 일자 신규 판매에 대한 입금 단건 삭제
 *   - 표준 cancelPointsCreditedOnPurchase 는 SubType='Purchase Accrual' 만 매칭 → 옛 거래는 'Api Forced Credit' 으로 적립되어 silent skip
 *   - 본 핸들러가 force-debit 으로 차감액 자동 보정
 *
 * 안전성
 *   - Feature Flag OFF 시 절대 호출되지 않음 (controller 가 보장)
 *   - 표준 로직 부수 효과 그대로 보존 (TJ.IsDeleted=true 처리, validation 등)
 *   - force-debit 실패 시 응답 표시만, throw X
 */
public with sharing class GdSaleDepositDeleteBranchHandler {
  @TestVisible
  private static final String WRAP_MESSAGE_SUFFIX = ' (오픈 전 거래 — 입금 삭제 자동 차감 처리)';

  @TestVisible
  private static final String WRAP_REASON = '오픈 전 거래에 대한 입금 단건 삭제 — 옛 적립분 자동 차감 (force-debit) 적용.';

  /**
   * 옛 일자 입금 단건 삭제 응답 wrap.
   *
   * @param standardResult  표준 deleteSaleDeposit 의 결과
   * @param depositNo       삭제 대상 입금 번호 (예: 'DEP202507020191-1')
   * @param logger          ApexLogger (null 허용)
   * @return                enrich 된 ApiResult
   */
  public static ApiResult wrapResponseForOldDeposit(ApiResult standardResult, String depositNo, ApexLogger logger) {
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
    standardResult.data.put('depositNo', depositNo);

    // === 자동 force-debit ===
    DebitOutcome outcome = computeAndForceDebitForDepositDelete(depositNo);

    standardResult.data.put('option_c_eligible_amount', outcome.eligibleAmount);
    standardResult.data.put('option_c_force_debit_requested', outcome.requested);
    standardResult.data.put('option_c_force_debit_actual', outcome.actual);
    standardResult.data.put('option_c_force_debit_loss', outcome.loss);
    standardResult.data.put('option_c_force_debit_success', outcome.success);
    if (outcome.success) {
      standardResult.data.put('point_processing', 'force_debited_with_estimation');
    } else if (outcome.requested == 0) {
      standardResult.data.put('point_processing', 'no_debit_needed');
    } else {
      standardResult.data.put('point_processing', 'force_debit_failed');
    }
    if (outcome.tjId != null) {
      standardResult.data.put('option_c_force_debit_tj_id', outcome.tjId);
    }
    if (String.isNotBlank(outcome.error)) {
      standardResult.data.put('option_c_force_debit_error', outcome.error);
    }

    if (logger != null) {
      logger.setStatus('PARTIAL');
      logger.setDescription(
        'Option C 분기 wrap: DELETE /sale/deposit — 입금 삭제 자동 차감. ' +
          'depositNo=' +
          depositNo +
          ', eligibleAmount=' +
          outcome.eligibleAmount +
          ', requested=' +
          outcome.requested +
          ', actual=' +
          outcome.actual +
          ', loss=' +
          outcome.loss
      );
    }

    Id logId = GdMigrationUtil.recordAdjustmentLog(
      outcome.memberId,
      null,
      'SALE_DEPOSIT_DELETE_BRANCH',
      'DELETE /gd/v1/sale/deposit',
      depositNo,
      outcome.requested,
      outcome.actual,
      '옛 일자 입금 삭제 옵션 C 분기. ' +
        'depositNo=' +
        depositNo +
        ', eligibleAmount=' +
        outcome.eligibleAmount +
        ', breakdown=' +
        outcome.breakdown +
        ', forceSuccess=' +
        outcome.success +
        (String.isBlank(outcome.error) ? '' : ', error=' + outcome.error)
    );
    if (logId != null) {
      standardResult.data.put('adjustment_log_id', logId);
    }

    return standardResult;
  }

  /**
   * force-debit 결과.
   */
  @TestVisible
  private class DebitOutcome {
    Decimal eligibleAmount = 0;
    Decimal requested = 0;
    Decimal actual = 0;
    Decimal loss = 0;
    Boolean success = false;
    Id tjId;
    Id memberId;
    String breakdown = '';
    String error;
  }

  /**
   * 입금 삭제 시 차감 추정 + force-debit 실행.
   *
   * 산식:
   *   eligibleAmount = 삭제 대상 TJ 의 net 적립 가능 금액 (PM 적립 비대상 제외, 환불 음수)
   *   adjustPoints = eligibleAmount × 등급 적립률 (사은포인트 PT='06' 제외)
   *
   * 안전성:
   *   - 모든 SOQL/DML try/catch
   *   - 삭제된 TJ (IsDeleted__c=true, DepositNo='del_*') 도 조회 가능하도록 prefix 분기
   */
  @TestVisible
  /*
  * 기존 로직 
  private static DebitOutcome computeAndForceDebitForDepositDelete(String depositNo) {
    DebitOutcome out = new DebitOutcome();
    if (String.isBlank(depositNo)) {
      out.error = 'invalid input';
      return out;
    }

    try {
      // 표준 로직이 이미 'del_' prefix 를 붙였을 수 있음. 양쪽 모두 시도.
      String delDepositNo = 'del_' + depositNo;
      List<TransactionJournal> tjList = [
        SELECT Id, MemberId, LoyaltyProgramId, OrderId, OrderId__c, SaleId__c,
               PaymentMethod, DepositType__c, TransactionAmount,
               PromotionId, IsDeleted__c, DepositNo__c
        FROM TransactionJournal
        WHERE DepositNo__c IN (:depositNo, :delDepositNo)
        ORDER BY CreatedDate DESC
        LIMIT 5
      ];
      if (tjList.isEmpty()) {
        out.error = 'tj not found for depositNo=' + depositNo;
        return out;
      }

      // 가장 최신 (방금 삭제 처리된) 1건 사용
      TransactionJournal targetTj = tjList[0];
      Id memberId = targetTj.MemberId;
      Id loyaltyProgramId = targetTj.LoyaltyProgramId;
      Id orderId = targetTj.OrderId;
      out.memberId = memberId;

      if (memberId == null) {
        out.error = 'memberId missing on tj';
        return out;
      }
        */
  // * 신규 로직 (26.05.20 CS) Start.
  private static DebitOutcome computeAndForceDebitForDepositDelete(String depositNo) {
    DebitOutcome out = new DebitOutcome();
    if (String.isBlank(depositNo)) {
      out.error = 'invalid input';
      return out;
    }

    try {
      String delDepositNo = 'del_' + depositNo;
      List<TransactionJournal> tjList = [
        SELECT
          Id,
          MemberId,
          LoyaltyProgramId,
          OrderId,
          OrderId__c,
          SaleId__c,
          PaymentMethod,
          DepositType__c,
          TransactionAmount,
          PromotionId,
          IsDeleted__c,
          DepositNo__c
        FROM TransactionJournal
        WHERE DepositNo__c IN (:depositNo, :delDepositNo)
        ORDER BY CreatedDate DESC
        LIMIT 5
      ];
      if (tjList.isEmpty()) {
        out.error = 'tj not found for depositNo=' + depositNo;
        return out;
      }

      TransactionJournal targetTj = tjList[0];
      Id memberId = targetTj.MemberId;
      Id loyaltyProgramId = targetTj.LoyaltyProgramId;
      Id orderId = targetTj.OrderId;
      out.memberId = memberId;

      if (memberId == null) {
        out.error = 'memberId missing on tj';
        return out;
      }

      // [기존: carry-over 이중 차감 방지 fix]
      // Fix #1 (GdSaleDepositServiceImpl.cls:1846) 적용 후 carry-over 케이스는
      // 표준 cancelPointsCreditedOnPurchase 가 실제 적립 LL 을 정상 cancel 한다.
      // 옵션 C force-debit 이 추가 실행되면 추정값만큼 OPTC_RESIDUAL 기타포인트
      // 가 부당 차감 → 이중 차감. carry-over (OrderId__c != null) 검출 시 skip.
      //
      // [Fix 결함 ⑥ 2026-06-08 — carry-over skip 조건 제거]
      //   배경: 위 가정 ("표준 cancel 이 처리") 은 옛 판매 (OPTC) 케이스에서는 적용 안 됨.
      //         옛 판매는 마이그레이션 시 모든 적립이 PT='04' lump (Option C residual lump) 로
      //         통합되어 'Purchase Accrual' SubType LL 자체가 존재하지 않음 →
      //         표준 cancel 결과 0 회수.
      //   영향: carry-over (주문→판매) 입금이 단건 삭제될 때 적립 회수가 누락됨
      //         (SOR Order 입금 단건 삭제 시 ACCRUAL_CANCEL 0건).
      //   해결: 본 함수 (computeAndForceDebitForDepositDelete) 자체가 OPTC 분기 안에서만
      //         호출됨 (shouldApplyOptionCBranchByDepositNo = true). 즉 옛 판매 케이스에서만
      //         진입하므로 carry-over skip 자체가 부정확. 제거하여 OPTC 추가 처리 진행.
      //   안전성:
      //     - 옛 판매에는 'Purchase Accrual' LL 없음 → 표준 cancel 0 회수 → 이중 차감 위험 없음
      //     - 정상 판매: OPTC 분기 자체 진입 안 함 (shouldApplyOptionCBranchByDepositNo = false)
      //     - 옛 판매 + 일반 (carry-over 아님): 이전 동작 그대로
      // * 신규 로직 (26.05.20 CS) End.

      // 1. 적립 가능 금액 (PM 적립 비대상 제외 + 환불 음수 처리)
      List<TransactionJournal> singletonList = new List<TransactionJournal>{ targetTj };
      // 환불(03/05) → 음수 변환된 복사본 사용
      List<TransactionJournal> accrualBasis = buildAccrualBasisCopy(singletonList);
      Decimal eligibleAmount = GdMigrationUtil.calculateEligibleAccrualAmount(accrualBasis, 0);
      if (eligibleAmount == null) {
        eligibleAmount = 0;
      }
      out.eligibleAmount = eligibleAmount;

      if (eligibleAmount <= 0) {
        // 적립 비대상 PM (포인트 사용/본사상품권 등) 또는 환불 → 차감 불필요
        out.success = true;
        return out;
      }

      // 2. 등급 기반 차감 추정
      Id promotionId = targetTj.PromotionId;
      List<GdMigrationUtil.AccrualEstimate> estimates = GdMigrationUtil.calculateAccrualForOldOrder(memberId, eligibleAmount, promotionId);
      Decimal totalPoints = 0;
      String breakdown = '';
      for (GdMigrationUtil.AccrualEstimate est : estimates) {
        if (est == null || est.points == null || est.points <= 0) {
          continue;
        }
        totalPoints += est.points;
        breakdown += (est.subtypeName == null ? '?' : est.subtypeName) + '=' + est.points.toPlainString() + 'P, ';
      }
      out.requested = totalPoints;
      out.breakdown = breakdown;

      if (totalPoints <= 0) {
        out.error = 'no accrual estimate';
        return out;
      }

      // 3. Option C old sale accrual cancel
      GdOptionCPointAdjustmentUtil.AccrualCancelResult fd = GdOptionCPointAdjustmentUtil.cancelOldSaleEtcAccrualSafe(
        memberId,
        loyaltyProgramId,
        orderId,
        null,
        totalPoints,
        'OPTC_SALE_DEPOSIT_DELETE_ETC_ACCRUAL_CANCEL: depositNo=' + depositNo + ', eligibleAmount=' + eligibleAmount + ', breakdown=' + breakdown
      );
      out.actual = fd.actualPoints;
      out.loss = fd.loss;
      out.success = fd.success;
      out.tjId = fd.reversalTjId;
      out.error = fd.error;
      return out;
    } catch (Exception e) {
      System.debug('computeAndForceDebitForDepositDelete exception: ' + e.getMessage());
      out.success = false;
      out.error = e.getMessage();
      return out;
    }
  }

  /**
   * 환불(03/05) 음수 변환된 복사본 생성 (createSaleDepositHistory 의 buildAccrualBasisDeposits 와 동일 패턴).
   */
  @TestVisible
  private static List<TransactionJournal> buildAccrualBasisCopy(List<TransactionJournal> srcList) {
    List<TransactionJournal> result = new List<TransactionJournal>();
    if (srcList == null || srcList.isEmpty()) {
      return result;
    }
    for (TransactionJournal tj : srcList) {
      if (tj == null)
        continue;
      TransactionJournal copy = tj.clone(false, true, false, false);
      Decimal amount = tj.TransactionAmount == null ? 0 : tj.TransactionAmount;
      if ('03'.equals(tj.DepositType__c) || '05'.equals(tj.DepositType__c)) {
        amount *= -1;
      }
      copy.TransactionAmount = amount;
      result.add(copy);
    }
    return result;
  }
}