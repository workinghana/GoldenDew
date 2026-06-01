public class MCDataSyncBatchChain implements Database.Batchable<SObject>, Database.AllowsCallouts, Database.Stateful {

    private static final Integer DEFAULT_BATCH_SIZE = 200;
    private static final Integer MAX_BATCH_SIZE = 2000;
    private static final String CONTACT_OBJECT_NAME = 'Contact';

    // MC Data Extension Phone 타입 허용 기준
    // - 허용 문자: 숫자(0-9), 하이픈(-), 플러스(+), 공백, 괄호((,)), 점(.)
    // - 전체 길이: 최대 50자 (MC Phone 필드 storage 한도)
    // - 숫자 개수: 7~15 (국내 최소 7자리 ~ E.164 국제 최대 15자리)
    private static final Pattern PHONE_ALLOWED_CHARS = Pattern.compile('^[0-9\\-\\+\\s\\(\\)\\.]+$');
    private static final Integer PHONE_MAX_LENGTH = 50;
    private static final Integer PHONE_MIN_DIGITS = 7;
    private static final Integer PHONE_MAX_DIGITS = 15;

    private List<String> objectNames;
    private Integer currentIndex;
    private Integer batchSize;
    private String currentObjectName;
    private String soqlFields;
    private String deKey;
    private String whereClause;

    private List<String> parsedFields;
    private Set<String> phoneFieldsLower;

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
            MCDataSyncBatchChain job = new MCDataSyncBatchChain(names, 0);
            Database.executeBatch(job, job.batchSize);
        }
    }

    public MCDataSyncBatchChain(List<String> objectNames, Integer startIndex) {
        this.objectNames = objectNames;
        this.currentIndex = startIndex;

        MC_Sync_Object__mdt config = [
            SELECT Object_Name__c, SOQL_Fields__c, DE_External_Key__c, Where_Clause__c, Batch_Size__c
            FROM MC_Sync_Object__mdt
            WHERE DeveloperName = :objectNames[startIndex]
            LIMIT 1
        ];
        this.currentObjectName = config.Object_Name__c;
        this.soqlFields = config.SOQL_Fields__c;
        this.deKey = config.DE_External_Key__c;
        this.whereClause = config.Where_Clause__c;
        this.batchSize = normalizeBatchSize(config.Batch_Size__c);

        this.parsedFields = new List<String>();
        for (String f : this.soqlFields.split(',')) {
            this.parsedFields.add(f.trim());
        }

        this.phoneFieldsLower = resolvePhoneFields(this.currentObjectName, this.parsedFields);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String query = 'SELECT ' + soqlFields + ' FROM ' + currentObjectName;
        if (String.isNotBlank(whereClause)) {
            query += ' WHERE ' + whereClause;
        }
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<SObject> records) {
        List<Map<String, String>> items = new List<Map<String, String>>();
        for (SObject rec : records) {
            Map<String, String> item = new Map<String, String>();
            for (String field : parsedFields) {
                Object val = rec.get(field);
                String strVal = val != null ? String.valueOf(val) : '';

                // Contact + Phone 타입 필드만 형식 검증, 불일치 시 공란 처리
                if (String.isNotBlank(strVal)
                    && phoneFieldsLower != null
                    && phoneFieldsLower.contains(field.toLowerCase())
                    && !isValidPhone(strVal)) {
                    strVal = '';
                }

                item.put(field, strVal);
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
            MCDataSyncBatchChain next = new MCDataSyncBatchChain(objectNames, nextIndex);
            Database.executeBatch(next, next.batchSize);
        }
    }

    @TestVisible
    private static Integer normalizeBatchSize(Decimal requested) {
        if (requested == null) {
            return DEFAULT_BATCH_SIZE;
        }
        Integer val = requested.intValue();
        if (val <= 0) {
            return DEFAULT_BATCH_SIZE;
        }
        if (val > MAX_BATCH_SIZE) {
            return MAX_BATCH_SIZE;
        }
        return val;
    }

    @TestVisible
    private static Set<String> resolvePhoneFields(String objectName, List<String> fields) {
        Set<String> result = new Set<String>();
        if (objectName != CONTACT_OBJECT_NAME || fields == null || fields.isEmpty()) {
            return result;
        }

        Schema.SObjectType sot = Schema.getGlobalDescribe().get(objectName);
        if (sot == null) {
            return result;
        }
        Map<String, Schema.SObjectField> fieldMap = sot.getDescribe().fields.getMap();

        for (String fname : fields) {
            if (String.isBlank(fname)) {
                continue;
            }
            Schema.SObjectField sof = fieldMap.get(fname.toLowerCase());
            if (sof == null) {
                continue;
            }
            if (sof.getDescribe().getType() == Schema.DisplayType.Phone) {
                result.add(fname.toLowerCase());
            }
        }
        return result;
    }

    /**
     * MC Data Extension Phone 타입 적합성 검증
     * - 전체 길이 > 50자: 거부 (MC storage 한도 초과)
     * - 허용 외 문자(영문/한글/특수문자) 포함: 거부
     * - 숫자 개수 < 7 또는 > 15: 거부 (phone으로 해석 불가)
     * 통과한 값만 MC에 그대로 전송하고, 거부된 값은 호출부에서 공란 처리됨
     */
    @TestVisible
    private static Boolean isValidPhone(String value) {
        if (String.isBlank(value)) {
            return false;
        }
        String trimmed = value.trim();
        if (trimmed.length() > PHONE_MAX_LENGTH) {
            return false;
        }
        if (!PHONE_ALLOWED_CHARS.matcher(trimmed).matches()) {
            return false;
        }
        String digitsOnly = trimmed.replaceAll('[^0-9]', '');
        Integer len = digitsOnly.length();
        return len >= PHONE_MIN_DIGITS && len <= PHONE_MAX_DIGITS;
    }
}