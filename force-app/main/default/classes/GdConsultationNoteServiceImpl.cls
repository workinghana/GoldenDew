// ! 상담노트 연동 X = 사용 X
public with sharing class GdConsultationNoteServiceImpl implements GdConsultationNoteService {
  public ApiResult getConsultationNote(Map<String, Object> reqData) {
    // 요청 body 검증
    if (reqData == null || reqData.isEmpty()) {
      throw new CustomException(400, 'Request body is empty.');
    }

    // 회원번호 추출
    String memberNo = ValidationUtil.stringValidationEx(reqData.get('MemberNo__c'), 'MemberNo__c', true, false);

    //회원 조회(요청 데이터)
    List<Contact> lpmList = [
      SELECT Id, MemberNo__c
      FROM Contact
      WHERE MemberNo__c = :memberNo
      LIMIT 1
    ];

    if (lpmList.isEmpty()) {
      throw new CustomException(400, '존재하지 않는 회원입니다. memberNo=' + memberNo);
    }

    Contact lpm = lpmList[0];
    Map<String, Object> data = new Map<String, Object>();

    //상담노트 조회
    List<Case> clist = [
      SELECT
        Id,
        ContactEmail, //회원 이메일
        CaseNumber, //사례 번호
        Type, //상담 유형 : 질문 or 답변
        Status, //접수 상태
        Subject, //접수 내용
        Description,
        Origin, //접수 경로
        Priority, //상담 중요도
        CreatedDate //상담 내용
      FROM Case
      WHERE ContactId = :lpm.Id
      ORDER BY CreatedDate DESC
    ];

    if (clist.isEmpty()) {
      throw new CustomException(400, '해당 회원의 상담 노트가 존재하지 않습니다.');
    }

    List<Map<String, Object>> notelist = new List<Map<String, Object>>();

    for (Case cs : clist) {
      Map<String, Object> note = new Map<String, Object>();
      // 식별 정보
      note.put('caseId', cs.Id);
      note.put('caseNumber', cs.CaseNumber);

      // 상담 기본 정보
      note.put('type', cs.Type);
      note.put('status', cs.Status);
      note.put('priority', cs.Priority);
      note.put('origin', cs.Origin);

      // 상담 내용
      note.put('subject', cs.Subject);
      note.put('description', cs.Description);

      // 회원 / 작성자 정보
      note.put('contactEmail', cs.ContactEmail);

      // 날짜
      note.put('createdDate', cs.CreatedDate);

      noteList.add(note);
    }
    data.put('consultationNotes', noteList);
    return ApiResult.ok(200, '상담노트 조회 성공', data);
  }
}