/**
 * ERP 쿠폰 개별(지급/수정) 요청 DTO
 */
public class ErpCouponReqDto {
  // DTO 자체에 "어떤 작업인지" 명시 (validate 분기용)
  public enum Op {
    ISSUE_OP, // 쿠폰 개별 지급
    UPDATE_OP // 쿠폰 개별 수정
  }

  public Op op;

  public class IssueRequest {
    public List<CouponDetailModel> couponDetailModels; // 쿠폰 개별 지급 목록

    public IssueRequest() {
      this.couponDetailModels = new List<CouponDetailModel>();
    }
  }

  public class CouponDetailModel {
    public String no_man_coupon; // 쿠폰 관리 번호
    public String no_man_coupon_mil; // 쿠폰 번호
    public String no_mbr; // 회원 번호
    public String id_insert; // 등록자

    public CouponDetailModel() {
    }

    public CouponDetailModel(String noManCoupon, String noManCouponMil, String noMbr, String idInsert) {
      this.no_man_coupon = noManCoupon;
      this.no_man_coupon_mil = noManCouponMil;
      this.no_mbr = noMbr;
      this.id_insert = idInsert;
    }
  }

  public class UpdateRequest {
    public List<CouponDetailUpdateModel> couponDetailUpdateModels; // 쿠폰 개별 수정 목록

    public UpdateRequest() {
      this.couponDetailUpdateModels = new List<CouponDetailUpdateModel>();
    }
  }

  public class CouponDetailUpdateModel {
    public String no_man_coupon; // 쿠폰 번호
    public String no_mbr; // 회원 번호
    public String no_coupon; // 쿠폰 번호
    public String id_update; // 수정자
    public String dt_end_exp_mbr; // 소멸일자
    public String cd_stat_coupon; // 쿠폰상태 (01 : 등록 / 02: 회원지급 / 03 : 회수 / 04 : 폐기 )

    public CouponDetailUpdateModel() {
    }

    public CouponDetailUpdateModel(Voucher v) {
      this.no_man_coupon = v.VoucherDefinition.CouponManNo__c;
      this.no_mbr = v.Contact.MemberNo__c;
      this.no_coupon = v.VoucherCode;
      this.id_update = UserInfo.getUserId();
      this.dt_end_exp_mbr = String.valueOf(v.ExpirationDate).replaceAll('-', '');
      this.cd_stat_coupon = (mapVoucherStatusToCode(v.Status) != null) ? mapVoucherStatusToCode(v.Status) : '';
    }
  }

  private static String mapVoucherStatusToCode(String status) {
    if (String.isBlank(status)) {
      return null;
    }

    switch on status {
      when 'Expired' {
        // 만료 = 회수
        return '03';
      }
      when else {
        return null;
      } // 정의되지 않은 값
    }
  }
}