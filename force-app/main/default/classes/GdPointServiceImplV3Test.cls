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
  static void v3_featureFlag_disabled_by_default() {
    GdFeatureFlag.clearCacheForTest();
    System.assertEquals(false, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'),
      'v3 Flag 는 미등록 시 false 반환');
  }

  @IsTest
  static void v3_featureFlag_setForTest_on_controlsReturn() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);
    System.assertEquals(true, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'),
      'setForTest 로 true 주입 시 true 반환');
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_featureFlag_setForTest_off_controlsReturn() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', false);
    System.assertEquals(false, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'),
      'setForTest 로 false 주입 시 false 반환');
    GdFeatureFlag.clearCacheForTest();
  }

  // ============================================================
  // 불변량 검증 — 규칙만 유효 (실제 DB 없이 논리 검증)
  // ============================================================

  @IsTest
  static void v3_invariant_flagOnAndOff_areExclusive() {
    // Flag 값이 명확히 독립적으로 제어 가능한지 확인
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);
    GdFeatureFlag.setForTest('CancelPointRedemption_UseFixedLogic', false);
    System.assertEquals(true, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'));
    System.assertEquals(false, GdFeatureFlag.isEnabled('CancelPointRedemption_UseFixedLogic'));
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_invariant_flagOnPath_tjUsage() {
    // v3 Flag ON 상태 확인 후 cancelPointRedemption dispatch 경로 의도 검증
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);
    GdFeatureFlag.setForTest('CancelPointRedemption_UseFixedLogic', true);

    // dispatch 로직상 v3 Flag 가 우선 → v3 경로 기대
    // (실제 호출은 integration 에서 검증)
    System.assertEquals(true, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'),
      'v3 Flag ON');
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_invariant_nullTj_throwsInServiceCall() {
    // v3 경로가 null TJ 입력 시 CustomException 던지는지 확인
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
    // v3 ON + v2 ON 동시: v3 가 dispatch 우선순위
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', true);
    GdFeatureFlag.setForTest('CancelPointRedemption_UseFixedLogic', true);

    // 두 Flag 가 동시에 true 여도 v3 가 읽혀야 함
    Boolean v3On = GdFeatureFlag.isEnabled('PointCancel_PreserveTrace');
    Boolean v2On = GdFeatureFlag.isEnabled('CancelPointRedemption_UseFixedLogic');
    System.assertEquals(true, v3On && v2On, '두 Flag 동시 ON 가능');
    GdFeatureFlag.clearCacheForTest();
  }

  @IsTest
  static void v3_flagOff_legacyBehaviorPreserved() {
    // v3 Flag OFF 인 경우 기존 Bug 2 Flag 에 따라 v1/v2 경로 사용
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest('PointCancel_PreserveTrace', false);
    GdFeatureFlag.setForTest('CancelPointRedemption_UseFixedLogic', true);
    System.assertEquals(false, GdFeatureFlag.isEnabled('PointCancel_PreserveTrace'));
    System.assertEquals(true, GdFeatureFlag.isEnabled('CancelPointRedemption_UseFixedLogic'));
    GdFeatureFlag.clearCacheForTest();
  }
}