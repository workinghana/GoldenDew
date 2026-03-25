import { LightningElement, api, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";

import getPromotionHistory from "@salesforce/apex/PromotionUIControllerV1.getPromotionHistory";

/* ================= Promotion (LDS) 필드 ================= */
const PROMOTION_FIELDS = [
  "Promotion.Name",
  "Promotion.PromotionCode",
  "Promotion.DisplayName",
  "Promotion.IsActive",
  "Promotion.StartDate",
  "Promotion.EndDate",
  "Promotion.PublishStartDate__c",
  "Promotion.PublishEndDate__c",
  "Promotion.DiscountRate__c",
  "Promotion.IsPointUsageAllowed__c"
];

export default class Promotionview extends LightningElement {
  @api recordId;

  /* ===== LDS 데이터 ===== */
  promotion;
  error;

  /* ===== Apex 가공 데이터 ===== */
  storegroup;
  storedetail;
  productNames;
  pointAccrualAvailable;
  couponAvailable;

  /* ===== Apex wire 결과 ===== */
  wiredPromotionHistoryResult;
  timer;

  /* ================= Promotion (LDS) ================= */
  @wire(getRecord, { recordId: "$recordId", fields: PROMOTION_FIELDS })
  wiredPromotion({ data, error }) {
    if (data) {
      this.promotion = {
        name: data.fields.Name.value,
        PromotionCode: data.fields.PromotionCode.value,
        DisplayName: data.fields.DisplayName.value,
        IsActive: data.fields.IsActive.value,
        StartDate: data.fields.StartDate.value,
        EndDate: data.fields.EndDate.value,
        PublishStartDate: data.fields.PublishStartDate__c?.value,
        PublishEndDate: data.fields.PublishEndDate__c?.value,
        DiscountRate: data.fields.DiscountRate__c?.value,
        IsPointUsageAllowed: data.fields.IsPointUsageAllowed__c?.value
      };
      this.error = undefined;
    } else if (error) {
      this.error = error;
      this.promotion = null;
      console.error(error);
    }
  }

  /* ================= Promotion (Apex 가공) ================= */
  @wire(getPromotionHistory, { promotionId: "$recordId" })
  wiredPromotionHistory(result) {
    this.wiredPromotionHistoryResult = result;

    if (result.data && result.data.length > 0) {
      const dto = result.data[0];
      this.storegroup = dto.storegroup;
      this.storedetail = dto.storedetail;
      this.productNames = dto.productNames;
      this.pointAccrualAvailable = dto.isPointAccrualAvailable;
      this.couponAvailable = dto.isCouponAvailable;
    } else if (result.error) {
      console.error(result.error);
      this.storegroup = null;
      this.storedetail = null;
      this.productNames = null;
      this.pointAccrualAvailable = null;
    }
  }

  /* ================= 화면 Getter ================= */

  get promotionName() {
    return this.promotion?.name ?? "---";
  }

  get promotionCode() {
    return this.promotion?.PromotionCode ?? "---";
  }

  get displayName() {
    if (!this.promotion) return "프로모션 표시명 미존재";

    return this.promotion.DisplayName || this.promotion.name || "프로모션 표시명 미존재";
  }

  get activeText() {
    if (!this.promotion) return "";
    return this.promotion.IsActive ? "활성" : "비활성";
  }

  get activeStatusClass() {
    if (!this.promotion) return "promotion-status-badge";

    return this.promotion.IsActive ? "promotion-status-badge status-active" : "promotion-status-badge status-inactive";
  }

  get periodText() {
    if (!this.promotion) return "";
    return `${this.promotion.StartDate} ~ ${this.promotion.EndDate}`;
  }

  get publishPeriodText() {
    if (!this.promotion?.PublishStartDate || !this.promotion?.PublishEndDate) {
      return "해당 기간 미설정";
    }
    return `${this.promotion.PublishStartDate} ~ ${this.promotion.PublishEndDate}`;
  }

  get storeGroupText() {
    return this.storegroup ?? "정보 없음";
  }

  get storeDetailText() {
    return this.storedetail ?? "정보 없음";
  }

  get productNamesText() {
    return this.productNames ?? "정보 없음";
  }
  get pointAccrualText() {
    return this.pointAccrualAvailable ? "적립 가능" : "적립 불가";
  }

  get PointUsageAllowed() {
    return this.promotion?.IsPointUsageAllowed ? "사용 가능" : "사용 불가";
  }

  get couponAvailableText() {
    return this.couponAvailable ? "적용 가능" : "적용 불가능";
  }
}