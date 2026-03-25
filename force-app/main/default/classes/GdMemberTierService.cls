public interface GdMemberTierService {
  /**
   * 요청 일자를 기준으로 회원 등급 조회
   */
  String resolveAccrualGrade(Id lpmId, Date reqDate);
}