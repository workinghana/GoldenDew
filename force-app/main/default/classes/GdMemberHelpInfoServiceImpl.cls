public with sharing class GdMemberHelpInfoServiceImpl implements GdMemberHelpInfoService {
  //결제 방법 결과 데이터 맵핑
  private static final Map<String, String> PAYMENT_METHOD_MAP = new Map<String, String>{
    '01' => '현금',
    '03' => '카드',
    '05' => '제예금',
    '06' => '가주문',
    '07' => '외상대금',
    '10' => '매입',
    '20' => 'Upgrade',
    '70' => 'CRD',
    '80' => '온라인몰포인트',
    '81' => '포인트',
    '82' => '스타일러스포인트',
    '90' => '본사상품권',
    '91' => '캐럿상품권',
    '92' => '백화점상품권',
    '93' => '본사교환권'
  };
  //쿠폰 관리 코드 맵핑
  private static final Map<String, String> COUPON_MAN_NO_MAP = new Map<String, String>{
    '01' => '교환권',
    '02' => '사은품쿠폰',
    '03' => '본사상품권',
    '04' => '(S)D/C쿠폰'
  };
  private static final Set<String> POINT_PAYMENT_METHODS = new Set<String>{ '81' };
  private static final Set<String> COUPON_PAYMENT_METHODS = new Set<String>{ '90', '91', '92', '93' };
  private static final Set<String> EXCLUDED_PAYMENT_JOURNAL_SUBTYPES = new Set<String>{
    'Coupon Redeem Cancel',
    'Point Redeem Cancel',
    'Order Deposit Reversal',
    'Sale Deposit Reversal',
    'Cancel Purchase Accrual'
  };
  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual';
  private static final String JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL = 'Accrual Reversal';
  private static final String RESTORE_PURCHASE_ACCRUAL_NOTE = 'Restore purchase accrual due to return deletion';
  private static final String RESTORE_PROMOTION_ACCRUAL_NOTE = 'Restore promotion point accrual due to return deletion';
  // [Eco Restore Fix 2026-05-03] 통반품 취소 시 재적립된 에코포인트 마커
  //   배경: restoreEcoPointsFromReturn 가 만든 재적립 LL 이 AccrualHistoryList 에 추가 행으로 노출됨.
  //         GdPointServiceImpl 의 같은 마커 처리 (라인 346, 350, 1193, 1197) 와 일관성 회복.
  private static final String ECO_POINT_RESTORE_NOTE = 'FULL_RETURN_ECO_POINT_RESTORE';
  // [Eco Restore Sum Fix 2026-05-03] 에코포인트 PointTypeCode (LoyaltyPgmCrcySubtype.PointTypeCode__c)
  //   원본 에코 LL 식별 + 재적립 LL 매핑 시 사용. GdReturnDepositServiceImpl 의 같은 상수와 동일.
  private static final String ECO_POINT_TYPE_CODE = '05';
  // [2026-04-24] v3 Point Redeem Cancel / 통반품 에코포인트 마커 (조회 쿼리 필터에 사용)
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_DEBIT = 'Point Debit';
  private static final String ADDITIONAL_NOTE_FULL_RETURN_ECO_POINT_CANCEL = 'FULL_RETURN_ECO_POINT_CANCEL';
  // [scn5 R1-10/R1-11/R2-8 Fix 2026-04-27] 반품 입금 삭제 재차감 Debit 마커 — v3 paradigm 으로 원본 trace 가 보존되어
  // 재차감 trace 가 화면에서 중복 노출되는 문제 방지용. 동일 마커가 GdReturnDepositServiceImpl/GdSaleDepositServiceImpl 에도 사용됨.
  private static final String RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';

  private static String getPaymentMethodLabel(String paymentCode) {
    return PAYMENT_METHOD_MAP.containsKey(paymentCode) ? PAYMENT_METHOD_MAP.get(paymentCode) : paymentCode;
  }

  private static Map<String, Object> buildHistoryRow(
    Datetime changeDate,
    String changeTarget,
    String field,
    Object oldValue,
    Object newValue,
    String changedBy
  ) {
    Map<String, Object> updates = new Map<String, Object>();
    updates.put('changeDate', changeDate);
    updates.put('changeTarget', changeTarget);
    updates.put('field', field);
    updates.put('oldValue', String.valueOf(oldValue));
    updates.put('newValue', String.valueOf(newValue));
    updates.put('changedBy', changedBy);
    return updates;
  }

  private static String buildExpiryAllocationKey(Id memberId, Id subtypeId, Date expiryDate) {
    return String.valueOf(memberId) + '::' + String.valueOf(subtypeId) + '::' + String.valueOf(expiryDate);
  }

  private static Boolean shouldExcludeFromAccrualHistory(LoyaltyLedger ledger) {
    if (ledger == null || ledger.EventType != 'Credit' || ledger.TransactionJournal == null) {
      return false;
    }

    // [2026-04-25 시나리오 4 R1-9 Fix] 전체 판매 DELETE 된 Order 의 Accrual Credit 은 AccrualHistoryList 에서 제외.
    //   - 전체 판매 DELETE 시 Order.IsDeleted__c = TRUE 로 마킹되지만 TJ 자체는 IsDeleted=FALSE 유지.
    //   - Accrual Reversal Debit 이 별도 생성되어 PT_SAVE==PT_DESTROY 로 "소멸" 표시되지만
    //     MD 기대는 판매 B 관련 로우의 완전 제거이므로 여기서 원천 필터링.
    //   - S1/S2/S3 의 Order 는 IsDeleted=FALSE 유지이므로 영향 없음.
    if (ledger.TransactionJournal.Order != null
        && ledger.TransactionJournal.Order.IsDeleted__c == true) {
      return true;
    }

    String journalTypeName = ledger.TransactionJournal.JournalType != null ? ledger.TransactionJournal.JournalType.Name : null;
    String journalAdditionalNotes = ledger.TransactionJournal.AdditionalNotes__c;
    String relatedJournalTypeName = ledger.TransactionJournal.RelatedJournal != null &&
      ledger.TransactionJournal.RelatedJournal.JournalType != null
      ? ledger.TransactionJournal.RelatedJournal.JournalType.Name
      : null;

    // [Eco Restore Fix 2026-05-03] 통반품 취소 시 재적립된 에코포인트 (FULL_RETURN_ECO_POINT_RESTORE) 도 제외
    //   배경: 통반품 → 취소 → 재통반품 시나리오에서 restoreEcoPointsFromReturn 이 만든
    //         재적립 LL 이 AccrualHistoryList 에 추가 행으로 노출되는 문제.
    //         처리 로직과 로우 데이터는 정상이며, 조회 측에서만 마커 기반 제외 필요.
    //   해결: ECO_POINT_RESTORE_NOTE 마커도 제외 대상에 추가 (다른 메서드 4곳과 일관).
    if (journalAdditionalNotes == RESTORE_PURCHASE_ACCRUAL_NOTE
        || journalAdditionalNotes == RESTORE_PROMOTION_ACCRUAL_NOTE
        || journalAdditionalNotes == ECO_POINT_RESTORE_NOTE) {
      return true;
    }

    return journalTypeName == JOURNAL_TYPE_NAME_ACCRUAL &&
      ledger.TransactionJournal.RelatedJournalId != null &&
      relatedJournalTypeName == JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL;
  }

  private static Map<Id, Integer> buildPointPaymentSummaryMap(Set<Id> orderIds) {
    Map<Id, Integer> result = new Map<Id, Integer>();

    if (orderIds.isEmpty()) {
      return result;
    }

    // [PT_USE_SALE Fix 2026-05-02] 주문→판매 끌어오기 케이스 매칭 보강
    //   배경: 주문에서 포인트 사용 후 판매로 끌어오면 사용 TJ.OrderId 는 주문 Id 그대로 유지되고
    //         SaleId__c 에만 판매 Id 가 채워짐. 반면 판매 자동 적립 LL.OrderId 는 판매 Id 라
    //         OrderId 단일 매칭 시 미스매치로 PT_USE_SALE = 0 이 됨.
    //   해결: WHERE 절에 SaleId__c 매칭 OR 추가 + 결과를 OrderId / SaleId__c 양쪽 키에 분배.
    //         OrderId == SaleId__c (판매 직접 사용) 인 경우 한 번만 카운트하여 중복 방지.
    for (TransactionJournal tj : [
      SELECT OrderId, SaleId__c, TransactionAmount
      FROM TransactionJournal
      WHERE
        (OrderId IN :orderIds OR SaleId__c IN :orderIds)
        AND TransactionAmount != NULL
        AND PaymentMethod IN :POINT_PAYMENT_METHODS
        AND IsDeleted__c = FALSE
        AND (JournalSubType.Name = NULL
        OR JournalSubType.Name NOT IN :EXCLUDED_PAYMENT_JOURNAL_SUBTYPES)
        // [scn5 R1-11 Fix 2026-04-27] 반품 입금 삭제 재차감 Debit TJ 제외
        //   v3 paradigm 으로 원본 사용 TJ 가 보존된 상태에서 재차감 TJ 가 함께 합산되면 PT_USE_SALE 가 두 배가 됨.
        AND (AdditionalNotes__c = NULL
        OR AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        // [scn6 R2-9 Fix 2026-04-27] 통반품/전체판매 DELETE 시 에코포인트 취소 Debit TJ 제외
        //   FULL_RETURN_ECO_POINT_CANCEL 마커가 붙은 Api Forced Debit TJ 는 사용이 아닌 소멸이므로 PT_USE_SALE 에 합산되면 안 됨.
        //   (현재 PaymentMethod=null 이라 자연 제외되지만 방어적 일관성을 위해 명시)
        AND (AdditionalNotes__c = NULL
        OR AdditionalNotes__c != :ADDITIONAL_NOTE_FULL_RETURN_ECO_POINT_CANCEL)
    ]) {
      Integer amt = tj.TransactionAmount == null ? 0 : tj.TransactionAmount.intValue();

      // OrderId 매칭 — 주문 단계 적립 LL 에 표시
      if (tj.OrderId != null && orderIds.contains(tj.OrderId)) {
        result.put(tj.OrderId, (result.containsKey(tj.OrderId) ? result.get(tj.OrderId) : 0) + amt);
      }

      // SaleId__c 매칭 — 판매 단계 적립 LL 에 표시
      //   OrderId == SaleId__c (판매 직접 사용) 시 위에서 이미 카운트되므로 스킵
      if (tj.SaleId__c != null && tj.SaleId__c != tj.OrderId && orderIds.contains(tj.SaleId__c)) {
        result.put(tj.SaleId__c, (result.containsKey(tj.SaleId__c) ? result.get(tj.SaleId__c) : 0) + amt);
      }
    }

    return result;
  }

  private static Map<Id, Integer> buildCouponPaymentSummaryMap(Set<Id> orderIds) {
    Map<Id, Integer> result = new Map<Id, Integer>();

    if (orderIds.isEmpty()) {
      return result;
    }

    // [PT_USE_SALE_COUPON Fix 2026-05-02] 주문→판매 끌어오기 케이스 매칭 보강
    //   배경: 주문에서 쿠폰 사용 후 판매로 끌어오면 사용 TJ.OrderId 는 주문 Id 그대로 유지되고
    //         SaleId__c 에만 판매 Id 가 채워짐. 반면 판매 자동 적립 LL.OrderId 는 판매 Id 라
    //         OrderId 단일 매칭 시 미스매치로 PT_USE_SALE_COUPON = 0 이 됨.
    //   해결: WHERE 절에 SaleId__c 매칭 OR 추가 + 결과를 OrderId / SaleId__c 양쪽 키에 분배.
    //         OrderId == SaleId__c (판매 직접 사용) 인 경우 한 번만 카운트하여 중복 방지.
    //         (buildPointPaymentSummaryMap 과 동일 패턴)
    for (TransactionJournal tj : [
      SELECT OrderId, SaleId__c, TransactionAmount, JournalType.Name, JournalSubType.Name
      FROM TransactionJournal
      WHERE (OrderId IN :orderIds OR SaleId__c IN :orderIds)
        AND TransactionAmount != NULL
        AND PaymentMethod IN :COUPON_PAYMENT_METHODS
        AND IsDeleted__c = FALSE
    ]) {
      String journalTypeName = tj.JournalType != null ? tj.JournalType.Name : null;
      String journalSubTypeName = tj.JournalSubType != null ? tj.JournalSubType.Name : null;
      Integer normalizedAmount = tj.TransactionAmount == null ? 0 : tj.TransactionAmount.abs().intValue();
      Integer signedAmount = 0;

      // [scn7 R1-12 Fix 2026-04-27] 쿠폰 사용 흔적 보존 (감사성)
      //   기존: 'Coupon Redeem Cancel' TJ 를 -금액으로 차감 (사용 + 취소 = 0 net)
      //   변경: Cancel TJ 는 EXCLUDED_PAYMENT_JOURNAL_SUBTYPES 에 이미 포함되어 자연 제외 → 원본 사용 금액만 합산
      //   효과: 통반품으로 쿠폰 사용 취소된 후에도 PT_USE_SALE_COUPON 에 원 사용 금액(예: 10,000) 이 보존됨
      if (journalSubTypeName == null || !EXCLUDED_PAYMENT_JOURNAL_SUBTYPES.contains(journalSubTypeName)) {
        signedAmount = normalizedAmount;
      }

      // OrderId 매칭 — 주문 단계 적립 LL 에 표시
      if (tj.OrderId != null && orderIds.contains(tj.OrderId)) {
        if (!result.containsKey(tj.OrderId)) {
          result.put(tj.OrderId, 0);
        }
        result.put(tj.OrderId, result.get(tj.OrderId) + signedAmount);
      }

      // SaleId__c 매칭 — 판매 단계 적립 LL 에 표시
      //   OrderId == SaleId__c (판매 직접 사용) 시 위에서 이미 카운트되므로 스킵
      if (tj.SaleId__c != null && tj.SaleId__c != tj.OrderId && orderIds.contains(tj.SaleId__c)) {
        if (!result.containsKey(tj.SaleId__c)) {
          result.put(tj.SaleId__c, 0);
        }
        result.put(tj.SaleId__c, result.get(tj.SaleId__c) + signedAmount);
      }
    }

    for (Id orderId : new List<Id>(result.keySet())) {
      result.put(orderId, Math.max(0, result.get(orderId)));
    }

    return result;
  }

  /**
   * [2026-04-24 R1-1~R2-3 Fix] 회원의 주문(OrderId)별 "포인트 사용 취소된 총액" 맵.
   *
   * v3 `cancelPointRedemption_v3` 경로에서 생성되는 Point Redeem Cancel TJ 의
   *   - OrderId = "사용이 취소된 원 주문/판매 Id"
   *   - TransactionAmount = "이번 취소로 환불된 포인트 금액"
   * 으로 기록되는 설계(GdReturnDepositServiceImpl:162~167 등 참조)를 활용해,
   * 조회 시 주문 단위로 "전액 취소 / 부분 취소" 를 판정하는 기준값을 구성한다.
   *
   * 동일 주문에 대해 여러 번 부분 취소된 경우 TransactionAmount 들이 합산된다.
   *
   * 설계 결정: 호출 맥락(AccrualHistoryList 의 accrualOrderIds / UserDestoryHistoryList 의
   * Debit LLT OrderId 등)에 따라 대상 OrderId 집합이 달라 한 번의 SOQL 로 모든 맥락을
   * 커버하기 위해 회원 단위(orderIds 필터 제거) 로 집계한다. Point Redeem Cancel TJ 는
   * 회원당 수 건~수십 건 수준이므로 row limit 영향 없음 (safety LIMIT 50000).
   *
   * governor limit: SOQL 1회 (AccrualHistoryList + UserDestoryHistoryList 공용).
   */
  private static Map<Id, Integer> buildOrderRedeemCancelMap(Id memberId) {
    Map<Id, Integer> result = new Map<Id, Integer>();
    if (memberId == null) {
      return result;
    }
    for (AggregateResult ar : [
      SELECT OrderId orderId, SUM(TransactionAmount) totalAmount
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND OrderId != NULL
        AND JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
        AND Status = 'Processed'
        AND IsDeleted__c = FALSE
      GROUP BY OrderId
      LIMIT 50000
    ]) {
      Id orderId = (Id) ar.get('orderId');
      if (orderId == null) {
        continue;
      }
      Decimal total = (Decimal) ar.get('totalAmount');
      result.put(orderId, total == null ? 0 : total.abs().intValue());
    }
    return result;
  }

  /**
   * [2026-04-25 R1-9/R2-7/R2-8 추가 Fix] Point Redeem Cancel Credit LL → "원 Credit LL" 매핑.
   *
   * 배경:
   *   - v3 cancelPointRedemption 은 원 Debit 을 IsDeleted=TRUE 로 마킹하면서 별도의
   *     Point Redeem Cancel Credit LL 을 생성한다.
   *   - 이 재적립 Credit 을 나중에 새 Debit 이 사용하면 (예: PATCH 재등록), 그 사용분의
   *     PT_USE 는 MD 기대상 "원 Credit (같은 주문의 원 적립)" 에 귀속되어 단일 로우로 보여야 한다.
   *
   * 매핑 규칙:
   *   - Point Redeem Cancel Credit LL X 의 OrderId = Y
   *   - Y 와 같은 OrderId 의 "삭제된 Point Debit TJ" 의 LLT 가 참조한 Credit LL 중 가장 Points 많이
   *     점유한 단일 Credit 을 "원 Credit" 으로 선택 (간단화)
   *
   * 반환: Map<Point Redeem Cancel Credit LL Id, 원 Credit LL Id>
   *
   * governor limit: SOQL 1회 (Traceability + 삭제 Debit 필터), 대상 주문 수 이내 → 안전.
   *                 대상 Point Redeem Cancel Credit 자체가 없으면 조기 반환 (SOQL 실행 없음).
   */
  private static Map<Id, Id> buildRedeemCancelCreditOriginMap(Id memberId, List<LoyaltyLedger> ledgers) {
    Map<Id, Id> result = new Map<Id, Id>();
    if (memberId == null || ledgers == null || ledgers.isEmpty()) {
      return result;
    }

    // [1] Point Redeem Cancel Credit LL 수집 (OrderId + SubType 함께 보존)
    //   [Bug Fix 2026-04-30] Cancel Credit 의 SubType 정보를 보존하여 SubType 별 정확 매핑.
    //   기존 로직은 OrderId 만 보고 "가장 큰 점유 원 Credit" 으로 단일 매핑 → 다중 SubType 환원 시
    //   모든 cancel 이 가장 큰 금액 1 개로 잘못 매핑되어 PT_USE 비정합 (회원 123002600463 케이스).
    Map<Id, Id> cancelLLToOrder = new Map<Id, Id>();      // Cancel Credit LL Id → OrderId
    Map<Id, Id> cancelLLToSubtype = new Map<Id, Id>();    // Cancel Credit LL Id → SubType (null 가능)
    Set<Id> targetOrderIds = new Set<Id>();
    for (LoyaltyLedger ll : ledgers) {
      if (ll.EventType == 'Credit'
          && ll.TransactionJournal != null
          && ll.TransactionJournal.OrderId != null
          && ll.TransactionJournal.JournalSubType != null
          && ll.TransactionJournal.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL) {
        Id oid = ll.TransactionJournal.OrderId;
        cancelLLToOrder.put(ll.Id, oid);
        cancelLLToSubtype.put(ll.Id, ll.LoyaltyPgmCrcySubtypeId);
        targetOrderIds.add(oid);
      }
    }
    if (targetOrderIds.isEmpty()) {
      return result;  // Point Redeem Cancel Credit 이 없으면 조기 반환 (S1/S2 등에선 여기서 종료)
    }

    // [2] "이미 사용 취소 처리된" Point Debit TJ 의 LLT → (OrderId, SubType, Credit LL Id, Points) 집계
    //   [Bug Fix 2026-04-30] CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId 추가하여 SubType 차원 분리.
    //   [v3 paradigm Trace 보존 Fix 2026-05-03]
    //     배경: v2 paradigm 에서는 사용 취소 시 원본 Debit TJ 가 IsDeleted=TRUE 로 마킹됨.
    //           v3 paradigm 에서는 원본 TJ 가 IsDeleted=FALSE 로 살아있고 마커
    //           (RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE) 만 부착됨.
    //     문제: 기존 SOQL 이 IsDeleted=TRUE 만 매칭하여 v3 케이스 누락 → Cancel Credit → 원 Credit 매핑 실패
    //           → 회원이 사용 취소 후 다시 사용한 경우 원 Credit LL 의 PT_USE 가 0 으로 표시되는 버그 (회원 269999800162).
    //     해결: OR 조건으로 마커 매칭 추가 — 두 paradigm 모두 처리.
    //     안전성: 매핑된 원 Credit 이 응답 표시 대상 (creditLedgerIds) 일 때만 PT_USE 이전됨 (라인 552 가드).
    //           Cancel Credit 에서 추가 사용 없는 일반 케이스 (시나리오 1/5/6/7 R1-2 등) 는 이전분 0 으로 영향 없음.
    Map<Id, Map<Id, Map<Id, Integer>>> ptsByOrderBySubtypeByCredit = new Map<Id, Map<Id, Map<Id, Integer>>>();
    for (AggregateResult ar : [
      SELECT DebitLoyaltyLedger.TransactionJournal.OrderId orderId,
             CreditLoyaltyLedgerId creditId,
             CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId subtypeId,
             SUM(Points) totalPts
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
        AND ActionType = 'Debit'
        AND (DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = TRUE
             OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        AND DebitLoyaltyLedger.TransactionJournal.OrderId IN :targetOrderIds
        AND DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_DEBIT
      GROUP BY DebitLoyaltyLedger.TransactionJournal.OrderId,
               CreditLoyaltyLedgerId,
               CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId
      LIMIT 50000
    ]) {
      Id oid = (Id) ar.get('orderId');
      Id cid = (Id) ar.get('creditId');
      Id sid = (Id) ar.get('subtypeId');   // null 가능 (옛 데이터 등)
      if (oid == null || cid == null) {
        continue;
      }
      Integer pts = ar.get('totalPts') == null ? 0 : ((Decimal) ar.get('totalPts')).abs().intValue();
      if (!ptsByOrderBySubtypeByCredit.containsKey(oid)) {
        ptsByOrderBySubtypeByCredit.put(oid, new Map<Id, Map<Id, Integer>>());
      }
      if (!ptsByOrderBySubtypeByCredit.get(oid).containsKey(sid)) {
        ptsByOrderBySubtypeByCredit.get(oid).put(sid, new Map<Id, Integer>());
      }
      ptsByOrderBySubtypeByCredit.get(oid).get(sid).put(cid, pts);
    }

    // [3] 매핑 — SubType 매칭 우선 + Fallback (가장 큰 점유)
    //   3-A. CC.SubType 과 동일 SubType 의 원 Credit 후보 시도 (정확)
    //   3-B. SubType=null 또는 매칭 안 되면 모든 SubType 후보 합쳐서 가장 큰 점유 (기존 동작 fallback)
    //   3-C. 단일 매핑 결과 (Map<Id, Id> 시그니처 유지로 호출자 변경 없음)
    for (Id cancelId : cancelLLToOrder.keySet()) {
      Id oid = cancelLLToOrder.get(cancelId);
      Id ccSid = cancelLLToSubtype.get(cancelId);   // CC 의 SubType (null 가능)

      Map<Id, Map<Id, Integer>> subtypeToOriginCredits = ptsByOrderBySubtypeByCredit.get(oid);
      if (subtypeToOriginCredits == null || subtypeToOriginCredits.isEmpty()) {
        continue;
      }

      // [3-A] SubType 매칭 시도 (정확)
      Map<Id, Integer> originCandidates = null;
      if (ccSid != null) {
        originCandidates = subtypeToOriginCredits.get(ccSid);
      }

      // [3-B] Fallback — SubType 매칭 안 되면 모든 SubType 후보 합치기 (기존 동작)
      if (originCandidates == null || originCandidates.isEmpty()) {
        originCandidates = new Map<Id, Integer>();
        for (Map<Id, Integer> creds : subtypeToOriginCredits.values()) {
          for (Id cid : creds.keySet()) {
            Integer pts = creds.get(cid);
            Integer cur = originCandidates.containsKey(cid) ? originCandidates.get(cid) : 0;
            originCandidates.put(cid, cur + (pts == null ? 0 : pts));
          }
        }
      }

      if (originCandidates.isEmpty()) {
        continue;
      }

      // [3-C] 후보 중 가장 큰 점유 선택 (단일 매핑)
      Id bestOrigin = null;
      Integer bestPts = 0;
      for (Id origCid : originCandidates.keySet()) {
        Integer p = originCandidates.get(origCid);
        if (p != null && p > bestPts) {
          bestPts = p;
          bestOrigin = origCid;
        }
      }
      if (bestOrigin != null) {
        result.put(cancelId, bestOrigin);
      }
    }
    return result;
  }

  /**
   * [2026-04-24 R1-2 Fix / 2026-04-25 R1-9 Fix] 각 Credit LL 의 "순 사용량(PT_USE)" 계산.
   *
   * 기존 로직(~04-23):
   *   - ActionType 'Debit' 은 +, 'DebitCancellation' 은 - 로 합산
   *   - 문제: v3 `cancelPointRedemption_v3` 는 DebitCancellation LLT 를 생성하지 않음 → PT_USE 고정 (R1-2)
   *
   * 04-24 수정:
   *   - Credit LL × Order 별 Debit 사용량 집계 후 주문 단위 취소 비율 반영
   *
   * 04-25 수정 (본 시나리오 3 R1-9 등 커버):
   *   - `orderDeletedDebitMap` (주문별 삭제된 Debit 금액) 을 추가로 받아서,
   *     effectiveCancel = max(0, orderRedeemCancelMap - orderDeletedDebitMap) 로 보정.
   *   - 이유: DELETE /sale/deposit 경로에서 원 Debit 이 IsDeleted=TRUE 로 마킹되고 Point Redeem Cancel 이
   *     별도 생성되는데, 이 Cancel 은 이미 삭제된 원 Debit 과 상쇄된 "과거 이벤트" 이므로
   *     현재 활성 Debit 에 대한 감산 대상이 아님.
   *
   * governor limit: SOQL 1회 (2중 GROUP BY), 응답 row 는 Credit 수 × Order 수 이내.
   */
  private static Map<Id, Integer> buildAccrualUsedPointMap(
    Id memberId,
    Set<Id> creditLedgerIds,
    Map<Id, Integer> orderRedeemCancelMap,
    Map<Id, Integer> orderPointUsedMap,
    Map<Id, Integer> orderDeletedDebitMap,
    Map<Id, Id> redeemCancelCreditOriginMap
  ) {
    Map<Id, Integer> result = new Map<Id, Integer>();

    if (memberId == null || creditLedgerIds == null || creditLedgerIds.isEmpty()) {
      return result;
    }
    if (orderRedeemCancelMap == null) {
      orderRedeemCancelMap = new Map<Id, Integer>();
    }
    if (orderPointUsedMap == null) {
      orderPointUsedMap = new Map<Id, Integer>();
    }
    if (orderDeletedDebitMap == null) {
      orderDeletedDebitMap = new Map<Id, Integer>();
    }
    if (redeemCancelCreditOriginMap == null) {
      redeemCancelCreditOriginMap = new Map<Id, Id>();
    }

    // 1단계: Credit LL × Order 별 Debit 사용량 집계 (삭제된 Debit 제외)
    Map<Id, Map<Id, Integer>> usedByCreditByOrder = new Map<Id, Map<Id, Integer>>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId,
             DebitLoyaltyLedger.TransactionJournal.OrderId orderId,
             SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :creditLedgerIds
        AND ActionType = 'Debit'
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        // [scn5 R1-10 Fix 2026-04-27] 반품 입금 삭제 재차감 Debit LLT 제외
        //   v3 paradigm 으로 원본 Debit trace 가 보존된 상태에서 재차감 trace 가 함께 합산되면
        //   원 적립 Credit 의 PT_USE 가 두 배가 되는 문제(시나리오5 의 판매1 구매포인트 8000) 해결.
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        // [scn6 R2-9 Fix 2026-04-27] 통반품/전체판매 DELETE 시 에코포인트 취소 Debit LLT 제외
        //   FULL_RETURN_ECO_POINT_CANCEL 마커가 붙은 Api Forced Debit TJ 의 LLT 는 사용 흔적이 아니라
        //   소멸 흔적이므로 PT_USE 에 합산되면 안 됨.
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :ADDITIONAL_NOTE_FULL_RETURN_ECO_POINT_CANCEL)
      GROUP BY CreditLoyaltyLedgerId, DebitLoyaltyLedger.TransactionJournal.OrderId
      LIMIT 50000
    ]) {
      Id creditId = (Id) ar.get('creditLedgerId');
      Id orderId = (Id) ar.get('orderId');
      if (creditId == null) {
        continue;
      }
      Integer points = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();
      if (!usedByCreditByOrder.containsKey(creditId)) {
        usedByCreditByOrder.put(creditId, new Map<Id, Integer>());
      }
      usedByCreditByOrder.get(creditId).put(orderId, points);
    }

    // 2단계: Credit LL 별로 주문 취소 여부를 반영한 순 사용량 계산
    for (Id creditId : usedByCreditByOrder.keySet()) {
      Integer netUsed = 0;
      Map<Id, Integer> usedByOrder = usedByCreditByOrder.get(creditId);
      for (Id orderId : usedByOrder.keySet()) {
        Integer usedInThisOrder = usedByOrder.get(orderId);
        if (usedInThisOrder == null || usedInThisOrder <= 0) {
          continue;
        }

        // [2026-04-25] 효과 있는 취소 = 전체 취소 - 이미 상쇄된 삭제 Debit 분
        Integer rawCancel = (orderId != null && orderRedeemCancelMap.containsKey(orderId))
            ? orderRedeemCancelMap.get(orderId)
            : 0;
        Integer deletedDebit = (orderId != null && orderDeletedDebitMap.containsKey(orderId))
            ? orderDeletedDebitMap.get(orderId)
            : 0;
        Integer orderCancel = Math.max(0, rawCancel - deletedDebit);

        Integer orderTotalUsed = (orderId != null && orderPointUsedMap.containsKey(orderId))
            ? orderPointUsedMap.get(orderId)
            : 0;

        if (orderCancel <= 0 || orderTotalUsed <= 0) {
          // 취소 기록이 없거나 기준 사용량 미집계 → 원 사용량 반영
          netUsed += usedInThisOrder;
        } else if (orderCancel >= orderTotalUsed) {
          // 전액 취소 → 이 Credit 의 해당 주문 사용량은 0
        } else {
          // 부분 취소 → 비례 잔여 계산 (오버플로 방어용 Long 중간 변환)
          Long numerator = (Long) usedInThisOrder * (Long) (orderTotalUsed - orderCancel);
          Integer remaining = (Integer) (numerator / (Long) orderTotalUsed);
          if (remaining > 0) {
            netUsed += remaining;
          }
        }
      }
      result.put(creditId, netUsed);
    }

    // [2026-04-25 추가 Fix] 3단계: Point Redeem Cancel Credit 사용분을 "원 Credit" 의 PT_USE 에 이월.
    //   - redeemCancelCreditOriginMap 이 비어있으면 SOQL 실행 없이 조기 스킵 (S1/S2 보호)
    //   - Cancel Credit 은 AccrualHistoryList 에서 숨김 처리되므로 그 자체의 PT_USE 는 집계 대상 아님
    //   - 대신 그 Cancel Credit 을 사용한 Debit LLT 의 Points 를 매핑된 원 Credit 에 가산하여
    //     MD 의 "단일 로우" 기대를 만족시킴
    if (!redeemCancelCreditOriginMap.isEmpty()) {
      Set<Id> cancelCreditIds = redeemCancelCreditOriginMap.keySet();
      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId cancelCreditId, SUM(Points) totalPts
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :memberId
          AND CreditLoyaltyLedgerId IN :cancelCreditIds
          AND ActionType = 'Debit'
          AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        GROUP BY CreditLoyaltyLedgerId
        LIMIT 50000
      ]) {
        Id cancelCid = (Id) ar.get('cancelCreditId');
        Id originCid = redeemCancelCreditOriginMap.get(cancelCid);
        if (originCid == null) {
          continue;
        }
        // 원 Credit 이 AccrualHistoryList 집계 대상 (creditLedgerIds) 이어야만 이월
        if (!creditLedgerIds.contains(originCid)) {
          continue;
        }
        Integer add = ar.get('totalPts') == null ? 0 : ((Decimal) ar.get('totalPts')).abs().intValue();
        if (add <= 0) {
          continue;
        }
        Integer prev = result.containsKey(originCid) ? result.get(originCid) : 0;
        result.put(originCid, prev + add);
      }
    }

    return result;
  }

  private static Map<Id, Integer> buildAccrualReductionPointMap(Id memberId, Set<Id> creditLedgerIds) {
    Map<Id, Integer> result = new Map<Id, Integer>();

    if (memberId == null || creditLedgerIds.isEmpty()) {
      return result;
    }

    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId, ActionType actionType, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :creditLedgerIds
        AND ActionType = 'Debit'
        AND (DebitLoyaltyLedgerId = NULL
        OR DebitLoyaltyLedger.TransactionJournal.JournalType.Name != 'Accrual Reversal')
        AND (DebitLoyaltyLedgerId = NULL
        OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
      GROUP BY CreditLoyaltyLedgerId, ActionType
    ]) {
      Id creditLedgerId = (Id) ar.get('creditLedgerId');
      if (!result.containsKey(creditLedgerId)) {
        result.put(creditLedgerId, 0);
      }
      Integer amount = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();
      result.put(creditLedgerId, result.get(creditLedgerId) + amount);
    }

    return result;
  }

  private static Map<Id, Integer> buildAccrualExpiredPointMap(
      Id memberId,
      List<LoyaltyLedger> creditLedgers,
      Map<Id, Integer> reductionPointMap,
      Map<Id, Id> ecoRestoreLLToOriginLLId
  ) {
    Map<Id, Integer> result = new Map<Id, Integer>();

    if (memberId == null || creditLedgers.isEmpty()) {
      return result;
    }
    // [Eco Restore Sum Fix 2026-05-03] null 방어
    if (ecoRestoreLLToOriginLLId == null) {
      ecoRestoreLLToOriginLLId = new Map<Id, Id>();
    }

    Set<Id> subtypeIds = new Set<Id>();
    Set<Date> expiryDates = new Set<Date>();
    Set<Id> creditLedgerIds = new Set<Id>();
    for (LoyaltyLedger credit : creditLedgers) {
      if (credit.Id != null) {
        creditLedgerIds.add(credit.Id);
      }
      if (credit.LoyaltyPgmCrcySubtypeId != null) {
        subtypeIds.add(credit.LoyaltyPgmCrcySubtypeId);
      }
      if (credit.ExpiryDate != null) {
        expiryDates.add(credit.ExpiryDate);
      }
    }

    if (subtypeIds.isEmpty() || expiryDates.isEmpty()) {
      return result;
    }

    Map<String, Integer> availableExpiredByKey = new Map<String, Integer>();
    Map<Id, Integer> returnCancelByCreditLedgerId = new Map<Id, Integer>();

    /**
     * [26.04.02 수정] 반품 포인트 적립취소 미표시 오류 해결
     *
     * 기존 문제:
     * - EventType = 'Expiry'만 조회하여 자동 만료 포인트만 포함
     * - 반품으로 인한 적립취소(EventType = 'Debit')는 제외됨
     * - 결과: PT_DESTROY(소멸포인트) = 0 → ERP 미표시
     *
     * 수정 내용:
     * - EventType = 'Expiry' (자동 만료)
     * - + (EventType = 'Debit' AND TransactionJournal.JournalType.Name = 'Accrual Reversal')
     * - 반품으로 인한 적립취소도 소멸 대상에 포함
     *
     * 원리:
     * - Accrual Reversal은 cancelPointsCreditedOnPurchase()에서 생성
     * - Salesforce Loyalty 표준 엔진이 LoyaltyLedger를 EventType='Debit'으로 생성
     * - 이는 포인트 사용이 아니라 포인트 적립취소(반품)의 의미
     */

    // [AS-IS] 기존 코드 (EventType = 'Expiry'만)
    /*
    for (AggregateResult ar : [
      SELECT LoyaltyPgmCrcySubtypeId subtypeId, ExpiryDate expiryDate, SUM(Points) totalPoints
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId AND EventType = 'Expiry' AND LoyaltyPgmCrcySubtypeId IN :subtypeIds AND ExpiryDate IN :expiryDates
      GROUP BY LoyaltyPgmCrcySubtypeId, ExpiryDate
    ]) {
      String key = buildExpiryAllocationKey(memberId, (Id) ar.get('subtypeId'), (Date) ar.get('expiryDate'));
      availableExpiredByKey.put(key, ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue());
    }
    */

    // [TO-BE] 수정된 코드 (EventType = 'Expiry' OR 반품 적립취소 추가)
    for (AggregateResult ar : [
      SELECT LoyaltyPgmCrcySubtypeId subtypeId, ExpiryDate expiryDate, SUM(Points) totalPoints
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId AND EventType = 'Expiry' AND LoyaltyPgmCrcySubtypeId IN :subtypeIds AND ExpiryDate IN :expiryDates
      GROUP BY LoyaltyPgmCrcySubtypeId, ExpiryDate
    ]) {
      String key = buildExpiryAllocationKey(memberId, (Id) ar.get('subtypeId'), (Date) ar.get('expiryDate'));
      availableExpiredByKey.put(key, ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue());
    }

    if (!creditLedgerIds.isEmpty()) {
      // [R1-4 수정 2026-04-24] 통반품 에코포인트 소멸을 PT_DESTROY 에 집계하기 위해 OR 조건 확장.
      //   - 기존: Accrual Reversal JournalType 만 집계 (구매/사은 포인트 반품 취소용)
      //   - 추가: AdditionalNotes__c = 'FULL_RETURN_ECO_POINT_CANCEL'
      //           → 통반품 시 cancelEcoPointsForFullReturn 경로가 남기는 Api Forced Debit TJ
      //             (JournalType = 'Redemption') 를 에코포인트 소멸로 포함.
      //   DML 없음. 읽기 전용 확장.
      // [Eco Cancel after Return Delete Fix 2026-05-03] 삭제된 반품 Order 의 차감 LLT 제외
      //   배경: 통반품 → 취소 (반품 삭제) 시 restoreEcoPointsFromReturn 가 새 적립 LL 만 만들고
      //         1차 차감 LLT (FULL_RETURN_ECO_POINT_CANCEL) 는 IsDeleted=FALSE 로 살아있음.
      //         이 차감 LLT 가 PT_DESTROY 로 잘못 합산되어 "이미 소멸됨" 으로 표시되는 문제.
      //   해결: SaleId 가 가리키는 반품 Order 가 IsDeleted=TRUE 이면 = "반품이 삭제됨" 신호이므로
      //         그 차감 LLT 는 합산에서 제외 (재적립으로 무효화된 상태).
      //         SaleId__c = NULL 인 케이스 (일반 사용 흔적 등) 는 OR 분기로 그대로 통과.
      // [Eco Restore Sum Fix 2026-05-03] 재적립 LL Id 도 IN 절에 포함
      //   배경: 통반품 → 취소 → 재통반품 시 차감 LLT 의 CreditLL 이 재적립 LL 인 경우,
      //         원본 LL 만 IN 절에 있으면 SOQL 결과에 안 잡혀 PT_DESTROY 누락됨.
      //   해결: 재적립 LL Id 도 IN 절에 포함하고, 결과에서 OrderId 그룹핑하여 원본 LL 로 합산.
      Set<Id> allEcoRelatedLLIds = new Set<Id>(creditLedgerIds);
      allEcoRelatedLLIds.addAll(ecoRestoreLLToOriginLLId.keySet());

      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId creditLedgerId, SUM(Points) totalPoints
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND CreditLoyaltyLedgerId IN :allEcoRelatedLLIds
          AND ActionType = 'CreditCancellation'
          AND (
            DebitLoyaltyLedger.TransactionJournal.JournalType.Name = :JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
            OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = :ADDITIONAL_NOTE_FULL_RETURN_ECO_POINT_CANCEL
          )
          AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
          AND (DebitLoyaltyLedger.TransactionJournal.SaleId__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = FALSE)
        GROUP BY CreditLoyaltyLedgerId
      ]) {
        Id creditLedgerId = (Id) ar.get('creditLedgerId');
        Integer points = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();

        // [Eco Restore Sum Fix 2026-05-03] 재적립 LL 의 차감은 원본 LL 의 PT_DESTROY 로 이전 합산.
        //   creditLedgerId 가 재적립 LL Id 이면 → 원본 LL Id 로 매핑 후 누적.
        //   그 외에는 원본 LL Id 로 직접 누적 (= 기존 동작).
        Id targetLLId = ecoRestoreLLToOriginLLId.containsKey(creditLedgerId)
            ? ecoRestoreLLToOriginLLId.get(creditLedgerId)
            : creditLedgerId;
        Integer prev = returnCancelByCreditLedgerId.containsKey(targetLLId)
            ? returnCancelByCreditLedgerId.get(targetLLId)
            : 0;
        returnCancelByCreditLedgerId.put(targetLLId, prev + points);
      }
    }

    for (LoyaltyLedger credit : creditLedgers) {
      if (credit.Id == null || credit.LoyaltyPgmCrcySubtypeId == null || credit.ExpiryDate == null) {
        result.put(credit.Id, 0);
        continue;
      }

      Integer reduction = reductionPointMap.containsKey(credit.Id) ? reductionPointMap.get(credit.Id) : 0;
      Integer credited = credit.Points == null ? 0 : credit.Points.intValue();
      Integer remaining = Math.max(0, credited - reduction);
      String key = buildExpiryAllocationKey(memberId, credit.LoyaltyPgmCrcySubtypeId, credit.ExpiryDate);
      Integer allocatable = availableExpiredByKey.containsKey(key) ? availableExpiredByKey.get(key) : 0;
      Integer expiredPoints = Math.min(remaining, allocatable);
      Integer returnCancelledPoints = returnCancelByCreditLedgerId.containsKey(credit.Id) ? returnCancelByCreditLedgerId.get(credit.Id) : 0;

      result.put(credit.Id, expiredPoints + returnCancelledPoints);
      availableExpiredByKey.put(key, Math.max(0, allocatable - expiredPoints));
    }

    return result;
  }

  /**
   * 회원 정보 조회
   * */
  public ApiResult getMemberHelpInfo(Map<String, Object> reqData) {
    // 요청 body 검증
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, 'Request body is empty.');
    }

    // 회원번호 추출
    String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);

    //회원 조회(요청 데이터)
    List<LoyaltyProgramMember> lpmList = [
      SELECT Id, Contact.MemberNo__c, MemberStatus, Contact.Name, Contact.Phone, Contact.MobilePhone, Contact.Email, Contact.Birthdate
      FROM LoyaltyProgramMember
      WHERE Contact.MemberNo__c = :memberNo
      LIMIT 1
    ];

    if (lpmList.isEmpty()) {
      throw new CustomException(400, '존재하지 않는 회원입니다. memberNo=' + memberNo);
    }

    LoyaltyProgramMember lpm = lpmList[0];
    Map<String, Object> data = new Map<String, Object>();

    //---------임금 내역 조회---------
    List<TransactionJournal> tjlist = [
      SELECT
        Brand,
        DepositType__c,
        DepositNo__c,
        DeposiSeqNo__c,
        TransactionAmount,
        PaymentMethod,
        Quantity,
        ActivityDate,
        Status,
        JournalTypeName__c,
        JournalReason,
        TotalPromotionDiscount,
        PromotionId
      FROM TransactionJournal
      WHERE MemberId = :lpm.id AND TransactionAmount != NULL AND DepositNo__c != NULL
    ];

    List<Map<String, Object>> depositlist = new List<Map<String, Object>>();

    for (TransactionJournal t : tjlist) {
      Map<String, Object> deposit = new Map<String, Object>();
      deposit.put('Brand', t.Brand);
      deposit.put('DepositType', t.DepositType__c);
      deposit.put('DepositNo', t.DepositNo__c);
      deposit.put('DepositSeqNo', t.DeposiSeqNo__c);
      deposit.put('JournalReason', t.JournalReason);

      deposit.put('TransactionAmount', t.TransactionAmount);

      String paymentCode = t.PaymentMethod;
      String paymentLabel = getPaymentMethodLabel(paymentCode);

      deposit.put('PaymentMethodCode', paymentCode);
      deposit.put('PaymentMethodName', paymentLabel);

      deposit.put('Quantity', t.Quantity);
      deposit.put('Status', t.Status);

      deposit.put('JournalTypeName', t.JournalTypeName__c);
      deposit.put('JournalReason', t.JournalReason);

      deposit.put('TotalPromotionDiscount', t.TotalPromotionDiscount);
      deposit.put('PromotionId', t.PromotionId);

      depositlist.add(deposit);
    }

    data.put('Depositlist', depositlist);

    //---------구매 내역 조회---------
    List<Order> olist = [
      SELECT
        Name,
        EffectiveDate,
        Status,
        ActualPaymentAmount__c,
        TotalAmount,
        StoreCode__c,
        SaleNo__c,
        EndDate,
        Type,
        SaleStatus__c,
        OrderReferenceNumber,
        InsertId__c,
        ActivatedDate,
        DeleteDateTime__c
      FROM Order
      WHERE MemberNo__c = :lpm.ContactId
      LIMIT 1
    ];

    if (olist.isEmpty()) {
      // throw new CustomException(400, '해당 회원의 구매 내역이 없습니다.');
    }

    List<Map<String, Object>> orders = new List<Map<String, Object>>();

    for (Order o : olist) {
      Map<String, Object> order = new Map<String, Object>();

      // 기본 주문 정보
      order.put('OrderName', o.Name);
      order.put('OrderDate', o.EffectiveDate);
      order.put('Status', o.Status);

      // 금액 정보
      order.put('TotalAmount', o.TotalAmount);
      order.put('ActualPaymentAmount', o.ActualPaymentAmount__c);

      // 매장 정보
      order.put('StoreCode', o.StoreCode__c);

      // 판매 / ERP 연계 정보
      order.put('SaleNo', o.SaleNo__c);
      order.put('SaleEndDate', o.EndDate);
      order.put('OrderType', o.Type);
      order.put('SaleStatus', o.SaleStatus__c);
      order.put('OrderReferenceNumber', o.OrderReferenceNumber);
      order.put('InsertId', o.InsertId__c);

      // 상태/이력 관련
      order.put('ActivatedDate', o.ActivatedDate);
      order.put('DeleteDateTime', o.DeleteDateTime__c);

      orders.add(order);
    }

    data.put('OrdersList', orders);

    //데이터 존재X
    //---------수선 내역 조회---------
    List<WorkOrder> wlist = [
      SELECT
        WorkOrderNumber, // 작업 주문 번호 (수선 접수 번호)
        Subject, // 수선 제목 / 작업 주제
        Status, // 수선 진행 상태 (접수, 진행중, 완료 등)
        Priority, // 우선순위 (긴급 여부 판단)
        StartDate, // 수선 시작 일자
        EndDate, // 수선 완료 일자
        IsClosed, // 작업 종료 여부 (true = 완료)
        GrandTotal, // 총 수선 금액
        Discount, // 할인 금액 (무상/부분 유상 판단)
        Description, // 수선 상세 설명
        CreatedDate // 수선 접수(생성) 일자
      FROM WorkOrder
      WHERE ContactId = :lpm.ContactId
      ORDER BY CreatedDate DESC
    ];

    // if(wlist.isEmpty()){
    //             throw new CustomException(400, '해당 회원의 수선 내역이 없습니다.');
    // }

    List<Map<String, Object>> works = new List<Map<String, Object>>();

    for (WorkOrder w : wlist) {
      Map<String, Object> work = new Map<String, Object>();

      // 기본 식별 정보
      work.put('WorkOrderNumber', w.WorkOrderNumber);
      work.put('Subject', w.Subject);
      work.put('Description', w.Description);

      // 상태 정보
      work.put('Status', w.Status);
      work.put('Priority', w.Priority);
      work.put('IsClosed', w.IsClosed);

      // 날짜 정보
      work.put('StartDate', w.StartDate);
      work.put('EndDate', w.EndDate);
      work.put('CreatedDate', w.CreatedDate);

      // 금액 정보
      work.put('GrandTotal', w.GrandTotal);
      work.put('Discount', w.Discount);

      works.add(work);
    }

    data.put('WorksList', works);

    //     //데이터 존재X
    //     //---------CS 내역 조회---------
    List<Case> clist = [
      SELECT
        Id,
        CaseNumber, // 사례 번호
        Subject, // 제목
        Type, // 유형
        Reason, // 사례 이유
        Origin, // 접수 경로
        Status, // 상태
        Priority, // 중요도
        IsEscalated, // 에스컬레이션 여부
        CreatedDate, // 접수 일시
        ClosedDate, // 종료 일시
        Owner.Name, // 담당자
        Description // 설명
      FROM Case
      WHERE Contact.MemberNo__c = :memberNo
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    // if (cList.isEmpty()) {
    //             throw new CustomException(400, '해당 회원의 cs내역이 존재하지 않습니다.');
    // }

    List<Map<String, Object>> cases = new List<Map<String, Object>>();

    for (Case c : cList) {
      Map<String, Object> cs = new Map<String, Object>();

      cs.put('CaseId', c.Id);
      cs.put('CaseNumber', c.CaseNumber);
      cs.put('Subject', c.Subject);
      cs.put('Type', c.Type);
      cs.put('Reason', c.Reason);
      cs.put('Origin', c.Origin);
      cs.put('Status', c.Status);
      cs.put('Priority', c.Priority);
      cs.put('IsEscalated', c.IsEscalated);
      cs.put('CreatedDate', c.CreatedDate);
      cs.put('ClosedDate', c.ClosedDate);
      cs.put('OwnerName', c.Owner != null ? c.Owner.Name : null);
      cs.put('Description', c.Description);

      cases.add(cs);
    }

    data.put('CustomerServiceHistory', cases);

    //데이터 존재X
    //---------상담 내역 조회---------

    List<Task> tlist = [
      SELECT
        Id,
        Subject, // 상담 제목
        Type, // 상담 유형
        Status, // 상담 상태
        Priority, // 중요도
        ActivityDate, // 상담 일자
        Description, // 상담 내용
        CallType, // 통화 유형
        CallDisposition, // 통화 결과
        CallDurationInSeconds, // 통화 시간
        CompletedDateTime, // 완료 일시
        Owner.Name, // 상담 담당자
        CreatedDate, // 기록 생성일
        WhatId // 관련 Case / Order
      FROM Task
      WHERE WhoId = :lpm.ContactId
      ORDER BY CreatedDate DESC
      LIMIT 1
    ];

    // if(tlist.isEmpty()){
    //             throw new CustomException(400, '해당 회원의 상담 내역이 존재하지 않습니다.');
    // }

    List<Map<String, Object>> tasks = new List<Map<String, Object>>();

    for (Task t : tlist) {
      Map<String, Object> task = new Map<String, Object>();

      // 기본 식별 정보
      task.put('TaskId', t.Id);
      task.put('Subject', t.Subject); // 상담 제목
      task.put('Type', t.Type); // 상담 유형
      task.put('Status', t.Status); // 상담 상태
      task.put('Priority', t.Priority); // 중요도

      // 일정 / 시간 관련
      task.put('ActivityDate', t.ActivityDate); // 상담 일자
      task.put('CompletedDateTime', t.CompletedDateTime); // 완료 일시
      task.put('CallDurationInSeconds', t.CallDurationInSeconds); // 통화 시간(초)

      // 상담 내용
      task.put('Description', t.Description); // 상담 내용

      // 통화 상담 정보
      task.put('CallType', t.CallType); // 통화 유형
      task.put('CallDisposition', t.CallDisposition); // 통화 결과

      // 담당자 / 생성 정보
      task.put('OwnerName', t.Owner != null ? t.Owner.Name : null); // 상담 담당자
      task.put('CreatedDate', t.CreatedDate); // 기록 생성 일자

      // 연관 객체 (Case / Order 등)
      task.put('RelatedObjectId', t.WhatId);

      tasks.add(task);
    }

    data.put('ConsultationList', tasks);

    //데이터 존재X
    //---------상담 노트 조회---------
    //---------상담 노트 조회 (Task 기반)---------
    /** 상담 노트 연동 X */
    // List<Task> noteTasks = [
    //   SELECT Id, Subject, Description, CreatedDate, CompletedDateTime, Owner.Name, WhatId
    //   FROM Task
    //   WHERE WhoId = :lpm.ContactId
    //   ORDER BY CreatedDate DESC
    // ];

    // List<Map<String, Object>> consultNoteList = new List<Map<String, Object>>();

    // for (Task t : noteTasks) {
    //   // Apex 단에서 Description 존재 여부 판단
    //   if (String.isNotBlank(t.Description)) {
    //     Map<String, Object> note = new Map<String, Object>();
    //     note.put('TaskId', t.Id);
    //     note.put('Subject', t.Subject);
    //     note.put('Note', t.Description);
    //     note.put('CreatedDate', t.CreatedDate);
    //     note.put('OwnerName', t.Owner != null ? t.Owner.Name : null);
    //     note.put('RelatedObjectId', t.WhatId);

    //     consultNoteList.add(note);
    //   }
    // }

    // data.put('ConsultationNoteList', consultNoteList);

    //---------변경 내역 조회---------
    List<Map<String, Object>> historyList = new List<Map<String, Object>>();

    // 1. LoyaltyProgramMemberHistory
    for (LoyaltyProgramMemberHistory h : [
      SELECT CreatedDate, Field, OldValue, NewValue, CreatedBy.Name
      FROM LoyaltyProgramMemberHistory
      WHERE LoyaltyProgramMemberId = :lpm.Id
    ]) {
      historyList.add(buildHistoryRow(h.CreatedDate, 'LoyaltyProgramMember', h.Field, h.OldValue, h.NewValue, h.CreatedBy.Name));
    }

    // 2. ContactHistory
    if (lpm.ContactId != null) {
      for (ContactHistory h : [
        SELECT CreatedDate, Field, OldValue, NewValue, CreatedBy.Name
        FROM ContactHistory
        WHERE ContactId = :lpm.ContactId
      ]) {
        historyList.add(buildHistoryRow(h.CreatedDate, 'Contact', h.Field, h.OldValue, h.NewValue, h.CreatedBy.Name));
      }
    }

    if (historyList.isEmpty()) {
      throw new CustomException(400, '변경 내역이 없습니다.');
    }

    data.put('HistoryUpdatedList', historyList);

    //---------사은품 내역 -> 보상 내역으로 대체---------
    List<MemberBenefit> mbList = [
      SELECT
        Id,
        Name, // 사은품 지급 이름
        Status, // 지급 상태
        StartDate,
        EndDate,
        Description,
        CreatedDate,
        BenefitId,
        Benefit.Name, // 사은품명
        Benefit.BenefitTypeId, // 사은품 유형
        Benefit.Description, // 설명
        Benefit.ImageUrl // 이미지
      FROM MemberBenefit
      WHERE MemberId = :lpm.Id
      ORDER BY CreatedDate DESC
    ];

    List<Map<String, Object>> giftList = new List<Map<String, Object>>();

    for (MemberBenefit mb : mbList) {
      Map<String, Object> gift = new Map<String, Object>();

      // 지급 정보
      gift.put('MemberBenefitId', mb.Id);
      gift.put('Status', mb.Status);
      gift.put('StartDate', mb.StartDate);
      gift.put('EndDate', mb.EndDate);
      gift.put('CreatedDate', mb.CreatedDate);
      gift.put('Description', mb.Description);

      // 사은품 정의 정보
      gift.put('BenefitId', mb.BenefitId);
      gift.put('BenefitName', mb.Benefit != null ? mb.Benefit.Name : null);
      gift.put('BenefitCategory', mb.Benefit != null ? mb.Benefit.BenefitTypeId : null);
      gift.put('BenefitDescription', mb.Benefit != null ? mb.Benefit.Description : null);
      gift.put('BenefitImage', mb.Benefit != null ? mb.Benefit.ImageUrl : null);

      giftList.add(gift);
    }

    data.put('GiftList', giftList);

    //---------포인트 조회---------

    // List<LoyaltyMemberCurrency> lpcList = [
    //     SELECT
    //     LoyaltyMemberId,
    //         Name, //포인트 하위 이름
    //         LoyaltyProgramCurrency.HasEscrow, //포인트 적립 예정 유무
    //         LoyaltyProgramCurrency.LoyaltyTierGroupId, //멤버십 그룹
    //         PointsBalance, //포인트 잔액
    //         TotalPointsAccrued, // 누적된 포인트 총액
    //         EscrowPointsBalance, //포인트 예정 잔액
    //         TotalPointsRedeemed, //상황된 포인트 총액
    //         TotalEscrowRolloverPoints, //에스크로 롤오버 포인트 총액
    //         BalanceBeforeReset, //재설정 전 잔액

    //         LastEscrowProcessedDate, //포인트 지급 최종 일자
    //         LastPointsAggregationDate, //마지막 포인트 집계 일자
    //         LastResetDate, //마지막 재설정 일자
    //         NextResetDate, //다음 재설정 일자
    //         LastExpiredPtTraceabilityRunDt, //최근 만료된 포인트 추적 기능 실행 일자
    //         LastAccrualProcessedDate, //최종 누적 처리 일자
    //         RedemStlPendFromDateTime //상환 정산 보류 시작 일자 시간

    //     FROM LoyaltyMemberCurrency
    //     WHERE LoyaltyMember.Contact.MemberNo__c = :memberNo
    // ];

    // // if (lpcList.isEmpty()) {
    //     //     throw new CustomException(400,'보유한 포인트가 없습니다.');
    // // }

    // List<Map<String, Object>> pointList = new List<Map<String, Object>>();

    // for (LoyaltyMemberCurrency lpc : lpcList) {
    //     Map<String, Object> points = new Map<String, Object>();

    //     points.put('NamRedemStlPendFromDateTimee', lpc.RedemStlPendFromDateTime);
    //     points.put('LastAccrualProcessedDate', lpc.LastAccrualProcessedDate);
    //     points.put('NLastExpiredPtTraceabilityRunDtame', lpc.LastExpiredPtTraceabilityRunDt);
    //     points.put('NextResetDate', lpc.NextResetDate);
    //     points.put('LastResetDate', lpc.LastResetDate);
    //     points.put('LastPointsAggregationDate', lpc.LastPointsAggregationDate);
    //     points.put('NamLastEscrowProcessedDatee', lpc.LastEscrowProcessedDate);
    //     points.put('BalanceBeforeReset', lpc.BalanceBeforeReset);
    //     points.put('TotalEscrowRolloverPoints', lpc.TotalEscrowRolloverPoints);
    //     points.put('TotalPointsRedeemed', lpc.TotalPointsRedeemed);
    //     points.put('NaEscrowPointsBalancee', lpc.EscrowPointsBalance);
    //     points.put('TotalPointsAccrued', lpc.TotalPointsAccrued);
    //     points.put('PointsBalance', lpc.PointsBalance);
    //     points.put('LoyaltyTierGroupId',lpc.LoyaltyProgramCurrency.LoyaltyTierGroupId);
    //     points.put('HasEscrow',lpc.LoyaltyProgramCurrency.HasEscrow);
    //     points.put('Name', lpc.Name);
    //     points.put('LoyaltyMemberId', lpc.LoyaltyMemberId);

    //     pointList.add(points);
    // }

    // data.put('PointList', pointList);

    // 26.04.02 WT 주석 시작 [기존 로직]
    // //고객사 요청 : 총포인트값만 보이게
    // //--------- 포인트 조회 ---------

    // AggregateResult[] totalPointResult = [
    //   SELECT SUM(PointsBalance) totalPointsBalance
    //   FROM LoyaltyMemberCurrency
    //   WHERE LoyaltyMember.Contact.MemberNo__c = :memberNo
    // ];

    // // 총 포인트 (PointsBalance 합계)
    // Decimal totalPointsBalance = 0;

    // if (!totalPointResult.isEmpty() && totalPointResult[0].get('totalPointsBalance') != null) {
    //   totalPointsBalance = (Decimal) totalPointResult[0].get('totalPointsBalance');
    // }

    // // PointList : 총 포인트만 1건
    // // List<Map<String, Object>> pointList = new List<Map<String, Object>>();

    // // Map<String, Object> totalPointRow = new Map<String, Object>();
    // // totalPointRow.put('TotalPointsBalance', totalPointsBalance);
    // // pointList.add(totalPointRow);

    // // 응답
    // // data.put('PointList', pointList);
    // data.put('TotalPointsBalance', totalPointsBalance);

    // 26.04.02 WT 수정 시작 [수정 로직]
    List<AggregateResult> totalPointResult = [
      SELECT SUM(AvailablePoints__c) totalPointsBalance
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE AvailablePoints__c > 0 AND ExpiryDate__c >= :Date.today() AND LoyaltyProgramMemberId__c = :lpm.Id
    ];
    Decimal totalPointsBalance = 0;
    if (!totalPointResult.isEmpty() && totalPointResult[0].get('totalPointsBalance') != null) {
      totalPointsBalance = (Decimal) totalPointResult[0].get('totalPointsBalance');
    }
    data.put('TotalPointsBalance', totalPointsBalance);

    // --------- 쿠폰 조회 ---------
    List<Voucher> vouchers = [
      SELECT
        Id,
        Status, // 쿠폰 상태
        EffectiveDate, // 시작일자 -> GD 발급일자
        VoucherDefinition.EffectiveDate, // 추가 GD 시작일자
        UseDate, // 사용일자
        ExpirationDate, // 종료일자
        CreatedDate, // 발급일자 -> GD 사용 안함
        CreatedBy.Name, // 등록자
        FaceValue, // 할인금액(정액)
        DiscountPercent, // 할인율(정률)
        VoucherCode, // 쿠폰번호
        Reason,
        InsertId__c,  // 등록자
        /* ===== VoucherDefinition ===== */
        VoucherDefinition.Type, // 쿠폰 타입
        VoucherDefinition.ExpirationPeriodUnit, // 기간 단위
        VoucherDefinition.ExpirationPeriod, // 기간 값
        VoucherDefinition.CouponManNo__c, // 쿠폰 관리 번호
        VoucherDefinition.CouponTypeCode__c, //쿠폰 구분 코드
        VoucherDefinition.InsertId__c, //등록자
        VoucherDefinition.Name, //쿠폰 이름
        VoucherDefinition.brand__c, //브랜드
        VoucherDefinition.ResponsibleDepartment__c, //담당부서
        VoucherDefinition.ResponsiblePerson__c, //담당자
        VoucherDefinition.ExpirationType,
        VoucherDefinition.Description //설명
      FROM Voucher
      WHERE LoyaltyProgramMemberId = :lpm.Id
      AND Status != 'Cancelled'
      ORDER BY CreatedDate DESC
    ];

    // List<Map<String, Object>> couponList = new List<Map<String, Object>>();
    List<VoucherResDTO> voucherResDtoList = new List<VoucherResDTO>();

    for (Voucher v : vouchers) {
      // Map<String, Object> coupon = new Map<String, Object>();

      // // 기본 정보
      // coupon.put('Id', v.Id);
      // coupon.put('CouponName', v.VoucherDefinition.Name);
      // coupon.put('Status', v.Status);

      // // 날짜 정보
      // coupon.put('StartDate', v.EffectiveDate);
      // coupon.put('UseDate', v.UseDate);
      // coupon.put('EndDate', v.ExpirationDate);
      // coupon.put('IssuedDate', v.CreatedDate);

      // // 금액 / 할인
      // coupon.put('FaceValue', v.FaceValue);
      // coupon.put('DiscountPercent', v.DiscountPercent);

      // // 쿠폰 정보
      // coupon.put('VoucherCode', v.VoucherCode);
      // coupon.put('CouponType', v.VoucherDefinition.Type);
      // coupon.put('ExpirationPeriodUnit', v.VoucherDefinition.ExpirationPeriod);
      // coupon.put('ExpirationPeriod', v.VoucherDefinition.ExpirationPeriod);
      // coupon.put('CouponManNo', v.VoucherDefinition.CouponManNo__c);
      // coupon.put('Created By', v.VoucherDefinition.InsertId__c);
      // coupon.put('Brand', v.VoucherDefinition.brand__c);
      // coupon.put('ResponsibleDepartment', v.VoucherDefinition.ResponsibleDepartment__c);

      // String couponManNoCode = (v.VoucherDefinition != null) ? v.VoucherDefinition.CouponTypeCode__c : null;

      // coupon.put('CouponTypeCode', COUPON_MAN_NO_MAP.containsKey(couponManNoCode) ? COUPON_MAN_NO_MAP.get(couponManNoCode) : couponManNoCode);
      // // 등록자
      // coupon.put('CreatedBy', v.CreatedBy != null ? v.CreatedBy.Name : null);

      // couponList.add(coupon);
      voucherResDtoList.add(new VoucherResDTO(v));
    }

    data.put('CouponList', voucherResDtoList);

    // =======================================================
    // 포인트 이력 조회 (적립 / 사용 / 소멸)
    // =======================================================

    Id memberId = lpm.Id;

    // 결과 리스트
    // List<Map<String, Object>> accrualHistoryList = new List<Map<String, Object>>();
    List<PointResDto.CreditPointResponse> creditPointResponseList = new List<PointResDto.CreditPointResponse>();
    // List<Map<String, Object>> usageExpiryHistoryList = new List<Map<String, Object>>();
    List<PointResDto.DebitPointResponse> debitPointResponseList = new List<PointResDto.DebitPointResponse>();

    // -------------------------------------------------------
    // LoyaltyLedger 조회
    // -------------------------------------------------------
    List<LoyaltyLedger> ledgers = [
      SELECT
        Id,
        ActivityDate,
        AdditionalNotes,
        EventType,
        Points,
        ExpiryDate,
        EscrowPointsCreditDate,
        LoyaltyProgramCurrency.Name,
        TransactionJournal.OrderId__c,
        TransactionJournal.TransactionAmount,
        TransactionJournalId,
        TransactionJournal.RelatedJournalId,
        TransactionJournal.RelatedJournal.JournalType.Name,
        TransactionJournal.JournalType.Name,
        TransactionJournal.JournalSubTypeId,
        TransactionJournal.JournalSubType.Name,
        TransactionJournal.AdditionalNotes__c,
        TransactionJournal.IsDeleted__c,
        LoyaltyPgmCrcySubtypeId,
        LoyaltyPgmCrcySubtype.Name,
        LoyaltyPgmCrcySubtype.PointTypeCode__c,
        TransactionJournal.OrderId,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.Order.ActualPaymentAmount__c,
        TransactionJournal.Order.IsDeleted__c,
        TransactionJournal.Promotion.PromotionNo__c
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
      ORDER BY ActivityDate DESC
    ];

    Set<Id> accrualOrderIds = new Set<Id>();
    Set<Id> accrualLedgerIds = new Set<Id>();
    List<LoyaltyLedger> creditLedgers = new List<LoyaltyLedger>();
    // [2026-04-24 R1-2/R2-2 Fix] 주문별 "원 포인트 사용량" 을 ledgers 루프에서 인라인 집계.
    //   - Point Debit LL 의 Points 합으로 Order 단위 사용량을 구성 (추가 SOQL 없음)
    //   - 이후 buildAccrualUsedPointMap / UserDestoryHistoryList 후처리에서
    //     취소 비율 계산의 분모로 사용됨
    // [2026-04-25 R1-9/R2-7/R2-8 Fix] DELETE /sale/deposit 경로 대응:
    //   - 활성 Debit (IsDeleted=FALSE) 만 `orderPointUsedMap` 분모에 포함
    //   - 삭제된 Debit (IsDeleted=TRUE) 은 `orderDeletedDebitMap` 에 별도 집계
    //     → 이미 Point Redeem Cancel 로 상쇄된 과거 사용분을 감산식에서 제외하기 위함
    // [2026-04-25 추가 Fix] Credit LL Id → 판매번호(SaleNo__c) 맵 (UserDestory NO_SAL_SAVE 덮어쓰기용)
    //   - Point Redeem Cancel Credit 을 참조한 Debit 로우의 NO_SAL_SAVE 를 원 Credit 의 판매번호로 교체
    Map<Id, Integer> orderPointUsedMap = new Map<Id, Integer>();
    Map<Id, String> saleNoByCreditLLId = new Map<Id, String>();
    Map<Id, Integer> orderDeletedDebitMap = new Map<Id, Integer>();
    // [Eco Restore Sum Fix 2026-05-03] 재적립 에코 LL 의 차감을 원본 에코 LL 의 PT_DESTROY 로 이전 합산하기 위한 매핑.
    //   배경: 통반품 → 취소 → 재통반품 시나리오에서 재적립 LL 은 응답에서 제외되지만 (Fix #7),
    //         그 LL 에 매달린 차감 LLT (FULL_RETURN_ECO_POINT_CANCEL) 는 회원의 실제 소멸을 의미하므로
    //         원본 LL 의 PT_DESTROY 에 합산되어야 정합성이 맞음.
    //   매핑 키: TransactionJournal.OrderId (재적립 시 OrderId = 원판매Id 로 박힘 — restoreEcoPointsFromReturn:5635).
    //   1차 패스: 원본 에코 LL (마커 없는 Credit) 의 OrderId → LL Id 매핑 구축.
    //   2차 패스: 재적립 에코 LL (마커=ECO_POINT_RESTORE_NOTE) → 원본 LL Id 매핑 구축.
    Map<Id, Id> ecoRestoreLLToOriginLLId = new Map<Id, Id>();
    Map<Id, Id> orderIdToEcoOriginLLId = new Map<Id, Id>();
    for (LoyaltyLedger ll : ledgers) {
      if (ll.EventType == 'Credit'
          && ll.Id != null
          && ll.TransactionJournal != null
          && ll.TransactionJournal.OrderId != null
          && ll.TransactionJournal.AdditionalNotes__c != ECO_POINT_RESTORE_NOTE
          && ll.LoyaltyPgmCrcySubtype != null
          && ll.LoyaltyPgmCrcySubtype.PointTypeCode__c == ECO_POINT_TYPE_CODE
          && !shouldExcludeFromAccrualHistory(ll)) {
        // 같은 OrderId 에 원본 에코 LL 이 여러 건이면 첫 번째만 매핑 (실무상 1건)
        if (!orderIdToEcoOriginLLId.containsKey(ll.TransactionJournal.OrderId)) {
          orderIdToEcoOriginLLId.put(ll.TransactionJournal.OrderId, ll.Id);
        }
      }
    }
    for (LoyaltyLedger ll : ledgers) {
      if (ll.EventType == 'Credit'
          && ll.Id != null
          && ll.TransactionJournal != null
          && ll.TransactionJournal.OrderId != null
          && ll.TransactionJournal.AdditionalNotes__c == ECO_POINT_RESTORE_NOTE
          && orderIdToEcoOriginLLId.containsKey(ll.TransactionJournal.OrderId)) {
        ecoRestoreLLToOriginLLId.put(ll.Id, orderIdToEcoOriginLLId.get(ll.TransactionJournal.OrderId));
      }
    }
    for (LoyaltyLedger ll : ledgers) {
      if (ll.EventType == 'Credit' && !shouldExcludeFromAccrualHistory(ll)) {
        creditLedgers.add(ll);
        if (ll.Id != null) {
          accrualLedgerIds.add(ll.Id);
        }
        if (ll.TransactionJournal != null && ll.TransactionJournal.OrderId != null) {
          accrualOrderIds.add(ll.TransactionJournal.OrderId);
        }
      }
      // [2026-04-25 추가 Fix] Credit LL Id → 판매번호 맵 (UserDestory NO_SAL_SAVE 덮어쓰기용, 추가 SOQL 없음)
      if (ll.EventType == 'Credit' && ll.Id != null
          && ll.TransactionJournal != null
          && ll.TransactionJournal.Order != null
          && String.isNotBlank(ll.TransactionJournal.Order.SaleNo__c)) {
        saleNoByCreditLLId.put(ll.Id, ll.TransactionJournal.Order.SaleNo__c);
      }
      // Point Debit LL → Order 단위 사용량 집계 (활성/삭제 분기)
      // [orderPointUsedMap Fix 2026-05-02] 재차감 보조 Debit LL 제외
      //   배경: 반품 입금 삭제 시 debitSpecificPoints 가 만든 재차감 보조 Debit LL 은 원본 사용을
      //         의미하지 않는 보조 흔적이라 분모에 포함되면 안 됨.
      //   증상: 분자 측 LLT SOQL (라인 411-412 / 1494-1495) 은 같은 마커를 이미 제외 중인데
      //         분모만 미제외라 비례 감산이 왜곡됨 (예: PT_USE 6666 = 10000 × (15000-5000)/15000).
      //   해결: 분자/분모 일관 처리로 정확한 비례 계산 회복 (동일 마커 정책 통일).
      if (ll.EventType == 'Debit'
          && ll.TransactionJournal != null
          && ll.TransactionJournal.OrderId != null
          && ll.TransactionJournal.JournalSubType != null
          && ll.TransactionJournal.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_POINT_DEBIT
          && ll.Points != null
          && ll.TransactionJournal.AdditionalNotes__c != RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE) {
        Id debitOrderId = ll.TransactionJournal.OrderId;
        Integer amt = ll.Points.abs().intValue();
        Boolean isDeleted = ll.TransactionJournal.IsDeleted__c == true;
        if (isDeleted) {
          // 삭제된 Debit → 해당 주문의 "이미 상쇄된 사용량" 으로 별도 집계
          Integer prevDel = orderDeletedDebitMap.containsKey(debitOrderId) ? orderDeletedDebitMap.get(debitOrderId) : 0;
          orderDeletedDebitMap.put(debitOrderId, prevDel + amt);
        } else {
          // 활성 Debit → 감산 계산 분모로 사용
          Integer prev = orderPointUsedMap.containsKey(debitOrderId) ? orderPointUsedMap.get(debitOrderId) : 0;
          orderPointUsedMap.put(debitOrderId, prev + amt);
        }
      }
    }

    // [2026-04-24 R1-1~R2-3 Fix] 회원의 Point Redeem Cancel TJ 집계 — SOQL 1회 (AccrualHistory+UserDestory 공용)
    // [2026-04-25 추가] 이미 삭제된 Debit 과 상쇄된 취소분 (orderDeletedDebitMap) 은 실효성 취소에서 제외해야 함.
    //   → effective cancel = max(0, redeemCancel - deletedDebit) 를 각 소비 지점에서 적용
    Map<Id, Integer> orderRedeemCancelMap = buildOrderRedeemCancelMap(memberId);

    // [2026-04-25 추가 Fix] Point Redeem Cancel Credit → 원 Credit 매핑 (DELETE /sale/deposit + PATCH 재등록 시나리오)
    //   - Cancel Credit 이 없으면 빈 맵 반환 (S1/S2 등 영향 없음)
    //   - 있는 경우에만 buildAccrualUsedPointMap 의 이월 단계 활성
    Map<Id, Id> redeemCancelCreditOriginMap = buildRedeemCancelCreditOriginMap(memberId, ledgers);

    Map<Id, Integer> accrualUsedPointMap = buildAccrualUsedPointMap(
        memberId, accrualLedgerIds, orderRedeemCancelMap, orderPointUsedMap, orderDeletedDebitMap, redeemCancelCreditOriginMap);
    Map<Id, Integer> accrualReductionPointMap = buildAccrualReductionPointMap(memberId, accrualLedgerIds);
    Map<Id, Integer> accrualExpiredPointMap = buildAccrualExpiredPointMap(
        memberId, creditLedgers, accrualReductionPointMap, ecoRestoreLLToOriginLLId);
    Map<Id, Integer> pointPaymentSummaryMap = buildPointPaymentSummaryMap(accrualOrderIds);
    Map<Id, Integer> couponPaymentSummaryMap = buildCouponPaymentSummaryMap(accrualOrderIds);

    // -------------------------------------------------------
    // Ledger → 적립 / 사용·소멸 분리
    // -------------------------------------------------------
    // [R1-1 Fix 2026-04-24] Point Redeem Cancel 로 생성된 재적립 Credit 은 AccrualHistoryList 에서 항상 숨김.
    //   - v3 Trace 보존 모델(Flag ON) 에서 원 Debit Trace 가 유지되므로 재적립 Credit 까지 표시하면
    //     회원 UI 에 "사용 취소 재적립" 로우가 중복 노출됨 (memberHelp 시나리오 R1-1 FAIL 원인).
    //   - 과거 PointCancel_PreserveTrace Flag 분기를 제거하고 MD 준수 동작으로 통일.
    // [Sort Fix 2026-04-28] AccrualHistoryList 정렬 적용 — 빌드 시 wrapper 함께 채우고 마지막에 sort.
    List<CreditSortable> creditSortables = new List<CreditSortable>();
    for (LoyaltyLedger ll : ledgers) {
      /**
       * 1. 적립 내역 (Credit)
       */
      Boolean isPointRedeemCancelCredit = (ll.TransactionJournal != null
          && ll.TransactionJournal.JournalSubType != null
          && ll.TransactionJournal.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL);
      if (ll.EventType == 'Credit'
          && !isPointRedeemCancelCredit
          && !shouldExcludeFromAccrualHistory(ll)) {
        Id orderId = ll.TransactionJournal != null ? ll.TransactionJournal.OrderId : null;
        Integer usedPoints = accrualUsedPointMap.containsKey(ll.Id) ? accrualUsedPointMap.get(ll.Id) : 0;
        Integer destroyedPoints = accrualExpiredPointMap.containsKey(ll.Id) ? accrualExpiredPointMap.get(ll.Id) : 0;
        Integer usedSalePoints = (orderId != null && pointPaymentSummaryMap.containsKey(orderId)) ? pointPaymentSummaryMap.get(orderId) : 0;
        Integer usedSaleCouponAmount = (orderId != null && couponPaymentSummaryMap.containsKey(orderId)) ? couponPaymentSummaryMap.get(orderId) : 0;
        PointResDto.CreditPointResponse response = new PointResDto.CreditPointResponse(
          ll,
          usedPoints,
          destroyedPoints,
          usedSalePoints,
          usedSaleCouponAmount
        );

        // accrualHistoryList.add(row);
        creditPointResponseList.add(response);
        creditSortables.add(new CreditSortable(response, ll));
      }
      /**
       * 사용 / 소멸 내역 (Debit / Expiry)
       */
      // else if (ll.EventType == 'Debit' || ll.EventType == 'Expiry') {
      // usageExpiryHistoryList.add(row);
      // }
    }
    // [Sort Fix 2026-04-28] 정렬 키 (DT_CREATE / CD_TYPE_POINT / NO_SEQ_CREATE) 오름차순 적용
    creditSortables.sort();
    creditPointResponseList.clear();
    for (CreditSortable s : creditSortables) {
      creditPointResponseList.add(s.response);
    }
    /**
     * 포인트 적립 내역
     */
    data.put('AccrualHistoryList', creditPointResponseList);

    // =======================================================
    // 소멸 예정 / 잔여 포인트 요약 (집계)
    // =======================================================
    // List<LoyaltyAggrSubPointExprLedger__c> expirySummary = [
    //   SELECT CurrencySubTypeName__c, AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c, ExpiryDate__c
    //   FROM LoyaltyAggrSubPointExprLedger__c
    //   WHERE LoyaltyProgramMemberId__c = :memberId
    // ];

    List<LoyaltyLedgerTraceability> lltList = [
      SELECT
        Id,
        OwnerId,
        IsDeleted,
        Name,
        CreatedDate,
        CreatedById,
        LastModifiedDate,
        LastModifiedById,
        SystemModstamp,
        LastViewedDate,
        LastReferencedDate,
        CreditLoyaltyLedgerId,
        DebitLoyaltyLedgerId,
        ActionType,
        Points,
        LoyaltyProgramCurrencyId,
        LoyaltyPgmCurrencySubtypeId,
        LoyaltyProgramMemberId,
        LoyaltyPgmCurrencySubtype.Name,
        DebitLoyaltyLedger.ActivityDate,
        DebitLoyaltyLedger.TransactionJournal.OrderId,
        DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.IsReductionOrder__c,
        DebitLoyaltyLedger.EventType,
        // 26.04.02 WT 수정
        // 88. 반품포인트의 경우에는 판매번호 란 빈값이어야함(원 판매건에서 취소가 되는거니까 오히려 적립 판매번호에 해당 판매번호가 찍여햐함)
        DebitLoyaltyLedger.TransactionJournal.SaleId__c,
        DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c,
        CreditLoyaltyLedger.Points,
        CreditLoyaltyLedger.ActivityDate,
        CreditLoyaltyLedger.TransactionJournal.Order.IsReductionOrder__c,
        CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c,
        DebitLoyaltyLedger.Points,
        DebitLoyaltyLedger.TransactionJournal.RelatedJournal.IsDeleted__c,
        DebitLoyaltyLedger.TransactionJournal.JournalDate
      FROM LoyaltyLedgerTraceability
      // WHERE DebitLoyaltyLedger.EventType = 'Debit' AND LoyaltyProgramMemberId = :memberId  // 기존 로직
      // 신규 로직 Start (Carson 26.04.07)
      // [2026-04-25 R2-7/R2-8 Fix] Debit 분기에 "원 Debit TJ IsDeleted=FALSE" 조건 추가.
      //   - DELETE /sale/deposit 경로에서 IsDeleted=TRUE 로 마킹된 Debit TJ 의 LLT 는
      //     이미 과거 이벤트로 상쇄된 것이므로 UserDestoryHistoryList 에 노출되면 안 됨.
      // [scn5 R2-8 Fix 2026-04-27] Debit 분기에 "AdditionalNotes != 반품 입금 삭제 재차감" 조건 추가.
      //   - 반품 입금 DELETE 시 debitSpecificPoints 가 만든 재차감 Debit LLT 는
      //     v3 paradigm 으로 보존된 원본 Debit trace 와 의미가 중복되어 UserDestoryHistoryList 에 추가 row 가
      //     발생함. 같은 마커 필터가 GdSaleDepositServiceImpl 에서 이미 사용 중이며 GdMemberHelpInfoServiceImpl 에는
      //     부재했음. (시나리오 5 회귀 검증 결과 9 row → 6 row 로 정정 기대)
      // [scn6 R2-9 Fix 2026-04-27] Debit 분기에 "AdditionalNotes != FULL_RETURN_ECO_POINT_CANCEL" 조건 추가.
      //   - 통반품 / 전체판매 DELETE 시 cancelEcoPointsForFullReturn 경로가 만든 Api Forced Debit TJ 의
      //     Debit LLT 가 UserDestoryHistoryList 에 NM_PERSON='사용' 로 노출되는 문제.
      //   - 이 LLT 는 사용 흔적이 아니라 에코포인트 소멸 흔적이므로 도움창에 표시되면 안 됨.
      //   - 같은 LLT 의 CreditCancellation 측은 "포인트 지급 취소" 로 별도 처리되므로 정상 표시됨.
      //   (시나리오 6 회귀 검증 결과 1 row 잔존 → 0 row 로 정정 기대)
      // [Eco Cancel after Return Delete Fix 2026-05-03] 삭제된 반품 Order 의 차감 LLT 제외
      //   배경: 통반품 → 취소 (반품 삭제) 시 1차 차감 LLT 가 살아있어 "포인트 지급 취소" 로
      //         UserDestoryHistoryList 에 잘못 노출되는 문제.
      //   해결: SaleId 가 가리키는 반품 Order 가 IsDeleted=TRUE 이면 = "반품이 삭제됨" 신호이므로
      //         그 LLT 는 응답에서 제외. SaleId__c = NULL 케이스는 OR 분기로 그대로 통과.
      //         (buildAccrualExpiredPointMap 의 동일 fix 와 일관)
      WHERE
        ((ActionType = 'Debit'
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :ADDITIONAL_NOTE_FULL_RETURN_ECO_POINT_CANCEL))
        OR ((ActionType = 'DebitCancellation'
        OR ActionType = 'CreditCancellation')
        AND (DebitLoyaltyLedger.TransactionJournal.RelatedJournalId = NULL
        OR DebitLoyaltyLedger.TransactionJournal.RelatedJournal.IsDeleted__c != TRUE)))
        AND (DebitLoyaltyLedger.TransactionJournal.SaleId__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = FALSE)
        AND LoyaltyProgramMemberId = :memberId
      ORDER BY CreatedDate DESC
      LIMIT 20000
    ];
    // [Sort Fix 2026-04-28] UserDestoryHistoryList 정렬 — response 별 representative LLT 정렬 키 보존용
    List<DebitSortable> debitSortablesAll = new List<DebitSortable>();
    if (!lltList.isEmpty()) {
      for (LoyaltyLedgerTraceability llt : lltList) {
        PointResDto.DebitPointResponse response = new PointResDto.DebitPointResponse(llt);
        if ((llt.ActionType == 'DebitCancellation' || llt.ActionType == 'CreditCancellation') && llt.Points != null) {
          response.PT_USE = Integer.valueOf(llt.Points.abs());
        }
        if (llt.ActionType == 'DebitCancellation') {
          response.NO_SAL = (llt.DebitLoyaltyLedger != null &&
            llt.DebitLoyaltyLedger.TransactionJournal != null &&
            llt.DebitLoyaltyLedger.TransactionJournal.Order != null &&
            String.isNotBlank(llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c))
            ? llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c
            : response.NO_SAL;
          response.NO_SAL_SAVE = (llt.CreditLoyaltyLedger != null &&
            llt.CreditLoyaltyLedger.TransactionJournal != null &&
            llt.CreditLoyaltyLedger.TransactionJournal.Order != null &&
            String.isNotBlank(llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c))
            ? llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c
            : response.NO_SAL_SAVE;
          response.NO_SAL_RTN = (llt.DebitLoyaltyLedger != null &&
            llt.DebitLoyaltyLedger.TransactionJournal != null &&
            llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r != null &&
            String.isNotBlank(llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c))
            ? llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c
            : response.NO_SAL_RTN;
        }

        // [R2-1/R2-2/R2-3 Fix 2026-04-24 / R2-7/R2-8 Fix 2026-04-25] "사용(Debit)" 로우에 주문 단위 취소 반영
        //   - Point Redeem Cancel TJ 의 OrderId == 이 Debit 의 원 주문 Id 인 경우,
        //     해당 주문에서 취소된 포인트 총액을 기준으로 "전액/부분" 판정.
        //   - effectiveCancel = max(0, orderRedeemCancelMap - orderDeletedDebitMap)
        //     (DELETE /sale/deposit 경로에서 이미 삭제 Debit 과 상쇄된 Cancel 분 제외)
        //   - 전액 취소 (effectiveCancel >= orderUsed) → 이 로우 스킵 (R2-1/R2-3 해결)
        //   - 부분 취소 → PT_USE 를 비례 감산 (R2-2 해결)
        //   - DebitCancellation/CreditCancellation 로우는 대상이 아님 (이미 위에서 PT_USE 재설정됨).
        if (llt.ActionType == 'Debit'
            && llt.DebitLoyaltyLedger != null
            && llt.DebitLoyaltyLedger.TransactionJournal != null
            && llt.DebitLoyaltyLedger.TransactionJournal.OrderId != null) {
          // [정책 변경 2026-05-03] 사용 행 비례 감산/행 제거 로직 제거
          //   배경: 기존 R2-2/R2-3 정책 ("사용 행을 net 으로 표시") 이 회원/운영자 입장에서
          //         "이 판매에서 얼마 썼고 얼마 환불받았는지" 흐름을 추적 불가능하게 만듦.
          //   새 정책: 사용 행은 원본 PT_USE 유지 + 별도 "포인트 사용 취소" 행으로 환불 표시.
          //         별도 합성 행 추가는 lltList 루프 다음의 "포인트 사용 취소 합성 로직" 에서 처리.

          // [2026-04-25 추가 Fix] Point Redeem Cancel Credit 참조 Debit 로우의 NO_SAL_SAVE 덮어쓰기 (유지)
          //   - Cancel Credit 을 사용하면 기본값은 Cancel 주문의 판매번호 (자기참조 형태)
          //   - 이를 "원 Credit (같은 주문의 원 적립)" 의 판매번호로 교체해
          //     이어지는 병합에서 원 Credit 기준 단일 로우로 통합되도록 함
          // [NO_SAL_SAVE 보정 Fix 2026-05-03] 수동 적립/마이그레이션 적립 케이스 보정
          //   배경: 원 Credit 이 수동 적립 (TJ.OrderId=null) 또는 마이그레이션 적립인 경우,
          //         saleNoByCreditLLId 에 해당 LL 이 등록되지 않아 (원 Credit.TJ.Order.SaleNo 빈 값) 보정 분기 진입 못 함.
          //         그 결과 Cancel Credit 의 자기참조 (Cancel TJ.Order = 사용 취소된 판매) 가 그대로 노출됨.
          //   증상: 수동 적립 → A 판매 사용 → 사용 취소 → B 판매 사용 시
          //         B 판매 사용 행의 NO_SAL_SAVE 에 A 판매번호가 잘못 노출.
          //   해결: 매핑 자체가 있으면 (= Cancel Credit → 원 Credit 매핑 성립)
          //         원 Credit 의 판매번호 존재 여부와 무관하게 무조건 덮어쓰기 (없으면 빈 값으로).
          //   영향 분석: 케이스 A (판매 자동 적립) - 결과 동일, 케이스 C/E (수동/마이그레이션) - 정정.
          //              시나리오 1~7 의 R 회귀 모두 영향 없음 (사전 검증 완료).
          if (llt.CreditLoyaltyLedgerId != null
              && redeemCancelCreditOriginMap.containsKey(llt.CreditLoyaltyLedgerId)) {
            Id originCid = redeemCancelCreditOriginMap.get(llt.CreditLoyaltyLedgerId);
            if (originCid != null) {
              String originSaleNo = saleNoByCreditLLId.containsKey(originCid)
                  ? saleNoByCreditLLId.get(originCid)
                  : '';
              // 원 Credit 의 판매번호가 빈 값이어도 무조건 덮어쓰기 (자기참조 방지)
              response.NO_SAL_SAVE = String.isNotBlank(originSaleNo) ? originSaleNo : '';
            }
          }
        }

        debitPointResponseList.add(response);
        debitSortablesAll.add(new DebitSortable(response, llt));
      }
    }

    // [정책 변경 2026-05-03] "포인트 사용 취소" 행 합성
    //   목적: 활성 Point Redeem Cancel TJ 1건당 응답 행 1건씩 추가.
    //   매핑:
    //     - NM_PERSON = "포인트 사용 취소"
    //     - PT_USE = Cancel LL 의 Points
    //     - NM_TYPE_POINT = LoyaltyPgmCrcySubtype.Name
    //     - NO_SAL_SAVE = 원판매번호 (Cancel TJ.Order.SaleNo__c, 없으면 OrderNo__c)
    //     - NO_SAL_RTN = 반품번호 (Cancel TJ.SaleId__r.SaleNo__c, 자기참조 또는 NULL 시 빈 값)
    //     - NO_SAL_ORD = 주문번호 (Cancel TJ.Order.OrderNo__c)
    //   필터:
    //     - Cancel TJ.IsDeleted = FALSE (반품 입금 삭제 시 자동 제외)
    //     - SaleId__r.IsDeleted__c = FALSE (반품 자체 삭제 시 자동 제외)
    List<LoyaltyLedger> redeemCancelLLList = [
      SELECT Id, Points, ActivityDate,
             LoyaltyPgmCrcySubtype.Name,
             TransactionJournal.OrderId,
             TransactionJournal.Order.SaleNo__c,
             TransactionJournal.Order.OrderNo__c,
             TransactionJournal.Order.ActualPaymentAmount__c,
             TransactionJournal.SaleId__c,
             TransactionJournal.SaleId__r.SaleNo__c,
             TransactionJournal.SaleId__r.IsDeleted__c,
             TransactionJournal.JournalDate
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.OrderId != NULL
        AND (TransactionJournal.SaleId__c = NULL
             OR TransactionJournal.SaleId__r.IsDeleted__c = FALSE)
      ORDER BY CreatedDate
      LIMIT 5000
    ];

    for (LoyaltyLedger cancelLL : redeemCancelLLList) {
      PointResDto.DebitPointResponse cancelRow = new PointResDto.DebitPointResponse();
      cancelRow.NM_PERSON = '포인트 사용 취소';
      cancelRow.PT_USE = cancelLL.Points == null ? 0 : Integer.valueOf(cancelLL.Points.abs());
      cancelRow.NM_TYPE_POINT = (cancelLL.LoyaltyPgmCrcySubtype != null && cancelLL.LoyaltyPgmCrcySubtype.Name != null)
          ? cancelLL.LoyaltyPgmCrcySubtype.Name : '';

      // 원판매/원주문 식별
      String origSaleNo = (cancelLL.TransactionJournal != null && cancelLL.TransactionJournal.Order != null
          && String.isNotBlank(cancelLL.TransactionJournal.Order.SaleNo__c))
          ? cancelLL.TransactionJournal.Order.SaleNo__c : '';
      String origOrderNo = (cancelLL.TransactionJournal != null && cancelLL.TransactionJournal.Order != null
          && String.isNotBlank(cancelLL.TransactionJournal.Order.OrderNo__c))
          ? cancelLL.TransactionJournal.Order.OrderNo__c : '';

      cancelRow.NO_SAL_SAVE = String.isNotBlank(origSaleNo) ? origSaleNo : origOrderNo;
      cancelRow.NO_SAL_ORD = origOrderNo;
      cancelRow.NO_SAL = '';

      // 반품번호 매핑 (반품이 아닌 자기참조/NULL 케이스는 빈 값)
      String returnSaleNo = '';
      if (cancelLL.TransactionJournal != null
          && cancelLL.TransactionJournal.SaleId__c != null
          && cancelLL.TransactionJournal.SaleId__c != cancelLL.TransactionJournal.OrderId
          && cancelLL.TransactionJournal.SaleId__r != null
          && String.isNotBlank(cancelLL.TransactionJournal.SaleId__r.SaleNo__c)) {
        returnSaleNo = cancelLL.TransactionJournal.SaleId__r.SaleNo__c;
      }
      cancelRow.NO_SAL_RTN = returnSaleNo;

      // 날짜 매핑
      cancelRow.YM_CREATE = (cancelLL.ActivityDate != null) ? cancelLL.ActivityDate.format('yyyyMM') : '';
      cancelRow.DT_USE = (cancelLL.TransactionJournal != null && cancelLL.TransactionJournal.JournalDate != null)
          ? cancelLL.TransactionJournal.JournalDate.format('yyyyMMdd') : '';
      cancelRow.DT_SAVE = (cancelLL.ActivityDate != null) ? cancelLL.ActivityDate.format('yyyyMMdd') : '';

      // 판매 금액
      Decimal amSal = (cancelLL.TransactionJournal != null && cancelLL.TransactionJournal.Order != null
          && cancelLL.TransactionJournal.Order.ActualPaymentAmount__c != null)
          ? cancelLL.TransactionJournal.Order.ActualPaymentAmount__c : 0;
      cancelRow.AM_SAL = Integer.valueOf(amSal);

      debitPointResponseList.add(cancelRow);
      debitSortablesAll.add(new DebitSortable(cancelRow, null));
    }

    // [2026-04-25 추가 Fix] UserDestoryHistoryList "사용(Debit)" 로우 병합
    //   - 같은 (NO_SAL + NM_TYPE_POINT + NO_SAL_SAVE) 키의 로우들을 PT_USE 합산해 단일 로우로 통합
    //   - 예: FIFO 로 여러 Credit 에 분할 차감되어 생성된 다수 LLT → 의미 단위 1건으로 표시
    //   - "사용" 로우 아닌 것 (포인트 지급 취소 등) 은 그대로 유지
    // [Sort Fix 2026-04-28] merge 시 representative DebitSortable 도 함께 유지하여 마지막 정렬 단계에서 사용
    List<DebitSortable> debitSortablesMerged = new List<DebitSortable>();
    if (!debitPointResponseList.isEmpty()) {
      Map<String, PointResDto.DebitPointResponse> usageMergedByKey = new Map<String, PointResDto.DebitPointResponse>();
      List<PointResDto.DebitPointResponse> mergedList = new List<PointResDto.DebitPointResponse>();
      for (Integer i = 0; i < debitPointResponseList.size(); i++) {
        PointResDto.DebitPointResponse r = debitPointResponseList[i];
        DebitSortable sk = (i < debitSortablesAll.size()) ? debitSortablesAll[i] : new DebitSortable(r, null);
        Boolean isUsageRow = ('사용'.equals(r.NM_PERSON)) && String.isNotBlank(r.NO_SAL);
        if (!isUsageRow) {
          mergedList.add(r);
          debitSortablesMerged.add(sk);
          continue;
        }
        String key = String.valueOf(r.NO_SAL) + '|'
            + (r.NM_TYPE_POINT == null ? '' : r.NM_TYPE_POINT) + '|'
            + (r.NO_SAL_SAVE == null ? '' : r.NO_SAL_SAVE);
        if (usageMergedByKey.containsKey(key)) {
          PointResDto.DebitPointResponse existing = usageMergedByKey.get(key);
          Integer prev = existing.PT_USE == null ? 0 : existing.PT_USE;
          Integer curr = r.PT_USE == null ? 0 : r.PT_USE;
          existing.PT_USE = prev + curr;
        } else {
          usageMergedByKey.put(key, r);
          mergedList.add(r);
          debitSortablesMerged.add(sk);
        }
      }
      debitPointResponseList = mergedList;
    }

    // [Sort Fix 2026-04-28] UserDestoryHistoryList 정렬 키 (YM_CREATE / DTS_INSERT / NO_SEQ_CREATE) 오름차순 적용
    if (!debitSortablesMerged.isEmpty()) {
      debitSortablesMerged.sort();
      debitPointResponseList = new List<PointResDto.DebitPointResponse>();
      for (DebitSortable s : debitSortablesMerged) {
        debitPointResponseList.add(s.response);
      }
    }

    /**
     * 포인트 사용/소멸 내역
     */
    data.put('UserDestoryHistoryList', debitPointResponseList);

    // =======================================================
    // 응답 데이터 세팅
    // =======================================================

    // data.put('AccrualHistoryList', accrualHistoryList);
    // data.put('UsageExpiryHistoryList', usageExpiryHistoryList);
    // data.put('ExpirySummary', expirySummary);

    // -------------------------------------------------------
    // CS내역 조회 (TransactionJournal)
    // -------------------------------------------------------
    List<TransactionJournal> cslist = [
      SELECT
        id,
        toLabel(CS_CHANNEL1__c),
        toLabel(CS_CHANNEL2__c),
        CS_CHANNEL1_F_CODE__c,
        CS_CHANNEL2_F_CODE__c,
        CS_Sentdate__c,
        CS_CAMP_NAME__c,
        CS_Content__c
      FROM TransactionJournal
      WHERE MemberId = :lpm.id AND UsageType__c = 'Campaign'
    ];

    List<CsResDto> csResDtoList = new List<CsResDto>();
    if (!cslist.isEmpty()) {
      for (TransactionJournal tj : cslist) {
        CsResDto csResDto = new CsResDto();
        csResDto.sentDate = String.valueOf(tj.CS_Sentdate__c).replaceAll('-', '');
        csResDto.detailContent = tj.CS_CAMP_NAME__c;

        String c1 = String.valueOf(tj.CS_CHANNEL1_F_CODE__c);
        String c2 = String.valueOf(tj.CS_CHANNEL2_F_CODE__c);

        // 1순위 발송 채널 성공
        if (c1 == '0' || c1 == '00') {
          csResDto.type = tj.CS_CHANNEL1__c;
        }
        // 2순위 발송 채널 성공
        else if (c2 == '0' || c2 == '00') {
          csResDto.type = tj.CS_CHANNEL2__c;
        }
        // 모두 실패
        else {
          //   // csResDto.type = '';
          csResDto.type = tj.CS_CHANNEL1__c;
        }

        //     csResDto.type = ''; // CS 구분
        // csResDto.content = tj.CS_Content__c; // CS 내역

        csResDtoList.add(csResDto);
      }
    }

    data.put('CsList', csResDtoList);

    return ApiResult.ok(200, '회원도움정보 조회 성공', data);
  }

  // [Sort Fix 2026-04-28] 회원정보 도움창 응답 정렬용 wrapper
  //   AccrualHistoryList 정렬 키: 1) ll.ActivityDate (DT_CREATE) 2) PointTypeCode__c (CD_TYPE_POINT) 3) ll.Id (NO_SEQ_CREATE)
  //   - 모두 오름차순. 응답 스펙은 변경하지 않고 LL/LLT 의 raw 키로 정렬만 적용.
  private class CreditSortable implements Comparable {
    public PointResDto.CreditPointResponse response;
    public Datetime activityDate;
    public String pointTypeCode;
    public String idStr;

    public CreditSortable(PointResDto.CreditPointResponse r, LoyaltyLedger ll) {
      this.response = r;
      this.activityDate = (ll != null) ? ll.ActivityDate : null;
      this.pointTypeCode = (ll != null && ll.LoyaltyPgmCrcySubtype != null) ? ll.LoyaltyPgmCrcySubtype.PointTypeCode__c : null;
      this.idStr = (ll != null && ll.Id != null) ? String.valueOf(ll.Id) : '';
    }

    public Integer compareTo(Object other) {
      CreditSortable o = (CreditSortable) other;
      // 1. ActivityDate 오름차순
      Long mine = (activityDate == null) ? 0 : activityDate.getTime();
      Long theirs = (o.activityDate == null) ? 0 : o.activityDate.getTime();
      if (mine != theirs) {
        return mine < theirs ? -1 : 1;
      }
      // 2. PointTypeCode 오름차순
      String pa = (pointTypeCode == null) ? '' : pointTypeCode;
      String pb = (o.pointTypeCode == null) ? '' : o.pointTypeCode;
      Integer cmp = pa.compareTo(pb);
      if (cmp != 0) {
        return cmp;
      }
      // 3. Id 오름차순
      return idStr.compareTo(o.idStr);
    }
  }

  // [Sort Fix 2026-04-28] UserDestoryHistoryList 정렬용 wrapper
  //   정렬 키: 1) yyyyMM (YM_CREATE) 2) llt.CreatedDate (DTS_INSERT) 3) llt.Id (NO_SEQ_CREATE)
  //   - 모두 오름차순.
  private class DebitSortable implements Comparable {
    public PointResDto.DebitPointResponse response;
    public String yearMonth;
    public Datetime createdDate;
    public String idStr;

    public DebitSortable(PointResDto.DebitPointResponse r, LoyaltyLedgerTraceability llt) {
      this.response = r;
      this.yearMonth = (llt != null && llt.CreatedDate != null) ? llt.CreatedDate.format('yyyyMM') : '';
      this.createdDate = (llt != null) ? llt.CreatedDate : null;
      this.idStr = (llt != null && llt.Id != null) ? String.valueOf(llt.Id) : '';
    }

    public Integer compareTo(Object other) {
      DebitSortable o = (DebitSortable) other;
      // 1. YM_CREATE 오름차순
      Integer cmp = yearMonth.compareTo(o.yearMonth);
      if (cmp != 0) {
        return cmp;
      }
      // 2. CreatedDate 오름차순
      Long mine = (createdDate == null) ? 0 : createdDate.getTime();
      Long theirs = (o.createdDate == null) ? 0 : o.createdDate.getTime();
      if (mine != theirs) {
        return mine < theirs ? -1 : 1;
      }
      // 3. Id 오름차순
      return idStr.compareTo(o.idStr);
    }
  }
}