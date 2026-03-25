@IsTest
private class GdAvailableCouponServiceImplTest {

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

        System.assertEquals(200, result.code);
        System.assertEquals(1, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_no_lpm() {
        ApiResult result =
            new MockService_NoLpm().getAvailableCoupon(req('MEM001'));

        System.assertEquals(200, result.code);
        System.assertEquals(0, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_no_definition_ids() {
        ApiResult result =
            new MockService_NoDefIds().getAvailableCoupon(req('MEM001'));

        System.assertEquals(200, result.code);
        System.assertEquals(0, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_def_not_found_in_map() {
        ApiResult result =
            new MockService_DefNotFound().getAvailableCoupon(req('MEM001'));

        System.assertEquals(200, result.code);
        System.assertEquals(0, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_voucher_filtered_out() {
        ApiResult result =
            new MockService_FilteredOut().getAvailableCoupon(req('MEM001'));

        System.assertEquals(200, result.code);
        System.assertEquals(0, ((List<Object>)result.data.get('list')).size());
        System.assert(true);
    }

    @IsTest
    static void test_null_request() {
        try {
            new MockService_Success().getAvailableCoupon(null);
            System.assert(false, 'should throw CustomException');
        } catch (CustomException ce) {
            System.assertEquals(400, ce.code);
            System.assert(true);
        }
    }

    @IsTest
    static void test_memberNo_blank() {
        try {
            new MockService_Success().getAvailableCoupon(req(''));
            System.assert(false, 'should throw CustomException for blank memberNo');
        } catch (CustomException ce) {
            System.assertEquals(400, ce.code);
            System.assert(true);
        }
    }
}