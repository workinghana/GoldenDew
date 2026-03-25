/**
 * 쿠폰 관련 인터페이스
 *
 * @author Changhwan Kim
 * @since 2026-01-06
 */
public interface GdVoucherService {
  /**
   * 생일 쿠폰 지급
   */
  void issueBirthdayCoupon();

  /**
   * 가입 쿠폰 지급
   */
  ApiResult issueSignupCoupon(Map<String, Object> reqData);

  /**
   * 가입 쿠폰 지급 V2
   */
  ApiResult issueSignupCouponV2(Map<String, Object> reqData);

  /**
   * 사용 가능한 쿠폰 조회
   */
  ApiResult getAvailableCouponList(Map<String, Object> reqData);

  /**
   * 사용 가능한 쿠폰 조회 V2
   */
  ApiResult getAvailableCouponListV2(VoucherReqDto.AvailableVoucherRequest req);

  /**
   * 쿠폰 사용 처리
   */
  ApiResult redeemVoucher(Map<String, Object> reqData);

  /**
   * 쿠폰 사용 처리 v2
   */
  ApiResult redeemVoucherV2(TransactionJournal tj);

  /**
   * 쿠폰 사용 취소
   */
  ApiResult redeemCancelVoucher(TransactionJournal tj);

  /**
   * 쿠폰 개별 지급
   */
  ApiResult issueCoupon(Map<String, Object> reqData);

  /**
   * 쿠폰 개별 수정
   */
  ApiResult updateCoupon(Map<String, Object> reqData);

  /**
   * 쿠폰 개별 삭제
   */
  ApiResult deleteCoupon(Map<String, Object> reqData);

  /**
   * [판매반품, 교환반품] 사용한 쿠폰 조회
   */
  ApiResult getReturnUsedCoupon(String originalOrderId);

  /**
   * 사용한 쿠폰 조회
   */
  ApiResult getRedeemCoupon(Map<String, Object> reqData);
}