public with sharing class ErrorLogUIControllerV1 {

    @AuraEnabled(cacheable=true)
    public static ApexAuditTrail__c getDetail(Id recordId) {
        return [
            SELECT
                Name,
                Status__c,
                ErrorCode__c,
                ErrorMessage__c,
                HttpStatusCode__c,
                RequestDateTime__c,
                ResponseDateTime__c,
                ApexClass__c,
                Method__c,
                RequestUrl__c,
                RequestBody__c,
                ResponseBody__c,
                StackTrace__c,
                Description__c,
                FailedRecordIds__c
            FROM ApexAuditTrail__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
}