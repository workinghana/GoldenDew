import { LightningElement, api, wire, track } from "lwc";
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

  @track isStoreDetailModalOpen = false;
  @track isStoreGroupModalOpen = false;

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

  /* 매장(구분) — PromotionAccount__c 자식 → Account.StoreGroupCode__c Label */
  get storegroupItems() {
    if (!this.storegroup) return [];
    return this.storegroup
      .split(/[;,]\s*/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
  }

  get storeGroupDisplay() {
    const items = this.storegroupItems;
    if (items.length === 0) return "적용 없음";
    if (items.length === 1) return items[0];
    return `${items[0]} 외 ${items.length - 1}개`;
  }

  get hasMoreStoreGroup() {
    return this.storegroupItems.length > 1;
  }

  handleOpenStoreGroupModal() {
    this.isStoreGroupModalOpen = true;
  }

  handleCloseStoreGroupModal() {
    this.isStoreGroupModalOpen = false;
  }

  /* 매장(계열) — Promotion.StoreType__c 멀티픽리스트 Label을 세미콜론 분리 표시 */
  get storedetailItems() {
    if (!this.storedetail) return [];
    return this.storedetail
      .split(/[;,]\s*/)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
  }

  get storeDetailDisplay() {
    const items = this.storedetailItems;
    if (items.length === 0) return "적용 없음";
    if (items.length === 1) return items[0];
    return `${items[0]} 외 ${items.length - 1}개`;
  }

  get hasMoreStoreDetail() {
    return this.storedetailItems.length > 1;
  }

  handleOpenStoreDetailModal() {
    this.isStoreDetailModalOpen = true;
  }

  handleCloseStoreDetailModal() {
    this.isStoreDetailModalOpen = false;
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
