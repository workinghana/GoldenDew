public with sharing class SObjectUtil {
  public SObjectUtil() {
  }

  // Name 필드로 검색
  public static Id findIdByName(Schema.SObjectType sType, String nameValue, Boolean isRequired) {
    if (sType == null || String.isBlank(nameValue)) {
      if (isRequired) {
        throw new ValidationException('findIdByName()', nameValue + ' 값이 없습니다.');
      }
      return null;
    }

    Schema.DescribeSObjectResult describe = sType.getDescribe();
    String objectApiName = describe.getName();

    // Name 필드 체크
    Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
    if (!fieldMap.containsKey('Name')) {
      if (isRequired) {
        throw new ValidationException('findIdByName()', objectApiName + ' 오브젝트에는 Name 필드가 없습니다.');
      }
      return null;
    }

    String soql = 'SELECT Id ' + 'FROM ' + objectApiName + ' ' + 'WHERE Name = :nameValue ' + 'LIMIT 1';

    List<SObject> records = Database.query(soql);

    if (records.isEmpty()) {
      if (isRequired) {
        throw new ValidationException('findIdByName()', nameValue + ' 값과 일치하는 레코드가 없습니다.');
      }
      return null;
    }

    return (Id) records[0].get('Id');
  }

  // 조건 검색
  public static Id findIdByConditions(Schema.SObjectType sType, Map<String, Object> conditions, Boolean isRequired) {
    if (sType == null || conditions == null || conditions.isEmpty()) {
      if (isRequired) {
        throw new ValidationException('findIdByConditions()', '검색 조건이 없습니다.');
      }
      return null;
    }

    Schema.DescribeSObjectResult describe = sType.getDescribe();
    String objectApiName = describe.getName();

    // 필드 존재 여부 체크
    Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
    for (String fieldName : conditions.keySet()) {
      if (!fieldMap.containsKey(fieldName)) {
        if (isRequired) {
          throw new ValidationException('findIdByConditions()', objectApiName + '.' + fieldName + ' 필드가 존재하지 않습니다.');
        }
        return null;
      }
    }

    // 조건문(WHERE) 생성
    List<String> whereList = new List<String>();
    for (String fieldName : conditions.keySet()) {
      whereList.add(fieldName + ' = \'' + conditions.get(fieldName) + '\'');
    }

    String whereClause = String.join(whereList, ' AND ');

    String soql = 'SELECT Id FROM ' + objectApiName + ' WHERE ' + whereClause + ' LIMIT 1';

    List<SObject> result = Database.query(soql);

    if (result.isEmpty()) {
      if (isRequired) {
        throw new ValidationException('findIdByConditions()', '조건에 맞는 레코드가 없습니다.');
      }
      return null;
    }

    return (Id) result[0].get('Id');
  }
}