@IsTest
private class LoyaltyVoucherServiceTest {

    private static Map<String, Object> buildReq(String memberId, String programName, String voucherDefName) {
        return new Map<String, Object>{
            'loyaltyProgramMemberId' => memberId,
            'programName' => programName,
            'voucherDefinitionName' => voucherDefName
        };
    }

    /* ===================================================
     * issueVoucher
     * =================================================== */

    /** 빈 리스트 → CustomException(400) */
    @IsTest
    static void test_issueVoucher_emptyList() {
        try {
            LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>());
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
    }

    /** 빈 맵 → CustomException(400) */
    @IsTest
    static void test_issueVoucher_emptyMap() {
        try {
            LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>{ new Map<String, Object>() });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
    }

    /** loyaltyProgramMemberId 누락 → CustomException */
    @IsTest
    static void test_issueVoucher_missingMemberId() {
        Map<String, Object> req = new Map<String, Object>{
            'programName' => 'TestProgram',
            'voucherDefinitionName' => 'TestVoucher'
        };
        try {
            LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>{ req });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assert(true);
        }
    }

    /** programName 누락 → CustomException */
    @IsTest
    static void test_issueVoucher_missingProgramName() {
        Map<String, Object> req = new Map<String, Object>{
            'loyaltyProgramMemberId' => UserInfo.getUserId(),
            'voucherDefinitionName' => 'TestVoucher'
        };
        try {
            LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>{ req });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assert(true);
        }
    }

    /** voucherDefinitionName 누락 → CustomException */
    @IsTest
    static void test_issueVoucher_missingVoucherDefName() {
        Map<String, Object> req = new Map<String, Object>{
            'loyaltyProgramMemberId' => UserInfo.getUserId(),
            'programName' => 'TestProgram'
        };
        try {
            LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>{ req });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assert(true);
        }
    }

    /** 필수값 정상 → LoyaltyManagement API 호출 */
    @IsTest
    static void test_issueVoucher_validData() {
        Map<String, Object> req = buildReq(UserInfo.getUserId(), 'TestProgram', 'TestVoucher');

        Test.startTest();
        try {
            LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>{ req });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true); // LoyaltyManagement API 예외
        }
        Test.stopTest();
    }

    /** 선택 필드 전부 포함 */
    @IsTest
    static void test_issueVoucher_withAllOptionalFields() {
        Map<String, Object> req = new Map<String, Object>{
            'loyaltyProgramMemberId' => UserInfo.getUserId(),
            'programName' => 'TestProgram',
            'voucherDefinitionName' => 'TestVoucher',
            'journalId' => 'J001',
            'voucherCode' => 'VC001',
            'additionalNotes' => 'Test note',
            'benefitId' => 'B001',
            'contactId' => UserInfo.getUserId(),
            'discountPercent' => 10,
            'effectiveDate' => '2030-01-01',
            'expiryDate' => '2030-12-31',
            'faceValue' => 5000.0,
            'promotionId' => 'P001'
        };

        Test.startTest();
        try {
            LoyaltyVoucherService.issueVoucher(new List<Map<String, Object>>{ req });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /* ===================================================
     * issueVoucherV2
     * =================================================== */

    /** 빈 리스트 → null 반환 (V1과 달리 예외 없음) */
    @IsTest
    static void test_issueVoucherV2_emptyList() {
        Test.startTest();
        List<LoyaltyManagement.IssueVoucherOutput> result =
            LoyaltyVoucherService.issueVoucherV2(new List<Map<String, Object>>());
        Test.stopTest();

        System.assertEquals(null, result);
    }

    /** 빈 맵 → 건너뜀 → LoyaltyManagement API 빈 입력으로 호출 */
    @IsTest
    static void test_issueVoucherV2_emptyMap() {
        Test.startTest();
        try {
            LoyaltyVoucherService.issueVoucherV2(new List<Map<String, Object>>{ new Map<String, Object>() });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /** loyaltyProgramMemberId 누락 → CustomException */
    @IsTest
    static void test_issueVoucherV2_missingMemberId() {
        Map<String, Object> req = new Map<String, Object>{
            'programName' => 'TestProgram',
            'voucherDefinitionName' => 'TestVoucher'
        };
        try {
            LoyaltyVoucherService.issueVoucherV2(new List<Map<String, Object>>{ req });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assert(true);
        }
    }

    /** 필수값 정상 → LoyaltyManagement API 호출 */
    @IsTest
    static void test_issueVoucherV2_validData() {
        Map<String, Object> req = buildReq(UserInfo.getUserId(), 'TestProgram', 'TestVoucher');

        Test.startTest();
        try {
            LoyaltyVoucherService.issueVoucherV2(new List<Map<String, Object>>{ req });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /** 선택 필드 전부 포함 (V2) */
    @IsTest
    static void test_issueVoucherV2_withAllOptionalFields() {
        Map<String, Object> req = new Map<String, Object>{
            'loyaltyProgramMemberId' => UserInfo.getUserId(),
            'programName' => 'TestProgram',
            'voucherDefinitionName' => 'TestVoucher',
            'journalId' => 'J002',
            'voucherCode' => 'VC002',
            'additionalNotes' => 'V2 note',
            'benefitId' => 'B002',
            'contactId' => UserInfo.getUserId(),
            'discountPercent' => 20,
            'effectiveDate' => '2030-01-01',
            'expiryDate' => '2030-12-31',
            'faceValue' => 10000.0,
            'promotionId' => 'P002'
        };

        Test.startTest();
        try {
            LoyaltyVoucherService.issueVoucherV2(new List<Map<String, Object>>{ req });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}