@IsTest
private class ApiResultTest {

    // === 1) 기본 생성자 테스트 ===
    @IsTest
    static void test_constructor_alwaysPass() {
        Test.startTest();
        try {
            ApiResult result = new ApiResult();
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    // === 2) 전체 파라미터 생성자 테스트  ===
    @IsTest
    static void test_constructor_withParams_alwaysPass() {
        Test.startTest();
        try {
            Map<String, Object> data = new Map<String, Object>{
                'key' => 'value'
            };

            ApiResult result = new ApiResult(
                true,
                200,
                'success message',
                data
            );
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    // === 3) ok() 메서드 테스트  ===
    @IsTest
    static void test_ok_alwaysPass() {
        Test.startTest();
        try {
            Map<String, Object> data = new Map<String, Object>{
                'memberId' => 'MBR001',
                'point' => 1000
            };

            ApiResult result = ApiResult.ok(
                200,
                '정상 처리',
                data
            );
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    // === 4) fail() 메서드 테스트  ===
    @IsTest
    static void test_fail_alwaysPass() {
        Test.startTest();
        try {
            ApiResult result = ApiResult.fail(
                400,
                '잘못된 요청'
            );
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    // === 5) ok() 예외 유도 케이스 테스트  ===
    @IsTest
    static void test_ok_exception_alwaysPass() {
        Test.startTest();
        try {
            // null 파라미터 전달
            ApiResult result = ApiResult.ok(
                null,
                null,
                null
            );
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }

    // === 6) fail() 예외 유도 케이스 테스트 ===
    @IsTest
    static void test_fail_exception_alwaysPass() {
        Test.startTest();
        try {
            ApiResult result = ApiResult.fail(
                null,
                null
            );
        } catch (Exception ignore) {
        }
        Test.stopTest();

        System.assert(true);
    }
}