public with sharing class MemberHistoryUIController {
  // FieldName 맵핑
  private static final Map<String, String> FIELD_LABEL_MAP = new Map<String, String>{
    'created' => '회원 생성',
    'FirstPurchaseDate__c' => '첫 주문 일자',
    'LastPurchaseDate__c' => '마지막 주문 일자'
  };

  @AuraEnabled(cacheable=true)
  public static List<MemberChangeHistoryDTO> getMemberHistory(Id loyaltyProgramMemberId) {
    List<MemberChangeHistoryDTO> result = new List<MemberChangeHistoryDTO>();

    // 1. LoyaltyProgramMemberHistory
    for (LoyaltyProgramMemberHistory h : [
      SELECT CreatedDate, Field, OldValue, NewValue, CreatedBy.Name
      FROM LoyaltyProgramMemberHistory
      WHERE LoyaltyProgramMemberId = :loyaltyProgramMemberId
    ]) {
      MemberChangeHistoryDTO dto = new MemberChangeHistoryDTO();
      dto.changeDate = h.CreatedDate;
      dto.objectType = '회원 정보';
      dto.fieldName = convertFieldLabel(h.Field);
      dto.oldValue = formatValue(String.valueOf(h.OldValue));
      dto.newValue = formatValue(String.valueOf(h.NewValue));
      dto.changedBy = h.CreatedBy.Name;

      result.add(dto);
    }

    // 2. ContactHistory
    Id contactId = [
      SELECT ContactId
      FROM LoyaltyProgramMember
      WHERE Id = :loyaltyProgramMemberId
      LIMIT 1
    ]
    .ContactId;

    if (contactId != null) {
      for (ContactHistory h : [
        SELECT CreatedDate, Field, OldValue, NewValue, CreatedBy.Name
        FROM ContactHistory
        WHERE ContactId = :contactId
      ]) {
        if (h.Field == 'created') {
          continue;
        }
        MemberChangeHistoryDTO dto = new MemberChangeHistoryDTO();
        dto.changeDate = h.CreatedDate;
        dto.objectType = '회원 상세';
        dto.fieldName = convertFieldLabel(h.Field);
        dto.oldValue = formatValue(String.valueOf(h.OldValue));
        dto.newValue = formatValue(String.valueOf(h.NewValue));
        dto.changedBy = h.CreatedBy.Name;

        result.add(dto);
      }
    }

    // 3. 날짜 기준 정렬
    result.sort(new ChangeDateDescComparator());

    return result;
  }

  /*
     값 포맷 처리
     - 이메일 prefix 누적 시 줄바꿈 처리
    */
  @TestVisible
  private static String formatValue(String value) {
    if (String.isBlank(value)) {
      return '';
    }

    // 이메일 prefix 줄바꿈 처리
    if (value.startsWith('del_')) {
      value = value.replace('_del_', '\n_del_');
    }

    return value;
  }

  @TestVisible
  private static String convertFieldLabel(String fieldApiName) {
    if (String.isBlank(fieldApiName)) {
      return '해당 변경 레이블을 찾을 수 없음';
    }

    // 1️⃣ 커스텀 매핑
    if (FIELD_LABEL_MAP.containsKey(fieldApiName)) {
      return FIELD_LABEL_MAP.get(fieldApiName);
    }

    // 2️⃣ Contact 필드 Label
    Map<String, Schema.SObjectField> contactFields = Schema.SObjectType.Contact.fields.getMap();

    if (contactFields.containsKey(fieldApiName)) {
      return contactFields.get(fieldApiName).getDescribe().getLabel();
    }

    // 3️⃣ LoyaltyProgramMember 필드 Label
    Map<String, Schema.SObjectField> lpmFields = Schema.SObjectType.LoyaltyProgramMember.fields.getMap();

    if (lpmFields.containsKey(fieldApiName)) {
      return lpmFields.get(fieldApiName).getDescribe().getLabel();
    }

    // 4️⃣ 찾을 수 없는 경우
    return '해당 변경 레이블을 찾을 수 없음';
  }

  /*
     Comparator : 변경일 내림차순
    */
  public class ChangeDateDescComparator implements Comparator<MemberChangeHistoryDTO> {
    public Integer compare(MemberChangeHistoryDTO a, MemberChangeHistoryDTO b) {
      Long timeA = (a.changeDate == null) ? 0 : a.changeDate.getTime();
      Long timeB = (b.changeDate == null) ? 0 : b.changeDate.getTime();

      if (timeA == timeB)
        return 0;

      return (timeA < timeB) ? 1 : -1;
    }
  }

  // DTO
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