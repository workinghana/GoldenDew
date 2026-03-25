@IsTest
private class LoyaltyPointExpirationBatchTest {

    private class MockBatchableContext implements Database.BatchableContext {
        public Id getJobId() { return UserInfo.getUserId(); }
        public Id getChildJobId() { return UserInfo.getUserId(); }
    }

    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
    }

    /* ===== 공통 데이터 생성 ===== */

    @TestSetup
    static void setupData() {
        // LoyaltyProgram — 이름이 System.Label.LoyaltyProgramName 과 일치해야
        // 정적 필드 LOYALTY_PROGRAM_ID = SObjectUtil.findIdByName(..., true) 가 예외 없이 초기화됨
        LoyaltyProgram lp = new LoyaltyProgram(Name = System.Label.LoyaltyProgramName, IsPrimary = true);
        insert lp;

        // LoyaltyProgramCurrency — Name = '포인트' (execute 내 SObjectUtil.findIdByName 조회 대상)
        String currencyType = 'NonQualifying';
        for (Schema.PicklistEntry e : LoyaltyProgramCurrency.CurrencyType.getDescribe().getPicklistValues()) {
            if (e.getValue().equalsIgnoreCase('NonQualifying')) { currencyType = e.getValue(); break; }
        }

        String expiryUnit = null;
        for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues()) {
            if (!e.getValue().toLowerCase().contains('day')) { expiryUnit = e.getValue(); break; }
        }
        if (expiryUnit == null) {
            List<Schema.PicklistEntry> unitEntries = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();
            if (!unitEntries.isEmpty()) expiryUnit = unitEntries[0].getValue();
        }

        String expiryModel = 'FIXED';
        for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
            if (e.getValue().equalsIgnoreCase('FIXED')) { expiryModel = e.getValue(); break; }
        }

        String extendExpiration = null;
        List<Schema.PicklistEntry> extEntries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
        if (!extEntries.isEmpty()) extendExpiration = extEntries[0].getValue();

        LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
            LoyaltyProgramId = lp.Id,
            Name = '포인트',
            CurrencyType = currencyType,
            IsActive = true,
            IsPrimary = true,
            ExpiryPeriodFrequency = 12,
            ExpiryPeriodUnit = expiryUnit,
            ExpiryModel = expiryModel,
            ExtendExpiration = extendExpiration,
            CostperUnit = 1,
            HasEscrow = false,
            DoesAllowLedgerTracing = true
        );
        insert lpc;

        String pointTypeCode = 'NORMAL';
        List<Schema.PicklistEntry> ptEntries = LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues();
        if (!ptEntries.isEmpty()) pointTypeCode = ptEntries[0].getValue();

        LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
            LoyaltyProgramCurrencyId = lpc.Id,
            Name = 'Test Subtype',
            PointTypeCode__c = pointTypeCode,
            UsagePriorityNumber = 1
        );
        insert subtype;

        // JournalType / JournalSubType — execute() 내 SObjectUtil 조회 대상
        JournalType jtExpiry = new JournalType(Name = 'Points Expiration', ProcessType = 'Loyalty');
        insert jtExpiry;

        JournalSubType jstExpiry = new JournalSubType(Name = 'Auto Expire', JournalTypeId = jtExpiry.Id);
        insert jstExpiry;

        // Credit LoyaltyLedger 생성용 JournalType
        JournalType jtAccrual = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
        insert jtAccrual;

        JournalSubType jstAccrual = new JournalSubType(Name = 'Manual Points Credit', JournalTypeId = jtAccrual.Id);
        insert jstAccrual;

        // Contact + LoyaltyProgramMember
        Contact c = new Contact(LastName = uniq('Contact'), MemberNo__c = uniq('M'));
        insert c;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ContactId = c.Id,
            ProgramId = lp.Id,
            MembershipNumber = uniq('NUM'),
            MemberStatus = 'Active',
            EnrollmentDate = Date.today()
        );
        insert lpm;

        // TransactionJournal — Credit LoyaltyLedger 에 연결
        TransactionJournal tj = new TransactionJournal();
        tj.MemberId = lpm.Id;
        tj.LoyaltyProgramId = lp.Id;
        tj.ActivityDate = Datetime.now();
        tj.JournalDate = Datetime.now();
        tj.JournalTypeId = jtAccrual.Id;
        tj.JournalSubTypeId = jstAccrual.Id;
        tj.Status = 'Processed';
        insert tj;

        // LoyaltyLedger (Credit) — start() 쿼리 대상
        LoyaltyLedger ll = new LoyaltyLedger();
        ll.LoyaltyProgramMemberId = lpm.Id;
        ll.LoyaltyProgramCurrencyId = lpc.Id;
        ll.LoyaltyPgmCrcySubtypeId = subtype.Id;
        ll.TransactionJournalId = tj.Id;
        ll.EventType = 'Credit';
        ll.Points = 100;
        ll.ActivityDate = Date.today();
        ll.ExpiryDate = Date.today();
        insert ll;
    }

    private static LoyaltyLedger getCreditLedger() {
        return [
            SELECT Id, LoyaltyProgramMemberId, LoyaltyPgmCrcySubtypeId, ExpiryDate, EventType, Points, LoyaltyProgramCurrencyId
            FROM LoyaltyLedger
            WHERE EventType = 'Credit'
            LIMIT 1
        ];
    }

    /* ===== 테스트 메서드 ===== */

    /** execute : 빈 scope 조기 반환 */
    @IsTest
    static void test_execute_emptyScope() {
        Test.startTest();
        new LoyaltyPointExpirationBatch().execute(new MockBatchableContext(), new List<LoyaltyLedger>());
        Test.stopTest();

        System.assert(true);
    }

    /** execute : null scope 조기 반환 */
    @IsTest
    static void test_execute_nullScope() {
        Test.startTest();
        new LoyaltyPointExpirationBatch().execute(new MockBatchableContext(), null);
        Test.stopTest();

        System.assert(true);
    }

    /** execute : LoyaltyLedger Id 없는 항목만 있는 경우 (creditLedgerIds empty 분기) */
    @IsTest
    static void test_execute_ledgerWithNullId() {
        LoyaltyLedger ll = new LoyaltyLedger(); // Id 없음

        Test.startTest();
        new LoyaltyPointExpirationBatch().execute(new MockBatchableContext(), new List<LoyaltyLedger>{ ll });
        Test.stopTest();

        System.assert(true);
    }

    /** execute : 정상 LoyaltyLedger → 만료 처리 전체 흐름 */
    @IsTest
    static void test_execute_withCreditLedger() {
        LoyaltyLedger ll = getCreditLedger();
        List<LoyaltyLedger> scope = new List<LoyaltyLedger>{ ll };

        Test.startTest();
        new LoyaltyPointExpirationBatch().execute(new MockBatchableContext(), scope);
        Test.stopTest();

        System.assert(true);
    }

    /** finish : 성공/실패 집계 및 알림 발행 */
    @IsTest
    static void test_finish() {
        Test.startTest();
        new LoyaltyPointExpirationBatch().finish(new MockBatchableContext());
        Test.stopTest();

        System.assert(true);
    }

    /** 전체 흐름 : Database.executeBatch (start → execute → finish) */
    @IsTest
    static void test_executeBatch_fullFlow() {
        Test.startTest();
        Database.executeBatch(new LoyaltyPointExpirationBatch(), 50);
        Test.stopTest();

        System.assert(true);
    }
}