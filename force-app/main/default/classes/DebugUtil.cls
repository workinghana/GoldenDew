public with sharing class DebugUtil {
  @TestVisible
  public static Boolean forceSerializeError = false;

  @TestVisible
  private static String serialize(Object obj) {
    if (Test.isRunningTest() && forceSerializeError) {
      throw new IllegalArgumentException('Forced serialize error'); // ✅ Apex에서 생성 가능
    }
    return JSON.serialize(obj);
  }

  public static void pretty(Object obj) {
    try {
      System.debug(serialize(obj));
    } catch (Exception e) {
      System.debug('JSON serialize failed: ' + e.getMessage());
    }
  }

  public static void pretty(String label, Object obj) {
    try {
      System.debug(label + ' => ' + JSON.serializePretty(obj));
    } catch (Exception e) {
      System.debug(label + ' => [serialize error]');
    }
  }
}