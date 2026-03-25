/**
 * 프로모션 상세 응답 DTO
 *
 * @author Changhwan Kim
 * @since 2026-01-15
 *
 * @see
 */
public class PromotionDetailResDTO {
  public PromotionDetailResDTO() {
  }

  public class PromotionMaster {
    // =========================
    // 프로모션 MASTER
    // =========================
    public String NO_PROM; // 프로모션번호
    public String NM_PROM; // 프로모션명
    public String YN_PROM_DC; // 할인율 적용 가능 여부
    // public String CD_BRAND; // 브랜드
    // public String CD_TYPE_PROM; // 프로모션구분
    // public String DT_START; // 시작일자 (yyyyMMdd)
    // public String DT_END; // 종료일자
    // public String DT_EVENT_START; // 게시 시작일자
    // public String DT_EVENT_END; // 게시 종료일자
    // public String CD_STAT; // 프로모션 상태

    // public String YN_USE_COUPON; // 쿠폰 사용 여부 (Y/N)
    // public String YN_USE_FIXED_COUPON; // 정액 쿠폰 사용 가능 여부
    // public String YN_USE_RATE_COUPON; // 정률 쿠폰 사용 가능 여부
    // public String YN_USE_SPECIFIC_COUPON; // 특정 쿠폰 사용 가능 여부
    // public String YN_USE_POINT; // 포인트 사용 가능 여부

    // =========================
    // 하위 시트 목록
    // =========================
    public List<PromotionStore> STORES;
    public List<PromotionItem> ITEMS;
    public List<PromotionCoupon> COUPONS;
    public List<PromotionPoint> POINTS;

    public PromotionMaster(Promotion p) {
      this.NO_PROM = p.PromotionNo__c;
      this.NM_PROM = p.Name;
      this.YN_PROM_DC = (p.IsDiscountRateApplicable__c) ? 'Y' : 'N';
      // this.CD_BRAND = p.BrandCode__c;
      // this.CD_TYPE_PROM = p.TypeCode__c;
      // this.DT_START = p.StartDateTime.format('yyyyMMdd');
      // this.DT_END = p.EndDateTime.format('yyyyMMdd');
      // this.DT_EVENT_START = String.valueOf(p.PublishStartDate__c).replaceAll('-', '');
      // this.DT_EVENT_END = String.valueOf(p.PublishEndDate__c).replaceAll('-', '');
      // this.CD_STAT = p.StatusCode__c;
      // this.YN_USE_COUPON = (p.IsCouponAllowed__c) ? 'Y' : 'N';
      // this.YN_USE_FIXED_COUPON = (p.IsFixedAmountCouponAllowed__c) ? 'Y' : 'N';
      // this.YN_USE_RATE_COUPON = (p.IsRateCouponAllowed__c) ? 'Y' : 'N';
      // this.YN_USE_SPECIFIC_COUPON = (p.IsSpecificCouponAllowed__c) ? 'Y' : 'N';
      // this.YN_USE_POINT = (p.IsPointUsageAllowed__c) ? 'Y' : 'N';

      this.STORES = new List<PromotionStore>();
      this.ITEMS = new List<PromotionItem>();
      this.COUPONS = new List<PromotionCoupon>();
      this.POINTS = new List<PromotionPoint>();
    }
  }

  public class PromotionStore {
    public String CD_STORE; // 매장 코드
    public String NM_STORE; // 매장 명
    // public String CD_BRAND; // 브랜드 코드 (삭제)
    // public String CD_GRP_STORE; // 매장 그룹 코드 (삭제)
    // public String CD_TYPE_STORE; // 매장 구분 코드 (삭제)
    public String NM_BRAND; // 브랜드명 (추가)
    public String NM_GRP_STORE; // 매장그룹명 (추가)
    public String NM_TYPE_STORE; // 매장구분명 (추가)

    public PromotionStore(PromotionAccount__c pa) {
      this.CD_STORE = pa.AccountId__r.StoreCode__c;
      this.NM_STORE = pa.AccountId__r.Name;
      // this.CD_BRAND = pa.AccountId__r.BrandCode__c;
      // this.CD_GRP_STORE = pa.AccountId__r.StoreGroupCode__c;
      // this.CD_TYPE_STORE = pa.AccountId__r.StoreType__c;
      this.NM_BRAND = pa.AccountId__r.BrandCode__c;
      this.NM_GRP_STORE = pa.AccountId__r.StoreGroupCode__c;
      this.NM_TYPE_STORE = pa.AccountId__r.StoreType__c;
    }
  }

  public class PromotionItem {
    public String CD_ITEM; // 품목 코드
    public String NM_ITEM; // 품목 명

    public String NM_CLAS_GROP_ITEM; // 품목군분류   
    public String NM_CLAS_ACCT_ITEM; // 품목계정분류
    public String NM_CLAS_LARG_ITEM; // 품목대분류   
    public String NM_CLAS_MEDI_ITEM; // 품목중분류   
    public String NM_CLAS_SMAL_ITEM; // 품목소분류   
    public Decimal AM_RETAIL_CURR; // 소비자가      

    public PromotionItem(PromotionProduct pp, ProductCategoryProduct pcp, PricebookEntry pe, Map<String, String> nameByFullCode) {
      this.CD_ITEM = pp.Product.ProductCode;
      this.NM_ITEM = pp.Product.Name;

      this.NM_CLAS_GROP_ITEM = (pp.Product.Family != null) ? pp.Product.Family : '';
      this.NM_CLAS_ACCT_ITEM = (pp.Product.ProductAccountCategoryCode__c != null) ? pp.Product.ProductAccountCategoryCode__c : '';

      this.NM_CLAS_LARG_ITEM = '';
      this.NM_CLAS_MEDI_ITEM = '';
      this.NM_CLAS_SMAL_ITEM = '';

      if (pcp == null || pcp.ProductCategory == null || nameByFullCode == null) {
        return;
      }

      String sys = pcp.ProductCategory.SystemCode__c;
      String lc = pcp.ProductCategory.LargeCategoryCode__c;
      String mc = pcp.ProductCategory.MediumCategoryCode__c;
      String sc = pcp.ProductCategory.SmallCategoryCode__c;

      String largeFull = buildCategoryCode(sys, lc, null, null);
      String mediumFull = buildCategoryCode(sys, lc, mc, null);
      String smallFull = buildCategoryCode(sys, lc, mc, sc);

      this.NM_CLAS_LARG_ITEM = nvl((largeFull == null) ? null : nameByFullCode.get(largeFull));
      this.NM_CLAS_MEDI_ITEM = nvl((mediumFull == null) ? null : nameByFullCode.get(mediumFull));
      this.NM_CLAS_SMAL_ITEM = nvl((smallFull == null) ? null : nameByFullCode.get(smallFull));

      this.AM_RETAIL_CURR = (pe != null) ? ((pe.UnitPrice != null) ? pe.UnitPrice : 0) : 0;
    }
  }

  public class PromotionCoupon {
    public String NM_MAN_COUPON; // 쿠폰 명
    // public String CD_TYPE_COUPON; // 쿠폰 구분 코드 (삭제)
    public String NM_TYPE_COUPON; // 쿠폰구분명 (추가)
    public String DT_STR_EXP; // 쿠폰유효시작일자 (추가)
    public String DT_END_EXP; // 쿠폰유효종료일자 (추가)
    public Integer RT_DISC; // 할인율
    public Decimal AM_DISC; // 할인 금액

    public PromotionCoupon(VoucherLimit__c vl) {
      this.NM_MAN_COUPON = vl.VoucherDefinitionId__r.Name;
      // this.CD_TYPE_COUPON = vl.VoucherDefinitionId__r.Type;
      this.RT_DISC = (vl.VoucherDefinitionId__r.DiscountPercent != null) ? vl.VoucherDefinitionId__r.DiscountPercent : 0;
      this.AM_DISC = (vl.VoucherDefinitionId__r.FaceValue != null) ? vl.VoucherDefinitionId__r.FaceValue : 0;
      this.NM_TYPE_COUPON = (mapVoucherTypeToCode(vl.VoucherDefinitionId__r.Type) != null)
        ? mapVoucherTypeToCode(vl.VoucherDefinitionId__r.Type)
        : '';
      this.DT_STR_EXP = (vl.VoucherDefinitionId__r.EffectiveDate != null)
        ? String.valueOf(vl.VoucherDefinitionId__r.EffectiveDate).replaceAll('-', '')
        : '';
      this.DT_END_EXP = (vl.VoucherDefinitionId__r.ExpirationDate != null)
        ? String.valueOf(vl.VoucherDefinitionId__r.ExpirationDate).replaceAll('-', '')
        : '';
    }
  }

  public class PromotionPoint {
    public String NM_PROM_POINT; // 프로모션 포인트 명
    public String NM_TYPE_PROM_POINT; // 프로모션 포인트 구분
    public String NM_TYPE_POINT; // 포인트 구분
    public Decimal PT_SAVE; // 적립 포인트 / 배율

    public PromotionPoint(PromotionPointLimit__c ppl) {
      this.NM_PROM_POINT = ppl.Name;
      this.NM_TYPE_PROM_POINT = ppl.Type__c;
      this.NM_TYPE_POINT = ppl.LoyaltyPgmCurrencySubtypeName__c;
      this.PT_SAVE = ppl.Value__c;
    }
  }

  private static String mapVoucherTypeToCode(String type) {
    if (String.isBlank(type)) {
      return null;
    }

    switch on type {
      when 'FixedValue' {
        // 정액
        return '정액';
      }
      when 'DiscountPercentage' {
        // 정률
        return '정률';
      }
      when 'ProductOrService' {
        // 기타(특정)
        return '기타(특정)';
      }
      when else {
        return null;
      } // 정의되지 않은 값
    }
  }

  private static String buildCategoryCode(String sys, String lc, String mc, String sc) {
    if (String.isBlank(sys) || String.isBlank(lc)) {
      return null;
    }

    List<String> parts = new List<String>();
    parts.add(sys);
    parts.add(lc);
    if (!String.isBlank(mc)) {
      parts.add(mc);
    }
    if (!String.isBlank(sc)) {
      parts.add(sc);
    }

    return String.join(parts, '-');
  }

  private static String nvl(String s) {
    return (s == null) ? '' : s;
  }
}