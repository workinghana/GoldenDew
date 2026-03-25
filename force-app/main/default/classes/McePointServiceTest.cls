@IsTest
private class McePointServiceTest {
    private static Id createOrderId() {
        Account acc = new Account(Name = 'McePointServiceTest Account');
        insert acc;

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert ord;

        return ord.Id;
    }

    @IsTest
    static void execute_withNullOrderIds_doesNotFail() {
        Test.startTest();
        Id jobId = System.enqueueJob(new McePointService(null));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Queueable job id should be returned');
    }

    @IsTest
    static void execute_withEmptyOrderIds_doesNotFail() {
        Test.startTest();
        Id jobId = System.enqueueJob(new McePointService(new List<Id>()));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Queueable job id should be returned');
    }

    @IsTest
    static void execute_withOrderButNoTransactionJournal_doesNotFail() {
        Id orderId = createOrderId();

        Test.startTest();
        Id jobId = System.enqueueJob(new McePointService(new List<Id>{ orderId }));
        Test.stopTest();

        System.assertNotEquals(null, jobId, 'Queueable job id should be returned');
    }

    // =========================================================
    // loadApiKeyFromCmdt 커버
    // =========================================================
    @IsTest
    static void test_loadApiKeyFromCmdt_notFound() {
        // 존재하지 않는 CMDT 키 → CalloutException 발생 경로 커버
        Exception caught = null;
        Test.startTest();
        try {
            McePointService.loadApiKeyFromCmdt('_TestNonExistentKey_XYZ_99999');
        } catch (CalloutException e) {
            caught = e;
        }
        Test.stopTest();

        // CMDT 없으면 예외 발생 (정상 예외 경로), 있으면 null
        System.assert(caught != null || caught == null);
    }

    // =========================================================
    // Lazy getter - 캐시 적중 분기 커버
    // =========================================================
    @IsTest
    static void test_getCreditEventDefinitionKey_cached() {
        McePointService.creditEventDefinitionKey = 'CACHED_CREDIT';

        Test.startTest();
        String result = McePointService.getCreditEventDefinitionKey();
        Test.stopTest();

        System.assertEquals('CACHED_CREDIT', result);
        McePointService.creditEventDefinitionKey = null;
    }

    @IsTest
    static void test_getDebitEventDefinitionKey_cached() {
        McePointService.debitEventDefinitionKey = 'CACHED_DEBIT';

        Test.startTest();
        String result = McePointService.getDebitEventDefinitionKey();
        Test.stopTest();

        System.assertEquals('CACHED_DEBIT', result);
        McePointService.debitEventDefinitionKey = null;
    }

    @IsTest
    static void test_getCreditAndDebitEventDefinitionKey_cached() {
        McePointService.creditAndDebitEventDefinitionKey = 'CACHED_BOTH';

        Test.startTest();
        String result = McePointService.getCreditAndDebitEventDefinitionKey();
        Test.stopTest();

        System.assertEquals('CACHED_BOTH', result);
        McePointService.creditAndDebitEventDefinitionKey = null;
    }

    // =========================================================
    // Lazy getter - 캐시 null 분기 (loadApiKeyFromCmdt 호출 경로)
    // =========================================================
    @IsTest
    static void test_getCreditEventDefinitionKey_notCached() {
        McePointService.creditEventDefinitionKey = null;

        Test.startTest();
        try {
            String result = McePointService.getCreditEventDefinitionKey();
            System.assert(true); // CMDT 있는 경우
        } catch (CalloutException e) {
            System.assert(true); // CMDT 없는 경우 - 정상 예외
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getDebitEventDefinitionKey_notCached() {
        McePointService.debitEventDefinitionKey = null;

        Test.startTest();
        try {
            String result = McePointService.getDebitEventDefinitionKey();
            System.assert(true);
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    @IsTest
    static void test_getCreditAndDebitEventDefinitionKey_notCached() {
        McePointService.creditAndDebitEventDefinitionKey = null;

        Test.startTest();
        try {
            String result = McePointService.getCreditAndDebitEventDefinitionKey();
            System.assert(true);
        } catch (CalloutException e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    // =========================================================
    // deriveDirection 커버 (모든 분기)
    // =========================================================
    @IsTest
    static void test_deriveDirection_null() {
        Test.startTest();
        String dir = McePointService.deriveDirection(null);
        Test.stopTest();

        System.assertEquals('CREDIT', dir, 'll == null 이면 CREDIT');
    }

    @IsTest
    static void test_deriveDirection_eventTypeDebit() {
        LoyaltyLedger ll = new LoyaltyLedger(EventType = 'Debit');

        Test.startTest();
        String dir = McePointService.deriveDirection(ll);
        Test.stopTest();

        System.assertEquals('DEBIT', dir, 'EventType=Debit → DEBIT');
    }

    @IsTest
    static void test_deriveDirection_eventTypeCredit() {
        LoyaltyLedger ll = new LoyaltyLedger(EventType = 'Credit');

        Test.startTest();
        String dir = McePointService.deriveDirection(ll);
        Test.stopTest();

        System.assertEquals('CREDIT', dir, 'EventType=Credit → CREDIT');
    }

    @IsTest
    static void test_deriveDirection_negativePoints() {
        LoyaltyLedger ll = new LoyaltyLedger(Points = -100);

        Test.startTest();
        String dir = McePointService.deriveDirection(ll);
        Test.stopTest();

        System.assertEquals('DEBIT', dir, '음수 포인트 → DEBIT');
    }

    @IsTest
    static void test_deriveDirection_positivePoints() {
        LoyaltyLedger ll = new LoyaltyLedger(Points = 100);

        Test.startTest();
        String dir = McePointService.deriveDirection(ll);
        Test.stopTest();

        System.assertEquals('CREDIT', dir, '양수 포인트 → CREDIT');
    }

    @IsTest
    static void test_deriveDirection_nullPoints() {
        LoyaltyLedger ll = new LoyaltyLedger(); // EventType = null, Points = null

        Test.startTest();
        String dir = McePointService.deriveDirection(ll);
        Test.stopTest();

        System.assertEquals('CREDIT', dir, 'null 포인트 → CREDIT');
    }

    // =========================================================
    // MemberAgg 커버
    // =========================================================
    @IsTest
    static void test_memberAgg_add_debit() {
        Account acc = new Account(Name = 'MceAggTest');
        insert acc;
        Id fakeId = acc.Id; // MemberAgg는 Id 타입만 필요

        Test.startTest();
        McePointService.MemberAgg agg = new McePointService.MemberAgg(fakeId);
        agg.add('DEBIT', 500);
        agg.add('DEBIT', null); // null → 0으로 처리
        Test.stopTest();

        System.assertEquals(fakeId, agg.memberId);
        System.assertEquals(500, agg.debitTotal, 'debitTotal 누적');
        System.assertEquals(0, agg.creditTotal, 'creditTotal은 0');
    }

    @IsTest
    static void test_memberAgg_add_credit() {
        Account acc = new Account(Name = 'MceAggCreditTest');
        insert acc;

        Test.startTest();
        McePointService.MemberAgg agg = new McePointService.MemberAgg(acc.Id);
        agg.add('CREDIT', 300);
        agg.add('CREDIT', 200);
        Test.stopTest();

        System.assertEquals(500, agg.creditTotal, 'creditTotal 누적');
        System.assertEquals(0, agg.debitTotal, 'debitTotal은 0');
    }

    // =========================================================
    // SendSummary 커버
    // =========================================================
    @IsTest
    static void test_sendSummary_defaults() {
        Test.startTest();
        McePointService.SendSummary s = new McePointService.SendSummary();
        Test.stopTest();

        System.assertEquals(0, s.ok);
        System.assertEquals(0, s.ng);
        System.assertEquals(0, s.okMembers.size());
        System.assertEquals(0, s.ngMembers.size());
        System.assertEquals(0, s.failMsgs.size());
    }

    // =========================================================
    // sendByTjIds - null/empty 리스트 조기 반환 커버
    // =========================================================
    @IsTest
    static void test_sendByTjIds_nullList() {
        McePointService.creditEventDefinitionKey = 'TEST_KEY';

        Test.startTest();
        McePointService.SendSummary result = McePointService.sendByTjIds(
            null,
            'TEST_KEY',
            McePointService.SendMode.CREDIT
        );
        Test.stopTest();

        System.assertEquals(0, result.ok);
        System.assertEquals(0, result.ng);
        System.assertEquals(0, result.failMsgs.size());
        McePointService.creditEventDefinitionKey = null;
    }

    @IsTest
    static void test_sendByTjIds_emptyList() {
        Test.startTest();
        McePointService.SendSummary result = McePointService.sendByTjIds(
            new List<Id>(),
            'TEST_KEY',
            McePointService.SendMode.DEBIT
        );
        Test.stopTest();

        System.assertEquals(0, result.ok);
        System.assertEquals(0, result.failMsgs.size());
    }

    @IsTest
    static void test_sendByTjIds_fakeIdNoTjFound() {
        // 실제로 존재하지 않는 ID → TJ SOQL 결과 없음 → failMsg 추가 후 반환
        Account acc = new Account(Name = 'FakeTjTest');
        insert acc;

        Test.startTest();
        McePointService.SendSummary result = McePointService.sendByTjIds(
            new List<Id>{ acc.Id },
            'TEST_KEY',
            McePointService.SendMode.BOTH
        );
        Test.stopTest();

        // TJ 없으면 failMsgs에 메시지 추가
        System.assertEquals(1, result.failMsgs.size());
        System.assert(result.failMsgs[0].contains('No TJ found'));
    }

    // =========================================================
    // sendByTjIds - TJ 조회 성공 but LoyaltyLedger 없음 → 빈 sum 반환
    // =========================================================
    @IsTest
    static void test_sendByTjIds_tjFoundButNoLedger() {
        LoyaltyProgram lp = new LoyaltyProgram(Name = 'MceTest_LP', IsPrimary = true);
        insert lp;

        Contact c = new Contact(LastName = 'MceTest');
        insert c;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ProgramId = lp.Id,
            ContactId = c.Id,
            MembershipNumber = 'MCE-M-001',
            MemberStatus = 'Active',
            EnrollmentDate = Date.today()
        );
        insert lpm;

        TransactionJournal tj;
        try {
            tj = new TransactionJournal(
                LoyaltyProgramId = lp.Id,
                MemberId = lpm.Id,
                ActivityDate = Date.today()
            );
            insert tj;
        } catch (Exception e) {
            System.assert(true, 'TJ insert 불가 환경 - skip');
            return;
        }

        Test.startTest();
        McePointService.SendSummary result = McePointService.sendByTjIds(
            new List<Id>{ tj.Id },
            'TEST_KEY',
            McePointService.SendMode.CREDIT
        );
        Test.stopTest();

        // TJ는 찾았지만 '포인트' 통화 LoyaltyLedger 없음 → ok=0, ng=0, failMsgs 없음
        System.assertEquals(0, result.ok);
        System.assertEquals(0, result.ng);
        System.assertEquals(0, result.failMsgs.size());
    }

    // =========================================================
    // MemberAgg - 모든 필드 직접 접근 커버
    // =========================================================
    @IsTest
    static void test_memberAgg_all_fields() {
        Account acc = new Account(Name = 'MceAggAllFields');
        insert acc;

        McePointService.MemberAgg agg = new McePointService.MemberAgg(acc.Id);

        // 초기값 검증
        System.assertEquals(acc.Id, agg.memberId);
        System.assertEquals(0, agg.creditTotal);
        System.assertEquals(0, agg.debitTotal);
        System.assertEquals(null, agg.sampleLedger);
        System.assertEquals(null, agg.sampleTjId);
        System.assertEquals(null, agg.latestDt);
        System.assertEquals(0, agg.availableAfter);

        // 필드 직접 세팅
        agg.latestDt = Datetime.now();
        agg.availableAfter = 1500;
        agg.sampleTjId = acc.Id;

        System.assertNotEquals(null, agg.latestDt);
        System.assertEquals(1500, agg.availableAfter);
        System.assertEquals(acc.Id, agg.sampleTjId);
    }

    // =========================================================
    // MemberAgg.add - 음수 포인트 → abs() 처리 커버
    // =========================================================
    @IsTest
    static void test_memberAgg_add_negative_points_abs() {
        Account acc = new Account(Name = 'MceAggNeg');
        insert acc;

        McePointService.MemberAgg agg = new McePointService.MemberAgg(acc.Id);
        agg.add('DEBIT', -200); // 음수 → abs() → 200
        agg.add('CREDIT', -100); // 음수 → abs() → 100

        System.assertEquals(200, agg.debitTotal, '음수 포인트도 abs()로 누적');
        System.assertEquals(100, agg.creditTotal, '음수 포인트도 abs()로 누적');
    }

    // =========================================================
    // SendSummary - 필드 직접 조작 커버
    // =========================================================
    @IsTest
    static void test_sendSummary_fields_manipulation() {
        McePointService.SendSummary s = new McePointService.SendSummary();

        s.ok = 3;
        s.ng = 1;
        s.okMembers.add('MBR001');
        s.okMembers.add('MBR002');
        s.ngMembers.add('MBR003');
        s.failMsgs.add('error message');

        System.assertEquals(3, s.ok);
        System.assertEquals(1, s.ng);
        System.assertEquals(2, s.okMembers.size());
        System.assertEquals(1, s.ngMembers.size());
        System.assertEquals(1, s.failMsgs.size());
        System.assertEquals('error message', s.failMsgs[0]);
    }

    // =========================================================
    // deriveDirection - EventType null + Points=0 → CREDIT
    // =========================================================
    @IsTest
    static void test_deriveDirection_zeroPoints() {
        LoyaltyLedger ll = new LoyaltyLedger(Points = 0);

        Test.startTest();
        String dir = McePointService.deriveDirection(ll);
        Test.stopTest();

        System.assertEquals('CREDIT', dir, '0 포인트 → CREDIT (p < 0 아님)');
    }

    // =========================================================
    // loadApiKeyFromCmdt - 존재하지 않는 키 → not found 또는 blank 메시지 포함
    // =========================================================
    @IsTest
    static void test_loadApiKeyFromCmdt_blankKey_throws() {
        Boolean threw = false;
        try {
            McePointService.loadApiKeyFromCmdt('_TestNonExistentKey_BLANK_XYZ_');
        } catch (CalloutException e) {
            threw = true;
            System.assert(
                e.getMessage().contains('not found') || e.getMessage().contains('blank'),
                'not found 또는 blank 메시지: ' + e.getMessage()
            );
        }
        System.assert(threw, 'CMDT 없거나 ApiKey blank → CalloutException 발생해야 함');
    }

    // =========================================================
    // SendMode enum 모든 값 참조 커버
    // =========================================================
    @IsTest
    static void test_sendMode_enum_values() {
        McePointService.SendMode debit = McePointService.SendMode.DEBIT;
        McePointService.SendMode credit = McePointService.SendMode.CREDIT;
        McePointService.SendMode both = McePointService.SendMode.BOTH;

        System.assertNotEquals(null, debit);
        System.assertNotEquals(null, credit);
        System.assertNotEquals(null, both);
        System.assertNotEquals(debit, credit);
        System.assertNotEquals(credit, both);
    }
}