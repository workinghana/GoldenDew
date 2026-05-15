import { LightningElement, api, wire } from "lwc";
import { getRecord } from "lightning/uiRecordApi";

import getPromotionHistory from "@salesforce/apex/PromotionUIControllerV1.getPromotionHistory";

const PROMOTION_FIELDS = [
  "Promotion.Name",
  "Promotion.PromotionNo__c",
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

  promotion;
  error;

  storegroup;
  storedetail;
  productNames;
  pointAccrualAvailable;
  pointAccrualAvailablePointTypes;
  pointAccrualUnavailablePointTypes;
  couponAvailable;

  wiredPromotionHistoryResult;
  timer;

  @wire(getRecord, { recordId: "$recordId", fields: PROMOTION_FIELDS })
  wiredPromotion({ data, error }) {
    if (data) {
      this.promotion = {
        name: data.fields.Name.value,
        PromotionNo: data.fields.PromotionNo__c?.value,
        DisplayName: data.fields.DisplayName.value,
        IsActive: data.fields.IsActive?.value,
        StartDate: data.fields.StartDate.value,
        EndDate: data.fields.EndDate.value,
        PublishStartDate: data.fields.PublishStartDate__c?.value,
        PublishEndDate: data.fields.PublishEndDate__c?.value,
        DiscountRate: data.fields.DiscountRate__c?.value,
        IsPointUsageAllowed: data.fields.IsPointUsageAllowed__c?.value
      };
      this.error = undefined;
      return;
    }

    if (error) {
      this.error = error;
      this.promotion = null;
      // eslint-disable-next-line no-console
      console.error(error);
    }
  }

  @wire(getPromotionHistory, { promotionId: "$recordId" })
  wiredPromotionHistory(result) {
    this.wiredPromotionHistoryResult = result;

    if (result.data && result.data.length > 0) {
      const dto = result.data[0];
      this.storegroup = dto.storegroup;
      this.storedetail = dto.storedetail;
      this.productNames = dto.productNames;
      this.pointAccrualAvailable = dto.isPointAccrualAvailable;
      this.pointAccrualAvailablePointTypes = dto.pointAccrualAvailablePointTypes;
      this.pointAccrualUnavailablePointTypes = dto.pointAccrualUnavailablePointTypes;
      this.couponAvailable = dto.isCouponAvailable;
      return;
    }

    if (result.error) {
      // eslint-disable-next-line no-console
      console.error(result.error);
      this.storegroup = null;
      this.storedetail = null;
      this.productNames = null;
      this.pointAccrualAvailable = null;
      this.pointAccrualAvailablePointTypes = null;
      this.pointAccrualUnavailablePointTypes = null;
      this.couponAvailable = null;
    }
  }

  get promotionName() {
    return this.promotion?.name ?? "---";
  }

  get isPromotionPublishActive() {
    if (!this.promotion?.IsActive) {
      return false;
    }

    const publishStartDate = this.promotion.PublishStartDate;
    const publishEndDate = this.promotion.PublishEndDate;
    if (!publishStartDate || !publishEndDate) {
      return false;
    }

    const now = new Date();
    const today = `${now.getFullYear()}-` + `${String(now.getMonth() + 1).padStart(2, "0")}-` + `${String(now.getDate()).padStart(2, "0")}`;

    return publishStartDate <= today && publishEndDate >= today;
  }

  get promotionPublishActiveText() {
    return this.isPromotionPublishActive ? "활성" : "비활성";
  }

  get promotionPublishActiveClass() {
    return this.isPromotionPublishActive ? "status-text status-active" : "status-text status-inactive";
  }

  get promotionIsActiveText() {
    return this.promotion?.IsActive ? "활성" : "비활성";
  }

  get promotionIsActiveClass() {
    return this.promotion?.IsActive ? "status-text status-active" : "status-text status-inactive";
  }

  get promotionNumber() {
    return this.promotion?.PromotionNo ?? "---";
  }

  get displayName() {
    if (!this.promotion) {
      return "프로모션 표시명 미정";
    }

    return this.promotion.DisplayName || this.promotion.name || "프로모션 표시명 미정";
  }

  get periodText() {
    if (!this.promotion) {
      return "";
    }

    return `${this.promotion.StartDate} ~ ${this.promotion.EndDate}`;
  }

  get publishPeriodText() {
    if (!this.promotion?.PublishStartDate || !this.promotion?.PublishEndDate) {
      return "해당 기간 미설정";
    }

    return `${this.promotion.PublishStartDate} ~ ${this.promotion.PublishEndDate}`;
  }

  getDisplayText(value, fallbackText) {
    if (typeof value === "string") {
      return value.trim() ? value : fallbackText;
    }

    return value ?? fallbackText;
  }

  get storeGroupText() {
    return this.getDisplayText(this.storegroup, "적용 없음");
  }

  get storeDetailText() {
    return this.getDisplayText(this.storedetail, "적용 없음");
  }

  get productNamesText() {
    return this.getDisplayText(this.productNames, "정보 없음");
  }

  get pointAccrualText() {
    return this.pointAccrualAvailablePointTypes ?? (this.pointAccrualAvailable ? "적립 가능" : "적립 불가");
  }

  get pointAccrualUnavailableText() {
    return this.pointAccrualUnavailablePointTypes ?? "해당 없음";
  }

  get PointUsageAllowed() {
    return this.promotion?.IsPointUsageAllowed ? "사용 가능" : "사용 불가";
  }

  get couponAvailableText() {
    return this.couponAvailable ? "적용 가능" : "적용 불가능";
  }
}