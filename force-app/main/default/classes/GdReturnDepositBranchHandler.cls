/**
 * 옵션 C 분기 처리 핸들러 — DELETE /gd/v1/return/deposit
 *
 * 적용 시점
 *   GdReturnDepositApiControllerV1.deleteReturnDeposit() 의 entry point 에서
 *   GdMigrationUtil.shouldApplyOptionCBranchByDepositNo(depositNo) == true 인 경우
 *   표준 service 호출 대신 본 핸들러 호출.
 *
 * 보수적 설계 (Phase 2 — silent failure 가시화 우선)
 *   - 강제 차감/적립 시도 X (lump 마이그로 회원별 정확한 source 추적 불가)
 *   - 표준 부수 효과 (TJ.IsDeleted__c=true) 는 보존
 *   - AdditionalNotes__c 에 명시적 마커 추가 (audit trail)
 *   - ApexLogger 상태 PARTIAL 로 설정
 *   - 응답 data 에 point_processing=skipped 명시 → 운영자가 silent failure 인지
 *
 * 효과
 *   - 표준 silent failure (HTTP 200 + 변동 0) 가 → 명시적 (HTTP 200 + skipped 표기)
 *   - 코드 수정 없는 검증 보고서의 발견 1번 차단
 *
 * 호출자 책임
 *   - 컨트롤러 entry point 에서 이 핸들러를 부른 후 반드시 return 하여 표준 로직 우회
 *   - logger 는 controller 가 만든 인스턴스를 그대로 전달 (null 도 안전 처리)
 */
public with sharing class GdReturnDepositBranchHandler {

  // AdditionalNotes__c 에 추가하는 마커 prefix (운영 시 SOQL 로 검색 가능)
  @TestVisible
  private static final String MARKER = 'OPTC_BRANCH_RETURN_DEPOSIT_DELETE';

  // 운영자에게 보여줄 메시지
  @TestVisible
  private static final String SKIP_REASON =
    '오픈 전 거래 — 포인트 자동 처리 미적용. 별도 수동 처리 필요.';

  // AdditionalNotes__c 최대 안전 길이 (LongTextArea 32k 보호)
  private static final Integer MAX_NOTES_LENGTH = 32000;

  /**
   * Entry point.
   *
   * @param depositNo  컨트롤러에서 결합된 입금 번호 (예: 'DEP202507020191-1')
   * @param logger     컨트롤러의 ApexLogger 인스턴스 (null 허용)
   * @return           ApiResult — HTTP 200 + 명시적 skip 정보
   * @throws CustomException 입금 이력 미존재 시 400
   */
  public static ApiResult handle(String depositNo, ApexLogger logger) {
    if (String.isBlank(depositNo)) {
      throw new CustomException(400, 'depositNo 누락');
    }

    // 1. 원본 TJ 조회 (표준과 동일한 필터 + Phase 6.7 force-credit 결정용 필드 추가)
    List<TransactionJournal> tjList = [
      SELECT Id, IsDeleted__c, MemberId, OrderId, InsertId__c,
             AdditionalNotes__c, JournalSubTypeId, TransactionAmount,
             JournalSubType.Name, PaymentMethod, LoyaltyProgramId, SaleId__c
      FROM TransactionJournal
      WHERE DepositNo__c = :depositNo AND IsDeleted__c = FALSE
      LIMIT 1
    ];
    if (tjList.isEmpty()) {
      throw new CustomException(400, '해당 입금 이력이 존재하지 않습니다. ' + depositNo);
    }

    TransactionJournal tj = tjList[0];
    String subTypeName = tj.JournalSubType != null ? tj.JournalSubType.Name : '(unknown)';

    // 2. TJ 마크 + 명시적 마커 추가
    tj.IsDeleted__c = true;
    tj.DeleteDateTime__c = Datetime.now();

    String existingNotes = String.isBlank(tj.AdditionalNotes__c) ? '' : tj.AdditionalNotes__c + ' | ';
    String markerEntry =
      MARKER +
      ': depositNo=' + depositNo +
      ', subType=' + subTypeName +
      ', point_processing=skipped';
    String combined = existingNotes + markerEntry;
    if (combined.length() > MAX_NOTES_LENGTH) {
      combined = combined.substring(0, MAX_NOTES_LENGTH);
    }
    tj.AdditionalNotes__c = combined;

    update tj;

    // 3. 로거 — PARTIAL 상태로 운영자가 추적 가능하게
    if (logger != null) {
      logger.setStatus('PARTIAL');
      logger.setDescription(
        'Option C 분기 처리: DELETE /return/deposit 표준 점수 복원 미적용. ' +
        'depositNo=' + depositNo +
        ', subType=' + subTypeName +
        ', tjId=' + tj.Id
      );
    }

    // 4. Phase 6.7 — 환불 입금 삭제 시 적립 복원 (force-credit)
    //    PaymentMethod='81' (포인트 결제) 는 사용 환원 영역 (시스템 한계) → 안내만
    //    외 결제 (현금/카드 등) 는 환불 시 차감했던 적립을 복원
    ForceCreditOutcome outcome = computeAndForceCreditForDepositDelete(tj);

    // 5. MigrationAdjustmentLog 기록 (실 force 결과 반영)
    Id logId = GdMigrationUtil.recordAdjustmentLog(
      tj.MemberId,
      null,
      'RETURN_DEPOSIT_DELETE_BRANCH',
      'DELETE /gd/v1/return/deposit',
      depositNo,
      outcome.requested,
      outcome.actual,
      'Phase 6.7 — silent fail visualized + force-credit applied (적립 복원). ' +
      'depositNo=' + depositNo + ', subType=' + subTypeName +
      ', paymentMethod=' + (tj.PaymentMethod == null ? 'null' : tj.PaymentMethod) +
      ', forceCreditSuccess=' + outcome.success +
      ', usageRestoreRequired=' + outcome.usageRestoreRequired +
      (String.isBlank(outcome.error) ? '' : ', forceCreditError=' + outcome.error),
      tj.SaleId__c
    );

    // 6. 응답 — Phase 6.7 결과 포함
    Map<String, Object> data = new Map<String, Object>();
    data.put('option_c_branch', true);
    data.put('depositNo', depositNo);
    data.put('subType', subTypeName);
    data.put('reason', SKIP_REASON);
    data.put('tjId', tj.Id);
    data.put('option_c_force_credit_requested', outcome.requested);
    data.put('option_c_force_credit_actual', outcome.actual);
    data.put('option_c_force_credit_unprocessed', outcome.unprocessed);
    if (outcome.success) {
      data.put('point_processing', 'force_credited_with_estimation');
    } else {
      data.put('point_processing', 'skipped');
    }
    if (outcome.creditTjId != null) {
      data.put('option_c_force_credit_tj_id', outcome.creditTjId);
    }
    if (outcome.usageRestoreRequired) {
      data.put('usage_restore_required', true);
      data.put('usage_restore_note', '포인트 결제 환불 입금 → 사용 환원은 운영자 수동 처리 필요');
    }
    if (logId != null) {
      data.put('adjustment_log_id', logId);
    }

    return ApiResult.ok(200, '반품 입금 삭제 완료 (오픈 전 거래 — 포인트 별도 처리 필요)', data);
  }

  /**
   * 적립 복원 결과.
   */
  @TestVisible
  private class ForceCreditOutcome {
    Decimal requested = 0;
    Decimal actual = 0;
    Decimal unprocessed = 0;
    Boolean success = false;
    Id creditTjId;
    String error;
    Boolean usageRestoreRequired = false;
  }

  /**
   * 환불 입금 삭제 시 적립 복원 (force-credit).
   *
   * 정책:
   *   - PaymentMethod='81' (포인트) → 사용 환원 영역 (시스템 한계), force-credit 안 함
   *   - 외 (현금/카드 등) → TransactionAmount × 등급 적립률 만큼 force-credit
   *
   * 안전성:
   *   - 모든 단계 try/catch
   *   - 실패 시 outcome 에 반영, throw 안 함
   */
  private static ForceCreditOutcome computeAndForceCreditForDepositDelete(TransactionJournal tj) {
    ForceCreditOutcome out = new ForceCreditOutcome();

    if (tj == null || tj.MemberId == null || tj.TransactionAmount == null || tj.TransactionAmount <= 0) {
      out.error = 'invalid input';
      return out;
    }

    // PaymentMethod='81' (포인트 결제) 는 사용 환원 영역 — 자동 처리 안 함
    if ('81'.equals(tj.PaymentMethod)) {
      out.usageRestoreRequired = true;
      out.error = 'usage restore required (PaymentMethod=81)';
      return out;
    }

    try {
      // 환불 금액 × 등급 적립률 추정
      List<GdMigrationUtil.AccrualEstimate> estimates = GdMigrationUtil.calculateAccrualForOldOrder(
        tj.MemberId, tj.TransactionAmount, null
      );

      Decimal totalPoints = 0;
      for (GdMigrationUtil.AccrualEstimate est : estimates) {
        if (est.points != null && est.points > 0) {
          totalPoints += est.points;
        }
      }
      out.requested = totalPoints;

      if (totalPoints <= 0) {
        out.error = 'no accrual estimate (rate 0 or no benefit)';
        return out;
      }

      // force-credit (회원의 묶음 잔액에 추가 적립)
      GdMigrationUtil.ForceCreditResult fc = GdMigrationUtil.forceCreditPointsSafe(
        tj.MemberId, tj.LoyaltyProgramId, tj.OrderId, totalPoints,
        'OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT: tjId=' + tj.Id +
        ', refundAmount=' + tj.TransactionAmount.toPlainString()
      );
      out.actual = fc.actualPoints;
      out.unprocessed = fc.unprocessed;
      out.success = fc.success;
      out.creditTjId = fc.creditTjId;
      out.error = fc.error;
      return out;
    } catch (Exception e) {
      System.debug('computeAndForceCreditForDepositDelete exception: ' + e.getMessage());
      out.success = false;
      out.error = e.getMessage();
      return out;
    }
  }
}