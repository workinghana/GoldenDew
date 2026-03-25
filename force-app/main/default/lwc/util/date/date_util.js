/**
 * @description Date 객체를 'YYYY-MM-DD' 형식으로 반환
 * @param {Date|String} date
 * @returns {String}
 */
export const formatDate = (date) => {
    if (!date) return '';
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
};

/**
 * @description Date 객체를 'YYYY-MM-DD HH:mm:ss' 형식으로 반환
 * @param {Date|String} date
 * @returns {String}
 */
export const formatDateTime = (date) => {
    if (!date) return '';
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hour = String(d.getHours()).padStart(2, '0');
    const min = String(d.getMinutes()).padStart(2, '0');
    const sec = String(d.getSeconds()).padStart(2, '0');
    return `${year}-${month}-${day} ${hour}:${min}:${sec}`;
};

/**
 * @description 오늘 날짜 반환 ('YYYY-MM-DD')
 * @returns {String}
 */
export const today = () => formatDate(new Date());

/**
 * @description 현재 시각 ISO 문자열 반환
 * @returns {String}
 */
export const nowISO = () => new Date().toISOString();

/**
 * @description 일수 더하기
 * @param {Date|String} date
 * @param {Number} days
 * @returns {String} ISO 형식
 */
export const addDays = (date, days) => {
    const result = new Date(date);
    result.setDate(result.getDate() + days);
    return result.toISOString();
};

/**
 * @description 두 날짜의 차이 (일 단위)
 * @param {Date|String} date1
 * @param {Date|String} date2
 * @returns {Number}
 */
export const diffDays = (date1, date2) => {
    const d1 = new Date(date1);
    const d2 = new Date(date2);
    const diffMs = Math.abs(d1 - d2);
    return Math.floor(diffMs / (1000 * 60 * 60 * 24));
};

/**
 * @description 날짜 비교 (date1 > date2 ?)
 * @param {Date|String} date1
 * @param {Date|String} date2
 * @returns {Boolean}
 */
export const isAfter = (date1, date2) => new Date(date1).getTime() > new Date(date2).getTime();

/**
 * @description 날짜 비교 (date1 < date2 ?)
 * @param {Date|String} date1
 * @param {Date|String} date2
 * @returns {Boolean}
 */
export const isBefore = (date1, date2) => new Date(date1).getTime() < new Date(date2).getTime();

/**
 * @description ISO 문자열을 로컬 시간 문자열로 변환
 * @param {String} isoString
 * @returns {String}
 */
export const toLocalString = (isoString) => {
    if (!isoString) return '';
    const d = new Date(isoString);
    return d.toLocaleString(); // 예: 2025. 11. 3. 오후 2:30:00
};

/**
 * @description YYYY-MM-DD 문자열을 ISO 형식으로 변환
 * @param {String} dateStr
 * @returns {String}
 */
export const toISO = (dateStr) => {
    if (!dateStr) return '';
    return new Date(dateStr).toISOString();
};

/**
 * @description 월 차이 계산 (전체 개월 수)
 * @param {Date|String} date1
 * @param {Date|String} date2
 * @returns {Number}
 */
export const diffMonths = (date1, date2) => {
    const d1 = new Date(date1);
    const d2 = new Date(date2);
    return (d1.getFullYear() - d2.getFullYear()) * 12 + (d1.getMonth() - d2.getMonth());
};