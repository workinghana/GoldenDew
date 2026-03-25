@IsTest
private class PointResDtoTest {
    // =========================================================
    // AvailablePointResponse
    // AggregateResult은 직접 생성 불가 → Account aggregate를 proxy로 사용
    // =========================================================

    @IsTest
    static void availablePointResponse_nonNullTotal_mapsCorrectly() {
        Account acc = new Account(
            Name = 'ARTestTech',
            Industry = 'Technology',
            AnnualRevenue = 500
        );
        insert acc;

        AggregateResult ar = [
            SELECT Industry pointTypeCode, SUM(AnnualRevenue) totalPoints
            FROM Account
            WHERE Id = :acc.Id
            GROUP BY Industry
        ][0];

        Test.startTest();
        PointResDto.AvailablePointResponse resp = new PointResDto.AvailablePointResponse(ar);
        Test.stopTest();

        System.assertEquals('Technology', resp.CD_TYPE_POINT, 'pointTypeCode → CD_TYPE_POINT');
        System.assertEquals(500, resp.points, 'totalPoints → points');
    }

    @IsTest
    static void availablePointResponse_nullTotal_returnsZero() {
        // AnnualRevenue 미설정 → SUM = null → points = 0
        Account acc = new Account(Name = 'ARTestNull', Industry = 'Education');
        insert acc;

        AggregateResult ar = [
            SELECT Industry pointTypeCode, SUM(AnnualRevenue) totalPoints
            FROM Account
            WHERE Id = :acc.Id
            GROUP BY Industry
        ][0];

        Test.startTest();
        PointResDto.AvailablePointResponse resp = new PointResDto.AvailablePointResponse(ar);
        Test.stopTest();

        System.assertEquals(0, resp.points, 'null totalPoints → 0');
    }

    // =========================================================
    // CreditPointResponse — null LoyaltyLedger
    // =========================================================

    @IsTest
    static void creditPointResponse_nullLl_allDefaults() {
        Test.startTest();
        PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(null);
        Test.stopTest();

        System.assertEquals('', resp.YM_CREATE);
        System.assertEquals('', resp.NM_TYPE_POINT);
        System.assertEquals('', resp.NM_TYPE_SAVE);
        System.assertEquals('', resp.DT_SAVE_PLAN);
        System.assertEquals(0, resp.PT_SAVE_PLAN);
        System.assertEquals('', resp.DT_SAVE);
        System.assertEquals(0, resp.PT_SAVE);
        System.assertEquals(0, resp.PT_USE);
        System.assertEquals(0, resp.PT_DESTROY);
        System.assertEquals('', resp.DT_LIMIT_START);
        System.assertEquals('', resp.DT_LIMIT_END);
        System.assertEquals('', resp.DT_DESTROY_PLAN);
        System.assertEquals('', resp.DT_DESTROY_DEL_SALE);
        System.assertEquals('', resp.NO_SAL);
        System.assertEquals(0, resp.AM_SAL);
        System.assertEquals(0, resp.PT_TARGET);
        System.assertEquals(0, resp.PT_USE_SALE);
    }

    // =========================================================
    // CreditPointResponse — 날짜/포인트 필드 (TransactionJournalId = null)
    // =========================================================

    @IsTest
    static void creditPointResponse_withDates_mapsDateAndPointFields() {
        LoyaltyLedger ll = new LoyaltyLedger();
        ll.ActivityDate = Datetime.newInstanceGmt(2025, 6, 15, 0, 0, 0);
        ll.Points = 500;
        ll.ExpiryDate = Date.newInstance(2026, 3, 1);
        // TransactionJournalId = null → NM_TYPE_SAVE='', NO_SAL='', AM_SAL=0
        // LoyaltyPgmCrcySubtypeId = null → NM_TYPE_POINT=''

        Test.startTest();
        PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);
        Test.stopTest();

        System.assertEquals('202506', resp.YM_CREATE, 'ActivityDate yyyyMM');
        System.assertEquals('20250615', resp.DT_SAVE, 'ActivityDate yyyyMMdd');
        System.assertEquals(500, resp.PT_SAVE, 'Points → PT_SAVE');
        System.assertEquals('20260228', resp.DT_LIMIT_END, 'ExpiryDate-1 yyyyMMdd (2026-02-28)');
        System.assertEquals('20260301', resp.DT_DESTROY_PLAN, 'ExpiryDate yyyyMMdd');
        System.assertEquals('', resp.NM_TYPE_SAVE, 'TransactionJournalId null → 빈 문자열');
        System.assertEquals('', resp.NM_TYPE_POINT, 'LoyaltyPgmCrcySubtypeId null → 빈 문자열');
        System.assertEquals('', resp.NO_SAL, 'OrderId null → 빈 문자열');
        System.assertEquals(0, resp.AM_SAL, 'Amount null → 0');
    }

    @IsTest
    static void creditPointResponse_withEscrowDate_mapsPlanFields() {
        LoyaltyLedger ll = new LoyaltyLedger();
        ll.ActivityDate = Datetime.newInstanceGmt(2025, 1, 10, 0, 0, 0);
        ll.Points = 200;
        ll.EscrowPointsCreditDate = Date.newInstance(2025, 2, 1);

        Test.startTest();
        PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);
        Test.stopTest();

        System.assertNotEquals(
            '',
            resp.DT_SAVE_PLAN,
            'EscrowPointsCreditDate 설정 → DT_SAVE_PLAN 비어있지 않음'
        );
        System.assertEquals(200, resp.PT_SAVE_PLAN, 'Points → PT_SAVE_PLAN');
    }

    // =========================================================
    // CreditPointResponse — POINT_JOURNAL_SUB_TYPE_MAP 조회
    // (TransactionJournalId + JournalSubTypeId 모두 non-null)
    // =========================================================

    @IsTest
    static void creditPointResponse_knownSubTypeName_mapsToKorean() {
        // 유효한 Salesforce ID를 proxy로 사용
        Contact c = new Contact(LastName = 'PointDtoProxy');
        insert c;
        Id fakeId = c.Id;

        JournalSubType jst = new JournalSubType(Name = 'Purchase Accrual');
        TransactionJournal tj = new TransactionJournal();
        tj.JournalSubTypeId = fakeId;
        tj.JournalSubType = jst;

        LoyaltyLedger ll = new LoyaltyLedger();
        ll.TransactionJournalId = fakeId;
        ll.TransactionJournal = tj;

        Test.startTest();
        PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);
        Test.stopTest();

        System.assertEquals(
            '구매 시 포인트 지급',
            resp.NM_TYPE_SAVE,
            'Purchase Accrual → 구매 시 포인트 지급'
        );
    }

    @IsTest
    static void creditPointResponse_unknownSubTypeName_returnsOriginal() {
        Contact c = new Contact(LastName = 'PointDtoProxy2');
        insert c;
        Id fakeId = c.Id;

        JournalSubType jst = new JournalSubType(Name = 'UnknownType');
        TransactionJournal tj = new TransactionJournal();
        tj.JournalSubTypeId = fakeId;
        tj.JournalSubType = jst;

        LoyaltyLedger ll = new LoyaltyLedger();
        ll.TransactionJournalId = fakeId;
        ll.TransactionJournal = tj;

        Test.startTest();
        PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);
        Test.stopTest();

        System.assertEquals('UnknownType', resp.NM_TYPE_SAVE, '미정의 타입 → 원본 그대로');
    }

    @IsTest
    static void creditPointResponse_withOrderInfo_mapsNoSalAndAmSal() {
        Contact c = new Contact(LastName = 'PointDtoProxy3');
        insert c;
        Id fakeId = c.Id;

        Order fakeOrder = new Order(SaleNo__c = 'SAL-999', ActualPaymentAmount__c = 75000);
        TransactionJournal tj = new TransactionJournal();
        tj.JournalSubTypeId = fakeId;
        tj.JournalSubType = new JournalSubType(Name = 'Manual Points Credit');
        tj.OrderId = fakeId;
        tj.Order = fakeOrder;

        LoyaltyLedger ll = new LoyaltyLedger();
        ll.TransactionJournalId = fakeId;
        ll.TransactionJournal = tj;

        Test.startTest();
        PointResDto.CreditPointResponse resp = new PointResDto.CreditPointResponse(ll);
        Test.stopTest();

        System.assertEquals('SAL-999', resp.NO_SAL, 'SaleNo__c → NO_SAL');
        System.assertEquals(75000, resp.AM_SAL, 'ActualPaymentAmount__c → AM_SAL');
        System.assertEquals(
            '포인트 수동 지급',
            resp.NM_TYPE_SAVE,
            'Manual Points Credit → 한국어 매핑'
        );
    }

    // =========================================================
    // DebitPointResponse
    // llt.CreatedDate 는 non-inserted SObject에서 null → NPE
    // =========================================================

    @IsTest
    static void debitPointResponse_nonInsertedLlt_throwsDueToNullCreatedDate() {
        LoyaltyLedgerTraceability llt = new LoyaltyLedgerTraceability();

        Boolean threw = false;
        try {
            PointResDto.DebitPointResponse resp = new PointResDto.DebitPointResponse(llt);
        } catch (Exception e) {
            threw = true;
        }

        System.assert(threw, 'CreatedDate null → NPE 예상');
    }
}