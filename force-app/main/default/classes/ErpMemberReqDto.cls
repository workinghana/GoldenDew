/**
 * ERP 멤버 관련 요청 DTO
 */
public class ErpMemberReqDto {
  // DTO 자체에 "어떤 작업인지" 명시 (validate 분기용)
  //   public enum Op {
  //     ISSUE_OP, // 쿠폰 개별 지급
  //     UPDATE_OP // 쿠폰 개별 수정
  //   }

  //   public Op op;

  /**
   * 회원 등급 변경 (벌크)
   */
  public class UpdateGradeRequest {
    public List<UpdateGradeMemebrModel> memebrModelList; // 멤버 등급 수정 목록

    public String ID_UPDATE;

    public UpdateGradeRequest() {
      this.memebrModelList = new List<UpdateGradeMemebrModel>();
    }
  }

  /**
   * 회원 등급 변경 (벌크) 내의 개별 모델
   */
  public class UpdateGradeMemebrModel {
    public String NO_MBR; // 회원 번호 (필수)
    public String CD_GRADE_MBR; // 등급 코드

    public UpdateGradeMemebrModel() {
    }

    public UpdateGradeMemebrModel(String noMbr, String cdGradeMbr) {
      this.NO_MBR = noMbr;
      this.CD_GRADE_MBR = cdGradeMbr;
    }
  }

  /**
   * 회원 매거진 구독 정보 변경 (벌크)
   */
  public class UpdateMagazineSubscriptionRequest {
    public List<UpdateMagazineSubscriptionMemebrModel> memebrModelList; // 멤버 등급 수정 목록

    public String ID_UPDATE;

    public UpdateMagazineSubscriptionRequest() {
      this.memebrModelList = new List<UpdateMagazineSubscriptionMemebrModel>();
    }
  }

  /**
   * 회원 매거진 구독 정보 변경 (벌크) 내의 개별 모델
   */
  public class UpdateMagazineSubscriptionMemebrModel {
    public String NO_MBR; // 회원 번호 (필수)
    public String YM_RECEIVE_MAGAZINE; // 매거진 구독 여부
    public String DT_RECEIVE_MAGAZINE; // 매거진 구독 일자
    public String CD_TYPE_MAGAZINE_SEASON; // 매거진 구독 시즌

    public UpdateMagazineSubscriptionMemebrModel() {
    }

    public UpdateMagazineSubscriptionMemebrModel(String noMbr, String ymReceiveMagazine, String dtReceiveMagazine, String cdTypeMagazineSeason) {
      this.NO_MBR = noMbr;
      this.YM_RECEIVE_MAGAZINE = ymReceiveMagazine;
      this.DT_RECEIVE_MAGAZINE = dtReceiveMagazine;
      this.CD_TYPE_MAGAZINE_SEASON = mapMagazineSeasonToCode(cdTypeMagazineSeason);
    }
  }

  public class UpdateMemberSmsReceiveRequest {
    public String P_NO_MBR; // 회원 번호 (필수)
    public String P_NM_MBR_KOR; // 성함 (필수)
    public String P_CD_STORE_REGI; // 등록 매장 (필수)
    public String P_NO_CELLPHONE1; // 휴대폰 (필수)
    public String P_YN_RECEIVE_SMS; // SMS 수신여부 (Y/N)
    public String P_ID_INSERT; // 등록자 (필수)
  }

  private static String mapMagazineSeasonToCode(String cdTypeMagazineSeason) {
    if (String.isBlank(cdTypeMagazineSeason)) {
      return null;
    }

    switch on cdTypeMagazineSeason {
      when '봄' {
        return '01';
      }
      when '여름' {
        return '02';
      }
      when '가을' {
        return '03';
      }
      when '겨울' {
        return '04';
      }
      when else {
        return null;
      } // 정의되지 않은 값
    }
  }
}