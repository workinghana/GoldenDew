public without sharing class GdPointRefreshPreviewService {
  private static final String PAYMENT_METHOD_POINT = '81';
  private static final Date OPTION_C_OPENING_USE_SOURCE_DATE = Date.newInstance(2020, 1, 1);
  private static final Set<String> ACCRUAL_EXCLUDED_PAYMENT_METHODS = new Set<String>{ '20', '81', '90', '93' };
  private static final Set<String> POSITIVE_DEPOSIT_TYPES = new Set<String>{ '01', '02' };
  private static final Set<String> REVERSAL_DEPOSIT_TYPES = new Set<String>{ '03', '05' };

  public class PreviewResult {
    public String memberNo;
    public Id memberId;
    public Date openDate;
    public Integer eventCount;
    public Integer bucketCount;
    public Integer allocationCount;
    public Decimal totalRemaining;
    public Map<String, Decimal> remainingByPointType;
    public List<EventRow> events;
    public List<BucketRow> buckets;
    public List<AllocationRow> allocations;
    public List<DebitCancellationRow> debitCancellations;
    public List<CreditCancellationRow> creditCancellations;
  }

  public class EventRow {
    public String eventKey;
    public String eventType;
    public Date eventDate;
    public Decimal points;
    public String saleNo;
    public String pointTypeCode;
    public String originKey;
    public String sourceDebitEventKey;
    public Boolean manualCredit;
    public String notes;

    EventRow(GdPointRefreshEngine.PointEvent event) {
      this.eventKey = event.eventKey;
      this.eventType = event.eventType;
      this.eventDate = event.eventDate;
      this.points = event.points;
      this.saleNo = event.saleNo;
      this.pointTypeCode = event.pointTypeCode;
      this.originKey = event.originKey;
      this.sourceDebitEventKey = event.sourceDebitEventKey;
      this.manualCredit = event.manualCredit;
      this.notes = event.notes;
    }
  }

  public class BucketRow {
    public String bucketKey;
    public String rootOriginKey;
    public String pointTypeCode;
    public String originSaleNo;
    public Date accrualDate;
    public Date expiryDate;
    public Decimal originalPoints;
    public Decimal remainingPoints;
    public Boolean manualCredit;
    public String notes;

    BucketRow(GdPointRefreshEngine.CreditBucket bucket) {
      this.bucketKey = bucket.bucketKey;
      this.rootOriginKey = bucket.rootOriginKey;
      this.pointTypeCode = bucket.pointTypeCode;
      this.originSaleNo = bucket.originSaleNo;
      this.accrualDate = bucket.accrualDate;
      this.expiryDate = bucket.expiryDate;
      this.originalPoints = bucket.originalPoints;
      this.remainingPoints = bucket.remainingPoints;
      this.manualCredit = bucket.manualCredit;
      this.notes = bucket.notes;
    }
  }

  public class AllocationRow {
    public String debitEventKey;
    public String creditBucketKey;
    public String rootOriginKey;
    public Decimal points;

    AllocationRow(GdPointRefreshEngine.Allocation allocation) {
      this.debitEventKey = allocation.debitEventKey;
      this.creditBucketKey = allocation.creditBucketKey;
      this.rootOriginKey = allocation.rootOriginKey;
      this.points = allocation.points;
    }
  }

  public class CreditCancellationRow {
    public String cancelEventKey;
    public String creditBucketKey;
    public String rootOriginKey;
    public Decimal points;

    CreditCancellationRow(GdPointRefreshEngine.CreditCancellationAllocation allocation) {
      this.cancelEventKey = allocation.cancelEventKey;
      this.creditBucketKey = allocation.creditBucketKey;
      this.rootOriginKey = allocation.rootOriginKey;
      this.points = allocation.points;
    }
  }

  public class DebitCancellationRow {
    public String cancelEventKey;
    public String sourceCreditBucketKey;
    public String restoredCreditBucketKey;
    public String rootOriginKey;
    public Decimal points;

    DebitCancellationRow(GdPointRefreshEngine.DebitCancellationAllocation allocation) {
      this.cancelEventKey = allocation.cancelEventKey;
      this.sourceCreditBucketKey = allocation.sourceCreditBucketKey;
      this.restoredCreditBucketKey = allocation.restoredCreditBucketKey;
      this.rootOriginKey = allocation.rootOriginKey;
      this.points = allocation.points;
    }
  }

  public PreviewResult simulateMember(String memberNo, Date openDate, Decimal openingPoints) {
    Map<String, Decimal> openingPointByType = new Map<String, Decimal>();
    if (openingPoints != null && openingPoints > 0) {
      openingPointByType.put('04', openingPoints);
    }
    return simulateMember(memberNo, openDate, openingPointByType);
  }

  public PreviewResult simulateMember(String memberNo, Date openDate, Map<String, Decimal> openingPointByType) {
    return simulateMember(memberNo, openDate, openingPointByType, true, defaultMigrationCutoff(openDate));
  }

  public PreviewResult simulateMember(
    String memberNo,
    Date openDate,
    Map<String, Decimal> openingPointByType,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    if (String.isBlank(memberNo)) {
      throw new CustomException(400, 'memberNo is required.');
    }
    if (openDate == null) {
      throw new CustomException(400, 'openDate is required.');
    }
    Boolean effectiveUseCutoff = useCreatedDateCutoff == true;
    Datetime effectiveMigrationCutoff = migrationCutoffDateTime == null ? defaultMigrationCutoff(openDate) : migrationCutoffDateTime;

    LoyaltyProgramMember member = [
      SELECT Id, Contact.MemberNo__c, OpeningPointBalance__c
      FROM LoyaltyProgramMember
      WHERE Contact.MemberNo__c = :memberNo
      LIMIT 1
    ];

    Map<String, Decimal> effectiveOpeningPointByType = resolveOpeningPointByType(member, openingPointByType);
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    events.addAll(buildOpeningUseEvents(member.Id, memberNo, openDate, effectiveUseCutoff, effectiveMigrationCutoff));
    events.addAll(buildOpeningEvents(memberNo, openDate, effectiveOpeningPointByType));
    events.addAll(buildBusinessSourceEvents(member.Id, memberNo, openDate, effectiveUseCutoff, effectiveMigrationCutoff));
    events.addAll(buildManualCreditEvents(member.Id, openDate));

    GdPointRefreshEngine.Result engineResult = new GdPointRefreshEngine().simulate(events);

    PreviewResult result = new PreviewResult();
    result.memberNo = memberNo;
    result.memberId = member.Id;
    result.openDate = openDate;
    result.eventCount = events.size();
    result.bucketCount = engineResult.buckets.size();
    result.allocationCount = engineResult.allocations.size();
    result.totalRemaining = engineResult.totalRemaining;
    result.remainingByPointType = engineResult.remainingByPointType;
    result.events = new List<EventRow>();
    result.buckets = new List<BucketRow>();
    result.allocations = new List<AllocationRow>();
    result.debitCancellations = new List<DebitCancellationRow>();
    result.creditCancellations = new List<CreditCancellationRow>();

    for (GdPointRefreshEngine.PointEvent event : events) {
      result.events.add(new EventRow(event));
    }
    for (GdPointRefreshEngine.CreditBucket bucket : engineResult.buckets) {
      result.buckets.add(new BucketRow(bucket));
    }
    for (GdPointRefreshEngine.Allocation allocation : engineResult.allocations) {
      result.allocations.add(new AllocationRow(allocation));
    }
    for (GdPointRefreshEngine.DebitCancellationAllocation allocation : engineResult.debitCancellations) {
      result.debitCancellations.add(new DebitCancellationRow(allocation));
    }
    for (GdPointRefreshEngine.CreditCancellationAllocation allocation : engineResult.creditCancellations) {
      result.creditCancellations.add(new CreditCancellationRow(allocation));
    }

    return result;
  }

  private static Map<String, Decimal> resolveOpeningPointByType(
    LoyaltyProgramMember member,
    Map<String, Decimal> openingPointByType
  ) {
    if (openingPointByType != null && !openingPointByType.isEmpty()) {
      return openingPointByType;
    }

    Map<String, Decimal> result = new Map<String, Decimal>();
    Decimal openingPointBalance = member == null ? null : member.OpeningPointBalance__c;
    if (openingPointBalance != null && openingPointBalance > 0) {
      result.put('04', openingPointBalance);
    }
    return result;
  }

  private static List<GdPointRefreshEngine.PointEvent> buildOpeningEvents(
    String memberNo,
    Date openDate,
    Map<String, Decimal> openingPointByType
  ) {
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    if (openingPointByType == null || openingPointByType.isEmpty()) {
      return events;
    }

    Integer seq = 0;
    for (String pointTypeCode : openingPointByType.keySet()) {
      Decimal points = openingPointByType.get(pointTypeCode);
      if (points == null || points <= 0) {
        continue;
      }
      GdPointRefreshEngine.PointEvent event = new GdPointRefreshEngine.PointEvent(
        'OPENING:' + memberNo + ':' + pointTypeCode,
        GdPointRefreshEngine.EVENT_CREDIT,
        openDate,
        points
      );
      event.sequence = seq++;
      event.pointTypeCode = pointTypeCode;
      event.usagePriority = 999;
      event.expiryDate = openDate.addYears(2);
      event.originKey = event.eventKey;
      event.notes = 'REFRESH_OPENING';
      events.add(event);
    }
    return events;
  }

  private static List<GdPointRefreshEngine.PointEvent> buildOpeningUseEvents(
    Id memberId,
    String memberNo,
    Date openDate,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    List<SourceDeposit> openingUseDeposits = loadOpeningUseDeposits(memberId, openDate, useCreatedDateCutoff, migrationCutoffDateTime);
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    if (openingUseDeposits.isEmpty()) {
      return events;
    }

    Decimal totalUsePoints = 0;
    for (SourceDeposit deposit : openingUseDeposits) {
      totalUsePoints += deposit.amount;
    }
    if (totalUsePoints <= 0) {
      return events;
    }

    String sourceKey = 'OPENING_USE_SOURCE:' + memberNo + ':04';
    GdPointRefreshEngine.PointEvent sourceCredit = new GdPointRefreshEngine.PointEvent(
      sourceKey,
      GdPointRefreshEngine.EVENT_CREDIT,
      OPTION_C_OPENING_USE_SOURCE_DATE,
      totalUsePoints
    );
    sourceCredit.sequence = 0;
    sourceCredit.pointTypeCode = '04';
    sourceCredit.usagePriority = 999;
    sourceCredit.expiryDate = openDate.addYears(2);
    sourceCredit.originKey = sourceKey;
    sourceCredit.notes = 'REFRESH_OPENING_USE_SOURCE';
    events.add(sourceCredit);

    Integer seq = 1;
    for (SourceDeposit deposit : openingUseDeposits) {
      GdPointRefreshEngine.PointEvent debit = new GdPointRefreshEngine.PointEvent(
        'OPENING_USE:' + String.valueOf(deposit.id),
        GdPointRefreshEngine.EVENT_DEBIT,
        deposit.businessDate == null ? openDate : deposit.businessDate,
        deposit.amount
      );
      debit.sequence = seq++;
      debit.saleNo = deposit.saleNo;
      debit.notes = 'REFRESH_OPENING_USE';
      events.add(debit);
    }
    return events;
  }

  private class BusinessOrderState {
    Id orderId;
    String saleNo;
    Id originalOrderId;
    Date businessDate;
    Boolean isReturn;
    Boolean isDeleted;
    Id promotionId;
    String promotionExcludedPointTypes;
  }

  private class SourceDeposit {
    Id id;
    Id orderId;
    String saleNo;
    Id originalOrderId;
    Date businessDate;
    Datetime createdDate;
    Boolean isReturn;
    Boolean isDeleted;
    Boolean orderDeleted;
    String paymentMethod;
    String depositType;
    Decimal amount;
    Id promotionId;
    String promotionExcludedPointTypes;
  }

  private class TierRate {
    String pointTypeCode;
    String pointTypeName;
    Integer usagePriority;
    Decimal rate;
  }

  private class PromotionPointRule {
    String pointTypeCode;
    String pointTypeName;
    Integer usagePriority;
    Decimal rate;
    Integer multiplier = 1;
  }

  private static List<GdPointRefreshEngine.PointEvent> buildBusinessSourceEvents(
    Id memberId,
    String memberNo,
    Date openDate,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    List<SourceDeposit> deposits = loadLiveBusinessDeposits(memberId, openDate, useCreatedDateCutoff, migrationCutoffDateTime);
    Map<Id, List<SourceDeposit>> depositByOrderId = groupDepositsByOrderId(deposits);
    Map<Id, BusinessOrderState> orderById = loadBusinessOrders(memberId, deposits);
    Map<String, TierRate> tierRateByPointType = loadTierRateByPointType(memberId);
    Map<Id, Decimal> excludeAmountByOrderId = loadExcludeAmountByOrderId(orderById.keySet());
    Map<Id, List<PromotionPointRule>> promotionRuleByPromotionId = loadPromotionRuleByPromotionId(collectPromotionIds(orderById), memberId);

    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    Integer seq = 1000;

    for (BusinessOrderState orderState : orderById.values()) {
      if (orderState == null || orderState.businessDate == null) {
        continue;
      }
      List<SourceDeposit> orderDeposits = depositByOrderId.get(orderState.orderId);
      if (orderDeposits == null) {
        orderDeposits = new List<SourceDeposit>();
      }
      if (orderState.businessDate < openDate && orderDeposits.isEmpty()) {
        continue;
      }

      if (orderState.isReturn == true) {
        Decimal pointCancelAmount = sumPointAmount(orderDeposits, true, false);
        if (pointCancelAmount > 0) {
          GdPointRefreshEngine.PointEvent debitCancel = new GdPointRefreshEngine.PointEvent(
            'DEBIT_CANCEL:RETURN:' + String.valueOf(orderState.orderId),
            GdPointRefreshEngine.EVENT_DEBIT_CANCEL,
            orderState.businessDate,
            pointCancelAmount
          );
          debitCancel.sequence = seq++;
          debitCancel.saleNo = orderState.saleNo;
          debitCancel.sourceDebitEventKey = orderState.originalOrderId == null ? null : 'DEBIT:SALE:' + String.valueOf(orderState.originalOrderId);
          debitCancel.notes = 'BUSINESS_RETURN_POINT_CANCEL;SALE=' + orderState.saleNo;
          events.add(debitCancel);
        }

        Decimal creditCancelBase = subtractExcludeAmount(
          sumAccrualEligibleAmount(orderDeposits, true, false),
          excludeAmountByOrderId.get(orderState.orderId)
        );
        if (creditCancelBase > 0) {
          BusinessOrderState originalSale = orderState.originalOrderId == null ? null : orderById.get(orderState.originalOrderId);
          for (TierRate rate : effectiveTierRates(tierRateByPointType, originalSale == null ? null : originalSale.promotionExcludedPointTypes)) {
            Decimal cancelPoints = calculatePoints(creditCancelBase, rate.rate);
            if (cancelPoints <= 0) {
              continue;
            }
            GdPointRefreshEngine.PointEvent creditCancel = new GdPointRefreshEngine.PointEvent(
              'CREDIT_CANCEL:RETURN:' + String.valueOf(orderState.orderId) + ':' + rate.pointTypeCode,
              GdPointRefreshEngine.EVENT_CREDIT_CANCEL,
              orderState.businessDate,
              cancelPoints
            );
            creditCancel.sequence = seq++;
            creditCancel.saleNo = originalSale == null ? null : originalSale.saleNo;
            creditCancel.originKey = buildCreditOriginKey(memberNo, openDate, originalSale, rate.pointTypeCode);
            creditCancel.pointTypeCode = rate.pointTypeCode;
            creditCancel.notes = 'BUSINESS_RETURN_CREDIT_CANCEL;RETURN=' + orderState.saleNo;
            events.add(creditCancel);
          }
          for (PromotionPointRule rule : promotionRulesForOrder(originalSale, promotionRuleByPromotionId)) {
            Decimal cancelPoints = calculatePoints(creditCancelBase, rule.rate) * rule.multiplier;
            if (cancelPoints <= 0) {
              continue;
            }
            GdPointRefreshEngine.PointEvent creditCancel = new GdPointRefreshEngine.PointEvent(
              'CREDIT_CANCEL:RETURN_PROMO:' + String.valueOf(orderState.orderId) + ':' + rule.pointTypeCode,
              GdPointRefreshEngine.EVENT_CREDIT_CANCEL,
              orderState.businessDate,
              cancelPoints
            );
            creditCancel.sequence = seq++;
            creditCancel.saleNo = originalSale == null ? null : originalSale.saleNo;
            creditCancel.originKey = buildPromotionCreditOriginKey(memberNo, openDate, originalSale, rule.pointTypeCode);
            creditCancel.pointTypeCode = rule.pointTypeCode;
            creditCancel.notes = 'BUSINESS_RETURN_PROMOTION_CREDIT_CANCEL;RETURN=' + orderState.saleNo;
            events.add(creditCancel);
          }
        }

        Decimal deletedPointCancelAmount = sumPointAmount(orderDeposits, true, true);
        if (deletedPointCancelAmount > 0) {
          GdPointRefreshEngine.PointEvent debitRestoreDelete = new GdPointRefreshEngine.PointEvent(
            'DEBIT:RETURN_DELETE:' + String.valueOf(orderState.orderId),
            GdPointRefreshEngine.EVENT_DEBIT,
            orderState.businessDate,
            deletedPointCancelAmount
          );
          debitRestoreDelete.sequence = seq++;
          debitRestoreDelete.saleNo = orderState.saleNo;
          debitRestoreDelete.notes = 'BUSINESS_RETURN_DELETE_POINT_REUSE;RETURN=' + orderState.saleNo;
          events.add(debitRestoreDelete);
        }

        Decimal deletedCreditCancelBase = subtractExcludeAmount(
          sumAccrualEligibleAmount(orderDeposits, true, true),
          excludeAmountByOrderId.get(orderState.orderId)
        );
        if (deletedCreditCancelBase > 0) {
          BusinessOrderState originalSale = orderState.originalOrderId == null ? null : orderById.get(orderState.originalOrderId);
          for (TierRate rate : effectiveTierRates(tierRateByPointType, originalSale == null ? null : originalSale.promotionExcludedPointTypes)) {
            Decimal restorePoints = calculatePoints(deletedCreditCancelBase, rate.rate);
            if (restorePoints <= 0) {
              continue;
            }
            GdPointRefreshEngine.PointEvent creditRestore = new GdPointRefreshEngine.PointEvent(
              'CREDIT:RETURN_DELETE_RESTORE:' + String.valueOf(orderState.orderId) + ':' + rate.pointTypeCode,
              GdPointRefreshEngine.EVENT_CREDIT,
              orderState.businessDate,
              restorePoints
            );
            creditRestore.sequence = seq++;
            creditRestore.saleNo = originalSale == null ? null : originalSale.saleNo;
            creditRestore.pointTypeCode = rate.pointTypeCode;
            creditRestore.usagePriority = rate.usagePriority;
            creditRestore.expiryDate = originalSale == null || originalSale.businessDate == null ? orderState.businessDate.addYears(2) : originalSale.businessDate.addYears(2);
            creditRestore.originKey = buildCreditOriginKey(memberNo, openDate, originalSale, rate.pointTypeCode);
            creditRestore.notes = 'BUSINESS_RETURN_DELETE_CREDIT_RESTORE;RETURN=' + orderState.saleNo;
            events.add(creditRestore);
          }
          for (PromotionPointRule rule : promotionRulesForOrder(originalSale, promotionRuleByPromotionId)) {
            Decimal restorePoints = calculatePoints(deletedCreditCancelBase, rule.rate) * rule.multiplier;
            if (restorePoints <= 0) {
              continue;
            }
            GdPointRefreshEngine.PointEvent creditRestore = new GdPointRefreshEngine.PointEvent(
              'CREDIT:RETURN_DELETE_PROMO_RESTORE:' + String.valueOf(orderState.orderId) + ':' + rule.pointTypeCode,
              GdPointRefreshEngine.EVENT_CREDIT,
              orderState.businessDate,
              restorePoints
            );
            creditRestore.sequence = seq++;
            creditRestore.saleNo = originalSale == null ? null : originalSale.saleNo;
            creditRestore.pointTypeCode = rule.pointTypeCode;
            creditRestore.usagePriority = rule.usagePriority;
            creditRestore.expiryDate = originalSale == null || originalSale.businessDate == null ? orderState.businessDate.addYears(2) : originalSale.businessDate.addYears(2);
            creditRestore.originKey = buildPromotionCreditOriginKey(memberNo, openDate, originalSale, rule.pointTypeCode);
            creditRestore.notes = 'BUSINESS_RETURN_DELETE_PROMOTION_CREDIT_RESTORE;RETURN=' + orderState.saleNo;
            events.add(creditRestore);
          }
        }
      } else {
        Decimal creditBase = subtractExcludeAmount(sumAccrualEligibleAmount(orderDeposits, false, false), excludeAmountByOrderId.get(orderState.orderId));
        if (creditBase > 0) {
          for (TierRate rate : effectiveTierRates(tierRateByPointType, orderState.promotionExcludedPointTypes)) {
            Decimal creditPoints = calculatePoints(creditBase, rate.rate);
            if (creditPoints <= 0) {
              continue;
            }
            GdPointRefreshEngine.PointEvent credit = new GdPointRefreshEngine.PointEvent(
              'CREDIT:SALE:' + String.valueOf(orderState.orderId) + ':' + rate.pointTypeCode,
              GdPointRefreshEngine.EVENT_CREDIT,
              orderState.businessDate,
              creditPoints
            );
            credit.sequence = seq++;
            credit.saleNo = orderState.saleNo;
            credit.pointTypeCode = rate.pointTypeCode;
            credit.usagePriority = rate.usagePriority;
            credit.expiryDate = orderState.businessDate.addYears(2);
            credit.originKey = credit.eventKey;
            credit.notes = 'BUSINESS_SALE_CREDIT;SALE=' + orderState.saleNo;
            events.add(credit);
          }
          for (PromotionPointRule rule : promotionRulesForOrder(orderState, promotionRuleByPromotionId)) {
            Decimal promotionPoints = calculatePoints(creditBase, rule.rate) * rule.multiplier;
            if (promotionPoints <= 0) {
              continue;
            }
            GdPointRefreshEngine.PointEvent credit = new GdPointRefreshEngine.PointEvent(
              'CREDIT:PROMO_SALE:' + String.valueOf(orderState.orderId) + ':' + rule.pointTypeCode,
              GdPointRefreshEngine.EVENT_CREDIT,
              orderState.businessDate,
              promotionPoints
            );
            credit.sequence = seq++;
            credit.saleNo = orderState.saleNo;
            credit.pointTypeCode = rule.pointTypeCode;
            credit.usagePriority = rule.usagePriority;
            credit.expiryDate = orderState.businessDate.addYears(2);
            credit.originKey = credit.eventKey;
            credit.notes = 'BUSINESS_PROMOTION_CREDIT;SALE=' + orderState.saleNo;
            events.add(credit);
          }
        }

        Decimal debitAmount = sumPointAmount(orderDeposits, false, false);
        if (debitAmount > 0) {
          GdPointRefreshEngine.PointEvent debit = new GdPointRefreshEngine.PointEvent(
            'DEBIT:SALE:' + String.valueOf(orderState.orderId),
            GdPointRefreshEngine.EVENT_DEBIT,
            orderState.businessDate,
            debitAmount
          );
          debit.sequence = seq++;
          debit.saleNo = orderState.saleNo;
          debit.notes = 'BUSINESS_SALE_POINT_DEBIT;SALE=' + orderState.saleNo;
          events.add(debit);
        }

        Decimal deletedCreditBase = subtractExcludeAmount(sumAccrualEligibleAmount(orderDeposits, false, true), excludeAmountByOrderId.get(orderState.orderId));
        if (deletedCreditBase > 0) {
          for (TierRate rate : effectiveTierRates(tierRateByPointType, orderState.promotionExcludedPointTypes)) {
            Decimal cancelPoints = calculatePoints(deletedCreditBase, rate.rate);
            if (cancelPoints <= 0) {
              continue;
            }
            GdPointRefreshEngine.PointEvent creditCancel = new GdPointRefreshEngine.PointEvent(
              'CREDIT_CANCEL:SALE_DELETE:' + String.valueOf(orderState.orderId) + ':' + rate.pointTypeCode,
              GdPointRefreshEngine.EVENT_CREDIT_CANCEL,
              orderState.businessDate,
              cancelPoints
            );
            creditCancel.sequence = seq++;
            creditCancel.saleNo = orderState.saleNo;
            creditCancel.originKey = 'CREDIT:SALE:' + String.valueOf(orderState.orderId) + ':' + rate.pointTypeCode;
            creditCancel.pointTypeCode = rate.pointTypeCode;
            creditCancel.notes = 'BUSINESS_SALE_DELETE_CREDIT_CANCEL;SALE=' + orderState.saleNo;
            events.add(creditCancel);
          }
          for (PromotionPointRule rule : promotionRulesForOrder(orderState, promotionRuleByPromotionId)) {
            Decimal cancelPoints = calculatePoints(deletedCreditBase, rule.rate) * rule.multiplier;
            if (cancelPoints <= 0) {
              continue;
            }
            GdPointRefreshEngine.PointEvent creditCancel = new GdPointRefreshEngine.PointEvent(
              'CREDIT_CANCEL:PROMO_SALE_DELETE:' + String.valueOf(orderState.orderId) + ':' + rule.pointTypeCode,
              GdPointRefreshEngine.EVENT_CREDIT_CANCEL,
              orderState.businessDate,
              cancelPoints
            );
            creditCancel.sequence = seq++;
            creditCancel.saleNo = orderState.saleNo;
            creditCancel.originKey = 'CREDIT:PROMO_SALE:' + String.valueOf(orderState.orderId) + ':' + rule.pointTypeCode;
            creditCancel.pointTypeCode = rule.pointTypeCode;
            creditCancel.notes = 'BUSINESS_SALE_DELETE_PROMOTION_CREDIT_CANCEL;SALE=' + orderState.saleNo;
            events.add(creditCancel);
          }
        }

        Decimal deletedDebitAmount = sumPointAmount(orderDeposits, false, true);
        if (deletedDebitAmount > 0) {
          GdPointRefreshEngine.PointEvent debitCancel = new GdPointRefreshEngine.PointEvent(
            'DEBIT_CANCEL:SALE_DELETE:' + String.valueOf(orderState.orderId),
            GdPointRefreshEngine.EVENT_DEBIT_CANCEL,
            orderState.businessDate,
            deletedDebitAmount
          );
          debitCancel.sequence = seq++;
          debitCancel.saleNo = orderState.saleNo;
          debitCancel.sourceDebitEventKey = 'DEBIT:SALE:' + String.valueOf(orderState.orderId);
          debitCancel.notes = 'BUSINESS_SALE_DELETE_POINT_RESTORE;SALE=' + orderState.saleNo;
          events.add(debitCancel);
        }
      }
    }
    return events;
  }

  private static Map<Id, BusinessOrderState> loadBusinessOrders(Id memberId, List<SourceDeposit> deposits) {
    Map<Id, BusinessOrderState> result = new Map<Id, BusinessOrderState>();
    Set<Id> orderIds = new Set<Id>();
    for (SourceDeposit deposit : deposits) {
      if (deposit.orderId != null) {
        orderIds.add(deposit.orderId);
      }
      if (deposit.originalOrderId != null) {
        orderIds.add(deposit.originalOrderId);
      }
    }
    if (orderIds.isEmpty()) {
      return result;
    }
    for (Order o : [
      SELECT
        Id,
        SaleNo__c,
        EndDate,
        EffectiveDate,
        IsReductionOrder__c,
        IsDeleted__c,
        OriginalOrderId__c
      FROM Order
      WHERE Id IN :orderIds
    ]) {
      BusinessOrderState state = new BusinessOrderState();
      state.orderId = o.Id;
      state.saleNo = o.SaleNo__c;
      state.originalOrderId = o.OriginalOrderId__c;
      state.businessDate = resolveOrderBusinessDate(o);
      state.isReturn = o.IsReductionOrder__c == true;
      state.isDeleted = o.IsDeleted__c == true;
      result.put(o.Id, state);
    }

    for (TransactionJournal tj : [
      SELECT OrderId, SaleId__c, PromotionId, Promotion.PointTypeCode__c
      FROM TransactionJournal
      WHERE MemberId = :memberId AND PromotionId != NULL
      LIMIT 50000
    ]) {
      Id orderId = resolveSourceOrderId(tj);
      if (orderId == null || !result.containsKey(orderId)) {
        continue;
      }
      BusinessOrderState state = result.get(orderId);
      if (state.promotionId == null) {
        state.promotionId = tj.PromotionId;
        state.promotionExcludedPointTypes = tj.Promotion == null ? null : tj.Promotion.PointTypeCode__c;
      }
    }
    return result;
  }

  private static List<SourceDeposit> loadLiveBusinessDeposits(
    Id memberId,
    Date openDate,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    List<SourceDeposit> result = new List<SourceDeposit>();
    for (TransactionJournal tj : [
      SELECT
        Id,
        CreatedDate,
        OrderId,
        SaleId__c,
        PaymentMethod,
        DepositType__c,
        TransactionAmount,
        IsDeleted__c,
        PromotionId,
        Promotion.PointTypeCode__c,
        Order.SaleNo__c,
        Order.EndDate,
        Order.EffectiveDate,
        Order.IsReductionOrder__c,
        Order.IsDeleted__c,
        Order.OriginalOrderId__c,
        SaleId__r.SaleNo__c,
        SaleId__r.EndDate,
        SaleId__r.EffectiveDate,
        SaleId__r.IsReductionOrder__c,
        SaleId__r.IsDeleted__c,
        SaleId__r.OriginalOrderId__c
      FROM TransactionJournal
      WHERE
        MemberId = :memberId
        AND PaymentMethod != NULL
        AND DepositType__c != NULL
      LIMIT 50000
    ]) {
      if (tj.TransactionAmount == null || tj.TransactionAmount <= 0) {
        continue;
      }
      Id orderId = resolveSourceOrderId(tj);
      if (orderId == null) {
        continue;
      }
      Boolean orderDeleted = resolveSourceOrderDeleted(tj);
      Date businessDate = resolveSourceBusinessDate(tj);
      if (!isLiveBusinessEvent(businessDate, tj.CreatedDate, openDate, useCreatedDateCutoff, migrationCutoffDateTime)) {
        continue;
      }

      SourceDeposit deposit = new SourceDeposit();
      deposit.id = tj.Id;
      deposit.orderId = orderId;
      deposit.saleNo = resolveSourceSaleNo(tj);
      deposit.originalOrderId = resolveSourceOriginalOrderId(tj);
      deposit.businessDate = businessDate;
      deposit.createdDate = tj.CreatedDate;
      deposit.isReturn = resolveSourceIsReturn(tj);
      deposit.isDeleted = tj.IsDeleted__c == true;
      deposit.orderDeleted = orderDeleted == true;
      deposit.paymentMethod = tj.PaymentMethod;
      deposit.depositType = tj.DepositType__c;
      deposit.amount = tj.TransactionAmount;
      deposit.promotionId = tj.PromotionId;
      deposit.promotionExcludedPointTypes = tj.Promotion == null ? null : tj.Promotion.PointTypeCode__c;
      result.add(deposit);
    }
    return result;
  }

  private static List<SourceDeposit> loadOpeningUseDeposits(
    Id memberId,
    Date openDate,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    List<SourceDeposit> result = new List<SourceDeposit>();
    for (TransactionJournal tj : [
      SELECT
        Id,
        CreatedDate,
        OrderId,
        SaleId__c,
        PaymentMethod,
        DepositType__c,
        TransactionAmount,
        IsDeleted__c,
        Order.SaleNo__c,
        Order.EndDate,
        Order.EffectiveDate,
        Order.IsReductionOrder__c,
        Order.IsDeleted__c,
        Order.OriginalOrderId__c,
        SaleId__r.SaleNo__c,
        SaleId__r.EndDate,
        SaleId__r.EffectiveDate,
        SaleId__r.IsReductionOrder__c,
        SaleId__r.IsDeleted__c,
        SaleId__r.OriginalOrderId__c
      FROM TransactionJournal
      WHERE
        MemberId = :memberId
        AND PaymentMethod = :PAYMENT_METHOD_POINT
        AND DepositType__c IN :POSITIVE_DEPOSIT_TYPES
        AND TransactionAmount > 0
      ORDER BY ActivityDate ASC, CreatedDate ASC, Id ASC
      LIMIT 50000
    ]) {
      Id orderId = resolveSourceOrderId(tj);
      if (orderId == null) {
        continue;
      }
      Date businessDate = resolveSourceBusinessDate(tj);
      if (!isMigratedPreOpenEvent(businessDate, tj.CreatedDate, openDate, useCreatedDateCutoff, migrationCutoffDateTime)) {
        continue;
      }
      Boolean isReturn = resolveSourceIsReturn(tj);
      if (isReturn == true) {
        continue;
      }
      Boolean orderDeleted = resolveSourceOrderDeleted(tj);
      if (tj.IsDeleted__c == true || orderDeleted == true) {
        continue;
      }

      SourceDeposit deposit = new SourceDeposit();
      deposit.id = tj.Id;
      deposit.orderId = orderId;
      deposit.saleNo = resolveSourceSaleNo(tj);
      deposit.originalOrderId = resolveSourceOriginalOrderId(tj);
      deposit.businessDate = businessDate;
      deposit.createdDate = tj.CreatedDate;
      deposit.isReturn = false;
      deposit.isDeleted = false;
      deposit.orderDeleted = false;
      deposit.paymentMethod = tj.PaymentMethod;
      deposit.depositType = tj.DepositType__c;
      deposit.amount = tj.TransactionAmount;
      result.add(deposit);
    }
    return result;
  }

  private static Map<Id, List<SourceDeposit>> groupDepositsByOrderId(List<SourceDeposit> deposits) {
    Map<Id, List<SourceDeposit>> result = new Map<Id, List<SourceDeposit>>();
    for (SourceDeposit deposit : deposits) {
      if (!result.containsKey(deposit.orderId)) {
        result.put(deposit.orderId, new List<SourceDeposit>());
      }
      result.get(deposit.orderId).add(deposit);
    }
    return result;
  }

  private static Boolean isMigratedPreOpenEvent(
    Date businessDate,
    Datetime createdDate,
    Date openDate,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    if (businessDate == null || openDate == null || businessDate >= openDate) {
      return false;
    }
    if (useCreatedDateCutoff != true) {
      return true;
    }
    Datetime cutoff = migrationCutoffDateTime == null ? defaultMigrationCutoff(openDate) : migrationCutoffDateTime;
    return cutoff != null && createdDate != null && createdDate <= cutoff;
  }

  private static Boolean isLiveBusinessEvent(
    Date businessDate,
    Datetime createdDate,
    Date openDate,
    Boolean useCreatedDateCutoff,
    Datetime migrationCutoffDateTime
  ) {
    if (businessDate == null || openDate == null) {
      return false;
    }
    if (businessDate >= openDate) {
      return true;
    }
    if (useCreatedDateCutoff != true) {
      return false;
    }
    Datetime cutoff = migrationCutoffDateTime == null ? defaultMigrationCutoff(openDate) : migrationCutoffDateTime;
    return cutoff != null && createdDate != null && createdDate > cutoff;
  }

  private static Datetime defaultMigrationCutoff(Date openDate) {
    return openDate == null ? null : TimeUtil.dateToUtcStartOfDay(openDate);
  }

  private static Map<String, TierRate> loadTierRateByPointType(Id memberId) {
    Map<String, TierRate> result = new Map<String, TierRate>();
    for (LoyaltyTierBenefit ltb : [
      SELECT
        Benefit.PurchasePointRate__c,
        Benefit.LoyaltyPgmCurrencySubtypeId__r.Name,
        Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c,
        Benefit.LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber
      FROM LoyaltyTierBenefit
      WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :memberId)
    ]) {
      if (ltb.Benefit == null || ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r == null) {
        continue;
      }
      String pointTypeCode = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;
      if (String.isBlank(pointTypeCode) || ltb.Benefit.PurchasePointRate__c == null || ltb.Benefit.PurchasePointRate__c <= 0) {
        continue;
      }
      TierRate rate = new TierRate();
      rate.pointTypeCode = pointTypeCode;
      rate.pointTypeName = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name;
      rate.usagePriority = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber == null
        ? 999
        : Integer.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber);
      rate.rate = ltb.Benefit.PurchasePointRate__c;
      result.put(pointTypeCode, rate);
    }
    return result;
  }

  private static Map<Id, Decimal> loadExcludeAmountByOrderId(Set<Id> orderIds) {
    Map<Id, Decimal> result = new Map<Id, Decimal>();
    if (orderIds == null || orderIds.isEmpty()) {
      return result;
    }
    for (OrderItem oi : [
      SELECT OrderId, NetSalesUnitPrice__c, Quantity, IsExclude__c
      FROM OrderItem
      WHERE OrderId IN :orderIds AND IsExclude__c = TRUE
      LIMIT 50000
    ]) {
      Decimal unitPrice = oi.NetSalesUnitPrice__c == null ? 0 : oi.NetSalesUnitPrice__c;
      Decimal qty = oi.Quantity == null ? 1 : oi.Quantity;
      Decimal current = result.containsKey(oi.OrderId) ? result.get(oi.OrderId) : 0;
      result.put(oi.OrderId, current + (unitPrice * qty));
    }
    return result;
  }

  private static Set<Id> collectPromotionIds(Map<Id, BusinessOrderState> orderById) {
    Set<Id> result = new Set<Id>();
    if (orderById == null) {
      return result;
    }
    for (BusinessOrderState state : orderById.values()) {
      if (state != null && state.promotionId != null) {
        result.add(state.promotionId);
      }
    }
    return result;
  }

  private static Map<Id, List<PromotionPointRule>> loadPromotionRuleByPromotionId(Set<Id> promotionIds, Id memberId) {
    Map<Id, List<PromotionPointRule>> result = new Map<Id, List<PromotionPointRule>>();
    if (promotionIds == null || promotionIds.isEmpty() || memberId == null) {
      return result;
    }

    Map<Id, TierRate> tierRateBySubtypeId = loadTierRateBySubtypeId(memberId);
    LoyaltyPgmCurrencySubtype eventPointSubtype = loadEventPointSubtype();

    for (PromotionPointLimit__c pointLimit : [
      SELECT
        PromotionId__c,
        Type__c,
        Value__c,
        LoyaltyPgmCurrencySubtypeId__c,
        LoyaltyPgmCurrencySubtypeId__r.Name,
        LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c,
        LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber
      FROM PromotionPointLimit__c
      WHERE PromotionId__c IN :promotionIds AND Type__c IN ('none', 'rate')
    ]) {
      if (pointLimit.PromotionId__c == null || pointLimit.LoyaltyPgmCurrencySubtypeId__c == null) {
        continue;
      }
      PromotionPointRule rule;
      if ('rate'.equals(pointLimit.Type__c)) {
        if (pointLimit.Value__c == null || pointLimit.Value__c <= 0) {
          continue;
        }
        rule = new PromotionPointRule();
        rule.pointTypeCode = pointLimit.LoyaltyPgmCurrencySubtypeId__r == null ? null : pointLimit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;
        rule.pointTypeName = pointLimit.LoyaltyPgmCurrencySubtypeId__r == null ? null : pointLimit.LoyaltyPgmCurrencySubtypeId__r.Name;
        rule.usagePriority = pointLimit.LoyaltyPgmCurrencySubtypeId__r == null || pointLimit.LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber == null
          ? 999
          : Integer.valueOf(pointLimit.LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber);
        rule.rate = pointLimit.Value__c;
      } else {
        if (eventPointSubtype == null || !tierRateBySubtypeId.containsKey(pointLimit.LoyaltyPgmCurrencySubtypeId__c)) {
          continue;
        }
        TierRate tierRate = tierRateBySubtypeId.get(pointLimit.LoyaltyPgmCurrencySubtypeId__c);
        rule = new PromotionPointRule();
        rule.pointTypeCode = eventPointSubtype.PointTypeCode__c;
        rule.pointTypeName = eventPointSubtype.Name;
        rule.usagePriority = eventPointSubtype.UsagePriorityNumber == null ? 999 : Integer.valueOf(eventPointSubtype.UsagePriorityNumber);
        rule.rate = tierRate.rate;
      }

      if (String.isBlank(rule.pointTypeCode) || rule.rate == null || rule.rate <= 0) {
        continue;
      }
      if (!result.containsKey(pointLimit.PromotionId__c)) {
        result.put(pointLimit.PromotionId__c, new List<PromotionPointRule>());
      }
      result.get(pointLimit.PromotionId__c).add(rule);
    }
    return result;
  }

  private static Map<Id, TierRate> loadTierRateBySubtypeId(Id memberId) {
    Map<Id, TierRate> result = new Map<Id, TierRate>();
    for (LoyaltyTierBenefit ltb : [
      SELECT
        Benefit.PurchasePointRate__c,
        Benefit.LoyaltyPgmCurrencySubtypeId__c,
        Benefit.LoyaltyPgmCurrencySubtypeId__r.Name,
        Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c,
        Benefit.LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber
      FROM LoyaltyTierBenefit
      WHERE LoyaltyTierId IN (SELECT LoyaltyTierId FROM LoyaltyMemberTier WHERE LoyaltyMemberId = :memberId)
    ]) {
      if (ltb.Benefit == null || ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c == null || ltb.Benefit.PurchasePointRate__c == null) {
        continue;
      }
      TierRate rate = new TierRate();
      rate.pointTypeCode = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r == null ? null : ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.PointTypeCode__c;
      rate.pointTypeName = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r == null ? null : ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.Name;
      rate.usagePriority = ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r == null || ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber == null
        ? 999
        : Integer.valueOf(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__r.UsagePriorityNumber);
      rate.rate = ltb.Benefit.PurchasePointRate__c;
      result.put(ltb.Benefit.LoyaltyPgmCurrencySubtypeId__c, rate);
    }
    return result;
  }

  private static LoyaltyPgmCurrencySubtype loadEventPointSubtype() {
    List<LoyaltyPgmCurrencySubtype> rows = [
      SELECT Id, Name, PointTypeCode__c, UsagePriorityNumber
      FROM LoyaltyPgmCurrencySubtype
      WHERE Name = '이벤트포인트'
      LIMIT 1
    ];
    return rows.isEmpty() ? null : rows[0];
  }

  private static List<PromotionPointRule> promotionRulesForOrder(
    BusinessOrderState orderState,
    Map<Id, List<PromotionPointRule>> promotionRuleByPromotionId
  ) {
    if (orderState == null || orderState.promotionId == null || promotionRuleByPromotionId == null) {
      return new List<PromotionPointRule>();
    }
    List<PromotionPointRule> rules = promotionRuleByPromotionId.get(orderState.promotionId);
    return rules == null ? new List<PromotionPointRule>() : rules;
  }

  private static Decimal subtractExcludeAmount(Decimal amount, Decimal excludeAmount) {
    Decimal result = (amount == null ? 0 : amount) - (excludeAmount == null ? 0 : excludeAmount);
    return result > 0 ? result : 0;
  }

  private static List<TierRate> effectiveTierRates(Map<String, TierRate> tierRateByPointType, String excludedPointTypes) {
    Set<String> excluded = parsePointTypeSet(excludedPointTypes);
    List<TierRate> result = new List<TierRate>();
    for (String pointTypeCode : tierRateByPointType.keySet()) {
      if (excluded.contains(pointTypeCode)) {
        continue;
      }
      result.add(tierRateByPointType.get(pointTypeCode));
    }
    return result;
  }

  private static Set<String> parsePointTypeSet(String value) {
    Set<String> result = new Set<String>();
    if (String.isBlank(value)) {
      return result;
    }
    for (String token : value.split(';')) {
      if (String.isNotBlank(token)) {
        result.add(token.trim());
      }
    }
    return result;
  }

  private static Decimal sumAccrualEligibleAmount(List<SourceDeposit> deposits, Boolean isReturn, Boolean deletedOnly) {
    Decimal total = 0;
    for (SourceDeposit deposit : deposits) {
      if (deposit == null || deposit.amount == null || deposit.amount <= 0) {
        continue;
      }
      if (deposit.isReturn != isReturn) {
        continue;
      }
      Boolean deletedSource = isDeletedSource(deposit);
      if (deletedOnly == true && !deletedSource) {
        continue;
      }
      if (deletedOnly != true && deletedSource) {
        continue;
      }
      if (ACCRUAL_EXCLUDED_PAYMENT_METHODS.contains(deposit.paymentMethod)) {
        continue;
      }
      if (isReturn == true && !REVERSAL_DEPOSIT_TYPES.contains(deposit.depositType)) {
        continue;
      }
      if (isReturn != true && !POSITIVE_DEPOSIT_TYPES.contains(deposit.depositType)) {
        continue;
      }
      total += deposit.amount;
    }
    return total;
  }

  private static Decimal sumPointAmount(List<SourceDeposit> deposits, Boolean isReturn, Boolean deletedOnly) {
    Decimal total = 0;
    for (SourceDeposit deposit : deposits) {
      if (deposit == null || deposit.amount == null || deposit.amount <= 0 || deposit.paymentMethod != PAYMENT_METHOD_POINT) {
        continue;
      }
      if (deposit.isReturn != isReturn) {
        continue;
      }
      Boolean deletedSource = isDeletedSource(deposit);
      if (deletedOnly == true && !deletedSource) {
        continue;
      }
      if (deletedOnly != true && deletedSource) {
        continue;
      }
      if (isReturn == true && !REVERSAL_DEPOSIT_TYPES.contains(deposit.depositType)) {
        continue;
      }
      if (isReturn != true && !POSITIVE_DEPOSIT_TYPES.contains(deposit.depositType)) {
        continue;
      }
      total += deposit.amount;
    }
    return total;
  }

  private static Boolean isDeletedSource(SourceDeposit deposit) {
    return deposit != null && (deposit.isDeleted == true || deposit.orderDeleted == true);
  }

  private static Decimal calculatePoints(Decimal baseAmount, Decimal rate) {
    if (baseAmount == null || baseAmount <= 0 || rate == null || rate <= 0) {
      return 0;
    }
    return (baseAmount * (rate / 100)).setScale(0, RoundingMode.HALF_UP);
  }

  private static String buildCreditOriginKey(String memberNo, Date openDate, BusinessOrderState originalSale, String pointTypeCode) {
    if (originalSale == null || originalSale.orderId == null || originalSale.businessDate == null || originalSale.businessDate < openDate) {
      return 'OPENING:' + memberNo + ':' + pointTypeCode;
    }
    return 'CREDIT:SALE:' + String.valueOf(originalSale.orderId) + ':' + pointTypeCode;
  }

  private static String buildPromotionCreditOriginKey(String memberNo, Date openDate, BusinessOrderState originalSale, String pointTypeCode) {
    if (originalSale == null || originalSale.orderId == null || originalSale.businessDate == null || originalSale.businessDate < openDate) {
      return 'OPENING:' + memberNo + ':' + pointTypeCode;
    }
    return 'CREDIT:PROMO_SALE:' + String.valueOf(originalSale.orderId) + ':' + pointTypeCode;
  }

  private static Date resolveOrderBusinessDate(Order o) {
    if (o == null) {
      return null;
    }
    if (o.EndDate != null) {
      return o.EndDate;
    }
    if (o.EffectiveDate != null) {
      return o.EffectiveDate;
    }
    return null;
  }

  private static Id resolveSourceOrderId(TransactionJournal tj) {
    return String.isNotBlank(tj.SaleId__c) ? (Id) tj.SaleId__c : tj.OrderId;
  }

  private static Date resolveSourceBusinessDate(TransactionJournal tj) {
    if (tj.SaleId__r != null) {
      if (tj.SaleId__r.EndDate != null) {
        return tj.SaleId__r.EndDate;
      }
      if (tj.SaleId__r.EffectiveDate != null) {
        return tj.SaleId__r.EffectiveDate;
      }
    }
    if (tj.Order != null) {
      if (tj.Order.EndDate != null) {
        return tj.Order.EndDate;
      }
      if (tj.Order.EffectiveDate != null) {
        return tj.Order.EffectiveDate;
      }
    }
    return tj.ActivityDate == null ? null : tj.ActivityDate.date();
  }

  private static String resolveSourceSaleNo(TransactionJournal tj) {
    if (tj.SaleId__r != null && String.isNotBlank(tj.SaleId__r.SaleNo__c)) {
      return tj.SaleId__r.SaleNo__c;
    }
    if (tj.Order != null && String.isNotBlank(tj.Order.SaleNo__c)) {
      return tj.Order.SaleNo__c;
    }
    return null;
  }

  private static Id resolveSourceOriginalOrderId(TransactionJournal tj) {
    if (tj.SaleId__r != null && tj.SaleId__r.OriginalOrderId__c != null) {
      return tj.SaleId__r.OriginalOrderId__c;
    }
    if (tj.Order != null && tj.Order.OriginalOrderId__c != null) {
      return tj.Order.OriginalOrderId__c;
    }
    return null;
  }

  private static Boolean resolveSourceIsReturn(TransactionJournal tj) {
    if (tj.SaleId__r != null) {
      return tj.SaleId__r.IsReductionOrder__c == true;
    }
    if (tj.Order != null) {
      return tj.Order.IsReductionOrder__c == true;
    }
    return false;
  }

  private static Boolean resolveSourceOrderDeleted(TransactionJournal tj) {
    if (tj.SaleId__r != null) {
      return tj.SaleId__r.IsDeleted__c == true;
    }
    if (tj.Order != null) {
      return tj.Order.IsDeleted__c == true;
    }
    return false;
  }

  private static List<GdPointRefreshEngine.PointEvent> buildManualCreditEvents(Id memberId, Date openDate) {
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    for (LoyaltyLedger ll : [
      SELECT
        Id,
        Points,
        ExpiryDate,
        ActivityDate,
        AdditionalNotes,
        LoyaltyPgmCrcySubtype.PointTypeCode__c,
        LoyaltyPgmCrcySubtype.UsagePriorityNumber,
        TransactionJournal.Id,
        TransactionJournal.ActivityDate,
        TransactionJournal.CreatedDate,
        TransactionJournal.IsDeleted__c,
        TransactionJournal.JournalSubType.Name,
        TransactionJournal.AdditionalNotes__c,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.SaleId__r.SaleNo__c
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND Points > 0
        AND (TransactionJournal.IsDeleted__c = FALSE
        OR TransactionJournal.IsDeleted__c = NULL)
      LIMIT 50000
    ]) {
      if (!isManualCreditLedger(ll)) {
        continue;
      }
      Date eventDate = ll.ActivityDate == null ? null : ll.ActivityDate.date();
      if (eventDate == null || eventDate < openDate) {
        continue;
      }
      GdPointRefreshEngine.PointEvent event = new GdPointRefreshEngine.PointEvent(
        'CREDIT:' + String.valueOf(ll.Id),
        GdPointRefreshEngine.EVENT_CREDIT,
        eventDate,
        ll.Points
      );
      event.pointTypeCode = ll.LoyaltyPgmCrcySubtype == null ? null : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      event.usagePriority = ll.LoyaltyPgmCrcySubtype == null ? null : Integer.valueOf(ll.LoyaltyPgmCrcySubtype.UsagePriorityNumber);
      event.expiryDate = ll.ExpiryDate;
      event.originKey = event.eventKey;
      event.manualCredit = true;
      event.notes = buildPreviewNotes(ll);
      events.add(event);
    }
    return events;
  }

  private static List<GdPointRefreshEngine.PointEvent> buildCreditEvents(Id memberId, Date openDate) {
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    for (LoyaltyLedger ll : [
      SELECT
        Id,
        Points,
        ExpiryDate,
        ActivityDate,
        CreatedDate,
        AdditionalNotes,
        LoyaltyPgmCrcySubtype.PointTypeCode__c,
        LoyaltyPgmCrcySubtype.UsagePriorityNumber,
        TransactionJournal.Id,
        TransactionJournal.ActivityDate,
        TransactionJournal.CreatedDate,
        TransactionJournal.IsDeleted__c,
        TransactionJournal.JournalType.Name,
        TransactionJournal.JournalSubType.Name,
        TransactionJournal.AdditionalNotes__c,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.Order.EffectiveDate,
        TransactionJournal.Order.IsDeleted__c,
        TransactionJournal.SaleId__r.SaleNo__c,
        TransactionJournal.SaleId__r.EffectiveDate,
        TransactionJournal.SaleId__r.IsDeleted__c
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND Points > 0
        AND (TransactionJournal.IsDeleted__c = FALSE
        OR TransactionJournal.IsDeleted__c = NULL)
      LIMIT 50000
    ]) {
      Date eventDate = resolveLedgerBusinessDate(ll);
      if (eventDate == null || eventDate < openDate) {
        continue;
      }
      String journalSubTypeName = ll.TransactionJournal != null && ll.TransactionJournal.JournalSubType != null
        ? ll.TransactionJournal.JournalSubType.Name
        : null;
      if (journalSubTypeName == 'Point Redeem Cancel') {
        continue;
      }

      GdPointRefreshEngine.PointEvent event = new GdPointRefreshEngine.PointEvent(
        'CREDIT:' + String.valueOf(ll.Id),
        GdPointRefreshEngine.EVENT_CREDIT,
        eventDate,
        ll.Points
      );
      event.pointTypeCode = ll.LoyaltyPgmCrcySubtype == null ? null : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      event.usagePriority = ll.LoyaltyPgmCrcySubtype == null ? null : Integer.valueOf(ll.LoyaltyPgmCrcySubtype.UsagePriorityNumber);
      event.expiryDate = ll.ExpiryDate;
      event.saleNo = resolveSaleNo(ll);
      event.originKey = event.eventKey;
      event.manualCredit = isManualCreditLedger(ll);
      event.notes = buildPreviewNotes(ll);
      events.add(event);
    }
    return events;
  }

  private static List<GdPointRefreshEngine.PointEvent> buildDebitEvents(Id memberId, Date openDate) {
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    for (LoyaltyLedger ll : [
      SELECT
        Id,
        Points,
        ActivityDate,
        CreatedDate,
        TransactionJournal.Id,
        TransactionJournal.ActivityDate,
        TransactionJournal.CreatedDate,
        TransactionJournal.IsDeleted__c,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.Order.EffectiveDate,
        TransactionJournal.Order.IsDeleted__c,
        TransactionJournal.SaleId__r.SaleNo__c,
        TransactionJournal.SaleId__r.EffectiveDate,
        TransactionJournal.SaleId__r.IsDeleted__c
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND EventType = 'Debit'
        AND Points > 0
        AND (TransactionJournal.IsDeleted__c = FALSE
        OR TransactionJournal.IsDeleted__c = NULL)
      LIMIT 50000
    ]) {
      Date eventDate = resolveLedgerBusinessDate(ll);
      if (eventDate == null || eventDate < openDate) {
        continue;
      }
      GdPointRefreshEngine.PointEvent event = new GdPointRefreshEngine.PointEvent(
        buildDebitEventKey(ll),
        GdPointRefreshEngine.EVENT_DEBIT,
        eventDate,
        ll.Points
      );
      event.saleNo = resolveSaleNo(ll);
      event.notes = 'DEBIT_LEDGER=' + String.valueOf(ll.Id);
      events.add(event);
    }
    return events;
  }

  private static List<GdPointRefreshEngine.PointEvent> buildDebitCancelEvents(Id memberId, Date openDate) {
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    for (LoyaltyLedger ll : [
      SELECT
        Id,
        Points,
        ExpiryDate,
        ActivityDate,
        CreatedDate,
        AdditionalNotes,
        LoyaltyPgmCrcySubtype.PointTypeCode__c,
        LoyaltyPgmCrcySubtype.UsagePriorityNumber,
        TransactionJournal.Id,
        TransactionJournal.ActivityDate,
        TransactionJournal.CreatedDate,
        TransactionJournal.IsDeleted__c,
        TransactionJournal.JournalSubType.Name,
        TransactionJournal.AdditionalNotes__c,
        TransactionJournal.Order.SaleNo__c,
        TransactionJournal.Order.EffectiveDate,
        TransactionJournal.Order.IsDeleted__c,
        TransactionJournal.SaleId__r.SaleNo__c,
        TransactionJournal.SaleId__r.EffectiveDate,
        TransactionJournal.SaleId__r.IsDeleted__c
      FROM LoyaltyLedger
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND EventType = 'Credit'
        AND Points > 0
        AND TransactionJournal.JournalSubType.Name = 'Point Redeem Cancel'
        AND (TransactionJournal.IsDeleted__c = FALSE
        OR TransactionJournal.IsDeleted__c = NULL)
      LIMIT 50000
    ]) {
      Date eventDate = resolveLedgerBusinessDate(ll);
      if (eventDate == null || eventDate < openDate) {
        continue;
      }
      GdPointRefreshEngine.PointEvent event = new GdPointRefreshEngine.PointEvent(
        'DEBIT_CANCEL:' + String.valueOf(ll.Id),
        GdPointRefreshEngine.EVENT_DEBIT_CANCEL,
        eventDate,
        ll.Points
      );
      Id originCreditLedgerId = extractOriginCreditLedgerId(ll.AdditionalNotes);
      event.originKey = originCreditLedgerId == null ? null : 'CREDIT:' + String.valueOf(originCreditLedgerId);
      event.saleNo = resolveSaleNo(ll);
      event.pointTypeCode = ll.LoyaltyPgmCrcySubtype == null ? null : ll.LoyaltyPgmCrcySubtype.PointTypeCode__c;
      event.usagePriority = ll.LoyaltyPgmCrcySubtype == null ? null : Integer.valueOf(ll.LoyaltyPgmCrcySubtype.UsagePriorityNumber);
      event.expiryDate = ll.ExpiryDate;
      event.notes = buildPreviewNotes(ll);
      events.add(event);
    }
    return events;
  }

  private static List<GdPointRefreshEngine.PointEvent> buildCreditCancelEvents(Id memberId, Date openDate) {
    List<GdPointRefreshEngine.PointEvent> events = new List<GdPointRefreshEngine.PointEvent>();
    for (LoyaltyLedgerTraceability llt : [
      SELECT
        Id,
        Points,
        CreditLoyaltyLedgerId,
        CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c,
        CreditLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c,
        DebitLoyaltyLedger.ActivityDate,
        DebitLoyaltyLedger.TransactionJournal.ActivityDate,
        DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate,
        DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate,
        DebitLoyaltyLedger.TransactionJournal.IsDeleted__c
      FROM LoyaltyLedgerTraceability
      WHERE
        LoyaltyProgramMemberId = :memberId
        AND ActionType = 'CreditCancellation'
        AND IsDeleted = FALSE
        AND Points > 0
        AND CreditLoyaltyLedgerId != NULL
        AND (DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = FALSE
        OR DebitLoyaltyLedger.TransactionJournal.IsDeleted__c = NULL)
      LIMIT 50000
    ]) {
      Date eventDate = resolveTraceDebitBusinessDate(llt);
      if (eventDate == null || eventDate < openDate) {
        continue;
      }
      GdPointRefreshEngine.PointEvent event = new GdPointRefreshEngine.PointEvent(
        'CREDIT_CANCEL:' + String.valueOf(llt.Id),
        GdPointRefreshEngine.EVENT_CREDIT_CANCEL,
        eventDate,
        llt.Points
      );
      event.originKey = 'CREDIT:' + String.valueOf(llt.CreditLoyaltyLedgerId);
      event.saleNo = resolveCreditSaleNo(llt);
      event.notes = 'TRACE_ACTION=CreditCancellation';
      events.add(event);
    }
    return events;
  }

  private static String buildDebitEventKey(LoyaltyLedger ll) {
    if (ll != null && ll.TransactionJournal != null && ll.TransactionJournal.Id != null) {
      return 'DEBIT:' + String.valueOf(ll.TransactionJournal.Id);
    }
    return 'DEBIT_LL:' + String.valueOf(ll == null ? null : ll.Id);
  }

  private static Date resolveLedgerBusinessDate(LoyaltyLedger ll) {
    if (ll == null) {
      return null;
    }
    if (ll.TransactionJournal != null) {
      if (ll.TransactionJournal.SaleId__r != null && ll.TransactionJournal.SaleId__r.EffectiveDate != null) {
        return ll.TransactionJournal.SaleId__r.EffectiveDate;
      }
      if (ll.TransactionJournal.Order != null && ll.TransactionJournal.Order.EffectiveDate != null) {
        return ll.TransactionJournal.Order.EffectiveDate;
      }
      if (ll.TransactionJournal.ActivityDate != null) {
        return ll.TransactionJournal.ActivityDate.date();
      }
    }
    return ll.ActivityDate == null ? null : ll.ActivityDate.date();
  }

  private static Date resolveTraceDebitBusinessDate(LoyaltyLedgerTraceability llt) {
    if (llt == null || llt.DebitLoyaltyLedger == null) {
      return null;
    }
    if (llt.DebitLoyaltyLedger.TransactionJournal != null) {
      if (llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r != null && llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate != null) {
        return llt.DebitLoyaltyLedger.TransactionJournal.SaleId__r.EffectiveDate;
      }
      if (llt.DebitLoyaltyLedger.TransactionJournal.Order != null && llt.DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate != null) {
        return llt.DebitLoyaltyLedger.TransactionJournal.Order.EffectiveDate;
      }
      if (llt.DebitLoyaltyLedger.TransactionJournal.ActivityDate != null) {
        return llt.DebitLoyaltyLedger.TransactionJournal.ActivityDate.date();
      }
    }
    return llt.DebitLoyaltyLedger.ActivityDate == null ? null : llt.DebitLoyaltyLedger.ActivityDate.date();
  }

  private static String resolveSaleNo(LoyaltyLedger ll) {
    if (ll == null || ll.TransactionJournal == null) {
      return null;
    }
    if (ll.TransactionJournal.SaleId__r != null && String.isNotBlank(ll.TransactionJournal.SaleId__r.SaleNo__c)) {
      return ll.TransactionJournal.SaleId__r.SaleNo__c;
    }
    if (ll.TransactionJournal.Order != null && String.isNotBlank(ll.TransactionJournal.Order.SaleNo__c)) {
      return ll.TransactionJournal.Order.SaleNo__c;
    }
    return null;
  }

  private static String resolveCreditSaleNo(LoyaltyLedgerTraceability llt) {
    if (llt == null || llt.CreditLoyaltyLedger == null || llt.CreditLoyaltyLedger.TransactionJournal == null) {
      return null;
    }
    if (llt.CreditLoyaltyLedger.TransactionJournal.SaleId__r != null && String.isNotBlank(llt.CreditLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c)) {
      return llt.CreditLoyaltyLedger.TransactionJournal.SaleId__r.SaleNo__c;
    }
    if (llt.CreditLoyaltyLedger.TransactionJournal.Order != null && String.isNotBlank(llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c)) {
      return llt.CreditLoyaltyLedger.TransactionJournal.Order.SaleNo__c;
    }
    return null;
  }

  private static String buildPreviewNotes(LoyaltyLedger ll) {
    if (ll == null) {
      return null;
    }
    List<String> parts = new List<String>();
    parts.add('LL=' + String.valueOf(ll.Id));
    if (ll.TransactionJournal != null) {
      parts.add('TJ=' + String.valueOf(ll.TransactionJournal.Id));
      if (ll.TransactionJournal.JournalSubType != null) {
        parts.add('JST=' + ll.TransactionJournal.JournalSubType.Name);
      }
      if (String.isNotBlank(ll.TransactionJournal.AdditionalNotes__c)) {
        parts.add('TJ_NOTE=' + ll.TransactionJournal.AdditionalNotes__c);
      }
    }
    if (String.isNotBlank(ll.AdditionalNotes)) {
      parts.add('LL_NOTE=' + ll.AdditionalNotes);
    }
    return String.join(parts, ';');
  }

  private static Boolean isManualCreditLedger(LoyaltyLedger ll) {
    if (ll == null) {
      return false;
    }
    String subTypeName = ll.TransactionJournal != null && ll.TransactionJournal.JournalSubType != null
      ? ll.TransactionJournal.JournalSubType.Name
      : null;
    String notes = ((ll.TransactionJournal == null ? '' : String.valueOf(ll.TransactionJournal.AdditionalNotes__c)) + ';' + String.valueOf(ll.AdditionalNotes)).toUpperCase();
    if (notes.contains('OPTC') || notes.contains('RETURN_DEPOSIT_DELETE') || notes.contains('RESTORE') || notes.contains('ORIGIN_CREDIT_LL')) {
      return false;
    }
    if (subTypeName == 'Api Forced Credit') {
      return true;
    }
    if (String.isNotBlank(resolveSaleNo(ll))) {
      return false;
    }
    return subTypeName == 'Api Forced Credit' || subTypeName == 'Manual Points Credit';
  }

  private static Id extractOriginCreditLedgerId(String additionalNotes) {
    if (String.isBlank(additionalNotes)) {
      return null;
    }
    String token = 'ORIGIN_CREDIT_LL=';
    Integer tokenIndex = additionalNotes.indexOf(token);
    if (tokenIndex < 0) {
      return null;
    }
    Integer valueStart = tokenIndex + token.length();
    Integer valueEnd = additionalNotes.indexOf(';', valueStart);
    String idText = valueEnd < 0 ? additionalNotes.substring(valueStart) : additionalNotes.substring(valueStart, valueEnd);
    idText = idText == null ? null : idText.trim();
    if (String.isBlank(idText) || (idText.length() != 15 && idText.length() != 18)) {
      return null;
    }
    try {
      return (Id) idText;
    } catch (Exception e) {
      return null;
    }
  }
}