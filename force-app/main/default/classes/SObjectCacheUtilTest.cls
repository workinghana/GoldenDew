@IsTest
private class SObjectCacheUtilTest {
  // 테스트용 Account Name (다른 테스트와 충돌 방지)
  private static final String TEST_ACCOUNT_NAME = 'SObjectCacheUtilTest_Acc_xyz';
  private static final String NON_EXISTENT_NAME = 'NonExistent_Acc_zzz_999';

  @IsTest
  static void test_constructor_works() {
    SObjectCacheUtil util = new SObjectCacheUtil();
    System.assertNotEquals(null, util, 'constructor must produce instance');
  }

  // ============================================================
  // null sType / blank name 가드
  // ============================================================

  @IsTest
  static void test_null_sType_required_throws() {
    SObjectCacheUtil.clearIdByNameCache();
    Boolean caught = false;
    try {
      SObjectCacheUtil.findIdByNameCached(null, 'AnyName', true);
    } catch (ValidationException e) {
      caught = true;
    }
    System.assertEquals(true, caught, 'null sType + required → ValidationException 발생해야 함');
  }

  @IsTest
  static void test_null_sType_optional_returns_null() {
    SObjectCacheUtil.clearIdByNameCache();
    Id result = SObjectCacheUtil.findIdByNameCached(null, 'AnyName', false);
    System.assertEquals(null, result, 'null sType + optional → null 반환');
  }

  @IsTest
  static void test_blank_name_required_throws() {
    SObjectCacheUtil.clearIdByNameCache();
    Boolean caught = false;
    try {
      SObjectCacheUtil.findIdByNameCached(Account.SObjectType, '', true);
    } catch (ValidationException e) {
      caught = true;
    }
    System.assertEquals(true, caught, 'blank name + required → ValidationException 발생해야 함');
  }

  @IsTest
  static void test_blank_name_optional_returns_null() {
    SObjectCacheUtil.clearIdByNameCache();
    Id result = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, '', false);
    System.assertEquals(null, result, 'blank name + optional → null 반환');
  }

  @IsTest
  static void test_null_name_optional_returns_null() {
    SObjectCacheUtil.clearIdByNameCache();
    Id result = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, null, false);
    System.assertEquals(null, result, 'null name + optional → null 반환');
  }

  // ============================================================
  // Cache miss / hit 동작
  // ============================================================

  @IsTest
  static void test_cacheMiss_then_cacheHit_returns_same_id() {
    Account acc = new Account(Name = TEST_ACCOUNT_NAME);
    insert acc;

    SObjectCacheUtil.clearIdByNameCache();

    Test.startTest();
    // 1차 호출: cache miss → SOQL 1건
    Integer q0 = Limits.getQueries();
    Id id1 = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, TEST_ACCOUNT_NAME, true);
    Integer q1 = Limits.getQueries();

    // 2차 호출: cache hit → SOQL 0건
    Id id2 = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, TEST_ACCOUNT_NAME, true);
    Integer q2 = Limits.getQueries();

    // 3차 호출: cache hit → SOQL 0건 (반복 확인)
    Id id3 = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, TEST_ACCOUNT_NAME, true);
    Integer q3 = Limits.getQueries();
    Test.stopTest();

    System.assertEquals(acc.Id, id1, '1차 호출 결과는 insert한 Account Id 와 일치');
    System.assertEquals(acc.Id, id2, '2차 호출은 동일 Id 반환');
    System.assertEquals(acc.Id, id3, '3차 호출은 동일 Id 반환');
    System.assertEquals(1, q1 - q0, '1차 호출은 SOQL 1건 발생 (cache miss)');
    System.assertEquals(0, q2 - q1, '2차 호출은 SOQL 0건 (cache hit)');
    System.assertEquals(0, q3 - q2, '3차 호출은 SOQL 0건 (cache hit)');
  }

  // ============================================================
  // Record not found
  // ============================================================

  @IsTest
  static void test_record_not_found_required_throws() {
    SObjectCacheUtil.clearIdByNameCache();
    Boolean caught = false;
    try {
      SObjectCacheUtil.findIdByNameCached(Account.SObjectType, NON_EXISTENT_NAME, true);
    } catch (ValidationException e) {
      caught = true;
    }
    System.assertEquals(true, caught, '존재하지 않는 Name + required → ValidationException 발생해야 함');
  }

  @IsTest
  static void test_record_not_found_optional_returns_null() {
    SObjectCacheUtil.clearIdByNameCache();
    Id result = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, NON_EXISTENT_NAME, false);
    System.assertEquals(null, result, '존재하지 않는 Name + optional → null 반환');
  }

  @IsTest
  static void test_null_result_not_cached() {
    SObjectCacheUtil.clearIdByNameCache();
    Test.startTest();
    // 1차 호출: SOQL 실행 후 null 반환 (캐시 저장 안 됨)
    Integer q0 = Limits.getQueries();
    Id id1 = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, NON_EXISTENT_NAME, false);
    Integer q1 = Limits.getQueries();

    // 2차 호출: 동일하게 SOQL 실행됨 (null 은 캐시 안 됨 정책 검증)
    Id id2 = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, NON_EXISTENT_NAME, false);
    Integer q2 = Limits.getQueries();
    Test.stopTest();

    System.assertEquals(null, id1, '1차 호출은 null 반환');
    System.assertEquals(null, id2, '2차 호출도 null 반환');
    System.assertEquals(1, q1 - q0, '1차 호출은 SOQL 1건 발생');
    System.assertEquals(1, q2 - q1, '2차 호출도 SOQL 1건 발생 (null 은 캐시되지 않음)');
  }

  // ============================================================
  // clearIdByNameCache 동작
  // ============================================================

  @IsTest
  static void test_clearIdByNameCache_clears_entries() {
    Account acc = new Account(Name = TEST_ACCOUNT_NAME);
    insert acc;

    Test.startTest();
    // 캐시 채우기
    Id id1 = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, TEST_ACCOUNT_NAME, true);
    Integer q1 = Limits.getQueries();

    // 캐시 hit 확인
    Id id2 = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, TEST_ACCOUNT_NAME, true);
    Integer q2 = Limits.getQueries();
    System.assertEquals(0, q2 - q1, 'clear 전: 2차 호출은 cache hit');

    // 캐시 클리어
    SObjectCacheUtil.clearIdByNameCache();

    // 클리어 후: 다시 SOQL 실행됨
    Id id3 = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, TEST_ACCOUNT_NAME, true);
    Integer q3 = Limits.getQueries();
    Test.stopTest();

    System.assertEquals(acc.Id, id1);
    System.assertEquals(acc.Id, id2);
    System.assertEquals(acc.Id, id3, 'clear 후에도 동일 Id 반환');
    System.assertEquals(1, q3 - q2, 'clear 후 호출은 SOQL 1건 발생 (cache miss)');
  }

  // ============================================================
  // 서로 다른 SObjectType 간 캐시 키 분리 검증
  // ============================================================

  @IsTest
  static void test_different_objectTypes_use_separate_keys() {
    Account acc = new Account(Name = TEST_ACCOUNT_NAME);
    insert acc;
    Product2 prod = new Product2(Name = TEST_ACCOUNT_NAME, IsActive = true);
    insert prod;

    SObjectCacheUtil.clearIdByNameCache();

    Test.startTest();
    // 같은 Name 이라도 SObjectType 다르면 별도 캐시 항목
    Id accId = SObjectCacheUtil.findIdByNameCached(Account.SObjectType, TEST_ACCOUNT_NAME, true);
    Id prodId = SObjectCacheUtil.findIdByNameCached(Product2.SObjectType, TEST_ACCOUNT_NAME, true);
    Test.stopTest();

    System.assertEquals(acc.Id, accId, 'Account 검색 결과는 Account Id');
    System.assertEquals(prod.Id, prodId, 'Product2 검색 결과는 Product2 Id');
    System.assertNotEquals(accId, prodId, '두 결과는 다른 record');
  }
}