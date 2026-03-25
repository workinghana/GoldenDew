@IsTest
private class IndividualMemberInputTest {

    /* =========================================================
     * 정상 케이스: Builder → build → toConnectApi
     * ========================================================= */
    @IsTest
    static void test_builder_and_toConnectApi_success() {

        // Contact 입력 (ConnectApi)
        ConnectApi.MemberContactInput contactInput =
            new ConnectApi.MemberContactInput();
        contactInput.firstName = 'Test';
        contactInput.lastName  = 'User';
        contactInput.email     = 'test@example.com';

        // additionalMemberFieldValues
        Map<String, String> additionalFields = new Map<String, String>{
            'Grade__c' => 'VIP',
            'Channel__c' => 'ONLINE'
        };

        // Builder 사용
        IndividualMemberInput input =
            new IndividualMemberInput.Builder()
                .setAdditionalMemberFieldValues(additionalFields)
                .setAssociatedContactDetails(contactInput)
                .setEnrollmentDate(Datetime.now())
                .setMemberStatus('Active')
                .setMembershipNumber('MEM-001')
                .setCanReceivePromotions(true)
                .setCreateTransactionJournals(true)
                .build();

        // ConnectApi 변환
        ConnectApi.IndividualMemberInput apiInput =
            input.toConnectApi();

        // ===== Assertions =====
        System.assertNotEquals(null, apiInput);
        System.assertEquals('MEM-001', apiInput.membershipNumber);
        System.assertEquals('Active', apiInput.memberStatus);
        System.assertEquals(true, apiInput.canReceivePromotions);
        System.assertEquals(true, apiInput.createTransactionJournals);
        System.assertEquals(
            'VIP',
            apiInput.additionalMemberFieldValues.get('Grade__c')
        );
        System.assertEquals(
            'User',
            apiInput.associatedContactDetails.lastName
        );
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

        System.assertEquals(
            true,
            thrown,
            '필수값 누락 시 예외가 발생해야 합니다.'
        );
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
}