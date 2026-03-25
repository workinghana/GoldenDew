@IsTest
private class ExpectedGradeCalculationBatchTest {
    private static String uniq(String prefix) {
        return prefix + '_' + String.valueOf(Datetime.now().getTime());
    }

    private static LoyaltyProgram createProgram() {
        LoyaltyProgram lp = new LoyaltyProgram(Name = uniq('LP'), IsPrimary = true);
        insert lp;
        return lp;
    }

    private static LoyaltyTierGroup createTierGroup(Id lpId) {
        LoyaltyTierGroup ltg = new LoyaltyTierGroup(
            Name = uniq('LTG'),
            LoyaltyProgramId = lpId,
            TierModel = 'Fixed',
            QpResetPeriod = 'Years',
            QpResetFrequency = 1,
            QpResetDate = Date.today()
        );
        insert ltg;
        return ltg;
    }

    private static void createTier(Id ltgId, Integer seq, Decimal minBal, String grade) {
        LoyaltyTier lt = new LoyaltyTier(
            Name = uniq('Tier' + String.valueOf(seq)),
            LoyaltyTierGroupId = ltgId,
            SequenceNumber = seq,
            MinimumEligibleBalance = minBal,
            Grade__c = grade
        );
        insert lt;
    }

    @IsTest
    static void test_batch_calculates_expected_grade_success() {
        LoyaltyProgram lp = createProgram();
        LoyaltyTierGroup ltg = createTierGroup(lp.Id);

        // 높은 등급이 먼저 매칭되어야 하므로 최소금액 큰 티어 포함
        createTier(ltg.Id, 1, 1000, '01');
        createTier(ltg.Id, 2, 0, '02');

        Contact cHigh = new Contact(
            LastName = uniq('High'),
            TierQualifyingSpend3Y__c = 1200,
            MemberDropDate__c = null
        );
        Contact cLow = new Contact(
            LastName = uniq('Low'),
            TierQualifyingSpend3Y__c = 100,
            MemberDropDate__c = null
        );
        insert new List<Contact>{ cHigh, cLow };

        Test.startTest();
        Database.executeBatch(new ExpectedGradeCalculationBatch(), 200);
        Test.stopTest();

        Map<Id, Contact> resultMap = new Map<Id, Contact>(
            [
                SELECT Id, ExpectedGrade__c
                FROM Contact
                WHERE Id IN :new Set<Id>{ cHigh.Id, cLow.Id }
            ]
        );

        System.assertEquals('01', resultMap.get(cHigh.Id).ExpectedGrade__c);
        System.assertEquals('02', resultMap.get(cLow.Id).ExpectedGrade__c);
    }

    @IsTest
    static void test_batch_when_no_loyalty_tier_does_not_update() {
        Contact c = new Contact(
            LastName = uniq('NoTier'),
            TierQualifyingSpend3Y__c = 9999,
            MemberDropDate__c = null,
            ExpectedGrade__c = null
        );
        insert c;

        Test.startTest();
        Database.executeBatch(new ExpectedGradeCalculationBatch(), 200);
        Test.stopTest();

        Contact refreshed = [SELECT Id, ExpectedGrade__c FROM Contact WHERE Id = :c.Id LIMIT 1];
        System.assertEquals(
            null,
            refreshed.ExpectedGrade__c,
            'Should remain unchanged when no LoyaltyTier exists'
        );
    }

    @IsTest
    static void test_batch_excludes_dropped_member() {
        LoyaltyProgram lp = createProgram();
        LoyaltyTierGroup ltg = createTierGroup(lp.Id);
        createTier(ltg.Id, 1, 0, '01');

        Contact dropped = new Contact(
            LastName = uniq('Dropped'),
            TierQualifyingSpend3Y__c = 5000,
            MemberDropDate__c = Date.today(),
            ExpectedGrade__c = null
        );
        insert dropped;

        Test.startTest();
        Database.executeBatch(new ExpectedGradeCalculationBatch(), 200);
        Test.stopTest();

        Contact refreshed = [
            SELECT Id, ExpectedGrade__c
            FROM Contact
            WHERE Id = :dropped.Id
            LIMIT 1
        ];
        System.assertEquals(
            null,
            refreshed.ExpectedGrade__c,
            'Dropped members must be excluded by start query'
        );
    }
}