@IsTest
private class GdContactUiControllerTest {
    private class McCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"result":"ok"}');
            return res;
        }
    }

    /* =====================================================
     * 정상 조회 (Controller 경로)
     * ===================================================== */
    @IsTest
    static void test_getMemberProfile_success() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        LoyaltyProgram program = new LoyaltyProgram(
            Name = 'VIP Program',
            Status = 'Active'
        );
        insert program;

        Contact c = new Contact(
            LastName = '홍길동',
            MemberNo__c = 'MEM-UI-001'
        );
        insert c;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ContactId = c.Id,
            ProgramId = program.Id,
            MemberStatus = 'Active',
            EnrollmentDate = Date.today(),
            MembershipNumber = 'LPM-001'
        );
        insert lpm;

        Test.startTest();
        GdContactUiController.MemberProfileDTO dto =
            GdContactUiController.getMemberProfile(lpm.Id);
        Test.stopTest();

        System.assertEquals('홍길동', dto.name);
        System.assertEquals('VIP Program', dto.programName);
    }

    /* =====================================================
     * DTO 분기 ① Contact = null
     * ===================================================== */
    @IsTest
    static void test_dto_contact_null() {

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            MemberStatus = 'Active',
            EnrollmentDate = Date.today()
        );

        Test.startTest();
        GdContactUiController.MemberProfileDTO dto =
            new GdContactUiController.MemberProfileDTO(lpm);
        Test.stopTest();

        System.assertEquals('Active', dto.memberStatus);
        System.assertEquals(null, dto.name);
    }

    /* =====================================================
     * DTO 분기 ② Program = null
     * ===================================================== */
    @IsTest
    static void test_dto_program_null() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        Contact c = new Contact(
            LastName = '테스터',
            MemberNo__c = 'MEM-UI-002'
        );
        insert c;

        // DTO 생성자가 접근하는 모든 Contact 필드를 쿼리 (LegalBirthdate__c 포함)
        c = [
            SELECT Id, Name, LastName, Phone, MobilePhone, Email, Birthdate,
                   LegalBirthdate__c, MemberNo__c, IsMarried__c, WeddingAnniversaryDate__c,
                   StoreMana__c, MailingStreet, MailingCity
            FROM Contact
            WHERE Id = :c.Id
        ];

        // ProgramId + MembershipNumber 필수 → insert 불가
        // → in-memory LPM에 Contact 관계를 수동 설정해 DTO 직접 테스트
        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ContactId      = c.Id,
            MemberStatus   = 'Inactive',
            EnrollmentDate = Date.today()
        );
        lpm.Contact = c; // Program은 null 유지 → dto.programName = null 분기 커버

        Test.startTest();
        GdContactUiController.MemberProfileDTO dto =
            new GdContactUiController.MemberProfileDTO(lpm);
        Test.stopTest();

        System.assertEquals('테스터', dto.name);
        System.assertEquals(null, dto.programName);
        System.assert(true);
    }
}