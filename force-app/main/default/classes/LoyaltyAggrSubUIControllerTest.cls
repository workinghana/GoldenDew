@IsTest
private class LoyaltyAggrSubUIControllerTest {
    private static String pickFirst(List<Schema.PicklistEntry> entries, String defaultValue) {
        return (entries != null && !entries.isEmpty()) ? entries[0].getValue() : defaultValue;
    }

    /* =========================================================
     * Test Data Setup
     * ========================================================= */
    @TestSetup
    static void setupData() {
        Contact c = new Contact(LastName = 'PointTester', MemberNo__c = 'M1001');
        insert c;

        LoyaltyProgram lp = new LoyaltyProgram(Name = 'Point Test Program', IsPrimary = true);
        insert lp;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ContactId = c.Id,
            ProgramId = lp.Id,
            MembershipNumber = 'LPM-M1001',
            EnrollmentDate = Date.today(),
            MemberStatus = 'Active'
        );
        insert lpm;

        String currencyType = 'NonQualifying';
        for (
            Schema.PicklistEntry e : LoyaltyProgramCurrency.CurrencyType.getDescribe()
                .getPicklistValues()
        ) {
            if (e.getValue().equalsIgnoreCase('NonQualifying')) {
                currencyType = e.getValue();
                break;
            }
        }
        // DoesAllowLedgerTracing=true(LoyaltyLedger 필수) → Fixed+NonQualifying 조합만 허용
        String expiryModel = 'Fixed';
        for (Schema.PicklistEntry e : LoyaltyProgramCurrency.ExpiryModel.getDescribe().getPicklistValues()) {
            if (e.getValue().equalsIgnoreCase('Fixed')) {
                expiryModel = e.getValue();
                break;
            }
        }
        // Fixed+NonQualifying에서 Days 단위 불가 → Months/Years 우선 선택
        List<Schema.PicklistEntry> unitEntries = LoyaltyProgramCurrency.ExpiryPeriodUnit.getDescribe().getPicklistValues();
        String expiryUnit = null;
        for (Schema.PicklistEntry e : unitEntries) {
            String v = e.getValue().toLowerCase();
            if (v.contains('month') || v.contains('year')) {
                expiryUnit = e.getValue();
                break;
            }
        }
        if (expiryUnit == null) {
            expiryUnit = pickFirst(unitEntries, null);
        }
        // Fixed+NonQualifying 조합은 만료 일자 연장 타입만 허용
        // API value(영문) 또는 라벨(한국어 '연장'/'만료')로 후보 탐색, 없으면 마지막 값 사용
        List<Schema.PicklistEntry> extEntries = LoyaltyProgramCurrency.ExtendExpiration.getDescribe().getPicklistValues();
        String extendExpiration = extEntries.isEmpty() ? null : extEntries[extEntries.size() - 1].getValue();
        for (Schema.PicklistEntry e : extEntries) {
            String v = e.getValue().toLowerCase();
            String lbl = e.getLabel().toLowerCase();
            if (v.contains('expir') || v.contains('date') || v.contains('extend')
                || lbl.contains('연장') || lbl.contains('만료')) {
                extendExpiration = e.getValue();
                break;
            }
        }

        LoyaltyProgramCurrency lpc = new LoyaltyProgramCurrency(
            LoyaltyProgramId = lp.Id,
            Name = '포인트',
            CurrencyType = currencyType,
            IsActive = true,
            IsPrimary = true,
            ExpiryModel = expiryModel,
            ExtendExpiration = extendExpiration,
            ExpiryPeriodFrequency = 12,
            ExpiryPeriodUnit = expiryUnit,
            CostperUnit = 1,
            HasEscrow = false,
            DoesAllowLedgerTracing = true
        );
        insert lpc;

        String pointTypeCode = pickFirst(
            LoyaltyPgmCurrencySubtype.PointTypeCode__c.getDescribe().getPicklistValues(),
            'NORMAL'
        );
        LoyaltyPgmCurrencySubtype subtype = new LoyaltyPgmCurrencySubtype(
            LoyaltyProgramCurrencyId = lpc.Id,
            Name = '기본 포인트',
            PointTypeCode__c = pointTypeCode,
            UsagePriorityNumber = 1
        );
        insert subtype;

        JournalType jt = new JournalType(Name = 'Accrual', ProcessType = 'Loyalty');
        insert jt;
        JournalSubType jst = new JournalSubType(
            Name = 'Manual Points Credit',
            JournalTypeId = jt.Id
        );
        insert jst;

        TransactionJournal tj = new TransactionJournal(
            MemberId = lpm.Id,
            LoyaltyProgramId = lp.Id,
            ActivityDate = Datetime.now(),
            JournalDate = Datetime.now(),
            JournalTypeId = jt.Id,
            JournalSubTypeId = jst.Id,
            Status = 'Processed'
        );
        insert tj;

        Date keyDate = Date.today().addDays(10);

        // 같은 key(subtype + expiryDate)에 Credit/Debit를 넣어 mapResult containsKey true 분기를 강제한다.
        LoyaltyLedger creditLedger = new LoyaltyLedger(
            LoyaltyProgramMemberId = lpm.Id,
            LoyaltyProgramCurrencyId = lpc.Id,
            LoyaltyPgmCrcySubtypeId = subtype.Id,
            TransactionJournalId = tj.Id,
            EventType = 'Credit',
            Points = 100,
            ActivityDate = Date.today(),
            ExpiryDate = keyDate
        );

        LoyaltyLedger debitLedger = new LoyaltyLedger(
            LoyaltyProgramMemberId = lpm.Id,
            LoyaltyProgramCurrencyId = lpc.Id,
            LoyaltyPgmCrcySubtypeId = subtype.Id,
            TransactionJournalId = tj.Id,
            EventType = 'Debit',
            Points = 40,
            ActivityDate = Date.today(),
            ExpiryDate = keyDate
        );

        insert new List<LoyaltyLedger>{ creditLedger, debitLedger };
    }

    /* =========================================================
     * getPointDetails 정상 케이스
     * ========================================================= */
    @IsTest
    static void test_getPointDetails_success() {
        Id lpmId = [SELECT Id FROM LoyaltyProgramMember LIMIT 1].Id;

        Test.startTest();
        LoyaltyAggrSubUIController.PointDetailResult result = LoyaltyAggrSubUIController.getPointDetails(
            lpmId
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(
            1,
            result.details.size(),
            '동일 key 2건(Credit/Debit)은 1건으로 집계되어야 함'
        );
        System.assertEquals(100, result.totalAccrued, 'Credit 합계');
        System.assertEquals(40, result.totalUsed, 'Debit 합계');
        System.assertEquals(60, result.totalRemaining, '잔여 합계');

        LoyaltyAggrSubUIController.PointDetailDTO first = result.details[0];
        System.assertEquals('기본 포인트', first.pointTypeName);
        System.assertEquals(100, first.accruedPoints);
        System.assertEquals(40, first.usedPoints);
        System.assertEquals(0, first.expiredPoints);
        System.assertEquals(60, first.remainingPoints);
    }

    /* =========================================================
     * Ledger 없는 경우
     * ========================================================= */
    @IsTest
    static void test_getPointDetails_empty() {
        Id fakeId = UserInfo.getUserId();

        Test.startTest();
        LoyaltyAggrSubUIController.PointDetailResult result = LoyaltyAggrSubUIController.getPointDetails(
            fakeId
        );
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(0, result.details.size());
        System.assertEquals(0, result.totalAccrued);
        System.assertEquals(0, result.totalUsed);
        System.assertEquals(0, result.totalRemaining);
    }
}