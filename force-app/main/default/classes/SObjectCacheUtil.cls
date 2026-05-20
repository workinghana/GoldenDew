public with sharing class SObjectCacheUtil {
  // 트랜잭션-범위 캐시. 키: objectApiName + '|' + nameValue
  // 값: 매칭된 Id (성공한 경우에만)
  // 라이프사이클: Apex static 의 트랜잭션 자동 reset 에 위임
  @TestVisible
  private static Map<String, Id> ID_BY_NAME_CACHE = new Map<String, Id>();

  public SObjectCacheUtil() {
  }

  /**
   * Name 필드로 Id 조회 (트랜잭션 캐시 적용).
   *
   * 동작:
   *   - 첫 호출: SOQL 1회 실행 후 결과를 트랜잭션 캐시에 저장
   *   - 동일 (SObjectType, Name) 재호출: SOQL 없이 캐시에서 반환
   *   - null 결과는 캐시하지 않음 (mid-transaction record 생성 시나리오 대비)
   *
   * 안전성:
   *   - Apex static 변수는 트랜잭션 종료 시 자동 reset → stale data 없음
   *   - SObjectUtil.findIdByName 과 결과 동일 (입력값 동일 시)
   */
  public static Id findIdByNameCached(Schema.SObjectType sType, String nameValue, Boolean isRequired) {
    // ① null/blank 가드
    if (sType == null || String.isBlank(nameValue)) {
      if (isRequired) {
        throw new ValidationException('findIdByNameCached()', nameValue + ' 값이 없습니다.');
      }
      return null;
    }

    Schema.DescribeSObjectResult describe = sType.getDescribe();
    String objectApiName = describe.getName();

    // ② Cache lookup
    String cacheKey = objectApiName + '|' + nameValue;
    if (ID_BY_NAME_CACHE.containsKey(cacheKey)) {
      return ID_BY_NAME_CACHE.get(cacheKey); // ★ SOQL 0건
    }

    // ③ Cache miss — SOQL 실행
    Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
    if (!fieldMap.containsKey('Name')) {
      if (isRequired) {
        throw new ValidationException('findIdByNameCached()', objectApiName + ' 오브젝트에는 Name 필드가 없습니다.');
      }
      return null;
    }

    String soql = 'SELECT Id FROM ' + objectApiName + ' WHERE Name = :nameValue LIMIT 1';
    List<SObject> records = Database.query(soql);

    if (records.isEmpty()) {
      if (isRequired) {
        throw new ValidationException('findIdByNameCached()', nameValue + ' 값과 일치하는 레코드가 없습니다.');
      }
      return null; // ④ null 결과는 캐시하지 않음
    }

    Id result = (Id) records[0].get('Id');
    ID_BY_NAME_CACHE.put(cacheKey, result); // ⑤ 성공 결과만 캐시
    return result;
  }

  // ⑥ 테스트 격리용 헬퍼
  @TestVisible
  private static void clearIdByNameCache() {
    ID_BY_NAME_CACHE.clear();
  }
}