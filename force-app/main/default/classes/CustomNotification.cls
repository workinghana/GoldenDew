public with sharing class CustomNotification {
  public static void notifyUsers(Set<String> recipientsIds, Integer recordCount) {
    System.debug('알림 테스트');

    // CustomNotificationType notificationType = [
    //   SELECT Id, DeveloperName
    //   FROM CustomNotificationType
    //   WHERE DeveloperName = 'New_Contact_Notification'
    // ];

    // Messaging.CustomNotification notification = new Messaging.CustomNotification();

    // notification.setTitle('Trailhead Trigger Tutorial');
    // notification.setBody(recordCount + ' contact(s) were inserted.');

    // notification.setNotificationTypeId(notificationType.Id);
    // notification.setTargetId('000000000000000AAA');

    // try {
    //   notification.send(recipientsIds);
    //   System.debug('Custom notification sent successfully.');
    // } catch (Exception e) {
    //   System.debug('Problem sending notification: ' + e.getMessage());
    // }
  }
}