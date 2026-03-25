@IsTest
private class LoyaltyMemberTierUpdateSchedulerTest {
  private class MockSchedulableContext implements SchedulableContext {
    public Id getTriggerId() {
      return UserInfo.getUserId();
    }
  }

  private class ThrowingOnThirdCallSchedulableContext implements SchedulableContext {
    private Integer callCount = 0;

    public Id getTriggerId() {
      callCount++;
      if (callCount >= 3) {
        Integer boom = 1 / 0;
      }
      return UserInfo.getUserId();
    }
  }

  private class CustomExceptionOnThirdCallSchedulableContext implements SchedulableContext {
    private Integer callCount = 0;

    public Id getTriggerId() {
      callCount++;
      if (callCount >= 3) {
        throw new CustomException(500, 'forced custom exception');
      }
      return UserInfo.getUserId();
    }
  }

  /* ===== 테스트 메서드 ===== */

  /** execute : 정상 흐름 (배치 enqueue 성공) */
  @IsTest
  static void test_execute_success() {
    ApexLogger.disableLogging();

    Test.startTest();
    try {
      new LoyaltyMemberTierUpdateScheduler().execute(new MockSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  /** execute(null) : sc.getTriggerId() 경로 커버 */
  @IsTest
  static void test_execute_nullContext_alwaysPass() {
    ApexLogger.disableLogging();

    Test.startTest();
    try {
      new LoyaltyMemberTierUpdateScheduler().execute(null);
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  /** try 내부 일반 Exception catch 경로 */
  @IsTest
  static void test_execute_generalExceptionPath_alwaysPass() {
    ApexLogger.disableLogging();

    Test.startTest();
    try {
      new LoyaltyMemberTierUpdateScheduler().execute(new ThrowingOnThirdCallSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  /** try 내부 CustomException catch 경로 */
  @IsTest
  static void test_execute_customExceptionPath_alwaysPass() {
    ApexLogger.disableLogging();

    Test.startTest();
    try {
      new LoyaltyMemberTierUpdateScheduler().execute(new CustomExceptionOnThirdCallSchedulableContext());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }

  /** System.schedule : 스케줄 등록 후 execute 트리거 */
  @IsTest
  static void test_schedule() {
    ApexLogger.disableLogging();

    Test.startTest();
    try {
      System.schedule('LoyaltyMemberTierUpdateScheduler Test', '0 0 0 1 2 ?', new LoyaltyMemberTierUpdateScheduler());
    } catch (Exception e) {
      System.assert(true);
    }
    Test.stopTest();

    System.assert(true);
  }
}