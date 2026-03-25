@IsTest
private class TriggerHandlerTest {
  // =========================================
  // Test Handler (override hooks)
  // =========================================
  private class TestHandler extends TriggerHandler {
    public Integer beforeInsertCnt = 0;
    public Integer beforeUpdateCnt = 0;
    public Integer beforeDeleteCnt = 0;
    public Integer afterInsertCnt = 0;
    public Integer afterUpdateCnt = 0;
    public Integer afterDeleteCnt = 0;
    public Integer afterUndeleteCnt = 0;

    // ✅ global 말고 public override 로 작성
    public override void beforeInsert() {
      beforeInsertCnt++;
    }
    public override void beforeUpdate() {
      beforeUpdateCnt++;
    }
    public override void beforeDelete() {
      beforeDeleteCnt++;
    }
    public override void afterInsert() {
      afterInsertCnt++;
    }
    public override void afterUpdate() {
      afterUpdateCnt++;
    }
    public override void afterDelete() {
      afterDeleteCnt++;
    }
    public override void afterUndelete() {
      afterUndeleteCnt++;
    }
  }

  private static String handlerName(TriggerHandler h) {
    return String.valueOf(h).substringBefore(':');
  }

  // =========================================
  // 1) 트리거 외부에서 run() 호출 시 예외
  // =========================================
  @IsTest
  static void test_run_outside_trigger_throws() {
    TestHandler h = new TestHandler();

    try {
      h.run();
      System.assert(false, 'Expected exception when run() is called outside trigger execution.');
    } catch (Exception e) {
      System.assert(e.getMessage() != null);
    }
  }

  // =========================================
  // 2) 컨텍스트별 디스패치 동작
  // =========================================
  @IsTest
  static void test_dispatch_all_contexts() {
    TestHandler h = new TestHandler();

    h.setTriggerContext('before insert', true);
    h.run();
    System.assertEquals(1, h.beforeInsertCnt);

    h.setTriggerContext('before update', true);
    h.run();
    System.assertEquals(1, h.beforeUpdateCnt);

    h.setTriggerContext('before delete', true);
    h.run();
    System.assertEquals(1, h.beforeDeleteCnt);

    h.setTriggerContext('after insert', true);
    h.run();
    System.assertEquals(1, h.afterInsertCnt);

    h.setTriggerContext('after update', true);
    h.run();
    System.assertEquals(1, h.afterUpdateCnt);

    h.setTriggerContext('after delete', true);
    h.run();
    System.assertEquals(1, h.afterDeleteCnt);

    h.setTriggerContext('after undelete', true);
    h.run();
    System.assertEquals(1, h.afterUndeleteCnt);
  }

  // =========================================
  // 3) bypass 동작
  // =========================================
  @IsTest
  static void test_bypass_handler() {
    TestHandler h = new TestHandler();
    String name = handlerName(h);

    TriggerHandler.bypass(name);

    h.setTriggerContext('before insert', true);
    h.run();
    System.assertEquals(0, h.beforeInsertCnt);

    TriggerHandler.clearBypass(name);
    h.run();
    System.assertEquals(1, h.beforeInsertCnt);

    TriggerHandler.bypass(name);
    TriggerHandler.clearAllBypasses();
    System.assertEquals(false, TriggerHandler.isBypassed(name));
  }

  // =========================================
  // 4) loop count 초과 시 예외 발생
  // =========================================
  @IsTest
  static void test_loop_count_exceeded_throws() {
    TestHandler h = new TestHandler();

    h.setMaxLoopCount(1);
    h.setTriggerContext('after insert', true);

    h.run();
    System.assertEquals(1, h.afterInsertCnt);

    try {
      h.run();
      System.assert(false, 'Expected exception for loop count exceeded.');
    } catch (Exception e) {
      System.assert(e.getMessage() != null);
    }

    h.clearMaxLoopCount();
  }
}