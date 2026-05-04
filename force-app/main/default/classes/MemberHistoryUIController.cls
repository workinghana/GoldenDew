public with sharing class MemberHistoryUIController {
  private static final Map<String, String> FIELD_LABEL_MAP = new Map<String, String>{
    'created' => '회원 생성',
    'FirstPurchaseDate__c' => '첫 주문 일자',
    'LastPurchaseDate__c' => '마지막 주문 일자'
  };
  private static final Pattern SALESFORCE_ID_PATTERN = Pattern.compile('^[a-zA-Z0-9]{15}$|^[a-zA-Z0-9]{18}$');

  @AuraEnabled(cacheable=true)
  public static List<MemberChangeHistoryDTO> getMemberHistory(Id loyaltyProgramMemberId) {
    List<MemberChangeHistoryDTO> result = new List<MemberChangeHistoryDTO>();

    for (LoyaltyProgramMemberHistory h : [
      SELECT CreatedDate, Field, OldValue, NewValue, CreatedBy.Name
      FROM LoyaltyProgramMemberHistory
      WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId
    ]) {
      MemberChangeHistoryDTO dto = buildHistoryDto(h.CreatedDate, '회원 정보', h.Field, h.OldValue, h.NewValue, h.CreatedBy.Name);
      if (dto != null) {
        result.add(dto);
      }
    }

    LoyaltyProgramMember member = [
      SELECT ContactId
      FROM LoyaltyProgramMember
      WHERE Id = :loyaltyProgramMemberId
      LIMIT 1
    ];

    Id contactId = member.ContactId;

    if (contactId != null) {
      for (ContactHistory h : [
        SELECT CreatedDate, Field, OldValue, NewValue, CreatedBy.Name
        FROM ContactHistory
        WHERE ContactId = :contactId
      ]) {
        if (h.Field == 'created') {
          continue;
        }

        MemberChangeHistoryDTO dto = buildHistoryDto(h.CreatedDate, '회원 상세', h.Field, h.OldValue, h.NewValue, h.CreatedBy.Name);
        if (dto != null) {
          result.add(dto);
        }
      }
    }

    result.sort(new ChangeDateDescComparator());
    return result;
  }

  @TestVisible
  private static String formatValue(String fieldApiName, Object rawValue) {
    String value = rawValue == null ? '' : String.valueOf(rawValue);
    if (String.isBlank(value)) {
      return '';
    }

    Schema.DescribeFieldResult fieldDescribe = getFieldDescribe(fieldApiName);
    if (fieldDescribe != null && fieldDescribe.getType() == Schema.DisplayType.Date) {
      return formatDateValue(rawValue, value);
    }

    value = convertPicklistValueToLabel(fieldApiName, value);

    if (value.startsWith('del_')) {
      value = value.replace('_del_', '\n_del_');
    }

    return value;
  }

  @TestVisible
  private static String formatDateValue(Object rawValue, String fallbackValue) {
    if (rawValue instanceof Date) {
      return String.valueOf((Date) rawValue);
    }

    if (rawValue instanceof Datetime) {
      return String.valueOf(((Datetime) rawValue).dateGmt());
    }

    if (!String.isBlank(fallbackValue) && fallbackValue.length() >= 10) {
      String datePart = fallbackValue.substring(0, 10);
      try {
        Date.valueOf(datePart);
        return datePart;
      } catch (Exception e) {
        return fallbackValue;
      }
    }

    return fallbackValue;
  }

  @TestVisible
  private static String formatValue(String value) {
    return formatValue(null, value);
  }

  @TestVisible
  private static Boolean shouldIncludeHistory(String oldValue, String newValue) {
    if (String.isBlank(oldValue) && String.isBlank(newValue)) {
      return false;
    }

    return oldValue != newValue;
  }

  @TestVisible
  private static MemberChangeHistoryDTO buildHistoryDto(
    Datetime changeDate,
    String objectType,
    String fieldApiName,
    Object oldRawValue,
    Object newRawValue,
    String changedBy
  ) {
    String oldValue = formatValue(fieldApiName, oldRawValue);
    String newValue = formatValue(fieldApiName, newRawValue);
    if (!shouldIncludeHistory(oldValue, newValue)) {
      return null;
    }
    // Lookup 필드 변경은 ContactHistory가 Name/ID 두 row를 만들어내므로 ID 형태 row는 버림
    if (looksLikeSalesforceId(oldValue) || looksLikeSalesforceId(newValue)) {
      return null;
    }

    MemberChangeHistoryDTO dto = new MemberChangeHistoryDTO();
    dto.changeDate = changeDate;
    dto.objectType = objectType;
    dto.fieldName = convertFieldLabel(fieldApiName);
    dto.oldValue = oldValue;
    dto.newValue = newValue;
    dto.changedBy = changedBy;
    return dto;
  }

  @TestVisible
  private static Boolean looksLikeSalesforceId(String value) {
    if (String.isBlank(value)) {
      return false;
    }
    return SALESFORCE_ID_PATTERN.matcher(value).matches();
  }

  @TestVisible
  private static String convertFieldLabel(String fieldApiName) {
    if (String.isBlank(fieldApiName)) {
      return '해당 변경 라벨을 찾을 수 없음';
    }

    if (FIELD_LABEL_MAP.containsKey(fieldApiName)) {
      return FIELD_LABEL_MAP.get(fieldApiName);
    }

    Schema.DescribeFieldResult fieldDescribe = getFieldDescribe(fieldApiName);
    if (fieldDescribe != null) {
      return fieldDescribe.getLabel();
    }

    return '해당 변경 라벨을 찾을 수 없음';
  }

  @TestVisible
  private static String convertPicklistValueToLabel(String fieldApiName, String value) {
    if (String.isBlank(fieldApiName) || String.isBlank(value)) {
      return value;
    }

    Schema.DescribeFieldResult fieldDescribe = getFieldDescribe(fieldApiName);
    if (fieldDescribe == null) {
      return value;
    }

    Schema.DisplayType fieldType = fieldDescribe.getType();
    if (fieldType == Schema.DisplayType.Picklist) {
      return getPicklistEntryLabel(fieldDescribe, value);
    }

    if (fieldType == Schema.DisplayType.MultiPicklist) {
      List<String> labels = new List<String>();
      for (String itemValue : value.split(';')) {
        labels.add(getPicklistEntryLabel(fieldDescribe, itemValue));
      }
      return String.join(labels, ';');
    }

    return value;
  }

  private static String getPicklistEntryLabel(Schema.DescribeFieldResult fieldDescribe, String value) {
    if (fieldDescribe == null || String.isBlank(value)) {
      return value;
    }

    String trimmedValue = value.trim();
    for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
      if (entry.getValue() == trimmedValue) {
        return entry.getLabel();
      }
    }

    return trimmedValue;
  }

  private static Schema.DescribeFieldResult getFieldDescribe(String fieldApiName) {
    if (String.isBlank(fieldApiName)) {
      return null;
    }

    Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();
    if (contactFields.containsKey(fieldApiName)) {
      return contactFields.get(fieldApiName).getDescribe();
    }

    Map<String, Schema.SObjectField> lpmFields = Schema.SObjectType.LoyaltyProgramMember.fields.getMap();
    if (lpmFields.containsKey(fieldApiName)) {
      return lpmFields.get(fieldApiName).getDescribe();
    }

    return null;
  }

  public class ChangeDateDescComparator implements Comparator<MemberChangeHistoryDTO> {
    public Integer compare(MemberChangeHistoryDTO a, MemberChangeHistoryDTO b) {
      Long timeA = (a.changeDate == null) ? 0 : a.changeDate.getTime();
      Long timeB = (b.changeDate == null) ? 0 : b.changeDate.getTime();

      if (timeA == timeB) {
        return 0;
      }

      return (timeA < timeB) ? 1 : -1;
    }
  }

  public class MemberChangeHistoryDTO {
    @AuraEnabled
    public Datetime changeDate;
    @AuraEnabled
    public String objectType;
    @AuraEnabled
    public String fieldName;
    @AuraEnabled
    public String oldValue;
    @AuraEnabled
    public String newValue;
    @AuraEnabled
    public String changedBy;
  }
}