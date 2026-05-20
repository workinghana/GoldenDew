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
  public String YN_SPEC_STORE; // 특정 매장 여부
  public String YN_SPEC_ITEM; // 특정 품목 여부

  // ✅ [Solution-22] 게시 기간 기반 활성화 상태 필드 추가 (IsActive 필드 제거에 따른 대체)
  public Boolean YN_ACTIVE; // 활성화 여부 (PublishStartDate <= TODAY <= PublishEndDate)
  public String DT_PUBLISH_START; // 게시 시작일자 (Date 형식)
  public String DT_PUBLISH_END; // 게시 종료일자 (Date 형식)

  public PromotionResDTO(Promotion p) {
    this.NO_PROM = p.PromotionNo__c;
    this.NM_PROM = p.Name;
    // this.CD_BRAND = p.BrandCode__c;
    this.NM_BRAND = p.BrandCode__c;
    // this.CD_TYPE_PROM = p.TypeCode__c;
    this.NM_TYPE_PROM = p.TypeCode__c;
    this.DT_START = (p.StartDate != null) ? String.valueOf(p.StartDate).replaceAll('-', '') : '';
    this.DT_END = (p.EndDate != null) ? String.valueOf(p.EndDate).replaceAll('-', '') : '';
    // 기존 코드
    this.DT_EVENT_START = (p.PublishStartDate__c != null) ? String.valueOf(p.PublishStartDate__c).replaceAll('-', '') : '';
    // 신규 코드 [2026-04-27 Casron]
    // this.DT_EVENT_START = (p.StartDate != null) ? String.valueOf(p.StartDate).replaceAll('-', '') : '';
    // 기존 코드
    this.DT_EVENT_END = (p.PublishEndDate__c != null) ? String.valueOf(p.PublishEndDate__c).replaceAll('-', '') : '';
    // 신규 코드 [2026-04-27 Casron]
    // this.DT_EVENT_END = (p.EndDate != null) ? String.valueOf(p.EndDate).replaceAll('-', '') : '';
    // this.CD_STAT = p.StatusCode__c;
    this.NM_STAT = p.StatusCode__c;
    this.YN_USE_COUPON = (p.IsCouponAllowed__c == true ||
      p.IsFixedAmountCouponAllowed__c == true ||
      p.IsRateCouponAllowed__c == true ||
      p.IsSpecificCouponAllowed__c == true)
      ? 'Y'
      : 'N';
    Boolean isAllCoupon = p.IsCouponAllowed__c == true;
    this.YN_USE_FIXED_COUPON = (isAllCoupon || p.IsFixedAmountCouponAllowed__c == true) ? 'Y' : 'N';
    this.YN_USE_RATE_COUPON = (isAllCoupon || p.IsRateCouponAllowed__c == true) ? 'Y' : 'N';
    this.YN_USE_SPECIFIC_COUPON = (isAllCoupon || p.IsSpecificCouponAllowed__c == true) ? 'Y' : 'N';
    this.YN_USE_POINT = (p.IsPointUsageAllowed__c) ? 'Y' : 'N';
    this.YN_ALL_STORE = (p.IsAllStore__c) ? 'Y' : 'N';
    this.YN_ALL_ITEM = (p.IsAllItem__c) ? 'Y' : 'N';
    this.YN_ALL_COUPON = isAllCoupon ? 'Y' : 'N';
    this.YN_PROM_DC = (p.IsDiscountRateApplicable__c) ? 'Y' : 'N';
    this.YN_SPEC_STORE = (p.IsStoreSpecific__c) ? 'Y' : 'N';
    this.YN_SPEC_ITEM = (p.HasTargetProductCondition__c) ? 'Y' : 'N';

    // ✅ [Solution-22] 게시 기간 기반 활성화 상태 계산 (IsActive 필드 제거에 따른 대체)
    // 원래: IsActive = TRUE 필드 사용
    // 변경: PublishStartDate__c <= TODAY() <= PublishEndDate__c 범위 내만 활성
    Date today = Date.today();
    this.YN_ACTIVE = (p.IsActive == true &&
      p.PublishStartDate__c != null &&
      p.PublishEndDate__c != null)
      ? (p.PublishStartDate__c <= today && p.PublishEndDate__c >= today)
      : false;
    this.DT_PUBLISH_START = (p.PublishStartDate__c != null) ? String.valueOf(p.PublishStartDate__c).replaceAll('-', '') : '';
    this.DT_PUBLISH_END = (p.PublishEndDate__c != null) ? String.valueOf(p.PublishEndDate__c).replaceAll('-', '') : '';
  }
}