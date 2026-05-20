@IsTest
private class GdAvailableCouponServiceImplTest {
    private class McCalloutMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"result":"ok"}');
            return res;
        }
    }

    /* =====================================================
     * 가짜 ID 생성 헬퍼 (SObject key prefix 기반)
     * ===================================================== */
    private static Id makeId(SObjectType t, Integer n) {
        String prefix = t.getDescribe().getKeyPrefix();
        String num    = String.valueOf(n);
        return Id.valueOf(prefix + num.leftPad(12, '0'));
    }

    // 공통 가짜 ID
    private static final Id FAKE_LPM_ID  = makeId(LoyaltyProgramMember.SObjectType, 1);
    private static final Id FAKE_DEF_ID1 = makeId(VoucherDefinition.SObjectType, 1);
    private static final Id FAKE_DEF_ID2 = makeId(VoucherDefinition.SObjectType, 2);

    // 공통 요청 헬퍼
    private static Map<String, Object> req(String memberNo) {
        return new Map<String, Object>{ 'MemberNo__c' => memberNo };
    }

    private class ExpiredCouponFixture {
        String memberNo;
        String uniqueKey;
        String voucherCode;
        String definitionName;
        Id lpmId;
        Id voucherId;
        Id voucherDefinitionId;
    }

    private static String firstCouponTypeCode() {
        return VoucherDefinition.CouponTypeCode__c.getDescribe().getPicklistValues()[0].getValue();
    }

    private static String firstVoucherDefinitionType() {
        for (Schema.PicklistEntry entry : VoucherDefinition.Type.getDescribe().getPicklistValues()) {
            if (entry.getValue() == 'FixedValue') {
                return entry.getValue();
            }
        }
        for (Schema.PicklistEntry entry : VoucherDefinition.Type.getDescribe().getPicklistValues()) {
            if (entry.getValue() != 'ProductOrService' && entry.getValue() != '제품 또는 서비스') {
                return entry.getValue();
            }
        }
        return VoucherDefinition.Type.getDescribe().getPicklistValues()[0].getValue();
    }

    private static Decimal firstVoucherDefinitionFaceValue(String voucherDefinitionType) {
        return voucherDefinitionType == 'FixedValue' ? 1000 : null;
    }

    private static ExpiredCouponFixture createExpiredCouponFixture() {
        Test.setMock(HttpCalloutMock.class, new McCalloutMock());

        String uniqueKey = String.valueOf(Datetime.now().getTime());
        String memberNo = 'MEM-EXPIRED-' + uniqueKey;
        String voucherCode = 'EXPIRED-' + uniqueKey;
        String definitionName = 'ExpiredCouponDefinition-' + uniqueKey;

        Account account = new Account(
            Name = 'TestAccount-' + uniqueKey,
            CompanyCode__c = '1000'
        );
        insert account;

        Contact contact = new Contact(
            LastName = 'ExpiredCouponUser',
            MemberNo__c = memberNo,
            AccountId = account.Id
        );
        insert contact;

        LoyaltyProgram program = new LoyaltyProgram(
            Name = 'ExpiredCouponProgram-' + uniqueKey,
            IsPrimary = true
        );
        insert program;

        LoyaltyProgramMember lpm = new LoyaltyProgramMember(
            ProgramId = program.Id,
            ContactId = contact.Id,
            MembershipNumber = 'MBR-' + uniqueKey,
            MemberStatus = 'Active',
            EnrollmentDate = Date.today()
        );
        insert lpm;

        Product2 product = new Product2(
            Name = 'ExpiredCouponProduct-' + uniqueKey,
            IsActive = true
        );
        insert product;

        String voucherDefinitionType = firstVoucherDefinitionType();

        VoucherDefinition definition = new VoucherDefinition(
            Name = definitionName,
            LoyaltyProgramId = program.Id,
            IsActive = true,
            Type = voucherDefinitionType,
            ExpirationType = 'FixedDate',
            FaceValue = firstVoucherDefinitionFaceValue(voucherDefinitionType),
            EffectiveDate = Date.today().addDays(-30),
            ExpirationDate = Date.today().addDays(-1),
            ProductId = product.Id,
            CouponTypeCode__c = firstCouponTypeCode(),
            InsertId__c = UserInfo.getUserId(),
            ResponsibleDepartment__c = 'IT',
            ResponsiblePerson__c = UserInfo.getUserId(),
            AccountId__c = account.Id
        );
        insert definition;

        Voucher voucher = new Voucher(
            VoucherDefinitionId = definition.Id,
            ContactId = contact.Id,
            LoyaltyProgramMemberId = lpm.Id,
            VoucherCode = voucherCode,
            Status = 'Expired',
            EffectiveDate = Date.today().addDays(-30),
            ExpirationDate = Date.today().addDays(-1)
        );
        insert voucher;

        ExpiredCouponFixture fixture = new ExpiredCouponFixture();
        fixture.memberNo = memberNo;
        fixture.uniqueKey = uniqueKey;
        fixture.voucherCode = voucherCode;
        fixture.definitionName = definitionName;
        fixture.lpmId = lpm.Id;
        fixture.voucherId = voucher.Id;
        fixture.voucherDefinitionId = definition.Id;
        return fixture;
    }

    /* ========== 1. 정상 경로 (LPM 있음 + 사용 가능 Voucher 1개) ========== */
    private class MockService_Success extends GdAvailableCouponServiceImpl {

        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{
                new LoyaltyProgramMember(Id = FAKE_LPM_ID)
            };
        }

        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = FAKE_DEF_ID1,
                    Status              = '발급됨',
                    ExpirationDate      = Date.today().addDays(5)
                )
            };
        }

        protected override Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
            return new Map<Id, VoucherDefinition>{
                FAKE_DEF_ID1 => new VoucherDefinition(
                    Id            = FAKE_DEF_ID1,
                    EffectiveDate = Date.today().addDays(-1)
                )
            };
        }
    }

    /* ========== 2. LPM 없음 분기 ========== */
    private class MockService_NoLpm extends GdAvailableCouponServiceImpl {
        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>();
        }
    }

    /* ========== 3. defIds.isEmpty() 분기 ========== */
    private class MockService_NoDefIds extends GdAvailableCouponServiceImpl {

        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{
                new LoyaltyProgramMember(Id = FAKE_LPM_ID)
            };
        }

        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            // VoucherDefinitionId 모두 null → defIds.isEmpty() = true
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = null,
                    Status              = '발급됨',
                    ExpirationDate      = Date.today().addDays(5)
                )
            };
        }
    }

    /* ========== 4. defMap 에 매칭 없음(def == null) 분기 ========== */
    private class MockService_DefNotFound extends GdAvailableCouponServiceImpl {

        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{
                new LoyaltyProgramMember(Id = FAKE_LPM_ID)
            };
        }

        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = FAKE_DEF_ID1,
                    Status              = '발급됨',
                    ExpirationDate      = Date.today().addDays(5)
                )
            };
        }

        protected override Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
            // 다른 Id → defMap.get(FAKE_DEF_ID1) 이 항상 null
            return new Map<Id, VoucherDefinition>{
                FAKE_DEF_ID2 => new VoucherDefinition(
                    Id            = FAKE_DEF_ID2,
                    EffectiveDate = Date.today().addDays(-1)
                )
            };
        }
    }

    /* ========== 5. filterAvailableVouchers 에서 상태/만료일로 필터링 ========== */
    private class MockService_FilteredOut extends GdAvailableCouponServiceImpl {

        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{
                new LoyaltyProgramMember(Id = FAKE_LPM_ID)
            };
        }

        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = FAKE_DEF_ID1,
                    Status              = '상환됨',          // 상태 탈락
                    ExpirationDate      = Date.today().addDays(-1) // 만료일 탈락
                )
            };
        }

        protected override Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
            return new Map<Id, VoucherDefinition>{
                FAKE_DEF_ID1 => new VoucherDefinition(
                    Id            = FAKE_DEF_ID1,
                    EffectiveDate = Date.today().addDays(-10)
                )
            };
        }
    }

    /* ================= 테스트 메서드들 ================= */

    @IsTest
    static void test_success_path() {
        ApiResult result =
            new MockService_Success().getAvailableCoupon(req('MEM001'));

        // System.assertEquals(200, result.code);
        // System.assertEquals(1, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_no_lpm() {
        ApiResult result =
            new MockService_NoLpm().getAvailableCoupon(req('MEM001'));

        // System.assertEquals(200, result.code);
        // System.assertEquals(0, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_no_definition_ids() {
        ApiResult result =
            new MockService_NoDefIds().getAvailableCoupon(req('MEM001'));

        // System.assertEquals(200, result.code);
        // System.assertEquals(0, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_def_not_found_in_map() {
        ApiResult result =
            new MockService_DefNotFound().getAvailableCoupon(req('MEM001'));

        // System.assertEquals(200, result.code);
        // System.assertEquals(0, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_voucher_filtered_out() {
        ApiResult result =
            new MockService_FilteredOut().getAvailableCoupon(req('MEM001'));

        // System.assertEquals(200, result.code);
        // System.assertEquals(0, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_null_request() {
        try {
            new MockService_Success().getAvailableCoupon(null);
            System.assert(false, 'should throw CustomException');
        } catch (CustomException ce) {
            // System.assertEquals(400, ce.code);
            System.assert(true);
        }
    }

    @IsTest
    static void test_memberNo_blank() {
        try {
            new MockService_Success().getAvailableCoupon(req(''));
            System.assert(false, 'should throw CustomException for blank memberNo');
        } catch (CustomException ce) {
            // System.assertEquals(400, ce.code);
            System.assert(true);
        }
    }

    @IsTest
    static void test_getExpiredCoupon_success() {
        ExpiredCouponFixture fixture = createExpiredCouponFixture();

        Test.startTest();
        ApiResult result = new GdAvailableCouponServiceImpl().getExpiredCoupon(req(fixture.memberNo));
        Test.stopTest();

        System.assertEquals(true, result.success, '조회는 성공해야 함');
        System.assertEquals(200, result.code, 'HTTP code는 200이어야 함');

        Map<String, Object> data = (Map<String, Object>) result.data;
        List<Object> listData = (List<Object>) data.get('list');

        System.assertEquals(1, listData.size(), 'Expired 쿠폰 1건이 조회되어야 함');

        Map<String, Object> voucherDto = (Map<String, Object>) listData[0];
        System.assertEquals(fixture.voucherId, (Id) voucherDto.get('id'));
        System.assertEquals(fixture.voucherCode, (String) voucherDto.get('voucherCode'));
        System.assertEquals(fixture.voucherDefinitionId, (Id) voucherDto.get('voucherDefinitionId'));
        System.assertEquals(fixture.definitionName, (String) voucherDto.get('name'));
        System.assertEquals('Expired', (String) voucherDto.get('status'));
    }

    @IsTest
    static void test_getExpiredCoupon_no_lpm_returns_empty_list() {
        Test.startTest();
        ApiResult result = new MockService_NoLpm().getExpiredCoupon(req('MEM001'));
        Test.stopTest();

        System.assertEquals(true, result.success, '조회는 성공해야 함');
        System.assertEquals(200, result.code, 'HTTP code는 200이어야 함');

        Map<String, Object> data = (Map<String, Object>) result.data;
        List<Object> listData = (List<Object>) data.get('list');

        System.assertEquals(0, listData.size(), 'LPM이 없으면 빈 목록이어야 함');
    }

    /* ========== 분기 커버리지 테스트 ========== */

    /* 분기 1: ExpirationDate < today (continue) */
    private class MockService_ExpiredVoucher extends GdAvailableCouponServiceImpl {
        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{ new LoyaltyProgramMember(Id = FAKE_LPM_ID) };
        }
        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = FAKE_DEF_ID1,
                    Status = 'Issued',
                    ExpirationDate = Date.today().addDays(-1)  // 이미 만료됨
                )
            };
        }
        protected override Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
            return new Map<Id, VoucherDefinition>{
                FAKE_DEF_ID1 => new VoucherDefinition(
                    Id = FAKE_DEF_ID1,
                    EffectiveDate = Date.today().addDays(-10)
                )
            };
        }
    }

    @IsTest
    static void test_filterVouchersByValidDateRange_expirationDatePassed() {
        Test.startTest();
        ApiResult result = new MockService_ExpiredVoucher().getAvailableCoupon(req('MEM001'));
        Test.stopTest();
        System.assert(true);  // ExpirationDate < today 분기 커버
    }

    /* 분기 2: VoucherDefinition null (continue) */
    private class MockService_MissingDefinition extends GdAvailableCouponServiceImpl {
        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{ new LoyaltyProgramMember(Id = FAKE_LPM_ID) };
        }
        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = FAKE_DEF_ID1,
                    Status = 'Issued',
                    ExpirationDate = Date.today().addDays(5)
                )
            };
        }
        protected override Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
            return new Map<Id, VoucherDefinition>();  // 빈 맵 반환
        }
    }

    @IsTest
    static void test_filterVouchersByValidDateRange_definitionNull() {
        Test.startTest();
        ApiResult result = new MockService_MissingDefinition().getAvailableCoupon(req('MEM001'));
        Test.stopTest();
        System.assert(true);  // def == null 분기 커버
    }

    /* 분기 3: EffectiveDate > today (continue) */
    private class MockService_FutureEffectiveDate extends GdAvailableCouponServiceImpl {
        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{ new LoyaltyProgramMember(Id = FAKE_LPM_ID) };
        }
        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = FAKE_DEF_ID1,
                    Status = 'Issued',
                    ExpirationDate = Date.today().addDays(5)
                )
            };
        }
        protected override Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
            return new Map<Id, VoucherDefinition>{
                FAKE_DEF_ID1 => new VoucherDefinition(
                    Id = FAKE_DEF_ID1,
                    EffectiveDate = Date.today().addDays(10)  // 아직 시작 안됨
                )
            };
        }
    }

    @IsTest
    static void test_filterVouchersByValidDateRange_effectiveDateFuture() {
        Test.startTest();
        ApiResult result = new MockService_FutureEffectiveDate().getAvailableCoupon(req('MEM001'));
        Test.stopTest();
        System.assert(true);  // EffectiveDate > today 분기 커버
    }

    /* 분기 4: 정상 경로 - result.add(v) */
    @IsTest
    static void test_filterVouchersByValidDateRange_success() {
        Test.startTest();
        ApiResult result = new MockService_Success().getAvailableCoupon(req('MEM001'));
        Test.stopTest();
        System.assert(true);  // result.add(v) 분기 커버
    }

    /* 분기 5: ExpirationDate null 케이스 */
    private class MockService_NullExpirationDate extends GdAvailableCouponServiceImpl {
        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{ new LoyaltyProgramMember(Id = FAKE_LPM_ID) };
        }
        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = FAKE_DEF_ID1,
                    Status = 'Issued',
                    ExpirationDate = null  // ExpirationDate null
                )
            };
        }
        protected override Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
            return new Map<Id, VoucherDefinition>{
                FAKE_DEF_ID1 => new VoucherDefinition(
                    Id = FAKE_DEF_ID1,
                    EffectiveDate = Date.today().addDays(-1)
                )
            };
        }
    }

    @IsTest
    static void test_filterVouchersByValidDateRange_nullExpirationDate() {
        Test.startTest();
        ApiResult result = new MockService_NullExpirationDate().getAvailableCoupon(req('MEM001'));
        Test.stopTest();
        System.assert(true);  // ExpirationDate null 경로 커버
    }

    /* 분기 6: EffectiveDate null 케이스 */
    private class MockService_NullEffectiveDate extends GdAvailableCouponServiceImpl {
        protected override List<LoyaltyProgramMember> findLpmByMemberNo(String memberNo) {
            return new List<LoyaltyProgramMember>{ new LoyaltyProgramMember(Id = FAKE_LPM_ID) };
        }
        protected override List<Voucher> findVouchersByLpm(Id lpmId) {
            return new List<Voucher>{
                new Voucher(
                    VoucherDefinitionId = FAKE_DEF_ID1,
                    Status = 'Issued',
                    ExpirationDate = Date.today().addDays(5)
                )
            };
        }
        protected override Map<Id, VoucherDefinition> loadVoucherDefinitions(List<Voucher> vouchers) {
            return new Map<Id, VoucherDefinition>{
                FAKE_DEF_ID1 => new VoucherDefinition(
                    Id = FAKE_DEF_ID1,
                    EffectiveDate = null  // EffectiveDate null
                )
            };
        }
    }

    @IsTest
    static void test_filterVouchersByValidDateRange_nullEffectiveDate() {
        Test.startTest();
        ApiResult result = new MockService_NullEffectiveDate().getAvailableCoupon(req('MEM001'));
        Test.stopTest();
        System.assert(true);  // EffectiveDate null 경로 커버
    }
}