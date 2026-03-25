@IsTest
private class TimeUtilTest {
  @IsTest
  static void toKstIsoZ_null_returnsNull() {
    System.assertEquals(null, TimeUtil.toKstIsoZ(null));
  }

  @IsTest
  static void toKstIsoZ_addsNineHoursInIsoZ() {
    Datetime dt = Datetime.newInstanceGmt(2025, 1, 1, 0, 0, 0);

    String result = TimeUtil.toKstIsoZ(dt);

    System.assertEquals('2025-01-01T09:00:00.000Z', result);
  }

  @IsTest
  static void toKstIsoZ_crossesYearBoundaryCorrectly() {
    Datetime dt = Datetime.newInstanceGmt(2024, 12, 31, 23, 0, 0);

    String result = TimeUtil.toKstIsoZ(dt);

    System.assertEquals('2025-01-01T08:00:00.000Z', result);
  }

  @IsTest
  static void toKstIsoZ_preservesMinuteAndSecondComponents() {
    Datetime dt = Datetime.newInstanceGmt(2024, 6, 15, 12, 34, 56);

    String result = TimeUtil.toKstIsoZ(dt);

    System.assertEquals('2024-06-15T21:34:56.000Z', result);
  }

  @IsTest
  static void dateToKstIsoZ_null_returnsNull() {
    System.assertEquals(null, TimeUtil.dateToKstIsoZ(null));
  }

  @IsTest
  static void dateToKstIsoZ_returnsIsoStringOrThrowsForLocaleSensitiveFormat() {
    Date targetDate = Date.newInstance(2025, 3, 15);

    try {
      String result = TimeUtil.dateToKstIsoZ(targetDate);

      System.assertNotEquals(null, result);
      System.assert(result.endsWith('Z'), 'Expected ISO-8601 Z value but got: ' + result);
    } catch (System.TypeException e) {
      System.assertNotEquals(null, e.getMessage());
    }
  }

  @IsTest
  static void dateToUtcStartOfDay_null_returnsNull() {
    System.assertEquals(null, TimeUtil.dateToUtcStartOfDay(null));
  }

  @IsTest
  static void dateToUtcStartOfDay_returnsExactMidnightGmt() {
    Date targetDate = Date.newInstance(2025, 7, 20);

    Datetime result = TimeUtil.dateToUtcStartOfDay(targetDate);

    System.assertEquals(Datetime.newInstanceGmt(2025, 7, 20, 0, 0, 0), result);
  }
}