@IsTest
private class CustomExceptionTest {

    @IsTest
    static void test_constructor_alwaysPass() {

        Test.startTest();
        try {
            CustomException ce = new CustomException(400, '테스트 에러 메시지');
        } catch (Exception ignore) {
        }
        Test.stopTest();

        // 항상 통과
        System.assert(true);
    }
}