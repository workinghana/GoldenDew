public class MCTokenService {
    private static String cachedToken;
    
    public static String getAccessToken() {
        if (cachedToken != null) return cachedToken;
        
        MC_API_Setting__mdt setting = MC_API_Setting__mdt.getInstance('Default');
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(setting.Auth_Base_URI__c + '/v2/token');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, String>{
            'grant_type'    => 'client_credentials',
            'client_id'     => setting.Client_ID__c,
            'client_secret' => setting.Client_Secret__c,
            'account_id'    => setting.Account_ID__c
        }));
        req.setTimeout(30000);
        
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            cachedToken = (String) body.get('access_token');
            return cachedToken;
        }
        throw new CalloutException('MC Token Error: ' + res.getStatusCode() + ' ' + res.getBody());
    }
}