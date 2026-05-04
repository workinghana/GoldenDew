/**
 * GdFeatureFlag — Custom Metadata 기반 Feature Flag 헬퍼.
 *
 * 용도:
 *   Apex 코드 내에서 런타임에 Feature 를 On/Off 할 수 있는 스위치 제공.
 *   각 Flag 는 GdFeatureFlag__mdt 의 DeveloperName 으로 식별.
 *
 * 사용:
 *   if (GdFeatureFlag.isEnabled('CancelPointRedemption_UseFixedLogic')) {
 *     // 신규 경로
 *   } else {
 *     // 기존 경로
 *   }
 *
 * 기본값: 존재하지 않거나 IsActive__c == false 이면 false.
 * 안전:   메타데이터 조회 실패 시 false 반환 (기존 로직 유지).
 *
 * 2026-04-24 Bug 2 Phase 2 신규.
 */
public with sharing class GdFeatureFlag {
  // 트랜잭션 당 1회 조회 후 캐싱 (같은 Flag 를 여러 번 조회해도 가벼움)
  private static Map<String, Boolean> cache = new Map<String, Boolean>();

  /**
   * Feature Flag 활성 여부 조회.
   * @param flagName  GdFeatureFlag__mdt.DeveloperName
   * @return          활성 true / 비활성·미존재·예외 false
   */
  public static Boolean isEnabled(String flagName) {
    if (String.isBlank(flagName)) {
      return false;
    }
    if (cache.containsKey(flagName)) {
      return cache.get(flagName);
    }
    Boolean enabled = false;
    try {
      GdFeatureFlag__mdt flag = GdFeatureFlag__mdt.getInstance(flagName);
      if (flag != null && flag.IsActive__c == true) {
        enabled = true;
      }
    } catch (Exception e) {
      // 조회 실패 시 기본 false (안전 기본값)
      enabled = false;
    }
    cache.put(flagName, enabled);
    return enabled;
  }

  /**
   * 테스트 전용 — 단위 테스트에서 Flag 값을 강제로 주입.
   * 운영 코드에서는 호출 금지.
   */
  @TestVisible
  private static void setForTest(String flagName, Boolean value) {
    cache.put(flagName, value);
  }

  /**
   * 테스트 전용 — 캐시 초기화.
   */
  @TestVisible
  private static void clearCacheForTest() {
    cache.clear();
  }
}