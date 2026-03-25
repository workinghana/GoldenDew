public with sharing class SchedulerJobResultTriggerHandler extends TriggerHandler {
  private static final String NOTIF_TYPE_DEVELOPER_NAME = 'Scheduler_Job_Result';
  private static final String GROUP_DEV_NAME = 'ERP_Operators'; // 또는 Scheduler 운영 그룹

  public SchedulerJobResultTriggerHandler() {
    this.setMaxLoopCount(10); // 최대 10번까지만 허용
  }

  public override void afterInsert() {
    System.debug('afterInsert 진입');
    handle((List<SchedulerJobResult__e>) Trigger.new);
  }

  @TestVisible
  public static void handle(List<SchedulerJobResult__e> events) {
    System.debug('handle 진입');
    System.debug('events: ' + events);
    if (events == null || events.isEmpty()) {
      return;
    }

    Id notifTypeId = getNotificationTypeId(NOTIF_TYPE_DEVELOPER_NAME);
    if (notifTypeId == null) {
      System.debug('[SCHED NOTIF] NotificationType not found: ' + NOTIF_TYPE_DEVELOPER_NAME);
      return;
    }

    Set<String> userIds = getUserIds(GROUP_DEV_NAME);
    if (userIds == null || userIds.isEmpty()) {
      System.debug('[SCHED NOTIF] No userIds. group=' + GROUP_DEV_NAME);
      return;
    }

    for (SchedulerJobResult__e e : events) {
      // 제목: 상태별 아이콘
      String icon = (e.Status__c == 'SUCCESS') ? '✅ ' : (e.Status__c == 'PARTIAL') ? '⚠️ ' : '🚨 ';
      String title = icon + '스케줄러 결과: ' + (String.isBlank(e.JobName__c) ? 'Job' : e.JobName__c) + ' (' + e.Status__c + ')';

      // 본문: Summary 중심
      String body = String.isBlank(e.Summary__c) ? '결과 요약이 없습니다.' : shorten(e.Summary__c, 140);

      // 클릭 이동
      Id targetId = toIdSafe(e.TargetRecordId__c);

      sendCustomNotification(notifTypeId, title, body, targetId, userIds);
    }
  }

  // ----- 아래 유틸은 기존 ErpAsyncFailureTriggerHandler와 동일 패턴 -----

  @TestVisible
  private static void sendCustomNotification(Id notifTypeId, String title, String body, Id targetId, Set<String> userIds) {
    try {
      Messaging.CustomNotification n = new Messaging.CustomNotification();
      n.setNotificationTypeId(notifTypeId);
      n.setTitle(title);
      n.setBody(body);
      if (targetId != null) {
        n.setTargetId(targetId);
      }
      n.send(userIds);
    } catch (Exception ex) {
      System.debug('[SCHED NOTIF] send failed: ' + ex.getMessage());
    }
  }

  @TestVisible
  private static Id getNotificationTypeId(String developerName) {
    List<CustomNotificationType> listCt = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = :developerName LIMIT 1];
    return listCt.isEmpty() ? null : listCt[0].Id;
  }

  @TestVisible
  private static Set<String> getUserIds(String groupDeveloperName) {
    Set<String> userIds = new Set<String>();
    List<Group> gList = [SELECT Id FROM Group WHERE Type = 'Regular' AND DeveloperName = :groupDeveloperName LIMIT 1];
    if (gList.isEmpty()) {
      return userIds;
    }

    for (GroupMember gm : [SELECT UserOrGroupId FROM GroupMember WHERE GroupId = :gList[0].Id]) {
      if (gm.UserOrGroupId != null) {
        userIds.add(String.valueOf(gm.UserOrGroupId));
      }
    }
    return userIds;
  }

  @TestVisible
  private static Id toIdSafe(String idStr) {
    if (String.isBlank(idStr)) {
      return null;
    }
    String s = idStr.trim();
    if (s.length() != 15 && s.length() != 18) {
      return null;
    }
    try {
      return (Id) s;
    } catch (Exception e) {
      return null;
    }
  }

  @TestVisible
  private static String shorten(String s, Integer maxLen) {
    if (s == null) {
      return null;
    }
    return (s.length() > maxLen) ? s.substring(0, maxLen) : s;
  }
}