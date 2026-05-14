public without sharing class GdPointRefreshApplyService {
  private static final Integer MAX_DML_ROWS_PER_SYNC_REFRESH = 9000;
  private static Map<String, Id> journalTypeIdByName = new Map<String, Id>();
  private static Map<String, Id> journalSubTypeIdByKey = new Map<String, Id>();
  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';

  public class Request {
    public String memberNo;
    public Date openDate;
    public Map<String, Decimal> openingPointByType;
    public Boolean dryRun = true;
    public Boolean useCreatedDateCutoff = true;
    public Datetime migrationCutoffDateTime;
  }

  public class ApplyResult {
    public Boolean dryRun;
    public String memberNo;
    public Id memberId;
    public Integer deleteTraceCount = 0;
    public Integer deleteLedgerCount = 0;
    public Integer deleteJournalCount = 0;
    public Integer insertJournalCount = 0;
    public Integer insertLedgerCount = 0;
    public Integer insertTraceCount = 0;
    public Decimal finalBalance = 0;
    public Map<String, Decimal> remainingByPointType = new Map<String, Decimal>();
    public GdPointRefreshPreviewService.PreviewResult preview;
  }

  public ApplyResult refreshMember(Request request) {
    validateRequest(request);

    Savepoint sp = Database.setSavepoint();
    try {
      GdPointRefreshPreviewService.PreviewResult preview = new GdPointRefreshPreviewService()
        .simulateMember(
          request.memberNo,
          request.openDate,
          request.openingPointByType,
          request.useCreatedDateCutoff,
          request.migrationCutoffDateTime
        );

      ApplyResult result = new ApplyResult();
      result.dryRun = request.dryRun != false;
      result.memberNo = preview.memberNo;
      result.memberId = preview.memberId;
      result.preview = preview;
      result.finalBalance = preview.totalRemaining;
      result.remainingByPointType = preview.remainingByPointType;

      Set<Id> preservedManualCreditLedgerIds = collectPreservedManualCreditLedgerIds(preview);
      List<LoyaltyLedger> targetLedgers = loadTargetLedgers(preview.memberId, preservedManualCreditLedgerIds);
      Set<Id> targetLedgerIds = new Map<Id, LoyaltyLedger>(targetLedgers).keySet();
      Set<Id> targetJournalIds = collectJournalIds(targetLedgers);

      result.deleteLedgerCount = targetLedgerIds.size();
      result.deleteJournalCount = targetJournalIds.size();
      result.deleteTraceCount = countTargetTraceRows(preview.memberId, targetLedgerIds);

      if (result.dryRun) {
        return result;
      }

      guardSynchronousDmlSize(result, preview, preservedManualCreditLedgerIds);

      deleteTargetTraceRows(preview.memberId, targetLedgerIds);
      if (!targetLedgers.isEmpty()) {
        delete targetLedgers;
      }
      deleteTargetJournals(targetJournalIds);

      InsertContext context = insertRefreshedLedgers(preview, preservedManualCreditLedgerIds);
      result.insertJournalCount = context.insertJournalCount;
      result.insertLedgerCount = context.insertLedgerCount;
      result.insertTraceCount = context.insertTraceCount;

      updateMemberCurrency(preview.memberId, preview.totalRemaining, context.totalAccrued, context.totalRedeemed);
      GdPointAggregationUtil.rebuildLoyaltyAggrSubPointExprLedger(preview.memberId);

      return result;
    } catch (Exception e) {
      Database.rollback(sp);
      throw e;
    }
  }

  private static void validateRequest(Request request) {
    if (request == null) {
      throw new CustomException(400, 'request is required.');
    }
    if (String.isBlank(request.memberNo)) {
      throw new CustomException(400, 'memberNo is required.');
    }
    if (request.openDate == null) {
      throw new CustomException(400, 'openDate is required.');
    }
    if (request.openingPointByType == null) {
      request.openingPointByType = new Map<String, Decimal>();
    }
    if (request.useCreatedDateCutoff == null) {
      request.useCreatedDateCutoff = true;
    }
    if (request.migrationCutoffDateTime == null) {
      request.migrationCutoffDateTime = TimeUtil.dateToUtcStartOfDay(request.openDate);
    }
  }

  private static void guardSynchronousDmlSize(
    ApplyResult result,
    GdPointRefreshPreviewService.PreviewResult preview,
    Set<Id> preservedManualCreditLedgerIds
  ) {
    Integer estimatedRows =
      result.deleteTraceCount +
      result.deleteLedgerCount +
      result.deleteJournalCount +
      estimateInsertRows(preview, preservedManualCreditLedgerIds);
    if (estimatedRows > MAX_DML_ROWS_PER_SYNC_REFRESH) {
      throw new CustomException(
        400,
        '포인트 새로고침 대상 데이터가 너무 많아 동기 실행이 불가합니다. 예상 DML Rows: ' +
          estimatedRows +
          ' / 제한 기준: ' +
          MAX_DML_ROWS_PER_SYNC_REFRESH +
          '. Batch 실행으로 분리해야 합니다.'
      );
    }
  }

  private static Integer estimateInsertRows(GdPointRefreshPreviewService.PreviewResult preview, Set<Id> preservedManualCreditLedgerIds) {
    if (preview == null) {
      return 0;
    }
    Integer newCreditBucketCount = 0;
    if (preview.buckets != null) {
      for (GdPointRefreshPreviewService.BucketRow bucket : preview.buckets) {
        if (bucket == null || bucket.originalPoints == null || bucket.originalPoints <= 0) {
          continue;
        }
        Id preservedId = bucket.manualCredit == true && bucket.bucketKey != null && bucket.bucketKey.startsWith('CREDIT:')
          ? toIdOrNull(bucket.bucketKey.substring('CREDIT:'.length()))
          : null;
        if (preservedId != null && preservedManualCreditLedgerIds != null && preservedManualCreditLedgerIds.contains(preservedId)) {
          continue;
        }
        newCreditBucketCount++;
      }
    }

    Set<String> debitEventKeys = new Set<String>();
    Integer debitTraceCount = 0;
    if (preview.allocations != null) {
      for (GdPointRefreshPreviewService.AllocationRow allocation : preview.allocations) {
        if (allocation == null || allocation.points == null || allocation.points <= 0) {
          continue;
        }
        debitEventKeys.add(allocation.debitEventKey);
        debitTraceCount++;
      }
    }

    Integer debitCancelTraceCount = 0;
    if (preview.debitCancellations != null) {
      for (GdPointRefreshPreviewService.DebitCancellationRow cancellation : preview.debitCancellations) {
        if (cancellation != null && cancellation.points != null && cancellation.points > 0) {
          debitCancelTraceCount++;
        }
      }
    }

    Integer creditCancelCount = 0;
    if (preview.creditCancellations != null) {
      for (GdPointRefreshPreviewService.CreditCancellationRow cancellation : preview.creditCancellations) {
        if (cancellation != null && cancellation.points != null && cancellation.points > 0) {
          creditCancelCount++;
        }
      }
    }

    return (newCreditBucketCount * 2) + (debitEventKeys.size() * 2) + debitTraceCount + debitCancelTraceCount + (creditCancelCount * 3);
  }

  private static Set<Id> collectPreservedManualCreditLedgerIds(GdPointRefreshPreviewService.PreviewResult preview) {
    Set<Id> ids = new Set<Id>();
    if (preview == null || preview.buckets == null) {
      return ids;
    }
    for (GdPointRefreshPreviewService.BucketRow bucket : preview.buckets) {
      if (bucket == null || bucket.manualCredit != true || String.isBlank(bucket.bucketKey) || !bucket.bucketKey.startsWith('CREDIT:')) {
        continue;
      }
      Id ledgerId = toIdOrNull(bucket.bucketKey.substring('CREDIT:'.length()));
      if (ledgerId != null) {
        ids.add(ledgerId);
      }
    }
    return ids;
  }

  private static List<LoyaltyLedger> loadTargetLedgers(Id memberId, Set<Id> preservedManualCreditLedgerIds) {
    List<LoyaltyLedger> result = new List<LoyaltyLedger>();
    for (LoyaltyLedger ll : [
      SELECT Id, TransactionJournalId
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :memberId
      LIMIT 50000
    ]) {
      if (preservedManualCreditLedgerIds != null && preservedManualCreditLedgerIds.contains(ll.Id)) {
        continue;
      }
      result.add(ll);
    }
    return result;
  }

  private static Set<Id> collectJournalIds(List<LoyaltyLedger> ledgers) {
    Set<Id> ids = new Set<Id>();
    if (ledgers == null) {
      return ids;
    }
    for (LoyaltyLedger ll : ledgers) {
      if (ll.TransactionJournalId != null) {
        ids.add(ll.TransactionJournalId);
      }
    }
    return ids;
  }

  private static Integer countTargetTraceRows(Id memberId, Set<Id> targetLedgerIds) {
    if (targetLedgerIds == null || targetLedgerIds.isEmpty()) {
      return 0;
    }
    return [
      SELECT COUNT()
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
      AND (CreditLoyaltyLedgerId IN :targetLedgerIds OR DebitLoyaltyLedgerId IN :targetLedgerIds)
    ];
  }

  private static void deleteTargetTraceRows(Id memberId, Set<Id> targetLedgerIds) {
    if (targetLedgerIds == null || targetLedgerIds.isEmpty()) {
      return;
    }
    List<LoyaltyLedgerTraceability> traces = [
      SELECT Id
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :memberId
      AND (CreditLoyaltyLedgerId IN :targetLedgerIds OR DebitLoyaltyLedgerId IN :targetLedgerIds)
      LIMIT 50000
    ];
    if (!traces.isEmpty()) {
      delete traces;
    }
  }

  private static void deleteTargetJournals(Set<Id> targetJournalIds) {
    if (targetJournalIds == null || targetJournalIds.isEmpty()) {
      return;
    }
    List<TransactionJournal> journals = [
      SELECT Id
      FROM TransactionJournal
      WHERE Id IN :targetJournalIds
    ];
    if (!journals.isEmpty()) {
      delete journals;
    }
  }

  private class InsertContext {
    Integer insertJournalCount = 0;
    Integer insertLedgerCount = 0;
    Integer insertTraceCount = 0;
    Decimal totalAccrued = 0;
    Decimal totalRedeemed = 0;
    Map<String, Id> bucketKeyToLedgerId = new Map<String, Id>();
    Map<String, Id> bucketKeyToSubtypeId = new Map<String, Id>();
  }

  private static InsertContext insertRefreshedLedgers(GdPointRefreshPreviewService.PreviewResult preview, Set<Id> preservedManualCreditLedgerIds) {
    InsertContext context = new InsertContext();
    Id loyaltyProgramCurrencyId = getLoyaltyProgramCurrencyId();
    Id loyaltyProgramId = getLoyaltyProgramId(preview.memberId);
    Map<String, Id> subtypeIdByPointType = loadSubtypeIdByPointType(preview);
    Map<String, Order> orderBySaleNo = loadOrderBySaleNo(preview);

    insertCreditBuckets(preview, context, loyaltyProgramId, loyaltyProgramCurrencyId, subtypeIdByPointType, orderBySaleNo, preservedManualCreditLedgerIds);
    insertDebitAllocations(preview, context, loyaltyProgramId, loyaltyProgramCurrencyId, orderBySaleNo);
    insertDebitCancellationAllocations(preview, context, loyaltyProgramCurrencyId);
    insertCreditCancellationAllocations(preview, context, loyaltyProgramId, loyaltyProgramCurrencyId, orderBySaleNo);
    return context;
  }

  private static void insertCreditBuckets(
    GdPointRefreshPreviewService.PreviewResult preview,
    InsertContext context,
    Id loyaltyProgramId,
    Id loyaltyProgramCurrencyId,
    Map<String, Id> subtypeIdByPointType,
    Map<String, Order> orderBySaleNo,
    Set<Id> preservedManualCreditLedgerIds
  ) {
    List<TransactionJournal> journals = new List<TransactionJournal>();
    List<GdPointRefreshPreviewService.BucketRow> newBuckets = new List<GdPointRefreshPreviewService.BucketRow>();

    for (GdPointRefreshPreviewService.BucketRow bucket : preview.buckets) {
      if (bucket == null || bucket.originalPoints == null || bucket.originalPoints <= 0) {
        continue;
      }
      Id preservedId = bucket.manualCredit == true && bucket.bucketKey != null && bucket.bucketKey.startsWith('CREDIT:')
        ? toIdOrNull(bucket.bucketKey.substring('CREDIT:'.length()))
        : null;
      if (preservedId != null && preservedManualCreditLedgerIds.contains(preservedId)) {
        context.bucketKeyToLedgerId.put(bucket.bucketKey, preservedId);
        context.bucketKeyToSubtypeId.put(bucket.bucketKey, subtypeIdByPointType.get(bucket.pointTypeCode));
        context.totalAccrued += bucket.originalPoints;
        continue;
      }

      TransactionJournal tj = buildJournal(
        preview.memberId,
        loyaltyProgramId,
        bucket.originSaleNo,
        bucket.accrualDate,
        bucket.originalPoints,
        'Accrual',
        resolveCreditJournalSubTypeName(bucket),
        'POINT_REFRESH_REBUILD:CREDIT:' + bucket.bucketKey,
        orderBySaleNo
      );
      journals.add(tj);
      newBuckets.add(bucket);
    }

    if (!journals.isEmpty()) {
      insert journals;
      context.insertJournalCount += journals.size();
    }

    List<LoyaltyLedger> ledgers = new List<LoyaltyLedger>();
    for (Integer i = 0; i < newBuckets.size(); i++) {
      GdPointRefreshPreviewService.BucketRow bucket = newBuckets[i];
      LoyaltyLedger ll = new LoyaltyLedger();
      ll.EventType = 'Credit';
      ll.LoyaltyProgramMemberId = preview.memberId;
      ll.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
      ll.LoyaltyPgmCrcySubtypeId = subtypeIdByPointType.get(bucket.pointTypeCode);
      ll.Points = bucket.originalPoints;
      ll.ExpiryDate = bucket.expiryDate;
      ll.ActivityDate = toStartOfDay(bucket.accrualDate);
      ll.TransactionJournalId = journals[i].Id;
      ll.AdditionalNotes = buildCreditLedgerNotes(bucket);
      ledgers.add(ll);
      context.totalAccrued += bucket.originalPoints;
    }

    if (!ledgers.isEmpty()) {
      insert ledgers;
      context.insertLedgerCount += ledgers.size();
      for (Integer i = 0; i < newBuckets.size(); i++) {
        context.bucketKeyToLedgerId.put(newBuckets[i].bucketKey, ledgers[i].Id);
        context.bucketKeyToSubtypeId.put(newBuckets[i].bucketKey, ledgers[i].LoyaltyPgmCrcySubtypeId);
      }
    }
  }

  private static void insertDebitCancellationAllocations(
    GdPointRefreshPreviewService.PreviewResult preview,
    InsertContext context,
    Id loyaltyProgramCurrencyId
  ) {
    if (preview.debitCancellations == null || preview.debitCancellations.isEmpty()) {
      return;
    }

    List<LoyaltyLedgerTraceability> traces = new List<LoyaltyLedgerTraceability>();
    for (GdPointRefreshPreviewService.DebitCancellationRow cancellation : preview.debitCancellations) {
      Id sourceCreditLedgerId = context.bucketKeyToLedgerId.get(cancellation.sourceCreditBucketKey);
      Id restoredCreditLedgerId = context.bucketKeyToLedgerId.get(cancellation.restoredCreditBucketKey);
      if (sourceCreditLedgerId == null || restoredCreditLedgerId == null || cancellation.points == null || cancellation.points <= 0) {
        continue;
      }
      traces.add(
        buildTrace(
          preview.memberId,
          loyaltyProgramCurrencyId,
          context.bucketKeyToSubtypeId.get(cancellation.sourceCreditBucketKey),
          sourceCreditLedgerId,
          restoredCreditLedgerId,
          cancellation.points,
          'DebitCancellation'
        )
      );
    }
    if (!traces.isEmpty()) {
      insert traces;
      context.insertTraceCount += traces.size();
    }
  }

  private static void insertDebitAllocations(
    GdPointRefreshPreviewService.PreviewResult preview,
    InsertContext context,
    Id loyaltyProgramId,
    Id loyaltyProgramCurrencyId,
    Map<String, Order> orderBySaleNo
  ) {
    Map<String, List<GdPointRefreshPreviewService.AllocationRow>> allocationsByDebitKey = new Map<String, List<GdPointRefreshPreviewService.AllocationRow>>();
    for (GdPointRefreshPreviewService.AllocationRow allocation : preview.allocations) {
      if (!allocationsByDebitKey.containsKey(allocation.debitEventKey)) {
        allocationsByDebitKey.put(allocation.debitEventKey, new List<GdPointRefreshPreviewService.AllocationRow>());
      }
      allocationsByDebitKey.get(allocation.debitEventKey).add(allocation);
    }

    Map<String, GdPointRefreshPreviewService.EventRow> eventByKey = buildEventByKey(preview);
    List<String> debitKeys = new List<String>();
    List<TransactionJournal> journals = new List<TransactionJournal>();
    List<Decimal> debitTotals = new List<Decimal>();
    List<GdPointRefreshPreviewService.EventRow> debitEvents = new List<GdPointRefreshPreviewService.EventRow>();
    for (String debitKey : allocationsByDebitKey.keySet()) {
      List<GdPointRefreshPreviewService.AllocationRow> allocations = allocationsByDebitKey.get(debitKey);
      Decimal total = sumAllocationPoints(allocations);
      GdPointRefreshPreviewService.EventRow sourceEvent = eventByKey.get(debitKey);
      debitKeys.add(debitKey);
      debitTotals.add(total);
      debitEvents.add(sourceEvent);
      journals.add(
        buildJournal(
          preview.memberId,
          loyaltyProgramId,
          sourceEvent == null ? null : sourceEvent.saleNo,
          sourceEvent == null ? preview.openDate : sourceEvent.eventDate,
          total,
          'Redemption',
          'Point Debit',
          'POINT_REFRESH_REBUILD:DEBIT:' + debitKey,
          orderBySaleNo
        )
      );
    }

    if (journals.isEmpty()) {
      return;
    }
    insert journals;
    context.insertJournalCount += journals.size();

    List<LoyaltyLedger> debitLedgers = new List<LoyaltyLedger>();
    for (Integer i = 0; i < debitKeys.size(); i++) {
      GdPointRefreshPreviewService.EventRow sourceEvent = debitEvents[i];
      LoyaltyLedger debitLedger = new LoyaltyLedger();
      debitLedger.EventType = 'Debit';
      debitLedger.LoyaltyProgramMemberId = preview.memberId;
      debitLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
      debitLedger.Points = debitTotals[i];
      debitLedger.ActivityDate = toStartOfDay(sourceEvent == null ? preview.openDate : sourceEvent.eventDate);
      debitLedger.TransactionJournalId = journals[i].Id;
      debitLedgers.add(debitLedger);
      context.totalRedeemed += debitTotals[i];
    }
    insert debitLedgers;
    context.insertLedgerCount += debitLedgers.size();

    List<LoyaltyLedgerTraceability> traces = new List<LoyaltyLedgerTraceability>();
    for (Integer i = 0; i < debitKeys.size(); i++) {
      String debitKey = debitKeys[i];
      LoyaltyLedger debitLedger = debitLedgers[i];
      for (GdPointRefreshPreviewService.AllocationRow allocation : allocationsByDebitKey.get(debitKey)) {
        Id creditLedgerId = context.bucketKeyToLedgerId.get(allocation.creditBucketKey);
        if (creditLedgerId == null) {
          continue;
        }
        traces.add(buildTrace(preview.memberId, loyaltyProgramCurrencyId, context.bucketKeyToSubtypeId.get(allocation.creditBucketKey), creditLedgerId, debitLedger.Id, allocation.points, 'Debit'));
      }
    }
    if (!traces.isEmpty()) {
      insert traces;
      context.insertTraceCount += traces.size();
    }
  }

  private static void insertCreditCancellationAllocations(
    GdPointRefreshPreviewService.PreviewResult preview,
    InsertContext context,
    Id loyaltyProgramId,
    Id loyaltyProgramCurrencyId,
    Map<String, Order> orderBySaleNo
  ) {
    if (preview.creditCancellations == null || preview.creditCancellations.isEmpty()) {
      return;
    }
    Map<String, GdPointRefreshPreviewService.EventRow> eventByKey = buildEventByKey(preview);
    List<GdPointRefreshPreviewService.CreditCancellationRow> validCancellations = new List<GdPointRefreshPreviewService.CreditCancellationRow>();
    List<TransactionJournal> journals = new List<TransactionJournal>();
    List<Date> eventDates = new List<Date>();
    for (GdPointRefreshPreviewService.CreditCancellationRow cancellation : preview.creditCancellations) {
      Id creditLedgerId = context.bucketKeyToLedgerId.get(cancellation.creditBucketKey);
      if (creditLedgerId == null || cancellation.points == null || cancellation.points <= 0) {
        continue;
      }
      GdPointRefreshPreviewService.EventRow sourceEvent = eventByKey.get(cancellation.cancelEventKey);
      Date eventDate = sourceEvent == null ? preview.openDate : sourceEvent.eventDate;
      validCancellations.add(cancellation);
      eventDates.add(eventDate);
      journals.add(
        buildJournal(
          preview.memberId,
          loyaltyProgramId,
          sourceEvent == null ? null : sourceEvent.saleNo,
          eventDate,
          cancellation.points,
          'Accrual Reversal',
          resolveCreditCancellationJournalSubTypeName(cancellation, sourceEvent),
          'POINT_REFRESH_REBUILD:CREDIT_CANCEL:' + cancellation.cancelEventKey,
          orderBySaleNo
        )
      );
    }

    if (journals.isEmpty()) {
      return;
    }
    insert journals;
    context.insertJournalCount += journals.size();

    List<LoyaltyLedger> debitLedgers = new List<LoyaltyLedger>();
    for (Integer i = 0; i < validCancellations.size(); i++) {
      GdPointRefreshPreviewService.CreditCancellationRow cancellation = validCancellations[i];
      LoyaltyLedger debitLedger = new LoyaltyLedger();
      debitLedger.EventType = 'Debit';
      debitLedger.LoyaltyProgramMemberId = preview.memberId;
      debitLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
      debitLedger.LoyaltyPgmCrcySubtypeId = context.bucketKeyToSubtypeId.get(cancellation.creditBucketKey);
      debitLedger.Points = cancellation.points;
      debitLedger.ActivityDate = toStartOfDay(eventDates[i]);
      debitLedger.TransactionJournalId = journals[i].Id;
      debitLedgers.add(debitLedger);
      context.totalRedeemed += cancellation.points;
    }
    insert debitLedgers;
    context.insertLedgerCount += debitLedgers.size();

    List<LoyaltyLedgerTraceability> traces = new List<LoyaltyLedgerTraceability>();
    for (Integer i = 0; i < validCancellations.size(); i++) {
      GdPointRefreshPreviewService.CreditCancellationRow cancellation = validCancellations[i];
      traces.add(
        buildTrace(
          preview.memberId,
          loyaltyProgramCurrencyId,
          context.bucketKeyToSubtypeId.get(cancellation.creditBucketKey),
          context.bucketKeyToLedgerId.get(cancellation.creditBucketKey),
          debitLedgers[i].Id,
          cancellation.points,
          'CreditCancellation'
        )
      );
    }
    if (!traces.isEmpty()) {
      insert traces;
      context.insertTraceCount += traces.size();
    }
  }

  private static String resolveCreditJournalSubTypeName(GdPointRefreshPreviewService.BucketRow bucket) {
    if (bucket == null) {
      return 'Api Forced Credit';
    }
    if (isDebitCancelRestoreBucket(bucket.bucketKey)) {
      return 'Point Redeem Cancel';
    }
    if (isPromotionCreditBucket(bucket.bucketKey)) {
      return 'Promotion Point Accrual';
    }
    return String.isBlank(bucket.originSaleNo) ? 'Api Forced Credit' : 'Purchase Accrual';
  }

  private static String resolveCreditCancellationJournalSubTypeName(
    GdPointRefreshPreviewService.CreditCancellationRow cancellation,
    GdPointRefreshPreviewService.EventRow sourceEvent
  ) {
    String key = ((cancellation == null ? '' : String.valueOf(cancellation.creditBucketKey)) + ';' + (sourceEvent == null ? '' : String.valueOf(sourceEvent.eventKey))).toUpperCase();
    return key.contains('PROMO') ? 'Promotion Point Accrual Reversal' : 'Cancel Purchase Accrual';
  }

  private static String buildCreditLedgerNotes(GdPointRefreshPreviewService.BucketRow bucket) {
    List<String> parts = new List<String>();
    if (bucket != null && String.isNotBlank(bucket.rootOriginKey) && bucket.rootOriginKey != bucket.bucketKey) {
      parts.add('ORIGIN_KEY=' + bucket.rootOriginKey);
    }
    if (bucket != null && isDebitCancelRestoreBucket(bucket.bucketKey) && String.isNotBlank(bucket.rootOriginKey)) {
      parts.add('ORIGIN_CREDIT_KEY=' + bucket.rootOriginKey);
    }
    if (bucket != null && String.isNotBlank(bucket.notes)) {
      parts.add(bucket.notes);
    }
    return parts.isEmpty() ? null : truncate(String.join(parts, ';'), 255);
  }

  private static Boolean isPromotionCreditBucket(String bucketKey) {
    return String.isNotBlank(bucketKey) && bucketKey.toUpperCase().contains('PROMO');
  }

  private static Boolean isDebitCancelRestoreBucket(String bucketKey) {
    return String.isNotBlank(bucketKey) && bucketKey.toUpperCase().contains('DEBIT_CANCEL') && bucketKey.toUpperCase().contains(':RESTORE:');
  }

  private static TransactionJournal buildJournal(
    Id memberId,
    Id loyaltyProgramId,
    String saleNo,
    Date eventDate,
    Decimal points,
    String journalTypeName,
    String journalSubTypeName,
    String notes,
    Map<String, Order> orderBySaleNo
  ) {
    TransactionJournal tj = new TransactionJournal();
    tj.MemberId = memberId;
    tj.LoyaltyProgramId = loyaltyProgramId;
    tj.JournalTypeId = getJournalTypeId(journalTypeName);
    tj.JournalSubTypeId = getJournalSubTypeId(journalSubTypeName, tj.JournalTypeId);
    tj.Status = 'Processed';
    tj.JournalReason__c = '6';
    tj.TransactionAmount = points;
    tj.ActivityDate = toStartOfDay(eventDate);
    tj.JournalDate = toStartOfDay(eventDate);
    tj.AdditionalNotes__c = truncate(notes, 255);
    Order order = String.isBlank(saleNo) || orderBySaleNo == null ? null : orderBySaleNo.get(saleNo);
    if (order != null) {
      if (order.IsReductionOrder__c == true) {
        tj.SaleId__c = order.Id;
      } else {
        tj.OrderId = order.Id;
      }
    }
    return tj;
  }

  private static LoyaltyLedgerTraceability buildTrace(
    Id memberId,
    Id currencyId,
    Id subtypeId,
    Id creditLedgerId,
    Id debitLedgerId,
    Decimal points,
    String actionType
  ) {
    LoyaltyLedgerTraceability trace = new LoyaltyLedgerTraceability();
    trace.LoyaltyProgramMemberId = memberId;
    trace.LoyaltyProgramCurrencyId = currencyId;
    trace.LoyaltyPgmCurrencySubtypeId = subtypeId;
    trace.CreditLoyaltyLedgerId = creditLedgerId;
    trace.DebitLoyaltyLedgerId = debitLedgerId;
    trace.Points = points;
    trace.ActionType = actionType;
    return trace;
  }

  private static void updateMemberCurrency(Id memberId, Decimal balance, Decimal totalAccrued, Decimal totalRedeemed) {
    List<LoyaltyMemberCurrency> rows = [
      SELECT Id, TotalPointsAccrued, TotalPointsRedeemed
      FROM LoyaltyMemberCurrency
      WHERE LoyaltyMemberId = :memberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
      LIMIT 1
    ];
    if (rows.isEmpty()) {
      return;
    }
    LoyaltyMemberCurrency lmc = rows[0];
    lmc.TotalPointsAccrued = totalAccrued;
    lmc.TotalPointsRedeemed = totalRedeemed;
    update lmc;
  }

  private static Map<String, GdPointRefreshPreviewService.EventRow> buildEventByKey(GdPointRefreshPreviewService.PreviewResult preview) {
    Map<String, GdPointRefreshPreviewService.EventRow> result = new Map<String, GdPointRefreshPreviewService.EventRow>();
    if (preview == null || preview.events == null) {
      return result;
    }
    for (GdPointRefreshPreviewService.EventRow event : preview.events) {
      result.put(event.eventKey, event);
    }
    return result;
  }

  private static Decimal sumAllocationPoints(List<GdPointRefreshPreviewService.AllocationRow> allocations) {
    Decimal total = 0;
    for (GdPointRefreshPreviewService.AllocationRow allocation : allocations) {
      total += allocation.points == null ? 0 : allocation.points;
    }
    return total;
  }

  private static Id getLoyaltyProgramCurrencyId() {
    return [SELECT Id FROM LoyaltyProgramCurrency WHERE Name = :LOYALTY_PROGRAM_CURRENCY_NAME LIMIT 1].Id;
  }

  private static Id getLoyaltyProgramId(Id memberId) {
    return [SELECT ProgramId FROM LoyaltyProgramMember WHERE Id = :memberId LIMIT 1].ProgramId;
  }

  private static Map<String, Id> loadSubtypeIdByPointType(GdPointRefreshPreviewService.PreviewResult preview) {
    Set<String> pointTypes = new Set<String>();
    for (GdPointRefreshPreviewService.BucketRow bucket : preview.buckets) {
      if (String.isNotBlank(bucket.pointTypeCode)) {
        pointTypes.add(bucket.pointTypeCode);
      }
    }
    Map<String, Id> result = new Map<String, Id>();
    if (pointTypes.isEmpty()) {
      return result;
    }
    for (LoyaltyPgmCurrencySubtype subtype : [
      SELECT Id, PointTypeCode__c
      FROM LoyaltyPgmCurrencySubtype
      WHERE PointTypeCode__c IN :pointTypes
    ]) {
      if (!result.containsKey(subtype.PointTypeCode__c)) {
        result.put(subtype.PointTypeCode__c, subtype.Id);
      }
    }
    return result;
  }

  private static Map<String, Order> loadOrderBySaleNo(GdPointRefreshPreviewService.PreviewResult preview) {
    Set<String> saleNos = new Set<String>();
    for (GdPointRefreshPreviewService.EventRow event : preview.events) {
      if (String.isNotBlank(event.saleNo)) {
        saleNos.add(event.saleNo);
      }
    }
    for (GdPointRefreshPreviewService.BucketRow bucket : preview.buckets) {
      if (String.isNotBlank(bucket.originSaleNo)) {
        saleNos.add(bucket.originSaleNo);
      }
    }
    Map<String, Order> result = new Map<String, Order>();
    if (saleNos.isEmpty()) {
      return result;
    }
    for (Order order : [
      SELECT Id, SaleNo__c, IsReductionOrder__c
      FROM Order
      WHERE SaleNo__c IN :saleNos
    ]) {
      result.put(order.SaleNo__c, order);
    }
    return result;
  }

  private static Id getJournalTypeId(String name) {
    if (journalTypeIdByName.containsKey(name)) {
      return journalTypeIdByName.get(name);
    }
    Id idValue = [SELECT Id FROM JournalType WHERE Name = :name LIMIT 1].Id;
    journalTypeIdByName.put(name, idValue);
    return idValue;
  }

  private static Id getJournalSubTypeId(String name, Id journalTypeId) {
    String key = String.valueOf(journalTypeId) + ':' + name;
    if (journalSubTypeIdByKey.containsKey(key)) {
      return journalSubTypeIdByKey.get(key);
    }
    Id idValue = [
      SELECT Id
      FROM JournalSubType
      WHERE Name = :name AND JournalTypeId = :journalTypeId
      LIMIT 1
    ].Id;
    journalSubTypeIdByKey.put(key, idValue);
    return idValue;
  }

  private static Datetime toStartOfDay(Date d) {
    return d == null ? Datetime.now() : TimeUtil.dateToUtcStartOfDay(d);
  }

  private static String truncate(String value, Integer maxLength) {
    if (value == null || maxLength == null || value.length() <= maxLength) {
      return value;
    }
    return value.substring(0, maxLength);
  }

  private static Id toIdOrNull(String value) {
    if (String.isBlank(value) || (value.length() != 15 && value.length() != 18)) {
      return null;
    }
    try {
      return (Id) value;
    } catch (Exception e) {
      return null;
    }
  }
}