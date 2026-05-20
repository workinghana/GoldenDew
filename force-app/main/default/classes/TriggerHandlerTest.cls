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

  @IsTest
  static void test_isEnabled_defaults_to_true_when_setting_missing() {
    TriggerHandler.mockCache = new Map<String, Apex_Trigger_Setting__mdt>();

    System.assertEquals(
      true,
      TriggerHandler.isEnabled('MissingTriggerSetting', System.TriggerOperation.BEFORE_INSERT),
      'Missing custom metadata should fail open.'
    );

    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void test_isEnabled_returns_false_when_trigger_inactive() {
    TriggerHandler.mockCache = new Map<String, Apex_Trigger_Setting__mdt>{
      'InactiveTrigger' => makeSetting(false, true, true, true, true, true, true, true)
    };

    System.assertEquals(
      false,
      TriggerHandler.isEnabled('InactiveTrigger', System.TriggerOperation.AFTER_INSERT),
      'Inactive trigger setting should disable every operation.'
    );

    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void test_isEnabled_returns_operation_flags() {
    TriggerHandler.mockCache = new Map<String, Apex_Trigger_Setting__mdt>{
      'MixedTrigger' => makeSetting(true, true, false, true, false, true, false, true)
    };

    System.assertEquals(true, TriggerHandler.isEnabled('MixedTrigger', System.TriggerOperation.BEFORE_INSERT));
    System.assertEquals(false, TriggerHandler.isEnabled('MixedTrigger', System.TriggerOperation.AFTER_INSERT));
    System.assertEquals(true, TriggerHandler.isEnabled('MixedTrigger', System.TriggerOperation.BEFORE_UPDATE));
    System.assertEquals(false, TriggerHandler.isEnabled('MixedTrigger', System.TriggerOperation.AFTER_UPDATE));
    System.assertEquals(true, TriggerHandler.isEnabled('MixedTrigger', System.TriggerOperation.BEFORE_DELETE));
    System.assertEquals(false, TriggerHandler.isEnabled('MixedTrigger', System.TriggerOperation.AFTER_DELETE));
    System.assertEquals(true, TriggerHandler.isEnabled('MixedTrigger', System.TriggerOperation.AFTER_UNDELETE));

    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void test_isEnabled_fail_safe_returns_true_on_exception() {
    TriggerHandler.mockCache = new Map<String, Apex_Trigger_Setting__mdt>{
      'AnyTrigger' => makeSetting(true, true, true, true, true, true, true, true)
    };

    System.assertEquals(true, TriggerHandler.isEnabled('AnyTrigger', null), 'Unexpected errors in isEnabled should fail open.');

    TriggerHandler.mockCache = null;
  }

  @IsTest
  static void test_loop_count_accessors() {
    TriggerHandler.LoopCount defaultLoopCount = new TriggerHandler.LoopCount();
    System.assertEquals(5, defaultLoopCount.getMax());
    System.assertEquals(0, defaultLoopCount.getCount());
    System.assertEquals(false, defaultLoopCount.exceeded());

    TriggerHandler.LoopCount limitedLoopCount = new TriggerHandler.LoopCount(1);
    System.assertEquals(false, limitedLoopCount.increment());
    System.assertEquals(true, limitedLoopCount.increment());
    System.assertEquals(2, limitedLoopCount.getCount());

    limitedLoopCount.setMax(-1);
    System.assertEquals(false, limitedLoopCount.exceeded());
  }

  private static Apex_Trigger_Setting__mdt makeSetting(
    Boolean isActive,
    Boolean beforeInsert,
    Boolean afterInsert,
    Boolean beforeUpdate,
    Boolean afterUpdate,
    Boolean beforeDelete,
    Boolean afterDelete,
    Boolean afterUndelete
  ) {
    return new Apex_Trigger_Setting__mdt(
      IsActive__c = isActive,
      Before_Insert__c = beforeInsert,
      After_Insert__c = afterInsert,
      Before_Update__c = beforeUpdate,
      After_Update__c = afterUpdate,
      Before_Delete__c = beforeDelete,
      After_Delete__c = afterDelete,
      After_Undelete__c = afterUndelete
    );
  }
}