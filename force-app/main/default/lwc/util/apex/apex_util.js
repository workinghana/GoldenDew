import { showError } from '../toast/toast_util';  // Toast 유틸에서 가져옴

/**
 * @description 일정 시간 대기 (비동기 딜레이)
 * @param {Number} ms - 밀리초 단위
 * @returns {Promise<void>}
 */
export const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * @description Apex/LDS 오류 객체를 공통 포맷으로 정규화
 */
export const normalizeApexError = (error) => {
    let messages = [];
    let statusCode = null;
    const details = {};

    if (!error) {
        return {
            message: '알 수 없는 오류가 발생했습니다.',
            messages: ['알 수 없는 오류가 발생했습니다.'],
            statusCode: null,
            details,
            raw: error
        };
    }

    const body = error.body || error;

    if (Array.isArray(body)) {
        messages = body.map((e) => e.message).filter(Boolean);
    } else if (typeof body === 'object') {
        if (body.message) messages.push(body.message);
        if (Array.isArray(body.pageErrors))
            body.pageErrors.forEach((e) => e.message && messages.push(e.message));
        if (body.fieldErrors && typeof body.fieldErrors === 'object') {
            Object.values(body.fieldErrors).forEach((arr) => {
                arr.forEach((e) => e.message && messages.push(e.message));
            });
        }
        statusCode = body.status || error.statusCode || null;
    } else if (typeof body === 'string') {
        messages.push(body);
    } else if (typeof error.message === 'string') {
        messages.push(error.message);
    }

    const message =
        messages.length > 0 ? messages.join(' / ') : '알 수 없는 오류가 발생했습니다.';
    return { message, messages, statusCode, details, raw: error };
};

/**
 * @description Apex 호출 Wrapper (에러 정규화 + Toast 통합)
 */
export const callApex = async ({
    apexMethod,
    params = {},
    toastOnError = true,
    toastTitle = 'Apex 오류',
    rethrow = false,
    debugLabel
}) => {
    if (!apexMethod || typeof apexMethod !== 'function') {
        throw new Error('[apexUtil.callApex] apexMethod is required and must be a function');
    }

    try {
        const data = await apexMethod(params);
        return { success: true, data };
    } catch (error) {
        const normalized = normalizeApexError(error);

        if (toastOnError) {
            showError(normalized.message, toastTitle); // ✅ Toast 유틸 사용
        }

        if (debugLabel) {
            console.error(`[Apex:${debugLabel}]`, normalized);
        } else {
            console.error('[Apex Error]', normalized);
        }

        if (rethrow) throw error;
        return { success: false, error: normalized };
    }
};

/**
 * @description 재시도 Wrapper (외부 API 등 일시 오류 대응)
 */
export const retry = async (fn, { retries = 3, delayMs = 500 } = {}) => {
    let lastError;
    for (let i = 0; i < retries; i++) {
        try {
            return await fn();
        } catch (err) {
            lastError = err;
            if (i < retries - 1) await delay(delayMs);
        }
    }
    throw lastError;
};

/**
 * @description Apex 호출 상태 관리형 Wrapper (로딩 + 성공/실패 콜백 포함)
 */
export const callApexWithState = async ({
    apexMethod,
    params = {},
    setLoading,
    onSuccess,
    onError,
    toastOnError = true,
    toastTitle = 'Apex 오류',
    debugLabel
}) => {
    if (typeof setLoading === 'function') setLoading(true);

    try {
        const result = await callApex({
            apexMethod,
            params,
            toastOnError,
            toastTitle,
            debugLabel
        });

        if (result.success && onSuccess) onSuccess(result.data);
        if (!result.success && onError) onError(result.error);
        return result;
    } finally {
        if (typeof setLoading === 'function') setLoading(false);
    }
};