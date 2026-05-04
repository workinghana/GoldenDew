global class MCDataSyncBatch implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    private String objectName;
    private String soqlFields;
    private String deKey;
    private String whereClause;
    private Integer successCount = 0;
    private Integer errorCount = 0;
    
    global MCDataSyncBatch(String metadataName) {
        MC_Sync_Object__mdt config = [
            SELECT Object_Name__c, SOQL_Fields__c, DE_External_Key__c, Where_Clause__c
            FROM MC_Sync_Object__mdt 
            WHERE DeveloperName = :metadataName AND Is_Active__c = true
            LIMIT 1
        ];
        this.objectName = config.Object_Name__c;
        this.soqlFields = config.SOQL_Fields__c;
        this.deKey = config.DE_External_Key__c;
        this.whereClause = config.Where_Clause__c;
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT ' + soqlFields + ' FROM ' + objectName;
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext bc, List<SObject> records) {
        List<String> fields = new List<String>();
        for (String f : soqlFields.split(',')) {
            fields.add(f.trim());
        }
        
        List<Map<String, String>> items = new List<Map<String, String>>();
        for (SObject rec : records) {
            Map<String, String> item = new Map<String, String>();
            for (String field : fields) {
                Object val = rec.get(field);
                item.put(field, val != null ? String.valueOf(val) : '');
            }
            items.add(item);
        }
        
        try {
            MC_API_Setting__mdt setting = MC_API_Setting__mdt.getInstance('Default');
            String token = MCTokenService.getAccessToken();
            
            String endpoint = setting.REST_Base_URI__c 
                            + '/data/v1/async/dataextensions/key:' + deKey + '/rows';
            
            String payload = JSON.serialize(new Map<String, Object>{ 'items' => items });
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('PUT');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setHeader('Content-Type', 'application/json');
            req.setBody(payload);
            req.setTimeout(120000);
            
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 202) {
                successCount += items.size();
            } else {
                errorCount += items.size();
                System.debug('MC Error: ' + res.getStatusCode() + ' ' + res.getBody());
            }
        } catch (Exception e) {
            errorCount += items.size();
            System.debug('Exception: ' + e.getMessage());
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('MC Sync Complete - Object: ' + objectName + ' Success: ' + successCount + ' Error: ' + errorCount);
    }
}