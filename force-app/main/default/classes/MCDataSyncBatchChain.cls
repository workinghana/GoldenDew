public class MCDataSyncBatchChain implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {
    
    private List<String> objectNames;
    private Integer currentIndex;
    private String currentObjectName;
    private String soqlFields;
    private String deKey;
    private String whereClause;
    
    public static void startChain() {
        List<MC_Sync_Object__mdt> configs = [
            SELECT DeveloperName 
            FROM MC_Sync_Object__mdt 
            WHERE Is_Active__c = true
            ORDER BY DeveloperName
        ];
        
        List<String> names = new List<String>();
        for (MC_Sync_Object__mdt c : configs) {
            names.add(c.DeveloperName);
        }
        
        if (!names.isEmpty()) {
            Database.executeBatch(new MCDataSyncBatchChain(names, 0), 200);
        }
    }
    
    public MCDataSyncBatchChain(List<String> objectNames, Integer startIndex) {
        this.objectNames = objectNames;
        this.currentIndex = startIndex;
        
        MC_Sync_Object__mdt config = [
            SELECT Object_Name__c, SOQL_Fields__c, DE_External_Key__c, Where_Clause__c
            FROM MC_Sync_Object__mdt 
            WHERE DeveloperName = :objectNames[startIndex]
            LIMIT 1
        ];
        this.currentObjectName = config.Object_Name__c;
        this.soqlFields = config.SOQL_Fields__c;
        this.deKey = config.DE_External_Key__c;
        this.whereClause = config.Where_Clause__c;
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT ' + soqlFields + ' FROM ' + currentObjectName;
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<SObject> records) {
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
            System.debug('MC [' + currentObjectName + '] Response: ' + res.getStatusCode());
        } catch (Exception e) {
            System.debug('MC [' + currentObjectName + '] Error: ' + e.getMessage());
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('MC Sync Complete: ' + currentObjectName);
        
        Integer nextIndex = currentIndex + 1;
        if (nextIndex < objectNames.size()) {
            Database.executeBatch(new MCDataSyncBatchChain(objectNames, nextIndex), 200);
        }
    }
}