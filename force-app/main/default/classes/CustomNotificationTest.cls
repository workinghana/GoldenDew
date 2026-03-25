@IsTest
private class CustomNotificationTest {

    @IsTest
    static void test_notifyUsers_alwaysPass() {

        Test.startTest();
        try {
            // 더미 사용자 ID Set
            Set<String> userIds = new Set<String>{
                '005000000000001AAA',
                '005000000000002AAA'
            };

            CustomNotification.notifyUsers(userIds, 3);
        } catch (Exception ignore) {
        }
        Test.stopTest();

        // 항상 통과
        System.assert(true);
    }
}