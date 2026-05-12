@IsTest
private class IndividualMemberInputTest {
  /* =========================================================
   * 정상 케이스: Builder → build → toConnectApi
   * ========================================================= */
  @IsTest
  static void test_builder_and_toConnectApi_success() {
    // Contact 입력 (ConnectApi)
    ConnectApi.MemberContactInput contactInput = new ConnectApi.MemberContactInput();
    contactInput.firstName = 'Test';
    contactInput.lastName = 'User';
    contactInput.email = 'test@example.com';

    // additionalMemberFieldValues
    Map<String, String> additionalFields = new Map<String, String>{ 'Grade__c' => 'VIP', 'Channel__c' => 'ONLINE' };

    // Builder 사용
    IndividualMemberInput input = new IndividualMemberInput.Builder()
      .setAdditionalMemberFieldValues(additionalFields)
      .setAssociatedContactDetails(contactInput)
      .setEnrollmentDate(Datetime.now())
      .setMemberStatus('Active')
      .setMembershipNumber('MEM-001')
      .setCanReceivePromotions(true)
      .setCreateTransactionJournals(true)
      .build();

    // ConnectApi 변환
    ConnectApi.IndividualMemberInput apiInput = input.toConnectApi();

    // ===== Assertions =====
    System.assertNotEquals(null, apiInput);
    System.assertEquals('MEM-001', apiInput.membershipNumber);
    System.assertEquals('Active', apiInput.memberStatus);
    System.assertEquals(true, apiInput.canReceivePromotions);
    System.assertEquals(true, apiInput.createTransactionJournals);
    System.assertEquals('VIP', apiInput.additionalMemberFieldValues.get('Grade__c'));
    System.assertEquals('User', apiInput.associatedContactDetails.lastName);
  }

  @IsTest
  static void test_builder_optional_fields_are_mapped() {
    ConnectApi.MemberContactInput contactInput = new ConnectApi.MemberContactInput();
    contactInput.firstName = 'Optional';
    contactInput.lastName = 'Fields';
    contactInput.email = 'optional@example.com';

    Map<String, String> additionalFields = new Map<String, String>{ 'Grade__c' => 'GOLD' };

    Datetime enrollmentDate = Datetime.newInstance(2026, 1, 2, 3, 4, 5);
    Datetime membershipEndDate = enrollmentDate.addYears(1);

    IndividualMemberInput input = new IndividualMemberInput.Builder()
      .setAdditionalMemberFieldValues(additionalFields)
      .setAssociatedContactDetails(contactInput)
      .setCanReceivePartnerPromotions(true)
      .setCanReceivePromotions(false)
      .setCreateTransactionJournals(false)
      .setEnrollmentChannel(null)
      .setEnrollmentDate(enrollmentDate)
      .setMemberStatus('Active')
      .setMembershipEndDate(membershipEndDate)
      .setMembershipNumber('MEM-OPTIONAL')
      .setReferredBy('MEM-REF')
      .setRelatedCorporateMembershipNumber('CORP-001')
      .setTransactionJournalStatementFrequency(null)
      .setTransactionJournalStatementMethod(null)
      .build();

    ConnectApi.IndividualMemberInput apiInput = input.toConnectApi();

    System.assertEquals(true, apiInput.canReceivePartnerPromotions);
    System.assertEquals(false, apiInput.canReceivePromotions);
    System.assertEquals(false, apiInput.createTransactionJournals);
    System.assertEquals(enrollmentDate, apiInput.enrollmentDate);
    System.assertEquals(membershipEndDate, apiInput.membershipEndDate);
    System.assertEquals('MEM-OPTIONAL', apiInput.membershipNumber);
    System.assertEquals('MEM-REF', apiInput.referredBy);
    System.assertEquals('CORP-001', apiInput.relatedCorporateMembershipNumber);
    System.assertEquals('GOLD', apiInput.additionalMemberFieldValues.get('Grade__c'));
    System.assertEquals('Fields', apiInput.associatedContactDetails.lastName);
  }

  /* =========================================================
   * 예외 케이스: 필수값 누락 (Builder 단계)
   * ========================================================= */
  @IsTest
  static void test_builder_missing_required_fields() {
    Boolean thrown = false;

    try {
      new IndividualMemberInput.Builder()
        // 필수값 일부 누락
        .setEnrollmentDate(Datetime.now())
        .setMemberStatus('Active')
        .build();
    } catch (CustomException e) {
      thrown = true;
      System.assert(true);
    }

    System.assertEquals(true, thrown, '필수값 누락 시 예외가 발생해야 합니다.');
  }

  /* =========================================================
   * 예외 케이스: build는 통과, toConnectApi에서 누락 검증
   * ========================================================= */
  @IsTest
  static void test_toConnectApi_missing_required_fields() {
    IndividualMemberInput input = new IndividualMemberInput();
    input.memberStatus = 'Active'; // 일부만 세팅

    Boolean thrown = false;

    try {
      input.toConnectApi();
    } catch (CustomException e) {
      thrown = true;
      System.assert(true);
    }

    System.assertEquals(true, thrown);
  }

  @IsTest
  static void test_blank_required_text_fields_are_rejected() {
    ConnectApi.MemberContactInput contactInput = new ConnectApi.MemberContactInput();
    contactInput.lastName = 'Required';

    Boolean builderThrown = false;
    try {
      new IndividualMemberInput.Builder()
        .setAdditionalMemberFieldValues(new Map<String, String>())
        .setAssociatedContactDetails(contactInput)
        .setEnrollmentDate(Datetime.now())
        .setMemberStatus(' ')
        .setMembershipNumber('MEM-BLANK')
        .build();
    } catch (CustomException e) {
      builderThrown = true;
    }

    IndividualMemberInput input = new IndividualMemberInput();
    input.additionalMemberFieldValues = new Map<String, String>();
    input.associatedContactDetails = contactInput;
    input.enrollmentDate = Datetime.now();
    input.memberStatus = 'Active';
    input.membershipNumber = '';

    Boolean toConnectApiThrown = false;
    try {
      input.toConnectApi();
    } catch (CustomException e) {
      toConnectApiThrown = true;
    }

    System.assertEquals(true, builderThrown);
    System.assertEquals(true, toConnectApiThrown);
  }
}