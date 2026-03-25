/**
 * ERP 포인트 소멸 요청 DTO
 */
public class ErpPointReqDto {
  // DTO 자체에 "어떤 작업인지" 명시 (validate 분기용)
  public enum Op {
    EXPIRY_OP // 포인트 소멸(만료)
  }

  public Op op;

  public class ExpiryRequest {
    public List<MbrPointUseModels> mbrPointUseModels; // 포인트 소멸 목록

    public ExpiryRequest() {
      this.mbrPointUseModels = new List<MbrPointUseModels>();
    }
  }

  public class MbrPointUseModels {
    public String cd_save_ledger; // 소멸 처리된 생성 포인트 key 값
    public String pt_destory; // 소멸 처리된 포인트 값
    public String cd_use_ledger; // 생성된 소멸 포인트 key 값
    public String id_insert; // 수정자

    public MbrPointUseModels() {
      this.cd_save_ledger = '';
      this.pt_destory = '';
      this.cd_use_ledger = '';
      this.id_insert = '';
    }
  }

  public class CreditRequest {
    public String cd_company; // 회사코드
    public String ym_create; // 생성년월(YYYYMM)
    public String cd_type_point; // 포인트 유형 (예: 구매포인트, 보상포인트 등)
    public String dt_create; // 생성일자 (YYYYMMDD)
    public String no_mbr; // 회원번호
    public String no_sal; // 매출번호
    public Decimal am_sal; // 매출금액
    public Decimal pt_target; // 대상 포인트 값 (예: 1000)
    public Decimal pt_use_sale; // 매출 사용 포인트
    public String dt_save_plan; // 적립 예정일
    public Decimal pt_save_plan; // 적립 예정 포인트
    public String dt_save; // 적립일
    public Decimal pt_save; // 적립 포인트
    public String dt_limit_start; // 유효 시작일
    public String dt_limit_end; // 유효 종료일
    public String dt_destroy_plan; // 소멸 예정일
    public String dt_destroy_del_sale; // 매출취소 소멸일
    public String id_insert; // 등록자 ID
    public String cd_type_save; // 적립 유형 (01:구매포인트 / 02:기념일포인트 / 03:승급포인트 / 04:기타포인트 / 05:에코포인트 / 06:사은포인트)
    public String tx_remark; // 비고
    public String cd_save_ledger; // 로열티 포인트 생성 키값
  }

  //   private static String mapVoucherStatusToCode(String status) {
  //     if (String.isBlank(status)) {
  //       return null;
  //     }

  //     switch on status {
  //       when 'Expired' {
  //         // 만료 = 회수
  //         return '03';
  //       }
  //       when else {
  //         return null;
  //       } // 정의되지 않은 값
  //     }
  //   }
}