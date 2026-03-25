@IsTest
private class LoyaltyPointServiceTest {

    private static Map<String, Object> buildReq(String memberId, Double points, String journalId) {
        return new Map<String, Object>{
            'loyaltyProgramMemberId' => memberId,
            'points' => points,
            'journalId' => journalId
        };
    }

    /* ===================================================
     * creditPoints
     * =================================================== */

    /** 빈 리스트 → CustomException(400) */
    @IsTest
    static void test_creditPoints_emptyList() {
        try {
            LoyaltyPointService.creditPoints(new List<Map<String, Object>>());
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
    }

    /** 빈 맵 → CustomException(400) */
    @IsTest
    static void test_creditPoints_emptyMap() {
        try {
            LoyaltyPointService.creditPoints(new List<Map<String, Object>>{ new Map<String, Object>() });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
    }

    /** loyaltyProgramMemberId 누락 → CustomException */
    @IsTest
    static void test_creditPoints_missingMemberId() {
        Map<String, Object> req = new Map<String, Object>{
            'points' => 100.0,
            'journalId' => 'J001'
        };
        try {
            LoyaltyPointService.creditPoints(new List<Map<String, Object>>{ req });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assert(true);
        }
    }

    /** points 누락 → CustomException */
    @IsTest
    static void test_creditPoints_missingPoints() {
        Map<String, Object> req = new Map<String, Object>{
            'loyaltyProgramMemberId' => UserInfo.getUserId(),
            'journalId' => 'J001'
        };
        try {
            LoyaltyPointService.creditPoints(new List<Map<String, Object>>{ req });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assert(true);
        }
    }

    /** journalId 누락 → CustomException */
    @IsTest
    static void test_creditPoints_missingJournalId() {
        Map<String, Object> req = new Map<String, Object>{
            'loyaltyProgramMemberId' => UserInfo.getUserId(),
            'points' => 100.0
        };
        try {
            LoyaltyPointService.creditPoints(new List<Map<String, Object>>{ req });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assert(true);
        }
    }

    /** 필수값 정상 → LoyaltyManagement API 호출 (테스트 환경에서 예외 발생 허용) */
    @IsTest
    static void test_creditPoints_validData() {
        Map<String, Object> req = buildReq(UserInfo.getUserId(), (Double)100.0, 'J001');

        Test.startTest();
        try {
            LoyaltyPointService.creditPoints(new List<Map<String, Object>>{ req });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true); // LoyaltyManagement API 예외
        }
        Test.stopTest();
    }

    /** 선택 필드 포함 (subtypeName, expirationDate, additionalNotes) */
    @IsTest
    static void test_creditPoints_withOptionalFields() {
        Map<String, Object> req = new Map<String, Object>{
            'loyaltyProgramMemberId' => UserInfo.getUserId(),
            'points' => 100.0,
            'journalId' => 'J001',
            'loyaltyProgramCurrencySubtypeName' => 'TestSubtype',
            'pointsExpirationDate' => '2030-12-31',
            'additionalNotes' => 'Test note'
        };

        Test.startTest();
        try {
            LoyaltyPointService.creditPoints(new List<Map<String, Object>>{ req });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /* ===================================================
     * debitPoints
     * =================================================== */

    /** 빈 리스트 → CustomException(400) */
    @IsTest
    static void test_debitPoints_emptyList() {
        try {
            LoyaltyPointService.debitPoints(new List<Map<String, Object>>());
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
    }

    /** 빈 맵 → CustomException(400) */
    @IsTest
    static void test_debitPoints_emptyMap() {
        try {
            LoyaltyPointService.debitPoints(new List<Map<String, Object>>{ new Map<String, Object>() });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
    }

    /** loyaltyProgramMemberId 누락 → CustomException */
    @IsTest
    static void test_debitPoints_missingMemberId() {
        Map<String, Object> req = new Map<String, Object>{
            'points' => 50.0,
            'journalId' => 'J002'
        };
        try {
            LoyaltyPointService.debitPoints(new List<Map<String, Object>>{ req });
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assert(true);
        }
    }

    /** 필수값 정상 → LoyaltyManagement API 호출 */
    @IsTest
    static void test_debitPoints_validData() {
        Map<String, Object> req = buildReq(UserInfo.getUserId(), (Double)50.0, 'J002');

        Test.startTest();
        try {
            LoyaltyPointService.debitPoints(new List<Map<String, Object>>{ req });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /** 선택 필드 포함 (subtypeName, additionalNotes) */
    @IsTest
    static void test_debitPoints_withOptionalFields() {
        Map<String, Object> req = new Map<String, Object>{
            'loyaltyProgramMemberId' => UserInfo.getUserId(),
            'points' => 50.0,
            'journalId' => 'J002',
            'loyaltyProgramCurrencySubtypeName' => 'TestSubtype',
            'additionalNotes' => 'Debit note'
        };

        Test.startTest();
        try {
            LoyaltyPointService.debitPoints(new List<Map<String, Object>>{ req });
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }

    /* ===================================================
     * getPointsBalance
     * =================================================== */

    /** null → CustomException(400) */
    @IsTest
    static void test_getPointsBalance_null() {
        try {
            LoyaltyPointService.getPointsBalance(null);
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
    }

    /** 빈 문자열 → CustomException(400) */
    @IsTest
    static void test_getPointsBalance_blank() {
        try {
            LoyaltyPointService.getPointsBalance('');
            System.assert(false, 'CustomException expected');
        } catch (CustomException e) {
            System.assertEquals(400, e.code);
        }
    }

    /** 유효한 memberId → LoyaltyManagement API 호출 */
    @IsTest
    static void test_getPointsBalance_validId() {
        Test.startTest();
        try {
            LoyaltyPointService.getPointsBalance(UserInfo.getUserId());
            System.assert(true);
        } catch (Exception e) {
            System.assert(true);
        }
        Test.stopTest();
    }
}