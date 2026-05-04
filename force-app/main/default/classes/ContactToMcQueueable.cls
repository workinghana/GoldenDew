public with sharing class ContactToMcQueueable implements Queueable, Database.AllowsCallouts {

    private List<Id> contactIds;

    public ContactToMcQueueable(List<Id> contactIds) {
        this.contactIds = contactIds;
    }

    public void execute(QueueableContext context) {
        List<Contact> contacts = [
            SELECT Id, LastName, Phone, CreatedDate
            FROM Contact
            WHERE Id IN :contactIds
        ];

        List<Object> rows = new List<Object>();

        for (Contact c : contacts) {
            Map<String, Object> row = new Map<String, Object>();
            Map<String, Object> keys = new Map<String, Object>();
            Map<String, Object> values = new Map<String, Object>();

            keys.put('ContactKey', c.Id);
            values.put('Phone', c.Phone);
            values.put('LastName', c.LastName);
            values.put('MemberJoinDate', String.valueOf(c.CreatedDate.date()));

            row.put('keys', keys);
            row.put('values', values);

            rows.add(row);
        }

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');

        // 아래 endpoint의 DE 외부키 부분은 실제 값으로 바꿔야 함
        req.setEndpoint('callout:MarketingCloudApiNC/hub/v1/dataevents/key:0036FAD5-FFFF-4F01-ADF9-6F922719927A/rowset');

        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(rows));

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('MC Response Code: ' + res.getStatusCode());
        System.debug('MC Response Body: ' + res.getBody());

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new CalloutException('Marketing Cloud call failed: ' + res.getStatusCode() + ' / ' + res.getBody());
        }
    }
}