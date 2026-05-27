/**
 * LoyaltyMemberValidatorBatch
 *
 * 책임 — 최근 활동 있는 회원을 대상으로 회원 단위 정밀 검증을 일괄 실행.
 *
 * 회원당 호출되는 검증:
 *   - LoyaltyPointInstantValidator.validateAndAlertByMemberNo           (§12, 잔액 + LASEL 정밀)
 *   - LoyaltyPointEventValidator.validateAndAlertOptionCLumpMatching   (§11.5 RESTORE 3종)
 *   - LoyaltyPointEventValidator.validateAndAlertSalePatchAccrualLump  (§11.5 SALE_PATCH)
 *   - LoyaltyPointEventValidator.validateAndAlertOriginCreditLLTrace   (§6.3 chain)
 *   - LoyaltyHelpInfoValidator.validateAndAlert                         (§9/§10 invariants)
 *
 * 대상 회원 선정:
 *   - LoyaltyLedger LastModifiedDate 최근 N 일 내 변동된 회원
 *   - 또는 LASEL.AvailablePoints__c < 0 인 회원 (positive selection)
 *
 * 주의:
 *   - 회원 1명당 callout 최대 5건 (5개 validator). batch scope 10 → execute 당 50 callout.
 *   - Slack 한도(100/Apex)를 고려해 scope 10 권장.
 */
public without sharing class LoyaltyMemberValidatorBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
  private final Integer recentDays;
  private Integer memberProcessedCount = 0;
  private Integer alertSentCount = 0;
  private Integer errorCount = 0;

  public LoyaltyMemberValidatorBatch() {
    this(7);
  }

  public LoyaltyMemberValidatorBatch(Integer recentDays) {
    this.recentDays = (recentDays == null || recentDays <= 0) ? 7 : recentDays;
  }

  public Database.QueryLocator start(Database.BatchableContext bc) {
    Datetime sinceDate = Datetime.now().addDays(-recentDays);
    // Apex SOQL 제약: 한 쿼리에 semi-join 1개, 최상위 WHERE 에만 허용.
    //   → 최근 LL 변동 회원만 우선 (LASEL 음수 회원은 LoyaltyActivityCounter 가 별도 즉시 알림)
    return Database.getQueryLocator([
      SELECT Id, MembershipNumber, Contact.MemberNo__c
      FROM LoyaltyProgramMember
      WHERE MemberStatus = 'Active'
        AND Id IN (SELECT LoyaltyProgramMemberId FROM LoyaltyLedger WHERE LastModifiedDate >= :sinceDate)
    ]);
  }

  public void execute(Database.BatchableContext bc, List<LoyaltyProgramMember> scope) {
    for (LoyaltyProgramMember m : scope) {
      try {
        String memberNoVal = (m.Contact == null) ? m.MembershipNumber : m.Contact.MemberNo__c;
        Boolean a1 = LoyaltyPointInstantValidator.validateAndAlertByMemberNo(memberNoVal);
        Boolean a2 = LoyaltyPointEventValidator.validateAndAlertOptionCLumpMatching(m.Id);
        Boolean a3 = LoyaltyPointEventValidator.validateAndAlertSalePatchAccrualLump(m.Id);
        Boolean a4 = LoyaltyPointEventValidator.validateAndAlertOriginCreditLLTrace(m.Id);
        Boolean a5 = LoyaltyHelpInfoValidator.validateAndAlert(m.Id);
        memberProcessedCount++;
        if (a1 == false) alertSentCount++;
        if (a2 == false) alertSentCount++;
        if (a3 == false) alertSentCount++;
        if (a4 == false) alertSentCount++;
        if (a5 == false) alertSentCount++;
      } catch (Exception e) {
        errorCount++;
        System.debug(LoggingLevel.ERROR,
          '[LoyaltyMemberValidatorBatch] memberId=' + m.Id + ' err=' + e.getMessage());
      }
    }
  }

  public void finish(Database.BatchableContext bc) {
    System.debug(LoggingLevel.INFO,
      '[LoyaltyMemberValidatorBatch] members=' + memberProcessedCount +
      ' alerts=' + alertSentCount +
      ' errors=' + errorCount);
  }
}