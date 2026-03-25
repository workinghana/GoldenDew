import { LightningElement, api, wire } from 'lwc';
import getMemebrInfo from '@salesforce/apex/GdMemberDashboardController.getMemebrInfo';

export default class MemberinfoDashboard extends LightningElement {

    @api recordId; // LoyaltyProgramMember Id

    benefit;
    grade;
    marketing;
    error;

    @wire(getMemebrInfo, { loyaltyProgramMemberId: '$recordId' })
    wiredMemberInfo({ data, error }) {
        if (data) {
            this.benefit = data.benefit;
            this.grade = data.grade;
            this.marketing = data.marketing;
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.benefit = undefined;
            this.grade = undefined;
            this.marketing = undefined;
            // 디버깅용
            console.error('getMemebrInfo error', error);
        }
    }

    get emailConsentLabel() {
        return this.marketing?.emailConsent ? '동의' : '거부';
    }

    get smsConsentLabel() {
        return this.marketing?.smsConsent ? '동의' : '거부';
    }

    get magazinConsentLabel() {
        return this.marketing?.magazineConsent ? '동의' : '거부';
    }

    get gradeUpdatedText() {
        if (!this.grade || !this.grade.lastUpdatedDate) {
            return '-';
        }

        const d = new Date(this.grade.lastUpdatedDate);
        return `${d.getFullYear()}.${String(d.getMonth() + 1).padStart(2, '0')}.${String(d.getDate()).padStart(2, '0')}
    ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    }



}