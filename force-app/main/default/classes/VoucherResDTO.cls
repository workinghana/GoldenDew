public with sharing class VoucherResDTO {
  public String NM_COUPON; // 쿠폰명
  public Decimal AM_DISC; // 할인가격
  public String TX_COUPON; // 쿠폰내역
  public String DT_STR_EXP; // 시작일자
  public String DT_USE; // 사용일자
  public String DT_END_EXP; // 종료일자
  public String DT_ISSUE; // 발급일자
  public String CD_BRAND; // 브랜드
  public String NO_MAN_COUPON; // 쿠폰관리번호
  public String NO_COUPON; // 쿠폰번호
  public String CD_TYPE_COUPON; // 쿠폰구분
  public String CD_STAT_COUPON; // 쿠폰상태
  public String CD_TYPE_DAY_EXP; // 기간구분
  public Integer DS_MON_EXP; // 개월
  public Decimal RT_DISC; // 할인율
  public String NM_DEPT; // 담당부서
  public String NM_RESPON; // 담당자
  public String DTS_INSERT; // 등록일자
  public String ID_INSERT; // 등록자

  public VoucherResDTO(Voucher v) {
    this.NM_COUPON = (v.VoucherDefinition.Name == null) ? '' : v.VoucherDefinition.Name;
    this.AM_DISC = (v.FaceValue == null) ? 0 : v.FaceValue;
    this.TX_COUPON = (v.Reason == null) ? '' : v.Reason;
    this.DT_STR_EXP = (v.EffectiveDate == null) ? '' : String.valueOf(v.EffectiveDate).replaceAll('-', '');
    this.DT_USE = (v.UseDate == null) ? '' : String.valueOf(v.UseDate).replaceAll('-', '');
    this.DT_END_EXP = (v.ExpirationDate == null) ? '' : String.valueOf(v.ExpirationDate).replaceAll('-', '');
    this.DT_ISSUE = (v.CreatedDate == null) ? '' : v.CreatedDate.format('yyyyMMdd');
    this.CD_BRAND = (v.VoucherDefinition.brand__c == null) ? '' : v.VoucherDefinition.brand__c;
    this.NO_MAN_COUPON = (v.VoucherDefinition.CouponManNo__c == null) ? '' : v.VoucherDefinition.CouponManNo__c;
    this.NO_COUPON = (v.VoucherCode == null) ? '' : v.VoucherCode;
    this.CD_TYPE_COUPON = (v.VoucherDefinition.CouponTypeCode__c == null) ? '' : v.VoucherDefinition.CouponTypeCode__c;
    this.CD_STAT_COUPON = (v.Status == null) ? '' : mapVoucherStatusToCode(v.Status);
    this.CD_TYPE_DAY_EXP = (v.VoucherDefinition.ExpirationType == null)
      ? ''
      : mapVoucherDefinitionExpirationTypeToCode(v.VoucherDefinition.ExpirationType);
    this.DS_MON_EXP = (v.VoucherDefinition.ExpirationPeriod == null) ? 0 : v.VoucherDefinition.ExpirationPeriod;
    this.RT_DISC = (v.DiscountPercent == null) ? 0 : v.DiscountPercent;
    this.NM_DEPT = (v.VoucherDefinition.ResponsibleDepartment__c == null) ? '' : v.VoucherDefinition.ResponsibleDepartment__c;
    this.NM_RESPON = (v.CreatedBy.Name == null) ? '' : v.CreatedBy.Name;
    this.DTS_INSERT = (v.CreatedDate == null) ? '' : v.CreatedDate.format('yyyyMMddHHmmss');
    this.ID_INSERT = (v.VoucherDefinition.InsertId__c == null) ? '' : v.VoucherDefinition.InsertId__c;
  }

  @TestVisible
  private static String mapVoucherStatusToCode(String status) {
    if (String.isBlank(status)) {
      return null;
    }

    switch on status {
      when 'Redeemed' {
        // 등록(=지급)
        return '01';
      }
      when 'Issued' {
        // 회원지급
        return '02';
      }
      when 'Canceled' {
        // 회수(=취소)
        return '03';
      }
      when 'Expired' {
        // 폐기(=만료)
        return '04';
      }
      when else {
        return null;
      } // 정의되지 않은 값
    }
  }

  @TestVisible
  private static String mapVoucherDefinitionExpirationTypeToCode(String expirationType) {
    if (String.isBlank(expirationType)) {
      return null;
    }

    switch on expirationType {
      when 'Period' {
        // 기간
        return '01';
      }
      when 'FixedDate' {
        // 개월
        return '02';
      }
      when else {
        return null;
      } // 정의되지 않은 값
    }
  }
}