// ! 상담노트 연동 X = 사용 X
public interface GdConsultationNoteService {
  /*
    상담노트 조회
    */
  ApiResult getConsultationNote(Map<String, Object> reqData);
}