/**
 * ! 운영 배포 X
 */
public with sharing class MemberContactInput {
  // ===== Fields =====
  // Contact 필드에 추가 할 속성 (선택)
  public Map<String, String> additionalContactFieldValues;
  // 중복 레코드 일 경우 생성 여부 (선택) | true : 생성 O | false : 생성 X
  public Boolean allowDuplicateRecords;
  // Contact 이메일 (선택)
  public String email;
  // Contact 이름 (선택)
  public String firstName;
  // Contact 성 (필수)
  public String lastName;

  // ===== Builder =====
  public class Builder {
    private MemberContactInput dto = new MemberContactInput();

    public Builder setAdditionalContactFieldValues(Map<String, String> values) {
      dto.additionalContactFieldValues = values;
      return this;
    }
    public Builder setAllowDuplicateRecords(Boolean value) {
      dto.allowDuplicateRecords = value;
      return this;
    }
    public Builder setEmail(String value) {
      dto.email = value;
      return this;
    }
    public Builder setFirstName(String value) {
      dto.firstName = value;
      return this;
    }
    public Builder setLastName(String value) {
      dto.lastName = value;
      return this;
    }

    public MemberContactInput build() {
      // 필수값 체크
      if (String.isBlank(dto.lastName)) {
        throw new CustomException(400, '필수값 누락 : lastName');
      }
      if (String.isBlank(dto.email)) {
        throw new CustomException(400, '필수값 누락 : email');
      }

      return dto;
    }
  }

  // ===== JSON helpers (optional) =====
  public static MemberContactInput fromJson(String jsonString) {
    return (MemberContactInput) JSON.deserialize(jsonString, MemberContactInput.class);
  }
  public String toJson() {
    return JSON.serialize(this);
  }

  // ===== Convert to ConnectApi.MemberContactInput =====
  public ConnectApi.MemberContactInput toConnectApi() {
    // validate again in case DTO created without Builder
    if (String.isBlank(this.lastName)) {
      throw new AuraHandledException('Required field missing: lastName');
    }

    ConnectApi.MemberContactInput outp = new ConnectApi.MemberContactInput();
    outp.additionalContactFieldValues = this.additionalContactFieldValues;
    outp.allowDuplicateRecords = this.allowDuplicateRecords;
    outp.email = this.email;
    outp.firstName = this.firstName;
    outp.lastName = this.lastName;
    return outp;
  }

  // 예시
  //   public static void exampleUsage() {
  //     MemberContactInput dto = new MemberContactInput.Builder()
  //       .setAdditionalContactFieldValues(
  //         new Map<String, String>{ 'Preferred_Language__c' => 'ko' }
  //       )
  //       .setAllowDuplicateRecords(false)
  //       .setEmail('user@example.com')
  //       .setFirstName('현수')
  //       .setLastName('김') // REQUIRED
  //       .build();

  //     ConnectApi.MemberContactInput payload = dto.toConnectApi();
  //     System.debug(JSON.serializePretty(payload));
  //   }
}