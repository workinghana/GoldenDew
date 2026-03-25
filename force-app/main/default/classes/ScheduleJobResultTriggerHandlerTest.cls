@IsTest
private class ScheduleJobResultTriggerHandlerTest {

    @TestSetup
    static void setup() {
        // Setup 개체(Group) DML 시 발생할 수 있는 Mixed DML 에러 방지를 위해 runAs 사용
        System.runAs(new User(Id = UserInfo.getUserId())) {
            
            // 1. 이미 조직에 해당 그룹(ERP_Operators)이 있는지 확인합니다.
            List<Group> gList = [SELECT Id FROM Group WHERE DeveloperName = 'ERP_Operators' LIMIT 1];
            Group testGroup;
            
            if (gList.isEmpty()) {
                // 없으면 새로 생성
                testGroup = new Group(Name = 'ERP Operators', DeveloperName = 'ERP_Operators', Type = 'Regular');
                insert testGroup;
            } else {
                // 이미 존재하면 기존 그룹 사용
                testGroup = gList[0];
            }

            // 2. 현재 테스트를 실행하는 유저가 이미 해당 그룹의 멤버인지 확인합니다.
            List<GroupMember> gmList = [
                SELECT Id 
                FROM GroupMember 
                WHERE GroupId = :testGroup.Id 
                AND UserOrGroupId = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            if (gmList.isEmpty()) {
                // 멤버가 아니면 새로 추가
                GroupMember gm = new GroupMember(GroupId = testGroup.Id, UserOrGroupId = UserInfo.getUserId());
                insert gm;
            }
        }
    }

    @IsTest
    static void testAfterInsertPlatformEvent() {
        Test.startTest();
        // 1. 플랫폼 이벤트(Platform Event) 발행 테스트
        SchedulerJobResult__e event = new SchedulerJobResult__e(
            JobName__c = 'Test Job',
            Status__c = 'SUCCESS',
            Summary__c = 'Test Summary',
            TargetRecordId__c = '001000000000000AAA'
        );
        
        // EventBus.publish를 호출하면 트리거의 afterInsert가 실행됩니다.
        Database.SaveResult sr = EventBus.publish(event);
        Test.stopTest();

        System.assertEquals(true, sr.isSuccess(), '플랫폼 이벤트가 정상적으로 발행되어야 합니다.');
    }

    @IsTest
    static void testHandleMethod() {
        // 2. handle 메서드 직접 호출 및 분기 처리 테스트
        List<SchedulerJobResult__e> events = new List<SchedulerJobResult__e>{
            new SchedulerJobResult__e(JobName__c = 'Job1', Status__c = 'SUCCESS', Summary__c = 'Sum1', TargetRecordId__c = '001000000000000AAA'),
            new SchedulerJobResult__e(JobName__c = 'Job2', Status__c = 'PARTIAL', Summary__c = 'Sum2'),
            new SchedulerJobResult__e(JobName__c = 'Job3', Status__c = 'ERROR', Summary__c = '')
        };

        Test.startTest();
        SchedulerJobResultTriggerHandler.handle(events); // 정상 리스트 전달
        SchedulerJobResultTriggerHandler.handle(null);   // 빈 값(null) 전달 (return 분기 테스트)
        Test.stopTest();
    }

    @IsTest
    static void testPrivateUtilityMethods() {
        Test.startTest();

        // 3-1. toIdSafe 메서드 테스트
        Id validId = SchedulerJobResultTriggerHandler.toIdSafe('001000000000000');
        System.assertNotEquals(null, validId, '정상적인 15자리 ID는 변환되어야 합니다.');
        System.assertEquals(null, SchedulerJobResultTriggerHandler.toIdSafe('invalid_id_format'), '잘못된 길이는 null을 반환해야 합니다.');
        System.assertEquals(null, SchedulerJobResultTriggerHandler.toIdSafe(''), '빈 문자열은 null을 반환해야 합니다.');
        System.assertEquals(null, SchedulerJobResultTriggerHandler.toIdSafe('123456789012345678'), 'ID 형식이 아닌 18자리는 catch에 걸려 null을 반환해야 합니다.');

        // 3-2. shorten 메서드 테스트
        System.assertEquals('ab', SchedulerJobResultTriggerHandler.shorten('abcde', 2), '지정된 길이만큼 잘려야 합니다.');
        System.assertEquals('abc', SchedulerJobResultTriggerHandler.shorten('abc', 5), '길이가 짧으면 원본을 반환해야 합니다.');
        System.assertEquals(null, SchedulerJobResultTriggerHandler.shorten(null, 5), 'null 입력 시 null을 반환해야 합니다.');

        // 3-3. getUserIds 메서드 테스트
        Set<String> userIds = SchedulerJobResultTriggerHandler.getUserIds('ERP_Operators');
        System.assert(!userIds.isEmpty(), 'TestSetup에서 생성한 그룹 멤버를 정상적으로 가져와야 합니다.');
        
        Set<String> emptyIds = SchedulerJobResultTriggerHandler.getUserIds('Fake_Group_123');
        System.assert(emptyIds.isEmpty(), '존재하지 않는 그룹은 빈 Set을 반환해야 합니다.');

        // 3-4. getNotificationTypeId 메서드 테스트
        Id notifId = SchedulerJobResultTriggerHandler.getNotificationTypeId('Fake_Notif_Type_123');
        System.assertEquals(null, notifId, '존재하지 않는 알림 유형은 null을 반환해야 합니다.');

        // 3-5. sendCustomNotification 메서드 테스트 (catch 블록 커버리지)
        // NotificationTypeId에 null을 넣으면 내부적으로 Exception이 발생하여 catch 블록을 타게 됩니다.
        SchedulerJobResultTriggerHandler.sendCustomNotification(null, 'Test Title', 'Test Body', null, userIds);

        Test.stopTest();
    }
}