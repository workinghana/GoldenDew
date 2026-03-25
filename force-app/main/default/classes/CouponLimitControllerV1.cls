public with sharing class CouponLimitControllerV1 {
    
    @AuraEnabled(cacheable=true)
    public static CouponLimitDTO getCouponLimit(Id voucherLimitId) {
        if (voucherLimitId == null) {
            return null;
        }
        CouponLimitDTO dto = new CouponLimitDTO();
        /* ================= VoucherLimit ================= */
        List<VoucherLimit__c> limits = [
            SELECT Type__c, Id, IsActive__c
            FROM VoucherLimit__c
            WHERE Id = :voucherLimitId
            AND IsActive__c = true
            LIMIT 1
        ];
        
        if (limits.isEmpty()) {
            dto.type = 'NONE';
            return dto;
        }
        
        dto.type = limits[0].Type__c;
        return dto;
        
        
    }
    
    public class CouponLimitDTO{
        
        @AuraEnabled public String type;
        
        
    }
    
}