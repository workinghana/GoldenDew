import { ShowToastEvent } from 'lightning/platformShowToastEvent';  // 토스트 메시지(알림 팝업)를 띄우기 위한 Salesforce 표준 모듈 import

/**
 * @description 공통 Toast 호출 유틸
 * @param {Object} param0 - Toast 파라미터 객체
 * @param {String} param0.title - 토스트 제목
 * @param {String} param0.message - 토스트 내용
 * @param {String} [param0.variant='info'] - 스타일 (success, warning, error, info)
 * @param {String} [param0.mode='dismissible'] - 유지 모드 (pester, dismissible, sticky)
 * @param {Array} [param0.messageData] - 메시지 내 링크 등 동적 데이터
 *
 * @example
 * showToast({
 *     title: '저장 완료',
 *     message: '레코드가 성공적으로 저장되었습니다.',
 *     variant: 'success',
 *     mode: 'dismissible'
 * });
 */
export const showToast = ({ title, message, variant = 'info', mode = 'dismissible', messageData }) => {
    const evt = new ShowToastEvent({
        title,
        message,
        variant,
        mode,
        messageData
    });
    dispatchEvent(evt);
};

/**
 * @description 성공 Toast 단축 호출
 * ex) showSuccess('데이터가 저장되었습니다.');
*/
export const showSuccess = (message, title = '성공', mode = 'dismissible') => {
    showToast({ title, message, variant: 'success', mode });
};

/**
 * @description 경고 Toast 단축 호출
 * ex) showError('API 호출 중 오류가 발생했습니다.', '서버 오류');
*/
export const showWarning = (message, title = '경고', mode = 'dismissible') => {
    showToast({ title, message, variant: 'warning', mode });
};

/**
 * @description 오류 Toast 단축 호출
*/
export const showError = (message, title = '오류', mode = 'sticky') => {
    showToast({ title, message, variant: 'error', mode });
};

/**
 * @description 정보 Toast 단축 호출
*/
export const showInfo = (message, title = '정보', mode = 'dismissible') => {
    showToast({ title, message, variant: 'info', mode });
};