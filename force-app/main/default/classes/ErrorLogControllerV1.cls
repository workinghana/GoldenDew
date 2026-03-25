public with sharing class ErrorLogControllerV1 {

    @AuraEnabled(cacheable=true)
    public static List<ApexAuditTrail__c> getErrorLogs(
        Datetime fromDt,
        Datetime toDt,
        String status,
        Integer limitSize
    ) {
        if (fromDt == null || toDt == null) {
            throw new AuraHandledException('조회 기간이 올바르지 않습니다.');
        }

        String soql =
            'SELECT Id, Name, Status__c, ApexClass__c, ' +
            'ErrorCode__c, ErrorMessage__c, StackTrace__c, ' +
            'RequestDateTime__c, ResponseDateTime__c, ' +
            'RequestBody__c, ResponseBody__c, ' +
            'IsBatch__c, IsQueueable__c, IsScheduled__c ' +
            'FROM ApexAuditTrail__c ' +
            'WHERE CreatedDate >= :fromDt ' +
            'AND CreatedDate <= :toDt ';


        if (String.isNotBlank(status)) {
            soql += 'AND Status__c = :status ';
        }

        soql += 'ORDER BY RequestDateTime__c DESC LIMIT :limitSize';

        return Database.query(soql);
    }
}