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
  private static final String OPTION_C_FORCE_CREDIT_NOTE_PREFIX = 'OPTC_FORCE_CREDIT:';
  private static final String OPTION_C_RETURN_DELETE_RESTORE_MARKER = 'OPTC_RETURN_DELETE_RESTORE:';
  private static final String OPTION_C_RETURN_DEPOSIT_DELETE_RESTORE_MARKER = 'OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT:';
  private static final String OPTION_C_SALE_PATCH_FORCE_CREDIT_MARKER = 'OPTC_SALE_PATCH_FORCE_CREDIT:';
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
  private static final String OPTION_C_RETURN_DEPOSIT_DELETE_USAGE_RESTORE_NOTE_PREFIX = 'OPTC_RETURN_DEPOSIT_DELETE_USAGE_RESTORE:';
  private static final String OPTION_C_RETURN_DEPOSIT_DELETE_USAGE_RESTORE_NOTE_LIKE =
    OPTION_C_RETURN_DEPOSIT_DELETE_USAGE_RESTORE_NOTE_PREFIX + '%';
  private static final String ORIGIN_CREDIT_LL_TOKEN = 'ORIGIN_CREDIT_LL=';
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

  private static String buildRestoreOriginKey(Id orderId, Id subtypeId, Date expiryDate) {
    return String.valueOf(orderId) + '::' + String.valueOf(subtypeId) + '::' + String.valueOf(expiryDate);
  }

  private static Boolean isRestoreOriginCandidate(LoyaltyLedger ledger) {
    if (ledger == null || ledger.EventType != 'Credit' || ledger.TransactionJournal == null) {
      return false;
    }
    String journalSubTypeName = ledger.TransactionJournal.JournalSubType == null ? null : ledger.TransactionJournal.JournalSubType.Name;
    String additionalNotes = ledger.TransactionJournal.AdditionalNotes__c;
    if (journalSubTypeName == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL) {
      return false;
    }
    if (additionalNotes == RESTORE_PURCHASE_ACCRUAL_NOTE ||
        additionalNotes == RESTORE_PROMOTION_ACCRUAL_NOTE ||
        additionalNotes == ECO_POINT_RESTORE_NOTE ||
        isOptionCReturnRestoreCreditNote(additionalNotes)) {
      return false;
    }
    return true;
  }

  private class PaymentSummaryResult {
    Map<Id, Integer> pointByOrderId = new Map<Id, Integer>();
    Map<Id, Integer> couponByOrderId = new Map<Id, Integer>();
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
    if (ledger.TransactionJournal.SaleId__r != null
        && ledger.TransactionJournal.SaleId__r.IsDeleted__c == true) {
      return true;
    }

    if (ledger.TransactionJournal.Order != null
        && ledger.TransactionJournal.Order.IsDeleted__c == true
        && ledger.TransactionJournal.SaleId__r == null) {
      return true;
    }

    String journalTypeName = ledger.TransactionJournal.JournalType != null ? ledger.TransactionJournal.JournalType.Name : null;
    String journalSubTypeName = ledger.TransactionJournal.JournalSubType != null ? ledger.TransactionJournal.JournalSubType.Name : null;
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
        || journalAdditionalNotes == ECO_POINT_RESTORE_NOTE
        || isOptionCReturnRestoreCreditNote(journalAdditionalNotes)) {
      return true;
    }

    if (journalTypeName == JOURNAL_TYPE_NAME_ACCRUAL
        && journalSubTypeName == 'Purchase Accrual'
        && ledger.TransactionJournal.SaleId__r != null
        && ledger.TransactionJournal.SaleId__r.IsReductionOrder__c == true) {
      return true;
    }

    return journalTypeName == JOURNAL_TYPE_NAME_ACCRUAL &&
      ledger.TransactionJournal.RelatedJournalId != null &&
      relatedJournalTypeName == JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL;
  }

  private static Boolean isOptionCReturnRestoreCreditNote(String additionalNotes) {
    if (String.isBlank(additionalNotes) || !additionalNotes.startsWith(OPTION_C_FORCE_CREDIT_NOTE_PREFIX)) {
      return false;
    }
    return additionalNotes.contains(OPTION_C_RETURN_DELETE_RESTORE_MARKER)
      || additionalNotes.contains(OPTION_C_RETURN_DEPOSIT_DELETE_RESTORE_MARKER);
  }

  private static Boolean isReturnDepositDeletePointRestoreHelperNote(String additionalNotes) {
    return additionalNotes == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE
      || (String.isNotBlank(additionalNotes)
        && additionalNotes.startsWith(OPTION_C_RETURN_DEPOSIT_DELETE_USAGE_RESTORE_NOTE_PREFIX));
  }

  private static Id extractOriginCreditLedgerId(String additionalNotes) {
    if (String.isBlank(additionalNotes)) {
      return null;
    }

    Integer tokenIndex = additionalNotes.indexOf(ORIGIN_CREDIT_LL_TOKEN);
    if (tokenIndex < 0) {
      return null;
    }

    Integer valueStart = tokenIndex + ORIGIN_CREDIT_LL_TOKEN.length();
    Integer valueEnd = additionalNotes.indexOf(';', valueStart);
    String originIdText = valueEnd < 0
      ? additionalNotes.substring(valueStart)
      : additionalNotes.substring(valueStart, valueEnd);
    originIdText = originIdText == null ? null : originIdText.trim();

    if (String.isBlank(originIdText) || (originIdText.length() != 15 && originIdText.length() != 18)) {
      return null;
    }

    try {
      return (Id) originIdText;
    } catch (Exception e) {
      return null;
    }
  }

  private static String extractOptionCNoteValue(String additionalNotes, String key) {
    if (String.isBlank(additionalNotes) || String.isBlank(key)) {
      return null;
    }

    Integer startIdx = additionalNotes.indexOf(key);
    if (startIdx < 0) {
      return null;
    }
    startIdx += key.length();
    Integer endIdx = additionalNotes.indexOf(',', startIdx);
    String value = endIdx < 0
      ? additionalNotes.substring(startIdx)
      : additionalNotes.substring(startIdx, endIdx);
    value = value == null ? null : value.trim();
    return String.isBlank(value) ? null : value;
  }

  private static Set<Id> buildOptionCRestoreCreditLLIdsLinkedToDeletedReturn(List<LoyaltyLedger> ledgers) {
    Set<Id> result = new Set<Id>();
    if (ledgers == null || ledgers.isEmpty()) {
      return result;
    }

    Set<Id> sourceTjIds = new Set<Id>();
    Set<String> returnSaleNos = new Set<String>();
    Map<Id, Id> ledgerIdBySourceTjId = new Map<Id, Id>();
    Map<String, Id> ledgerIdByReturnSaleNo = new Map<String, Id>();

    for (LoyaltyLedger ll : ledgers) {
      if (ll == null || ll.Id == null || ll.EventType != 'Credit'
          || ll.TransactionJournal == null
          || !isOptionCReturnRestoreCreditNote(ll.TransactionJournal.AdditionalNotes__c)) {
        continue;
      }

      String note = ll.TransactionJournal.AdditionalNotes__c;
      String sourceTjIdText = extractOptionCNoteValue(note, 'tjId=');
      if (String.isNotBlank(sourceTjIdText)) {
        try {
          Id sourceTjId = (Id) sourceTjIdText;
          sourceTjIds.add(sourceTjId);
          ledgerIdBySourceTjId.put(sourceTjId, ll.Id);
        } catch (Exception e) {
          // ignore malformed legacy marker
        }
      }

      String returnSaleNo = extractOptionCNoteValue(note, 'returnSaleNo=');
      if (String.isNotBlank(returnSaleNo)) {
        returnSaleNos.add(returnSaleNo);
        ledgerIdByReturnSaleNo.put(returnSaleNo, ll.Id);
      }
    }

    if (!sourceTjIds.isEmpty()) {
      for (TransactionJournal sourceTj : [
        SELECT Id, SaleId__r.IsDeleted__c
        FROM TransactionJournal
        WHERE Id IN :sourceTjIds
      ]) {
        if (sourceTj.SaleId__r != null && sourceTj.SaleId__r.IsDeleted__c == true) {
          Id restoreLLId = ledgerIdBySourceTjId.get(sourceTj.Id);
          if (restoreLLId != null) {
            result.add(restoreLLId);
          }
        }
      }
    }

    if (!returnSaleNos.isEmpty()) {
      for (Order returnOrder : [
        SELECT SaleNo__c, IsDeleted__c
        FROM Order
        WHERE SaleNo__c IN :returnSaleNos
      ]) {
        if (returnOrder.IsDeleted__c == true) {
          Id restoreLLId = ledgerIdByReturnSaleNo.get(returnOrder.SaleNo__c);
          if (restoreLLId != null) {
            result.add(restoreLLId);
          }
        }
      }
    }

    return result;
  }

  private static Map<Id, List<OriginPortion>> buildOptionCRestoreOriginPortionsBySourceTj(
      Id memberId,
      List<LoyaltyLedger> ledgers,
      Boolean expandToFinalOrigin
  ) {
    Map<Id, List<OriginPortion>> result = new Map<Id, List<OriginPortion>>();
    if (memberId == null || ledgers == null || ledgers.isEmpty()) {
      return result;
    }

    Set<Id> sourceTjIds = new Set<Id>();
    Map<Id, Id> restoreLLIdBySourceTjId = new Map<Id, Id>();
    Map<Id, Integer> restorePointsByLLId = new Map<Id, Integer>();
    for (LoyaltyLedger ll : ledgers) {
      if (ll == null || ll.Id == null || ll.EventType != 'Credit'
          || ll.TransactionJournal == null
          || !isOptionCReturnRestoreCreditNote(ll.TransactionJournal.AdditionalNotes__c)
          || ll.Points == null) {
        continue;
      }

      String sourceTjIdText = extractOptionCNoteValue(ll.TransactionJournal.AdditionalNotes__c, 'tjId=');
      if (String.isBlank(sourceTjIdText)) {
        continue;
      }
      try {
        Id sourceTjId = (Id) sourceTjIdText;
        sourceTjIds.add(sourceTjId);
        restoreLLIdBySourceTjId.put(sourceTjId, ll.Id);
        restorePointsByLLId.put(ll.Id, ll.Points.abs().intValue());
      } catch (Exception e) {
        // ignore malformed legacy marker
      }
    }

    if (sourceTjIds.isEmpty()) {
      return result;
    }

    Map<Id, Id> restoreLLIdByReturnOrderId = new Map<Id, Id>();
    for (TransactionJournal sourceTj : [
      SELECT Id, SaleId__c
      FROM TransactionJournal
      WHERE Id IN :sourceTjIds
    ]) {
      Id restoreLLId = restoreLLIdBySourceTjId.get(sourceTj.Id);
      if (restoreLLId != null && sourceTj.SaleId__c != null) {
        restoreLLIdByReturnOrderId.put(sourceTj.SaleId__c, restoreLLId);
      }
    }

    if (restoreLLIdByReturnOrderId.isEmpty()) {
      return result;
    }

    Map<Id, List<OriginPortion>> rawPortionsByRestoreLLId = new Map<Id, List<OriginPortion>>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT CreditLoyaltyLedgerId, Points, DebitLoyaltyLedger.TransactionJournal.SaleId__c
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
        AND ActionType = 'CreditCancellation'
        AND DebitLoyaltyLedger.TransactionJournal.SaleId__c IN :restoreLLIdByReturnOrderId.keySet()
        AND DebitLoyaltyLedger.TransactionJournal.JournalType.Name = :JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      LIMIT 50000
    ]) {
      if (llt.CreditLoyaltyLedgerId == null || llt.Points == null
          || llt.DebitLoyaltyLedger == null
          || llt.DebitLoyaltyLedger.TransactionJournal == null
          || llt.DebitLoyaltyLedger.TransactionJournal.SaleId__c == null) {
        continue;
      }
      Id restoreLLId = restoreLLIdByReturnOrderId.get(llt.DebitLoyaltyLedger.TransactionJournal.SaleId__c);
      if (restoreLLId == null) {
        continue;
      }
      if (!rawPortionsByRestoreLLId.containsKey(restoreLLId)) {
        rawPortionsByRestoreLLId.put(restoreLLId, new List<OriginPortion>());
      }
      rawPortionsByRestoreLLId.get(restoreLLId).add(
        new OriginPortion(llt.CreditLoyaltyLedgerId, llt.Points.abs().intValue())
      );
    }

    for (Id restoreLLId : rawPortionsByRestoreLLId.keySet()) {
      Integer restorePoints = restorePointsByLLId.containsKey(restoreLLId)
        ? restorePointsByLLId.get(restoreLLId)
        : 0;
      result.put(restoreLLId, capOriginPortions(rawPortionsByRestoreLLId.get(restoreLLId), restorePoints));
    }

    if (expandToFinalOrigin != true) {
      return result;
    }

    for (Integer i = 0; i < result.size(); i++) {
      Boolean changed = false;
      Map<Id, List<OriginPortion>> nextResult = new Map<Id, List<OriginPortion>>();
      for (Id restoreLLId : result.keySet()) {
        List<OriginPortion> expanded = new List<OriginPortion>();
        List<OriginPortion> portions = result.get(restoreLLId);
        if (portions == null) {
          nextResult.put(restoreLLId, portions);
          continue;
        }
        for (OriginPortion p : portions) {
          if (p == null || p.originCreditLLId == null || p.points == null || p.points <= 0) {
            continue;
          }
          if (result.containsKey(p.originCreditLLId)) {
            expanded.addAll(capOriginPortions(result.get(p.originCreditLLId), p.points));
            changed = true;
          } else {
            expanded.add(p);
          }
        }
        Integer restorePoints = restorePointsByLLId.containsKey(restoreLLId)
          ? restorePointsByLLId.get(restoreLLId)
          : 0;
        nextResult.put(restoreLLId, capOriginPortions(expanded, restorePoints));
      }
      result = nextResult;
      if (!changed) {
        break;
      }
    }

    return result;
  }

  private static List<OriginPortion> capOriginPortions(List<OriginPortion> rawPortions, Integer maxPoints) {
    List<OriginPortion> result = new List<OriginPortion>();
    if (rawPortions == null || rawPortions.isEmpty() || maxPoints == null || maxPoints <= 0) {
      return result;
    }

    Integer remaining = maxPoints;
    for (OriginPortion p : rawPortions) {
      if (p == null || p.originCreditLLId == null || p.points == null || p.points <= 0 || remaining <= 0) {
        continue;
      }
      Integer portionPoints = Math.min(p.points, remaining);
      result.add(new OriginPortion(p.originCreditLLId, portionPoints));
      remaining -= portionPoints;
    }
    return result;
  }

  private static List<OriginPortion> scaleOriginPortions(List<OriginPortion> rawPortions, Integer targetPoints) {
    List<OriginPortion> result = new List<OriginPortion>();
    if (rawPortions == null || rawPortions.isEmpty() || targetPoints == null || targetPoints <= 0) {
      return result;
    }

    Integer total = 0;
    for (OriginPortion p : rawPortions) {
      if (p != null && p.originCreditLLId != null && p.points != null && p.points > 0) {
        total += p.points;
      }
    }
    if (total <= 0) {
      return result;
    }

    if (targetPoints >= total) {
      return coalesceOriginPortions(capOriginPortions(rawPortions, targetPoints));
    }

    Integer allocated = 0;
    Integer lastIdx = rawPortions.size() - 1;
    for (Integer i = 0; i < rawPortions.size(); i++) {
      OriginPortion p = rawPortions[i];
      if (p == null || p.originCreditLLId == null || p.points == null || p.points <= 0) {
        continue;
      }
      Integer share;
      if (i == lastIdx) {
        share = targetPoints - allocated;
        if (share < 0) share = 0;
      } else {
        Long numerator = (Long) targetPoints * (Long) p.points;
        share = (Integer) (numerator / (Long) total);
      }
      allocated += share;
      if (share > 0) {
        result.add(new OriginPortion(p.originCreditLLId, share));
      }
    }
    return coalesceOriginPortions(result);
  }

  private static List<OriginPortion> coalesceOriginPortions(List<OriginPortion> rawPortions) {
    List<OriginPortion> result = new List<OriginPortion>();
    if (rawPortions == null || rawPortions.isEmpty()) {
      return result;
    }

    Map<Id, Integer> pointsByOrigin = new Map<Id, Integer>();
    List<Id> originOrder = new List<Id>();
    for (OriginPortion p : rawPortions) {
      if (p == null || p.originCreditLLId == null || p.points == null || p.points <= 0) {
        continue;
      }
      if (!pointsByOrigin.containsKey(p.originCreditLLId)) {
        originOrder.add(p.originCreditLLId);
        pointsByOrigin.put(p.originCreditLLId, 0);
      }
      pointsByOrigin.put(p.originCreditLLId, pointsByOrigin.get(p.originCreditLLId) + p.points);
    }
    for (Id originCreditLLId : originOrder) {
      Integer points = pointsByOrigin.get(originCreditLLId);
      if (points != null && points > 0) {
        result.add(new OriginPortion(originCreditLLId, points));
      }
    }
    return result;
  }

  private static Map<Id, List<OriginPortion>> expandOriginPortionsToFinalOrigin(
      Map<Id, List<OriginPortion>> basePortions,
      Map<Id, List<OriginPortion>> restoreOriginPortions
  ) {
    Map<Id, List<OriginPortion>> result = new Map<Id, List<OriginPortion>>();
    if (basePortions == null || basePortions.isEmpty()) {
      return result;
    }

    for (Id sourceLLId : basePortions.keySet()) {
      result.put(sourceLLId, coalesceOriginPortions(basePortions.get(sourceLLId)));
    }

    Integer maxIterations = result.size() + (restoreOriginPortions == null ? 0 : restoreOriginPortions.size()) + 1;
    for (Integer i = 0; i < maxIterations; i++) {
      Boolean changed = false;
      Map<Id, List<OriginPortion>> nextResult = new Map<Id, List<OriginPortion>>();
      for (Id sourceLLId : result.keySet()) {
        List<OriginPortion> expanded = new List<OriginPortion>();
        List<OriginPortion> portions = result.get(sourceLLId);
        if (portions == null || portions.isEmpty()) {
          nextResult.put(sourceLLId, portions);
          continue;
        }

        for (OriginPortion p : portions) {
          if (p == null || p.originCreditLLId == null || p.points == null || p.points <= 0) {
            continue;
          }

          List<OriginPortion> childPortions = null;
          if (restoreOriginPortions != null && restoreOriginPortions.containsKey(p.originCreditLLId)) {
            childPortions = restoreOriginPortions.get(p.originCreditLLId);
          } else if (p.originCreditLLId != sourceLLId && result.containsKey(p.originCreditLLId)) {
            childPortions = result.get(p.originCreditLLId);
          }

          if (childPortions != null && !childPortions.isEmpty()) {
            expanded.addAll(scaleOriginPortions(childPortions, p.points));
            changed = true;
          } else {
            expanded.add(p);
          }
        }
        nextResult.put(sourceLLId, coalesceOriginPortions(expanded));
      }
      result = nextResult;
      if (!changed) {
        break;
      }
    }

    return result;
  }

  private static Boolean isOptionCSalePatchForceCreditNote(String additionalNotes) {
    return String.isNotBlank(additionalNotes)
      && additionalNotes.startsWith(OPTION_C_FORCE_CREDIT_NOTE_PREFIX)
      && additionalNotes.contains(OPTION_C_SALE_PATCH_FORCE_CREDIT_MARKER);
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
        AND (AdditionalNotes__c = NULL
        OR (NOT AdditionalNotes__c LIKE :OPTION_C_RETURN_DEPOSIT_DELETE_USAGE_RESTORE_NOTE_LIKE))
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

  private static PaymentSummaryResult buildPaymentSummaryMaps(Set<Id> orderIds) {
    PaymentSummaryResult result = new PaymentSummaryResult();

    if (orderIds == null || orderIds.isEmpty()) {
      return result;
    }

    Set<String> paymentMethods = new Set<String>();
    paymentMethods.addAll(POINT_PAYMENT_METHODS);
    paymentMethods.addAll(COUPON_PAYMENT_METHODS);

    for (TransactionJournal tj : [
      SELECT OrderId, SaleId__c, TransactionAmount, PaymentMethod, JournalSubType.Name, AdditionalNotes__c
      FROM TransactionJournal
      WHERE
        (OrderId IN :orderIds OR SaleId__c IN :orderIds)
        AND TransactionAmount != NULL
        AND PaymentMethod IN :paymentMethods
        AND IsDeleted__c = FALSE
    ]) {
      Integer amount = tj.TransactionAmount == null ? 0 : tj.TransactionAmount.abs().intValue();
      String journalSubTypeName = tj.JournalSubType != null ? tj.JournalSubType.Name : null;
      Boolean isExcludedSubType = journalSubTypeName != null && EXCLUDED_PAYMENT_JOURNAL_SUBTYPES.contains(journalSubTypeName);
      Boolean isPointRestoreHelper = isReturnDepositDeletePointRestoreHelperNote(tj.AdditionalNotes__c)
          || tj.AdditionalNotes__c == ADDITIONAL_NOTE_FULL_RETURN_ECO_POINT_CANCEL;

      Map<Id, Integer> targetMap;
      Integer signedAmount = 0;
      if (POINT_PAYMENT_METHODS.contains(tj.PaymentMethod)) {
        if (isExcludedSubType || isPointRestoreHelper) {
          continue;
        }
        targetMap = result.pointByOrderId;
        signedAmount = amount;
      } else if (COUPON_PAYMENT_METHODS.contains(tj.PaymentMethod)) {
        targetMap = result.couponByOrderId;
        signedAmount = isExcludedSubType ? 0 : amount;
      } else {
        continue;
      }

      if (tj.OrderId != null && orderIds.contains(tj.OrderId)) {
        Integer prev = targetMap.containsKey(tj.OrderId) ? targetMap.get(tj.OrderId) : 0;
        targetMap.put(tj.OrderId, prev + signedAmount);
      }

      if (tj.SaleId__c != null && tj.SaleId__c != tj.OrderId && orderIds.contains(tj.SaleId__c)) {
        Integer prev = targetMap.containsKey(tj.SaleId__c) ? targetMap.get(tj.SaleId__c) : 0;
        targetMap.put(tj.SaleId__c, prev + signedAmount);
      }
    }

    for (Id orderId : new List<Id>(result.couponByOrderId.keySet())) {
      result.couponByOrderId.put(orderId, Math.max(0, result.couponByOrderId.get(orderId)));
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

    // [Pull-In Order Alias Fix 2026-05-08] 주문→판매 끌어오기 케이스 OrderId 비대칭 보정.
    //   배경: 반품으로 포인트 사용 취소 시 Point Redeem Cancel TJ.OrderId 는 originalOrderId
    //         (= 판매 Id) 로 박힌다 (GdReturnDepositServiceImpl:200). 그러나 주문에서 사용 후
    //         판매로 끌어온 사용 Debit TJ 의 OrderId 는 주문 Id 그대로 유지되어 (TJ.SaleId__c
    //         에만 판매 Id 가 추가) 차감 로직 (debitOrderId = Debit LL.TJ.OrderId = 주문 Id) 이
    //         orderRedeemCancelMap[주문 Id] 를 조회하면 0 → effectiveCancel = 0 → PT_USE 차감
    //         미발생.
    //   해결: Cancel TJ 가 박힌 OrderId (= 판매 Id) 를 SaleId__c 로 가지고 있는 사용 Debit TJ 의
    //         OrderId (= 주문 Id) 를 별칭 키로 동일 취소액 등록. 차감 로직이 어느 키로 조회해도
    //         매칭됨. 4개 소비 지점 (L820 / L1098 / L2587 / L2701) 모두 자동 적용.
    //   안전성:
    //     - Flag OFF 시 기존 동작 그대로 (회귀 안전).
    //     - OrderId != SaleId__c 가드 → 판매 직접 사용 케이스 (OrderId=SaleId__c=판매 Id) 영향 0.
    //     - SaleId__c IN cancelOrderIds 가드 → Cancel TJ 가 실제로 가리키는 판매 만 대상.
    //     - JournalSubType.Name = Point Debit 가드 → 사용 TJ 만 매칭 (적립/취소/쿠폰 영향 0).
    //     - IsDeleted__c = FALSE → 삭제된 사용 TJ 제외.
    //     - 별칭 키 등록 시 기존 값보다 클 때만 덮어씀 → 다중 시나리오 보수적 안전.
    //     - result 가 비었으면 추가 SOQL 실행 안 함 (Cancel TJ 없는 회원 영향 0).
    if (!result.isEmpty() && GdFeatureFlag.isEnabled('OrderRedeemCancelMap_PullInAlias')) {
      Set<Id> cancelOrderIds = new Set<Id>(result.keySet());
      Map<Id, Set<Id>> aliasOrderIdsBySaleId = new Map<Id, Set<Id>>();
      for (TransactionJournal tj : [
        SELECT OrderId, SaleId__c
        FROM TransactionJournal
        WHERE MemberId = :memberId
          AND SaleId__c IN :cancelOrderIds
          AND OrderId != NULL
          AND JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_DEBIT
          AND IsDeleted__c = FALSE
        LIMIT 50000
      ]) {
        if (tj.SaleId__c == null || tj.OrderId == null) {
          continue;
        }
        // SOQL 은 두 필드 간 비교 (OrderId != SaleId__c) 미지원 → Apex 에서 필터.
        // 판매 직접 사용 케이스 (OrderId = SaleId__c = 판매 Id) 는 별칭 등록 불필요.
        if (tj.OrderId == tj.SaleId__c) {
          continue;
        }
        if (!aliasOrderIdsBySaleId.containsKey(tj.SaleId__c)) {
          aliasOrderIdsBySaleId.put(tj.SaleId__c, new Set<Id>());
        }
        aliasOrderIdsBySaleId.get(tj.SaleId__c).add(tj.OrderId);
      }
      for (Id saleId : aliasOrderIdsBySaleId.keySet()) {
        Integer cancelAmount = result.get(saleId);
        if (cancelAmount == null) {
          continue;
        }
        for (Id aliasOrderId : aliasOrderIdsBySaleId.get(saleId)) {
          Integer prev = result.containsKey(aliasOrderId) ? result.get(aliasOrderId) : 0;
          if (cancelAmount > prev) {
            result.put(aliasOrderId, cancelAmount);
          }
        }
      }
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
      // [Active Only Fix 2026-05-07] 삭제된 Cancel Credit (TJ.IsDeleted=true) 은 매핑 대상 제외.
      //   배경: 반품 입금 삭제 등으로 비활성화된 Cancel Credit 은 회원 잔액에 영향 없는 과거 흔적.
      //         포함 시 portions 환불 합이 effectiveCancel 과 불일치하여 정합 검증 실패 → fallback 비례 분배
      //         → LL 별 PT_USE 부정확 (회원 193001000334 케이스).
      //   안전성: TJ.IsDeleted=true 케이스가 없는 회원은 영향 0 (S1/S2/S4/S5 회귀 안전).
      if (ll.EventType == 'Credit'
          && ll.IsDeleted == false
          && ll.TransactionJournal != null
          && ll.TransactionJournal.IsDeleted__c == false
          && ll.TransactionJournal.OrderId != null
          && ll.TransactionJournal.JournalSubType != null
          && ll.TransactionJournal.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL) {
        Id directOriginCreditLLId = extractOriginCreditLedgerId(ll.AdditionalNotes);
        if (directOriginCreditLLId != null) {
          result.put(ll.Id, directOriginCreditLLId);
          continue;
        }
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
    //
    //   [v3 paradigm 일반 사용 취소 Fix 2026-05-05]
    //     추가 배경: 위의 2026-05-03 fix 는 반품 입금 삭제 케이스 (RESTORE_NOTE 마커 부착) 만 커버함.
    //               일반 입금 삭제 → 사용 취소 흐름에서는 원 Debit TJ 가 IsDeleted=FALSE 이고 마커도 없음.
    //               → 매칭 실패 → NO_SAL_SAVE 보정 미진입 → Cancel Credit LL 의 TJ.Order.SaleNo (= 사용 취소된 판매번호) 그대로 노출.
    //     증상: 마이그레이션 적립 (TJ.OrderId=null) 회원이 사용 → 취소 → 재사용 시 재사용 행의
    //           "적립 판매번호" 칸에 "사용 취소된 판매번호" 가 잘못 노출 (회원 212501600243 케이스).
    //     해결: Feature Flag 'RedeemCancelOriginMap_IncludeV3Active' ON 시 IsDeleted/RESTORE_NOTE 조건 제거.
    //           → v3 일반 사용 취소 케이스도 매칭 → NO_SAL_SAVE 보정 진입 가능.
    //     안전성: 매핑 알고리즘 (가장 큰 점유 단일 선택) 은 동일. 매핑 후보가 늘어나도 결과는 단일.
    //           PT_USE 이월 (line 569-570) 은 [creditLedgerIds 가드] 로 표시 대상에만 작동 → 회원 도움창 표시 정확도만 향상.
    //           Flag OFF 시 기존 SOQL 그대로 작동 (회귀 영향 없음).
    Map<Id, Map<Id, Map<Id, Integer>>> ptsByOrderBySubtypeByCredit = new Map<Id, Map<Id, Map<Id, Integer>>>();
    Boolean includeV3Active = GdFeatureFlag.isEnabled('RedeemCancelOriginMap_IncludeV3Active');
    List<AggregateResult> aggList;
    if (includeV3Active) {
      // Flag ON: IsDeleted/RESTORE_NOTE 조건 제거 — v3 일반 사용 취소 케이스 포함
      aggList = [
        SELECT DebitLoyaltyLedger.TransactionJournal.OrderId orderId,
               CreditLoyaltyLedgerId creditId,
               CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId subtypeId,
               SUM(Points) totalPts
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :memberId
          AND ActionType = 'Debit'
          AND DebitLoyaltyLedger.TransactionJournal.OrderId IN :targetOrderIds
          AND DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_DEBIT
        GROUP BY DebitLoyaltyLedger.TransactionJournal.OrderId,
                 CreditLoyaltyLedgerId,
                 CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId
        LIMIT 50000
      ];
    } else {
      // Flag OFF: 기존 SOQL 그대로 (회귀 영향 없음)
      aggList = [
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
      ];
    }
    for (AggregateResult ar : aggList) {
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
   * [Precise Origin Mapping 2026-05-06] Cancel Credit (Point Redeem Cancel) → 다중 origin 분배 매핑.
   *
   * 배경:
   *   기존 buildRedeemCancelCreditOriginMap 은 Cancel Credit 별로 "최다 점유 단일 Credit" 만 origin 으로 매핑.
   *   다중 적립 (예: LL_A 60K + LL_B 40K) 사용 후 환불 시 한쪽만 origin 으로 잡혀 다른 origin 누락.
   *   회원도움창 PT_USE / DT_SAVE / NO_SAL_SAVE 표시가 일부 부정확 (특히 다중 ExpiryDate 적립).
   *
   * 알고리즘:
   *   1. Cancel Credit LL 들 (Point Redeem Cancel) 수집 — (Id, OrderId, SubType, ExpiryDate, Points) 보존
   *   2. 각 Cancel Credit 의 OrderId 의 사용 LLT 들 (CreditId, SubType, ExpiryDate, Points) 집계
   *      Cancel Credit 의 SubType 와 동일한 사용 LLT 만 후보로 사용
   *   3. 각 Cancel Credit 별로 ExpiryDate 매칭 우선 → 매칭된 후보가 1개면 100% 분배
   *      매칭된 후보가 여러 개면 사용 Points 비례 분배
   *      매칭 실패 시 fallback (기존 buildRedeemCancelCreditOriginMap 의 단일 최다 점유 결과 사용)
   *
   * 반환: Map<Cancel Credit LL Id, List<OriginPortion>>
   *       각 OriginPortion 은 (origin Credit LL Id, 분배 Points)
   *
   * 호출 위치: Flag 'RedeemCancelOriginMap_Precise' ON 시 회원도움창 빌드 흐름에서 활용 (Phase 2~4)
   *
   * 안전성:
   *   - LMS 데이터 안 건드림 (조회만)
   *   - 매핑 결과 데이터 구조만 다름 (Map<Id, List<OriginPortion>>)
   *   - 호출처가 활용 안 하면 영향 없음 (Phase 1 단계)
   *   - Fallback 으로 기존 단일 매핑 결과 사용 → 정확히 매칭 안 되는 케이스도 기존 동작 보장
   */
  private static Map<Id, List<OriginPortion>> buildRedeemCancelCreditOriginPortions(
    Id memberId,
    List<LoyaltyLedger> ledgers,
    Map<Id, Id> fallbackSingleMap
  ) {
    Map<Id, List<OriginPortion>> result = new Map<Id, List<OriginPortion>>();
    if (memberId == null || ledgers == null || ledgers.isEmpty()) {
      return result;
    }

    // [1] Cancel Credit LL 수집 (Id, OrderId, SubType, ExpiryDate, Points)
    // [Active Only Fix 2026-05-07] 삭제된 Cancel Credit (TJ.IsDeleted=true 또는 LL.IsDeleted=true) 제외.
    //   배경: 반품 입금 삭제로 비활성화된 Cancel Credit 도 매핑에 들어가면 portions 환불 합이 부풀려져
    //         effectiveCancel 과 불일치 → 정합 검증 실패 → fallback 비례 분배 → PT_USE 부정확.
    //   회원 193001000334 / SAL202605070214: 삭제된 Cancel Credit 50,410(47cP+47cQ)+30,000(46TU)
    //         이 portions 환불 합 100K 으로 잡혀 effectiveCancel 40K 와 불일치 → 정합 깨짐.
    //   수정: Cancel Credit 수집 시 활성 (LL.IsDeleted=false AND TJ.IsDeleted=false) 만 포함.
    Map<Id, Id> cancelLLToOrder = new Map<Id, Id>();
    Map<Id, Id> cancelLLToSubtype = new Map<Id, Id>();
    Map<Id, Date> cancelLLToExpiry = new Map<Id, Date>();
    Map<Id, Integer> cancelLLToPoints = new Map<Id, Integer>();
    Set<Id> targetOrderIds = new Set<Id>();
    for (LoyaltyLedger ll : ledgers) {
      if (ll.EventType == 'Credit'
          && ll.IsDeleted == false
          && ll.TransactionJournal != null
          && ll.TransactionJournal.IsDeleted__c == false
          && ll.TransactionJournal.OrderId != null
          && ll.TransactionJournal.JournalSubType != null
          && ll.TransactionJournal.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL) {
        Id directOriginCreditLLId = extractOriginCreditLedgerId(ll.AdditionalNotes);
        Integer cancelPoints = ll.Points == null ? 0 : ll.Points.abs().intValue();
        if (directOriginCreditLLId != null && cancelPoints > 0) {
          result.put(ll.Id, new List<OriginPortion>{ new OriginPortion(directOriginCreditLLId, cancelPoints) });
          continue;
        }
        cancelLLToOrder.put(ll.Id, ll.TransactionJournal.OrderId);
        cancelLLToSubtype.put(ll.Id, ll.LoyaltyPgmCrcySubtypeId);
        cancelLLToExpiry.put(ll.Id, ll.ExpiryDate);
        cancelLLToPoints.put(ll.Id, cancelPoints);
        targetOrderIds.add(ll.TransactionJournal.OrderId);
      }
    }
    if (targetOrderIds.isEmpty()) {
      return result;
    }

    // [2] 사용 LLT 집계 — (OrderId, CreditId, SubType, ExpiryDate) → Points 합
    //   Flag 'RedeemCancelOriginMap_IncludeV3Active' 와 동일한 SOQL 정책 사용 (v3 paradigm 호환)
    Boolean includeV3Active = GdFeatureFlag.isEnabled('RedeemCancelOriginMap_IncludeV3Active');
    List<AggregateResult> aggList;
    if (includeV3Active) {
      aggList = [
        SELECT DebitLoyaltyLedger.TransactionJournal.OrderId orderId,
               CreditLoyaltyLedgerId creditId,
               CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId subtypeId,
               CreditLoyaltyLedger.ExpiryDate expiryDate,
               SUM(Points) totalPts
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :memberId
          AND ActionType = 'Debit'
          AND DebitLoyaltyLedger.TransactionJournal.OrderId IN :targetOrderIds
          AND DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_DEBIT
        GROUP BY DebitLoyaltyLedger.TransactionJournal.OrderId,
                 CreditLoyaltyLedgerId,
                 CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId,
                 CreditLoyaltyLedger.ExpiryDate
        LIMIT 50000
      ];
    } else {
      aggList = [
        SELECT DebitLoyaltyLedger.TransactionJournal.OrderId orderId,
               CreditLoyaltyLedgerId creditId,
               CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId subtypeId,
               CreditLoyaltyLedger.ExpiryDate expiryDate,
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
                 CreditLoyaltyLedger.LoyaltyPgmCrcySubtypeId,
                 CreditLoyaltyLedger.ExpiryDate
        LIMIT 50000
      ];
    }

    // (OrderId, SubType, ExpiryDate) → Map<CreditId, Points> 자료구조
    Map<String, Map<Id, Integer>> usageByOrderSubtypeExpiry = new Map<String, Map<Id, Integer>>();
    for (AggregateResult ar : aggList) {
      Id oid = (Id) ar.get('orderId');
      Id cid = (Id) ar.get('creditId');
      Id sid = (Id) ar.get('subtypeId');
      Date expDate = (Date) ar.get('expiryDate');
      if (oid == null || cid == null) continue;
      Integer pts = ar.get('totalPts') == null ? 0 : ((Decimal) ar.get('totalPts')).abs().intValue();
      String key = String.valueOf(oid) + '|' + String.valueOf(sid) + '|' + String.valueOf(expDate);
      if (!usageByOrderSubtypeExpiry.containsKey(key)) {
        usageByOrderSubtypeExpiry.put(key, new Map<Id, Integer>());
      }
      Map<Id, Integer> creds = usageByOrderSubtypeExpiry.get(key);
      Integer prev = creds.containsKey(cid) ? creds.get(cid) : 0;
      creds.put(cid, prev + pts);
    }

    // [3] 각 Cancel Credit 별로 분배
    for (Id cancelId : cancelLLToOrder.keySet()) {
      Id oid = cancelLLToOrder.get(cancelId);
      Id ccSid = cancelLLToSubtype.get(cancelId);
      Date ccExp = cancelLLToExpiry.get(cancelId);
      Integer ccPts = cancelLLToPoints.get(cancelId);
      if (ccPts == null || ccPts <= 0) continue;

      // ExpiryDate + SubType 매칭 우선
      String exactKey = String.valueOf(oid) + '|' + String.valueOf(ccSid) + '|' + String.valueOf(ccExp);
      Map<Id, Integer> candidates = usageByOrderSubtypeExpiry.get(exactKey);

      List<OriginPortion> portions = new List<OriginPortion>();
      if (candidates != null && !candidates.isEmpty()) {
        // 매칭된 후보 — Points 비례 분배 (사용량 비율)
        Integer totalCandidatePts = 0;
        for (Integer p : candidates.values()) totalCandidatePts += (p == null ? 0 : p);
        if (totalCandidatePts > 0) {
          Integer allocated = 0;
          List<Id> candidateIds = new List<Id>(candidates.keySet());
          for (Integer i = 0; i < candidateIds.size(); i++) {
            Id origCid = candidateIds[i];
            Integer origPts = candidates.get(origCid) == null ? 0 : candidates.get(origCid);
            Integer portionPts;
            if (i == candidateIds.size() - 1) {
              // 마지막 — round-off 보정
              portionPts = ccPts - allocated;
              if (portionPts < 0) portionPts = 0;
            } else {
              Long num = (Long) ccPts * (Long) origPts;
              portionPts = (Integer) (num / (Long) totalCandidatePts);
            }
            if (portionPts > 0) {
              portions.add(new OriginPortion(origCid, portionPts));
              allocated += portionPts;
            }
          }
        }
      }

      // Fallback — 매칭 실패 시 기존 단일 매핑 결과 사용
      if (portions.isEmpty() && fallbackSingleMap != null && fallbackSingleMap.containsKey(cancelId)) {
        Id fallbackOrigin = fallbackSingleMap.get(cancelId);
        if (fallbackOrigin != null) {
          portions.add(new OriginPortion(fallbackOrigin, ccPts));
        }
      }

      if (!portions.isEmpty()) {
        result.put(cancelId, portions);
      }
    }

    return result;
  }

  // [Precise Origin Mapping 2026-05-06] Cancel Credit 의 origin 분배 한 단위
  private class OriginPortion {
    Id originCreditLLId;
    Integer points;
    OriginPortion(Id originCreditLLId, Integer points) {
      this.originCreditLLId = originCreditLLId;
      this.points = points;
    }
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
    Map<Id, Id> redeemCancelCreditOriginMap,
    Map<Id, List<OriginPortion>> redeemCancelCreditOriginPortions,
    Map<Id, Id> cancelLLToOrderId,
    Map<Id, List<OriginPortion>> hiddenRestoreCreditOriginPortions
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

    // [Raw Trace Mode 2026-05-05] Flag ON 시 raw LLT/LL 합산으로 PT_USE 계산.
    //   배경: 기존 비례 감산은 (orderUsed × netRate / orderTotalUsed) 추정 분배 — round-off 누적 + 다중 SubType 분포에서 부정확.
    //   raw 식: (a) X 활성 Debit + (b) origin=X Cancel Credit 활성 Debit
    //         - (c) origin=X Cancel Credit Points - (d) origin=(Cancel-of-X) Cancel Credit Points → clamp 0
    //   안전성: Flag OFF 시 기존 비례 감산 그대로 (회귀 영향 없음).
    if (GdFeatureFlag.isEnabled('AccrualPtUse_RawTraceMode')) {
      return buildAccrualUsedPointMap_Raw(memberId, creditLedgerIds,
          orderRedeemCancelMap, orderPointUsedMap, orderDeletedDebitMap, redeemCancelCreditOriginMap,
          redeemCancelCreditOriginPortions, cancelLLToOrderId, hiddenRestoreCreditOriginPortions);
    }

    // 1단계: Credit LL × Order 별 Debit 사용량 집계 (삭제된 Debit 제외)
    //   [PT_USE Round-off Fix 2026-05-05] 가산을 두 번 (1단계 자기 사용 / 3단계 Cancel 이월) 나눠 하면서
    //   같은 Order 의 여러 (Credit, Order) 그룹마다 정수 나눗셈 round-off 가 누적되어 합계가
    //   (orderUsed - effectiveCancel) 미만으로 떨어짐 (사용자 케이스 19000 → 18998).
    //   해결: 두 단계 raw 결과를 (originCid, debitOrderId) 차원 으로 모두 모아두고,
    //         debitOrderId 별 그룹 마지막에 round-off 보정. originCid 는 Cancel Credit 인 경우 매핑된 원 Credit.
    //
    //   추가 표기:
    //     pendingByOrder: debitOrderId → List<{ creditId, rawPts }>
    //     orderRawTotal:  debitOrderId → 그 Order 에서 활성 (origin Credit 별) raw 합
    Map<Id, List<RawAccrualUsage>> pendingByOrder = new Map<Id, List<RawAccrualUsage>>();
    Map<Id, Integer> orderRawTotal = new Map<Id, Integer>();

    // [PT_USE Round-off Fix 2026-05-05] Cancel Credit 자체는 1단계 SOQL 제외 — 3단계에서 origin Credit 으로 이월되므로
    //   그렇지 않으면 같은 사용분이 (1단계: Cancel 자기) + (3단계: origin 매핑) 으로 두 번 카운트되어 합계 초과 (회원 123002600463 케이스).
    Set<Id> firstStageCreditIds = new Set<Id>(creditLedgerIds);
    if (redeemCancelCreditOriginMap != null && !redeemCancelCreditOriginMap.isEmpty()) {
      firstStageCreditIds.removeAll(redeemCancelCreditOriginMap.keySet());
    }

    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId,
             DebitLoyaltyLedger.TransactionJournal.OrderId orderId,
             SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :firstStageCreditIds
        AND ActionType = 'Debit'
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        // [scn5 R1-10 Fix 2026-04-27] 반품 입금 삭제 재차감 Debit LLT 제외
        //   v3 paradigm 으로 원본 Debit trace 가 보존된 상태에서 재차감 trace 가 함께 합산되면
        //   원 적립 Credit 의 PT_USE 가 두 배가 되는 문제(시나리오5 의 판매1 구매포인트 8000) 해결.
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR (NOT DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c LIKE :OPTION_C_RETURN_DEPOSIT_DELETE_USAGE_RESTORE_NOTE_LIKE))
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
      if (points <= 0) {
        continue;
      }
      if (!pendingByOrder.containsKey(orderId)) {
        pendingByOrder.put(orderId, new List<RawAccrualUsage>());
      }
      pendingByOrder.get(orderId).add(new RawAccrualUsage(creditId, points));
      Integer prev = orderRawTotal.containsKey(orderId) ? orderRawTotal.get(orderId) : 0;
      orderRawTotal.put(orderId, prev + points);
    }

    // [2026-04-25 추가 Fix] 3단계 합치기: Point Redeem Cancel Credit 사용분을 "원 Credit" 의 PT_USE 에 이월.
    //   - redeemCancelCreditOriginMap 이 비어있으면 SOQL 실행 없이 조기 스킵 (S1/S2 보호)
    //   - Cancel Credit 은 AccrualHistoryList 에서 숨김 처리되므로 그 자체의 PT_USE 는 집계 대상 아님
    //   - 대신 그 Cancel Credit 을 사용한 Debit LLT 의 Points 를 매핑된 원 Credit 에 가산하여
    //     MD 의 "단일 로우" 기대를 만족시킴
    if (!redeemCancelCreditOriginMap.isEmpty()) {
      Set<Id> cancelCreditIds = redeemCancelCreditOriginMap.keySet();
      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId cancelCreditId,
               DebitLoyaltyLedger.TransactionJournal.OrderId debitOrderId,
               SUM(Points) totalPts
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :memberId
          AND CreditLoyaltyLedgerId IN :cancelCreditIds
          AND ActionType = 'Debit'
          AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        GROUP BY CreditLoyaltyLedgerId, DebitLoyaltyLedger.TransactionJournal.OrderId
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
        Integer rawAdd = ar.get('totalPts') == null ? 0 : ((Decimal) ar.get('totalPts')).abs().intValue();
        if (rawAdd <= 0) {
          continue;
        }
        Id debitOrderId = (Id) ar.get('debitOrderId');
        if (!pendingByOrder.containsKey(debitOrderId)) {
          pendingByOrder.put(debitOrderId, new List<RawAccrualUsage>());
        }
        pendingByOrder.get(debitOrderId).add(new RawAccrualUsage(originCid, rawAdd));
        Integer prev = orderRawTotal.containsKey(debitOrderId) ? orderRawTotal.get(debitOrderId) : 0;
        orderRawTotal.put(debitOrderId, prev + rawAdd);
      }
    }

    // 2단계: Order 별 비례 분배 + 마지막 그룹 round-off 보정.
    if (hiddenRestoreCreditOriginPortions != null && !hiddenRestoreCreditOriginPortions.isEmpty()) {
      Set<Id> restoreCreditIds = hiddenRestoreCreditOriginPortions.keySet();
      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId restoreCreditId,
               DebitLoyaltyLedger.TransactionJournal.OrderId debitOrderId,
               SUM(Points) totalPts
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :memberId
          AND CreditLoyaltyLedgerId IN :restoreCreditIds
          AND ActionType = 'Debit'
          AND IsDeleted = FALSE
          AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        GROUP BY CreditLoyaltyLedgerId, DebitLoyaltyLedger.TransactionJournal.OrderId
        LIMIT 50000
      ]) {
        Id restoreCid = (Id) ar.get('restoreCreditId');
        List<OriginPortion> portions = hiddenRestoreCreditOriginPortions.get(restoreCid);
        if (portions == null || portions.isEmpty()) {
          continue;
        }
        Integer rawAdd = ar.get('totalPts') == null ? 0 : ((Decimal) ar.get('totalPts')).abs().intValue();
        if (rawAdd <= 0) {
          continue;
        }
        Integer portionTotal = 0;
        for (OriginPortion p : portions) {
          portionTotal += (p.points == null ? 0 : p.points);
        }
        if (portionTotal <= 0) {
          continue;
        }
        Id debitOrderId = (Id) ar.get('debitOrderId');
        Integer allocated = 0;
        Integer lastIdx = portions.size() - 1;
        for (Integer i = 0; i < portions.size(); i++) {
          OriginPortion p = portions[i];
          Integer share;
          if (i == lastIdx) {
            share = rawAdd - allocated;
            if (share < 0) share = 0;
          } else {
            Long numerator = (Long) rawAdd * (Long) (p.points == null ? 0 : p.points);
            share = (Integer) (numerator / (Long) portionTotal);
          }
          allocated += share;
          if (share <= 0 || p.originCreditLLId == null || !creditLedgerIds.contains(p.originCreditLLId)) {
            continue;
          }
          if (!pendingByOrder.containsKey(debitOrderId)) {
            pendingByOrder.put(debitOrderId, new List<RawAccrualUsage>());
          }
          pendingByOrder.get(debitOrderId).add(new RawAccrualUsage(p.originCreditLLId, share));
          Integer prev = orderRawTotal.containsKey(debitOrderId) ? orderRawTotal.get(debitOrderId) : 0;
          orderRawTotal.put(debitOrderId, prev + share);
        }
      }
    }

    for (Id orderId : pendingByOrder.keySet()) {
      List<RawAccrualUsage> rows = pendingByOrder.get(orderId);
      Integer rawTotal = orderRawTotal.containsKey(orderId) ? orderRawTotal.get(orderId) : 0;

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
        // 취소 없음 → 그대로 가산
        for (RawAccrualUsage r : rows) {
          Integer prev = result.containsKey(r.creditId) ? result.get(r.creditId) : 0;
          result.put(r.creditId, prev + r.points);
        }
        continue;
      }
      if (orderCancel >= orderTotalUsed) {
        // 전액 취소 → 가산 안 함
        continue;
      }

      // 비례 감산: raw_i × (orderTotalUsed - orderCancel) / orderTotalUsed
      //   합계 기대값: rawTotal × netRate. 마지막 그룹에 round-off 보정.
      Integer netTotal = orderTotalUsed - orderCancel;
      Long expectedSumNum = (Long) rawTotal * (Long) netTotal;
      Integer expectedSum = (orderTotalUsed > 0)
          ? (Integer) (expectedSumNum / (Long) orderTotalUsed)
          : 0;
      Integer allocated = 0;
      Integer lastIdx = rows.size() - 1;
      for (Integer i = 0; i < rows.size(); i++) {
        RawAccrualUsage r = rows[i];
        Integer adjustedAdd;
        if (i == lastIdx) {
          // 마지막 그룹 — round-off 보정 (남은 expected 모두 할당)
          adjustedAdd = expectedSum - allocated;
          if (adjustedAdd < 0) adjustedAdd = 0;
        } else {
          Long numerator = (Long) r.points * (Long) netTotal;
          adjustedAdd = (Integer) (numerator / (Long) orderTotalUsed);
        }
        if (adjustedAdd > 0) {
          Integer prev = result.containsKey(r.creditId) ? result.get(r.creditId) : 0;
          result.put(r.creditId, prev + adjustedAdd);
          allocated += adjustedAdd;
        }
      }
    }

    return result;
  }

  /**
   * [Raw Trace Mode 2026-05-05] PT_USE raw LLT/LL 합산.
   *
   * 식:
   *   PT_USE(X) = (a) X 활성 Debit LLT 합
   *             + (b) origin=X 인 Cancel Credit 활성 Debit LLT 합
   *             - (c) origin=X 인 Cancel Credit LL.Points 합
   *             - (d) origin=(Cancel-of-X) 인 Cancel Credit LL.Points 합
   *             → clamp 0
   *
   * 활성 = LLT.IsDeleted=FALSE AND DebitTJ.IsDeleted__c=FALSE
   *        AND notes ≠ RESTORE_NOTE/ECO_CANCEL_NOTE 처리:
   *   - (a)/(b): RESTORE_NOTE 는 사용 복원이므로 포함, ECO_CANCEL_NOTE 는 소멸이므로 제외
   *   - (c)/(d): Cancel Credit LL 의 LL.IsDeleted=FALSE AND TJ.IsDeleted__c=FALSE
   *
   * origin 매핑은 호출자가 build 한 redeemCancelCreditOriginMap 그대로 사용.
   *
   * governor limit: SOQL 4회 ((a) + (b) + (c)/(d) 통합 + Cancel Credit Points lookup).
   */
  private static Map<Id, Integer> buildAccrualUsedPointMap_Raw(
    Id memberId,
    Set<Id> creditLedgerIds,
    Map<Id, Integer> orderRedeemCancelMap,
    Map<Id, Integer> orderPointUsedMap,
    Map<Id, Integer> orderDeletedDebitMap,
    Map<Id, Id> redeemCancelCreditOriginMap,
    Map<Id, List<OriginPortion>> redeemCancelCreditOriginPortions,
    Map<Id, Id> cancelLLToOrderId,
    Map<Id, List<OriginPortion>> hiddenRestoreCreditOriginPortions
  ) {
    Map<Id, Integer> result = new Map<Id, Integer>();
    for (Id cid : creditLedgerIds) {
      result.put(cid, 0);
    }

    // [Net Use Mode 2026-05-06] 정책: AccrualHistoryList PT_USE = Destory 표시 사용 LLT 의 origin=X 합 (순 사용).
    //   사용자 정책 (옵션 1):
    //     - 사용 흔적 누적이 아니라 "현재 살아있는 순 사용" 표시
    //     - 환불받은 양은 PT_USE 에서 차감 (정합성)
    //     - 두 영역 합 일치: SUM(AccrualHistoryList.PT_USE) = SUM(UserDestoryHistoryList "사용".PT_USE)
    //     - LMS Aggr Available 과 정합 (회원 잔액 = 적립 - 순 사용)
    //
    //   식 (Destory 와 정확히 동일):
    //     1. 활성 사용 LLT 들 SOQL 으로 가져옴 (RESTORE_NOTE 제외, ECO_CANCEL 제외, excludeDebitTjIds 제외).
    //        creditLedgerIds 와 origin=creditLedgerIds 인 Cancel Credit (재귀) 모두 매핑 대상.
    //     2. 각 OrderId 별 net 사용 = max(0, orderUsed - effectiveCancel) 계산.
    //        effectiveCancel = max(0, orderRedeemCancelMap - orderDeletedDebitMap)
    //        orderUsed = orderPointUsedMap (호출자가 빌드한 활성 Debit 합)
    //     3. 각 LLT 의 PT_USE 기여 = LLT.Points × netRate (round-off 보정 포함).
    //     4. 각 LLT 의 origin Credit (X) 으로 합산.
    //
    //   round-off 보정: 같은 OrderId 의 마지막 LLT 에 누적 보정 → SUM(LLT 비례 분배) = net 정확.

    // excludeDebitTjIds 빌드 (HideUseRowOnInputDepositDelete Flag ON 시) — Destory SOQL 과 동일 셋 확보
    Set<Id> excludeDebitTjIds = buildExcludeDebitTjIdsForRawMode(memberId);

    // origin → [Cancel Credit Id] 역매핑
    Map<Id, Set<Id>> originToCancels = new Map<Id, Set<Id>>();
    if (redeemCancelCreditOriginMap != null) {
      for (Id cancelCid : redeemCancelCreditOriginMap.keySet()) {
        Id originCid = redeemCancelCreditOriginMap.get(cancelCid);
        if (originCid == null) continue;
        if (!originToCancels.containsKey(originCid)) {
          originToCancels.put(originCid, new Set<Id>());
        }
        originToCancels.get(originCid).add(cancelCid);
      }
    }

    // 각 X 의 모든 자식 Cancel Credit (재귀 — Cancel-of-Cancel 까지)
    Map<Id, Id> cancelToTargetX = new Map<Id, Id>();   // Cancel Credit Id → 최상위 origin X
    for (Id targetCid : creditLedgerIds) {
      Set<Id> queue = new Set<Id>{ targetCid };
      Set<Id> visited = new Set<Id>{ targetCid };
      while (!queue.isEmpty()) {
        Set<Id> next = new Set<Id>();
        for (Id originCid : queue) {
          if (originToCancels.containsKey(originCid)) {
            for (Id cancelCid : originToCancels.get(originCid)) {
              if (!visited.contains(cancelCid)) {
                visited.add(cancelCid);
                cancelToTargetX.put(cancelCid, targetCid);
                next.add(cancelCid);
              }
            }
          }
        }
        queue = next;
      }
    }

    // SOQL 대상 Credit Id Set: creditLedgerIds + 모든 자식 Cancel Credit
    Set<Id> allTraceCreditIds = new Set<Id>(creditLedgerIds);
    allTraceCreditIds.addAll(cancelToTargetX.keySet());
    if (hiddenRestoreCreditOriginPortions != null) {
      allTraceCreditIds.addAll(hiddenRestoreCreditOriginPortions.keySet());
    }

    // 활성 사용 LLT 가져오기 — (a) X 자체 + (b) origin=X Cancel Credit (재귀)
    //   GROUP BY (CreditId, OrderId) 으로 비례 분배 분모 (orderUsed) + Order 단위 보정 가능
    //   각 (Credit, Order) 그룹의 LLT 들의 합을 활용
    //   round-off 보정을 위해 SOQL 결과를 (Order, Credit 별 그룹 리스트) 로 정리
    List<RawNetUseRow> rows = new List<RawNetUseRow>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditId,
             DebitLoyaltyLedger.TransactionJournal.OrderId orderId,
             SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :allTraceCreditIds
        AND ActionType = 'Debit'
        AND IsDeleted = FALSE
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :ADDITIONAL_NOTE_FULL_RETURN_ECO_POINT_CANCEL)
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR (NOT DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c LIKE :OPTION_C_RETURN_DEPOSIT_DELETE_USAGE_RESTORE_NOTE_LIKE))
        AND DebitLoyaltyLedger.TransactionJournalId NOT IN :excludeDebitTjIds
      GROUP BY CreditLoyaltyLedgerId, DebitLoyaltyLedger.TransactionJournal.OrderId
      LIMIT 50000
    ]) {
      Id cid = (Id) ar.get('creditId');
      Id oid = (Id) ar.get('orderId');
      Integer pts = ar.get('total') == null ? 0 : ((Decimal) ar.get('total')).abs().intValue();
      if (pts <= 0) continue;

      // [Phase 2 Precise Origin 2026-05-06] Cancel Credit 사용분 → portions 비율 분할 우선.
      //   redeemCancelCreditOriginPortions 가 빌드된 경우(=Flag ON), Cancel Credit (cid) 의 사용 LLT pts 를
      //   여러 origin Credit 으로 비례 분배하여 row 들을 추가.
      //   기존 단일 매핑(cancelToTargetX)은 portions 가 없는 cid 에만 적용 (재귀 Cancel-of-Cancel 등 fallback).
      //   creditLedgerIds 직접 cid 는 그대로 자기 자신 origin 으로.
      if (redeemCancelCreditOriginPortions != null
          && redeemCancelCreditOriginPortions.containsKey(cid)) {
        List<OriginPortion> portions = redeemCancelCreditOriginPortions.get(cid);
        Integer totalPortionPts = 0;
        for (OriginPortion p : portions) {
          totalPortionPts += (p.points == null ? 0 : p.points);
        }
        if (totalPortionPts > 0 && portions != null && !portions.isEmpty()) {
          Integer allocated = 0;
          Integer lastIdx = portions.size() - 1;
          for (Integer i = 0; i < portions.size(); i++) {
            OriginPortion p = portions[i];
            // creditLedgerIds 에 포함되지 않는 origin (예: 외부 LL) 은 매핑 대상 아님 → 비례 분배에서 제외 안 하고
            // 일단 분배 후 check (그대로 합산 안 됨) → 단순화 위해 여기서 컨티뉴 시 round-off 누적이 깨질 수 있어
            // 일단 모든 portion 을 분배 후 result 매핑 시 creditLedgerIds 멤버십 체크.
            Integer share;
            if (i == lastIdx) {
              share = pts - allocated;
              if (share < 0) share = 0;
            } else {
              Long num = (Long) pts * (Long) (p.points == null ? 0 : p.points);
              share = (Integer) (num / (Long) totalPortionPts);
            }
            if (share > 0 && p.originCreditLLId != null && creditLedgerIds.contains(p.originCreditLLId)) {
              rows.add(new RawNetUseRow(p.originCreditLLId, oid, share));
            }
            allocated += share;
          }
          continue;
        }
      }

      if (hiddenRestoreCreditOriginPortions != null
          && hiddenRestoreCreditOriginPortions.containsKey(cid)) {
        List<OriginPortion> portions = hiddenRestoreCreditOriginPortions.get(cid);
        Integer totalPortionPts = 0;
        for (OriginPortion p : portions) {
          totalPortionPts += (p.points == null ? 0 : p.points);
        }
        if (totalPortionPts > 0 && portions != null && !portions.isEmpty()) {
          Integer allocated = 0;
          Integer lastIdx = portions.size() - 1;
          for (Integer i = 0; i < portions.size(); i++) {
            OriginPortion p = portions[i];
            Integer share;
            if (i == lastIdx) {
              share = pts - allocated;
              if (share < 0) share = 0;
            } else {
              Long num = (Long) pts * (Long) (p.points == null ? 0 : p.points);
              share = (Integer) (num / (Long) totalPortionPts);
            }
            if (share > 0 && p.originCreditLLId != null && creditLedgerIds.contains(p.originCreditLLId)) {
              rows.add(new RawNetUseRow(p.originCreditLLId, oid, share));
            }
            allocated += share;
          }
          continue;
        }
      }

      // origin X 결정 — Cancel Credit (cancelToTargetX 에 있음) 은 origin X 우선 매핑.
      //   `creditLedgerIds` 에 Cancel Credit 도 포함 가능 (응답 표시는 별도 hide) → 매핑 충돌 방지 위해 cancelToTargetX 우선.
      Id targetX = cancelToTargetX.containsKey(cid) ? cancelToTargetX.get(cid)
          : (creditLedgerIds.contains(cid) ? cid : null);
      if (targetX == null) continue;
      rows.add(new RawNetUseRow(targetX, oid, pts));
    }

    if (rows.isEmpty()) {
      return result;
    }

    // OrderId 별 그룹핑 (round-off 보정용)
    Map<Id, List<RawNetUseRow>> rowsByOrder = new Map<Id, List<RawNetUseRow>>();
    Map<Id, Integer> orderRawTotalLocal = new Map<Id, Integer>();   // 그 Order 의 (X, X-자식) raw 합
    for (RawNetUseRow r : rows) {
      if (r.orderId == null) {
        // Order 없는 LLT (마이그 적립 등) — 전액 가산 (환불 없음)
        Integer prev = result.containsKey(r.creditId) ? result.get(r.creditId) : 0;
        result.put(r.creditId, prev + r.points);
        continue;
      }
      if (!rowsByOrder.containsKey(r.orderId)) {
        rowsByOrder.put(r.orderId, new List<RawNetUseRow>());
      }
      rowsByOrder.get(r.orderId).add(r);
      Integer prev = orderRawTotalLocal.containsKey(r.orderId) ? orderRawTotalLocal.get(r.orderId) : 0;
      orderRawTotalLocal.put(r.orderId, prev + r.points);
    }

    // [Phase 2.1 2026-05-06] portions 기반 (originLLId, orderId) → 환불액 맵 빌드.
    //   각 Cancel Credit LL 의 OrderId(=환불 발생 판매 Order) 별로 portions 비율 분배 합산.
    //   Order 별 portions 환불 합 == effectiveCancel 이면 origin 별 직접 차감 가능 → 정확한 분배.
    //   불일치 Order 는 fallback (기존 비례 분배).
    Map<Id, Map<Id, Integer>> orderToOriginRefund = new Map<Id, Map<Id, Integer>>();
    if (redeemCancelCreditOriginPortions != null && cancelLLToOrderId != null
        && !redeemCancelCreditOriginPortions.isEmpty() && !cancelLLToOrderId.isEmpty()) {
      for (Id cancelLLId : redeemCancelCreditOriginPortions.keySet()) {
        Id refundOrderId = cancelLLToOrderId.get(cancelLLId);
        if (refundOrderId == null) continue;
        List<OriginPortion> portions = redeemCancelCreditOriginPortions.get(cancelLLId);
        if (portions == null) continue;
        if (!orderToOriginRefund.containsKey(refundOrderId)) {
          orderToOriginRefund.put(refundOrderId, new Map<Id, Integer>());
        }
        Map<Id, Integer> originRefund = orderToOriginRefund.get(refundOrderId);
        for (OriginPortion p : portions) {
          if (p.originCreditLLId == null) continue;
          // origin 이 creditLedgerIds 에 없으면 (외부 LL — 매핑 대상 아님) 차감 무의미 → 스킵
          if (!creditLedgerIds.contains(p.originCreditLLId)) continue;
          Integer prev = originRefund.containsKey(p.originCreditLLId) ? originRefund.get(p.originCreditLLId) : 0;
          originRefund.put(p.originCreditLLId, prev + (p.points == null ? 0 : p.points));
        }
      }
    }

    // 각 OrderId 별로 비례 분배 + 마지막 row round-off 보정
    for (Id oid : rowsByOrder.keySet()) {
      List<RawNetUseRow> orderRows = rowsByOrder.get(oid);
      Integer rawTotal = orderRawTotalLocal.get(oid);

      // orderUsed = orderPointUsedMap (호출자가 빌드한 활성 Debit 합 — Destory 와 같은 분모)
      Integer orderUsed = (orderPointUsedMap != null && orderPointUsedMap.containsKey(oid))
          ? orderPointUsedMap.get(oid) : 0;
      Integer rawCancel = (orderRedeemCancelMap != null && orderRedeemCancelMap.containsKey(oid))
          ? orderRedeemCancelMap.get(oid) : 0;
      Integer deletedDebit = (orderDeletedDebitMap != null && orderDeletedDebitMap.containsKey(oid))
          ? orderDeletedDebitMap.get(oid) : 0;
      Integer effectiveCancel = Math.max(0, rawCancel - deletedDebit);

      // 전액 환불 → 모두 스킵
      if (orderUsed > 0 && effectiveCancel >= orderUsed) {
        continue;
      }

      // 환불 없음 → 그대로 가산
      if (orderUsed <= 0 || effectiveCancel <= 0) {
        for (RawNetUseRow r : orderRows) {
          Integer prev = result.containsKey(r.creditId) ? result.get(r.creditId) : 0;
          result.put(r.creditId, prev + r.points);
        }
        continue;
      }

      // [Phase 2.1] portions 기반 origin 직접 차감 시도.
      //   조건: 해당 Order 에 portions 매핑 존재 + 환불 총합 == effectiveCancel (정합 검증).
      //   정합 시: 각 origin 별 (사용 - 환불) 직접 가산 → 비례 분배 우회.
      //   부정합 (매칭 못한 환불 포함) → fallback 비례 분배.
      Boolean useDirectOriginRefund = false;
      Map<Id, Integer> originRefundForThisOrder = orderToOriginRefund.get(oid);
      if (originRefundForThisOrder != null && !originRefundForThisOrder.isEmpty()) {
        Integer totalOriginRefund = 0;
        for (Integer v : originRefundForThisOrder.values()) totalOriginRefund += v;
        // effectiveCancel 과 일치(±0) 시 portions 매핑이 환불 전체를 커버 → 직접 차감 안전
        if (totalOriginRefund == effectiveCancel) {
          useDirectOriginRefund = true;
        }
      }

      if (useDirectOriginRefund) {
        // origin 별 (사용 합 - 환불 합) clamp 0 직접 가산
        Map<Id, Integer> originUsedForThisOrder = new Map<Id, Integer>();
        for (RawNetUseRow r : orderRows) {
          Integer prev = originUsedForThisOrder.containsKey(r.creditId) ? originUsedForThisOrder.get(r.creditId) : 0;
          originUsedForThisOrder.put(r.creditId, prev + r.points);
        }
        for (Id originCid : originUsedForThisOrder.keySet()) {
          Integer used = originUsedForThisOrder.get(originCid);
          Integer refund = originRefundForThisOrder.containsKey(originCid) ? originRefundForThisOrder.get(originCid) : 0;
          Integer netUsed = Math.max(0, used - refund);
          if (netUsed > 0) {
            Integer prev = result.containsKey(originCid) ? result.get(originCid) : 0;
            result.put(originCid, prev + netUsed);
          }
        }
        continue;
      }

      // 부분 환불 → 비례 분배 + 마지막 row round-off 보정 (fallback)
      //   netRate = (orderUsed - effectiveCancel) / orderUsed
      //   합계 기대값 = rawTotal × netRate
      Integer netTotal = orderUsed - effectiveCancel;
      Long expectedSumNum = (Long) rawTotal * (Long) netTotal;
      Integer expectedSum = (orderUsed > 0)
          ? (Integer) (expectedSumNum / (Long) orderUsed)
          : 0;
      Integer allocated = 0;
      Integer lastIdx = orderRows.size() - 1;
      for (Integer i = 0; i < orderRows.size(); i++) {
        RawNetUseRow r = orderRows[i];
        Integer adjustedAdd;
        if (i == lastIdx) {
          // 마지막 row — round-off 보정 (남은 expected 모두 할당)
          adjustedAdd = expectedSum - allocated;
          if (adjustedAdd < 0) adjustedAdd = 0;
        } else {
          Long numerator = (Long) r.points * (Long) netTotal;
          adjustedAdd = (Integer) (numerator / (Long) orderUsed);
        }
        if (adjustedAdd > 0) {
          Integer prev = result.containsKey(r.creditId) ? result.get(r.creditId) : 0;
          result.put(r.creditId, prev + adjustedAdd);
          allocated += adjustedAdd;
        }
      }
    }

    return result;
  }

  // [Net Use Mode 2026-05-06] raw 식 내부 row 보관용
  private class RawNetUseRow {
    Id creditId;       // origin X (creditLedgerIds 중 하나)
    Id orderId;        // Debit OrderId
    Integer points;    // (Credit, Order) 그룹의 raw 사용 합
    RawNetUseRow(Id creditId, Id orderId, Integer points) {
      this.creditId = creditId;
      this.orderId = orderId;
      this.points = points;
    }
  }

  /**
   * [Destory Consistency Fix 2026-05-06] HideUseRowOnInputDepositDelete Flag 로 Destory 가 hide 하는
   * Debit TJ Id 셋을 동일하게 빌드하여 raw 모드 PT_USE 와 Destory 사용 행의 일관성을 보장.
   *
   * 알고리즘:
   *   1. 활성 'del_point_*' Cancel TJ 조회 → (OrderId, 원본 DepositNo) 셋 추출.
   *   2. 매칭되는 원 Point Debit TJ Id 셋 빌드 (OrderId+DepositNo 정확 매칭).
   *
   * Flag OFF 시 빈 셋 반환 (NOT IN empty = always true → 영향 없음).
   */
  private static Set<Id> buildExcludeDebitTjIdsForRawMode(Id memberId) {
    Set<Id> excludeDebitTjIds = new Set<Id>();
    if (!GdFeatureFlag.isEnabled('HideUseRowOnInputDepositDelete')) {
      return excludeDebitTjIds;
    }
    Map<Id, Set<String>> excludeOrigDepositNoByOrderId = new Map<Id, Set<String>>();
    Map<String, Datetime> excludeCutoffByOrderDepositKey = new Map<String, Datetime>();
    for (TransactionJournal cancelTj : [
      SELECT Id, OrderId, DepositNo__c, CreatedDate
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND IsDeleted__c = FALSE
        AND DepositNo__c LIKE 'del_point_%'
        AND JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
      LIMIT 5000
    ]) {
      if (cancelTj.OrderId == null || String.isBlank(cancelTj.DepositNo__c)) {
        continue;
      }
      String origDepositNo = cancelTj.DepositNo__c.substring('del_point_'.length());
      if (String.isBlank(origDepositNo)) {
        continue;
      }
      if (!excludeOrigDepositNoByOrderId.containsKey(cancelTj.OrderId)) {
        excludeOrigDepositNoByOrderId.put(cancelTj.OrderId, new Set<String>());
      }
      excludeOrigDepositNoByOrderId.get(cancelTj.OrderId).add(origDepositNo);
      String cutoffKey = String.valueOf(cancelTj.OrderId) + '|' + origDepositNo;
      if (!excludeCutoffByOrderDepositKey.containsKey(cutoffKey)
          || cancelTj.CreatedDate < excludeCutoffByOrderDepositKey.get(cutoffKey)) {
        excludeCutoffByOrderDepositKey.put(cutoffKey, cancelTj.CreatedDate);
      }
    }
    if (excludeOrigDepositNoByOrderId.isEmpty()) {
      return excludeDebitTjIds;
    }
    Set<Id> targetOrderIds = excludeOrigDepositNoByOrderId.keySet();
    Set<String> allOrigDepositNos = new Set<String>();
    for (Set<String> s : excludeOrigDepositNoByOrderId.values()) {
      allOrigDepositNos.addAll(s);
    }
    for (TransactionJournal origTj : [
      SELECT Id, OrderId, DepositNo__c, CreatedDate
      FROM TransactionJournal
      WHERE MemberId = :memberId
        AND OrderId IN :targetOrderIds
        AND DepositNo__c IN :allOrigDepositNos
        AND JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_DEBIT
        AND IsDeleted__c = FALSE
      LIMIT 5000
    ]) {
      Set<String> depositNosForOrder = excludeOrigDepositNoByOrderId.get(origTj.OrderId);
      String cutoffKey = String.valueOf(origTj.OrderId) + '|' + origTj.DepositNo__c;
      Datetime cutoff = excludeCutoffByOrderDepositKey.get(cutoffKey);
      if (depositNosForOrder != null
          && depositNosForOrder.contains(origTj.DepositNo__c)
          && cutoff != null
          && origTj.CreatedDate <= cutoff) {
        excludeDebitTjIds.add(origTj.Id);
      }
    }
    return excludeDebitTjIds;
  }

  // [PT_USE Round-off Fix 2026-05-05] buildAccrualUsedPointMap 내부 1+3단계 raw row 보관용.
  private class RawAccrualUsage {
    Id creditId;
    Integer points;
    RawAccrualUsage(Id creditId, Integer points) {
      this.creditId = creditId;
      this.points = points;
    }
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

  private static Map<Id, Integer> buildAccrualSaleCancelPointMap(Id memberId, Set<Id> creditLedgerIds) {
    Map<Id, Integer> result = new Map<Id, Integer>();

    if (memberId == null || creditLedgerIds == null || creditLedgerIds.isEmpty()) {
      return result;
    }

    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :creditLedgerIds
        AND ActionType = 'CreditCancellation'
        AND DebitLoyaltyLedger.TransactionJournal.JournalType.Name = :JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (
          DebitLoyaltyLedger.TransactionJournal.SaleId__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c != TRUE
        )
      GROUP BY CreditLoyaltyLedgerId
      LIMIT 50000
    ]) {
      Id creditLedgerId = (Id) ar.get('creditLedgerId');
      if (creditLedgerId == null) {
        continue;
      }
      Integer amount = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();
      result.put(creditLedgerId, amount);
    }

    return result;
  }

  private static Map<Id, Integer> buildAccrualExpiredPointMap(
      Id memberId,
      List<LoyaltyLedger> creditLedgers,
      Map<Id, Integer> reductionPointMap,
      Map<Id, Id> ecoRestoreLLToOriginLLId,
      Map<Id, List<OriginPortion>> hiddenRestoreCreditOriginPortions,
      Map<Id, List<OriginPortion>> activeReturnRestoreCreditOriginPortions,
      Map<Id, List<OriginPortion>> directRestoreCreditOriginPortions
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
    Map<Id, Integer> returnCancelTransferredFromRestoreByOriginCreditLLId = new Map<Id, Integer>();
    Map<Id, Integer> restoredPointsByOriginCreditLLId = new Map<Id, Integer>();
    Map<Id, Integer> restoredPointsByDirectCreditLLId = new Map<Id, Integer>();
    Map<Id, List<OriginPortion>> optionCRestoreCreditOriginPortionsByRestoreLLId =
      hiddenRestoreCreditOriginPortions == null
        ? new Map<Id, List<OriginPortion>>()
        : hiddenRestoreCreditOriginPortions;
    Map<Id, List<OriginPortion>> activeRestoreCreditOriginPortionsByRestoreLLId =
      activeReturnRestoreCreditOriginPortions == null
        ? new Map<Id, List<OriginPortion>>()
        : activeReturnRestoreCreditOriginPortions;
    Map<Id, List<OriginPortion>> directRestoreCreditOriginPortionsByRestoreLLId =
      directRestoreCreditOriginPortions == null
        ? new Map<Id, List<OriginPortion>>()
        : directRestoreCreditOriginPortions;

    if (!activeRestoreCreditOriginPortionsByRestoreLLId.isEmpty()) {
      for (List<OriginPortion> portions : activeRestoreCreditOriginPortionsByRestoreLLId.values()) {
        if (portions == null) {
          continue;
        }
        for (OriginPortion p : portions) {
          if (p == null || p.originCreditLLId == null || p.points == null || p.points <= 0) {
            continue;
          }
          Integer prev = restoredPointsByOriginCreditLLId.containsKey(p.originCreditLLId)
              ? restoredPointsByOriginCreditLLId.get(p.originCreditLLId)
              : 0;
          restoredPointsByOriginCreditLLId.put(p.originCreditLLId, prev + p.points);
        }
      }
    }

    if (!directRestoreCreditOriginPortionsByRestoreLLId.isEmpty()) {
      for (List<OriginPortion> portions : directRestoreCreditOriginPortionsByRestoreLLId.values()) {
        if (portions == null) {
          continue;
        }
        for (OriginPortion p : portions) {
          if (p == null || p.originCreditLLId == null || p.points == null || p.points <= 0) {
            continue;
          }
          Integer prev = restoredPointsByDirectCreditLLId.containsKey(p.originCreditLLId)
              ? restoredPointsByDirectCreditLLId.get(p.originCreditLLId)
              : 0;
          restoredPointsByDirectCreditLLId.put(p.originCreditLLId, prev + p.points);
        }
      }
    }

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
      allEcoRelatedLLIds.addAll(optionCRestoreCreditOriginPortionsByRestoreLLId.keySet());

      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId creditLedgerId, SUM(Points) totalPoints
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND CreditLoyaltyLedgerId IN :allEcoRelatedLLIds
          AND ActionType = 'CreditCancellation'
          AND (
            (
              DebitLoyaltyLedger.TransactionJournal.JournalType.Name = :JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
              AND DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c = TRUE
            )
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
        if (optionCRestoreCreditOriginPortionsByRestoreLLId.containsKey(creditLedgerId)) {
          Integer restoredAgainstRestoreCredit = restoredPointsByDirectCreditLLId.containsKey(creditLedgerId)
            ? restoredPointsByDirectCreditLLId.get(creditLedgerId)
            : 0;
          Integer effectiveTransferredPoints = Math.max(0, points - restoredAgainstRestoreCredit);
          List<OriginPortion> portions = capOriginPortions(
            optionCRestoreCreditOriginPortionsByRestoreLLId.get(creditLedgerId),
            effectiveTransferredPoints
          );
          for (OriginPortion p : portions) {
            if (p == null || p.originCreditLLId == null || p.points == null || p.points <= 0) {
              continue;
            }
            Integer prev = returnCancelTransferredFromRestoreByOriginCreditLLId.containsKey(p.originCreditLLId)
              ? returnCancelTransferredFromRestoreByOriginCreditLLId.get(p.originCreditLLId)
              : 0;
            returnCancelTransferredFromRestoreByOriginCreditLLId.put(p.originCreditLLId, prev + p.points);
          }
          continue;
        }

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
      Integer restoredPoints = restoredPointsByOriginCreditLLId.containsKey(credit.Id)
          ? restoredPointsByOriginCreditLLId.get(credit.Id)
          : 0;
      returnCancelledPoints = Math.max(0, returnCancelledPoints - restoredPoints);
      Integer transferredReturnCancelledPoints = returnCancelTransferredFromRestoreByOriginCreditLLId.containsKey(credit.Id)
          ? returnCancelTransferredFromRestoreByOriginCreditLLId.get(credit.Id)
          : 0;

      result.put(credit.Id, expiredPoints + returnCancelledPoints + transferredReturnCancelledPoints);
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
        IsDeleted,                                    // [Active Only Fix 2026-05-07] Cancel Credit 활성 필터링용
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
        LoyaltyPgmCrcySubtype.UsagePriorityNumber, // 26.05.05 CS - AccrualHistoryList 정렬 키
        TransactionJournal.OrderId,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.Order.ActualPaymentAmount__c,
        TransactionJournal.Order.IsDeleted__c,
        TransactionJournal.Promotion.PromotionNo__c,
        TransactionJournal.SaleId__c,
        TransactionJournal.SaleId__r.SaleNo__c,
        TransactionJournal.SaleId__r.IsDeleted__c,
        TransactionJournal.SaleId__r.IsReductionOrder__c,
        TransactionJournal.SaleId__r.OriginalOrderId__c
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
    Map<Id, Datetime> ledgerIdToActivityDateForDisplay = new Map<Id, Datetime>();
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
    Map<String, LoyaltyLedger> optionCBaseCreditByDisplayKey = new Map<String, LoyaltyLedger>();
    for (LoyaltyLedger ll : ledgers) {
      if (ll.Id != null && ll.ActivityDate != null) {
        ledgerIdToActivityDateForDisplay.put(ll.Id, ll.ActivityDate);
      }
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
      if (ll.EventType == 'Credit'
          && ll.Id != null
          && ll.TransactionJournal != null
          && ll.TransactionJournal.OrderId != null
          && ll.LoyaltyPgmCrcySubtypeId != null
          && ll.ExpiryDate != null
          && !shouldExcludeFromAccrualHistory(ll)
          && !isOptionCSalePatchForceCreditNote(ll.TransactionJournal.AdditionalNotes__c)
          && !isOptionCReturnRestoreCreditNote(ll.TransactionJournal.AdditionalNotes__c)) {
        String displayKey = buildRestoreOriginKey(ll.TransactionJournal.OrderId, ll.LoyaltyPgmCrcySubtypeId, ll.ExpiryDate);
        if (!optionCBaseCreditByDisplayKey.containsKey(displayKey)) {
          optionCBaseCreditByDisplayKey.put(displayKey, ll);
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
          && !isReturnDepositDeletePointRestoreHelperNote(ll.TransactionJournal.AdditionalNotes__c)) {
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
    Map<String, List<LoyaltyLedger>> originCreditsByRestoreKey = new Map<String, List<LoyaltyLedger>>();
    for (LoyaltyLedger ll : creditLedgers) {
      if (!isRestoreOriginCandidate(ll)) {
        continue;
      }
      if (ll.Id == null
          || ll.TransactionJournal == null
          || ll.TransactionJournal.OrderId == null
          || ll.LoyaltyPgmCrcySubtypeId == null
          || ll.ExpiryDate == null) {
        continue;
      }
      String key = buildRestoreOriginKey(ll.TransactionJournal.OrderId, ll.LoyaltyPgmCrcySubtypeId, ll.ExpiryDate);
      if (!originCreditsByRestoreKey.containsKey(key)) {
        originCreditsByRestoreKey.put(key, new List<LoyaltyLedger>());
      }
      originCreditsByRestoreKey.get(key).add(ll);
    }

    Map<Id, List<OriginPortion>> hiddenRestoreCreditOriginPortions = new Map<Id, List<OriginPortion>>();
    Map<Id, List<OriginPortion>> activeReturnRestoreCreditOriginPortions = new Map<Id, List<OriginPortion>>();
    Map<Id, Integer> activeRestoreRemainingByOriginCreditLLId = new Map<Id, Integer>();
    Map<Id, Integer> optionCActiveRestoreRemainingByOriginCreditLLId = new Map<Id, Integer>();
    Set<Id> optionCRestoreCreditLLIdsLinkedToDeletedReturn =
      buildOptionCRestoreCreditLLIdsLinkedToDeletedReturn(ledgers);
    Map<Id, List<OriginPortion>> optionCRestoreDirectOriginPortionsBySourceTj =
      buildOptionCRestoreOriginPortionsBySourceTj(memberId, ledgers, false);
    Map<Id, List<OriginPortion>> optionCRestoreOriginPortionsBySourceTj =
      buildOptionCRestoreOriginPortionsBySourceTj(memberId, ledgers, true);
    for (LoyaltyLedger ll : ledgers) {
      if (ll.EventType != 'Credit'
          || ll.Id == null
          || ll.TransactionJournal == null
          || ll.TransactionJournal.OrderId == null
          || ll.LoyaltyPgmCrcySubtypeId == null
          || ll.ExpiryDate == null
          || ll.Points == null) {
        continue;
      }
      String note = ll.TransactionJournal.AdditionalNotes__c;
      Boolean isOptionCForceCreditRestore = isOptionCReturnRestoreCreditNote(note);
      Boolean isPointRedeemCancelCredit = ll.TransactionJournal.JournalSubType != null
          && ll.TransactionJournal.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL;
      Id directOriginCreditLLId = extractOriginCreditLedgerId(ll.AdditionalNotes);
      Boolean hasDirectOriginCreditLL = directOriginCreditLLId != null && isPointRedeemCancelCredit;
      Boolean isUnmarkedReturnPurchaseAccrualRestore =
          note == null
          && ll.TransactionJournal.JournalType != null
          && ll.TransactionJournal.JournalType.Name == JOURNAL_TYPE_NAME_ACCRUAL
          && ll.TransactionJournal.JournalSubType != null
          && ll.TransactionJournal.JournalSubType.Name == 'Purchase Accrual'
          && ll.TransactionJournal.SaleId__r != null
          && ll.TransactionJournal.SaleId__r.IsReductionOrder__c == true
          && ll.TransactionJournal.SaleId__r.OriginalOrderId__c != null;
      if (note != RESTORE_PURCHASE_ACCRUAL_NOTE
          && note != RESTORE_PROMOTION_ACCRUAL_NOTE
          && note != ECO_POINT_RESTORE_NOTE
          && !isOptionCForceCreditRestore
          && !isUnmarkedReturnPurchaseAccrualRestore
          && !hasDirectOriginCreditLL) {
        continue;
      }
      Boolean isDeletedReturnRestore = ll.TransactionJournal.SaleId__r != null
          && ll.TransactionJournal.SaleId__r.IsDeleted__c == true;
      isDeletedReturnRestore = isDeletedReturnRestore
          || optionCRestoreCreditLLIdsLinkedToDeletedReturn.contains(ll.Id);
      Id restoreOriginOrderId = isUnmarkedReturnPurchaseAccrualRestore
          ? ll.TransactionJournal.SaleId__r.OriginalOrderId__c
          : ll.TransactionJournal.OrderId;
      String key = buildRestoreOriginKey(restoreOriginOrderId, ll.LoyaltyPgmCrcySubtypeId, ll.ExpiryDate);
      List<LoyaltyLedger> originCandidates = originCreditsByRestoreKey.get(key);
      List<OriginPortion> directOptionCPortions = optionCRestoreOriginPortionsBySourceTj.get(ll.Id);
      if ((originCandidates == null || originCandidates.isEmpty())
          && (directOptionCPortions == null || directOptionCPortions.isEmpty())
          && directOriginCreditLLId == null) {
        continue;
      }
      Integer restorePoints = ll.Points.abs().intValue();
      if (restorePoints <= 0) {
        continue;
      }
      List<OriginPortion> portions = new List<OriginPortion>();
      if (directOriginCreditLLId != null) {
        portions.add(new OriginPortion(directOriginCreditLLId, restorePoints));
      } else if (directOptionCPortions != null && !directOptionCPortions.isEmpty()) {
        portions.addAll(directOptionCPortions);
      } else {
        Integer candidateTotal = 0;
        for (LoyaltyLedger origin : originCandidates) {
          candidateTotal += origin.Points == null ? 0 : origin.Points.abs().intValue();
        }
        if (candidateTotal <= 0) {
          continue;
        }
        Integer allocated = 0;
        Integer lastIdx = originCandidates.size() - 1;
        for (Integer i = 0; i < originCandidates.size(); i++) {
          LoyaltyLedger origin = originCandidates[i];
          Integer share;
          if (i == lastIdx) {
            share = restorePoints - allocated;
            if (share < 0) share = 0;
          } else {
            Integer originPoints = origin.Points == null ? 0 : origin.Points.abs().intValue();
            Long numerator = (Long) restorePoints * (Long) originPoints;
            share = (Integer) (numerator / (Long) candidateTotal);
          }
          allocated += share;
          if (share > 0) {
            portions.add(new OriginPortion(origin.Id, share));
          }
        }
      }
      if (!portions.isEmpty()) {
        hiddenRestoreCreditOriginPortions.put(ll.Id, portions);
        if (!isDeletedReturnRestore) {
          activeReturnRestoreCreditOriginPortions.put(ll.Id, portions);
          List<OriginPortion> activeRemainingPortions = portions;
          if (isOptionCForceCreditRestore) {
            List<OriginPortion> directActiveRemainingPortions = optionCRestoreDirectOriginPortionsBySourceTj.get(ll.Id);
            if (directActiveRemainingPortions != null && !directActiveRemainingPortions.isEmpty()) {
              activeRemainingPortions = directActiveRemainingPortions;
            }
            for (OriginPortion p : activeRemainingPortions) {
              if (p.originCreditLLId == null || p.points == null || p.points <= 0) {
                continue;
              }
              Integer prev = optionCActiveRestoreRemainingByOriginCreditLLId.containsKey(p.originCreditLLId)
                ? optionCActiveRestoreRemainingByOriginCreditLLId.get(p.originCreditLLId)
                : 0;
              optionCActiveRestoreRemainingByOriginCreditLLId.put(p.originCreditLLId, prev + p.points);
            }
          }
          for (OriginPortion p : activeRemainingPortions) {
            if (p.originCreditLLId == null || p.points == null || p.points <= 0) {
              continue;
            }
            Integer prev = activeRestoreRemainingByOriginCreditLLId.containsKey(p.originCreditLLId)
              ? activeRestoreRemainingByOriginCreditLLId.get(p.originCreditLLId)
              : 0;
            activeRestoreRemainingByOriginCreditLLId.put(p.originCreditLLId, prev + p.points);
          }
        }
      }
    }

    Map<Id, Integer> orderRedeemCancelMap = buildOrderRedeemCancelMap(memberId);

    // [2026-04-25 추가 Fix] Point Redeem Cancel Credit → 원 Credit 매핑 (DELETE /sale/deposit + PATCH 재등록 시나리오)
    //   - Cancel Credit 이 없으면 빈 맵 반환 (S1/S2 등 영향 없음)
    //   - 있는 경우에만 buildAccrualUsedPointMap 의 이월 단계 활성
    Map<Id, Id> redeemCancelCreditOriginMap = buildRedeemCancelCreditOriginMap(memberId, ledgers);

    // [Origin ActivityDate Fix 2026-05-06] Cancel Credit (Point Redeem Cancel) 의 사용 LLT 에 대해
    //   DT_SAVE 를 원 적립 Credit LL 의 ActivityDate 로 덮어쓰기 위한 사전 매핑.
    //   Flag ON 시: cancelLLId → origin LL.ActivityDate 매핑 (origin 매핑 재귀 추적 후 최종 origin 의 ActivityDate)
    //   배경: LMS 표준 API 가 재적립 Cancel Credit 의 ActivityDate 를 today 로 설정 → DT_SAVE 가 재적립일로 표시되는 결함.
    //   해결: 화면 표시 단계에서 cancelLLId 의 ActivityDate 를 origin LL 의 ActivityDate 로 덮어씀 (LMS 데이터 안 건드림).
    Boolean preserveOriginActivityDate = GdFeatureFlag.isEnabled('CancelCredit_PreserveOriginActivityDate');
    Map<Id, Datetime> cancelLLToOriginActivityDate = new Map<Id, Datetime>();
    if (preserveOriginActivityDate && !redeemCancelCreditOriginMap.isEmpty()) {
      // ledgers 안에 모든 LL 이 있으므로 거기서 ActivityDate 추출
      Map<Id, Datetime> ledgerIdToActivityDate = new Map<Id, Datetime>();
      for (LoyaltyLedger ll : ledgers) {
        if (ll.Id != null && ll.ActivityDate != null) {
          ledgerIdToActivityDate.put(ll.Id, ll.ActivityDate);
        }
      }
      // 각 cancelLLId 에 대해 origin 재귀 추적 후 최종 origin 의 ActivityDate 매핑
      for (Id cancelLLId : redeemCancelCreditOriginMap.keySet()) {
        Id current = cancelLLId;
        Set<Id> visited = new Set<Id>();
        while (redeemCancelCreditOriginMap.containsKey(current) && !visited.contains(current)) {
          visited.add(current);
          current = redeemCancelCreditOriginMap.get(current);
          if (current == null) break;
        }
        if (current != null && ledgerIdToActivityDate.containsKey(current)) {
          cancelLLToOriginActivityDate.put(cancelLLId, ledgerIdToActivityDate.get(current));
        }
      }
    }

    // [Phase 2 Precise Origin 2026-05-06] Flag ON 시 다중 분배 매핑 (portions) 빌드.
    //   raw 모드의 Cancel Credit 사용분을 origin 비율 분할로 더 정확히 귀속.
    //   Flag OFF → null 전달 → 기존 단일 매핑 동작 그대로.
    // [Phase 2.1 2026-05-06] cancelLLToOrderId 도 함께 빌드 — Cancel Credit 의 환불(차감) 도
    //   origin 별 직접 차감 으로 처리하기 위함.
    // [Phase 3 2026-05-06] originLLId → ActivityDate 매핑도 메서드 스코프로 빌드 →
    //   UserDestoryHistoryList Cancel Credit 사용 row 의 portions 분할 시 각 row 의 DT_SAVE 결정.
    Map<Id, List<OriginPortion>> redeemCancelCreditOriginPortions = null;
    Map<Id, Id> cancelLLToOrderId = null;
    Map<Id, Datetime> originLLToActivityDate = null;
    if (GdFeatureFlag.isEnabled('RedeemCancelOriginMap_Precise')
        && !redeemCancelCreditOriginMap.isEmpty()) {
      redeemCancelCreditOriginPortions = buildRedeemCancelCreditOriginPortions(
          memberId, ledgers, redeemCancelCreditOriginMap);
      redeemCancelCreditOriginPortions = expandOriginPortionsToFinalOrigin(
          redeemCancelCreditOriginPortions, hiddenRestoreCreditOriginPortions);
      cancelLLToOrderId = new Map<Id, Id>();
      originLLToActivityDate = new Map<Id, Datetime>();
      for (LoyaltyLedger ll : ledgers) {
        if (ll.Id != null && ll.ActivityDate != null) {
          originLLToActivityDate.put(ll.Id, ll.ActivityDate);
        }
        // [Active Only Fix 2026-05-07] buildRedeemCancelCreditOriginPortions 와 일관 — 삭제된 Cancel Credit 제외.
        //   둘이 일치하지 않으면 portions 매핑은 활성만 잡고, cancelLLToOrderId 는 비활성도 포함되어
        //   Phase 2.1 정합 검증 시 환불 합 부풀려져 fallback 비례 진입 (회원 193001000334 케이스).
        if (ll.EventType == 'Credit'
            && ll.IsDeleted == false
            && ll.TransactionJournal != null
            && ll.TransactionJournal.IsDeleted__c == false
            && ll.TransactionJournal.OrderId != null
            && ll.TransactionJournal.JournalSubType != null
            && ll.TransactionJournal.JournalSubType.Name == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL) {
          cancelLLToOrderId.put(ll.Id, ll.TransactionJournal.OrderId);
        }
      }
    }

    Map<Id, Integer> accrualUsedPointMap = buildAccrualUsedPointMap(
        memberId, accrualLedgerIds, orderRedeemCancelMap, orderPointUsedMap, orderDeletedDebitMap, redeemCancelCreditOriginMap,
        redeemCancelCreditOriginPortions, cancelLLToOrderId, hiddenRestoreCreditOriginPortions);
    Map<Id, Integer> accrualSaleCancelPointMap = buildAccrualSaleCancelPointMap(memberId, accrualLedgerIds);
    Map<Id, Integer> accrualReductionPointMap = buildAccrualReductionPointMap(memberId, accrualLedgerIds);
    Map<Id, Integer> accrualExpiredPointMap = buildAccrualExpiredPointMap(
        memberId, creditLedgers, accrualReductionPointMap, ecoRestoreLLToOriginLLId,
        hiddenRestoreCreditOriginPortions, activeReturnRestoreCreditOriginPortions, optionCRestoreDirectOriginPortionsBySourceTj);
    PaymentSummaryResult paymentSummary = buildPaymentSummaryMaps(accrualOrderIds);
    Map<Id, Integer> pointPaymentSummaryMap = paymentSummary.pointByOrderId;
    Map<Id, Integer> couponPaymentSummaryMap = paymentSummary.couponByOrderId;

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
        Integer saleCanceledPoints = accrualSaleCancelPointMap.containsKey(ll.Id) ? accrualSaleCancelPointMap.get(ll.Id) : 0;
        Integer originalSavePoints = ll.Points == null ? 0 : ll.Points.intValue();
        Integer effectiveSavePoints = Math.max(0, originalSavePoints - saleCanceledPoints);
        if (effectiveSavePoints <= 0) {
          continue;
        }
        Integer usedSalePoints = (orderId != null && pointPaymentSummaryMap.containsKey(orderId)) ? pointPaymentSummaryMap.get(orderId) : 0;
        Integer usedSaleCouponAmount = (orderId != null && couponPaymentSummaryMap.containsKey(orderId)) ? couponPaymentSummaryMap.get(orderId) : 0;
        PointResDto.CreditPointResponse response = new PointResDto.CreditPointResponse(
          ll,
          usedPoints,
          destroyedPoints,
          usedSalePoints,
          usedSaleCouponAmount
        );
        response.PT_SAVE = effectiveSavePoints;
        if (ll.TransactionJournal != null
            && isOptionCSalePatchForceCreditNote(ll.TransactionJournal.AdditionalNotes__c)
            && ll.TransactionJournal.OrderId != null
            && ll.LoyaltyPgmCrcySubtypeId != null
            && ll.ExpiryDate != null) {
          String displayKey = buildRestoreOriginKey(ll.TransactionJournal.OrderId, ll.LoyaltyPgmCrcySubtypeId, ll.ExpiryDate);
          LoyaltyLedger baseCredit = optionCBaseCreditByDisplayKey.get(displayKey);
          if (baseCredit != null) {
            PointResDto.CreditPointResponse baseDisplay = new PointResDto.CreditPointResponse(baseCredit, 0, 0, usedSalePoints, usedSaleCouponAmount);
            response.YM_CREATE = baseDisplay.YM_CREATE;
            response.NM_TYPE_SAVE = baseDisplay.NM_TYPE_SAVE;
            response.DT_SAVE = baseDisplay.DT_SAVE;
            response.DT_SAVE_PLAN = baseDisplay.DT_SAVE_PLAN;
            response.DT_LIMIT_START = baseDisplay.DT_LIMIT_START;
            response.DT_LIMIT_END = baseDisplay.DT_LIMIT_END;
            response.DT_DESTROY_PLAN = baseDisplay.DT_DESTROY_PLAN;
            response.NO_PROM_MBR = baseDisplay.NO_PROM_MBR;
          }
        }

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
    // 26.05.05 CS - 정렬 키 (YM_CREATE / NO_SAL / UsagePriorityNumber / Id) 오름차순 적용
    creditSortables.sort();
    creditPointResponseList.clear();
    for (CreditSortable s : creditSortables) {
      creditPointResponseList.add(s.response);
    }
    creditPointResponseList = aggregateCreditPointResponsesForDisplay(creditPointResponseList);
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

    // [HideUseRowOnInputDepositDelete Fix 2026-05-05]
    //   배경: 사용자 정책 — "포인트 사용 입금 건을 삭제하면 사용 행이 사라져야 한다."
    //         그러나 v3 paradigm 에서 입금 삭제 시 원 Point Debit TJ 는 IsDeleted=FALSE 로 보존되어
    //         회원도움창 SOQL 매칭으로 사용 행이 그대로 노출되는 문제.
    //   식별: 입금 삭제 흐름 (GdSaleDepositServiceImpl.cls:1498) 은 Cancel TJ 에 'del_point_*' prefix 부여.
    //         반품 흐름은 prefix 없는 일반 DepositNo. 이 차이로 두 시나리오 구분.
    //   해결: Flag ON 시 'del_point_*' Cancel TJ 의 OrderId+원본DepositNo 셋 빌드 →
    //         그 셋과 일치하는 원 Debit TJ 의 LLT 는 응답에서 제외.
    //   회귀 안전:
    //     - Flag OFF: 기존 SOQL 그대로 (회귀 영향 없음).
    //     - Flag ON: 시나리오 1 (일반 사용), 2 (반품으로 사용 취소), 3 (반품 입금 삭제) 영향 없음 검증.
    //                시나리오 4 (사용 입금 삭제) 만 사용 행 사라짐 (의도된 동작).
    //     - PT_USE 계산 (buildAccrualUsedPointMap) 은 별도 SOQL 이며 영향 없음.
    Boolean hideUseRowOnInputDelete = GdFeatureFlag.isEnabled('HideUseRowOnInputDepositDelete');
    Set<Id> excludeDebitTjIds = new Set<Id>();
    if (hideUseRowOnInputDelete) {
      // Step A: 활성 'del_point_*' Cancel TJ 조회 — (OrderId, 원본DepositNo) 추출
      Map<Id, Set<String>> excludeOrigDepositNoByOrderId = new Map<Id, Set<String>>();
      Map<String, Datetime> excludeCutoffByOrderDepositKey = new Map<String, Datetime>();
      for (TransactionJournal cancelTj : [
        SELECT Id, OrderId, DepositNo__c, CreatedDate
        FROM TransactionJournal
        WHERE MemberId = :memberId
          AND IsDeleted__c = FALSE
          AND DepositNo__c LIKE 'del_point_%'
          AND JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
        LIMIT 5000
      ]) {
        if (cancelTj.OrderId == null || String.isBlank(cancelTj.DepositNo__c)) {
          continue;
        }
        // 원본 DepositNo = 'del_point_' 이후 문자열
        String origDepositNo = cancelTj.DepositNo__c.substring('del_point_'.length());
        if (String.isBlank(origDepositNo)) {
          continue;
        }
        if (!excludeOrigDepositNoByOrderId.containsKey(cancelTj.OrderId)) {
          excludeOrigDepositNoByOrderId.put(cancelTj.OrderId, new Set<String>());
        }
        excludeOrigDepositNoByOrderId.get(cancelTj.OrderId).add(origDepositNo);
        String cutoffKey = String.valueOf(cancelTj.OrderId) + '|' + origDepositNo;
        if (!excludeCutoffByOrderDepositKey.containsKey(cutoffKey)
            || cancelTj.CreatedDate < excludeCutoffByOrderDepositKey.get(cutoffKey)) {
          excludeCutoffByOrderDepositKey.put(cutoffKey, cancelTj.CreatedDate);
        }
      }

      // Step B: 매칭되는 원 Point Debit TJ Id 셋 빌드 (OrderId + DepositNo 단위 정확 매칭)
      if (!excludeOrigDepositNoByOrderId.isEmpty()) {
        Set<Id> targetOrderIds = excludeOrigDepositNoByOrderId.keySet();
        Set<String> allOrigDepositNos = new Set<String>();
        for (Set<String> s : excludeOrigDepositNoByOrderId.values()) {
          allOrigDepositNos.addAll(s);
        }
        for (TransactionJournal origTj : [
          SELECT Id, OrderId, DepositNo__c, CreatedDate
          FROM TransactionJournal
          WHERE MemberId = :memberId
            AND OrderId IN :targetOrderIds
            AND DepositNo__c IN :allOrigDepositNos
            AND JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_POINT_DEBIT
            AND IsDeleted__c = FALSE
          LIMIT 5000
        ]) {
          // (OrderId, DepositNo) 정확 매칭 확인 (cross-order 오매칭 방지)
          Set<String> depositNosForOrder = excludeOrigDepositNoByOrderId.get(origTj.OrderId);
          String cutoffKey = String.valueOf(origTj.OrderId) + '|' + origTj.DepositNo__c;
          Datetime cutoff = excludeCutoffByOrderDepositKey.get(cutoffKey);
          if (depositNosForOrder != null
              && depositNosForOrder.contains(origTj.DepositNo__c)
              && cutoff != null
              && origTj.CreatedDate <= cutoff) {
            excludeDebitTjIds.add(origTj.Id);
          }
        }
      }
    }

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
        LoyaltyPgmCurrencySubtype.UsagePriorityNumber, // 26.05.05 CS - UserDestoryHistoryList 정렬 키
        LoyaltyPgmCurrencySubtype.PointTypeCode__c, // 정렬 정책 2026-05-05 - 포인트구분
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
        DebitLoyaltyLedger.TransactionJournal.JournalType.Name,
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
      // [HideUseRowOnInputDepositDelete Fix 2026-05-05]
      //   - excludeDebitTjIds 가 비어있지 않으면 (Flag ON + del_point_* Cancel 존재) 해당 Debit TJ Id 의 LLT 제외.
      //   - bind variable 은 Flag OFF 시에도 빈 셋으로 평가되므로 SOQL 동작에 영향 없음 (NOT IN empty = always true).
      WHERE
        ((ActionType = 'Debit'
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (CreditLoyaltyLedger.TransactionJournalId = NULL
        OR CreditLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR (NOT DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c LIKE :OPTION_C_RETURN_DEPOSIT_DELETE_USAGE_RESTORE_NOTE_LIKE))
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :ADDITIONAL_NOTE_FULL_RETURN_ECO_POINT_CANCEL)
        AND (DebitLoyaltyLedger.TransactionJournalId NOT IN :excludeDebitTjIds))
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
    // [PT_USE Round-off Fix 2026-05-05] Order 단위 사용 LLT 의 통합 비례 감산을 위한 사전 집계.
    //   기존: LLT 별 개별 비례 감산 (정수 나눗셈) → round-off 누적으로 합계가 정확값 미만.
    //   수정: 같은 Debit OrderId 의 활성 'Debit' LLT 들의 원본 Points 합계를 미리 집계 →
    //         루프 내에서 LLT 별 비례 분배 + 마지막 LLT 에 round-off 보정.
    //   효과: 같은 주문의 사용 행 PT_USE 합계가 (orderUsed - effectiveCancel) 와 정확히 일치.
    Map<Id, Integer> orderTotalRawDebit = new Map<Id, Integer>();
    Map<Id, Integer> orderActiveDebitCount = new Map<Id, Integer>();
    Map<Id, Integer> orderProcessedDebitCount = new Map<Id, Integer>();
    Map<Id, Integer> orderAllocatedNet = new Map<Id, Integer>();
    for (LoyaltyLedgerTraceability llt : lltList) {
      if (llt.ActionType == 'Debit'
          && llt.DebitLoyaltyLedger != null
          && llt.DebitLoyaltyLedger.TransactionJournal != null
          && llt.DebitLoyaltyLedger.TransactionJournal.OrderId != null
          && llt.Points != null) {
        Id oid = llt.DebitLoyaltyLedger.TransactionJournal.OrderId;
        Integer pts = llt.Points.abs().intValue();
        Integer prev = orderTotalRawDebit.containsKey(oid) ? orderTotalRawDebit.get(oid) : 0;
        orderTotalRawDebit.put(oid, prev + pts);
        Integer cnt = orderActiveDebitCount.containsKey(oid) ? orderActiveDebitCount.get(oid) : 0;
        orderActiveDebitCount.put(oid, cnt + 1);
      }
    }

    // [Phase 3.1 2026-05-06] portions 기반 (orderId, originLLId) → 환불액 맵 빌드.
    //   사용자 정책: 환불(=사용 취소) 은 사용 행에 origin 별로 정확히 차감 → 0행 은 제거.
    //   기존 비례 감산은 Order 합 정합만 보장하고 origin 별 분포는 비례 분배 (부정확).
    //   Phase 3.1 은 portions 매핑이 환불 전체를 커버하는 경우 (정합) → origin 직접 차감으로 전환.
    Map<Id, Map<Id, Integer>> orderToOriginRefundDestory = new Map<Id, Map<Id, Integer>>();
    // 처리 중 차감되는 잔여 환불액 (LLT 처리 루프 내에서 점차 감소)
    Map<Id, Map<Id, Integer>> orderOriginRefundRemaining = new Map<Id, Map<Id, Integer>>();
    if (redeemCancelCreditOriginPortions != null && cancelLLToOrderId != null
        && !redeemCancelCreditOriginPortions.isEmpty() && !cancelLLToOrderId.isEmpty()) {
      for (Id cancelLLId : redeemCancelCreditOriginPortions.keySet()) {
        Id refundOrderId = cancelLLToOrderId.get(cancelLLId);
        if (refundOrderId == null) continue;
        List<OriginPortion> portions = redeemCancelCreditOriginPortions.get(cancelLLId);
        if (portions == null) continue;
        if (!orderToOriginRefundDestory.containsKey(refundOrderId)) {
          orderToOriginRefundDestory.put(refundOrderId, new Map<Id, Integer>());
          orderOriginRefundRemaining.put(refundOrderId, new Map<Id, Integer>());
        }
        Map<Id, Integer> originRefund = orderToOriginRefundDestory.get(refundOrderId);
        Map<Id, Integer> originRemaining = orderOriginRefundRemaining.get(refundOrderId);
        for (OriginPortion p : portions) {
          if (p.originCreditLLId == null) continue;
          Integer prev = originRefund.containsKey(p.originCreditLLId) ? originRefund.get(p.originCreditLLId) : 0;
          originRefund.put(p.originCreditLLId, prev + (p.points == null ? 0 : p.points));
          Integer prevR = originRemaining.containsKey(p.originCreditLLId) ? originRemaining.get(p.originCreditLLId) : 0;
          originRemaining.put(p.originCreditLLId, prevR + (p.points == null ? 0 : p.points));
        }
      }
    }

    // [Sort Fix 2026-04-28] UserDestoryHistoryList 정렬 — response 별 representative LLT 정렬 키 보존용
    List<DebitSortable> debitSortablesAll = new List<DebitSortable>();
    if (!lltList.isEmpty()) {
      for (LoyaltyLedgerTraceability llt : lltList) {
        if (isSaleModificationCreditCancellation(llt)) {
          continue;
        }
        PointResDto.DebitPointResponse response = new PointResDto.DebitPointResponse(llt);
        if ((llt.ActionType == 'DebitCancellation' || llt.ActionType == 'CreditCancellation') && llt.Points != null) {
          response.PT_USE = Integer.valueOf(llt.Points.abs());
        }
        if (llt.ActionType == 'CreditCancellation'
            && llt.CreditLoyaltyLedgerId != null
            && activeRestoreRemainingByOriginCreditLLId.containsKey(llt.CreditLoyaltyLedgerId)) {
          Integer restoreRemaining = activeRestoreRemainingByOriginCreditLLId.get(llt.CreditLoyaltyLedgerId);
          Integer currentUse = response.PT_USE == null ? 0 : response.PT_USE;
          Integer restored = Math.min(restoreRemaining, currentUse);
          response.PT_USE = currentUse - restored;
          activeRestoreRemainingByOriginCreditLLId.put(llt.CreditLoyaltyLedgerId, restoreRemaining - restored);
          if (response.PT_USE <= 0) {
            continue;
          }
        }
        if (llt.ActionType == 'CreditCancellation') {
          response.NO_SAL = '';
          response.NO_SAL_SAVE = (llt.CreditLoyaltyLedger != null &&
            llt.CreditLoyaltyLedger.TransactionJournal != null &&
            llt.CreditLoyaltyLedger.TransactionJournal.Order != null &&
            String.isNotBlank(llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c))
            ? llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c
            : response.NO_SAL_SAVE;
          response.NO_SAL_RTN = (llt.DebitLoyaltyLedger != null &&
            llt.DebitLoyaltyLedger.TransactionJournal != null &&
            llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r != null &&
            llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c == true &&
            String.isNotBlank(llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c))
            ? llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c
            : '';
          if (llt.CreditLoyaltyLedgerId != null
              && hiddenRestoreCreditOriginPortions.containsKey(llt.CreditLoyaltyLedgerId)) {
            List<OriginPortion> portions = hiddenRestoreCreditOriginPortions.get(llt.CreditLoyaltyLedgerId);
            if (portions != null && !portions.isEmpty()) {
              OriginPortion originPortion = portions[0];
              Id originCreditLLId = originPortion == null ? null : originPortion.originCreditLLId;
              String originSaleNo = originCreditLLId != null && saleNoByCreditLLId.containsKey(originCreditLLId)
                ? saleNoByCreditLLId.get(originCreditLLId)
                : '';
              if (String.isNotBlank(originSaleNo)) {
                response.NO_SAL_SAVE = originSaleNo;
              }
              if (originCreditLLId != null && ledgerIdToActivityDateForDisplay.containsKey(originCreditLLId)) {
                Datetime originActivityDate = ledgerIdToActivityDateForDisplay.get(originCreditLLId);
                if (originActivityDate != null) {
                  response.DT_SAVE = originActivityDate.format('yyyyMMdd');
                }
              }
            }
          }
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

        // [정책 2/3 복원 Fix 2026-05-05] "사용(Debit)" 로우에 주문 단위 취소 반영
        //   정책: A판매에서 1,000P 사용 → 반품으로 일부(500) 환불 → 사용 행 PT_USE 1,000 → 500 으로 감산.
        //         A판매에서 1,000P 사용 → 반품으로 전액(1,000) 환불 → 사용 행 자체 제거.
        //   계산: effectiveCancel = max(0, orderRedeemCancelMap - orderDeletedDebitMap)
        //         (DELETE /sale/deposit 경로에서 이미 삭제 Debit 과 상쇄된 Cancel 분 제외)
        //   전액 취소 (effectiveCancel >= orderUsed) → 사용 행 스킵
        //   부분 취소 → PT_USE 비례 감산 (PT_USE * (orderUsed - effectiveCancel) / orderUsed)
        //   DebitCancellation/CreditCancellation 로우는 위에서 이미 처리되어 영향 없음.
        Boolean skipThisDebitRow = false;
        if (llt.ActionType == 'Debit'
            && llt.DebitLoyaltyLedger != null
            && llt.DebitLoyaltyLedger.TransactionJournal != null
            && llt.DebitLoyaltyLedger.TransactionJournal.OrderId != null) {
          Id debitOrderId = llt.DebitLoyaltyLedger.TransactionJournal.OrderId;
          Integer rawCancel = orderRedeemCancelMap.containsKey(debitOrderId)
              ? orderRedeemCancelMap.get(debitOrderId) : 0;
          Integer deletedDebit = orderDeletedDebitMap.containsKey(debitOrderId)
              ? orderDeletedDebitMap.get(debitOrderId) : 0;
          Integer effectiveCancel = Math.max(0, rawCancel - deletedDebit);
          Integer orderUsed = orderPointUsedMap.containsKey(debitOrderId)
              ? orderPointUsedMap.get(debitOrderId) : 0;

          if (effectiveCancel > 0 && orderUsed > 0 && effectiveCancel >= orderUsed) {
            skipThisDebitRow = true;
          }

          // [Phase 3.1 2026-05-06] portions 정합 시 origin 직접 차감 모드 진입 여부.
          //   조건: 해당 Order 에 portions 매핑 환불 합 == effectiveCancel (정합).
          //   정합 시 → 비례 감산 / 전액 취소 분기 둘 다 우회 (Phase 3 split 분기에서 origin 별 직접 차감).
          //   부정합 시 → 기존 비례 감산 / 전액 취소 분기 그대로 (fallback, 회귀 안전).
          Boolean useDirectOriginRefundDestory = false;
          if (!skipThisDebitRow) {
            Map<Id, Integer> originRefundForThisOrder = orderToOriginRefundDestory.get(debitOrderId);
            if (originRefundForThisOrder != null && !originRefundForThisOrder.isEmpty()
                && effectiveCancel > 0) {
              Integer totalOriginRefund = 0;
              for (Integer v : originRefundForThisOrder.values()) totalOriginRefund += v;
              if (totalOriginRefund == effectiveCancel) {
                useDirectOriginRefundDestory = true;
              }
            }
          }

          if (!skipThisDebitRow && effectiveCancel > 0 && orderUsed > 0 && !useDirectOriginRefundDestory) {
            if (effectiveCancel >= orderUsed) {
              // 전액 취소 → 이 사용 행 스킵 (정책 3)
              skipThisDebitRow = true;
            } else {
              // 부분 취소 → PT_USE Order 단위 통합 비례 분배 (정책 2)
              //   기존(LLT별 정수 나눗셈) → round-off 누적으로 합계가 (orderUsed-effectiveCancel) 미만 발생.
              //   변경: 같은 Order 활성 Debit LLT 들에 net 을 비례 분배하고,
              //         마지막 LLT 에 누적 round-off 보정으로 합계가 정확히 net 과 일치.
              Integer originalPt = response.PT_USE != null ? response.PT_USE : 0;
              Integer netUsed = orderUsed - effectiveCancel;
              Integer rawTotal = orderTotalRawDebit.containsKey(debitOrderId)
                  ? orderTotalRawDebit.get(debitOrderId) : 0;
              Integer activeCnt = orderActiveDebitCount.containsKey(debitOrderId)
                  ? orderActiveDebitCount.get(debitOrderId) : 0;
              Integer processed = orderProcessedDebitCount.containsKey(debitOrderId)
                  ? orderProcessedDebitCount.get(debitOrderId) : 0;
              Integer allocated = orderAllocatedNet.containsKey(debitOrderId)
                  ? orderAllocatedNet.get(debitOrderId) : 0;
              Integer adjusted;
              if (rawTotal > 0 && activeCnt > 0 && processed + 1 == activeCnt) {
                // 마지막 LLT — round-off 보정: 남은 net 을 모두 할당
                adjusted = netUsed - allocated;
                if (adjusted < 0) adjusted = 0;
              } else if (rawTotal > 0) {
                // [Phase 3 Fix 2026-05-06] Integer 오버플로 방지 — Long 캐스팅.
                //   기존: originalPt * netUsed 가 Integer 곱셈으로 처리되어
                //   60000 * 50000 = 3,000,000,000 > Integer.MAX (2,147,483,647) → 오버플로 음수 발생.
                //   merge 시 round-off 보정으로 합은 유지되지만 개별 row 분포는 음수/큰값 으로 잘못됨.
                Long num = (Long) originalPt * (Long) netUsed;
                adjusted = (Integer) (num / (Long) rawTotal);
              } else {
                Long num = (Long) originalPt * (Long) netUsed;
                adjusted = (Integer) (num / (Long) orderUsed);
              }
              response.PT_USE = adjusted;
              orderProcessedDebitCount.put(debitOrderId, processed + 1);
              orderAllocatedNet.put(debitOrderId, allocated + adjusted);
            }
          }

          // [2026-04-25 / 2026-05-03 NO_SAL_SAVE 보정 Fix] (유지)
          //   Cancel Credit 을 사용한 Debit 로우의 NO_SAL_SAVE 를 원 Credit 의 판매번호로 교체.
          //   수동 적립/마이그레이션 적립 케이스 (원 Credit.TJ.OrderId=null) 도 빈 값으로 덮어쓰기.
          if (!skipThisDebitRow
              && llt.CreditLoyaltyLedgerId != null
              && redeemCancelCreditOriginMap.containsKey(llt.CreditLoyaltyLedgerId)) {
            Id originCid = redeemCancelCreditOriginMap.get(llt.CreditLoyaltyLedgerId);
            if (originCid != null) {
              String originSaleNo = saleNoByCreditLLId.containsKey(originCid)
                  ? saleNoByCreditLLId.get(originCid)
                  : '';
              response.NO_SAL_SAVE = String.isNotBlank(originSaleNo) ? originSaleNo : '';
            }
          }
        }

        // [Origin ActivityDate Fix 2026-05-06] Flag ON 시 Cancel Credit 의 사용 LLT 의 DT_SAVE 를 원 적립일로 덮어쓰기
        //   LMS 데이터의 Cancel Credit ActivityDate=today 결함을 화면 표시 단계에서만 보정.
        //   Cancel-of-Cancel 다단도 재귀 추적으로 최종 origin ActivityDate 사용.
        if (!skipThisDebitRow
            && preserveOriginActivityDate
            && llt.CreditLoyaltyLedgerId != null
            && cancelLLToOriginActivityDate.containsKey(llt.CreditLoyaltyLedgerId)) {
          Datetime origDate = cancelLLToOriginActivityDate.get(llt.CreditLoyaltyLedgerId);
          if (origDate != null) {
            response.DT_SAVE = origDate.format('yyyyMMdd');
          }
        }

        if (skipThisDebitRow) {
          continue;
        }

        // [Phase 3 Precise Origin DT_SAVE 분할 2026-05-06] Cancel Credit 의 사용 LLT 가 portions 매핑에 있으면
        //   portions 비율로 N개 분할 row 생성 (각 row 의 DT_SAVE / NO_SAL_SAVE 가 origin 별 정확).
        //   Flag OFF (portions=null) 또는 매핑 없음 → 기존 단일 row 그대로.
        // [Phase 3.1 2026-05-06] Phase 3.1 모드 ON 시 — split 후 각 row 에 origin 잔여 환불 직접 차감 (0 row 제거).
        //   직접 사용 LLT (적립 LL) 도 자기 origin 잔여 환불 직접 차감.
        Boolean splitByPortions = false;
        Id debitOrderForRefund = (llt.ActionType == 'Debit'
            && llt.DebitLoyaltyLedger != null
            && llt.DebitLoyaltyLedger.TransactionJournal != null)
            ? llt.DebitLoyaltyLedger.TransactionJournal.OrderId : null;
        Boolean phase31Active = (debitOrderForRefund != null
            && orderOriginRefundRemaining.containsKey(debitOrderForRefund));
        // 정합 검증 — 해당 Order 의 portions 환불 합 == effectiveCancel
        if (phase31Active) {
          Integer totRef = 0;
          Map<Id, Integer> oref = orderToOriginRefundDestory.get(debitOrderForRefund);
          if (oref != null) for (Integer v : oref.values()) totRef += v;
          Integer rawC = orderRedeemCancelMap.containsKey(debitOrderForRefund)
              ? orderRedeemCancelMap.get(debitOrderForRefund) : 0;
          Integer delD = orderDeletedDebitMap.containsKey(debitOrderForRefund)
              ? orderDeletedDebitMap.get(debitOrderForRefund) : 0;
          Integer effC = Math.max(0, rawC - delD);
          if (totRef != effC) {
            phase31Active = false;
          }
        }

        if (llt.ActionType == 'Debit'
            && llt.CreditLoyaltyLedgerId != null
            && redeemCancelCreditOriginPortions != null
            && redeemCancelCreditOriginPortions.containsKey(llt.CreditLoyaltyLedgerId)) {
          List<OriginPortion> portions = redeemCancelCreditOriginPortions.get(llt.CreditLoyaltyLedgerId);
          if (portions != null && !portions.isEmpty()) {
            // portions 기반 row 생성 — size==1 도 정확한 origin 사용 위해 처리
            //   (기존 cancelLLToOriginActivityDate 의 단일 매핑은 다중 origin 케이스에서 잘못된 origin 가리킬 수 있음).
            Integer baseUse = (response.PT_USE == null ? 0 : response.PT_USE);
            Integer totalPortionPts = 0;
            for (OriginPortion p : portions) totalPortionPts += (p.points == null ? 0 : p.points);
            if (totalPortionPts > 0 && baseUse > 0) {
              Integer allocated = 0;
              Integer lastIdx = portions.size() - 1;
              for (Integer i = 0; i < portions.size(); i++) {
                OriginPortion p = portions[i];
                Integer share;
                if (i == lastIdx) {
                  share = baseUse - allocated;
                  if (share < 0) share = 0;
                } else {
                  Long num = (Long) baseUse * (Long) (p.points == null ? 0 : p.points);
                  share = (Integer) (num / (Long) totalPortionPts);
                }
                allocated += share;
                if (share <= 0) {
                  continue;
                }
                // [Phase 3.1] 모드 ON 시 origin 잔여 환불 직접 차감
                Integer netShare = share;
                if (phase31Active && p.originCreditLLId != null) {
                  Map<Id, Integer> remaining = orderOriginRefundRemaining.get(debitOrderForRefund);
                  if (remaining != null && remaining.containsKey(p.originCreditLLId)) {
                    Integer rem = remaining.get(p.originCreditLLId);
                    if (rem > 0) {
                      Integer take = Math.min(rem, share);
                      netShare = share - take;
                      remaining.put(p.originCreditLLId, rem - take);
                    }
                  }
                  if (netShare <= 0) continue; // 0 행 제거
                }
                // 새 response 인스턴스 생성 — 같은 LLT 기반, PT_USE / DT_SAVE / NO_SAL_SAVE 만 origin 별로
                PointResDto.DebitPointResponse splitResp = new PointResDto.DebitPointResponse(llt);
                splitResp.PT_USE = netShare;
                // DT_SAVE = origin LL.ActivityDate (있으면)
                if (originLLToActivityDate != null && p.originCreditLLId != null
                    && originLLToActivityDate.containsKey(p.originCreditLLId)) {
                  Datetime od = originLLToActivityDate.get(p.originCreditLLId);
                  if (od != null) {
                    splitResp.DT_SAVE = od.format('yyyyMMdd');
                  }
                }
                // NO_SAL_SAVE = origin LL 의 SaleNo. origin 이 saleNoByCreditLLId 에 없으면 (수동 적립 등) 빈 값.
                String osn = '';
                if (p.originCreditLLId != null && saleNoByCreditLLId.containsKey(p.originCreditLLId)) {
                  String s = saleNoByCreditLLId.get(p.originCreditLLId);
                  osn = String.isNotBlank(s) ? s : '';
                }
                splitResp.NO_SAL_SAVE = osn;
                debitPointResponseList.add(splitResp);
                debitSortablesAll.add(new DebitSortable(splitResp, llt));
              }
              splitByPortions = true;
            }
          }
        }

        if (!splitByPortions) {
          // [Phase 3.1] 직접 사용 LLT — 자기 origin (LLT.CreditLoyaltyLedgerId) 잔여 환불 직접 차감
          if (phase31Active
              && llt.ActionType == 'Debit'
              && llt.CreditLoyaltyLedgerId != null) {
            Map<Id, Integer> remaining = orderOriginRefundRemaining.get(debitOrderForRefund);
            Integer baseUse = (response.PT_USE == null ? 0 : response.PT_USE);
            if (remaining != null && remaining.containsKey(llt.CreditLoyaltyLedgerId) && baseUse > 0) {
              Integer rem = remaining.get(llt.CreditLoyaltyLedgerId);
              if (rem > 0) {
                Integer take = Math.min(rem, baseUse);
                Integer netUseAdj = baseUse - take;
                remaining.put(llt.CreditLoyaltyLedgerId, rem - take);
                response.PT_USE = netUseAdj;
                if (netUseAdj <= 0) continue; // 0 행 제거
              }
            }
          }
          debitPointResponseList.add(response);
          debitSortablesAll.add(new DebitSortable(response, llt));
        }
      }
    }

    // [정책 변경 2026-05-05] "포인트 사용 취소" 합성 행 제거 (정책 5)
    //   배경: 사용 행 PT_USE 감산/제거 정책 (정책 2/3) 으로 환불 효과가 사용 행 자체에 반영됨.
    //         별도 "포인트 사용 취소" 행은 회원/운영자에게 중복 정보 + 노이즈가 되므로 제거.
    //   영향: UserDestoryHistoryList row 수가 줄어듦. 다른 영역 영향 없음.

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
        // 정렬 정책 2026-05-05 - fallback 은 LLT=null 로 첫 번째 생성자 호출 (이론상 도달 불가, 안전장치).
        DebitSortable sk = (i < debitSortablesAll.size()) ? debitSortablesAll[i] : new DebitSortable(r, (LoyaltyLedgerTraceability) null);
        Boolean isUsageRow = ('사용'.equals(r.NM_PERSON)) && String.isNotBlank(r.NO_SAL);
        if (!isUsageRow) {
          mergedList.add(r);
          debitSortablesMerged.add(sk);
          continue;
        }
        // [Phase 3 Fix 2026-05-06] Flag ON 시에만 DT_SAVE 도 키에 포함 — portions 분할 row 가 같은
        //   NO_SAL+NM_TYPE_POINT+NO_SAL_SAVE 조합이지만 DT_SAVE 가 다른 경우 (다중 origin) 별 row 로 유지.
        //   Flag OFF 면 기존 동작 그대로 (회귀 영향 0).
        String key;
        if (redeemCancelCreditOriginPortions != null && !redeemCancelCreditOriginPortions.isEmpty()) {
          key = String.valueOf(r.NO_SAL) + '|'
              + (r.NM_TYPE_POINT == null ? '' : r.NM_TYPE_POINT) + '|'
              + (r.NO_SAL_SAVE == null ? '' : r.NO_SAL_SAVE) + '|'
              + (r.DT_SAVE == null ? '' : r.DT_SAVE);
        } else {
          key = String.valueOf(r.NO_SAL) + '|'
              + (r.NM_TYPE_POINT == null ? '' : r.NM_TYPE_POINT) + '|'
              + (r.NO_SAL_SAVE == null ? '' : r.NO_SAL_SAVE);
        }
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

    // 26.05.05 CS - 정렬 키 (DT_USE / NO_SAL / NO_SAL_SAVE / UsagePriorityNumber / Id) 오름차순 적용
    if (!debitSortablesMerged.isEmpty()) {
      debitSortablesMerged.sort();
      debitPointResponseList = new List<PointResDto.DebitPointResponse>();
      for (DebitSortable s : debitSortablesMerged) {
        debitPointResponseList.add(s.response);
      }
    }

    // [Group-By Aggregation Fix 2026-05-06]
    //   사용자 정책: 같은 (YM_CREATE, NM_TYPE_POINT, NM_PERSON, DT_USE, NO_SAL, DT_SAVE, NO_SAL_ORD) 그룹의
    //   사용 행을 단일 행으로 통합하여 PT_USE 합산. NO_SAL_SAVE, NO_SAL_RTN 도 키에 포함하여 사용 취소 행 분리 유지.
    //   배경: 회원 043004800023 SOR202605060282 케이스 — 구매포인트 5,738 + 88,524 가 별도 2행으로 표시되는 결함.
    //         그룹바이로 단일 행 (94,262) 통합 → 사용자 직관 개선.
    //   효과:
    //     - 같은 SubType + 같은 NO_SAL_ORD/NO_SAL 의 분리 행 → 1행 통합 (PT_USE 합산).
    //     - 다른 SubType (구매 vs 기타) 은 자연 분리 유지.
    //     - 정렬은 통합 전에 이미 적용됨 → 통합 후 첫 행의 정렬 위치 유지.
    //     - Accrual PT_USE 합 = Destory 사용 합 일관성 보장 (단순 통합이라 합 변화 없음).
    debitPointResponseList = aggregateDestoryRowsByGroup(debitPointResponseList);

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

  // [정렬 정책 2026-05-05] AccrualHistoryList 정렬 키 (정책 6).
  //   순서: 1) 적립월 (YM_CREATE)  2) 판매번호 (NO_SAL)
  //         3) 포인트구분 (LoyaltyPgmCrcySubtype.PointTypeCode__c)
  //         4) ll.Id (tie-breaker)
  //   - 모두 오름차순. 응답 스펙 변경 없음.
  private static List<PointResDto.CreditPointResponse> aggregateCreditPointResponsesForDisplay(
      List<PointResDto.CreditPointResponse> rows
  ) {
    List<PointResDto.CreditPointResponse> result = new List<PointResDto.CreditPointResponse>();
    if (rows == null || rows.isEmpty()) {
      return result;
    }

    Map<String, PointResDto.CreditPointResponse> rowByKey = new Map<String, PointResDto.CreditPointResponse>();
    List<String> keyOrder = new List<String>();
    for (PointResDto.CreditPointResponse row : rows) {
      if (row == null) {
        continue;
      }
      String key = buildCreditDisplayAggregateKey(row);
      if (!rowByKey.containsKey(key)) {
        rowByKey.put(key, row);
        keyOrder.add(key);
        continue;
      }

      PointResDto.CreditPointResponse base = rowByKey.get(key);
      base.PT_SAVE_PLAN = safeAdd(base.PT_SAVE_PLAN, row.PT_SAVE_PLAN);
      base.PT_SAVE = safeAdd(base.PT_SAVE, row.PT_SAVE);
      base.PT_USE = safeAdd(base.PT_USE, row.PT_USE);
      base.PT_DESTROY = safeAdd(base.PT_DESTROY, row.PT_DESTROY);
      base.PT_TARGET = safeAdd(base.PT_TARGET, row.PT_TARGET);

      // Sale-level payment summaries can be repeated on delta accrual rows.
      base.PT_USE_SALE = safeMax(base.PT_USE_SALE, row.PT_USE_SALE);
      base.PT_USE_SALE_COUPON = safeMax(base.PT_USE_SALE_COUPON, row.PT_USE_SALE_COUPON);
      base.AM_SAL = safeMax(base.AM_SAL, row.AM_SAL);

      if (String.isBlank(base.DT_DESTROY_DEL_SALE) && String.isNotBlank(row.DT_DESTROY_DEL_SALE)) {
        base.DT_DESTROY_DEL_SALE = row.DT_DESTROY_DEL_SALE;
      }
      if (String.isBlank(base.DT_DESTROY_PLAN) && String.isNotBlank(row.DT_DESTROY_PLAN)) {
        base.DT_DESTROY_PLAN = row.DT_DESTROY_PLAN;
      }
    }

    for (String key : keyOrder) {
      result.add(rowByKey.get(key));
    }
    return result;
  }

  private static String buildCreditDisplayAggregateKey(PointResDto.CreditPointResponse row) {
    return String.join(new List<String>{
      nullToBlank(row.YM_CREATE),
      nullToBlank(row.NO_SAL),
      nullToBlank(row.NM_TYPE_SAVE),
      nullToBlank(row.NM_TYPE_POINT),
      nullToBlank(row.DT_SAVE),
      nullToBlank(row.DT_LIMIT_START),
      nullToBlank(row.DT_LIMIT_END),
      nullToBlank(row.NO_PROM_MBR)
    }, '|');
  }

  private static String nullToBlank(String value) {
    return value == null ? '' : value;
  }

  private static Integer safeAdd(Integer leftValue, Integer rightValue) {
    return (leftValue == null ? 0 : leftValue) + (rightValue == null ? 0 : rightValue);
  }

  private static Integer safeMax(Integer leftValue, Integer rightValue) {
    Integer leftSafe = leftValue == null ? 0 : leftValue;
    Integer rightSafe = rightValue == null ? 0 : rightValue;
    return Math.max(leftSafe, rightSafe);
  }

  private static Boolean isSaleModificationCreditCancellation(LoyaltyLedgerTraceability llt) {
    if (llt == null || llt.ActionType != 'CreditCancellation') {
      return false;
    }
    if (llt.DebitLoyaltyLedger == null || llt.DebitLoyaltyLedger.TransactionJournal == null) {
      return false;
    }

    TransactionJournal tj = llt.DebitLoyaltyLedger.TransactionJournal;
    String journalTypeName = tj.JournalType == null ? null : tj.JournalType.Name;
    if (journalTypeName != JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL) {
      return false;
    }

    // Return-driven accrual cancellations remain visible as "포인트 지급 취소".
    if (tj.SaleId__r != null && tj.SaleId__r.IsReductionOrder__c == true) {
      return false;
    }
    return true;
  }

  private class CreditSortable implements Comparable {
    public PointResDto.CreditPointResponse response;
    public String yearMonth;
    public String saleNo;
    public String pointTypeCode;
    public String idStr;

    public CreditSortable(PointResDto.CreditPointResponse r, LoyaltyLedger ll) {
      this.response = r;
      this.yearMonth = (r != null && r.YM_CREATE != null) ? r.YM_CREATE : '';
      this.saleNo = (r != null && r.NO_SAL != null) ? r.NO_SAL : '';
      this.pointTypeCode = (ll != null
          && ll.LoyaltyPgmCrcySubtype != null
          && ll.LoyaltyPgmCrcySubtype.PointTypeCode__c != null)
        ? ll.LoyaltyPgmCrcySubtype.PointTypeCode__c
        : '';
      this.idStr = (ll != null && ll.Id != null) ? String.valueOf(ll.Id) : '';
    }

    public Integer compareTo(Object other) {
      CreditSortable o = (CreditSortable) other;
      // 1. 적립월 오름차순
      Integer cmp = yearMonth.compareTo(o.yearMonth);
      if (cmp != 0) {
        return cmp;
      }
      // 2. 판매번호 오름차순
      cmp = saleNo.compareTo(o.saleNo);
      if (cmp != 0) {
        return cmp;
      }
      // 3. 포인트구분 오름차순 (PointTypeCode)
      cmp = pointTypeCode.compareTo(o.pointTypeCode);
      if (cmp != 0) {
        return cmp;
      }
      // 4. Id (tie-breaker)
      return idStr.compareTo(o.idStr);
    }
  }

  // [정렬 정책 2026-05-05] UserDestoryHistoryList 정렬 키 (정책 6).
  //   순서: 1) 발생일자 (DT_USE, yyyyMMdd)  2) 레코드 생성일시 (LLT.CreatedDate)
  //         3) 판매번호 (NO_SAL)  4) 적립판매번호 (NO_SAL_SAVE)
  //         5) 포인트구분 (LLT.LoyaltyPgmCurrencySubtype.PointTypeCode__c)
  //         6) llt.Id (tie-breaker)
  //   - 모두 오름차순. 응답 스펙 변경 없음.
  //   - 정책 5 (합성 사용 취소 행 제거) 로 합성 행용 두 번째 생성자도 제거됨.
  private class DebitSortable implements Comparable {
    public PointResDto.DebitPointResponse response;
    public String useDate;
    public Datetime createdDt;
    public String saleNo;
    public String saleNoSave;
    public String pointTypeCode;
    public String idStr;

    // LLT 기반 (사용/소멸 행)
    public DebitSortable(PointResDto.DebitPointResponse r, LoyaltyLedgerTraceability llt) {
      this.response = r;
      this.useDate = (r != null && r.DT_USE != null) ? r.DT_USE : '';
      this.createdDt = (llt != null && llt.CreatedDate != null) ? llt.CreatedDate : null;
      this.saleNo = (r != null && r.NO_SAL != null) ? r.NO_SAL : '';
      this.saleNoSave = (r != null && r.NO_SAL_SAVE != null) ? r.NO_SAL_SAVE : '';
      this.pointTypeCode = (llt != null
          && llt.LoyaltyPgmCurrencySubtype != null
          && llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c != null)
        ? llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c
        : '';
      this.idStr = (llt != null && llt.Id != null) ? String.valueOf(llt.Id) : '';
    }

    public Integer compareTo(Object other) {
      DebitSortable o = (DebitSortable) other;
      // 1. 발생일자 오름차순 (DT_USE, yyyyMMdd)
      Integer cmp = useDate.compareTo(o.useDate);
      if (cmp != 0) {
        return cmp;
      }
      // 2. 레코드 생성일시 오름차순 (null 은 끝으로)
      Boolean aNull = (createdDt == null);
      Boolean bNull = (o.createdDt == null);
      if (aNull && !bNull) return 1;
      if (!aNull && bNull) return -1;
      if (!aNull && !bNull) {
        if (createdDt < o.createdDt) return -1;
        if (createdDt > o.createdDt) return 1;
      }
      // 3. 판매번호 오름차순
      cmp = saleNo.compareTo(o.saleNo);
      if (cmp != 0) {
        return cmp;
      }
      // 4. 적립판매번호 오름차순
      cmp = saleNoSave.compareTo(o.saleNoSave);
      if (cmp != 0) {
        return cmp;
      }
      // 5. 포인트구분 오름차순 (PointTypeCode)
      cmp = pointTypeCode.compareTo(o.pointTypeCode);
      if (cmp != 0) {
        return cmp;
      }
      // 6. Id (tie-breaker)
      return idStr.compareTo(o.idStr);
    }
  }

  /**
   * [Group-By Aggregation Fix 2026-05-06] UserDestoryHistoryList 행 통합.
   *
   * 그룹 키: YM_CREATE, NM_TYPE_POINT, NM_PERSON, DT_USE, NO_SAL, DT_SAVE, NO_SAL_ORD,
   *         NO_SAL_SAVE, NO_SAL_RTN
   * 통합 시 PT_USE 합산. 다른 필드는 첫 행 값 유지 (정렬 결과 보존).
   *
   * 입력 리스트는 정렬된 상태로 들어옴 → 통합 후에도 같은 정렬 순서 유지.
   */
  private static List<PointResDto.DebitPointResponse> aggregateDestoryRowsByGroup(
    List<PointResDto.DebitPointResponse> rows
  ) {
    if (rows == null || rows.isEmpty()) {
      return rows;
    }
    Map<String, PointResDto.DebitPointResponse> grouped = new Map<String, PointResDto.DebitPointResponse>();
    List<String> orderedKeys = new List<String>();   // 정렬 순서 보존
    for (PointResDto.DebitPointResponse row : rows) {
      String key = String.valueOf(row.YM_CREATE)
        + '|' + String.valueOf(row.NM_TYPE_POINT)
        + '|' + String.valueOf(row.NM_PERSON)
        + '|' + String.valueOf(row.DT_USE)
        + '|' + String.valueOf(row.NO_SAL)
        + '|' + String.valueOf(row.DT_SAVE)
        + '|' + String.valueOf(row.NO_SAL_ORD)
        + '|' + String.valueOf(row.NO_SAL_SAVE)
        + '|' + String.valueOf(row.NO_SAL_RTN);
      if (grouped.containsKey(key)) {
        // 같은 그룹 — PT_USE 합산
        PointResDto.DebitPointResponse existing = grouped.get(key);
        Integer prevPt = existing.PT_USE != null ? existing.PT_USE : 0;
        Integer addPt = row.PT_USE != null ? row.PT_USE : 0;
        existing.PT_USE = prevPt + addPt;
      } else {
        grouped.put(key, row);
        orderedKeys.add(key);
      }
    }
    List<PointResDto.DebitPointResponse> result = new List<PointResDto.DebitPointResponse>();
    for (String k : orderedKeys) {
      result.add(grouped.get(k));
    }
    return result;
  }
}