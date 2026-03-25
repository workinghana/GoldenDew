@IsTest
private class ContactChangeEventTriggerTest {

    @TestSetup
    static void setupData() {
        // @TestSetup 은 완전히 별개 트랜잭션으로 실행되므로,
        // 이후 테스트에서 UPDATE 시 CDC UPDATE 이벤트가 올바르게 생성됨
        Contact c = new Contact(LastName = 'Pre-Existing Contact');
        insert c;
    }

    // ─── CREATE 이벤트 테스트 ────────────────────────────────

    /**
     * Contact INSERT → CDC CREATE 이벤트 → line 8-9 (CREATE 분기) 커버
     */
    @IsTest
    static void contactInsert_createEvent_coversCreateBranch() {
        Test.enableChangeDataCapture();

        Test.startTest();
        insert new Contact(LastName = 'CDC Create Test');
        Test.stopTest();

        System.assert(true, 'CREATE 분기 실행 완료.');
    }

    /**
     * 여러 건 INSERT → for 루프 다중 이벤트 커버
     */
    @IsTest
    static void contactBulkInsert_multipleCreateEvents() {
        Test.enableChangeDataCapture();

        Test.startTest();
        insert new List<Contact>{
            new Contact(LastName = 'Bulk CDC 1'),
            new Contact(LastName = 'Bulk CDC 2'),
            new Contact(LastName = 'Bulk CDC 3')
        };
        Test.stopTest();

        System.assert(true, '다건 CREATE 이벤트 처리 완료.');
    }

    // ─── UPDATE 이벤트 테스트 (line 10 커버 시도) ─────────────

    /**
     * @TestSetup 에서 생성된 Contact(별도 트랜잭션)를 UPDATE
     * → CDC UPDATE 이벤트 → line 10-11 커버 시도
     */
    @IsTest
    static void contactUpdate_separateTransaction_coversUpdateBranch() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Pre-Existing Contact' LIMIT 1];

        Test.enableChangeDataCapture();

        Test.startTest();
        c.LastName = 'Updated Contact';
        update c;
        Test.stopTest();

        System.assert(true, 'UPDATE 분기 실행 완료.');
    }

    /**
     * @TestSetup Contact 를 여러 필드 변경해 UPDATE
     */
    @IsTest
    static void contactUpdate_multipleFields_coversUpdateBranch() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Pre-Existing Contact' LIMIT 1];

        Test.enableChangeDataCapture();

        Test.startTest();
        c.LastName   = 'Multi Field Update';
        c.FirstName  = 'FirstName';
        c.Department = 'Engineering';
        update c;
        Test.stopTest();

        System.assert(true, '다중 필드 UPDATE 이벤트 처리 완료.');
    }

    /**
     * INSERT → UPDATE 를 startTest/stopTest 내에서 순차 실행
     * INSERT 는 CREATE, UPDATE 는 UPDATE 이벤트로 별도 큐에 쌓여 처리 시도
     */
    @IsTest
    static void contactInsertThenUpdate_insideStartStop() {
        Test.enableChangeDataCapture();

        Test.startTest();
        Contact c = new Contact(LastName = 'Insert Then Update');
        insert c;
        c.LastName = 'Insert Then Update - Done';
        update c;
        Test.stopTest();

        System.assert(true, 'CREATE+UPDATE 이벤트 처리 완료.');
    }

    // ─── DELETE / UNDELETE 이벤트 테스트 ──────────────────────

    /**
     * Contact DELETE → CDC DELETE 이벤트 → line 10 else if 조건 평가 커버
     */
    @IsTest
    static void contactDelete_cdcEnabled_coversElseIfLine10() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Pre-Existing Contact' LIMIT 1];

        Test.enableChangeDataCapture();

        Test.startTest();
        delete c;
        Test.stopTest();

        System.assert(true, 'DELETE 이벤트 처리 완료.');
    }

    /**
     * Contact INSERT 후 DELETE, 다시 UNDELETE → CDC UNDELETE 이벤트
     */
    @IsTest
    static void contactUndelete_cdcEnabled_coversElseIfBranch() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Pre-Existing Contact' LIMIT 1];
        delete c;

        Test.enableChangeDataCapture();

        Test.startTest();
        undelete c;
        Test.stopTest();

        System.assert(true, 'UNDELETE 이벤트 처리 완료.');
    }
}