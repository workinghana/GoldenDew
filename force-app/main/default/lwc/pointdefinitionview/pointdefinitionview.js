import { LightningElement, api, wire } from 'lwc';
import getLoyaltyCurrencyDetail from '@salesforce/apex/PointDefinitionViewControllerV1.getLoyaltyCurrencyDetail';

export default class Pointdefinitionview extends LightningElement {


    @api recordId;


    pointDetail;    // DTO 전체
    error;          // 에러 처리용

    /* ================= Apex Call ================= */
    @wire(getLoyaltyCurrencyDetail, { loyaltyCurrencyId: '$recordId' })
    wiredPointDetail({ data, error }) {
        if (data) {
            this.pointDetail = data;
            this.error = undefined;
            console.log('Point Detail:', JSON.stringify(data));
        } else if (error) {
            this.error = error;
            this.pointDetail = undefined;
            console.error('Error:', error);
        }
    }

    /* ================= Getter (Template 용) ================= */

    get pointName() {
        return this.pointDetail?.pointName;
    }

    get currencyType() {
        return this.pointDetail?.currencyType;
    }

    get isActiveLabel() {
        return this.pointDetail?.isActive ? '활성' : '비활성';
    }

    get currencyStatusClass() {
        if (!this.pointDetail) return '';

        return [
            'status-badge',
            this.pointDetail.isActive
                ? 'status-badge--active'
                : 'status-badge--inactive'
        ].join(' ');
    }


    /* ================= 만료 정책 ================= */
    get expiryPolicy() {
        const freq = this.pointDetail?.expiryPeriodFrequency;
        const unit = this.pointDetail?.expiryPeriodUnit;

        if (!freq || !unit) {
            return null;
        }

        const UNIT_LABEL_MAP = {
            Years: '년',
            Months: '개월',
            Days: '일'
        };

        const unitLabel = UNIT_LABEL_MAP[unit] ?? unit;

        return `적립일로부터 ${freq}${unitLabel}`;
    }


    get hasSubtype() {
        return this.pointDetail?.pointTypeCode != null;
    }

    get usagePriority() {
        return this.pointDetail?.usagePriority;
    }

    get accruedPoints() {
        return this.pointDetail?.accruedPoints;
    }

    get expiryDate() {
        return this.pointDetail?.expiryDate;
    }
}