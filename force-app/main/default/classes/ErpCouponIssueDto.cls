public with sharing class ErpCouponIssueDto {
  public ErpCouponIssueDto() {
  }

  // 쿠폰 개별 지급 요청 DTO
  public class IssueRequest {
    public String no_man_coupon;
    public String no_mbr;
    public String id_insert;
  }

  public class IssueResponse {
    public Boolean success;
    public String message;
    public String errorMessage;
    public List<String> issuedCouponCodes;
  }
}