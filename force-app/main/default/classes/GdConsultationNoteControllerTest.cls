@IsTest
private class GdConsultationNoteControllerTest {

    /* =====================================================
     * Mock Service - Success
     * ===================================================== */
    private class MockConsultationNoteServiceSuccess
        implements GdConsultationNoteService {

        public ApiResult getConsultationNote(Map<String, Object> reqData) {
            Map<String, Object> data = new Map<String, Object>();
            data.put('list', new List<Object>{ 'TEST_NOTE' });
            return ApiResult.ok(200, '조회 성공', data);
        }
    }

    /* =====================================================
     * Mock Service - CustomException
     * ===================================================== */
    private class MockConsultationNoteServiceFail
        implements GdConsultationNoteService {

        public ApiResult getConsultationNote(Map<String, Object> reqData) {
            throw new CustomException(400, '강제 예외');
        }
    }

    /* =====================================================
     * 정상 흐름 테스트
     * ===================================================== */
    @IsTest
    static void test_getConsultationNotes_success() {

        GdConsultationNoteController.setGdConsultationNoteService(
            new MockConsultationNoteServiceSuccess()
        );

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/consultation-note';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "memberNo": "MEM001" }');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        GdConsultationNoteController.getConsultationNotes();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        System.assertNotEquals(null, res.responseBody);
    }

    /* =====================================================
     * CustomException 흐름 테스트
     * ===================================================== */
    @IsTest
    static void test_getConsultationNotes_customException() {

        GdConsultationNoteController.setGdConsultationNoteService(
            new MockConsultationNoteServiceFail()
        );

        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/gd/consultation-note';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{ "memberNo": "MEM001" }');

        RestResponse res = new RestResponse();
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        GdConsultationNoteController.getConsultationNotes();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }
}