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
    public String NO_PROM;
    public String NM_PROM;
    public String YN_PROM_DC;
    public String YN_ALL_ITEM; //프로모션 품목 전체 설정 여부

    // ✅ [Solution-22] 게시 기간 기반 활성화 상태 필드 추가 (IsActive 필드 제거에 따른 대체)
    public Boolean YN_ACTIVE; // 활성화 여부 (PublishStartDate <= TODAY <= PublishEndDate)
    public String DT_PUBLISH_START; // 게시 시작일자 (yyyyMMdd)
    public String DT_PUBLISH_END; // 게시 종료일자 (yyyyMMdd)

    public List<PromotionStore> STORES;
    public List<PromotionItem> ITEMS;
    public List<PromotionCoupon> COUPONS;
    public List<PromotionPoint> POINTS;

    // 2026-04-14 (하나): 프로모션 전체 품목 설정 여부(YN_ALL_ITEM) 응답 추가
    public PromotionMaster(Promotion p) {
      this.NO_PROM = p.PromotionNo__c;
      this.NM_PROM = p.Name;
      this.YN_PROM_DC = (p.IsDiscountRateApplicable__c) ? 'Y' : 'N';
      this.YN_ALL_ITEM = (p.IsAllItem__c) ? 'Y' : 'N';

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

      this.STORES = new List<PromotionStore>();
      this.ITEMS = new List<PromotionItem>();
      this.COUPONS = new List<PromotionCoupon>();
      this.POINTS = new List<PromotionPoint>();
    }
  }

  public class PromotionStore {
    public String CD_STORE;
    public String NM_STORE;
    public String NM_BRAND;
    public String NM_GRP_STORE;
    public String NM_TYPE_STORE;

    public PromotionStore(PromotionAccount__c pa) {
      this.CD_STORE = pa.AccountId__r.StoreCode__c;
      this.NM_STORE = pa.AccountId__r.Name;
      this.NM_BRAND = pa.AccountId__r.BrandCode__c;
      this.NM_GRP_STORE = pa.AccountId__r.StoreGroupCode__c;
      this.NM_TYPE_STORE = pa.AccountId__r.StoreType__c;
    }
  }

  public class PromotionItem {
    public String CD_ITEM;
    public String NM_ITEM;
    public String TX_SIZE;
    public String NM_COLOR;
    public String NM_CLARITY;
    public String NM_CUT;
    public String NM_CLAS_GROP_ITEM;
    public String NM_CLAS_ACCT_ITEM;
    public String NM_CLAS_LARG_ITEM;
    public String NM_CLAS_MEDI_ITEM;
    public String NM_CLAS_SMAL_ITEM;
    public Decimal AM_RETAIL_CURR;

    public PromotionItem(PromotionProduct pp, ProductCategoryProduct pcp, PricebookEntry pe, Map<String, String> nameByFullCode) {
      this.CD_ITEM = pp.Product.ProductCode;
      this.NM_ITEM = pp.Product.Name;
      this.TX_SIZE = nvl(pp.Product.Size__c);
      this.NM_COLOR = nvl(pp.Product.Color2__c);
      this.NM_CLARITY = nvl(pp.Product.Clarity2__c);
      this.NM_CUT = nvl(pp.Product.Cut2__c);
      this.NM_CLAS_GROP_ITEM = (pp.Product.Family != null) ? pp.Product.Family : '';
      this.NM_CLAS_ACCT_ITEM = (pp.Product.ProductAccountCategoryCode__c != null) ? pp.Product.ProductAccountCategoryCode__c : '';
      this.NM_CLAS_LARG_ITEM = '';
      this.NM_CLAS_MEDI_ITEM = '';
      this.NM_CLAS_SMAL_ITEM = '';
      this.AM_RETAIL_CURR = (pe != null) ? ((pe.UnitPrice != null) ? pe.UnitPrice : 0) : 0;

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
    }
  }

  public class PromotionCoupon {
    public String NM_MAN_COUPON;
    public String NM_TYPE_COUPON;
    public String DT_STR_EXP;
    public String DT_END_EXP;
    public Integer RT_DISC;
    public Decimal AM_DISC;

    public PromotionCoupon(VoucherLimit__c vl) {
      this.NM_MAN_COUPON = vl.VoucherDefinitionId__r.Name;
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

    public PromotionCoupon(VoucherDefinition vd) {
      this.NM_MAN_COUPON = vd.Name;
      this.RT_DISC = (vd.DiscountPercent != null) ? vd.DiscountPercent : 0;
      this.AM_DISC = (vd.FaceValue != null) ? vd.FaceValue : 0;
      this.NM_TYPE_COUPON = (mapVoucherTypeToCode(vd.Type) != null) ? mapVoucherTypeToCode(vd.Type) : '';
      this.DT_STR_EXP = (vd.EffectiveDate != null) ? String.valueOf(vd.EffectiveDate).replaceAll('-', '') : '';
      this.DT_END_EXP = (vd.ExpirationDate != null) ? String.valueOf(vd.ExpirationDate).replaceAll('-', '') : '';
    }
  }

  public class PromotionPoint {
    public String NM_PROM_POINT;
    public String NM_TYPE_PROM_POINT;
    public String NM_TYPE_POINT;
    public Decimal PT_SAVE;

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
    if (type == 'FixedValue') {
      return '정액';
    } else if (type == 'DiscountPercentage') {
      return '정률';
    } else if (type == 'ProductOrService') {
      return '기타(특정)';
    } else {
      return null;
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