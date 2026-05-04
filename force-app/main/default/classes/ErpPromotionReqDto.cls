/**
 * ERP 프로모션 요청 DTO
 *
 * @author Changhwan Kim
 * @since 2026-01-27
 */
public class ErpPromotionReqDto {
  public ErpPromotionReqDto() {
  }

  // 프로모션 마스터 등록 요청 클래스
  public class CreateRequest {
    public String no_prom; // 프로모션 번호
    public String nm_prom; // 프로모션 이름
    public String cd_brand; // 브랜드 코드
    public String nm_brand; // 브랜드 명
    public String cd_type_prom; // 프로모션 구분
    public String nm_type_prom; // 프로모션 구분명
    public String dt_start; // 프로모션 시작일자(YYYYMMDD)
    public String dt_end; // 프로모션 종료일자(YYYYMMDD)
    public String dt_event_start; // 이벤트 시작일자(YYYYMMDD)
    public String dt_event_end; // 이벤트 종료일자(YYYYMMDD)
    public String cd_stat; // 상태 (01: 등록 / 02: 진행 / 03: 종료)
    public String nm_stat; // 상태명
    public String yn_use_coupon; // 쿠폰 사용 여부
    public String yn_use_fixed_coupon; // 정액 쿠폰 사용 여부
    public String yn_use_rate_coupon; // 정률 쿠폰 사용 여부
    public String yn_use_specific_coupon; // 특정 쿠폰 사용 여부
    public String yn_use_point; // 포인트 사용 여부
    public String yn_all_store; // 전체 매장 여부
    public String yn_all_item; // 전체 품목 여부
    public String yn_all_coupon; // 전체 쿠폰 여부
    // 26.04.22 하나 수정: 특정 매장/품목 여부 (ERP 요청)
    public String yn_spec_store; // 특정 매장 여부 (전체매장 아니고 매장 선택 시 'Y')
    public String yn_spec_item; // 특정 품목 여부 (전체품목 아니고 품목 선택 시 'Y')
    // 26.04.23 하나 수정: 포인트 유형별 적립 여부 (ERP 요청)
    public String yn_pur_point; // 구매포인트 적립 여부 (PointTypeCode__c에 '01' 포함 시 'N')
    public String yn_gift_point; // 사은포인트 적립 여부 (PointTypeCode__c에 '06' 포함 시 'N')
    public String yn_event_point; // 이벤트포인트 적립 여부 (PointTypeCode__c에 '07' 포함 시 'N')
    public String cd_dept; // 담당부서코드
    public String id_insert; // 등록자
    public String id_update; // 수정자
    public String id_respon; // 담당자

    public CreateRequest() {
    }

    public CreateRequest(Promotion p) {
      this.no_prom = p.PromotionNo__c;
      this.nm_prom = p.Name;
      this.cd_brand = p.BrandCode__c;
      this.cd_type_prom = p.TypeCode__c;
      this.dt_start = ErpPromotionReqDto.dateToYmd(p.StartDate);
      this.dt_end = ErpPromotionReqDto.dateToYmd(p.EndDate);
      this.dt_event_start = ErpPromotionReqDto.dateToYmd(p.PublishStartDate__c);
      this.dt_event_end = ErpPromotionReqDto.dateToYmd(p.PublishEndDate__c);
      this.cd_stat = p.StatusCode__c;
      this.yn_use_coupon = ErpPromotionReqDto.boolToYn(p.IsCouponAllowed__c);
      this.yn_use_fixed_coupon = ErpPromotionReqDto.boolToYn(p.IsFixedAmountCouponAllowed__c);
      this.yn_use_rate_coupon = ErpPromotionReqDto.boolToYn(p.IsRateCouponAllowed__c);
      this.yn_use_specific_coupon = ErpPromotionReqDto.boolToYn(p.IsSpecificCouponAllowed__c);
      this.yn_use_point = ErpPromotionReqDto.boolToYn(p.IsPointUsageAllowed__c);
      this.yn_all_store = ErpPromotionReqDto.boolToYn(p.IsAllStore__c);
      this.yn_all_item = ErpPromotionReqDto.boolToYn(p.IsAllItem__c);
      this.yn_all_coupon = ErpPromotionReqDto.isAllCoupon(this.yn_use_coupon, this.yn_use_fixed_coupon, this.yn_use_rate_coupon);
      // 26.04.23 하나 수정: 포인트 유형별 적립 여부 세팅 (PointTypeCode__c = 적립 불가 유형 멀티픽리스트)
      this.yn_pur_point = ErpPromotionReqDto.isPointTypeAllowed(p.PointTypeCode__c, '01');
      this.yn_gift_point = ErpPromotionReqDto.isPointTypeAllowed(p.PointTypeCode__c, '06');
      this.yn_event_point = ErpPromotionReqDto.isPointTypeAllowed(p.PointTypeCode__c, '07');
      this.cd_dept = p.DepartmentCode__c;
      this.id_insert = p.InsertId__c;
      this.id_update = p.LastModifiedBy.Name;
      this.id_respon = p.ResponId__c;
    }

    public CreateRequest(Promotion p, Boolean hasSpecificStore, Boolean hasSpecificItem) {
      this(p);
      this.yn_spec_store = ErpPromotionReqDto.resolveYnSpec(p.IsAllStore__c, hasSpecificStore);
      this.yn_spec_item = ErpPromotionReqDto.resolveYnSpec(p.IsAllItem__c, hasSpecificItem);
    }
  }

  // 프로모션 마스터 삭제 요청 클래스
  public class DeleteRequest {
    public String no_prom; // 프로모션 번호
    public String id_delete; // 삭제자

    public DeleteRequest(Promotion p) {
      this.no_prom = p.PromotionCode;
      this.id_delete = UserInfo.getUserId();
    }
  }

  // 프로모션 마스터 수정 요청 클래스
  public class UpdateRequest {
    public String no_prom; // 프로모션 번호
    public String nm_prom; // 프로모션 이름
    public String cd_brand; // 브랜드 코드
    public String nm_brand; // 브랜드 명
    public String cd_type_prom; // 프로모션 구분
    public String nm_type_prom; // 프로모션 구분명
    public String dt_start; // 프로모션 시작일자(YYYYMMDD)
    public String dt_end; // 프로모션 종료일자(YYYYMMDD)
    public String dt_event_start; // 이벤트 시작일자(YYYYMMDD)
    public String dt_event_end; // 이벤트 종료일자(YYYYMMDD)
    public String cd_stat; // 상태 (01: 등록 / 02: 진행 / 03: 종료)
    public String nm_stat; // 상태명
    public String yn_use_coupon; // 쿠폰 사용 여부
    public String yn_use_fixed_coupon; // 정액 쿠폰 사용 여부
    public String yn_use_rate_coupon; // 정률 쿠폰 사용 여부
    public String yn_use_specific_coupon; // 특정 쿠폰 사용 여부
    public String yn_use_point; // 포인트 사용 여부
    public String yn_all_store; // 전체 매장 여부
    public String yn_all_item; // 전체 품목 여부
    public String yn_all_coupon; // 전체 쿠폰 여부
    // 26.04.22 하나 수정: 특정 매장/품목 여부 (ERP 요청)
    public String yn_spec_store; // 특정 매장 여부 (전체매장 아니고 매장 선택 시 'Y')
    public String yn_spec_item; // 특정 품목 여부 (전체품목 아니고 품목 선택 시 'Y')
    // 26.04.23 하나 수정: 포인트 유형별 적립 여부 (ERP 요청)
    public String yn_pur_point; // 구매포인트 적립 여부 (PointTypeCode__c에 '01' 포함 시 'N')
    public String yn_gift_point; // 사은포인트 적립 여부 (PointTypeCode__c에 '06' 포함 시 'N')
    public String yn_event_point; // 이벤트포인트 적립 여부 (PointTypeCode__c에 '07' 포함 시 'N')
    public String id_insert; // 등록자
    public String id_update; // 수정자

    public UpdateRequest() {
    }

    public UpdateRequest(Promotion p) {
      this.no_prom = p.PromotionNo__c;
      this.nm_prom = p.Name;
      this.cd_brand = p.BrandCode__c;
      this.cd_type_prom = p.TypeCode__c;
      this.dt_start = ErpPromotionReqDto.dateToYmd(p.StartDate);
      this.dt_end = ErpPromotionReqDto.dateToYmd(p.EndDate);
      this.dt_event_start = ErpPromotionReqDto.dateToYmd(p.PublishStartDate__c);
      this.dt_event_end = ErpPromotionReqDto.dateToYmd(p.PublishEndDate__c);
      this.cd_stat = p.StatusCode__c;
      this.yn_use_coupon = ErpPromotionReqDto.boolToYn(p.IsCouponAllowed__c);
      this.yn_use_fixed_coupon = ErpPromotionReqDto.boolToYn(p.IsFixedAmountCouponAllowed__c);
      this.yn_use_rate_coupon = ErpPromotionReqDto.boolToYn(p.IsRateCouponAllowed__c);
      this.yn_use_specific_coupon = ErpPromotionReqDto.boolToYn(p.IsSpecificCouponAllowed__c);
      this.yn_use_point = ErpPromotionReqDto.boolToYn(p.IsPointUsageAllowed__c);
      this.yn_all_store = ErpPromotionReqDto.boolToYn(p.IsAllStore__c);
      this.yn_all_item = ErpPromotionReqDto.boolToYn(p.IsAllItem__c);
      this.yn_all_coupon = ErpPromotionReqDto.isAllCoupon(this.yn_use_coupon, this.yn_use_fixed_coupon, this.yn_use_rate_coupon);
      // 26.04.23 하나 수정: 포인트 유형별 적립 여부 세팅 (PointTypeCode__c = 적립 불가 유형 멀티픽리스트)
      this.yn_pur_point = ErpPromotionReqDto.isPointTypeAllowed(p.PointTypeCode__c, '01');
      this.yn_gift_point = ErpPromotionReqDto.isPointTypeAllowed(p.PointTypeCode__c, '06');
      this.yn_event_point = ErpPromotionReqDto.isPointTypeAllowed(p.PointTypeCode__c, '07');
      this.id_insert = p.CreatedBy.Name;
      this.id_update = p.LastModifiedBy.Name;
    }

    public UpdateRequest(Promotion p, Boolean hasSpecificStore, Boolean hasSpecificItem) {
      this(p);
      this.yn_spec_store = ErpPromotionReqDto.resolveYnSpec(p.IsAllStore__c, hasSpecificStore);
      this.yn_spec_item = ErpPromotionReqDto.resolveYnSpec(p.IsAllItem__c, hasSpecificItem);
    }
  }

  // =========================
  // Helpers
  // =========================

  /** Date -> YYYYMMDD */
  public static String dateToYmd(Date d) {
    if (d == null) {
      return '';
    }
    // Date는 format() 지원 안 하므로 문자열 변환 후 '-' 제거
    return String.valueOf(d).replaceAll('-', '');
  }

  /** Datetime -> YYYYMMDD (Asia/Seoul) */
  public static String dtToYmd(Datetime dt) {
    if (dt == null) {
      return '';
    }
    return dt.format('yyyyMMdd', 'Asia/Seoul');
  }

  /** Boolean -> Y/N (null이면 'N' 기본) */
  public static String boolToYn(Boolean b) {
    return (b == true) ? 'Y' : 'N';
  }

  public static String isStrNull(String s) {
    return (String.isBlank(s)) ? '' : s;
  }

  public static String isAllCoupon(String yn_use_coupon, String yn_use_fixed_coupon, String yn_use_rate_coupon) {
    if (yn_use_coupon == 'Y' && yn_use_fixed_coupon == 'Y' && yn_use_rate_coupon == 'Y') {
      return 'Y';
    }
    return 'N';
  }

  public static String resolveYnSpec(Boolean isAll, Boolean hasSpecific) {
    if (isAll == true) {
      return 'N';
    }
    return (hasSpecific == true) ? 'Y' : 'N';
  }

  /**
   * 26.04.23 하나 수정
   * 포인트 유형별 적립 여부 판정
   * - PointTypeCode__c는 '적립 불가 포인트 유형' 멀티픽리스트(세미콜론 구분)
   * - targetCode 포함 → 'N' (적립 불가)
   * - 미포함 또는 빈값 → 'Y' (적립 가능)
   */
  public static String isPointTypeAllowed(String pointTypeCode, String targetCode) {
    if (String.isBlank(pointTypeCode)) {
      return 'Y';
    }
    for (String code : pointTypeCode.split(';')) {
      if (targetCode != null && targetCode.equalsIgnoreCase(code.trim())) {
        return 'N';
      }
    }
    return 'Y';
  }
}