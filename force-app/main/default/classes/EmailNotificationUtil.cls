public with sharing class EmailNotificationUtil {

    public static void send(
        String subject,
        String body,
        List<String> toAddresses
    ) {
        if (toAddresses == null || toAddresses.isEmpty()) {
            System.debug('⚠ 이메일 수신자 없음. 전송 생략');
            return;
        }

        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();

        mail.setSubject(subject);
        mail.setPlainTextBody(body);
        mail.setToAddresses(toAddresses);
        mail.setSaveAsActivity(false);

        Messaging.sendEmail(
            new Messaging.SingleEmailMessage[]{ mail },
            false
        );
    }
}