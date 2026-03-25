/**
 * ! 운영 배포 X
 */
public with sharing class IndividualMemberInput {
  public IndividualMemberInput() {
  }

  // ===== Fields =====
  // 추가 멤버 필드 값 (필수)
  public Map<String, String> additionalMemberFieldValues;
  // Contact (필수)
  public ConnectApi.MemberContactInput associatedContactDetails;
  // 파트너 프로모션 적용 가능 여부
  public Boolean canReceivePartnerPromotions;
  // 프로모션 적용 가능 여부
  public Boolean canReceivePromotions;
  // 트랜잭션 저널 생성 여부 (다음 경우를 위해 생성함 => 회원 가입 시 포인트 지급, 회원 가입 시 추천인 회원에게 포인트 지급)
  public Boolean createTransactionJournals;
  // 등록 채널
  public ConnectApi.EnrollmentChannelResource enrollmentChannel;
  // 등록일 (필수)
  public Datetime enrollmentDate;
  // 회원 상태 (필수)
  public String memberStatus;
  // 멤버십 종료일
  public Datetime membershipEndDate;
  // 멤버십 번호 (필수)
  public String membershipNumber;
  // 추천인 멤버십 번호
  public String referredBy;
  // 외부 기업 회원 자격
  public String relatedCorporateMembershipNumber;
  // 거래 분개장 명세서를 회원에게 전달해야 하는 빈도
  public ConnectApi.StatementFrequencyResource transactionJournalStatementFrequency;
  // 회원에게 거래 일지 명세서를 전달하는 데 사용되는 방법
  public ConnectApi.StatementMethodResource transactionJournalStatementMethod;

  // ===== Builder =====
  public class Builder {
    private IndividualMemberInput dto = new IndividualMemberInput();

    // 필수
    public Builder setAdditionalMemberFieldValues(Map<String, String> values) {
      dto.additionalMemberFieldValues = values;
      return this;
    }

    // 필수
    public Builder setAssociatedContactDetails(ConnectApi.MemberContactInput value) {
      dto.associatedContactDetails = value;
      return this;
    }

    public Builder setCanReceivePartnerPromotions(Boolean value) {
      dto.canReceivePartnerPromotions = value;
      return this;
    }

    public Builder setCanReceivePromotions(Boolean value) {
      dto.canReceivePromotions = value;
      return this;
    }

    public Builder setCreateTransactionJournals(Boolean value) {
      dto.createTransactionJournals = value;
      return this;
    }

    public Builder setEnrollmentChannel(ConnectApi.EnrollmentChannelResource value) {
      dto.enrollmentChannel = value;
      return this;
    }

    // 필수
    public Builder setEnrollmentDate(Datetime value) {
      dto.enrollmentDate = value;
      return this;
    }

    // 필수
    public Builder setMemberStatus(String value) {
      dto.memberStatus = value;
      return this;
    }

    public Builder setMembershipEndDate(Datetime value) {
      dto.membershipEndDate = value;
      return this;
    }

    // 필수
    public Builder setMembershipNumber(String value) {
      dto.membershipNumber = value;
      return this;
    }

    public Builder setReferredBy(String value) {
      dto.referredBy = value;
      return this;
    }

    public Builder setRelatedCorporateMembershipNumber(String value) {
      dto.relatedCorporateMembershipNumber = value;
      return this;
    }

    public Builder setTransactionJournalStatementFrequency(ConnectApi.StatementFrequencyResource value) {
      dto.transactionJournalStatementFrequency = value;
      return this;
    }

    public Builder setTransactionJournalStatementMethod(ConnectApi.StatementMethodResource value) {
      dto.transactionJournalStatementMethod = value;
      return this;
    }

    // ===== build() with validation =====
    public IndividualMemberInput build() {
      // 필수값 검증
      List<String> missing = new List<String>();
      if (dto.additionalMemberFieldValues == null)
        missing.add('additionalMemberFieldValues');
      if (dto.associatedContactDetails == null)
        missing.add('associatedContactDetails');
      if (dto.enrollmentDate == null)
        missing.add('enrollmentDate');
      if (String.isBlank(dto.memberStatus))
        missing.add('memberStatus');
      if (String.isBlank(dto.membershipNumber))
        missing.add('membershipNumber');

      if (!missing.isEmpty()) {
        throw new CustomException(400, '필수값 누락 : ' + String.join(missing, ', '));
      }

      return dto;
    }
  }

  // ===== Convert to ConnectApi.IndividualMemberInput =====
  // ===== Convert to ConnectApi.IndividualMemberInput =====
  public ConnectApi.IndividualMemberInput toConnectApi() {
    // (선택) 안정성을 위해 필수값 재검증
    List<String> missing = new List<String>();
    if (this.additionalMemberFieldValues == null)
      missing.add('additionalMemberFieldValues');
    if (this.associatedContactDetails == null)
      missing.add('associatedContactDetails');
    if (this.enrollmentDate == null)
      missing.add('enrollmentDate');
    if (String.isBlank(this.memberStatus))
      missing.add('memberStatus');
    if (String.isBlank(this.membershipNumber))
      missing.add('membershipNumber');
    if (!missing.isEmpty()) {
      throw new CustomException(400, '필수값 누락 : ' + String.join(missing, ', '));
    }

    // DTO → ConnectApi 객체 매핑
    ConnectApi.IndividualMemberInput outp = new ConnectApi.IndividualMemberInput();
    outp.additionalMemberFieldValues = this.additionalMemberFieldValues;
    outp.associatedContactDetails = this.associatedContactDetails; // already ConnectApi.MemberContactInput
    outp.canReceivePartnerPromotions = this.canReceivePartnerPromotions;
    outp.canReceivePromotions = this.canReceivePromotions;
    outp.createTransactionJournals = this.createTransactionJournals;
    outp.enrollmentChannel = this.enrollmentChannel;
    outp.enrollmentDate = this.enrollmentDate;
    outp.memberStatus = this.memberStatus;
    outp.membershipEndDate = this.membershipEndDate;
    outp.membershipNumber = this.membershipNumber;
    outp.referredBy = this.referredBy;
    outp.relatedCorporateMembershipNumber = this.relatedCorporateMembershipNumber;
    outp.transactionJournalStatementFrequency = this.transactionJournalStatementFrequency;
    outp.transactionJournalStatementMethod = this.transactionJournalStatementMethod;
    return outp;
  }
}