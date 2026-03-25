@IsTest
private class EmailSampleServiceImplTest {
    private static Group ensureEmailGroup() {
        List<Group> groups = [
            SELECT Id, Name
            FROM Group
            WHERE Name = 'EmailGroup'
            LIMIT 1
        ];

        if (!groups.isEmpty()) {
            return groups[0];
        }

        Group g = new Group(Name = 'EmailGroup', DeveloperName = 'EmailGroup', Type = 'Regular');
        insert g;
        return g;
    }

    private static void ensureCurrentUserMember(Group g) {
        List<GroupMember> members = [
            SELECT Id
            FROM GroupMember
            WHERE GroupId = :g.Id AND UserOrGroupId = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (members.isEmpty()) {
            insert new GroupMember(GroupId = g.Id, UserOrGroupId = UserInfo.getUserId());
        }
    }

    @IsTest
    static void test_notifyError_string_sends_email() {
        Group g = ensureEmailGroup();
        ensureCurrentUserMember(g);

        Test.startTest();
        Integer beforeCount = Limits.getEmailInvocations();

        EmailSampleServiceImpl.notifyError('테스트 오류 메시지');

        Integer afterCount = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(beforeCount + 1, afterCount);
    }

    @IsTest
    static void test_notifyError_exception_sends_email() {
        Group g = ensureEmailGroup();
        ensureCurrentUserMember(g);

        Exception ex;
        try {
            Integer x = 1 / 0;
        } catch (Exception e) {
            ex = e;
        }

        Test.startTest();
        Integer beforeCount = Limits.getEmailInvocations();

        EmailSampleServiceImpl.notifyError(ex);

        Integer afterCount = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertNotEquals(null, ex);
        System.assertEquals(beforeCount + 1, afterCount);
    }
}