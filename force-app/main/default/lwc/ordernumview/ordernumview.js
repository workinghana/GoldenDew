import { LightningElement, api, wire } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";

import getOrderNumView from "@salesforce/apex/OrderNumViewController.getOrderNumView";

export default class Ordernumview extends NavigationMixin(LightningElement) {
  @api recordId;

  order;
  error;
  wiredOrderResult;
  isSaleItemsModalOpen = false;
  isSaleRecordsModalOpen = false;
  currentSaleItemsPage = 1;
  saleItemsPerPage = 5;
  saleItemsPageButtonCount = 5;

  emptyText = "정보 없음";
  saleEmptyText = "판매 없음";
  returnEmptyText = "반품 없음";

  @wire(getOrderNumView, { orderId: "$recordId" })
  wiredOrder(result) {
    this.wiredOrderResult = result;
    const { data, error } = result;

    if (data) {
      this.order = data;
      this.error = undefined;
      return;
    }

    if (error) {
      this.error = error;
      this.order = undefined;

      console.error("getOrderNumView error", error);
    }
  }

  @api
  refreshData() {
    refreshApex(this.wiredOrderResult);
  }

  get hasOrderData() {
    return Boolean(
      this.order?.orderNo ||
      this.order?.orderStatus ||
      this.order?.orderDate ||
      this.order?.orderStoreName ||
      Number(this.order?.orderQuantity) > 0 ||
      Number(this.order?.totalAmount) > 0
    );
  }

  get hasSaleData() {
    return Boolean(
      this.order?.saleNo ||
      this.order?.saleStatus ||
      this.order?.saleDate ||
      this.order?.saleStoreName ||
      (Array.isArray(this.order?.orderItems) && this.order.orderItems.length > 0) ||
      Number(this.order?.saleQuantity) > 0 ||
      Number(this.order?.saleTotalAmount) > 0 ||
      Number(this.order?.saleCashAmount) > 0 ||
      Number(this.order?.saleCardAmount) > 0 ||
      Number(this.order?.saleCouponAmount) > 0 ||
      Number(this.order?.salePointAmount) > 0
    );
  }

  get hasReturnData() {
    return Boolean(
      this.order?.returnNo ||
      this.order?.returnStatus ||
      this.order?.returnDate ||
      this.order?.returnStoreName ||
      Number(this.order?.returnQuantity) > 0 ||
      Number(this.order?.returnTotalAmount) > 0 ||
      Number(this.order?.refundCashAmount) > 0 ||
      Number(this.order?.refundCardAmount) > 0 ||
      Number(this.order?.refundCouponAmount) > 0 ||
      Number(this.order?.refundPointAmount) > 0
    );
  }

  get isOrderStarted() {
    return this.hasOrderData;
  }

  get isSaleStarted() {
    return this.hasSaleData;
  }

  get isReturnStarted() {
    return this.hasReturnData;
  }

  get orderProgressLabel() {
    return this.getProgressLabel(this.order?.orderStatus, this.hasOrderData);
  }

  get saleProgressLabel() {
    return this.getProgressLabel(this.order?.saleStatus, this.hasSaleData);
  }

  get returnProgressLabel() {
    return this.getProgressLabel(this.order?.returnStatus, this.hasReturnData);
  }

  get orderProgressClass() {
    return this.getProgressClass(this.order?.orderStatus, this.hasOrderData);
  }

  get saleProgressClass() {
    return this.getProgressClass(this.order?.saleStatus, this.hasSaleData);
  }

  get returnProgressClass() {
    return this.getProgressClass(this.order?.returnStatus, this.hasReturnData);
  }

  get orderNo() {
    return this.order?.orderNo ?? this.emptyText;
  }

  get orderStatusLabel() {
    return this.order?.orderStatus ?? this.emptyText;
  }

  get orderTypeLabel() {
    return this.order?.orderType ?? this.emptyText;
  }

  get orderDateText() {
    return this.order?.orderDate ? this.formatDate(this.order.orderDate) : this.emptyText;
  }

  get orderStoreName() {
    return this.order?.orderStoreName ?? this.emptyText;
  }

  get orderQuantityText() {
    return this.formatQuantity(this.order?.orderQuantity);
  }

  get totalAmountText() {
    return this.formatCurrency(this.order?.totalAmount);
  }

  get orderCashAmountText() {
    return this.formatCurrency(this.order?.orderCashAmount);
  }

  get orderCardAmountText() {
    return this.formatCurrency(this.order?.orderCardAmount);
  }

  get orderCouponAmountText() {
    return this.formatCurrency(this.order?.orderCouponAmount);
  }

  get orderPointAmountText() {
    return this.formatCurrency(this.order?.orderPointAmount);
  }

  get orderQuantitySummaryText() {
    return `총 ${this.orderQuantityText}개`;
  }

  get orderPaymentItems() {
    return [
      { key: "order-cash", label: "현금", value: this.orderCashAmountText },
      { key: "order-card", label: "카드", value: this.orderCardAmountText },
      { key: "order-coupon", label: "쿠폰", value: this.orderCouponAmountText },
      { key: "order-point", label: "포인트", value: this.orderPointAmountText }
    ];
  }

  get saleStoreName() {
    return this.isSaleStarted ? (this.order?.saleStoreName ?? this.emptyText) : this.saleEmptyText;
  }

  get saleNo() {
    return this.isSaleStarted ? (this.order?.saleNo ?? this.emptyText) : this.saleEmptyText;
  }

  get saleStatusLabel() {
    return this.isSaleStarted ? (this.order?.saleStatus ?? this.emptyText) : this.saleEmptyText;
  }

  get saleDateText() {
    return this.isSaleStarted ? (this.order?.saleDate ? this.formatDate(this.order.saleDate) : this.emptyText) : this.saleEmptyText;
  }

  get saleQuantityText() {
    return this.formatQuantity(this.isSaleStarted ? this.order?.saleQuantity : 0);
  }

  get saleItems() {
    return this.isSaleStarted ? (this.order?.orderItems ?? []) : [];
  }

  get saleRecords() {
    return this.order?.saleRecords ?? [];
  }

  get hasSaleRecordsButton() {
    return this.saleRecords.length > 0;
  }

  get saleRecordsButtonLabel() {
    return `모두 보기(${this.saleRecords.length}건)`;
  }

  get saleRecordRows() {
    return this.saleRecords.map((record, index) => ({
      key: `sale-record-${record.saleNo || index}`,
      saleNo: record.saleNo || this.emptyText,
      status: record.status || this.emptyText,
      saleDate: record.saleDate ? this.formatDate(record.saleDate) : this.emptyText,
      storeName: record.storeName || this.emptyText,
      amount: this.formatCurrency(record.amount)
    }));
  }

  get hasSaleItems() {
    return this.saleItems.length > 0;
  }

  get showSaleItemsEmptyState() {
    return this.isSaleStarted && !this.hasSaleItems;
  }

  get visibleSaleItems() {
    return this.saleItems.slice(0, 2);
  }

  get totalSaleItemsPages() {
    return Math.max(1, Math.ceil(this.saleItems.length / this.saleItemsPerPage));
  }

  get pagedSaleItems() {
    const startIndex = (this.currentSaleItemsPage - 1) * this.saleItemsPerPage;
    return this.saleItems.slice(startIndex, startIndex + this.saleItemsPerPage);
  }

  get saleItemsPageGroupStart() {
    return Math.floor((this.currentSaleItemsPage - 1) / this.saleItemsPageButtonCount) * this.saleItemsPageButtonCount + 1;
  }

  get saleItemsPageGroupEnd() {
    return Math.min(this.saleItemsPageGroupStart + this.saleItemsPageButtonCount - 1, this.totalSaleItemsPages);
  }

  get saleItemsPageNumbers() {
    const pages = [];

    for (let pageNumber = this.saleItemsPageGroupStart; pageNumber <= this.saleItemsPageGroupEnd; pageNumber += 1) {
      pages.push({
        key: `sale-page-${pageNumber}`,
        number: pageNumber,
        className: pageNumber === this.currentSaleItemsPage ? "page-number-btn page-number-btn--active" : "page-number-btn"
      });
    }

    return pages;
  }

  get hasPreviousSaleItemsPageGroup() {
    return this.saleItemsPageGroupStart > 1;
  }

  get hasNextSaleItemsPageGroup() {
    return this.saleItemsPageGroupEnd < this.totalSaleItemsPages;
  }

  get disablePreviousSaleItemsPageGroup() {
    return !this.hasPreviousSaleItemsPageGroup;
  }

  get disableNextSaleItemsPageGroup() {
    return !this.hasNextSaleItemsPageGroup;
  }

  get showSaleItemsButton() {
    return this.saleItems.length > 2;
  }

  get saleAmountText() {
    return this.formatCurrency(this.isSaleStarted ? this.order?.saleTotalAmount : 0);
  }

  get saleCashAmountText() {
    return this.formatCurrency(this.isSaleStarted ? this.order?.saleCashAmount : 0);
  }

  get saleCardAmountText() {
    return this.formatCurrency(this.isSaleStarted ? this.order?.saleCardAmount : 0);
  }

  get saleCouponAmountText() {
    return this.formatCurrency(this.isSaleStarted ? this.order?.saleCouponAmount : 0);
  }

  get salePointAmountText() {
    return this.formatCurrency(this.isSaleStarted ? this.order?.salePointAmount : 0);
  }

  get saleQuantitySummaryText() {
    return `총 ${this.saleQuantityText}개`;
  }

  get salePaymentItems() {
    return [
      { key: "cash", label: "현금", value: this.saleCashAmountText },
      { key: "card", label: "카드", value: this.saleCardAmountText },
      { key: "coupon", label: "쿠폰", value: this.saleCouponAmountText },
      { key: "point", label: "포인트", value: this.salePointAmountText }
    ];
  }

  get salePointItems() {
    return this.buildPointItems(this.isSaleStarted ? this.order?.earnedPointItems : [], "point");
  }

  get hasSalePointItems() {
    return this.salePointItems.length > 0;
  }

  get returnPaymentItems() {
    return [
      { key: "refund-cash", label: "현금", value: this.refundCashAmountText },
      { key: "refund-card", label: "카드", value: this.refundCardAmountText },
      { key: "refund-coupon", label: "쿠폰", value: this.refundCouponAmountText },
      { key: "refund-point", label: "포인트", value: this.refundPointAmountText }
    ];
  }

  get returnStoreName() {
    return this.isReturnStarted ? (this.order?.returnStoreName ?? this.emptyText) : this.returnEmptyText;
  }

  get returnNo() {
    return this.isReturnStarted ? (this.order?.returnNo ?? this.returnEmptyText) : this.returnEmptyText;
  }

  get returnStatusLabel() {
    return this.isReturnStarted ? (this.order?.returnStatus ?? this.returnEmptyText) : this.returnEmptyText;
  }

  get returnDateText() {
    return this.isReturnStarted ? (this.order?.returnDate ? this.formatDate(this.order.returnDate) : this.emptyText) : this.returnEmptyText;
  }

  get returnQuantityText() {
    return this.formatQuantity(this.isReturnStarted ? this.order?.returnQuantity : 0);
  }

  get returnAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.returnTotalAmount : 0);
  }

  get refundAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.returnTotalAmount : 0);
  }

  get refundCashAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundCashAmount : 0);
  }

  get refundCardAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundCardAmount : 0);
  }

  get refundCouponAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundCouponAmount : 0);
  }

  get refundPointAmountText() {
    return this.formatCurrency(this.isReturnStarted ? this.order?.refundPointAmount : 0);
  }

  get restoredPointItems() {
    return this.buildPointItems(this.isReturnStarted ? this.order?.restoredPointItems : [], "restored-point");
  }

  get pointTypeOptions() {
    return this.order?.pointTypeOptions ?? [];
  }

  get customerName() {
    return this.order?.customerName ?? this.emptyText;
  }

  get customerMemberNo() {
    return this.order?.customerMemberNo ?? this.emptyText;
  }

  get customerPhone() {
    return this.formatPhone(this.order?.customerPhone);
  }

  get customerGrade() {
    return this.order?.customerGrade ?? this.emptyText;
  }

  get managedStoreName() {
    return this.order?.managedStoreName ?? this.emptyText;
  }

  handleOpenSaleItemsModal() {
    this.currentSaleItemsPage = 1;
    this.isSaleItemsModalOpen = true;
  }

  handleCloseSaleItemsModal() {
    this.isSaleItemsModalOpen = false;
    this.currentSaleItemsPage = 1;
  }

  handleOpenSaleRecordsModal() {
    this.isSaleRecordsModalOpen = true;
  }

  handleCloseSaleRecordsModal() {
    this.isSaleRecordsModalOpen = false;
  }

  handleSaleItemsPageClick(event) {
    const pageNumber = Number(event.currentTarget.dataset.page);

    if (!Number.isFinite(pageNumber)) {
      return;
    }

    this.currentSaleItemsPage = pageNumber;
  }

  handlePreviousSaleItemsPageGroup() {
    this.currentSaleItemsPage = Math.max(1, this.saleItemsPageGroupStart - this.saleItemsPageButtonCount);
  }

  handleNextSaleItemsPageGroup() {
    this.currentSaleItemsPage = Math.min(this.totalSaleItemsPages, this.saleItemsPageGroupStart + this.saleItemsPageButtonCount);
  }

  handleCustomerDetail() {
    const loyaltyProgramMemberId = this.order?.loyaltyProgramMemberId;
    if (!loyaltyProgramMemberId) {
      return;
    }

    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: loyaltyProgramMemberId,
        objectApiName: "LoyaltyProgramMember",
        actionName: "view"
      }
    });
  }

  buildPointItems(sourceItems, prefix) {
    const pointAmountByType = new Map();
    const pointLabelByType = new Map();

    if (Array.isArray(sourceItems)) {
      sourceItems.forEach((item) => {
        const type = item?.type || item?.label;
        const label = item?.label || item?.type;

        if (!type) {
          return;
        }

        pointLabelByType.set(type, label || type);
        pointAmountByType.set(type, Number(item?.amount) || 0);
      });
    }

    const optionList =
      this.pointTypeOptions.length > 0 ? this.pointTypeOptions : Array.from(pointLabelByType.entries()).map(([type, label]) => ({ type, label }));

    return optionList.map((option, index) => {
      const type = option?.type || option?.label || `${prefix}-${index}`;
      const label = option?.label || option?.type || type;

      return {
        key: `${prefix}-${type}-${index}`,
        label,
        value: `${this.formatNumber(pointAmountByType.get(type))}P`
      };
    });
  }

  getProgressLabel(statusLabel, hasData) {
    const progressState = this.getStageProgressState(statusLabel, hasData);

    if (progressState === "completed") {
      return "진행 완료";
    }

    if (progressState === "in_progress") {
      return "진행중";
    }

    return "미진행";
  }

  getProgressClass(statusLabel, hasData) {
    const progressState = this.getStageProgressState(statusLabel, hasData);

    if (progressState === "completed") {
      return "progress-badge progress-badge--completed";
    }

    if (progressState === "in_progress") {
      return "progress-badge progress-badge--in-progress";
    }

    return "progress-badge progress-badge--not-started";
  }

  getStageProgressState(statusLabel, hasData) {
    const normalizedStatus = (statusLabel || "").trim();

    if (!normalizedStatus) {
      return hasData ? "completed" : "not_started";
    }

    if (
      normalizedStatus.includes("완료") ||
      normalizedStatus.includes("결제") ||
      normalizedStatus.includes("성공") ||
      normalizedStatus.includes("생성")
    ) {
      return "completed";
    }

    return "in_progress";
  }

  formatCurrency(value) {
    return `${this.formatNumber(value)}원`;
  }

  formatQuantity(value) {
    return this.formatNumber(value);
  }

  formatNumber(value) {
    const numberValue = Number(value);
    return Number.isFinite(numberValue) ? numberValue.toLocaleString("ko-KR") : "0";
  }

  formatDate(value) {
    if (!value) {
      return this.emptyText;
    }

    const dateValue = new Date(value);
    return `${dateValue.getFullYear()}.${String(dateValue.getMonth() + 1).padStart(2, "0")}.${String(dateValue.getDate()).padStart(2, "0")}`;
  }

  formatPhone(phone) {
    if (!phone) {
      return this.emptyText;
    }

    const digits = phone.replace(/\D/g, "");
    if (digits.length === 11) {
      return digits.replace(/(\d{3})(\d{4})(\d{4})/, "$1-$2-$3");
    }

    return phone;
  }
}
