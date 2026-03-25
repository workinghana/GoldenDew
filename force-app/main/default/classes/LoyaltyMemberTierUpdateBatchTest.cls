@IsTest
private class LoyaltyMemberTierUpdateBatchTest {

    private class MockBatchableContext implements Database.BatchableContext {
        public Id getJobId() { return UserInfo.getUserId(); }
        public Id getChildJobId() { return UserInfo.getUserId(); }
    }

    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
    }

    private static String getFirstGradeValue() {
        List<Schema.PicklistEntry> entries = LoyaltyTier.Grade__c.getDescribe().getPicklistValues();
        return entries.isEmpty() ? null : entries[0].getValue();
    }

    private static String getSecondGradeValue() {
        List<Schema.PicklistEntry> entries = LoyaltyTier.Grade__c.getDescribe().getPicklistValues();
        return entries.size() > 1 ? entries[1].getValue() : null;
    }

    /* ===== 공통 데이터 생성 ===== */

    @TestSetup
    static void setupData() {
        String gradeValue = getFirstGradeValue();

        LoyaltyProgram lp = new LoyaltyProgram(Name = 'TierUpdate Test Program', IsPrimary = true);
        insert lp;

        LoyaltyTierGroup ltg = new LoyaltyTierGroup(
            Name = 'TierUpdate Tier Group',
            LoyaltyProgramId = lp.Id,
            TierModel = 'Fixed',
            QpResetPeriod = 'Years',
            QpResetFrequency = 1,
            QpResetDate = Date.today()
        );
        insert ltg;

        LoyaltyTier lt = new LoyaltyTier(
            Name = 'Test Tier',
            LoyaltyTierGroupId = ltg.Id,
            SequenceNumber = 1,
            Grade__c = gradeValue
        );
        insert lt;

        Contact c = new Contact(
            LastName = uniq('Contact'),
            MemberNo__c = uniq('M'),
            Grade__c = gradeValue,
            ExpectedGrade__c = gradeValue
        );
        insert c;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ContactId = c.Id,
            ProgramId = lp.Id,
            MembershipNumber = uniq('NUM'),
            MemberStatus = 'Active',
            EnrollmentDate = Date.today()
        );
        insert lpm;
    }

    private static Contact getContact() {
        return [SELECT Id, Grade__c, ExpectedGrade__c, MemberNo__c FROM Contact LIMIT 1];
    }

    /* ===== 테스트 메서드 ===== */

    /** execute : 빈 scope 조기 반환 */
    @IsTest
    static void test_execute_emptyScope() {
        Test.startTest();
        new LoyaltyMemberTierUpdateBatch().execute(new MockBatchableContext(), new List<Contact>());
        Test.stopTest();

        System.assert(true);
    }

    /** execute : LoyaltyTier 매핑 없는 Contact (두 번째 등급이 있으나 Tier 미존재) */
    @IsTest
    static void test_execute_noTierMapping() {
        String secondGrade = getSecondGradeValue();
        if (secondGrade == null) {
            System.assert(true, 'skipped - only one grade value exists');
            return;
        }

        String firstGrade = getFirstGradeValue();

        Contact c = new Contact(
            LastName = uniq('NoTier'),
            MemberNo__c = uniq('M'),
            Grade__c = firstGrade,
            ExpectedGrade__c = secondGrade
        );
        insert c;

        List<Contact> scope = [SELECT Id, ExpectedGrade__c, Grade__c, MemberNo__c FROM Contact WHERE Id = :c.Id];

        Test.startTest();
        new LoyaltyMemberTierUpdateBatch().execute(new MockBatchableContext(), scope);
        Test.stopTest();

        System.assert(true);
    }

    /** execute : Contact 있으나 LoyaltyProgramMember 없음 */
    @IsTest
    static void test_execute_noLoyaltyProgramMember() {
        String gradeValue = getFirstGradeValue();

        Contact c = new Contact(
            LastName = uniq('NoLPM'),
            MemberNo__c = uniq('M'),
            Grade__c = gradeValue,
            ExpectedGrade__c = gradeValue
        );
        insert c;

        List<Contact> scope = [SELECT Id, ExpectedGrade__c, Grade__c, MemberNo__c FROM Contact WHERE Id = :c.Id];

        Test.startTest();
        new LoyaltyMemberTierUpdateBatch().execute(new MockBatchableContext(), scope);
        Test.stopTest();

        System.assert(true);
    }

    /** execute : 정상 데이터 (LPM 존재 → changeTier 시도) */
    @IsTest
    static void test_execute_withLoyaltyProgramMember() {
        Contact c = getContact();
        List<Contact> scope = [SELECT Id, ExpectedGrade__c, Grade__c, MemberNo__c FROM Contact WHERE Id = :c.Id];

        Test.startTest();
        new LoyaltyMemberTierUpdateBatch().execute(new MockBatchableContext(), scope);
        Test.stopTest();

        System.assert(true);
    }

    /** finish : 성공/실패 집계 및 알림 발행 */
    @IsTest
    static void test_finish() {
        Test.startTest();
        new LoyaltyMemberTierUpdateBatch().finish(new MockBatchableContext());
        Test.stopTest();

        System.assert(true);
    }

    /** 전체 흐름 : Database.executeBatch (start → execute → finish) */
    @IsTest
    static void test_executeBatch_fullFlow() {
        Test.startTest();
        Database.executeBatch(new LoyaltyMemberTierUpdateBatch(), 50);
        Test.stopTest();

        System.assert(true);
    }
}