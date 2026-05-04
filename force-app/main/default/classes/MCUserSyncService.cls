public class MCUserSyncService {
    
    private static final String DE_KEY = '8E4A3E60-4F3E-4176-82B0-F14DCA6A676C';
    
    public static void syncAllUsers() {
        List<User> users = [
            SELECT Id, ContactId, AccountId, CallCenterId, 
                   CreatedById, DelegatedApproverId, Email,
                   IndividualId, LastModifiedById, ManagerId,
                   Name, ProfileId, UserRoleId
            FROM User
            WHERE IsActive = true
        ];
        
        List<List<User>> batches = new List<List<User>>();
        List<User> currentBatch = new List<User>();
        
        for (User u : users) {
            currentBatch.add(u);
            if (currentBatch.size() == 200) {
                batches.add(currentBatch);
                currentBatch = new List<User>();
            }
        }
        if (!currentBatch.isEmpty()) {
            batches.add(currentBatch);
        }
        
        if (!batches.isEmpty()) {
            String payload = buildPayload(batches[0]);
            sendToMC(payload);
        }
    }
    
    private static String buildPayload(List<User> users) {
        List<Map<String, String>> items = new List<Map<String, String>>();
        
        for (User u : users) {
            items.add(new Map<String, String>{
                'ContactKey'          => u.Id,
                'AccountId'           => nullSafe(u.AccountId),
                'CallCenterId'        => nullSafe(u.CallCenterId),
                'ContactId'           => nullSafe(u.ContactId),
                'CreatedById'         => nullSafe(u.CreatedById),
                'DelegatedApproverId' => nullSafe(u.DelegatedApproverId),
                'Email'               => nullSafe(u.Email),
                'Id'                  => u.Id,
                'IndividualId'        => nullSafe(u.IndividualId),
                'LastModifiedById'    => nullSafe(u.LastModifiedById),
                'ManagerId'           => nullSafe(u.ManagerId),
                'Name'                => nullSafe(u.Name),
                'ProfileId'           => nullSafe(u.ProfileId),
                'UserRoleId'          => nullSafe(u.UserRoleId)
            });
        }
        
        return JSON.serialize(new Map<String, Object>{ 'items' => items });
    }
    
    private static String nullSafe(String val) {
        return val != null ? val : '';
    }
    
    @future(callout=true)
    public static void sendToMC(String payload) {
        MC_API_Setting__mdt setting = MC_API_Setting__mdt.getInstance('Default');
        String token = MCTokenService.getAccessToken();
        
        String endpoint = setting.REST_Base_URI__c 
                        + '/data/v1/async/dataextensions/key:' + DE_KEY + '/rows';
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('PUT');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(payload);
        req.setTimeout(120000);
        
        HttpResponse res = new Http().send(req);
        System.debug('MC Response Code: ' + res.getStatusCode());
        System.debug('MC Response Body: ' + res.getBody());
    }
}