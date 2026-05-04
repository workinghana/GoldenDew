/**
 * TierQualifyingSpend3Y__c 재산정 Batch
 * 3개년 금액 재산정 Batch
 *
 * 정책:
 * - 전환일이 2/1이라고 가정
 * - 전환연도 기준: (y-2)-01-01 ~ (전환일-1) 까지 구매금액 합산
 *   예) 2023-02-01 전환이면 2021-01-01 ~ 2023-01-31
 *
 * 실행 방식:
 * - 기본 생성자: Date.today() 기준으로 올해 전환일(2/1)을 계산하여 사용
 * - Date 파라미터 생성자: 특정 전환일로 재실행 가능(운영/재처리 용)
 *
 * @author Changhwan Kim
 * @since 2026-01-30
 */
public with sharing class TierQualifyingSpend3YRecalcBatch implements Database.Batchable<SObject>, Database.Stateful {
  // Stateful total 집계
  private Set<String> totalSuccess = new Set<String>();
  private Set<String> totalFail = new Set<String>();

  // 기준/기간
  private final Date targetDate;
  private final Date conversionDate;
  private final Date fromDate;
  private final Date toDate;

  // (선택) 전환월/일 고정 정책이면 상수화 가능
  private static final Integer CONVERSION_MONTH = 2;
  private static final Integer CONVERSION_DAY = 1;

  /** 기본: 오늘 기준으로 전환연도 계산 */
  public TierQualifyingSpend3YRecalcBatch() {
    this(Date.today());
  }

  /** 운영/재처리: targetDate(또는 전환일)을 외부에서 지정 */
  public TierQualifyingSpend3YRecalcBatch(Date baseDate) {
    this.targetDate = (baseDate == null) ? Date.today() : baseDate;

    // "올해 전환일(2/1)"을 기준으로 계산
    Integer y = this.targetDate.year();
    this.conversionDate = Date.newInstance(y, CONVERSION_MONTH, CONVERSION_DAY);

    // 기간: (y-2)-01-01 ~ 전환일-1
    this.fromDate = Date.newInstance(y - 2, 1, 1);
    this.toDate = this.conversionDate.addDays(-1); // 2/1이면 1/31
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    System.debug('fromDate : ' + fromDate);
    System.debug('toDate : ' + toDate);
    // 전 회원 대상(탈퇴 제외)
    return Database.getQueryLocator(
      [
        SELECT Id
        FROM Contact
        WHERE MemberDropDate__c = NULL
      ]
    );
  }

  public void execute(Database.BatchableContext bc, List<Contact> cList) {
    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(TierQualifyingSpend3YRecalcBatch.class.getName());
    logger.setRequestDatetime(Datetime.now());

    if (cList != null && !cList.isEmpty()) {
      logger.setScopedIds((List<SObject>) cList, 'Id');
    }

    Set<String> successIds = new Set<String>();
    Set<String> failIds = new Set<String>();
    List<String> failMsgs = new List<String>();

    Integer chunkSize = (cList == null) ? 0 : cList.size();
    Integer updateFailCnt = 0;

    try {
      if (cList == null || cList.isEmpty()) {
        logger.setStatus('SUCCESS');
        logger.setDescription('cList is empty');
        return;
      }

      Set<Id> contactIds = new Set<Id>();
      for (Contact c : cList) {
        contactIds.add(c.Id);
      }

      // 회원별 합계
      Map<Id, Decimal> sumByContactId = new Map<Id, Decimal>();

      // 판매(+) 합산
      // 기존 판매(+) 합산
      // List<AggregateResult> plusAgg = [
      //   SELECT MemberNo__c contactId, SUM(ActualPaymentAmount__c) amt
      //   FROM Order
      //   WHERE MemberNo__c IN :contactIds AND EndDate >= :fromDate AND EndDate <= :toDate AND Status IN ('saleSuccess')
      //   GROUP BY MemberNo__c
      // ];

      // 신규 판매(+) 합산 - 고재성
      List<AggregateResult> plusAgg = [
        SELECT Order.MemberNo__c contactId, SUM(NetSalesUnitPrice__c) amt 
        FROM OrderItem
        WHERE Order.MemberNo__c IN :contactIds
        AND Order.EndDate >= :fromDate 
        AND Order.EndDate <= :toDate
        AND (
          Order.StoreCode__r.StoreType__c IN ('11', '40')
          OR Order.StoreCode__r.StoreTypeFour__c = '01'
        )
        AND Order.Status IN ('saleSuccess')
        AND Product2Id NOT IN (
          SELECT ProductId 
          FROM ProductCategoryProduct 
          WHERE ProductCategory.Name = '골드바'
        )
        AND (NOT Product2.Name LIKE '%수선%')
        AND (NOT Product2.Name LIKE '%각인%')
        AND (NOT Product2.Name LIKE '%위약금%')
        AND (NOT Product2.Name LIKE '%재감비%')
        AND (NOT Product2.Name LIKE '%재인쇄비%')
        GROUP BY Order.MemberNo__c
      ];

      // 반품/환불(-) 합산
      // 기존 반품/환불(-) 합산
      // List<AggregateResult> minusAgg = [
      //   SELECT MemberNo__c contactId, SUM(ActualPaymentAmount__c) amt
      //   FROM Order
      //   WHERE MemberNo__c IN :contactIds AND EndDate >= :fromDate AND EndDate <= :toDate AND Status IN ('returnSuccess')
      //   GROUP BY MemberNo__c
      // ];

      // 신규 반품/환불(-) 합산 - 고재성
      List<AggregateResult> minusAgg = [
        SELECT Order.MemberNo__c contactId, SUM(NetSalesUnitPrice__c) amt 
        FROM OrderItem
        WHERE Order.MemberNo__c IN :contactIds
        AND Order.EndDate >= :fromDate 
        AND Order.EndDate <= :toDate
        AND (
          Order.StoreCode__r.StoreType__c IN ('11', '40')
          OR Order.StoreCode__r.StoreTypeFour__c = '01'
        )
        AND Order.Status IN ('returnSuccess')
        AND Product2Id NOT IN (
          SELECT ProductId 
          FROM ProductCategoryProduct 
          WHERE ProductCategory.Name = '골드바'
        )
        AND (NOT Product2.Name LIKE '%수선%')
        AND (NOT Product2.Name LIKE '%각인%')
        AND (NOT Product2.Name LIKE '%위약금%')
        AND (NOT Product2.Name LIKE '%재감비%')
        AND (NOT Product2.Name LIKE '%재인쇄비%')
        GROUP BY Order.MemberNo__c
      ];

      for (AggregateResult ar : plusAgg) {
        Id cid = (Id) ar.get('contactId');
        Decimal amt = (Decimal) ar.get('amt');
        sumByContactId.put(cid, (amt == null) ? 0 : amt);
      }

      for (AggregateResult ar : minusAgg) {
        Id cid = (Id) ar.get('contactId');
        Decimal amt = (Decimal) ar.get('amt');
        Decimal cur = sumByContactId.containsKey(cid) ? sumByContactId.get(cid) : 0;
        sumByContactId.put(cid, cur - ((amt == null) ? 0 : amt));
      }

      // 재산정 결과 반영(전부 세팅 정책)
      List<Contact> upd = new List<Contact>();
      for (Contact c : cList) {
        Decimal newAmt = sumByContactId.containsKey(c.Id) ? sumByContactId.get(c.Id) : 0;

        upd.add(new Contact(Id = c.Id, TierQualifyingSpend3Y__c = newAmt));
      }

      Database.SaveResult[] srs = Database.update(upd, false);

      for (Integer i = 0; i < srs.size(); i++) {
        Database.SaveResult sr = srs[i];
        Id cid = upd[i].Id;

        if (sr.isSuccess()) {
          successIds.add((String) cid);
        } else {
          updateFailCnt++;
          failIds.add((String) cid);

          for (Database.Error err : sr.getErrors()) {
            failMsgs.add('Contact update failed. contactId=' + cid + ', msg=' + err.getMessage());
          }
        }
      }

      // 성공한 건은 실패에서 제거
      failIds.removeAll(successIds);

      Boolean hasAnyFail = !failIds.isEmpty();
      Boolean hasAnySuccess = !successIds.isEmpty();

      if (hasAnyFail && hasAnySuccess) {
        logger.setStatus('PARTIAL');
      } else if (hasAnyFail) {
        logger.setStatus('ERROR');
      } else {
        logger.setStatus('SUCCESS');
      }

      logger.setDescription(
        'baseDate=' +
          targetDate +
          ', conversionDate=' +
          conversionDate +
          ', from=' +
          fromDate +
          ', to=' +
          toDate +
          ', chunkSize=' +
          chunkSize +
          ', success=' +
          successIds.size() +
          ', fail=' +
          failIds.size() +
          ', updateFailCnt=' +
          updateFailCnt
      );
    } catch (Exception e) {
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
    } finally {
      // Stateful total 집계
      totalSuccess.addAll(successIds);
      totalFail.addAll(failIds);

      if (!successIds.isEmpty()) {
        logger.setSuccessRecordIds(successIds);
      }
      if (!failIds.isEmpty()) {
        logger.setFailedRecordIds(failIds);
      }
      if (!failMsgs.isEmpty()) {
        logger.setErrorMessage(String.join(failMsgs, ' | '));
      }

      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();
    }
  }

  public void finish(Database.BatchableContext bc) {
    totalFail.removeAll(totalSuccess);

    Integer successCnt = totalSuccess.size();
    Integer failCnt = totalFail.size();

    String status;
    SchedulerNotificationPublisher.ResultStatus notifStatus;

    if (failCnt > 0 && successCnt > 0) {
      status = 'PARTIAL';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.PARTIAL;
    } else if (failCnt > 0) {
      status = 'ERROR';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.ERROR;
    } else {
      status = 'SUCCESS';
      notifStatus = SchedulerNotificationPublisher.ResultStatus.SUCCESS;
    }

    ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, bc.getJobId(), null);
    logger.logging(TierQualifyingSpend3YRecalcBatch.class.getName());
    logger.setStatus(status);
    logger.setDescription(
      'TOTAL baseDate=' +
        targetDate +
        ', conversionDate=' +
        conversionDate +
        ', from=' +
        fromDate +
        ', to=' +
        toDate +
        ', success=' +
        successCnt +
        ', fail=' +
        failCnt
    );
    logger.setResponseDatetime(Datetime.now());
    logger.addLog();
    ApexLogger.insertLogs();

    String msg =
      'Status=' +
      status +
      ', baseDate=' +
      targetDate +
      ', conversionDate=' +
      conversionDate +
      ', from=' +
      fromDate +
      ', to=' +
      toDate +
      ', success=' +
      successCnt +
      ', fail=' +
      failCnt +
      ', jobId=' +
      bc.getJobId();

    SchedulerNotificationPublisher.publishResult('TierQualifyingSpend3YRecalcBatch', notifStatus, msg, bc.getJobId(), null);
  }
}