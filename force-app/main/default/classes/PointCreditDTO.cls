/**
 * ERP 포인트 적립 DTO
 */
public with sharing class PointCreditDTO {
  public String CD_JOURNAL; // 로열티 생성 키값
  public String CD_TYPE_POINT; // 포인트 구분
  public String NO_MBR; // 회원번호
  public String NO_SAL; // 판매번호
  public Decimal AM_SAL; // 판매 금액
  public Decimal PT_TARGET; // 적립 포인트
  public String DT_SAVE_PLAN; // 해당 포인트 적립 예정일
  public String DT_LIMIT_START; // 포인트 유효기간 시작일
  public String DT_LIMIT_END; // 포인트 유효기간 종료일
  public String DT_DESTROY_PLAN; // 소멸 예정일
  public String DTS_INSERT; // 등록일자
  public String ID_INSERT; // 등록자
  public String CD_TYPE_SAVE; // 적립구분
  public String NO_PROM_MBR; // 프로모션 번호
  public String TX_REMARK; // 비고
  public String NO_GRADE_ADVAN; // 승급번호

  public PointCreditDTO() {
  }
}