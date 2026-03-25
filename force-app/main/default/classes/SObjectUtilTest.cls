@IsTest
private class SObjectUtilTest {
    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = '테스트계정');
        insert acc;
    }

    /* =====================================================
     * findIdByName - 정상 조회
     * ===================================================== */
    @IsTest
    static void test_findIdByName_success() {
        Id result = SObjectUtil.findIdByName(Account.SObjectType, '테스트계정', true);

        System.assertNotEquals(null, result);
    }

    /* =====================================================
     * findIdByName - name null + isRequired = false
     * ===================================================== */
    @IsTest
    static void test_findIdByName_nameNull_notRequired() {
        Id result = SObjectUtil.findIdByName(Account.SObjectType, null, false);

        System.assertEquals(null, result);
    }

    /* =====================================================
     * findIdByName - name null + isRequired = true
     * ===================================================== */
    @IsTest
    static void test_findIdByName_nameNull_required() {
        try {
            SObjectUtil.findIdByName(Account.SObjectType, null, true);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (ValidationException e) {
            System.assert(true);
        }
    }

    /* =====================================================
     * findIdByName - 조회 결과 없음 + isRequired = true
     * ===================================================== */
    @IsTest
    static void test_findIdByName_notFound_required() {
        try {
            SObjectUtil.findIdByName(Account.SObjectType, '존재하지않는계정', true);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (ValidationException e) {
            // Exception successfully thrown
            System.assert(true);
        }
    }

    /* =====================================================
     * findIdByConditions - 정상 조회
     * ===================================================== */
    @IsTest
    static void test_findIdByConditions_success() {
        Map<String, Object> conditions = new Map<String, Object>{ 'Name' => '테스트계정' };

        Id result = SObjectUtil.findIdByConditions(Account.SObjectType, conditions, true);

        System.assertNotEquals(null, result);
    }

    /* =====================================================
     * findIdByConditions - 조건 null + isRequired = false
     * ===================================================== */
    @IsTest
    static void test_findIdByConditions_null_notRequired() {
        Id result = SObjectUtil.findIdByConditions(Account.SObjectType, null, false);

        System.assertEquals(null, result);
    }

    /* =====================================================
     * findIdByConditions - 조건 null + isRequired = true
     * ===================================================== */
    @IsTest
    static void test_findIdByConditions_null_required() {
        try {
            SObjectUtil.findIdByConditions(Account.SObjectType, null, true);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (ValidationException e) {
            // Exception successfully thrown
            System.assert(true);
        }
    }

    /* =====================================================
     * findIdByConditions - 존재하지 않는 필드
     * ===================================================== */
    @IsTest
    static void test_findIdByConditions_invalidField() {
        Map<String, Object> conditions = new Map<String, Object>{ 'NotExistField__c' => 'test' };

        Id result = SObjectUtil.findIdByConditions(Account.SObjectType, conditions, false);

        System.assertEquals(null, result);
    }

    /* =====================================================
     * findIdByConditions - 조건 불일치 + isRequired = true
     * ===================================================== */
    @IsTest
    static void test_findIdByConditions_notFound_required() {
        Map<String, Object> conditions = new Map<String, Object>{ 'Name' => '없는값' };

        try {
            SObjectUtil.findIdByConditions(Account.SObjectType, conditions, true);
            System.assert(false, '예외가 발생해야 합니다.');
        } catch (ValidationException e) {
            // Exception successfully thrown
            System.assert(true);
        }
    }
}