public without sharing class LoyaltyPointInstantValidator {
  public class ValidationResult {
    public Id memberId;
    public String memberNo;
    public String memberName;
    public Decimal lmcBalance;
    public Decimal calculatedBalance;
    public Decimal difference;
    public Integer negativeAggrLedgerCount = 0;
    public Decimal negativeAggrAvailablePoints = 0;
    public List<Id> negativeAggrLedgerIds = new List<Id>();
    // [강화] LASEL 정밀 재계산 검증 (§12)
    //   GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger 와 동일 로직을 read-only 로 미러링.
    //   storage 3필드 (Accrued/Redeemed/Expired) 가 LL/LLT 재계산값과 일치하는지 lump 단위 비교.
    public Integer lumpMismatchCount = 0;
    public Integer missingLumpCount = 0;   // 재계산 결과 존재해야 하나 LASEL 미존재
    public Integer orphanLumpCount = 0;    // LASEL 존재하나 재계산 결과 없음 (또는 0 으로 stale)
    public List<String> lumpMismatchDetails = new List<String>();
    public Boolean isValid;
    public String summary;
  }

  public static ValidationResult validateByMemberNo(String memberNo) {
    if (String.isBlank(memberNo)) {
      throw new IllegalArgumentException('memberNo is required.');
    }

    List<LoyaltyProgramMember> members = [
      SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
      FROM LoyaltyProgramMember
      WHERE Contact.MemberNo__c = :memberNo AND MemberStatus = 'Active'
      LIMIT 1
    ];

    if (members.isEmpty()) {
      ValidationResult result = new ValidationResult();
      result.memberNo = memberNo;
      result.lmcBalance = 0;
      result.calculatedBalance = 0;
      result.difference = 0;
      result.isValid = false;
      result.summary = 'Active LoyaltyProgramMember not found.';
      return result;
    }

    return validateMember(members[0]);
  }

  public static List<ValidationResult> validateByContactIds(Set<Id> contactIds) {
    List<ValidationResult> results = new List<ValidationResult>();
    if (contactIds == null || contactIds.isEmpty()) {
      return results;
    }

    for (LoyaltyProgramMember member : [
      SELECT Id, MembershipNumber, Contact.MemberNo__c, Contact.Name, Account.Name
      FROM LoyaltyProgramMember
      WHERE ContactId IN :contactIds AND MemberStatus = 'Active'
    ]) {
      results.add(validateMember(member));
    }

    return results;
  }

  public static Boolean validateAndAlertByMemberNo(String memberNo) {
    ValidationResult result = validateByMemberNo(memberNo);
    if (result.isValid == true) {
      return true;
    }
    return sendValidationAlert(result);
  }

  public static ValidationResult validateNegativeAggrByMemberNo(String memberNo) {
    return validateByMemberNo(memberNo);
  }

  public static Boolean validateAndAlertNegativeAggrByMemberNo(String memberNo) {
    ValidationResult result = validateByMemberNo(memberNo);
    if (result.negativeAggrLedgerCount == null || result.negativeAggrLedgerCount == 0) {
      return true;
    }
    return sendValidationAlert(result);
  }

  @future(callout=true)
  public static void validateAndAlertByContactIdsAsync(String contactIdsJson) {
    if (String.isBlank(contactIdsJson)) {
      return;
    }

    List<Object> rawIds = (List<Object>) JSON.deserializeUntyped(contactIdsJson);
    Set<Id> contactIds = new Set<Id>();
    for (Object rawId : rawIds) {
      if (rawId != null) {
        contactIds.add((Id) String.valueOf(rawId));
      }
    }

    for (ValidationResult result : validateByContactIds(contactIds)) {
      if (result.isValid != true) {
        sendValidationAlert(result);
      }
    }
  }

  private static ValidationResult validateMember(LoyaltyProgramMember member) {
    ValidationResult result = new ValidationResult();
    result.memberId = member.Id;
    result.memberNo = member.Contact == null ? member.MembershipNumber : member.Contact.MemberNo__c;
    result.memberName = getMemberName(member);

    result.lmcBalance = queryLmcBalance(member.Id);
    result.calculatedBalance = queryAvailableLedgerBalance(member.Id);
    result.difference = result.calculatedBalance - result.lmcBalance;
    applyNegativeAggrValidation(result);
    applyLASELRebuildValidation(result);
    finalizeResult(result);
    return result;
  }

  private static Decimal queryLmcBalance(Id memberId) {
    List<LoyaltyMemberCurrency> rows = [
      SELECT PointsBalance
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :memberId
      LIMIT 1
    ];
    if (rows.isEmpty() || rows[0].PointsBalance == null) {
      return 0;
    }
    return rows[0].PointsBalance;
  }

  private static Decimal queryAvailableLedgerBalance(Id memberId) {
    Decimal balance = 0;
    for (AggregateResult row : [
      SELECT EventType eventType, SUM(Points) total
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
      GROUP BY EventType
    ]) {
      String eventType = (String) row.get('eventType');
      Decimal points = (Decimal) row.get('total');
      if (points == null) {
        continue;
      }

      Decimal amount = points.abs();
      if (eventType == 'Credit' || eventType == 'DebitCancellation') {
        balance += amount;
      } else if (eventType == 'Debit' || eventType == 'CreditCancellation' || eventType == 'Expiry') {
        balance -= amount;
      }
    }
    return balance;
  }

  private static void applyNegativeAggrValidation(ValidationResult result) {
    if (result == null || result.memberId == null) {
      return;
    }

    for (AggregateResult row : [
      SELECT COUNT(Id) cnt, SUM(AvailablePoints__c) total
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :result.memberId AND AvailablePoints__c < 0
    ]) {
      result.negativeAggrLedgerCount = (Integer) row.get('cnt');
      result.negativeAggrAvailablePoints = row.get('total') == null ? 0 : (Decimal) row.get('total');
    }

    if (result.negativeAggrLedgerCount == null || result.negativeAggrLedgerCount == 0) {
      return;
    }

    for (LoyaltyAggrSubPointExprLedger__c aggr : [
      SELECT Id
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :result.memberId AND AvailablePoints__c < 0
      ORDER BY AvailablePoints__c ASC
      LIMIT 20
    ]) {
      result.negativeAggrLedgerIds.add(aggr.Id);
    }
  }

  // ============================================================
  // [강화] LASEL 정밀 재계산 검증 (§12)
  //   GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger 의 계산 로직을
  //   read-only 로 미러링하여 storage 3필드 (Accrued/Redeemed/Expired) 의 정합 비교.
  //
  //   미러링 원본: GdPointAggregationUtil:14~222
  //   동기화 주의: 원본 로직이 변경되면 이 메서드도 함께 갱신 필요.
  // ============================================================
  private static final String JST_POINT_DEBIT = 'Point Debit';
  private static final String JST_POINT_REDEEM_CANCEL = 'Point Redeem Cancel';
  private static final String JST_PURCHASE_ACCRUAL = 'Purchase Accrual';
  private static final String JST_MANUAL_POINTS_CREDIT = 'Manual Points Credit';
  private static final String JST_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual';
  private static final String JST_AUTO_EXPIRE = 'Auto Expire';
  private static final String JST_API_FORCED_EXPIRE = 'Api Forced Expire';
  private static final String JST_API_FORCED_DEBIT = 'Api Forced Debit';
  private static final String JST_API_FORCED_CREDIT = 'Api Forced Credit';
  private static final String JST_PROMOTION_POINT_ACCRUAL = 'Promotion Point Accrual';
  private static final String JST_PROMOTION_POINT_ACCRUAL_REVERSAL = 'Promotion Point Accrual Reversal';
  private static final Integer MAX_LUMP_MISMATCH_DETAILS = 30;

  private static void applyLASELRebuildValidation(ValidationResult result) {
    if (result == null || result.memberId == null) {
      return;
    }
    Map<String, LumpExpected> expectedByKey;
    try {
      expectedByKey = computeExpectedLumps(result.memberId);
    } catch (Exception e) {
      result.lumpMismatchDetails.add('LASEL 재계산 실패: ' + e.getMessage());
      return;
    }

    Map<String, LoyaltyAggrSubPointExprLedger__c> actualByKey = new Map<String, LoyaltyAggrSubPointExprLedger__c>();
    for (LoyaltyAggrSubPointExprLedger__c lasel : [
      SELECT Id, CurrencySubTypeId__c, ExpiryDate__c, CurrencySubTypeName__c,
             AccruedPoints__c, RedeemedPoints__c, ExpiredPoints__c
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE LoyaltyProgramMemberId__c = :result.memberId
      LIMIT 50000
    ]) {
      actualByKey.put(buildLumpKey(lasel.CurrencySubTypeId__c, lasel.ExpiryDate__c), lasel);
    }

    // Phase A: expected 에 있는 lump 들을 actual 과 비교
    for (String key : expectedByKey.keySet()) {
      LumpExpected exp = expectedByKey.get(key);
      LoyaltyAggrSubPointExprLedger__c actual = actualByKey.get(key);
      if (actual == null) {
        // expected 가 0/0/0 이면 missing 으로 카운트하지 않음 (정합)
        if (exp.isNonZero()) {
          result.missingLumpCount++;
          addLumpDetail(result, 'MISSING_LASEL: ' + describeLump(exp) +
                                ' expected accrued=' + formatPoint(exp.accruedPoints) +
                                ' redeemed=' + formatPoint(exp.redeemedPoints) +
                                ' expired=' + formatPoint(exp.expiredPoints));
        }
        continue;
      }
      Decimal aAct = nz(actual.AccruedPoints__c);
      Decimal rAct = nz(actual.RedeemedPoints__c);
      Decimal eAct = nz(actual.ExpiredPoints__c);
      if (aAct != exp.accruedPoints || rAct != exp.redeemedPoints || eAct != exp.expiredPoints) {
        result.lumpMismatchCount++;
        addLumpDetail(result, 'MISMATCH: ' + describeLump(exp) +
                              ' actual(A/R/E)=' + formatPoint(aAct) + '/' + formatPoint(rAct) + '/' + formatPoint(eAct) +
                              ' expected(A/R/E)=' + formatPoint(exp.accruedPoints) + '/' + formatPoint(exp.redeemedPoints) + '/' + formatPoint(exp.expiredPoints));
      }
    }

    // Phase B: actual 에 있는데 expected 에 없는 orphan
    for (String key : actualByKey.keySet()) {
      if (expectedByKey.containsKey(key)) {
        continue;
      }
      LoyaltyAggrSubPointExprLedger__c actual = actualByKey.get(key);
      if (nz(actual.AccruedPoints__c) == 0 && nz(actual.RedeemedPoints__c) == 0 && nz(actual.ExpiredPoints__c) == 0) {
        // 모두 0 인 stale 레코드는 orphan 으로 보지 않음 (rebuild 가 0 으로 마킹한 정상 상태)
        continue;
      }
      result.orphanLumpCount++;
      addLumpDetail(result, 'ORPHAN_LASEL: subtype=' + actual.CurrencySubTypeName__c +
                            ' expiryDate=' + actual.ExpiryDate__c +
                            ' actual(A/R/E)=' + formatPoint(nz(actual.AccruedPoints__c)) +
                            '/' + formatPoint(nz(actual.RedeemedPoints__c)) +
                            '/' + formatPoint(nz(actual.ExpiredPoints__c)));
    }
  }

  // GdPointAggregationUtil 의 rebuild 계산 로직을 read-only 미러링
  private static Map<String, LumpExpected> computeExpectedLumps(Id memberId) {
    Map<String, LumpExpected> targetByKey = new Map<String, LumpExpected>();
    Set<Id> debitLedgerIds = new Set<Id>();
    Map<Id, LoyaltyLedger> debitLedgerById = new Map<Id, LoyaltyLedger>();
    Map<String, List<CreditBucket>> creditBucketsBySourceAndSubtype = new Map<String, List<CreditBucket>>();
    Set<Id> debitLedgerIdsWithTrace = new Set<Id>();

    Boolean preservePointCancelTrace = GdFeatureFlag.isEnabled('PointCancel_PreserveTrace');

    // Phase 1 — 활성 LL 순회
    for (LoyaltyLedger ledger : [
      SELECT Id, EventType, Points, ExpiryDate,
             LoyaltyPgmCrcySubtypeId, LoyaltyPgmCrcySubtype.Name,
             TransactionJournal.OrderId, TransactionJournal.SaleId__c, TransactionJournal.OrderId__c,
             TransactionJournal.JournalSubType.Name
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId AND IsDeleted = FALSE
      ORDER BY CreatedDate ASC
      LIMIT 50000
    ]) {
      if (ledger == null) continue;
      if ('Debit'.equals(ledger.EventType)) {
        debitLedgerIds.add(ledger.Id);
        debitLedgerById.put(ledger.Id, ledger);
        continue;
      }
      if (ledger.LoyaltyPgmCrcySubtypeId == null || ledger.ExpiryDate == null) continue;

      String subtypeName = ledger.LoyaltyPgmCrcySubtype == null ? null : ledger.LoyaltyPgmCrcySubtype.Name;
      String jstName = (ledger.TransactionJournal == null || ledger.TransactionJournal.JournalSubType == null)
        ? null
        : ledger.TransactionJournal.JournalSubType.Name;
      Decimal points = ledger.Points == null ? 0 : ledger.Points;

      LumpExpected exp = getOrCreateExpected(targetByKey, ledger.LoyaltyPgmCrcySubtypeId, ledger.ExpiryDate, subtypeName);

      if ('Credit'.equals(ledger.EventType)) {
        if (JST_POINT_REDEEM_CANCEL.equals(jstName)) {
          if (preservePointCancelTrace) {
            exp.accruedPoints += points;
          } else {
            exp.redeemedPoints -= points;
          }
        } else if (
          JST_PURCHASE_ACCRUAL.equals(jstName) ||
          JST_MANUAL_POINTS_CREDIT.equals(jstName) ||
          JST_API_FORCED_CREDIT.equals(jstName) ||
          JST_PROMOTION_POINT_ACCRUAL.equals(jstName)
        ) {
          exp.accruedPoints += points;
          addCreditBucket(creditBucketsBySourceAndSubtype, ledger, points, subtypeName);
        }
      } else if ('Expiry'.equals(ledger.EventType)) {
        if (
          JST_AUTO_EXPIRE.equals(jstName) ||
          JST_API_FORCED_EXPIRE.equals(jstName) ||
          JST_POINT_REDEEM_CANCEL.equals(jstName)
        ) {
          exp.expiredPoints += points;
        }
      }
    }

    // Phase 2 — Debit LL 의 LLT trace
    if (!debitLedgerIds.isEmpty()) {
      for (LoyaltyLedgerTraceability trace : [
        SELECT CreditLoyaltyLedger.ExpiryDate,
               DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name,
               LoyaltyPgmCurrencySubtypeId, LoyaltyPgmCurrencySubtype.Name,
               DebitLoyaltyLedgerId, Points, ActionType
        FROM LoyaltyLedgerTraceability
        WHERE DebitLoyaltyLedgerId IN :debitLedgerIds
          AND ActionType IN ('Debit', 'CreditCancellation')
          AND IsDeleted = FALSE
        LIMIT 50000
      ]) {
        if (trace == null || trace.LoyaltyPgmCurrencySubtypeId == null) continue;
        debitLedgerIdsWithTrace.add(trace.DebitLoyaltyLedgerId);
        if (trace.CreditLoyaltyLedger == null || trace.CreditLoyaltyLedger.ExpiryDate == null) continue;

        String jstName = (trace.DebitLoyaltyLedger == null
          || trace.DebitLoyaltyLedger.TransactionJournal == null
          || trace.DebitLoyaltyLedger.TransactionJournal.JournalSubType == null)
          ? null
          : trace.DebitLoyaltyLedger.TransactionJournal.JournalSubType.Name;
        String subtypeName = trace.LoyaltyPgmCurrencySubtype == null ? null : trace.LoyaltyPgmCurrencySubtype.Name;
        Decimal points = trace.Points == null ? 0 : trace.Points;

        LumpExpected exp = getOrCreateExpected(targetByKey, trace.LoyaltyPgmCurrencySubtypeId, trace.CreditLoyaltyLedger.ExpiryDate, subtypeName);

        if (JST_POINT_DEBIT.equals(jstName)) {
          exp.redeemedPoints += points;
        } else if (
          JST_CANCEL_PURCHASE_ACCRUAL.equals(jstName) ||
          JST_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(jstName) ||
          JST_API_FORCED_DEBIT.equals(jstName)
        ) {
          exp.accruedPoints -= points;
        } else if (JST_API_FORCED_EXPIRE.equals(jstName)) {
          exp.expiredPoints += points;
        }
      }

      // Phase 3 — trace 없는 Debit 에 대한 fallback (적립 reversal 케이스)
      applyMissingCreditCancellationFallback(targetByKey, debitLedgerById, debitLedgerIdsWithTrace, creditBucketsBySourceAndSubtype);
    }

    return targetByKey;
  }

  private static LumpExpected getOrCreateExpected(Map<String, LumpExpected> targetByKey, Id subtypeId, Date expiryDate, String subtypeName) {
    String key = buildLumpKey(subtypeId, expiryDate);
    if (!targetByKey.containsKey(key)) {
      targetByKey.put(key, new LumpExpected(subtypeId, expiryDate, subtypeName));
    }
    LumpExpected exp = targetByKey.get(key);
    if (String.isNotBlank(subtypeName)) {
      exp.subtypeName = subtypeName;
    }
    return exp;
  }

  private static String buildLumpKey(Id subtypeId, Date expiryDate) {
    return String.valueOf(subtypeId) + '|' + String.valueOf(expiryDate);
  }

  private static void addCreditBucket(Map<String, List<CreditBucket>> creditBucketsBySourceAndSubtype, LoyaltyLedger ledger, Decimal points, String subtypeName) {
    String sourceKey = buildSourceSubtypeKey(ledger);
    if (String.isBlank(sourceKey) || ledger.ExpiryDate == null || ledger.LoyaltyPgmCrcySubtypeId == null) {
      return;
    }
    if (!creditBucketsBySourceAndSubtype.containsKey(sourceKey)) {
      creditBucketsBySourceAndSubtype.put(sourceKey, new List<CreditBucket>());
    }
    creditBucketsBySourceAndSubtype.get(sourceKey).add(
      new CreditBucket(ledger.LoyaltyPgmCrcySubtypeId, ledger.ExpiryDate, subtypeName, points == null ? 0 : points)
    );
  }

  private static void applyMissingCreditCancellationFallback(
    Map<String, LumpExpected> targetByKey,
    Map<Id, LoyaltyLedger> debitLedgerById,
    Set<Id> debitLedgerIdsWithTrace,
    Map<String, List<CreditBucket>> creditBucketsBySourceAndSubtype
  ) {
    for (Id debitLedgerId : debitLedgerById.keySet()) {
      if (debitLedgerIdsWithTrace.contains(debitLedgerId)) continue;
      LoyaltyLedger debit = debitLedgerById.get(debitLedgerId);
      if (debit == null || debit.LoyaltyPgmCrcySubtypeId == null) continue;
      String jstName = (debit.TransactionJournal == null || debit.TransactionJournal.JournalSubType == null)
        ? null
        : debit.TransactionJournal.JournalSubType.Name;
      if (!isAccrualReversalSubType(jstName)) continue;
      String sourceKey = buildSourceSubtypeKey(debit);
      if (String.isBlank(sourceKey) || !creditBucketsBySourceAndSubtype.containsKey(sourceKey)) continue;

      Decimal remaining = debit.Points == null ? 0 : debit.Points;
      for (CreditBucket bucket : creditBucketsBySourceAndSubtype.get(sourceKey)) {
        if (remaining <= 0) break;
        if (bucket.remainingPoints <= 0) continue;
        Decimal allocated = remaining > bucket.remainingPoints ? bucket.remainingPoints : remaining;
        if (allocated <= 0) continue;
        LumpExpected exp = getOrCreateExpected(targetByKey, bucket.subtypeId, bucket.expiryDate, bucket.subtypeName);
        exp.accruedPoints -= allocated;
        bucket.remainingPoints -= allocated;
        remaining -= allocated;
      }
    }
  }

  private static Boolean isAccrualReversalSubType(String jstName) {
    return JST_CANCEL_PURCHASE_ACCRUAL.equals(jstName)
      || JST_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(jstName)
      || JST_API_FORCED_DEBIT.equals(jstName);
  }

  private static String buildSourceSubtypeKey(LoyaltyLedger ledger) {
    if (ledger == null || ledger.TransactionJournal == null || ledger.LoyaltyPgmCrcySubtypeId == null) return null;
    String sourceId = ledger.TransactionJournal.OrderId == null ? null : String.valueOf(ledger.TransactionJournal.OrderId);
    if (String.isBlank(sourceId) && String.isNotBlank(ledger.TransactionJournal.SaleId__c)) {
      sourceId = String.valueOf(ledger.TransactionJournal.SaleId__c);
    }
    if (String.isBlank(sourceId) && String.isNotBlank(ledger.TransactionJournal.OrderId__c)) {
      sourceId = String.valueOf(ledger.TransactionJournal.OrderId__c);
    }
    if (String.isBlank(sourceId)) return null;
    return sourceId + '|' + String.valueOf(ledger.LoyaltyPgmCrcySubtypeId);
  }

  private static void addLumpDetail(ValidationResult result, String detail) {
    if (result.lumpMismatchDetails.size() < MAX_LUMP_MISMATCH_DETAILS) {
      result.lumpMismatchDetails.add(detail);
    }
  }

  private static String describeLump(LumpExpected exp) {
    return 'subtype=' + (String.isBlank(exp.subtypeName) ? String.valueOf(exp.subtypeId) : exp.subtypeName) +
           ' expiryDate=' + exp.expiryDate;
  }

  private static Decimal nz(Decimal v) {
    return v == null ? 0 : v;
  }

  // === inner classes (GdPointAggregationUtil 미러링) ===
  private class LumpExpected {
    Id subtypeId;
    Date expiryDate;
    String subtypeName;
    Decimal accruedPoints = 0;
    Decimal redeemedPoints = 0;
    Decimal expiredPoints = 0;
    LumpExpected(Id subtypeId, Date expiryDate, String subtypeName) {
      this.subtypeId = subtypeId;
      this.expiryDate = expiryDate;
      this.subtypeName = subtypeName;
    }
    Boolean isNonZero() {
      return accruedPoints != 0 || redeemedPoints != 0 || expiredPoints != 0;
    }
  }

  private class CreditBucket {
    Id subtypeId;
    Date expiryDate;
    String subtypeName;
    Decimal remainingPoints;
    CreditBucket(Id subtypeId, Date expiryDate, String subtypeName, Decimal points) {
      this.subtypeId = subtypeId;
      this.expiryDate = expiryDate;
      this.subtypeName = subtypeName;
      this.remainingPoints = points == null ? 0 : points;
    }
  }

  private static void finalizeResult(ValidationResult result) {
    Boolean balanceValid = result.difference == 0;
    Boolean aggrValid = result.negativeAggrLedgerCount == null || result.negativeAggrLedgerCount == 0;
    Boolean lumpValid = (result.lumpMismatchCount == 0)
                        && (result.missingLumpCount == 0)
                        && (result.orphanLumpCount == 0);
    result.isValid = balanceValid && aggrValid && lumpValid;

    if (result.isValid) {
      result.summary = '포인트 즉시 검증 정상 (LMC/LL/LASEL 정합)';
      return;
    }

    List<String> messages = new List<String>();
    if (!balanceValid) {
      messages.add(
        'LMC/LL 불일치: LMC=' +
          formatPoint(result.lmcBalance) +
          'P, 계산=' +
          formatPoint(result.calculatedBalance) +
          'P, 차이=' +
          formatPoint(result.difference) +
          'P'
      );
    }
    if (!aggrValid) {
      messages.add(
        '집계 음수 원장 발견: 건수=' +
          String.valueOf(result.negativeAggrLedgerCount) +
          ', 음수 합계=' +
          formatPoint(result.negativeAggrAvailablePoints) +
          'P, 샘플=' +
          JSON.serialize(result.negativeAggrLedgerIds)
      );
    }
    if (!lumpValid) {
      messages.add(
        'LASEL 정밀 불일치: mismatch=' +
          String.valueOf(result.lumpMismatchCount) +
          ', missing=' +
          String.valueOf(result.missingLumpCount) +
          ', orphan=' +
          String.valueOf(result.orphanLumpCount) +
          (result.lumpMismatchDetails.isEmpty() ? '' : ' / 샘플=' + JSON.serialize(result.lumpMismatchDetails))
      );
    }
    result.summary = String.join(messages, ' / ');
  }

  private static Boolean sendValidationAlert(ValidationResult result) {
    Slack_Config__mdt config = Slack_Config__mdt.getInstance('Member_Activity_Alert');
    if (config == null || !config.Is_Active__c || String.isBlank(config.Webhook_URL__c)) {
      System.debug(LoggingLevel.WARN, '[포인트 즉시 검증] Slack 설정이 비활성화되어 알림을 보내지 않습니다. ' + result.summary);
      return false;
    }

    HttpRequest req = new HttpRequest();
    req.setEndpoint(config.Webhook_URL__c);
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody(buildSlackBody(result));
    req.setTimeout(10000);

    HttpResponse res = new Http().send(req);
    Boolean success = res.getStatusCode() >= 200 && res.getStatusCode() < 300;
    if (!success) {
      System.debug(LoggingLevel.ERROR, '[포인트 즉시 검증] Slack 발송 실패: ' + res.getStatusCode() + ' / ' + res.getBody());
    }
    return success;
  }

  private static String buildSlackBody(ValidationResult result) {
    String orgUrl = URL.getOrgDomainUrl().toExternalForm();
    String memberLink = result.memberId == null ? '' : orgUrl + '/' + result.memberId;
    String memberTitle = String.isBlank(memberLink)
      ? String.valueOf(result.memberName)
      : '<' + memberLink + '|' + result.memberName + '>';

    Map<String, Object> msg = new Map<String, Object>{
      'text' => '[골든듀 모니터링] 포인트 즉시 검증 불일치',
      'blocks' => new List<Object>{
        new Map<String, Object>{
          'type' => 'header',
          'text' => new Map<String, Object>{ 'type' => 'plain_text', 'text' => '포인트 즉시 검증 불일치' }
        },
        new Map<String, Object>{
          'type' => 'section',
          'fields' => new List<Object>{
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원:*\n' + memberTitle },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*회원번호:*\n' + String.valueOf(result.memberNo) },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*LMC 잔액:*\n' + formatPoint(result.lmcBalance) + 'P' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*LL 계산 잔액:*\n' + formatPoint(result.calculatedBalance) + 'P' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*차이:*\n' + formatPoint(result.difference) + 'P' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*음수 집계 건수:*\n' + String.valueOf(result.negativeAggrLedgerCount) },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*음수 집계 합계:*\n' + formatPoint(result.negativeAggrAvailablePoints) + 'P' },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*LASEL 정밀(불일치/누락/잉여):*\n' +
              String.valueOf(result.lumpMismatchCount) + '/' +
              String.valueOf(result.missingLumpCount) + '/' +
              String.valueOf(result.orphanLumpCount) },
            new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*검증 시각:*\n' + Datetime.now().format('yyyy-MM-dd HH:mm') }
          }
        },
        new Map<String, Object>{
          'type' => 'section',
          'text' => new Map<String, Object>{ 'type' => 'mrkdwn', 'text' => '*요약:*\n' + result.summary }
        }
      }
    };

    return JSON.serialize(msg);
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
}