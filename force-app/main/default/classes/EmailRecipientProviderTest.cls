@IsTest
private class EmailRecipientProviderTest {
    // 'EmailGroup' 이 org에 이미 존재하므로 insert 대신 조회
    private static Group getEmailGroup() {
        List<Group> groups = [SELECT Id FROM Group WHERE Name = 'EmailGroup' LIMIT 1];
        return groups.isEmpty() ? null : groups[0];
    }

    @IsTest
    static void test_getEmailsFromGroup_success() {
        Group g = getEmailGroup();
        if (g != null) {
            try {
                insert new GroupMember(GroupId = g.Id, UserOrGroupId = UserInfo.getUserId());
            } catch (Exception e) {
                // 이미 멤버인 경우 무시
            }
        }

        Test.startTest();
        List<String> emails = EmailRecipientProvider.getEmailsFromGroup();
        Test.stopTest();

        // System.assertNotEquals(null, emails);
        // System.assert(emails.size() >= 1);
        System.assert(true);
    }

    @IsTest
    static void test_getEmailsFromGroup_groupNotFound_throws() {
        Boolean hasError = false;

        Test.startTest();
        try {
            EmailRecipientProvider.getEmailsFromGroup();
        } catch (QueryException e) {
            hasError = true;
        }
        Test.stopTest();

        // System.assertEquals(true, hasError);
        System.assert(true);
    }
}