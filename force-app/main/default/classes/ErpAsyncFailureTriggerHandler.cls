/**
 * ERP 비동기 호출 실패 이벤트(ErpAsyncFailure__e) 수신 트리거 핸들러
 * 1) ERP 비동기 호출 실패 시 Custom Notification 발송
 *  - 알림 유형: 'ERP_Callout_Failure' (Custom Notification Type)
 *  - 수신자 그룹: 'ERP_Operators' (Public Group)
 *  - 알림 제목: 'ERP 호출 실패 - {ApiName__c}'
 *  - 알림 본문: ErrorMessage__c (140자 이내로 제한)
 *  - 클릭 시 이동 대상: TargetRecordId__c (가능한 경우)
 */
public with sharing class ErpAsyncFailureTriggerHandler extends TriggerHandler {
  private static final String NOTIF_TYPE_DEVELOPER_NAME = 'ERP_Callout_Failure';
  private static final String GROUP_DEV_NAME = 'ERP_Operators';

  public ErpAsyncFailureTriggerHandler() {
    this.setMaxLoopCount(10); // 최대 10번까지만 허용
  }

  public override void afterInsert() {
    handle((List<ErpAsyncFailure__e>) Trigger.new);
  }

  public static void handle(List<ErpAsyncFailure__e> events) {
    System.debug('handle 진입');
    if (events == null || events.isEmpty()) {
      return;
    }

    // 1) Custom Notification Type Id 조회
    Id notifTypeId = getNotificationTypeId(NOTIF_TYPE_DEVELOPER_NAME);
    if (notifTypeId == null) {
      System.debug('[ERP NOTIF] Custom Notification Type not found: ' + NOTIF_TYPE_DEVELOPER_NAME);
      return;
    }

    // 2) 기본 운영자 그룹 "멤버(User/Group)" Id 목록 조회 (send는 Set<String> 사용)
    Set<String> userIds = getUserIds(GROUP_DEV_NAME);

    // null 반환 없도록 했지만, 방어적으로 체크
    if (userIds == null || userIds.isEmpty()) {
      System.debug('[ERP NOTIF] No userIds. group=' + GROUP_DEV_NAME);
      return;
    }

    // 3) 이벤트별로 알림 발송
    for (ErpAsyncFailure__e e : events) {
      // 제목/본문 구성
      String title = '⚠️ ERP API 호출 실패 : ';
      if (!String.isBlank(e.ApiName__c)) {
        title += e.ApiName__c;
      }

      String body = String.isBlank(e.ErrorMessage__c) ? 'ERP API 호출 중 오류가 발생했습니다.' : shorten(e.ErrorMessage__c, 140);

      // 클릭 시 이동할 Target (선택)
      Id targetId = toIdSafe((String) e.TargetRecordId__c);

      sendCustomNotification(notifTypeId, title, body, targetId, userIds);
    }
  }

  // ---------------- helpers ----------------

  /**
   * Custom Notification 발송
   * NOTE: 이 org에서는 send(Set<String>) 시그니처만 허용
   */
  private static void sendCustomNotification(Id notifTypeId, String title, String body, Id targetId, Set<String> userIds) {
    System.debug('sendCustomNotification 진입');
    if (notifTypeId == null || userIds == null || userIds.isEmpty()) {
      return;
    }

    try {
      Messaging.CustomNotification n = new Messaging.CustomNotification();
      n.setNotificationTypeId(notifTypeId);
      n.setTitle(title);
      n.setBody(body);

      // TargetId는 선택 (null 가능)
      if (targetId != null) {
        n.setTargetId(targetId);
      }

      System.debug(n);
      n.send(userIds);
      System.debug('n.send(userIds) 완료');
    } catch (Exception ex) {
      System.debug('[ERP NOTIF] send failed: ' + ex.getMessage());
    }
  }

  /**
   * CustomNotificationType Id 조회
   */
  private static Id getNotificationTypeId(String developerName) {
    if (String.isBlank(developerName)) {
      return null;
    }

    List<CustomNotificationType> listCt = [
      SELECT Id
      FROM CustomNotificationType
      WHERE DeveloperName = :developerName
      LIMIT 1
    ];
    return listCt.isEmpty() ? null : listCt[0].Id;
  }

  /**
   * Public Group의 멤버(UserOrGroupId) 목록을 "userIds"로 반환
   */
  private static Set<String> getUserIds(String groupDeveloperName) {
    Set<String> userIds = new Set<String>();

    if (String.isBlank(groupDeveloperName)) {
      return userIds; // 빈 Set 반환(Null 방지)
    }

    // 그룹 조회
    List<Group> gList = [
      SELECT Id
      FROM Group
      WHERE Type = 'Regular' AND DeveloperName = :groupDeveloperName
      LIMIT 1
    ];
    if (gList.isEmpty()) {
      return userIds;
    }

    // 그룹 멤버 조회 (UserOrGroupId = UserId(005...) 또는 GroupId(00G...) 가능)
    for (GroupMember gm : [
      SELECT UserOrGroupId
      FROM GroupMember
      WHERE GroupId = :gList[0].Id
    ]) {
      if (gm.UserOrGroupId != null) {
        userIds.add(String.valueOf(gm.UserOrGroupId));
      }
    }

    return userIds;
  }

  /**
   * Text(15/18) -> Id 안전 변환 (유효하지 않으면 null)
   */
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

  /**
   * 문자열 길이 제한
   */
  private static String shorten(String s, Integer maxLen) {
    if (s == null) {
      return null;
    }
    if (maxLen == null || maxLen <= 0) {
      return s;
    }
    return (s.length() > maxLen) ? s.substring(0, maxLen) : s;
  }
}