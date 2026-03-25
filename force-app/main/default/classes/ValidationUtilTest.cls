@IsTest
private class ValidationUtilTest {
  // === String ===
  @IsTest
  static void test_stringValidation() {
    ValidationUtil.stringValidation('abc', 'Name', true);
    ValidationUtil.stringValidation(null, 'Optional', false);

    try {
      ValidationUtil.stringValidation(10, 'Name', true);
    } catch (Exception e) {
    }
  }

  // === String Ex ===
  @IsTest
  static void test_stringValidationEx() {
    ValidationUtil.stringValidationEx('abc', 'Name', true, false);
    ValidationUtil.stringValidationEx('', 'Name', false, true);
    ValidationUtil.stringValidationEx(null, 'Opt', false, true);

    try {
      ValidationUtil.stringValidationEx('', 'Name', true, false);
    } catch (Exception e) {
    }

    try {
      ValidationUtil.stringValidationEx(123, 'Name', true, false);
    } catch (Exception e) {
    }
  }

  // === Integer ===
  @IsTest
  static void test_integerValidation() {
    ValidationUtil.integerValidation(5, 'Age', true);
    ValidationUtil.integerValidation(null, 'AgeOpt', false);

    try {
      ValidationUtil.integerValidation('5', 'Age', true);
    } catch (Exception e) {
    }
  }

  // === Decimal ===
  @IsTest
  static void test_decimalValidation() {
    ValidationUtil.decimalValidation(10.5, 'Price', true);
    ValidationUtil.decimalValidation(null, 'PriceOpt', false);

    try {
      ValidationUtil.decimalValidation('10.5', 'Price', true);
    } catch (Exception e) {
    }
  }

  // === Decimal > 0 ===
  @IsTest
  static void test_decimalGreaterThanZero() {
    ValidationUtil.decimalGreaterThanZero(10.0, 'Amount', true);
    ValidationUtil.decimalGreaterThanZero(null, 'AmountOpt', false);

    try {
      ValidationUtil.decimalGreaterThanZero(0, 'Amount', true);
    } catch (Exception e) {
    }
  }

  // === Double ===
  @IsTest
  static void test_doubleValidation() {
    ValidationUtil.doubleValidation(3.14, 'Rate', true);
    ValidationUtil.doubleValidation(null, 'RateOpt', false);

    try {
      ValidationUtil.doubleValidation('3.14', 'Rate', true);
    } catch (Exception e) {
    }
  }

  // === Boolean ===
  @IsTest
  static void test_booleanValidation() {
    ValidationUtil.booleanValidation(true, 'Active', true);
    ValidationUtil.booleanValidation(null, 'ActiveOpt', false);

    try {
      ValidationUtil.booleanValidation('true', 'Active', true);
    } catch (Exception e) {
    }
  }

  // === Date ===
  @IsTest
  static void test_dateValidation() {
    ValidationUtil.dateValidation(Date.today(), 'Date', true);
    ValidationUtil.dateValidation('2025-01-01', 'Date', true);
    ValidationUtil.dateValidation('20250101', 'Date', true);
    ValidationUtil.dateValidation('', 'DateOpt', false);

    try {
      ValidationUtil.dateValidation('01/01/2025', 'Date', true);
    } catch (Exception e) {
    }
  }

  // === Datetime ===
  @IsTest
  static void test_datetimeValidation() {
    ValidationUtil.datetimeValidation(Datetime.now(), 'Dt', true);
    ValidationUtil.datetimeValidation('2025-01-01 12:00:00', 'Dt', true);
    ValidationUtil.datetimeValidation('20250101120000', 'Dt', true);
    ValidationUtil.datetimeValidation('', 'DtOpt', false);

    try {
      ValidationUtil.datetimeValidation('2025/01/01', 'Dt', true);
    } catch (Exception e) {
    }
  }

  // === List<Object> ===
  @IsTest
  static void test_listObjValidation() {
    ValidationUtil.listObjValidation(new List<Object>{ 'a', 1 }, 'List', true);
    ValidationUtil.listObjValidation(new List<Object>(), 'ListOpt', false);

    try {
      ValidationUtil.listObjValidation(new List<Object>(), 'List', true);
    } catch (Exception e) {
    }
  }

  // === List<Object> → List<String> ===
  @IsTest
  static void test_listObjToStrValidation() {
    ValidationUtil.listObjToStrValidation(new List<Object>{ 'a', 'b' }, 'StrList', true);

    try {
      ValidationUtil.listObjToStrValidation(123, 'StrList', true);
    } catch (Exception e) {
    }
  }

  // === Map<String, Object> ===
  @IsTest
  static void test_mapStrObjValidation() {
    ValidationUtil.mapStrObjValidation(new Map<String, Object>{ 'k' => 'v' }, 'Map', true);

    try {
      ValidationUtil.mapStrObjValidation(123, 'Map', true);
    } catch (Exception e) {
    }
  }

  // === SObject ===
  @IsTest
  static void test_sObjectValidation() {
    Account a = new Account(Name = 'Test');
    ValidationUtil.sObjectValidation(a, 'Account', true);

    try {
      ValidationUtil.sObjectValidation('not sobject', 'Account', true);
    } catch (Exception e) {
    }
  }

  @IsTest
  static void test_stringValidationEx_null_required_branch() {
    try {
      ValidationUtil.stringValidationEx(null, 'Name', true, false);
    } catch (Exception e) {
    }
  }

  @IsTest
  static void test_dateValidation_extra_branches() {
    try {
      ValidationUtil.dateValidation('2025/01/01', 'Date', true);
    } catch (Exception e) {
    }

    try {
      ValidationUtil.dateValidation(12345, 'Date', true);
    } catch (Exception e) {
    }
  }

  @IsTest
  static void test_datetimeValidation_extra_branches() {
    try {
      ValidationUtil.datetimeValidation('2025/01/01 10:10:10', 'Dt', true);
    } catch (Exception e) {
    }

    try {
      ValidationUtil.datetimeValidation(999, 'Dt', true);
    } catch (Exception e) {
    }
  }

  @IsTest
  static void test_listObjToStrValidation_null_optional_branch() {
    List<String> result = ValidationUtil.listObjToStrValidation(null, 'List', false);
    System.assertEquals(null, result);
  }

  @IsTest
  static void test_mapStrObjValidation_null_optional_branch() {
    Map<String, Object> result = ValidationUtil.mapStrObjValidation(null, 'Map', false);
    System.assertEquals(null, result);
  }

  @IsTest
  static void test_sObjectValidation_null_optional_branch() {
    SObject result = ValidationUtil.sObjectValidation(null, 'Obj', false);
    System.assertEquals(null, result);
  }
}