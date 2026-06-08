/**
 * LoyaltyPointIntegrityEngine
 *
 * 포인트 정합성 검증 엔진 — Event Replay paradigm.
 *
 * paradigm:
 *   - 회원의 모든 paradigm 이벤트 (판매/반품/사용/취소/만료/복원/OPTC/수동) 를 시간순으로 정렬
 *   - 각 이벤트마다 paradigm 으로 기대 변화량 계산 → 실제 LL 변화량과 비교
 *   - 이벤트별 mismatch 를 정확히 기록 (어느 거래가 paradigm 위반인지 식별)
 *   - 최종 가상 LMC 잔액과 실제 LMC 비교
 *
 * 1차 구현 범위 (이번 단계):
 *   - SALE_ACCRUAL          (A 판매 적립)
 *   - RETURN_CANCEL         (B 반품 적립 취소)
 *   - DELETED_SALE_CANCEL   (B+ 삭제 Order 자기 취소)
 *
 * 후속 단계:
 *   - POINT_USE / POINT_USE_CANCEL (C, D)
 *   - EXPIRE (E)
 *   - RESTORE (F)
 *   - OPTC_LUMP / ORDER_UPDATE_MARK (G, J)
 *   - MANUAL / API_FORCED (I — paradigm 외 audit)
 *
 * 운영 코드 참조:
 *   - GdPointServiceImpl.creditPointsOnPurchaseV2 (L4868-)
 *   - GdSaleDepositServiceImpl (L530-547 매장 적립 제외)
 */
public without sharing class LoyaltyPointIntegrityEngine {
  private static final Set<String> STORE_TYPE_EXCLUDED = new Set<String>{ '20', '25', '33' };
  private static final Set<String> PAYMENT_METHOD_NON_ACCRUAL = new Set<String>{ '20', '81', '90', '93' };
  private static final String JST_PURCHASE_ACCRUAL = 'Purchase Accrual';
  private static final String JST_PROMOTION_ACCRUAL = 'Promotion Point Accrual';
  private static final String JST_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual';
  private static final String JST_PROMOTION_ACCRUAL_REVERSAL = 'Promotion Point Accrual Reversal';
  // [Phase 3.4 F] RESTORE Debit 마커
  private static final String RESTORE_NOTE = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';
  // [Phase 3.4 J] 주문 수정 마커
  private static final String ORDER_UPDATE_NOTE = '주문 수정 포인트 사용 취소 완료';

  // ============================================================
  // Public API
  // ============================================================
  public static IntegrityResult validateByMemberNo(String memberNo) {
    IntegrityResult result = new IntegrityResult();
    result.memberNo = memberNo;
    result.eventMismatches = new List<EventMismatch>();
    result.mismatchDetails = new List<String>();
    result.expectedByPointType = new Map<String, Decimal>();
    result.actualByPointType = new Map<String, Decimal>();
    result.expectedCancellationByPointType = new Map<String, Decimal>();
    result.actualCancellationByPointType = new Map<String, Decimal>();

    if (String.isBlank(memberNo)) {
      result.isValid = false;
      result.summary = '회원번호가 비어있습니다.';
      return result;
    }

    // 1. MemberContext 로드
    MemberContext ctx;
    try {
      ctx = loadMemberContext(memberNo);
    } catch (Exception e) {
      result.isValid = false;
      result.summary = 'MemberContext 로드 실패: ' + e.getMessage();
      return result;
    }
    if (ctx.member == null) {
      result.isValid = false;
      result.summary = '회원을 찾을 수 없습니다: ' + memberNo;
      return result;
    }
    result.memberId = ctx.member.Id;
    result.memberName = ctx.member.Contact == null ? null : ctx.member.Contact.Name;
    result.isMigratedMember = ctx.isMigratedMember == true;
    result.migrationCutoffDate = ctx.migrationCutoffDate;

    // ============================================================
    // [paradigm 정확성 강화 2026-06-15] 운영 paradigm (GdPointRefreshPreviewService) 호출
    //   운영 코드의 paradigm 정의를 100% 그대로 사용 — paradigm 정확성 보장
    //   실패 시 내 엔진 fallback (paradigm 위반 회원도 처리 가능)
    //
    // [paradigm 보강 2026-06-15 #2] OpeningPointBalance__c 누락 시 OPTC LL.Points fallback
    //   마이그레이션 paradigm:
    //     ① 사용가능 덩어리 (OPTC LL "Option C residual lump") + OpeningPointBalance__c 저장
    //     ② 사용 덩어리 (paradigm 시뮬레이션용)
    //   OpeningPointBalance__c 가 null 이면 OPTC LL.Points 로 자동 전달 → paradigm 정확
    // ============================================================
    try {
      Date opOpenDate = resolveOperationalOpenDate(ctx);
      Map<String, Decimal> opOpeningPoints = resolveOperationalOpeningPoints(ctx);
      // useCreatedDateCutoff=false: cutoff 이전 sale 의 OPTC_OLD_SALE_ETC_ACCRUAL 재시뮬레이션 비활성화
      //   마이그레이션 paradigm 상 cutoff 이전 거래는 OPTC lump / OpeningPointBalance__c 에 이미 통합되어 있음
      GdPointRefreshPreviewService.PreviewResult opPreview =
        new GdPointRefreshPreviewService().simulateMember(memberNo, opOpenDate, opOpeningPoints, false, null);
      result.operationalSuccess = true;
      result.operationalExpectedBalance = opPreview.totalRemaining;
      result.operationalEventCount = opPreview.eventCount;
      result.operationalBucketCount = opPreview.bucketCount;
      result.operationalRemainingByPointType = opPreview.remainingByPointType;
      result.operationalOpenDate = opOpenDate;
    } catch (Exception opEx) {
      result.operationalSuccess = false;
      result.operationalError = opEx.getMessage();
      // 운영 paradigm 실패 회원 — 내 엔진 fallback 진행
    }

    // 2. Timeline 로드 (이벤트 시간순)
    List<TimelineEvent> timeline = loadTimeline(ctx);
    result.eventCount = timeline.size();

    if (timeline.isEmpty()) {
      result.isValid = true;
      result.summary = '거래 이력 없음 (검증 대상 0건)';
      return result;
    }

    // 3. ReplayContext 준비 — promotion limits + 실제 LL ↔ Order 매핑 + 입금 TJ 기반 적립 대상금액
    ReplayContext rctx = new ReplayContext();
    rctx.ctx = ctx;
    rctx.promoLimitsByPromoId = loadPromotionPointLimits(collectPromotionIds(timeline));
    loadActualLLByOrderId(ctx.member.Id, rctx);
    // [paradigm 정확화 2026-06-01] 적립 대상금액은 OrderItem 합이 아닌 Sale Deposit TJ 기준
    //   운영 paradigm (GdPointServiceImpl.calculateEligibleAccrualAmount L9698) mirror:
    //     - Sale Deposit TJ 의 TransactionAmount 합 (PaymentMethod 20/81/90/93 제외)
    //     - 동일 SaleId 의 여러 입금 TJ 합산
    rctx.eligibleAmountByOrderIdFromTJs = loadEligibleAmountFromTJs(ctx.member.Id);
    rctx.returnEligibleAmountByOrderIdFromTJs = loadReturnEligibleAmountFromTJs(ctx.member.Id);
    loadActualUsageLLByTJ(ctx.member.Id, rctx);
    loadActualExpireLLByTJ(ctx.member.Id, rctx);
    loadActualManualLLByTJ(ctx.member.Id, rctx);

    // 4. Event Replay
    VirtualState state = new VirtualState();
    for (TimelineEvent e : timeline) {
      processEvent(e, state, rctx, result);
    }

    // 5. 최종 가상 LMC vs 실제 LMC 비교
    Decimal finalExpectedBalance = state.totalBalance();
    Decimal finalActualBalance = queryFinalLMCBalance(ctx.member.Id);
    result.finalExpectedBalance = finalExpectedBalance;
    result.finalActualBalance = finalActualBalance;
    result.finalBalanceDifference = finalExpectedBalance - finalActualBalance;

    // 6. 누적 요약 (호환 유지)
    populateAggregateSummary(result, rctx);
    result.totalDifference = (result.totalActualAccrual == null ? 0 : result.totalActualAccrual)
                           - (result.totalActualCancellation == null ? 0 : result.totalActualCancellation)
                           - (result.totalExpectedAccrual == null ? 0 : result.totalExpectedAccrual)
                           + (result.totalExpectedCancellation == null ? 0 : result.totalExpectedCancellation);

    result.salesCount = countByType(timeline, EventType.SALE_ACCRUAL);
    result.returnsCount = countByType(timeline, EventType.RETURN_CANCEL);
    result.mismatchCount = result.eventMismatches.size();

    // [운영 paradigm 결합] operationalDifference 계산
    if (result.operationalSuccess == true && result.operationalExpectedBalance != null) {
      result.operationalDifference = result.operationalExpectedBalance - finalActualBalance;
    }

    // 정합 판정 paradigm:
    //   1순위: 운영 paradigm 결과 (paradigm 정확성)
    //   2순위: 내 엔진 결과 (paradigm 위반 식별)
    Boolean operationalValid = result.operationalSuccess == true
      && result.operationalDifference != null
      && result.operationalDifference == 0;
    Boolean myEngineValid = (result.mismatchCount == 0 && result.finalBalanceDifference == 0);
    result.isValid = operationalValid || (result.operationalSuccess != true && myEngineValid);

    if (result.isValid) {
      if (operationalValid) {
        result.summary = '✅ 운영 paradigm 정합 (가상 ' + result.operationalExpectedBalance + 'P = 실제 LMC)';
      } else {
        result.summary = '✅ Event Replay 통과 (' + timeline.size() + ' 이벤트)';
      }
    } else {
      List<String> issues = new List<String>();
      if (result.operationalSuccess == true && result.operationalDifference != 0) {
        issues.add('운영 paradigm 차이 ' + result.operationalDifference + 'P');
      }
      if (result.operationalSuccess == false) {
        issues.add('운영 paradigm 실패: ' + result.operationalError);
      }
      if (result.mismatchCount > 0) {
        issues.add('내 엔진 mismatch ' + result.mismatchCount + '건');
      }
      if (result.finalBalanceDifference != 0) {
        issues.add('내 엔진 LMC 차이 ' + result.finalBalanceDifference + 'P');
      }
      result.summary = '⚠️ 결함 — ' + String.join(issues, ' / ');
    }

    // 호환 — 이벤트 mismatch 를 mismatchDetails 문자열로 요약
    for (EventMismatch m : result.eventMismatches) {
      result.mismatchDetails.add(m.toSummary());
    }

    return result;
  }

  // ============================================================
  // Timeline 로드
  // ============================================================
  private static List<TimelineEvent> loadTimeline(MemberContext ctx) {
    List<TimelineEvent> events = new List<TimelineEvent>();
    Datetime cutoff = ctx.migrationCutoffDate;

    // 판매 Order (활성 + 삭제 포함)
    for (Order sale : loadSales(ctx.member.Id)) {
      // OPTC 마이그레이션 cutoff 이전 거래 skip — paradigm 외 (LL 없거나 OPTC lump 에 통합)
      if (cutoff != null && sale.EffectiveDate != null && sale.EffectiveDate < cutoff) {
        continue;
      }
      TimelineEvent eAccrual = new TimelineEvent();
      eAccrual.occurredAt = sale.EffectiveDate != null
        ? sale.EffectiveDate
        : Datetime.newInstance(2000, 1, 1);
      eAccrual.eventType = EventType.SALE_ACCRUAL;
      eAccrual.relatedRecordId = sale.Id;
      eAccrual.relatedOrder = sale;
      events.add(eAccrual);

      // 삭제된 Order 는 자기 적립 100% 취소 이벤트 추가
      if (sale.IsDeleted__c == true) {
        TimelineEvent eCancel = new TimelineEvent();
        // 시간 우선순위: 적립 후 취소이므로 살짝 이후
        eCancel.occurredAt = eAccrual.occurredAt.addSeconds(1);
        eCancel.eventType = EventType.DELETED_SALE_CANCEL;
        eCancel.relatedRecordId = sale.Id;
        eCancel.relatedOrder = sale;
        events.add(eCancel);
      }
    }

    // 반품 Order
    for (Order rtn : loadReturns(ctx)) {
      if (cutoff != null && rtn.EffectiveDate != null && rtn.EffectiveDate < cutoff) continue;
      TimelineEvent e = new TimelineEvent();
      e.occurredAt = rtn.EffectiveDate != null
        ? rtn.EffectiveDate
        : Datetime.newInstance(2000, 1, 1);
      e.eventType = EventType.RETURN_CANCEL;
      e.relatedRecordId = rtn.Id;
      e.relatedOrder = rtn;
      events.add(e);
    }

    // [Phase 3.3+F+J] 사용 이벤트 — POINT_USE / POINT_USE_CANCEL / RESTORE / ORDER_UPDATE_MARK 분류
    for (TransactionJournal tj : loadPointUsageTJs(ctx.member.Id)) {
      Datetime occurred = tj.ActivityDate != null ? tj.ActivityDate : tj.CreatedDate;
      if (cutoff != null && occurred != null && occurred < cutoff) continue;
      TimelineEvent e = new TimelineEvent();
      e.occurredAt = occurred;
      e.eventType = classifyUsageEvent(tj);
      e.relatedRecordId = tj.Id;
      e.relatedTj = tj;
      e.txAmount = tj.TransactionAmount == null ? 0 : tj.TransactionAmount;
      events.add(e);
    }

    // [Phase 3.4 E] 만료 이벤트 — Auto Expire / API Forced Expire
    for (TransactionJournal tj : loadExpireTJs(ctx.member.Id)) {
      Datetime occurred = tj.ActivityDate != null ? tj.ActivityDate : tj.CreatedDate;
      if (cutoff != null && occurred != null && occurred < cutoff) continue;
      TimelineEvent e = new TimelineEvent();
      e.occurredAt = occurred;
      e.eventType = EventType.EXPIRE;
      e.relatedRecordId = tj.Id;
      e.relatedTj = tj;
      e.txAmount = tj.TransactionAmount == null ? 0 : tj.TransactionAmount;
      events.add(e);
    }

    // [Phase 3.4 I] 수동/API Forced 이벤트 — paradigm 외 audit
    for (TransactionJournal tj : loadManualAdjustTJs(ctx.member.Id)) {
      Datetime occurred = tj.ActivityDate != null ? tj.ActivityDate : tj.CreatedDate;
      if (cutoff != null && occurred != null && occurred < cutoff) continue;
      TimelineEvent e = new TimelineEvent();
      e.occurredAt = occurred;
      e.eventType = EventType.MANUAL_ADJUST;
      e.relatedRecordId = tj.Id;
      e.relatedTj = tj;
      e.txAmount = tj.TransactionAmount == null ? 0 : tj.TransactionAmount;
      events.add(e);
    }

    events.sort();
    return events;
  }

  private static List<TransactionJournal> loadExpireTJs(Id memberId) {
    return [
      SELECT Id, MemberId, ActivityDate, CreatedDate, TransactionAmount,
             JournalSubType.Name
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND IsDeleted__c = FALSE
        AND JournalSubType.Name IN ('Auto Expire', 'Api Forced Expire')
        AND TransactionAmount > 0
      ORDER BY ActivityDate ASC, CreatedDate ASC
      LIMIT 1000
    ];
  }

  private static List<TransactionJournal> loadManualAdjustTJs(Id memberId) {
    return [
      SELECT Id, MemberId, ActivityDate, CreatedDate, TransactionAmount,
             JournalSubType.Name, AdditionalNotes__c
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND IsDeleted__c = FALSE
        AND JournalSubType.Name IN (
          'Manual Points Credit', 'Manual Points Debit',
          'Api Forced Credit', 'Api Forced Debit',
          'Manual Coupon Issuance'
        )
        AND TransactionAmount > 0
      ORDER BY ActivityDate ASC, CreatedDate ASC
      LIMIT 1000
    ];
  }

  private static Boolean isPointUseCancelJST(String jstName) {
    return 'Point Redeem Cancel'.equals(jstName) || 'Coupon Redeem Cancel'.equals(jstName);
  }

  /**
   * 사용 이벤트 분류 — Point Debit 의 AdditionalNotes 마커 기반 분기
   *   RESTORE_NOTE (반품 입금 삭제 복원) → EventType.RESTORE
   *   ORDER_UPDATE_NOTE (주문 수정 마커) → EventType.ORDER_UPDATE_MARK
   *   그 외 Point Debit / Coupon Redeem → POINT_USE
   *   Point Redeem Cancel / Coupon Redeem Cancel → POINT_USE_CANCEL
   */
  private static EventType classifyUsageEvent(TransactionJournal tj) {
    String jstName = tj.JournalSubType == null ? null : tj.JournalSubType.Name;
    String notes = tj.AdditionalNotes__c;

    if ('Point Debit'.equals(jstName)) {
      if (RESTORE_NOTE.equals(notes)) return EventType.RESTORE;
      if (ORDER_UPDATE_NOTE.equals(notes)) return EventType.ORDER_UPDATE_MARK;
      return EventType.POINT_USE;
    }
    if ('Coupon Redeem'.equals(jstName)) {
      return EventType.POINT_USE;
    }
    if (isPointUseCancelJST(jstName)) {
      return EventType.POINT_USE_CANCEL;
    }
    return EventType.POINT_USE;
  }

  /**
   * 포인트 사용 / 취소 TJ 로드 — Point Debit, Coupon Redeem, Point Redeem Cancel, Coupon Redeem Cancel
   *   AdditionalNotes__c 필드도 select (RESTORE / ORDER_UPDATE 마커 식별용)
   */
  private static List<TransactionJournal> loadPointUsageTJs(Id memberId) {
    return [
      SELECT Id, MemberId, ActivityDate, CreatedDate, TransactionAmount,
             PaymentMethod, JournalSubType.Name, SaleId__c, OrderId__c, IsDeleted__c,
             AdditionalNotes__c
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND IsDeleted__c = FALSE
        AND JournalSubType.Name IN ('Point Debit', 'Coupon Redeem', 'Point Redeem Cancel', 'Coupon Redeem Cancel')
        AND TransactionAmount > 0
      ORDER BY ActivityDate ASC, CreatedDate ASC
      LIMIT 1000
    ];
  }

  private static Set<Id> collectPromotionIds(List<TimelineEvent> events) {
    Set<Id> ids = new Set<Id>();
    for (TimelineEvent e : events) {
      if (e.relatedOrder != null && e.relatedOrder.PromotionId__c != null) {
        ids.add(e.relatedOrder.PromotionId__c);
      }
    }
    return ids;
  }

  // ============================================================
  // 실제 LL ↔ Order 매핑 로드
  //   LL.TransactionJournal.SaleId__c = Order.Id paradigm
  //   적립 / 취소 LL 을 각각 SaleId 기준 그룹화
  // ============================================================
  private static void loadActualLLByOrderId(Id memberId, ReplayContext rctx) {
    rctx.actualAccrualByOrderId = new Map<Id, Map<String, Decimal>>();
    rctx.actualCancelByOrderId = new Map<Id, Map<String, Decimal>>();

    for (LoyaltyLedger ll : [
      SELECT Points, EventType,
             TransactionJournal.SaleId__c,
             TransactionJournal.JournalSubType.Name,
             LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.SaleId__c != NULL
        AND TransactionJournal.JournalSubType.Name IN (
          :JST_PURCHASE_ACCRUAL,
          :JST_PROMOTION_ACCRUAL,
          :JST_CANCEL_PURCHASE_ACCRUAL,
          :JST_PROMOTION_ACCRUAL_REVERSAL
        )
        AND Points > 0
      LIMIT 5000
    ]) {
      Id saleIdAsOrderId = tryParseId(ll.TransactionJournal.SaleId__c);
      if (saleIdAsOrderId == null) {
        continue;
      }
      String pt = ll.LoyaltyPgmCrcySubtype == null
        ? null
        : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      if (String.isBlank(pt)) continue;
      Decimal pts = ll.Points == null ? 0 : ll.Points;

      String jstName = ll.TransactionJournal.JournalSubType.Name;
      Boolean isAccrual = JST_PURCHASE_ACCRUAL.equals(jstName) || JST_PROMOTION_ACCRUAL.equals(jstName);
      Boolean isCancel = JST_CANCEL_PURCHASE_ACCRUAL.equals(jstName) || JST_PROMOTION_ACCRUAL_REVERSAL.equals(jstName);

      Map<Id, Map<String, Decimal>> target = isAccrual
        ? rctx.actualAccrualByOrderId
        : (isCancel ? rctx.actualCancelByOrderId : null);
      if (target == null) continue;

      if (!target.containsKey(saleIdAsOrderId)) {
        target.put(saleIdAsOrderId, new Map<String, Decimal>());
      }
      Map<String, Decimal> bucket = target.get(saleIdAsOrderId);
      bucket.put(pt, (bucket.containsKey(pt) ? bucket.get(pt) : 0) + pts);
    }
  }

  /**
   * 적립 대상금액 계산 — 운영 paradigm mirror
   *   GdPointServiceImpl.calculateEligibleAccrualAmount (L9698) 와 동일:
   *     - Sale Deposit TJ 의 TransactionAmount 합
   *     - PaymentMethod IN ('20','81','90','93') 제외 (포인트/이코점/기타 비현금)
   *     - 같은 SaleId 의 분할 입금 합산
   *   TJ.SaleId__c = Order.Id paradigm
   */
  private static Map<Id, Decimal> loadEligibleAmountFromTJs(Id memberId) {
    Map<Id, Decimal> result = new Map<Id, Decimal>();
    // [paradigm 정확화 2026-06-01] IsDeleted__c 필터 제거.
    //   삭제된 Order(자기 cancel paradigm) 의 적립 시점 paradigm 도 mirror 하려면
    //   당시 active 였던 모든 Sale Deposit TJ 를 봐야 함. 입금이 후에 삭제됐어도
    //   적립 자체는 입금 발생 시점 TJ amount × 등급 혜택 비율로 발생.
    for (TransactionJournal tj : [
      SELECT SaleId__c, PaymentMethod, TransactionAmount
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND JournalSubType.Name = 'Sale Deposit'
        AND SaleId__c != NULL
        AND TransactionAmount > 0
      LIMIT 5000
    ]) {
      if (PAYMENT_METHOD_NON_ACCRUAL.contains(tj.PaymentMethod)) continue;
      Id orderId = tryParseId(tj.SaleId__c);
      if (orderId == null) continue;
      Decimal current = result.containsKey(orderId) ? result.get(orderId) : 0;
      Decimal amount = tj.TransactionAmount == null ? 0 : tj.TransactionAmount;
      result.put(orderId, current + amount);
    }
    return result;
  }

  /**
   * 반품 환불 금액 — Sale Deposit Reversal TJ 기준
   *   반품 Order 의 환불 입금 (DT=03) 의 TransactionAmount 합
   *   PaymentMethod 제외 paradigm 동일 적용
   */
  private static Map<Id, Decimal> loadReturnEligibleAmountFromTJs(Id memberId) {
    Map<Id, Decimal> result = new Map<Id, Decimal>();
    for (TransactionJournal tj : [
      SELECT SaleId__c, PaymentMethod, TransactionAmount
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND JournalSubType.Name = 'Sale Deposit Reversal'
        AND SaleId__c != NULL
        AND TransactionAmount > 0
      LIMIT 5000
    ]) {
      if (PAYMENT_METHOD_NON_ACCRUAL.contains(tj.PaymentMethod)) continue;
      Id orderId = tryParseId(tj.SaleId__c);
      if (orderId == null) continue;
      Decimal current = result.containsKey(orderId) ? result.get(orderId) : 0;
      Decimal amount = tj.TransactionAmount == null ? 0 : tj.TransactionAmount;
      result.put(orderId, current + amount);
    }
    return result;
  }

  /**
   * 사용 / 사용 취소 TJ 의 실제 LL Points 합 (PointType별)
   *   POINT_USE: EventType='Debit' (포인트 차감)
   *   POINT_USE_CANCEL: EventType='Credit' (포인트 환원)
   *   TJ.Id 기준 그룹화
   */
  private static void loadActualUsageLLByTJ(Id memberId, ReplayContext rctx) {
    rctx.actualUsageByTjId = new Map<Id, Map<String, Decimal>>();
    rctx.actualUsageCancelByTjId = new Map<Id, Map<String, Decimal>>();

    for (LoyaltyLedger ll : [
      SELECT Points, EventType, TransactionJournalId,
             TransactionJournal.JournalSubType.Name,
             LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name IN (
          'Point Debit', 'Coupon Redeem', 'Point Redeem Cancel', 'Coupon Redeem Cancel'
        )
        AND Points > 0
      LIMIT 5000
    ]) {
      Id tjId = ll.TransactionJournalId;
      if (tjId == null) continue;
      String pt = ll.LoyaltyPgmCrcySubtype == null
        ? null
        : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      if (String.isBlank(pt)) continue;
      Decimal pts = ll.Points == null ? 0 : ll.Points;

      String jstName = ll.TransactionJournal.JournalSubType.Name;
      Map<Id, Map<String, Decimal>> target = isPointUseCancelJST(jstName)
        ? rctx.actualUsageCancelByTjId
        : rctx.actualUsageByTjId;

      if (!target.containsKey(tjId)) target.put(tjId, new Map<String, Decimal>());
      Map<String, Decimal> bucket = target.get(tjId);
      bucket.put(pt, (bucket.containsKey(pt) ? bucket.get(pt) : 0) + pts);
    }
  }

  /**
   * 만료 TJ 의 실제 LL Debit 합 (PointType별)
   */
  private static void loadActualExpireLLByTJ(Id memberId, ReplayContext rctx) {
    rctx.actualExpireByTjId = new Map<Id, Map<String, Decimal>>();
    for (LoyaltyLedger ll : [
      SELECT Points, EventType, TransactionJournalId,
             LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name IN ('Auto Expire', 'Api Forced Expire')
        AND Points > 0
        AND EventType = 'Debit'
      LIMIT 5000
    ]) {
      Id tjId = ll.TransactionJournalId;
      if (tjId == null) continue;
      String pt = ll.LoyaltyPgmCrcySubtype == null ? null : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      if (String.isBlank(pt)) continue;
      Decimal pts = ll.Points == null ? 0 : ll.Points;
      if (!rctx.actualExpireByTjId.containsKey(tjId)) rctx.actualExpireByTjId.put(tjId, new Map<String, Decimal>());
      Map<String, Decimal> bucket = rctx.actualExpireByTjId.get(tjId);
      bucket.put(pt, (bucket.containsKey(pt) ? bucket.get(pt) : 0) + pts);
    }
  }

  /**
   * 수동/API Forced TJ 의 실제 LL 합 (PointType별, EventType 별도 추적)
   */
  private static void loadActualManualLLByTJ(Id memberId, ReplayContext rctx) {
    rctx.actualManualByTjId = new Map<Id, Map<String, Decimal>>();
    rctx.manualEventTypeByTjId = new Map<Id, String>();
    for (LoyaltyLedger ll : [
      SELECT Points, EventType, TransactionJournalId,
             LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name IN (
          'Manual Points Credit', 'Manual Points Debit',
          'Api Forced Credit', 'Api Forced Debit',
          'Manual Coupon Issuance'
        )
        AND Points > 0
      LIMIT 5000
    ]) {
      Id tjId = ll.TransactionJournalId;
      if (tjId == null) continue;
      String pt = ll.LoyaltyPgmCrcySubtype == null ? null : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      if (String.isBlank(pt)) continue;
      Decimal pts = ll.Points == null ? 0 : ll.Points;
      if (!rctx.actualManualByTjId.containsKey(tjId)) rctx.actualManualByTjId.put(tjId, new Map<String, Decimal>());
      Map<String, Decimal> bucket = rctx.actualManualByTjId.get(tjId);
      bucket.put(pt, (bucket.containsKey(pt) ? bucket.get(pt) : 0) + pts);
      rctx.manualEventTypeByTjId.put(tjId, ll.EventType);
    }
  }

  /**
   * 운영 paradigm 호출용 openDate 자동 결정
   *   - 마이그레이션 회원: migrationCutoffDate
   *   - 신규 회원: 회원의 첫 거래 일 (또는 default 2020-01-01)
   *   - default fallback: 2020-01-01
   */
  private static Date resolveOperationalOpenDate(MemberContext ctx) {
    if (ctx.migrationCutoffDate != null) {
      return ctx.migrationCutoffDate.date();
    }
    Set<String> memberRefs = new Set<String>();
    if (ctx.member.Contact != null && String.isNotBlank(ctx.member.Contact.MemberNo__c)) {
      memberRefs.add(ctx.member.Contact.MemberNo__c);
    }
    if (ctx.member.ContactId != null) {
      memberRefs.add(String.valueOf(ctx.member.ContactId));
    }
    if (memberRefs.isEmpty()) return Date.newInstance(2020, 1, 1);
    for (Order o : [
      SELECT EffectiveDate FROM Order
      WHERE MemberNo__c IN :memberRefs
        AND IsDeleted__c = FALSE
        AND EffectiveDate != NULL
      ORDER BY EffectiveDate ASC
      LIMIT 1
    ]) {
      if (o.EffectiveDate != null) return o.EffectiveDate;
    }
    return Date.newInstance(2020, 1, 1);
  }

  /**
   * 운영 paradigm 호출용 openingPoint 결정
   *   1순위: LoyaltyProgramMember.OpeningPointBalance__c (마이그레이션 paradigm 표준)
   *   2순위: OPTC LL.Points (Option C residual lump) — sandbox/누락 회원 fallback
   *   3순위: 빈 map (운영 paradigm 의 default 사용)
   *
   *   paradigm 의도:
   *     마이그레이션 paradigm: 사용가능 덩어리 양을 OpeningPointBalance__c 에 저장
   *     운영 paradigm: openingPointByType['04'] 로 사용
   *     누락 시 OPTC LL.Points 가 동일한 paradigm (사용가능 덩어리)
   */
  private static Map<String, Decimal> resolveOperationalOpeningPoints(MemberContext ctx) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    // 1순위: OpeningPointBalance__c (운영 paradigm 표준)
    for (LoyaltyProgramMember m : [
      SELECT OpeningPointBalance__c FROM LoyaltyProgramMember WHERE Id = :ctx.member.Id LIMIT 1
    ]) {
      if (m.OpeningPointBalance__c != null && m.OpeningPointBalance__c > 0) {
        result.put('04', m.OpeningPointBalance__c);
        return result;
      }
    }
    // 2순위: OPTC LL.Points (Option C residual lump) — 마이그레이션 회원의 사용가능 덩어리
    Decimal optcSum = 0;
    for (LoyaltyLedger ll : [
      SELECT Points FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :ctx.member.Id
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND AdditionalNotes LIKE 'Option C residual lump%'
        AND TransactionJournal.JournalSubType.Name = 'Api Forced Credit'
    ]) {
      if (ll.Points != null) optcSum += ll.Points;
    }
    if (optcSum > 0) {
      result.put('04', optcSum);
    }
    return result;
  }

  private static Id tryParseId(String value) {
    if (String.isBlank(value)) return null;
    if (value.length() != 15 && value.length() != 18) return null;
    try {
      return (Id) value;
    } catch (Exception e) {
      return null;
    }
  }

  // ============================================================
  // Event Replay — 이벤트 처리 dispatcher
  // ============================================================
  private static void processEvent(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    if (e.eventType == EventType.SALE_ACCRUAL) {
      processSaleAccrual(e, state, rctx, result);
    } else if (e.eventType == EventType.RETURN_CANCEL) {
      processReturnCancel(e, state, rctx, result);
    } else if (e.eventType == EventType.DELETED_SALE_CANCEL) {
      processDeletedSaleCancel(e, state, rctx, result);
    } else if (e.eventType == EventType.POINT_USE) {
      processPointUse(e, state, rctx, result);
    } else if (e.eventType == EventType.POINT_USE_CANCEL) {
      processPointUseCancel(e, state, rctx, result);
    } else if (e.eventType == EventType.EXPIRE) {
      processExpire(e, state, rctx, result);
    } else if (e.eventType == EventType.MANUAL_ADJUST) {
      processManualAdjust(e, state, rctx, result);
    } else if (e.eventType == EventType.RESTORE) {
      processRestore(e, state, rctx, result);
    } else if (e.eventType == EventType.ORDER_UPDATE_MARK) {
      processOrderUpdateMark(e, state, rctx, result);
    }
  }

  /**
   * RESTORE 처리 — 반품 입금 삭제로 인한 사용 복원
   *   paradigm: POINT_USE 와 동일 (회원 잔액 차감)
   *   다만 별도 EventType 으로 표시하여 audit 강화
   *   expected = TJ.TransactionAmount (복원 요청량)
   *   actual = LL Debit Points 합
   */
  private static void processRestore(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Decimal requestedAmount = e.txAmount == null ? 0 : e.txAmount;
    Map<String, Decimal> actual = rctx.actualUsageByTjId.containsKey(e.relatedRecordId)
      ? rctx.actualUsageByTjId.get(e.relatedRecordId)
      : new Map<String, Decimal>();
    Decimal actualTotal = sumDecimalMap(actual);

    Map<String, Decimal> expected = new Map<String, Decimal>();
    Map<String, Decimal> actualForCompare = new Map<String, Decimal>();
    expected.put('TOTAL', requestedAmount);
    actualForCompare.put('TOTAL', actualTotal);

    compareAndRecord(e, expected, actualForCompare, state, /*isCredit*/ false, result);
    state.applyDebit(actual);
  }

  /**
   * ORDER_UPDATE_MARK 처리 — 주문 수정으로 이미 취소된 사용 마커
   *   paradigm: 원본 사용 Debit TJ 가 "이미 취소됨" 으로 마킹됨
   *   따라서 paradigm 외 audit (state 변화 없음, mismatch 기록 안 함)
   *   실제 LL 효과는 같은 TJ 의 LL 이 살아있다면 적용 (drift 검증용)
   */
  private static void processOrderUpdateMark(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Map<String, Decimal> actual = rctx.actualUsageByTjId.containsKey(e.relatedRecordId)
      ? rctx.actualUsageByTjId.get(e.relatedRecordId)
      : new Map<String, Decimal>();
    // paradigm 외 — mismatch 기록 X
    // 그러나 state 에는 LL 효과 적용 (LMC 정합 paradigm)
    state.applyDebit(actual);
  }

  /**
   * EXPIRE 처리 — Auto Expire / API Forced Expire
   *   paradigm:
   *     expected = TJ.TransactionAmount (만료 요청량)
   *     actual = LL Debit Points 합
   *     검증: 두 합 일치
   *   state: PointType별 차감
   */
  private static void processExpire(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Decimal requestedAmount = e.txAmount == null ? 0 : e.txAmount;
    Map<String, Decimal> actual = rctx.actualExpireByTjId.containsKey(e.relatedRecordId)
      ? rctx.actualExpireByTjId.get(e.relatedRecordId)
      : new Map<String, Decimal>();
    Decimal actualTotal = sumDecimalMap(actual);

    Map<String, Decimal> expected = new Map<String, Decimal>();
    Map<String, Decimal> actualForCompare = new Map<String, Decimal>();
    expected.put('TOTAL', requestedAmount);
    actualForCompare.put('TOTAL', actualTotal);

    compareAndRecord(e, expected, actualForCompare, state, /*isCredit*/ false, result);
    state.applyDebit(actual);
  }

  /**
   * MANUAL_ADJUST 처리 — paradigm 외 audit 이벤트
   *   Manual Points Credit/Debit, API Forced Credit/Debit 등
   *   paradigm 검증 X — 그대로 audit (paradigm 외 이벤트)
   *   state 적용은 정확히 (회원 잔액 영향)
   */
  private static void processManualAdjust(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Map<String, Decimal> actual = rctx.actualManualByTjId.containsKey(e.relatedRecordId)
      ? rctx.actualManualByTjId.get(e.relatedRecordId)
      : new Map<String, Decimal>();
    String eventType = rctx.manualEventTypeByTjId.get(e.relatedRecordId);

    // paradigm 외 이벤트 — mismatch 기록 안 함 (audit 만)
    if (eventType == 'Credit') {
      state.applyCredit(actual);
    } else if (eventType == 'Debit') {
      state.applyDebit(actual);
    }
  }

  /**
   * POINT_USE 처리 — Point Debit / Coupon Redeem
   *   paradigm:
   *     expected = TJ.TransactionAmount (사용 요청량, PointType 무관)
   *     actual = TJ 에 묶인 LL.Points 합 (Event=Debit, PointType별)
   *     검증: expected == Σ actual values
   *
   *   현재 paradigm 한계 (MVP):
   *     - PointType별 분배 paradigm (FIFO + 만료일 + 같은판매제외) 은 시뮬레이션 안 함
   *     - 단순히 총량 정합만 검증
   *   추후 Phase 3.3+ 에서 LASEL FIFO 시뮬레이션 추가
   */
  private static void processPointUse(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Decimal requestedAmount = e.txAmount == null ? 0 : e.txAmount;
    Map<String, Decimal> actual = rctx.actualUsageByTjId.containsKey(e.relatedRecordId)
      ? rctx.actualUsageByTjId.get(e.relatedRecordId)
      : new Map<String, Decimal>();
    Decimal actualTotal = sumDecimalMap(actual);

    // expected 는 단일 paradigm — 총량만. PointType 별 분배 paradigm 누락.
    // 표현 paradigm: expected map 의 key='TOTAL' 로 통합량 비교
    Map<String, Decimal> expected = new Map<String, Decimal>();
    Map<String, Decimal> actualForCompare = new Map<String, Decimal>();
    expected.put('TOTAL', requestedAmount);
    actualForCompare.put('TOTAL', actualTotal);

    compareAndRecord(e, expected, actualForCompare, state, /*isCredit*/ false, result);
    // VirtualState 는 실제 PointType별 paradigm 으로 차감
    state.applyDebit(actual);
  }

  /**
   * POINT_USE_CANCEL 처리 — Point Redeem Cancel / Coupon Redeem Cancel
   *   paradigm: expected = TJ.TransactionAmount (취소 요청량)
   *             actual = TJ 의 LL.Points 합 (Event=Credit, PointType별)
   */
  private static void processPointUseCancel(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Decimal requestedAmount = e.txAmount == null ? 0 : e.txAmount;
    Map<String, Decimal> actual = rctx.actualUsageCancelByTjId.containsKey(e.relatedRecordId)
      ? rctx.actualUsageCancelByTjId.get(e.relatedRecordId)
      : new Map<String, Decimal>();
    Decimal actualTotal = sumDecimalMap(actual);

    Map<String, Decimal> expected = new Map<String, Decimal>();
    Map<String, Decimal> actualForCompare = new Map<String, Decimal>();
    expected.put('TOTAL', requestedAmount);
    actualForCompare.put('TOTAL', actualTotal);

    compareAndRecord(e, expected, actualForCompare, state, /*isCredit*/ true, result);
    state.applyCredit(actual);
  }

  private static Decimal sumDecimalMap(Map<String, Decimal> m) {
    if (m == null) return 0;
    Decimal total = 0;
    for (Decimal v : m.values()) total += v;
    return total;
  }

  private static void processSaleAccrual(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Order sale = e.relatedOrder;
    // 적립 대상금액 — Sale Deposit TJ 기반 (운영 paradigm mirror)
    // OrderItem fallback 은 입금 TJ 가 없을 때만 사용
    Decimal eligible = rctx.eligibleAmountByOrderIdFromTJs.containsKey(sale.Id)
      ? rctx.eligibleAmountByOrderIdFromTJs.get(sale.Id)
      : calculateEligibleAmount(sale);
    rctx.eligibleByOrderId.put(sale.Id, eligible);

    Map<String, Decimal> expected = new Map<String, Decimal>();
    mergeMap(expected, simulatePurchaseAccrualForSale(sale, rctx.ctx, eligible));
    mergeMap(expected, simulatePromotionAccrualForSale(sale, eligible, rctx.promoLimitsByPromoId));
    rctx.accrualByOrderId.put(sale.Id, expected);

    Map<String, Decimal> actual = rctx.actualAccrualByOrderId.containsKey(sale.Id)
      ? rctx.actualAccrualByOrderId.get(sale.Id)
      : new Map<String, Decimal>();

    compareAndRecord(e, expected, actual, state, /*isCredit*/ true, result);
  }

  private static void processReturnCancel(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Order rtn = e.relatedOrder;
    // [paradigm 정확화 2026-06-01] 환불 비율 계산 시 TJ 기반 amount 사용
    //   returnEligible = 반품 Order 의 Sale Deposit Reversal TJ 합 (TJ 기반)
    //   origEligible = 원본 Order 의 Sale Deposit TJ 합 (TJ 기반)
    //   둘 다 운영 paradigm 의 TJ.TransactionAmount 기준
    Map<String, Decimal> expected = simulateReturnCancellationByTJ(rtn, rctx);
    Map<String, Decimal> actual = rctx.actualCancelByOrderId.containsKey(rtn.Id)
      ? rctx.actualCancelByOrderId.get(rtn.Id)
      : new Map<String, Decimal>();
    compareAndRecord(e, expected, actual, state, /*isCredit*/ false, result);
  }

  /**
   * 반품 적립 취소 시뮬레이션 — TJ 기반 paradigm
   *   원본 적립 (origAccrual) × (returnEligibleAmount / origEligibleAmount)
   *   모든 amount 는 Sale Deposit / Sale Deposit Reversal TJ 기반
   */
  private static Map<String, Decimal> simulateReturnCancellationByTJ(Order rtn, ReplayContext rctx) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    Id origId = rtn.OriginalOrderId__c;
    if (origId == null) return result;
    Map<String, Decimal> origAccrual = rctx.accrualByOrderId.get(origId);
    if (origAccrual == null || origAccrual.isEmpty()) return result;

    // origEligible: 원본 Order 의 Sale Deposit TJ 기준
    Decimal origEligible = rctx.eligibleAmountByOrderIdFromTJs.containsKey(origId)
      ? rctx.eligibleAmountByOrderIdFromTJs.get(origId)
      : (rctx.eligibleByOrderId.containsKey(origId) ? rctx.eligibleByOrderId.get(origId) : 0);
    if (origEligible <= 0) return result;

    // returnEligible: 반품 Order 의 Sale Deposit Reversal TJ 기준 (fallback: OrderItem 계산)
    Decimal returnEligible = rctx.returnEligibleAmountByOrderIdFromTJs.containsKey(rtn.Id)
      ? rctx.returnEligibleAmountByOrderIdFromTJs.get(rtn.Id)
      : calculateReturnEligibleAmount(rtn);
    if (returnEligible <= 0) return result;

    Decimal ratio = returnEligible / origEligible;
    for (String pt : origAccrual.keySet()) {
      Decimal cancelled = (origAccrual.get(pt) * ratio).setScale(0, RoundingMode.HALF_UP);
      if (cancelled <= 0) continue;
      result.put(pt, cancelled);
    }
    return result;
  }

  private static void processDeletedSaleCancel(TimelineEvent e, VirtualState state, ReplayContext rctx, IntegrityResult result) {
    Order sale = e.relatedOrder;
    Map<String, Decimal> expected = rctx.accrualByOrderId.get(sale.Id);
    if (expected == null) expected = new Map<String, Decimal>();
    Map<String, Decimal> actual = rctx.actualCancelByOrderId.containsKey(sale.Id)
      ? rctx.actualCancelByOrderId.get(sale.Id)
      : new Map<String, Decimal>();
    compareAndRecord(e, expected, actual, state, /*isCredit*/ false, result);
  }

  /**
   * paradigm 비교 + mismatch 기록 (state 적용은 호출자가 별도)
   */
  private static void compareAndRecord(
    TimelineEvent e,
    Map<String, Decimal> expected,
    Map<String, Decimal> actual,
    VirtualState state,
    Boolean isCredit,
    IntegrityResult result
  ) {
    if (!mapsEqual(expected, actual)) {
      EventMismatch m = new EventMismatch();
      m.occurredAt = e.occurredAt;
      m.eventType = e.eventType.name();
      m.relatedRecordId = e.relatedRecordId;
      m.saleNo = (e.relatedOrder == null ? null : e.relatedOrder.SaleNo__c);
      m.expected = expected == null ? new Map<String, Decimal>() : expected;
      m.actual = actual == null ? new Map<String, Decimal>() : actual;
      m.diff = new Map<String, Decimal>();
      Set<String> allPts = new Set<String>();
      allPts.addAll(m.expected.keySet());
      allPts.addAll(m.actual.keySet());
      for (String pt : allPts) {
        Decimal ev = m.expected.containsKey(pt) ? m.expected.get(pt) : 0;
        Decimal av = m.actual.containsKey(pt) ? m.actual.get(pt) : 0;
        if (ev != av) {
          m.diff.put(pt, av - ev);
        }
      }
      result.eventMismatches.add(m);
    }

    // VirtualState 적용 — 호출자가 명시적으로 처리하는 paradigm 으로 변경.
    // SALE_ACCRUAL, RETURN_CANCEL, DELETED_SALE_CANCEL 은 actual 그대로 적용 (PointType별).
    // POINT_USE / POINT_USE_CANCEL 은 별도 paradigm (TOTAL key 가 아닌 actual PointType 적용 필요).
    // 따라서 호환을 위해 actual 이 TOTAL key 만 가지면 state 적용 skip.
    if (actual != null && actual.size() == 1 && actual.containsKey('TOTAL')) {
      // POINT_USE / POINT_USE_CANCEL — 호출자가 state 적용
      return;
    }
    if (isCredit) {
      state.applyCredit(actual);
    } else {
      state.applyDebit(actual);
    }
  }

  private static Boolean mapsEqual(Map<String, Decimal> a, Map<String, Decimal> b) {
    if (a == null) a = new Map<String, Decimal>();
    if (b == null) b = new Map<String, Decimal>();
    Set<String> allKeys = new Set<String>();
    allKeys.addAll(a.keySet());
    allKeys.addAll(b.keySet());
    for (String k : allKeys) {
      Decimal av = a.containsKey(k) ? a.get(k) : 0;
      Decimal bv = b.containsKey(k) ? b.get(k) : 0;
      if (av != bv) return false;
    }
    return true;
  }

  // ============================================================
  // 최종 LMC 잔액 조회
  // ============================================================
  private static Decimal queryFinalLMCBalance(Id memberId) {
    Decimal total = 0;
    for (LoyaltyMemberCurrency lmc : [
      SELECT PointsBalance FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :memberId
    ]) {
      if (lmc.PointsBalance != null) {
        total += lmc.PointsBalance;
      }
    }
    return total;
  }

  // ============================================================
  // 누적 요약 (호환성 유지)
  // ============================================================
  private static void populateAggregateSummary(IntegrityResult result, ReplayContext rctx) {
    Decimal expAccr = 0;
    Decimal expCanc = 0;
    Decimal actAccr = 0;
    Decimal actCanc = 0;

    for (Map<String, Decimal> m : rctx.accrualByOrderId.values()) {
      for (String pt : m.keySet()) {
        Decimal v = m.get(pt);
        result.expectedByPointType.put(pt, (result.expectedByPointType.containsKey(pt) ? result.expectedByPointType.get(pt) : 0) + v);
        expAccr += v;
      }
    }
    for (Map<String, Decimal> m : rctx.actualAccrualByOrderId.values()) {
      for (String pt : m.keySet()) {
        Decimal v = m.get(pt);
        result.actualByPointType.put(pt, (result.actualByPointType.containsKey(pt) ? result.actualByPointType.get(pt) : 0) + v);
        actAccr += v;
      }
    }
    for (Map<String, Decimal> m : rctx.actualCancelByOrderId.values()) {
      for (String pt : m.keySet()) {
        Decimal v = m.get(pt);
        result.actualCancellationByPointType.put(pt, (result.actualCancellationByPointType.containsKey(pt) ? result.actualCancellationByPointType.get(pt) : 0) + v);
        actCanc += v;
      }
    }
    // expected cancellation 은 eventMismatches 의 RETURN_CANCEL + DELETED_SALE_CANCEL 에서 expected 합산
    // (현재 paradigm 에서는 별도 캐시가 없으므로 actualCancel 기준으로만 representation)
    result.totalExpectedAccrual = expAccr;
    result.totalExpectedCancellation = expCanc;
    result.totalActualAccrual = actAccr;
    result.totalActualCancellation = actCanc;
  }

  private static Integer countByType(List<TimelineEvent> events, EventType t) {
    Integer n = 0;
    for (TimelineEvent e : events) {
      if (e.eventType == t) n++;
    }
    return n;
  }

  // ============================================================
  // === 이하 기존 helper 재사용 (paradigm 변경 없음) ===
  // ============================================================

  private static Decimal calculateEligibleAmount(Order sale) {
    Decimal eligible = 0;
    if (sale.OrderItems == null) return eligible;
    for (OrderItem oi : sale.OrderItems) {
      if (oi.IsExclude__c == true) continue;
      Decimal price = oi.NetSalesUnitPrice__c == null ? 0 : oi.NetSalesUnitPrice__c;
      Decimal qty = oi.Quantity == null ? 1 : oi.Quantity;
      eligible += price * qty;
    }
    return eligible;
  }

  private static Map<Id, List<PromotionPointLimit__c>> loadPromotionPointLimits(Set<Id> promoIds) {
    Map<Id, List<PromotionPointLimit__c>> result = new Map<Id, List<PromotionPointLimit__c>>();
    if (promoIds == null || promoIds.isEmpty()) return result;
    for (PromotionPointLimit__c ppl : [
      SELECT PromotionId__c, Type__c, Value__c,
             LoyaltyPgmCurrencySubtypeId__c,
             LoyaltyPgmCurrencySubtypeId__r.Name,
             LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c
      FROM PromotionPointLimit__c
      WHERE PromotionId__c IN :promoIds
        AND Type__c IN ('none', 'rate')
    ]) {
      if (!result.containsKey(ppl.PromotionId__c)) {
        result.put(ppl.PromotionId__c, new List<PromotionPointLimit__c>());
      }
      result.get(ppl.PromotionId__c).add(ppl);
    }
    return result;
  }

  private static Map<String, Decimal> simulatePromotionAccrualForSale(Order sale, Decimal eligibleAmount, Map<Id, List<PromotionPointLimit__c>> promoLimitsByPromoId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (sale.PromotionId__c == null) return result;
    List<PromotionPointLimit__c> limits = promoLimitsByPromoId.get(sale.PromotionId__c);
    if (limits == null || limits.isEmpty()) return result;
    if (eligibleAmount <= 0) return result;
    for (PromotionPointLimit__c ppl : limits) {
      if (ppl.LoyaltyPgmCurrencySubtypeId__r == null) continue;
      String pointType = ppl.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;
      if (String.isBlank(pointType)) continue;
      Decimal points = 0;
      if ('none'.equals(ppl.Type__c)) {
        points = ppl.Value__c == null ? 0 : ppl.Value__c;
      } else if ('rate'.equals(ppl.Type__c)) {
        Decimal rate = ppl.Value__c == null ? 0 : ppl.Value__c;
        points = (eligibleAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);
      }
      if (points <= 0) continue;
      if (!result.containsKey(pointType)) result.put(pointType, 0);
      result.put(pointType, result.get(pointType) + points);
    }
    return result;
  }

  private static List<Order> loadReturns(MemberContext ctx) {
    Set<String> memberRefs = new Set<String>();
    if (ctx.member.Contact != null && String.isNotBlank(ctx.member.Contact.MemberNo__c)) {
      memberRefs.add(ctx.member.Contact.MemberNo__c);
    }
    if (ctx.member.ContactId != null) {
      memberRefs.add(String.valueOf(ctx.member.ContactId));
    }
    if (memberRefs.isEmpty()) return new List<Order>();
    return [
      SELECT Id, SaleNo__c, EffectiveDate, OriginalOrderId__c, IsDeleted__c,
             Account.StoreType__c,
             PromotionId__c,
             (SELECT Id, Quantity, NetSalesUnitPrice__c, IsExclude__c,
                     OriginalOrderItemId, OriginalOrderItem.IsExclude__c, OriginalOrderItem.NetSalesUnitPrice__c
              FROM OrderItems)
      FROM Order
      WHERE MemberNo__c IN :memberRefs
        AND IsReductionOrder__c = TRUE
        AND IsDeleted__c = FALSE
        AND SaleNo__c != NULL
      ORDER BY EffectiveDate ASC, CreatedDate ASC
      LIMIT 1000
    ];
  }

  private static Map<String, Decimal> simulateReturnCancellation(Order rtn, Map<Id, Map<String, Decimal>> accrualByOrderId, Map<Id, Decimal> eligibleByOrderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    Id origId = rtn.OriginalOrderId__c;
    if (origId == null) return result;
    Map<String, Decimal> origAccrual = accrualByOrderId.get(origId);
    if (origAccrual == null || origAccrual.isEmpty()) return result;
    Decimal origEligible = eligibleByOrderId.containsKey(origId) ? eligibleByOrderId.get(origId) : 0;
    if (origEligible <= 0) return result;

    Decimal returnEligible = calculateReturnEligibleAmount(rtn);
    if (returnEligible <= 0) return result;

    Decimal ratio = returnEligible / origEligible;
    for (String pt : origAccrual.keySet()) {
      Decimal cancelled = (origAccrual.get(pt) * ratio).setScale(0, RoundingMode.HALF_UP);
      if (cancelled <= 0) continue;
      result.put(pt, cancelled);
    }
    return result;
  }

  private static Decimal calculateReturnEligibleAmount(Order rtn) {
    Decimal eligible = 0;
    if (rtn.OrderItems == null) return eligible;
    for (OrderItem oi : rtn.OrderItems) {
      Boolean isExcluded = (oi.OriginalOrderItemId != null && oi.OriginalOrderItem != null)
        ? (oi.OriginalOrderItem.IsExclude__c == true)
        : (oi.IsExclude__c == true);
      if (isExcluded) continue;
      Decimal price = (oi.OriginalOrderItemId != null && oi.OriginalOrderItem != null && oi.OriginalOrderItem.NetSalesUnitPrice__c != null)
        ? oi.OriginalOrderItem.NetSalesUnitPrice__c
        : (oi.NetSalesUnitPrice__c == null ? 0 : oi.NetSalesUnitPrice__c);
      Decimal qty = oi.Quantity == null ? 1 : oi.Quantity;
      eligible += price * qty;
    }
    return eligible < 0 ? -eligible : eligible;
  }

  private static void mergeMap(Map<String, Decimal> target, Map<String, Decimal> source) {
    if (target == null || source == null) return;
    for (String key : source.keySet()) {
      if (!target.containsKey(key)) target.put(key, 0);
      target.put(key, target.get(key) + source.get(key));
    }
  }

  // ============================================================
  // MemberContext 로드 (등급 timeline + 등급별 혜택)
  // ============================================================
  private static MemberContext loadMemberContext(String memberRef) {
    MemberContext ctx = new MemberContext();
    ctx.gradeTimeline = new List<GradeChange>();
    ctx.benefitsByGrade = new Map<String, List<LoyaltyTierBenefit>>();

    List<LoyaltyProgramMember> members;
    if (isSalesforceContactId(memberRef)) {
      Id contactId = (Id) memberRef;
      members = [
        SELECT Id, ContactId, MembershipNumber, Contact.Name, Contact.MemberNo__c, Contact.Grade__c
        FROM LoyaltyProgramMember
        WHERE ContactId = :contactId AND MemberStatus = 'Active'
        LIMIT 1
      ];
    } else {
      members = [
        SELECT Id, ContactId, MembershipNumber, Contact.Name, Contact.MemberNo__c, Contact.Grade__c
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberRef AND MemberStatus = 'Active'
        LIMIT 1
      ];
    }
    if (members.isEmpty()) return ctx;
    ctx.member = members[0];
    ctx.currentGrade = ctx.member.Contact == null ? null : ctx.member.Contact.Grade__c;

    if (ctx.member.ContactId != null) {
      for (ContactHistory ch : [
        SELECT Field, OldValue, NewValue, CreatedDate
        FROM ContactHistory
        WHERE ContactId = :ctx.member.ContactId AND Field = 'Grade__c'
        ORDER BY CreatedDate ASC
      ]) {
        GradeChange gc = new GradeChange();
        gc.changedAt = ch.CreatedDate;
        gc.oldGrade = ch.OldValue == null ? null : String.valueOf(ch.OldValue);
        gc.newGrade = ch.NewValue == null ? null : String.valueOf(ch.NewValue);
        ctx.gradeTimeline.add(gc);
      }
    }

    Set<String> allGradeValues = new Set<String>();
    if (String.isNotBlank(ctx.currentGrade)) allGradeValues.add(ctx.currentGrade);
    for (GradeChange gc : ctx.gradeTimeline) {
      if (String.isNotBlank(gc.oldGrade)) allGradeValues.add(gc.oldGrade);
      if (String.isNotBlank(gc.newGrade)) allGradeValues.add(gc.newGrade);
    }

    Map<String, String> gradeValueToLabel = new Map<String, String>();
    Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
    for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
      gradeValueToLabel.put(entry.getValue(), entry.getLabel());
    }

    Set<String> involvedLabels = new Set<String>();
    Map<String, String> valueToLabel = new Map<String, String>();
    for (String gv : allGradeValues) {
      if (gradeValueToLabel.containsKey(gv)) {
        String label = gradeValueToLabel.get(gv);
        involvedLabels.add(label);
        valueToLabel.put(gv, label);
      }
    }

    Map<String, Id> labelToTierId = new Map<String, Id>();
    if (!involvedLabels.isEmpty()) {
      for (LoyaltyTier t : [SELECT Id, Name FROM LoyaltyTier WHERE Name IN :involvedLabels]) {
        labelToTierId.put(t.Name, t.Id);
      }
    }

    Set<Id> tierIds = new Set<Id>(labelToTierId.values());
    Map<Id, List<LoyaltyTierBenefit>> benefitsByTierId = new Map<Id, List<LoyaltyTierBenefit>>();
    if (!tierIds.isEmpty()) {
      for (LoyaltyTierBenefit ltb : [
        SELECT LoyaltyTierId,
               Benefit.PurchasePointRate__c,
               Benefit.LoyaltyPgmCurrencySubtypeId__r.Name,
               Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c,
               Benefit.LoyaltyPgmCurrencySubtypeId__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN :tierIds
      ]) {
        if (!benefitsByTierId.containsKey(ltb.LoyaltyTierId)) {
          benefitsByTierId.put(ltb.LoyaltyTierId, new List<LoyaltyTierBenefit>());
        }
        benefitsByTierId.get(ltb.LoyaltyTierId).add(ltb);
      }
    }

    for (String gv : allGradeValues) {
      String label = valueToLabel.get(gv);
      if (String.isBlank(label)) continue;
      Id tierId = labelToTierId.get(label);
      if (tierId == null) continue;
      List<LoyaltyTierBenefit> benefits = benefitsByTierId.get(tierId);
      if (benefits == null) continue;
      ctx.benefitsByGrade.put(gv, benefits);
    }

    // [OPTC paradigm 2026-06-01] 마이그레이션 cutoff date 계산
    //   OPTC LL: AdditionalNotes LIKE 'Option C residual lump%' AND JST='Api Forced Credit'
    //   cutoff = MAX(ActivityDate)
    ctx.migrationCutoffDate = null;
    ctx.isMigratedMember = false;
    for (LoyaltyLedger optcLL : [
      SELECT ActivityDate
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :ctx.member.Id
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND AdditionalNotes LIKE 'Option C residual lump%'
        AND TransactionJournal.JournalSubType.Name = 'Api Forced Credit'
      ORDER BY ActivityDate DESC
      LIMIT 5
    ]) {
      ctx.isMigratedMember = true;
      if (optcLL.ActivityDate != null) {
        if (ctx.migrationCutoffDate == null || optcLL.ActivityDate > ctx.migrationCutoffDate) {
          ctx.migrationCutoffDate = optcLL.ActivityDate;
        }
      }
    }

    return ctx;
  }

  private static String resolveGradeAtDate(Date saleDate, List<GradeChange> timeline, String currentGrade) {
    if (timeline == null || timeline.isEmpty()) return currentGrade;
    Datetime saleDt = Datetime.newInstanceGmt(saleDate, Time.newInstance(0, 0, 0, 0));
    for (GradeChange gc : timeline) {
      if (saleDt < gc.changedAt) return gc.oldGrade;
    }
    return currentGrade;
  }

  private static List<Order> loadSales(Id memberId) {
    String memberNoActual = null;
    String contactIdStr = null;
    for (LoyaltyProgramMember m : [
      SELECT ContactId, Contact.MemberNo__c FROM LoyaltyProgramMember WHERE Id = :memberId LIMIT 1
    ]) {
      if (m.Contact != null) memberNoActual = m.Contact.MemberNo__c;
      if (m.ContactId != null) contactIdStr = String.valueOf(m.ContactId);
    }
    Set<String> memberRefs = new Set<String>();
    if (String.isNotBlank(memberNoActual)) memberRefs.add(memberNoActual);
    if (String.isNotBlank(contactIdStr)) memberRefs.add(contactIdStr);
    if (memberRefs.isEmpty()) return new List<Order>();
    return [
      SELECT Id, SaleNo__c, EffectiveDate, Type, ActualPaymentAmount__c, IsDeleted__c,
             AccountId, Account.StoreType__c,
             PromotionId__c, PromotionId__r.PointTypeCode__c, PromotionId__r.Name,
             (SELECT Id, Quantity, NetSalesUnitPrice__c, IsExclude__c FROM OrderItems)
      FROM Order
      WHERE MemberNo__c IN :memberRefs
        AND IsReductionOrder__c = FALSE
        AND SaleNo__c != NULL
      ORDER BY EffectiveDate ASC, CreatedDate ASC
      LIMIT 1000
    ];
  }

  private static Map<String, Decimal> simulatePurchaseAccrualForSale(Order sale, MemberContext ctx, Decimal eligibleAmount) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (sale.Account != null && STORE_TYPE_EXCLUDED.contains(sale.Account.StoreType__c)) return result;
    if (eligibleAmount <= 0) return result;

    Set<String> excludedPointTypes = new Set<String>();
    if (sale.PromotionId__c != null && sale.PromotionId__r != null && String.isNotBlank(sale.PromotionId__r.PointTypeCode__c)) {
      for (String code : sale.PromotionId__r.PointTypeCode__c.split(';')) {
        if (String.isNotBlank(code)) excludedPointTypes.add(code.trim());
      }
    }

    String saleGrade = resolveGradeAtDate(sale.EffectiveDate, ctx.gradeTimeline, ctx.currentGrade);
    List<LoyaltyTierBenefit> benefits = ctx.benefitsByGrade.get(saleGrade);
    if (benefits == null || benefits.isEmpty()) return result;

    for (LoyaltyTierBenefit ltb : benefits) {
      if (ltb.Benefit == null || ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r == null) continue;
      String benefitPointType = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;
      if (String.isBlank(benefitPointType)) continue;
      if (excludedPointTypes.contains(benefitPointType.trim())) continue;
      Decimal rate = ltb.Benefit.PurchasePointRate__c == null ? 0 : ltb.Benefit.PurchasePointRate__c;
      if (rate <= 0) continue;
      Decimal points = (eligibleAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);
      if (points <= 0) continue;
      if (!result.containsKey(benefitPointType)) result.put(benefitPointType, 0);
      result.put(benefitPointType, result.get(benefitPointType) + points);
    }
    return result;
  }

  private static Boolean isSalesforceContactId(String value) {
    if (String.isBlank(value)) return false;
    if (value.length() != 15 && value.length() != 18) return false;
    if (!value.startsWith('003')) return false;
    try {
      Id parsed = (Id) value;
      return parsed != null;
    } catch (Exception e) {
      return false;
    }
  }

  // ============================================================
  // 내부 클래스 / Enum
  // ============================================================
  public enum EventType {
    SALE_ACCRUAL,
    RETURN_CANCEL,
    DELETED_SALE_CANCEL,
    POINT_USE,            // C: Point Debit / Coupon Redeem (정상 사용)
    POINT_USE_CANCEL,     // D: Point Redeem Cancel / Coupon Redeem Cancel
    EXPIRE,               // E: Auto Expire / API Forced Expire
    RESTORE,              // F: 반품 입금 삭제로 인한 사용 복원 (RESTORE_NOTE 마킹)
    ORDER_UPDATE_MARK,    // J: 주문 수정 마커 (ORDER_UPDATE_NOTE 마킹된 사용)
    MANUAL_ADJUST         // I: Manual Points Credit/Debit, API Forced Credit/Debit (paradigm 외 audit)
  }

  private class TimelineEvent implements Comparable {
    Datetime occurredAt;
    EventType eventType;
    Id relatedRecordId;
    Order relatedOrder;
    TransactionJournal relatedTj;   // POINT_USE / POINT_USE_CANCEL 용
    Decimal txAmount;               // 사용/취소 요청량 (TJ.TransactionAmount)

    public Integer compareTo(Object other) {
      TimelineEvent o = (TimelineEvent) other;
      if (this.occurredAt < o.occurredAt) return -1;
      if (this.occurredAt > o.occurredAt) return 1;
      // 동시간: SALE_ACCRUAL(0) 먼저, 그 다음 RETURN_CANCEL(1), DELETED_SALE_CANCEL(2)
      Integer ao = this.eventType == null ? 99 : this.eventType.ordinal();
      Integer bo = o.eventType == null ? 99 : o.eventType.ordinal();
      return ao - bo;
    }
  }

  private class ReplayContext {
    MemberContext ctx;
    Map<Id, List<PromotionPointLimit__c>> promoLimitsByPromoId;
    Map<Id, Map<String, Decimal>> accrualByOrderId = new Map<Id, Map<String, Decimal>>();
    Map<Id, Decimal> eligibleByOrderId = new Map<Id, Decimal>();
    Map<Id, Map<String, Decimal>> actualAccrualByOrderId;
    Map<Id, Map<String, Decimal>> actualCancelByOrderId;
    // 운영 paradigm mirror — Sale Deposit TJ 기준 적립 대상금액
    Map<Id, Decimal> eligibleAmountByOrderIdFromTJs;
    // 반품 환불 금액 — Sale Deposit Reversal TJ 기준
    Map<Id, Decimal> returnEligibleAmountByOrderIdFromTJs;
    // [Phase 3.3] 사용 / 취소 TJ 의 실제 LL 합계 (PointType 무관 합)
    //   key = TJ.Id, value = 해당 TJ 에 묶인 LL.Points 합
    Map<Id, Map<String, Decimal>> actualUsageByTjId;        // POINT_USE 의 LL Debit 합 (PointType별)
    Map<Id, Map<String, Decimal>> actualUsageCancelByTjId;  // POINT_USE_CANCEL 의 LL Credit 합 (PointType별)
    // [Phase 3.4] 만료 / 수동 TJ 의 실제 LL 합계
    Map<Id, Map<String, Decimal>> actualExpireByTjId;       // EXPIRE 의 LL Debit 합
    Map<Id, Map<String, Decimal>> actualManualByTjId;       // MANUAL_ADJUST 의 LL 합 (PointType별, EventType 무관)
    Map<Id, String> manualEventTypeByTjId;                  // TJ.Id → 'Credit' or 'Debit' (state 적용 방향)
  }

  private class VirtualState {
    Map<String, Decimal> balanceByPointType = new Map<String, Decimal>();

    public Decimal totalBalance() {
      Decimal total = 0;
      for (Decimal v : balanceByPointType.values()) total += v;
      return total;
    }

    public void applyCredit(Map<String, Decimal> delta) {
      if (delta == null) return;
      for (String pt : delta.keySet()) {
        Decimal current = balanceByPointType.containsKey(pt) ? balanceByPointType.get(pt) : 0;
        balanceByPointType.put(pt, current + delta.get(pt));
      }
    }

    public void applyDebit(Map<String, Decimal> delta) {
      if (delta == null) return;
      for (String pt : delta.keySet()) {
        Decimal current = balanceByPointType.containsKey(pt) ? balanceByPointType.get(pt) : 0;
        balanceByPointType.put(pt, current - delta.get(pt));
      }
    }
  }

  private class MemberContext {
    LoyaltyProgramMember member;
    String currentGrade;
    List<GradeChange> gradeTimeline;
    Map<String, List<LoyaltyTierBenefit>> benefitsByGrade;
    // [OPTC paradigm 2026-06-01] 마이그레이션 cutoff date
    //   OPTC LL ('Option C residual lump%') 의 MAX(ActivityDate)
    //   이 date 이전 거래는 마이그레이션 paradigm — 운영 코드 적립 paradigm 적용 대상 아님
    //   cutoff 이후 거래만 paradigm 검증
    Datetime migrationCutoffDate;
    Boolean isMigratedMember;
  }

  private class GradeChange {
    Datetime changedAt;
    String oldGrade;
    String newGrade;
  }

  // ============================================================
  // 결과 DTO
  // ============================================================
  public class IntegrityResult {
    @AuraEnabled public Id memberId;
    @AuraEnabled public String memberNo;
    @AuraEnabled public String memberName;
    @AuraEnabled public Boolean isValid;
    @AuraEnabled public String summary;
    @AuraEnabled public Integer eventCount;
    @AuraEnabled public Integer salesCount;
    @AuraEnabled public Integer returnsCount;
    @AuraEnabled public Integer mismatchCount;
    @AuraEnabled public Decimal finalExpectedBalance;
    @AuraEnabled public Decimal finalActualBalance;
    @AuraEnabled public Decimal finalBalanceDifference;
    @AuraEnabled public Decimal totalExpectedAccrual;
    @AuraEnabled public Decimal totalActualAccrual;
    @AuraEnabled public Decimal totalExpectedCancellation;
    @AuraEnabled public Decimal totalActualCancellation;
    @AuraEnabled public Decimal totalDifference;
    @AuraEnabled public Map<String, Decimal> expectedByPointType;
    @AuraEnabled public Map<String, Decimal> actualByPointType;
    @AuraEnabled public Map<String, Decimal> expectedCancellationByPointType;
    @AuraEnabled public Map<String, Decimal> actualCancellationByPointType;
    @AuraEnabled public List<EventMismatch> eventMismatches;
    @AuraEnabled public List<String> mismatchDetails;
    @AuraEnabled public Boolean isMigratedMember;
    @AuraEnabled public Datetime migrationCutoffDate;
    // [운영 paradigm 결합 2026-06-15] GdPointRefreshPreviewService 호출 결과
    @AuraEnabled public Boolean operationalSuccess;
    @AuraEnabled public String operationalError;
    @AuraEnabled public Decimal operationalExpectedBalance;
    @AuraEnabled public Integer operationalEventCount;
    @AuraEnabled public Integer operationalBucketCount;
    @AuraEnabled public Map<String, Decimal> operationalRemainingByPointType;
    @AuraEnabled public Date operationalOpenDate;
    @AuraEnabled public Decimal operationalDifference;  // 운영 paradigm 가상 - 실제 LMC
  }

  public class EventMismatch {
    @AuraEnabled public Datetime occurredAt;
    @AuraEnabled public String eventType;
    @AuraEnabled public Id relatedRecordId;
    @AuraEnabled public String saleNo;
    @AuraEnabled public Map<String, Decimal> expected;
    @AuraEnabled public Map<String, Decimal> actual;
    @AuraEnabled public Map<String, Decimal> diff;

    public String toSummary() {
      List<String> parts = new List<String>();
      if (diff != null) {
        for (String pt : diff.keySet()) {
          parts.add('PT=' + pt + ' Δ=' + diff.get(pt));
        }
      }
      return '[' + eventType + '] '
        + (saleNo == null ? String.valueOf(relatedRecordId) : saleNo)
        + ' @ ' + (occurredAt == null ? '-' : String.valueOf(occurredAt.date()))
        + ' — ' + String.join(parts, ', ');
    }
  }
}