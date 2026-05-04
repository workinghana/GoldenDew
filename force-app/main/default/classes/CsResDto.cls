public with sharing class CsResDto {
  public String sentDate; // 발송일자
  public String storeCode; // 매장코드
  public String storeName; // 매장명
  public String type; // CS 구분
  public String content; // CS 내역
  public String detailContent; // 세부내역

  public CsResDto() {
    this.storeCode = 'AD004'; // 매장코드 : 'AD004' (고정 값)
    this.storeName = 'IMC팀'; // 매장명 : 'IMC팀' (고정 값)
    this.content = '기타'; // CS내역 : '기타' (고정 값)
  }
}