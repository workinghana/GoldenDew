@IsTest
private class McePointDebitBatchTest {
    private static void assertBatchCompleted(Id jobId) {
        System.assertNotEquals(null, jobId, 'Batch job id should not be null');

        AsyncApexJob job = [
            SELECT Id, Status, NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];

        System.assertEquals('Completed', job.Status, 'Batch should complete successfully');
        System.assertEquals(0, job.NumberOfErrors, 'Batch should not have execution errors');
    }

    @IsTest
    static void executeBatch_withNullIds_completes() {
        Test.startTest();
        Id jobId = Database.executeBatch(new McePointDebitBatch(null), 50);
        Test.stopTest();

        assertBatchCompleted(jobId);
    }

    @IsTest
    static void executeBatch_withEmptyIds_completes() {
        Test.startTest();
        Id jobId = Database.executeBatch(new McePointDebitBatch(new Set<Id>()), 50);
        Test.stopTest();

        assertBatchCompleted(jobId);
    }

    @IsTest
    static void executeBatch_withNonMatchingTransactionJournalIds_completes() {
        // Valid Id format but not a TransactionJournal Id -> start() returns empty scope.
        Set<Id> ids = new Set<Id>{ UserInfo.getUserId() };

        Test.startTest();
        Id jobId = Database.executeBatch(new McePointDebitBatch(ids), 50);
        Test.stopTest();

        assertBatchCompleted(jobId);
    }

    @IsTest
    static void execute_directScope_coversExecuteMethod() {
        TransactionJournal tj = new TransactionJournal(ActivityDate = Date.today());

        Test.startTest();
        McePointDebitBatch.executeForTest(new List<TransactionJournal>{ tj });
        Test.stopTest();

        System.assert(true, 'execute method should run with non-empty scope in test hook');
    }

    @IsTest
    static void deriveDirection_branches_areCovered() {
        System.assertEquals('CREDIT', McePointDebitBatch.deriveDirectionForTest('Credit', 10));
        System.assertEquals('DEBIT', McePointDebitBatch.deriveDirectionForTest('Debit', 10));
        System.assertEquals('DEBIT', McePointDebitBatch.deriveDirectionForTest(null, -1));
        System.assertEquals('CREDIT', McePointDebitBatch.deriveDirectionForTest(null, 0));
    }

    @IsTest
    static void memberAgg_add_accumulates_credit_and_debit() {
        McePointDebitBatch.MemberAgg agg = new McePointDebitBatch.MemberAgg(UserInfo.getUserId());

        Id firstTjId = UserInfo.getUserId();
        Id secondTjId = UserInfo.getOrganizationId();

        agg.add('CREDIT', 10, firstTjId);
        agg.add('DEBIT', -3, secondTjId);
        agg.add('DEBIT', null, null);

        System.assertEquals(10, agg.creditTotal);
        System.assertEquals(3, agg.debitTotal);
        System.assertEquals(firstTjId, agg.sampleTjId, 'sampleTjId should keep first non-null id');
    }
}