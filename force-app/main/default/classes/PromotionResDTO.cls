public with sharing class PromotionResDTO {
  // =========================
  // 프로모션 MASTER
  // =========================
  public String NO_PROM; // 프로모션번호
  public String NM_PROM; // 프로모션명
  // public String CD_BRAND; // 브랜드 코드 (삭제)
  public String NM_BRAND; // 브랜드명 (추가)
  // public String CD_TYPE_PROM; // 프로모션구분 (삭제)
  public String NM_TYPE_PROM; // 프로모션구분명 (추가)
  public String DT_START; // 시작일자 (yyyyMMdd)
  public String DT_END; // 종료일자
  public String DT_EVENT_START; // 게시 시작일자
  public String DT_EVENT_END; // 게시 종료일자
  // public String CD_STAT; // 프로모션 상태 (삭제)
  public String NM_STAT; // 프로모션 상태명 (추가)
  public String YN_USE_COUPON; // 쿠폰 사용 여부 (Y/N)
  public String YN_USE_FIXED_COUPON; // 정액 쿠폰 사용 가능 여부
  public String YN_USE_RATE_COUPON; // 정률 쿠폰 사용 가능 여부
  public String YN_USE_SPECIFIC_COUPON; // 특정 쿠폰 사용 가능 여부
  public String YN_USE_POINT; // 포인트 사용 가능 여부
  public String YN_ALL_STORE; // 전체 매장 여부 (추가)
  public String YN_ALL_ITEM; // 전체 품목 여부 (추가)
  public String YN_ALL_COUPON; // 전체 쿠폰 여부 (추가)
  public String YN_PROM_DC; // 할인율 적용 가능 여부

  public PromotionResDTO(Promotion p) {
    this.NO_PROM = p.PromotionNo__c;
    this.NM_PROM = p.Name;
    // this.CD_BRAND = p.BrandCode__c;
    this.NM_BRAND = p.BrandCode__c;
    // this.CD_TYPE_PROM = p.TypeCode__c;
    this.NM_TYPE_PROM = p.TypeCode__c;
    this.DT_START = (p.StartDateTime != null) ? p.StartDateTime.format('yyyyMMdd') : '';
    this.DT_END = (p.EndDateTime != null) ? p.EndDateTime.format('yyyyMMdd') : '';
    this.DT_EVENT_START = (p.PublishStartDate__c != null) ? String.valueOf(p.PublishStartDate__c).replaceAll('-', '') : '';
    this.DT_EVENT_END = (p.PublishEndDate__c != null) ? String.valueOf(p.PublishEndDate__c).replaceAll('-', '') : '';
    // this.CD_STAT = p.StatusCode__c;
    this.NM_STAT = p.StatusCode__c;
    this.YN_USE_COUPON = (p.IsCouponAllowed__c) ? 'Y' : 'N';
    this.YN_USE_FIXED_COUPON = (p.IsFixedAmountCouponAllowed__c) ? 'Y' : 'N';
    this.YN_USE_RATE_COUPON = (p.IsRateCouponAllowed__c) ? 'Y' : 'N';
    this.YN_USE_SPECIFIC_COUPON = (p.IsSpecificCouponAllowed__c) ? 'Y' : 'N';
    this.YN_USE_POINT = (p.IsPointUsageAllowed__c) ? 'Y' : 'N';
    this.YN_ALL_STORE = (p.IsAllStore__c) ? 'Y' : 'N';
    this.YN_ALL_ITEM = (p.IsAllItem__c) ? 'Y' : 'N';
    this.YN_ALL_COUPON = (p.IsCouponAllowed__c) ? 'Y' : 'N';
    this.YN_PROM_DC = (p.IsDiscountRateApplicable__c) ? 'Y' : 'N';
  }
}