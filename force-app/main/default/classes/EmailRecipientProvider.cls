/**
 * Public Group 기반 이메일 수신자 조회 유틸
 */
public class EmailRecipientProvider {

    private static final String ALERT_GROUP_NAME = 'EmailGroup';

    /**
     * EmailGroup에 속한 활성 사용자들의 이메일 반환
     */
    public static List<String> getEmailsFromGroup() {

        List<String> emails = new List<String>();

        // 1. 그룹 조회
        Group g = [
            SELECT Id
            FROM Group
            WHERE Name = :ALERT_GROUP_NAME
            LIMIT 1
        ];

        // 2. 그룹 멤버 조회
        List<GroupMember> members = [
            SELECT UserOrGroupId
            FROM GroupMember
            WHERE GroupId = :g.Id
        ];

        // 3. User(005)만 필터링
        Set<Id> userIds = new Set<Id>();
        for (GroupMember gm : members) {
            if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                userIds.add(gm.UserOrGroupId);
            }
        }

        if (userIds.isEmpty()) {
            return emails;
        }

        // 4. 활성 사용자 이메일 조회
        for (User u : [
            SELECT Email
            FROM User
            WHERE Id IN :userIds
            AND IsActive = true
        ]) {
            if (u.Email != null) {
                emails.add(u.Email);
            }
        }

        return emails;
    }
}