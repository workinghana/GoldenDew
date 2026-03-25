/**
 * ERP 프로모션 포인트 요청 DTO
 *
 * @author Hana Lee
 * @since 2026-02-05
 */
public class ErpPromotionPointReqDto {
    
    public ErpPromotionPointReqDto() {}
    
    /* =====================================================
     * 프로모션 포인트 등록 요청
     * ===================================================== */
    public class CreateRequest {
        public String cd_company;           // 회사 코드
        public String no_prom;              // 프로모션 번호
        public String no_prom_point;        // 프로모션 포인트 번호
        public String nm_prom_point;        // 프로모션 포인트 명
        public String cd_type_prom_point;   // 프로모션 포인트 유형 코드
        public String nm_type_prom_point;   // 프로모션 포인트 유형 명
        public String cd_type_point;        // 포인트 유형 코드
        public String nm_type_point;        // 포인트 유형 명
        public Integer pt_save;             // 적립 포인트
        public String id_insert;            // 등록자
        
        public CreateRequest() {}
        
        public CreateRequest(PromotionPointLimit__c ppl) {
            this.cd_company = '1000'; // 필요 시 Promotion에서 추출
            this.no_prom = ppl.PromotionId__r.PromotionNo__c;
            this.nm_prom_point = ppl.Name;
            this.pt_save = ppl.Value__c == null
                ? null
                : Integer.valueOf(ppl.Value__c);
            this.id_insert = UserInfo.getUserName();
        }
    }
    
    /* =====================================================
     * 프로모션 포인트 수정 요청
     * ===================================================== */
    public class UpdateRequest {
        public String cd_company;           // 회사 코드
        public String no_prom;              // 프로모션 번호
        public String no_prom_point;        // 프로모션 포인트 번호
        public String nm_prom_point;        // 프로모션 포인트 명
        public String cd_type_prom_point;   // 프로모션 포인트 유형 코드
        public String nm_type_prom_point;   // 프로모션 포인트 유형 명
        public String cd_type_point;        // 포인트 유형 코드
        public String nm_type_point;        // 포인트 유형 명
        public Integer pt_save;             // 적립 포인트
        public String id_update;            // 수정자
        
        public UpdateRequest() {}
    }
    
    /* =====================================================
     * 프로모션 포인트 삭제 요청 (필요 시)
     * ===================================================== */
    public class DeleteRequest {
        public String no_prom;        // 프로모션 번호
        public String no_prom_point;  // 프로모션 포인트 번호
        public String id_delete;      // 삭제자
        
        public DeleteRequest() {}

        public DeleteRequest(PromotionPointLimit__c ppl) {
            this.no_prom = ppl.PromotionId__r.PromotionNo__c;
            this.no_prom_point = ppl.Name;
            this.id_delete = UserInfo.getUserName();
        }
    }
}