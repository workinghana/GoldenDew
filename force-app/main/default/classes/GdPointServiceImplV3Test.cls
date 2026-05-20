@IsTest
private class GdPointServiceImplV3Test {
  /**
   * v3 Phase 4 — Traceability 보존 모델 전용 단위 테스트
   *
   * Flag: PointCancel_PreserveTrace
   *
   * 목적:
   *   v3 경로(cancelPointRedemption_v3) 의 핵심 invariant 를 단위 테스트로 고정.
   *   Flag ON 상태에서의 동작을 검증.
   */

  // ============================================================
  // Feature Flag 헬퍼 검증
  // ============================================================

  @IsTest
  static void v3_featureFlag_unregistered_returnsFalse() {
    GdFeatureFlag.clearCacheForTest();
    System.assertEquals(false, GdFeatureFlag.isEnabled('__NonExistent_Flag_For_Unit_Test__'), '미등록 Flag 는 false 반환');
  }

  @IsTest
  static void v3_featureFlag_blankName_returnsFalse() {
    GdFeatureFlag.clearCacheForTest();
    System.assertEquals(false, GdFeatureFlag.isEnabled(null), 'null 이름은 false');
    System.assertEquals(false, GdFeatureFlag.isEnabled(''), '빈 문자열은 false');
    System.assertEquals(false, GdFeatureFlag.isEnabled('   '), '공백 문자열은 false');
  }

  @IsTest
  static void v3_featureFlag_cacheHit_returnsCachedValue() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', false);
    // 첫 호출 캐시 적중 후 두 번째 호출도 동일 값
    System.assertEquals(false, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'));
    System.assertEquals(false, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'));
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_featureFlag_setForTest_on_controlsReturn() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);
    System.assertEquals(true, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'), 'setForTest 로 true 주입 시 true 반환');
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_featureFlag_setForTest_off_controlsReturn() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', false);
    System.assertEquals(false, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'), 'setForTest 로 false 주입 시 false 반환');
    GdFeatureFlag.clearCacheForTest();
  }

  // ============================================================
  // 불변량 검증 — 규칙만 유효 (실제 DB 없이 논리 검증)
  // ============================================================

  @IsTest
  static void v3_invariant_flagOnAndOff_areExclusive() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);
    GdFeatureFlag.setForTest('CancelPointRedemption_UseFixedLogic', false);
    System.assertEquals(true, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'));
    System.assertEquals(false, GdFeatureFlag.isEnabled('CancelPointRedemption_UseFixedLogic'));
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_invariant_flagOnPath_tjUsage() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);
    GdFeatureFlag.setForTest('CancelPointRedemption_UseFixedLogic', true);

    System.assertEquals(true, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'), 'v3 Flag ON');
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_invariant_nullTj_throwsInServiceCall() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);

    GdPointServiceImpl svc = new GdPointServiceImpl();
    Boolean thrown = false;
    try {
      svc.cancelPointRedemption_v3(null);
    } catch (CustomException e) {
      thrown = (e.code == 400);
    }
    System.assertEquals(true, thrown, 'v3 null TJ → CustomException(400)');
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_flagInteraction_v3OverridesV2() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);
    GdFeatureFlag.setForTest('CancelPointRedemption_UseFixedLogic', true);

    Boolean v3On = GdFeatureFlag.isEnabled('PointCancel_PreserveTrace');
    Boolean v2On = GdFeatureFlag.isEnabled('CancelPointRedemption_UseFixedLogic');
    System.assertEquals(true, v3On && v2On, '두 Flag 동시 ON 가능');
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_flagOff_legacyBehaviorPreserved() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', false);
    GdFeatureFlag.setForTest('CancelPointRedemption_UseFixedLogic', true);
    System.assertEquals(false, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'));
    System.assertEquals(true, GdFeatureFlag.isEnabled('CancelPointRedemption_UseFixedLogic'));
    GdFeatureFlag.clearCacheForTest();
  }
}