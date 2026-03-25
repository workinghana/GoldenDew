@IsTest
private class LoyaltyMemberServiceImplTest {

    /* =========================================================
     * Contact null 케이스
     * ========================================================= */
    @IsTest
    static void test_createIndividualMember_contactNull() {

        LoyaltyMemberServiceImpl service =
            new LoyaltyMemberServiceImpl();

        Test.startTest();
        ApiResult result =
            service.createIndividualMemberByContact(null);
        Test.stopTest();

        System.assertEquals(400, result.code);
        System.assertEquals('Contact is null', result.message);
    }

    /* =========================================================
     * Contact 정상 → ConnectApi 호출 구간 진입
     * (예외 발생해도 fail 응답이면 OK)
     * ========================================================= */
    @IsTest
    static void test_createIndividualMember_contactProvided() {

        // 테스트용 Contact
        Contact c = new Contact(
            LastName = 'TestUser',
            MemberNo__c = 'M-10001',
            Email = 'test@example.com'
        );
        insert c;

        LoyaltyMemberServiceImpl service =
            new LoyaltyMemberServiceImpl();

        Test.startTest();
        ApiResult result =
            service.createIndividualMemberByContact(c);
        Test.stopTest();

        /*
         * 테스트 환경에서는 ConnectApi 호출이 실패하는 것이 정상
         * → catch 블록으로 진입 → fail(500, 'error') 반환
         */
        System.assertEquals(
            500,
            result.code,
            '테스트 환경에서는 ConnectApi 예외로 500이 반환되어야 합니다.'
        );
    }
}