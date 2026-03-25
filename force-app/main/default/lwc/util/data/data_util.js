/**
 * @description 깊은 복사 (Deep Clone)
 * @param {*} data - 복사할 객체 또는 배열
 * @returns {*} 복제된 객체/배열
 */
export const deepClone = (data) => {
    try {
        return JSON.parse(JSON.stringify(data));
    } catch (e) {
        console.error('[dataUtil.deepClone] Invalid data:', e);
        return data;
    }
};

/**
 * @description 비어있는 값인지 확인 (null, undefined, '', [], {})
 * @param {*} value
 * @returns {Boolean}
 */
export const isEmpty = (value) => {
    if (value === null || value === undefined) return true;
    if (typeof value === 'string' && value.trim().length === 0) return true;
    if (Array.isArray(value) && value.length === 0) return true;
    if (typeof value === 'object' && Object.keys(value).length === 0) return true;
    return false;
};

/**
 * @description 안전한 속성 접근 (Optional Chaining)
 * @param {Object} obj - 대상 객체
 * @param {String} path - 경로 (ex: 'account.owner.name')
 * @param {*} defaultValue - 기본값
 */
export const getValue = (obj, path, defaultValue = null) => {
    if (!obj || !path) return defaultValue;
    try {
        const value = path.split('.').reduce((acc, key) => (acc ? acc[key] : undefined), obj);
        return value !== undefined && value !== null ? value : defaultValue;
    } catch {
        return defaultValue;
    }
};

/**
 * @description 배열의 중복 제거
 * @param {Array} arr
 * @returns {Array}
 */
export const uniqueList = (arr = []) => Array.from(new Set(arr));

/**
 * @description 배열 정렬 (오름/내림차순)
 * @param {Array} arr
 * @param {String} key - 정렬 기준 key
 * @param {Boolean} [asc=true] - true: 오름차순, false: 내림차순
 */
export const sortByKey = (arr, key, asc = true) => {
    if (!Array.isArray(arr)) return [];
    return [...arr].sort((a, b) => {
        const aVal = a[key] ?? '';
        const bVal = b[key] ?? '';
        return asc ? (aVal > bVal ? 1 : -1) : (aVal < bVal ? 1 : -1);
    });
};

/**
 * @description 랜덤 ID 생성
 * @param {String} [prefix='tmp']
 * @returns {String}
 */
export const generateRandomId = (prefix = 'tmp') =>
    `${prefix}_${Math.random().toString(36).substring(2, 10)}`;

/**
 * @description null, undefined → '' 변환 (NVL)
 * @param {*} val
 * @returns {String}
 */
export const nvl = (val) => (val === null || val === undefined ? '' : val);

/**
 * @description 특정 키값 추출 (pluck)
 * @param {Array} arr
 * @param {String} key
 * @returns {Array}
 */
export const pluck = (arr, key) => {
    if (!Array.isArray(arr)) return [];
    return arr.map((item) => item[key]);
};

/**
 * @description 깊은 병합 (Deep Merge)
 * @param {Object} target
 * @param {Object} source
 * @returns {Object}
 */
export const deepMerge = (target, source) => {
    if (!source) return target;
    const output = { ...target };
    Object.keys(source).forEach((key) => {
        if (typeof source[key] === 'object' && !Array.isArray(source[key])) {
            output[key] = deepMerge(output[key] || {}, source[key]);
        } else {
            output[key] = source[key];
        }
    });
    return output;
};

/**
 * @description 배열 내 객체 검색 (key, value)
 * @param {Array} arr
 * @param {String} key
 * @param {*} value
 * @returns {Object|null}
 */
export const findByKey = (arr, key, value) => {
    if (!Array.isArray(arr)) return null;
    return arr.find((item) => item[key] === value) || null;
};

/**
 * @description 안전하게 JSON Parse 수행
 * @param {String} str
 * @param {*} [defaultValue={}]
 * @returns {Object|Array}
 */
export const safeJsonParse = (str, defaultValue = {}) => {
    try {
        return JSON.parse(str);
    } catch {
        return defaultValue;
    }
};