global virtual class TriggerHandler {
  // static map of handlername, times run() was invoked
  private static Map<String, LoopCount> loopCountMap;
  private static Set<String> bypassedHandlers;

  // the current context of the trigger, overridable in tests
  @TestVisible
  private TriggerContext context;

  // the current context of the trigger, overridable in tests
  @TestVisible
  private Boolean isTriggerExecuting;

  // static initialization
  static {
    loopCountMap = new Map<String, LoopCount>();
    bypassedHandlers = new Set<String>();
  }

  // 생성자
  global TriggerHandler() {
    this.setTriggerContext();
  }

  // =================================================================================================================
  // Public Instance Methods

  // main method that will be called during execution
  global void run() {
    System.debug('트리거 실행 run !');
    if (!validateRun()) {
      return;
    }

    addToLoopCount();

    System.debug('this.context : ' + this.context);

    // dispatch to the correct handler method
    switch on this.context {
      when BEFORE_INSERT {
        this.beforeInsert();
      }
      when BEFORE_UPDATE {
        this.beforeUpdate();
      }
      when BEFORE_DELETE {
        this.beforeDelete();
      }
      when AFTER_INSERT {
        this.afterInsert();
      }
      when AFTER_UPDATE {
        this.afterUpdate();
      }
      when AFTER_DELETE {
        this.afterDelete();
      }
      when AFTER_UNDELETE {
        this.afterUndelete();
      }
    }
  }

  public void setMaxLoopCount(Integer max) {
    String handlerName = getHandlerName();
    if (!TriggerHandler.loopCountMap.containsKey(handlerName)) {
      TriggerHandler.loopCountMap.put(handlerName, new LoopCount(max));
    } else {
      TriggerHandler.loopCountMap.get(handlerName).setMax(max);
    }
  }

  public void clearMaxLoopCount() {
    this.setMaxLoopCount(-1);
  }

  // =================================================================================================================
  // Public Static Methods

  global static void bypass(String handlerName) {
    TriggerHandler.bypassedHandlers.add(handlerName);
  }

  global static void clearBypass(String handlerName) {
    TriggerHandler.bypassedHandlers.remove(handlerName);
  }

  global static Boolean isBypassed(String handlerName) {
    return TriggerHandler.bypassedHandlers.contains(handlerName);
  }

  global static void clearAllBypasses() {
    TriggerHandler.bypassedHandlers.clear();
  }

  // =================================================================================================================
  // Private Instance Methods

  @TestVisible
  private void setTriggerContext() {
    this.setTriggerContext(null, false);
  }

  @TestVisible
  private void setTriggerContext(String ctx, Boolean testMode) {
    if (!Trigger.isExecuting && !testMode) {
      this.isTriggerExecuting = false;
      return;
    } else {
      this.isTriggerExecuting = true;
    }

    if ((Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert) || (ctx != null && ctx == 'before insert')) {
      this.context = TriggerContext.BEFORE_INSERT;
    } else if ((Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate) || (ctx != null && ctx == 'before update')) {
      this.context = TriggerContext.BEFORE_UPDATE;
    } else if ((Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete) || (ctx != null && ctx == 'before delete')) {
      this.context = TriggerContext.BEFORE_DELETE;
    } else if ((Trigger.isExecuting && Trigger.isAfter && Trigger.isInsert) || (ctx != null && ctx == 'after insert')) {
      this.context = TriggerContext.AFTER_INSERT;
    } else if ((Trigger.isExecuting && Trigger.isAfter && Trigger.isUpdate) || (ctx != null && ctx == 'after update')) {
      this.context = TriggerContext.AFTER_UPDATE;
    } else if ((Trigger.isExecuting && Trigger.isAfter && Trigger.isDelete) || (ctx != null && ctx == 'after delete')) {
      this.context = TriggerContext.AFTER_DELETE;
    } else if ((Trigger.isExecuting && Trigger.isAfter && Trigger.isUndelete) || (ctx != null && ctx == 'after undelete')) {
      this.context = TriggerContext.AFTER_UNDELETE;
    }
  }

  // increment the loop count
  @TestVisible
  private void addToLoopCount() {
    String handlerName = getHandlerName();
    if (TriggerHandler.loopCountMap.containsKey(handlerName)) {
      System.debug('트리거 실행 횟수 : ' + TriggerHandler.loopCountMap.get(handlerName).count);
      Boolean exceeded = TriggerHandler.loopCountMap.get(handlerName).increment();
      if (exceeded) {
        Integer max = TriggerHandler.loopCountMap.get(handlerName).max;
        // throw new TriggerHandlerException('Maximum loop count of ' + String.valueOf(max) + ' reached in ' + handlerName);
        throw new CustomException('트리거가 허용된 최대 실행 횟수를 초과했습니다. (최대 ' + String.valueOf(max) + '회, 핸들러: ' + handlerName + ')');
      }
    }
  }

  // make sure this trigger should continue to run
  @TestVisible
  private Boolean validateRun() {
    System.debug('validateRun 진입');
    if (!this.isTriggerExecuting || this.context == null) {
      System.debug('Trigger handler called outside of Trigger execution');
      // throw new TriggerHandlerException(500, 'Trigger handler called outside of Trigger execution');
      throw new CustomException(500, 'Trigger handler called outside of Trigger execution');
    }
    return !TriggerHandler.bypassedHandlers.contains(getHandlerName());
  }

  @TestVisible
  private String getHandlerName() {
    return this.toString().substringBefore(':');
  }

  // =================================================================================================================
  // Context Methods

  // context-specific methods for override
  global virtual void beforeInsert() {
  }
  global virtual void beforeUpdate() {
  }
  global virtual void beforeDelete() {
  }
  global virtual void afterInsert() {
  }
  global virtual void afterUpdate() {
  }
  global virtual void afterDelete() {
  }
  global virtual void afterUndelete() {
  }

  // =================================================================================================================
  // Inner Classes

  // inner class for managing the loop count per handler
  @TestVisible
  private class LoopCount {
    private Integer max;
    private Integer count;

    public LoopCount() {
      this.max = 5;
      this.count = 0;
    }

    public LoopCount(Integer max) {
      this.max = max;
      this.count = 0;
    }

    public Boolean increment() {
      this.count++;
      return this.exceeded();
    }

    public Boolean exceeded() {
      return this.max >= 0 && this.count > this.max;
    }

    public Integer getMax() {
      return this.max;
    }

    public Integer getCount() {
      return this.count;
    }

    public void setMax(Integer max) {
      this.max = max;
    }
  }

  // possible trigger contexts
  @TestVisible
  private enum TriggerContext {
    BEFORE_INSERT,
    BEFORE_UPDATE,
    BEFORE_DELETE,
    AFTER_INSERT,
    AFTER_UPDATE,
    AFTER_DELETE,
    AFTER_UNDELETE
  }

  // exception class
  public class TriggerHandlerException extends Exception {
  }

  /**
   * Trigger.isInsert |	Boolean	Insert | 트리거 여부
   * Trigger.isUpdate |	Boolean	Update | 트리거 여부
   * Trigger.isDelete |	Boolean	Delete | 트리거 여부
   * Trigger.isUndelete |	Boolean	Undelete | 트리거 여부
   * Trigger.isBefore |	Boolean	Before | 트리거
   * Trigger.isAfter |	Boolean	After | 트리거
   * Trigger.isExecuting |	Boolean	| 트리거 실행 중 여부
   * Trigger.new |	List<SObject>	| 변경 후 레코드
   * Trigger.newMap |	Map<Id, SObject> | 변경 후 레코드 Map
   * Trigger.old |	List<SObject>	| 변경 전 레코드
   * Trigger.oldMap |	Map<Id, SObject> | 변경 전 레코드 Map
   * Trigger.size |	Integer	Trigger | 실행 레코드 수
   */
}