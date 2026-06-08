public without sharing class LoyaltyPointEventValidator {
  private static final String PAYMENT_METHOD_POINT = '81';
  private static final String DEPOSIT_TYPE_RETURN = '03';
  private static final String ACTION_CREDIT_CANCELLATION = 'CreditCancellation';
  private static final String JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String JOURNAL_SUB_TYPE_API_FORCED_CREDIT = 'Api Forced Credit';
  private static final String JOURNAL_SUB_TYPE_POINT_DEBIT = 'Point Debit';
  private static final String JOURNAL_SUB_TYPE_PURCHASE_ACCRUAL = 'Purchase Accrual';
  private static final String ACTION_DEBIT = 'Debit';
  private static final String ORIGIN_CREDIT_LL_TOKEN = 'ORIGIN_CREDIT_LL=';
  private static final String OPTC_RESTORE_MARKER = 'OPTC_OLD_SALE_USAGE_RESTORE';
  private static final String OPTC_RETURN_DELETE_MARKER = 'OPTC_RETURN_DELETE_RESTORE';
  private static final String OPTC_RETURN_DEPOSIT_DELETE_MARKER = 'OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT';
  private static final String OPTC_SALE_PATCH_MARKER = 'OPTC_SALE_PATCH_FORCE_CREDIT';
  private static final Set<String> ACCRUAL_EXCLUDED_PAYMENT_METHODS = new Set<String>{ '20', '81', '90', '93' };
  private static final String UNKNOWN_POINT_TYPE = 'UNKNOWN';

  public class ValidationResult {
    public Boolean isValid;
    public String eventType;
    public Id memberId;
    public String memberNo;
    public String memberName;
    public Id orderId;
    public Id originalOrderId;
    public String saleNo;
    public String originalSaleNo;
    public Decimal expectedCreditCancelPoints = 0;
    public Decimal actualCreditCancelPoints = 0;
    public Decimal expectedRedeemCancelPoints = 0;
    public Decimal actualRedeemCancelPoints = 0;
    public Decimal creditCancelDifference = 0;
    public Decimal redeemCancelDifference = 0;
    public Map<String, Decimal> expectedCreditCancelByType = new Map<String, Decimal>();
    public Map<String, Decimal> actualCreditCancelByType = new Map<String, Decimal>();
    public Map<String, Decimal> expectedRedeemCancelByType = new Map<String, Decimal>();
    public Map<String, Decimal> actualRedeemCancelByType = new Map<String, Decimal>();
    public Integer mismatchCount = 0;
    public List<String> mismatchDetails = new List<String>();
    // 보강 #5 — SALE_CREATE 전용 필드 (§ 4)
    public Decimal expectedDepositTotal = 0;
    public Decimal actualDepositTotal = 0;
    public Decimal pointUsageLimit = 0;
    public Decimal actualPointUsage = 0;
    public Decimal actualPointDebitLLT = 0;
    public Decimal expectedPurchaseAccrual = 0;
    public Decimal actualPurchaseAccrual = 0;
    public Decimal expectedPromotionAccrual = 0;
    public Decimal actualPromotionAccrual = 0;
    // [Fix 결함 ①~⑥ 2026-06-08] 옛 판매 OPTC paradigm 검증 결과
    //   true 면 OPTC force-debit paradigm 으로 검증 (Purchase Accrual LL 회수 paradigm 이 아니라
    //   ActualPaymentAmount 기반 추정 + OPTC ACCRUAL_CANCEL 마커 TJ 합 비교)
    public Boolean isOldSale = false;
    public String summary;
  }

  public static ValidationResult validateSaleDelete(String saleNo) {
    return validateSaleDelete(findOrderBySaleNo(saleNo));
  }

  public static ValidationResult validateSaleDelete(Id orderId) {
    return validateSaleDelete(findOrderById(orderId));
  }

  public static ValidationResult validateReturnCreate(String returnSaleNo) {
    return validateReturnCreate(findOrderBySaleNo(returnSaleNo));
  }

  public static ValidationResult validateReturnCreate(Id returnOrderId) {
    return validateReturnCreate(findOrderById(returnOrderId));
  }

  public static ValidationResult validateSaleDepositDelete(String depositNo) {
    return validateDepositDelete('SALE_DEPOSIT_DELETE', findDeletedDeposit(depositNo, null));
  }

  // 보강 #4 — DeposiSeqNo 분리 식별 (§ 8 line 432-434)
  public static ValidationResult validateSaleDepositDelete(String depositNo, String seqNo) {
    return validateDepositDelete('SALE_DEPOSIT_DELETE', findDeletedDeposit(depositNo, seqNo));
  }

  // TJ Id 직접 지정 — 가장 정확한 식별
  public static ValidationResult validateSaleDepositDeleteByTjId(Id tjId) {
    return validateDepositDelete('SALE_DEPOSIT_DELETE', findDeletedDepositById(tjId));
  }

  public static ValidationResult validateReturnDepositDelete(String depositNo) {
    return validateDepositDelete('RETURN_DEPOSIT_DELETE', findDeletedDeposit(depositNo, null));
  }

  // 보강 #4 — DeposiSeqNo 분리 식별 (§ 8 line 452-453)
  public static ValidationResult validateReturnDepositDelete(String depositNo, String seqNo) {
    return validateDepositDelete('RETURN_DEPOSIT_DELETE', findDeletedDeposit(depositNo, seqNo));
  }

  public static ValidationResult validateReturnDepositDeleteByTjId(Id tjId) {
    return validateDepositDelete('RETURN_DEPOSIT_DELETE', findDeletedDepositById(tjId));
  }

  public static Boolean validateAndAlertSaleDelete(String saleNo) {
    return alertIfInvalid(validateSaleDelete(saleNo));
  }

  public static Boolean validateAndAlertReturnCreate(String returnSaleNo) {
    return alertIfInvalid(validateReturnCreate(returnSaleNo));
  }

  public static Boolean validateAndAlertSaleDepositDelete(String depositNo) {
    return alertIfInvalid(validateSaleDepositDelete(depositNo));
  }

  public static Boolean validateAndAlertSaleDepositDelete(String depositNo, String seqNo) {
    return alertIfInvalid(validateSaleDepositDelete(depositNo, seqNo));
  }

  public static Boolean validateAndAlertReturnDepositDelete(String depositNo) {
    return alertIfInvalid(validateReturnDepositDelete(depositNo));
  }

  public static Boolean validateAndAlertReturnDepositDelete(String depositNo, String seqNo) {
    return alertIfInvalid(validateReturnDepositDelete(depositNo, seqNo));
  }

  public static Boolean validateAndAlertSaleDepositDeleteByTjId(Id tjId) {
    return alertIfInvalid(validateSaleDepositDeleteByTjId(tjId));
  }

  public static Boolean validateAndAlertReturnDepositDeleteByTjId(Id tjId) {
    return alertIfInvalid(validateReturnDepositDeleteByTjId(tjId));
  }

  // ============================================================
  // 보강 #5 — 판매 등록 검증 (§ 4 전체)
  //   5개 절을 통합 검증:
  //     § 4.1 입금 합계: Order.ActualPaymentAmount__c ↔ 활성 TJ.TransactionAmount 합
  //     § 4.2 사용 한도: (적립가능 OI 금액 + 수리 OI 금액) ≥ PM=81 입금 합계
  //     § 4.3 사용 정합: PM=81 입금 합계 = Debit LLT.Points 합
  //     § 4.4 구매 적립: (적립대상 × 등급률 / 100, HALF_UP) = Purchase Accrual LL 합 (subtype별)
  //     § 4.5 프로모션 적립: PromotionPointLimit 기준 기대값 = Promotion Point Accrual LL 합
  //
  //   주의:
  //     - PromotionPointLimit.Type__c='none' (이벤트 포인트) 는 검증 스킵 (고정값 정책 다양)
  //     - 등급 적립 시 프로모션 subtype 은 일반 적립에서 제외 (excludedSubtype 반영)
  // ============================================================
  public static ValidationResult validateSaleCreate(String saleNo) {
    return validateSaleCreate(findOrderBySaleNo(saleNo));
  }

  public static ValidationResult validateSaleCreate(Id orderId) {
    return validateSaleCreate(findOrderById(orderId));
  }

  public static Boolean validateAndAlertSaleCreate(String saleNo) {
    return alertIfInvalid(validateSaleCreate(saleNo));
  }

  public static Boolean validateAndAlertSaleCreate(Id orderId) {
    return alertIfInvalid(validateSaleCreate(orderId));
  }

  // ============================================================
  // 보강 #1 — 반품 삭제 검증 (§ 7)
  //   기대: 반품 등록 시 생성된 모든 취소/재적립 효과가 회수되어 활성 합계 = 0
  //   실제: 현재 활성 (TJ.IsDeleted__c=FALSE) CreditCancellation 및 Point Redeem Cancel 합계
  //   불일치 시 = 반품 삭제가 완전히 회수되지 않음
  // ============================================================
  public static ValidationResult validateReturnDelete(String returnSaleNo) {
    return validateReturnDelete(findOrderBySaleNo(returnSaleNo));
  }

  public static ValidationResult validateReturnDelete(Id returnOrderId) {
    return validateReturnDelete(findOrderById(returnOrderId));
  }

  public static Boolean validateAndAlertReturnDelete(String returnSaleNo) {
    return alertIfInvalid(validateReturnDelete(returnSaleNo));
  }

  // ============================================================
  // 보강 #2 — 옵션 C lump 매칭 정합성 검증 (§ 11 원칙 5, 결함 ⑨)
  //   force-credit Credit LL 의 ExpiryDate (Actual) vs.
  //   원 Debit 의 LLT 가 가리키는 Credit lump 의 ExpiryDate Set (Origin)
  //   불일치 시 = 결함 ⑨ 패턴 (환원이 잘못된 lump 으로 감)
  //
  //   대상 마커 (3종 — origin 추출 방식별):
  //     - OPTC_OLD_SALE_USAGE_RESTORE              (pm81TjId=<TJ Id> 직접)
  //     - OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT  (tjId=<TJ Id> 직접)
  //     - OPTC_RETURN_DELETE_RESTORE               (origSaleNo=<SaleNo> → Point Debit TJ Id 들로 해소)
  //   대상 외:
  //     - OPTC_SALE_PATCH_FORCE_CREDIT             (saleNo=..., addition 케이스 — lump 매칭 N/A)
  //
  //   다중 lump 매칭 지원: 한 origin TJ 가 여러 Credit lump 에 차감된 경우
  //   actualExpiry 가 그 Set 중 하나에 포함되면 정합.
  // ============================================================
  public static ValidationResult validateOptionCLumpMatching(Id memberId) {
    if (memberId == null) {
      return invalidMissing('OPTC_LUMP_MATCHING', '회원 ID가 필요합니다.');
    }

    ValidationResult result = new ValidationResult();
    result.eventType = 'OPTC_LUMP_MATCHING';
    result.memberId = memberId;
    populateMemberById(result, memberId);

    // 3종 마커 모두 스캔 (OPTC_SALE_PATCH 제외)
    String likeRestore = '%' + OPTC_RESTORE_MARKER + '%';
    String likeReturnDelete = '%' + OPTC_RETURN_DELETE_MARKER + '%';
    String likeReturnDeposit = '%' + OPTC_RETURN_DEPOSIT_DELETE_MARKER + '%';
    List<TransactionJournal> forceTjs = [
      SELECT Id, AdditionalNotes__c
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND JournalSubType.Name = :JOURNAL_SUB_TYPE_API_FORCED_CREDIT
        AND IsDeleted__c = FALSE
        AND (AdditionalNotes__c LIKE :likeRestore
          OR AdditionalNotes__c LIKE :likeReturnDelete
          OR AdditionalNotes__c LIKE :likeReturnDeposit)
      LIMIT 1000
    ];

    if (forceTjs.isEmpty()) {
      result.isValid = true;
      result.summary = 'OPTC force-credit TJ 없음 (검증 대상 없음)';
      return result;
    }

    Set<Id> tjIds = new Map<Id, TransactionJournal>(forceTjs).keySet();

    Map<Id, Date> actualExpiryByTjId = new Map<Id, Date>();
    for (LoyaltyLedger ll : [
      SELECT TransactionJournalId, ExpiryDate
      FROM LoyaltyLedger
      WHERE TransactionJournalId IN :tjIds AND EventType = 'Credit'
    ]) {
      actualExpiryByTjId.put(ll.TransactionJournalId, ll.ExpiryDate);
    }

    // 3종 마커별 origin 추출
    //   - pm81TjId=<TJ Id>           (OPTC_OLD_SALE_USAGE_RESTORE)
    //   - tjId=<TJ Id>               (OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT)
    //   - origSaleNo=<SaleNo>        (OPTC_RETURN_DELETE_RESTORE — SOQL 로 Point Debit TJ Id 해소)
    //
    // 한 force-credit TJ 가 여러 origin 을 참조할 수 있으므로 Map<Id, Set<String>> 구조.
    Map<Id, Set<String>> originTjIdsByForceTjId = new Map<Id, Set<String>>();
    Set<String> allOriginTjIds = new Set<String>();
    Map<Id, Set<String>> origSaleNosByForceTjId = new Map<Id, Set<String>>();
    Set<String> origSaleNosToResolve = new Set<String>();

    Pattern patPm81 = Pattern.compile('pm81TjId=([a-zA-Z0-9]+)');
    Pattern patTjId = Pattern.compile('(?:^|[^a-zA-Z0-9])tjId=([a-zA-Z0-9]+)');
    Pattern patOrigSaleNo = Pattern.compile('origSaleNo=([A-Za-z0-9_-]+)');
    Integer skippedNoOrigin = 0;

    for (TransactionJournal tj : forceTjs) {
      if (String.isBlank(tj.AdditionalNotes__c)) {
        skippedNoOrigin++;
        continue;
      }
      Set<String> tjIdRefs = new Set<String>();
      Matcher m1 = patPm81.matcher(tj.AdditionalNotes__c);
      if (m1.find()) {
        tjIdRefs.add(m1.group(1));
      }
      Matcher m2 = patTjId.matcher(tj.AdditionalNotes__c);
      if (m2.find()) {
        tjIdRefs.add(m2.group(1));
      }
      Set<String> saleNoRefs = new Set<String>();
      Matcher m3 = patOrigSaleNo.matcher(tj.AdditionalNotes__c);
      while (m3.find()) {
        saleNoRefs.add(m3.group(1));
      }

      if (tjIdRefs.isEmpty() && saleNoRefs.isEmpty()) {
        skippedNoOrigin++;
        continue;
      }
      if (!tjIdRefs.isEmpty()) {
        originTjIdsByForceTjId.put(tj.Id, tjIdRefs);
        allOriginTjIds.addAll(tjIdRefs);
      }
      if (!saleNoRefs.isEmpty()) {
        origSaleNosByForceTjId.put(tj.Id, saleNoRefs);
        origSaleNosToResolve.addAll(saleNoRefs);
      }
    }

    // OPTC_RETURN_DELETE_RESTORE — origSaleNo → 원판매의 Point Debit TJ Id 들로 해소
    if (!origSaleNosToResolve.isEmpty()) {
      Map<String, Set<String>> tjIdsBySaleNo = new Map<String, Set<String>>();
      for (TransactionJournal pdTj : [
        SELECT Id, Order.SaleNo__c
        FROM TransactionJournal
        WHERE Order.SaleNo__c IN :origSaleNosToResolve
          AND JournalSubType.Name = :JOURNAL_SUB_TYPE_POINT_DEBIT
          AND PaymentMethod = :PAYMENT_METHOD_POINT
          AND IsDeleted__c = FALSE
      ]) {
        if (pdTj.Order == null || String.isBlank(pdTj.Order.SaleNo__c)) {
          continue;
        }
        String saleNo = pdTj.Order.SaleNo__c;
        if (!tjIdsBySaleNo.containsKey(saleNo)) {
          tjIdsBySaleNo.put(saleNo, new Set<String>());
        }
        tjIdsBySaleNo.get(saleNo).add(String.valueOf(pdTj.Id));
      }
      for (Id forceTjId : origSaleNosByForceTjId.keySet()) {
        Set<String> saleNos = origSaleNosByForceTjId.get(forceTjId);
        Set<String> mergedIds = originTjIdsByForceTjId.containsKey(forceTjId)
          ? originTjIdsByForceTjId.get(forceTjId)
          : new Set<String>();
        for (String saleNo : saleNos) {
          Set<String> resolvedIds = tjIdsBySaleNo.get(saleNo);
          if (resolvedIds != null) {
            mergedIds.addAll(resolvedIds);
            allOriginTjIds.addAll(resolvedIds);
          }
        }
        if (!mergedIds.isEmpty()) {
          originTjIdsByForceTjId.put(forceTjId, mergedIds);
        }
      }
    }

    // 다중 lump 매칭 — origin TJ 마다 Credit lump ExpiryDate Set 수집
    Map<String, Set<Date>> originExpirySetByTjId = new Map<String, Set<Date>>();
    if (!allOriginTjIds.isEmpty()) {
      for (LoyaltyLedgerTraceability llt : [
        SELECT DebitLoyaltyLedger.TransactionJournalId,
               CreditLoyaltyLedger.ExpiryDate
        FROM LoyaltyLedgerTraceability
        WHERE DebitLoyaltyLedger.TransactionJournalId IN :allOriginTjIds
          AND DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_POINT_DEBIT
          AND ActionType = :ACTION_DEBIT
          AND Points > 0
      ]) {
        String originId = String.valueOf(llt.DebitLoyaltyLedger.TransactionJournalId);
        Date expiry = llt.CreditLoyaltyLedger.ExpiryDate;
        if (!originExpirySetByTjId.containsKey(originId)) {
          originExpirySetByTjId.put(originId, new Set<Date>());
        }
        originExpirySetByTjId.get(originId).add(expiry);
      }
    }

    Integer checkedCount = 0;
    for (TransactionJournal tj : forceTjs) {
      Set<String> originIds = originTjIdsByForceTjId.get(tj.Id);
      if (originIds == null || originIds.isEmpty()) {
        continue;
      }
      Date actualExp = actualExpiryByTjId.get(tj.Id);
      if (actualExp == null) {
        continue;
      }
      // 모든 origin TJ 의 ExpiryDate 합집합 — actual 이 이 안에 있어야 정합
      Set<Date> combinedExpirySet = new Set<Date>();
      for (String originId : originIds) {
        Set<Date> s = originExpirySetByTjId.get(originId);
        if (s != null) {
          combinedExpirySet.addAll(s);
        }
      }
      if (combinedExpirySet.isEmpty()) {
        continue;
      }
      checkedCount++;
      if (!combinedExpirySet.contains(actualExp)) {
        result.mismatchCount++;
        result.mismatchDetails.add(
          'forceCreditTjId=' + tj.Id +
          ' originTjIds=' + originIds +
          ' actualExpiry=' + actualExp +
          ' originExpirySet=' + combinedExpirySet
        );
      }
    }

    result.isValid = (result.mismatchCount == 0);
    result.summary = result.isValid
      ? 'OPTC lump 매칭 정합 (검증 ' + checkedCount + '건, origin 추출 불가 ' + skippedNoOrigin + '건 skip)'
      : 'OPTC lump 매칭 결함 ' + result.mismatchCount + '건 / 검증 ' + checkedCount + '건 — 결함 ⑨ 패턴';
    return result;
  }

  public static Boolean validateAndAlertOptionCLumpMatching(Id memberId) {
    return alertIfInvalid(validateOptionCLumpMatching(memberId));
  }

  // ============================================================
  // 보강 #3 — 원천 LL 추적 정합성 검증 (§ 6.3 step 3-5)
  //   Point Redeem Cancel Credit LL 의 AdditionalNotes 에 'ORIGIN_CREDIT_LL=' 토큰이
  //   있다면 그 토큰이 가리키는 원천 Credit LL 을 chain 끝까지 따라가서
  //   ultimate origin LL 이 실제로 존재하고 (IsDeleted=FALSE) EventType='Credit' 이어야 함.
  //   불일치 시 = 원천 추적 깨짐 (도움창/회원정보 정확성 영향)
  //   토큰 자체가 없는 LL 은 v2 paradigm 일 수 있으므로 정합 위반으로 보지 않음 (info 만).
  //
  //   chain 깊이 제한 (MAX_CHAIN_DEPTH=10) 으로 무한 루프 방어.
  // ============================================================
  private static final Integer MAX_ORIGIN_CHAIN_DEPTH = 10;

  public static ValidationResult validateOriginCreditLLTrace(Id memberId) {
    if (memberId == null) {
      return invalidMissing('ORIGIN_CREDIT_LL_TRACE', '회원 ID가 필요합니다.');
    }

    ValidationResult result = new ValidationResult();
    result.eventType = 'ORIGIN_CREDIT_LL_TRACE';
    result.memberId = memberId;
    populateMemberById(result, memberId);

    List<LoyaltyLedger> redeemCancelLLs = [
      SELECT Id, AdditionalNotes
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL
        AND TransactionJournal.IsDeleted__c = FALSE
      LIMIT 1000
    ];

    if (redeemCancelLLs.isEmpty()) {
      result.isValid = true;
      result.summary = 'Point Redeem Cancel LL 없음';
      return result;
    }

    Map<Id, Id> directOriginByLLId = new Map<Id, Id>();
    Integer withoutTokenCount = 0;
    for (LoyaltyLedger ll : redeemCancelLLs) {
      Id originId = extractOriginCreditLLId(ll.AdditionalNotes);
      if (originId == null) {
        withoutTokenCount++;
        continue;
      }
      directOriginByLLId.put(ll.Id, originId);
    }

    if (directOriginByLLId.isEmpty()) {
      result.isValid = true;
      result.summary = '원천 LL 추적 — 모든 LL 이 token 없음 (' + withoutTokenCount + '건, v2 paradigm 가능)';
      return result;
    }

    // chain 끝까지 traversal 을 위한 캐시
    //   notesByLLId: AdditionalNotes 로 다음 origin 추출 가능
    //   activeLLIds: 유효한 LL (IsDeleted=FALSE, EventType='Credit')
    Map<Id, String> notesByLLId = new Map<Id, String>();
    Set<Id> activeLLIds = new Set<Id>();
    Set<Id> visitedIds = new Set<Id>(directOriginByLLId.values());
    // 반복 SOQL 로 chain 따라감 — 한 번에 visitedIds 전체 조회 후 새 origin 추가
    Integer iteration = 0;
    while (!visitedIds.isEmpty() && iteration < MAX_ORIGIN_CHAIN_DEPTH) {
      Set<Id> newToFetch = new Set<Id>();
      for (Id id : visitedIds) {
        if (!activeLLIds.contains(id) && !notesByLLId.containsKey(id)) {
          newToFetch.add(id);
        }
      }
      if (newToFetch.isEmpty()) {
        break;
      }
      for (LoyaltyLedger ll : [
        SELECT Id, AdditionalNotes
        FROM LoyaltyLedger
        WHERE Id IN :newToFetch
          AND EventType = 'Credit'
          AND IsDeleted = FALSE
          AND TransactionJournal.IsDeleted__c = FALSE
      ]) {
        activeLLIds.add(ll.Id);
        if (String.isNotBlank(ll.AdditionalNotes)) {
          notesByLLId.put(ll.Id, ll.AdditionalNotes);
        }
      }
      // 다음 iteration 대상: 방금 발견된 LL 의 ORIGIN_CREDIT_LL token
      Set<Id> nextVisit = new Set<Id>();
      for (Id id : newToFetch) {
        String notes = notesByLLId.get(id);
        if (notes == null) {
          continue;
        }
        Id nextOrigin = extractOriginCreditLLId(notes);
        if (nextOrigin != null && !activeLLIds.contains(nextOrigin)) {
          nextVisit.add(nextOrigin);
        }
      }
      visitedIds = nextVisit;
      iteration++;
    }

    // 각 Redeem Cancel LL 에서 chain 끝까지 추적 — chain 중간에 끊기면 mismatch
    for (Id llId : directOriginByLLId.keySet()) {
      Id cursor = directOriginByLLId.get(llId);
      Set<Id> seen = new Set<Id>{ llId };
      Boolean ok = false;
      Integer depth = 0;
      while (cursor != null && depth <= MAX_ORIGIN_CHAIN_DEPTH) {
        if (seen.contains(cursor)) {
          // chain cycle — 결함
          break;
        }
        seen.add(cursor);
        if (!activeLLIds.contains(cursor)) {
          // chain 중간 LL 이 존재하지 않거나 삭제됨
          break;
        }
        String notes = notesByLLId.get(cursor);
        Id next = (notes == null) ? null : extractOriginCreditLLId(notes);
        if (next == null) {
          // ultimate origin 도달 (token 없는 LL = 최초 적립 LL)
          ok = true;
          break;
        }
        cursor = next;
        depth++;
      }
      if (!ok) {
        result.mismatchCount++;
        result.mismatchDetails.add(
          'LL=' + llId + ' chainDepth=' + depth + ' lastCursor=' + cursor +
          (depth > MAX_ORIGIN_CHAIN_DEPTH ? ' (max depth 초과)' : ' (chain 끊김 — 삭제/누락 LL)')
        );
      }
    }

    result.isValid = (result.mismatchCount == 0);
    Integer withTokenCount = directOriginByLLId.size();
    result.summary = result.isValid
      ? '원천 LL 추적 정합 (token 보유 ' + withTokenCount + '건 chain 검증 / token 없음 ' + withoutTokenCount + '건 — v2 paradigm 가능)'
      : '원천 LL 추적 결함 ' + result.mismatchCount + '건 / token 보유 ' + withTokenCount + '건';
    return result;
  }

  public static Boolean validateAndAlertOriginCreditLLTrace(Id memberId) {
    return alertIfInvalid(validateOriginCreditLLTrace(memberId));
  }

  // ============================================================
  // 보강 #6 — OPTC_SALE_PATCH force-credit lump 정합성 검증 (§ 11.1 4번째 마커)
  //
  //   배경: SALE_PATCH 는 "환원" 이 아닌 "추가 적립" 케이스라 §11.5 의 origin lump
  //         일치 원칙이 적용되지 않음. 다만 force-credit 가 만료된 lump 또는
  //         존재하지 않는 lump 으로 가면 회원이 사실상 포인트를 받지 못한다.
  //
  //   검증 대상 invariant (현 시점 기준):
  //     1. Credit LL.ExpiryDate >= Today  — 만료된 lump 향이면 결함
  //     2. 해당 ExpiryDate 의 LASEL lump 이 존재해야 함
  //     3. 해당 LASEL.isExpired__c = FALSE 이어야 함
  //
  //   향후 보강 가능: force-credit 시점의 latest residual lump 비교 (현재는 단순 invariant 만).
  // ============================================================
  public static ValidationResult validateSalePatchAccrualLump(Id memberId) {
    if (memberId == null) {
      return invalidMissing('OPTC_SALE_PATCH_LUMP', '회원 ID가 필요합니다.');
    }

    ValidationResult result = new ValidationResult();
    result.eventType = 'OPTC_SALE_PATCH_LUMP';
    result.memberId = memberId;
    populateMemberById(result, memberId);

    String likeSalePatch = '%' + OPTC_SALE_PATCH_MARKER + '%';
    List<TransactionJournal> patchTjs = [
      SELECT Id, AdditionalNotes__c, CreatedDate
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND JournalSubType.Name = :JOURNAL_SUB_TYPE_API_FORCED_CREDIT
        AND IsDeleted__c = FALSE
        AND AdditionalNotes__c LIKE :likeSalePatch
      LIMIT 1000
    ];

    if (patchTjs.isEmpty()) {
      result.isValid = true;
      result.summary = 'OPTC_SALE_PATCH force-credit TJ 없음 (검증 대상 없음)';
      return result;
    }

    Set<Id> patchTjIds = new Map<Id, TransactionJournal>(patchTjs).keySet();

    // 각 force-credit TJ 가 만든 Credit LL.ExpiryDate
    Map<Id, Date> expiryByTjId = new Map<Id, Date>();
    for (LoyaltyLedger ll : [
      SELECT TransactionJournalId, ExpiryDate
      FROM LoyaltyLedger
      WHERE TransactionJournalId IN :patchTjIds
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
    ]) {
      expiryByTjId.put(ll.TransactionJournalId, ll.ExpiryDate);
    }

    // 회원의 현재 LASEL lump 들 (ExpiryDate 기준 인덱스)
    Map<Date, LoyaltyAggrSubPointExprLedger__c> laselByExpiry = new Map<Date, LoyaltyAggrSubPointExprLedger__c>();
    for (LoyaltyAggrSubPointExprLedger__c lasel : [
      SELECT ExpiryDate__c, AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c,
             AvailablePoints__c, isExpired__c, CurrencySubTypeName__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :memberId
    ]) {
      laselByExpiry.put(lasel.ExpiryDate__c, lasel);
    }

    Date today = Date.today();
    Integer checkedCount = 0;

    for (TransactionJournal tj : patchTjs) {
      Date expiry = expiryByTjId.get(tj.Id);
      if (expiry == null) {
        // force-credit 결과 Credit LL 자체가 없음 → 실패한 환원
        result.mismatchCount++;
        result.mismatchDetails.add(
          'salePatchTjId=' + tj.Id + ' Credit LL 미존재 (force-credit 실패 가능)'
        );
        continue;
      }
      checkedCount++;

      // Invariant 1 — 만료된 lump
      if (expiry < today) {
        result.mismatchCount++;
        result.mismatchDetails.add(
          'salePatchTjId=' + tj.Id + ' lumpExpiry=' + expiry +
          ' < today=' + today + ' (만료된 lump 으로 적립 → 회원 실수령 0)'
        );
        continue;
      }

      // Invariant 2 — LASEL lump 존재
      LoyaltyAggrSubPointExprLedger__c lasel = laselByExpiry.get(expiry);
      if (lasel == null) {
        result.mismatchCount++;
        result.mismatchDetails.add(
          'salePatchTjId=' + tj.Id + ' lumpExpiry=' + expiry +
          ' (해당 ExpiryDate 의 LASEL 미존재 — rebuild 누락 가능)'
        );
        continue;
      }

      // Invariant 3 — LASEL.isExpired__c = TRUE 면 결함
      if (lasel.isExpired__c == true) {
        result.mismatchCount++;
        result.mismatchDetails.add(
          'salePatchTjId=' + tj.Id + ' lumpExpiry=' + expiry +
          ' (LASEL.isExpired=TRUE — 만료 처리된 lump 향)'
        );
      }
    }

    result.isValid = (result.mismatchCount == 0);
    result.summary = result.isValid
      ? 'OPTC_SALE_PATCH lump 정합 (검증 ' + checkedCount + '건)'
      : 'OPTC_SALE_PATCH lump 결함 ' + result.mismatchCount + '건 / 검증 ' + checkedCount + '건';
    return result;
  }

  public static Boolean validateAndAlertSalePatchAccrualLump(Id memberId) {
    return alertIfInvalid(validateSalePatchAccrualLump(memberId));
  }

  // ============================================================
  // 보강 #7 — 반품 입금 삭제 시 적립 복원 paradigm 의 프로모션 제외 정책 검증
  //
  //   배경: 반품 입금 삭제 fallback (GdReturnDepositServiceImpl L972-973) 에서
  //         creditPointsOnPurchase / creditPointsOnPurchaseByGrade 가 호출되면서
  //         원판매 프로모션의 PointTypeCode__c 제외 정책이 적용 안 되어
  //         프로모션이 제외한 PointType (예: 사은포인트) 까지 부당 적립 발생.
  //         (회원 253007200063 강명성 사건의 사은포인트 114,660P 부당 적립)
  //
  //   검증 대상 패턴:
  //     - 반품 Order (Order.IsReductionOrder__c = TRUE) 에 생성된 Purchase Accrual TJ
  //     - 그 TJ 의 PromotionId = NULL (원판매 프로모션 정보 단절)
  //     - 원판매 (Order.OriginalOrderId__c) 의 PromotionId__r.PointTypeCode__c 와
  //       그 TJ 가 만든 Credit LL 의 PointType 가 매칭되면 부당 적립 확정
  //
  //   회원 단위 스캔. memberId=null 이면 invalid.
  // ============================================================
  public static ValidationResult validateReturnDepositRestoredAccrual(Id memberId) {
    if (memberId == null) {
      return invalidMissing('RETURN_DEPOSIT_RESTORED_ACCRUAL', '회원 ID가 필요합니다.');
    }

    ValidationResult result = new ValidationResult();
    result.eventType = 'RETURN_DEPOSIT_RESTORED_ACCRUAL';
    result.memberId = memberId;
    populateMemberById(result, memberId);

    // 1. 의심 후보 TJ 조회 — 반품 Order 의 Purchase Accrual + PromotionId=NULL
    List<TransactionJournal> suspectTjs = [
      SELECT Id, OrderId, SaleId__c,
             Order.SaleNo__c,
             Order.OriginalOrderId__c,
             Order.OriginalOrderId__r.SaleNo__c,
             Order.OriginalOrderId__r.PromotionId__c,
             Order.OriginalOrderId__r.PromotionId__r.Name,
             Order.OriginalOrderId__r.PromotionId__r.PointTypeCode__c,
             CreatedDate
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND JournalSubType.Name = :JOURNAL_SUB_TYPE_PURCHASE_ACCRUAL
        AND PromotionId = NULL
        AND IsDeleted__c = FALSE
        AND Order.IsReductionOrder__c = TRUE
        AND Order.OriginalOrderId__c != NULL
      LIMIT 1000
    ];

    if (suspectTjs.isEmpty()) {
      result.isValid = true;
      result.summary = '의심 패턴 없음 (반품 Order 의 PromotionId=NULL Purchase Accrual TJ 0건)';
      return result;
    }

    // 2. 후보 TJ 들의 Credit LL 일괄 조회
    Set<Id> suspectTjIds = new Map<Id, TransactionJournal>(suspectTjs).keySet();
    Map<Id, List<LoyaltyLedger>> llsByTjId = new Map<Id, List<LoyaltyLedger>>();
    for (LoyaltyLedger ll : [
      SELECT Id, Points, TransactionJournalId,
             LoyaltyPgmCrcySubtype.PointTypeCode__c,
             LoyaltyPgmCrcySubtype.Name
      FROM LoyaltyLedger
      WHERE TransactionJournalId IN :suspectTjIds
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND Points > 0
    ]) {
      if (!llsByTjId.containsKey(ll.TransactionJournalId)) {
        llsByTjId.put(ll.TransactionJournalId, new List<LoyaltyLedger>());
      }
      llsByTjId.get(ll.TransactionJournalId).add(ll);
    }

    // 3. 매칭 검증 — 원판매 프로모션 제외 정책 위반 LL 식별
    Integer checkedCount = 0;
    Integer skippedNoExclusion = 0;
    for (TransactionJournal tj : suspectTjs) {
      Order origOrder = tj.Order == null ? null : tj.Order.OriginalOrderId__r;
      if (origOrder == null || origOrder.PromotionId__c == null) {
        skippedNoExclusion++;
        continue;
      }
      String excludedCodes = origOrder.PromotionId__r == null ? null : origOrder.PromotionId__r.PointTypeCode__c;
      if (String.isBlank(excludedCodes)) {
        skippedNoExclusion++;
        continue;
      }

      Set<String> excludedSet = new Set<String>();
      for (String code : excludedCodes.split(';')) {
        if (String.isNotBlank(code)) {
          excludedSet.add(code.trim());
        }
      }

      List<LoyaltyLedger> tjLLs = llsByTjId.get(tj.Id);
      if (tjLLs == null || tjLLs.isEmpty()) {
        continue;
      }
      checkedCount++;

      for (LoyaltyLedger ll : tjLLs) {
        String llPointType = ll.LoyaltyPgmCrcySubtype == null ? null : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
        if (String.isNotBlank(llPointType) && excludedSet.contains(llPointType.trim())) {
          // 결함 확정 — 프로모션이 제외한 PointType 에 적립됨
          result.mismatchCount++;
          result.mismatchDetails.add(
            'TJ=' + tj.Id +
            ' returnSale=' + tj.Order.SaleNo__c +
            ' origSale=' + origOrder.SaleNo__c +
            ' Promo=' + origOrder.PromotionId__r.Name +
            ' excludedCodes=' + excludedCodes +
            ' LL=' + ll.Id +
            ' subType=' + ll.LoyaltyPgmCrcySubtype.Name +
            ' (PT=' + llPointType + ')' +
            ' Points=' + ll.Points
          );
        }
      }
    }

    result.isValid = (result.mismatchCount == 0);
    result.summary = result.isValid
      ? '반품 입금 삭제 복원 적립 정합 (의심 TJ ' + suspectTjs.size() + '건 / 검증 ' + checkedCount + '건 / skip ' + skippedNoExclusion + '건)'
      : '반품 입금 삭제 복원 적립 결함 ' + result.mismatchCount + '건 — 원판매 프로모션 제외 정책 위반 (보강 #7 패턴)';
    return result;
  }

  public static Boolean validateAndAlertReturnDepositRestoredAccrual(Id memberId) {
    return alertIfInvalid(validateReturnDepositRestoredAccrual(memberId));
  }

  private static ValidationResult validateSaleDelete(Order saleOrder) {
    if (saleOrder == null) {
      return invalidMissing('SALE_DELETE', '삭제 판매를 찾을 수 없습니다.');
    }

    ValidationResult result = baseResult('SALE_DELETE', saleOrder);

    // [Fix 결함 ①③④⑤ 2026-06-08] 옛 판매 OPTC paradigm 분기
    //   옛 판매 (마이그레이션 cutoff 이전) 는 적립 LL 자체가 없고
    //   OPTC force-debit (OPTC_OLD_SALE_ETC_ACCRUAL_CANCEL) 으로 회수가 발생함.
    //   따라서 일반 Purchase Accrual LL ↔ CreditCancellation LLT 비교가 무의미.
    //   대신 ActualPaymentAmount - 비대상 PM 합 → 구매포인트 적립률 × 금액 추정 vs OPTC 마커 TJ 합 비교.
    if (isOldSaleByOrder(saleOrder)) {
      result.isOldSale = true;
      Decimal expected = 0;
      if (!isOriginalOrderNonAccrualStoreById(saleOrder.Id)) {
        Decimal eligibleAmount = calculateOldSaleEligibleAmount(saleOrder);
        expected = estimateOldSalePurchasePointAccrual(result.memberId, eligibleAmount);
      }
      // 옛 적립은 마이그레이션 시 PT='04' 기타포인트 lump 로 통합됨
      result.expectedCreditCancelByType.put('04', expected);
      result.actualCreditCancelByType.put('04', sumOldSaleOptcAccrualCancelActual(saleOrder.Id));
      finalizeResult(result);
      return result;
    }

    result.expectedCreditCancelByType = sumEffectiveAccrualPointsByType(saleOrder.Id);
    result.actualCreditCancelByType = sumCreditCancellationByOriginOrderByType(saleOrder.Id);
    finalizeResult(result);
    return result;
  }

  private static ValidationResult validateSaleCreate(Order saleOrder) {
    if (saleOrder == null) {
      return invalidMissing('SALE_CREATE', '판매 Order 를 찾을 수 없습니다.');
    }
    if (saleOrder.IsReductionOrder__c == true) {
      return invalidMissing('SALE_CREATE', '반품 Order 는 SALE_CREATE 대상이 아닙니다.');
    }
    if (saleOrder.IsDeleted__c == true) {
      return invalidMissing('SALE_CREATE', '삭제된 판매는 SALE_CREATE 검증 대상이 아닙니다 (별도 SALE_DELETE 검증 사용).');
    }

    ValidationResult result = baseResult('SALE_CREATE', saleOrder);

    // § 4.1 — 입금 합계
    result.expectedDepositTotal = absDecimal(saleOrder.ActualPaymentAmount__c);
    result.actualDepositTotal = sumAllValidDepositsForSale(saleOrder.Id);
    Decimal depositDiff = result.actualDepositTotal - result.expectedDepositTotal;

    // § 4.2 — 사용 한도 vs 실제 사용
    result.pointUsageLimit = calculatePointUsageLimit(saleOrder);
    result.actualPointUsage = sumPointPaymentDeposits(saleOrder.Id);
    Boolean pointUsageExceedsLimit = result.actualPointUsage > result.pointUsageLimit;

    // § 4.3 — 사용 정합 (PM=81 입금 ↔ Debit LLT)
    result.actualPointDebitLLT = sumPointDebitLLTByOrder(saleOrder.Id);
    Decimal debitLLTDiff = result.actualPointDebitLLT - result.actualPointUsage;

    // § 4.4 — 구매 적립 (subtype 별)
    Decimal eligibleAmount = calculateOriginalSaleEligibleAmount(saleOrder.Id);
    Set<Id> excludedSubtypeIds = collectPromotionExcludedSubtypeIds(saleOrder.PromotionId__c);
    result.expectedPurchaseAccrual = estimatePurchaseAccrualTotal(result.memberId, eligibleAmount, excludedSubtypeIds);
    result.actualPurchaseAccrual = sumAccrualLLByJST(saleOrder.Id, 'Purchase Accrual');
    Decimal purchaseDiff = result.actualPurchaseAccrual - result.expectedPurchaseAccrual;

    // § 4.5 — 프로모션 적립
    PromotionEstimate promoEst = estimatePromotionAccrual(saleOrder.PromotionId__c, eligibleAmount);
    result.expectedPromotionAccrual = promoEst.expected;
    result.actualPromotionAccrual = sumAccrualLLByJST(saleOrder.Id, 'Promotion Point Accrual');
    Decimal promoDiff = result.actualPromotionAccrual - result.expectedPromotionAccrual;

    // Mismatch 집계
    if (depositDiff != 0) {
      result.mismatchCount++;
      result.mismatchDetails.add('§4.1 입금합계 불일치: expected=' + formatPoint(result.expectedDepositTotal) +
                                 ' actual=' + formatPoint(result.actualDepositTotal) +
                                 ' diff=' + formatPoint(depositDiff));
    }
    if (pointUsageExceedsLimit) {
      result.mismatchCount++;
      result.mismatchDetails.add('§4.2 포인트 사용 한도 초과: limit=' + formatPoint(result.pointUsageLimit) +
                                 ' actualUsage=' + formatPoint(result.actualPointUsage));
    }
    if (debitLLTDiff != 0) {
      result.mismatchCount++;
      result.mismatchDetails.add('§4.3 Debit LLT 불일치: PM81입금=' + formatPoint(result.actualPointUsage) +
                                 ' DebitLLT합=' + formatPoint(result.actualPointDebitLLT) +
                                 ' diff=' + formatPoint(debitLLTDiff));
    }
    if (purchaseDiff != 0) {
      result.mismatchCount++;
      result.mismatchDetails.add('§4.4 구매적립 불일치: expected=' + formatPoint(result.expectedPurchaseAccrual) +
                                 ' actual=' + formatPoint(result.actualPurchaseAccrual) +
                                 ' diff=' + formatPoint(purchaseDiff) +
                                 ' eligible=' + formatPoint(eligibleAmount));
    }
    if (promoEst.verifiable && promoDiff != 0) {
      result.mismatchCount++;
      result.mismatchDetails.add('§4.5 프로모션적립 불일치: expected=' + formatPoint(result.expectedPromotionAccrual) +
                                 ' actual=' + formatPoint(result.actualPromotionAccrual) +
                                 ' diff=' + formatPoint(promoDiff) +
                                 ' (Type=' + promoEst.typeCode + ')');
    } else if (!promoEst.verifiable && result.actualPromotionAccrual > 0) {
      result.mismatchDetails.add('§4.5 프로모션적립 검증 스킵: Type=' + promoEst.typeCode +
                                 ' (이벤트/고정 포인트 정책 다양) — actual=' + formatPoint(result.actualPromotionAccrual));
    }

    result.isValid = (result.mismatchCount == 0);
    result.summary = result.isValid
      ? 'SALE_CREATE 검증 정상 (§4.1~4.5 모두 통과)'
      : 'SALE_CREATE 검증 불일치 ' + result.mismatchCount + '건';
    return result;
  }

  // 프로모션 적립 추정 결과
  private class PromotionEstimate {
    Decimal expected = 0;
    Boolean verifiable = false;  // false = Type 'none' 등 검증 불가
    String typeCode = '(없음)';
  }

  private static ValidationResult validateReturnCreate(Order returnOrder) {
    if (returnOrder == null) {
      return invalidMissing('RETURN_CREATE', '반품 판매를 찾을 수 없습니다.');
    }

    ValidationResult result = baseResult('RETURN_CREATE', returnOrder);
    result.originalOrderId = returnOrder.OriginalOrderId__c;
    if (returnOrder.OriginalOrderId__c != null) {
      Order originalOrder = findOrderById(returnOrder.OriginalOrderId__c);
      result.originalSaleNo = originalOrder == null ? null : originalOrder.SaleNo__c;
      result.expectedCreditCancelByType = estimateReturnCreditCancelPointsByType(returnOrder);
      result.actualCreditCancelByType = sumCreditCancellationByDebitOrderByType(returnOrder.Id);
    }

    result.expectedRedeemCancelPoints = sumPointReturnDeposits(returnOrder.Id);
    result.actualRedeemCancelByType = sumPointRedeemCancelCreditsByType(returnOrder.Id);
    finalizeResult(result);
    return result;
  }

  private static ValidationResult validateReturnDelete(Order returnOrder) {
    if (returnOrder == null) {
      return invalidMissing('RETURN_DELETE', '삭제 반품을 찾을 수 없습니다.');
    }
    if (returnOrder.IsReductionOrder__c != true) {
      return invalidMissing('RETURN_DELETE', '반품 Order 가 아닙니다 (IsReductionOrder__c != true).');
    }
    if (returnOrder.IsDeleted__c != true) {
      return invalidMissing('RETURN_DELETE',
        '반품 Order 가 삭제 상태가 아닙니다 (IsDeleted__c != true). 등록만 된 반품에 호출되었거나 삭제가 반영되지 않음.');
    }

    ValidationResult result = baseResult('RETURN_DELETE', returnOrder);
    result.originalOrderId = returnOrder.OriginalOrderId__c;
    if (returnOrder.OriginalOrderId__c != null) {
      Order originalOrder = findOrderById(returnOrder.OriginalOrderId__c);
      result.originalSaleNo = originalOrder == null ? null : originalOrder.SaleNo__c;
    }

    // 반품 삭제 후: 활성 CreditCancellation 및 Point Redeem Cancel 효과 모두 회수되어야 함
    // 기대 = 0 (반품 효과 전부 회수)
    // 실제 = 활성 (TJ.IsDel=FALSE) 합계
    result.expectedCreditCancelByType = new Map<String, Decimal>();
    result.actualCreditCancelByType = sumCreditCancellationByDebitOrderByType(returnOrder.Id);
    result.expectedRedeemCancelByType = new Map<String, Decimal>();
    result.actualRedeemCancelByType = sumPointRedeemCancelCreditsByType(returnOrder.Id);

    finalizeResult(result);
    return result;
  }

  private static ValidationResult validateDepositDelete(String eventType, TransactionJournal deletedDeposit) {
    if (deletedDeposit == null) {
      return invalidMissing(eventType, '삭제 입금 TransactionJournal을 찾을 수 없습니다.');
    }

    Id eventOrderId = resolveEventOrderId(deletedDeposit);
    Order eventOrder = eventOrderId == null ? deletedDeposit.Order : findOrderById(eventOrderId);
    ValidationResult result = baseResult(eventType, eventOrder);
    result.orderId = eventOrderId == null ? deletedDeposit.OrderId : eventOrderId;
    result.memberId = deletedDeposit.MemberId;
    if (deletedDeposit.MemberId != null) {
      populateMemberById(result, deletedDeposit.MemberId);
    }
    result.saleNo = eventOrder == null ? null : eventOrder.SaleNo__c;

    if (deletedDeposit.PaymentMethod == PAYMENT_METHOD_POINT) {
      result.expectedRedeemCancelPoints = absDecimal(deletedDeposit.TransactionAmount);
      result.actualRedeemCancelByType = sumPointRedeemCancelCreditsByType(result.orderId);
    } else if (deletedDeposit.DepositType__c == DEPOSIT_TYPE_RETURN && eventOrder != null) {
      result.expectedCreditCancelByType = estimateReturnCreditCancelPointsByType(eventOrder);
      result.actualCreditCancelByType = sumCreditCancellationByDebitOrderByType(result.orderId);
    } else if ('SALE_DEPOSIT_DELETE'.equals(eventType)
               && deletedDeposit.PaymentMethod != PAYMENT_METHOD_POINT
               && ('01'.equals(deletedDeposit.DepositType__c) || '02'.equals(deletedDeposit.DepositType__c))) {
      // [Fix 결함 ⑥ 2026-06-08] 옛 판매 입금 단건 삭제 OPTC paradigm 분기
      //   옛 판매 입금 (carry-over 포함) 은 적립 LL 자체가 없고
      //   OPTC force-debit (OPTC_SALE_DEPOSIT_DELETE_ETC_ACCRUAL_CANCEL) 으로 회수가 발생함.
      //   carry-over (OrderId__c != null) 케이스도 동일 paradigm 적용 (수정 ③ 효과 검증).
      if (isOldDepositNo(deletedDeposit.DepositNo__c)) {
        result.isOldSale = true;
        Decimal expected = 0;
        if (!isOriginalOrderNonAccrualStoreById(result.orderId)
            && !ACCRUAL_EXCLUDED_PAYMENT_METHODS.contains(deletedDeposit.PaymentMethod)) {
          Decimal eligibleAmount = absDecimal(deletedDeposit.TransactionAmount);
          expected = estimateOldSalePurchasePointAccrual(result.memberId, eligibleAmount);
        }
        result.expectedCreditCancelByType.put('04', expected);
        result.actualCreditCancelByType.put('04',
          sumOldDepositOptcAccrualCancelActual(result.orderId, deletedDeposit.DepositNo__c));
      } else {
        // 보강 #4 — 일반 결제 판매 입금 삭제 (§ 8 line 418)
        //   기대: 삭제 입금 TJ 가 만든 적립 Credit LL 합계 (= 취소되어야 할 적립)
        //   실제: 그 Credit LL 들을 가리키는 CreditCancellation LLT 합계
        //   불일치 시 = 적립이 정상 취소되지 않음
        result.expectedCreditCancelByType = sumAccrualPointsByDepositTJ(deletedDeposit.Id);
        result.actualCreditCancelByType = sumCreditCancellationByDepositTJ(deletedDeposit.Id);
      }
    }

    finalizeResult(result);
    return result;
  }

  // ============================================================
  // 보강 #5 헬퍼 — SALE_CREATE (§4) 검증용
  // ============================================================

  // § 4.1 — 판매의 모든 활성 입금 합계 (DepositType 무관, 환불 음수 처리 포함)
  private static Decimal sumAllValidDepositsForSale(Id orderId) {
    if (orderId == null) {
      return 0;
    }
    String orderIdText = String.valueOf(orderId);
    Decimal total = 0;
    for (TransactionJournal tj : [
      SELECT PaymentMethod, DepositType__c, TransactionAmount
      FROM TransactionJournal
      WHERE (OrderId = :orderId OR SaleId__c = :orderIdText)
        AND IsDeleted__c = FALSE
        AND TransactionAmount != NULL
    ]) {
      Decimal amt = absDecimal(tj.TransactionAmount);
      // 환불(DepositType '03'/'05')은 음수로 처리해 판매 금액에 부합
      if ('03'.equals(tj.DepositType__c) || '05'.equals(tj.DepositType__c)) {
        total -= amt;
      } else {
        total += amt;
      }
    }
    return total;
  }

  // § 4.2 — 포인트 사용 가능 한도 (적립가능 + 수리)
  private static Decimal calculatePointUsageLimit(Order saleOrder) {
    if (saleOrder == null) {
      return 0;
    }
    Decimal usageLimit = 0;
    Boolean isRepairOrder = '03'.equals(saleOrder.Type);
    for (OrderItem oi : [
      SELECT NetSalesUnitPrice__c, Quantity, IsExclude__c
      FROM OrderItem
      WHERE OrderId = :saleOrder.Id
    ]) {
      Decimal amount = absDecimal(oi.NetSalesUnitPrice__c) * absDecimal(oi.Quantity == null ? 1 : oi.Quantity);
      if (oi.IsExclude__c != true) {
        // 적립 가능 상품
        usageLimit += amount;
      } else if (isRepairOrder) {
        // 수리 상품 (IsExclude=true 이지만 원주문 Type='03' 이면 사용 한도 포함)
        usageLimit += amount;
      }
    }
    return usageLimit;
  }

  // § 4.2 / 4.3 — PM='81' 입금 합계
  private static Decimal sumPointPaymentDeposits(Id orderId) {
    if (orderId == null) {
      return 0;
    }
    String orderIdText = String.valueOf(orderId);
    List<AggregateResult> rows = [
      SELECT SUM(TransactionAmount) total
      FROM TransactionJournal
      WHERE (OrderId = :orderId OR SaleId__c = :orderIdText)
        AND PaymentMethod = :PAYMENT_METHOD_POINT
        AND IsDeleted__c = FALSE
    ];
    return aggregateDecimal(rows, 'total').abs();
  }

  // § 4.3 — Debit LLT.Points 합 (이 판매에서 사용한 포인트)
  private static Decimal sumPointDebitLLTByOrder(Id orderId) {
    if (orderId == null) {
      return 0;
    }
    String orderIdText = String.valueOf(orderId);
    List<AggregateResult> rows = [
      SELECT SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE ActionType = :ACTION_DEBIT
        AND (DebitLoyaltyLedger.TransactionJournal.OrderId = :orderId
          OR DebitLoyaltyLedger.TransactionJournal.SaleId__c = :orderIdText)
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_POINT_DEBIT
    ];
    return aggregateDecimal(rows, 'total').abs();
  }

  // § 4.4 / 4.5 — 특정 JST 의 적립 LL 합 (이 판매에서 발생)
  private static Decimal sumAccrualLLByJST(Id orderId, String jstName) {
    if (orderId == null || String.isBlank(jstName)) {
      return 0;
    }
    String orderIdText = String.valueOf(orderId);
    List<AggregateResult> rows = [
      SELECT SUM(Points) total
      FROM LoyaltyLedger
      WHERE (TransactionJournal.OrderId = :orderId OR TransactionJournal.SaleId__c = :orderIdText)
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name = :jstName
    ];
    return aggregateDecimal(rows, 'total').abs();
  }

  // § 4.5 — 프로모션이 점유하는 subtype Id 셋 (등급 적립에서 제외 대상)
  private static Set<Id> collectPromotionExcludedSubtypeIds(Id promotionId) {
    Set<Id> result = new Set<Id>();
    if (promotionId == null) {
      return result;
    }
    for (PromotionPointLimit__c ppl : [
      SELECT LoyaltyPgmCurrencySubtypeId__c
      FROM PromotionPointLimit__c
      WHERE PromotionId__c = :promotionId
        AND LoyaltyPgmCurrencySubtypeId__c != NULL
    ]) {
      result.add(ppl.LoyaltyPgmCurrencySubtypeId__c);
    }
    return result;
  }

  // § 4.4 — 등급 적립 기대값 (subtype 별 합)
  //   회원의 모든 LoyaltyTierBenefit 순회, subtype 이 excluded 가 아닌 것만 합산.
  //   각 subtype 별로 (eligible × rate / 100) HALF_UP 후 합 — 실제 코드와 동일 패턴.
  private static Decimal estimatePurchaseAccrualTotal(Id memberId, Decimal eligibleAmount, Set<Id> excludedSubtypeIds) {
    if (memberId == null || eligibleAmount == null || eligibleAmount <= 0) {
      return 0;
    }
    Decimal total = 0;
    for (LoyaltyTierBenefit ltb : [
      SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__c
      FROM LoyaltyTierBenefit
      WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :memberId)
    ]) {
      if (ltb.Benefit == null || ltb.Benefit.PurchasePointRate__c == null) {
        continue;
      }
      Id subtypeId = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c;
      if (excludedSubtypeIds != null && subtypeId != null && excludedSubtypeIds.contains(subtypeId)) {
        continue;
      }
      Decimal rate = ltb.Benefit.PurchasePointRate__c;
      total += (eligibleAmount * rate / 100).setScale(0, RoundingMode.HALF_UP);
    }
    return total;
  }

  // § 4.5 — 프로모션 적립 기대값
  //   Type='rate' → (eligible × value / 100) HALF_UP
  //   Type='none' → 검증 불가 (verifiable=false)
  //   Type 외 / Promotion 없음 → expected=0, verifiable=true (적립 없어야 정상)
  private static PromotionEstimate estimatePromotionAccrual(Id promotionId, Decimal eligibleAmount) {
    PromotionEstimate est = new PromotionEstimate();
    if (promotionId == null) {
      est.verifiable = true;
      est.typeCode = '(프로모션 없음)';
      return est;
    }
    List<PromotionPointLimit__c> pplList = [
      SELECT Type__c, Value__c
      FROM PromotionPointLimit__c
      WHERE PromotionId__c = :promotionId
    ];
    if (pplList.isEmpty()) {
      est.verifiable = true;
      est.typeCode = '(PromotionPointLimit 없음)';
      return est;
    }
    Boolean anyNone = false;
    Decimal sumRateExpected = 0;
    for (PromotionPointLimit__c ppl : pplList) {
      if ('rate'.equals(ppl.Type__c) && ppl.Value__c != null && eligibleAmount != null && eligibleAmount > 0) {
        sumRateExpected += (eligibleAmount * ppl.Value__c / 100).setScale(0, RoundingMode.HALF_UP);
      } else if ('none'.equals(ppl.Type__c)) {
        anyNone = true;
      }
    }
    if (anyNone) {
      // 'none' 이 하나라도 있으면 전체 검증 불가 (고정/이벤트 포인트 정책 다양)
      est.verifiable = false;
      est.typeCode = 'none(혼합)';
      est.expected = sumRateExpected;
    } else {
      est.verifiable = true;
      est.typeCode = 'rate';
      est.expected = sumRateExpected;
    }
    return est;
  }

  // 보강 #4 헬퍼 — 입금 TJ 가 직접 발행한 적립 Credit LL 합계 (PointType 별)
  private static Map<String, Decimal> sumAccrualPointsByDepositTJ(Id tjId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (tjId == null) {
      return result;
    }
    for (AggregateResult row : [
      SELECT LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedger
      WHERE TransactionJournalId = :tjId
        AND EventType = 'Credit'
        AND IsDeleted = FALSE
        AND (TransactionJournal.JournalSubType.Name = NULL
          OR TransactionJournal.JournalSubType.Name != :JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL)
      GROUP BY LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  // 보강 #4 헬퍼 — 위 Credit LL 들에 대한 CreditCancellation LLT 합계 (PointType 별)
  private static Map<String, Decimal> sumCreditCancellationByDepositTJ(Id tjId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (tjId == null) {
      return result;
    }
    for (AggregateResult row : [
      SELECT CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE ActionType = :ACTION_CREDIT_CANCELLATION
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND CreditLoyaltyLedger.TransactionJournalId = :tjId
      GROUP BY CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Order findOrderBySaleNo(String saleNo) {
    if (String.isBlank(saleNo)) {
      return null;
    }
    List<Order> rows = [
      SELECT Id, SaleNo__c, OriginalOrderId__c, IsReductionOrder__c, MemberNo__c, AccountId,
             TotalAmount, ActualPaymentAmount__c, IsDeleted__c, DeleteDateTime__c,
             Type, PromotionId__c
      FROM Order
      WHERE SaleNo__c = :saleNo
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static Order findOrderById(Id orderId) {
    if (orderId == null) {
      return null;
    }
    List<Order> rows = [
      SELECT Id, SaleNo__c, OriginalOrderId__c, IsReductionOrder__c, MemberNo__c, AccountId,
             TotalAmount, ActualPaymentAmount__c, IsDeleted__c, DeleteDateTime__c,
             Type, PromotionId__c
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static TransactionJournal findDeletedDeposit(String depositNo, String seqNo) {
    if (String.isBlank(depositNo)) {
      return null;
    }
    List<TransactionJournal> rows = (seqNo == null)
      ? [
          SELECT
            Id, OrderId, SaleId__c, MemberId, PaymentMethod, DepositType__c,
            TransactionAmount, DepositNo__c, DeposiSeqNo__c, IsDeleted__c,
            Order.Id, Order.SaleNo__c, Order.OriginalOrderId__c, Order.IsReductionOrder__c,
            Order.MemberNo__c, Order.AccountId, Order.TotalAmount, Order.ActualPaymentAmount__c
          FROM TransactionJournal
          WHERE DepositNo__c = :depositNo AND IsDeleted__c = TRUE
          ORDER BY LastModifiedDate DESC
          LIMIT 1
        ]
      : [
          SELECT
            Id, OrderId, SaleId__c, MemberId, PaymentMethod, DepositType__c,
            TransactionAmount, DepositNo__c, DeposiSeqNo__c, IsDeleted__c,
            Order.Id, Order.SaleNo__c, Order.OriginalOrderId__c, Order.IsReductionOrder__c,
            Order.MemberNo__c, Order.AccountId, Order.TotalAmount, Order.ActualPaymentAmount__c
          FROM TransactionJournal
          WHERE DepositNo__c = :depositNo
            AND DeposiSeqNo__c = :seqNo
            AND IsDeleted__c = TRUE
          ORDER BY LastModifiedDate DESC
          LIMIT 1
        ];
    return rows.isEmpty() ? null : rows[0];
  }

  // TJ Id 직접 — 가장 정확한 식별
  private static TransactionJournal findDeletedDepositById(Id tjId) {
    if (tjId == null) {
      return null;
    }
    List<TransactionJournal> rows = [
      SELECT
        Id, OrderId, SaleId__c, MemberId, PaymentMethod, DepositType__c,
        TransactionAmount, DepositNo__c, DeposiSeqNo__c, IsDeleted__c,
        Order.Id, Order.SaleNo__c, Order.OriginalOrderId__c, Order.IsReductionOrder__c,
        Order.MemberNo__c, Order.AccountId, Order.TotalAmount, Order.ActualPaymentAmount__c
      FROM TransactionJournal
      WHERE Id = :tjId AND IsDeleted__c = TRUE
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static ValidationResult baseResult(String eventType, Order orderRecord) {
    ValidationResult result = new ValidationResult();
    result.eventType = eventType;
    if (orderRecord != null) {
      result.orderId = orderRecord.Id;
      result.originalOrderId = orderRecord.OriginalOrderId__c;
      result.saleNo = orderRecord.SaleNo__c;
      result.memberNo = orderRecord.MemberNo__c;
      populateMember(result, orderRecord);
    }
    return result;
  }

  private static ValidationResult invalidMissing(String eventType, String message) {
    ValidationResult result = new ValidationResult();
    result.eventType = eventType;
    result.isValid = false;
    result.summary = message;
    return result;
  }

  private static void populateMember(ValidationResult result, Order orderRecord) {
    if (orderRecord == null || String.isBlank(orderRecord.MemberNo__c)) {
      return;
    }
    String memberRef = orderRecord.MemberNo__c;
    List<LoyaltyProgramMember> members;
    if (isSalesforceId(memberRef) && memberRef.startsWith('003')) {
      Id contactId = (Id) memberRef;
      members = [
        SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
        FROM LoyaltyProgramMember
        WHERE ContactId = :contactId AND MemberStatus = 'Active'
        LIMIT 1
      ];
    } else {
      members = [
        SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberRef AND MemberStatus = 'Active'
        LIMIT 1
      ];
    }
    applyMember(result, members);
  }

  private static void populateMemberById(ValidationResult result, Id memberId) {
    if (memberId == null) {
      return;
    }
    List<LoyaltyProgramMember> members = [
      SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
      FROM LoyaltyProgramMember
      WHERE Id = :memberId
      LIMIT 1
    ];
    applyMember(result, members);
  }

  private static void applyMember(ValidationResult result, List<LoyaltyProgramMember> members) {
    if (!members.isEmpty()) {
      result.memberId = members[0].Id;
      result.memberNo = members[0].Contact == null ? members[0].MembershipNumber : members[0].Contact.MemberNo__c;
      result.memberName = getMemberName(members[0]);
    }
  }

  private static Map<String, Decimal> estimateReturnCreditCancelPointsByType(Order returnOrder) {
    Map<String, Decimal> emptyResult = new Map<String, Decimal>();
    if (returnOrder == null || returnOrder.OriginalOrderId__c == null) {
      return emptyResult;
    }

    Map<String, Decimal> originalCreditsByType = sumEffectiveAccrualPointsByType(returnOrder.OriginalOrderId__c);
    Decimal originalEligibleAmount = calculateOriginalSaleEligibleAmount(returnOrder.OriginalOrderId__c);
    Decimal returnEligibleAmount = calculateReturnEligibleAmount(returnOrder.Id);
    if (originalCreditsByType.isEmpty() || originalEligibleAmount <= 0 || returnEligibleAmount <= 0) {
      return emptyResult;
    }
    return prorateByType(originalCreditsByType, returnEligibleAmount, originalEligibleAmount);
  }

  private static Map<String, Decimal> sumOriginalAccrualPointsByType(Id orderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (orderId == null) {
      return result;
    }
    String orderIdText = String.valueOf(orderId);
    for (AggregateResult row : [
      SELECT LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedger
      WHERE (TransactionJournal.OrderId = :orderId OR TransactionJournal.SaleId__c = :orderIdText)
        AND EventType = 'Credit'
        AND (TransactionJournal.JournalSubType.Name = NULL OR TransactionJournal.JournalSubType.Name != :JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL)
      GROUP BY LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Map<String, Decimal> sumEffectiveAccrualPointsByType(Id orderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (orderId == null) {
      return result;
    }

    String orderIdText = String.valueOf(orderId);
    List<LoyaltyLedger> creditLedgers = [
      SELECT Id, Points, LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE (TransactionJournal.OrderId = :orderId OR TransactionJournal.SaleId__c = :orderIdText)
        AND EventType = 'Credit'
        AND TransactionJournal.IsDeleted__c = FALSE
        AND (TransactionJournal.JournalSubType.Name = NULL OR TransactionJournal.JournalSubType.Name != :JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL)
    ];
    if (creditLedgers.isEmpty()) {
      return result;
    }

    Map<Id, LoyaltyLedger> creditById = new Map<Id, LoyaltyLedger>(creditLedgers);
    Map<Id, Decimal> canceledByCreditId = new Map<Id, Decimal>();
    for (AggregateResult row : [
      SELECT CreditLoyaltyLedgerId creditId, SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId IN :creditById.keySet()
        AND ActionType = :ACTION_CREDIT_CANCELLATION
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      GROUP BY CreditLoyaltyLedgerId
    ]) {
      canceledByCreditId.put((Id) row.get('creditId'), absDecimal((Decimal) row.get('total')));
    }

    for (LoyaltyLedger creditLedger : creditLedgers) {
      Decimal creditPoints = absDecimal(creditLedger.Points);
      Decimal canceledPoints = canceledByCreditId.containsKey(creditLedger.Id) ? canceledByCreditId.get(creditLedger.Id) : 0;
      Decimal effectivePoints = creditPoints - canceledPoints;
      if (effectivePoints > 0) {
        addToMap(result, normalizePointType(creditLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c), effectivePoints);
      }
    }
    return result;
  }

  private static Map<String, Decimal> sumCreditCancellationByOriginOrderByType(Id originalOrderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (originalOrderId == null) {
      return result;
    }
    String originalOrderIdText = String.valueOf(originalOrderId);
    for (AggregateResult row : [
      SELECT CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE ActionType = :ACTION_CREDIT_CANCELLATION
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (CreditLoyaltyLedger.TransactionJournal.OrderId = :originalOrderId
        OR CreditLoyaltyLedger.TransactionJournal.SaleId__c = :originalOrderIdText)
      GROUP BY CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Map<String, Decimal> sumCreditCancellationByDebitOrderByType(Id debitOrderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (debitOrderId == null) {
      return result;
    }
    String debitOrderIdText = String.valueOf(debitOrderId);
    for (AggregateResult row : [
      SELECT CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE ActionType = :ACTION_CREDIT_CANCELLATION
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (DebitLoyaltyLedger.TransactionJournal.OrderId = :debitOrderId
        OR DebitLoyaltyLedger.TransactionJournal.SaleId__c = :debitOrderIdText)
      GROUP BY CreditLoyaltyLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Decimal sumPointReturnDeposits(Id orderId) {
    if (orderId == null) {
      return 0;
    }
    String orderIdText = String.valueOf(orderId);
    List<AggregateResult> rows = [
      SELECT SUM(TransactionAmount) total
      FROM TransactionJournal
      WHERE (OrderId = :orderId OR SaleId__c = :orderIdText)
        AND PaymentMethod = :PAYMENT_METHOD_POINT
        AND DepositType__c = :DEPOSIT_TYPE_RETURN
        AND IsDeleted__c = FALSE
    ];
    return aggregateDecimal(rows, 'total').abs();
  }

  private static Map<String, Decimal> sumPointRedeemCancelCreditsByType(Id orderId) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (orderId == null) {
      return result;
    }
    String orderIdText = String.valueOf(orderId);
    for (AggregateResult row : [
      SELECT LoyaltyPgmCrcySubtype.PointTypeCode__c pointType, SUM(Points) total
      FROM LoyaltyLedger
      WHERE (TransactionJournal.OrderId = :orderId OR TransactionJournal.SaleId__c = :orderIdText)
        AND EventType = 'Credit'
        AND TransactionJournal.IsDeleted__c = FALSE
        AND TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL
      GROUP BY LoyaltyPgmCrcySubtype.PointTypeCode__c
    ]) {
      addToMap(result, normalizePointType((String) row.get('pointType')), absDecimal((Decimal) row.get('total')));
    }
    return result;
  }

  private static Decimal calculateOriginalSaleEligibleAmount(Id originalOrderId) {
    if (originalOrderId == null) {
      return 0;
    }
    Decimal eligibleDepositAmount = calculateAccrualEligibleDepositAmount(originalOrderId, false);
    Decimal excludedAmount = calculateSaleExcludedAmount(originalOrderId);
    Decimal result = eligibleDepositAmount - excludedAmount;
    return result <= 0 ? 0 : result;
  }

  private static Decimal calculateReturnEligibleAmount(Id returnOrderId) {
    if (returnOrderId == null) {
      return 0;
    }
    Decimal eligibleDepositAmount = calculateAccrualEligibleDepositAmount(returnOrderId, true);
    Decimal excludedAmount = calculateReturnExcludedAmount(returnOrderId);
    Decimal result = eligibleDepositAmount - excludedAmount;
    return result <= 0 ? 0 : result;
  }

  private static Decimal calculateAccrualEligibleDepositAmount(Id orderId, Boolean includeReturnDepositTypes) {
    Decimal total = 0;
    if (orderId == null) {
      return total;
    }
    String orderIdText = String.valueOf(orderId);
    for (TransactionJournal tj : [
      SELECT PaymentMethod, DepositType__c, TransactionAmount
      FROM TransactionJournal
      WHERE (OrderId = :orderId OR SaleId__c = :orderIdText)
        AND IsDeleted__c = FALSE
    ]) {
      if (!isAccrualEligiblePayment(tj)) {
        continue;
      }
      Boolean depositTypeEligible = includeReturnDepositTypes
        ? (tj.DepositType__c == '03' || tj.DepositType__c == '05')
        : (tj.DepositType__c == '01' || tj.DepositType__c == '02');
      if (!depositTypeEligible) {
        continue;
      }
      total += absDecimal(tj.TransactionAmount);
    }
    return total;
  }

  private static Boolean isAccrualEligiblePayment(TransactionJournal tj) {
    if (tj == null || tj.TransactionAmount == null || tj.TransactionAmount == 0) {
      return false;
    }
    if (String.isBlank(tj.PaymentMethod) || ACCRUAL_EXCLUDED_PAYMENT_METHODS.contains(tj.PaymentMethod)) {
      return false;
    }
    return true;
  }

  private static Decimal calculateSaleExcludedAmount(Id orderId) {
    Decimal excludedAmount = 0;
    if (orderId == null) {
      return excludedAmount;
    }
    for (OrderItem oi : [
      SELECT NetSalesUnitPrice__c, Quantity, IsExclude__c
      FROM OrderItem
      WHERE OrderId = :orderId
    ]) {
      if (oi.IsExclude__c == true) {
        excludedAmount += absDecimal(oi.NetSalesUnitPrice__c) * absDecimal(oi.Quantity == null ? 1 : oi.Quantity);
      }
    }
    return excludedAmount;
  }

  private static Decimal calculateReturnExcludedAmount(Id returnOrderId) {
    Decimal excludedAmount = 0;
    if (returnOrderId == null) {
      return excludedAmount;
    }
    for (OrderItem oi : [
      SELECT
        IsExclude__c,
        NetSalesUnitPrice__c,
        Quantity,
        OriginalOrderItemId__c,
        OriginalOrderItem.IsExclude__c,
        OriginalOrderItem.NetSalesUnitPrice__c
      FROM OrderItem
      WHERE OrderId = :returnOrderId
    ]) {
      Boolean isExcluded = oi.OriginalOrderItemId__c != null ? oi.OriginalOrderItem.IsExclude__c : oi.IsExclude__c;
      Decimal unitPrice = oi.OriginalOrderItemId__c != null ? oi.OriginalOrderItem.NetSalesUnitPrice__c : oi.NetSalesUnitPrice__c;
      if (isExcluded == true) {
        excludedAmount += absDecimal(unitPrice) * absDecimal(oi.Quantity == null ? 1 : oi.Quantity);
      }
    }
    return excludedAmount;
  }

  private static Map<String, Decimal> prorateByType(Map<String, Decimal> sourceByType, Decimal numerator, Decimal denominator) {
    Map<String, Decimal> result = new Map<String, Decimal>();
    if (sourceByType == null || sourceByType.isEmpty() || numerator == null || denominator == null || denominator <= 0) {
      return result;
    }
    for (String pointType : sourceByType.keySet()) {
      Decimal sourcePoints = sourceByType.get(pointType) == null ? 0 : sourceByType.get(pointType);
      Decimal points = (sourcePoints * numerator / denominator).setScale(0, RoundingMode.HALF_UP);
      if (points > 0) {
        result.put(pointType, points);
      }
    }
    return result;
  }

  private static void finalizeResult(ValidationResult result) {
    result.expectedCreditCancelPoints = sumMap(result.expectedCreditCancelByType);
    result.actualCreditCancelPoints = sumMap(result.actualCreditCancelByType);
    if (result.expectedRedeemCancelPoints == null || result.expectedRedeemCancelPoints == 0) {
      result.expectedRedeemCancelPoints = sumMap(result.expectedRedeemCancelByType);
    }
    result.actualRedeemCancelPoints = sumMap(result.actualRedeemCancelByType);

    result.creditCancelDifference = result.actualCreditCancelPoints - result.expectedCreditCancelPoints;
    result.redeemCancelDifference = result.actualRedeemCancelPoints - result.expectedRedeemCancelPoints;
    result.isValid = result.creditCancelDifference == 0 && result.redeemCancelDifference == 0;
    result.summary = result.isValid
      ? '포인트 이벤트 검증 정상'
      : '포인트 이벤트 검증 불일치. 적립취소 기대=' + formatPoint(result.expectedCreditCancelPoints) +
        'P/실제=' + formatPoint(result.actualCreditCancelPoints) +
        'P, 사용취소 기대=' + formatPoint(result.expectedRedeemCancelPoints) +
        'P/실제=' + formatPoint(result.actualRedeemCancelPoints) +
        'P, 기대 적립취소 타입별=' + JSON.serialize(result.expectedCreditCancelByType) +
        ', 실제 적립취소 타입별=' + JSON.serialize(result.actualCreditCancelByType);
  }

  private static Boolean alertIfInvalid(ValidationResult result) {
    if (result == null || result.isValid == true) {
      return true;
    }
    return sendValidationAlert(result);
  }

  private static Boolean sendValidationAlert(ValidationResult result) {
    Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
    if (config == null || !config.Is_Active__c || String.isBlank(config.Webhook_URL__c)) {
      System.debug(LoggingLevel.WARN, '[포인트 이벤트 검증] Slack 설정이 비활성화되어 알림을 보내지 않습니다. ' + result.summary);
      return false;
    }

    HttpRequest req = new HttpRequest();
    req.setEndpoint(config.Webhook_URL__c);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(buildSlackBody(result));
    req.setTimeout(10000);

    HttpResponse res = new Http().send(req);
    return res.getStatusCode() >= 200 && res.getStatusCode() < 300;
  }

  private static String buildSlackBody(ValidationResult result) {
    String orgUrl = URL.getOrgDomainUrl().toExternalForm();
    String memberLink = result.memberId == null ? '' : orgUrl + '/' + result.memberId;
    String memberTitle = String.isBlank(memberLink)
      ? String.valueOf(result.memberName)
      : '<' + memberLink + '|' + result.memberName + '>';

    Map<String, Object> msg = new Map<String, Object>{
      'text' => '[골든듀 모니터링] 포인트 이벤트 검증 불일치',
      'blocks' => new List<Object>{
        new Map<String, Object>{
          'type' => 'header',
          'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => '포인트 이벤트 검증 불일치' }
        },
        new Map<String, Object>{
          'type' => 'section',
          'fields' => new List<Object>{
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*이벤트*\n' + result.eventType },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원*\n' + memberTitle },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원번호*\n' + String.valueOf(result.memberNo) },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*판매번호*\n' + String.valueOf(result.saleNo) },
            new Map<String, Object>{
              'type' => 'mrkdwn',
              'text' => '*적립취소 기대/실제*\n' + formatPoint(result.expectedCreditCancelPoints) + 'P / ' + formatPoint(result.actualCreditCancelPoints) + 'P'
            },
            new Map<String, Object>{
              'type' => 'mrkdwn',
              'text' => '*사용취소 기대/실제*\n' + formatPoint(result.expectedRedeemCancelPoints) + 'P / ' + formatPoint(result.actualRedeemCancelPoints) + 'P'
            }
          }
        },
        new Map<String, Object>{
          'type' => 'section',
          'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*요약*\n' + result.summary }
        }
      }
    };
    return JSON.serialize(msg);
  }

  private static Decimal aggregateDecimal(List<AggregateResult> rows, String fieldName) {
    if (rows == null || rows.isEmpty() || rows[0].get(fieldName) == null) {
      return 0;
    }
    return (Decimal) rows[0].get(fieldName);
  }

  private static Decimal absDecimal(Decimal value) {
    return value == null ? 0 : value.abs();
  }

  // ============================================================
  // [Fix 결함 ①~⑥ 2026-06-08] 옛 판매 OPTC paradigm 검증 헬퍼
  //
  // paradigm 정의:
  //   - 옛 판매 (마이그레이션 cutoff 이전) 는 적립 LL 자체가 없음.
  //     마이그레이션 시 모든 적립이 PT='04' 기타포인트 lump 로 통합됨 (Option C residual lump).
  //   - 옛 판매 삭제 / 입금 단건 삭제 시 OPTC force-debit (회수 추정 + 기타포인트 lump 차감) 실행.
  //   - 검증 paradigm:
  //       expected = (ActualPaymentAmount - 비대상 PM 합) × 회원 등급의 PT='01' 구매포인트 적립률
  //       actual = OPTC_..._ACCRUAL_CANCEL 마커 TJ 의 TransactionAmount 합
  //   - 적립 불가 매장 (StoreType 20/25/33) 은 expected=0 (안전 skip).
  // ============================================================

  /**
   * 옛 판매 여부 — saleNo 기준 (cutoff 이전 + 마이그레이션 import 흔적).
   */
  private static Boolean isOldSaleByOrder(Order saleOrder) {
    if (saleOrder == null || String.isBlank(saleOrder.SaleNo__c)) {
      return false;
    }
    try {
      return GdMigrationUtil.shouldApplyOptionCBranchBySaleNo(saleOrder.SaleNo__c);
    } catch (Exception e) {
      return false;
    }
  }

  /**
   * 옛 입금 여부 — depositNo 기준.
   */
  private static Boolean isOldDepositNo(String depositNo) {
    if (String.isBlank(depositNo)) {
      return false;
    }
    // 'del_' prefix 가 붙어 있어도 원본 depositNo 로 판정 가능하도록 분기
    String testDepositNo = depositNo.startsWith('del_') ? depositNo.substring(4) : depositNo;
    try {
      return GdMigrationUtil.shouldApplyOptionCBranchByDepositNo(testDepositNo);
    } catch (Exception e) {
      return false;
    }
  }

  /**
   * 원판매 매장이 적립 불가 매장(StoreType 20/25/33)인지 검사.
   * OPTC force-debit 의 Non-Accrual Store Guard paradigm 과 동일.
   */
  private static Boolean isOriginalOrderNonAccrualStoreById(Id orderId) {
    if (orderId == null) {
      return false;
    }
    try {
      for (Order o : [
        SELECT StoreCode__r.StoreType__c
        FROM Order
        WHERE Id = :orderId
        LIMIT 1
      ]) {
        String storeType = o.StoreCode__r != null ? o.StoreCode__r.StoreType__c : null;
        if (String.isBlank(storeType)) {
          return false;
        }
        return storeType == '20' || storeType == '25' || storeType == '33';
      }
    } catch (Exception e) {
      return false;
    }
    return false;
  }

  /**
   * 옛 판매 적립 가능 금액 = ActualPaymentAmount - 비대상 PM 합.
   * 핸들러의 보강 ② 와 동일 paradigm. 3 매칭 키 (SaleId__c / OrderId__c / OrderId) 로 SAL Order 와 연결.
   */
  private static Decimal calculateOldSaleEligibleAmount(Order saleOrder) {
    if (saleOrder == null || saleOrder.ActualPaymentAmount__c == null) {
      return 0;
    }
    Decimal baseAmount = absDecimal(saleOrder.ActualPaymentAmount__c);
    if (baseAmount <= 0) {
      return 0;
    }
    Decimal nonAccrual = 0;
    Id orderId = saleOrder.Id;
    String orderIdText = String.valueOf(orderId);
    for (TransactionJournal tj : [
      SELECT TransactionAmount
      FROM TransactionJournal
      WHERE (SaleId__c = :orderIdText OR OrderId__c = :orderId OR OrderId = :orderId)
        AND PaymentMethod IN :ACCRUAL_EXCLUDED_PAYMENT_METHODS
    ]) {
      if (tj.TransactionAmount != null) {
        nonAccrual += absDecimal(tj.TransactionAmount);
      }
    }
    Decimal result = baseAmount - nonAccrual;
    return result <= 0 ? 0 : result;
  }

  /**
   * 회원 등급의 PT='01' (구매포인트) 적립률 × 금액 → OPTC 추정 회수액.
   * GdMigrationUtil.calculateAccrualForOldOrder 와 동일 paradigm (PT='01' 만 사용).
   */
  private static Decimal estimateOldSalePurchasePointAccrual(Id memberId, Decimal eligibleAmount) {
    if (memberId == null || eligibleAmount == null || eligibleAmount <= 0) {
      return 0;
    }
    Decimal total = 0;
    for (LoyaltyTierBenefit ltb : [
      SELECT Benefit.PurchasePointRate__c,
             Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c
      FROM LoyaltyTierBenefit
      WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :memberId)
    ]) {
      if (ltb.Benefit == null || ltb.Benefit.PurchasePointRate__c == null) {
        continue;
      }
      String pt = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r != null
        ? ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c
        : null;
      // 옛 판매 paradigm: 구매포인트 비율(PT='01') 만 사용 (사은포인트 PT='06' 등 제외)
      if (!'01'.equals(pt)) {
        continue;
      }
      Decimal rate = ltb.Benefit.PurchasePointRate__c;
      total += (eligibleAmount * rate / 100).setScale(0, RoundingMode.HALF_UP);
    }
    return total;
  }

  /**
   * 옛 판매 전체 삭제 OPTC ACCRUAL_CANCEL 마커 TJ 의 TransactionAmount 합.
   * 운영 기존 마커 (OPTC_OLD_SALE_ETC_ACCRUAL_CANCEL) + 새 핸들러 마커 (OPTC_SALE_DELETE_ETC_ACCRUAL_CANCEL) 모두 인식.
   */
  private static Decimal sumOldSaleOptcAccrualCancelActual(Id orderId) {
    if (orderId == null) {
      return 0;
    }
    Decimal total = 0;
    for (TransactionJournal tj : [
      SELECT TransactionAmount
      FROM TransactionJournal
      WHERE OrderId = :orderId
        AND IsDeleted__c = FALSE
        AND (AdditionalNotes__c LIKE 'OPTC_OLD_SALE_ETC_ACCRUAL_CANCEL%'
             OR AdditionalNotes__c LIKE 'OPTC_SALE_DELETE_ETC_ACCRUAL_CANCEL%')
    ]) {
      if (tj.TransactionAmount != null) {
        total += absDecimal(tj.TransactionAmount);
      }
    }
    return total;
  }

  /**
   * 옛 판매 입금 단건 삭제 OPTC ACCRUAL_CANCEL 마커 TJ 합.
   * 새 핸들러 마커: OPTC_SALE_DEPOSIT_DELETE_ETC_ACCRUAL_CANCEL
   * depositNo 가 AdditionalNotes 안에 포함된 케이스만 카운트 (정확 매칭).
   */
  private static Decimal sumOldDepositOptcAccrualCancelActual(Id orderId, String depositNo) {
    if (orderId == null) {
      return 0;
    }
    String origDepositNo = (String.isNotBlank(depositNo) && depositNo.startsWith('del_'))
      ? depositNo.substring(4)
      : depositNo;
    Decimal total = 0;
    for (TransactionJournal tj : [
      SELECT TransactionAmount, AdditionalNotes__c
      FROM TransactionJournal
      WHERE OrderId = :orderId
        AND IsDeleted__c = FALSE
        AND AdditionalNotes__c LIKE 'OPTC_SALE_DEPOSIT_DELETE_ETC_ACCRUAL_CANCEL%'
    ]) {
      if (String.isBlank(origDepositNo)
          || tj.AdditionalNotes__c == null
          || tj.AdditionalNotes__c.contains(origDepositNo)) {
        if (tj.TransactionAmount != null) {
          total += absDecimal(tj.TransactionAmount);
        }
      }
    }
    return total;
  }

  private static Decimal sumMap(Map<String, Decimal> valuesByKey) {
    Decimal total = 0;
    if (valuesByKey == null) {
      return total;
    }
    for (Decimal value : valuesByKey.values()) {
      total += value == null ? 0 : value;
    }
    return total;
  }

  private static void addToMap(Map<String, Decimal> valuesByKey, String key, Decimal value) {
    if (valuesByKey == null || value == null || value == 0) {
      return;
    }
    String normalizedKey = normalizePointType(key);
    valuesByKey.put(normalizedKey, (valuesByKey.containsKey(normalizedKey) ? valuesByKey.get(normalizedKey) : 0) + value);
  }

  private static String normalizePointType(String pointType) {
    return String.isBlank(pointType) ? UNKNOWN_POINT_TYPE : pointType.trim();
  }

  private static Id resolveEventOrderId(TransactionJournal tj) {
    if (tj == null) {
      return null;
    }
    if (String.isNotBlank(tj.SaleId__c) && isSalesforceId(tj.SaleId__c)) {
      return (Id) tj.SaleId__c;
    }
    return tj.OrderId;
  }

  private static Boolean isSalesforceId(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    try {
      Id parsedId = (Id) value;
      return parsedId != null;
    } catch (Exception e) {
      return false;
    }
  }

  private static String getMemberName(LoyaltyProgramMember member) {
    if (member.Contact != null && String.isNotBlank(member.Contact.Name)) {
      return member.Contact.Name;
    }
    if (member.Account != null && String.isNotBlank(member.Account.Name)) {
      return member.Account.Name;
    }
    return member.MembershipNumber != null ? member.MembershipNumber : '(이름 없음)';
  }

  private static String formatPoint(Decimal value) {
    return String.valueOf(value == null ? 0 : value.setScale(0));
  }

  // ORIGIN_CREDIT_LL=<id> 토큰에서 원천 LL Id 추출
  private static Id extractOriginCreditLLId(String additionalNotes) {
    if (String.isBlank(additionalNotes)) {
      return null;
    }
    Integer tokenIdx = additionalNotes.indexOf(ORIGIN_CREDIT_LL_TOKEN);
    if (tokenIdx < 0) {
      return null;
    }
    Integer valueStart = tokenIdx + ORIGIN_CREDIT_LL_TOKEN.length();
    Integer valueEnd = additionalNotes.indexOf(';', valueStart);
    String idText = valueEnd < 0
      ? additionalNotes.substring(valueStart)
      : additionalNotes.substring(valueStart, valueEnd);
    try {
      return (Id) idText.trim();
    } catch (Exception e) {
      return null;
    }
  }
}