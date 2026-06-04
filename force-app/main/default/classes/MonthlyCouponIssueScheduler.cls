/**
 * 매월 쿠폰 지급 스케줄러
 * 실행 시기 : 매월 1일
 */
public with sharing class MonthlyCouponIssueScheduler implements Schedulable {
  @TestVisible
  private class TestHookException extends Exception {
  }

  @TestVisible
  private static Boolean forceGenericException = false;

  private static final String VOUCHER_LIMIT_TYPE_NAME_GRADE_INCLUDE_LIST = 'GradeIncludeList';
  private static final Integer MAX_ISSUE_VOUCHER_REQUEST_SIZE = 200;
  private static final Integer DEFAULT_SCOPE_SIZE = 200;
  private static final Integer MIN_SCOPE_SIZE = 1;

  private final String VOUCHER_CATEGORY_NAME_MONTHLY_COUPON = 'MonthlyCoupon';

  public void execute(SchedulableContext sc) {
    String triggerId = sc == null ? null : sc.getTriggerId();

    ApexLogger startLogger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, triggerId, null);
    startLogger.logging(MonthlyCouponIssueScheduler.class.getName());
    startLogger.setRequestDatetime(Datetime.now());

    // (선택) 시작 알림
    SchedulerNotificationPublisher.publishStarted('MonthlyCouponIssueScheduler', 'TriggerId=' + triggerId, null);

    try {
      if (Test.isRunningTest() && forceGenericException) {
        forceGenericException = false;
        throw new TestHookException('forced generic exception for test');
      }

      List<VoucherDefinition> monthlyVoucherDefinitions = [
        SELECT Id
        FROM VoucherDefinition
        WHERE IsActive = TRUE AND VoucherCategoryId__r.Code__c = :VOUCHER_CATEGORY_NAME_MONTHLY_COUPON
        LIMIT 200
      ];

      if (monthlyVoucherDefinitions.isEmpty()) {
        throw new CustomException(404, '지급 가능한 월 쿠폰이 없습니다.');
      }

      // 월 지급 배치 실행 (배치 사이즈는 정책에 맞게)
      Integer maxCouponsPerMember = calculateMaxCouponsPerMember(monthlyVoucherDefinitions);
      Integer scopeSize = calculateScopeSize(maxCouponsPerMember);

      startLogger.setStatus('SUCCESS');
      startLogger.setDescription(
        'Scheduler started. triggerId=' +
          triggerId +
          ', activeMonthlyCoupon=' +
          monthlyVoucherDefinitions.size() +
          ', maxCouponsPerMember=' +
          maxCouponsPerMember +
          ', scopeSize=' +
          scopeSize +
          ', maxIssueRequestSize=' +
          MAX_ISSUE_VOUCHER_REQUEST_SIZE
      );
      startLogger.setResponseDatetime(Datetime.now());
      startLogger.addLog();
      ApexLogger.insertLogs();

      Database.executeBatch(new MonthlyCouponIssueBatch(), scopeSize);
    } catch (CustomException ce) {
      ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, triggerId, null);
      logger.logging(MonthlyCouponIssueScheduler.class.getName());
      logger.setRequestDatetime(Datetime.now());
      logger.createCustomExceptionLog(ce);
      logger.setStatus('ERROR');
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();

      SchedulerNotificationPublisher.publishResult(
        'MonthlyCouponIssueScheduler',
        SchedulerNotificationPublisher.ResultStatus.ERROR,
        'Scheduler failed: ' + ce.getMessage(),
        null,
        null
      );
    } catch (Exception e) {
      ApexLogger logger = new ApexLogger(ApexLogger.JobType.ASYNCHRONOUS, triggerId, null);
      logger.logging(MonthlyCouponIssueScheduler.class.getName());
      logger.setRequestDatetime(Datetime.now());
      logger.createExceptionLog(e);
      logger.setStatus('ERROR');
      logger.setResponseDatetime(Datetime.now());
      logger.addLog();
      ApexLogger.insertLogs();

      SchedulerNotificationPublisher.publishResult(
        'MonthlyCouponIssueScheduler',
        SchedulerNotificationPublisher.ResultStatus.ERROR,
        'Scheduler failed: ' + e.getMessage(),
        null,
        null
      );
    }
  }

  @TestVisible
  private static Integer calculateScopeSize(List<VoucherDefinition> monthlyVoucherDefinitions) {
    return calculateScopeSize(calculateMaxCouponsPerMember(monthlyVoucherDefinitions));
  }

  private static Integer calculateScopeSize(Integer maxCouponsPerMember) {
    if (maxCouponsPerMember <= 0) {
      return DEFAULT_SCOPE_SIZE;
    }

    Integer scopeSize = MAX_ISSUE_VOUCHER_REQUEST_SIZE / maxCouponsPerMember;
    return Math.max(MIN_SCOPE_SIZE, Math.min(DEFAULT_SCOPE_SIZE, scopeSize));
  }

  private static Integer calculateMaxCouponsPerMember(List<VoucherDefinition> monthlyVoucherDefinitions) {
    if (monthlyVoucherDefinitions == null || monthlyVoucherDefinitions.isEmpty()) {
      return 0;
    }

    Set<Id> voucherDefinitionIds = new Map<Id, VoucherDefinition>(monthlyVoucherDefinitions).keySet();
    List<VoucherLimit__c> gradeLimits = [
      SELECT VoucherDefinitionId__c, Value__c
      FROM VoucherLimit__c
      WHERE
        IsActive__c = TRUE
        AND Type__c = :VOUCHER_LIMIT_TYPE_NAME_GRADE_INCLUDE_LIST
        AND VoucherDefinitionId__c IN :voucherDefinitionIds
        AND VoucherDefinitionId__c != NULL
        AND Value__c != NULL
    ];

    Map<String, Id> tierIdByGrade = new Map<String, Id>();
    for (LoyaltyTier tier : [
      SELECT Id, Grade__c
      FROM LoyaltyTier
      WHERE Grade__c != NULL
    ]) {
      tierIdByGrade.put(tier.Grade__c, tier.Id);
    }

    Set<Id> limitedVoucherDefinitionIds = new Set<Id>();
    Map<Id, Set<Id>> voucherDefinitionIdsByTierId = new Map<Id, Set<Id>>();

    for (VoucherLimit__c gradeLimit : gradeLimits) {
      Id tierId = resolveTierId(gradeLimit.Value__c, tierIdByGrade);
      if (tierId == null) {
        continue;
      }

      limitedVoucherDefinitionIds.add(gradeLimit.VoucherDefinitionId__c);
      if (!voucherDefinitionIdsByTierId.containsKey(tierId)) {
        voucherDefinitionIdsByTierId.put(tierId, new Set<Id>());
      }
      voucherDefinitionIdsByTierId.get(tierId).add(gradeLimit.VoucherDefinitionId__c);
    }

    Integer unrestrictedCouponCount = 0;
    for (VoucherDefinition voucherDefinition : monthlyVoucherDefinitions) {
      if (!limitedVoucherDefinitionIds.contains(voucherDefinition.Id)) {
        unrestrictedCouponCount++;
      }
    }

    Integer maxLimitedCouponCountForOneTier = 0;
    for (Id tierId : voucherDefinitionIdsByTierId.keySet()) {
      maxLimitedCouponCountForOneTier = Math.max(maxLimitedCouponCountForOneTier, voucherDefinitionIdsByTierId.get(tierId).size());
    }

    return unrestrictedCouponCount + maxLimitedCouponCountForOneTier;
  }

  private static Id resolveTierId(String value, Map<String, Id> tierIdByGrade) {
    if (String.isBlank(value)) {
      return null;
    }

    if (isSalesforceId(value)) {
      try {
        return (Id) value;
      } catch (Exception ignore) {
        return null;
      }
    }

    return tierIdByGrade.get(value);
  }

  private static Boolean isSalesforceId(String value) {
    return !String.isBlank(value) && Pattern.matches('^[a-zA-Z0-9]{15}([a-zA-Z0-9]{3})?$', value);
  }
}