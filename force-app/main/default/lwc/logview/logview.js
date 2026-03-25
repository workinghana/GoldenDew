import { LightningElement, api, wire } from 'lwc';
import getDetail from '@salesforce/apex/ErrorLogUIControllerV1.getDetail';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';
import getLpmIdByContactId
    from '@salesforce/apex/GdMemberDetailUIController.getLoyaltyProgramMemberIdByContactId';


export default class ApexAuditTrailDetail extends NavigationMixin(LightningElement) {
    @api recordId;

    log;
    error;
    wiredResult;
    timer;

    /* ======================
       Apex Log 조회
    ====================== */
    @wire(getDetail, { recordId: '$recordId' })
    wiredLog(result) {
        this.wiredResult = result;

        if (result.data) {
            this.log = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.log = undefined;
        }
    }



    refresh() {
        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }



    /* ======================
       UI 제어
    ====================== */
    get hasStackTrace() {
        return this.log?.StackTrace__c && this.log.StackTrace__c.trim() !== '';
    }

    get statusBadgeClass() {
        if (this.log?.Status__c === 'SUCCESS') {
            return 'status-badge success';
        }
        if (this.log?.Status__c === 'ERROR') {
            return 'status-badge error';
        }
        if (this.log?.Status__c === 'PARTIAL') {
            return 'status-badge partial';
        }
        return 'status-badge';
    }

    get requestDateTimeFormatted() {
        return this.formatDateTime(this.log?.RequestDateTime__c);
    }

    /* ======================
       실패 Id 파싱
    ====================== */
    get failedIds() {
        if (!this.log?.FailedRecordIds__c) return [];
        return this.log.FailedRecordIds__c.split('|');
    }

    get hasFailedIds() {
        return this.failedIds.length > 0;
    }

    /* ======================
       레코드 페이지 이동
    ====================== */
    handleGoToRecord(event) {
        const contactId = event.currentTarget.dataset.id;
        if (!contactId) return;

        getLpmIdByContactId({ contactId })
            .then(lpmId => {
                if (lpmId) {
                    // ✅ LoyaltyProgramMember가 있으면 → 회원 상세
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: lpmId,
                            objectApiName: 'LoyaltyProgramMember',
                            actionName: 'view'
                        }
                    });
                } else {
                    // ✅ 없으면 → Contact 상세
                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: contactId,
                            objectApiName: 'Contact',
                            actionName: 'view'
                        }
                    });
                }
            })
            .catch(error => {
                console.error('Failed to navigate to member', error);

                // 🔒 예외 상황에서도 Contact로 폴백
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: contactId,
                        objectApiName: 'Contact',
                        actionName: 'view'
                    }
                });
            });
    }




    formatDateTime(value) {
        if (!value) return '';

        const date = new Date(value);
        return new Intl.DateTimeFormat('ko-KR', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: false,
            timeZone: 'Asia/Seoul'
        }).format(date);
    }
}