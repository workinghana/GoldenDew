public with sharing class MceEventReqDto {
  public String ContactKey; // 최상위 ContactKey (보통 PK와 동일 권장)
  // private final String creditPointEventDefinitionKey = 'APIEvent-2ad7a45b-99fd-0100-89e1-d5aeacb120a9'; // 포인트 차감 Key 값
  // private final String debitPointEventDefinitionKey = 'APIEvent-70fdac47-dd41-5c1b-91a6-900768d2670d';  // 포인트 적립 Key 값
  private String EventDefinitionKey; // 이벤트 Key 값
  public Map<String, Object> Data; // 이벤트별 payload

  public MceEventReqDto() {
    Data = new Map<String, Object>();
  }

  public MceEventReqDto(Map<String, Object> data) {
    this.Data = data;
  }

  public MceEventReqDto setContactKey(String v) {
    this.ContactKey = v;
    return this;
  }

  public MceEventReqDto setEventDefinitionKey(String v) {
    this.EventDefinitionKey = v;
    return this;
  }

  // public MceEventReqDto put(String key, Object value) {
  //   if (this.Data == null) {
  //     this.Data = new Map<String, Object>();
  //   }
  //   this.Data.put(key, value);
  //   return this;
  // }

  public void validate() {
    if (String.isBlank(ContactKey)) {
      throw new MceApiClient.MceApiException('ContactKey is required.');
    }
    if (String.isBlank(EventDefinitionKey)) {
      throw new MceApiClient.MceApiException('EventDefinitionKey is required.');
    }
    if (Data == null || Data.isEmpty()) {
      throw new MceApiClient.MceApiException('Data is required.');
    }
  }

  public Map<String, Object> toMap() {
    validate();
    return new Map<String, Object>{ 'ContactKey' => ContactKey, 'EventDefinitionKey' => EventDefinitionKey, 'Data' => Data };
  }

  // -----------------------------
  // 편의: PK 자동 생성 (중복 방지)
  // -----------------------------
  public static String buildPk(String memberNo) {
    // yyyyMMddHHmmssSSS + 랜덤4자리 = 테스트/대량 전송에도 중복 거의 없음
    String ts = Datetime.now().format('yyyyMMddHHmmss');
    // String rnd = String.valueOf(Math.mod(Crypto.getRandomInteger(), 10000)).leftPad(4, '0');
    return memberNo + ts;
    // return memberNo + ts + rnd;
  }

  // -----------------------------
  // 편의: 공통 필드 세팅 템플릿
  // (필요 없는 필드는 안 넣어도 됨)
  // -----------------------------
  // public MceEventReqDto applyCommonMemberKeys(String memberNo, String pk) {
  // Data 내부 공통 키들
  // put('ContactKey', memberNo);
  // put('SubscriberKey', memberNo);
  // put('PK', pk);
  // return this;
  // }

  // 포인트 적립
  public class CreditPoint {
    public String accountNumber; // ? 지급된 포인트 금액인가?
    public String patronName; // ? 회원 이름인가?
  }

  // 포인트 차감
  public class DebitPoint {
    private Map<String, Object> payload;

    // 기본 생성자(빈 템플릿)
    public DebitPoint() {
      payload = new Map<String, Object>();
    }

    // 값 주입 생성자(요청하신 방식)
    // public DebitPoint(LoyaltyLedger ll) {
    // payload = new Map<String, Object>();

    // payload.put('ContactKey', ll.LoyaltyProgramMember.Contact.MemberNo__c); // [필수]TEXT(50), 회원번호
    // payload.put('PK', pk); // [필수]TEXT(500), 회원번호 + 데이터 전송일자(시분초)
    // payload.put('SubscriberKey', subscriberKey); // TEXT(254), 회원번호
    // payload.put('Phone', phone); // Phone, 휴대폰 번호
    // payload.put('EmailAddress', emailAddress); // EmailAddress, 이메일 주소
    // payload.put('LastName', lastName); // TEXT(500), 이름

    // payload.put('AvailablePoints', availablePoints); // Number, 잔여 포인트
    // payload.put('UsedPoints', usedPoints); // Number, 사용 포인트

    // payload.put('Grade__c', grade); // TEXT(500), 회원등급
    // payload.put('StoreCode__c', storeCode); // TEXT(500), 구매 매장 코드

    // payload.put('Purchase_Store', purchaseStore); // TEXT(500), 구매 매장명
    // payload.put('PurchaseDate', purchaseDate == null ? null : String.valueOf(purchaseDate)); // Date, 구매일자(KST 기준으로 전송) (예시: 2023-01-01T12:00:00Z)
    // }

    // 최종 반환
    public Map<String, Object> toMap() {
      return payload;
    }

    // (선택) JSON으로도 바로 뽑고 싶으면
    public String toJson() {
      return JSON.serialize(payload);
    }
  }
}