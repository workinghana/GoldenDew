public interface GdContactService {
  /**
   * 회원 생성 - Contact insert
   */
  ApiResult createContact(Map<String, Object> reqData);

  /**
   * 회원 수정 - Contact update
   */
  ApiResult updateContact(Map<String, Object> reqData);

  /**
   * 회원 수정 - Contact undelete
   */
  ApiResult undeleteContact(Map<String, Object> reqData);
}