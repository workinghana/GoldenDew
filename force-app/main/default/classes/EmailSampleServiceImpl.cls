public with sharing class EmailSampleServiceImpl {

    /**
     * 문자열 메시지용 (간단 알림)
     * ※ 기존 Plain Text 유지
     */
    public static void notifyError(String errorMessage) {

        String subject =
            '[시스템 오류 알림] 예외 발생 감지';

        String body =
            '시스템 오류가 발생했습니다.\n\n' +
            '[발생 시각] ' +
            Datetime.now()
                .addHours(9)
                .format('yyyy-MM-dd HH:mm:ss \'KST\'') +
            '\n\n' +
            '[오류 내용]\n' +
            errorMessage;

        EmailNotificationUtil.send(
            subject,
            body,
            EmailRecipientProvider.getEmailsFromGroup()
        );
    }

    /**
     * Exception 기반 (실무용, 권장)
     * - 제목, 섹션명만 Bold 처리
     * - 색상/폰트 변경 없음
     */
    public static void notifyError(Exception e) {

        String subject =
            '[시스템 오류 알림] 예외 발생 감지';

        String htmlBody =
            '<div>' +

            '<p><b>[시스템 오류 알림]</b> 시스템 실행 중 예외가 감지되어 아래와 같이 상세 정보를 전달드립니다.</p>' +

            '<br/>' +

            '<p><b>[기본 정보]</b></p>' +
            '<p>' +
            '- 발생 시각 : ' +
            Datetime.now().addHours(9)
                .format('yyyy-MM-dd HH:mm:ss \'KST\'') + '<br/>' +
            '- 실행 사용자 : ' + UserInfo.getUserName() + '<br/>' +
            '- 사용자 ID : ' + UserInfo.getUserId() +
            '</p>' +

            '<br/>' +

            '<p><b>[오류 메시지]</b></p>' +
            '<p>' + e.getMessage() + '</p>' +

            '<br/>' +

            '<p><b>[발생 지점]</b></p>' +
            '<pre>' + e.getStackTraceString() + '</pre>' +

            '</div>';

        EmailNotificationUtil.send(
            subject,
            htmlBody,
            EmailRecipientProvider.getEmailsFromGroup()
        );
    }
}