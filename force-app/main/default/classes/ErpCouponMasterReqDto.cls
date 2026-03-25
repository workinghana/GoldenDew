/**
 * ERP 쿠폰 마스터 등록/수정 요청 DTO
 */
public class ErpCouponMasterReqDto {
  // =========================
  // Constructors
  // =========================
  public ErpCouponMasterReqDto() {
  }

  public class IssueRequest {
    /** 회사코드 */
    public String cd_company;

    /** 쿠폰 마스터 번호
     *  - 등록 시: 빈값 허용
     *  - 수정 시: 필수 (정책 협의 필요)
     */
    public String no_man_coupon;

    /** 쿠폰명 (필수) */
    public String nm_coupon;

    /** 브랜드코드 */
    public String cd_brand;

    /** 쿠폰구분코드
     *  - 01: 교환권
     *  - 02: 리셋팅쿠폰
     *  - 03: 본사상품권
     *  (필수)
     */
    public String cd_type_coupon;

    /** 발급일자 (YYYYMMDD) (필수) */
    public String dt_issue;

    /** 쿠폰 시작 번호 (필수) */
    public String no_str_coupon;

    /** 쿠폰 종료 번호 (필수) */
    public String no_end_coupon;

    /** 유효기간 구분코드
     *  - 01: 기간형
     *  - 02: 개월형
     *  (필수)
     */
    public String cd_type_day_exp;

    /** 유효 시작일자 (YYYYMMDD) (필수) */
    public String dt_str_exp;

    /** 유효 종료일자 (YYYYMMDD) (필수) */
    public String dt_end_exp;

    /** 유효 개월수
     *  - 기간형(cd_type_day_exp = 01)일 경우 "0"
     *  - 개월형(cd_type_day_exp = 02)일 경우 필수 값
     */
    public String ds_mon_exp;

    /** 쿠폰 비고 */
    public String tx_coupon;

    /** 할인율
     *  - 퍼센트 단위
     *  - 할인율 쿠폰이 아닐 경우 0
     */
    public Integer rt_disc;

    /** 할인금액
     *  - 정액 할인 금액
     *  - 할인금액 쿠폰이 아닐 경우 0
     */
    public Integer am_disc;

    /** 담당부서 코드 (필수) */
    public String cd_dept;

    /** 담당자 ID 또는 명 (필수) */
    public String id_respon;

    /** 등록자 ID (필수) */
    public String id_insert;

    public IssueRequest() {
    }

    /**
     * VoucherDefinition → ERP 쿠폰 마스터 요청 DTO 변환 생성자
     */
    public IssueRequest(VoucherDefinition vd) {
      this.cd_company = vd.AccountId__r.CompanyCode__c; // 회사 코드
      this.no_man_coupon = vd.CouponManNo__c; // 쿠폰 관리 번호
      this.nm_coupon = vd.Name; // 쿠폰 명 (필수)
      this.cd_brand = (vd.brand__c == null) ? '' : vd.brand__c; // 브랜드 코드
      this.cd_type_coupon = vd.CouponTypeCode__c; // 쿠폰 구분 코드 (필수)
      this.dt_issue = vd.CreatedDate.format('yyyyMMdd', 'Asia/Seoul'); // 발급 일자 (필수)
      this.no_str_coupon = (vd.CodePrefix == null) ? '' : vd.CodePrefix; // 쿠폰 시작 번호 (필수)
      this.no_end_coupon = (vd.CodeSuffix == null) ? '' : vd.CodeSuffix; // 쿠폰 종료 번호 (필수)
      this.cd_type_day_exp = mapVoucherDefinitionExpirationTypeToCode(vd.ExpirationType); // 유효기간 구분코드 (01 : 기간 / 02: 개월) (필수)
      this.dt_str_exp = (vd.EffectiveDate == null) ? '' : String.valueOf(vd.EffectiveDate).replaceAll('-', ''); // 유효시작일자 (필수)
      this.dt_end_exp = (vd.ExpirationDate == null) ? '' : String.valueOf(vd.ExpirationDate).replaceAll('-', ''); // 유효종료일자 (필수)
      this.ds_mon_exp = (vd.ExpirationPeriod == null) ? '' : String.valueOf(vd.ExpirationPeriod); // 유효개월수 (필수)
      this.tx_coupon = (vd.Description == null) ? '' : vd.Description; // 쿠폰내역 비고
      this.rt_disc = (vd.DiscountPercent == null) ? 0 : vd.DiscountPercent; // 할인율 (필수)
      this.am_disc = (vd.FaceValue == null) ? 0 : (Integer) vd.FaceValue; // 할인금액 (필수)
      this.cd_dept = vd.ResponsibleDepartment__c; // 담당부서 (필수)
      this.id_respon = vd.ResponsiblePerson__c; // 담당자 (필수)
      this.id_insert = vd.InsertId__c; // 등록자 (필수)
    }
  }

  // 쿠폰 마스터 삭제 요청 클래스
  public class DeleteRequest {
    public String no_man_coupon; // 쿠폰 관리 번호
    public String id_delete; // 삭제자

    public DeleteRequest() {
    }

    public DeleteRequest(VoucherDefinition vd) {
      this.no_man_coupon = vd.CouponManNo__c;
      this.id_delete = UserInfo.getUserId();
    }
  }

  // 쿠폰 마스터 수정 요청 클래스
  public class UpdateRequest {
    public String cd_company;
    public String no_man_coupon;
    public String nm_coupon;
    public String cd_brand;
    public String cd_type_coupon;
    public String dt_issue;
    public String no_str_coupon;
    public String no_end_coupon;
    public String cd_type_day_exp;
    public String dt_str_exp;
    public String dt_end_exp;
    public String ds_mon_exp;
    public String tx_coupon;
    public Integer rt_disc;
    public Integer am_disc;
    public String cd_dept;
    public String id_respon;
    public String id_insert;

    public UpdateRequest() {
    }

    /**
     * VoucherDefinition → ERP 쿠폰 마스터 수정 요청 DTO 변환 생성자
     */
    public UpdateRequest(VoucherDefinition vd) {
      this.cd_company = vd.AccountId__r.CompanyCode__c; // 회사 코드
      this.no_man_coupon = vd.CouponManNo__c; // 쿠폰 관리 번호
      this.nm_coupon = vd.Name; // 쿠폰 명 (필수)
      this.cd_brand = (vd.brand__c == null) ? '' : vd.brand__c; // 브랜드 코드
      this.cd_type_coupon = vd.CouponTypeCode__c; // 쿠폰 구분 코드 (필수)
      this.dt_issue = vd.CreatedDate.format('yyyyMMdd', 'Asia/Seoul'); // 발급 일자 (필수)
      this.no_str_coupon = (vd.CodePrefix == null) ? '' : vd.CodePrefix; // 쿠폰 시작 번호 (필수)
      this.no_end_coupon = (vd.CodeSuffix == null) ? '' : vd.CodeSuffix; // 쿠폰 종료 번호 (필수)
      this.cd_type_day_exp = mapVoucherDefinitionExpirationTypeToCode(vd.ExpirationType); // 유효기간 구분코드 (01 : 기간 / 02: 개월) (필수)
      this.dt_str_exp = (vd.EffectiveDate == null) ? '' : String.valueOf(vd.EffectiveDate).replaceAll('-', ''); // 유효시작일자 (필수)
      this.dt_end_exp = (vd.ExpirationDate == null) ? '' : String.valueOf(vd.ExpirationDate).replaceAll('-', ''); // 유효종료일자 (필수)
      this.ds_mon_exp = (vd.ExpirationPeriod == null) ? '' : String.valueOf(vd.ExpirationPeriod); // 유효개월수 (필수)
      this.tx_coupon = (vd.Description == null) ? '' : vd.Description; // 쿠폰내역 비고
      this.rt_disc = (vd.DiscountPercent == null) ? 0 : vd.DiscountPercent; // 할인율 (필수)
      this.am_disc = (vd.FaceValue == null) ? 0 : (Integer) vd.FaceValue; // 할인금액 (필수)
      this.cd_dept = vd.ResponsibleDepartment__c; // 담당부서 (필수)
      this.id_respon = vd.ResponsiblePerson__c; // 담당자 (필수)
      this.id_insert = vd.InsertId__c; // 등록자 (필수)
    }
  }

  // =========================
  // Validation
  // =========================

  /**
   * 필수값 검증
   * - 등록/수정 공통 필수 필드 기준
   * - no_man_coupon은 정책 확정 전까지 필수 검증에서 제외
   */
  // public void validate() {
  //   // 문자열 필수
  //   validateRequired(cd_company, 'cd_company');
  //   validateRequired(nm_coupon, 'nm_coupon');
  //   validateRequired(cd_type_coupon, 'cd_type_coupon');
  //   validateRequired(dt_issue, 'dt_issue');
  //   validateRequired(no_str_coupon, 'no_str_coupon');
  //   validateRequired(no_end_coupon, 'no_end_coupon');
  //   validateRequired(cd_type_day_exp, 'cd_type_day_exp');
  //   validateRequired(dt_str_exp, 'dt_str_exp');
  //   validateRequired(dt_end_exp, 'dt_end_exp');
  //   validateRequired(ds_mon_exp, 'ds_mon_exp');
  //   validateRequired(cd_dept, 'cd_dept');
  //   validateRequired(id_respon, 'id_respon');
  //   validateRequired(id_insert, 'id_insert');

  //   // 숫자 필수
  //   if (rt_disc == null) {
  //     throw new IllegalArgumentException('rt_disc is required.');
  //   }
  //   if (am_disc == null) {
  //     throw new IllegalArgumentException('am_disc is required.');
  //   }
  // }

  // // =========================
  // // Internal helper
  // // =========================
  // private static void validateRequired(String val, String fieldName) {
  //   if (String.isBlank(val)) {
  //     throw new IllegalArgumentException(fieldName + ' is required.');
  //   }
  // }

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