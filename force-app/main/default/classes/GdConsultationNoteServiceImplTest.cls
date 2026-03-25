@IsTest
private class GdConsultationNoteServiceImplTest {

    /* =====================================================
     * 공통 데이터 생성
     * ===================================================== */
    private static Contact createContact(String memberNo) {
        Contact c = new Contact(
            LastName = '테스트회원',
            MemberNo__c = memberNo,
            Email = 'test@test.com'
        );
        insert c;
        return c;
    }

    private static Case createCase(Contact c) {
        Case cs = new Case(
            ContactId = c.Id,
            Status = 'New',
            Priority = 'Medium',
            Origin = 'Phone',
            Subject = '테스트 상담',
            Description = '상담 내용'
        );
        insert cs;
        return cs;
    }

    /* =====================================================
     * 1️⃣ 요청 body null
     * ===================================================== */
    @IsTest
    static void test_nullRequest() {

        GdConsultationNoteServiceImpl service =
            new GdConsultationNoteServiceImpl();

        Test.startTest();
        try {
            service.getConsultationNote(null);
            System.assert(false, '예외가 발생해야 함');
        } catch (CustomException ce) {
            System.assertEquals(400, ce.code);
        }
        Test.stopTest();
    }

    /* =====================================================
     * 2️⃣ 회원 없음
     * ===================================================== */
    @IsTest
    static void test_memberNotFound() {

        GdConsultationNoteServiceImpl service =
            new GdConsultationNoteServiceImpl();

        Map<String, Object> req = new Map<String, Object>{
            'MemberNo__c' => 'NOT_EXIST'
        };

        Test.startTest();
        try {
            service.getConsultationNote(req);
            System.assert(false, '예외가 발생해야 함');
        } catch (CustomException ce) {
            System.assertEquals(400, ce.code);
        }
        Test.stopTest();
    }

    /* =====================================================
     * 3️⃣ 회원은 있으나 상담노트 없음
     * ===================================================== */
    @IsTest
    static void test_noConsultationNote() {

        Contact c = createContact('MEM001');

        GdConsultationNoteServiceImpl service =
            new GdConsultationNoteServiceImpl();

        Map<String, Object> req = new Map<String, Object>{
            'MemberNo__c' => 'MEM001'
        };

        Test.startTest();
        try {
            service.getConsultationNote(req);
            System.assert(false, '예외가 발생해야 함');
        } catch (CustomException ce) {
            System.assertEquals(400, ce.code);
        }
        Test.stopTest();
    }

    /* =====================================================
     * 4️⃣ 정상 조회
     * ===================================================== */
    @IsTest
    static void test_success() {

        Contact c = createContact('MEM002');
        createCase(c);

        GdConsultationNoteServiceImpl service =
            new GdConsultationNoteServiceImpl();

        Map<String, Object> req = new Map<String, Object>{
            'MemberNo__c' => 'MEM002'
        };

        Test.startTest();
        ApiResult result = service.getConsultationNote(req);
        Test.stopTest();

        System.assertEquals(200, result.code);

        Map<String, Object> data =
            (Map<String, Object>) result.data;

        List<Object> notes =
            (List<Object>) data.get('consultationNotes');

        System.assertEquals(1, notes.size());
    }
}