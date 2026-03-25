public with sharing class DepositResponseDTO {
  public String CD_TYPE_APPR; // 결제 구분
  public Decimal AM_DEPOSIT; // 금액
  public String NO_COUPON_ALL; // 쿠폰 코드
  public String NM_COUPON; // 쿠폰명
  public Date DT_EXP; // 만료 날짜
  public Integer RT_DISC; // 할인율
  public Decimal AM_DISC; // 할인 금액
  public String TX_REMARK; // 비고

  public DepositResponseDTO() {
  }
}