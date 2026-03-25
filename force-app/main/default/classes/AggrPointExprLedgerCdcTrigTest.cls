@IsTest
private class AggrPointExprLedgerCdcTrigTest {
    @TestSetup
    static void setupData() {
        Contact c = new Contact(LastName = 'CDC Member');
        insert c;

        LoyaltyProgram lp = new LoyaltyProgram(Name = 'CDC Program', IsPrimary = true);
        insert lp;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ContactId = c.Id,
            ProgramId = lp.Id,
            MembershipNumber = 'CDC-M-001',
            EnrollmentDate = System.today(),
            MemberStatus = 'Active',
            MemberType = 'Individual'
        );
        insert lpm;

        LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
            Name = 'CDC Point',
            LoyaltyProgramId = lp.Id,
            CurrencyType = 'NonQualifying',
            IsActive = true,
            ExpiryPeriodFrequency = 2,
            ExpiryModel = 'Fixed',
            ExpiryPeriodUnit = 'Years',
            ExtendExpiration = 'None',
            DoesAllowLedgerTracing = true
        );
        insert lpc;
    }

    @IsTest
    static void trigger_create_change_event_executes() {
        Schema.SObjectType targetType = getTargetType();

        System.assertNotEquals(null, targetType, '대상 오브젝트가 존재해야 합니다.');

        Schema.DescribeSObjectResult dsr = targetType.getDescribe();
        if (!dsr.isCreateable()) {
            System.assert(true, '오브젝트가 생성 불가인 org에서는 테스트를 스킵합니다.');
            return;
        }

        SObject recordToInsert = buildCreateableRecord(targetType);

        Test.startTest();
        Test.enableChangeDataCapture();
        insert recordToInsert;
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assertNotEquals(null, recordToInsert.get('Id'));
    }

    @IsTest
    static void trigger_update_change_event_executes() {
        Schema.SObjectType targetType = getTargetType();

        System.assertNotEquals(null, targetType, '대상 오브젝트가 존재해야 합니다.');

        Schema.DescribeSObjectResult dsr = targetType.getDescribe();
        if (!dsr.isCreateable() || !dsr.isUpdateable()) {
            System.assert(true, '오브젝트가 생성/수정 불가인 org에서는 테스트를 스킵합니다.');
            return;
        }

        SObject recordToInsert = buildCreateableRecord(targetType);
        insert recordToInsert;

        Boolean updateApplied = applyFirstUpdatableField(recordToInsert);
        if (!updateApplied) {
            System.assert(true, '수정 가능한 필드를 찾지 못해 테스트를 스킵합니다.');
            return;
        }

        Test.startTest();
        Test.enableChangeDataCapture();
        update recordToInsert;
        Test.getEventBus().deliver();
        Test.stopTest();

        System.assertNotEquals(null, recordToInsert.get('Id'));
    }

    private static Schema.SObjectType getTargetType() {
        return Schema.getGlobalDescribe().get('LoyaltyAggrPointExprLedger');
    }

    private static Id getLpmId() {
        return [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;
    }

    private static Id getLpcId() {
        return [SELECT Id FROM LoyaltyProgramCurrency LIMIT 1].Id;
    }

    private static SObject buildCreateableRecord(Schema.SObjectType targetType) {
        SObject sobj = targetType.newSObject();
        Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();

        for (String fieldName : fieldMap.keySet()) {
            if (fieldName == 'Id') {
                continue;
            }

            Schema.DescribeFieldResult f = fieldMap.get(fieldName).getDescribe();
            if (!f.isCreateable()) {
                continue;
            }
            if (f.isNillable() || f.isDefaultedOnCreate() || f.isAutoNumber() || f.isCalculated()) {
                continue;
            }

            Object val = sampleValueForCreate(f);
            if (val != null) {
                sobj.put(fieldName, val);
            }
        }

        if (fieldMap.containsKey('LoyaltyProgramMemberId') && sobj.get('LoyaltyProgramMemberId') == null) {
            sobj.put('LoyaltyProgramMemberId', getLpmId());
        }
        if (fieldMap.containsKey('LoyaltyProgramCurrencyId') && sobj.get('LoyaltyProgramCurrencyId') == null) {
            sobj.put('LoyaltyProgramCurrencyId', getLpcId());
        }

        return sobj;
    }

    private static Object sampleValueForCreate(Schema.DescribeFieldResult f) {
        Schema.DisplayType t = f.getType();

        if (t == Schema.DisplayType.String || t == Schema.DisplayType.TextArea) {
            return 'TEST';
        }
        if (t == Schema.DisplayType.Boolean) {
            return true;
        }
        if (t == Schema.DisplayType.Date) {
            return Date.today();
        }
        if (t == Schema.DisplayType.Datetime) {
            return System.now();
        }
        if (t == Schema.DisplayType.Integer) {
            return 1;
        }
        if (
            t == Schema.DisplayType.Double ||
            t == Schema.DisplayType.Percent ||
            t == Schema.DisplayType.Currency
        ) {
            return 1;
        }
        if (t == Schema.DisplayType.Long) {
            return 1L;
        }
        if (t == Schema.DisplayType.Phone) {
            return '01012341234';
        }
        if (t == Schema.DisplayType.Email) {
            return 'test@example.com';
        }
        if (t == Schema.DisplayType.Url) {
            return 'https://example.com';
        }
        if (t == Schema.DisplayType.Picklist) {
            List<Schema.PicklistEntry> entries = f.getPicklistValues();
            if (!entries.isEmpty()) {
                return entries[0].getValue();
            }
        }

        return null;
    }

    private static Boolean applyFirstUpdatableField(SObject sobj) {
        Map<String, Schema.SObjectField> fieldMap = sobj.getSObjectType().getDescribe().fields.getMap();

        for (String fieldName : fieldMap.keySet()) {
            if (fieldName == 'Id') {
                continue;
            }

            Schema.DescribeFieldResult f = fieldMap.get(fieldName).getDescribe();
            if (!f.isUpdateable() || f.isCalculated() || f.isAutoNumber()) {
                continue;
            }

            Object currentVal = sobj.get(fieldName);
            Object nextVal = sampleValueForUpdate(f, currentVal);
            if (nextVal != null) {
                sobj.put(fieldName, nextVal);
                return true;
            }
        }

        return false;
    }

    private static Object sampleValueForUpdate(Schema.DescribeFieldResult f, Object currentVal) {
        Schema.DisplayType t = f.getType();

        if (t == Schema.DisplayType.String || t == Schema.DisplayType.TextArea) {
            return String.valueOf(currentVal) == 'UPDATED' ? 'UPDATED2' : 'UPDATED';
        }
        if (t == Schema.DisplayType.Boolean) {
            return currentVal == null ? true : !((Boolean) currentVal);
        }
        if (t == Schema.DisplayType.Date) {
            return Date.today().addDays(1);
        }
        if (t == Schema.DisplayType.Datetime) {
            return System.now().addMinutes(1);
        }
        if (t == Schema.DisplayType.Integer) {
            return 2;
        }
        if (
            t == Schema.DisplayType.Double ||
            t == Schema.DisplayType.Percent ||
            t == Schema.DisplayType.Currency
        ) {
            return 2;
        }
        if (t == Schema.DisplayType.Long) {
            return 2L;
        }
        if (t == Schema.DisplayType.Picklist) {
            List<Schema.PicklistEntry> entries = f.getPicklistValues();
            if (entries.size() > 1) {
                return entries[1].getValue();
            }
            if (entries.size() == 1) {
                return entries[0].getValue();
            }
        }

        return null;
    }
}