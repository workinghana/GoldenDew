/**
 * LoyaltyPointIntegrityEngine
 *
 * 진정한 포인트 정합성 검증 엔진 — Phase 3.1 (Purchase Accrual 시뮬레이션).
 *
 * paradigm:
 *   - 회원의 판매 이력을 시간순으로 재실행하여 기대 적립 포인트를 산출
 *   - 운영 코드 (creditPointsOnPurchaseV2) 의 계산 paradigm 을 read-only 로 mirror
 *   - 실제 LoyaltyLedger 의 Purchase Accrual 합계와 비교
 *
 * 검증 차원 (Phase 3.1 현재):
 *   1. 회원의 판매 적립 = (적립 대상 금액) × (등급 적립률) × (프로모션 제외 정책 적용)
 *   2. 실제 Purchase Accrual LL 합계와 비교
 *   3. PointType 별 차이 보고
 *
 * 한계 (Phase 3.2-3.5 에서 점진 보강):
 *   - 프로모션 적립 (Promotion Point Accrual) 미시뮬레이션
 *   - 반품 적립 취소 (Cancel Purchase Accrual) 미시뮬레이션
 *   - 포인트 사용 / 사용 취소 미시뮬레이션
 *   - 입금 삭제 / 반품 삭제 미시뮬레이션
 *   - OPTC 분기 미시뮬레이션
 *   - 만료 처리 미시뮬레이션
 *
 * 운영 코드 참조:
 *   - GdPointServiceImpl.creditPointsOnPurchaseV2 (L4868-)
 *   - GdSaleDepositServiceImpl (L530-547 매장 적립 제외 분기)
 */
public without sharing class LoyaltyPointIntegrityEngine {
  private static final Set<String> STORE_TYPE_EXCLUDED = new Set<String>{ '20', '25', '33' };
  private static final Set<String> PAYMENT_METHOD_NON_ACCRUAL = new Set<String>{ '20', '81', '90', '93' };
  private static final String JST_PURCHASE_ACCRUAL = 'Purchase Accrual';

  // ============================================================
  // Public API
  // ============================================================

  /**
   * 회원 번호 기준 정합성 검증 (Phase 3.1 — Purchase Accrual 만).
   */
  public static IntegrityResult validateByMemberNo(String memberNo) {
    IntegrityResult result = new IntegrityResult();
    result.memberNo = memberNo;
    if (String.isBlank(memberNo)) {
      result.isValid = false;
      result.summary = '회원번호가 비어있습니다.';
      return result;
    }

    // 1. 회원 컨텍스트 로드 (회원 + 등급 + 보상)
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

    // 2. 모든 판매 Order 시간순 로드 (OrderItem + Account 포함)
    List<Order> sales = loadSales(ctx.member.Id);
    result.salesCount = sales.size();
    if (sales.isEmpty()) {
      result.isValid = true;
      result.summary = '판매 이력 없음 (검증 대상 0건)';
      return result;
    }

    // 3a. PromotionPointLimit__c 일괄 로드 (sales 의 PromotionId 들)
    Set<Id> promoIds = new Set<Id>();
    for (Order s : sales) {
      if (s.PromotionId__c != null) promoIds.add(s.PromotionId__c);
    }
    Map<Id, List<PromotionPointLimit__c>> promoLimitsByPromoId = loadPromotionPointLimits(promoIds);

    // 3b. 판매당 시뮬레이션 — 등급 적립 + 프로모션 적립
    //     각 판매의 기대 적립을 Map<Id orderId, Map<String pointType, Decimal points>> 로 보존
    //     (반품 cancellation 비율 계산 시 원판매 적립 lookup 용)
    Map<Id, Map<String, Decimal>> accrualByOrderId = new Map<Id, Map<String, Decimal>>();
    Map<Id, Decimal> eligibleByOrderId = new Map<Id, Decimal>();
    Map<String, Decimal> expectedAccrualByType = new Map<String, Decimal>();
    for (Order sale : sales) {
      Decimal eligible = calculateEligibleAmount(sale);
      eligibleByOrderId.put(sale.Id, eligible);

      // 등급 기반 Purchase Accrual
      Map<String, Decimal> purchaseAccrual = simulatePurchaseAccrualForSale(sale, ctx, eligible);
      // 프로모션 추가 적립
      Map<String, Decimal> promotionAccrual = simulatePromotionAccrualForSale(sale, eligible, promoLimitsByPromoId);

      Map<String, Decimal> combined = new Map<String, Decimal>();
      mergeMap(combined, purchaseAccrual);
      mergeMap(combined, promotionAccrual);
      accrualByOrderId.put(sale.Id, combined);
      mergeMap(expectedAccrualByType, combined);
    }
    result.expectedByPointType = expectedAccrualByType;

    // 3c. 반품 적립 취소 시뮬레이션
    List<Order> returns = loadReturns(ctx);
    result.returnsCount = returns.size();
    Map<String, Decimal> expectedCancelByType = new Map<String, Decimal>();
    for (Order rtn : returns) {
      Map<String, Decimal> cancelByType = simulateReturnCancellation(rtn, accrualByOrderId, eligibleByOrderId);
      mergeMap(expectedCancelByType, cancelByType);
    }

    // 3d. 삭제된 Order 의 자기 적립 취소 시뮬레이션
    //     적립 후 Order 가 IsDeleted__c=TRUE 로 변경되면 시스템이 동일 SaleId 로 Cancel Purchase Accrual TJ 발생
    for (Order sale : sales) {
      if (sale.IsDeleted__c != true) continue;
      Map<String, Decimal> selfAccrual = accrualByOrderId.get(sale.Id);
      if (selfAccrual == null) continue;
      mergeMap(expectedCancelByType, selfAccrual);
    }
    result.expectedCancellationByPointType = expectedCancelByType;

    // 4. 실제 Purchase/Promotion Accrual LL 합계 (Credit)
    Map<String, Decimal> actualAccrualByType = queryActualAccrual(ctx.member.Id);
    result.actualByPointType = actualAccrualByType;

    // 4b. 실제 Cancel Purchase Accrual / Promotion Point Accrual Reversal 합계 (Debit)
    Map<String, Decimal> actualCancelByType = queryActualCancellation(ctx.member.Id);
    result.actualCancellationByPointType = actualCancelByType;

    // 5. 비교 — Net 기준
    Set<String> allTypes = new Set<String>();
    allTypes.addAll(expectedAccrualByType.keySet());
    allTypes.addAll(actualAccrualByType.keySet());
    allTypes.addAll(expectedCancelByType.keySet());
    allTypes.addAll(actualCancelByType.keySet());

    Decimal totalExpAccr = 0;
    Decimal totalActAccr = 0;
    Decimal totalExpCanc = 0;
    Decimal totalActCanc = 0;
    for (String pt : allTypes) {
      Decimal expAccr = expectedAccrualByType.containsKey(pt) ? expectedAccrualByType.get(pt) : 0;
      Decimal actAccr = actualAccrualByType.containsKey(pt) ? actualAccrualByType.get(pt) : 0;
      Decimal expCanc = expectedCancelByType.containsKey(pt) ? expectedCancelByType.get(pt) : 0;
      Decimal actCanc = actualCancelByType.containsKey(pt) ? actualCancelByType.get(pt) : 0;
      totalExpAccr += expAccr;
      totalActAccr += actAccr;
      totalExpCanc += expCanc;
      totalActCanc += actCanc;

      Decimal expNet = expAccr - expCanc;
      Decimal actNet = actAccr - actCanc;
      if (expNet != actNet) {
        result.mismatchDetails.add(
          'PointType=' + pt
          + ' ExpAccr=' + expAccr + ', ActAccr=' + actAccr
          + ' / ExpCanc=' + expCanc + ', ActCanc=' + actCanc
          + ' / NetDiff=' + (actNet - expNet) + 'P'
        );
      }
    }
    result.totalExpectedAccrual = totalExpAccr;
    result.totalActualAccrual = totalActAccr;
    result.totalExpectedCancellation = totalExpCanc;
    result.totalActualCancellation = totalActCanc;
    result.totalDifference = (totalActAccr - totalActCanc) - (totalExpAccr - totalExpCanc);

    result.isValid = (result.mismatchDetails.isEmpty());
    result.summary = result.isValid
      ? '판매/반품 정합 (판매 ' + sales.size() + '건, 반품 ' + returns.size() + '건, NetExp ' + (totalExpAccr - totalExpCanc) + 'P)'
      : '결함 — NetExp=' + (totalExpAccr - totalExpCanc) + 'P, NetAct=' + (totalActAccr - totalActCanc) + 'P, Diff=' + result.totalDifference + 'P';
    return result;
  }

  // ============================================================
  // Phase 3.2 헬퍼 — eligible amount, promotion limits, return cancellation
  // ============================================================

  private static Decimal calculateEligibleAmount(Order sale) {
    Decimal eligible = 0;
    if (sale.OrderItems == null) {
      return eligible;
    }
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
    if (promoIds == null || promoIds.isEmpty()) {
      return result;
    }
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
      SELECT Id, SaleNo__c, EffectiveDate, OriginalOrderId__c,
             Account.StoreType__c,
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
      // 반품 OI 의 IsExclude 는 OriginalOrderItem 기준 우선 (정책 § 6.2)
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
    // 반품 OrderItem.Quantity 는 음수(-1)로 저장 → 절댓값으로 변환
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
  // 실제 Cancel Purchase Accrual / Promotion Point Accrual Reversal 합계
  // ============================================================
  private static Map<String, Decimal> queryActualCancellation(Id memberId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    for (AggregateResult row : [
      SELECT LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND EventType = 'Debit'
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name IN ('Cancel Purchase Accrual', 'Promotion Point Accrual Reversal')
      GROUP BY LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      String pt = (String) row.get('pointType');
      Decimal total = (Decimal) row.get('total');
      if (String.isBlank(pt) || total == null) continue;
      result.put(pt, total);
    }
    return result;
  }

  // ============================================================
  // Stage 1 — MemberContext 로드
  // ============================================================

  private static MemberContext loadMemberContext(String memberRef) {
    // memberRef 는 두 가지 paradigm 지원:
    //   1. Contact.MemberNo__c 의 실제 값
    //   2. Contact.Id 의 문자열 (003 prefix)
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
    if (members.isEmpty()) {
      return ctx;
    }
    ctx.member = members[0];
    ctx.currentGrade = ctx.member.Contact == null ? null : ctx.member.Contact.Grade__c;

    // 등급 이력 로드 (ContactHistory 의 Grade__c 변경)
    if (ctx.member.ContactId != null) {
      for (ContactHistory ch : [
        SELECT Field, OldValue, NewValue, CreatedDate
        FROM ContactHistory
        WHERE ContactId = :ctx.member.ContactId
          AND Field = 'Grade__c'
        ORDER BY CreatedDate ASC
      ]) {
        GradeChange gc = new GradeChange();
        gc.changedAt = ch.CreatedDate;
        gc.oldGrade = ch.OldValue == null ? null : String.valueOf(ch.OldValue);
        gc.newGrade = ch.NewValue == null ? null : String.valueOf(ch.NewValue);
        ctx.gradeTimeline.add(gc);
      }
    }

    // 모든 가능한 등급 값 수집 (이력 + 현재)
    Set<String> allGradeValues = new Set<String>();
    if (String.isNotBlank(ctx.currentGrade)) {
      allGradeValues.add(ctx.currentGrade);
    }
    for (GradeChange gc : ctx.gradeTimeline) {
      if (String.isNotBlank(gc.oldGrade)) allGradeValues.add(gc.oldGrade);
      if (String.isNotBlank(gc.newGrade)) allGradeValues.add(gc.newGrade);
    }

    // Grade Picklist 값 → Label 매핑 (LoyaltyTier.Name 매칭용)
    Map<String, String> gradeValueToLabel = new Map<String, String>();
    Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
    for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
      gradeValueToLabel.put(entry.getValue(), entry.getLabel());
    }

    // 등급 Label → LoyaltyTier.Id 매핑
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
    Map<Id, String> tierIdToLabel = new Map<Id, String>();
    if (!involvedLabels.isEmpty()) {
      for (LoyaltyTier t : [SELECT Id, Name FROM LoyaltyTier WHERE Name IN :involvedLabels]) {
        labelToTierId.put(t.Name, t.Id);
        tierIdToLabel.put(t.Id, t.Name);
      }
    }

    // 각 등급별 LoyaltyTierBenefit 일괄 로드
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

    // grade value → benefits 캐시 구축
    for (String gv : allGradeValues) {
      String label = valueToLabel.get(gv);
      if (String.isBlank(label)) continue;
      Id tierId = labelToTierId.get(label);
      if (tierId == null) continue;
      List<LoyaltyTierBenefit> benefits = benefitsByTierId.get(tierId);
      if (benefits == null) continue;
      ctx.benefitsByGrade.put(gv, benefits);
    }

    return ctx;
  }

  // ============================================================
  // 등급 이력 조회 — sale.EffectiveDate 시점의 등급 결정
  //
  // paradigm:
  //   - timeline 은 CreatedDate ASC 정렬됨
  //   - 첫 변경 이전: timeline[0].oldGrade
  //   - 변경 i 와 i+1 사이: timeline[i].newGrade
  //   - 마지막 변경 이후: currentGrade
  // ============================================================
  private static String resolveGradeAtDate(Date saleDate, List<GradeChange> timeline, String currentGrade) {
    if (timeline == null || timeline.isEmpty()) {
      return currentGrade;
    }
    Datetime saleDt = Datetime.newInstanceGmt(saleDate, Time.newInstance(0, 0, 0, 0));
    for (GradeChange gc : timeline) {
      if (saleDt < gc.changedAt) {
        // saleDate 가 이 변경 이전 → grade 는 oldGrade
        return gc.oldGrade;
      }
    }
    // 모든 변경 이후 → 현재 등급
    return currentGrade;
  }

  // ============================================================
  // Stage 2 — 판매 Order 시간순 로드 + Promotion 정보
  // ============================================================

  private static List<Order> loadSales(Id memberId) {
    // Order.MemberNo__c 는 두 가지 paradigm 으로 저장 가능:
    //   1. Contact.MemberNo__c 의 실제 값 (예: '253007200063')
    //   2. Contact.Id 의 문자열 (예: '003JO00000EXPe3YAH')
    // 두 paradigm 모두 catch 하기 위해 dual lookup.
    String memberNoActual = null;
    String contactIdStr = null;
    for (LoyaltyProgramMember m : [
      SELECT ContactId, Contact.MemberNo__c FROM LoyaltyProgramMember WHERE Id = :memberId LIMIT 1
    ]) {
      if (m.Contact != null) {
        memberNoActual = m.Contact.MemberNo__c;
      }
      if (m.ContactId != null) {
        contactIdStr = String.valueOf(m.ContactId);
      }
    }
    Set<String> memberRefs = new Set<String>();
    if (String.isNotBlank(memberNoActual)) {
      memberRefs.add(memberNoActual);
    }
    if (String.isNotBlank(contactIdStr)) {
      memberRefs.add(contactIdStr);
    }
    if (memberRefs.isEmpty()) {
      return new List<Order>();
    }
    // 삭제된 Order(IsDeleted__c=TRUE) 도 포함: 적립 후 Order가 삭제된 cycle 은
    // 적립 TJ + 자기 자신 100% 취소 TJ 두 LL 을 남긴다 (net=0). 정확한 시뮬레이션을 위해 포함.
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

  // ============================================================
  // Stage 3 — 판매당 Purchase Accrual 시뮬레이션
  //   운영 paradigm:
  //     1. 매장 적립 제외 분기 (StoreType '20', '25', '33' → 0 적립)
  //     2. 적립 대상 금액 = 적립 가능 상품 합계 (IsExclude__c=false)
  //     3. 프로모션 제외 PointType Set 추출
  //     4. 각 LoyaltyTierBenefit 별:
  //        - PointType 가 프로모션 제외 Set 에 포함 → 0
  //        - 아니면 (금액 × Rate/100) HALF_UP → 적립
  // ============================================================

  private static Map<String, Decimal> simulatePurchaseAccrualForSale(Order sale, MemberContext ctx, Decimal eligibleAmount) {
    Map<String, Decimal> result = new Map<String, Decimal>();

    // 매장 적립 제외 분기
    if (sale.Account != null && STORE_TYPE_EXCLUDED.contains(sale.Account.StoreType__c)) {
      return result;  // 0 적립
    }

    if (eligibleAmount <= 0) {
      return result;
    }

    // 프로모션 제외 PointType Set
    Set<String> excludedPointTypes = new Set<String>();
    if (sale.PromotionId__c != null && sale.PromotionId__r != null && String.isNotBlank(sale.PromotionId__r.PointTypeCode__c)) {
      for (String code : sale.PromotionId__r.PointTypeCode__c.split(';')) {
        if (String.isNotBlank(code)) {
          excludedPointTypes.add(code.trim());
        }
      }
    }

    // 시점 등급 결정 — ContactHistory 기반 historical lookup
    String saleGrade = resolveGradeAtDate(sale.EffectiveDate, ctx.gradeTimeline, ctx.currentGrade);
    List<LoyaltyTierBenefit> benefits = ctx.benefitsByGrade.get(saleGrade);
    if (benefits == null || benefits.isEmpty()) {
      // 해당 등급의 benefit 미존재 → 적립 0 (또는 매핑 결함)
      return result;
    }

    // 각 등급 보상 시뮬레이션
    for (LoyaltyTierBenefit ltb : benefits) {
      if (ltb.Benefit == null || ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r == null) {
        continue;
      }
      String benefitPointType = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;
      if (String.isBlank(benefitPointType)) {
        continue;
      }
      // 프로모션 제외 적용
      if (excludedPointTypes.contains(benefitPointType.trim())) {
        continue;
      }
      Decimal rate = ltb.Benefit.PurchasePointRate__c == null ? 0 : ltb.Benefit.PurchasePointRate__c;
      if (rate <= 0) {
        continue;
      }
      Decimal points = (eligibleAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);
      if (points <= 0) {
        continue;
      }
      if (!result.containsKey(benefitPointType)) {
        result.put(benefitPointType, 0);
      }
      result.put(benefitPointType, result.get(benefitPointType) + points);
    }
    return result;
  }

  // ============================================================
  // Stage 4 — 실제 Purchase Accrual LL 합계
  //   대상: JST = 'Purchase Accrual', IsDel=FALSE, TJ.IsDel=FALSE, Points > 0
  // ============================================================

  private static Map<String, Decimal> queryActualAccrual(Id memberId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    for (AggregateResult row : [
      SELECT LoyaltyPgmCrcySubtype.PointTypeCode__c pointType,
             SUM(Points) total
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name IN ('Purchase Accrual', 'Promotion Point Accrual')
        AND Points > 0
      GROUP BY LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      String pt = (String) row.get('pointType');
      Decimal total = (Decimal) row.get('total');
      if (String.isBlank(pt) || total == null) {
        continue;
      }
      result.put(pt, total);
    }
    return result;
  }

  // ============================================================
  // 내부 컨텍스트 + DTO
  // ============================================================

  private class MemberContext {
    LoyaltyProgramMember member;
    String currentGrade;
    List<GradeChange> gradeTimeline;
    Map<String, List<LoyaltyTierBenefit>> benefitsByGrade;
  }

  private class GradeChange {
    Datetime changedAt;
    String oldGrade;
    String newGrade;
  }

  private static Boolean isSalesforceContactId(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    if (value.length() != 15 && value.length() != 18) {
      return false;
    }
    if (!value.startsWith('003')) {
      return false;
    }
    try {
      Id parsed = (Id) value;
      return parsed != null;
    } catch (Exception e) {
      return false;
    }
  }

  public class IntegrityResult {
    @AuraEnabled public Id memberId;
    @AuraEnabled public String memberNo;
    @AuraEnabled public String memberName;
    @AuraEnabled public Boolean isValid;
    @AuraEnabled public String summary;
    @AuraEnabled public Integer salesCount;
    @AuraEnabled public Integer returnsCount;
    @AuraEnabled public Decimal totalExpectedAccrual;
    @AuraEnabled public Decimal totalActualAccrual;
    @AuraEnabled public Decimal totalExpectedCancellation;
    @AuraEnabled public Decimal totalActualCancellation;
    @AuraEnabled public Decimal totalDifference;
    @AuraEnabled public Map<String, Decimal> expectedByPointType = new Map<String, Decimal>();
    @AuraEnabled public Map<String, Decimal> actualByPointType = new Map<String, Decimal>();
    @AuraEnabled public Map<String, Decimal> expectedCancellationByPointType = new Map<String, Decimal>();
    @AuraEnabled public Map<String, Decimal> actualCancellationByPointType = new Map<String, Decimal>();
    @AuraEnabled public List<String> mismatchDetails = new List<String>();
  }
}