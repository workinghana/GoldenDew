/**
 * ERP 프로모션 쿠폰 요청 DTO
 *
 * @author
 * @since 2026-02-04
 */
public class ErpPromotionCouponReqDto {
  public ErpPromotionCouponReqDto() {
  }

  // 프로모션 쿠폰 등록 요청 클래스
  public class CreateRequest {
    public String cd_company;
    public String no_prom;
    public String no_man_coupon;
    public String nm_man_coupon;
    public String cd_type_coupon;
    public String nm_type_coupon;
    public String dt_str_exp;
    public String dt_end_exp;
    public String rt_disc;
    public String am_disc;
    public String id_insert;

    public CreateRequest() {
    }

    // public CreateRequest(PromotionProduct pp) {
    //   this.no_prom = pp.Promotion.PromotionNo__c;
    //   this.cd_item = pp.Product.ProductCode;
    //   this.id_insert = UserInfo.getUserName();
    // }
  }

  // 프로모션 쿠폰 삭제 요청 클래스
  //public class DeleteRequest {
  // public String no_prom; // 프로모션 번호
  // public String cd_item; // 쿠폰 코드
  // public String id_delete; // 삭제자

  // public DeleteRequest() {
  // }
  // public DeleteRequest(PromotionProduct pp) {
  //   this.no_prom = pp.Promotion.PromotionNo__c;
  //   this.cd_item = pp.Product.ProductCode;
  //   this.id_delete = UserInfo.getUserName();
  // }
  //}

  // 프로모션 쿠폰 삭제 요청 클래스 2
  public class DeleteRequest {
    public String no_prom; // 프로모션 번호
    public String cd_coupon; // 쿠폰 코드
    public String id_delete; // 삭제자

    public DeleteRequest() {
    }
  }

  // 프로모션 쿠폰 수정 요청 클래스
  public class UpdateRequest {
    public String cd_company;
    public String no_prom;
    public String no_man_coupon;
    public String nm_man_coupon;
    public String cd_type_coupon;
    public String nm_type_coupon;
    public String dt_str_exp;
    public String dt_end_exp;
    public Decimal rt_disc;
    public Decimal am_disc;
    public String id_update;

    public UpdateRequest() {
    }
  }

  // =========================
  // Helpers
  // =========================

  /** Date -> YYYYMMDD */
  public static String dateToYmd(Date d) {
    if (d == null) {
      return '';
    }
    // Date는 format() 지원 안 하므로 문자열 변환 후 '-' 제거
    return String.valueOf(d).replaceAll('-', '');
  }

  /** Datetime -> YYYYMMDD (Asia/Seoul) */
  public static String dtToYmd(Datetime dt) {
    if (dt == null) {
      return '';
    }
    return dt.format('yyyyMMdd', 'Asia/Seoul');
  }

  /** Boolean -> Y/N (null이면 'N' 기본) */
  public static String boolToYn(Boolean b) {
    return (b == true) ? 'Y' : 'N';
  }

  public static String isStrNull(String s) {
    return (String.isBlank(s)) ? '' : s;
  }
}