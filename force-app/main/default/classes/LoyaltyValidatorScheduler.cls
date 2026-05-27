/**
 * LoyaltyValidatorScheduler
 *
 * 책임 — 주기적 cron 으로 검증 batch 들을 자동 실행.
 *
 * 두 가지 모드:
 *   - EVENT  : LoyaltyEventValidatorBatch  (Order/TJ 최근 변경 사후 검증)
 *   - MEMBER : LoyaltyMemberValidatorBatch (회원 단위 정밀 검증 5종)
 *
 * 권장 cron 설정 (Setup → Apex Classes → Schedule Apex):
 *   - EVENT  : 30분마다     (since = 30분 전 정도, 약간의 overlap)
 *       new LoyaltyValidatorScheduler(LoyaltyValidatorScheduler.Mode.EVENT, 35);
 *       cron: 0 0,30 * * * ?
 *   - MEMBER : 매일 새벽 1번 (recentDays=7)
 *       new LoyaltyValidatorScheduler(LoyaltyValidatorScheduler.Mode.MEMBER, 7);
 *       cron: 0 0 3 * * ?
 *
 * 사용 예:
 *   System.schedule('LoyaltyValidator_Event_30min', '0 0,30 * * * ?',
 *     new LoyaltyValidatorScheduler(LoyaltyValidatorScheduler.Mode.EVENT, 35));
 *   System.schedule('LoyaltyValidator_Member_Daily', '0 0 3 * * ?',
 *     new LoyaltyValidatorScheduler(LoyaltyValidatorScheduler.Mode.MEMBER, 7));
 */
public without sharing class LoyaltyValidatorScheduler implements Schedulable {
  public enum Mode { EVENT, MEMBER }

  private final Mode runMode;
  private final Integer windowParam;

  public LoyaltyValidatorScheduler() {
    this(Mode.EVENT, 35);
  }

  public LoyaltyValidatorScheduler(Mode md, Integer windowParam) {
    this.runMode = md == null ? Mode.EVENT : md;
    this.windowParam = (windowParam == null || windowParam <= 0)
      ? (this.runMode == Mode.EVENT ? 35 : 7)
      : windowParam;
  }

  public void execute(SchedulableContext sc) {
    try {
      if (runMode == Mode.EVENT) {
        Datetime since = Datetime.now().addMinutes(-windowParam);
        Database.executeBatch(new LoyaltyEventValidatorBatch(since, LoyaltyEventValidatorBatch.Phase.ORDERS), 20);
        System.debug(LoggingLevel.INFO,
          '[LoyaltyValidatorScheduler] mode=EVENT since=' + since + ' (Order phase 시작, Deposit phase 자동 chain)');
      } else {
        Database.executeBatch(new LoyaltyMemberValidatorBatch(windowParam), 10);
        System.debug(LoggingLevel.INFO,
          '[LoyaltyValidatorScheduler] mode=MEMBER recentDays=' + windowParam);
      }
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR,
        '[LoyaltyValidatorScheduler] mode=' + runMode + ' err=' + e.getMessage());
    }
  }
}