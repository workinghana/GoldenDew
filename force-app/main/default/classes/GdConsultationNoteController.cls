// ! 상담노트 연동 X = 사용 X
@RestResource(urlMapping='/gd/consultation-note')
global with sharing class GdConsultationNoteController {
  private static GdConsultationNoteService gdConsultationNoteservice;

  // 테스트 클래스 용도
  @TestVisible
  private static void setGdConsultationNoteService(GdConsultationNoteService service) {
    gdConsultationNoteservice = service;
  }

  private static GdConsultationNoteService getGdConsultationNoteService() {
    if (gdConsultationNoteservice == null) {
      gdConsultationNoteservice = new GdConsultationNoteServiceImpl();
    }
    return gdConsultationNoteservice;
  }

  @HttpPost
  global static void getConsultationNotes() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    res.addHeader('Content-Type', 'application/json');

    Savepoint sp = Database.setSavepoint();

    try {
      Map<String, Object> reqData = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

      ApiResult result = getGdConsultationNoteService().getConsultationNote(reqData);

      res.statusCode = 200;
      res.responseBody = Blob.valueOf(JSON.serialize(result));
    } catch (CustomException ce) {
      RestResponseUtil.handleCustomException(ce, sp, ce.code, ce.message);
    } catch (Exception e) {
      RestResponseUtil.handleException(e, sp, 500);
    }
  }
}