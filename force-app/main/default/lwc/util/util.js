/*
    [Util 사용법] - 두가지 중 취향껏..
    1. import { showToast, showSuccess, showWarning } from 'c/_util';
    2. import { toastUtil, navigationUtil, apexUtil } from 'c/_util';
       toastUtil.showToast
       navigationUtil.navigateToRecord

       둘다 자원낭비에 차이없음. (Tree-Shaking)
       실제로는 util.js 전체가 다 로딩되지 않고, 해당 함수들만 번들에 포함
       가독성의 차이

    - Navigation 은 import { NavigationMixin } from 'lightning/navigation';
      extends NavigationMixin(LightningElement) 해야 사용가능.
*/

// Toast
export {
    showToast,    // ex) showToast({title: '저장 완료', message : '레코드가 성공적으로 저장되었습니다.', variant : 'success', mode : 'dismissible' })
    showSuccess,  // ex) showSuccess('데이터가 저장되었습니다.');
    showWarning,  // ex) showError('데이터를 확인하세요.');
    showError,    // ex) showError('API 호출 중 에러가 발생했습니다.', '서버 오류');
    showInfo      // ex) showError('전송되었습니다.');
} from './toast/toast_util';

// Navigation
export {
    navigateToRecord,            // 레코드 상세 페이지로 이동 - ex) navigateToRecord(this, '5005h00001ABCDE', 'Case');
    navigateToListView,          // Object ListView로 이동 - ex) navigateToListView(this, 'Case');
    navigateToNewRecord,         // 새 레코드 생성페이지로 이동 - ex) navigateToNewRecord(this, 'Case');
    navigateToUrl,               // 외부 URL 또는 내부 링크 이동 - ex) navigateToUrl(this, urlLink);
    navigateToApp,               // App (Lightning App) 으로 이동
    navigateToTab,               // Lightning Tab 으로 이동 (탭 이름)
    navigateToComponent,         // Lightning Component Page 로 이동
    navigateToReportOrDashboard, // Report 또는 Dashboard 로 이동
    navigateToFlow,              // Flow 실행 페이지로 이동 (Lightning Flow)
    navigateToVfPage             // Visualforce Page로 이동
} from './navigation/navigation_util';

// Data
export {
    deepClone,          // 깊은 복사 (Deep Clone)
    isEmpty,            // 비어있는 값인지 확인 (null, undefined, '', [], {})
    getValue,           // 안전한 속성 접근 (Optional Chaining)
    uniqueList,         // 배열의 중복 제거
    sortByKey,          // 배열 정렬 (오름/내림차순)
    generateRandomId,   // 랜덤 ID 생성
    nvl,                // null, undefined → '' 변환 (NVL)
    pluck,              // 특정 키값 추출 (pluck)
    deepMerge,          // 깊은 병합 (Deep Merge)
    findByKey,          // 배열 내 객체 검색 (key, value)
    safeJsonParse       // 안전하게 JSON Parse 수행
} from './data/data_util';

// Date
export {
    formatDate,         // Date 객체를 'YYYY-MM-DD' 형식으로 반환
    formatDateTime,     // Date 객체를 'YYYY-MM-DD HH:mm:ss' 형식으로 반환
    today,              // 오늘 날짜 반환 ('YYYY-MM-DD')
    nowISO,             // 현재 시각 ISO 문자열 반환
    addDays,            // 일수 더하기
    diffDays,           // 두 날짜의 차이 (일 단위)
    isAfter,            // 날짜 비교 (date1 > date2 ?)
    isBefore,           // 날짜 비교 (date1 < date2 ?)
    toLocalString,      // ISO 문자열을 로컬 시간 문자열로 변환
    toISO,              // YYYY-MM-DD 문자열을 ISO 형식으로 변환
    diffMonths          // 월 차이 계산 (전체 개월 수)
} from './date/date_util';

// Apex
export {
    callApex,           // try/catch 없이 간단 호출
    callApexWithState,  // 로딩 상태 관리
    delay,              // UI 흐름 제어
    retry               // 재시도 처리
} from './apex/apex_util';

import * as toastUtil from './toast/toast_util';
import * as navigationUtil from './navigation/navigation_util';
import * as apexUtil from './apex/apex_util';
import * as dataUtil from './data/data_util';
import * as dateUtil from './date/date_util';

export {
    toastUtil,
    navigationUtil,
    apexUtil,
    dataUtil,
    dateUtil
};

/*
   [Apex Util 사용법]
   1. callApex (로딩, UI 이벤트 상관없이 단순히 Apex 결과만 가져오고 싶을 때 (ex 초기 데이터 로드 등)

   import { LightningElement } from 'lwc';
   import getCaseList from '@salesforce/apex/CaseController.getCaseList';
   import { callApex } from 'c/util';

   export default class CaseListViewer extends LightningElement {
       cases = [];

       async connectedCallback() {
           const { success, data, error } = await callApex({
               apexMethod: getCaseList,
               params: { limitSize: 10 },
               debugLabel: 'CaseList_init'
           });

           if (success) {
               this.cases = data;
           } else {
               console.error('Case 조회 실패:', error);
           }
       }
   }

   2. callApexWithState (화면에 로딩스피너, Apex 성공/실패 시 각각 UI 상태를 바꿔야 할 때)

   import { LightningElement } from 'lwc';
   import getContactList from '@salesforce/apex/ContactController.getContactList';
   import { callApexWithState } from 'c/util';

   export default class ContactLoader extends LightningElement {
       contacts = [];
       isLoading = false;

       handleLoad() {
           callApexWithState({
               apexMethod: getContactList,
               params: { limitSize: 5 },
               setLoading: (flag) => (this.isLoading = flag),
               onSuccess: (data) => (this.contacts = data),
               onError: (err) => console.warn('Apex Error:', err),
               toastOnError: true,
               toastTitle: '연락처 조회 실패',
               debugLabel: 'ContactLoader_handleLoad'
           });
       }
   }

   3. retry (외부 시스템 연계나 비안정 API 호출 시 일시적 실패를 자동 재시도 하고 싶을 때)

   import { LightningElement } from 'lwc';
   import syncExternal from '@salesforce/apex/ExternalSyncController.syncData';
   import { retry } from 'c/util';

   export default class ExternalSync extends LightningElement {
       async handleSync() {
           try {
               const result = await retry(() => syncExternal({ recordId: '500xx' }), {
                   retries: 3,
                   delayMs: 1000,
                   onRetry: (count, err) => console.warn(`재시도 #${count}`, err)
               });
               console.log('동기화 성공:', result);
           } catch (e) {
               console.error('최종 실패:', e);
           }
       }
   }

   4. delay (연속 동작 간 시간 차를 줄때, 순차 화면전환 등)

   import { LightningElement } from 'lwc';
   import { delay } from 'c/util';

   export default class DelayExample extends LightningElement {
       async handleSequence() {
           console.log('1단계 시작');
           await delay(1000); // 1초 대기
           console.log('2단계 시작');
           await delay(2000);
           console.log('3단계 완료');
       }
   }

*/