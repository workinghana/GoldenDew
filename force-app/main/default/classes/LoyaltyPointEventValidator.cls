public without sharing class LoyaltyPointEventValidator {
  private static final String PAYMENT_METHOD_POINT = '81';
  private static final String DEPOSIT_TYPE_RETURN = '03';
  private static final String ACTION_CREDIT_CANCELLATION = 'CreditCancellation';
  private static final String JOURNAL_SUB_TYPE_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String JOURNAL_SUB_TYPE_API_FORCED_CREDIT = 'Api Forced Credit';
  private static final String JOURNAL_SUB_TYPE_POINT_DEBIT = 'Point Debit';
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

  private static ValidationResult validateSaleDelete(Order saleOrder) {
    if (saleOrder == null) {
      return invalidMissing('SALE_DELETE', '삭제 판매를 찾을 수 없습니다.');
    }

    ValidationResult result = baseResult('SALE_DELETE', saleOrder);
    result.expectedCreditCancelByType = sumEffectiveAccrualPointsByType(saleOrder.Id);
    result.actualCreditCancelByType = sumCreditCancellationByOriginOrderByType(saleOrder.Id);
    finalizeResult(result);
    return result;
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
      // 보강 #4 — 일반 결제 판매 입금 삭제 (§ 8 line 418)
      //   기대: 삭제 입금 TJ 가 만든 적립 Credit LL 합계 (= 취소되어야 할 적립)
      //   실제: 그 Credit LL 들을 가리키는 CreditCancellation LLT 합계
      //   불일치 시 = 적립이 정상 취소되지 않음
      result.expectedCreditCancelByType = sumAccrualPointsByDepositTJ(deletedDeposit.Id);
      result.actualCreditCancelByType = sumCreditCancellationByDepositTJ(deletedDeposit.Id);
    }

    finalizeResult(result);
    return result;
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
             TotalAmount, ActualPaymentAmount__c, IsDeleted__c, DeleteDateTime__c
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
             TotalAmount, ActualPaymentAmount__c, IsDeleted__c, DeleteDateTime__c
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