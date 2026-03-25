/**
 * ERP 쿠폰 개별 지급 요청 DTO
 *
 * 요청 JSON 예시:
 * {
 *   "no_man_coupon": "COP2025DC0011",
 *   "no_mbr": "263005000001",
 *   "id_insert": "쿠폰 지급 테스트"
 * }
 */
public class ErpIssueRequestDto {
  // /** 쿠폰 마스터 번호 */
  // public String no_man_coupon;

  // /** 회원 번호 */
  // public String no_mbr;

  // /** 등록자 / 요청자 */
  // public String id_insert;

  // public ErpIssueRequestDto() {
  // }

  // public ErpIssueRequestDto(String noManCoupon, String noMbr, String idInsert) {
  //   this.no_man_coupon = noManCoupon;
  //   this.no_mbr = noMbr;
  //   this.id_insert = idInsert;
  // }

  // /**
  //  * 필수값 검증
  //  * - ErpCouponApiClient.issue()에서 호출
  //  */
  // public void validate() {
  //   if (String.isBlank(no_man_coupon)) {
  //     throw new IllegalArgumentException('no_man_coupon is required.');
  //   }
  //   if (String.isBlank(no_mbr)) {
  //     throw new IllegalArgumentException('no_mbr is required.');
  //   }
  //   if (String.isBlank(id_insert)) {
  //     throw new IllegalArgumentException('id_insert is required.');
  //   }
  // }
}