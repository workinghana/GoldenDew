/**
 * ERP 쿠폰 개별 수정 요청 DTO
 *
 * 요청 JSON:
 * {
 *   "no_man_coupon": "COP2025OC0011",
 *   "no_mbr": "213006800125",
 *   "no_coupon": "COP2025OC0011",
 *   "id_update": "쿠폰 지급 테스트",
 *   "dt_end_exp_mbr": "20250101"
 * }
 */
public class ErpCouponUpdateReqDto {
  /** 쿠폰 마스터 번호 */
  public String no_man_coupon;

  /** 회원 번호 */
  public String no_mbr;

  /** 쿠폰 번호 */
  public String no_coupon;

  /** 수정자 */
  public String id_update;

  /** 회원 기준 소멸일자 (YYYYMMDD) */
  public String dt_end_exp_mbr;

  public ErpCouponUpdateReqDto() {
  }

  public ErpCouponUpdateReqDto(String noManCoupon, String noMbr, String noCoupon, String idUpdate, String dtEndExpMbr) {
    this.no_man_coupon = noManCoupon;
    this.no_mbr = noMbr;
    this.no_coupon = noCoupon;
    this.id_update = idUpdate;
    this.dt_end_exp_mbr = dtEndExpMbr;
  }

  /** 필수값 검증 */
  public void validate() {
    validateRequired(no_man_coupon, 'no_man_coupon');
    validateRequired(no_mbr, 'no_mbr');
    validateRequired(no_coupon, 'no_coupon');
    validateRequired(id_update, 'id_update');
    validateRequired(dt_end_exp_mbr, 'dt_end_exp_mbr');
  }

  private static void validateRequired(String val, String fieldName) {
    if (String.isBlank(val)) {
      throw new IllegalArgumentException(fieldName + ' is required.');
    }
  }
}