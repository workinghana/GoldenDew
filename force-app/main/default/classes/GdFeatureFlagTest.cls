@IsTest
private class GdFeatureFlagTest {
  private static final String FLAG_NAME = 'UnitTest_Flag_A';
  private static final String OTHER_FLAG = 'UnitTest_Flag_B';

  @IsTest
  static void isEnabled_null_returnsFalse() {
    GdFeatureFlag.clearCacheForTest();

    System.assertEquals(false, GdFeatureFlag.isEnabled(null));
  }

  @IsTest
  static void isEnabled_blank_returnsFalse() {
    GdFeatureFlag.clearCacheForTest();

    System.assertEquals(false, GdFeatureFlag.isEnabled(''));
    System.assertEquals(false, GdFeatureFlag.isEnabled('   '));
  }

  @IsTest
  static void isEnabled_nonExistentFlag_returnsFalse() {
    GdFeatureFlag.clearCacheForTest();

    Boolean result = GdFeatureFlag.isEnabled('Definitely_Not_A_Real_Flag_' + System.now().getTime());

    System.assertEquals(false, result);
  }

  @IsTest
  static void isEnabled_setForTestTrue_returnsTrue() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest(FLAG_NAME, true);

    Boolean result = GdFeatureFlag.isEnabled(FLAG_NAME);

    System.assertEquals(true, result);
  }

  @IsTest
  static void isEnabled_setForTestFalse_returnsFalse() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest(FLAG_NAME, false);

    Boolean result = GdFeatureFlag.isEnabled(FLAG_NAME);

    System.assertEquals(false, result);
  }

  @IsTest
  static void isEnabled_repeatedCall_usesCache() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest(FLAG_NAME, true);

    Boolean first = GdFeatureFlag.isEnabled(FLAG_NAME);
    Boolean second = GdFeatureFlag.isEnabled(FLAG_NAME);

    System.assertEquals(true, first);
    System.assertEquals(true, second);
  }

  @IsTest
  static void clearCacheForTest_removesCachedValue() {
    GdFeatureFlag.setForTest(FLAG_NAME, true);
    System.assertEquals(true, GdFeatureFlag.isEnabled(FLAG_NAME));

    GdFeatureFlag.clearCacheForTest();

    // 캐시 비워진 후 미존재 Flag 조회 → 메타데이터 조회 경로 진입 후 false 반환
    Boolean result = GdFeatureFlag.isEnabled(FLAG_NAME);
    System.assertEquals(false, result);
  }

  @IsTest
  static void isEnabled_independentFlagsCachedSeparately() {
    GdFeatureFlag.clearCacheForTest();
    GdFeatureFlag.setForTest(FLAG_NAME, true);
    GdFeatureFlag.setForTest(OTHER_FLAG, false);

    System.assertEquals(true, GdFeatureFlag.isEnabled(FLAG_NAME));
    System.assertEquals(false, GdFeatureFlag.isEnabled(OTHER_FLAG));
  }
}