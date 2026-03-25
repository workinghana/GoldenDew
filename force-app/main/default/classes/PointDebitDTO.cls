/**
 * ERP 포인트 사용/소멸 DTO
 */
public with sharing class PointDebitDTO {
  public String NO_DEPOSIT; // 입금 번호
  public String CD_LEDGER; // 로열티 소멸 키값
  public String CD_JOURNAL; // 로열티 생성 키값
  public String CD_TYPE_POINT; // 포인트 구분
  public String CD_RESON; // 회원포인트소진구분
  public String NO_MBR; // 회원번호
  public String NO_SAL; // 판매처리된 번호
  public Decimal AM_SAL; // 판매처리된 판매의 금액
  public Decimal PT_USE; // 사용처리된 금액
  public String DTS_INSERT; // 등록일자
  public String ID_INSERT; // 등록자
  public String NO_SAL_RTN; //  판매 반품번호

  public PointDebitDTO() {
  }
}