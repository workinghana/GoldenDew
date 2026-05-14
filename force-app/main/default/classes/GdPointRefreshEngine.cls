public without sharing class GdPointRefreshEngine {
  public static final String EVENT_CREDIT = 'CREDIT';
  public static final String EVENT_DEBIT = 'DEBIT';
  public static final String EVENT_DEBIT_CANCEL = 'DEBIT_CANCEL';
  public static final String EVENT_CREDIT_CANCEL = 'CREDIT_CANCEL';

  public class PointEvent {
    public String eventKey;
    public String eventType;
    public Date eventDate;
    public Integer sequence;
    public String saleNo;
    public String originKey;
    public String sourceDebitEventKey;
    public String pointTypeCode;
    public Integer usagePriority;
    public Date expiryDate;
    public Decimal points;
    public Boolean manualCredit;
    public String notes;

    public PointEvent(String eventKey, String eventType, Date eventDate, Decimal points) {
      this.eventKey = eventKey;
      this.eventType = eventType;
      this.eventDate = eventDate;
      this.points = points;
      this.sequence = 0;
      this.usagePriority = 999;
      this.manualCredit = false;
    }
  }

  public class CreditBucket {
    public String bucketKey;
    public String rootOriginKey;
    public String pointTypeCode;
    public String originSaleNo;
    public Date accrualDate;
    public Date expiryDate;
    public Integer usagePriority;
    public Decimal originalPoints;
    public Decimal remainingPoints;
    public Boolean manualCredit;
    public String notes;

    public CreditBucket cloneForResult() {
      CreditBucket b = new CreditBucket();
      b.bucketKey = bucketKey;
      b.rootOriginKey = rootOriginKey;
      b.pointTypeCode = pointTypeCode;
      b.originSaleNo = originSaleNo;
      b.accrualDate = accrualDate;
      b.expiryDate = expiryDate;
      b.usagePriority = usagePriority;
      b.originalPoints = originalPoints;
      b.remainingPoints = remainingPoints;
      b.manualCredit = manualCredit;
      b.notes = notes;
      return b;
    }
  }

  public class Allocation {
    public String debitEventKey;
    public String creditBucketKey;
    public String rootOriginKey;
    public Decimal points;

    public Allocation(String debitEventKey, CreditBucket bucket, Decimal points) {
      this.debitEventKey = debitEventKey;
      this.creditBucketKey = bucket.bucketKey;
      this.rootOriginKey = bucket.rootOriginKey;
      this.points = points;
    }
  }

  public class CreditCancellationAllocation {
    public String cancelEventKey;
    public String creditBucketKey;
    public String rootOriginKey;
    public Decimal points;

    public CreditCancellationAllocation(String cancelEventKey, CreditBucket bucket, Decimal points) {
      this.cancelEventKey = cancelEventKey;
      this.creditBucketKey = bucket.bucketKey;
      this.rootOriginKey = bucket.rootOriginKey;
      this.points = points;
    }
  }

  public class DebitCancellationAllocation {
    public String cancelEventKey;
    public String sourceCreditBucketKey;
    public String restoredCreditBucketKey;
    public String rootOriginKey;
    public Decimal points;

    public DebitCancellationAllocation(String cancelEventKey, CreditBucket sourceBucket, CreditBucket restoredBucket, Decimal points) {
      this.cancelEventKey = cancelEventKey;
      this.sourceCreditBucketKey = sourceBucket == null ? null : sourceBucket.bucketKey;
      this.restoredCreditBucketKey = restoredBucket == null ? null : restoredBucket.bucketKey;
      this.rootOriginKey = sourceBucket == null ? null : sourceBucket.rootOriginKey;
      this.points = points;
    }
  }

  public class Result {
    public List<CreditBucket> buckets = new List<CreditBucket>();
    public List<Allocation> allocations = new List<Allocation>();
    public List<DebitCancellationAllocation> debitCancellations = new List<DebitCancellationAllocation>();
    public List<CreditCancellationAllocation> creditCancellations = new List<CreditCancellationAllocation>();
    public Map<String, Decimal> remainingByPointType = new Map<String, Decimal>();
    public Decimal totalRemaining = 0;
  }

  public Result simulate(List<PointEvent> eventList) {
    List<PointEvent> events = eventList == null ? new List<PointEvent>() : new List<PointEvent>(eventList);
    events.sort(new PointEventSorter());

    List<CreditBucket> buckets = new List<CreditBucket>();
    Map<String, List<Allocation>> allocationByDebitEventKey = new Map<String, List<Allocation>>();
    Result result = new Result();

    for (PointEvent event : events) {
      if (event == null || String.isBlank(event.eventType) || event.points == null || event.points <= 0) {
        continue;
      }

      if (event.eventType == EVENT_CREDIT) {
        buckets.add(buildCreditBucket(event, event.originKey));
      } else if (event.eventType == EVENT_DEBIT) {
        List<Allocation> allocations = applyDebit(event, buckets);
        allocationByDebitEventKey.put(event.eventKey, allocations);
        result.allocations.addAll(allocations);
      } else if (event.eventType == EVENT_DEBIT_CANCEL) {
        result.debitCancellations.addAll(applyDebitCancel(event, buckets, allocationByDebitEventKey.get(event.sourceDebitEventKey)));
      } else if (event.eventType == EVENT_CREDIT_CANCEL) {
        result.creditCancellations.addAll(applyCreditCancel(event, buckets));
      }
    }

    for (CreditBucket bucket : buckets) {
      result.buckets.add(bucket.cloneForResult());
      Decimal remaining = bucket.remainingPoints == null ? 0 : bucket.remainingPoints;
      result.totalRemaining += remaining;
      String pointTypeCode = String.isBlank(bucket.pointTypeCode) ? 'UNKNOWN' : bucket.pointTypeCode;
      Decimal current = result.remainingByPointType.containsKey(pointTypeCode) ? result.remainingByPointType.get(pointTypeCode) : 0;
      result.remainingByPointType.put(pointTypeCode, current + remaining);
    }

    return result;
  }

  private static CreditBucket buildCreditBucket(PointEvent event, String inheritedRootOriginKey) {
    CreditBucket bucket = new CreditBucket();
    bucket.bucketKey = event.eventKey;
    bucket.rootOriginKey = String.isBlank(inheritedRootOriginKey) ? event.eventKey : inheritedRootOriginKey;
    bucket.pointTypeCode = event.pointTypeCode;
    bucket.originSaleNo = event.saleNo;
    bucket.accrualDate = event.eventDate;
    bucket.expiryDate = event.expiryDate == null && event.eventDate != null ? event.eventDate.addYears(2) : event.expiryDate;
    bucket.usagePriority = event.usagePriority == null ? 999 : event.usagePriority;
    bucket.originalPoints = event.points;
    bucket.remainingPoints = event.points;
    bucket.manualCredit = event.manualCredit == true;
    bucket.notes = event.notes;
    return bucket;
  }

  private static List<Allocation> applyDebit(PointEvent event, List<CreditBucket> buckets) {
    Decimal remaining = event.points;
    List<Allocation> allocations = new List<Allocation>();
    List<CreditBucket> candidates = new List<CreditBucket>();

    for (CreditBucket bucket : buckets) {
      if (bucket.remainingPoints == null || bucket.remainingPoints <= 0) {
        continue;
      }
      if (String.isNotBlank(event.saleNo) && String.isNotBlank(bucket.originSaleNo) && event.saleNo == bucket.originSaleNo) {
        continue;
      }
      candidates.add(bucket);
    }
    candidates.sort(new CreditBucketSorter());

    for (CreditBucket bucket : candidates) {
      if (remaining <= 0) {
        break;
      }
      Decimal usePoints = Math.min(bucket.remainingPoints, remaining);
      bucket.remainingPoints -= usePoints;
      remaining -= usePoints;
      allocations.add(new Allocation(event.eventKey, bucket, usePoints));
    }

    if (remaining > 0) {
      throw new CustomException(400, '포인트 잔액이 부족합니다. 사용 가능 금액: ' + (event.points - remaining).intValue() + 'P (요청: ' + event.points.intValue() + 'P)');
    }
    return allocations;
  }

  private static List<DebitCancellationAllocation> applyDebitCancel(PointEvent event, List<CreditBucket> buckets, List<Allocation> sourceAllocations) {
    if (sourceAllocations == null || sourceAllocations.isEmpty()) {
      return applyDebitCancelByOrigin(event, buckets);
    }

    Decimal cancelRemaining = event.points;
    Integer restoreSeq = 0;
    List<DebitCancellationAllocation> debitCancellations = new List<DebitCancellationAllocation>();
    Map<String, CreditBucket> bucketByKey = new Map<String, CreditBucket>();
    for (CreditBucket bucket : buckets) {
      bucketByKey.put(bucket.bucketKey, bucket);
    }

    for (Allocation source : sourceAllocations) {
      if (cancelRemaining <= 0) {
        break;
      }
      CreditBucket sourceBucket = bucketByKey.get(source.creditBucketKey);
      if (sourceBucket == null) {
        continue;
      }

      Decimal restorePoints = Math.min(source.points, cancelRemaining);
      PointEvent restoreEvent = new PointEvent(event.eventKey + ':RESTORE:' + restoreSeq, EVENT_CREDIT, sourceBucket.accrualDate, restorePoints);
      restoreEvent.originKey = sourceBucket.rootOriginKey;
      restoreEvent.saleNo = sourceBucket.originSaleNo;
      restoreEvent.pointTypeCode = sourceBucket.pointTypeCode;
      restoreEvent.usagePriority = sourceBucket.usagePriority;
      restoreEvent.expiryDate = sourceBucket.expiryDate;
      restoreEvent.manualCredit = sourceBucket.manualCredit;
      restoreEvent.notes = event.notes;
      CreditBucket restoredBucket = buildCreditBucket(restoreEvent, sourceBucket.rootOriginKey);
      buckets.add(restoredBucket);
      debitCancellations.add(new DebitCancellationAllocation(event.eventKey, sourceBucket, restoredBucket, restorePoints));

      cancelRemaining -= restorePoints;
      restoreSeq++;
    }

    if (cancelRemaining > 0) {
      throw new CustomException(400, '사용 취소 가능 금액을 초과했습니다. 초과: ' + cancelRemaining.intValue() + 'P');
    }
    return debitCancellations;
  }

  private static List<DebitCancellationAllocation> applyDebitCancelByOrigin(PointEvent event, List<CreditBucket> buckets) {
    Decimal cancelRemaining = event.points;
    List<CreditBucket> candidates = new List<CreditBucket>();
    List<DebitCancellationAllocation> debitCancellations = new List<DebitCancellationAllocation>();
    for (CreditBucket bucket : buckets) {
      if (String.isNotBlank(event.originKey) && bucket.rootOriginKey != event.originKey && bucket.bucketKey != event.originKey) {
        continue;
      }
      candidates.add(bucket);
    }
    candidates.sort(new CreditBucketSorter());

    Integer restoreSeq = 0;
    for (CreditBucket sourceBucket : candidates) {
      if (cancelRemaining <= 0) {
        break;
      }
      Decimal sourceCapacity = sourceBucket.originalPoints == null ? 0 : sourceBucket.originalPoints;
      if (sourceCapacity <= 0) {
        continue;
      }
      Decimal restorePoints = Math.min(sourceCapacity, cancelRemaining);
      PointEvent restoreEvent = new PointEvent(event.eventKey + ':RESTORE:' + restoreSeq, EVENT_CREDIT, sourceBucket.accrualDate, restorePoints);
      restoreEvent.originKey = sourceBucket.rootOriginKey;
      restoreEvent.saleNo = sourceBucket.originSaleNo;
      restoreEvent.pointTypeCode = sourceBucket.pointTypeCode;
      restoreEvent.usagePriority = sourceBucket.usagePriority;
      restoreEvent.expiryDate = sourceBucket.expiryDate;
      restoreEvent.manualCredit = sourceBucket.manualCredit;
      restoreEvent.notes = event.notes;
      CreditBucket restoredBucket = buildCreditBucket(restoreEvent, sourceBucket.rootOriginKey);
      buckets.add(restoredBucket);
      debitCancellations.add(new DebitCancellationAllocation(event.eventKey, sourceBucket, restoredBucket, restorePoints));
      cancelRemaining -= restorePoints;
      restoreSeq++;
    }

    if (cancelRemaining > 0) {
      PointEvent restoreEvent = new PointEvent(event.eventKey + ':RESTORE:' + restoreSeq, EVENT_CREDIT, event.eventDate, cancelRemaining);
      restoreEvent.originKey = String.isBlank(event.originKey) ? event.eventKey : event.originKey;
      restoreEvent.saleNo = event.saleNo;
      restoreEvent.pointTypeCode = event.pointTypeCode;
      restoreEvent.usagePriority = event.usagePriority;
      restoreEvent.expiryDate = event.expiryDate;
      restoreEvent.manualCredit = event.manualCredit;
      restoreEvent.notes = event.notes;
      buckets.add(buildCreditBucket(restoreEvent, restoreEvent.originKey));
    }
    return debitCancellations;
  }

  private static List<CreditCancellationAllocation> applyCreditCancel(PointEvent event, List<CreditBucket> buckets) {
    Decimal remaining = event.points;
    List<CreditBucket> candidates = new List<CreditBucket>();
    List<CreditCancellationAllocation> allocations = new List<CreditCancellationAllocation>();
    for (CreditBucket bucket : buckets) {
      if (bucket.remainingPoints == null || bucket.remainingPoints <= 0) {
        continue;
      }
      if (String.isNotBlank(event.originKey) && bucket.rootOriginKey != event.originKey && bucket.bucketKey != event.originKey) {
        continue;
      }
      if (String.isNotBlank(event.saleNo) && bucket.originSaleNo != event.saleNo) {
        continue;
      }
      candidates.add(bucket);
    }
    candidates.sort(new CreditBucketSorter());

    for (CreditBucket bucket : candidates) {
      if (remaining <= 0) {
        break;
      }
      Decimal cancelPoints = Math.min(bucket.remainingPoints, remaining);
      bucket.remainingPoints -= cancelPoints;
      remaining -= cancelPoints;
      allocations.add(new CreditCancellationAllocation(event.eventKey, bucket, cancelPoints));
    }

    if (remaining > 0) {
      throw new CustomException(400, '적립 취소 가능 금액을 초과했습니다. 초과: ' + remaining.intValue() + 'P');
    }
    return allocations;
  }

  private class PointEventSorter implements System.Comparator<PointEvent> {
    public Integer compare(PointEvent a, PointEvent b) {
      Integer result = compareDate(a == null ? null : a.eventDate, b == null ? null : b.eventDate);
      if (result != 0) return result;
      result = compareInteger(a == null ? null : a.sequence, b == null ? null : b.sequence);
      if (result != 0) return result;
      result = compareInteger(eventRank(a == null ? null : a.eventType), eventRank(b == null ? null : b.eventType));
      if (result != 0) return result;
      return compareString(a == null ? null : a.eventKey, b == null ? null : b.eventKey);
    }
  }

  private class CreditBucketSorter implements System.Comparator<CreditBucket> {
    public Integer compare(CreditBucket a, CreditBucket b) {
      Integer result = compareDate(a == null ? null : a.expiryDate, b == null ? null : b.expiryDate);
      if (result != 0) return result;
      result = compareInteger(a == null ? null : a.usagePriority, b == null ? null : b.usagePriority);
      if (result != 0) return result;
      result = compareDate(a == null ? null : a.accrualDate, b == null ? null : b.accrualDate);
      if (result != 0) return result;
      return compareString(a == null ? null : a.rootOriginKey, b == null ? null : b.rootOriginKey);
    }
  }

  private static Integer eventRank(String eventType) {
    if (eventType == EVENT_CREDIT) return 10;
    if (eventType == EVENT_DEBIT_CANCEL) return 20;
    if (eventType == EVENT_CREDIT_CANCEL) return 30;
    if (eventType == EVENT_DEBIT) return 40;
    return 999;
  }

  private static Integer compareDate(Date a, Date b) {
    if (a == b) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  }

  private static Integer compareInteger(Integer a, Integer b) {
    if (a == b) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  }

  private static Integer compareString(String a, String b) {
    if (a == b) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }
}