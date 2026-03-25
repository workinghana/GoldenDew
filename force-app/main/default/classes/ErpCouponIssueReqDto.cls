/**
 * ERP 쿠폰 개별 지급 요청 DTO
 *
 * 요청 JSON:
 * {
 *   "no_man_coupon": "COP2025DC0002",
 *   "no_mbr": "259999800019",
 *   "id_insert": "쿠폰 지급 테스트"
 * }
 */
public class ErpCouponIssueReqDto {
  /** 쿠폰 마스터 번호 */
  public String no_man_coupon;

  /** 회원 번호 */
  public String no_mbr;

  /** 등록자 */
  public String id_insert;

  public ErpCouponIssueReqDto() {
  }

  public ErpCouponIssueReqDto(String noManCoupon, String noMbr, String idInsert) {
    this.no_man_coupon = noManCoupon;
    this.no_mbr = noMbr;
    this.id_insert = idInsert;
  }

  /** 필수값 검증 */
  public void validate() {
    validateRequired(no_man_coupon, 'no_man_coupon');
    validateRequired(no_mbr, 'no_mbr');
    validateRequired(id_insert, 'id_insert');
  }

  private static void validateRequired(String val, String fieldName) {
    if (String.isBlank(val)) {
      throw new IllegalArgumentException(fieldName + ' is required.');
    }
  }
}