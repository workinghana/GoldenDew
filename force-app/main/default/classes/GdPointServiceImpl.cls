public with sharing class GdPointServiceImpl implements GdPointService {
  private static final String JOURNAL_TYPE_NAME_ACCRUAL = 'Accrual'; // 포인트/쿠폰 지급
  private static final String JOURNAL_TYPE_NAME_REDEMPTION = 'Redemption'; // 포인트/쿠폰 사용
  private static final String JOURNAL_TYPE_NAME_POINTS_EXPIRATION = 'Points Expiration'; // 포인트 만료
  private static final String JOURNAL_TYPE_NAME_DEPOSIT = 'Deposit'; // 입금/결제
  private static final String JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL = 'Accrual Reversal'; // 포인트/쿠폰 지급 취소
  private static final String JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL = 'Redemption Reversal'; // 포인트/쿠폰 사용 취소
  private static final String JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL = 'Deposit Reversal'; // 입금/결제 취소

  private static final String JOURNAL_SUB_TYPE_NAME_POINT_DEBIT = 'Point Debit'; // 포인트 사용
  private static final String JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL = 'Purchase Accrual'; // 구매 시 포인트 적립
  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT = 'Order Deposit'; // 주문 입금
  private static final String JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL = 'Order Deposit Reversal'; // 주문 입금 취소
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT = 'Sale Deposit'; // 판매 입금
  private static final String JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL = 'Sale Deposit Reversal'; // 판매 입금 취소
  private static final String JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL = 'Point Redeem Cancel'; // 포인트 사용 취소
  private static final String JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL = 'Cancel Purchase Accrual'; // 구매 시 포인트 적립 취소
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM = 'Coupon Redeem'; // 쿠폰 사용
  private static final String JOURNAL_SUB_TYPE_NAME_COUPON_REDEEM_CANCEL = 'Coupon Redeem Cancel'; // 쿠폰 사용 취소
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_EXPIRE = 'Api Forced Expire'; // API 요청에 의한 포인트 강제 소멸 처리
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT = 'Api Forced Debit'; // API 요청에 의한 포인트 강제 차감 처리
  private static final String JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT = 'Api Forced Credit'; // API 요청에 의한 포인트 강제 지급(적립) 처리
  private static final String JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL = 'Promotion Point Accrual'; // 프로모션 포인트 지급
  private static final String JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL = 'Promotion Point Accrual Reversal'; // 프로모션 포인트 지급 취소

  private static final String LOYALTY_PROGRAM_CURRENCY_NAME = '포인트';

  private static final String POINT_SUB_TYPE_NAME = '에코포인트';
  private static final String POINT_SUB_TYPE_NAME_EVENT = '이벤트포인트';

  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT = 'Debit'; // 포인트 사용
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION = 'DebitCancellation'; // 포인트 사용 취소
  private static final String LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION = 'CreditCancellation'; // 포인트 적립 취소

  private static final String ECO_POINT_TYPE_CODE = '05';
  private static final String ECO_POINT_CANCEL_NOTE = 'FULL_RETURN_ECO_POINT_CANCEL';
  private static final String ECO_POINT_RESTORE_NOTE = 'FULL_RETURN_ECO_POINT_RESTORE';
  private static final String ECO_POINT_CANCEL_RESULT_KEY = 'FullReturnEcoPointCancelList';
  private static final String ECO_POINT_RESTORE_RESULT_KEY = 'FullReturnEcoPointRestoreList';
  private static final String OPTION_C_RETURN_DEPOSIT_DELETE_FORCE_CREDIT_MARKER = 'OPTC_RETURN_DEPOSIT_DELETE_FORCE_CREDIT';
  private static final String OPTION_C_RETURN_ORDER_ID_KEY = 'returnOrderId=';
  private static final String RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE = '반품 입금 삭제로 인한 "포인트 사용" 내역 복구';

  /**
   * 삭제 보조 LL 식별용 마커 노트 모음. (반품 삭제/판매 삭제로 추가 발생한 LL)
   * 이들 노트가 TJ.AdditionalNotes__c 에 박혀 있으면 시점 컷오프 비교 시
   * Sale/Order.EffectiveDate 가 아닌 CreatedDate 기준 (반품/판매 삭제는 무조건 당일 발생).
   */
  private static final Set<String> RESTORE_NOTES = new Set<String>{
    RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE,
    'Restore purchase accrual due to return deletion',
    'Restore promotion point accrual due to return deletion',
    ECO_POINT_RESTORE_NOTE
  };

  private static void logTiming(String label, Long startMs, Integer startCpu) {
    Long elapsedMs = Datetime.now().getTime() - startMs;
    Integer elapsedCpu = Limits.getCpuTime() - startCpu;
    System.debug(LoggingLevel.WARN, '[TIMING] ' + label + ' | 누적 ' + elapsedMs + 'ms | CPU ' + elapsedCpu + 'ms');
  }

  private class TimingCheckpoint {
    public Long elapsedMs;
    public Integer elapsedCpu;

    public TimingCheckpoint(Long elapsedMs, Integer elapsedCpu) {
      this.elapsedMs = elapsedMs;
      this.elapsedCpu = elapsedCpu;
    }
  }

  private class SaleSequenceCutoff {
    public Datetime activityDate;
    public Datetime createdDate;
    public Id journalId;
    public Id orderId;
    public String saleNo;

    public SaleSequenceCutoff(Datetime activityDate, Datetime createdDate, Id journalId, Id orderId, String saleNo) {
      this.activityDate = activityDate;
      this.createdDate = createdDate;
      this.journalId = journalId;
      this.orderId = orderId;
      this.saleNo = saleNo;
    }
  }

  private class AvailableCreditBalance {
    public Id creditLedgerId;
    public Id subtypeId;
    public String subtypeName;
    public String pointTypeCode;
    public Date expiryDate;
    public Integer availablePoints;

    public AvailableCreditBalance(
      Id creditLedgerId,
      Id subtypeId,
      String subtypeName,
      String pointTypeCode,
      Date expiryDate,
      Integer availablePoints
    ) {
      this.creditLedgerId = creditLedgerId;
      this.subtypeId = subtypeId;
      this.subtypeName = subtypeName;
      this.pointTypeCode = pointTypeCode;
      this.expiryDate = expiryDate;
      this.availablePoints = availablePoints;
    }
  }

  private static TimingCheckpoint logTimingWithDelta(String label, Long startMs, Integer startCpu, TimingCheckpoint previousCheckpoint) {
    Long elapsedMs = Datetime.now().getTime() - startMs;
    Integer elapsedCpu = Limits.getCpuTime() - startCpu;
    Long deltaMs = (previousCheckpoint == null) ? elapsedMs : elapsedMs - previousCheckpoint.elapsedMs;
    Integer deltaCpu = (previousCheckpoint == null) ? elapsedCpu : elapsedCpu - previousCheckpoint.elapsedCpu;
    System.debug(
      LoggingLevel.WARN,
      '[TIMING] ' + label + ' | 누적 ' + elapsedMs + 'ms | CPU ' + elapsedCpu + 'ms | 구간 ' + deltaMs + 'ms | 구간CPU ' + deltaCpu + 'ms'
    );
    return new TimingCheckpoint(elapsedMs, elapsedCpu);
  }

  private static Decimal parseAdditionalNotesPointRate(String rawRateText) {
    if (String.isBlank(rawRateText)) {
      return 0;
    }

    String rateText = rawRateText.trim();
    Integer metadataStartIndex = rateText.indexOf(';');
    if (metadataStartIndex >= 0) {
      rateText = rateText.substring(0, metadataStartIndex).trim();
    }

    return Decimal.valueOf(rateText);
  }

  private static Boolean isOptionCReturnDepositDeleteForceCredit(String notes) {
    return !String.isBlank(notes) && notes.contains(OPTION_C_RETURN_DEPOSIT_DELETE_FORCE_CREDIT_MARKER);
  }

  private static Id parseOptionCReturnOrderId(String notes) {
    if (String.isBlank(notes)) {
      return null;
    }

    Integer startIndex = notes.indexOf(OPTION_C_RETURN_ORDER_ID_KEY);
    if (startIndex < 0) {
      return null;
    }

    startIndex += OPTION_C_RETURN_ORDER_ID_KEY.length();
    Integer endIndex = notes.indexOf(',', startIndex);
    if (endIndex < 0) {
      endIndex = notes.indexOf(';', startIndex);
    }
    if (endIndex < 0) {
      endIndex = notes.length();
    }

    String rawId = notes.substring(startIndex, endIndex).trim();
    if (String.isBlank(rawId)) {
      return null;
    }

    try {
      return (Id) rawId;
    } catch (Exception e) {
      return null;
    }
  }

  private static Map<Id, Date> loadOrderEffectiveDateMap(Set<Id> orderIdSet) {
    Map<Id, Date> result = new Map<Id, Date>();
    if (orderIdSet == null || orderIdSet.isEmpty()) {
      return result;
    }

    for (Order orderRecord : [SELECT Id, EffectiveDate FROM Order WHERE Id IN :orderIdSet]) {
      result.put(orderRecord.Id, orderRecord.EffectiveDate);
    }
    return result;
  }

  private static Boolean shouldExcludeOptionCForceCreditByReturnDate(String notes, Date queryDate, Map<Id, Date> returnOrderEffectiveDateMap) {
    if (queryDate == null || !isOptionCReturnDepositDeleteForceCredit(notes)) {
      return false;
    }

    Id returnOrderId = parseOptionCReturnOrderId(notes);
    if (returnOrderId == null || returnOrderEffectiveDateMap == null || !returnOrderEffectiveDateMap.containsKey(returnOrderId)) {
      return false;
    }

    Date returnEffectiveDate = returnOrderEffectiveDateMap.get(returnOrderId);
    return returnEffectiveDate != null && returnEffectiveDate > queryDate;
  }

  private static Boolean isActivePointHelpTransaction(TransactionJournal tj) {
    if (tj == null) {
      return true;
    }
    if (tj.IsDeleted__c == true) {
      return false;
    }
    if (tj.Order != null && tj.Order.IsDeleted__c == true) {
      return false;
    }
    if (tj.SaleId__r != null && tj.SaleId__r.IsDeleted__c == true) {
      return false;
    }
    return true;
  }

  private static String resolvePointHelpSaleNo(TransactionJournal tj) {
    if (tj == null) {
      return null;
    }
    if (tj.Order != null && String.isNotBlank(tj.Order.SaleNo__c)) {
      return tj.Order.SaleNo__c;
    }
    if (tj.SaleId__r != null && String.isNotBlank(tj.SaleId__r.SaleNo__c)) {
      return tj.SaleId__r.SaleNo__c;
    }
    return null;
  }

  private static Boolean isOriginCreditExcludedForPointHelp(
    Id originCreditLedgerId,
    String currentSaleNo,
    Map<Id, LoyaltyLedger> originCreditLedgerMap
  ) {
    if (originCreditLedgerId == null || originCreditLedgerMap == null || !originCreditLedgerMap.containsKey(originCreditLedgerId)) {
      return false;
    }

    LoyaltyLedger originCreditLedger = originCreditLedgerMap.get(originCreditLedgerId);
    if (originCreditLedger == null || !isActivePointHelpTransaction(originCreditLedger.TransactionJournal)) {
      return true;
    }

    String originSaleNo = resolvePointHelpSaleNo(originCreditLedger.TransactionJournal);
    return String.isNotBlank(currentSaleNo) && String.isNotBlank(originSaleNo) && currentSaleNo == originSaleNo;
  }

  private static Map<Id, LoyaltyLedger> loadOriginCreditLedgersForPointHelp(List<LoyaltyLedger> creditLedgerList) {
    Set<Id> originCreditLedgerIdSet = new Set<Id>();
    if (creditLedgerList != null) {
      for (LoyaltyLedger creditLedger : creditLedgerList) {
        Id originCreditLedgerId = extractOriginCreditLedgerId(creditLedger == null ? null : creditLedger.AdditionalNotes);
        if (originCreditLedgerId != null) {
          originCreditLedgerIdSet.add(originCreditLedgerId);
        }
      }
    }

    if (originCreditLedgerIdSet.isEmpty()) {
      return new Map<Id, LoyaltyLedger>();
    }

    return new Map<Id, LoyaltyLedger>(
      [
        SELECT
          Id,
          TransactionJournal.Id,
          TransactionJournal.IsDeleted__c,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.IsDeleted__c,
          TransactionJournal.SaleId__r.SaleNo__c,
          TransactionJournal.SaleId__r.IsDeleted__c
        FROM LoyaltyLedger
        WHERE Id IN :originCreditLedgerIdSet
      ]
    );
  }

  private static Datetime resolvePurchaseAccrualDatetime(Id orderId) {
    if (orderId == null) {
      return Datetime.now();
    }

    List<Order> orderList = [
      SELECT EndDate
      FROM Order
      WHERE Id = :orderId
      LIMIT 1
    ];

    if (orderList.isEmpty() || orderList[0].EndDate == null) {
      return Datetime.now();
    }

    return TimeUtil.dateToUtcStartOfDay(orderList[0].EndDate);
  }

  private static Date resolvePurchaseAccrualExpirationDate(Id orderId) {
    Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(orderId);
    Date baseDate = purchaseAccrualDatetime.date();
    return baseDate == null ? null : baseDate.addYears(2);
  }

  private static Id resolvePurchaseAccrualOrderId(TransactionJournal sourceTj) {
    if (sourceTj == null) {
      return null;
    }
    return sourceTj.SaleId__c != null ? sourceTj.SaleId__c : sourceTj.OrderId;
  }

  private static Integer compareSaleSequence(
    Datetime leftActivityDate,
    Datetime leftCreatedDate,
    Id leftJournalId,
    Datetime rightActivityDate,
    Datetime rightCreatedDate,
    Id rightJournalId
  ) {
    Long leftActivity = leftActivityDate == null ? 0 : leftActivityDate.getTime();
    Long rightActivity = rightActivityDate == null ? 0 : rightActivityDate.getTime();
    if (leftActivity != rightActivity) {
      return leftActivity < rightActivity ? -1 : 1;
    }

    Long leftCreated = leftCreatedDate == null ? 0 : leftCreatedDate.getTime();
    Long rightCreated = rightCreatedDate == null ? 0 : rightCreatedDate.getTime();
    if (leftCreated != rightCreated) {
      return leftCreated < rightCreated ? -1 : 1;
    }

    String leftIdValue = leftJournalId == null ? '' : String.valueOf(leftJournalId);
    String rightIdValue = rightJournalId == null ? '' : String.valueOf(rightJournalId);
    return leftIdValue.compareTo(rightIdValue);
  }

  // 포인트 적용 도움창 조회 관련 매서드 2
  private static SaleSequenceCutoff resolveSaleSequenceCutoff(Id orderId, String saleNo) {
    Id resolvedOrderId = orderId;
    String resolvedSaleNo = saleNo;
    Date resolvedSaleDate;

    if (resolvedOrderId == null && String.isNotBlank(resolvedSaleNo)) {
      List<Order> saleOrderList = [SELECT Id, SaleNo__c, EffectiveDate FROM Order WHERE SaleNo__c = :resolvedSaleNo LIMIT 1];
      if (!saleOrderList.isEmpty()) {
        resolvedOrderId = saleOrderList[0].Id;
        resolvedSaleNo = saleOrderList[0].SaleNo__c;
        resolvedSaleDate = saleOrderList[0].EffectiveDate;
      }
    }

    if (resolvedOrderId == null) {
      return null;
    }

    if (String.isBlank(resolvedSaleNo)) {
      List<Order> orderList = [SELECT SaleNo__c, EffectiveDate FROM Order WHERE Id = :resolvedOrderId LIMIT 1];
      if (!orderList.isEmpty()) {
        resolvedSaleNo = orderList[0].SaleNo__c;
        resolvedSaleDate = orderList[0].EffectiveDate;
      }
    } else if (resolvedSaleDate == null) {
      List<Order> orderList = [SELECT EffectiveDate FROM Order WHERE Id = :resolvedOrderId LIMIT 1];
      if (!orderList.isEmpty()) {
        resolvedSaleDate = orderList[0].EffectiveDate;
      }
    }

    List<TransactionJournal> saleDepositList = [
      SELECT Id, ActivityDate, CreatedDate, Order.SaleNo__c
      FROM TransactionJournal
      WHERE OrderId = :resolvedOrderId AND JournalSubType.Name = :JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT AND IsDeleted__c = FALSE
      ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
      LIMIT 1
    ];

    if (!saleDepositList.isEmpty()) {
      TransactionJournal saleDeposit = saleDepositList[0];
      Datetime cutoffActivityDate = resolvedSaleDate == null ? saleDeposit.ActivityDate : TimeUtil.dateToUtcStartOfDay(resolvedSaleDate);
      return new SaleSequenceCutoff(
        cutoffActivityDate,
        saleDeposit.CreatedDate,
        saleDeposit.Id,
        resolvedOrderId,
        String.isBlank(resolvedSaleNo) ? saleDeposit.Order.SaleNo__c : resolvedSaleNo
      );
    }

    return null;
  }

  private static List<AvailableCreditBalance> buildAvailableCreditBalances(
    Id memberId,
    SaleSequenceCutoff cutoff,
    Datetime nextDayStart,
    String currentSaleNo
  ) {
    if (memberId == null) {
      return new List<AvailableCreditBalance>();
    }

    // [Time-Symmetric Fix 2026-04-27] 시점 시뮬레이션 비대칭 버그 해결
    //   기존 동작: Credit 은 시점 필터로 그 시점 이전만 조회되지만,
    //              LLT/Expiry/AccrualReversal 차감은 시간 필터가 없어 미래 사건까지 합산.
    //   결과: 과거 OrderDate 기준 조회 시 미래의 반품/취소/소멸이 차감되어 가용 포인트가 실제보다 적게 표시.
    //   해결: 모든 차감 단계에 동일한 시점 컷오프를 적용. cutoff/nextDayStart 모드를 단일 effectiveCutoff 로 통합.
    Datetime effectiveCutoff;
    if (cutoff != null && cutoff.activityDate != null) {
      effectiveCutoff = cutoff.activityDate; // 판매 시퀀스 모드: 해당 시점까지 포함 (<=)
    } else if (nextDayStart != null) {
      effectiveCutoff = Datetime.newInstance(nextDayStart.getTime() - 1); // OrderDate 모드: 그 날 자정 직전 (1ms 전)
    } else {
      effectiveCutoff = Datetime.newInstance(9999, 12, 31); // 컷오프 없음 → 사실상 ∞ (필터 무력화)
    }

    List<LoyaltyLedger> creditLedgerList;
    if (cutoff != null && cutoff.activityDate != null) {
      creditLedgerList = [
        SELECT
          Id,
          Points,
          ExpiryDate,
          ActivityDate,
          AdditionalNotes,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          TransactionJournal.Id,
          TransactionJournal.CreatedDate,
          TransactionJournal.JournalType.Name,
          TransactionJournal.JournalSubType.Name,
          TransactionJournal.AdditionalNotes__c,
          TransactionJournal.RelatedJournalId,
          TransactionJournal.RelatedJournal.JournalType.Name,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.SaleId__r.SaleNo__c
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Credit'
          AND Points > 0
          AND ActivityDate <= :cutoff.activityDate
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
        ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
        LIMIT 50000
      ];
    } else if (nextDayStart != null) {
      creditLedgerList = [
        SELECT
          Id,
          Points,
          ExpiryDate,
          ActivityDate,
          AdditionalNotes,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          TransactionJournal.Id,
          TransactionJournal.CreatedDate,
          TransactionJournal.JournalType.Name,
          TransactionJournal.JournalSubType.Name,
          TransactionJournal.AdditionalNotes__c,
          TransactionJournal.RelatedJournalId,
          TransactionJournal.RelatedJournal.JournalType.Name,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.SaleId__r.SaleNo__c
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Credit'
          AND Points > 0
          AND ActivityDate < :nextDayStart
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
        ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
        LIMIT 50000
      ];
    } else {
      creditLedgerList = [
        SELECT
          Id,
          Points,
          ExpiryDate,
          ActivityDate,
          AdditionalNotes,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          TransactionJournal.Id,
          TransactionJournal.CreatedDate,
          TransactionJournal.JournalType.Name,
          TransactionJournal.JournalSubType.Name,
          TransactionJournal.AdditionalNotes__c,
          TransactionJournal.RelatedJournalId,
          TransactionJournal.RelatedJournal.JournalType.Name,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.SaleId__r.SaleNo__c
        FROM LoyaltyLedger
        WHERE LoyaltyProgramMemberId = :memberId AND EventType = 'Credit' AND Points > 0 AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
        ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
        LIMIT 50000
      ];
    }

    if (creditLedgerList.isEmpty()) {
      return new List<AvailableCreditBalance>();
    }

    Map<Id, OriginRestoreCreditState> originRestoreCreditStateByOriginId = buildOriginRestoreCreditStateMap(creditLedgerList);

    List<LoyaltyLedger> filteredCreditLedgerList = new List<LoyaltyLedger>();
    Set<Id> creditLedgerIdSet = new Set<Id>();
    Set<Id> subtypeIdSet = new Set<Id>();
    Set<Date> expiryDateSet = new Set<Date>();

    for (LoyaltyLedger creditLedger : creditLedgerList) {
      String creditJournalTypeName = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.JournalType != null
        ? creditLedger.TransactionJournal.JournalType.Name
        : null;
      String creditJournalSubTypeName = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.JournalSubType != null
        ? creditLedger.TransactionJournal.JournalSubType.Name
        : null;
      String creditJournalAdditionalNotes = creditLedger.TransactionJournal != null ? creditLedger.TransactionJournal.AdditionalNotes__c : null;
      String relatedJournalTypeName = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.RelatedJournal != null &&
        creditLedger.TransactionJournal.RelatedJournal.JournalType != null
        ? creditLedger.TransactionJournal.RelatedJournal.JournalType.Name
        : null;
      Id originCreditLedgerId = extractOriginCreditLedgerId(creditLedger.AdditionalNotes);
      if (shouldExcludeRestoreCreditByOrigin(originCreditLedgerId, originRestoreCreditStateByOriginId)) {
        continue;
      }

      if (
        creditLedger.AdditionalNotes == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE ||
        creditLedger.AdditionalNotes == ECO_POINT_RESTORE_NOTE ||
        creditJournalAdditionalNotes == 'Restore purchase accrual due to return deletion' ||
        creditJournalAdditionalNotes == 'Restore promotion point accrual due to return deletion' ||
        creditJournalAdditionalNotes == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE ||
        creditJournalAdditionalNotes == ECO_POINT_RESTORE_NOTE
      ) {
        continue;
      }
      if (
        creditJournalTypeName == JOURNAL_TYPE_NAME_ACCRUAL &&
        creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.RelatedJournalId != null &&
        relatedJournalTypeName == JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
      ) {
        continue;
      }
      if (
        creditJournalTypeName == JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL &&
        (creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL ||
        creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL)
      ) {
        continue;
      }

      // [2026-04-23 추가] Point Redeem Cancel 이중 계산 방지
      // 주문 취소 시 cancelPointRedemption 이 원본 Debit Traceability 를 삭제하면서
      // 별도의 Point Redeem Cancel Credit Ledger 를 재생성한다.
      // 같은 (subtype, expiryDate) 쌍에서 원본 Credit Ledger (Point Redeem Cancel 아닌 것)
      // 가 아직 남아있으면, 이 복원 Credit 을 집계 제외하여 이중 계산을 방지.
      // 원본이 소진되어 사라진 경우(쌍이 없으면)에는 이 복원분을 살려서 안전장치 확보.
      // [v3 fix 2026-04-24] Flag ON 하에선 Trace 보존으로 자연 정합이므로 이 우회 블록 스킵
      if (creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL && !GdFeatureFlag.isEnabled('PointCancel_PreserveTrace')) {
        Boolean hasOriginalCounterpart = false;
        for (LoyaltyLedger other : creditLedgerList) {
          if (other.Id == creditLedger.Id) {
            continue;
          }
          if (other.LoyaltyPgmCrcySubtypeId != creditLedger.LoyaltyPgmCrcySubtypeId) {
            continue;
          }
          if (other.ExpiryDate != creditLedger.ExpiryDate) {
            continue;
          }
          String otherJst = other.TransactionJournal != null &&
            other.TransactionJournal.JournalSubType != null
            ? other.TransactionJournal.JournalSubType.Name
            : null;
          if (otherJst != null && otherJst != JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL) {
            hasOriginalCounterpart = true;
            break;
          }
        }
        if (hasOriginalCounterpart) {
          continue;
        }
      }

      String creditSaleNo = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.Order != null
        ? creditLedger.TransactionJournal.Order.SaleNo__c
        : null;
      String creditReturnSaleNo = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.SaleId__r != null
        ? creditLedger.TransactionJournal.SaleId__r.SaleNo__c
        : null;

      // [v3 fix 2026-04-24] Flag ON 하에선 재적립 Credit (Point Redeem Cancel) 이 same-sale 에 연결돼 있어도
      //   실제 사용 가능한 별도 Credit 이므로 same-sale 필터로 배제하지 않음.
      Boolean v3SkipSameSaleFilter = (creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL &&
      GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'));
      if (!v3SkipSameSaleFilter && !String.isBlank(currentSaleNo) && (currentSaleNo == creditSaleNo || currentSaleNo == creditReturnSaleNo)) {
        continue;
      }

      if (
        cutoff != null &&
        compareSaleSequence(
          creditLedger.ActivityDate,
          creditLedger.TransactionJournal == null ? null : creditLedger.TransactionJournal.CreatedDate,
          creditLedger.TransactionJournal == null ? null : creditLedger.TransactionJournal.Id,
          cutoff.activityDate,
          cutoff.createdDate,
          cutoff.journalId
        ) > 0
      ) {
        continue;
      }

      filteredCreditLedgerList.add(creditLedger);
      creditLedgerIdSet.add(creditLedger.Id);
      if (creditLedger.LoyaltyPgmCrcySubtypeId != null) {
        subtypeIdSet.add(creditLedger.LoyaltyPgmCrcySubtypeId);
      }
      if (creditLedger.ExpiryDate != null) {
        expiryDateSet.add(creditLedger.ExpiryDate);
      }
    }

    if (filteredCreditLedgerList.isEmpty()) {
      return new List<AvailableCreditBalance>();
    }

    Map<Id, Integer> reductionPointMap = new Map<Id, Integer>();
    Map<Id, Integer> traceCreditCancellationPointMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId, ActionType actionType, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :creditLedgerIdSet
        AND ActionType IN (
          'Debit',
          'DebitCancellation',
          'CreditCancellation'
          // [Time-Symmetric Fix 2026-04-27] 컷오프 시점 이후의 차감(미래 반품/취소) 은 시뮬레이션에서 제외
        )
        AND DebitLoyaltyLedger.ActivityDate <= :effectiveCutoff
      GROUP BY CreditLoyaltyLedgerId, ActionType
    ]) {
      Id creditLedgerId = (Id) ar.get('creditLedgerId');
      String actionType = (String) ar.get('actionType');
      Integer amount = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();

      if (!reductionPointMap.containsKey(creditLedgerId)) {
        reductionPointMap.put(creditLedgerId, 0);
      }

      if (actionType == 'DebitCancellation') {
        reductionPointMap.put(creditLedgerId, Math.max(0, reductionPointMap.get(creditLedgerId) - amount));
      } else {
        reductionPointMap.put(creditLedgerId, reductionPointMap.get(creditLedgerId) + amount);
        if (actionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION) {
          traceCreditCancellationPointMap.put(creditLedgerId, amount);
        }
      }
    }

    Map<String, Integer> expiredPointByKey = new Map<String, Integer>();
    if (!subtypeIdSet.isEmpty() && !expiryDateSet.isEmpty()) {
      for (AggregateResult ar : [
        SELECT LoyaltyPgmCrcySubtypeId subtypeId, ExpiryDate expiryDate, SUM(Points) totalPoints
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Expiry'
          AND LoyaltyPgmCrcySubtypeId IN :subtypeIdSet
          AND ExpiryDate IN :expiryDateSet
          // [Time-Symmetric Fix 2026-04-27] 컷오프 시점 이후의 소멸(미래 만료) 은 시뮬레이션에서 제외
          AND ActivityDate <= :effectiveCutoff
        GROUP BY LoyaltyPgmCrcySubtypeId, ExpiryDate
      ]) {
        String expiredKey = String.valueOf((Id) ar.get('subtypeId')) + '|' + String.valueOf((Date) ar.get('expiryDate'));
        expiredPointByKey.put(expiredKey, ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue());
      }
    }

    Map<String, Integer> accrualReversalPointByKey = new Map<String, Integer>();
    Map<Id, Integer> accrualReversalPointBySubtypeId = new Map<Id, Integer>();
    if (!subtypeIdSet.isEmpty()) {
      for (AggregateResult ar : [
        SELECT LoyaltyPgmCrcySubtypeId subtypeId, ExpiryDate expiryDate, SUM(Points) totalPoints
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Debit'
          AND TransactionJournal.JournalType.Name = :JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
          AND LoyaltyPgmCrcySubtypeId IN :subtypeIdSet
          // [Time-Symmetric Fix 2026-04-27] 컷오프 시점 이후의 적립취소(미래 반품) 는 시뮬레이션에서 제외
          AND ActivityDate <= :effectiveCutoff
        GROUP BY LoyaltyPgmCrcySubtypeId, ExpiryDate
      ]) {
        Id subtypeId = (Id) ar.get('subtypeId');
        Date reversalExpiryDate = (Date) ar.get('expiryDate');
        Integer totalPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();

        if (reversalExpiryDate == null) {
          if (!accrualReversalPointBySubtypeId.containsKey(subtypeId)) {
            accrualReversalPointBySubtypeId.put(subtypeId, 0);
          }
          accrualReversalPointBySubtypeId.put(subtypeId, accrualReversalPointBySubtypeId.get(subtypeId) + totalPoints);
        } else {
          String reversalKey = String.valueOf(subtypeId) + '|' + String.valueOf(reversalExpiryDate);
          if (!accrualReversalPointByKey.containsKey(reversalKey)) {
            accrualReversalPointByKey.put(reversalKey, 0);
          }
          accrualReversalPointByKey.put(reversalKey, accrualReversalPointByKey.get(reversalKey) + totalPoints);
        }
      }
    }

    for (LoyaltyLedger creditLedger : filteredCreditLedgerList) {
      Integer traceCreditCancellationPoints = traceCreditCancellationPointMap.containsKey(creditLedger.Id)
        ? traceCreditCancellationPointMap.get(creditLedger.Id)
        : 0;
      if (traceCreditCancellationPoints <= 0) {
        continue;
      }

      String reversalKey = String.valueOf(creditLedger.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(creditLedger.ExpiryDate);
      if (accrualReversalPointByKey.containsKey(reversalKey)) {
        Integer remainingTracePoints = Math.max(0, traceCreditCancellationPoints - accrualReversalPointByKey.get(reversalKey));
        accrualReversalPointByKey.put(reversalKey, Math.max(0, accrualReversalPointByKey.get(reversalKey) - traceCreditCancellationPoints));
        traceCreditCancellationPoints = remainingTracePoints;
      }

      if (traceCreditCancellationPoints > 0 && accrualReversalPointBySubtypeId.containsKey(creditLedger.LoyaltyPgmCrcySubtypeId)) {
        accrualReversalPointBySubtypeId.put(
          creditLedger.LoyaltyPgmCrcySubtypeId,
          Math.max(0, accrualReversalPointBySubtypeId.get(creditLedger.LoyaltyPgmCrcySubtypeId) - traceCreditCancellationPoints)
        );
      }
    }

    List<AvailableCreditBalance> result = new List<AvailableCreditBalance>();
    for (LoyaltyLedger creditLedger : filteredCreditLedgerList) {
      Integer credited = creditLedger.Points == null ? 0 : creditLedger.Points.intValue();
      Integer reduced = reductionPointMap.containsKey(creditLedger.Id) ? reductionPointMap.get(creditLedger.Id) : 0;
      Integer remaining = Math.max(0, credited - reduced);

      String expiredKey = String.valueOf(creditLedger.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(creditLedger.ExpiryDate);
      Integer allocatableExpired = expiredPointByKey.containsKey(expiredKey) ? expiredPointByKey.get(expiredKey) : 0;
      Integer expired = Math.min(remaining, allocatableExpired);
      remaining = Math.max(0, remaining - expired);
      if (expired > 0) {
        expiredPointByKey.put(expiredKey, Math.max(0, allocatableExpired - expired));
      }

      String reversalKey = String.valueOf(creditLedger.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(creditLedger.ExpiryDate);
      Integer allocatableReversal = accrualReversalPointByKey.containsKey(reversalKey) ? accrualReversalPointByKey.get(reversalKey) : 0;
      Integer reversal = Math.min(remaining, allocatableReversal);
      remaining = Math.max(0, remaining - reversal);
      if (reversal > 0) {
        accrualReversalPointByKey.put(reversalKey, Math.max(0, allocatableReversal - reversal));
      }

      if (remaining > 0 && accrualReversalPointBySubtypeId.containsKey(creditLedger.LoyaltyPgmCrcySubtypeId)) {
        Integer allocatableSubtypeReversal = accrualReversalPointBySubtypeId.get(creditLedger.LoyaltyPgmCrcySubtypeId);
        Integer subtypeReversal = Math.min(remaining, allocatableSubtypeReversal);
        remaining = Math.max(0, remaining - subtypeReversal);
        if (subtypeReversal > 0) {
          accrualReversalPointBySubtypeId.put(creditLedger.LoyaltyPgmCrcySubtypeId, Math.max(0, allocatableSubtypeReversal - subtypeReversal));
        }
      }

      if (remaining <= 0 || creditLedger.LoyaltyPgmCrcySubtype == null) {
        continue;
      }

      Id originCreditLedgerId = extractOriginCreditLedgerId(creditLedger.AdditionalNotes);
      if (originCreditLedgerId != null) {
        OriginRestoreCreditState originState = originRestoreCreditStateByOriginId.get(originCreditLedgerId);
        if (originState == null || originState.isInvalid == true || originState.remainingCap == null || originState.remainingCap <= 0) {
          continue;
        }
        remaining = Math.min(remaining, originState.remainingCap);
        originState.remainingCap = Math.max(0, originState.remainingCap - remaining);
        if (remaining <= 0) {
          continue;
        }
      }

      result.add(
        new AvailableCreditBalance(
          creditLedger.Id,
          creditLedger.LoyaltyPgmCrcySubtypeId,
          creditLedger.LoyaltyPgmCrcySubtype.Name,
          creditLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c,
          creditLedger.ExpiryDate,
          remaining
        )
      );
    }

    return result;
  }

  /**
   * [도움창 전용] buildAvailableCreditBalances 의 hierarchy 적용 변형.
   *   - 일반 LL: Sale/Order.EffectiveDate hierarchy + TJ.ActivityDate fallback
   *   - 삭제 보조 LL (RESTORE_NOTES): CreatedDate 기준
   *   - 추가: 당일 등록된 backdate Credit LL 이중 가시화 (5/5 = 150 케이스)
   *
   * 주의: getPointApplyHelpBySaleSequence (포인트 적용 도움창 조회) 전용.
   *       calculatePointUsageAvailableLimit 등 차감 로직은 원본 buildAvailableCreditBalances 사용.
   */
  private static List<AvailableCreditBalance> buildAvailableCreditBalancesForHelp(
    Id memberId,
    SaleSequenceCutoff cutoff,
    Datetime nextDayStart,
    String currentSaleNo
  ) {
    if (memberId == null) {
      return new List<AvailableCreditBalance>();
    }

    // [Time-Symmetric Fix 2026-04-27] 시점 시뮬레이션 비대칭 버그 해결
    //   기존 동작: Credit 은 시점 필터로 그 시점 이전만 조회되지만,
    //              LLT/Expiry/AccrualReversal 차감은 시간 필터가 없어 미래 사건까지 합산.
    //   결과: 과거 OrderDate 기준 조회 시 미래의 반품/취소/소멸이 차감되어 가용 포인트가 실제보다 적게 표시.
    //   해결: 모든 차감 단계에 동일한 시점 컷오프를 적용. cutoff/nextDayStart 모드를 단일 effectiveCutoff 로 통합.

    Datetime effectiveCutoff;
    if (cutoff != null && cutoff.activityDate != null) {
      effectiveCutoff = cutoff.activityDate; // 판매 시퀀스 모드: 해당 시점까지 포함 (<=)
    } else if (nextDayStart != null) {
      effectiveCutoff = Datetime.newInstance(nextDayStart.getTime() - 1); // OrderDate 모드: 그 날 자정 직전 (1ms 전)
    } else {
      effectiveCutoff = Datetime.newInstance(9999, 12, 31); // 컷오프 없음 → 사실상 ∞ (필터 무력화)
    }

    // [Effective Date Hierarchy Fix] Sale/Order.EffectiveDate 기준 비교용 Date/Datetime 산출.
    //   - 주문/반품: 무조건 당일 → Order.EffectiveDate 신뢰 가능
    //   - 판매: 과거 일자 등록 가능 → SaleId__r.EffectiveDate 가 backdate 효력일
    //   - 개별 지급/없음: TJ.ActivityDate fallback
    Date queryDate;
    Datetime startOfQueryDate;
    if (cutoff != null && cutoff.activityDate != null) {
      queryDate = cutoff.activityDate.date();
      startOfQueryDate = TimeUtil.dateToUtcStartOfDay(queryDate);
    } else if (nextDayStart != null) {
      queryDate = nextDayStart.addDays(-1).date();
      startOfQueryDate = TimeUtil.dateToUtcStartOfDay(queryDate);
    } else {
      queryDate = Date.newInstance(9999, 12, 31);
      startOfQueryDate = Datetime.newInstance(9999, 12, 31, 0, 0, 0);
    }

    List<LoyaltyLedger> creditLedgerList;
    if (cutoff != null && cutoff.activityDate != null) {
      creditLedgerList = [
        SELECT
          Id,
          Points,
          ExpiryDate,
          ActivityDate,
          AdditionalNotes,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          TransactionJournal.Id,
          TransactionJournal.IsDeleted__c,
          TransactionJournal.CreatedDate,
          TransactionJournal.ActivityDate,
          TransactionJournal.JournalType.Name,
          TransactionJournal.JournalSubType.Name,
          TransactionJournal.AdditionalNotes__c,
          TransactionJournal.RelatedJournalId,
          TransactionJournal.RelatedJournal.JournalType.Name,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.IsDeleted__c,
          TransactionJournal.Order.EffectiveDate,
          TransactionJournal.SaleId__r.SaleNo__c,
          TransactionJournal.SaleId__r.IsDeleted__c,
          TransactionJournal.SaleId__r.EffectiveDate
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Credit'
          AND Points > 0
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
          AND (TransactionJournal.IsDeleted__c = FALSE
          OR TransactionJournal.IsDeleted__c = NULL)
          AND (TransactionJournal.OrderId = NULL
          OR TransactionJournal.Order.IsDeleted__c = FALSE
          OR TransactionJournal.Order.IsDeleted__c = NULL)
          AND (TransactionJournal.SaleId__c = NULL
          OR TransactionJournal.SaleId__r.IsDeleted__c = FALSE
          OR TransactionJournal.SaleId__r.IsDeleted__c = NULL)
          // (1) 삭제 보조 LL: CreatedDate 기준
          AND ((TransactionJournal.AdditionalNotes__c IN :RESTORE_NOTES
          AND CreatedDate <= :effectiveCutoff)
          // (2) 일반 LL: Sale > Order > ActivityDate hierarchy
          OR ((TransactionJournal.AdditionalNotes__c = NULL
          OR TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
          AND ((TransactionJournal.SaleId__r.EffectiveDate != NULL
          AND TransactionJournal.SaleId__r.EffectiveDate <= :queryDate)
          OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND TransactionJournal.Order.EffectiveDate != NULL
          AND TransactionJournal.Order.EffectiveDate <= :queryDate)
          OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND TransactionJournal.Order.EffectiveDate = NULL
          AND TransactionJournal.ActivityDate <= :effectiveCutoff))))
        ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
        LIMIT 50000
      ];
    } else if (nextDayStart != null) {
      creditLedgerList = [
        SELECT
          Id,
          Points,
          ExpiryDate,
          ActivityDate,
          AdditionalNotes,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          TransactionJournal.Id,
          TransactionJournal.IsDeleted__c,
          TransactionJournal.CreatedDate,
          TransactionJournal.ActivityDate,
          TransactionJournal.JournalType.Name,
          TransactionJournal.JournalSubType.Name,
          TransactionJournal.AdditionalNotes__c,
          TransactionJournal.RelatedJournalId,
          TransactionJournal.RelatedJournal.JournalType.Name,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.IsDeleted__c,
          TransactionJournal.Order.EffectiveDate,
          TransactionJournal.SaleId__r.SaleNo__c,
          TransactionJournal.SaleId__r.IsDeleted__c,
          TransactionJournal.SaleId__r.EffectiveDate
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Credit'
          AND Points > 0
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
          AND (TransactionJournal.IsDeleted__c = FALSE
          OR TransactionJournal.IsDeleted__c = NULL)
          AND (TransactionJournal.OrderId = NULL
          OR TransactionJournal.Order.IsDeleted__c = FALSE
          OR TransactionJournal.Order.IsDeleted__c = NULL)
          AND (TransactionJournal.SaleId__c = NULL
          OR TransactionJournal.SaleId__r.IsDeleted__c = FALSE
          OR TransactionJournal.SaleId__r.IsDeleted__c = NULL)
          // (1) 삭제 보조 LL: CreatedDate 기준
          AND ((TransactionJournal.AdditionalNotes__c IN :RESTORE_NOTES
          AND CreatedDate <= :effectiveCutoff)
          // (2) 일반 LL: Sale > Order > ActivityDate hierarchy
          OR ((TransactionJournal.AdditionalNotes__c = NULL
          OR TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
          AND ((TransactionJournal.SaleId__r.EffectiveDate != NULL
          AND TransactionJournal.SaleId__r.EffectiveDate <= :queryDate)
          OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND TransactionJournal.Order.EffectiveDate != NULL
          AND TransactionJournal.Order.EffectiveDate <= :queryDate)
          OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND TransactionJournal.Order.EffectiveDate = NULL
          AND TransactionJournal.ActivityDate <= :effectiveCutoff))))
        ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
        LIMIT 50000
      ];
    } else {
      creditLedgerList = [
        SELECT
          Id,
          Points,
          ExpiryDate,
          ActivityDate,
          AdditionalNotes,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          TransactionJournal.Id,
          TransactionJournal.IsDeleted__c,
          TransactionJournal.CreatedDate,
          TransactionJournal.ActivityDate,
          TransactionJournal.JournalType.Name,
          TransactionJournal.JournalSubType.Name,
          TransactionJournal.AdditionalNotes__c,
          TransactionJournal.RelatedJournalId,
          TransactionJournal.RelatedJournal.JournalType.Name,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.IsDeleted__c,
          TransactionJournal.Order.EffectiveDate,
          TransactionJournal.SaleId__r.SaleNo__c,
          TransactionJournal.SaleId__r.IsDeleted__c,
          TransactionJournal.SaleId__r.EffectiveDate
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Credit'
          AND Points > 0
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
          AND (TransactionJournal.IsDeleted__c = FALSE
          OR TransactionJournal.IsDeleted__c = NULL)
          AND (TransactionJournal.OrderId = NULL
          OR TransactionJournal.Order.IsDeleted__c = FALSE
          OR TransactionJournal.Order.IsDeleted__c = NULL)
          AND (TransactionJournal.SaleId__c = NULL
          OR TransactionJournal.SaleId__r.IsDeleted__c = FALSE
          OR TransactionJournal.SaleId__r.IsDeleted__c = NULL)
        ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
        LIMIT 50000
      ];
    }

    if (creditLedgerList.isEmpty()) {
      return new List<AvailableCreditBalance>();
    }

    Map<Id, LoyaltyLedger> originCreditLedgerMap = loadOriginCreditLedgersForPointHelp(creditLedgerList);
    Map<Id, OriginRestoreCreditState> originRestoreCreditStateByOriginId = buildOriginRestoreCreditStateMap(creditLedgerList);

    Set<Id> optionCForceCreditReturnOrderIdSet = new Set<Id>();
    for (LoyaltyLedger creditLedger : creditLedgerList) {
      String notes = creditLedger.TransactionJournal == null ? null : creditLedger.TransactionJournal.AdditionalNotes__c;
      if (isOptionCReturnDepositDeleteForceCredit(notes)) {
        Id returnOrderId = parseOptionCReturnOrderId(notes);
        if (returnOrderId != null) {
          optionCForceCreditReturnOrderIdSet.add(returnOrderId);
        }
      }
    }
    Map<Id, Date> optionCForceCreditReturnEffectiveDateMap = loadOrderEffectiveDateMap(optionCForceCreditReturnOrderIdSet);

    List<LoyaltyLedger> filteredCreditLedgerList = new List<LoyaltyLedger>();
    Set<Id> creditLedgerIdSet = new Set<Id>();
    Set<Id> subtypeIdSet = new Set<Id>();
    Set<Date> expiryDateSet = new Set<Date>();

    for (LoyaltyLedger creditLedger : creditLedgerList) {
      String creditJournalTypeName = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.JournalType != null
        ? creditLedger.TransactionJournal.JournalType.Name
        : null;
      String creditJournalSubTypeName = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.JournalSubType != null
        ? creditLedger.TransactionJournal.JournalSubType.Name
        : null;
      String creditJournalAdditionalNotes = creditLedger.TransactionJournal != null ? creditLedger.TransactionJournal.AdditionalNotes__c : null;
      String relatedJournalTypeName = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.RelatedJournal != null &&
        creditLedger.TransactionJournal.RelatedJournal.JournalType != null
        ? creditLedger.TransactionJournal.RelatedJournal.JournalType.Name
        : null;

      if (!isActivePointHelpTransaction(creditLedger.TransactionJournal)) {
        continue;
      }

      Id originCreditLedgerId = extractOriginCreditLedgerId(creditLedger.AdditionalNotes);
      if (isOriginCreditExcludedForPointHelp(originCreditLedgerId, currentSaleNo, originCreditLedgerMap)) {
        continue;
      }
      if (shouldExcludeRestoreCreditByOrigin(originCreditLedgerId, originRestoreCreditStateByOriginId)) {
        continue;
      }

      if (shouldExcludeOptionCForceCreditByReturnDate(creditJournalAdditionalNotes, queryDate, optionCForceCreditReturnEffectiveDateMap)) {
        continue;
      }

      if (
        creditLedger.AdditionalNotes == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE ||
        creditLedger.AdditionalNotes == ECO_POINT_RESTORE_NOTE ||
        creditJournalAdditionalNotes == 'Restore purchase accrual due to return deletion' ||
        creditJournalAdditionalNotes == 'Restore promotion point accrual due to return deletion' ||
        creditJournalAdditionalNotes == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE ||
        creditJournalAdditionalNotes == ECO_POINT_RESTORE_NOTE
      ) {
        continue;
      }
      if (
        creditJournalTypeName == JOURNAL_TYPE_NAME_ACCRUAL &&
        creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.RelatedJournalId != null &&
        relatedJournalTypeName == JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
      ) {
        continue;
      }
      if (
        creditJournalTypeName == JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL &&
        (creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL ||
        creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL)
      ) {
        continue;
      }

      // [2026-04-23 추가] Point Redeem Cancel 이중 계산 방지
      // 주문 취소 시 cancelPointRedemption 이 원본 Debit Traceability 를 삭제하면서
      // 별도의 Point Redeem Cancel Credit Ledger 를 재생성한다.
      // 같은 (subtype, expiryDate) 쌍에서 원본 Credit Ledger (Point Redeem Cancel 아닌 것)
      // 가 아직 남아있으면, 이 복원 Credit 을 집계 제외하여 이중 계산을 방지.
      // 원본이 소진되어 사라진 경우(쌍이 없으면)에는 이 복원분을 살려서 안전장치 확보.
      // [v3 fix 2026-04-24] Flag ON 하에선 Trace 보존으로 자연 정합이므로 이 우회 블록 스킵
      if (creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL && !GdFeatureFlag.isEnabled('PointCancel_PreserveTrace')) {
        Boolean hasOriginalCounterpart = false;
        for (LoyaltyLedger other : creditLedgerList) {
          if (other.Id == creditLedger.Id) {
            continue;
          }
          if (other.LoyaltyPgmCrcySubtypeId != creditLedger.LoyaltyPgmCrcySubtypeId) {
            continue;
          }
          if (other.ExpiryDate != creditLedger.ExpiryDate) {
            continue;
          }
          String otherJst = other.TransactionJournal != null &&
            other.TransactionJournal.JournalSubType != null
            ? other.TransactionJournal.JournalSubType.Name
            : null;
          if (otherJst != null && otherJst != JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL) {
            hasOriginalCounterpart = true;
            break;
          }
        }
        if (hasOriginalCounterpart) {
          continue;
        }
      }

      String creditSaleNo = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.Order != null
        ? creditLedger.TransactionJournal.Order.SaleNo__c
        : null;
      String creditReturnSaleNo = creditLedger.TransactionJournal != null &&
        creditLedger.TransactionJournal.SaleId__r != null
        ? creditLedger.TransactionJournal.SaleId__r.SaleNo__c
        : null;

      // [v3 fix 2026-04-24] Flag ON 하에선 재적립 Credit (Point Redeem Cancel) 이 same-sale 에 연결돼 있어도
      //   실제 사용 가능한 별도 Credit 이므로 same-sale 필터로 배제하지 않음.
      Boolean v3SkipSameSaleFilter = (creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL &&
      GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'));
      if (!v3SkipSameSaleFilter && !String.isBlank(currentSaleNo) && (currentSaleNo == creditSaleNo || currentSaleNo == creditReturnSaleNo)) {
        continue;
      }

      if (
        cutoff != null &&
        compareSaleSequence(
          creditLedger.ActivityDate,
          creditLedger.TransactionJournal == null ? null : creditLedger.TransactionJournal.CreatedDate,
          creditLedger.TransactionJournal == null ? null : creditLedger.TransactionJournal.Id,
          cutoff.activityDate,
          cutoff.createdDate,
          cutoff.journalId
        ) > 0
      ) {
        continue;
      }

      filteredCreditLedgerList.add(creditLedger);
      creditLedgerIdSet.add(creditLedger.Id);
      if (creditLedger.LoyaltyPgmCrcySubtypeId != null) {
        subtypeIdSet.add(creditLedger.LoyaltyPgmCrcySubtypeId);
      }
      if (creditLedger.ExpiryDate != null) {
        expiryDateSet.add(creditLedger.ExpiryDate);
      }
    }

    if (filteredCreditLedgerList.isEmpty()) {
      return new List<AvailableCreditBalance>();
    }

    Map<Id, Integer> reductionPointMap = new Map<Id, Integer>();
    Map<Id, Integer> traceCreditCancellationPointMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId, ActionType actionType, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :creditLedgerIdSet
        AND ActionType IN (
          'Debit',
          'DebitCancellation',
          'CreditCancellation'
          // [Time-Symmetric + Effective Date Hierarchy] 컷오프 시점 이후의 차감(미래 반품/취소) 은 시뮬레이션에서 제외.
          //   Debit LL 측 TJ 의 AdditionalNotes 가 RESTORE_NOTES 이면 CreatedDate, 아니면 Sale/Order/ActivityDate hierarchy.
        )
        AND (DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = NULL)
        AND (DebitLoyaltyLedger.TransactionJournal.OrderId = NULL
        OR DebitLoyaltyLedger.TransactionJournal.Order.IsDeleted__c = FALSE
        OR DebitLoyaltyLedger.TransactionJournal.Order.IsDeleted__c = NULL)
        AND (DebitLoyaltyLedger.TransactionJournal.SaleId__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = FALSE
        OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = NULL)
        AND ((DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c IN :RESTORE_NOTES
        AND DebitLoyaltyLedger.CreatedDate <= :effectiveCutoff)
        OR ((DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
        AND ((DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate != NULL
        AND DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate <= :queryDate)
        OR (DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate = NULL
        AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate != NULL
        AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate <= :queryDate)
        OR (DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate = NULL
        AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate = NULL
        AND DebitLoyaltyLedger.TransactionJournal.ActivityDate <= :effectiveCutoff))))
      GROUP BY CreditLoyaltyLedgerId, ActionType
    ]) {
      Id creditLedgerId = (Id) ar.get('creditLedgerId');
      String actionType = (String) ar.get('actionType');
      Integer amount = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();

      if (!reductionPointMap.containsKey(creditLedgerId)) {
        reductionPointMap.put(creditLedgerId, 0);
      }

      if (actionType == 'DebitCancellation') {
        reductionPointMap.put(creditLedgerId, Math.max(0, reductionPointMap.get(creditLedgerId) - amount));
      } else {
        reductionPointMap.put(creditLedgerId, reductionPointMap.get(creditLedgerId) + amount);
        if (actionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION) {
          traceCreditCancellationPointMap.put(creditLedgerId, amount);
        }
      }
    }

    Map<String, Integer> expiredPointByKey = new Map<String, Integer>();
    if (!subtypeIdSet.isEmpty() && !expiryDateSet.isEmpty()) {
      for (AggregateResult ar : [
        SELECT LoyaltyPgmCrcySubtypeId subtypeId, ExpiryDate expiryDate, SUM(Points) totalPoints
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Expiry'
          AND LoyaltyPgmCrcySubtypeId IN :subtypeIdSet
          AND ExpiryDate IN :expiryDateSet
          // [Time-Symmetric Fix 2026-04-27] 컷오프 시점 이후의 소멸(미래 만료) 은 시뮬레이션에서 제외
          AND ActivityDate <= :effectiveCutoff
        GROUP BY LoyaltyPgmCrcySubtypeId, ExpiryDate
      ]) {
        String expiredKey = String.valueOf((Id) ar.get('subtypeId')) + '|' + String.valueOf((Date) ar.get('expiryDate'));
        expiredPointByKey.put(expiredKey, ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue());
      }
    }

    Map<String, Integer> accrualReversalPointByKey = new Map<String, Integer>();
    Map<Id, Integer> accrualReversalPointBySubtypeId = new Map<Id, Integer>();
    Set<Id> tracedAccrualReversalDebitLedgerIdSet = new Set<Id>();
    if (!subtypeIdSet.isEmpty()) {
      for (LoyaltyLedgerTraceability llt : [
        SELECT DebitLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
          AND DebitLoyaltyLedgerId != NULL
          AND DebitLoyaltyLedger.EventType = 'Debit'
          AND DebitLoyaltyLedger.TransactionJournal.JournalType.Name = :JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
          AND DebitLoyaltyLedger.LoyaltyPgmCrcySubtypeId IN :subtypeIdSet
          AND (DebitLoyaltyLedger.ExpiryDate IN :expiryDateSet
          OR DebitLoyaltyLedger.ExpiryDate = NULL)
          AND ((DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c IN :RESTORE_NOTES
          AND DebitLoyaltyLedger.CreatedDate <= :effectiveCutoff)
          OR ((DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
          AND ((DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate != NULL
          AND DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate <= :queryDate)
          OR (DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate != NULL
          AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate <= :queryDate)
          OR (DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate = NULL
          AND DebitLoyaltyLedger.TransactionJournal.ActivityDate <= :effectiveCutoff))))
      ]) {
        tracedAccrualReversalDebitLedgerIdSet.add(llt.DebitLoyaltyLedgerId);
      }

      for (AggregateResult ar : [
        SELECT LoyaltyPgmCrcySubtypeId subtypeId, ExpiryDate expiryDate, SUM(Points) totalPoints
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Debit'
          AND TransactionJournal.JournalType.Name = :JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL
          AND LoyaltyPgmCrcySubtypeId IN :subtypeIdSet
          AND Id NOT IN :tracedAccrualReversalDebitLedgerIdSet
          AND (TransactionJournal.OrderId = NULL
          OR TransactionJournal.Order.IsDeleted__c = FALSE
          OR TransactionJournal.Order.IsDeleted__c = NULL)
          AND (TransactionJournal.SaleId__c = NULL
          OR TransactionJournal.SaleId__r.IsDeleted__c = FALSE
          OR TransactionJournal.SaleId__r.IsDeleted__c = NULL)
          // [Time-Symmetric + Effective Date Hierarchy] 컷오프 시점 이후의 적립취소(미래 반품) 는 시뮬레이션에서 제외.
          //   AdditionalNotes 가 RESTORE_NOTES 이면 CreatedDate, 아니면 Sale/Order/ActivityDate hierarchy.
          AND ((TransactionJournal.AdditionalNotes__c IN :RESTORE_NOTES
          AND CreatedDate <= :effectiveCutoff)
          OR ((TransactionJournal.AdditionalNotes__c = NULL
          OR TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
          AND ((TransactionJournal.SaleId__r.EffectiveDate != NULL
          AND TransactionJournal.SaleId__r.EffectiveDate <= :queryDate)
          OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND TransactionJournal.Order.EffectiveDate != NULL
          AND TransactionJournal.Order.EffectiveDate <= :queryDate)
          OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND TransactionJournal.Order.EffectiveDate = NULL
          AND TransactionJournal.ActivityDate <= :effectiveCutoff))))
        GROUP BY LoyaltyPgmCrcySubtypeId, ExpiryDate
      ]) {
        Id subtypeId = (Id) ar.get('subtypeId');
        Date reversalExpiryDate = (Date) ar.get('expiryDate');
        Integer totalPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();

        if (reversalExpiryDate == null) {
          if (!accrualReversalPointBySubtypeId.containsKey(subtypeId)) {
            accrualReversalPointBySubtypeId.put(subtypeId, 0);
          }
          accrualReversalPointBySubtypeId.put(subtypeId, accrualReversalPointBySubtypeId.get(subtypeId) + totalPoints);
        } else {
          String reversalKey = String.valueOf(subtypeId) + '|' + String.valueOf(reversalExpiryDate);
          if (!accrualReversalPointByKey.containsKey(reversalKey)) {
            accrualReversalPointByKey.put(reversalKey, 0);
          }
          accrualReversalPointByKey.put(reversalKey, accrualReversalPointByKey.get(reversalKey) + totalPoints);
        }
      }
    }

    List<AvailableCreditBalance> result = new List<AvailableCreditBalance>();
    Set<Id> includedCreditLedgerIdSet = new Set<Id>();
    for (LoyaltyLedger creditLedger : filteredCreditLedgerList) {
      Integer credited = creditLedger.Points == null ? 0 : creditLedger.Points.intValue();
      Integer reduced = reductionPointMap.containsKey(creditLedger.Id) ? reductionPointMap.get(creditLedger.Id) : 0;
      Integer remaining = Math.max(0, credited - reduced);

      String expiredKey = String.valueOf(creditLedger.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(creditLedger.ExpiryDate);
      Integer allocatableExpired = expiredPointByKey.containsKey(expiredKey) ? expiredPointByKey.get(expiredKey) : 0;
      Integer expired = Math.min(remaining, allocatableExpired);
      remaining = Math.max(0, remaining - expired);
      if (expired > 0) {
        expiredPointByKey.put(expiredKey, Math.max(0, allocatableExpired - expired));
      }

      String reversalKey = String.valueOf(creditLedger.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(creditLedger.ExpiryDate);
      Integer allocatableReversal = accrualReversalPointByKey.containsKey(reversalKey) ? accrualReversalPointByKey.get(reversalKey) : 0;
      Integer reversal = Math.min(remaining, allocatableReversal);
      remaining = Math.max(0, remaining - reversal);
      if (reversal > 0) {
        accrualReversalPointByKey.put(reversalKey, Math.max(0, allocatableReversal - reversal));
      }

      if (remaining > 0 && accrualReversalPointBySubtypeId.containsKey(creditLedger.LoyaltyPgmCrcySubtypeId)) {
        Integer allocatableSubtypeReversal = accrualReversalPointBySubtypeId.get(creditLedger.LoyaltyPgmCrcySubtypeId);
        Integer subtypeReversal = Math.min(remaining, allocatableSubtypeReversal);
        remaining = Math.max(0, remaining - subtypeReversal);
        if (subtypeReversal > 0) {
          accrualReversalPointBySubtypeId.put(creditLedger.LoyaltyPgmCrcySubtypeId, Math.max(0, allocatableSubtypeReversal - subtypeReversal));
        }
      }

      if (remaining <= 0 || creditLedger.LoyaltyPgmCrcySubtype == null) {
        continue;
      }

      Id originCreditLedgerId = extractOriginCreditLedgerId(creditLedger.AdditionalNotes);
      if (originCreditLedgerId != null) {
        OriginRestoreCreditState originState = originRestoreCreditStateByOriginId.get(originCreditLedgerId);
        if (originState == null || originState.isInvalid == true || originState.remainingCap == null || originState.remainingCap <= 0) {
          continue;
        }
        remaining = Math.min(remaining, originState.remainingCap);
        originState.remainingCap = Math.max(0, originState.remainingCap - remaining);
        if (remaining <= 0) {
          continue;
        }
      }

      includedCreditLedgerIdSet.add(creditLedger.Id);
      result.add(
        new AvailableCreditBalance(
          creditLedger.Id,
          creditLedger.LoyaltyPgmCrcySubtypeId,
          creditLedger.LoyaltyPgmCrcySubtype.Name,
          creditLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c,
          creditLedger.ExpiryDate,
          remaining
        )
      );
    }

    // [Backdate Dual-Visibility] 그 일자에 새로 등록된 backdate Credit LL 추가 가산.
    //   예) 5/5에 적립일자=5/1 backdate 개별 지급 50P → 5/1 조회와 5/5 조회 양쪽 모두에서 +가산.
    //   조건: CreatedDate 가 queryDate 당일이고, hierarchy effective_date 가 queryDate 시작 이전 (backdate).
    if (queryDate != null && queryDate.year() < 9999) {
      Datetime startOfNextDay = startOfQueryDate.addDays(1);
      List<LoyaltyLedger> backdatedCreditLedgers = [
        SELECT
          Id,
          Points,
          ExpiryDate,
          AdditionalNotes,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          TransactionJournal.AdditionalNotes__c,
          TransactionJournal.IsDeleted__c,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.Order.IsDeleted__c,
          TransactionJournal.SaleId__r.SaleNo__c,
          TransactionJournal.SaleId__r.IsDeleted__c
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :memberId
          AND EventType = 'Credit'
          AND Points > 0
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
          AND (TransactionJournal.IsDeleted__c = FALSE
          OR TransactionJournal.IsDeleted__c = NULL)
          AND (TransactionJournal.OrderId = NULL
          OR TransactionJournal.Order.IsDeleted__c = FALSE
          OR TransactionJournal.Order.IsDeleted__c = NULL)
          AND (TransactionJournal.SaleId__c = NULL
          OR TransactionJournal.SaleId__r.IsDeleted__c = FALSE
          OR TransactionJournal.SaleId__r.IsDeleted__c = NULL)
          AND CreatedDate >= :startOfQueryDate
          AND CreatedDate < :startOfNextDay
          AND (TransactionJournal.AdditionalNotes__c = NULL
          OR TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
          // backdate 식별: hierarchy 효력일이 queryDate 시작 이전
          AND ((TransactionJournal.SaleId__r.EffectiveDate != NULL
          AND TransactionJournal.SaleId__r.EffectiveDate < :queryDate)
          OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND TransactionJournal.Order.EffectiveDate != NULL
          AND TransactionJournal.Order.EffectiveDate < :queryDate)
          OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
          AND TransactionJournal.Order.EffectiveDate = NULL
          AND TransactionJournal.ActivityDate < :startOfQueryDate))
        LIMIT 50000
      ];

      Set<Id> backdatedForceCreditReturnOrderIdSet = new Set<Id>();
      for (LoyaltyLedger backdatedLL : backdatedCreditLedgers) {
        String notes = backdatedLL.TransactionJournal == null ? null : backdatedLL.TransactionJournal.AdditionalNotes__c;
        if (isOptionCReturnDepositDeleteForceCredit(notes)) {
          Id returnOrderId = parseOptionCReturnOrderId(notes);
          if (returnOrderId != null) {
            backdatedForceCreditReturnOrderIdSet.add(returnOrderId);
          }
        }
      }
      Map<Id, Date> backdatedForceCreditReturnEffectiveDateMap = loadOrderEffectiveDateMap(backdatedForceCreditReturnOrderIdSet);
      Map<Id, LoyaltyLedger> backdatedOriginCreditLedgerMap = loadOriginCreditLedgersForPointHelp(backdatedCreditLedgers);
      Map<Id, OriginRestoreCreditState> backdatedOriginRestoreCreditStateByOriginId = buildOriginRestoreCreditStateMap(backdatedCreditLedgers);
      for (Id originCreditLedgerId : originRestoreCreditStateByOriginId.keySet()) {
        backdatedOriginRestoreCreditStateByOriginId.put(originCreditLedgerId, originRestoreCreditStateByOriginId.get(originCreditLedgerId));
      }

      Set<Id> backdatedCreditLedgerIdSet = new Set<Id>();
      for (LoyaltyLedger backdatedLL : backdatedCreditLedgers) {
        if (creditLedgerIdSet.contains(backdatedLL.Id) || includedCreditLedgerIdSet.contains(backdatedLL.Id)) {
          continue;
        }
        backdatedCreditLedgerIdSet.add(backdatedLL.Id);
      }

      Map<Id, Integer> backdatedReductionPointMap = new Map<Id, Integer>();
      if (!backdatedCreditLedgerIdSet.isEmpty()) {
        for (AggregateResult ar : [
          SELECT CreditLoyaltyLedgerId creditLedgerId, ActionType actionType, SUM(Points) totalPoints
          FROM LoyaltyLedgerTraceability
          WHERE
            LoyaltyProgramMemberId = :memberId
            AND CreditLoyaltyLedgerId IN :backdatedCreditLedgerIdSet
            AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
            AND (DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
            OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = NULL)
            AND (DebitLoyaltyLedger.TransactionJournal.OrderId = NULL
            OR DebitLoyaltyLedger.TransactionJournal.Order.IsDeleted__c = FALSE
            OR DebitLoyaltyLedger.TransactionJournal.Order.IsDeleted__c = NULL)
            AND (DebitLoyaltyLedger.TransactionJournal.SaleId__c = NULL
            OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = FALSE
            OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = NULL)
            AND ((DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c IN :RESTORE_NOTES
            AND DebitLoyaltyLedger.CreatedDate <= :effectiveCutoff)
            OR ((DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
            OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
            AND ((DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate != NULL
            AND DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate <= :queryDate)
            OR (DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate = NULL
            AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate != NULL
            AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate <= :queryDate)
            OR (DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate = NULL
            AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate = NULL
            AND DebitLoyaltyLedger.TransactionJournal.ActivityDate <= :effectiveCutoff))))
          GROUP BY CreditLoyaltyLedgerId, ActionType
        ]) {
          Id creditLedgerId = (Id) ar.get('creditLedgerId');
          String actionType = (String) ar.get('actionType');
          Integer amount = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();

          if (!backdatedReductionPointMap.containsKey(creditLedgerId)) {
            backdatedReductionPointMap.put(creditLedgerId, 0);
          }

          if (actionType == 'DebitCancellation') {
            backdatedReductionPointMap.put(creditLedgerId, Math.max(0, backdatedReductionPointMap.get(creditLedgerId) - amount));
          } else {
            backdatedReductionPointMap.put(creditLedgerId, backdatedReductionPointMap.get(creditLedgerId) + amount);
          }
        }
      }

      for (LoyaltyLedger backdatedLL : backdatedCreditLedgers) {
        String backdatedNotes = backdatedLL.TransactionJournal == null ? null : backdatedLL.TransactionJournal.AdditionalNotes__c;
        if (shouldExcludeOptionCForceCreditByReturnDate(backdatedNotes, queryDate, backdatedForceCreditReturnEffectiveDateMap)) {
          continue;
        }
        if (!isActivePointHelpTransaction(backdatedLL.TransactionJournal)) {
          continue;
        }
        Id backdatedOriginCreditLedgerId = extractOriginCreditLedgerId(backdatedLL.AdditionalNotes);
        if (isOriginCreditExcludedForPointHelp(backdatedOriginCreditLedgerId, currentSaleNo, backdatedOriginCreditLedgerMap)) {
          continue;
        }
        if (shouldExcludeRestoreCreditByOrigin(backdatedOriginCreditLedgerId, backdatedOriginRestoreCreditStateByOriginId)) {
          continue;
        }
        if (creditLedgerIdSet.contains(backdatedLL.Id)) {
          continue;
        }
        if (includedCreditLedgerIdSet.contains(backdatedLL.Id)) {
          continue;
        }

        // same-sale 필터 (기존 SOQL ① 후처리와 동일 로직)
        String creditSaleNo = (backdatedLL.TransactionJournal != null &&
          backdatedLL.TransactionJournal.Order != null)
          ? backdatedLL.TransactionJournal.Order.SaleNo__c
          : null;
        String creditReturnSaleNo = (backdatedLL.TransactionJournal != null &&
          backdatedLL.TransactionJournal.SaleId__r != null)
          ? backdatedLL.TransactionJournal.SaleId__r.SaleNo__c
          : null;
        if (!String.isBlank(currentSaleNo) && (currentSaleNo == creditSaleNo || currentSaleNo == creditReturnSaleNo)) {
          continue;
        }

        if (backdatedLL.LoyaltyPgmCrcySubtype == null) {
          continue;
        }
        Integer credited = backdatedLL.Points == null ? 0 : backdatedLL.Points.intValue();
        Integer reduced = backdatedReductionPointMap.containsKey(backdatedLL.Id) ? backdatedReductionPointMap.get(backdatedLL.Id) : 0;
        Integer addPoints = Math.max(0, credited - reduced);
        if (addPoints <= 0) {
          continue;
        }
        if (backdatedOriginCreditLedgerId != null) {
          OriginRestoreCreditState backdatedOriginState = backdatedOriginRestoreCreditStateByOriginId.get(backdatedOriginCreditLedgerId);
          if (backdatedOriginState == null ||
              backdatedOriginState.isInvalid == true ||
              backdatedOriginState.remainingCap == null ||
              backdatedOriginState.remainingCap <= 0) {
            continue;
          }
          addPoints = Math.min(addPoints, backdatedOriginState.remainingCap);
          backdatedOriginState.remainingCap = Math.max(0, backdatedOriginState.remainingCap - addPoints);
          if (addPoints <= 0) {
            continue;
          }
        }

        // 별도 AvailableCreditBalance 로 추가 (reduction 계산 우회 — 통째로 +가산)
        includedCreditLedgerIdSet.add(backdatedLL.Id);
        result.add(
          new AvailableCreditBalance(
            backdatedLL.Id,
            backdatedLL.LoyaltyPgmCrcySubtypeId,
            backdatedLL.LoyaltyPgmCrcySubtype.Name,
            backdatedLL.LoyaltyPgmCrcySubtype.PointTypeCode__c,
            backdatedLL.ExpiryDate,
            addPoints
          )
        );
      }
    }

    return result;
  }

  private static String resolveSaleNoForPointUsage(Id orderId) {
    if (orderId == null) {
      return null;
    }

    List<Order> orderList = [SELECT SaleNo__c, OrderNo__c FROM Order WHERE Id = :orderId LIMIT 1];
    if (orderList.isEmpty()) {
      return null;
    }

    return String.isNotBlank(orderList[0].SaleNo__c) ? orderList[0].SaleNo__c : orderList[0].OrderNo__c;
  }

  private static Integer calculatePointUsageAvailableLimit(TransactionJournal tj) {
    if (tj == null || tj.MemberId == null || tj.TransactionAmount == null || tj.TransactionAmount <= 0) {
      return null;
    }

    Date usageDate = tj.ActivityDate == null ? null : tj.ActivityDate.date();
    String saleNo = resolveSaleNoForPointUsage(tj.OrderId);

    if (usageDate == null || usageDate >= Date.today()) {
      return null;
    }

    Datetime nextDayStart = TimeUtil.dateToUtcStartOfDay(usageDate.addDays(1));
    Map<Id, Integer> currentAvailableByCreditLedgerId = new Map<Id, Integer>();
    for (AvailableCreditBalance currentBalance : buildAvailableCreditBalancesForDebitValidation(tj.MemberId, null, null, saleNo)) {
      if (currentBalance.creditLedgerId == null || currentBalance.availablePoints == null || currentBalance.availablePoints <= 0) {
        continue;
      }
      currentAvailableByCreditLedgerId.put(currentBalance.creditLedgerId, currentBalance.availablePoints);
    }

    Integer available = 0;
    for (AvailableCreditBalance historicalBalance : buildAvailableCreditBalancesForDebitValidation(tj.MemberId, null, nextDayStart, saleNo)) {
      if (historicalBalance.creditLedgerId == null || historicalBalance.availablePoints == null || historicalBalance.availablePoints <= 0) {
        continue;
      }
      Integer currentAvailable = currentAvailableByCreditLedgerId.containsKey(historicalBalance.creditLedgerId)
        ? currentAvailableByCreditLedgerId.get(historicalBalance.creditLedgerId)
        : 0;
      if (currentAvailable > 0) {
        available += Math.min(historicalBalance.availablePoints, currentAvailable);
      }
    }
    return available;
  }

  private static List<AvailableCreditBalance> buildAvailableCreditBalancesForDebitValidation(
    Id memberId,
    SaleSequenceCutoff cutoff,
    Datetime nextDayStart,
    String currentSaleNo
  ) {
    return buildAvailableCreditBalancesForHelp(memberId, cutoff, nextDayStart, currentSaleNo);
  }

  /**
   * 포인트 지급
   */
  public ApiResult creditPoint(Map<String, Object> reqData) {
    Map<String, Object> result = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, '요청 body가 비었습니다.');
    }

    try {
      List<Object> pointsList = ValidationUtil.listObjValidation(reqData.get('PointsList'), 'PointsList', true); // 포인트 목록
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', false); // 판매 번호
      Date endDate = ValidationUtil.dateValidation(reqData.get('EndDate'), 'EndDate', false); // 판매 일자

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo AND MemberStatus != 'Inactive'
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원 찾을 수 없습니다. ' + memberNo);
      }

      Id saleId = null;
      Id promotionId = null;
      if (String.isNotBlank(saleNo)) {
        List<Order> saleList = [SELECT Id FROM Order WHERE SaleNo__c = :saleNo LIMIT 1];
        if (saleList.isEmpty()) {
          throw new CustomException(400, '해당 판매 건을 찾을 수 없습니다. ' + saleNo);
        }
        saleId = saleList[0].Id;
        List<TransactionJournal> sourceTjList = [
          SELECT Id, PromotionId
          FROM TransactionJournal
          WHERE
            (OrderId = :saleId
            OR SaleId__c = :saleId)
            AND PromotionId != NULL
            AND IsDeleted__c = FALSE
            AND (JournalSubType.Name = NULL
            OR JournalSubType.Name NOT IN (
              'Cancel Purchase Accrual',
              'Point Redeem Cancel',
              'Coupon Redeem Cancel',
              'Order Deposit Reversal',
              'Sale Deposit Reversal'
            ))
          ORDER BY CreatedDate DESC
          LIMIT 1
        ];
        if (!sourceTjList.isEmpty()) {
          promotionId = sourceTjList[0].PromotionId;
        }
      }

      Map<String, Decimal> pointByTypeMap = new Map<String, Decimal>();
      Decimal totalPoints = 0;
      for (Object v : pointsList) {
        Map<String, Object> vMap = ValidationUtil.mapStrObjValidation(v, 'PointsList', true);
        Decimal point = ValidationUtil.decimalValidation(vMap.get('point'), 'point', true); // 포인트 금액
        String cd_type_point = ValidationUtil.stringValidationEx(vMap.get('cd_type_point'), 'cd_type_point', true, false); // 포인트 구분

        totalPoints += point;

        if (pointByTypeMap.containsKey(cd_type_point)) {
          pointByTypeMap.put(cd_type_point, pointByTypeMap.get(cd_type_point) + point);
        } else {
          pointByTypeMap.put(cd_type_point, point);
        }
      }

      if (totalPoints <= 0) {
        throw new CustomException(400, '지급할 포인트가 0 이하입니다.');
      }

      Date expirationDate = null;

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
      tj.MemberId = lpmList[0].Id; // 적립 대상 멤버 Id
      if (endDate != null) {
        tj.JournalDate = TimeUtil.dateToUtcStartOfDay(endDate); // 거래 일자
        tj.ActivityDate = TimeUtil.dateToUtcStartOfDay(endDate); // 활동 일자

        expirationDate = endDate.addYears(2);
      } else {
        tj.JournalDate = Datetime.now(); // 거래 일자
        tj.ActivityDate = Datetime.now(); // 활동 일자
      }
      tj.TransactionAmount = totalPoints; // 지급 포인트
      tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
      tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT, true);
      if (saleId != null) {
        tj.OrderId = saleId;
        tj.SaleId__c = saleId;
      }
      if (promotionId != null) {
        tj.PromotionId = promotionId;
      }

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (String cdTypePoint : pointByTypeMap.keySet()) {
        List<LoyaltyPgmCurrencySubtype> lpcsList = [
          SELECT Id, Name
          FROM LoyaltyPgmCurrencySubtype
          WHERE PointTypeCode__c = :cdTypePoint
          LIMIT 1
        ];
        if (lpcsList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 포인트 구분 값 입니다. ' + cdTypePoint);
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', lpmList[0].Id);
        req.put('journalId', tj.Id);
        if ('05'.equals(cdTypePoint)) {
          req.put('loyaltyProgramCurrencySubtypeName', '에코포인트');
          req.put('additionalNotes', '이벤트포인트');
        } else {
          req.put('loyaltyProgramCurrencySubtypeName', lpcsList[0].Name);
        }
        req.put('points', pointByTypeMap.get(cdTypePoint));
        if (expirationDate != null) {
          req.put('pointsExpirationDate', String.valueOf(expirationDate));
        }

        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT Id, Points, ExpiryDate, EscrowPointsCreditDate, ActivityDate, CreatedDate, EventType, AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();

      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate.addDays(1)); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        pcDtoList.add(pcDto);
      }

      result.put('PointCreditList', pcDtoList);

      return ApiResult.ok(200, '포인트 지급 성공', result);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 에코 포인트 지급
   */
  public ApiResult creditEcopoint(Map<String, Object> reqData) {
    Map<String, Object> result = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, '요청 body가 비었습니다.');
    }

    try {
      String memberNo = ValidationUtil.stringValidation(reqData.get('MemberNo__c'), 'MemberNo__c', true); // 회원 번호
      Decimal point = ValidationUtil.decimalValidation(reqData.get('point'), 'point', true); // 포인트 금액

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, ProgramId
        FROM LoyaltyProgramMember
        WHERE Contact.MemberNo__c = :memberNo AND MemberStatus != 'Inactive'
        LIMIT 1
      ];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원 찾을 수 없습니다. ' + memberNo);
      }

      if (point <= 0) {
        throw new CustomException(400, '지급할 포인트가 0 이하입니다.');
      }

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
      tj.MemberId = lpmList[0].Id; // 적립 대상 멤버 Id
      tj.JournalDate = Datetime.now(); // 거래 일자
      tj.ActivityDate = Datetime.now(); // 활동 일자
      tj.TransactionAmount = point; // 지급 포인트
      tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
      tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true);

      insert tj;

      List<LoyaltyPgmCurrencySubtype> lpcsList = [
        SELECT Id, Name
        FROM LoyaltyPgmCurrencySubtype
        WHERE Name = :POINT_SUB_TYPE_NAME
        LIMIT 1
      ];
      if (lpcsList.isEmpty()) {
        throw new CustomException(400, POINT_SUB_TYPE_NAME + '가 존재하지 않습니다.');
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Map<String, Object> req = new Map<String, Object>();
      req.put('loyaltyProgramMemberId', lpmList[0].Id);
      req.put('journalId', tj.Id);
      req.put('loyaltyProgramCurrencySubtypeName', '에코포인트');
      req.put('additionalNotes', '이벤트포인트');
      req.put('points', point);

      reqList.add(req);

      LoyaltyPointService.creditPoints(reqList);

      return ApiResult.ok(200, '에코포인트 지급 성공', result);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 사용 x
   * 포인트 수정
   */
  public ApiResult updatePoint(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, '요청 body가 비었습니다.');
    }

    try {
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      String type = ValidationUtil.stringValidationEx(reqData.get('type'), 'type', true, false); // 타입 (01:지급 | 02:차감)
      Decimal point = ValidationUtil.decimalValidation(reqData.get('point'), 'point', true); // 포인트 금액
      String cd_type_point = ValidationUtil.stringValidationEx(reqData.get('cd_type_point'), 'cd_type_point', true, false); // 포인트 구분 (01:구매포인트 | 02:기념일포인트 | 03:승급포인트 | 04:기타포인트 | 05:에코포인트 = 이벤트포인트)
      Date expiryDate = ValidationUtil.dateValidation(reqData.get('ExpiryDate__c'), 'ExpiryDate__c', true); // 소멸예정일

      List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원 찾을 수 없습니다. ' + memberNo);
      }

      if (point <= 0) {
        throw new CustomException(400, '지급할 포인트가 0 이하입니다.');
      }

      if ('01'.equals(type)) {
        // 포인트 지급 로직
        Map<String, Object> creditReqMap = new Map<String, Object>();
        List<Map<String, Object>> pointsList = new List<Map<String, Object>>();
        Map<String, Object> pointMap = new Map<String, Object>();
        creditReqMap.put('MemberNo__c', memberNo);
        pointMap.put('point', point);
        pointMap.put('cd_type_point', cd_type_point);
        pointsList.add(pointMap);
        pointMap.put('PointsList', pointsList);

        return creditPoint(creditReqMap);
      } else if ('02'.equals(type)) {
        // 포인트 차감 로직
        List<LoyaltyAggrSubPointExprLedger__c> laspelList = [
          SELECT Id, AvailablePoints__c, CurrencySubTypeId__r.Name, ExpiryDate__c, CurrencySubTypeId__r.PointTypeCode__c
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE LoyaltyProgramMemberId__c = :lpmList[0].Id AND ExpiryDate__c = :expiryDate AND CurrencySubTypeId__r.PointTypeCode__c = :cd_type_point
          LIMIT 1
        ];
        if (!laspelList.isEmpty()) {
          if (laspelList[0].AvailablePoints__c < point) {
            throw new CustomException(
              400,
              '차감 가능한 포인트가 부족합니다. (종류:' +
                laspelList[0].CurrencySubTypeId__r.Name +
                ' | 만료일자:' +
                laspelList[0].ExpiryDate__c +
                ' | 잔액:' +
                laspelList[0].AvailablePoints__c +
                ')'
            );
          } else {
            // 포인트 차감 로직
            TransactionJournal tj = new TransactionJournal();

            tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
            tj.MemberId = lpmList[0].Id; // 대상 멤버 Id
            tj.JournalDate = Datetime.now(); // 거래 일자
            tj.ActivityDate = Datetime.now(); // 활동 일자
            tj.TransactionAmount = point; // 삭제(소멸) 포인트
            tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
            tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT, true);
            tj.JournalReason__c = '2';

            insert tj;

            List<Map<String, Object>> pointDeleteReqList = new List<Map<String, Object>>();

            // 포인트 차감을 위한 값 설정
            Map<String, Object> pointDeleteReq = new Map<String, Object>();
            pointDeleteReq.put('loyaltyProgramMemberId', lpmList[0].Id);
            pointDeleteReq.put('journalId', tj.Id);
            pointDeleteReq.put('loyaltyProgramCurrencySubtypeName', laspelList[0].CurrencySubTypeId__r.Name);
            pointDeleteReq.put('additionalNotes', '포인트 개별 수정 API를 통한 포인트 차감 처리');
            pointDeleteReq.put('points', point);

            pointDeleteReqList.add(pointDeleteReq);

            // 포인트 사용 처리
            LoyaltyPointService.debitPoints(pointDeleteReqList);

            // 포인트 사용 추적 조회
            List<LoyaltyLedgerTraceability> lltList = [
              SELECT
                LoyaltyPgmCurrencySubtype.Name,
                Points,
                CreditLoyaltyLedger.ExpiryDate,
                LoyaltyProgramMember.Contact.MemberNo__c,
                LastModifiedDate,
                DebitLoyaltyLedgerId,
                LoyaltyPgmCurrencySubtype.PointTypeCode__c
              FROM LoyaltyLedgerTraceability
              WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
              LIMIT 100
            ];
            if (lltList.isEmpty()) {
              throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
            }

            List<PointDebitDTO> pcDtoList = new List<PointDebitDTO>();
            for (LoyaltyLedgerTraceability llt : lltList) {
              PointDebitDTO pcDto = new PointDebitDTO();
              pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId; // 로열티 소멸 키값
              pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c; // 포인트 구분
              pcDto.CD_RESON = tj.JournalReason__c; // 회원 포인트 소진 구분
              pcDto.NO_MBR = memberNo; // 회원 번호
              pcDto.PT_USE = llt.Points; // 소멸된 금액
              pcDto.DTS_INSERT = String.valueOf(tj.CreatedDate); // 등록 일자

              pcDtoList.add(pcDto);
            }
            data.put('PointDeleteList', pcDtoList);
          }
        } else {
          throw new CustomException(400, '차감 가능한 포인트 잔액 정보가 없습니다.');
        }
      } else {
        throw new CustomException(400, 'type 값이 올바르지 않습니다. (01:지급 | 02:차감)');
      }

      return ApiResult.ok(200, '포인트 수정 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 보류
   * 포인트 조회
   */
  public Double getPointList(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);

      return results[0].getPoints();
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * [주문,판매] 포인트 적용 도움창 조회
   * @version V1
   */
  public ApiResult getPointApplyHelp(Map<String, Object> reqData) {
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String storeCode = ValidationUtil.stringValidation(reqData.get('StoreCode__c'), 'StoreCode__c', false); // 매장 코드
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      String type = ValidationUtil.stringValidation(reqData.get('Type'), 'Type', false); // 주문 구분 코드
      String promotionNo = ValidationUtil.stringValidation(reqData.get('PromotionNo__c'), 'PromotionNo__c', false); // 프로모션 번호
      // String orderDate = ValidationUtil.stringValidation(reqData.get('OrderDate'), 'OrderDate', false); // 주문/판매 일자

      if (String.isNotBlank(promotionNo)) {
        List<Promotion> pList = [SELECT Id, IsPointUsageAllowed__c FROM Promotion WHERE PromotionNo__c = :promotionNo LIMIT 1];
        if (pList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 프로모션입니다. ' + promotionNo);
        } else {
          if (!pList[0].IsPointUsageAllowed__c) {
            throw new CustomException(400, '해당 프로모션은 포인트 사용 불가합니다. ' + promotionNo);
          }
        }
      }

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      if (storeCode != null) {
        List<Account> aList = [SELECT Id, StoreTypeFour__c FROM Account WHERE StoreCode__c = :storeCode LIMIT 1];
        if (aList.isEmpty()) {
          throw new CustomException(400, '존재하지 않는 매장입니다. ' + storeCode);
        }

        // '01' => 백화점 | '05' => 아울렛 | '20' => 예술의전당
        if ('01'.equals(aList[0].StoreTypeFour__c) || '05'.equals(aList[0].StoreTypeFour__c) || '20'.equals(aList[0].StoreTypeFour__c)) {
          // '05' => 아울렛
          if ('05'.equals(aList[0].StoreTypeFour__c)) {
            if (String.isNotBlank(type)) {
              // '03' => 수선 : 아울렛에서 수선 건에 한해 포인트 사용 가능
              if ('03'.equals(type)) {
                // List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);
                // return results[0].getPoints();
                return getPointApplyHelpV2(reqData);
              }
            }
          } else {
            // List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);
            // return results[0].getPoints();
            return getPointApplyHelpV2(reqData);
          }
        }
      }
      // else {
      // List<LoyaltyManagement.MemberPointBalanceOutput> results = LoyaltyPointService.getPointsBalance(lpmList[0].Id);
      // return results[0].getPoints();
      return getPointApplyHelpV2(reqData);
      // }

      // return 0;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * [주문,판매] 포인트 적용 도움창 조회
   * @version V2
   */
  public ApiResult getPointApplyHelpV2(Map<String, Object> reqData) {
    Boolean useSaleSequenceWrapper = true;
    if (useSaleSequenceWrapper) {
      // Legacy V2 body is intentionally left below for quick rollback/reference.
      return getPointApplyHelpBySaleSequence(reqData);
    }
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호

      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      List<PointResDto.AvailablePointResponse> pointList = new List<PointResDto.AvailablePointResponse>();
      Object rawOrderDate = reqData.get('orderDate');
      if (rawOrderDate == null) {
        rawOrderDate = reqData.get('OrderDate');
      }
      Object rawSaleNo = reqData.get('SaleNo__c');
      if (rawSaleNo == null) {
        rawSaleNo = reqData.get('saleNo');
      }
      if (rawSaleNo == null) {
        rawSaleNo = reqData.get('SaleNo');
      }
      String saleNo = rawSaleNo == null ? null : ValidationUtil.stringValidation(rawSaleNo, 'SaleNo__c', false);
      Date normalizedOrderDate = rawOrderDate == null ? null : ValidationUtil.dateValidation(rawOrderDate, 'OrderDate', false);
      // Object rawOrderDate = reqData.get('OrderDate');
      // if (rawOrderDate == null) {
      // rawOrderDate = reqData.get('OrderDate');
      // }
      Date orderDate = ValidationUtil.dateValidation(reqData.get('OrderDate'), 'OrderDate', false); // 주문/판매 일자

      if (orderDate == null && normalizedOrderDate != null) {
        orderDate = normalizedOrderDate;
      }

      if (orderDate == null) {
        List<AggregateResult> arList = [
          SELECT sum(AvailablePoints__c) totalPoints, CurrencySubTypeId__r.PointTypeCode__c pointTypeCode
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE
            AvailablePoints__c > 0
            AND ExpiryDate__c >= :Date.today()
            AND LoyaltyProgramMemberId__c = :lpmList[0].Id
            AND CurrencySubTypeId__r.PointTypeCode__c != NULL
          GROUP BY CurrencySubTypeId__r.PointTypeCode__c
        ];

        for (AggregateResult ar : arList) {
          PointResDto.AvailablePointResponse item = new PointResDto.AvailablePointResponse(ar);
          pointList.add(item);
        }
      } else {
        Datetime nextDayStart = TimeUtil.dateToUtcStartOfDay(orderDate.addDays(1));
        List<LoyaltyLedger> creditLedgerList = [
          SELECT
            Id,
            Points,
            ExpiryDate,
            AdditionalNotes,
            LoyaltyPgmCrcySubtypeId,
            LoyaltyPgmCrcySubtype.PointTypeCode__c,
            TransactionJournal.JournalType.Name,
            TransactionJournal.JournalSubType.Name,
            TransactionJournal.AdditionalNotes__c,
            TransactionJournal.RelatedJournalId,
            TransactionJournal.RelatedJournal.JournalType.Name,
            TransactionJournal.Order.SaleNo__c,
            TransactionJournal.SaleId__r.SaleNo__c
          FROM LoyaltyLedger
          WHERE
            LoyaltyProgramMemberId = :lpmList[0].Id
            AND EventType = 'Credit'
            AND Points > 0
            AND ActivityDate < :nextDayStart
            AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
          ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
          LIMIT 50000
        ];

        if (!creditLedgerList.isEmpty()) {
          List<LoyaltyLedger> filteredCreditLedgerList = new List<LoyaltyLedger>();
          Set<Id> creditLedgerIdSet = new Set<Id>();
          Set<Id> subtypeIdSet = new Set<Id>();
          Set<Date> expiryDateSet = new Set<Date>();

          for (LoyaltyLedger creditLedger : creditLedgerList) {
            String creditJournalTypeName = creditLedger.TransactionJournal != null &&
              creditLedger.TransactionJournal.JournalType != null
              ? creditLedger.TransactionJournal.JournalType.Name
              : null;
            String creditJournalSubTypeName = creditLedger.TransactionJournal != null &&
              creditLedger.TransactionJournal.JournalSubType != null
              ? creditLedger.TransactionJournal.JournalSubType.Name
              : null;
            String creditJournalAdditionalNotes = creditLedger.TransactionJournal != null ? creditLedger.TransactionJournal.AdditionalNotes__c : null;
            String relatedJournalTypeName = creditLedger.TransactionJournal != null &&
              creditLedger.TransactionJournal.RelatedJournal != null &&
              creditLedger.TransactionJournal.RelatedJournal.JournalType != null
              ? creditLedger.TransactionJournal.RelatedJournal.JournalType.Name
              : null;
            if (
              creditLedger.AdditionalNotes == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE ||
              creditLedger.AdditionalNotes == ECO_POINT_RESTORE_NOTE ||
              creditJournalAdditionalNotes == 'Restore purchase accrual due to return deletion' ||
              creditJournalAdditionalNotes == 'Restore promotion point accrual due to return deletion' ||
              creditJournalAdditionalNotes == RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE ||
              creditJournalAdditionalNotes == ECO_POINT_RESTORE_NOTE
            ) {
              continue;
            }
            if (
              creditJournalTypeName == JOURNAL_TYPE_NAME_ACCRUAL &&
              creditLedger.TransactionJournal != null &&
              creditLedger.TransactionJournal.RelatedJournalId != null &&
              relatedJournalTypeName == 'Accrual Reversal'
            ) {
              continue;
            }
            if (
              creditJournalTypeName == JOURNAL_TYPE_NAME_DEPOSIT_REVERSAL &&
              (creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_ORDER_DEPOSIT_REVERSAL ||
              creditJournalSubTypeName == JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL)
            ) {
              continue;
            }

            String creditSaleNo = creditLedger.TransactionJournal != null &&
              creditLedger.TransactionJournal.Order != null
              ? creditLedger.TransactionJournal.Order.SaleNo__c
              : null;
            String creditReturnSaleNo = creditLedger.TransactionJournal != null &&
              creditLedger.TransactionJournal.SaleId__r != null
              ? creditLedger.TransactionJournal.SaleId__r.SaleNo__c
              : null;

            if (!String.isBlank(saleNo) && (saleNo == creditSaleNo || saleNo == creditReturnSaleNo)) {
              continue;
            }

            filteredCreditLedgerList.add(creditLedger);
            creditLedgerIdSet.add(creditLedger.Id);
            if (creditLedger.LoyaltyPgmCrcySubtypeId != null) {
              subtypeIdSet.add(creditLedger.LoyaltyPgmCrcySubtypeId);
            }
            if (creditLedger.ExpiryDate != null) {
              expiryDateSet.add(creditLedger.ExpiryDate);
            }
          }

          Map<Id, Integer> reductionPointMap = new Map<Id, Integer>();
          Map<Id, Integer> traceCreditCancellationPointMap = new Map<Id, Integer>();
          if (!creditLedgerIdSet.isEmpty()) {
            for (AggregateResult ar : [
              SELECT CreditLoyaltyLedgerId creditLedgerId, ActionType actionType, SUM(Points) totalPoints
              FROM LoyaltyLedgerTraceability
              WHERE
                LoyaltyProgramMemberId = :lpmList[0].Id
                AND CreditLoyaltyLedgerId IN :creditLedgerIdSet
                AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
              GROUP BY CreditLoyaltyLedgerId, ActionType
            ]) {
              Id creditLedgerId = (Id) ar.get('creditLedgerId');
              String actionType = (String) ar.get('actionType');
              Integer amount = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();

              if (!reductionPointMap.containsKey(creditLedgerId)) {
                reductionPointMap.put(creditLedgerId, 0);
              }

              if (actionType == 'DebitCancellation') {
                reductionPointMap.put(creditLedgerId, Math.max(0, reductionPointMap.get(creditLedgerId) - amount));
              } else {
                reductionPointMap.put(creditLedgerId, reductionPointMap.get(creditLedgerId) + amount);
                if (actionType == 'CreditCancellation') {
                  traceCreditCancellationPointMap.put(creditLedgerId, amount);
                }
              }
            }
          }

          Map<String, Integer> expiredPointByKey = new Map<String, Integer>();
          if (!subtypeIdSet.isEmpty() && !expiryDateSet.isEmpty()) {
            for (AggregateResult ar : [
              SELECT LoyaltyPgmCrcySubtypeId subtypeId, ExpiryDate expiryDate, SUM(Points) totalPoints
              FROM LoyaltyLedger
              WHERE
                LoyaltyProgramMemberId = :lpmList[0].Id
                AND EventType = 'Expiry'
                AND LoyaltyPgmCrcySubtypeId IN :subtypeIdSet
                AND ExpiryDate IN :expiryDateSet
              GROUP BY LoyaltyPgmCrcySubtypeId, ExpiryDate
            ]) {
              String expiredKey = String.valueOf((Id) ar.get('subtypeId')) + '|' + String.valueOf((Date) ar.get('expiryDate'));
              expiredPointByKey.put(expiredKey, ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue());
            }
          }

          Map<String, Integer> accrualReversalPointByKey = new Map<String, Integer>();
          Map<Id, Integer> accrualReversalPointBySubtypeId = new Map<Id, Integer>();
          if (!subtypeIdSet.isEmpty()) {
            for (AggregateResult ar : [
              SELECT LoyaltyPgmCrcySubtypeId subtypeId, ExpiryDate expiryDate, SUM(Points) totalPoints
              FROM LoyaltyLedger
              WHERE
                LoyaltyProgramMemberId = :lpmList[0].Id
                AND EventType = 'Debit'
                AND TransactionJournal.JournalType.Name = 'Accrual Reversal'
                AND LoyaltyPgmCrcySubtypeId IN :subtypeIdSet
              GROUP BY LoyaltyPgmCrcySubtypeId, ExpiryDate
            ]) {
              Id subtypeId = (Id) ar.get('subtypeId');
              Date reversalExpiryDate = (Date) ar.get('expiryDate');
              Integer totalPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();

              if (reversalExpiryDate == null) {
                if (!accrualReversalPointBySubtypeId.containsKey(subtypeId)) {
                  accrualReversalPointBySubtypeId.put(subtypeId, 0);
                }
                accrualReversalPointBySubtypeId.put(subtypeId, accrualReversalPointBySubtypeId.get(subtypeId) + totalPoints);
              } else {
                String reversalKey = String.valueOf(subtypeId) + '|' + String.valueOf(reversalExpiryDate);
                if (!accrualReversalPointByKey.containsKey(reversalKey)) {
                  accrualReversalPointByKey.put(reversalKey, 0);
                }
                accrualReversalPointByKey.put(reversalKey, accrualReversalPointByKey.get(reversalKey) + totalPoints);
              }
            }
          }

          for (LoyaltyLedger creditLedger : filteredCreditLedgerList) {
            Integer traceCreditCancellationPoints = traceCreditCancellationPointMap.containsKey(creditLedger.Id)
              ? traceCreditCancellationPointMap.get(creditLedger.Id)
              : 0;
            if (traceCreditCancellationPoints <= 0) {
              continue;
            }

            String reversalKey = String.valueOf(creditLedger.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(creditLedger.ExpiryDate);
            if (accrualReversalPointByKey.containsKey(reversalKey)) {
              Integer remainingTracePoints = Math.max(0, traceCreditCancellationPoints - accrualReversalPointByKey.get(reversalKey));
              accrualReversalPointByKey.put(reversalKey, Math.max(0, accrualReversalPointByKey.get(reversalKey) - traceCreditCancellationPoints));
              traceCreditCancellationPoints = remainingTracePoints;
            }

            if (traceCreditCancellationPoints > 0 && accrualReversalPointBySubtypeId.containsKey(creditLedger.LoyaltyPgmCrcySubtypeId)) {
              accrualReversalPointBySubtypeId.put(
                creditLedger.LoyaltyPgmCrcySubtypeId,
                Math.max(0, accrualReversalPointBySubtypeId.get(creditLedger.LoyaltyPgmCrcySubtypeId) - traceCreditCancellationPoints)
              );
            }
          }

          Map<String, Integer> availablePointByTypeCode = new Map<String, Integer>();
          for (LoyaltyLedger creditLedger : filteredCreditLedgerList) {
            Integer credited = creditLedger.Points == null ? 0 : creditLedger.Points.intValue();
            Integer reduced = reductionPointMap.containsKey(creditLedger.Id) ? reductionPointMap.get(creditLedger.Id) : 0;
            Integer remaining = Math.max(0, credited - reduced);

            String expiredKey = String.valueOf(creditLedger.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(creditLedger.ExpiryDate);
            Integer allocatableExpired = expiredPointByKey.containsKey(expiredKey) ? expiredPointByKey.get(expiredKey) : 0;
            Integer expired = Math.min(remaining, allocatableExpired);
            remaining = Math.max(0, remaining - expired);
            if (expired > 0) {
              expiredPointByKey.put(expiredKey, Math.max(0, allocatableExpired - expired));
            }

            String reversalKey = String.valueOf(creditLedger.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(creditLedger.ExpiryDate);
            Integer allocatableReversal = accrualReversalPointByKey.containsKey(reversalKey) ? accrualReversalPointByKey.get(reversalKey) : 0;
            Integer reversal = Math.min(remaining, allocatableReversal);
            remaining = Math.max(0, remaining - reversal);
            if (reversal > 0) {
              accrualReversalPointByKey.put(reversalKey, Math.max(0, allocatableReversal - reversal));
            }

            if (remaining > 0 && accrualReversalPointBySubtypeId.containsKey(creditLedger.LoyaltyPgmCrcySubtypeId)) {
              Integer allocatableSubtypeReversal = accrualReversalPointBySubtypeId.get(creditLedger.LoyaltyPgmCrcySubtypeId);
              Integer subtypeReversal = Math.min(remaining, allocatableSubtypeReversal);
              remaining = Math.max(0, remaining - subtypeReversal);
              if (subtypeReversal > 0) {
                accrualReversalPointBySubtypeId.put(creditLedger.LoyaltyPgmCrcySubtypeId, Math.max(0, allocatableSubtypeReversal - subtypeReversal));
              }
            }

            if (remaining <= 0) {
              continue;
            }

            String pointTypeCode = creditLedger.LoyaltyPgmCrcySubtype.PointTypeCode__c;
            if (String.isBlank(pointTypeCode)) {
              continue;
            }
            if (!availablePointByTypeCode.containsKey(pointTypeCode)) {
              availablePointByTypeCode.put(pointTypeCode, 0);
            }
            availablePointByTypeCode.put(pointTypeCode, availablePointByTypeCode.get(pointTypeCode) + remaining);
          }

          List<String> pointTypeCodeList = new List<String>(availablePointByTypeCode.keySet());
          pointTypeCodeList.sort();

          for (String pointTypeCode : pointTypeCodeList) {
            Map<String, Object> itemMap = new Map<String, Object>{
              'CD_TYPE_POINT' => pointTypeCode,
              'points' => availablePointByTypeCode.get(pointTypeCode)
            };
            pointList.add((PointResDto.AvailablePointResponse) JSON.deserialize(JSON.serialize(itemMap), PointResDto.AvailablePointResponse.class));
          }
        }
      }

      data.put('pointList', pointList);
      return ApiResult.ok(200, '포인트 적용 도움창 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // 포인트 적용 도움창 조회 관련 매서드 1
  public ApiResult getPointApplyHelpBySaleSequence(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);
      List<LoyaltyProgramMember> lpmList = [SELECT Id FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 회원입니다. ' + memberNo);
      }

      Object rawSaleNo = reqData.get('SaleNo__c');
      if (rawSaleNo == null) {
        rawSaleNo = reqData.get('saleNo');
      }
      if (rawSaleNo == null) {
        rawSaleNo = reqData.get('SaleNo');
      }
      String saleNo = rawSaleNo == null ? null : ValidationUtil.stringValidation(rawSaleNo, 'SaleNo__c', false);

      Object rawOrderDate = reqData.get('orderDate');
      if (rawOrderDate == null) {
        rawOrderDate = reqData.get('OrderDate');
      }
      Date orderDate = rawOrderDate == null ? null : ValidationUtil.dateValidation(rawOrderDate, 'OrderDate', false);

      // [2026-04-23 추가] 3-Way 라우팅 로직
      // 경로 A: 일반 조회 (SaleNo 없음, OrderDate 오늘/미래) → Aggr 직접 집계 (정확)
      // 경로 B: SaleNo 제외 시뮬레이션 (OrderDate 오늘/미래) → Aggr - A판매 잔여분 (Option+)
      // 경로 C: 과거 OrderDate 시뮬레이션 → 기존 Ledger 기반 로직 유지
      Boolean isPastDate = (orderDate != null && orderDate < Date.today());
      Boolean hasSaleFilter = String.isNotBlank(saleNo);

      if (!isPastDate) {
        // 경로 A 또는 B: Aggr 테이블 기반 정확한 집계
        Map<String, Integer> aggrByPtype = buildPointMapFromAggregate(lpmList[0].Id);
        if (hasSaleFilter) {
          // 경로 B: A판매 잔여 적립분만 정확히 차감 (Option+)
          Map<String, Integer> saleRemainingByPtype = computeSaleAccrualRemaining(lpmList[0].Id, saleNo, orderDate);
          for (String ptype : saleRemainingByPtype.keySet()) {
            Integer current = aggrByPtype.containsKey(ptype) ? aggrByPtype.get(ptype) : 0;
            aggrByPtype.put(ptype, Math.max(0, current - saleRemainingByPtype.get(ptype)));
          }
        }
        List<PointResDto.AvailablePointResponse> plist = buildPointListResponse(aggrByPtype);

        // 26.04.30 GD 포인트 10000 미만일 시 에러
        Integer totalPoints = 0;
        for (Integer pts : aggrByPtype.values()) {
          if (pts != null) {
            totalPoints += pts;
          }
        }

        // todo : 운영 시 주석 해제
        // if (totalPoints < 10000) {
        //   plist = new List<PointResDto.AvailablePointResponse>();
        //   data.put('pointList', plist);
        //   return ApiResult.ok(200, '포인트 적용 조회 실패', data);
        // }

        data.put('pointList', plist);

        return ApiResult.ok(200, '포인트 적용 조회 성공', data);
      }

      // 경로 C: 과거 시뮬레이션 — 도움창 전용 hierarchy 적용 메서드 사용
      //   다른 차감 로직(calculatePointUsageAvailableLimit 등) 에는 영향 주지 않도록 분리.
      SaleSequenceCutoff cutoff = hasSaleFilter ? resolveSaleSequenceCutoff(null, saleNo) : null;
      Datetime nextDayStart = cutoff == null && orderDate != null ? TimeUtil.dateToUtcStartOfDay(orderDate.addDays(1)) : null;

      List<AvailableCreditBalance> availableBalanceList = buildAvailableCreditBalancesForHelp(lpmList[0].Id, cutoff, nextDayStart, saleNo);
      Map<String, Integer> availablePointByTypeCode = new Map<String, Integer>();

      for (AvailableCreditBalance balance : availableBalanceList) {
        if (String.isBlank(balance.pointTypeCode) || balance.availablePoints == null || balance.availablePoints <= 0) {
          continue;
        }
        if (!availablePointByTypeCode.containsKey(balance.pointTypeCode)) {
          availablePointByTypeCode.put(balance.pointTypeCode, 0);
        }
        availablePointByTypeCode.put(balance.pointTypeCode, availablePointByTypeCode.get(balance.pointTypeCode) + balance.availablePoints);
      }

      List<PointResDto.AvailablePointResponse> pointList = buildPointListResponse(availablePointByTypeCode);

      // 26.04.30 GD 포인트 10000 미만일 시 에러
      Integer totalPoints = 0;
      for (Integer pts : availablePointByTypeCode.values()) {
        if (pts != null) {
          totalPoints += pts;
        }
      }
      // todo : 운영 시 주석 해제
      // if (totalPoints < 10000) {
      //   return ApiResult.ok(200, '포인트 적용 조회 실패', data);
      // }

      data.put('pointList', pointList);

      return ApiResult.ok(200, '포인트 적용 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * [2026-04-23 추가] Aggr 테이블 기반 포인트 타입별 Available 집계.
   * DB 트리거가 실시간 유지하는 정확한 값을 사용.
   */
  private static Map<String, Integer> buildPointMapFromAggregate(Id memberId) {
    Map<String, Integer> result = new Map<String, Integer>();
    if (memberId == null) {
      return result;
    }
    for (AggregateResult ar : [
      SELECT CurrencySubTypeId__r.PointTypeCode__c ptype, SUM(AvailablePoints__c) total
      FROM LoyaltyAggrSubPointExprLedger__c
      WHERE
        LoyaltyProgramMemberId__c = :memberId
        AND ExpiryDate__c >= :Date.today()
        AND AvailablePoints__c > 0
        AND CurrencySubTypeId__r.PointTypeCode__c != NULL
      GROUP BY CurrencySubTypeId__r.PointTypeCode__c
    ]) {
      String ptype = (String) ar.get('ptype');
      Decimal total = ar.get('total') == null ? 0 : (Decimal) ar.get('total');
      if (String.isBlank(ptype) || total <= 0) {
        continue;
      }
      result.put(ptype, total.intValue());
    }
    return result;
  }

  /**
   * [2026-04-23 추가] 지정 판매의 적립 포인트 중 "아직 잔여 중인" 양을 ptype 별로 계산.
   * Option+ 정밀 로직: Accrual Credit 의 Traceability 를 추적해서 실제 사용된 양을 제외한 잔여만 계산.
   *
   * 계산식: Accrual Credit Points - (해당 Credit 을 참조한 Debit Traceability 합)
   *         - (해당 Credit 에 대한 CreditCancellation Traceability 합)
   */
  private static Map<String, Integer> computeSaleAccrualRemaining(Id memberId, String saleNo, Date queryDate) {
    Map<String, Integer> result = new Map<String, Integer>();
    if (memberId == null || String.isBlank(saleNo)) {
      return result;
    }

    // [Effective Date Hierarchy Fix] queryDate 가 null 이면 현재 기준 (=모든 row 통과)
    Date effectiveQueryDate = queryDate == null ? Date.newInstance(9999, 12, 31) : queryDate;
    Datetime queryDateEnd = queryDate == null
      ? Datetime.newInstance(9999, 12, 31)
      : Datetime.newInstance(TimeUtil.dateToUtcStartOfDay(queryDate.addDays(1)).getTime() - 1);

    // 1단계: 해당 판매에서 적립된 Credit LoyaltyLedger 조회 (Accrual 계열)
    List<LoyaltyLedger> saleCredits = [
      SELECT Id, Points, LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND Points > 0
        AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
        AND (TransactionJournal.Order.SaleNo__c = :saleNo
        OR TransactionJournal.SaleId__r.SaleNo__c = :saleNo)
        AND TransactionJournal.JournalType.Name IN ('Accrual')
        AND (TransactionJournal.AdditionalNotes__c = NULL
        OR (TransactionJournal.AdditionalNotes__c != 'Restore purchase accrual due to return deletion'
        AND TransactionJournal.AdditionalNotes__c != 'Restore promotion point accrual due to return deletion'
        AND TransactionJournal.AdditionalNotes__c != :ECO_POINT_RESTORE_NOTE))
        // 일반 LL: Sale > Order > ActivityDate hierarchy (Accrual 은 RESTORE_NOTES 아니라 hierarchy 만 적용)
        AND ((TransactionJournal.SaleId__r.EffectiveDate != NULL
        AND TransactionJournal.SaleId__r.EffectiveDate <= :effectiveQueryDate)
        OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
        AND TransactionJournal.Order.EffectiveDate != NULL
        AND TransactionJournal.Order.EffectiveDate <= :effectiveQueryDate)
        OR (TransactionJournal.SaleId__r.EffectiveDate = NULL
        AND TransactionJournal.Order.EffectiveDate = NULL
        AND TransactionJournal.ActivityDate <= :queryDateEnd))
      LIMIT 1000
    ];
    if (saleCredits.isEmpty()) {
      return result;
    }

    Set<Id> creditIds = new Set<Id>();
    Map<Id, LoyaltyLedger> creditById = new Map<Id, LoyaltyLedger>();
    for (LoyaltyLedger ll : saleCredits) {
      creditIds.add(ll.Id);
      creditById.put(ll.Id, ll);
    }

    // 2단계: Traceability 기반 사용/취소 합산 (해당 Credit Ledger 를 참조한 Debit/CreditCancellation)
    Map<Id, Decimal> reducedByCreditId = new Map<Id, Decimal>();
    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId cid, SUM(Points) total
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND CreditLoyaltyLedgerId IN :creditIds
        AND ActionType IN (
          'Debit',
          'CreditCancellation'
          // 삭제 보조 (반품 삭제 재차감): CreatedDate 기준
        )
        AND ((DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c IN :RESTORE_NOTES
        AND DebitLoyaltyLedger.CreatedDate <= :queryDateEnd)
        // 일반: Sale > Order > ActivityDate hierarchy
        OR ((DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
        AND ((DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate != NULL
        AND DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate <= :effectiveQueryDate)
        OR (DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate = NULL
        AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate != NULL
        AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate <= :effectiveQueryDate)
        OR (DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate = NULL
        AND DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate = NULL
        AND DebitLoyaltyLedger.TransactionJournal.ActivityDate <= :queryDateEnd))))
      GROUP BY CreditLoyaltyLedgerId
    ]) {
      Id cid = (Id) ar.get('cid');
      Decimal total = ar.get('total') == null ? 0 : (Decimal) ar.get('total');
      reducedByCreditId.put(cid, total.abs());
    }

    // 3단계: ptype 별 실제 잔여 = (Credit Points - Reduced) 합산
    for (LoyaltyLedger ll : saleCredits) {
      String ptype = ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      if (String.isBlank(ptype)) {
        continue;
      }
      Decimal credited = ll.Points == null ? 0 : ll.Points;
      Decimal reduced = reducedByCreditId.containsKey(ll.Id) ? reducedByCreditId.get(ll.Id) : 0;
      Integer remaining = (Integer) Math.max(0, (credited - reduced).intValue());
      if (remaining <= 0) {
        continue;
      }
      Integer prev = result.containsKey(ptype) ? result.get(ptype) : 0;
      result.put(ptype, prev + remaining);
    }
    return result;
  }

  /**
   * [2026-04-23 추가] 공통 헬퍼: ptype -> points Map 을 PointList 응답 구조로 변환.
   */
  private static List<PointResDto.AvailablePointResponse> buildPointListResponse(Map<String, Integer> pointByTypeCode) {
    List<PointResDto.AvailablePointResponse> result = new List<PointResDto.AvailablePointResponse>();
    List<String> keys = new List<String>(pointByTypeCode.keySet());
    keys.sort();
    for (String ptype : keys) {
      Integer pts = pointByTypeCode.get(ptype);
      if (pts == null || pts <= 0) {
        continue;
      }
      Map<String, Object> itemMap = new Map<String, Object>{ 'CD_TYPE_POINT' => ptype, 'points' => pts };
      result.add((PointResDto.AvailablePointResponse) JSON.deserialize(JSON.serialize(itemMap), PointResDto.AvailablePointResponse.class));
    }
    return result;
  }

  /**
   * 사용한 포인트 조회
   */
  public ApiResult getDebitPointList(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'Request body is empty.');
      }

      String saleNo = ValidationUtil.stringValidation(reqData.get('SaleNo__c'), 'SaleNo__c', false); // 판매 번호
      String orderNo = ValidationUtil.stringValidation(reqData.get('OrderNo__c'), 'OrderNo__c', false); // 주문 번호

      // 판매번호 있으면 SaleNo__c, 없으면 OrderNo__c 로 조회
      String fieldPath;
      String keyValue;

      if (!String.isBlank(saleNo)) {
        fieldPath = 'SaleNo__c';
        keyValue = saleNo;
      } else if (!String.isBlank(orderNo)) {
        fieldPath = 'OrderNo__c';
        keyValue = orderNo;
      } else {
        throw new CustomException(400, 'SaleNo__c 또는 OrderNo__c 값이 필요합니다.');
      }

      if (!([SELECT COUNT() FROM Order WHERE OrderNo__c = :keyValue OR SaleNo__c = :keyValue LIMIT 1] > 0)) {
        throw new CustomException(400, '존재하지 않는 주문/판매 번호 입니다. ' + keyValue);
      }

      Id pointDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, true);

      // 신규 로직 (2026-04-02) Start.
      List<PointDebitDTO> pointDebitList = new List<PointDebitDTO>();

      // [기존 코드 시작] 2026-04-22
      // String debitTjSoql =
      //   'SELECT Id, DepositNo__c FROM TransactionJournal WHERE JournalSubTypeId = :pointDebitJstId AND DepositType__c != \'03\' AND Order.' +
      //   fieldPath +
      //   ' = :keyValue LIMIT 1';
      // [기존 코드 끝] 2026-04-22

      // [수정 코드 시작] 2026-04-22 - 주문에서 debit되어 판매에 연결된 TJ(SaleId__r 경로)도 포함하도록 OR 조건 확장 + 2차 쿼리와 정합성 맞추어 IsDeleted__c=FALSE 추가
      String debitTjSoql =
        'SELECT Id, DepositNo__c FROM TransactionJournal WHERE JournalSubTypeId = :pointDebitJstId AND DepositType__c != \'03\' AND IsDeleted__c = FALSE AND (Order.' +
        fieldPath +
        ' = :keyValue OR SaleId__r.' +
        fieldPath +
        ' = :keyValue) LIMIT 1';
      // [수정 코드 끝] 2026-04-22
      List<TransactionJournal> debitTjList = (List<TransactionJournal>) Database.query(debitTjSoql);
      if (debitTjList.isEmpty()) {
        data.put('DebitPointList', pointDebitList);
        return ApiResult.ok(200, '사용한 포인트 조회 성공', data); // 조회 결과 없음
      }
      String depositNo = debitTjList[0].DepositNo__c;
      // 신규 로직 (2026-04-02) End.

      String soql =
        'SELECT ' +
        'CreditLoyaltyLedgerId, DebitLoyaltyLedgerId, LoyaltyPgmCurrencySubtypeId, ActionType, Points, CreatedDate, ' +
        'DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c, DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c, DebitLoyaltyLedger.TransactionJournal.Order.IsReductionOrder__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c, DebitLoyaltyLedger.TransactionJournal.SaleId__r.OrderNo__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.SaleId__r.ActualPaymentAmount__c, DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c, ' +
        'LoyaltyProgramMember.Contact.MemberNo__c, CreditLoyaltyLedger.ExpiryDate, LoyaltyPgmCurrencySubtype.Name, ' +
        'DebitLoyaltyLedger.TransactionJournal.InsertId__c, DebitLoyaltyLedger.TransactionJournal.DepositNo__c, ' +
        'DebitLoyaltyLedger.TransactionJournal.IsDeleted__c, DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c ' +
        'FROM LoyaltyLedgerTraceability ' +
        'WHERE ' +
        'ActionType = \'Debit\' ' +
        'AND DebitLoyaltyLedger.TransactionJournal.JournalSubTypeId = :pointDebitJstId ' +
        'AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE ' +
        // [getDebitPointList Fix 2026-05-02] 반품 입금 삭제 재차감 Debit LLT 제외
        //   v3 paradigm 으로 원본 사용 LLT 가 보존된 상태에서 재차감 보조 LLT 가 함께 합산되면 PT_USE 가 이중 표시됨.
        //   (GdMemberHelpInfoServiceImpl.buildPointPaymentSummaryMap 의 [scn5 R1-11 Fix 2026-04-27] 와 동일 패턴)
        //   2026-04-02 v2 paradigm 시기에 일시 주석 처리되었던 필터를 v3 정합성 회복 위해 재활성화.
        'AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL ' +
        'OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE) ' +
        'AND (DebitLoyaltyLedger.TransactionJournal.Order.' +
        fieldPath +
        ' = :keyValue ' +
        'OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.' +
        fieldPath +
        ' = :keyValue) ' +
        'LIMIT 200';

      List<LoyaltyLedgerTraceability> lltList = (List<LoyaltyLedgerTraceability>) Database.query(soql);

      Map<LedgerAggKey, Decimal> usedPointMap = new Map<LedgerAggKey, Decimal>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        // Credit 기준 만료일
        Date expiryDate = llt.CreditLoyaltyLedger.ExpiryDate;

        LedgerAggKey key = new LedgerAggKey(llt);

        if (!usedPointMap.containsKey(key)) {
          usedPointMap.put(key, 0);
        }

        usedPointMap.put(key, usedPointMap.get(key) + llt.Points);
      }

      // [scn7 R3-2 Fix 2026-04-27] 부분반품/사용취소로 인한 Cancel Credit LL 을 ptype 별 합산해 차감
      //   v3 paradigm 의 cancelPointRedemption_v3 는 새 LLT 를 만들지 않고 Cancel Credit LL 만 발급하므로
      //   기존 LLT 합산만으로는 부분반품 후 잔여 사용액이 반영되지 않음 (시나리오 7 Step 7-11 회귀 R3-2).
      //   같은 원판매(또는 반품판매)의 Point Redeem Cancel Credit LL 을 ptype 별 합산하여 사용액에서 차감.
      String cancelCreditSoql =
        'SELECT LoyaltyPgmCrcySubtypeId stid, SUM(Points) totalPoints ' +
        'FROM LoyaltyLedger ' +
        'WHERE EventType = \'Credit\' ' +
        'AND TransactionJournal.JournalSubType.Name = \'Point Redeem Cancel\' ' +
        'AND TransactionJournal.IsDeleted__c = FALSE ' +
        'AND (TransactionJournal.Order.' +
        fieldPath +
        ' = :keyValue ' +
        'OR TransactionJournal.SaleId__r.' +
        fieldPath +
        ' = :keyValue) ' +
        'GROUP BY LoyaltyPgmCrcySubtypeId';
      Map<Id, Decimal> cancelByPtype = new Map<Id, Decimal>();
      for (AggregateResult ar : (List<AggregateResult>) Database.query(cancelCreditSoql)) {
        Id stid = (Id) ar.get('stid');
        Decimal total = ar.get('totalPoints') == null ? 0 : (Decimal) ar.get('totalPoints');
        if (stid != null && total > 0) {
          cancelByPtype.put(stid, total);
        }
      }
      // ptype 별 사용액에서 Cancel Credit 합산 차감 (음수 방지)
      for (LedgerAggKey key : new Set<LedgerAggKey>(usedPointMap.keySet())) {
        Decimal cancel = cancelByPtype.containsKey(key.currencySubtypeId) ? cancelByPtype.get(key.currencySubtypeId) : 0;
        if (cancel > 0) {
          Decimal netUsed = Math.max(0, usedPointMap.get(key) - cancel);
          usedPointMap.put(key, netUsed);
        }
      }

      // List<Map<String, Object>> l1 = new List<Map<String, Object>>();
      for (LedgerAggKey key : usedPointMap.keySet()) {
        Decimal used = usedPointMap.get(key);

        // 실제 사용된 포인트만 포함
        if (used > 0) {
          PointDebitDTO pointDebitDto = new PointDebitDTO();

          // 신규 로직
          if (!String.isBlank(depositNo)) {
            // if (!String.isBlank(key.depositNo)) {  // 기존 로직
            pointDebitDto.NO_DEPOSIT = depositNo.replaceAll('-\\d+$', ''); // 입금 번호   // 신규 로직
            // pointDebitDto.NO_DEPOSIT = key.depositNo.replaceAll('-\\d+$', ''); // 입금 번호  // 기존 로직
          }
          pointDebitDto.CD_LEDGER = key.debitLoyaltyLedgerId; // 로열티 소멸 키값
          pointDebitDto.CD_JOURNAL = key.creditLoyaltyLedgerId; // key.debitLoyaltyLedgerId; -> key.creditLoyaltyLedgerId; (26.02.03)
          pointDebitDto.CD_TYPE_POINT = key.currencySubtypeId; // 포인트 구분
          pointDebitDto.CD_RESON = '1'; // 회원포인트소진구분
          pointDebitDto.NO_MBR = key.memberNo; // 회원번호
          pointDebitDto.NO_SAL = key.saleOrOrderNo; // 판매/반품/주문 번호
          pointDebitDto.AM_SAL = key.actualPaymentAmount; // 판매처리된 판매의 금액
          pointDebitDto.PT_USE = used; // 사용처리된 금액
          pointDebitDto.DTS_INSERT = key.createdDate; // 등록일자
          pointDebitDto.ID_INSERT = key.insertId; // 등록자
          if (key.isReductionOrder && !String.isBlank(key.returnSaleNo)) {
            pointDebitDto.NO_SAL_RTN = key.returnSaleNo; // 판매 반품 번호
          }

          pointDebitList.add(pointDebitDto);
        }
      }
      data.put('DebitPointList', pointDebitList);

      return ApiResult.ok(200, '사용한 포인트 조회 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // ! 사용 X
  /*
  // 신규 로직 (Hana 2026-04-??) Start.
  // public List<GdSaleApiController.PointDebitDTO> debitPointBySaleSequence(TransactionJournal tj) {
  //   try {
  //     Long totalStartMs = Datetime.now().getTime();
  //     Integer totalStartCpu = Limits.getCpuTime();
  //     if (tj == null) {
  //       throw new CustomException(400, 'TransactionJournal is null');
  //     }
  //
  //     Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
  //     Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
  //     Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);
  //     logTiming('debitPointBySaleSequence.resolveJournalTypes', totalStartMs, totalStartCpu);
  //
  //     tj.JournalReason__c = '1';
  //     tj.JournalTypeId = jtId;
  //     tj.JournalSubTypeId = jstId;
  //     tj.Status = 'Pending';
  //
  //     List<LoyaltyMemberCurrency> lmcList = [
  //       SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
  //       FROM LoyaltyMemberCurrency
  //       WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
  //       LIMIT 1
  //     ];
  //     tj.PostPointBalance__c = lmcList[0].PointsBalance - tj.TransactionAmount;
  //     logTiming('debitPointBySaleSequence.loadMemberCurrency', totalStartMs, totalStartCpu);
  //
  //     insert tj;
  //     logTiming('debitPointBySaleSequence.insertJournal', totalStartMs, totalStartCpu);
  //
  //     String saleNo;
  //     if (String.isNotBlank(tj.OrderId)) {
  //       List<Order> oList = [SELECT OrderNo__c, SaleNo__c FROM Order WHERE Id = :tj.OrderId LIMIT 1];
  //       if (!oList.isEmpty()) {
  //         if (String.isNotBlank(oList[0].OrderNo__c)) {
  //           saleNo = oList[0].OrderNo__c;
  //         } else if (String.isNotBlank(oList[0].SaleNo__c)) {
  //           saleNo = oList[0].SaleNo__c;
  //         }
  //       }
  //     }
  //
  //     SaleSequenceCutoff cutoff = resolveSaleSequenceCutoff(tj.OrderId, null);
  //     if (cutoff == null) {
  //       Datetime nowDt = tj.ActivityDate == null ? Datetime.now() : tj.ActivityDate;
  //       cutoff = new SaleSequenceCutoff(nowDt, tj.CreatedDate, tj.Id, tj.OrderId, saleNo);
  //     }
  //     cutoff.activityDate = tj.ActivityDate == null ? cutoff.activityDate : tj.ActivityDate;
  //     cutoff.createdDate = tj.CreatedDate == null ? cutoff.createdDate : tj.CreatedDate;
  //     cutoff.journalId = tj.Id;
  //
  //     List<AvailableCreditBalance> availableBalanceList = buildAvailableCreditBalances(tj.MemberId, cutoff, null, saleNo);
  //     Decimal totalAvailable = 0;
  //     for (AvailableCreditBalance balance : availableBalanceList) {
  //       totalAvailable += balance.availablePoints;
  //     }
  //     if (totalAvailable < tj.TransactionAmount) {
  //       // [Insufficient Balance Message Fix 2026-05-07] debitPoint 와 동일 패턴 — 가용 금액 포함.
  //       throw new CustomException(400,
  //         '포인트 예약액이 부족합니다. 사용 가능 금액: ' + totalAvailable.intValue() + 'P (요청: ' + tj.TransactionAmount.intValue() + 'P)');
  //     }
  //
  //     Decimal remaining = tj.TransactionAmount;
  //     Map<String, Decimal> subtypeDebitMap = new Map<String, Decimal>();
  //     for (AvailableCreditBalance balance : availableBalanceList) {
  //       if (remaining <= 0) {
  //         break;
  //       }
  //       if (String.isBlank(balance.subtypeName) || balance.availablePoints == null || balance.availablePoints <= 0) {
  //         continue;
  //       }
  //       Decimal amt = Math.min((Decimal) balance.availablePoints, remaining);
  //       if (!subtypeDebitMap.containsKey(balance.subtypeName)) {
  //         subtypeDebitMap.put(balance.subtypeName, 0);
  //       }
  //       subtypeDebitMap.put(balance.subtypeName, subtypeDebitMap.get(balance.subtypeName) + amt);
  //       remaining -= amt;
  //     }
  //
  //     List<Map<String, Object>> reqList = new List<Map<String, Object>>();
  //     for (String subtypeName : subtypeDebitMap.keySet()) {
  //       Map<String, Object> req = new Map<String, Object>();
  //       req.put('loyaltyProgramMemberId', tj.MemberId);
  //       req.put('points', subtypeDebitMap.get(subtypeName));
  //       req.put('journalId', tj.Id);
  //       req.put('loyaltyProgramCurrencySubtypeName', subtypeName);
  //       reqList.add(req);
  //     }
  //
  //     List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);
  //     logTiming('debitPointBySaleSequence.loyaltyPointServiceDebit', totalStartMs, totalStartCpu);
  //
  //     String memberNo;
  //     List<LoyaltyProgramMember> lpmList = [
  //       SELECT Contact.MemberNo__c
  //       FROM LoyaltyProgramMember
  //       WHERE Id = :tj.MemberId
  //       LIMIT 1
  //     ];
  //     if (!lpmList.isEmpty()) {
  //       memberNo = lpmList[0].Contact.MemberNo__c;
  //     }
  //
  //     List<LoyaltyLedgerTraceability> lltList = [
  //       SELECT Points, LastModifiedDate, DebitLoyaltyLedgerId, LoyaltyPgmCurrencySubtype.PointTypeCode__c, CreditLoyaltyLedgerId
  //       FROM LoyaltyLedgerTraceability
  //       WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
  //       LIMIT 100
  //     ];
  //     if (lltList.isEmpty()) {
  //       throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
  //     }
  //
  //     List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
  //     for (LoyaltyLedgerTraceability llt : lltList) {
  //       GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
  //       pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
  //       pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId;
  //       pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
  //       pcDto.CD_RESON = tj.JournalReason__c;
  //       pcDto.NO_MBR = memberNo;
  //       if (String.isNotBlank(saleNo)) {
  //         pcDto.NO_SAL = saleNo;
  //       }
  //       pcDto.PT_USE = llt.Points;
  //       pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);
  //       pdDtoList.add(pcDto);
  //     }
  //
  //     return pdDtoList;
  //   } catch (ValidationException ve) {
  //     throw new CustomException(ve.code, ve.detail);
  //   } catch (Exception e) {
  //     throw e;
  //   }
  // }
  // 신규 로직 (Hana 2026-04-??) End.
  */

  /**
   * 판매 수정(PATCH /sale) 전용 포인트 사용 — 커스텀 직접 DML 방식.
   *
   * 목적: 해당 판매에서 적립된 포인트(Purchase Accrual / Promotion Point Accrual)를 차감 대상에서 제외하고,
   *       만료일자 ASC → 포인트 하위유형 UsagePriorityNumber ASC 순으로 기존 보유 Credit Ledger에서만 차감.
   *
   * 표준 API(LoyaltyPointService.debitPoints())를 사용하지 않는 이유:
   *   - 서브타입 지정 시에도 해당 서브타입 잔액 부족 시 다른 서브타입으로 자동 폴백
   *   - 서브타입 내부 Credit Ledger 선택이 API 자율이라 same-sale Credit이 우선 소비될 수 있음
   *
   * 호출 계약:
   *   - tj.MemberId, tj.OrderId, tj.TransactionAmount, tj.ActivityDate 필수 선세팅
   *   - JournalTypeId/JournalSubTypeId/Status/JournalReason__c는 본 메서드가 설정
   */
  public List<GdSaleApiController.PointDebitDTO> debitPointForSaleUpdate(TransactionJournal tj) {
    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }
      if (tj.MemberId == null) {
        throw new CustomException(400, 'TransactionJournal.MemberId is required');
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount <= 0) {
        throw new CustomException(400, 'TransactionJournal.TransactionAmount must be positive');
      }

      // 1. JournalType / JournalSubType / LoyaltyProgramCurrency 상수 조회
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);
      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.JournalReason__c = '1'; // 1: 사용
      tj.Status = 'Pending';

      // 2. PostPointBalance__c 계산
      List<LoyaltyMemberCurrency> lmcPre = [
        SELECT LoyaltyMemberId, PointsBalance
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      if (lmcPre.isEmpty()) {
        throw new CustomException(400, 'LoyaltyMemberCurrency not found for member ' + tj.MemberId);
      }
      tj.PostPointBalance__c = lmcPre[0].PointsBalance - tj.TransactionAmount;

      // 3. TJ insert (Pending 상태)
      insert tj;

      // 4. 판매 정보 도출 (OrderId -> Order.SaleNo / EndDate)
      String saleNo = null;
      Date saleDate = null;
      if (String.isNotBlank(tj.OrderId)) {
        List<Order> oList = [SELECT SaleNo__c, OrderNo__c, EndDate FROM Order WHERE Id = :tj.OrderId LIMIT 1];
        if (!oList.isEmpty()) {
          saleNo = String.isNotBlank(oList[0].OrderNo__c) ? oList[0].OrderNo__c : oList[0].SaleNo__c;
          saleDate = oList[0].EndDate;
        }
      }

      // 5. 후보 Credit Ledger 조회 (ExpiryDate ASC, UsagePriorityNumber ASC, CreatedDate ASC, Id ASC)
      List<LoyaltyLedger> credits = [
        SELECT
          Id,
          Points,
          ExpiryDate,
          ActivityDate,
          CreatedDate,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.UsagePriorityNumber,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.SaleId__r.SaleNo__c,
          TransactionJournal.JournalSubType.Name
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :tj.MemberId
          AND EventType = 'Credit'
          AND Points > 0
          AND ExpiryDate >= TODAY
          AND LoyaltyPgmCrcySubtype.PointTypeCode__c != NULL
          AND TransactionJournal.JournalSubType.Name != :JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL
        ORDER BY ExpiryDate ASC, LoyaltyPgmCrcySubtype.UsagePriorityNumber ASC, CreatedDate ASC, Id ASC
        LIMIT 50000
      ];

      // 6. Traceability로 각 Credit Ledger의 남은 금액 계산
      Set<Id> creditIds = new Set<Id>();
      for (LoyaltyLedger c : credits) {
        creditIds.add(c.Id);
      }
      Map<Id, Decimal> reductionMap = new Map<Id, Decimal>();
      if (!creditIds.isEmpty()) {
        for (AggregateResult ar : [
          SELECT CreditLoyaltyLedgerId credId, ActionType act, SUM(Points) tot
          FROM LoyaltyLedgerTraceability
          WHERE
            LoyaltyProgramMemberId = :tj.MemberId
            AND CreditLoyaltyLedgerId IN :creditIds
            AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
            AND (ActionType != 'Debit'
            OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
          GROUP BY CreditLoyaltyLedgerId, ActionType
        ]) {
          Id cid = (Id) ar.get('credId');
          String act = (String) ar.get('act');
          Decimal pts = ar.get('tot') == null ? 0 : ((Decimal) ar.get('tot')).abs();
          Decimal cur = reductionMap.containsKey(cid) ? reductionMap.get(cid) : 0;
          if (act == 'DebitCancellation') {
            reductionMap.put(cid, Math.max(0, cur - pts));
          } else {
            reductionMap.put(cid, cur + pts);
          }
        }
      }

      // 7. same-sale 필터링 + Greedy 차감 분배
      List<AllocationEntry> allocations = new List<AllocationEntry>();
      Decimal remaining = tj.TransactionAmount;
      for (LoyaltyLedger c : credits) {
        if (remaining <= 0) {
          break;
        }

        // same-sale 제외 (Order.SaleNo / SaleId.SaleNo 양쪽 비교)
        String csn = (c.TransactionJournal != null && c.TransactionJournal.Order != null) ? c.TransactionJournal.Order.SaleNo__c : null;
        String crsn = (c.TransactionJournal != null && c.TransactionJournal.SaleId__r != null) ? c.TransactionJournal.SaleId__r.SaleNo__c : null;
        if (String.isNotBlank(saleNo) && (saleNo == csn || saleNo == crsn)) {
          continue;
        }

        // saleDate 이후 적립분 제외 (Order.EndDate 기준)
        if (saleDate != null && c.ActivityDate != null && c.ActivityDate.date() > saleDate) {
          continue;
        }

        Decimal used = reductionMap.containsKey(c.Id) ? reductionMap.get(c.Id) : 0;
        Decimal usable = c.Points - used;
        if (usable <= 0) {
          continue;
        }

        Decimal amt = (usable >= remaining) ? remaining : usable;

        AllocationEntry a = new AllocationEntry();
        a.creditId = c.Id;
        a.subtypeId = c.LoyaltyPgmCrcySubtypeId;
        a.subtypeName = c.LoyaltyPgmCrcySubtype != null ? c.LoyaltyPgmCrcySubtype.Name : null;
        a.pointTypeCode = c.LoyaltyPgmCrcySubtype != null ? c.LoyaltyPgmCrcySubtype.PointTypeCode__c : null;
        a.amount = amt;
        allocations.add(a);

        remaining -= amt;
      }

      if (remaining > 0) {
        // [Insufficient Balance Message Fix 2026-05-07] 가용 금액 / 요청 금액 포함.
        //   available = 요청 - 잔여 (할당 못한 부분 = 가용 부족분)
        Decimal available = tj.TransactionAmount - remaining;
        throw new CustomException(
          400,
          '포인트 잔액이 부족합니다. 사용 가능 금액: ' + available.intValue() + 'P (요청: ' + tj.TransactionAmount.intValue() + 'P)'
        );
      }

      // 8. Debit LoyaltyLedger insert (단일, subtypeId=null, ExpiryDate=null - 표준 동작 일치)
      LoyaltyLedger debitLedger = new LoyaltyLedger(
        EventType = 'Debit',
        LoyaltyProgramMemberId = tj.MemberId,
        LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId,
        Points = tj.TransactionAmount,
        TransactionJournalId = tj.Id,
        ActivityDate = (tj.ActivityDate != null ? tj.ActivityDate : Datetime.now())
      );
      insert debitLedger;

      // 9. Traceability N건 insert (cancelPointRedemption 재쿼리 호환 위해 LoyaltyProgramCurrencyId 필수)
      List<LoyaltyLedgerTraceability> traces = new List<LoyaltyLedgerTraceability>();
      for (AllocationEntry a : allocations) {
        LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability(
          ActionType = 'Debit',
          LoyaltyProgramMemberId = tj.MemberId,
          LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId,
          LoyaltyPgmCurrencySubtypeId = a.subtypeId,
          DebitLoyaltyLedgerId = debitLedger.Id,
          CreditLoyaltyLedgerId = a.creditId,
          Points = a.amount
        );
        traces.add(t);
      }
      if (!traces.isEmpty()) {
        insert traces;
      }

      // 10. LoyaltyMemberCurrency update (FOR UPDATE 락)
      List<LoyaltyMemberCurrency> lmcs = [
        SELECT Id, TotalPointsRedeemed
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        FOR UPDATE
      ];
      if (lmcs.isEmpty()) {
        throw new CustomException(400, 'LoyaltyMemberCurrency not found (second read) for member ' + tj.MemberId);
      }
      LoyaltyMemberCurrency lmc = lmcs[0];
      lmc.TotalPointsRedeemed = (lmc.TotalPointsRedeemed == null ? 0 : lmc.TotalPointsRedeemed) + tj.TransactionAmount;
      update lmc;

      // 11. TJ Status='Processed' → GdTransactionJournalTriggerHandler 발동 → LoyaltyAggrSubPointExprLedger__c 집계
      tj.Status = 'Processed';
      update tj;

      // 12. Response DTO 구성 (기존 debitPoint와 동일 스키마)
      String memberNo;
      List<LoyaltyProgramMember> lpmList = [SELECT Contact.MemberNo__c FROM LoyaltyProgramMember WHERE Id = :tj.MemberId LIMIT 1];
      if (!lpmList.isEmpty()) {
        memberNo = lpmList[0].Contact.MemberNo__c;
      }

      List<LoyaltyLedgerTraceability> insertedTraces = [
        SELECT Points, LastModifiedDate, DebitLoyaltyLedgerId, CreditLoyaltyLedgerId, LoyaltyPgmCurrencySubtype.PointTypeCode__c
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : insertedTraces) {
        GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId;
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = memberNo;
        pcDto.NO_SAL = saleNo;
        pcDto.PT_USE = llt.Points;
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);
        pdDtoList.add(pcDto);
      }
      return pdDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // debitPointForSaleUpdate 내부 사용 allocation 구조체
  private class AllocationEntry {
    Id creditId;
    Id subtypeId;
    String subtypeName;
    String pointTypeCode;
    Decimal amount;
  }

  // Custom 포인트 차감
  private class CustomDebitRequest {
    Id memberId;
    Decimal points;
    Id journalId;
    Id subtypeId;
    String subtypeName;
    String additionalNotes;
  }

  // Custom 포인트 차감
  private class CustomDebitAllocation {
    Integer requestIndex;
    Id creditLedgerId;
    Id subtypeId;
    Decimal points;

    CustomDebitAllocation(Integer requestIndex, Id creditLedgerId, Id subtypeId, Decimal points) {
      this.requestIndex = requestIndex;
      this.creditLedgerId = creditLedgerId;
      this.subtypeId = subtypeId;
      this.points = points;
    }
  }

  private class CustomDebitCandidate {
    Id creditLedgerId;
    Id originCreditLedgerId;
    Id subtypeId;
    Decimal availablePoints;
    Date expiryDate;
    Integer usagePriority;
    Datetime originActivityDate;
    Datetime originCreatedDate;
    Boolean isRestoredCredit;
    Datetime creditCreatedDate;

    CustomDebitCandidate(LoyaltyLedger creditLedger, LoyaltyLedger originLedger, Decimal availablePoints) {
      this.creditLedgerId = creditLedger.Id;
      this.subtypeId = creditLedger.LoyaltyPgmCrcySubtypeId;
      this.availablePoints = availablePoints;
      this.expiryDate = originLedger != null ? originLedger.ExpiryDate : creditLedger.ExpiryDate;
      this.usagePriority = creditLedger.LoyaltyPgmCrcySubtype == null ? null : creditLedger.LoyaltyPgmCrcySubtype.UsagePriorityNumber;
      this.originActivityDate = originLedger != null ? originLedger.ActivityDate : creditLedger.ActivityDate;
      this.originCreatedDate = originLedger != null ? originLedger.CreatedDate : creditLedger.CreatedDate;
      this.originCreditLedgerId = originLedger != null ? originLedger.Id : creditLedger.Id;
      this.isRestoredCredit = originLedger != null && originLedger.Id != creditLedger.Id;
      this.creditCreatedDate = creditLedger.CreatedDate;
    }
  }

  private class CustomDebitCandidateSorter implements System.Comparator<Object> {
    public Integer compare(Object a, Object b) {
      CustomDebitCandidate x = (CustomDebitCandidate) a;
      CustomDebitCandidate y = (CustomDebitCandidate) b;

      Integer result = compareDateAsc(x.expiryDate, y.expiryDate);
      if (result != 0)
        return result;

      result = compareIntegerAsc(x.usagePriority, y.usagePriority);
      if (result != 0)
        return result;

      result = compareDatetimeAsc(x.originActivityDate, y.originActivityDate);
      if (result != 0)
        return result;

      result = compareDatetimeAsc(x.originCreatedDate, y.originCreatedDate);
      if (result != 0)
        return result;

      result = compareStringAsc(String.valueOf(x.originCreditLedgerId), String.valueOf(y.originCreditLedgerId));
      if (result != 0)
        return result;

      if (x.isRestoredCredit != y.isRestoredCredit) {
        return x.isRestoredCredit ? 1 : -1;
      }

      result = compareDatetimeAsc(x.creditCreatedDate, y.creditCreatedDate);
      if (result != 0)
        return result;

      return compareStringAsc(String.valueOf(x.creditLedgerId), String.valueOf(y.creditLedgerId));
    }

    private Integer compareDateAsc(Date x, Date y) {
      if (x == y)
        return 0;
      if (x == null)
        return 1;
      if (y == null)
        return -1;
      if (x < y)
        return -1;
      if (x > y)
        return 1;
      return 0;
    }

    private Integer compareDatetimeAsc(Datetime x, Datetime y) {
      if (x == y)
        return 0;
      if (x == null)
        return 1;
      if (y == null)
        return -1;
      if (x < y)
        return -1;
      if (x > y)
        return 1;
      return 0;
    }

    private Integer compareIntegerAsc(Integer x, Integer y) {
      if (x == y)
        return 0;
      if (x == null)
        return 1;
      if (y == null)
        return -1;
      if (x < y)
        return -1;
      if (x > y)
        return 1;
      return 0;
    }

    private Integer compareStringAsc(String x, String y) {
      if (x == y)
        return 0;
      if (x == null)
        return 1;
      if (y == null)
        return -1;
      return x.compareTo(y);
    }
  }

  /**
   * ? Custom 포인트 차감
   * Custom replacement candidate for LoyaltyPointService.debitPoints().
   *
   * Accepts the same request map shape used by LoyaltyPointService.debitPoints:
   * - loyaltyProgramMemberId
   * - points
   * - journalId
   * - loyaltyProgramCurrencySubtypeName (optional)
   * - additionalNotes (optional)
   *
   * The caller must create the TransactionJournal before calling this method
   * and must update TJ.Status to Processed after this method returns.
   */
  public List<GdSaleApiController.PointDebitDTO> debitPointsCustom(TransactionJournal tj) {
    Savepoint sp = Database.setSavepoint();
    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }
      if (tj.MemberId == null) {
        throw new CustomException(400, 'TransactionJournal.MemberId is required.');
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount <= 0) {
        throw new CustomException(400, 'TransactionJournal.TransactionAmount must be positive.');
      }

      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);
      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      tj.JournalReason__c = '1';
      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      // 포인트 사용 시점에서 실제로 사용 가능한 포인트 조회
      Integer usageDateAvailableLimit = calculatePointUsageAvailableLimit(tj);
      if (usageDateAvailableLimit != null && usageDateAvailableLimit < tj.TransactionAmount) {
        throw new CustomException(
          400,
          '포인트 잔액이 부족합니다. 사용 가능 금액: ' + usageDateAvailableLimit + 'P (요청: ' + tj.TransactionAmount.intValue() + 'P)'
        );
      }

      List<LoyaltyMemberCurrency> lmcList = [
        SELECT Id, LoyaltyMemberId, PointsBalance, TotalPointsRedeemed, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
        FOR UPDATE
      ];
      if (lmcList.isEmpty()) {
        throw new CustomException(400, 'LoyaltyMemberCurrency not found. ' + tj.MemberId);
      }

      LoyaltyMemberCurrency lmc = lmcList[0];
      Decimal currentBalance = lmc.PointsBalance == null ? 0 : lmc.PointsBalance;
      if (currentBalance < tj.TransactionAmount) {
        throw new CustomException(
          400,
          '포인트 잔액이 부족합니다. 사용 가능 금액: ' + currentBalance.intValue() + 'P (요청: ' + tj.TransactionAmount.intValue() + 'P)'
        );
      }
      tj.PostPointBalance__c = currentBalance - tj.TransactionAmount;

      insert tj;

      List<LoyaltyLedger> creditLedgers = [
        SELECT
          Id,
          LoyaltyProgramMemberId,
          LoyaltyProgramCurrencyId,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.UsagePriorityNumber,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          Points,
          ExpiryDate,
          ActivityDate,
          CreatedDate,
          AdditionalNotes,
          TransactionJournal.JournalSubType.Name,
          TransactionJournal.Order.OrderNo__c,
          TransactionJournal.Order.SaleNo__c,
          TransactionJournal.SaleId__r.SaleNo__c
        FROM LoyaltyLedger
        WHERE
          LoyaltyProgramMemberId = :tj.MemberId
          AND EventType = 'Credit'
          AND Points > 0
          AND ExpiryDate >= TODAY
          AND LoyaltyPgmCrcySubtypeId != NULL
        ORDER BY ExpiryDate ASC, LoyaltyPgmCrcySubtype.UsagePriorityNumber ASC, CreatedDate ASC, Id ASC
        LIMIT 50000
      ];

      if (creditLedgers.isEmpty()) {
        throw new CustomException(400, '포인트 잔액이 부족합니다. 사용 가능 금액: 0P (요청: ' + tj.TransactionAmount.intValue() + 'P)');
      }

      Map<Id, OriginRestoreCreditState> originRestoreCreditStateByOriginId = buildOriginRestoreCreditStateMap(creditLedgers);

      Set<Id> creditLedgerIds = new Set<Id>();
      for (LoyaltyLedger creditLedger : creditLedgers) {
        creditLedgerIds.add(creditLedger.Id);
      }

      Set<Id> originCreditLedgerIds = new Set<Id>();
      for (LoyaltyLedger creditLedger : creditLedgers) {
        Id originCreditLedgerId = extractOriginCreditLedgerId(creditLedger.AdditionalNotes);
        if (originCreditLedgerId != null && originCreditLedgerId != creditLedger.Id) {
          originCreditLedgerIds.add(originCreditLedgerId);
        }
      }

      Map<Id, LoyaltyLedger> originCreditLedgerById = new Map<Id, LoyaltyLedger>();
      if (!originCreditLedgerIds.isEmpty()) {
        originCreditLedgerById = new Map<Id, LoyaltyLedger>(
          [
            SELECT Id, LoyaltyPgmCrcySubtypeId, LoyaltyPgmCrcySubtype.UsagePriorityNumber, ExpiryDate, ActivityDate, CreatedDate
            FROM LoyaltyLedger
            WHERE Id IN :originCreditLedgerIds
          ]
        );
      }

      Map<Id, Decimal> debitOrCreditCancelByCreditId = new Map<Id, Decimal>();
      Map<Id, Decimal> debitCancelByCreditId = new Map<Id, Decimal>();
      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :tj.MemberId
          AND CreditLoyaltyLedgerId IN :creditLedgerIds
          AND IsDeleted = FALSE
          AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
          AND (DebitLoyaltyLedgerId = NULL
          OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
        GROUP BY CreditLoyaltyLedgerId, ActionType
      ]) {
        Id creditId = (Id) ar.get('creditId');
        String actionType = (String) ar.get('actionType');
        Decimal points = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs();

        if (actionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION) {
          Decimal current = debitCancelByCreditId.containsKey(creditId) ? debitCancelByCreditId.get(creditId) : 0;
          debitCancelByCreditId.put(creditId, current + points);
        } else {
          Decimal current = debitOrCreditCancelByCreditId.containsKey(creditId) ? debitOrCreditCancelByCreditId.get(creditId) : 0;
          debitOrCreditCancelByCreditId.put(creditId, current + points);
        }
      }

      List<CustomDebitCandidate> candidates = new List<CustomDebitCandidate>();
      Decimal availableTotal = 0;

      for (LoyaltyLedger creditLedger : creditLedgers) {
        Decimal usedOrCanceled = debitOrCreditCancelByCreditId.containsKey(creditLedger.Id) ? debitOrCreditCancelByCreditId.get(creditLedger.Id) : 0;
        Decimal restored = debitCancelByCreditId.containsKey(creditLedger.Id) ? debitCancelByCreditId.get(creditLedger.Id) : 0;
        Decimal reduced = Math.max(0, usedOrCanceled - restored);
        Decimal available = (creditLedger.Points == null ? 0 : creditLedger.Points) - reduced;

        if (available <= 0) {
          continue;
        }

        Id originCreditLedgerId = extractOriginCreditLedgerId(creditLedger.AdditionalNotes);
        if (shouldExcludeRestoreCreditByOrigin(originCreditLedgerId, originRestoreCreditStateByOriginId)) {
          continue;
        }

        OriginRestoreCreditState originState = originCreditLedgerId == null ? null : originRestoreCreditStateByOriginId.get(originCreditLedgerId);
        if (originState != null) {
          Integer availableByOrigin = Math.min(available.intValue(), originState.remainingCap);
          originState.remainingCap = Math.max(0, originState.remainingCap - availableByOrigin);
          available = availableByOrigin;
          if (available <= 0) {
            continue;
          }
        }

        availableTotal += available;
        LoyaltyLedger originLedger = originCreditLedgerId == null ? null : originCreditLedgerById.get(originCreditLedgerId);
        candidates.add(new CustomDebitCandidate(creditLedger, originLedger, available));
      }

      Map<String, CustomDebitCandidate> candidateBySortKey = new Map<String, CustomDebitCandidate>();
      List<String> candidateSortKeys = new List<String>();
      for (CustomDebitCandidate candidate : candidates) {
        String baseSortKey = buildCustomDebitCandidateSortKey(candidate);
        String sortKey = baseSortKey;
        Integer duplicateIndex = 0;
        while (candidateBySortKey.containsKey(sortKey)) {
          duplicateIndex++;
          sortKey = baseSortKey + '|DUP=' + padSortNumber(duplicateIndex, 6);
        }
        candidateBySortKey.put(sortKey, candidate);
        candidateSortKeys.add(sortKey);
      }
      candidateSortKeys.sort();

      List<CustomDebitAllocation> allocations = new List<CustomDebitAllocation>();
      Decimal remaining = tj.TransactionAmount;

      for (String candidateSortKey : candidateSortKeys) {
        CustomDebitCandidate candidate = candidateBySortKey.get(candidateSortKey);
        if (remaining <= 0) {
          continue;
        }

        Decimal debitPoints = Math.min(candidate.availablePoints, remaining);
        if (debitPoints <= 0) {
          continue;
        }

        allocations.add(new CustomDebitAllocation(0, candidate.creditLedgerId, candidate.subtypeId, debitPoints));
        remaining -= debitPoints;
      }

      if (remaining > 0) {
        throw new CustomException(
          400,
          '포인트 잔액이 부족합니다. 사용 가능 금액: ' + availableTotal.intValue() + 'P (요청: ' + tj.TransactionAmount.intValue() + 'P)'
        );
      }

      LoyaltyLedger debitLedger = new LoyaltyLedger();
      debitLedger.EventType = 'Debit';
      debitLedger.LoyaltyProgramMemberId = tj.MemberId;
      debitLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
      debitLedger.Points = tj.TransactionAmount;
      debitLedger.TransactionJournalId = tj.Id;
      debitLedger.ActivityDate = tj.ActivityDate != null ? tj.ActivityDate : Datetime.now();
      insert debitLedger;

      List<LoyaltyLedgerTraceability> traceList = new List<LoyaltyLedgerTraceability>();
      for (CustomDebitAllocation allocation : allocations) {
        LoyaltyLedgerTraceability trace = new LoyaltyLedgerTraceability();
        trace.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
        trace.LoyaltyProgramMemberId = tj.MemberId;
        trace.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        trace.LoyaltyPgmCurrencySubtypeId = allocation.subtypeId;
        trace.CreditLoyaltyLedgerId = allocation.creditLedgerId;
        trace.DebitLoyaltyLedgerId = debitLedger.Id;
        trace.Points = allocation.points;
        traceList.add(trace);
      }
      insert traceList;

      lmc.TotalPointsRedeemed = (lmc.TotalPointsRedeemed == null ? 0 : lmc.TotalPointsRedeemed) + tj.TransactionAmount;
      update lmc;

      tj.Status = 'Processed';
      update tj;

      String memberNo;
      List<LoyaltyProgramMember> lpmList = [
        SELECT Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      if (!lpmList.isEmpty()) {
        memberNo = lpmList[0].Contact.MemberNo__c;
      }

      String saleNo;
      List<TransactionJournal> tjList = [
        SELECT Order.OrderNo__c, Order.SaleNo__c, SaleId__r.SaleNo__c
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      if (!tjList.isEmpty()) {
        if (tjList[0].Order != null && String.isNotBlank(tjList[0].Order.OrderNo__c)) {
          saleNo = tjList[0].Order.OrderNo__c;
        } else if (tjList[0].Order != null && String.isNotBlank(tjList[0].Order.SaleNo__c)) {
          saleNo = tjList[0].Order.SaleNo__c;
        } else if (tjList[0].SaleId__r != null && String.isNotBlank(tjList[0].SaleId__r.SaleNo__c)) {
          saleNo = tjList[0].SaleId__r.SaleNo__c;
        }
      }

      Set<Id> traceIds = new Set<Id>();
      for (LoyaltyLedgerTraceability trace : traceList) {
        traceIds.add(trace.Id);
      }

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT Points, LastModifiedDate, DebitLoyaltyLedgerId, LoyaltyPgmCurrencySubtype.PointTypeCode__c, CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :traceIds
        ORDER BY CreatedDate ASC, Id ASC
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      }

      List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId;
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = memberNo;
        pcDto.NO_SAL = saleNo;
        pcDto.PT_USE = llt.Points;
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);
        pdDtoList.add(pcDto);
      }
      return pdDtoList;
    } catch (ValidationException ve) {
      Database.rollback(sp);
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      Database.rollback(sp);
      throw e;
    }
  }

  private Boolean shouldExcludeCreditLedgerForCustomDebit(CustomDebitRequest req, LoyaltyLedger creditLedger) {
    // Extension point for future business rules, such as excluding credits from
    // the same sale or excluding credits after a requested business date.
    return false;
  }

  private static String buildCustomDebitCandidateSortKey(CustomDebitCandidate candidate) {
    return String.join(
      new List<String>{
        sortDateKey(candidate == null ? null : candidate.expiryDate),
        sortNumberKey(candidate == null ? null : candidate.usagePriority),
        sortDatetimeKey(candidate == null ? null : candidate.originActivityDate),
        sortDatetimeKey(candidate == null ? null : candidate.originCreatedDate),
        sortStringKey(candidate == null ? null : String.valueOf(candidate.originCreditLedgerId)),
        candidate != null && candidate.isRestoredCredit == true ? '1' : '0',
        sortDatetimeKey(candidate == null ? null : candidate.creditCreatedDate),
        sortStringKey(candidate == null ? null : String.valueOf(candidate.creditLedgerId))
      },
      '|'
    );
  }

  private static String sortDateKey(Date value) {
    return value == null ? '99991231' : String.valueOf(value).replace('-', '');
  }

  private static String sortDatetimeKey(Datetime value) {
    return value == null ? '99991231235959999' : value.formatGmt('yyyyMMddHHmmssSSS');
  }

  private static String sortNumberKey(Integer value) {
    return value == null ? '999999999' : padSortNumber(value, 9);
  }

  private static String sortStringKey(String value) {
    return String.isBlank(value) ? '~' : value;
  }

  private static String padSortNumber(Integer value, Integer width) {
    String result = String.valueOf(value == null ? 0 : value);
    while (result.length() < width) {
      result = '0' + result;
    }
    return result;
  }

  /*
  // public List<LoyaltyLedgerTraceability> debitPointsCustom(List<Map<String, Object>> reqData) {
  public List<GdSaleApiController.PointDebitDTO> debitPointsCustom(TransactionJournal tj) {
    Savepoint sp = Database.setSavepoint();
    try {
      if (reqData == null || reqData.isEmpty()) {
        throw new CustomException(400, 'reqData is required.');
      }

      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);
      Set<Id> journalIds = new Set<Id>();
      Set<String> subtypeNames = new Set<String>();
      List<CustomDebitRequest> customRequests = new List<CustomDebitRequest>();

      for (Map<String, Object> row : reqData) {
        if (row == null || row.isEmpty()) {
          throw new CustomException(400, 'reqData is required.');
        }

        String memberIdText = ValidationUtil.stringValidation(row.get('loyaltyProgramMemberId'), 'loyaltyProgramMemberId', true);
        Double pointsDouble = ValidationUtil.doubleValidation(row.get('points'), 'points', true);
        String journalIdText = ValidationUtil.stringValidation(row.get('journalId'), 'journalId', true);
        String subtypeName = ValidationUtil.stringValidation(
          row.get('loyaltyProgramCurrencySubtypeName'),
          'loyaltyProgramCurrencySubtypeName',
          false
        );
        String additionalNotes = ValidationUtil.stringValidation(row.get('additionalNotes'), 'additionalNotes', false);

        Decimal points = Decimal.valueOf(String.valueOf(pointsDouble));
        if (points <= 0) {
          throw new CustomException(400, 'points must be positive.');
        }

        CustomDebitRequest req = new CustomDebitRequest();
        req.memberId = (Id) memberIdText;
        req.points = points;
        req.journalId = (Id) journalIdText;
        req.subtypeName = subtypeName;
        req.additionalNotes = additionalNotes;
        customRequests.add(req);

        journalIds.add(req.journalId);
        if (String.isNotBlank(subtypeName)) {
          subtypeNames.add(subtypeName);
        }
      }

      Map<Id, TransactionJournal> journalById = new Map<Id, TransactionJournal>(
        [
          SELECT Id, MemberId, ActivityDate, IsDeleted__c
          FROM TransactionJournal
          WHERE Id IN :journalIds
        ]
      );
      if (journalById.size() != journalIds.size()) {
        throw new CustomException(400, 'TransactionJournal not found for one or more debit requests.');
      }

      Map<String, LoyaltyPgmCurrencySubtype> subtypeByName = new Map<String, LoyaltyPgmCurrencySubtype>();
      if (!subtypeNames.isEmpty()) {
        for (LoyaltyPgmCurrencySubtype subtype : [
          SELECT Id, Name
          FROM LoyaltyPgmCurrencySubtype
          WHERE Name IN :subtypeNames
        ]) {
          subtypeByName.put(subtype.Name, subtype);
        }
      }

      Set<Id> memberIds = new Set<Id>();
      Set<Id> requestedSubtypeIds = new Set<Id>();
      for (CustomDebitRequest req : customRequests) {
        TransactionJournal tj = journalById.get(req.journalId);
        if (tj == null || tj.IsDeleted__c == true) {
          throw new CustomException(400, 'TransactionJournal is not available. ' + req.journalId);
        }
        if (tj.MemberId != null && tj.MemberId != req.memberId) {
          throw new CustomException(400, 'TransactionJournal.MemberId does not match debit request member. ' + req.journalId);
        }
        if (String.isNotBlank(req.subtypeName)) {
          LoyaltyPgmCurrencySubtype subtype = subtypeByName.get(req.subtypeName);
          if (subtype == null) {
            throw new CustomException(400, 'LoyaltyProgramCurrencySubtype not found. ' + req.subtypeName);
          }
          req.subtypeId = subtype.Id;
          requestedSubtypeIds.add(subtype.Id);
        }
        memberIds.add(req.memberId);
      }

      List<LoyaltyLedger> creditLedgers;
      if (requestedSubtypeIds.isEmpty()) {
        creditLedgers = [
          SELECT
            Id,
            LoyaltyProgramMemberId,
            LoyaltyProgramCurrencyId,
            LoyaltyPgmCrcySubtypeId,
            LoyaltyPgmCrcySubtype.Name,
            LoyaltyPgmCrcySubtype.UsagePriorityNumber,
            Points,
            ExpiryDate,
            CreatedDate
          FROM LoyaltyLedger
          WHERE
            LoyaltyProgramMemberId IN :memberIds
            AND EventType = 'Credit'
            AND Points > 0
            AND ExpiryDate >= TODAY
            AND LoyaltyPgmCrcySubtypeId != NULL
          ORDER BY ExpiryDate ASC, LoyaltyPgmCrcySubtype.UsagePriorityNumber ASC, CreatedDate ASC, Id ASC
          LIMIT 50000
        ];
      } else {
        creditLedgers = [
          SELECT
            Id,
            LoyaltyProgramMemberId,
            LoyaltyProgramCurrencyId,
            LoyaltyPgmCrcySubtypeId,
            LoyaltyPgmCrcySubtype.Name,
            LoyaltyPgmCrcySubtype.UsagePriorityNumber,
            Points,
            ExpiryDate,
            CreatedDate
          FROM LoyaltyLedger
          WHERE
            LoyaltyProgramMemberId IN :memberIds
            AND EventType = 'Credit'
            AND Points > 0
            AND ExpiryDate >= TODAY
            AND LoyaltyPgmCrcySubtypeId != NULL
            AND LoyaltyPgmCrcySubtypeId IN :requestedSubtypeIds
          ORDER BY ExpiryDate ASC, LoyaltyPgmCrcySubtype.UsagePriorityNumber ASC, CreatedDate ASC, Id ASC
          LIMIT 50000
        ];
      }

      if (creditLedgers.isEmpty()) {
        throw new CustomException(400, '포인트 차감 실패 : 회원의 포인트 잔액은 0P 입니다.');
      }

      Set<Id> creditLedgerIds = new Set<Id>();
      for (LoyaltyLedger creditLedger : creditLedgers) {
        creditLedgerIds.add(creditLedger.Id);
      }

      Map<Id, Decimal> reducedByCreditLedgerId = new Map<Id, Decimal>();
      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId IN :memberIds
          AND CreditLoyaltyLedgerId IN :creditLedgerIds
          AND IsDeleted = FALSE
          AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
          AND (DebitLoyaltyLedgerId = NULL
          OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
        GROUP BY CreditLoyaltyLedgerId, ActionType
      ]) {
        Id creditId = (Id) ar.get('creditId');
        String actionType = (String) ar.get('actionType');
        Decimal points = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs();
        Decimal current = reducedByCreditLedgerId.containsKey(creditId) ? reducedByCreditLedgerId.get(creditId) : 0;
        if (actionType == LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION) {
          reducedByCreditLedgerId.put(creditId, Math.max(0, current - points));
        } else {
          reducedByCreditLedgerId.put(creditId, current + points);
        }
      }

      Map<Id, Decimal> availableByCreditLedgerId = new Map<Id, Decimal>();
      Map<Id, List<LoyaltyLedger>> creditLedgersByMemberId = new Map<Id, List<LoyaltyLedger>>();
      for (LoyaltyLedger creditLedger : creditLedgers) {
        Decimal reduced = reducedByCreditLedgerId.containsKey(creditLedger.Id) ? reducedByCreditLedgerId.get(creditLedger.Id) : 0;
        Decimal available = (creditLedger.Points == null ? 0 : creditLedger.Points) - reduced;
        if (available <= 0) {
          continue;
        }
        availableByCreditLedgerId.put(creditLedger.Id, available);
        if (!creditLedgersByMemberId.containsKey(creditLedger.LoyaltyProgramMemberId)) {
          creditLedgersByMemberId.put(creditLedger.LoyaltyProgramMemberId, new List<LoyaltyLedger>());
        }
        creditLedgersByMemberId.get(creditLedger.LoyaltyProgramMemberId).add(creditLedger);
      }

      List<CustomDebitAllocation> allocations = new List<CustomDebitAllocation>();
      List<LoyaltyLedger> debitLedgers = new List<LoyaltyLedger>();
      Map<Id, Decimal> totalDebitPointsByMemberId = new Map<Id, Decimal>();

      for (Integer requestIndex = 0; requestIndex < customRequests.size(); requestIndex++) {
        CustomDebitRequest req = customRequests[requestIndex];
        Decimal remaining = req.points;
        List<LoyaltyLedger> memberCreditLedgers = creditLedgersByMemberId.get(req.memberId);
        if (memberCreditLedgers != null) {
          for (LoyaltyLedger creditLedger : memberCreditLedgers) {
            if (remaining <= 0) {
              break;
            }
            if (req.subtypeId != null && creditLedger.LoyaltyPgmCrcySubtypeId != req.subtypeId) {
              continue;
            }
            if (shouldExcludeCreditLedgerForCustomDebit(req, creditLedger)) {
              continue;
            }
            Decimal available = availableByCreditLedgerId.containsKey(creditLedger.Id) ? availableByCreditLedgerId.get(creditLedger.Id) : 0;
            if (available <= 0) {
              continue;
            }
            Decimal debitPoints = Math.min(available, remaining);
            if (debitPoints <= 0) {
              continue;
            }
            allocations.add(new CustomDebitAllocation(requestIndex, creditLedger.Id, creditLedger.LoyaltyPgmCrcySubtypeId, debitPoints));
            availableByCreditLedgerId.put(creditLedger.Id, available - debitPoints);
            remaining -= debitPoints;
          }
        }
        if (remaining > 0) {
          Decimal availablePoints = req.points - remaining;
          throw new CustomException(
            400,
            '?ъ씤???붿븸??遺議깊빀?덈떎. ?ъ슜 媛??湲덉븸: ' + availablePoints.intValue() + 'P (?붿껌: ' + req.points.intValue() + 'P)'
          );
        }

        TransactionJournal tj = journalById.get(req.journalId);
        LoyaltyLedger debitLedger = new LoyaltyLedger();
        debitLedger.EventType = 'Debit';
        debitLedger.LoyaltyProgramMemberId = req.memberId;
        debitLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        if (req.subtypeId != null) {
          debitLedger.LoyaltyPgmCrcySubtypeId = req.subtypeId;
        }
        debitLedger.Points = req.points;
        debitLedger.TransactionJournalId = req.journalId;
        debitLedger.ActivityDate = tj.ActivityDate != null ? tj.ActivityDate : Datetime.now();
        if (String.isNotBlank(req.additionalNotes)) {
          debitLedger.AdditionalNotes = req.additionalNotes;
        }
        debitLedgers.add(debitLedger);

        Decimal memberTotal = totalDebitPointsByMemberId.containsKey(req.memberId) ? totalDebitPointsByMemberId.get(req.memberId) : 0;
        totalDebitPointsByMemberId.put(req.memberId, memberTotal + req.points);
      }

      if (debitLedgers.isEmpty() || allocations.isEmpty()) {
        throw new CustomException(400, '?ъ씤???붿븸??遺議깊빀?덈떎. ?ъ슜 媛??湲덉븸: 0P');
      }

      insert debitLedgers;

      List<LoyaltyLedgerTraceability> traceList = new List<LoyaltyLedgerTraceability>();
      for (CustomDebitAllocation allocation : allocations) {
        CustomDebitRequest req = customRequests[allocation.requestIndex];
        LoyaltyLedgerTraceability trace = new LoyaltyLedgerTraceability();
        trace.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
        trace.LoyaltyProgramMemberId = req.memberId;
        trace.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        trace.LoyaltyPgmCurrencySubtypeId = allocation.subtypeId;
        trace.CreditLoyaltyLedgerId = allocation.creditLedgerId;
        trace.DebitLoyaltyLedgerId = debitLedgers[allocation.requestIndex].Id;
        trace.Points = allocation.points;
        traceList.add(trace);
      }
      insert traceList;

      List<LoyaltyMemberCurrency> lmcList = [
        SELECT Id, LoyaltyMemberId, TotalPointsRedeemed
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId IN :totalDebitPointsByMemberId.keySet() AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        FOR UPDATE
      ];
      if (lmcList.size() != totalDebitPointsByMemberId.size()) {
        throw new CustomException(400, 'LoyaltyMemberCurrency not found for one or more debit request members.');
      }
      for (LoyaltyMemberCurrency lmc : lmcList) {
        Decimal points = totalDebitPointsByMemberId.get(lmc.LoyaltyMemberId);
        if (points == null || points <= 0) {
          continue;
        }
        lmc.TotalPointsRedeemed = (lmc.TotalPointsRedeemed == null ? 0 : lmc.TotalPointsRedeemed) + points;
      }
      if (!lmcList.isEmpty()) {
        update lmcList;
      }

      return [
        SELECT
          Id,
          ActionType,
          Points,
          CreditLoyaltyLedgerId,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtypeId,
          LoyaltyPgmCurrencySubtype.Name,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :traceList
        ORDER BY CreatedDate ASC, Id ASC
      ];
    } catch (ValidationException ve) {
      Database.rollback(sp);
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      Database.rollback(sp);
      throw e;
    }
  }
  */

  /**
   * * 사용 중
   * 포인트 사용
   */
  public List<GdSaleApiController.PointDebitDTO> debitPoint(TransactionJournal tj) {
    Boolean useCustomDebit = true;
    if (useCustomDebit) {
      return debitPointsCustom(tj);
    }

    // 신규 로직 (2026-04-??) Start.
    // Boolean useSaleSequenceWrapper = true;
    // if (useSaleSequenceWrapper) {
    //   // Legacy debit body is intentionally left below for quick rollback/reference.
    //   return debitPointBySaleSequence(tj);
    // }
    // 신규 로직 (2026-04-??) End.

    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      // 저널 유형 체크
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);

      // 저날 하위 유형 체크
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);
      logTiming('debitPoint.resolveJournalTypes', totalStartMs, totalStartCpu);

      tj.JournalReason__c = '1'; // 1 : 사용
      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      Integer usageDateAvailableLimit = calculatePointUsageAvailableLimit(tj);
      if (usageDateAvailableLimit != null && usageDateAvailableLimit < tj.TransactionAmount) {
        throw new CustomException(
          400,
          '포인트 잔액이 부족합니다. 사용 가능 금액: ' + usageDateAvailableLimit + 'P (요청: ' + tj.TransactionAmount.intValue() + 'P)'
        );
      }

      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      tj.PostPointBalance__c = lmcList[0].PointsBalance - tj.transactionAmount;
      logTiming('debitPoint.loadMemberCurrency', totalStartMs, totalStartCpu);

      Long insertJournalStartMs = Datetime.now().getTime();
      Integer insertJournalStartCpu = Limits.getCpuTime();
      insert tj;
      logTiming('debitPoint.insertJournal', insertJournalStartMs, insertJournalStartCpu);

      // 26.04.04 WT 수정 - 기존 코드 시작
      // List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      // Map<String, Object> req = new Map<String, Object>();

      // req.put('loyaltyProgramMemberId', tj.MemberId);
      // req.put('points', tj.transactionAmount);
      // req.put('journalId', tj.Id);
      // reqList.add(req);
      // Long debitServiceStartMs = Datetime.now().getTime();
      // Integer debitServiceStartCpu = Limits.getCpuTime();
      // List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);
      // logTiming('debitPoint.loyaltyPointServiceDebit', debitServiceStartMs, debitServiceStartCpu);
      // 26.04.04 WT 수정 - 기존 코드 끝

      // 26.04.04 WT 수정 - 수정 코드 시작
      // 1. 서브타입별 가용잔액 조회 (만료일 → 우선순위 순)
      List<LoyaltyAggrSubPointExprLedger__c> aggrList = [
        SELECT AvailablePoints__c, CurrencySubTypeId__r.Name, CurrencySubTypeId__r.UsagePriorityNumber, ExpiryDate__c
        FROM LoyaltyAggrSubPointExprLedger__c
        WHERE LoyaltyProgramMemberId__c = :tj.MemberId AND AvailablePoints__c > 0 AND ExpiryDate__c >= TODAY
        ORDER BY ExpiryDate__c ASC, CurrencySubTypeId__r.UsagePriorityNumber ASC
      ];

      // 2. 총 가용잔액 검증
      Decimal totalAvailable = 0;
      for (LoyaltyAggrSubPointExprLedger__c aggr : aggrList) {
        totalAvailable += aggr.AvailablePoints__c;
      }
      if (totalAvailable < tj.transactionAmount) {
        // [Insufficient Balance Message Fix 2026-05-07] 사용 가능 금액 / 요청 금액을 메시지에 포함.
        //   배경: 클라이언트가 잔액 부족 응답 받을 때 추가 API 호출 없이 가용액을 알 수 있도록.
        throw new CustomException(
          400,
          '포인트 잔액이 부족합니다. 사용 가능 금액: ' + totalAvailable.intValue() + 'P (요청: ' + tj.transactionAmount.intValue() + 'P)'
        );
      }

      // 3. 우선순위대로 서브타입별 차감액 분배
      Decimal remaining = tj.transactionAmount;
      Map<String, Decimal> subtypeDebitMap = new Map<String, Decimal>();

      for (LoyaltyAggrSubPointExprLedger__c aggr : aggrList) {
        if (remaining <= 0)
          break;
        String name = aggr.CurrencySubTypeId__r.Name;
        Decimal amt = Math.min(aggr.AvailablePoints__c, remaining);

        if (subtypeDebitMap.containsKey(name)) {
          subtypeDebitMap.put(name, subtypeDebitMap.get(name) + amt);
        } else {
          subtypeDebitMap.put(name, amt);
        }
        remaining -= amt;
      }

      // 4. 서브타입별 debitPoints 호출
      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      for (String subtypeName : subtypeDebitMap.keySet()) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('points', subtypeDebitMap.get(subtypeName));
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', subtypeName);
        reqList.add(req);
      }

      Long debitServiceStartMs = Datetime.now().getTime();
      Integer debitServiceStartCpu = Limits.getCpuTime();
      List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);
      logTiming('debitPoint.loyaltyPointServiceDebit', debitServiceStartMs, debitServiceStartCpu);
      // 26.04.04 WT 수정 - 수정 코드 끝

      // TJ Status Pending → Processed: afterUpdate 트리거가 LoyaltyAggrSubPointExprLedger__c 집계 업데이트
      tj.Status = 'Processed';
      update tj;

      String memberNo;
      List<LoyaltyProgramMember> lpmList = [
        SELECT Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      if (!lpmList.isEmpty()) {
        memberNo = lpmList[0].Contact.MemberNo__c;
      }

      String saleNo;
      if (String.isNotBlank(tj.OrderId)) {
        List<Order> oList = [SELECT OrderNo__c, SaleNo__c FROM Order WHERE Id = :tj.OrderId LIMIT 1];
        if (!oList.isEmpty()) {
          if (String.isNotBlank(oList[0].OrderNo__c)) {
            saleNo = oList[0].OrderNo__c;
          } else if (String.isNotBlank(oList[0].SaleNo__c)) {
            saleNo = oList[0].SaleNo__c;
          }
        }
      }
      logTiming('debitPoint.loadMemberAndOrder', totalStartMs, totalStartCpu);

      // 포인트 사용 추적 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT Points, LastModifiedDate, DebitLoyaltyLedgerId, LoyaltyPgmCurrencySubtype.PointTypeCode__c, CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      logTiming('debitPoint.loadTraceability', totalStartMs, totalStartCpu);
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      }

      List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // tj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = memberNo; // 회원 번호
        pcDto.NO_SAL = saleNo; // 주문/판매 번호
        pcDto.PT_USE = llt.Points; // 사용처리된 금액
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 사용처리된 금액

        pdDtoList.add(pcDto);
      }
      logTiming('debitPoint.total', totalStartMs, totalStartCpu);
      return pdDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 특정 포인트 포인트 차감
   *
   * @version V1
   * @author Changhwan Kim
   */
  public List<PointDebitDTO> debitSpecificPoints(TransactionJournal tj, List<LoyaltyLedger> llList) {
    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      // 저널 유형 체크
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);

      // 저날 하위 유형 체크
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

      tj.JournalReason__c = '1'; // 1 : 사용
      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      for (LoyaltyLedger ll : llList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('points', ll.Points);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ll.LoyaltyPgmCrcySubtype.Name);
        reqList.add(req);
      }

      List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);

      // 포인트 사용 추적 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      }

      List<PointDebitDTO> pdDtoList = new List<PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // tj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c; // 회원 번호
        if (String.isNotBlank(tj.Order.OrderNo__c)) {
          pcDto.NO_SAL = tj.Order.OrderNo__c; // 주문 번호
        } else if (String.isNotBlank(tj.Order.SaleNo__c)) {
          pcDto.NO_SAL = tj.Order.SaleNo__c; // 판매 번호
        }
        pcDto.PT_USE = llt.Points; // 사용처리된 금액
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 사용처리된 금액

        pdDtoList.add(pcDto);
      }
      return pdDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 특정 Credit 포인트 원장을 직접 차감한다.
   *
   * @version V2
   * @since 2026-05-09
   * @author Changhwan Kim
   */
  public List<PointDebitDTO> debitSpecificPointsV2(TransactionJournal tj, List<LoyaltyLedger> llList) {
    if (llList == null || llList.isEmpty()) {
      throw new CustomException(400, '차감 대상 포인트 원장이 존재하지 않습니다.');
    }
    Map<Id, Decimal> requestedPointsByLedgerId = new Map<Id, Decimal>();
    for (LoyaltyLedger ll : llList) {
      if (ll != null && ll.Id != null) {
        requestedPointsByLedgerId.put(ll.Id, ll.Points);
      }
    }
    return debitSpecificPointsV3(tj, requestedPointsByLedgerId);
  }

  public List<PointDebitDTO> debitSpecificPointsV3(TransactionJournal tj, Map<Id, Decimal> requestedPointsByLedgerId) {
    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }
      if (tj.MemberId == null) {
        throw new CustomException(400, 'TransactionJournal.MemberId is required');
      }
      if (requestedPointsByLedgerId == null || requestedPointsByLedgerId.isEmpty()) {
        throw new CustomException(400, '차감 대상 포인트 원장이 존재하지 않습니다.');
      }

      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION, true);
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_DEBIT, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);
      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      Set<Id> sourceLedgerIds = new Set<Id>();
      for (Id ledgerId : requestedPointsByLedgerId.keySet()) {
        if (ledgerId != null) {
          sourceLedgerIds.add(ledgerId);
        }
      }
      if (sourceLedgerIds.isEmpty()) {
        throw new CustomException(400, '차감 대상 포인트 원장 Id가 존재하지 않습니다.');
      }

      List<LoyaltyLedger> sourceLedgers = [
        SELECT
          Id,
          EventType,
          Points,
          ExpiryDate,
          LoyaltyProgramMemberId,
          LoyaltyPgmCrcySubtypeId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c
        FROM LoyaltyLedger
        WHERE Id IN :sourceLedgerIds
        ORDER BY ExpiryDate ASC, CreatedDate ASC, Id ASC
      ];
      if (sourceLedgers.isEmpty()) {
        throw new CustomException(400, '차감 대상 포인트 원장을 찾을 수 없습니다.');
      }

      Set<Id> creditLedgerIds = new Set<Id>();
      for (LoyaltyLedger ll : sourceLedgers) {
        if (ll.EventType != 'Credit') {
          throw new CustomException(400, '차감 대상은 Credit 포인트 원장만 가능합니다. ' + ll.Id);
        }
        if (ll.LoyaltyProgramMemberId != tj.MemberId) {
          throw new CustomException(400, '차감 대상 포인트 원장의 회원이 요청 회원과 다릅니다. ' + ll.Id);
        }
        if (ll.Points == null || ll.Points <= 0) {
          continue;
        }
        if (ll.LoyaltyPgmCrcySubtypeId == null) {
          throw new CustomException(400, '차감 대상 포인트 원장의 포인트 유형이 없습니다. ' + ll.Id);
        }
        creditLedgerIds.add(ll.Id);
      }

      // 기존 로직 Start
      // Map<Id, Decimal> reductionByCreditLedgerId = new Map<Id, Decimal>();
      // if (!creditLedgerIds.isEmpty()) {
      //   for (AggregateResult ar : [
      //     SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
      // 기존 로직 End
      // 신규 로직 Start
      Map<Id, Decimal> reductionByCreditLedgerId = new Map<Id, Decimal>();
      Map<Id, Decimal> cancellationByCreditLedgerId = new Map<Id, Decimal>();
      if (!creditLedgerIds.isEmpty()) {
        for (AggregateResult ar : [
          SELECT CreditLoyaltyLedgerId creditId, ActionType actionType, SUM(Points) totalPoints
          // 신규 로직 End
          FROM LoyaltyLedgerTraceability
          WHERE
            // 기존 로직 Start
            // LoyaltyProgramMemberId = :tj.MemberId
            //   AND CreditLoyaltyLedgerId IN :creditLedgerIds
            //   AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
            //   AND (DebitLoyaltyLedgerId = NULL
            //     OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
            // 기존 로직 End
            // 신규 로직 Start
            LoyaltyProgramMemberId = :tj.MemberId
            AND CreditLoyaltyLedgerId IN :creditLedgerIds
            AND IsDeleted = FALSE
            AND ActionType IN ('Debit', 'DebitCancellation', 'CreditCancellation')
            AND (DebitLoyaltyLedgerId = NULL
            OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE)
          // 신규 로직 End
          GROUP BY CreditLoyaltyLedgerId, ActionType
          // 기존 로직 Start
          //     ]) {
          //     Id creditId = (Id) ar.get('creditId');
          //     String actionType = (String) ar.get('actionType');
          //     Decimal totalPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs();
          //     Decimal current = reductionByCreditLedgerId.containsKey(creditId) ? reductionByCreditLedgerId.get(creditId) : 0;
          //     if (actionType == 'DebitCancellation') {
          //       reductionByCreditLedgerId.put(creditId, Math.max(0, current - totalPoints));
          //     } else {
          //       reductionByCreditLedgerId.put(creditId, current + totalPoints);
          //     }
          //   }
          // }
          // 기존 로직 End
          // 신규 로직 Start
        ]) {
          Id creditId = (Id) ar.get('creditId');
          String actionType = (String) ar.get('actionType');
          Decimal totalPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs();
          if (actionType == 'DebitCancellation') {
            Decimal currentCancellation = cancellationByCreditLedgerId.containsKey(creditId) ? cancellationByCreditLedgerId.get(creditId) : 0;
            cancellationByCreditLedgerId.put(creditId, currentCancellation + totalPoints);
          } else {
            Decimal current = reductionByCreditLedgerId.containsKey(creditId) ? reductionByCreditLedgerId.get(creditId) : 0;
            reductionByCreditLedgerId.put(creditId, current + totalPoints);
          }
        }
        for (Id creditId : cancellationByCreditLedgerId.keySet()) {
          Decimal reduced = reductionByCreditLedgerId.containsKey(creditId) ? reductionByCreditLedgerId.get(creditId) : 0;
          reductionByCreditLedgerId.put(creditId, Math.max(0, reduced - cancellationByCreditLedgerId.get(creditId)));
        }
      }
      // 신규 로직 End

      tj.JournalReason__c = '1';
      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';
      insert tj;

      List<LoyaltyLedger> debitLedgers = new List<LoyaltyLedger>();
      List<Id> traceCreditLedgerIds = new List<Id>();
      List<Id> traceSubtypeIds = new List<Id>();
      List<Decimal> tracePoints = new List<Decimal>();

      for (LoyaltyLedger sourceLedger : sourceLedgers) {
        if (sourceLedger.Points == null || sourceLedger.Points <= 0) {
          continue;
        }
        Decimal alreadyReduced = reductionByCreditLedgerId.containsKey(sourceLedger.Id) ? reductionByCreditLedgerId.get(sourceLedger.Id) : 0;
        Decimal availablePoints = sourceLedger.Points - alreadyReduced;
        if (availablePoints <= 0) {
          continue;
        }
        Decimal requestedPoints = requestedPointsByLedgerId.containsKey(sourceLedger.Id)
          ? requestedPointsByLedgerId.get(sourceLedger.Id)
          : sourceLedger.Points;
        Decimal debitPoints = Math.min(availablePoints, requestedPoints);
        if (debitPoints <= 0) {
          continue;
        }

        LoyaltyLedger debitLedger = new LoyaltyLedger();
        debitLedger.LoyaltyProgramMemberId = tj.MemberId;
        debitLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        debitLedger.TransactionJournalId = tj.Id;
        debitLedger.LoyaltyPgmCrcySubtypeId = sourceLedger.LoyaltyPgmCrcySubtypeId;
        debitLedger.Points = debitPoints;
        debitLedger.EventType = 'Debit';
        debitLedger.ActivityDate = tj.ActivityDate != null ? tj.ActivityDate : Datetime.now();
        debitLedgers.add(debitLedger);

        traceCreditLedgerIds.add(sourceLedger.Id);
        traceSubtypeIds.add(sourceLedger.LoyaltyPgmCrcySubtypeId);
        tracePoints.add(debitPoints);
      }

      if (debitLedgers.isEmpty()) {
        throw new CustomException(400, '차감 가능한 포인트 원장 잔액이 존재하지 않습니다.');
      }

      insert debitLedgers;

      List<LoyaltyLedgerTraceability> traceList = new List<LoyaltyLedgerTraceability>();
      Decimal totalDebitPoints = 0;
      for (Integer i = 0; i < debitLedgers.size(); i++) {
        LoyaltyLedgerTraceability trace = new LoyaltyLedgerTraceability();
        trace.ActionType = 'Debit';
        trace.LoyaltyProgramMemberId = tj.MemberId;
        trace.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        trace.LoyaltyPgmCurrencySubtypeId = traceSubtypeIds[i];
        trace.CreditLoyaltyLedgerId = traceCreditLedgerIds[i];
        trace.DebitLoyaltyLedgerId = debitLedgers[i].Id;
        trace.Points = tracePoints[i];
        traceList.add(trace);
        totalDebitPoints += tracePoints[i];
      }
      insert traceList;

      List<LoyaltyMemberCurrency> lmcList = [
        SELECT Id, TotalPointsRedeemed
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      if (!lmcList.isEmpty()) {
        LoyaltyMemberCurrency lmc = lmcList[0];
        lmc.TotalPointsRedeemed = (lmc.TotalPointsRedeemed == null ? 0 : lmc.TotalPointsRedeemed) + totalDebitPoints;
        update lmc;
      }

      tj.TransactionAmount = totalDebitPoints;
      tj.Status = 'Processed';
      update tj;

      // List<LoyaltyLedgerTraceability> lltList = [
      //   SELECT
      //     LoyaltyPgmCurrencySubtype.Name,
      //     Points,
      //     CreditLoyaltyLedger.ExpiryDate,
      //     LoyaltyProgramMember.Contact.MemberNo__c,
      //     LastModifiedDate,
      //     DebitLoyaltyLedgerId,
      //     LoyaltyPgmCurrencySubtype.PointTypeCode__c,
      //     CreditLoyaltyLedgerId,
      //     DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
      //     DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c
      //   FROM LoyaltyLedgerTraceability
      //   WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
      //   LIMIT 100
      // ];
      // if (lltList.isEmpty()) {
      //   throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      // }

      List<PointDebitDTO> pdDtoList = new List<PointDebitDTO>();
      // for (LoyaltyLedgerTraceability llt : lltList) {
      //   PointDebitDTO pcDto = new PointDebitDTO();
      //   pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
      //   pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId;
      //   pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
      //   pcDto.CD_RESON = tj.JournalReason__c;
      //   pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c;
      //   if (llt.DebitLoyaltyLedger != null &&
      //       llt.DebitLoyaltyLedger.TransactionJournal != null &&
      //       llt.DebitLoyaltyLedger.TransactionJournal.Order != null &&
      //       String.isNotBlank(llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c)) {
      //     pcDto.NO_SAL = llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c;
      //   } else if (llt.DebitLoyaltyLedger != null &&
      //       llt.DebitLoyaltyLedger.TransactionJournal != null &&
      //       llt.DebitLoyaltyLedger.TransactionJournal.Order != null &&
      //       String.isNotBlank(llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c)) {
      //     pcDto.NO_SAL = llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c;
      //   }
      //   pcDto.PT_USE = llt.Points;
      //   pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);
      //   pdDtoList.add(pcDto);
      // }
      return pdDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 구매 시 포인트 지급
   */
  public List<PointCreditDTO> creditPointsOnPurchase(List<TransactionJournal> data) {
    try {
      if (data.isEmpty()) {
        return null;
      }

      // [Zero Accrual Skip Fix 2026-05-07] 적립 대상 금액이 0 이하면 TJ insert 전 early return.
      //   배경: 호출자가 PaymentMethod=20/81/90/93 이거나 Amt=0 인 TJ 만 넘기는 케이스 존재.
      //         예: deleteReturnDeposit 의 Sale Deposit Reversal (PaymentMethod=93) 환불 입금 삭제 시
      //         linkedAccrualReversalTjList 빈 분기에서 호출됨 (GdReturnDepositServiceImpl.cls:965).
      //   기존 동작: TJ insert + LMS API 호출 → 0P Purchase Accrual TJ + 0P LL 발급
      //         → 회원도움창 적립 내역에 0/0/0 행 노출 (회원 193001000334 케이스).
      //   수정 후: 사전 계산하여 eligibleAmount <= 0 이면 null 반환 → 0P TJ/LL 미발생.
      //   안전성: 같은 클래스의 creditPointsOnPurchaseByGrade(:3117) /
      //           cancelPointsCreditedOnPurchase(:4944) 가 이미 같은 early return 패턴 적용 → 일관성.
      //           양수 eligibleAmount 케이스는 기존 동작 100% 유지.
      Decimal eligibleAmount = 0;
      for (TransactionJournal v : data) {
        if (v == null) {
          continue;
        }
        if (v.PaymentMethod == '20' || v.PaymentMethod == '81' || v.PaymentMethod == '90' || v.PaymentMethod == '93') {
          continue;
        }
        if (v.TransactionAmount == null || v.TransactionAmount == 0) {
          continue;
        }
        eligibleAmount += v.TransactionAmount;
      }
      if (eligibleAmount <= 0) {
        return null;
      }

      // 저널 유형 체크
      List<JournalType> jtListByCreditPoint = [SELECT Id FROM journalType WHERE Name = :JOURNAL_TYPE_NAME_ACCRUAL LIMIT 1];
      if (jtListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 타입(포인트 지급)이 없습니다. ' + JOURNAL_TYPE_NAME_ACCRUAL);
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstListByCreditPoint = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL AND JournalTypeId = :jtListByCreditPoint[0].Id
        LIMIT 1
      ];
      if (jstListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 하위 타입(포인트 지급)이 없습니다. ' + JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);
      }

      // 계층 보상 가져오기
      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, '해당 회원의 등급 보상이 없습니다. ' + data[0].MemberId);
      }

      Id purchaseAccrualOrderId = resolvePurchaseAccrualOrderId(data[0]);
      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(purchaseAccrualOrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(purchaseAccrualOrderId);

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = purchaseAccrualDatetime;
      tj.JournalDate = purchaseAccrualDatetime;
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = purchaseAccrualOrderId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtListByCreditPoint[0].Id;
      tj.JournalSubTypeId = jstListByCreditPoint[0].Id;

      Long insertJournalStartMs = Datetime.now().getTime();
      Integer insertJournalStartCpu = Limits.getCpuTime();
      insert tj;
      logTiming('creditPointsOnPurchase.insertJournal', insertJournalStartMs, insertJournalStartCpu);

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Decimal totalAmount = 0;
      for (TransactionJournal v : data) {
        if (v.PaymentMethod == '20' || v.PaymentMethod == '81' || v.PaymentMethod == '90' || v.PaymentMethod == '93') {
          continue;
        }
        if (v.TransactionAmount == null || v.TransactionAmount == 0) {
          continue;
        }

        totalAmount += v.TransactionAmount;
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (totalAmount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        req.put('pointsExpirationDate', String.valueOf(purchaseAccrualExpirationDate));
        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      String memberNo = resolveMemberNoFromTransactionJournal(tj.Id);

      List<PointCreditDTO> pcDtoList = buildPointCreditDtos(llList, memberNo, '01');
      Decimal totalPoints = sumPositiveLedgerPoints(llList);
      tj.TransactionAmount = totalPoints;
      update tj;

      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 구매 시 포인트 지급 V2
   */
  public List<PointCreditDTO> creditPointsOnPurchaseV2(List<TransactionJournal> data, Decimal excludeAmount) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      TimingCheckpoint timingCheckpoint;
      Savepoint sp1 = Database.setSavepoint();

      if (data.isEmpty()) {
        return null;
      }

      // 프로모션에서 제외할 포인트 유형 코드 추출
      Set<String> excludedPointTypeCodeSet = new Set<String>();
      System.debug('data[0].PromotionId : ' + data[0].PromotionId);
      List<Promotion> pList = [SELECT Id, PointTypeCode__c FROM Promotion WHERE Id = :data[0].PromotionId LIMIT 1];
      if (!pList.isEmpty()) {
        if (String.isNotBlank(pList[0].PointTypeCode__c)) {
          for (String code : pList[0].PointTypeCode__c.split(';')) {
            if (String.isNotBlank(code)) {
              excludedPointTypeCodeSet.add(code.trim());
            }
          }
        }
      }
      timingCheckpoint = logTimingWithDelta('creditPointsOnPurchaseV2.promotionSetup', totalStartMs, totalStartCpu, timingCheckpoint);

      // System.debug('data[0].Promotion.PointTypeCode__c : ' + data[0].Promotion.PointTypeCode__c);
      // if (data[0].PromotionId != null && String.isNotBlank(data[0].Promotion.PointTypeCode__c)) {
      //   for (String code : data[0].Promotion.PointTypeCode__c.split(';')) {
      //     if (String.isNotBlank(code)) {
      //       excludedPointTypeCodeSet.add(code.trim());
      //     }
      //   }
      // }

      // 저널 유형 체크
      List<JournalType> jtListByCreditPoint = [SELECT Id FROM journalType WHERE Name = :JOURNAL_TYPE_NAME_ACCRUAL LIMIT 1];
      if (jtListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 타입(포인트 지급)이 없습니다. ' + JOURNAL_TYPE_NAME_ACCRUAL);
      }

      // 저널 하위 유형 체크
      List<JournalSubType> jstListByCreditPoint = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL AND JournalTypeId = :jtListByCreditPoint[0].Id
        LIMIT 1
      ];
      if (jstListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 하위 타입(포인트 지급)이 없습니다. ' + JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);
      }

      // 계층 보상 가져오기
      timingCheckpoint = logTimingWithDelta('creditPointsOnPurchaseV2.resolveJournalTypes', totalStartMs, totalStartCpu, timingCheckpoint);
      List<LoyaltyTierBenefit> rawLtbList = [
        SELECT
          Benefit.PurchasePointRate__c,
          Benefit.LoyaltyPgmCurrencySubtypeId__r.Name,
          Benefit.LoyaltyPgmCurrencySubtypeId__c,
          Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];

      // 프로모션 포인트 유형 코드와 동일한 보상 제외
      List<LoyaltyTierBenefit> ltbList = new List<LoyaltyTierBenefit>();
      for (LoyaltyTierBenefit ltb : rawLtbList) {
        String benefitPointTypeCode = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;

        if (String.isBlank(benefitPointTypeCode) || !excludedPointTypeCodeSet.contains(benefitPointTypeCode.trim())) {
          ltbList.add(ltb);
        }
      }
      timingCheckpoint = logTimingWithDelta('creditPointsOnPurchaseV2.loadTierBenefits', totalStartMs, totalStartCpu, timingCheckpoint);

      if (ltbList.isEmpty()) {
        return null;
      }

      Id purchaseAccrualOrderId = resolvePurchaseAccrualOrderId(data[0]);
      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(purchaseAccrualOrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(purchaseAccrualOrderId);

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = purchaseAccrualDatetime;
      tj.JournalDate = purchaseAccrualDatetime;
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = purchaseAccrualOrderId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtListByCreditPoint[0].Id;
      tj.JournalSubTypeId = jstListByCreditPoint[0].Id;
      if (data[0].PromotionId != null && String.isNotBlank(data[0].PromotionId)) {
        tj.PromotionId = data[0].PromotionId;
      }

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      Decimal totalAmount = calculateEligibleAccrualAmount(data, excludeAmount);
      timingCheckpoint = logTimingWithDelta('creditPointsOnPurchaseV2.calculateAmount', totalStartMs, totalStartCpu, timingCheckpoint);
      if (totalAmount <= 0) {
        Database.rollback(sp1);
        return null;
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (totalAmount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        reqList.add(req);
      }

      Long creditServiceStartMs = Datetime.now().getTime();
      Integer creditServiceStartCpu = Limits.getCpuTime();
      LoyaltyPointService.creditPoints(reqList);
      logTiming('creditPointsOnPurchaseV2.loyaltyPointServiceCredit', creditServiceStartMs, creditServiceStartCpu);
      timingCheckpoint = logTimingWithDelta(
        'creditPointsOnPurchaseV2.loyaltyPointServiceCredit.total',
        totalStartMs,
        totalStartCpu,
        timingCheckpoint
      );

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      timingCheckpoint = logTimingWithDelta('creditPointsOnPurchaseV2.loadLoyaltyLedger', totalStartMs, totalStartCpu, timingCheckpoint);

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      if (lpmList.isEmpty() || lpmList[0].Contact.MemberNo__c == null) {
        throw new CustomException(500, 'member contact is null');
      }
      // String memberNo = ValidationUtil.stringValidationEx(lpmList[0].Contact.MemberNo__c, 'MemberNo__c', true, false);
      String memberNo = lpmList[0].Contact.MemberNo__c;
      timingCheckpoint = logTimingWithDelta('creditPointsOnPurchaseV2.loadJournalAndMember', totalStartMs, totalStartCpu, timingCheckpoint);

      Decimal totalPoints = 0;

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // 생성(지급)된 레저 ID 전달
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate.addDays(1)); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }

      tj.TransactionAmount = totalPoints;
      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      tj.PostPointBalance__c = lmcList[0].PointsBalance;

      Long updateJournalStartMs = Datetime.now().getTime();
      Integer updateJournalStartCpu = Limits.getCpuTime();
      update tj;
      logTiming('creditPointsOnPurchaseV2.updateJournal', updateJournalStartMs, updateJournalStartCpu);
      timingCheckpoint = logTimingWithDelta('creditPointsOnPurchaseV2.updateJournal.total', totalStartMs, totalStartCpu, timingCheckpoint);

      logTimingWithDelta('creditPointsOnPurchaseV2.total', totalStartMs, totalStartCpu, timingCheckpoint);
      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 26.05.08 CS - [옵션 C — 옛 일자 신규 판매 전용] 구매 시 포인트 지급 (기타포인트 redirect)
   *
   * 표준 creditPointsOnPurchaseV2 의 99% 동일 동작 + 단 3가지 차이:
   *   1. 등급 보상 중 PT='01' (구매포인트) 비율만 사용 (사은포인트 등 제외)
   *   2. 적립 SubType 을 '기타포인트' 로 강제 redirect
   *   3. 부모 TJ.AdditionalNotes 에 옵션 C 마커 추가 (운영 추적용)
   *
   * 만료일 / 적립 일자 / LL/LLT 생성 / 트리거 LASEL 자동 생성 / TJ.PostPointBalance 업데이트 모두 표준 동일.
   *
   * 호출 조건 (호출자가 보장):
   *   - GdMigrationUtil.shouldApplyOptionCBranchByOrderId(data[0].OrderId) == true
   *   - 즉 IsEnabled=true + Order.EffectiveDate < OpenDate
   *
   * 안전성:
   *   - DML 모두 try/catch
   *   - 표준 메서드와 격리 (코드 복제, 표준 0줄 수정)
   */
  public List<PointCreditDTO> creditEtcPointsOnPurchaseForOldSale(List<TransactionJournal> data, Decimal excludeAmount) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      Savepoint sp1 = Database.setSavepoint();

      if (data == null || data.isEmpty()) {
        return null;
      }

      // 1. 프로모션에서 제외할 PointTypeCode 추출 (표준과 동일)
      Set<String> excludedPointTypeCodeSet = new Set<String>();
      List<Promotion> pList = [SELECT Id, PointTypeCode__c FROM Promotion WHERE Id = :data[0].PromotionId LIMIT 1];
      if (!pList.isEmpty() && String.isNotBlank(pList[0].PointTypeCode__c)) {
        for (String code : pList[0].PointTypeCode__c.split(';')) {
          if (String.isNotBlank(code)) {
            excludedPointTypeCodeSet.add(code.trim());
          }
        }
      }

      // 2. JournalType + JournalSubType 조회 (표준과 동일 — Purchase Accrual)
      List<JournalType> jtListByCreditPoint = [SELECT Id FROM JournalType WHERE Name = :JOURNAL_TYPE_NAME_ACCRUAL LIMIT 1];
      if (jtListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 타입(포인트 지급)이 없습니다. ' + JOURNAL_TYPE_NAME_ACCRUAL);
      }
      List<JournalSubType> jstListByCreditPoint = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL AND JournalTypeId = :jtListByCreditPoint[0].Id
        LIMIT 1
      ];
      if (jstListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '저널 하위 타입(포인트 지급)이 없습니다. ' + JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL);
      }

      // 3. 회원 등급 LoyaltyTierBenefit 조회 (표준과 동일)
      List<LoyaltyTierBenefit> rawLtbList = [
        SELECT
          Benefit.PurchasePointRate__c,
          Benefit.LoyaltyPgmCurrencySubtypeId__r.Name,
          Benefit.LoyaltyPgmCurrencySubtypeId__c,
          Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];

      // 4. ★ 차이점 1: PT='01' (구매포인트) 비율만 추출 + 프로모션 제외 PT 적용
      List<LoyaltyTierBenefit> ltbList = new List<LoyaltyTierBenefit>();
      for (LoyaltyTierBenefit ltb : rawLtbList) {
        if (ltb.Benefit == null || ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r == null) {
          continue;
        }
        String benefitPointTypeCode = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;
        if (!'01'.equals(benefitPointTypeCode)) {
          continue; // 구매포인트(PT=01) 외 모두 제외
        }
        if (String.isNotBlank(benefitPointTypeCode) && excludedPointTypeCodeSet.contains(benefitPointTypeCode.trim())) {
          continue; // 프로모션이 PT=01 을 제외 명시한 경우
        }
        ltbList.add(ltb);
      }

      if (ltbList.isEmpty()) {
        return null;
      }

      // 5. ★ 차이점 2: 기타포인트 SubType 조회 (적립 redirect 대상)
      List<LoyaltyPgmCurrencySubtype> etcSubtypeList = [SELECT Id, Name FROM LoyaltyPgmCurrencySubtype WHERE PointTypeCode__c = '04' LIMIT 1];
      if (etcSubtypeList.isEmpty()) {
        throw new CustomException(400, '기타포인트 SubType (PT=04) 이 존재하지 않습니다.');
      }
      String etcSubtypeName = etcSubtypeList[0].Name;
      Id etcSubtypeId = etcSubtypeList[0].Id;

      // 6. 적립 일자 + 만료일 결정 (표준과 동일)
      Id purchaseAccrualOrderId = resolvePurchaseAccrualOrderId(data[0]);
      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(purchaseAccrualOrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(purchaseAccrualOrderId);

      // 7. 부모 TJ insert (표준과 동일 + ★ 차이점 3: AdditionalNotes 마커)
      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = purchaseAccrualDatetime;
      tj.JournalDate = purchaseAccrualDatetime;
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = purchaseAccrualOrderId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtListByCreditPoint[0].Id;
      tj.JournalSubTypeId = jstListByCreditPoint[0].Id;
      tj.AdditionalNotes__c = 'OPTC_OLD_SALE_ETC_ACCRUAL';
      if (data[0].PromotionId != null && String.isNotBlank(data[0].PromotionId)) {
        tj.PromotionId = data[0].PromotionId;
      }

      insert tj;

      // 8. 적립 가능 금액 계산 (표준과 동일)
      Decimal totalAmount = calculateEligibleAccrualAmount(data, excludeAmount);
      if (totalAmount <= 0) {
        Database.rollback(sp1);
        return null;
      }

      // 9. reqList 구성 — ★ 차이점 2 적용: SubtypeName='기타포인트' 강제
      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      for (LoyaltyTierBenefit ltb : ltbList) {
        Decimal points = (totalAmount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP);
        if (points <= 0) {
          continue;
        }
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', etcSubtypeName); // ← '기타포인트' redirect
        req.put('points', points);
        req.put('pointsExpirationDate', String.valueOf(purchaseAccrualExpirationDate));
        // audit: 원본 LTB 정보 보존 (어떤 등급 PT='01' 비율을 썼는지 추적)
        req.put(
          'additionalNotes',
          'OPTC_OLD_SALE|origin=' +
            ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|originSubtypeId=' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|rate=' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c) +
            '|redirectTo=' +
            etcSubtypeName
        );
        reqList.add(req);
      }

      if (reqList.isEmpty()) {
        Database.rollback(sp1);
        return null;
      }

      // 10. LoyaltyPointService.creditPoints (표준과 동일 — LL/LLT 자동 생성, 트리거가 LASEL 처리)
      LoyaltyPointService.creditPoints(reqList);

      // 11. 생성된 LL 조회 (표준과 동일)
      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      // 12. 회원 정보 (PointCreditDTO 빌드용)
      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      if (lpmList.isEmpty() || lpmList[0].Contact.MemberNo__c == null) {
        throw new CustomException(500, 'member contact is null');
      }
      String memberNo = lpmList[0].Contact.MemberNo__c;

      // 13. PointCreditDTO 빌드 (표준과 동일)
      Decimal totalPoints = 0;
      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id;
        pcDto.CD_TYPE_POINT = '04'; // 기타포인트
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points;
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate);
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate);
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate);
        pcDto.DT_DESTROY_PLAN = ll.ExpiryDate == null ? null : String.valueOf(ll.ExpiryDate.addDays(1));
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate);
        pcDto.CD_TYPE_SAVE = ll.EventType;
        pcDto.TX_REMARK = ll.AdditionalNotes;
        pcDtoList.add(pcDto);

        if (ll.Points != null && ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }

      // 14. TJ.PostPointBalance 업데이트 (표준과 동일)
      tj.TransactionAmount = totalPoints;
      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      if (!lmcList.isEmpty()) {
        tj.PostPointBalance__c = lmcList[0].PointsBalance;
      }
      update tj;

      logTiming('creditEtcPointsOnPurchaseForOldSale.total', totalStartMs, totalStartCpu);
      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 프로모션 포인트 지급
   */
  public List<PointCreditDTO> creditPromotionPointsOnPurchase(List<TransactionJournal> data, Decimal excludeAmount) {
    try {
      Long totalStartMs = Datetime.now().getTime();
      Integer totalStartCpu = Limits.getCpuTime();
      Savepoint sp1 = Database.setSavepoint();

      if (data == null || data.isEmpty() || data[0].PromotionId == null) {
        return null;
      }

      List<PromotionPointLimit__c> pointLimitList = [
        SELECT Type__c, Value__c, LoyaltyPgmCurrencySubtypeId__c, LoyaltyPgmCurrencySubtypeId__r.Name
        FROM PromotionPointLimit__c
        WHERE PromotionId__c = :data[0].PromotionId AND Type__c IN ('none', 'rate')
      ];
      if (pointLimitList.isEmpty()) {
        return null;
      }
      logTiming('creditPromotionPointsOnPurchase.loadPointLimits', totalStartMs, totalStartCpu);

      Map<Id, Integer> targetSubtypeCountMap = new Map<Id, Integer>();
      Boolean hasNoneTypeLimit = false;
      for (PromotionPointLimit__c pointLimit : pointLimitList) {
        if ('none'.equals(pointLimit.Type__c) && pointLimit.LoyaltyPgmCurrencySubtypeId__c != null) {
          hasNoneTypeLimit = true;
          Id subtypeId = pointLimit.LoyaltyPgmCurrencySubtypeId__c;
          targetSubtypeCountMap.put(subtypeId, (targetSubtypeCountMap.containsKey(subtypeId) ? targetSubtypeCountMap.get(subtypeId) : 0) + 1);
        }
      }
      if (targetSubtypeCountMap.isEmpty() && !hasRatePromotionPointLimit(pointLimitList)) {
        return null;
      }

      List<JournalType> jtListByCreditPoint = [SELECT Id FROM JournalType WHERE Name = :JOURNAL_TYPE_NAME_ACCRUAL LIMIT 1];
      if (jtListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 포인트 지급 거래 유형입니다. ' + JOURNAL_TYPE_NAME_ACCRUAL);
      }

      List<JournalSubType> jstListByCreditPoint = [
        SELECT Id
        FROM JournalSubType
        WHERE Name = :JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL AND JournalTypeId = :jtListByCreditPoint[0].Id
        LIMIT 1
      ];
      if (jstListByCreditPoint.isEmpty()) {
        throw new CustomException(400, '존재하지 않는 구매 포인트 지급 거래 하위 유형입니다. ' + JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL);
      }
      logTiming('creditPromotionPointsOnPurchase.resolveJournalTypes', totalStartMs, totalStartCpu);

      LoyaltyPgmCurrencySubtype eventPointSubtype;
      if (hasNoneTypeLimit) {
        List<LoyaltyPgmCurrencySubtype> eventPointSubtypeList = [
          SELECT Id, Name
          FROM LoyaltyPgmCurrencySubtype
          WHERE Name = :POINT_SUB_TYPE_NAME_EVENT
          LIMIT 1
        ];
        if (eventPointSubtypeList.isEmpty()) {
          throw new CustomException(400, POINT_SUB_TYPE_NAME_EVENT + '가 존재하지 않습니다.');
        }
        eventPointSubtype = eventPointSubtypeList[0];
      }

      List<LoyaltyTierBenefit> rawLtbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__c
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :data[0].MemberId)
      ];
      logTiming('creditPromotionPointsOnPurchase.loadTierBenefits', totalStartMs, totalStartCpu);

      Decimal totalAmount = calculateEligibleAccrualAmount(data, excludeAmount);
      logTiming('creditPromotionPointsOnPurchase.calculateAmount', totalStartMs, totalStartCpu);
      if (totalAmount <= 0) {
        Database.rollback(sp1);
        return null;
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();
      if (hasNoneTypeLimit) {
        for (LoyaltyTierBenefit ltb : rawLtbList) {
          Id benefitSubtypeId = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c;
          Decimal rate = ltb.Benefit.PurchasePointRate__c;
          Integer subtypeCount = (benefitSubtypeId == null || !targetSubtypeCountMap.containsKey(benefitSubtypeId))
            ? 0
            : targetSubtypeCountMap.get(benefitSubtypeId);
          if (benefitSubtypeId == null || rate == null || rate <= 0 || subtypeCount <= 0) {
            continue;
          }

          Decimal points = (totalAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);
          if (points <= 0) {
            continue;
          }

          for (Integer i = 0; i < subtypeCount; i++) {
            Map<String, Object> req = new Map<String, Object>();
            req.put('loyaltyProgramMemberId', data[0].MemberId);
            req.put('loyaltyProgramCurrencySubtypeName', eventPointSubtype.Name);
            req.put('points', points);
            req.put('additionalNotes', eventPointSubtype.Name + '|' + String.valueOf(eventPointSubtype.Id) + '|' + String.valueOf(rate));
            reqList.add(req);
          }
        }
      }

      for (PromotionPointLimit__c pointLimit : pointLimitList) {
        if (!'rate'.equals(pointLimit.Type__c) || pointLimit.LoyaltyPgmCurrencySubtypeId__c == null) {
          continue;
        }

        Decimal rate = pointLimit.Value__c;
        if (rate == null || rate <= 0) {
          continue;
        }

        Decimal points = (totalAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);
        if (points <= 0) {
          continue;
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', data[0].MemberId);
        req.put('loyaltyProgramCurrencySubtypeName', pointLimit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', points);
        req.put(
          'additionalNotes',
          pointLimit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(pointLimit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(rate)
        );
        reqList.add(req);
      }

      if (reqList.isEmpty()) {
        Database.rollback(sp1);
        return null;
      }

      Id purchaseAccrualOrderId = resolvePurchaseAccrualOrderId(data[0]);
      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(purchaseAccrualOrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(purchaseAccrualOrderId);

      TransactionJournal tj = new TransactionJournal();
      tj.ActivityDate = purchaseAccrualDatetime;
      tj.JournalDate = purchaseAccrualDatetime;
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = purchaseAccrualOrderId;
      tj.PromotionId = data[0].PromotionId;
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      tj.JournalTypeId = jtListByCreditPoint[0].Id;
      tj.JournalSubTypeId = jstListByCreditPoint[0].Id;

      insert tj;

      for (Map<String, Object> req : reqList) {
        req.put('journalId', tj.Id);
        req.put('pointsExpirationDate', String.valueOf(purchaseAccrualExpirationDate));
      }

      Long creditServiceStartMs = Datetime.now().getTime();
      Integer creditServiceStartCpu = Limits.getCpuTime();
      LoyaltyPointService.creditPoints(reqList);
      logTiming('creditPromotionPointsOnPurchase.loyaltyPointServiceCredit', creditServiceStartMs, creditServiceStartCpu);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      logTiming('creditPromotionPointsOnPurchase.loadLoyaltyLedger', totalStartMs, totalStartCpu);

      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      if (lpmList.isEmpty() || lpmList[0].Contact.MemberNo__c == null) {
        throw new CustomException(500, 'member contact is null');
      }

      Decimal totalPoints = 0;
      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id;
        pcDto.CD_TYPE_POINT = ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
        pcDto.NO_MBR = lpmList[0].Contact.MemberNo__c;
        pcDto.PT_TARGET = ll.Points;
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate);
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate);
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate);
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate.addDays(1));
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate);
        pcDto.CD_TYPE_SAVE = ll.EventType;
        pcDto.TX_REMARK = ll.AdditionalNotes;
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }

      tj.TransactionAmount = totalPoints;
      List<LoyaltyMemberCurrency> lmcList = [
        SELECT LoyaltyMemberId, PointsBalance, LoyaltyProgramCurrency.Name
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      if (!lmcList.isEmpty()) {
        tj.PostPointBalance__c = lmcList[0].PointsBalance;
      }
      update tj;
      logTiming('creditPromotionPointsOnPurchase.total', totalStartMs, totalStartCpu);
      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * (특정 등급의 비율에 따른) 구매 시 포인트 지급
   */
  public List<PointCreditDTO> creditPointsOnPurchaseByGrade(Map<String, Object> reqData) {
    List<PointCreditDTO> result = new List<PointCreditDTO>();
    try {
      String grade = ValidationUtil.stringValidationEx(reqData.get('Grade__c'), 'Grade__c', true, false);
      TransactionJournal tj = (TransactionJournal) ValidationUtil.sObjectValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String additionalNotes = ValidationUtil.stringValidation(reqData.get('AdditionalNotes__c'), 'AdditionalNotes__c', true);
      Decimal adjustAmount = ValidationUtil.decimalValidation(reqData.get('adjustAmount'), 'adjustAmount', false); // 포인트 강제 조정 금액

      // Contact의 Grade__c 필드 PickList 값 Label 조회
      Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldDesc.getPicklistValues();

      String labelName;
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.getValue() == grade) {
          labelName = entry.getLabel();
          break;
        }
      }

      // 등급 조회
      List<LoyaltyTier> ltList = [SELECT Id FROM LoyaltyTier WHERE Name = :labelName LIMIT 1];
      if (ltList.isEmpty()) {
        throw new CustomException(400, '해당 등급이 존재하지 않습니다. ' + labelName);
      }

      // 계층 보상 조회
      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c, LoyaltyTierId
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId = :ltList[0].Id
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, '해당 회원의 등급 보상이 없습니다. ' + tj.MemberId);
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
        return result;
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
        return result;
      }

      Datetime purchaseAccrualDatetime = resolvePurchaseAccrualDatetime(tj.OrderId);
      Date purchaseAccrualExpirationDate = resolvePurchaseAccrualExpirationDate(tj.OrderId);

      TransactionJournal newTj = new TransactionJournal();
      newTj.ActivityDate = purchaseAccrualDatetime;
      newTj.JournalDate = purchaseAccrualDatetime;
      newTj.LoyaltyProgramId = tj.LoyaltyProgramId;
      newTj.RelatedJournalId = tj.Id;
      newTj.MemberId = tj.MemberId;
      newTj.OrderId = tj.OrderId;
      if (String.isNotBlank(tj.SaleId__c)) {
        newTj.SaleId__c = tj.SaleId__c;
      } else if (String.isNotBlank(tj.OrderId__c)) {
        newTj.OrderId__c = tj.OrderId__c;
      }
      newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
      newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true);
      newTj.AdditionalNotes__c = additionalNotes;

      insert newTj;

      Decimal amount = (adjustAmount != null) ? adjustAmount : tj.TransactionAmount;
      if (amount <= 0) {
        throw new CustomException(400, '포인트 지급 할 금액이 없습니다. ' + amount);
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', newTj.MemberId);
        req.put('journalId', newTj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (amount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        req.put('pointsExpirationDate', String.valueOf(purchaseAccrualExpirationDate));
        reqList.add(req);
      }

      LoyaltyPointService.creditPoints(reqList);

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :newTj.Id
        LIMIT 100
      ];

      TransactionJournal tj2 = [
        SELECT
          Id,
          MemberId,
          TYPEOF Member
            WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
          END
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      SObject memberObj = tj2.getSObject('Member');
      if (memberObj == null) {
        throw new CustomException(500, 'memberObj is null');
      }
      SObject contactObj = memberObj.getSObject('Contact');
      if (contactObj == null) {
        throw new CustomException(500, 'contactObj is null');
      }
      String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

      Decimal totalPoints = 0;

      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = '01';
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate.addDays(1)); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        result.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }
      newTj.TransactionAmount = totalPoints;
      update newTj;

      return result;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * (특정 등급의 비율에 따른) 구매 시 포인트 지급 취소
   */
  public List<PointDebitDTO> debitPointsOnPurchaseByGrade(Map<String, Object> reqData) {
    List<PointDebitDTO> result = new List<PointDebitDTO>();
    try {
      String grade = ValidationUtil.stringValidationEx(reqData.get('Grade__c'), 'Grade__c', true, false);
      TransactionJournal tj = (TransactionJournal) ValidationUtil.sObjectValidation(reqData.get('TransactionJournal'), 'TransactionJournal', true);
      String additionalNotes = ValidationUtil.stringValidation(reqData.get('AdditionalNotes__c'), 'AdditionalNotes__c', true);
      Decimal adjustAmount = ValidationUtil.decimalValidation(reqData.get('adjustAmount'), 'adjustAmount', false); // 포인트 강제 조정 금액

      // Contact의 Grade__c 필드 PickList 값 Label 조회
      Schema.DescribeFieldResult fieldDesc = Contact.Grade__c.getDescribe();
      List<Schema.PicklistEntry> picklistValues = fieldDesc.getPicklistValues();

      String labelName;
      for (Schema.PicklistEntry entry : picklistValues) {
        if (entry.getValue() == grade) {
          labelName = entry.getLabel();
          break;
        }
      }

      // 등급 조회
      List<LoyaltyTier> ltList = [SELECT Id FROM LoyaltyTier WHERE Name = :labelName LIMIT 1];
      if (ltList.isEmpty()) {
        throw new CustomException(400, '해당 등급이 존재하지 않습니다. ' + labelName);
      }

      // 계층 보상 조회
      List<LoyaltyTierBenefit> ltbList = [
        SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__r.Name, Benefit.LoyaltyPgmCurrencySubtypeId__c, LoyaltyTierId
        FROM LoyaltyTierBenefit
        WHERE LoyaltyTierId = :ltList[0].Id
      ];
      if (ltbList.isEmpty()) {
        throw new CustomException(400, '해당 회원의 등급 보상이 없습니다. ' + tj.MemberId);
      }

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      TransactionJournal newTj = new TransactionJournal();
      newTj.ActivityDate = Datetime.now();
      newTj.JournalDate = Datetime.now();
      newTj.LoyaltyProgramId = tj.LoyaltyProgramId;
      newTj.RelatedJournalId = tj.Id;
      newTj.MemberId = tj.MemberId;
      newTj.OrderId = tj.OrderId;
      if (String.isNotBlank(tj.SaleId__c)) {
        newTj.SaleId__c = tj.SaleId__c;
      } else if (String.isNotBlank(tj.OrderId__c)) {
        newTj.OrderId__c = tj.OrderId__c;
      }
      newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, true);
      newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL, true);
      newTj.AdditionalNotes__c = additionalNotes;

      insert newTj;

      Decimal amount = (adjustAmount != null) ? adjustAmount : tj.TransactionAmount;
      if (amount <= 0) {
        throw new CustomException(400, '포인트 지급 할 금액이 없습니다. ' + amount);
      }

      for (LoyaltyTierBenefit ltb : ltbList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', newTj.MemberId);
        req.put('journalId', newTj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name);
        req.put('points', (amount * (ltb.Benefit.PurchasePointRate__c / 100)).setScale(0, RoundingMode.HALF_UP));
        req.put(
          'additionalNotes',
          ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name +
            '|' +
            String.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c) +
            '|' +
            String.valueOf(ltb.Benefit.PurchasePointRate__c)
        );
        reqList.add(req);
      }

      List<LoyaltyManagement.DebitPointsOutput> resList = LoyaltyPointService.debitPoints(reqList);

      // 포인트 사용 추적 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          CreditLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :newTj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + newTj.Id);
      }
      List<LoyaltyLedgerTraceability> newLltList = new List<LoyaltyLedgerTraceability>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        LoyaltyLedgerTraceability newLlt = llt.clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
        newLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;

        newLltList.add(newLlt);
      }

      // llt.ActionType 필드가 update 불가하여, 새로운 LoyaltyLedgerTraceability insert 후 기존 LoyaltyLedgerTraceability는 삭제
      List<Database.SaveResult> insertResultList = Database.insert(newLltList);

      for (Database.SaveResult insertResult : insertResultList) {
        if (!insertResult.isSuccess()) {
          Database.Error err = insertResult.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      // 기존 LoyaltyLedgerTraceability 삭제
      List<Database.DeleteResult> deleteResultList = Database.delete(lltList);

      for (Database.DeleteResult deleteResult : deleteResultList) {
        if (!deleteResult.isSuccess()) {
          Database.Error err = deleteResult.getErrors()[0];
          throw new CustomException(400, err.getMessage());
        }
      }

      Decimal totalPoints = 0;
      for (LoyaltyLedgerTraceability llt : newLltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId; // 로열티 소멸 키값
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId; // newTj.Id; -> llt.CreditLoyaltyLedgerId; (26.02.03)
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c; // 포인트 구분
        pcDto.CD_RESON = newTj.JournalReason__c; // 회원 포인트 소진 구분
        pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c; // 회원 번호
        if (String.isNotBlank(newTj.Order.OrderNo__c)) {
          pcDto.NO_SAL = newTj.Order.OrderNo__c; // 주문 번호
        } else if (String.isNotBlank(newTj.Order.SaleNo__c)) {
          pcDto.NO_SAL = newTj.Order.SaleNo__c; // 판매 번호
        }
        pcDto.PT_USE = llt.Points; // 적립 취소된 금액
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate); // 적립 취소된 금액

        result.add(pcDto);

        if (llt.Points > 0) {
          totalPoints += llt.Points;
        }
      }

      newTj.TransactionAmount = totalPoints;
      update newTj;

      return result;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 특정 포인트 지급
   */
  public List<PointCreditDTO> creditSepcificPoints(TransactionJournal tj, List<LoyaltyLedgerTraceability> lltList) {
    try {
      Id creditPointJt = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true); // 포인트/쿠폰 지급

      tj.JournalTypeId = creditPointJt;
      tj.JournalSubTypeId = resolveRestoreAccrualJournalSubTypeId(tj.JournalSubTypeId);

      insert tj;

      List<Map<String, Object>> reqList = new List<Map<String, Object>>();

      // [수정] 2026-04-03: 만료된 포인트 이중 검증 추가
      // 기존: 모든 LoyaltyLedgerTraceability 항목을 복구 요청
      // 수정: ExpiryDate < TODAY인 포인트는 복구 대상에서 제외
      // 원인: 이미 소멸한 포인트가 복구되는 문제 (1차 필터링: SOQL, 2차 필터링: 메서드)

      /*
      // [기존 코드 - 주석 처리] 2026-04-03
      for (LoyaltyLedgerTraceability llt : lltList) {
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', llt.LoyaltyPgmCurrencySubtype.Name);
        req.put('points', llt.Points);
        req.put('additionalNotes', buildRestoreCreditAdditionalNotes(llt));
        req.put('pointsExpirationDate', String.valueOf(llt.CreditLoyaltyLedger.ExpiryDate));
        reqList.add(req);
      }
      */

      /*
      // [수정된 코드 - 주석 처리] 2026-04-03
      // [버그] ExpiryDate = TODAY(당일)인 포인트가 필터링되지 않는 문제
      //        Salesforce Loyalty 소멸 배치는 ExpiryDate = TODAY인 포인트를 자정(00:00)에 소멸 처리함
      //        따라서 반품일 = ExpiryDate인 경우(CASE2)에도 포인트는 이미 소멸 상태이나
      //        ExpiryDate < TODAY (= 4/3 < 4/3) 가 FALSE가 되어 복구 대상에 포함되는 문제 발생
      for (LoyaltyLedgerTraceability llt : lltList) {
        if (llt.CreditLoyaltyLedger.ExpiryDate < System.today()) {
          continue;
        }
        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', llt.LoyaltyPgmCurrencySubtype.Name);
        req.put('points', llt.Points);
        req.put('additionalNotes', resolveRestoreCreditAdditionalNotes(llt));
        req.put('pointsExpirationDate', String.valueOf(llt.CreditLoyaltyLedger.ExpiryDate));
        reqList.add(req);
      }
      */

      // [수정된 코드] 2026-04-04
      // [변경] ExpiryDate < TODAY → ExpiryDate <= TODAY
      // [이유] Salesforce Loyalty 소멸 배치는 ExpiryDate = TODAY인 포인트를 자정(00:00)에 소멸 처리하므로
      //        반품일(TODAY)과 ExpiryDate가 같은 경우(CASE2)에도 포인트는 이미 소멸된 상태
      //        ExpiryDate <= TODAY 조건으로 당일 소멸 포인트까지 복구 대상에서 제외
      System.debug('lltList.size() = ' + lltList.size());
      Map<Id, LoyaltyLedger> restoreSourceCreditLedgerById = loadRestoreSourceCreditLedgersFromTraceability(lltList);
      for (LoyaltyLedgerTraceability llt : lltList) {
        // 기존 로직
        // // [수정] 2026-04-04: ExpiryDate <= TODAY (기존: < TODAY)
        // if (llt.CreditLoyaltyLedger.ExpiryDate <= System.today()) {
        //   continue; // 당일 소멸 포인트 포함하여 복구하지 않음
        // }

        // 신규 로직 [2026-04-24 Carson]
        if (llt.CreditLoyaltyLedger.ExpiryDate < System.today()) {
          continue;
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', tj.MemberId);
        req.put('journalId', tj.Id);
        req.put('loyaltyProgramCurrencySubtypeName', llt.LoyaltyPgmCurrencySubtype.Name);
        req.put('points', llt.Points);
        req.put('additionalNotes', buildRestoreCreditAdditionalNotes(String.valueOf(llt.CreditLoyaltyLedgerId), restoreSourceCreditLedgerById));
        req.put('pointsExpirationDate', String.valueOf(llt.CreditLoyaltyLedger.ExpiryDate));
        reqList.add(req);
      }

      // System.debug('진입1');
      // System.debug('reqList.size() = ' + reqList.size());
      LoyaltyPointService.creditPoints(reqList);
      // System.debug('진입2');

      List<LoyaltyLedger> llList = [
        SELECT
          Id,
          TransactionJournalId,
          LoyaltyPgmCrcySubtype.Name,
          LoyaltyPgmCrcySubtype.PointTypeCode__c,
          Points,
          ExpiryDate,
          EscrowPointsCreditDate,
          ActivityDate,
          CreatedDate,
          EventType,
          AdditionalNotes
        FROM LoyaltyLedger
        WHERE TransactionJournalId = :tj.Id
        LIMIT 100
      ];

      TransactionJournal tj2 = [
        SELECT
          Id,
          MemberId,
          TYPEOF Member
            WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
          END
        FROM TransactionJournal
        WHERE Id = :tj.Id
        LIMIT 1
      ];
      SObject memberObj = tj2.getSObject('Member');
      if (memberObj == null) {
        throw new CustomException(500, 'memberObj is null');
      }
      SObject contactObj = memberObj.getSObject('Contact');
      if (contactObj == null) {
        throw new CustomException(500, 'contactObj is null');
      }
      String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

      Decimal totalPoints = 0;

      List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
      for (LoyaltyLedger ll : llList) {
        PointCreditDTO pcDto = new PointCreditDTO();
        pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
        pcDto.CD_TYPE_POINT = ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
        pcDto.NO_MBR = memberNo;
        pcDto.PT_TARGET = ll.Points; // 적립 포인트
        pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
        pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
        pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate); // 포인트 유효기간 종료일
        pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate.addDays(1)); // 소멸 예정일
        pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
        pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
        pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
        pcDtoList.add(pcDto);

        if (ll.Points > 0) {
          totalPoints += ll.Points;
        }
      }
      tj.TransactionAmount = totalPoints;
      update tj;

      return pcDtoList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 포인트 사용 취소
   */
  private static String resolveRestoreCreditAdditionalNotes(LoyaltyLedgerTraceability llt) {
    if (llt == null) {
      return null;
    }
    String creditNotes = getRelatedLedgerAdditionalNotes(llt, 'CreditLoyaltyLedger');
    if (String.isNotBlank(creditNotes)) {
      return creditNotes;
    }
    String debitNotes = getRelatedLedgerAdditionalNotes(llt, 'DebitLoyaltyLedger');
    if (String.isNotBlank(debitNotes)) {
      return debitNotes;
    }
    return null;
  }

  private static String buildRestoreCreditAdditionalNotes(LoyaltyLedgerTraceability llt) {
    return appendOriginCreditLedgerId(resolveRestoreCreditAdditionalNotes(llt), resolveRestoreOriginCreditLedgerId(llt));
  }

  private static String buildRestoreCreditAdditionalNotes(String creditLoyaltyLedgerId, Map<Id, LoyaltyLedger> restoreSourceCreditLedgerById) {
    Id creditLedgerId = toIdOrNull(creditLoyaltyLedgerId);
    if (creditLedgerId == null) {
      return null;
    }

    LoyaltyLedger sourceLedger = restoreSourceCreditLedgerById == null ? null : restoreSourceCreditLedgerById.get(creditLedgerId);
    String baseAdditionalNotes = sourceLedger == null ? null : sourceLedger.AdditionalNotes;
    Id originCreditLedgerId = extractOriginCreditLedgerId(baseAdditionalNotes);
    return appendOriginCreditLedgerId(baseAdditionalNotes, originCreditLedgerId == null ? creditLedgerId : originCreditLedgerId);
  }

  private static Id resolveRestoreOriginCreditLedgerId(LoyaltyLedgerTraceability llt) {
    if (llt == null || llt.CreditLoyaltyLedgerId == null) {
      return null;
    }

    Id existingOriginCreditLedgerId = extractOriginCreditLedgerId(getRelatedLedgerAdditionalNotes(llt, 'CreditLoyaltyLedger'));
    return existingOriginCreditLedgerId == null ? llt.CreditLoyaltyLedgerId : existingOriginCreditLedgerId;
  }

  private static String getRelatedLedgerAdditionalNotes(LoyaltyLedgerTraceability llt, String relationshipName) {
    if (llt == null || String.isBlank(relationshipName)) {
      return null;
    }
    SObject ledgerObj = llt.getSObject(relationshipName);
    if (ledgerObj == null) {
      return null;
    }
    try {
      Object notes = ledgerObj.get('AdditionalNotes');
      return notes == null ? null : String.valueOf(notes);
    } catch (Exception e) {
      return null;
    }
  }

  private static Map<Id, LoyaltyLedger> loadRestoreSourceCreditLedgers(List<CancelPortionV2> cancelPortionList) {
    Set<Id> creditLedgerIds = new Set<Id>();
    if (cancelPortionList != null) {
      for (CancelPortionV2 cancelPortion : cancelPortionList) {
        Id creditLedgerId = cancelPortion == null ? null : toIdOrNull(cancelPortion.creditLoyaltyLedgerId);
        if (creditLedgerId != null) {
          creditLedgerIds.add(creditLedgerId);
        }
      }
    }
    if (creditLedgerIds.isEmpty()) {
      return new Map<Id, LoyaltyLedger>();
    }

    return new Map<Id, LoyaltyLedger>(
      [
        SELECT Id, AdditionalNotes
        FROM LoyaltyLedger
        WHERE Id IN :creditLedgerIds
      ]
    );
  }

  private static Map<Id, LoyaltyLedger> loadRestoreSourceCreditLedgersFromTraceability(List<LoyaltyLedgerTraceability> traceabilityList) {
    Set<Id> creditLedgerIds = new Set<Id>();
    if (traceabilityList != null) {
      for (LoyaltyLedgerTraceability trace : traceabilityList) {
        if (trace != null && trace.CreditLoyaltyLedgerId != null) {
          creditLedgerIds.add(trace.CreditLoyaltyLedgerId);
        }
      }
    }
    if (creditLedgerIds.isEmpty()) {
      return new Map<Id, LoyaltyLedger>();
    }

    return new Map<Id, LoyaltyLedger>(
      [
        SELECT Id, AdditionalNotes
        FROM LoyaltyLedger
        WHERE Id IN :creditLedgerIds
      ]
    );
  }

  private static String appendOriginCreditLedgerId(String additionalNotes, Id originCreditLedgerId) {
    if (originCreditLedgerId == null) {
      return additionalNotes;
    }
    String originToken = 'ORIGIN_CREDIT_LL=';
    if (String.isNotBlank(additionalNotes) && additionalNotes.contains(originToken)) {
      return additionalNotes;
    }

    String originNote = originToken + String.valueOf(originCreditLedgerId);
    return String.isBlank(additionalNotes) ? originNote : additionalNotes + ';' + originNote;
  }

  private static Id extractOriginCreditLedgerId(String additionalNotes) {
    if (String.isBlank(additionalNotes)) {
      return null;
    }

    String originToken = 'ORIGIN_CREDIT_LL=';
    Integer tokenIndex = additionalNotes.indexOf(originToken);
    if (tokenIndex < 0) {
      return null;
    }

    Integer valueStart = tokenIndex + originToken.length();
    Integer valueEnd = additionalNotes.indexOf(';', valueStart);
    String originIdText = valueEnd < 0 ? additionalNotes.substring(valueStart) : additionalNotes.substring(valueStart, valueEnd);
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

  private static Id toIdOrNull(String idText) {
    if (String.isBlank(idText) || (idText.length() != 15 && idText.length() != 18)) {
      return null;
    }
    try {
      return (Id) idText;
    } catch (Exception e) {
      return null;
    }
  }

  private static Map<Id, OriginRestoreCreditState> buildOriginRestoreCreditStateMap(List<LoyaltyLedger> creditLedgerList) {
    Set<Id> originCreditLedgerIds = new Set<Id>();
    if (creditLedgerList != null) {
      for (LoyaltyLedger creditLedger : creditLedgerList) {
        Id originCreditLedgerId = extractOriginCreditLedgerId(creditLedger == null ? null : creditLedger.AdditionalNotes);
        if (originCreditLedgerId != null) {
          originCreditLedgerIds.add(originCreditLedgerId);
        }
      }
    }

    if (originCreditLedgerIds.isEmpty()) {
      return new Map<Id, OriginRestoreCreditState>();
    }

    Map<Id, OriginRestoreCreditState> stateByOriginCreditLedgerId = new Map<Id, OriginRestoreCreditState>();
    for (Id originCreditLedgerId : originCreditLedgerIds) {
      stateByOriginCreditLedgerId.put(originCreditLedgerId, new OriginRestoreCreditState(0, true));
    }

    for (LoyaltyLedger originLedger : [
      SELECT
        Id,
        Points,
        TransactionJournal.IsDeleted__c,
        TransactionJournal.Order.IsDeleted__c,
        TransactionJournal.SaleId__r.IsDeleted__c
      FROM LoyaltyLedger
      WHERE Id IN :originCreditLedgerIds
    ]) {
      Boolean isInvalid =
        originLedger.TransactionJournal == null ||
        originLedger.TransactionJournal.IsDeleted__c == true ||
        (originLedger.TransactionJournal.Order != null && originLedger.TransactionJournal.Order.IsDeleted__c == true) ||
        (originLedger.TransactionJournal.SaleId__r != null && originLedger.TransactionJournal.SaleId__r.IsDeleted__c == true);
      Integer originPoints = originLedger.Points == null ? 0 : originLedger.Points.abs().intValue();
      stateByOriginCreditLedgerId.put(originLedger.Id, new OriginRestoreCreditState(originPoints, isInvalid));
    }

    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId IN :originCreditLedgerIds
        AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
      GROUP BY CreditLoyaltyLedgerId
    ]) {
      Id originCreditLedgerId = (Id) ar.get('creditLedgerId');
      OriginRestoreCreditState state = stateByOriginCreditLedgerId.get(originCreditLedgerId);
      if (state == null) {
        continue;
      }
      Integer canceledPoints = ar.get('totalPoints') == null ? 0 : ((Decimal) ar.get('totalPoints')).abs().intValue();
      state.remainingCap = Math.max(0, state.remainingCap - canceledPoints);
      if (state.remainingCap <= 0) {
        state.isInvalid = true;
      }
    }

    return stateByOriginCreditLedgerId;
  }

  private static Boolean shouldExcludeRestoreCreditByOrigin(Id originCreditLedgerId, Map<Id, OriginRestoreCreditState> stateByOriginCreditLedgerId) {
    if (originCreditLedgerId == null) {
      return false;
    }
    if (stateByOriginCreditLedgerId == null || !stateByOriginCreditLedgerId.containsKey(originCreditLedgerId)) {
      return true;
    }
    OriginRestoreCreditState state = stateByOriginCreditLedgerId.get(originCreditLedgerId);
    return state == null || state.isInvalid == true || state.remainingCap == null || state.remainingCap <= 0;
  }

  private static void assertOriginRestoreCreditsNotUsedByActiveDebit(List<LoyaltyLedger> originalAccrualLedgerList, TransactionJournal sourceTj) {
    if (originalAccrualLedgerList == null || originalAccrualLedgerList.isEmpty() || sourceTj == null || sourceTj.MemberId == null) {
      return;
    }

    Set<Id> originCreditLedgerIds = new Set<Id>();
    for (LoyaltyLedger originalAccrualLedger : originalAccrualLedgerList) {
      if (originalAccrualLedger != null && originalAccrualLedger.Id != null) {
        originCreditLedgerIds.add(originalAccrualLedger.Id);
      }
    }
    if (originCreditLedgerIds.isEmpty()) {
      return;
    }

    List<LoyaltyLedger> restoreCreditLedgers = [
      SELECT Id, AdditionalNotes
      FROM LoyaltyLedger
      WHERE LoyaltyProgramMemberId = :sourceTj.MemberId
        AND EventType = 'Credit'
        AND Points > 0
        AND AdditionalNotes LIKE '%ORIGIN_CREDIT_LL=%'
      LIMIT 50000
    ];

    Map<Id, Id> originCreditLedgerIdByRestoreCreditLedgerId = new Map<Id, Id>();
    for (LoyaltyLedger restoreCreditLedger : restoreCreditLedgers) {
      Id originCreditLedgerId = extractOriginCreditLedgerId(restoreCreditLedger.AdditionalNotes);
      if (originCreditLedgerId != null && originCreditLedgerIds.contains(originCreditLedgerId)) {
        originCreditLedgerIdByRestoreCreditLedgerId.put(restoreCreditLedger.Id, originCreditLedgerId);
      }
    }
    if (originCreditLedgerIdByRestoreCreditLedgerId.isEmpty()) {
      return;
    }

    Set<String> activeUseSaleNos = new Set<String>();
    for (LoyaltyLedgerTraceability activeUse : [
      SELECT
        Id,
        Points,
        DebitLoyaltyLedger.TransactionJournal.OrderId,
        DebitLoyaltyLedger.TransactionJournal.SaleId__c,
        DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c,
        DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c
      FROM LoyaltyLedgerTraceability
      WHERE LoyaltyProgramMemberId = :sourceTj.MemberId
        AND CreditLoyaltyLedgerId IN :originCreditLedgerIdByRestoreCreditLedgerId.keySet()
        AND ActionType = 'Debit'
        AND Points > 0
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        AND (DebitLoyaltyLedger.TransactionJournal.OrderId = NULL
          OR DebitLoyaltyLedger.TransactionJournal.Order.IsDeleted__c = FALSE
          OR DebitLoyaltyLedger.TransactionJournal.Order.IsDeleted__c = NULL)
        AND (DebitLoyaltyLedger.TransactionJournal.SaleId__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = FALSE
          OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = NULL)
      LIMIT 1000
    ]) {
      TransactionJournal debitTj = activeUse.DebitLoyaltyLedger == null ? null : activeUse.DebitLoyaltyLedger.TransactionJournal;
      if (debitTj == null) {
        continue;
      }
      if (sourceTj.OrderId != null && debitTj.OrderId == sourceTj.OrderId) {
        continue;
      }
      if (sourceTj.SaleId__c != null && debitTj.SaleId__c == sourceTj.SaleId__c) {
        continue;
      }
      String saleNo = debitTj.Order != null && String.isNotBlank(debitTj.Order.SaleNo__c)
        ? debitTj.Order.SaleNo__c
        : null;
      if (String.isBlank(saleNo) && debitTj.Order != null && String.isNotBlank(debitTj.Order.OrderNo__c)) {
        saleNo = debitTj.Order.OrderNo__c;
      }
      if (String.isBlank(saleNo) && debitTj.SaleId__r != null) {
        saleNo = debitTj.SaleId__r.SaleNo__c;
      }
      if (String.isNotBlank(saleNo)) {
        activeUseSaleNos.add(saleNo);
      }
    }

    if (!activeUseSaleNos.isEmpty()) {
      List<String> sortedSaleNos = new List<String>(activeUseSaleNos);
      sortedSaleNos.sort();
      throw new CustomException(
        400,
        '해당 판매에서 적립된 포인트의 사용 취소 복원분이 이미 다른 주문/판매에서 사용되어 적립 취소할 수 없습니다. 먼저 사용 건을 취소한 뒤 다시 처리해 주세요. 사용 주문/판매: ' +
        String.join(sortedSaleNos, ', ')
      );
    }
  }

  public Map<String, Object> cancelPointRedemption(TransactionJournal tj) {
    // === v3 Phase 2 신규 추가: Feature Flag 최우선 분기 (2026-04-24) ===
    // v3 Flag ON -> Trace 보존 모델. Bug 2, Bug 3 근본 해결.
    // v3 Flag OFF & Bug 2 Flag ON -> v2 로직 사용 (현재 Sandbox 기본).
    // v3 Flag OFF & Bug 2 Flag OFF -> v1 legacy.
    if (GdFeatureFlag.isEnabled('PointCancel_PreserveTrace')) {
      return cancelPointRedemption_v3(tj);
    }
    // === Bug 2 Phase 2 Feature Flag 분기 ===
    if (GdFeatureFlag.isEnabled('CancelPointRedemption_UseFixedLogic')) {
      return cancelPointRedemption_v2(tj);
    }
    // === Bug 2 Phase 2 신규 추가 끝 ===

    Map<String, Object> response = new Map<String, Object>();

    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      // 저널 유형 체크
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);

      // 저날 하위 유형 체크
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      insert tj;

      // 포인트 마스터 Id
      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      List<Order> oList = [SELECT Id FROM Order WHERE Id = :tj.OrderId LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, 'Order is null');
      }

      // [수정] 2026-04-03: 포인트 사용 취소 및 적립 포인트 회수 로직 추가
      // 기존: ActionType='Debit'인 사용 취소만 처리
      // 수정: ActionType='Credit'인 적립 포인트 회수도 처리
      // 원인: 반품 시 적립 포인트가 회수되지 않음

      // /*
      // [기존 코드 - 주석 처리] 2026-04-03
      // 포인트 사용 상세 이력 조회 (2개 SOQL 쿼리 - 비효율적)

      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          Id,
          CreditLoyaltyLedgerId,
          DebitLoyaltyLedgerId,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyPgmCurrencySubtype.Name,
          LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          ActionType,
          Points,
          LoyaltyPgmCurrencySubtypeId
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :tj.MemberId
          AND DebitLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId
          AND ActionType = 'Debit' // ❌ 사용(Debit)만 조회 - 적립(Credit) 회수 불가
          AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
          AND Points > 0
        LIMIT 100
      ];

      if (lltList.isEmpty()) {
        lltList = findDebitTraceabilityForPartialReturnCancellation(tj);
      }

      // DebugUtil.pretty('lltList : ', lltList);

      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 내역이 존재하지 않습니다. ' + tj.OrderId);
      }
      // */

      // // [수정된 코드] 2026-04-03
      // // 포인트 사용 및 적립 내역 조회 (1회 SOQL - 최적화)
      // // ActionType 필터 없이 전부 조회한 후 메모리에서 분류
      // List<LoyaltyLedgerTraceability> allLltList = [
      //   SELECT
      //     Id,
      //     CreditLoyaltyLedgerId,
      //     DebitLoyaltyLedgerId,
      //     CreditLoyaltyLedger.ExpiryDate,
      //     LoyaltyPgmCurrencySubtype.Name,
      //     LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
      //     ActionType,
      //     Points,
      //     LoyaltyPgmCurrencySubtypeId
      //   FROM LoyaltyLedgerTraceability
      //   WHERE
      //     LoyaltyProgramMemberId = :tj.MemberId
      //     AND CreditLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId
      //     AND Points > 0
      //   LIMIT 100
      // ];

      // // [수정] 2026-04-03: ActionType으로 분리 (코드에서 처리)
      // // Debit (사용 포인트 취소용) / Credit (적립 포인트 회수용)
      // List<LoyaltyLedgerTraceability> lltList = new List<LoyaltyLedgerTraceability>();
      // List<LoyaltyLedgerTraceability> creditLltList = new List<LoyaltyLedgerTraceability>();

      // for (LoyaltyLedgerTraceability llt : allLltList) {
      //   if (llt.ActionType == 'Debit') {  // [추가] 2026-04-03: 사용 포인트 분류
      //     lltList.add(llt);
      //   } else if (llt.ActionType == 'Credit') {  // [추가] 2026-04-03: 적립 포인트 분류
      //     creditLltList.add(llt);
      //   }
      // }

      // DebugUtil.pretty('allLltList : ', allLltList);  // [수정] 2026-04-03: 전체 조회 결과 확인
      // DebugUtil.pretty('lltList : ', lltList);  // [수정] 2026-04-03: 사용 포인트 목록
      // DebugUtil.pretty('creditLltList : ', creditLltList);  // [수정] 2026-04-03: 적립 포인트 목록

      // // [수정] 2026-04-03: 사용 또는 적립 중 하나 이상 필요
      // if (lltList.isEmpty() && creditLltList.isEmpty()) {
      //   throw new CustomException(400, '포인트 사용 내역 또는 적립 내역이 존재하지 않습니다. ' + tj.OrderId);
      // }

      // [수정] 2026-04-03: 사용 취소 처리 - lltList가 있을 때만 실행
      // Step 1: 사용 취소 처리 (Debit 처리)

      // 포인트 사용 건 추출 = 사용('Debit')
      Map<String, UsageBucket> usedPointMap = new Map<String, UsageBucket>();

      // if (!lltList.isEmpty()) {
      //   // [추가] 2026-04-03: 사용 포인트 취소 처리 - 사용 내역이 있을 때만 실행
      //   System.debug('사용 포인트 취소 처리 진입 - 개수: ' + lltList.size());

      for (LoyaltyLedgerTraceability llt : lltList) {
        String creditLoyaltyLedgerId = ValidationUtil.stringValidation(llt.CreditLoyaltyLedgerId, 'CreditLoyaltyLedgerId', true); // 적립 원장 ID
        String debitLoyaltyLedgerId = ValidationUtil.stringValidation(llt.DebitLoyaltyLedgerId, 'DebitLoyaltyLedgerId', true); // 사용 원장 ID
        Date expiryDate = ValidationUtil.dateValidation(llt.CreditLoyaltyLedger.ExpiryDate, 'CreditLoyaltyLedger.ExpiryDate', true); // 적립 원장의 만료일
        String loyaltyPgmCurrencySubtypeName = ValidationUtil.stringValidation( // 포인트 하위 유형 이름
          llt.LoyaltyPgmCurrencySubtype.Name,
          'LoyaltyPgmCurrencySubtype.Name',
          true
        );
        Integer usagePriorityNumber = ValidationUtil.integerValidation( // 포인트 하위 유형 사용 우선 순위
          llt.LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          'LoyaltyPgmCurrencySubtype.UsagePriorityNumber',
          true
        );
        String actionType = ValidationUtil.stringValidation(llt.ActionType, 'ActionType', true); // 사용 유형
        Decimal points = ValidationUtil.decimalValidation(llt.Points, 'Points', true); // 포인트
        String loyaltyPgmCurrencySubtypeId = ValidationUtil.stringValidation(llt.LoyaltyPgmCurrencySubtypeId, 'LoyaltyPgmCurrencySubtypeId', true); // 포인트 하위 유형 ID

        String key = String.valueOf(expiryDate) + '|' + loyaltyPgmCurrencySubtypeName + '|' + String.valueOf(usagePriorityNumber);

        if (!usedPointMap.containsKey(key)) {
          usedPointMap.put(
            key,
            new UsageBucket(
              llt.Id,
              expiryDate,
              loyaltyPgmCurrencySubtypeName,
              usagePriorityNumber,
              loyaltyPgmCurrencySubtypeId,
              creditLoyaltyLedgerId,
              debitLoyaltyLedgerId
            )
          );
        }

        usedPointMap.get(key).usagePoints += points;
      }

      // Map -> List 변환
      List<UsageBucket> ubList = new List<UsageBucket>(usedPointMap.values());

      // 만료일 DESC, 우선순위 DESC 로 정렬
      ubList.sort(new UsageBucketCancelSorter());

      Decimal cancelAmount = tj.TransactionAmount; // 사용 취소 할 금액

      List<CancelPortion> expiredCancelList = new List<CancelPortion>(); // 만료 대상 리스트
      List<CancelPortion> unexpiredCancelList = new List<CancelPortion>(); // 만료 대상 아닌 리스트

      // 사용 취소 할 포인트 선정
      for (UsageBucket ub : ubList) {
        if (cancelAmount <= 0) {
          System.debug('cancelAmount(사용 취소 할 금액) : ' + cancelAmount);
          // cancelAmount : 사용 취소 할 금액
          break;
        }

        // 이 구간에서 취소 가능한 포인트 없음
        if (ub.usagePoints == null || ub.usagePoints <= 0) {
          System.debug('이 구간에서 취소 가능한 포인트 없음');
          continue;
        }

        // 포인트 사용 취소 가능한 최대 금액
        Decimal possible = ub.usagePoints;
        System.debug('possible(포인트 사용 취소 가능한 최대 금액) : ' + possible);

        // ub.usagePoints : 사용한 금액
        Decimal fromThis = (cancelAmount > possible) ? possible : cancelAmount;
        System.debug('fromThis ' + fromThis);
        // 사용 취소 할 금액이 사용한 금액보다 크다면, 사용한 금액으로 입력.
        // 사용 취소 할 금액이 적다면, 사용 취소 할 금액으로 입력.

        // 바로 위에서 사용 취소 할 금액이 0보다 적으면 다음 for문으로 넘어감.
        if (fromThis <= 0) {
          System.debug('사용 취소 할 금액이 0보다 적습니다. continue 실행');
          continue;
        }

        // 만료일자를 지났는지 확인
        System.debug('만료일자 지났는지 확인 ub.expiryDate : ' + ub.expiryDate);
        // Boolean isExpired = (ub.expiryDate != null && ub.expiryDate <= Date.today()); // todo : 포인트 만료일자 확인 후 다시 설정 필요 // 기존 로직
        Boolean isExpired = (ub.expiryDate != null && ub.expiryDate < Date.today()); // 신규 로직 [2026-04-24 Carson]

        if (isExpired) {
          System.debug('만료일지가 지난 포인트입니다. fromThis : ' + fromThis);
          // 만료 될 포인트
          expiredCancelList.add(new CancelPortion(ub, fromThis));
        } else {
          System.debug('만료가 아닌 재지급 대상 포인트입니다. fromThis : ' + fromThis);
          // 만료가 아닌 재지급 될 포인트
          unexpiredCancelList.add(new CancelPortion(ub, fromThis));
        }

        // 사용 취소 할 금액만큼 빼준다.
        cancelAmount -= fromThis;
      }

      // ================================================================================================================================
      // 기존 Debit LLT 부분 제거 + 재생성 블록
      List<LoyaltyLedgerTraceability> deleteDebitList = new List<LoyaltyLedgerTraceability>();
      List<LoyaltyLedgerTraceability> insertRemainDebitList = new List<LoyaltyLedgerTraceability>();

      // 어떤 LLT가 얼마나 취소됐는지 집계
      Map<Id, Decimal> cancelSumByLLT = new Map<Id, Decimal>();

      // 만료 처리 할 포인트들을 cancelSumByLLT에 담아준다.
      if (!expiredCancelList.isEmpty()) {
        System.debug('expiredCancelList가 존재합니다.');
        for (CancelPortion cp : expiredCancelList) {
          cancelSumByLLT.put(
            cp.loyaltyLedgerTraceabilityId,
            (cancelSumByLLT.containsKey(cp.loyaltyLedgerTraceabilityId) ? cancelSumByLLT.get(cp.loyaltyLedgerTraceabilityId) : 0) + cp.cancelPoints
          );
        }
      }

      // 재지급 처리 할 포인트들을 cancelSumByLLT에 담아준다.
      if (!unexpiredCancelList.isEmpty()) {
        System.debug('unexpiredCancelList가 존재합니다.');
        for (CancelPortion cp : unexpiredCancelList) {
          cancelSumByLLT.put(
            cp.loyaltyLedgerTraceabilityId,
            (cancelSumByLLT.containsKey(cp.loyaltyLedgerTraceabilityId) ? cancelSumByLLT.get(cp.loyaltyLedgerTraceabilityId) : 0) + cp.cancelPoints
          );
        }
      }

      if (cancelSumByLLT.isEmpty()) {
        System.debug('취소 대상 금액이 존재하지 않습니다.');
        throw new CustomException(400, '취소 대상 금액이 존재하지 않습니다.');
      }

      //  원본 Debit LLT 다시 조회 (Id 기준으로만)
      List<LoyaltyLedgerTraceability> originalDebitList = [
        SELECT Id, Points, LoyaltyProgramMemberId, LoyaltyPgmCurrencySubtypeId, LoyaltyProgramCurrencyId, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :cancelSumByLLT.keySet()
      ];

      // LLT 하나씩 판단
      for (LoyaltyLedgerTraceability orig : originalDebitList) {
        Decimal originalPts = orig.Points; // 원본 Debit LLT 에서 사용한 포인트
        Decimal cancelledPts = cancelSumByLLT.get(orig.Id); // 취소
        Decimal cancelAmountPts = originalPts - cancelledPts;

        // 기존 LLT는 무조건 delete
        deleteDebitList.add(orig);

        // 남은 포인트가 있으면 새로운 Debit LLT로 생성
        if (cancelAmountPts > 0) {
          LoyaltyLedgerTraceability newDebit = new LoyaltyLedgerTraceability();
          newDebit.LoyaltyProgramMemberId = orig.LoyaltyProgramMemberId;
          newDebit.LoyaltyPgmCurrencySubtypeId = orig.LoyaltyPgmCurrencySubtypeId;
          newDebit.LoyaltyProgramCurrencyId = orig.LoyaltyProgramCurrencyId;
          newDebit.Points = cancelAmountPts;
          newDebit.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
          newDebit.DebitLoyaltyLedgerId = orig.DebitLoyaltyLedgerId;
          newDebit.CreditLoyaltyLedgerId = orig.CreditLoyaltyLedgerId;

          insertRemainDebitList.add(newDebit);
        }
      }

      // (DML 실행 순서 중요)
      if (!deleteDebitList.isEmpty()) {
        System.debug('기존 LLT 삭제합니다.');
        delete deleteDebitList;
      }
      if (!insertRemainDebitList.isEmpty()) {
        System.debug('새로운 Debit LLT를 생성합니다.');
        insert insertRemainDebitList;
      }
      // ================================================================================================================================

      // 포인트 사용 취소 금액이 남아 있는 경우
      if (cancelAmount > 0) {
        System.debug('취소 요청 포인트가 실제 사용 포인트보다 큽니다. ' + cancelAmount);
        throw new CustomException(400, '취소 요청 포인트가 실제 사용 포인트보다 큽니다.');
      }

      // 취소 -> 만료 처리 케이스
      if (!expiredCancelList.isEmpty()) {
        System.debug('취소 -> 만료 처리 케이스 진입하였습니다.');
        List<LoyaltyLedger> expireLedgerList = new List<LoyaltyLedger>();
        List<TraceSeed> traceSeedList = new List<TraceSeed>();

        List<Map<String, Object>> expiredPointList = new List<Map<String, Object>>();

        for (CancelPortion expiredCancel : expiredCancelList) {
          // 사용 취소 원장
          LoyaltyLedger expireLedger = new LoyaltyLedger();
          expireLedger.LoyaltyProgramMemberId = tj.MemberId;
          expireLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
          expireLedger.TransactionJournalId = tj.Id;
          expireLedger.ActivityDate = Datetime.now();
          expireLedger.LoyaltyPgmCrcySubtypeId = expiredCancel.loyaltyPgmCurrencySubtypeId;
          expireLedger.Points = expiredCancel.cancelPoints;
          expireLedger.ExpiryDate = expiredCancel.expiryDate;
          expireLedger.EventType = 'Credit'; // 지급

          expireLedgerList.add(expireLedger);

          // 만료 원장 (사용 취소 원장 복제)
          LoyaltyLedger creditLedger = expireLedger.clone(false, true, false, false); // (ID 복사 여부 | 관계 필드 복사 여부 | 생성 일시, 수정 일시 유지 여부 | 자동 등가 번호 유지 여부)
          creditLedger.EventType = 'Expiry'; // 만료
          expireLedgerList.add(creditLedger);

          traceSeedList.add(
            new TraceSeed(
              expiredCancel.debitLoyaltyLedgerId, // 기존 사용(차감) 레저 Id
              creditLedger // 새로 만든 사용취소용 레저(Traceability에서 Credit 쪽으로 볼 대상)
            )
          );

          // return 값 담기
          Map<String, Object> expiredPoint = new Map<String, Object>();
          expiredPoint.put('Point', expiredCancel.cancelPoints);
          expiredPoint.put('Name', expiredCancel.pointSubTypeName);
          expiredPoint.put('ExpiryDate', String.valueOf(expiredCancel.expiryDate));
          expiredPointList.add(expiredPoint);
        }
        response.put('ExpiryPointList', expiredPointList);

        insert expireLedgerList;

        // List<LoyaltyLedgerTraceability> debitCancellationTracebilityList = new List<LoyaltyLedgerTraceability>();

        // for (TraceSeed seed : traceSeedList) {
        //   LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability();
        //   t.LoyaltyProgramMemberId = tj.MemberId;
        //   t.LoyaltyPgmCurrencySubtypeId = seed.creditLedger.LoyaltyPgmCrcySubtypeId;
        //   t.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        //   t.Points = seed.creditLedger.Points;
        //   t.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION;
        //   t.DebitLoyaltyLedgerId = seed.debitLedgerId; // 원래 사용 원장 ID
        //   t.CreditLoyaltyLedgerId = seed.creditLedger.Id; // 지금 만든 취소용 원장 ID

        //   debitCancellationTracebilityList.add(t);
        // }

        // if (!debitCancellationTracebilityList.isEmpty()) {
        //   insert debitCancellationTracebilityList;
        // }

        tj.Status = 'Processed';
        update tj;
      }

      // 취소 -> 재지급 하는 케이스
      if (!unexpiredCancelList.isEmpty()) {
        System.debug('취소 -> 재지급 하는 케이스 진입');
        List<Map<String, Object>> reqList = new List<Map<String, Object>>();

        List<Map<String, Object>> recreditPointList = new List<Map<String, Object>>();

        Map<String, TraceSeed> traceSeedMap = new Map<String, TraceSeed>();

        for (CancelPortion unexpiredCancel : unexpiredCancelList) {
          Map<String, Object> req = new Map<String, Object>();
          req.put('loyaltyProgramMemberId', tj.MemberId);
          req.put('loyaltyProgramCurrencyId', loyaltyProgramCurrencyId);
          req.put('journalId', tj.Id);
          req.put('loyaltyProgramCurrencySubtypeName', unexpiredCancel.pointSubTypeName);
          req.put('points', unexpiredCancel.cancelPoints);
          req.put('pointsExpirationDate', String.valueOf(unexpiredCancel.expiryDate));
          reqList.add(req);

          String traceKey = String.valueOf(tj.Id) + '|' + unexpiredCancel.pointSubTypeName + '|' + String.valueOf(unexpiredCancel.expiryDate);
          System.debug('traceKey : ' + traceKey);
          traceSeedMap.put(
            traceKey,
            new TraceSeed(
              unexpiredCancel.debitLoyaltyLedgerId, // 기존 사용(차감) 레저 Id
              null
            )
          );

          // return 값 담기
          Map<String, Object> recreditPoint = new Map<String, Object>();
          recreditPoint.put('Point', unexpiredCancel.cancelPoints);
          recreditPoint.put('Name', unexpiredCancel.pointSubTypeName);
          recreditPoint.put('ExpiryDate', String.valueOf(unexpiredCancel.expiryDate));
          recreditPointList.add(recreditPoint);
        }
        response.put('RecreditPointList', recreditPointList);

        // 포인트 재지급
        List<LoyaltyManagement.CreditPointsOutput> creditPointsOutputs = LoyaltyPointService.creditPoints(reqList);

        // List<LoyaltyLedger> creditLedgerList = [
        //   SELECT Id, ExpiryDate, LoyaltyPgmCrcySubtype.Name, TransactionJournalId, Points
        //   FROM LoyaltyLedger
        //   WHERE TransactionJournalId = :tj.Id AND EventType = 'Credit'
        //   LIMIT 100
        // ];

        // for (LoyaltyLedger creditLedger : creditLedgerList) {
        //   String traceKey =
        //     String.valueOf(creditLedger.TransactionJournalId) +
        //     '|' +
        //     creditLedger.LoyaltyPgmCrcySubtype.Name +
        //     '|' +
        //     String.valueOf(creditLedger.ExpiryDate);

        //   if (traceSeedMap.containsKey(traceKey)) {
        //     TraceSeed seed = traceSeedMap.get(traceKey);
        //     seed.creditLedger = creditLedger;
        //   }
        // }

        // LoyaltyLedgerTraceability 생성
        // List<LoyaltyLedgerTraceability> traceList = new List<LoyaltyLedgerTraceability>();

        // for (String key : traceSeedMap.keySet()) {
        //   TraceSeed seed = traceSeedMap.get(key);

        //   if (seed.creditLedger == null) {
        //     throw new CustomException(500, '재지급 원장 매핑 실패 : ' + key);
        //   }

        //   LoyaltyLedgerTraceability t = new LoyaltyLedgerTraceability();
        //   t.LoyaltyProgramMemberId = tj.MemberId;
        //   t.LoyaltyPgmCurrencySubtypeId = seed.creditLedger.LoyaltyPgmCrcySubtypeId;
        //   t.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        //   t.Points = seed.creditLedger.Points;
        //   t.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT_CANCELLATION; // 포인트 사용 취소
        //   t.DebitLoyaltyLedgerId = seed.debitLedgerId; // 원 사용 원장
        //   t.CreditLoyaltyLedgerId = seed.creditLedger.Id; // 재지급 원장

        //   traceList.add(t);
        // }

        // if (!traceList.isEmpty()) {
        //   DebugUtil.pretty('traceList', traceList);
        //   // insert traceList;
        //   List<Database.SaveResult> resultList = Database.insert(traceList);

        //   for (Database.SaveResult result : resultList) {
        //     if (!result.isSuccess()) {
        //       Database.Error err = result.getErrors()[0];
        //       throw new CustomException(400, err.getMessage());
        //     }
        //   }
        // }
      } else {
        tj.Status = 'Processed';
        update tj;
      }

      // } // [추가] 2026-04-03: 사용 취소 처리 if (!lltList.isEmpty()) 블록 종료

      // // [추가] 2026-04-03: 적립 포인트 회수 처리
      // // 판매 시 적립된 포인트를 반품 시 회수
      // // 시나리오: 500,000원 판매 => 5,000P 적립 => 반품 => 5,000P 회수되어야 함
      // if (!creditLltList.isEmpty()) {
      //   System.debug('creditLltList 적립 포인트 회수 처리 진입 - 개수: ' + creditLltList.size());

      //   List<Map<String, Object>> creditRecoverReqList = new List<Map<String, Object>>();
      //   List<Map<String, Object>> creditRecoverList = new List<Map<String, Object>>();

      //   // [추가] 2026-04-03: 각 적립 포인트를 회수 처리
      //   for (LoyaltyLedgerTraceability creditLlt : creditLltList) {
      //     System.debug('적립 포인트 회수 처리 - Points: ' + creditLlt.Points + ', PointType: ' + creditLlt.LoyaltyPgmCurrencySubtype.Name);

      //     // [추가] 2026-04-03: 포인트 회수 요청 생성
      //     Map<String, Object> creditRecoverReq = new Map<String, Object>();
      //     creditRecoverReq.put('loyaltyProgramMemberId', tj.MemberId);
      //     creditRecoverReq.put('loyaltyProgramCurrencyId', loyaltyProgramCurrencyId);
      //     creditRecoverReq.put('journalId', tj.Id);
      //     creditRecoverReq.put('loyaltyProgramCurrencySubtypeName', creditLlt.LoyaltyPgmCurrencySubtype.Name);
      //     creditRecoverReq.put('points', creditLlt.Points);  // [추가] 2026-04-03: 적립 포인트
      //     creditRecoverReq.put('actionType', 'Debit');  // [추가] 2026-04-03: 회수 처리
      //     creditRecoverReq.put('remarks', '반품 적립 회수');  // [추가] 2026-04-03: 비고

      //     creditRecoverReqList.add(creditRecoverReq);

      //     // [추가] 2026-04-03: return 값 담기
      //     Map<String, Object> creditRecover = new Map<String, Object>();
      //     creditRecover.put('Point', creditLlt.Points);
      //     creditRecover.put('Name', creditLlt.LoyaltyPgmCurrencySubtype.Name);
      //     creditRecover.put('Type', 'AccrualRecover');  // [추가] 2026-04-03: 적립 회수 구분
      //     creditRecoverList.add(creditRecover);
      //   }

      //   // [추가] 2026-04-03: 적립 포인트 회수 실행 (debitPoints 호출)
      //   if (!creditRecoverReqList.isEmpty()) {
      //     System.debug('적립 포인트 회수 실행 - 개수: ' + creditRecoverReqList.size());

      //     try {
      //       // [추가] 2026-04-03: LoyaltyPointService.debitPoints() 호출하여 적립 포인트 회수
      //       List<LoyaltyManagement.DebitPointsOutput> creditRecoverOutputs = LoyaltyPointService.debitPoints(creditRecoverReqList);

      //       System.debug('적립 포인트 회수 완료 - 결과 개수: ' + creditRecoverOutputs.size());

      //       // [추가] 2026-04-03: 회수 결과를 response에 포함
      //       response.put('CreditRecoverList', creditRecoverList);
      //     } catch (Exception creditRecoverEx) {
      //       System.debug('적립 포인트 회수 중 오류 발생: ' + creditRecoverEx.getMessage());
      //       throw new CustomException(400, '적립 포인트 회수 처리 중 오류 발생: ' + creditRecoverEx.getMessage());
      //     }
      //   }
      // }

      return response;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * ! 사용 x
   * Bug 2 Phase 3 — cancelPointRedemption 수정 버전 (v2).
   *
   * 목적:
   *   UsageBucket 그룹화 결함으로 인한 고아 Traceability 문제 해결.
   *   Feature Flag 'CancelPointRedemption_UseFixedLogic' 가 ON 일 때만 호출됨.
   *
   * 주요 변경 (v1 대비):
   *   1. 그룹화 키(ExpiryDate+subtype+priority) 당 Traceability 를 모두 리스트로 보관 (UsageBucketV2)
   *   2. Bucket 내 cancel 금액을 FIFO 로 개별 Traceability 에 분배 (allocateCancel)
   *   3. 원본 Debit Traceability 쿼리에 모든 관련 Id 포함 (기존: 첫 번째 Id 만 포함)
   *   4. 각 Traceability 별 정확한 cancel 금액으로 부분 취소 시 남은 Points 만 재insert
   *
   * 기존 흐름(유지):
   *   - TJ 설정/insert, Order 검증, lltList 조회
   *   - 만료(expired) / 미만료(unexpired) 분기
   *   - Expiry Ledger 생성 + LoyaltyPointService.creditPoints() 복원 호출
   *   - Response 스키마
   */
  public Map<String, Object> cancelPointRedemption_v2(TransactionJournal tj) {
    Map<String, Object> response = new Map<String, Object>();

    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      // 저널 유형 체크
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      insert tj;

      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      List<Order> oList = [SELECT Id FROM Order WHERE Id = :tj.OrderId LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, 'Order is null');
      }

      // lltList 조회 (기존과 동일 쿼리, CreatedDate ASC 로 FIFO 안정성 확보)
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          Id,
          CreditLoyaltyLedgerId,
          DebitLoyaltyLedgerId,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyPgmCurrencySubtype.Name,
          LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          ActionType,
          Points,
          LoyaltyPgmCurrencySubtypeId,
          CreatedDate
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :tj.MemberId
          AND DebitLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId
          AND ActionType = 'Debit'
          AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
          AND Points > 0
        ORDER BY CreatedDate ASC
        LIMIT 100
      ];

      if (lltList.isEmpty()) {
        lltList = findDebitTraceabilityForPartialReturnCancellation(tj);
      }

      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 내역이 존재하지 않습니다. ' + tj.OrderId);
      }

      // 그룹화 — UsageBucketV2 (같은 key 의 Traceability 를 모두 entries 리스트에 보관)
      Map<Id, LoyaltyLedgerTraceability> debitTraceById = new Map<Id, LoyaltyLedgerTraceability>(lltList);
      Map<String, UsageBucketV2> usedPointMap = new Map<String, UsageBucketV2>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        String creditLoyaltyLedgerId = ValidationUtil.stringValidation(llt.CreditLoyaltyLedgerId, 'CreditLoyaltyLedgerId', true);
        String debitLoyaltyLedgerId = ValidationUtil.stringValidation(llt.DebitLoyaltyLedgerId, 'DebitLoyaltyLedgerId', true);
        Date expiryDate = ValidationUtil.dateValidation(llt.CreditLoyaltyLedger.ExpiryDate, 'CreditLoyaltyLedger.ExpiryDate', true);
        String loyaltyPgmCurrencySubtypeName = ValidationUtil.stringValidation(
          llt.LoyaltyPgmCurrencySubtype.Name,
          'LoyaltyPgmCurrencySubtype.Name',
          true
        );
        Integer usagePriorityNumber = ValidationUtil.integerValidation(
          llt.LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          'LoyaltyPgmCurrencySubtype.UsagePriorityNumber',
          true
        );
        Decimal points = ValidationUtil.decimalValidation(llt.Points, 'Points', true);
        String loyaltyPgmCurrencySubtypeId = ValidationUtil.stringValidation(llt.LoyaltyPgmCurrencySubtypeId, 'LoyaltyPgmCurrencySubtypeId', true);

        String key = String.valueOf(expiryDate) + '|' + loyaltyPgmCurrencySubtypeName + '|' + String.valueOf(usagePriorityNumber);

        if (!usedPointMap.containsKey(key)) {
          usedPointMap.put(
            key,
            new UsageBucketV2(
              expiryDate,
              loyaltyPgmCurrencySubtypeName,
              usagePriorityNumber,
              loyaltyPgmCurrencySubtypeId,
              creditLoyaltyLedgerId,
              debitLoyaltyLedgerId
            )
          );
        }
        // v1 와 차이점: 단일 Id 가 아닌 addEntry 로 모든 Id/Points 를 리스트 누적
        usedPointMap.get(key).addEntry(llt.Id, points);
      }

      // Map -> List + 정렬 (만료일 DESC, 우선순위 DESC, 이름 ASC — 기존과 동일)
      List<UsageBucketV2> ubList = new List<UsageBucketV2>(usedPointMap.values());
      ubList.sort(new UsageBucketV2CancelSorter());

      Decimal cancelAmount = tj.TransactionAmount;

      List<CancelPortionV2> expiredCancelList = new List<CancelPortionV2>();
      List<CancelPortionV2> unexpiredCancelList = new List<CancelPortionV2>();

      // v1 와 차이점: bucket 단위 cancel 결정 후 bucket 내부 Traceability 에 FIFO 분배
      Map<Id, Decimal> cancelSumByLLT = new Map<Id, Decimal>();

      for (UsageBucketV2 ub : ubList) {
        if (cancelAmount <= 0) {
          break;
        }
        if (ub.totalPoints == null || ub.totalPoints <= 0) {
          continue;
        }

        Decimal possible = ub.totalPoints;
        Decimal fromThis = (cancelAmount > possible) ? possible : cancelAmount;

        if (fromThis <= 0) {
          continue;
        }

        // Bucket 내 cancel 금액을 FIFO 로 각 Traceability 에 분배
        Map<Id, Decimal> allocatedByTrace = ub.allocateCancel(fromThis);
        for (Id lltId : allocatedByTrace.keySet()) {
          Decimal prev = cancelSumByLLT.containsKey(lltId) ? cancelSumByLLT.get(lltId) : 0;
          cancelSumByLLT.put(lltId, prev + allocatedByTrace.get(lltId));
        }

        // 만료 여부
        // Boolean isExpired = (ub.expiryDate != null && ub.expiryDate <= Date.today()); // 기존 로직
        Boolean isExpired = (ub.expiryDate != null && ub.expiryDate < Date.today()); // 신규 로직 [2026-04-24 Carson]

        Map<Id, Decimal> allocated = ub.allocateCancel(fromThis);
        for (Id lltId : allocated.keySet()) {
          LoyaltyLedgerTraceability sourceTrace = debitTraceById.get(lltId);
          Decimal allocatedPoints = allocated.get(lltId);
          if (sourceTrace == null || allocatedPoints == null || allocatedPoints <= 0) {
            continue;
          }
          CancelPortionV2 portion = new CancelPortionV2(
            ub,
            allocatedPoints,
            String.valueOf(sourceTrace.CreditLoyaltyLedgerId),
            String.valueOf(sourceTrace.DebitLoyaltyLedgerId)
          );
          if (isExpired) {
            expiredCancelList.add(portion);
          } else {
            unexpiredCancelList.add(portion);
          }
        }

        cancelAmount -= fromThis;
      }

      if (cancelAmount > 0) {
        throw new CustomException(400, '취소 요청 포인트가 실제 사용 포인트보다 큽니다.');
      }

      if (cancelSumByLLT.isEmpty()) {
        throw new CustomException(400, '취소 대상 금액이 존재하지 않습니다.');
      }

      // v1 와 차이점: 모든 관련 Traceability Id 를 포함해서 원본 조회
      List<LoyaltyLedgerTraceability> originalDebitList = [
        SELECT Id, Points, LoyaltyProgramMemberId, LoyaltyPgmCurrencySubtypeId, LoyaltyProgramCurrencyId, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :cancelSumByLLT.keySet()
      ];

      List<LoyaltyLedgerTraceability> deleteDebitList = new List<LoyaltyLedgerTraceability>();
      List<LoyaltyLedgerTraceability> insertRemainDebitList = new List<LoyaltyLedgerTraceability>();

      for (LoyaltyLedgerTraceability orig : originalDebitList) {
        Decimal originalPts = orig.Points == null ? 0 : orig.Points;
        Decimal cancelledPts = cancelSumByLLT.get(orig.Id) == null ? 0 : cancelSumByLLT.get(orig.Id);
        Decimal remainPts = originalPts - cancelledPts;

        // 기존 Traceability 는 무조건 delete
        deleteDebitList.add(orig);

        // 부분 취소된 경우에만 남은 Points 재insert
        if (remainPts > 0) {
          LoyaltyLedgerTraceability newDebit = new LoyaltyLedgerTraceability();
          newDebit.LoyaltyProgramMemberId = orig.LoyaltyProgramMemberId;
          newDebit.LoyaltyPgmCurrencySubtypeId = orig.LoyaltyPgmCurrencySubtypeId;
          newDebit.LoyaltyProgramCurrencyId = orig.LoyaltyProgramCurrencyId;
          newDebit.Points = remainPts;
          newDebit.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
          newDebit.DebitLoyaltyLedgerId = orig.DebitLoyaltyLedgerId;
          newDebit.CreditLoyaltyLedgerId = orig.CreditLoyaltyLedgerId;

          insertRemainDebitList.add(newDebit);
        }
      }

      // DML 실행 순서: 삭제 → 재insert
      if (!deleteDebitList.isEmpty()) {
        delete deleteDebitList;
      }
      if (!insertRemainDebitList.isEmpty()) {
        insert insertRemainDebitList;
      }

      // === 아래부터는 v1 와 동일한 expired/unexpired 처리 ===

      // 취소 → 만료 처리 케이스
      if (!expiredCancelList.isEmpty()) {
        List<LoyaltyLedger> expireLedgerList = new List<LoyaltyLedger>();
        List<Map<String, Object>> expiredPointList = new List<Map<String, Object>>();

        for (CancelPortionV2 expiredCancel : expiredCancelList) {
          LoyaltyLedger expireLedger = new LoyaltyLedger();
          expireLedger.LoyaltyProgramMemberId = tj.MemberId;
          expireLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
          expireLedger.TransactionJournalId = tj.Id;
          expireLedger.ActivityDate = Datetime.now();
          expireLedger.LoyaltyPgmCrcySubtypeId = expiredCancel.loyaltyPgmCurrencySubtypeId;
          expireLedger.Points = expiredCancel.cancelPoints;
          expireLedger.ExpiryDate = expiredCancel.expiryDate;
          expireLedger.EventType = 'Credit';

          expireLedgerList.add(expireLedger);

          LoyaltyLedger creditLedger = expireLedger.clone(false, true, false, false);
          creditLedger.EventType = 'Expiry';
          expireLedgerList.add(creditLedger);

          Map<String, Object> expiredPoint = new Map<String, Object>();
          expiredPoint.put('Point', expiredCancel.cancelPoints);
          expiredPoint.put('Name', expiredCancel.pointSubTypeName);
          expiredPoint.put('ExpiryDate', String.valueOf(expiredCancel.expiryDate));
          expiredPointList.add(expiredPoint);
        }
        response.put('ExpiryPointList', expiredPointList);

        insert expireLedgerList;

        tj.Status = 'Processed';
        update tj;
      }

      // 취소 → 재지급 하는 케이스
      if (!unexpiredCancelList.isEmpty()) {
        List<Map<String, Object>> reqList = new List<Map<String, Object>>();
        List<Map<String, Object>> recreditPointList = new List<Map<String, Object>>();
        Map<Id, LoyaltyLedger> restoreSourceCreditLedgerById = loadRestoreSourceCreditLedgers(unexpiredCancelList);

        for (CancelPortionV2 unexpiredCancel : unexpiredCancelList) {
          Map<String, Object> req = new Map<String, Object>();
          req.put('loyaltyProgramMemberId', tj.MemberId);
          req.put('loyaltyProgramCurrencyId', loyaltyProgramCurrencyId);
          req.put('journalId', tj.Id);
          req.put('loyaltyProgramCurrencySubtypeName', unexpiredCancel.pointSubTypeName);
          req.put('points', unexpiredCancel.cancelPoints);
          req.put('pointsExpirationDate', String.valueOf(unexpiredCancel.expiryDate));
          req.put('additionalNotes', buildRestoreCreditAdditionalNotes(unexpiredCancel.creditLoyaltyLedgerId, restoreSourceCreditLedgerById));
          reqList.add(req);

          Map<String, Object> recreditPoint = new Map<String, Object>();
          recreditPoint.put('Point', unexpiredCancel.cancelPoints);
          recreditPoint.put('Name', unexpiredCancel.pointSubTypeName);
          recreditPoint.put('ExpiryDate', String.valueOf(unexpiredCancel.expiryDate));
          recreditPointList.add(recreditPoint);
        }
        response.put('RecreditPointList', recreditPointList);

        // 포인트 재지급 (기존과 동일)
        List<LoyaltyManagement.CreditPointsOutput> creditPointsOutputs = LoyaltyPointService.creditPoints(reqList);
      } else {
        tj.Status = 'Processed';
        update tj;
      }

      return response;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * * 사용 중
   * * 포인트 사용 취소 V3
   * [v3 Phase 2 신규] cancelPointRedemption_v3
   *
   * 목적:
   *   Bug 2 (UsageBucket 단일 Id 결함) 과 Bug 3 (Cancel Credit 재사용 시 Aggregate -Available) 의
   *   근본 원인인 "원본 Trace 삭제 + 새 Credit Ledger 발행" 이중 구조를 해소.
   *
   *   v3 모델: 원본 Trace 를 보존하고 재적립 Credit Ledger 만 새로 발행.
   *   - 원본 사용 이력(Trace)은 그대로 유지 → LL 기반 가용 계산이 자연스럽게 정확
   *   - 재적립 Credit 은 FIFO 분배기에서 가용 있는 별도 Credit 으로 사용 → 사용자 직관 일치
   *   - Aggregate 트리거는 Cancel Credit 을 Accrued 로 취급 (별도 분기)
   *
   * v2 대비 변경점:
   *   - originalDebitList 쿼리 후 DML (delete / insert) 블록 제거
   *   - cancelSumByLLT 계산은 참조 목적으로만 유지 (dead metric)
   *   - LoyaltyPointService.creditPoints() 호출은 v2 와 동일 (재적립 Credit 발행)
   *
   * Feature Flag: 'PointCancel_PreserveTrace'
   */
  public Map<String, Object> cancelPointRedemption_v3(TransactionJournal tj) {
    System.debug('cancelPointRedemption_v3 진입');
    Map<String, Object> response = new Map<String, Object>();

    try {
      if (tj == null) {
        throw new CustomException(400, 'TransactionJournal is null');
      }

      // 저널 유형 체크 (v2 동일)
      Id jtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_REDEMPTION_REVERSAL, true);
      Map<String, Object> jstCond = new Map<String, Object>{ 'Name' => JOURNAL_SUB_TYPE_NAME_POINT_REDEEM_CANCEL, 'JournalTypeId' => jtId };
      Id jstId = SObjectUtil.findIdByConditions(JournalSubType.SObjectType, jstCond, true);

      tj.JournalTypeId = jtId;
      tj.JournalSubTypeId = jstId;
      tj.Status = 'Pending';

      System.debug('cancelPointRedemption_v3 진입22');
      insert tj;
      System.debug('cancelPointRedemption_v3 진입33');

      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      List<Order> oList = [SELECT Id FROM Order WHERE Id = :tj.OrderId LIMIT 1];
      if (oList.isEmpty()) {
        throw new CustomException(400, 'Order is null');
      }

      // lltList 조회 (v2 와 동일 쿼리)
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          Id,
          CreditLoyaltyLedgerId,
          DebitLoyaltyLedgerId,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyPgmCurrencySubtype.Name,
          LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          ActionType,
          Points,
          LoyaltyPgmCurrencySubtypeId,
          CreatedDate
        FROM LoyaltyLedgerTraceability
        WHERE
          LoyaltyProgramMemberId = :tj.MemberId
          AND DebitLoyaltyLedger.TransactionJournal.OrderId = :tj.OrderId
          AND ActionType = 'Debit'
          AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
          AND Points > 0
        ORDER BY CreatedDate ASC
        LIMIT 100
      ];

      if (lltList.isEmpty()) {
        lltList = findDebitTraceabilityForPartialReturnCancellation(tj);
      }

      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 내역이 존재하지 않습니다. ' + tj.OrderId);
      }

      // 그룹화 — UsageBucketV2 (v2 와 동일)
      Map<Id, LoyaltyLedgerTraceability> debitTraceById = new Map<Id, LoyaltyLedgerTraceability>(lltList);
      Map<String, UsageBucketV2> usedPointMap = new Map<String, UsageBucketV2>();

      for (LoyaltyLedgerTraceability llt : lltList) {
        String creditLoyaltyLedgerId = ValidationUtil.stringValidation(llt.CreditLoyaltyLedgerId, 'CreditLoyaltyLedgerId', true);
        String debitLoyaltyLedgerId = ValidationUtil.stringValidation(llt.DebitLoyaltyLedgerId, 'DebitLoyaltyLedgerId', true);
        Date expiryDate = ValidationUtil.dateValidation(llt.CreditLoyaltyLedger.ExpiryDate, 'CreditLoyaltyLedger.ExpiryDate', true);
        String loyaltyPgmCurrencySubtypeName = ValidationUtil.stringValidation(
          llt.LoyaltyPgmCurrencySubtype.Name,
          'LoyaltyPgmCurrencySubtype.Name',
          true
        );
        Integer usagePriorityNumber = ValidationUtil.integerValidation(
          llt.LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
          'LoyaltyPgmCurrencySubtype.UsagePriorityNumber',
          true
        );
        Decimal points = ValidationUtil.decimalValidation(llt.Points, 'Points', true);
        String loyaltyPgmCurrencySubtypeId = ValidationUtil.stringValidation(llt.LoyaltyPgmCurrencySubtypeId, 'LoyaltyPgmCurrencySubtypeId', true);

        String key = String.valueOf(expiryDate) + '|' + loyaltyPgmCurrencySubtypeName + '|' + String.valueOf(usagePriorityNumber);

        if (!usedPointMap.containsKey(key)) {
          usedPointMap.put(
            key,
            new UsageBucketV2(
              expiryDate,
              loyaltyPgmCurrencySubtypeName,
              usagePriorityNumber,
              loyaltyPgmCurrencySubtypeId,
              creditLoyaltyLedgerId,
              debitLoyaltyLedgerId
            )
          );
        }
        usedPointMap.get(key).addEntry(llt.Id, points);
      }

      // 정렬 (만료일 DESC, 우선순위 DESC, 이름 ASC — v2 와 동일)
      List<UsageBucketV2> ubList = new List<UsageBucketV2>(usedPointMap.values());
      ubList.sort(new UsageBucketV2CancelSorter());

      Decimal cancelAmount = tj.TransactionAmount;

      List<CancelPortionV2> expiredCancelList = new List<CancelPortionV2>();
      List<CancelPortionV2> unexpiredCancelList = new List<CancelPortionV2>();

      // 취소 가능액 집계 (분배는 표시용. v3 에선 Trace 를 건드리지 않음)
      for (UsageBucketV2 ub : ubList) {
        if (cancelAmount <= 0) {
          break;
        }
        if (ub.totalPoints == null || ub.totalPoints <= 0) {
          continue;
        }

        Decimal possible = ub.totalPoints;
        Decimal fromThis = (cancelAmount > possible) ? possible : cancelAmount;

        if (fromThis <= 0) {
          continue;
        }

        // Boolean isExpired = (ub.expiryDate != null && ub.expiryDate <= Date.today()); // 기존 로직
        Boolean isExpired = (ub.expiryDate != null && ub.expiryDate < Date.today()); // 신규 로직 [2026-04-24 Carson]

        Map<Id, Decimal> allocated = ub.allocateCancel(fromThis);
        for (Id lltId : allocated.keySet()) {
          LoyaltyLedgerTraceability sourceTrace = debitTraceById.get(lltId);
          Decimal allocatedPoints = allocated.get(lltId);
          if (sourceTrace == null || allocatedPoints == null || allocatedPoints <= 0) {
            continue;
          }
          CancelPortionV2 portion = new CancelPortionV2(
            ub,
            allocatedPoints,
            String.valueOf(sourceTrace.CreditLoyaltyLedgerId),
            String.valueOf(sourceTrace.DebitLoyaltyLedgerId)
          );
          if (isExpired) {
            expiredCancelList.add(portion);
          } else {
            unexpiredCancelList.add(portion);
          }
        }

        cancelAmount -= fromThis;
      }

      if (cancelAmount > 0) {
        throw new CustomException(400, '취소 요청 포인트가 실제 사용 포인트보다 큽니다.');
      }

      if (expiredCancelList.isEmpty() && unexpiredCancelList.isEmpty()) {
        throw new CustomException(400, '취소 대상 금액이 존재하지 않습니다.');
      }

      // ★ v3 핵심: Trace 삭제/재insert 블록 제거됨
      //    원본 Debit Trace 는 그대로 보존되어 사용 이력이 유지됨
      //    재적립 Credit 은 아래 LoyaltyPointService.creditPoints() 에서 새로 생성됨

      // 취소 → 만료 처리 (v2 동일)
      if (!expiredCancelList.isEmpty()) {
        System.debug('if (!expiredCancelList.isEmpty()) { 진입');
        List<LoyaltyLedger> expireLedgerList = new List<LoyaltyLedger>();
        List<Map<String, Object>> expiredPointList = new List<Map<String, Object>>();
        Map<Id, LoyaltyLedger> restoreSourceCreditLedgerById = loadRestoreSourceCreditLedgers(expiredCancelList);

        for (CancelPortionV2 expiredCancel : expiredCancelList) {
          LoyaltyLedger expireLedger = new LoyaltyLedger();
          expireLedger.LoyaltyProgramMemberId = tj.MemberId;
          expireLedger.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
          expireLedger.TransactionJournalId = tj.Id;
          expireLedger.ActivityDate = Datetime.now();
          expireLedger.LoyaltyPgmCrcySubtypeId = expiredCancel.loyaltyPgmCurrencySubtypeId;
          expireLedger.Points = expiredCancel.cancelPoints;
          expireLedger.ExpiryDate = expiredCancel.expiryDate;
          expireLedger.EventType = 'Credit';
          expireLedger.AdditionalNotes = buildRestoreCreditAdditionalNotes(expiredCancel.creditLoyaltyLedgerId, restoreSourceCreditLedgerById);

          expireLedgerList.add(expireLedger);

          LoyaltyLedger creditLedger = expireLedger.clone(false, true, false, false);
          creditLedger.EventType = 'Expiry';
          expireLedgerList.add(creditLedger);

          Map<String, Object> expiredPoint = new Map<String, Object>();
          expiredPoint.put('Point', expiredCancel.cancelPoints);
          expiredPoint.put('Name', expiredCancel.pointSubTypeName);
          expiredPoint.put('ExpiryDate', String.valueOf(expiredCancel.expiryDate));
          expiredPointList.add(expiredPoint);
        }
        response.put('ExpiryPointList', expiredPointList);

        System.debug('if (!expiredCancelList.isEmpty()) { 진입2');
        insert expireLedgerList;
        System.debug('if (!expiredCancelList.isEmpty()) { 진입3');

        System.debug('cancelPointRedemption_v3 진입1');
        tj.ActivityDate = Datetime.now().addDays(-1);
        tj.Status = 'Processed';
        update tj;
      }

      // 취소 → 재지급 (v2 동일)
      if (!unexpiredCancelList.isEmpty()) {
        System.debug('// 취소 → 재지급 (v2 동일) 진입');
        List<Map<String, Object>> reqList = new List<Map<String, Object>>();
        List<Map<String, Object>> recreditPointList = new List<Map<String, Object>>();
        Map<Id, LoyaltyLedger> restoreSourceCreditLedgerById = loadRestoreSourceCreditLedgers(unexpiredCancelList);

        for (CancelPortionV2 unexpiredCancel : unexpiredCancelList) {
          Map<String, Object> req = new Map<String, Object>();
          req.put('loyaltyProgramMemberId', tj.MemberId);
          req.put('loyaltyProgramCurrencyId', loyaltyProgramCurrencyId);
          req.put('journalId', tj.Id);
          req.put('loyaltyProgramCurrencySubtypeName', unexpiredCancel.pointSubTypeName);
          req.put('points', unexpiredCancel.cancelPoints);
          req.put('pointsExpirationDate', String.valueOf(unexpiredCancel.expiryDate));
          req.put('additionalNotes', buildRestoreCreditAdditionalNotes(unexpiredCancel.creditLoyaltyLedgerId, restoreSourceCreditLedgerById));
          reqList.add(req);

          Map<String, Object> recreditPoint = new Map<String, Object>();
          recreditPoint.put('Point', unexpiredCancel.cancelPoints);
          recreditPoint.put('Name', unexpiredCancel.pointSubTypeName);
          recreditPoint.put('ExpiryDate', String.valueOf(unexpiredCancel.expiryDate));
          recreditPointList.add(recreditPoint);
        }
        response.put('RecreditPointList', recreditPointList);
        System.debug('// 취소 → 재지급 (v2 동일) 진입1');

        // [Origin ActivityDate via TJ Fix 2026-05-06] Flag ON 시 LMS API 호출 전 tj.ActivityDate 를 origin Credit ActivityDate 로 변경.
        //   배경: 표준 LoyaltyPointService.creditPoints() 가 LL.ActivityDate 를 today 로 자동 설정.
        //         tj.ActivityDate 를 미리 변경하면 LMS 가 발행하는 Cancel Credit LL 의 ActivityDate 도 그 값을 사용 (예상).
        //   안전: LMS 표준 API 흐름 그대로 → Aggregate / Trace 자동 발행 정합 보장.
        //   다중 SubType / 다중 origin: 가장 빠른 origin ActivityDate 채택 (보수적 기본값).
        if (GdFeatureFlag.isEnabled('CancelCredit_PreserveOriginActivityDate')) {
          Set<Id> originCreditIds = new Set<Id>();
          for (CancelPortionV2 cp : unexpiredCancelList) {
            if (String.isNotBlank(cp.creditLoyaltyLedgerId)) {
              originCreditIds.add(cp.creditLoyaltyLedgerId);
            }
          }
          Datetime earliestOriginDate = null;
          if (!originCreditIds.isEmpty()) {
            for (LoyaltyLedger origLL : [SELECT ActivityDate FROM LoyaltyLedger WHERE Id IN :originCreditIds AND ActivityDate != NULL]) {
              if (earliestOriginDate == null || origLL.ActivityDate < earliestOriginDate) {
                earliestOriginDate = origLL.ActivityDate;
              }
            }
          }
          if (earliestOriginDate != null) {
            tj.ActivityDate = earliestOriginDate;
            update tj;
            System.debug('[Origin ActivityDate via TJ] tj.ActivityDate set to ' + earliestOriginDate);
          }
        }

        // 포인트 재지급 (재적립 Credit LL 생성)
        List<LoyaltyManagement.CreditPointsOutput> creditPointsOutputs = LoyaltyPointService.creditPoints(reqList);
        System.debug('// 취소 → 재지급 (v2 동일) 진입2');
      } else {
        System.debug('// 취소 → 재지급 (v2 동일) 진입3');
        tj.Status = 'Processed';
        update tj;
        System.debug('// 취소 → 재지급 (v2 동일) 진입4');
      }
      System.debug('cancelPointRedemption_v3 진입12');

      return response;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  // ==========================================================================
  // Bug 2 Phase 3 신규 inner 클래스들 (cancelPointRedemption_v2 / v3 공용)
  // ==========================================================================

  /**
   * UsageBucketV2 — 동일 key(ExpiryDate+subtype+priority) 의 Traceability 를
   * 모두 entries 리스트로 보관. v1 의 UsageBucket 과 달리 단일 Id 가 아닌 전체 Id 보유.
   */
  public class UsageBucketV2 {
    public Date expiryDate;
    public String pointSubTypeName;
    public Integer usagePriority;
    public Id loyaltyPgmCurrencySubtypeId;
    public String creditLoyaltyLedgerId; // 대표 (최초 entry)
    public String debitLoyaltyLedgerId; // 대표 (최초 entry)
    public Decimal totalPoints = 0;
    public List<TraceabilityEntry> entries = new List<TraceabilityEntry>();

    public UsageBucketV2(Date e, String s, Integer p, Id lpcsi, String clli, String dlli) {
      this.expiryDate = e;
      this.pointSubTypeName = s;
      this.usagePriority = p;
      this.loyaltyPgmCurrencySubtypeId = lpcsi;
      this.creditLoyaltyLedgerId = clli;
      this.debitLoyaltyLedgerId = dlli;
    }

    public void addEntry(Id lltId, Decimal points) {
      if (points == null) {
        points = 0;
      }
      entries.add(new TraceabilityEntry(lltId, points));
      totalPoints += points;
    }

    /**
     * 주어진 cancel 금액을 entries 에 FIFO 분배.
     * @param cancelAmount  이 bucket 에 할당된 cancel 금액 (<= totalPoints 이어야 함)
     * @return Map<Id, Decimal>  각 Traceability Id 에 할당된 cancel 금액 (0 인 경우 포함 안 함)
     */
    public Map<Id, Decimal> allocateCancel(Decimal cancelAmount) {
      Map<Id, Decimal> result = new Map<Id, Decimal>();
      if (cancelAmount == null || cancelAmount <= 0 || entries.isEmpty()) {
        return result;
      }
      Decimal remaining = cancelAmount;
      for (TraceabilityEntry e : entries) {
        if (remaining <= 0) {
          break;
        }
        if (e.points == null || e.points <= 0) {
          continue;
        }
        Decimal take = (e.points >= remaining) ? remaining : e.points;
        result.put(e.lltId, take);
        remaining -= take;
      }
      return result;
    }
  }

  /**
   * TraceabilityEntry — UsageBucketV2 내부에서 개별 Traceability 를 표현.
   */
  public class TraceabilityEntry {
    public Id lltId;
    public Decimal points;

    public TraceabilityEntry(Id id, Decimal p) {
      this.lltId = id;
      this.points = (p == null ? 0 : p);
    }
  }

  /**
   * UsageBucketV2CancelSorter — v1 UsageBucketCancelSorter 와 동일한 정렬 규칙.
   * 만료일 DESC, 우선순위 DESC, 이름 ASC.
   */
  public class UsageBucketV2CancelSorter implements System.Comparator<Object> {
    public Integer compare(Object a, Object b) {
      UsageBucketV2 x = (UsageBucketV2) a;
      UsageBucketV2 y = (UsageBucketV2) b;
      if (x.expiryDate > y.expiryDate)
        return -1;
      if (x.expiryDate < y.expiryDate)
        return 1;
      if (x.usagePriority > y.usagePriority)
        return -1;
      if (x.usagePriority < y.usagePriority)
        return 1;
      return x.pointSubTypeName.toLowerCase().compareTo(y.pointSubTypeName.toLowerCase());
    }
  }

  /**
   * CancelPortionV2 — v1 CancelPortion 과 동일 구조, UsageBucketV2 로부터 생성.
   */
  public class CancelPortionV2 {
    public Date expiryDate;
    public String pointSubTypeName;
    public Integer usagePriority;
    public Decimal cancelPoints;
    public Id loyaltyPgmCurrencySubtypeId;
    public String creditLoyaltyLedgerId;
    public String debitLoyaltyLedgerId;

    public CancelPortionV2(UsageBucketV2 ub, Decimal cancelPoints) {
      this.expiryDate = ub.expiryDate;
      this.pointSubTypeName = ub.pointSubTypeName;
      this.usagePriority = ub.usagePriority;
      this.cancelPoints = cancelPoints;
      this.loyaltyPgmCurrencySubtypeId = ub.loyaltyPgmCurrencySubtypeId;
      this.creditLoyaltyLedgerId = ub.creditLoyaltyLedgerId;
      this.debitLoyaltyLedgerId = ub.debitLoyaltyLedgerId;
    }

    public CancelPortionV2(UsageBucketV2 ub, Decimal cancelPoints, String creditLoyaltyLedgerId, String debitLoyaltyLedgerId) {
      this(ub, cancelPoints);
      if (String.isNotBlank(creditLoyaltyLedgerId)) {
        this.creditLoyaltyLedgerId = creditLoyaltyLedgerId;
      }
      if (String.isNotBlank(debitLoyaltyLedgerId)) {
        this.debitLoyaltyLedgerId = debitLoyaltyLedgerId;
      }
    }
  }

  /**
   * ! 사용 x
   * 포인트 개별 삭제(소멸)
   */
  public ApiResult deletePoint(Map<String, Object> reqData) {
    Map<String, Object> data = new Map<String, Object>();
    try {
      String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false); // 회원 번호
      List<Object> pointsList = ValidationUtil.listObjValidation(reqData.get('PointsList'), 'PointsList', true); // 포인트 목록

      if (pointsList.size() > 50) {
        throw new CustomException(400, '포인트 삭제(소멸) 요청 개수가 허용 범위를 초과하였습니다. (최대 50건)');
      }

      List<LoyaltyProgramMember> lpmList = [SELECT Id, ProgramId FROM LoyaltyProgramMember WHERE Contact.MemberNo__c = :memberNo LIMIT 1];
      if (lpmList.isEmpty()) {
        throw new CustomException(400, '해당 회원 찾을 수 없습니다. ' + memberNo);
      }

      Map<String, Decimal> pointByTypeMap = new Map<String, Decimal>();
      Decimal totalPoints = 0;

      for (Object v : pointsList) {
        Map<String, Object> vMap = ValidationUtil.mapStrObjValidation(v, 'PointsList', true);

        Decimal point = ValidationUtil.decimalGreaterThanZero(vMap.get('point'), 'point', true); // 포인트 금액
        String cdTypePoint = ValidationUtil.stringValidationEx(vMap.get('cd_type_point'), 'cd_type_point', true, false); // 포인트 구분
        String expiryDateStr = ValidationUtil.stringValidationEx(vMap.get('ExpiryDate__c'), 'ExpiryDate__c', true, false); // 소멸예정일

        String key = cdTypePoint + '|' + expiryDateStr;
        totalPoints += point;

        pointByTypeMap.put(key, (pointByTypeMap.containsKey(key) ? pointByTypeMap.get(key) : 0) + point);
      }

      TransactionJournal tj = new TransactionJournal();

      tj.LoyaltyProgramId = lpmList[0].ProgramId; // 로열티 프로그램 Id
      tj.MemberId = lpmList[0].Id; // 대상 멤버 Id
      tj.JournalDate = Datetime.now(); // 거래 일자
      tj.ActivityDate = Datetime.now(); // 활동 일자
      tj.TransactionAmount = totalPoints; // 삭제(소멸) 포인트
      tj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_POINTS_EXPIRATION, true);
      tj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_EXPIRE, true);
      tj.JournalReason__c = '2';

      insert tj;

      List<Map<String, Object>> pointDeleteReqList = new List<Map<String, Object>>();

      for (String key : pointByTypeMap.keySet()) {
        List<String> parts = key.split('\\|');
        String cdTypePoint = parts[0]; // 포인트 구분
        Date expiryDate = ValidationUtil.dateValidation(parts[1], 'expiryDateStr', true); // 만료 일자

        List<LoyaltyAggrSubPointExprLedger__c> laspelList = [
          SELECT
            Id,
            CurrencySubTypeName__c,
            CurrencySubTypeId__r.PointTypeCode__c,
            ExpiryDate__c,
            AccruedPoints__c,
            RedeemedPoints__c,
            ExpiredPoints__c,
            AvailablePoints__c
          FROM LoyaltyAggrSubPointExprLedger__c
          WHERE
            LoyaltyProgramMemberId__c = :lpmList[0].Id
            AND CurrencySubTypeId__r.PointTypeCode__c = :cdTypePoint
            AND ExpiryDate__c = :expiryDate
            AND AvailablePoints__c >= :pointByTypeMap.get(key)
            AND AvailablePoints__c > 0
          LIMIT 1
        ];

        if (laspelList.isEmpty()) {
          throw new CustomException(
            400,
            '해당 유형, 만료일자에 해당하는 포인트를 찾을 수 없습니다. (포인트 구분 : ' + cdTypePoint + '| 소멸예정일 : ' + expiryDate + ')'
          );
        }

        // 포인트 차감을 위한 값 설정
        Map<String, Object> pointDeleteReq = new Map<String, Object>();
        pointDeleteReq.put('loyaltyProgramMemberId', lpmList[0].Id);
        pointDeleteReq.put('journalId', tj.Id);
        pointDeleteReq.put('loyaltyProgramCurrencySubtypeName', laspelList[0].CurrencySubTypeName__c);
        pointDeleteReq.put('additionalNotes', '포인트 개별 삭제 API를 통한 포인트 삭제(소멸) 처리');
        pointDeleteReq.put('points', pointByTypeMap.get(key));

        pointDeleteReqList.add(pointDeleteReq);
      }

      // 포인트 사용 처리
      LoyaltyPointService.debitPoints(pointDeleteReqList);

      // 포인트 사용 추적 조회
      List<LoyaltyLedgerTraceability> lltList = [
        SELECT
          LoyaltyPgmCurrencySubtype.Name,
          Points,
          CreditLoyaltyLedger.ExpiryDate,
          LoyaltyProgramMember.Contact.MemberNo__c,
          LastModifiedDate,
          DebitLoyaltyLedgerId,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c
        FROM LoyaltyLedgerTraceability
        WHERE LoyaltyProgramMemberId = :tj.MemberId AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        LIMIT 100
      ];
      if (lltList.isEmpty()) {
        throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      }

      List<PointDebitDTO> pcDtoList = new List<PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : lltList) {
        PointDebitDTO pcDto = new PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId; // 로열티 소멸 키값
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c; // 포인트 구분
        pcDto.CD_RESON = tj.JournalReason__c; // 회원 포인트 소진 구분
        pcDto.NO_MBR = memberNo; // 회원 번호
        pcDto.PT_USE = llt.Points; // 소멸된 금액
        pcDto.DTS_INSERT = String.valueOf(tj.CreatedDate); // 등록 일자

        pcDtoList.add(pcDto);
      }
      data.put('PointDeleteList', pcDtoList);

      return ApiResult.ok(200, '포인트 개별 삭제 성공', data);
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 구매 시 지급된 포인트 적립 취소
   */
  public List<GdSaleApiController.PointDebitDTO> cancelPointsCreditedOnPurchase(List<TransactionJournal> data) {
    try {
      if (data == null || data.isEmpty()) {
        return null;
      }

      Decimal totalCancelAmount = calculateEligibleAccrualAmount(data, 0);
      if (totalCancelAmount <= 0) {
        return null;
      }

      List<GdSaleApiController.PointDebitDTO> resultList = new List<GdSaleApiController.PointDebitDTO>();

      List<GdSaleApiController.PointDebitDTO> purchasePointResult = cancelAccrualPointsBySubtype(
        data,
        totalCancelAmount,
        JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL,
        JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL
      );
      if (purchasePointResult != null) {
        resultList.addAll(purchasePointResult);
      }

      if (data[0].PromotionId != null) {
        List<GdSaleApiController.PointDebitDTO> promotionPointResult = cancelAccrualPointsBySubtype(
          data,
          totalCancelAmount,
          JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL,
          JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL
        );
        if (promotionPointResult != null) {
          resultList.addAll(promotionPointResult);
        }
      }

      return resultList.isEmpty() ? null : resultList;
    } catch (ValidationException ve) {
      throw new CustomException(ve.code, ve.detail);
    } catch (Exception e) {
      throw e;
    }
  }

  /**
   * 포인트 하위 유형 적립 취소
   */
  private List<GdSaleApiController.PointDebitDTO> cancelAccrualPointsBySubtype(
    List<TransactionJournal> data,
    Decimal totalCancelAmount,
    String accrualSubTypeName,
    String reversalSubTypeName
  ) {
    // [Feature Flag 분기 — 2026-05-04] AccrualReversal_UseSpecificLedger ON 시 신규 경로 사용
    // 신규 경로는 표준 LoyaltyPointService.debitPoints() 의 FIFO 분배 결함을 우회하고
    // 원본 적립 LL의 ExpiryDate / SubType 을 직접 가리키는 LL/Trace 를 수동 생성
    // Flag OFF 시 기존 로직 그대로 실행 (회귀 영향 없음)
    // * 현재 Flag On 상태
    if (GdFeatureFlag.isEnabled('AccrualReversal_UseSpecificLedger')) {
      return cancelAccrualPointsBySubtype_v2(data, totalCancelAmount, accrualSubTypeName, reversalSubTypeName);
    }

    Id accrualJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
    Id accrualReversalJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, true);
    Id accrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, accrualSubTypeName, true);
    Id reversalJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, reversalSubTypeName, true);

    List<LoyaltyLedger> llList;
    if (data[0].OrderId__c != null) {
      llList = [
        SELECT Points, AdditionalNotes, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtypeId, EventType, CreatedDate, Id
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.SaleId__c = :data[0].SaleId__c
          AND (TransactionJournal.JournalTypeId = :accrualJtId
          OR TransactionJournal.JournalTypeId = :accrualReversalJtId)
          AND (TransactionJournal.JournalSubTypeId = :accrualJstId
          OR TransactionJournal.JournalSubTypeId = :reversalJstId)
        ORDER BY CreatedDate ASC
        LIMIT 1000
      ];
    } else {
      // 적립, 적립 취소 OrderId 기준으로 LoyaltyLedger 조회 (2026-04-04 Carson)
      llList = [
        SELECT Points, AdditionalNotes, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtypeId, EventType, CreatedDate, Id
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.OrderId = :data[0].OrderId
          AND (TransactionJournal.JournalTypeId = :accrualJtId
          OR TransactionJournal.JournalTypeId = :accrualReversalJtId)
          AND (TransactionJournal.JournalSubTypeId = :accrualJstId
          OR TransactionJournal.JournalSubTypeId = :reversalJstId)
        ORDER BY CreatedDate ASC
        LIMIT 1000
      ];
    }

    // DebugUtil.pretty('data : ', data);

    if (llList.isEmpty()) {
      return null;
    }

    Map<String, Decimal> netPointMap = new Map<String, Decimal>();

    for (LoyaltyLedger ll : llList) {
      if (String.isBlank(ll.AdditionalNotes)) {
        continue;
      }

      if (!netPointMap.containsKey(ll.AdditionalNotes)) {
        netPointMap.put(ll.AdditionalNotes, 0);
      }

      if (ll.EventType == 'Credit') {
        netPointMap.put(ll.AdditionalNotes, netPointMap.get(ll.AdditionalNotes) + ll.Points);
      } else if (ll.EventType == 'Debit') {
        netPointMap.put(ll.AdditionalNotes, netPointMap.get(ll.AdditionalNotes) - ll.Points);
      }
    }

    List<CancelPurchasePoints> cppList = new List<CancelPurchasePoints>();
    for (String key : netPointMap.keySet()) {
      Decimal remainPts = netPointMap.get(key);
      if (remainPts == null || remainPts <= 0) {
        continue;
      }

      List<String> parts = key.split('\\|');
      if (parts.size() < 3) {
        continue;
      }

      cppList.add(new CancelPurchasePoints(remainPts, (Id) parts[1], parts[0], parseAdditionalNotesPointRate(parts[2])));
    }

    if (cppList.isEmpty()) {
      return null;
    }

    TransactionJournal tj = new TransactionJournal();
    tj.JournalDate = Datetime.now();
    tj.ActivityDate = Datetime.now();
    tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
    tj.MemberId = data[0].MemberId;
    tj.OrderId = data[0].OrderId;
    tj.JournalTypeId = accrualReversalJtId;
    tj.JournalSubTypeId = reversalJstId;
    if (JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(reversalSubTypeName)) {
      tj.PromotionId = data[0].PromotionId;
    }
    if (String.isNotBlank(data[0].SaleId__c)) {
      tj.SaleId__c = data[0].SaleId__c;
    } else if (String.isNotBlank(data[0].OrderId__c)) {
      tj.OrderId__c = data[0].OrderId__c;
    }
    if (data.size() == 1) {
      tj.RelatedJournalId = data[0].Id;
    }
    if (data[0].JournalSubTypeId == SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true)) {
      tj.JournalReason__c = '6';
    }

    insert tj;

    List<Map<String, Object>> reqList = JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(reversalSubTypeName)
      ? buildPromotionCancelRequestList(data[0], totalCancelAmount, cppList, tj.Id)
      : buildCancelRequestList(data[0].MemberId, totalCancelAmount, cppList, tj.Id);

    if (reqList.isEmpty()) {
      return null;
    }

    // 신규 로직 Start 2026-04-19
    // [변경] originalAccrualLedgerList 조회를 debitPoints() 호출 이전으로 이동
    // [이유] 기존 로직은 debitPoints() 호출 후 originalAccrualLedgerList가 비어있으면 throw하여
    //        TJ insert + debitPoints가 커밋된 채로 에러가 발생해 데이터 불일치 초래.
    //        debitPoints 전에 원판매 적립 내역 존재 여부를 먼저 확인해 불필요한 처리를 방지.
    // 기존 로직 Start 2026-04-19
    // LoyaltyPointService.debitPoints(reqList);  -- 아래로 이동 (원판매 적립 확인 후 호출)
    // 기존 로직 End 2026-04-19
    List<LoyaltyLedger> originalAccrualLedgerList;
    if (data[0].OrderId__c != null) {
      originalAccrualLedgerList = [
        SELECT Id, Points, LoyaltyPgmCrcySubtypeId, CreatedDate
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.SaleId__c = :data[0].SaleId__c
          AND TransactionJournal.JournalTypeId = :accrualJtId
          AND TransactionJournal.JournalSubTypeId = :accrualJstId
          AND EventType = 'Credit'
        ORDER BY CreatedDate ASC
        LIMIT 1000
      ];
    } else {
      // System.debug('진입1');
      // System.debug('data[0].OrderId : ' + data[0].OrderId);
      originalAccrualLedgerList = [
        SELECT Id, Points, LoyaltyPgmCrcySubtypeId, CreatedDate
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.SaleId__c = :data[0].OrderId
          // TransactionJournal.OrderId = :data[0].OrderId
          AND TransactionJournal.JournalTypeId = :accrualJtId
          AND TransactionJournal.JournalSubTypeId = :accrualJstId
          AND EventType = 'Credit'
        ORDER BY CreatedDate ASC
        LIMIT 1000
      ];
    }
    // [수정 2026-04-19] 원판매 적립 내역 없으면 null 반환 (포인트 미적립 판매 — 아울렛 등)
    // [수정 전]
    // if (originalAccrualLedgerList.isEmpty()) {
    //   throw new CustomException(400, '원판매 적립 LoyaltyLedger가 존재하지 않습니다. ' + tj.Id);
    // }
    // [수정 후]
    if (originalAccrualLedgerList.isEmpty()) {
      return null;
    }
    // 신규 로직 End 2026-04-19

    assertOriginRestoreCreditsNotUsedByActiveDebit(originalAccrualLedgerList, data[0]);

    LoyaltyPointService.debitPoints(reqList);

    // System.debug('step 01. 진입');
    // System.debug('tj.Id : ' + tj.Id);
    // System.debug('tj.MemberId : ' + tj.MemberId);
    List<LoyaltyLedgerTraceability> autoLltList = [
      SELECT
        Id,
        LoyaltyProgramCurrencyId,
        LoyaltyPgmCurrencySubtypeId,
        LoyaltyPgmCurrencySubtype.Name,
        Points,
        LoyaltyProgramMember.Contact.MemberNo__c,
        LastModifiedDate,
        DebitLoyaltyLedgerId,
        LoyaltyPgmCurrencySubtype.PointTypeCode__c,
        CreditLoyaltyLedgerId,
        DebitLoyaltyLedger.TransactionJournal.IsDeleted__c
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :tj.MemberId
        AND DebitLoyaltyLedger.TransactionJournalId = :tj.Id
        AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      LIMIT 100
    ];
    if (autoLltList.isEmpty()) {
      // System.debug('포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
      throw new CustomException(400, '포인트 사용 추적 내용이 존재하지 않습니다. ' + tj.Id);
    }

    // 신규 로직 (2026-04-05 Carson) start

    Map<Id, OriginalAccrualTraceBucket> originalBucketByLedgerId = new Map<Id, OriginalAccrualTraceBucket>();
    Map<Id, List<OriginalAccrualTraceBucket>> originalBucketsBySubtypeId = new Map<Id, List<OriginalAccrualTraceBucket>>();
    for (LoyaltyLedger originalLedger : originalAccrualLedgerList) {
      OriginalAccrualTraceBucket bucket = new OriginalAccrualTraceBucket(
        originalLedger.Id,
        originalLedger.LoyaltyPgmCrcySubtypeId,
        originalLedger.Points
      );
      originalBucketByLedgerId.put(originalLedger.Id, bucket);
      if (!originalBucketsBySubtypeId.containsKey(originalLedger.LoyaltyPgmCrcySubtypeId)) {
        originalBucketsBySubtypeId.put(originalLedger.LoyaltyPgmCrcySubtypeId, new List<OriginalAccrualTraceBucket>());
      }
      originalBucketsBySubtypeId.get(originalLedger.LoyaltyPgmCrcySubtypeId).add(bucket);
    }

    for (AggregateResult ar : [
      SELECT CreditLoyaltyLedgerId creditLedgerId, SUM(Points) totalPoints
      FROM LoyaltyLedgerTraceability
      WHERE CreditLoyaltyLedgerId IN :originalBucketByLedgerId.keySet() AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
      GROUP BY CreditLoyaltyLedgerId
    ]) {
      Id creditLedgerId = (Id) ar.get('creditLedgerId');
      Decimal cancellationPoints = (Decimal) ar.get('totalPoints');
      if (originalBucketByLedgerId.containsKey(creditLedgerId)) {
        OriginalAccrualTraceBucket bucket = originalBucketByLedgerId.get(creditLedgerId);
        bucket.remainingPoints -= cancellationPoints;
        if (bucket.remainingPoints < 0) {
          bucket.remainingPoints = 0;
        }
      }
    }

    Map<String, ManualCreditCancellationSeed> debitSeedByKey = new Map<String, ManualCreditCancellationSeed>();
    List<String> debitSeedKeyList = new List<String>();
    for (LoyaltyLedgerTraceability autoLlt : autoLltList) {
      String seedKey = String.valueOf(autoLlt.DebitLoyaltyLedgerId) + '|' + String.valueOf(autoLlt.LoyaltyPgmCurrencySubtypeId);
      System.debug('seedKey : ' + seedKey);
      if (!debitSeedByKey.containsKey(seedKey)) {
        debitSeedByKey.put(
          seedKey,
          new ManualCreditCancellationSeed(autoLlt.DebitLoyaltyLedgerId, autoLlt.LoyaltyPgmCurrencySubtypeId, autoLlt.LoyaltyProgramCurrencyId, 0)
        );
        debitSeedKeyList.add(seedKey);
      }
      debitSeedByKey.get(seedKey).points += autoLlt.Points;
    }

    List<Database.DeleteResult> deleteResultList = Database.delete(autoLltList);
    for (Database.DeleteResult deleteResult : deleteResultList) {
      if (!deleteResult.isSuccess()) {
        Database.Error err = deleteResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
    }

    List<LoyaltyLedgerTraceability> newLltList = new List<LoyaltyLedgerTraceability>();

    // 신규 로직 (2026-04-05 Carson) start
    for (String seedKey : debitSeedKeyList) {
      ManualCreditCancellationSeed seed = debitSeedByKey.get(seedKey);
      Decimal remainingPoints = seed.points;
      System.debug('remainingPoints : ' + remainingPoints);
      List<OriginalAccrualTraceBucket> bucketList = originalBucketsBySubtypeId.get(seed.loyaltyPgmCurrencySubtypeId);
      if (bucketList == null || bucketList.isEmpty()) {
        throw new CustomException(400, '매핑할 원판매 적립 LoyaltyLedger가 존재하지 않습니다. ' + seed.loyaltyPgmCurrencySubtypeId);
      }

      for (OriginalAccrualTraceBucket bucket : bucketList) {
        if (remainingPoints <= 0) {
          break;
        }
        if (bucket.remainingPoints == null || bucket.remainingPoints <= 0) {
          continue;
        }

        Decimal allocatedPoints = (remainingPoints > bucket.remainingPoints) ? bucket.remainingPoints : remainingPoints;
        System.debug('allocatedPoints : ' + allocatedPoints);
        LoyaltyLedgerTraceability newLlt = new LoyaltyLedgerTraceability();
        newLlt.LoyaltyProgramMemberId = tj.MemberId;
        newLlt.LoyaltyPgmCurrencySubtypeId = seed.loyaltyPgmCurrencySubtypeId;
        newLlt.LoyaltyProgramCurrencyId = seed.loyaltyProgramCurrencyId;
        newLlt.Points = allocatedPoints;
        newLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;
        newLlt.DebitLoyaltyLedgerId = seed.debitLoyaltyLedgerId;
        newLlt.CreditLoyaltyLedgerId = bucket.creditLoyaltyLedgerId;
        newLltList.add(newLlt);

        bucket.remainingPoints -= allocatedPoints;
        remainingPoints -= allocatedPoints;
      }

      if (remainingPoints > 0) {
        throw new CustomException(400, '원판매 적립 LoyaltyLedgerTraceability 재구성에 실패했습니다. 남은 포인트: ' + remainingPoints);
      }
    }
    for (LoyaltyLedgerTraceability llt : new List<LoyaltyLedgerTraceability>()) {
      // System.debug('기존lltList의 적립 CreditLoyaltyLedgerId : ' + llt.CreditLoyaltyLedgerId);
      // 신규 로직 (2026-04-05 Carson) end
      LoyaltyLedgerTraceability newLlt = llt.clone(false, true, false, false);
      newLlt.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;
      newLltList.add(newLlt);
    }
    // System.debug('step 02. 진입');

    List<Database.SaveResult> insertResultList = Database.insert(newLltList);
    List<Id> insertedLltIdList = new List<Id>(); // 신규 로직 (2026-04-05 Carson)
    for (Database.SaveResult insertResult : insertResultList) {
      if (!insertResult.isSuccess()) {
        Database.Error err = insertResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }

      // 신규 로직 (2026-04-05 Carson)
      insertedLltIdList.add(insertResult.getId());
    }
    // System.debug('step 03. 진입');

    // 신규 로직 (2026-04-05 Carson)
    deleteResultList = new List<Database.DeleteResult>();

    for (Database.DeleteResult deleteResult : deleteResultList) {
      if (!deleteResult.isSuccess()) {
        Database.Error err = deleteResult.getErrors()[0];
        throw new CustomException(400, err.getMessage());
      }
    }

    // 신규 로직 (2026-04-05 Carson)
    newLltList = [
      SELECT
        LoyaltyPgmCurrencySubtype.Name,
        Points,
        LoyaltyProgramMember.Contact.MemberNo__c,
        LastModifiedDate,
        DebitLoyaltyLedgerId,
        LoyaltyPgmCurrencySubtype.PointTypeCode__c,
        CreditLoyaltyLedgerId
      FROM LoyaltyLedgerTraceability
      WHERE Id IN :insertedLltIdList
      LIMIT 100
    ];

    Order orderInfo = null;
    if (tj.OrderId != null) {
      List<Order> orderList = [SELECT OrderNo__c, SaleNo__c FROM Order WHERE Id = :tj.OrderId LIMIT 1];
      if (!orderList.isEmpty()) {
        orderInfo = orderList[0];
      }
    }

    Decimal totalPoints = 0;
    List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
    for (LoyaltyLedgerTraceability llt : newLltList) {
      GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
      pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
      pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId;
      pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c;
      pcDto.CD_RESON = tj.JournalReason__c;
      pcDto.NO_MBR = llt.LoyaltyProgramMember.Contact.MemberNo__c;
      if (orderInfo != null) {
        if (String.isNotBlank(orderInfo.OrderNo__c)) {
          pcDto.NO_SAL = orderInfo.OrderNo__c;
        } else if (String.isNotBlank(orderInfo.SaleNo__c)) {
          pcDto.NO_SAL = orderInfo.SaleNo__c;
        }
      }
      pcDto.PT_USE = llt.Points;
      pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);
      pdDtoList.add(pcDto);

      if (llt.Points > 0) {
        totalPoints += llt.Points;
      }
    }

    tj.TransactionAmount = totalPoints;
    update tj;

    return pdDtoList;
  }

  /**
   * * 현재 Flag On 상태
   * cancelAccrualPointsBySubtype_v2 — Feature Flag 'AccrualReversal_UseSpecificLedger' ON 시 사용
   *
   * 표준 LoyaltyPointService.debitPoints() 의 FIFO 분배 결함을 우회하기 위해
   * 원본 적립 LL 의 ExpiryDate / SubType 을 직접 가리키는 Debit LL 과 Trace 를 수동 생성한다.
   *
   * 결함 메커니즘 (Flag OFF):
   *   1. debitPoints API 가 자동 Trace 를 만들어 만료일 빠른 가용 포인트부터 FIFO 차감
   *   2. Aggregate 트리거가 발화하여 잘못된 만료일 버킷에 -= 차감 적용
   *   3. 사후에 자동 Trace 를 삭제하고 올바른 만료일 가리키는 새 Trace 로 교체
   *   4. 새 Trace insert 시점엔 트리거가 다시 발화 안 함 → Aggregate 어긋남 잔존
   *
   * 신규 경로 (Flag ON):
   *   1. originalAccrualLedgerList 를 직접 조회 (이미 ExpiryDate 포함)
   *   2. 원본 적립 LL 의 SubType / ExpiryDate 를 정확히 가리키는 Debit LL / Trace 직접 생성
   *   3. tj.Status 를 Pending → Processed 로 update 시 트리거가 정확한 Trace 를 보고 처리
   *   4. 한 번에 정확한 만료일 버킷에 -= 차감 적용 → Aggregate 어긋남 발생 불가
   *
   * 응답 DTO 구조 (PointDebitDTO) 와 호출자 인터페이스는 기존과 100% 동일.
   *
   * 2026-05-04 작성.
   */
  private List<GdSaleApiController.PointDebitDTO> cancelAccrualPointsBySubtype_v2(
    List<TransactionJournal> data,
    Decimal totalCancelAmount,
    String accrualSubTypeName,
    String reversalSubTypeName
  ) {
    Savepoint sp = Database.setSavepoint();
    try {
      Id accrualJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
      Id accrualReversalJtId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL_REVERSAL, true);
      Id accrualJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, accrualSubTypeName, true);
      Id reversalJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, reversalSubTypeName, true);
      Id loyaltyProgramCurrencyId = SObjectUtil.findIdByName(LoyaltyProgramCurrency.SObjectType, LOYALTY_PROGRAM_CURRENCY_NAME, true);

      // [Step 1] netPointMap 빌드용 Credit LoyaltyLedger 조회 (Accrual 만)
      //   [NetMap Trace Correction Fix 2026-05-08]
      //   기존: Accrual + Accrual Reversal LL 모두 조회 후 EventType 별 +/- 합산.
      //   문제: Reversal LL 의 AdditionalNotes 가 null 이라 빌드 루프에서 건너뛰어 → net 에서 차감 안 됨.
      //         이전 부분 반품으로 회수된 양이 net 에 누락 → 회수 요청 양 부풀려져 분배 실패.
      //   해결: Accrual Credit LL 만 조회하여 합산 + 별도 LLT (CreditCancellation) 조회로 차감.
      //         가드: DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      //         → 살아있는 reversal 만 net 차감 → 반품 삭제/재반품 시나리오 안전.
      List<LoyaltyLedger> llList = findCancelableAccrualCreditLedgers(data[0], accrualJtId, accrualJstId);

      if (llList.isEmpty()) {
        return null;
      }

      // [Step 2] AdditionalNotes 기반 netPointMap 빌드 — Credit 합산
      Boolean usePurchaseFallbackNotes = JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL.equals(accrualSubTypeName);
      Decimal fallbackPurchaseAccrualBaseAmount = usePurchaseFallbackNotes ? calculateOriginalPurchaseAccrualBaseAmount(data[0]) : 0;
      Map<String, Decimal> netPointMap = new Map<String, Decimal>();
      Map<Id, String> additionalNotesByCreditLedgerId = new Map<Id, String>();
      Set<Id> creditLedgerIdsForLlt = new Set<Id>();
      for (LoyaltyLedger ll : llList) {
        String cancelBucketKey = ll.AdditionalNotes;
        if (String.isBlank(cancelBucketKey) && usePurchaseFallbackNotes) {
          cancelBucketKey = buildFallbackPurchaseCancelBucketKey(ll, fallbackPurchaseAccrualBaseAmount);
        }
        if (String.isBlank(cancelBucketKey)) {
          continue;
        }
        if (!netPointMap.containsKey(cancelBucketKey)) {
          netPointMap.put(cancelBucketKey, 0);
        }
        netPointMap.put(cancelBucketKey, netPointMap.get(cancelBucketKey) + ll.Points);
        additionalNotesByCreditLedgerId.put(ll.Id, cancelBucketKey);
        creditLedgerIdsForLlt.add(ll.Id);
      }

      // [Step 2.5] LLT 기반 차감 — 살아있는 Reversal 만 net 에서 차감
      //   가드: DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
      //   → 반품 삭제된 reversal 의 LLT 는 무시 → 잔여 회복 → 재반품 안전.
      //   주의: LL.IsDeleted 는 운영 데이터상 동기화 안 됨 (TJ.IsDeleted__c 만 마킹) →
      //         TJ.IsDeleted__c 만 가드로 사용.
      if (!creditLedgerIdsForLlt.isEmpty()) {
        for (AggregateResult ar : [
          SELECT CreditLoyaltyLedgerId creditId, SUM(Points) totalPts
          FROM LoyaltyLedgerTraceability
          WHERE
            CreditLoyaltyLedgerId IN :creditLedgerIdsForLlt
            AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
            AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
            AND (DebitLoyaltyLedger.TransactionJournal.SaleId__c = NULL
            OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = FALSE)
          GROUP BY CreditLoyaltyLedgerId
        ]) {
          Id creditId = (Id) ar.get('creditId');
          String additionalNotes = additionalNotesByCreditLedgerId.get(creditId);
          if (String.isBlank(additionalNotes)) {
            continue;
          }
          if (!netPointMap.containsKey(additionalNotes)) {
            continue;
          }
          Decimal sub = (Decimal) ar.get('totalPts');
          if (sub == null) {
            continue;
          }
          netPointMap.put(additionalNotes, netPointMap.get(additionalNotes) - sub.abs());
        }
      }

      // [Step 3] cppList 빌드 (기존 로직과 동일)
      List<CancelPurchasePoints> cppList = new List<CancelPurchasePoints>();
      for (String key : netPointMap.keySet()) {
        Decimal remainPts = netPointMap.get(key);
        if (remainPts == null || remainPts <= 0) {
          continue;
        }
        List<String> parts = key.split('\\|');
        if (parts.size() < 3) {
          continue;
        }
        cppList.add(new CancelPurchasePoints(remainPts, (Id) parts[1], parts[0], parseAdditionalNotesPointRate(parts[2])));
      }

      if (cppList.isEmpty()) {
        return null;
      }

      // [Step 4] Reversal TJ 생성 (기존 로직과 동일)
      TransactionJournal tj = new TransactionJournal();
      tj.JournalDate = Datetime.now();
      tj.ActivityDate = Datetime.now();
      tj.LoyaltyProgramId = data[0].LoyaltyProgramId;
      tj.MemberId = data[0].MemberId;
      tj.OrderId = data[0].OrderId;
      tj.JournalTypeId = accrualReversalJtId;
      tj.JournalSubTypeId = reversalJstId;
      tj.Status = 'Pending';
      if (JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(reversalSubTypeName)) {
        tj.PromotionId = data[0].PromotionId;
      }
      if (String.isNotBlank(data[0].SaleId__c)) {
        tj.SaleId__c = data[0].SaleId__c;
      } else if (String.isNotBlank(data[0].OrderId__c)) {
        tj.OrderId__c = data[0].OrderId__c;
      }
      if (data.size() == 1) {
        tj.RelatedJournalId = data[0].Id;
      }
      if (data[0].JournalSubTypeId == SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT_REVERSAL, true)) {
        tj.JournalReason__c = '6';
      }

      insert tj;

      // [Step 5] reqList 빌드 — 기존 helper 그대로 재사용 (분배 알고리즘 동일)
      List<Map<String, Object>> reqList = JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL.equals(reversalSubTypeName)
        ? buildPromotionCancelRequestList(data[0], totalCancelAmount, cppList, tj.Id)
        : buildCancelRequestList(data[0].MemberId, totalCancelAmount, cppList, tj.Id);

      if (reqList.isEmpty()) {
        Database.rollback(sp);
        return null;
      }

      // [Step 6] originalAccrualLedgerList 조회 (ExpiryDate 포함 — 신규 메서드의 핵심 입력)
      // 만료된 포인트는 차감 대상에서 제외 (ExpiryDate < TODAY)
      List<LoyaltyLedger> originalAccrualLedgerList = llList;

      if (originalAccrualLedgerList.isEmpty()) {
        Database.rollback(sp);
        return null;
      }

      // [Step 7] 원본 적립 LL 의 잔여 한도 계산 (기존 로직과 동일 패턴)
      Map<Id, OriginalAccrualTraceBucket> originalBucketByLedgerId = new Map<Id, OriginalAccrualTraceBucket>();
      Map<Id, List<OriginalAccrualTraceBucket>> originalBucketsBySubtypeId = new Map<Id, List<OriginalAccrualTraceBucket>>();
      Map<Id, LoyaltyLedger> originalLedgerById = new Map<Id, LoyaltyLedger>();
      for (LoyaltyLedger originalLedger : originalAccrualLedgerList) {
        OriginalAccrualTraceBucket bucket = new OriginalAccrualTraceBucket(
          originalLedger.Id,
          originalLedger.LoyaltyPgmCrcySubtypeId,
          originalLedger.Points
        );
        originalBucketByLedgerId.put(originalLedger.Id, bucket);
        originalLedgerById.put(originalLedger.Id, originalLedger);
        if (!originalBucketsBySubtypeId.containsKey(originalLedger.LoyaltyPgmCrcySubtypeId)) {
          originalBucketsBySubtypeId.put(originalLedger.LoyaltyPgmCrcySubtypeId, new List<OriginalAccrualTraceBucket>());
        }
        originalBucketsBySubtypeId.get(originalLedger.LoyaltyPgmCrcySubtypeId).add(bucket);
      }

      // 이미 차감된 분량 반영 (기존 CreditCancellation Trace 합계)
      //   [NetMap Trace Correction Fix 2026-05-08] Step 2.5 와 동일 가드 적용 — 살아있는 reversal 만 차감.
      //   → netPointMap 의 net 과 bucket.remainingPoints 잔여가 같은 기준으로 정합.
      for (AggregateResult ar : [
        SELECT CreditLoyaltyLedgerId creditLedgerId, SUM(Points) totalPoints
        FROM LoyaltyLedgerTraceability
        WHERE
          CreditLoyaltyLedgerId IN :originalBucketByLedgerId.keySet()
          AND ActionType = :LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION
          AND DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
          AND (DebitLoyaltyLedger.TransactionJournal.SaleId__c = NULL
          OR DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsDeleted__c = FALSE)
        GROUP BY CreditLoyaltyLedgerId
      ]) {
        Id creditLedgerId = (Id) ar.get('creditLedgerId');
        Decimal cancellationPoints = (Decimal) ar.get('totalPoints');
        if (originalBucketByLedgerId.containsKey(creditLedgerId)) {
          OriginalAccrualTraceBucket bucket = originalBucketByLedgerId.get(creditLedgerId);
          bucket.remainingPoints -= cancellationPoints;
          if (bucket.remainingPoints < 0) {
            bucket.remainingPoints = 0;
          }
        }
      }

      // [Step 8] reqList 의 각 요청을 원본 적립 LL 에 분배하면서 Debit LL / Trace 직접 생성
      List<LoyaltyLedger> newDebitLedgerList = new List<LoyaltyLedger>();
      // (debitLedgerIndex, creditLedgerId, allocatedPoints, subtypeId) 매핑 보관
      List<Integer> traceMapDebitIdx = new List<Integer>();
      List<Id> traceMapCreditLedgerId = new List<Id>();
      List<Decimal> traceMapAllocated = new List<Decimal>();
      List<Id> traceMapSubtypeId = new List<Id>();

      for (Map<String, Object> req : reqList) {
        String subtypeName = (String) req.get('loyaltyProgramCurrencySubtypeName');
        Decimal cancelPoints = (Decimal) req.get('points');
        if (cancelPoints == null || cancelPoints <= 0) {
          continue;
        }

        // SubType 이름으로 SubType Id 매핑 (원본 적립 LL의 LoyaltyPgmCrcySubtype.Name 비교)
        Id subtypeId = null;
        for (LoyaltyLedger ledger : originalAccrualLedgerList) {
          if (ledger.LoyaltyPgmCrcySubtype != null && subtypeName.equals(ledger.LoyaltyPgmCrcySubtype.Name)) {
            subtypeId = ledger.LoyaltyPgmCrcySubtypeId;
            break;
          }
        }
        if (subtypeId == null) {
          continue;
        }

        List<OriginalAccrualTraceBucket> bucketList = originalBucketsBySubtypeId.get(subtypeId);
        if (bucketList == null || bucketList.isEmpty()) {
          throw new CustomException(400, '매핑할 원판매 적립 LoyaltyLedger가 존재하지 않습니다. ' + subtypeId);
        }

        Decimal remainingPoints = cancelPoints;
        for (OriginalAccrualTraceBucket bucket : bucketList) {
          if (remainingPoints <= 0) {
            break;
          }
          if (bucket.remainingPoints == null || bucket.remainingPoints <= 0) {
            continue;
          }

          Decimal allocated = (remainingPoints > bucket.remainingPoints) ? bucket.remainingPoints : remainingPoints;
          if (allocated <= 0) {
            continue;
          }

          // Debit LL 직접 생성 (원본 적립 LL 의 SubType 정확히 매핑)
          LoyaltyLedger debitLL = new LoyaltyLedger();
          debitLL.LoyaltyProgramMemberId = tj.MemberId;
          debitLL.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
          debitLL.TransactionJournalId = tj.Id;
          debitLL.LoyaltyPgmCrcySubtypeId = subtypeId;
          debitLL.Points = allocated;
          debitLL.EventType = 'Debit';
          debitLL.ActivityDate = Datetime.now();

          Integer debitIdx = newDebitLedgerList.size();
          newDebitLedgerList.add(debitLL);

          // Trace 매핑 보관 (Debit LL insert 후 Id 가 채워지면 Trace 생성)
          traceMapDebitIdx.add(debitIdx);
          traceMapCreditLedgerId.add(bucket.creditLoyaltyLedgerId);
          traceMapAllocated.add(allocated);
          traceMapSubtypeId.add(subtypeId);

          bucket.remainingPoints -= allocated;
          remainingPoints -= allocated;
        }

        if (remainingPoints > 0) {
          throw new CustomException(
            400,
            '원판매 적립 LoyaltyLedger 분배에 실패했습니다. SubType: ' + subtypeName + ', 남은 포인트: ' + remainingPoints
          );
        }
      }

      if (newDebitLedgerList.isEmpty()) {
        Database.rollback(sp);
        return null;
      }

      // [Step 9] Debit LL insert
      insert newDebitLedgerList;

      // [Step 10] Trace 직접 생성 (ActionType = 'Debit' → 트리거 진입 조건 충족)
      List<LoyaltyLedgerTraceability> newTraceList = new List<LoyaltyLedgerTraceability>();
      for (Integer i = 0; i < traceMapDebitIdx.size(); i++) {
        LoyaltyLedger debitLL = newDebitLedgerList[traceMapDebitIdx[i]];
        LoyaltyLedgerTraceability trace = new LoyaltyLedgerTraceability();
        trace.LoyaltyProgramMemberId = tj.MemberId;
        trace.LoyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
        trace.LoyaltyPgmCurrencySubtypeId = traceMapSubtypeId[i];
        trace.CreditLoyaltyLedgerId = traceMapCreditLedgerId[i];
        trace.DebitLoyaltyLedgerId = debitLL.Id;
        trace.Points = traceMapAllocated[i];
        trace.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_DEBIT;
        newTraceList.add(trace);
      }
      insert newTraceList;

      // [Step 11] TJ.Status 를 Pending → Processed 로 update
      // 이 시점에 Aggregate 트리거 발화 → Trace 가 정확한 만료일/SubType 가리킴
      // → 정확한 버킷에 Accrued -= 적용 → 음수 발생 불가
      Decimal totalCancelPointsForTj = 0;
      for (Decimal p : traceMapAllocated) {
        totalCancelPointsForTj += p;
      }
      tj.TransactionAmount = totalCancelPointsForTj;
      tj.Status = 'Processed';
      update tj;

      // [Step 11.3] Trace ActionType 'Debit' → 'CreditCancellation' 으로 교체
      // ActionType 필드가 updateable=false (Salesforce 표준 제약) 이라 update 불가.
      // 따라서 기존 cancelAccrualPointsBySubtype Flag OFF 경로 (line 5204-5239) 와 동일하게
      // delete + 재 insert 패턴 사용.
      //
      // 이유:
      //  - 트리거는 이미 'Debit' Trace 처리 완료 (Aggregate 갱신 끝남)
      //  - 회원 도움창의 buildAccrualExpiredPointMap (PT_DESTROY 집계) 가
      //    ActionType = 'CreditCancellation' 만 합산하므로 적립 취소를 소멸로 표시하려면 필수
      //
      // 안전성:
      //  - 같은 트랜잭션 내 작업이라 외부 조회 시점에는 항상 일관된 상태
      //  - TJ.Status 변경 없으므로 Aggregate 트리거 재발화 안 됨
      //  - 만료일 매핑은 그대로 정확 (CreditLoyaltyLedgerId 동일)
      List<LoyaltyLedgerTraceability> tracesToReplace = [
        SELECT Id, LoyaltyProgramMemberId, LoyaltyProgramCurrencyId, LoyaltyPgmCurrencySubtypeId, CreditLoyaltyLedgerId, DebitLoyaltyLedgerId, Points
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :newTraceList
      ];

      // 새 Trace (CreditCancellation) 빌드
      List<LoyaltyLedgerTraceability> replacementTraces = new List<LoyaltyLedgerTraceability>();
      for (LoyaltyLedgerTraceability t : tracesToReplace) {
        LoyaltyLedgerTraceability newT = new LoyaltyLedgerTraceability();
        newT.LoyaltyProgramMemberId = t.LoyaltyProgramMemberId;
        newT.LoyaltyProgramCurrencyId = t.LoyaltyProgramCurrencyId;
        newT.LoyaltyPgmCurrencySubtypeId = t.LoyaltyPgmCurrencySubtypeId;
        newT.CreditLoyaltyLedgerId = t.CreditLoyaltyLedgerId;
        newT.DebitLoyaltyLedgerId = t.DebitLoyaltyLedgerId;
        newT.Points = t.Points;
        newT.ActionType = LOYALTY_LEDGER_TRACEABILITY_ACTION_TYPE_CREDIT_CANCELLATION;
        replacementTraces.add(newT);
      }

      // 기존 'Debit' Trace 삭제
      Database.delete(tracesToReplace);

      // 'CreditCancellation' Trace 재 insert
      if (!replacementTraces.isEmpty()) {
        insert replacementTraces;
      }

      // [Step 11.5] LMC.TotalPointsRedeemed 직접 갱신
      // 표준 LoyaltyPointService.debitPoints 를 우회했기 때문에 LMC 자동 갱신이 누락됨.
      // 검증 결과: 표준 API 는 차감 시 LMC.TotalPointsRedeemed 만 갱신하며
      // PointsBalance 는 수식 필드로 자동 재계산됨 (TotalPointsAccrued/Expired 미변동).
      // 동일 효과를 직접 update 로 재현.
      List<LoyaltyMemberCurrency> lmcList = [
        SELECT Id, TotalPointsRedeemed
        FROM LoyaltyMemberCurrency
        WHERE LoyaltyMemberId = :tj.MemberId AND LoyaltyProgramCurrency.Name = :LOYALTY_PROGRAM_CURRENCY_NAME
        LIMIT 1
      ];
      if (!lmcList.isEmpty()) {
        LoyaltyMemberCurrency lmc = lmcList[0];
        lmc.TotalPointsRedeemed = (lmc.TotalPointsRedeemed == null ? 0 : lmc.TotalPointsRedeemed) + totalCancelPointsForTj;
        update lmc;
      }

      // [Step 12] 응답 DTO 빌드 (기존 응답 구조 100% 동일 유지)
      Order orderInfo = null;
      if (tj.OrderId != null) {
        List<Order> orderList = [SELECT OrderNo__c, SaleNo__c FROM Order WHERE Id = :tj.OrderId LIMIT 1];
        if (!orderList.isEmpty()) {
          orderInfo = orderList[0];
        }
      }

      // 회원 번호 조회
      List<LoyaltyProgramMember> lpmList = [
        SELECT Id, Contact.MemberNo__c
        FROM LoyaltyProgramMember
        WHERE Id = :tj.MemberId
        LIMIT 1
      ];
      String memberNo = (!lpmList.isEmpty() && lpmList[0].Contact != null) ? lpmList[0].Contact.MemberNo__c : null;

      // 방금 생성한 Trace 를 Id 로 다시 조회하여 PointTypeCode 등 정보 확보
      // 참고: Step 11.3 에서 'Debit' Trace 를 삭제하고 'CreditCancellation' Trace 로 재 insert 했으므로
      //       응답 DTO 는 새 Trace (replacementTraces) 의 Id 기반으로 빌드
      Set<Id> newTraceIdSet = new Set<Id>();
      for (LoyaltyLedgerTraceability t : replacementTraces) {
        if (t.Id != null) {
          newTraceIdSet.add(t.Id);
        }
      }
      List<LoyaltyLedgerTraceability> resultLltList = [
        SELECT
          Id,
          DebitLoyaltyLedgerId,
          CreditLoyaltyLedgerId,
          Points,
          LastModifiedDate,
          LoyaltyPgmCurrencySubtype.PointTypeCode__c,
          LoyaltyPgmCurrencySubtype.Name
        FROM LoyaltyLedgerTraceability
        WHERE Id IN :newTraceIdSet
        LIMIT 1000
      ];

      List<GdSaleApiController.PointDebitDTO> pdDtoList = new List<GdSaleApiController.PointDebitDTO>();
      for (LoyaltyLedgerTraceability llt : resultLltList) {
        GdSaleApiController.PointDebitDTO pcDto = new GdSaleApiController.PointDebitDTO();
        pcDto.CD_LEDGER = llt.DebitLoyaltyLedgerId;
        pcDto.CD_JOURNAL = llt.CreditLoyaltyLedgerId;
        pcDto.CD_TYPE_POINT = llt.LoyaltyPgmCurrencySubtype != null ? llt.LoyaltyPgmCurrencySubtype.PointTypeCode__c : null;
        pcDto.CD_RESON = tj.JournalReason__c;
        pcDto.NO_MBR = memberNo;
        if (orderInfo != null) {
          if (String.isNotBlank(orderInfo.OrderNo__c)) {
            pcDto.NO_SAL = orderInfo.OrderNo__c;
          } else if (String.isNotBlank(orderInfo.SaleNo__c)) {
            pcDto.NO_SAL = orderInfo.SaleNo__c;
          }
        }
        pcDto.PT_USE = llt.Points;
        pcDto.DTS_INSERT = String.valueOf(llt.LastModifiedDate);
        pdDtoList.add(pcDto);
      }

      return pdDtoList;
    } catch (ValidationException ve) {
      Database.rollback(sp);
      throw new CustomException(ve.code, ve.detail);
    } catch (CustomException ce) {
      Database.rollback(sp);
      throw ce;
    } catch (Exception e) {
      Database.rollback(sp);
      throw e;
    }
  }

  // 구매 시 지급된 포인트 적립 취소 시 일반 포인트와 프로모션 포인트 각각의 로직으로 취소 요청 리스트 생성
  private List<Map<String, Object>> buildCancelRequestList(Id memberId, Decimal totalCancelAmount, List<CancelPurchasePoints> cppList, Id journalId) {
    Map<Id, List<CancelPurchasePoints>> cppGroupMap = new Map<Id, List<CancelPurchasePoints>>();
    for (CancelPurchasePoints cp : cppList) {
      if (!cppGroupMap.containsKey(cp.loyaltyPgmCrcySubtypeId)) {
        cppGroupMap.put(cp.loyaltyPgmCrcySubtypeId, new List<CancelPurchasePoints>());
      }
      cppGroupMap.get(cp.loyaltyPgmCrcySubtypeId).add(cp);
    }

    List<Map<String, Object>> reqList = new List<Map<String, Object>>();
    for (Id subtypeId : cppGroupMap.keySet()) {
      Decimal remainCancelAmountForSubtype = totalCancelAmount;
      List<CancelPurchasePoints> bucketList = cppGroupMap.get(subtypeId);
      bucketList.sort(new CancelRateSorter());

      for (CancelPurchasePoints cp : bucketList) {
        if (remainCancelAmountForSubtype <= 0) {
          break;
        }

        Decimal rateFraction = cp.rate / 100;
        if (rateFraction <= 0) {
          continue;
        }

        Decimal maxCancelableAmount = cp.points / rateFraction;
        Decimal useAmountFromThis = (remainCancelAmountForSubtype > maxCancelableAmount) ? maxCancelableAmount : remainCancelAmountForSubtype;
        if (useAmountFromThis <= 0) {
          continue;
        }

        Decimal cancelPoints = useAmountFromThis * rateFraction;
        if (cancelPoints > cp.points) {
          cancelPoints = cp.points;
        }
        if (cancelPoints <= 0) {
          continue;
        }

        Map<String, Object> req = new Map<String, Object>();
        req.put('loyaltyProgramMemberId', memberId);
        req.put('points', cancelPoints);
        req.put('journalId', journalId);
        req.put('additionalNotes', cp.loyaltyPgmCrcySubtypeName + '|' + String.valueOf(cp.loyaltyPgmCrcySubtypeId) + '|' + String.valueOf(cp.rate));
        req.put('loyaltyProgramCurrencySubtypeName', cp.loyaltyPgmCrcySubtypeName);
        reqList.add(req);

        remainCancelAmountForSubtype -= useAmountFromThis;
      }
    }

    return reqList;
  }

  /** 프로모션 포인트 적립 취소 */
  private List<Map<String, Object>> buildPromotionCancelRequestList(
    TransactionJournal sourceJournal,
    Decimal totalCancelAmount,
    List<CancelPurchasePoints> cppList,
    Id journalId
  ) {
    Map<String, Integer> additionalNotesCountMap = buildPromotionAdditionalNotesCountMap(sourceJournal);
    List<Map<String, Object>> reqList = new List<Map<String, Object>>();

    for (CancelPurchasePoints cp : cppList) {
      Decimal rateFraction = cp.rate / 100;
      if (rateFraction <= 0) {
        continue;
      }

      String additionalNotes = cp.loyaltyPgmCrcySubtypeName + '|' + String.valueOf(cp.loyaltyPgmCrcySubtypeId) + '|' + String.valueOf(cp.rate);
      Integer multiplier = additionalNotesCountMap.containsKey(additionalNotes) ? additionalNotesCountMap.get(additionalNotes) : 1;
      if (multiplier == null || multiplier <= 0) {
        multiplier = 1;
      }

      Decimal maxCancelableAmount = cp.points / rateFraction;
      Decimal targetCancelableAmount = totalCancelAmount * multiplier;
      Decimal useAmountFromThis = (targetCancelableAmount > maxCancelableAmount) ? maxCancelableAmount : targetCancelableAmount;
      if (useAmountFromThis <= 0) {
        continue;
      }

      Decimal cancelPoints = useAmountFromThis * rateFraction;
      if (cancelPoints > cp.points) {
        cancelPoints = cp.points;
      }
      if (cancelPoints <= 0) {
        continue;
      }

      Map<String, Object> req = new Map<String, Object>();
      req.put('loyaltyProgramMemberId', sourceJournal.MemberId);
      req.put('points', cancelPoints);
      req.put('journalId', journalId);
      req.put('additionalNotes', additionalNotes);
      req.put('loyaltyProgramCurrencySubtypeName', cp.loyaltyPgmCrcySubtypeName);
      reqList.add(req);
    }

    return reqList;
  }

  // 프로모션 포인트 적립 취소 시 AdditionalNotes에 포함된 정보 기반으로 취소 가능한 금액 계산을 위한 맵 생성
  @TestVisible
  private Map<String, Integer> buildPromotionAdditionalNotesCountMap(TransactionJournal tj) {
    Map<String, Integer> additionalNotesCountMap = new Map<String, Integer>();
    if (tj == null || tj.PromotionId == null || tj.MemberId == null) {
      return additionalNotesCountMap;
    }

    List<PromotionPointLimit__c> pointLimitList = [
      SELECT Type__c, Value__c, LoyaltyPgmCurrencySubtypeId__c, LoyaltyPgmCurrencySubtypeId__r.Name
      FROM PromotionPointLimit__c
      WHERE PromotionId__c = :tj.PromotionId AND Type__c IN ('none', 'rate')
    ];
    if (pointLimitList.isEmpty()) {
      return additionalNotesCountMap;
    }

    Map<Id, Integer> targetSubtypeCountMap = new Map<Id, Integer>();
    Boolean hasNoneTypeLimit = false;
    for (PromotionPointLimit__c pointLimit : pointLimitList) {
      if ('none'.equals(pointLimit.Type__c) && pointLimit.LoyaltyPgmCurrencySubtypeId__c != null) {
        hasNoneTypeLimit = true;
        Id subtypeId = pointLimit.LoyaltyPgmCurrencySubtypeId__c;
        targetSubtypeCountMap.put(subtypeId, (targetSubtypeCountMap.containsKey(subtypeId) ? targetSubtypeCountMap.get(subtypeId) : 0) + 1);
      }
    }

    if (hasNoneTypeLimit) {
      List<LoyaltyPgmCurrencySubtype> eventPointSubtypeList = [
        SELECT Id, Name
        FROM LoyaltyPgmCurrencySubtype
        WHERE Name = :POINT_SUB_TYPE_NAME_EVENT
        LIMIT 1
      ];
      if (!eventPointSubtypeList.isEmpty()) {
        LoyaltyPgmCurrencySubtype eventPointSubtype = eventPointSubtypeList[0];
        List<LoyaltyTierBenefit> rawLtbList = [
          SELECT Benefit.PurchasePointRate__c, Benefit.LoyaltyPgmCurrencySubtypeId__c
          FROM LoyaltyTierBenefit
          WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :tj.MemberId)
        ];

        for (LoyaltyTierBenefit ltb : rawLtbList) {
          Id benefitSubtypeId = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c;
          Decimal rate = ltb.Benefit.PurchasePointRate__c;
          Integer subtypeCount = (benefitSubtypeId == null || !targetSubtypeCountMap.containsKey(benefitSubtypeId))
            ? 0
            : targetSubtypeCountMap.get(benefitSubtypeId);
          if (benefitSubtypeId == null || rate == null || rate <= 0 || subtypeCount <= 0) {
            continue;
          }

          String key = eventPointSubtype.Name + '|' + String.valueOf(eventPointSubtype.Id) + '|' + String.valueOf(rate);
          additionalNotesCountMap.put(key, (additionalNotesCountMap.containsKey(key) ? additionalNotesCountMap.get(key) : 0) + subtypeCount);
        }
      }
    }

    for (PromotionPointLimit__c pointLimit : pointLimitList) {
      if (
        !'rate'.equals(pointLimit.Type__c) ||
        pointLimit.LoyaltyPgmCurrencySubtypeId__c == null ||
        pointLimit.Value__c == null ||
        pointLimit.Value__c <= 0
      ) {
        continue;
      }

      String key =
        pointLimit.LoyaltyPgmCurrencySubtypeId__r.Name +
        '|' +
        String.valueOf(pointLimit.LoyaltyPgmCurrencySubtypeId__c) +
        '|' +
        String.valueOf(pointLimit.Value__c);
      additionalNotesCountMap.put(key, (additionalNotesCountMap.containsKey(key) ? additionalNotesCountMap.get(key) : 0) + 1);
    }

    return additionalNotesCountMap;
  }

  public class UsageBucket {
    public Id loyaltyLedgerTraceabilityId;
    public Date expiryDate;
    public String pointSubTypeName;
    public Integer usagePriority;
    public Decimal usagePoints = 0;
    public Id loyaltyPgmCurrencySubtypeId;
    public String creditLoyaltyLedgerId;
    public String debitLoyaltyLedgerId;

    public UsageBucket(Id id, Date e, String s, Integer p, Id lpcsi, String clli, String dlli) {
      loyaltyLedgerTraceabilityId = id;
      expiryDate = e;
      pointSubTypeName = s;
      usagePriority = p;
      loyaltyPgmCurrencySubtypeId = lpcsi;
      creditLoyaltyLedgerId = clli;
      debitLoyaltyLedgerId = dlli;
    }
  }

  // 포인트 사용 취소 할 포인트 정렬 메서드
  public class UsageBucketCancelSorter implements System.Comparator<Object> {
    public Integer compare(Object a, Object b) {
      UsageBucket x = (UsageBucket) a;
      UsageBucket y = (UsageBucket) b;
      // 만료일이 느린 순으로 정렬
      if (x.expiryDate > y.expiryDate) {
        return -1; // x를 먼저
      }
      if (x.expiryDate < y.expiryDate) {
        return 1; // y를 먼저
      }

      // 우선순위 정렬 (사용 우선 순위가 낮은 순서대로 정렬)
      if (x.usagePriority > y.usagePriority) {
        return -1;
      }
      if (x.usagePriority < y.usagePriority) {
        return 1;
      }

      // 최종 (이름 순..)
      return x.pointSubTypeName.toLowerCase().compareTo(y.pointSubTypeName.toLowerCase());
    }
  }

  // 포인트 사용 취소를 위한 클래스
  public class CancelPortion {
    public Id loyaltyLedgerTraceabilityId;
    public Date expiryDate;
    public String pointSubTypeName;
    public Integer usagePriority;
    public Decimal cancelPoints;
    public Id loyaltyPgmCurrencySubtypeId;
    public String creditLoyaltyLedgerId;
    public String debitLoyaltyLedgerId;

    public CancelPortion(UsageBucket ub, Decimal cancelPoints) {
      this.loyaltyLedgerTraceabilityId = ub.loyaltyLedgerTraceabilityId;
      this.expiryDate = ub.expiryDate;
      this.pointSubTypeName = ub.pointSubTypeName;
      this.usagePriority = ub.usagePriority;
      this.cancelPoints = cancelPoints;
      this.loyaltyPgmCurrencySubtypeId = ub.loyaltyPgmCurrencySubtypeId;
      this.creditLoyaltyLedgerId = ub.creditLoyaltyLedgerId;
      this.debitLoyaltyLedgerId = ub.debitLoyaltyLedgerId;
    }
  }

  // 에코포인트 지급 취소 복원 (재지급)
  // private static List<PointCreditDTO> restoreEcoPointsFromReturn(TransactionJournal newTj, Id sourceTransactionJournalId) {
  public List<PointCreditDTO> restoreEcoPointsFromReturn(Id orderId) {
    Id apiForcedDebitJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_DEBIT, true); // api 요청에 의한 강제 차감

    // 에코포인트 지급 취소 저널 조회
    List<TransactionJournal> ecoCreditCancelJournalList = [
      SELECT
        Id,
        JournalSubTypeId,
        PaymentMethod,
        TransactionAmount,
        OrderId,
        LoyaltyProgramId,
        MemberId,
        SaleId__c,
        DepositNo__c,
        IsDeleted__c,
        DeleteDateTime__c,
        VoucherCode,
        JournalDate,
        Order.EndDate,
        InsertId__c,
        Order.ActualPaymentAmount__c,
        Promotion.PromotionNo__c,
        AdditionalNotes__c
      FROM TransactionJournal
      WHERE SaleId__c = :orderId AND AdditionalNotes__c = :ECO_POINT_CANCEL_NOTE AND JournalSubTypeId = :apiForcedDebitJstId
      LIMIT 1
    ];
    if (ecoCreditCancelJournalList.isEmpty()) {
      return new List<PointCreditDTO>();
    }

    TransactionJournal newTj = new TransactionJournal();

    newTj.LoyaltyProgramId = ecoCreditCancelJournalList[0].LoyaltyProgramId; // 로열티 프로그램 Id
    newTj.MemberId = ecoCreditCancelJournalList[0].MemberId; // 적립 대상 멤버 Id
    // if (endDate != null) {
    //   newTj.JournalDate = TimeUtil.dateToUtcStartOfDay(endDate); // 거래 일자
    //   newTj.ActivityDate = TimeUtil.dateToUtcStartOfDay(endDate); // 활동 일자

    //   expirationDate = endDate.addYears(2);
    // } else {
    newTj.JournalDate = Datetime.now(); // 거래 일자
    newTj.ActivityDate = Datetime.now(); // 활동 일자
    // }
    newTj.TransactionAmount = ecoCreditCancelJournalList[0].TransactionAmount; // 지급 포인트
    newTj.JournalTypeId = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true);
    newTj.JournalSubTypeId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT, true);
    // if (saleId != null) {
    newTj.OrderId = ecoCreditCancelJournalList[0].OrderId;
    newTj.SaleId__c = ecoCreditCancelJournalList[0].SaleId__c;
    newTj.AdditionalNotes__c = ECO_POINT_RESTORE_NOTE;
    // }

    insert newTj;

    List<LoyaltyLedgerTraceability> lltList = [
      SELECT CreditLoyaltyLedger.ExpiryDate, LoyaltyPgmCurrencySubtype.Name, Points, DebitLoyaltyLedger.AdditionalNotes
      FROM LoyaltyLedgerTraceability
      WHERE DebitLoyaltyLedger.TransactionJournal.Id = :ecoCreditCancelJournalList[0].Id
      LIMIT 200
    ];
    if (lltList.isEmpty()) {
      return new List<PointCreditDTO>();
    }

    // return getPointService().creditSepcificPoints(newTj, lltList);

    // Id creditPointJt = SObjectUtil.findIdByName(JournalType.SObjectType, JOURNAL_TYPE_NAME_ACCRUAL, true); // 포인트/쿠폰 지급
    // Id purchaseAccrualJt = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_API_FORCED_CREDIT, true); // API 요청에 의한 포인트 강제 지급(적립) 처리

    // newTj.JournalTypeId = creditPointJt;
    // newTj.JournalSubTypeId = purchaseAccrualJt;

    // insert newTj;

    List<Map<String, Object>> reqList = new List<Map<String, Object>>();

    for (LoyaltyLedgerTraceability llt : lltList) {
      Map<String, Object> req = new Map<String, Object>();
      req.put('loyaltyProgramMemberId', newTj.MemberId);
      req.put('journalId', newTj.Id);
      req.put('loyaltyProgramCurrencySubtypeName', llt.LoyaltyPgmCurrencySubtype.Name);
      req.put('points', llt.Points);
      req.put('additionalNotes', ECO_POINT_RESTORE_NOTE);
      req.put('pointsExpirationDate', String.valueOf(llt.CreditLoyaltyLedger.ExpiryDate));
      reqList.add(req);
    }

    LoyaltyPointService.creditPoints(reqList);

    List<LoyaltyLedger> llList = [
      SELECT
        Id,
        TransactionJournalId,
        LoyaltyPgmCrcySubtype.Name,
        Points,
        ExpiryDate,
        EscrowPointsCreditDate,
        ActivityDate,
        CreatedDate,
        EventType,
        AdditionalNotes,
        LoyaltyPgmCrcySubtype.PointTypeCode__c
      FROM LoyaltyLedger
      WHERE TransactionJournalId = :newTj.Id
      LIMIT 100
    ];

    TransactionJournal tj2 = [
      SELECT
        Id,
        MemberId,
        TYPEOF Member
          WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
        END
      FROM TransactionJournal
      WHERE Id = :newTj.Id
      LIMIT 1
    ];
    SObject memberObj = tj2.getSObject('Member');
    if (memberObj == null) {
      throw new CustomException(500, 'memberObj is null');
    }
    SObject contactObj = memberObj.getSObject('Contact');
    if (contactObj == null) {
      throw new CustomException(500, 'contactObj is null');
    }
    String memberNo = ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);

    Decimal totalPoints = 0;

    List<PointCreditDTO> pcDtoList = new List<PointCreditDTO>();
    for (LoyaltyLedger ll : llList) {
      PointCreditDTO pcDto = new PointCreditDTO();
      pcDto.CD_JOURNAL = ll.Id; // tj.Id; -> ll.Id; (26.02.03)
      pcDto.CD_TYPE_POINT = ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      pcDto.NO_MBR = memberNo;
      pcDto.PT_TARGET = ll.Points; // 적립 포인트
      pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate); // 해당 포인트 적립 예정일
      pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate); // 포인트 유효기간 시작일
      pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate); // 포인트 유효기간 종료일
      pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate.addDays(1)); // 소멸 예정일
      pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate); // 등록 일자
      pcDto.CD_TYPE_SAVE = ll.EventType; // 적립구분
      pcDto.TX_REMARK = ll.AdditionalNotes; // 비고
      pcDtoList.add(pcDto);

      if (ll.Points > 0) {
        totalPoints += ll.Points;
      }
    }
    newTj.TransactionAmount = totalPoints;
    update newTj;

    return pcDtoList;
  }

  // 포인트 적립 추적용 클래스 - 2026-04-04 Carson
  public class CreditTraceSeed {
    public Id creditLedgerId;
    public Decimal points;

    public CreditTraceSeed(Id creditLedgerId, Decimal points) {
      this.creditLedgerId = creditLedgerId;
      this.points = points;
    }
  }

  // 포인트 사용 취소를 위한 추적용 클래스
  public class TraceSeed {
    public Id debitLedgerId;
    public LoyaltyLedger creditLedger;

    public TraceSeed(Id debitLedgerId, LoyaltyLedger creditLedger) {
      this.debitLedgerId = debitLedgerId;
      this.creditLedger = creditLedger;
    }
  }

  // 구매 적립 포인트 취소를 위한 클래스
  public class CancelPurchasePoints {
    public Decimal points; // 해당 비율/타입에 대해 남아 있는 순 포인트
    public Id loyaltyPgmCrcySubtypeId; // 포인트 하위 유형 Id
    public String loyaltyPgmCrcySubtypeName; // 포인트 하위 유형 Name
    public Decimal rate;
    public Integer cancelAmountMultiplier;

    public CancelPurchasePoints(Decimal p, Id lpcsi, String lpcsn, Decimal r) {
      this(p, lpcsi, lpcsn, r, 1);
    }

    public CancelPurchasePoints(Decimal p, Id lpcsi, String lpcsn, Decimal r, Integer m) {
      this.points = p;
      this.loyaltyPgmCrcySubtypeId = lpcsi;
      this.loyaltyPgmCrcySubtypeName = lpcsn;
      this.rate = r;
      this.cancelAmountMultiplier = m;
    }
  }

  // 구매 적립 포인트 취소를 위한 정렬 메서드
  public class CancelRateSorter implements Comparator<CancelPurchasePoints> {
    public Integer compare(CancelPurchasePoints a, CancelPurchasePoints b) {
      if (a.rate == null && b.rate == null) {
        return 0;
      }
      if (a.rate == null) {
        return 1;
      }
      if (b.rate == null) {
        return -1;
      }

      if (a.rate < b.rate) {
        return -1;
      }
      if (a.rate > b.rate) {
        return 1;
      }
      return 0;
    }
  }

  public class DepositResponseDTO {
    public String CD_TYPE_APPR; // 결제 구분
    public Decimal AM_DEPOSIT; // 금액
    public String NO_COUPON_ALL; // 쿠폰 코드
    public String NM_COUPON; // 쿠폰명
    public Date DT_EXP; // 만료 날짜
    public Integer RT_DISC; // 할인율
    public Decimal AM_DISC; // 할인 금액
    public String TX_REMARK; // 비고
  }

  // 사용한 포인트 집계용 클래스
  public class LedgerAggKey {
    public String memberNo;
    public Id currencySubtypeId;
    public Date expiryDate;
    public String pointSubtypeName;
    public Id debitLoyaltyLedgerId;
    public Id creditLoyaltyLedgerId;
    public String insertId;
    public String createdDate;
    public String saleOrOrderNo;
    public String returnSaleNo;
    public Decimal actualPaymentAmount;
    public boolean isReductionOrder;
    public String depositNo;

    public LedgerAggKey(LoyaltyLedgerTraceability llt) {
      this.memberNo = llt.LoyaltyProgramMember.Contact.MemberNo__c;
      this.currencySubtypeId = llt.LoyaltyPgmCurrencySubtypeId;
      this.expiryDate = llt.CreditLoyaltyLedger.ExpiryDate;
      this.pointSubtypeName = llt.LoyaltyPgmCurrencySubtype.Name;
      this.debitLoyaltyLedgerId = llt.DebitLoyaltyLedgerId;
      this.creditLoyaltyLedgerId = llt.CreditLoyaltyLedgerId;
      this.insertId = llt.DebitLoyaltyLedger.TransactionJournal.InsertId__c;
      this.createdDate = llt.CreatedDate.format('yyyyMMddHHmmss');
      String saleSaleNo = llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c;
      String saleOrderNo = llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.OrderNo__c;
      String orderSaleNo = llt.DebitLoyaltyLedger.TransactionJournal.Order.SaleNo__c;
      String orderOrderNo = llt.DebitLoyaltyLedger.TransactionJournal.Order.OrderNo__c;
      this.returnSaleNo = saleSaleNo;
      this.saleOrOrderNo = !String.isBlank(saleSaleNo)
        ? saleSaleNo
        : (!String.isBlank(saleOrderNo) ? saleOrderNo : (!String.isBlank(orderSaleNo) ? orderSaleNo : orderOrderNo));
      this.actualPaymentAmount = (llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.ActualPaymentAmount__c != null)
        ? llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.ActualPaymentAmount__c
        : llt.DebitLoyaltyLedger.TransactionJournal.Order.ActualPaymentAmount__c;
      Boolean hasSaleContext = !String.isBlank(saleSaleNo) || !String.isBlank(saleOrderNo);
      this.isReductionOrder = hasSaleContext
        ? llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.IsReductionOrder__c
        : llt.DebitLoyaltyLedger.TransactionJournal.Order.IsReductionOrder__c;
      this.depositNo = llt.DebitLoyaltyLedger.TransactionJournal.DepositNo__c;
    }

    public Boolean equals(Object obj) {
      if (obj == null || !(obj instanceof LedgerAggKey)) {
        return false;
      }
      LedgerAggKey other = (LedgerAggKey) obj;
      return this.currencySubtypeId == other.currencySubtypeId && this.expiryDate == other.expiryDate;
    }

    public Integer hashCode() {
      return (String.valueOf(currencySubtypeId) + '|' + String.valueOf(expiryDate)).hashCode();
    }
  }

  /**
   * 포인트 적립 대상 여부 판단
   */
  public class OriginalAccrualTraceBucket {
    public Id creditLoyaltyLedgerId;
    public Id loyaltyPgmCurrencySubtypeId;
    public Decimal remainingPoints;

    public OriginalAccrualTraceBucket(Id creditLoyaltyLedgerId, Id loyaltyPgmCurrencySubtypeId, Decimal remainingPoints) {
      this.creditLoyaltyLedgerId = creditLoyaltyLedgerId;
      this.loyaltyPgmCurrencySubtypeId = loyaltyPgmCurrencySubtypeId;
      this.remainingPoints = remainingPoints;
    }
  }

  public class ManualCreditCancellationSeed {
    public Id debitLoyaltyLedgerId;
    public Id loyaltyPgmCurrencySubtypeId;
    public Id loyaltyProgramCurrencyId;
    public Decimal points;

    public ManualCreditCancellationSeed(Id debitLoyaltyLedgerId, Id loyaltyPgmCurrencySubtypeId, Id loyaltyProgramCurrencyId, Decimal points) {
      this.debitLoyaltyLedgerId = debitLoyaltyLedgerId;
      this.loyaltyPgmCurrencySubtypeId = loyaltyPgmCurrencySubtypeId;
      this.loyaltyProgramCurrencyId = loyaltyProgramCurrencyId;
      this.points = points;
    }
  }

  private class OriginRestoreCreditState {
    public Integer remainingCap;
    public Boolean isInvalid;

    public OriginRestoreCreditState(Integer remainingCap, Boolean isInvalid) {
      this.remainingCap = remainingCap == null ? 0 : remainingCap;
      this.isInvalid = isInvalid == true;
    }
  }

  @TestVisible
  private static List<LoyaltyLedger> findCancelableAccrualCreditLedgers(TransactionJournal sourceTj, Id accrualJtId, Id accrualJstId) {
    if (sourceTj == null || accrualJtId == null || accrualJstId == null) {
      return new List<LoyaltyLedger>();
    }

    String originCreditLedgerNoteLike = '%ORIGIN_CREDIT_LL=%';

    if (sourceTj.OrderId__c != null) {
      return [
        SELECT Id, Points, AdditionalNotes, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtypeId, EventType, ExpiryDate, ActivityDate, CreatedDate
        FROM LoyaltyLedger
        WHERE
          TransactionJournal.SaleId__c = :sourceTj.SaleId__c
          AND TransactionJournal.JournalTypeId = :accrualJtId
          AND TransactionJournal.JournalSubTypeId = :accrualJstId
          AND EventType = 'Credit'
          AND ExpiryDate >= :Date.today()
          AND (TransactionJournal.AdditionalNotes__c = NULL
          OR TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
          AND (AdditionalNotes = NULL
          OR (NOT AdditionalNotes LIKE :originCreditLedgerNoteLike))
        ORDER BY CreatedDate ASC
        LIMIT 1000
      ];
    }

    return [
      SELECT Id, Points, AdditionalNotes, LoyaltyPgmCrcySubtype.Name, LoyaltyPgmCrcySubtypeId, EventType, ExpiryDate, ActivityDate, CreatedDate
      FROM LoyaltyLedger
      WHERE
        TransactionJournal.OrderId = :sourceTj.OrderId
        AND TransactionJournal.JournalTypeId = :accrualJtId
        AND TransactionJournal.JournalSubTypeId = :accrualJstId
        AND EventType = 'Credit'
        AND ExpiryDate >= :Date.today()
        AND (TransactionJournal.AdditionalNotes__c = NULL
        OR TransactionJournal.AdditionalNotes__c NOT IN :RESTORE_NOTES)
        AND (AdditionalNotes = NULL
        OR (NOT AdditionalNotes LIKE :originCreditLedgerNoteLike))
      ORDER BY CreatedDate ASC
      LIMIT 1000
    ];
  }

  public Boolean isAccrualEligible(TransactionJournal tj) {
    if (!('01'.equals(tj.DepositType__c) || '02'.equals(tj.DepositType__c))) {
      return false;
    }

    if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
      return false;
    }

    if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
      return false;
    }

    return true;
  }

  // 프로모션 포인트 정률 적립 확인
  @TestVisible
  private static Boolean hasRatePromotionPointLimit(List<PromotionPointLimit__c> pointLimitList) {
    for (PromotionPointLimit__c pointLimit : pointLimitList) {
      if (
        'rate'.equals(pointLimit.Type__c) &&
        pointLimit.LoyaltyPgmCurrencySubtypeId__c != null &&
        pointLimit.Value__c != null &&
        pointLimit.Value__c > 0
      ) {
        return true;
      }
    }
    return false;
  }

  @TestVisible
  private static Decimal calculateOriginalPurchaseAccrualBaseAmount(TransactionJournal sourceTj) {
    if (sourceTj == null) {
      return 0;
    }

    Id targetOrderId = sourceTj.OrderId;
    if (sourceTj.OrderId__c != null && String.isNotBlank(sourceTj.SaleId__c)) {
      try {
        targetOrderId = (Id) sourceTj.SaleId__c;
      } catch (Exception e) {
        targetOrderId = sourceTj.OrderId;
      }
    }
    if (targetOrderId == null) {
      return 0;
    }

    Id saleDepositJstId = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_SALE_DEPOSIT, true);
    Decimal totalAmount = 0;
    for (TransactionJournal tj : [
      SELECT PaymentMethod, TransactionAmount
      FROM TransactionJournal
      WHERE OrderId = :targetOrderId AND JournalSubTypeId = :saleDepositJstId AND IsDeleted__c = FALSE
    ]) {
      if (tj.PaymentMethod == '20' || tj.PaymentMethod == '81' || tj.PaymentMethod == '90' || tj.PaymentMethod == '93') {
        continue;
      }
      if (tj.TransactionAmount == null || tj.TransactionAmount == 0) {
        continue;
      }
      totalAmount += tj.TransactionAmount;
    }

    return totalAmount;
  }

  @TestVisible
  private static String buildFallbackPurchaseCancelBucketKey(LoyaltyLedger ll, Decimal baseAmount) {
    if (
      ll == null ||
      ll.Points == null ||
      ll.Points <= 0 ||
      baseAmount == null ||
      baseAmount <= 0 ||
      ll.LoyaltyPgmCrcySubtypeId == null ||
      ll.LoyaltyPgmCrcySubtype == null ||
      String.isBlank(ll.LoyaltyPgmCrcySubtype.Name)
    ) {
      return null;
    }

    Decimal rate = ((ll.Points.abs() / baseAmount) * 100).setScale(6, RoundingMode.HALF_UP);
    if (rate <= 0) {
      return null;
    }
    return ll.LoyaltyPgmCrcySubtype.Name + '|' + String.valueOf(ll.LoyaltyPgmCrcySubtypeId) + '|' + String.valueOf(rate);
  }

  @TestVisible
  private static Decimal calculateEligibleAccrualAmount(List<TransactionJournal> data, Decimal excludeAmount) {
    if (data == null || data.isEmpty()) {
      return 0;
    }

    Decimal totalAmount = 0;
    for (TransactionJournal v : data) {
      if (v == null) {
        continue;
      }
      if (v.PaymentMethod == '20' || v.PaymentMethod == '81' || v.PaymentMethod == '90' || v.PaymentMethod == '93') {
        continue;
      }
      if (v.TransactionAmount == null || v.TransactionAmount == 0) {
        continue;
      }
      totalAmount += v.TransactionAmount;
    }

    if (excludeAmount != null) {
      totalAmount -= excludeAmount;
    }

    return totalAmount;
  }

  @TestVisible
  private static Id resolveRestoreAccrualJournalSubTypeId(Id reversalJournalSubTypeId) {
    Id cancelPurchaseAccrualJt = SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_CANCEL_PURCHASE_ACCRUAL, true);
    if (reversalJournalSubTypeId == cancelPurchaseAccrualJt) {
      return SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PURCHASE_ACCRUAL, true);
    }

    Id promotionPointAccrualReversalJt = SObjectUtil.findIdByName(
      JournalSubType.SObjectType,
      JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL_REVERSAL,
      true
    );
    if (reversalJournalSubTypeId == promotionPointAccrualReversalJt) {
      return SObjectUtil.findIdByName(JournalSubType.SObjectType, JOURNAL_SUB_TYPE_NAME_PROMOTION_POINT_ACCRUAL, true);
    }

    return reversalJournalSubTypeId;
  }

  @TestVisible
  private static String resolveMemberNoFromTransactionJournal(Id journalId) {
    TransactionJournal tj2 = [
      SELECT
        Id,
        MemberId,
        TYPEOF Member
          WHEN LoyaltyProgramMember THEN Contact.MemberNo__c
        END
      FROM TransactionJournal
      WHERE Id = :journalId
      LIMIT 1
    ];
    SObject memberObj = tj2.getSObject('Member');
    if (memberObj == null) {
      throw new CustomException(500, 'memberObj is null');
    }
    SObject contactObj = memberObj.getSObject('Contact');
    if (contactObj == null) {
      throw new CustomException(500, 'contactObj is null');
    }
    return ValidationUtil.stringValidationEx(contactObj.get('MemberNo__c'), 'MemberNo__c', true, false);
  }

  // 신규 로직 (2026-04-?? Hana) Start.
  @TestVisible
  private static Set<Id> resolvePartialReturnRelatedOrderIds(TransactionJournal tj) {
    Set<Id> relatedOrderIds = new Set<Id>();
    List<Id> seedOrderIds = new List<Id>();

    if (tj.OrderId != null) {
      relatedOrderIds.add(tj.OrderId);
      seedOrderIds.add(tj.OrderId);
    }
    if (tj.SaleId__c != null) {
      relatedOrderIds.add(tj.SaleId__c);
      seedOrderIds.add(tj.SaleId__c);
    }

    Set<Id> pendingOrderIds = new Set<Id>(seedOrderIds);
    Integer hop = 0;
    while (!pendingOrderIds.isEmpty() && hop < 5) {
      Set<Id> nextOrderIds = new Set<Id>();
      for (Order ord : [
        SELECT Id, OriginalOrderId__c
        FROM Order
        WHERE Id IN :pendingOrderIds
      ]) {
        if (ord.OriginalOrderId__c != null && !relatedOrderIds.contains(ord.OriginalOrderId__c)) {
          relatedOrderIds.add(ord.OriginalOrderId__c);
          nextOrderIds.add(ord.OriginalOrderId__c);
        }
      }
      pendingOrderIds = nextOrderIds;
      hop++;
    }

    return relatedOrderIds;
  }
  // 신규 로직 (2026-04-?? Hana) End.

  // [수정] 2026-04-03 (하나): 부분 반품 시, 포인트 사용 취소 로직 수정
  // 기존 : 현재 취소하려는 반품 저널의 orderid와 같은 주문에 묶인 사용 포인트만 조회
  // 수정 : 원 주문/판매의 orderid/saleid__c에 묶인 사용 포인트 모두 조회
  @TestVisible
  private static List<LoyaltyLedgerTraceability> findDebitTraceabilityForPartialReturnCancellation(TransactionJournal tj) {
    Set<Id> relatedOrderIds = resolvePartialReturnRelatedOrderIds(tj);
    if (relatedOrderIds.isEmpty()) {
      return new List<LoyaltyLedgerTraceability>();
    }

    return [
      SELECT
        Id,
        CreditLoyaltyLedgerId,
        DebitLoyaltyLedgerId,
        CreditLoyaltyLedger.ExpiryDate,
        LoyaltyPgmCurrencySubtype.Name,
        LoyaltyPgmCurrencySubtype.UsagePriorityNumber,
        ActionType,
        Points,
        LoyaltyPgmCurrencySubtypeId
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :tj.MemberId
        AND (DebitLoyaltyLedger.TransactionJournal.OrderId IN :relatedOrderIds
        OR DebitLoyaltyLedger.TransactionJournal.SaleId__c IN :relatedOrderIds)
        AND ActionType = 'Debit'
        AND (DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c = NULL
        OR DebitLoyaltyLedger.TransactionJournal.AdditionalNotes__c != :RETURN_DEPOSIT_DELETE_POINT_RESTORE_NOTE)
        AND Points > 0
      LIMIT 100
    ];
  }

  @TestVisible
  private static List<PointCreditDTO> buildPointCreditDtos(List<LoyaltyLedger> llList, String memberNo, String defaultPointTypeCode) {
    List<PointCreditDTO> result = new List<PointCreditDTO>();
    for (LoyaltyLedger ll : llList) {
      PointCreditDTO pcDto = new PointCreditDTO();
      pcDto.CD_JOURNAL = ll.Id;
      pcDto.CD_TYPE_POINT = (defaultPointTypeCode != null) ? defaultPointTypeCode : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      pcDto.NO_MBR = memberNo;
      pcDto.PT_TARGET = ll.Points;
      pcDto.DT_SAVE_PLAN = String.valueOf(ll.EscrowPointsCreditDate);
      pcDto.DT_LIMIT_START = String.valueOf(ll.ActivityDate);
      pcDto.DT_LIMIT_END = String.valueOf(ll.ExpiryDate);
      pcDto.DT_DESTROY_PLAN = String.valueOf(ll.ExpiryDate.addDays(1));
      pcDto.DTS_INSERT = String.valueOf(ll.CreatedDate);
      pcDto.CD_TYPE_SAVE = ll.EventType;
      pcDto.TX_REMARK = ll.AdditionalNotes;
      result.add(pcDto);
    }
    return result;
  }

  @TestVisible
  private static Decimal sumPositiveLedgerPoints(List<LoyaltyLedger> llList) {
    Decimal totalPoints = 0;
    for (LoyaltyLedger ll : llList) {
      if (ll.Points > 0) {
        totalPoints += ll.Points;
      }
    }
    return totalPoints;
  }
}