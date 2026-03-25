import { NavigationMixin } from 'lightning/navigation';

/**
 * @description 레코드 상세 페이지로 이동
 * ex) navigateToRecord(this, '5005h00001ABCDE', 'Case');
 */
export const navigateToRecord = (cmp, recordId, objectApiName, actionName = 'view') => {
    cmp[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
            recordId,
            objectApiName,
            actionName
        }
    });
};

/**
 * @description 오브젝트 리스트뷰로 이동
 */
export const navigateToListView = (cmp, objectApiName, filterName = 'Recent') => {
    cmp[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
            objectApiName,
            actionName: 'list'
        },
        state: { filterName }
    });
};

/**
 * @description 새 레코드 생성 페이지로 이동
 */
export const navigateToNewRecord = (cmp, objectApiName) => {
    cmp[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
            objectApiName,
            actionName: 'new'
        }
    });
};

/**
 * @description 외부 URL 또는 내부 링크 이동
 */
export const navigateToUrl = (cmp, url, newTab = true) => {
    if (!url) return;
    if (newTab) {
        window.open(url, '_blank');
    } else {
        cmp[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url }
        });
    }
};

/**
 * @description App (Lightning App) 으로 이동
 * @param {LightningElement} cmp
 * @param {String} appTargetName ex) 'standard__LightningSales'
 */
export const navigateToApp = (cmp, appTargetName) => {
    cmp[NavigationMixin.Navigate]({
        type: 'standard__app',
        attributes: {
            appTarget: appTargetName
        }
    });
};

/**
 * @description Lightning Tab 으로 이동 (탭 이름)
 * @param {LightningElement} cmp
 * @param {String} tabName ex) 'MyCustomTab'
 */
export const navigateToTab = (cmp, tabName) => {
    cmp[NavigationMixin.Navigate]({
        type: 'standard__navItemPage',
        attributes: {
            apiName: tabName
        }
    });
};

/**
 * @description Lightning Component Page 로 이동
 * @param {LightningElement} cmp
 * @param {String} componentName ex) 'c__MyCustomComponent'
 * @param {Object} [state={}] - 전달할 파라미터
 */
export const navigateToComponent = (cmp, componentName, state = {}) => {
    cmp[NavigationMixin.Navigate]({
        type: 'standard__component',
        attributes: {
            componentName
        },
        state
    });
};

/**
 * @description Report 또는 Dashboard 로 이동
 * @param {LightningElement} cmp
 * @param {String} recordId - 레포트 또는 대시보드 ID
 * @param {String} [type='standard__recordPage'] - 기본 recordPage 타입
 * @param {String} [actionName='view']
 */
export const navigateToReportOrDashboard = (cmp, recordId, type = 'standard__recordPage', actionName = 'view') => {
    cmp[NavigationMixin.Navigate]({
        type,
        attributes: {
            recordId,
            actionName
        }
    });
};

/**
 * @description Flow 실행 페이지로 이동 (Lightning Flow)
 * @param {LightningElement} cmp
 * @param {String} flowApiName - Flow API Name
 * @param {Object} [params={}] - Flow 변수 전달용
 */
export const navigateToFlow = (cmp, flowApiName, params = {}) => {
    cmp[NavigationMixin.Navigate]({
        type: 'standard__flow',
        attributes: {
            flowApiName
        },
        state: params
    });
};

/**
 * @description Visualforce Page로 이동
 * @param {LightningElement} cmp
 * @param {String} vfPageName ex) 'MyVfPage'
 * @param {Object} [params={}] - 쿼리 파라미터
 */
export const navigateToVfPage = (cmp, vfPageName, params = {}) => {
    let url = `/apex/${vfPageName}`;
    const keys = Object.keys(params);
    if (keys.length > 0) {
        const query = keys.map((k) => `${k}=${encodeURIComponent(params[k])}`).join('&');
        url += `?${query}`;
    }
    navigateToUrl(cmp, url, false);
};